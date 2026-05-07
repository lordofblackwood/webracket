#lang racket/base

(require rackunit
         "faslable-linklet.rkt")

(define make-faslable-correlated-linklet
  (dynamic-require 'compiler/faslable-correlated
                   'faslable-correlated-linklet
                   (lambda () #f)))
(define make-faslable-correlated
  (dynamic-require 'compiler/faslable-correlated
                   'faslable-correlated
                   (lambda () #f)))

(test-case "faslable adapter extracts synthetic linklet datum"
  (cond
    [(and make-faslable-correlated-linklet make-faslable-correlated)
     (define wrapped-body
       (make-faslable-correlated
        '(define-values (x) 1)
        #f
        1
        1
        0
        1
        '#hasheq()))
     (define linklet
       (make-faslable-correlated-linklet
        `(linklet () (x) ,wrapped-body)
        'module))
     (check-true (webify-faslable-correlated-available?))
     (check-true (webify-faslable-correlated-linklet? linklet))
     (check-equal? (webify-faslable-correlated-linklet->datum linklet)
                   '(linklet () (x)
                      (define-values (x) 1)))]
    [else
     (check-false (webify-faslable-correlated-available?))]))

(module+ main
  (void))
