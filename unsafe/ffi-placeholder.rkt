#lang racket/base

(provide make-unsafe-ffi-placeholder)

;; make-unsafe-ffi-placeholder : symbol? exact-nonnegative-integer? -> procedure?
;;   Create a raw FFI placeholder for modules that are generated before direct imports.
(define (make-unsafe-ffi-placeholder name arity)
  (lambda args
    (unless (= (length args) arity)
      (raise-arity-error name arity args))
    (error name
           "unsafe FFI binding is declared but not yet backed by a direct module import")))
