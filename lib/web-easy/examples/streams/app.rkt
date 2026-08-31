#lang webracket/base

(require browser/dom
         js/promise
         streams)

(define (append-text-node! element text)
  (js-append-child! element (js-create-text-node text)))

(define (set-text! element text)
  (js-set! element "textContent" text))

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define intro (js-create-element "p"))
(define status (js-create-element "p"))

(append-text-node! title "Streams API Demo")
(append-text-node! intro
                   "Write one Racket string through a static TransformStream binding, then read it back.")
(js-set! status "id" "stream-status")
(set-text! status "Running the static Streams API round trip...")

(js-append-child! main title)
(js-append-child! main intro)
(js-append-child! main status)
(js-append-child! body main)

(define (run-stream-round-trip!)
  (define transform (make-transform-stream))
  (define writer (writable-stream-get-writer
                  (transform-stream-writable transform)))
  (define reader (readable-stream-get-reader
                  (transform-stream-readable transform)))
  (define read-result #f)
  (define (promise-failed _reason)
    (set-text! status "FAIL: a Streams API Promise was rejected.")
    (void))
  (define (finish-read raw-result)
    (set! read-result (readable-stream-read-result-wrap raw-result))
    (void))
  (define (finish-close _ignored)
    (cond
      [(not read-result)
       (set-text! status "FAIL: writer closed before a chunk was read.")]
      [(readable-stream-read-result-done? read-result)
       (set-text! status "FAIL: stream ended before producing a chunk.")]
      [(string=? (readable-stream-read-result-value read-result)
                  "static Streams API round trip")
       (set-text! status "PASS: static TransformStream round trip completed.")]
      [else
       (set-text! status "FAIL: stream returned an unexpected chunk.")])
    (void))
  (define (finish-write _ignored)
    (js-promise-then (writable-stream-writer-close writer)
                     finish-close
                     promise-failed)
    (void))
  ;; Read before writing so the transform has a consumer and the write can
  ;; resolve instead of waiting on its normal backpressure signal.
  (js-promise-then (readable-stream-reader-read reader)
                   finish-read
                   promise-failed)
  (js-promise-then
   (writable-stream-writer-write writer "static Streams API round trip")
   finish-write
   promise-failed)
  ;; Promise callback return values cross a FASL boundary.  The callbacks
  ;; above schedule their next step and return void instead of a js-promise.
  (void))

(if (streams-supported?)
    (run-stream-round-trip!)
    (set-text! status "FAIL: Streams API is not available in this browser."))
