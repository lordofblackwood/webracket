#lang webracket/base

(require browser/dom
         js/promise
         streams)

(define (set-status! text)
  (js-set! (js-document-body) "textContent" text))

(define (run-stream-smoke!)
  (define transform (make-transform-stream))
  (define writer (writable-stream-get-writer
                  (transform-stream-writable transform)))
  (define reader (readable-stream-get-reader
                  (transform-stream-readable transform)))
  (define read-result #f)
  (define (promise-failed _reason)
    (set-status! "FAIL: a Streams API Promise was rejected")
    (void))
  (define (finish-read raw-result)
    (set! read-result (readable-stream-read-result-wrap raw-result))
    (void))
  (define (finish-close _ignored)
    (cond
      [(not read-result)
       (set-status! "FAIL: writer closed before a chunk was read")]
      [(readable-stream-read-result-done? read-result)
       (set-status! "FAIL: stream ended without a chunk")]
      [(string=? (readable-stream-read-result-value read-result)
                  "static streams smoke")
       (set-status! "PASS: static streams round trip")]
      [else
       (set-status! "FAIL: unexpected stream chunk")])
    (void))
  (define (finish-write _ignored)
    (js-promise-then (writable-stream-writer-close writer)
                     finish-close
                     promise-failed)
    (void))
  ;; Start the read before writing: a TransformStream applies backpressure
  ;; until its readable side consumes the pending chunk.
  (js-promise-then (readable-stream-reader-read reader)
                   finish-read
                   promise-failed)
  (js-promise-then (writable-stream-writer-write writer "static streams smoke")
                   finish-write
                   promise-failed)
  ;; Promise callback results cross the FASL boundary, so callbacks above
  ;; schedule follow-up work and return void rather than wrapped promises.
  (void))

(if (streams-supported?)
    (run-stream-smoke!)
    (set-status! "FAIL: Streams API is not available."))
