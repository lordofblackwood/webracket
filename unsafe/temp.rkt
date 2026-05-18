#lang racket/base

(require (only-in "../primitives.rkt" unsafe-ffi-primitive))

(provide js-temp-x
         js-temp-set-x!)

;; This module is generated from `ffi/temp.ffi`. The bindings are raw and
;; unsafe; public code should prefer `js/temp`.

(define js-temp-x      (unsafe-ffi-primitive 'js-temp-x))
(define js-temp-set-x! (unsafe-ffi-primitive 'js-temp-set-x!))
