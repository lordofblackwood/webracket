#lang webracket/base

(require js/promise
         webracket/unsafe/streams
         (only-in webracket/primitives external?))

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
         readable-stream-read-result-value)

;; The browser calls are all static FFI imports from `streams.ffi`.  The
;; structs below deliberately keep their raw host values private so callers
;; compose streams through the checked API rather than dynamic property names.

;; readable-stream-info : external/raw -> readable-stream-info?
;;   Hold one browser ReadableStream host value.
(struct readable-stream-info (raw) #:transparent)

;; writable-stream-info : external/raw -> writable-stream-info?
;;   Hold one browser WritableStream host value.
(struct writable-stream-info (raw) #:transparent)

;; transform-stream-info : external/raw -> transform-stream-info?
;;   Hold one browser TransformStream host value.
(struct transform-stream-info (raw) #:transparent)

;; readable-stream-reader-info : external/raw -> readable-stream-reader-info?
;;   Hold one browser ReadableStreamDefaultReader host value.
(struct readable-stream-reader-info (raw) #:transparent)

;; writable-stream-writer-info : external/raw -> writable-stream-writer-info?
;;   Hold one browser WritableStreamDefaultWriter host value.
(struct writable-stream-writer-info (raw) #:transparent)

;; readable-stream-read-result-info : external/raw -> readable-stream-read-result-info?
;;   Hold the host object delivered when a reader's Promise resolves.
(struct readable-stream-read-result-info (raw) #:transparent)

;; readable-stream-supported? : -> boolean?
;;   Report whether the browser provides ReadableStream.
(define (readable-stream-supported?)
  (js-readable-stream-supported?))

;; writable-stream-supported? : -> boolean?
;;   Report whether the browser provides WritableStream.
(define (writable-stream-supported?)
  (js-writable-stream-supported?))

;; transform-stream-supported? : -> boolean?
;;   Report whether the browser provides TransformStream.
(define (transform-stream-supported?)
  (js-transform-stream-supported?))

;; streams-supported? : -> boolean?
;;   Report whether the fixed Streams API surface used by this library exists.
(define (streams-supported?)
  (and (readable-stream-supported?)
       (writable-stream-supported?)
       (transform-stream-supported?)))

;; stream-chunk? : any/c -> boolean?
;;   Recognize the FASL-marshallable values accepted by writer-write.
(define (stream-chunk? value)
  (cond
    [(or (boolean? value)
         (char? value)
         (number? value)
         (string? value)
         (symbol? value)
         (bytes? value)
         (null? value)
         (void? value)
         (external? value))
     #t]
    [(pair? value)
     (and (stream-chunk? (car value))
          (stream-chunk? (cdr value)))]
    [(vector? value)
     (let loop ([index 0])
       (or (= index (vector-length value))
           (and (stream-chunk? (vector-ref value index))
                (loop (+ index 1)))))]
    [else #f]))

;; readable-stream? : any/c -> boolean?
;;   Report whether value is a checked browser ReadableStream.
(define (readable-stream? value)
  (and (readable-stream-info? value)
       (external? (readable-stream-info-raw value))
       (js-readable-stream? (readable-stream-info-raw value))))

;; writable-stream? : any/c -> boolean?
;;   Report whether value is a checked browser WritableStream.
(define (writable-stream? value)
  (and (writable-stream-info? value)
       (external? (writable-stream-info-raw value))
       (js-writable-stream? (writable-stream-info-raw value))))

;; transform-stream? : any/c -> boolean?
;;   Report whether value is a checked browser TransformStream.
(define (transform-stream? value)
  (and (transform-stream-info? value)
       (external? (transform-stream-info-raw value))
       (js-transform-stream? (transform-stream-info-raw value))))

;; readable-stream-reader? : any/c -> boolean?
;;   Report whether value is a checked browser default stream reader.
(define (readable-stream-reader? value)
  (and (readable-stream-reader-info? value)
       (external? (readable-stream-reader-info-raw value))
       (js-readable-stream-default-reader?
        (readable-stream-reader-info-raw value))))

;; writable-stream-writer? : any/c -> boolean?
;;   Report whether value is a checked browser default stream writer.
(define (writable-stream-writer? value)
  (and (writable-stream-writer-info? value)
       (external? (writable-stream-writer-info-raw value))
       (js-writable-stream-default-writer?
        (writable-stream-writer-info-raw value))))

;; readable-stream-read-result? : any/c -> boolean?
;;   Report whether value wraps a result supplied by reader-read.
(define (readable-stream-read-result? value)
  (and (readable-stream-read-result-info? value)
       (external? (readable-stream-read-result-info-raw value))
       (js-readable-stream-read-result?
        (readable-stream-read-result-info-raw value))))

;; check-readable-stream : symbol? any/c -> void?
;;   Raise an argument error unless value is a readable stream.
(define (check-readable-stream who value)
  (unless (readable-stream? value)
    (raise-argument-error who "readable-stream?" value)))

;; check-writable-stream : symbol? any/c -> void?
;;   Raise an argument error unless value is a writable stream.
(define (check-writable-stream who value)
  (unless (writable-stream? value)
    (raise-argument-error who "writable-stream?" value)))

;; check-transform-stream : symbol? any/c -> void?
;;   Raise an argument error unless value is a transform stream.
(define (check-transform-stream who value)
  (unless (transform-stream? value)
    (raise-argument-error who "transform-stream?" value)))

;; check-readable-stream-reader : symbol? any/c -> void?
;;   Raise an argument error unless value is a default stream reader.
(define (check-readable-stream-reader who value)
  (unless (readable-stream-reader? value)
    (raise-argument-error who "readable-stream-reader?" value)))

;; check-writable-stream-writer : symbol? any/c -> void?
;;   Raise an argument error unless value is a default stream writer.
(define (check-writable-stream-writer who value)
  (unless (writable-stream-writer? value)
    (raise-argument-error who "writable-stream-writer?" value)))

;; check-readable-stream-read-result : symbol? any/c -> void?
;;   Raise an argument error unless value wraps a stream read result.
(define (check-readable-stream-read-result who value)
  (unless (readable-stream-read-result? value)
    (raise-argument-error who "readable-stream-read-result?" value)))

;; wrap-readable-stream : symbol? external/raw -> readable-stream?
;;   Validate and wrap a ReadableStream returned by a static host import.
(define (wrap-readable-stream who raw)
  (define value (readable-stream-info raw))
  (unless (readable-stream? value)
    (raise-arguments-error who "expected the browser to return a ReadableStream"))
  value)

;; wrap-writable-stream : symbol? external/raw -> writable-stream?
;;   Validate and wrap a WritableStream returned by a static host import.
(define (wrap-writable-stream who raw)
  (define value (writable-stream-info raw))
  (unless (writable-stream? value)
    (raise-arguments-error who "expected the browser to return a WritableStream"))
  value)

;; wrap-transform-stream : symbol? external/raw -> transform-stream?
;;   Validate and wrap a TransformStream returned by a static host import.
(define (wrap-transform-stream who raw)
  (define value (transform-stream-info raw))
  (unless (transform-stream? value)
    (raise-arguments-error who "expected the browser to return a TransformStream"))
  value)

;; wrap-readable-stream-reader : symbol? external/raw -> readable-stream-reader?
;;   Validate and wrap a default reader returned by a static host import.
(define (wrap-readable-stream-reader who raw)
  (define value (readable-stream-reader-info raw))
  (unless (readable-stream-reader? value)
    (raise-arguments-error who
                           "expected the browser to return a ReadableStreamDefaultReader"))
  value)

;; wrap-writable-stream-writer : symbol? external/raw -> writable-stream-writer?
;;   Validate and wrap a default writer returned by a static host import.
(define (wrap-writable-stream-writer who raw)
  (define value (writable-stream-writer-info raw))
  (unless (writable-stream-writer? value)
    (raise-arguments-error who
                           "expected the browser to return a WritableStreamDefaultWriter"))
  value)

;; readable-stream-locked? : readable-stream? -> boolean?
;;   Report whether stream currently has an acquired reader.
(define (readable-stream-locked? stream)
  (check-readable-stream 'readable-stream-locked? stream)
  (js-readable-stream-locked? (readable-stream-info-raw stream)))

;; writable-stream-locked? : writable-stream? -> boolean?
;;   Report whether stream currently has an acquired writer.
(define (writable-stream-locked? stream)
  (check-writable-stream 'writable-stream-locked? stream)
  (js-writable-stream-locked? (writable-stream-info-raw stream)))

;; make-transform-stream : -> transform-stream?
;;   Create an identity TransformStream with browser default strategies.
(define (make-transform-stream)
  (unless (transform-stream-supported?)
    (raise-arguments-error 'make-transform-stream "TransformStream is not available"))
  (wrap-transform-stream 'make-transform-stream (js-transform-stream-new)))

;; transform-stream-readable : transform-stream? -> readable-stream?
;;   Return the readable side of a transform stream.
(define (transform-stream-readable stream)
  (check-transform-stream 'transform-stream-readable stream)
  (wrap-readable-stream
   'transform-stream-readable
   (js-transform-stream-readable (transform-stream-info-raw stream))))

;; transform-stream-writable : transform-stream? -> writable-stream?
;;   Return the writable side of a transform stream.
(define (transform-stream-writable stream)
  (check-transform-stream 'transform-stream-writable stream)
  (wrap-writable-stream
   'transform-stream-writable
   (js-transform-stream-writable (transform-stream-info-raw stream))))

;; readable-stream-get-reader : readable-stream? -> readable-stream-reader?
;;   Lock stream and return its default reader.
(define (readable-stream-get-reader stream)
  (check-readable-stream 'readable-stream-get-reader stream)
  (wrap-readable-stream-reader
   'readable-stream-get-reader
   (js-readable-stream-get-reader (readable-stream-info-raw stream))))

;; writable-stream-get-writer : writable-stream? -> writable-stream-writer?
;;   Lock stream and return its default writer.
(define (writable-stream-get-writer stream)
  (check-writable-stream 'writable-stream-get-writer stream)
  (wrap-writable-stream-writer
   'writable-stream-get-writer
   (js-writable-stream-get-writer (writable-stream-info-raw stream))))

;; readable-stream-reader-read : readable-stream-reader? -> js-promise?
;;   Read the next chunk; its fulfillment value is wrapped with read-result-wrap.
(define (readable-stream-reader-read reader)
  (check-readable-stream-reader 'readable-stream-reader-read reader)
  (js-promise-wrap-result
   'readable-stream-reader-read
   "read"
   (js-readable-stream-default-reader-read
    (readable-stream-reader-info-raw reader))
   "ReadableStreamDefaultReader"))

;; readable-stream-reader-release-lock! : readable-stream-reader? -> void?
;;   Release reader's lock on its readable stream.
(define (readable-stream-reader-release-lock! reader)
  (check-readable-stream-reader 'readable-stream-reader-release-lock! reader)
  (js-readable-stream-default-reader-release-lock!
   (readable-stream-reader-info-raw reader)))

;; writable-stream-writer-write : writable-stream-writer? stream-chunk? -> js-promise?
;;   Write chunk and return the browser Promise that tracks completion.
(define (writable-stream-writer-write writer chunk)
  (check-writable-stream-writer 'writable-stream-writer-write writer)
  (unless (stream-chunk? chunk)
    (raise-argument-error 'writable-stream-writer-write "stream-chunk?" chunk))
  (js-promise-wrap-result
   'writable-stream-writer-write
   "write"
   (js-writable-stream-default-writer-write
    (writable-stream-writer-info-raw writer)
    chunk)
   "WritableStreamDefaultWriter"))

;; writable-stream-writer-close : writable-stream-writer? -> js-promise?
;;   Close writer and return the browser Promise that tracks completion.
(define (writable-stream-writer-close writer)
  (check-writable-stream-writer 'writable-stream-writer-close writer)
  (js-promise-wrap-result
   'writable-stream-writer-close
   "close"
   (js-writable-stream-default-writer-close
    (writable-stream-writer-info-raw writer))
   "WritableStreamDefaultWriter"))

;; writable-stream-writer-release-lock! : writable-stream-writer? -> void?
;;   Release writer's lock on its writable stream.
(define (writable-stream-writer-release-lock! writer)
  (check-writable-stream-writer 'writable-stream-writer-release-lock! writer)
  (js-writable-stream-default-writer-release-lock!
   (writable-stream-writer-info-raw writer)))

;; readable-stream-pipe-through : readable-stream? transform-stream? -> readable-stream?
;;   Pipe stream through transform and return the resulting readable side.
(define (readable-stream-pipe-through stream transform)
  (check-readable-stream 'readable-stream-pipe-through stream)
  (check-transform-stream 'readable-stream-pipe-through transform)
  (wrap-readable-stream
   'readable-stream-pipe-through
   (js-readable-stream-pipe-through (readable-stream-info-raw stream)
                                    (transform-stream-info-raw transform))))

;; readable-stream-pipe-to : readable-stream? writable-stream? -> js-promise?
;;   Pipe stream to destination and return the Promise that tracks completion.
(define (readable-stream-pipe-to stream destination)
  (check-readable-stream 'readable-stream-pipe-to stream)
  (check-writable-stream 'readable-stream-pipe-to destination)
  (js-promise-wrap-result
   'readable-stream-pipe-to
   "pipeTo"
   (js-readable-stream-pipe-to (readable-stream-info-raw stream)
                               (writable-stream-info-raw destination))
   "ReadableStream"))

;; readable-stream-read-result-wrap : external/raw -> readable-stream-read-result?
;;   Validate the host read result delivered to a Promise fulfillment callback.
(define (readable-stream-read-result-wrap raw)
  (define value (readable-stream-read-result-info raw))
  (unless (readable-stream-read-result? value)
    (raise-argument-error 'readable-stream-read-result-wrap
                          "ReadableStream read-result external/raw"
                          raw))
  value)

;; readable-stream-read-result-done? : readable-stream-read-result? -> boolean?
;;   Report whether the reader reached the end of its stream.
(define (readable-stream-read-result-done? result)
  (check-readable-stream-read-result 'readable-stream-read-result-done? result)
  (js-readable-stream-read-result-done?
   (readable-stream-read-result-info-raw result)))

;; readable-stream-read-result-value : readable-stream-read-result? -> stream-chunk?
;;   Return the chunk supplied by a completed reader-read Promise.
(define (readable-stream-read-result-value result)
  (check-readable-stream-read-result 'readable-stream-read-result-value result)
  (js-readable-stream-read-result-value
   (readable-stream-read-result-info-raw result)))
