#lang racket/base

(require racket/contract/base)

(provide file-system-open-picker-supported?
         file-system-save-picker-supported?
         file-system-directory-picker-supported?
         file-system-origin-private-supported?
         file-system-supported?
         file-system-name?
         file-system-write-data?
         file-system-byte-count?
         file-system-file-handle?
         file-system-directory-handle?
         file-system-writable-file-stream?
         file-system-file?
         file-system-file-handle-wrap
         file-system-directory-handle-wrap
         file-system-writable-file-stream-wrap
         file-system-file-wrap
         file-system-pick-open-file
         file-system-pick-save-file
         file-system-pick-directory
         file-system-origin-private-directory
         file-system-file-handle-name
         file-system-directory-handle-name
         file-system-file-handle-get-file
         file-system-file-handle-create-writable
         file-system-directory-get-file-handle
         file-system-directory-get-directory-handle
         file-system-directory-remove-entry!
         file-system-file-name
         file-system-file-size
         file-system-file-type
         file-system-file-last-modified
         file-system-file-text
         file-system-writable-file-stream-write
         file-system-writable-file-stream-seek
         file-system-writable-file-stream-truncate
         file-system-writable-file-stream-close
         (for-label (all-defined-out)))

(define file-system-open-picker-supported? any/c)
(define file-system-save-picker-supported? any/c)
(define file-system-directory-picker-supported? any/c)
(define file-system-origin-private-supported? any/c)
(define file-system-supported? any/c)
(define file-system-name? any/c)
(define file-system-write-data? any/c)
(define file-system-byte-count? any/c)
(define file-system-file-handle? any/c)
(define file-system-directory-handle? any/c)
(define file-system-writable-file-stream? any/c)
(define file-system-file? any/c)
(define file-system-file-handle-wrap any/c)
(define file-system-directory-handle-wrap any/c)
(define file-system-writable-file-stream-wrap any/c)
(define file-system-file-wrap any/c)
(define file-system-pick-open-file any/c)
(define file-system-pick-save-file any/c)
(define file-system-pick-directory any/c)
(define file-system-origin-private-directory any/c)
(define file-system-file-handle-name any/c)
(define file-system-directory-handle-name any/c)
(define file-system-file-handle-get-file any/c)
(define file-system-file-handle-create-writable any/c)
(define file-system-directory-get-file-handle any/c)
(define file-system-directory-get-directory-handle any/c)
(define file-system-directory-remove-entry! any/c)
(define file-system-file-name any/c)
(define file-system-file-size any/c)
(define file-system-file-type any/c)
(define file-system-file-last-modified any/c)
(define file-system-file-text any/c)
(define file-system-writable-file-stream-write any/c)
(define file-system-writable-file-stream-seek any/c)
(define file-system-writable-file-stream-truncate any/c)
(define file-system-writable-file-stream-close any/c)
