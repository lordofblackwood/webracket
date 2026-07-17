#lang webracket/base

;; Browser smoke for Compression Streams wrapper host-method boundary errors.

(require compression-streams
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(js-eval
 "globalThis.__wrCompressionBoundarySaved = {
    CompressionStream: globalThis.CompressionStream,
    DecompressionStream: globalThis.DecompressionStream
  };
  globalThis.CompressionStream = class CompressionStream {
    constructor(format) {
      this.format = format;
      this.readable = {kind: 'compressed-readable'};
      this.writable = {kind: 'compressed-writable'};
    }
  };
  globalThis.DecompressionStream = class DecompressionStream {
    constructor(format) {
      this.format = format;
      this.readable = {kind: 'decompressed-readable'};
      this.writable = {kind: 'decompressed-writable'};
    }
  };
  globalThis.__wrCompressionBoundaryReadable = {
    pipeThrough(stream) {
      return {kind: 'piped-readable', stream};
    }
  };
  globalThis.__wrCompressionBoundaryInstall = (missing) => {
    globalThis.__wrCompressionBoundaryReadable = {
      pipeThrough(stream) {
        return {kind: 'piped-readable', stream};
      }
    };
    delete globalThis.__wrCompressionBoundaryReadable[missing];
  };
  globalThis.__wrCompressionBoundaryRestore = () => {
    if (globalThis.__wrCompressionBoundarySaved.CompressionStream === undefined) {
      delete globalThis.CompressionStream;
    } else {
      globalThis.CompressionStream = globalThis.__wrCompressionBoundarySaved.CompressionStream;
    }
    if (globalThis.__wrCompressionBoundarySaved.DecompressionStream === undefined) {
      delete globalThis.DecompressionStream;
    } else {
      globalThis.DecompressionStream = globalThis.__wrCompressionBoundarySaved.DecompressionStream;
    }
    delete globalThis.__wrCompressionBoundarySaved;
    delete globalThis.__wrCompressionBoundaryReadable;
    delete globalThis.__wrCompressionBoundaryInstall;
    delete globalThis.__wrCompressionBoundaryRestore;
  };")

(define (missing-pipe-through-message thunk)
  (js-eval "__wrCompressionBoundaryInstall('pipeThrough')")
  (catch-message thunk))

(define compression-message
  (missing-pipe-through-message
   (lambda ()
     (define readable (js-eval "globalThis.__wrCompressionBoundaryReadable"))
     (define stream (make-compression-stream 'gzip))
     (check-true (compression-stream? stream)
                 "compression-stream? accepts fake host stream")
     (readable-stream-pipe-through-compression readable stream))))

(define decompression-message
  (missing-pipe-through-message
   (lambda ()
     (define readable (js-eval "globalThis.__wrCompressionBoundaryReadable"))
     (define stream (make-decompression-stream 'gzip))
     (check-true (decompression-stream? stream)
                 "decompression-stream? accepts fake host stream")
     (readable-stream-pipe-through-decompression readable stream))))

(check-message compression-message
               "ReadableStream.pipeThrough is not available"
               "missing compression ReadableStream.pipeThrough message")
(check-message decompression-message
               "ReadableStream.pipeThrough is not available"
               "missing decompression ReadableStream.pipeThrough message")

(js-eval "__wrCompressionBoundaryRestore();")

(js-log "compression-stream-method-missing-host-ffi-ok")
#t
