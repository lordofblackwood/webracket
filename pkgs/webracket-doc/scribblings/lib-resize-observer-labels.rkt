#lang racket/base

(require racket/contract/base)

(provide
  resize-observer
  resize-observer-raw
  resize-observer?
  resize-observer-supported?
  make-resize-observer-options
  resize-observer-options?
  resize-observer-options-box
  make-resize-observer
  resize-observer-observe!
  resize-observer-unobserve!
  resize-observer-disconnect!
  resize-observer-entry
  resize-observer-entry?
  resize-observer-entry-raw
  resize-observer-entry-target
  resize-observer-entry-content-rect
  (for-label (all-defined-out)))

(define resize-observer any/c)
(define resize-observer-raw any/c)
(define resize-observer? any/c)
(define resize-observer-supported? any/c)
(define make-resize-observer-options any/c)
(define resize-observer-options? any/c)
(define resize-observer-options-box any/c)
(define make-resize-observer any/c)
(define resize-observer-observe! any/c)
(define resize-observer-unobserve! any/c)
(define resize-observer-disconnect! any/c)
(struct resize-observer-entry (raw) #:transparent)
(define resize-observer-entry-target any/c)
(define resize-observer-entry-content-rect any/c)
