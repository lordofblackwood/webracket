#lang racket/base

(provide unsafe-ffi-primitive)

;; unsafe-ffi-primitive : symbol? -> procedure?
;;   Host-side placeholder for raw FFI bindings; WebRacket replaces this call
;;   with an active runtime primitive during compilation.
(define (unsafe-ffi-primitive name)
  (lambda args
    (error name
           "unsafe FFI primitive placeholder is only executable after WebRacket compilation")))
