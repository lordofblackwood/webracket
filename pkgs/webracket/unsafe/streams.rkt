#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-readable-stream-supported?
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
 js-writable-stream-default-writer-release-lock!)

;; js-readable-stream-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-supported? (unsafe-ffi-primitive 'js-readable-stream-supported?))

;; js-writable-stream-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-supported? (unsafe-ffi-primitive 'js-writable-stream-supported?))

;; js-transform-stream-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-transform-stream-supported? (unsafe-ffi-primitive 'js-transform-stream-supported?))

;; js-readable-stream? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream? (unsafe-ffi-primitive 'js-readable-stream?))

;; js-writable-stream? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream? (unsafe-ffi-primitive 'js-writable-stream?))

;; js-transform-stream? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-transform-stream? (unsafe-ffi-primitive 'js-transform-stream?))

;; js-readable-stream-default-reader? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-default-reader? (unsafe-ffi-primitive 'js-readable-stream-default-reader?))

;; js-writable-stream-default-writer? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-default-writer? (unsafe-ffi-primitive 'js-writable-stream-default-writer?))

;; js-readable-stream-read-result? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-read-result? (unsafe-ffi-primitive 'js-readable-stream-read-result?))

;; js-transform-stream-new : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-transform-stream-new (unsafe-ffi-primitive 'js-transform-stream-new))

;; js-transform-stream-readable : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-transform-stream-readable (unsafe-ffi-primitive 'js-transform-stream-readable))

;; js-transform-stream-writable : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-transform-stream-writable (unsafe-ffi-primitive 'js-transform-stream-writable))

;; js-readable-stream-locked? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-locked? (unsafe-ffi-primitive 'js-readable-stream-locked?))

;; js-readable-stream-get-reader : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-get-reader (unsafe-ffi-primitive 'js-readable-stream-get-reader))

;; js-readable-stream-pipe-through : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-pipe-through (unsafe-ffi-primitive 'js-readable-stream-pipe-through))

;; js-readable-stream-pipe-to : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-pipe-to (unsafe-ffi-primitive 'js-readable-stream-pipe-to))

;; js-readable-stream-default-reader-read : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-default-reader-read (unsafe-ffi-primitive 'js-readable-stream-default-reader-read))

;; js-readable-stream-default-reader-release-lock! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-default-reader-release-lock! (unsafe-ffi-primitive 'js-readable-stream-default-reader-release-lock!))

;; js-readable-stream-read-result-done? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-read-result-done? (unsafe-ffi-primitive 'js-readable-stream-read-result-done?))

;; js-readable-stream-read-result-value : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-readable-stream-read-result-value (unsafe-ffi-primitive 'js-readable-stream-read-result-value))

;; js-writable-stream-locked? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-locked? (unsafe-ffi-primitive 'js-writable-stream-locked?))

;; js-writable-stream-get-writer : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-get-writer (unsafe-ffi-primitive 'js-writable-stream-get-writer))

;; js-writable-stream-default-writer-write : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-default-writer-write (unsafe-ffi-primitive 'js-writable-stream-default-writer-write))

;; js-writable-stream-default-writer-close : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-default-writer-close (unsafe-ffi-primitive 'js-writable-stream-default-writer-close))

;; js-writable-stream-default-writer-release-lock! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/streams.
(define js-writable-stream-default-writer-release-lock! (unsafe-ffi-primitive 'js-writable-stream-default-writer-release-lock!))
