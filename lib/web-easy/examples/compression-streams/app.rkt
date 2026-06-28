#lang webracket/base

(require browser/dom
         compression-streams)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-text! elem text)
  (js-set! elem "textContent" text))

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define intro (js-create-element "p"))
(define status (js-create-element "p"))

(append-text-node! title "Compression Streams API Demo")
(append-text-node! intro "Create a gzip CompressionStream and inspect its readable/writable sides.")

(cond
  [(compression-stream-supported?)
   (define gzip-stream (make-compression-stream 'gzip))
   (compression-stream-readable gzip-stream)
   (compression-stream-writable gzip-stream)
   (set-text! status "Created a gzip CompressionStream.")]
  [else
   (set-text! status "CompressionStream is not available.")])

(js-append-child! main title)
(js-append-child! main intro)
(js-append-child! main status)
(js-append-child! body main)
