#lang racket/base

(require webracket/unsafe/math)

(provide math-abs
         math-acos
         math-acosh
         math-asin
         math-asinh
         math-atan
         math-atan2
         math-atanh
         math-cbrt
         math-ceil
         math-clz32
         math-cos
         math-cosh
         math-exp
         math-expm1
         math-floor
         math-fround
         math-hypot
         math-imul
         math-log
         math-log10
         math-log1p
         math-log2
         math-max
         math-min
         math-pow
         math-random
         math-round
         math-sign
         math-sin
         math-sinh
         math-sqrt
         math-tan
         math-tanh
         math-trunc)

;; Public JavaScript Math wrappers. These names avoid clobbering Racket's own
;; numeric bindings while the raw `js-math-*` layer remains explicitly unsafe.

(define math-abs    js-math-abs)
(define math-acos   js-math-acos)
(define math-acosh  js-math-acosh)
(define math-asin   js-math-asin)
(define math-asinh  js-math-asinh)
(define math-atan   js-math-atan)
(define math-atan2  js-math-atan2)
(define math-atanh  js-math-atanh)
(define math-cbrt   js-math-cbrt)
(define math-ceil   js-math-ceil)
(define math-clz32  js-math-clz32)
(define math-cos    js-math-cos)
(define math-cosh   js-math-cosh)
(define math-exp    js-math-exp)
(define math-expm1  js-math-expm1)
(define math-floor  js-math-floor)
(define math-fround js-math-fround)
(define math-hypot  js-math-hypot)
(define math-imul   js-math-imul)
(define math-log    js-math-log)
(define math-log10  js-math-log10)
(define math-log1p  js-math-log1p)
(define math-log2   js-math-log2)
(define math-max    js-math-max)
(define math-min    js-math-min)
(define math-pow    js-math-pow)
(define math-random js-math-random)
(define math-round  js-math-round)
(define math-sign   js-math-sign)
(define math-sin    js-math-sin)
(define math-sinh   js-math-sinh)
(define math-sqrt   js-math-sqrt)
(define math-tan    js-math-tan)
(define math-tanh   js-math-tanh)
(define math-trunc  js-math-trunc)
