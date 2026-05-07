#lang racket/base

(provide webify-module-protocol-name
         webify-module-protocol-linklet
         webify-module-protocol-report
         webify-module-protocol-input
         webify-module-protocol-dependency)

(require "module-extractor.rkt"
         "module-input.rkt")

;; webify-module-protocol-name : symbol?
;;   The synthetic provider name used for Racket's module-linklet protocol imports.
(define webify-module-protocol-name 'module-protocol)

;; webify-module-protocol-linklet : linklet-datum?
;;   Minimal runtime provider for protocol imports seen in compiled module linklets.
(define webify-module-protocol-linklet
  '(linklet () (.get-syntax-literal! .set-transformer!)
     (define-values (.get-syntax-literal!)
       (lambda args
         (error '.get-syntax-literal!
                "syntax literals are not supported by WebRacket module protocol yet")))
     (define-values (.set-transformer!)
       (lambda args (void)))))

;; webify-module-protocol-report : webify-module-report?
;;   Expose the protocol provider through the stable extractor report shape.
(define webify-module-protocol-report
  (webify-module-report
   webify-module-protocol-name
   '(#f)
   '(0)
   '()
   '()
   '(.get-syntax-literal! .set-transformer!)
   webify-module-protocol-linklet
   #t
   '("synthetic Webify module protocol provider"
     ".get-syntax-literal! is fail-fast because syntax/source-location literals are not implemented"
     ".set-transformer! is a runtime no-op in the current bridge")))

;; webify-module-protocol-input : webify-module-linklet-input?
;;   Expose the protocol provider through the registry input shape.
(define webify-module-protocol-input
  (webify-module-linklet-input
   webify-module-protocol-name
   webify-module-protocol-linklet
   '()))

;; webify-module-protocol-dependency : symbol?
;;   Convenience value for #:module-protocol-dependency.
(define webify-module-protocol-dependency webify-module-protocol-name)
