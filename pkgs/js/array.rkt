#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/array))

(provide array->bytes
         array->vector
         array-at
         array-from
         array-join
         array-length
         array-of
         array-push
         array-ref
         array-set-length!)

;; Public wrappers for JavaScript Array operations. The raw aggregate
;; `array.ffi` surface also includes standard/low-level helpers; keep those in
;; `webracket/unsafe/array` unless a public wrapper is deliberately chosen.

(define array-from unsafe:js-array-from)
(define array-of unsafe:js-array-of)
(define array->vector unsafe:js-array->vector)
(define array->bytes unsafe:js-array->bytes)
(define array-length unsafe:js-array-length)
(define array-set-length! unsafe:js-set-array-length!)
(define array-ref unsafe:js-array-ref)
(define array-at unsafe:js-array-at)
(define array-join unsafe:js-array-join)
(define array-push unsafe:js-array-push)
