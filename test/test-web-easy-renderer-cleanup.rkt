#lang racket/base

(require rackunit
         web-easy/private/dom-like)

;; observer-count : observable? -> exact-nonnegative-integer?
;;   Inspect the transparent observable struct for renderer lifecycle tests.
(define (observer-count o)
  (length (vector-ref (struct->vector o) 4)))

(define @outer (obs 'shown))
(define @inner (obs "inner"))

(define r
  (render
   (window
    (observable-view
     @outer
     (lambda (state)
       (if (eq? state 'shown)
           (text @inner)
           (text "gone")))))))

(check-equal? (observer-count @inner) 1)
(obs-set! @outer 'hidden)
(check-equal? (observer-count @inner) 0)
(renderer-destroy r)
(check-equal? (observer-count @outer) 0)
