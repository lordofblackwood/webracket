#lang racket/base

(require racket/list
         racket/runtime-path
         rackunit
         "../webify/test-module-support.rkt")

(define-runtime-path repo-root "..")

;; read-single-datum : string? -> any/c
;;   Read the one result tree that test-basics prints.
(define (read-single-datum output)
  (define in (open-input-string output))
  (define datum (read in))
  (check-false (eof-object? datum) "test-basics should print one result datum")
  (define trailing (read in))
  (check-true (eof-object? trailing)
              "test-basics should not print extra data after the result datum")
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

(test-case "test-basics has no false leaves"
  (define-values (status output)
    (run-webracket (list "--no-stdlib" "-r" "test/test-basics.rkt")
                   repo-root))
  (check-equal? status 0 output)
  (define datum (read-single-datum output))
  (define failures (false-leaf-paths datum))
  (check-equal? (length failures)
                0
                (format "false leaves at result-tree paths: ~s" failures)))

(module+ main
  (void))
