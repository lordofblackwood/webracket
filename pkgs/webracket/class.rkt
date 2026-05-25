#lang racket/base

(require racket/private/class-internal)

;; A Goal 1 class provider that keeps Racket's class implementation while
;; avoiding the public `racket/class` contract wrapper graph.

(define (make-erased-class-contract name args)
  (cons name args))

(define (class/c . args)
  (make-erased-class-contract 'class/c args))

(define (->m . args)
  (make-erased-class-contract '->m args))

(define (->*m . args)
  (make-erased-class-contract '->*m args))

(define (->dm . args)
  (make-erased-class-contract '->dm args))

(define (case->m . args)
  (make-erased-class-contract 'case->m args))

(define (object/c . args)
  (make-erased-class-contract 'object/c args))

(define (instanceof/c . args)
  (make-erased-class-contract 'instanceof/c args))

(define (dynamic-object/c . args)
  (make-erased-class-contract 'dynamic-object/c args))

(provide-public-names)
