#lang racket

(provide core-runtime-helpers
         core-runtime-helper-index
         generate-core-runtime)

(require "core-helper.rkt"
         "core/fixnums.rkt"
         "shared-types.rkt")

;; core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate the functions currently shared between monolithic and core runtime trees.
(define core-runtime-helpers
  (append
   fixnum-core-runtime-helpers))

;; core-runtime-helper-index : hasheq?
;;   Index core runtime helpers by Wasm function name.
(define core-runtime-helper-index
  (make-core-runtime-helper-index core-runtime-helpers))

;; generate-core-runtime : -> datum?
;;   Build the standalone core runtime module tree used by split-runtime experiments.
(define (generate-core-runtime)
  `(module
     ,@(generate-shared-types)
     ,@(core-runtime-helper-forms core-runtime-helpers #:export? #t)))
