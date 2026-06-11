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

;; racket-path : path?
;;   Pick one Racket executable for the whole test run.
(define racket-path
  (or (maybe-local-racket-path)
      (find-executable-path "racket")))

;; raco-path : path?
;;   Pick one `raco` executable for the whole test run.
(define raco-path
  (or (maybe-local-raco-path)
      (find-executable-path "raco")))

;; collects-root : path?
;;   Derive the matching collects root for the selected toolchain.
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

;; write-source! : path? string? string? -> path?
;;   Write a temporary source file and return its path.
(define (write-source! dir name source)
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
    (thread (lambda ()
              (channel-put
               out-ch
               (with-handlers ([exn:fail? (lambda (_e) "")])
                 (port->string out)))))
    (thread (lambda ()
              (channel-put
               err-ch
               (with-handlers ([exn:fail? (lambda (_e) "")])
                 (port->string err)))))
    (define done? (sync/timeout timeout-seconds proc))
    (unless done?
      (subprocess-kill proc #t)
      (sync proc)
      (error 'run/collect
             (string-append
              "subprocess timed out\n"
              (channel-get out-ch)
              (channel-get err-ch))))
    (subprocess-wait proc)
    (values (subprocess-status proc)
            (string-append (channel-get out-ch)
                           (channel-get err-ch)))))

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

;; compile-with-timings : path? path? (listof string?) environment-variables? -> values
;;   Compile one source file and return exit status plus the combined transcript.
(define (compile-with-timings source-path dest-dir extra-args env)
  (run/collect racket-path
               (append
                (list (path->string (build-path repo-root "webracket.rkt"))
                      "--browser"
                      "--dest" (path->string dest-dir)
                      "--timings")
                extra-args
                (list (path->string source-path)))
               repo-root
               env
               240))

;; assert-stdlib-mode! : string? string? string? -> void
;;   Check that the output contains one stdlib decision line with the expected value.
(define (assert-stdlib-mode! key expected output)
  (check-true
   (for/or ([line (in-list (string-split output "\n"))])
     (and (regexp-match? (pregexp (format "^\\s*~a\\s*:" (regexp-quote key))) line)
          (regexp-match? (pregexp (format ":\\s*~a\\s*$" (regexp-quote expected))) line)))
   (format "expected ~a = ~a\n--- output ---\n~a" key expected output)))

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

(define temp-root
  (make-temp-dir "webracket-module-no-legacy-stdlib~a"))
(define compiled-root
  (build-path temp-root "compiled"))
(define generated-root
  (build-path temp-root "generated"))
(define sources-root
  (build-path temp-root "sources"))

(make-directory* compiled-root)
(make-directory* generated-root)
(make-directory* sources-root)

(define env (build-env compiled-root))

(define module-source
  (write-source!
   sources-root
   "module-default.rkt"
   (string-join
    '("#lang webracket/base"
      ""
      "(define greeting \"hello\")"
      ""
      "greeting")
    "\n")))

(define script-source
  (write-source!
   sources-root
   "script-stdlib.rkt"
   (string-join
    '("(define rendered"
      "  (format \"fmt ~a\" 'ok))"
      ""
      "rendered")
    "\n")))

(define test-suite/module-no-legacy-stdlib
  (test-suite
   "module-no-legacy-stdlib"
   (test-case
    "module input skips legacy stdlib and io/format provider by default"
    (precompile-webracket! env)
    (define dest-dir (build-path generated-root "module-default"))
    (make-directory* dest-dir)
    (define-values (status output)
      (compile-with-timings module-source dest-dir '() env))
    (check-equal? status 0 output)
    (assert-stdlib-mode! "input-mode" "module" output)
    (assert-stdlib-mode! "legacy-stdlib-mode" "skipped-module-input" output)
    (assert-stdlib-mode! "io-format-provider-mode" "skipped-module-input" output)
    (assert-generated-output! dest-dir))

   (test-case
    "module input stays stdlib-free under --no-stdlib"
    (define dest-dir (build-path generated-root "module-no-stdlib"))
    (make-directory* dest-dir)
    (define-values (status output)
      (compile-with-timings module-source dest-dir '("--no-stdlib") env))
    (check-equal? status 0 output)
    (assert-stdlib-mode! "legacy-stdlib-mode" "skipped-module-input" output)
    (assert-stdlib-mode! "io-format-provider-mode" "skipped-module-input" output)
    (assert-generated-output! dest-dir))

   (test-case
    "module input ignores explicit --stdlib"
    (define dest-dir (build-path generated-root "module-explicit-stdlib"))
    (make-directory* dest-dir)
    (define-values (status output)
      (compile-with-timings module-source dest-dir '("--stdlib") env))
    (check-equal? status 0 output)
    (assert-stdlib-mode! "legacy-stdlib-mode" "ignored-module-input" output)
    (assert-stdlib-mode! "io-format-provider-mode" "skipped-module-input" output)
    (assert-generated-output! dest-dir))

   (test-case
    "script input still enables legacy stdlib explicitly"
    (define dest-dir (build-path generated-root "script-explicit-stdlib"))
    (make-directory* dest-dir)
    (define-values (status output)
      (compile-with-timings script-source dest-dir '("--stdlib") env))
    (check-equal? status 0 output)
    (assert-stdlib-mode! "input-mode" "script" output)
    (assert-stdlib-mode! "legacy-stdlib-mode" "enabled-script-input" output)
    (assert-stdlib-mode! "io-format-provider-mode" "enabled-script-input" output)
    (assert-generated-output! dest-dir))))

(module+ main
  (require rackunit/text-ui)
  (define result
    (run-tests test-suite/module-no-legacy-stdlib))
  (unless (zero? result)
    (exit result)))
