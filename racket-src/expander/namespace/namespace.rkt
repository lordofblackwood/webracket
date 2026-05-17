#lang racket/base

(require "registry.rkt")

(provide make-namespace
         namespace?
         current-namespace
         namespace-module-registry
         namespace-root-namespace)

(struct namespace (module-registry root-namespace)
  #:authentic)

(define (make-namespace)
  (namespace (make-module-registry) #f))

(define current-namespace
  (make-parameter
   (make-namespace)
   (lambda (v)
     (unless (namespace? v)
       (raise-argument-error 'current-namespace "namespace?" v))
     v)
   'current-namespace))
