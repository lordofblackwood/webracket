#lang racket/base

(require racket/list
         racket/runtime-path
         rackunit
         "../webify/test-module-support.rkt")

(define-runtime-path repo-root "..")

;; read-single-datum : string? string? -> any/c
;;   Read the one result tree that a no-stdlib test program prints.
(define (read-single-datum output)
  (define in (open-input-string output))
  (define datum (read in))
  (check-false (eof-object? datum) "test program should print one result datum")
  (define trailing (read in))
  (check-true (eof-object? trailing)
              "test program should not print extra data after the result datum")
  datum)

;; false-leaf-paths : any/c -> (listof (listof any/c))
;;   Find false leaves in the nested test-basics result tree.
(define (false-leaf-paths datum)
  (let loop ([v datum] [path '()])
    (cond
      [(eq? v #f) (list (reverse path))]
      [(pair? v)
       (append* (for/list ([child (in-list v)]
                           [index (in-naturals)])
                  (loop child (cons index path))))]
      [(vector? v)
       (append* (for/list ([child (in-vector v)]
                           [index (in-naturals)])
                  (loop child (cons index path))))]
      [else '()])))

(define (check-no-stdlib-result-tree test-path #:timeout-seconds [timeout-seconds 180])
  (define-values (status output)
    (run-webracket (list "--no-stdlib"
                         "--internal-bind-immutable-hash-debug-shape"
                         "-r"
                         test-path)
                   repo-root
                   #:timeout-seconds timeout-seconds
                   #:memory-mb 4096))
  (check-equal? status 0 output)
  (define datum (read-single-datum output))
  (define failures (false-leaf-paths datum))
  (check-equal? (length failures)
                0
                (format "~a false leaves at result-tree paths: ~s"
                        test-path
                        failures)))

(test-case "test-basics has no false leaves"
  (check-no-stdlib-result-tree "test/test-basics.rkt"))

(test-case "test-hash has no false leaves"
  (check-no-stdlib-result-tree "test/test-hash.rkt"
                               #:timeout-seconds 120))

(module+ main
  (void))
