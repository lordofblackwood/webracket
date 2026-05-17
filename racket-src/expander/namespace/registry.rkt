#lang racket/base

(provide (struct-out module-registry)
         make-module-registry
         registry-call-with-lock)

(struct module-registry (declarations)
  #:authentic)

(define (make-module-registry)
  (module-registry (make-hasheq)))

(define (registry-call-with-lock r proc)
  (proc))
