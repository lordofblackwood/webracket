#lang racket

(provide i31-ref
         immediate-ref
         false-ref
         true-ref)

(require "../../private/immediates.rkt")

;; i31-ref : integer? -> datum?
;;   Return WAT that injects bits into an i31 reference.
(define (i31-ref bits)
  `(ref.i31 (i32.const ,bits)))

;; immediate-ref : any/c -> datum?
;;   Return WAT that represents a WebRacket immediate value.
(define (immediate-ref v)
  (i31-ref (immediate-rep v)))

;; false-ref : datum?
;;   Return the WebRacket false immediate expression.
(define false-ref (immediate-ref #f))

;; true-ref : datum?
;;   Return the WebRacket true immediate expression.
(define true-ref (immediate-ref #t))
