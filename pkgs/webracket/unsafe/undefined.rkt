#lang racket/base

(require (only-in webracket/core unsafe-undefined))

(provide check-not-unsafe-undefined
         check-not-unsafe-undefined/assign
         unsafe-undefined
         prop:chaperone-unsafe-undefined
         chaperone-struct-unsafe-undefined)

(define-values (prop:chaperone-unsafe-undefined
                prop:chaperone-unsafe-undefined?
                prop:chaperone-unsafe-undefined-ref)
  (make-struct-type-property 'chaperone-unsafe-undefined))

;; raise-unsafe-undefined : symbol? symbol? string? -> any/c
;;   Report a use of Racket's internal unsafe-undefined placeholder.
(define (raise-unsafe-undefined who sym detail)
  (error who "~a: ~a" sym detail))

;; check-not-unsafe-undefined : any/c symbol? -> any/c
;;   Return v unless it is the internal unsafe-undefined placeholder.
(define (check-not-unsafe-undefined v sym)
  (if (eq? v unsafe-undefined)
      (raise-unsafe-undefined 'check-not-unsafe-undefined
                              sym
                              "undefined; use before initialization")
      v))

;; check-not-unsafe-undefined/assign : any/c symbol? -> any/c
;;   Return v unless it is the internal unsafe-undefined placeholder.
(define (check-not-unsafe-undefined/assign v sym)
  (if (eq? v unsafe-undefined)
      (raise-unsafe-undefined 'check-not-unsafe-undefined/assign
                              sym
                              "undefined; assignment before initialization")
      v))

;; chaperone-struct-unsafe-undefined : any/c -> any/c
;;   Preserve identity until WebRacket has real struct chaperone wrappers.
(define (chaperone-struct-unsafe-undefined v)
  v)
