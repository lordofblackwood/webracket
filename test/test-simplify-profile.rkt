#lang racket/base

(require rackunit
         rackunit/text-ui
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

;; compile-with-profile : path? path? environment-variables? -> values
;;   Compile one source file and return exit status plus the combined transcript.
(define (compile-with-profile source-path dest-dir env)
  (run/collect racket-path
               (list (path->string (build-path repo-root "webracket.rkt"))
                     "--browser"
                     "--dest" (path->string dest-dir)
                     "--timings"
                     "--enable-simplify"
                     "--simplify-profile"
                     "--no-io-format-provider"
                     (path->string source-path))
               repo-root
               env
               240))

;; assert-output-contains! : string? string? -> void
;;   Check that the transcript contains one stable profile marker.
(define (assert-output-contains! needle output)
  (check-true
   (regexp-match? (pregexp (regexp-quote needle)) output)
   (format "expected output to contain ~a\n--- output ---\n~a" needle output)))

;; assert-output-matches! : string? string? -> void
;;   Check that the transcript matches one explicit regexp pattern.
(define (assert-output-matches! pattern output)
  (check-true
   (regexp-match? (pregexp pattern) output)
   (format "expected output to match ~a\n--- output ---\n~a" pattern output)))

(define temp-root
  (make-temp-dir "webracket-simplify-profile~a"))
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
   "module-simplify.rkt"
   (string-join
    '("#lang webracket/base"
      ""
      "(define (demo x)"
      "  (let-values ([(unused) (string-append \"a\" \"b\")])"
      "    ((case-lambda"
      "       [(y) y]"
      "       [(y z) ((lambda (a b) (+ a b)) y z)])"
      "     1 2)))"
      ""
      "(demo 0)")
    "\n")))

(define test-suite/simplify-profile
  (test-suite
   "simplify-profile"
   (test-case
    "module compile emits simplify profile report"
    (precompile-webracket! env)
    (define dest-dir (build-path generated-root "module-simplify"))
    (make-directory* dest-dir)
    (define-values (status output)
      (compile-with-profile module-source dest-dir env))
    (check-equal? status 0 output)
    (assert-output-contains! "=== Simplify-LFE Profile ===" output)
    (assert-output-contains! "input-nodes" output)
    (assert-output-contains! "output-nodes" output)
    (assert-output-contains! "nodes-removed" output)
    (assert-output-contains! "free-var-summary-cache-hits" output)
    (assert-output-contains! "free-var-summary-cache-misses" output)
    (assert-output-contains! "free-var-summary-root-ms" output)
    (assert-output-contains! "free-var-summary-total-inclusive-ms" output)
    (assert-output-contains! "free-var-summary-max-expression-nodes" output)
    (assert-output-contains! "free-var-summary-total-root-nodes" output)
    (assert-output-contains! "let-unused-pure-membership-checks" output)
    (assert-output-contains! "let-unused-pure-fallback-scans" output)
    (assert-output-contains! "rule\tprimitive-constant-fold\tfires\t" output)
    (assert-output-contains! "shape-before" output)
    (assert-output-contains! "shape-after" output)
    (assert-output-contains! "app-operators-before" output)
    (assert-output-contains! "app-operators-after" output)
    (assert-output-contains! "top-unsimplified-app-operators" output)
    (assert-output-contains! "top-unsimplified-pure-app-operators" output)
    (assert-output-contains! "top-unsimplified-foldable-looking-app-operators" output)
    (assert-output-contains! "top-unsimplified-arity-query-apps" output)
    (assert-output-contains! "top-unsimplified-procedure-query-apps" output))
   (test-case
    "targeted simplify rules fire on the fixture"
    (define dest-dir (build-path generated-root "module-simplify-targeted"))
    (make-directory* dest-dir)
    (define-values (status output)
      (compile-with-profile module-source dest-dir env))
    (check-equal? status 0 output)
    (assert-output-matches! "rule\tlet-unused-pure\tfires\t[1-9]" output))))

(module+ main
  (define result
    (run-tests test-suite/simplify-profile))
  (exit (if (zero? result) 0 1)))
