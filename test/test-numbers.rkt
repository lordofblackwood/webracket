#lang racket/base

(require rackunit
         "numbers/cases.rkt")

(test-case "number port sources are registered"
  (check-not-false (assoc 'racket-number
                          (map (lambda (s)
                                 (cons (number-port-source-id s) s))
                               number-port-sources)))
  (check-not-false (assoc 'racket-fixnum
                          (map (lambda (s)
                                 (cons (number-port-source-id s) s))
                               number-port-sources)))
  (check-not-false (assoc 'racket-flonum
                          (map (lambda (s)
                                 (cons (number-port-source-id s) s))
                               number-port-sources))))

(test-case "number ports include current gated oracle corpus"
  (define gate-cases
    (select-number-port-cases))
  (check-not-equal? gate-cases '())
  (check-true
   (for/and ([c (in-list gate-cases)])
     (number-port-case-gate? c))))

(test-case "generated upstream accounting is loaded"
  (define generated
    (select-number-port-cases #:sources '(racket-number)
                              #:include-non-gates? #t))
  (check-true (list? generated))
  (check-true (list? (select-number-port-skips))))

(module+ main
  (void))
