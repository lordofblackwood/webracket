#lang racket/base

(require "ffi-placeholder.rkt")

(provide js-math-abs
         js-math-acos
         js-math-acosh
         js-math-asin
         js-math-asinh
         js-math-atan
         js-math-atan2
         js-math-atanh
         js-math-cbrt
         js-math-ceil
         js-math-clz32
         js-math-cos
         js-math-cosh
         js-math-exp
         js-math-expm1
         js-math-floor
         js-math-fround
         js-math-hypot
         js-math-imul
         js-math-log
         js-math-log10
         js-math-log1p
         js-math-log2
         js-math-max
         js-math-min
         js-math-pow
         js-math-random
         js-math-round
         js-math-sign
         js-math-sin
         js-math-sinh
         js-math-sqrt
         js-math-tan
         js-math-tanh
         js-math-trunc)

;; This module is generated from `ffi/math.ffi` in the same raw/unsafe layer as
;; `webracket/unsafe/console`. The bodies are placeholders until the module
;; bridge can bind `.ffi` imports directly inside provider instances.

(define js-math-abs    (make-unsafe-ffi-placeholder 'js-math-abs 1))
(define js-math-acos   (make-unsafe-ffi-placeholder 'js-math-acos 1))
(define js-math-acosh  (make-unsafe-ffi-placeholder 'js-math-acosh 1))
(define js-math-asin   (make-unsafe-ffi-placeholder 'js-math-asin 1))
(define js-math-asinh  (make-unsafe-ffi-placeholder 'js-math-asinh 1))
(define js-math-atan   (make-unsafe-ffi-placeholder 'js-math-atan 1))
(define js-math-atan2  (make-unsafe-ffi-placeholder 'js-math-atan2 2))
(define js-math-atanh  (make-unsafe-ffi-placeholder 'js-math-atanh 1))
(define js-math-cbrt   (make-unsafe-ffi-placeholder 'js-math-cbrt 1))
(define js-math-ceil   (make-unsafe-ffi-placeholder 'js-math-ceil 1))
(define js-math-clz32  (make-unsafe-ffi-placeholder 'js-math-clz32 1))
(define js-math-cos    (make-unsafe-ffi-placeholder 'js-math-cos 1))
(define js-math-cosh   (make-unsafe-ffi-placeholder 'js-math-cosh 1))
(define js-math-exp    (make-unsafe-ffi-placeholder 'js-math-exp 1))
(define js-math-expm1  (make-unsafe-ffi-placeholder 'js-math-expm1 1))
(define js-math-floor  (make-unsafe-ffi-placeholder 'js-math-floor 1))
(define js-math-fround (make-unsafe-ffi-placeholder 'js-math-fround 1))
(define js-math-hypot  (make-unsafe-ffi-placeholder 'js-math-hypot 2))
(define js-math-imul   (make-unsafe-ffi-placeholder 'js-math-imul 2))
(define js-math-log    (make-unsafe-ffi-placeholder 'js-math-log 1))
(define js-math-log10  (make-unsafe-ffi-placeholder 'js-math-log10 1))
(define js-math-log1p  (make-unsafe-ffi-placeholder 'js-math-log1p 1))
(define js-math-log2   (make-unsafe-ffi-placeholder 'js-math-log2 1))
(define js-math-max    (make-unsafe-ffi-placeholder 'js-math-max 2))
(define js-math-min    (make-unsafe-ffi-placeholder 'js-math-min 2))
(define js-math-pow    (make-unsafe-ffi-placeholder 'js-math-pow 2))
(define js-math-random (make-unsafe-ffi-placeholder 'js-math-random 0))
(define js-math-round  (make-unsafe-ffi-placeholder 'js-math-round 1))
(define js-math-sign   (make-unsafe-ffi-placeholder 'js-math-sign 1))
(define js-math-sin    (make-unsafe-ffi-placeholder 'js-math-sin 1))
(define js-math-sinh   (make-unsafe-ffi-placeholder 'js-math-sinh 1))
(define js-math-sqrt   (make-unsafe-ffi-placeholder 'js-math-sqrt 1))
(define js-math-tan    (make-unsafe-ffi-placeholder 'js-math-tan 1))
(define js-math-tanh   (make-unsafe-ffi-placeholder 'js-math-tanh 1))
(define js-math-trunc  (make-unsafe-ffi-placeholder 'js-math-trunc 1))
