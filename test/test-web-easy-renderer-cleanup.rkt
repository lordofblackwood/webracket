#lang racket/base

(require rackunit
         web-easy/private/dom-like)

;; observer-count : observable? -> exact-nonnegative-integer?
;;   Inspect the transparent observable struct for renderer lifecycle tests.
(define (observer-count o)
  (length (vector-ref (struct->vector o) 4)))

(define @outer (obs 'shown))
(define @inner (obs "inner"))

(define dynamic-child
  (view 'observable-element-children
        (list (cons 'tag 'div)
              (cons 'data @outer)
              (cons 'make-children
                    (lambda (state)
                      (if (eq? state 'shown)
                          (list (view 'raw-text
                                      (list (cons 'value @inner))
                                      '()))
                          (list (view 'raw-text
                                      (list (cons 'value "gone"))
                                      '())))))
              (cons 'equal-proc equal?)
              (cons 'after-render #f))
        '()))

(define r
  (render (window dynamic-child)))

(check-equal? (observer-count @inner) 1)
(obs-set! @outer 'hidden)
(check-equal? (observer-count @inner) 0)
(renderer-destroy r)
(check-equal? (observer-count @outer) 0)
