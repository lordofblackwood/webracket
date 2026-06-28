#lang racket/base

(require racket/contract/base)

(provide
  intersection-observer
  intersection-observer-raw
  intersection-observer?
  intersection-observer-supported?
  make-intersection-observer-options
  intersection-observer-options?
  intersection-observer-options-root
  intersection-observer-options-root-margin
  intersection-observer-options-threshold
  make-intersection-observer
  intersection-observer-observe!
  intersection-observer-unobserve!
  intersection-observer-disconnect!
  intersection-observer-entry
  intersection-observer-entry?
  intersection-observer-entry-raw
  intersection-observer-entry-target
  intersection-observer-entry-is-intersecting?
  intersection-observer-entry-intersection-ratio
  intersection-observer-entry-bounding-client-rect
  intersection-observer-entry-intersection-rect
  intersection-observer-entry-root-bounds
  intersection-observer-entry-time
  (for-label (all-defined-out)))

(define intersection-observer any/c)
(define intersection-observer-raw any/c)
(define intersection-observer? any/c)
(define intersection-observer-supported? any/c)
(define make-intersection-observer-options any/c)
(define intersection-observer-options? any/c)
(define intersection-observer-options-root any/c)
(define intersection-observer-options-root-margin any/c)
(define intersection-observer-options-threshold any/c)
(define make-intersection-observer any/c)
(define intersection-observer-observe! any/c)
(define intersection-observer-unobserve! any/c)
(define intersection-observer-disconnect! any/c)
(struct intersection-observer-entry (raw) #:transparent)
(define intersection-observer-entry-target any/c)
(define intersection-observer-entry-is-intersecting? any/c)
(define intersection-observer-entry-intersection-ratio any/c)
(define intersection-observer-entry-bounding-client-rect any/c)
(define intersection-observer-entry-intersection-rect any/c)
(define intersection-observer-entry-root-bounds any/c)
(define intersection-observer-entry-time any/c)
