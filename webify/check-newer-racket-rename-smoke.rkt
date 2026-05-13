#lang racket/base

(require rackunit
         racket/list
         "module-extractor-spike.rkt"
         "module-input.rkt")

;; This smoke is intended for the newer ../racket checkout, where
;; current-compile-target-machine #f exposes a decompilable phase-0 linklet.

(define module-datum
  '(module a racket/base
     (require (rename-in racket/list [first head]))
     (provide y)
     (define y (head (list 10)))))

(define report (webify-compile-module-extractor-spike module-datum))

(unless (webify-module-extractor-spike-manifest-ready? report)
  (error 'check-newer-racket-rename-smoke
         "source module did not produce a decompilable phase-0 linklet datum; notes: ~s"
         (webify-module-extractor-spike-notes report)))

(define input
  (webify-source-module->resolved-linklet-input
   module-datum
   #:dependency-exports '((racket/list (first)))
   #:module-protocol-dependency 'module-protocol))

(check-equal? (drop (webify-module-linklet-input-imports input) 2)
              '((first racket/list first)))

(displayln "newer-racket-rename-smoke: ok")
