#lang racket/base

;; Provider root for the first isolated `expander/read` syntax-aware staging
;; probe. Do not publish public `read-syntax` from this root yet; it is here so
;; the demodularizer can reveal the minimal syntax/namespace dependency chain.

(require (prefix-in raw: "read/api.rkt"))

(define webify-expander-read-syntax raw:read-syntax)
(define webify-expander-read-syntax/recursive raw:read-syntax/recursive)

(provide webify-expander-read-syntax
         webify-expander-read-syntax/recursive)
