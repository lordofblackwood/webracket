#lang racket/base

(require (only-in "../primitives.rkt" unsafe-ffi-primitive))

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
;; `webracket/unsafe/console`. Each binding aliases an active `.ffi` primitive;
;; compile users with `--ffi math` to make the imports available.

(define js-math-abs    (unsafe-ffi-primitive 'js-math-abs))
(define js-math-acos   (unsafe-ffi-primitive 'js-math-acos))
(define js-math-acosh  (unsafe-ffi-primitive 'js-math-acosh))
(define js-math-asin   (unsafe-ffi-primitive 'js-math-asin))
(define js-math-asinh  (unsafe-ffi-primitive 'js-math-asinh))
(define js-math-atan   (unsafe-ffi-primitive 'js-math-atan))
(define js-math-atan2  (unsafe-ffi-primitive 'js-math-atan2))
(define js-math-atanh  (unsafe-ffi-primitive 'js-math-atanh))
(define js-math-cbrt   (unsafe-ffi-primitive 'js-math-cbrt))
(define js-math-ceil   (unsafe-ffi-primitive 'js-math-ceil))
(define js-math-clz32  (unsafe-ffi-primitive 'js-math-clz32))
(define js-math-cos    (unsafe-ffi-primitive 'js-math-cos))
(define js-math-cosh   (unsafe-ffi-primitive 'js-math-cosh))
(define js-math-exp    (unsafe-ffi-primitive 'js-math-exp))
(define js-math-expm1  (unsafe-ffi-primitive 'js-math-expm1))
(define js-math-floor  (unsafe-ffi-primitive 'js-math-floor))
(define js-math-fround (unsafe-ffi-primitive 'js-math-fround))
(define js-math-hypot  (unsafe-ffi-primitive 'js-math-hypot))
(define js-math-imul   (unsafe-ffi-primitive 'js-math-imul))
(define js-math-log    (unsafe-ffi-primitive 'js-math-log))
(define js-math-log10  (unsafe-ffi-primitive 'js-math-log10))
(define js-math-log1p  (unsafe-ffi-primitive 'js-math-log1p))
(define js-math-log2   (unsafe-ffi-primitive 'js-math-log2))
(define js-math-max    (unsafe-ffi-primitive 'js-math-max))
(define js-math-min    (unsafe-ffi-primitive 'js-math-min))
(define js-math-pow    (unsafe-ffi-primitive 'js-math-pow))
(define js-math-random (unsafe-ffi-primitive 'js-math-random))
(define js-math-round  (unsafe-ffi-primitive 'js-math-round))
(define js-math-sign   (unsafe-ffi-primitive 'js-math-sign))
(define js-math-sin    (unsafe-ffi-primitive 'js-math-sin))
(define js-math-sinh   (unsafe-ffi-primitive 'js-math-sinh))
(define js-math-sqrt   (unsafe-ffi-primitive 'js-math-sqrt))
(define js-math-tan    (unsafe-ffi-primitive 'js-math-tan))
(define js-math-tanh   (unsafe-ffi-primitive 'js-math-tanh))
(define js-math-trunc  (unsafe-ffi-primitive 'js-math-trunc))
