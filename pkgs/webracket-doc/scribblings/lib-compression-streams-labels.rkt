#lang racket/base

(require racket/contract/base)

(provide compression-stream-supported?
         decompression-stream-supported?
         compression-stream?
         compression-stream-raw
         decompression-stream?
         decompression-stream-raw
         compression-format?
         make-compression-stream
         make-decompression-stream
         compression-stream-readable
         compression-stream-writable
         decompression-stream-readable
         decompression-stream-writable
         readable-stream-pipe-through-compression
         readable-stream-pipe-through-decompression
         (struct-out compression-stream-info)
         (struct-out decompression-stream-info)
         (for-label (all-defined-out)))

(define compression-stream-supported? any/c)
(define decompression-stream-supported? any/c)
(define compression-stream? any/c)
(define compression-stream-raw any/c)
(define decompression-stream? any/c)
(define decompression-stream-raw any/c)
(define compression-format? any/c)
(define make-compression-stream any/c)
(define make-decompression-stream any/c)
(define compression-stream-readable any/c)
(define compression-stream-writable any/c)
(define decompression-stream-readable any/c)
(define decompression-stream-writable any/c)
(define readable-stream-pipe-through-compression any/c)
(define readable-stream-pipe-through-decompression any/c)
(struct compression-stream-info (raw) #:transparent)
(struct decompression-stream-info (raw) #:transparent)
