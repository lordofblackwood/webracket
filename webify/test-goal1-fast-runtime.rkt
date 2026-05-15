#lang racket/base

(require rackunit
         racket/runtime-path
         racket/system)

(define-runtime-path probe-installed-runtime-smoke-path
  "probe-installed-runtime-smoke.rkt")

;; getenv/default : string? string? -> string?
;;   Read a test-control environment variable with a safe default.
(define (getenv/default name default)
  (or (getenv name) default))

;; current-racket-bin : -> path?
;;   Use the executable running this test to avoid mixing 8.12 and 9.2 zo files.
(define (current-racket-bin)
  (define exec-file (find-system-path 'exec-file))
  (cond
    [(and (path? exec-file) (complete-path? exec-file)) exec-file]
    [(path? exec-file) (path->complete-path exec-file)]
    [else (find-executable-path "racket")]))

;; run-goal1-fast-runtime/bounded : -> exact-integer?
;;   Run the compact Goal 1 runtime suite through the bounded probe wrapper.
(define (run-goal1-fast-runtime/bounded)
  (system*/exit-code
   (current-racket-bin)
   (path->string probe-installed-runtime-smoke-path)
   "--goal1-fast"
   "--timeout" (getenv/default "WEBIFY_GOAL1_FAST_TIMEOUT_SECONDS" "120")
   "--memory-mb" (getenv/default "WEBIFY_GOAL1_FAST_MEMORY_MB" "1024")))

(check-equal? (run-goal1-fast-runtime/bounded) 0)
