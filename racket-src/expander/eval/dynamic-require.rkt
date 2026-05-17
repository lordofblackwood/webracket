#lang racket/base

(provide dynamic-require
         dynamic-require-for-syntax)

;; The read-syntax slice only needs this module for reader-extension hooks such
;; as `#reader`. Goal 1 does not support browser-side namespace/eval services,
;; so keep the dependency private and fail precisely if an extension path tries
;; to cross into dynamic module loading.

(define (unsupported who)
  (error who "reader-extension dynamic require is unsupported"))

(define (dynamic-require mod-path sym [fail-k 'error] [syntax-k 'eval])
  (unsupported 'dynamic-require))

(define (dynamic-require-for-syntax mod-path sym [fail-k 'error] [syntax-k 'eval])
  (unsupported 'dynamic-require-for-syntax))
