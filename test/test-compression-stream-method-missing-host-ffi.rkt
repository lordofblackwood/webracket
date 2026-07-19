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
  globalThis.__wrCompressionBoundaryFakeStream = (missing) => {
    const stream = {
      readable: {kind: 'fake-readable'},
      writable: {kind: 'fake-writable'}
    };
    delete stream[missing];
    return stream;
  };
  globalThis.__wrCompressionBoundaryInstallNonConstructor = (kind) => {
    globalThis[kind] = () => {};
  };
  globalThis.__wrCompressionBoundaryRestoreConstructor = (kind) => {
    const saved = globalThis.__wrCompressionBoundarySaved[kind];
    if (saved === undefined) {
      delete globalThis[kind];
    } else {
      globalThis[kind] = saved;
    }
  };
  globalThis.__wrCompressionBoundaryRestore = () => {
    globalThis.__wrCompressionBoundaryRestoreConstructor('CompressionStream');
    globalThis.__wrCompressionBoundaryRestoreConstructor('DecompressionStream');
    delete globalThis.__wrCompressionBoundarySaved;
    delete globalThis.__wrCompressionBoundaryReadable;
    delete globalThis.__wrCompressionBoundaryInstall;
    delete globalThis.__wrCompressionBoundaryFakeStream;
    delete globalThis.__wrCompressionBoundaryInstallNonConstructor;
    delete globalThis.__wrCompressionBoundaryRestoreConstructor;
    delete globalThis.__wrCompressionBoundaryRestore;
  };")

(define (non-constructor-stream-message kind thunk)
  (js-eval (string-append "__wrCompressionBoundaryInstallNonConstructor('"
                          kind
                          "')"))
  (define message (catch-message thunk))
  (js-eval (string-append "__wrCompressionBoundaryRestoreConstructor('"
                          kind
                          "')"))
  message)

(define (missing-pipe-through-message thunk)
  (js-eval "__wrCompressionBoundaryInstall('pipeThrough')")
  (catch-message thunk))

(define (fake-compression-stream missing)
  (compression-stream-info
   (js-eval (string-append "__wrCompressionBoundaryFakeStream('"
                           missing
                           "')"))))

(define (fake-decompression-stream missing)
  (decompression-stream-info
   (js-eval (string-append "__wrCompressionBoundaryFakeStream('"
                           missing
                           "')"))))

(define compression-message
  (missing-pipe-through-message
   (lambda ()
     (define readable (js-eval "globalThis.__wrCompressionBoundaryReadable"))
     (define stream (make-compression-stream 'gzip))
     (check-true (compression-stream? stream)
                 "compression-stream? accepts fake host stream")
     (readable-stream-pipe-through-compression readable stream))))

(define compression-constructor-message
  (non-constructor-stream-message
   "CompressionStream"
   (lambda ()
     (make-compression-stream 'gzip))))

(define decompression-message
  (missing-pipe-through-message
   (lambda ()
     (define readable (js-eval "globalThis.__wrCompressionBoundaryReadable"))
     (define stream (make-decompression-stream 'gzip))
     (check-true (decompression-stream? stream)
                 "decompression-stream? accepts fake host stream")
     (readable-stream-pipe-through-decompression readable stream))))

(define decompression-constructor-message
  (non-constructor-stream-message
   "DecompressionStream"
   (lambda ()
     (make-decompression-stream 'gzip))))

(define compression-readable-message
  (catch-message
   (lambda ()
     (compression-stream-readable (fake-compression-stream "readable")))))

(define compression-writable-message
  (catch-message
   (lambda ()
     (compression-stream-writable (fake-compression-stream "writable")))))

(define decompression-readable-message
  (catch-message
   (lambda ()
     (decompression-stream-readable (fake-decompression-stream "readable")))))

(define decompression-writable-message
  (catch-message
   (lambda ()
     (decompression-stream-writable (fake-decompression-stream "writable")))))

(check-message compression-message
               "ReadableStream.pipeThrough is not available"
               "missing compression ReadableStream.pipeThrough message")
(check-message compression-constructor-message
               "CompressionStream is not available"
               "non-constructible CompressionStream message")
(check-message decompression-message
               "ReadableStream.pipeThrough is not available"
               "missing decompression ReadableStream.pipeThrough message")
(check-message decompression-constructor-message
               "DecompressionStream is not available"
               "non-constructible DecompressionStream message")
(check-message compression-readable-message
               "CompressionStream.readable is not available"
               "missing CompressionStream.readable message")
(check-message compression-writable-message
               "CompressionStream.writable is not available"
               "missing CompressionStream.writable message")
(check-message decompression-readable-message
               "DecompressionStream.readable is not available"
               "missing DecompressionStream.readable message")
(check-message decompression-writable-message
               "DecompressionStream.writable is not available"
               "missing DecompressionStream.writable message")

(js-eval "__wrCompressionBoundaryRestore();")

(js-log "compression-stream-method-missing-host-ffi-ok")
#t
