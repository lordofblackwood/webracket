#lang webracket/base

(require (only-in webracket/unsafe/dom
                  js-constructible?
                  js-new
                  js-nullish?
                  js-ref/extern
                  js-send/extern
                  js-typeof
                  js-var)
         (only-in webracket/primitives
                  external?))

(provide (all-defined-out))

;;;
;;; Compression Streams wrappers
;;;

;; compression-stream-info : external/raw -> compression-stream-info?
;;   Wrap a browser CompressionStream object.
(struct compression-stream-info (raw) #:transparent)

;; decompression-stream-info : external/raw -> decompression-stream-info?
;;   Wrap a browser DecompressionStream object.
(struct decompression-stream-info (raw) #:transparent)

;; compression-stream-raw : compression-stream-info? -> external/raw
;;   Extract the raw CompressionStream object.
(define (compression-stream-raw value)
  (compression-stream-info-raw value))

;; decompression-stream-raw : decompression-stream-info? -> external/raw
;;   Extract the raw DecompressionStream object.
(define (decompression-stream-raw value)
  (decompression-stream-info-raw value))

;; compression-stream-constructor-present? : string? -> boolean?
;;   Report whether a stream constructor exists.
(define (compression-stream-constructor-present? name)
  (js-constructible? (js-var name)))

;; compression-stream-supported? : -> boolean?
;;   Report whether CompressionStream is available.
(define (compression-stream-supported?)
  (compression-stream-constructor-present? "CompressionStream"))

;; decompression-stream-supported? : -> boolean?
;;   Report whether DecompressionStream is available.
(define (decompression-stream-supported?)
  (compression-stream-constructor-present? "DecompressionStream"))

;; compression-stream-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable stream method.
(define (compression-stream-host-method-present? raw method-name)
  (and (compression-stream-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; compression-stream-host-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish stream property.
(define (compression-stream-host-property-present? raw property-name)
  (and (compression-stream-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; compression-stream-core-surface-present? : external/raw -> boolean?
;;   Report whether raw has the required CompressionStream surface.
(define (compression-stream-core-surface-present? raw)
  (and (compression-stream-host-property-present? raw "readable")
       (compression-stream-host-property-present? raw "writable")))

;; compression-stream-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (compression-stream-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; check-compression-stream-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required stream host method is available.
(define (check-compression-stream-host-method who raw receiver-name method-name)
  (unless (compression-stream-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " is not available"))))

;; check-compression-stream-host-property : symbol? external/raw string? string? -> void?
;;   Ensure a required stream host property is available.
(define (check-compression-stream-host-property who raw receiver-name property-name)
  (unless (compression-stream-host-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " is not available"))))

;; check-compression-stream-result : symbol? string? any/c -> compression-stream?
;;   Wrap and validate a CompressionStream constructor result.
(define (check-compression-stream-result who display-name raw)
  (define stream (compression-stream-info raw))
  (unless (compression-stream? stream)
    (raise-arguments-error who
                           (string-append display-name
                                          " result must be CompressionStream-like")))
  stream)

;; check-decompression-stream-result : symbol? string? any/c -> decompression-stream?
;;   Wrap and validate a DecompressionStream constructor result.
(define (check-decompression-stream-result who display-name raw)
  (define stream (decompression-stream-info raw))
  (unless (decompression-stream? stream)
    (raise-arguments-error who
                           (string-append display-name
                                          " result must be DecompressionStream-like")))
  stream)

;; compression-stream? : any/c -> boolean?
;;   Report whether v is a wrapped CompressionStream object.
(define (compression-stream? v)
  (and (compression-stream-host-value? v)
       (compression-stream-core-surface-present? (compression-stream-raw v))))

;; compression-stream-host-value? : any/c -> boolean?
;;   Report whether v wraps an external CompressionStream-like host value.
(define (compression-stream-host-value? v)
  (and (compression-stream-info? v)
       (compression-stream-raw-host-value? (compression-stream-raw v))))

;; decompression-stream? : any/c -> boolean?
;;   Report whether v is a wrapped DecompressionStream object.
(define (decompression-stream? v)
  (and (decompression-stream-host-value? v)
       (compression-stream-core-surface-present? (decompression-stream-raw v))))

;; decompression-stream-host-value? : any/c -> boolean?
;;   Report whether v wraps an external DecompressionStream-like host value.
(define (decompression-stream-host-value? v)
  (and (decompression-stream-info? v)
       (compression-stream-raw-host-value? (decompression-stream-raw v))))

;; compression-format? : any/c -> boolean?
;;   Recognize CompressionStream format names.
(define (compression-format? value)
  (and (or (string? value) (symbol? value))
       (let ([s (if (symbol? value) (symbol->string value) value)])
         (or (string=? s "gzip")
             (string=? s "deflate")
             (string=? s "deflate-raw")
             (string=? s "brotli")
             (string=? s "zstd")))))

;; compression-format->string : symbol? any/c -> string?
;;   Normalize a compression format to a JavaScript string.
(define (compression-format->string who value)
  (unless (compression-format? value)
    (raise-argument-error who "compression-format?" value))
  (if (symbol? value) (symbol->string value) value))

;; make-compression-stream : (or/c string? symbol?) -> compression-stream?
;;   Create a browser CompressionStream for format.
(define (make-compression-stream format)
  (unless (compression-stream-supported?)
    (raise-arguments-error 'make-compression-stream
                           "CompressionStream is not available"))
  (check-compression-stream-result
   'make-compression-stream
   "CompressionStream constructor"
   (js-new (js-var "CompressionStream")
           (vector (compression-format->string 'make-compression-stream format)))))

;; make-decompression-stream : (or/c string? symbol?) -> decompression-stream?
;;   Create a browser DecompressionStream for format.
(define (make-decompression-stream format)
  (unless (decompression-stream-supported?)
    (raise-arguments-error 'make-decompression-stream
                           "DecompressionStream is not available"))
  (check-decompression-stream-result
   'make-decompression-stream
   "DecompressionStream constructor"
   (js-new (js-var "DecompressionStream")
           (vector (compression-format->string 'make-decompression-stream format)))))

;; compression-stream-readable : compression-stream? -> external/raw
;;   Return the readable side of a CompressionStream.
(define (compression-stream-readable value)
  (unless (compression-stream-host-value? value)
    (raise-argument-error 'compression-stream-readable "compression-stream?" value))
  (check-compression-stream-host-property 'compression-stream-readable
                                          (compression-stream-raw value)
                                          "CompressionStream"
                                          "readable")
  (js-ref/extern (compression-stream-raw value) "readable"))

;; compression-stream-writable : compression-stream? -> external/raw
;;   Return the writable side of a CompressionStream.
(define (compression-stream-writable value)
  (unless (compression-stream-host-value? value)
    (raise-argument-error 'compression-stream-writable "compression-stream?" value))
  (check-compression-stream-host-property 'compression-stream-writable
                                          (compression-stream-raw value)
                                          "CompressionStream"
                                          "writable")
  (js-ref/extern (compression-stream-raw value) "writable"))

;; decompression-stream-readable : decompression-stream? -> external/raw
;;   Return the readable side of a DecompressionStream.
(define (decompression-stream-readable value)
  (unless (decompression-stream-host-value? value)
    (raise-argument-error 'decompression-stream-readable "decompression-stream?" value))
  (check-compression-stream-host-property 'decompression-stream-readable
                                          (decompression-stream-raw value)
                                          "DecompressionStream"
                                          "readable")
  (js-ref/extern (decompression-stream-raw value) "readable"))

;; decompression-stream-writable : decompression-stream? -> external/raw
;;   Return the writable side of a DecompressionStream.
(define (decompression-stream-writable value)
  (unless (decompression-stream-host-value? value)
    (raise-argument-error 'decompression-stream-writable "decompression-stream?" value))
  (check-compression-stream-host-property 'decompression-stream-writable
                                          (decompression-stream-raw value)
                                          "DecompressionStream"
                                          "writable")
  (js-ref/extern (decompression-stream-raw value) "writable"))

;; readable-stream-pipe-through-compression : external/raw compression-stream? -> external/raw
;;   Pipe a ReadableStream through a CompressionStream and return the resulting ReadableStream.
(define (readable-stream-pipe-through-compression readable value)
  (unless (compression-stream-raw-host-value? readable)
    (raise-argument-error 'readable-stream-pipe-through-compression "external?" readable))
  (unless (compression-stream-host-value? value)
    (raise-argument-error 'readable-stream-pipe-through-compression "compression-stream?" value))
  (check-compression-stream-host-method 'readable-stream-pipe-through-compression
                                        readable
                                        "ReadableStream"
                                        "pipeThrough")
  (js-send/extern readable "pipeThrough" (vector (compression-stream-raw value))))

;; readable-stream-pipe-through-decompression : external/raw decompression-stream? -> external/raw
;;   Pipe a ReadableStream through a DecompressionStream and return the resulting ReadableStream.
(define (readable-stream-pipe-through-decompression readable value)
  (unless (compression-stream-raw-host-value? readable)
    (raise-argument-error 'readable-stream-pipe-through-decompression "external?" readable))
  (unless (decompression-stream-host-value? value)
    (raise-argument-error 'readable-stream-pipe-through-decompression "decompression-stream?" value))
  (check-compression-stream-host-method 'readable-stream-pipe-through-decompression
                                        readable
                                        "ReadableStream"
                                        "pipeThrough")
  (js-send/extern readable "pipeThrough" (vector (decompression-stream-raw value))))
