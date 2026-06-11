#lang racket/base

(require rackunit
         racket/file
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system)

(define-runtime-path here ".")
(define repo-root
  (simplify-path (build-path here 'up)))

;; maybe-local-racket-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-racket-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "racket")))
  (and (file-exists? p) p))

;; maybe-local-raco-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-raco-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "raco")))
  (and (file-exists? p) p))

;; current-racket-path : -> (or/c path? #f)
;;   Fall back to the current PATH when the sibling checkout is unavailable.
(define (current-racket-path)
  (find-executable-path "racket"))

;; current-raco-path : -> (or/c path? #f)
;;   Fall back to the current PATH when the sibling checkout is unavailable.
(define (current-raco-path)
  (find-executable-path "raco"))

;; racket-path : path?
;;   Pick one Racket executable for the whole test run.
(define racket-path
  (or (maybe-local-racket-path)
      (current-racket-path)))

;; raco-path : path?
;;   Pick one `raco` executable for the whole test run.
(define raco-path
  (or (maybe-local-raco-path)
      (current-raco-path)))

;; collects-root : path?
;;   Derive the collects root that matches `racket-path`.
(define collects-root
  (cond
    [(maybe-local-racket-path)
     (simplify-path
      (build-path repo-root 'up "racket" "racket" "collects"))]
    [else
     (find-system-path 'collects-dir)]))

;; skip! : string? -> none
;;   Exit cleanly with a visible skip reason instead of failing misleadingly.
(define (skip! msg)
  (displayln (string-append "SKIP: " msg))
  (exit 0))

(unless racket-path
  (skip! "could not find a Racket executable"))

(unless raco-path
  (skip! "could not find a raco executable"))

(unless (directory-exists? collects-root)
  (skip! (format "collects directory not found: ~a" collects-root)))

;; make-temp-dir : string? -> path?
;;   Create a fresh temporary directory for one test run.
(define (make-temp-dir template)
  (make-temporary-file template 'directory))

;; write-program! : path? string? -> path?
;;   Write one temporary WebRacket source file and return its path.
(define (write-program! dir name source)
  (define p (build-path dir name))
  (call-with-output-file p
    (lambda (out)
      (display source out))
    #:exists 'truncate/replace)
  p)

;; build-env : path? -> environment-variables?
;;   Construct an isolated subprocess environment for compiler checks.
(define (build-env compiled-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (environment-variables-set!
   env
   #"PLTCOLLECTS"
   (string->bytes/utf-8
    (format "~a:~a"
            (path->string (build-path repo-root "pkgs"))
            (path->string collects-root))))
  (environment-variables-set!
   env
   #"PLTCOMPILEDROOTS"
   (string->bytes/utf-8 (path->string compiled-root)))
  env)

;; run/collect : path? (listof string?) path? environment-variables? exact-positive-integer? -> values
;;   Run one subprocess, capture stdout/stderr together, and enforce a timeout.
(define (run/collect exe args cwd env timeout-seconds)
  (parameterize ([current-directory cwd]
                 [current-environment-variables env])
    (define-values (proc out in err)
      (apply subprocess #f #f #f (path->string exe) args))
    (close-output-port in)
    (define out-ch (make-channel))
    (define err-ch (make-channel))
    (define out-th
      (thread (lambda ()
                (channel-put
                 out-ch
                 (with-handlers ([exn:fail? (lambda (_e) "")])
                   (port->string out))))))
    (define err-th
      (thread (lambda ()
                (channel-put
                 err-ch
                 (with-handlers ([exn:fail? (lambda (_e) "")])
                   (port->string err))))))
    (define done? (sync/timeout timeout-seconds proc))
    (unless done?
      (subprocess-kill proc #t)
      (sync proc)
      (define timed-out-output
        (string-append
         (channel-get out-ch)
         (channel-get err-ch)))
      (error 'run/collect
             (string-append
              "subprocess timed out\n"
              timed-out-output)))
    (subprocess-wait proc)
    (values (subprocess-status proc)
            (string-append (channel-get out-ch)
                           (channel-get err-ch)))))

;; assert-cache-status! : string? string? -> void
;;   Check that one transcript line reports the expected cache status.
(define (assert-cache-status! expected output)
  (define ok?
    (for/or ([line (in-list (string-split output "\n"))])
      (and (regexp-match? #rx"runtime-analysis-v2-cache-hit\\?" line)
           (regexp-match? (pregexp (format ":\\s*~a\\s*$" expected)) line))))
  (check-true
   ok?
   (format "expected cache status ~a\n--- output ---\n~a" expected output)))

;; assert-generated-output! : path? -> void
;;   Confirm the compile produced a wasm artifact somewhere in the destination.
(define (assert-generated-output! dest-dir)
  (define wasm-files
    (find-files
     (lambda (p)
       (and (file-exists? p)
            (regexp-match? #rx"[.]wasm$" (path->string p))))
     dest-dir))
  (check-true
   (pair? wasm-files)
   (format "expected at least one .wasm file in ~a" dest-dir)))

;; precompile-webracket! : environment-variables? -> void
;;   Build `webracket.rkt` once with the isolated compiled-root environment.
(define (precompile-webracket! env)
  (define-values (status output)
    (run/collect raco-path
                 (list "make" "webracket.rkt")
                 repo-root
                 env
                 240))
  (check-equal? status 0
                (format "precompile failed\n--- output ---\n~a" output)))

;; compile-with-timings : path? path? path? environment-variables? -> values
;;   Compile one source file and return exit status plus the combined transcript.
(define (compile-with-timings source-path dest-dir cache-dir env)
  (run/collect racket-path
               (list (path->string (build-path repo-root "webracket.rkt"))
                     "--browser"
                     "--dest" (path->string dest-dir)
                     "--timings"
                     "--provider-cache-dir" (path->string cache-dir)
                     (path->string source-path))
               repo-root
               env
               240))

;; compatible-racket? : environment-variables? -> boolean?
;;   Check that the selected toolchain can at least report a version.
(define (compatible-racket? env)
  (define-values (status output)
    (run/collect racket-path
                 (list "-e" "(display (version))")
                 repo-root
                 env
                 30))
  (and (equal? status 0)
       (regexp-match? #rx"^[0-9]+" output)))

(define temp-root
  (make-temp-dir "webracket-runtime-analysis-cache-test~a"))
(define compiled-root
  (build-path temp-root "compiled"))
(define provider-cache-dir
  (build-path temp-root "provider-cache"))
(define generated-root
  (build-path temp-root "generated"))
(define sources-root
  (build-path temp-root "sources"))

(make-directory* compiled-root)
(make-directory* provider-cache-dir)
(make-directory* generated-root)
(make-directory* sources-root)

(define env (build-env compiled-root))

(unless (compatible-racket? env)
  (skip! (format "selected racket is unavailable or incompatible: ~a" racket-path)))

(define program-a
  (write-program!
   sources-root
   "program-a.rkt"
   (string-join
    '("#lang webracket/base"
      ""
      "(define greeting \"Have a nice day.\")"
      ""
      "greeting")
    "\n")))

(define program-a-edited
  (write-program!
   sources-root
   "program-a-edited.rkt"
   (string-replace
    (file->string program-a)
    "Have a nice day."
    "Have a brighter day.")))

(define program-b
  (write-program!
   sources-root
   "program-b.rkt"
   (string-join
    '("#lang webracket/base"
      ""
      "(define (bump n)"
      "  (+ n 1))"
      ""
      "(bump 41)")
    "\n")))

(define test-suite/runtime-analysis-cache
  (test-suite
   "runtime-analysis-cache"
   (test-case
    "runtime analysis v2 cache survives rebuilds, edits, and different programs"
    (precompile-webracket! env)

    (define dest-a-1 (build-path generated-root "a-1"))
    (define dest-a-2 (build-path generated-root "a-2"))
    (define dest-a-edit (build-path generated-root "a-edit"))
    (define dest-b (build-path generated-root "b"))
    (for ([dir (in-list (list dest-a-1 dest-a-2 dest-a-edit dest-b))])
      (make-directory* dir))

    (define-values (status-a-1 output-a-1)
      (compile-with-timings program-a dest-a-1 provider-cache-dir env))
    (check-equal? status-a-1 0 output-a-1)
    (assert-cache-status! "no" output-a-1)
    (assert-generated-output! dest-a-1)

    (define-values (status-a-2 output-a-2)
      (compile-with-timings program-a dest-a-2 provider-cache-dir env))
    (check-equal? status-a-2 0 output-a-2)
    (assert-cache-status! "yes" output-a-2)
    (assert-generated-output! dest-a-2)

    (define-values (status-a-edit output-a-edit)
      (compile-with-timings program-a-edited dest-a-edit provider-cache-dir env))
    (check-equal? status-a-edit 0 output-a-edit)
    (assert-cache-status! "yes" output-a-edit)
    (assert-generated-output! dest-a-edit)

    (define-values (status-b output-b)
      (compile-with-timings program-b dest-b provider-cache-dir env))
    (check-equal? status-b 0 output-b)
    (assert-cache-status! "yes" output-b)
    (assert-generated-output! dest-b))))

(module+ main
  (require rackunit/text-ui)
  (define result
    (run-tests test-suite/runtime-analysis-cache))
  (unless (zero? result)
    (exit result)))
