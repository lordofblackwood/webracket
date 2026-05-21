#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/math))

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

(define math-abs    unsafe:js-math-abs)
(define math-acos   unsafe:js-math-acos)
(define math-acosh  unsafe:js-math-acosh)
(define math-asin   unsafe:js-math-asin)
(define math-asinh  unsafe:js-math-asinh)
(define math-atan   unsafe:js-math-atan)
(define math-atan2  unsafe:js-math-atan2)
(define math-atanh  unsafe:js-math-atanh)
(define math-cbrt   unsafe:js-math-cbrt)
(define math-ceil   unsafe:js-math-ceil)
(define math-clz32  unsafe:js-math-clz32)
(define math-cos    unsafe:js-math-cos)
(define math-cosh   unsafe:js-math-cosh)
(define math-exp    unsafe:js-math-exp)
(define math-expm1  unsafe:js-math-expm1)
(define math-floor  unsafe:js-math-floor)
(define math-fround unsafe:js-math-fround)
(define math-hypot  unsafe:js-math-hypot)
(define math-imul   unsafe:js-math-imul)
(define math-log    unsafe:js-math-log)
(define math-log10  unsafe:js-math-log10)
(define math-log1p  unsafe:js-math-log1p)
(define math-log2   unsafe:js-math-log2)
(define math-max    unsafe:js-math-max)
(define math-min    unsafe:js-math-min)
(define math-pow    unsafe:js-math-pow)
(define math-random unsafe:js-math-random)
(define math-round  unsafe:js-math-round)
(define math-sign   unsafe:js-math-sign)
(define math-sin    unsafe:js-math-sin)
(define math-sinh   unsafe:js-math-sinh)
(define math-sqrt   unsafe:js-math-sqrt)
(define math-tan    unsafe:js-math-tan)
(define math-tanh   unsafe:js-math-tanh)
(define math-trunc  unsafe:js-math-trunc)
