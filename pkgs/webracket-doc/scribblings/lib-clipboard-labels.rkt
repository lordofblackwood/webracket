#lang racket/base

(require racket/contract/base)

;; Docs-only fake bindings for the public clipboard wrapper library.

(provide
  clipboard
  clipboard-raw
  clipboard?
  clipboard-supported?
  clipboard-read-text
  clipboard-write-text!
  (for-label (all-defined-out)))

(define clipboard any/c)
(define clipboard-raw any/c)
(define clipboard? any/c)
(define clipboard-supported? any/c)
(define clipboard-read-text any/c)
(define clipboard-write-text! any/c)
