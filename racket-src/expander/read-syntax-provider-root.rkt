#lang racket/base

;; Provider root for the first isolated `expander/read` syntax-aware staging
;; probe. Do not publish public `read-syntax` from this root yet; it is here so
;; the demodularizer can reveal the minimal syntax/namespace dependency chain.

(require (prefix-in raw: "read/api.rkt")
         (prefix-in srcloc: "syntax/srcloc.rkt")
         (prefix-in syntax: "syntax/syntax.rkt"))

(define webify-expander-read-syntax raw:read-syntax)
(define webify-expander-read-syntax/recursive raw:read-syntax/recursive)
(define webify-expander-syntax->datum syntax:syntax->datum)
(define webify-expander-syntax-source srcloc:syntax-source)
(define webify-expander-syntax-line srcloc:syntax-line)
(define webify-expander-syntax-column srcloc:syntax-column)
(define webify-expander-syntax-position srcloc:syntax-position)

(provide webify-expander-read-syntax
         webify-expander-read-syntax/recursive
         webify-expander-syntax->datum
         webify-expander-syntax-source
         webify-expander-syntax-line
         webify-expander-syntax-column
         webify-expander-syntax-position)
