#lang webracket/base

;; Browser smoke for Compression Streams wrapper host-method boundary errors.

(require compression-streams
         (only-in webracket/unsafe/dom
                  js-eval
                  js-null
                  js-undefined))

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
  globalThis.__wrCompressionBoundaryInstallBadConstructorResult = (kind, missing) => {
    globalThis[kind] = class {
      constructor(format) {
        this.format = format;
        this.readable = {kind: 'bad-readable'};
        this.writable = {kind: 'bad-writable'};
        delete this[missing];
      }
    };
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
    delete globalThis.__wrCompressionBoundaryInstallBadConstructorResult;
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

(define (bad-constructor-result-message kind missing thunk)
  (js-eval (string-append "__wrCompressionBoundaryInstallBadConstructorResult('"
                          kind
                          "', '"
                          missing
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

(define null-raw-compression-stream
  (compression-stream-info (js-null)))

(define undefined-raw-compression-stream
  (compression-stream-info (js-undefined)))

(define null-raw-decompression-stream
  (decompression-stream-info (js-null)))

(define undefined-raw-decompression-stream
  (decompression-stream-info (js-undefined)))

(check-true (not (compression-stream? null-raw-compression-stream))
            "compression-stream? rejects null raw")
(check-true (not (compression-stream? undefined-raw-compression-stream))
            "compression-stream? rejects undefined raw")
(check-true (not (decompression-stream? null-raw-decompression-stream))
            "decompression-stream? rejects null raw")
(check-true (not (decompression-stream? undefined-raw-decompression-stream))
            "decompression-stream? rejects undefined raw")
(check-true (not (compression-stream? (fake-compression-stream "readable")))
            "compression-stream? rejects missing readable")
(check-true (not (compression-stream? (fake-compression-stream "writable")))
            "compression-stream? rejects missing writable")
(check-true (not (decompression-stream? (fake-decompression-stream "readable")))
            "decompression-stream? rejects missing readable")
(check-true (not (decompression-stream? (fake-decompression-stream "writable")))
            "decompression-stream? rejects missing writable")

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

(define compression-constructor-result-message
  (bad-constructor-result-message
   "CompressionStream"
   "readable"
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

(define decompression-constructor-result-message
  (bad-constructor-result-message
   "DecompressionStream"
   "writable"
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

(define compression-null-raw-message
  (catch-message
   (lambda ()
     (compression-stream-readable null-raw-compression-stream))))

(define compression-undefined-raw-message
  (catch-message
   (lambda ()
     (compression-stream-readable undefined-raw-compression-stream))))

(define decompression-null-raw-message
  (catch-message
   (lambda ()
     (decompression-stream-readable null-raw-decompression-stream))))

(define decompression-undefined-raw-message
  (catch-message
   (lambda ()
     (decompression-stream-readable undefined-raw-decompression-stream))))

(define readable-null-raw-message
  (catch-message
   (lambda ()
     (readable-stream-pipe-through-compression
      (js-null)
      (make-compression-stream 'gzip)))))

(define readable-undefined-raw-message
  (catch-message
   (lambda ()
     (readable-stream-pipe-through-decompression
      (js-undefined)
      (make-decompression-stream 'gzip)))))

(check-message compression-message
               "ReadableStream.pipeThrough is not available"
               "missing compression ReadableStream.pipeThrough message")
(check-message compression-constructor-message
               "CompressionStream is not available"
               "non-constructible CompressionStream message")
(check-message compression-constructor-result-message
               "CompressionStream constructor result must be CompressionStream-like"
               "bad CompressionStream constructor result message")
(check-message decompression-message
               "ReadableStream.pipeThrough is not available"
               "missing decompression ReadableStream.pipeThrough message")
(check-message decompression-constructor-message
               "DecompressionStream is not available"
               "non-constructible DecompressionStream message")
(check-message decompression-constructor-result-message
               "DecompressionStream constructor result must be DecompressionStream-like"
               "bad DecompressionStream constructor result message")
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
(check-message compression-null-raw-message
               "compression-stream?"
               "missing CompressionStream null raw message")
(check-message compression-undefined-raw-message
               "compression-stream?"
               "missing CompressionStream undefined raw message")
(check-message decompression-null-raw-message
               "decompression-stream?"
               "missing DecompressionStream null raw message")
(check-message decompression-undefined-raw-message
               "decompression-stream?"
               "missing DecompressionStream undefined raw message")
(check-message readable-null-raw-message
               "external?"
               "missing ReadableStream null raw message")
(check-message readable-undefined-raw-message
               "external?"
               "missing ReadableStream undefined raw message")

(js-eval "__wrCompressionBoundaryRestore();")

(js-log "compression-stream-method-missing-host-ffi-ok")
#t
