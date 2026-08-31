#lang racket/base

(require racket/contract/base)

(provide readable-stream-supported?
         writable-stream-supported?
         transform-stream-supported?
         streams-supported?
         stream-chunk?
         readable-stream?
         writable-stream?
         transform-stream?
         readable-stream-locked?
         writable-stream-locked?
         make-transform-stream
         transform-stream-readable
         transform-stream-writable
         readable-stream-get-reader
         writable-stream-get-writer
         readable-stream-reader?
         writable-stream-writer?
         readable-stream-reader-read
         readable-stream-reader-release-lock!
         writable-stream-writer-write
         writable-stream-writer-close
         writable-stream-writer-release-lock!
         readable-stream-pipe-through
         readable-stream-pipe-to
         readable-stream-read-result-wrap
         readable-stream-read-result?
         readable-stream-read-result-done?
         readable-stream-read-result-value
         (for-label (all-defined-out)))

(define readable-stream-supported? any/c)
(define writable-stream-supported? any/c)
(define transform-stream-supported? any/c)
(define streams-supported? any/c)
(define stream-chunk? any/c)
(define readable-stream? any/c)
(define writable-stream? any/c)
(define transform-stream? any/c)
(define readable-stream-locked? any/c)
(define writable-stream-locked? any/c)
(define make-transform-stream any/c)
(define transform-stream-readable any/c)
(define transform-stream-writable any/c)
(define readable-stream-get-reader any/c)
(define writable-stream-get-writer any/c)
(define readable-stream-reader? any/c)
(define writable-stream-writer? any/c)
(define readable-stream-reader-read any/c)
(define readable-stream-reader-release-lock! any/c)
(define writable-stream-writer-write any/c)
(define writable-stream-writer-close any/c)
(define writable-stream-writer-release-lock! any/c)
(define readable-stream-pipe-through any/c)
(define readable-stream-pipe-to any/c)
(define readable-stream-read-result-wrap any/c)
(define readable-stream-read-result? any/c)
(define readable-stream-read-result-done? any/c)
(define readable-stream-read-result-value any/c)
