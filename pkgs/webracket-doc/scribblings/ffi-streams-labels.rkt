#lang racket/base

(require racket/contract/base)

;; Docs-only fake bindings for raw FFI Scribble links.
(provide js-readable-stream-supported?
         js-writable-stream-supported?
         js-transform-stream-supported?
         js-readable-stream?
         js-writable-stream?
         js-transform-stream?
         js-readable-stream-default-reader?
         js-writable-stream-default-writer?
         js-readable-stream-read-result?
         js-transform-stream-new
         js-transform-stream-readable
         js-transform-stream-writable
         js-readable-stream-locked?
         js-readable-stream-get-reader
         js-readable-stream-pipe-through
         js-readable-stream-pipe-to
         js-readable-stream-default-reader-read
         js-readable-stream-default-reader-release-lock!
         js-readable-stream-read-result-done?
         js-readable-stream-read-result-value
         js-writable-stream-locked?
         js-writable-stream-get-writer
         js-writable-stream-default-writer-write
         js-writable-stream-default-writer-close
         js-writable-stream-default-writer-release-lock!
         (for-label (all-defined-out)))

(define js-readable-stream-supported? any/c)
(define js-writable-stream-supported? any/c)
(define js-transform-stream-supported? any/c)
(define js-readable-stream? any/c)
(define js-writable-stream? any/c)
(define js-transform-stream? any/c)
(define js-readable-stream-default-reader? any/c)
(define js-writable-stream-default-writer? any/c)
(define js-readable-stream-read-result? any/c)
(define js-transform-stream-new any/c)
(define js-transform-stream-readable any/c)
(define js-transform-stream-writable any/c)
(define js-readable-stream-locked? any/c)
(define js-readable-stream-get-reader any/c)
(define js-readable-stream-pipe-through any/c)
(define js-readable-stream-pipe-to any/c)
(define js-readable-stream-default-reader-read any/c)
(define js-readable-stream-default-reader-release-lock! any/c)
(define js-readable-stream-read-result-done? any/c)
(define js-readable-stream-read-result-value any/c)
(define js-writable-stream-locked? any/c)
(define js-writable-stream-get-writer any/c)
(define js-writable-stream-default-writer-write any/c)
(define js-writable-stream-default-writer-close any/c)
(define js-writable-stream-default-writer-release-lock! any/c)
