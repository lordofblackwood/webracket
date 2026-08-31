#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-streams-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[streams]}
@declare-exporting[(lib "scribblings/lib-streams-labels.rkt" "webracket-doc")]

@defmodule[streams]

The @racketmodname[streams] module wraps the browser Streams API with fixed,
statically named FFI imports. Use it to create an identity @tt{TransformStream},
read chunks from a @tt{ReadableStream}, write chunks to a @tt{WritableStream},
and connect compatible streams.

@(mdn-bar "Streams API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Streams_API")

@bold{Read MDN first.} Stream operations are asynchronous:
@racket[readable-stream-reader-read] and
@racket[writable-stream-writer-write] return @racket[js-promise?] values, and
locking a stream with a reader or writer prevents another reader or writer
from being acquired until the lock is released.

@bold{This first version intentionally omits custom JavaScript sources, sinks,
and transform callbacks.} Those require an explicit callback lifetime and
backpressure design. The fixed browser operations below are static imports,
not calls through @racket[js-send/extern].

@section{Quick Start}

@racketblock[
(require js/promise
         streams)

(define transform (make-transform-stream))
(define writer (writable-stream-get-writer
                (transform-stream-writable transform)))
(define reader (readable-stream-get-reader
                (transform-stream-readable transform)))
(define read-result #f)

(define (failed _reason)
  (displayln "stream Promise rejected")
  (void))

(define (finish-read raw-result)
  (set! read-result (readable-stream-read-result-wrap raw-result))
  (void))

(define (finish-close _ignored)
  (unless (or (not read-result)
              (readable-stream-read-result-done? read-result))
    (displayln (readable-stream-read-result-value read-result)))
  (void))

(define (finish-write _ignored)
  (js-promise-then (writable-stream-writer-close writer) finish-close failed)
  (void))

;; Start reading first: TransformStream applies backpressure until a reader
;; consumes the pending chunk.
(js-promise-then (readable-stream-reader-read reader) finish-read failed)
(js-promise-then (writable-stream-writer-write writer "hello") finish-write failed)
]

The result supplied to a Promise callback is an opaque browser object. Wrap it
with @racket[readable-stream-read-result-wrap] before using the static
@racket[readable-stream-read-result-done?] and
@racket[readable-stream-read-result-value] accessors.

@bold{Promise callback results cross a FASL boundary.} A callback may return
a FASL-marshallable value, but it must not return @racket[js-promise?] or
another checked wrapper. When a callback starts another asynchronous operation,
schedule it and then return @racket[(void)], as @racket[finish-write] does
above.

@section{Availability and Values}

@defproc[(readable-stream-supported?) boolean?]{
Returns @racket[#t] when the browser provides @tt{ReadableStream}.
}

@defproc[(writable-stream-supported?) boolean?]{
Returns @racket[#t] when the browser provides @tt{WritableStream}.
}

@defproc[(transform-stream-supported?) boolean?]{
Returns @racket[#t] when the browser provides @tt{TransformStream}.
}

@defproc[(streams-supported?) boolean?]{
Returns @racket[#t] when all three constructors used by this wrapper are
available.
}

@defproc[(stream-chunk? [value any/c]) boolean?]{
Recognizes values accepted by @racket[writable-stream-writer-write]: booleans,
characters, numbers, strings, symbols, byte strings, the empty list, void,
external browser values, and pairs or vectors containing those values.
}

@section{Transform Streams}

@defproc[(make-transform-stream) transform-stream?]{
@(mdn-bar "TransformStream() constructor"
          "https://developer.mozilla.org/en-US/docs/Web/API/TransformStream/TransformStream")
Creates an identity @tt{TransformStream} with browser-default queuing
strategies. Values written to its writable side emerge unchanged on its
readable side.
}

@defproc[(transform-stream? [value any/c]) boolean?]{
Returns @racket[#t] for wrapped browser @tt{TransformStream} values.
}

@defproc[(transform-stream-readable [stream transform-stream?]) readable-stream?]{
@(mdn-bar "TransformStream: readable"
          "https://developer.mozilla.org/en-US/docs/Web/API/TransformStream/readable")
Returns the checked readable side of @racket[stream].
}

@defproc[(transform-stream-writable [stream transform-stream?]) writable-stream?]{
@(mdn-bar "TransformStream: writable"
          "https://developer.mozilla.org/en-US/docs/Web/API/TransformStream/writable")
Returns the checked writable side of @racket[stream].
}

@section{Readable Streams}

@defproc[(readable-stream? [value any/c]) boolean?]{
Returns @racket[#t] for wrapped browser @tt{ReadableStream} values.
}

@defproc[(readable-stream-locked? [stream readable-stream?]) boolean?]{
@(mdn-bar "ReadableStream: locked"
          "https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/locked")
Reports whether @racket[stream] is locked to a reader.
}

@defproc[(readable-stream-get-reader [stream readable-stream?])
         readable-stream-reader?]{
@(mdn-bar "ReadableStream: getReader()"
          "https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/getReader")
Acquires the default reader and locks @racket[stream].
}

@defproc[(readable-stream-reader? [value any/c]) boolean?]{
Returns @racket[#t] for wrapped @tt{ReadableStreamDefaultReader} values.
}

@defproc[(readable-stream-reader-read [reader readable-stream-reader?])
         js-promise?]{
@(mdn-bar "ReadableStreamDefaultReader: read()"
          "https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultReader/read")
Starts one read. Its fulfillment value must be passed to
@racket[readable-stream-read-result-wrap].
}

@defproc[(readable-stream-reader-release-lock! [reader readable-stream-reader?])
         void?]{
Releases @racket[reader]'s lock on its stream.
}

@defproc[(readable-stream-pipe-through [stream readable-stream?]
                                       [transform transform-stream?])
         readable-stream?]{
@(mdn-bar "ReadableStream: pipeThrough()"
          "https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/pipeThrough")
Returns the readable output from piping @racket[stream] through
@racket[transform].
}

@defproc[(readable-stream-pipe-to [stream readable-stream?]
                                  [destination writable-stream?])
         js-promise?]{
@(mdn-bar "ReadableStream: pipeTo()"
          "https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/pipeTo")
Pipes @racket[stream] to @racket[destination] and returns the completion
Promise.
}

@section{Writable Streams}

@defproc[(writable-stream? [value any/c]) boolean?]{
Returns @racket[#t] for wrapped browser @tt{WritableStream} values.
}

@defproc[(writable-stream-locked? [stream writable-stream?]) boolean?]{
@(mdn-bar "WritableStream: locked"
          "https://developer.mozilla.org/en-US/docs/Web/API/WritableStream/locked")
Reports whether @racket[stream] is locked to a writer.
}

@defproc[(writable-stream-get-writer [stream writable-stream?])
         writable-stream-writer?]{
@(mdn-bar "WritableStream: getWriter()"
          "https://developer.mozilla.org/en-US/docs/Web/API/WritableStream/getWriter")
Acquires the default writer and locks @racket[stream].
}

@defproc[(writable-stream-writer? [value any/c]) boolean?]{
Returns @racket[#t] for wrapped @tt{WritableStreamDefaultWriter} values.
}

@defproc[(writable-stream-writer-write [writer writable-stream-writer?]
                                       [chunk stream-chunk?])
         js-promise?]{
@(mdn-bar "WritableStreamDefaultWriter: write()"
          "https://developer.mozilla.org/en-US/docs/Web/API/WritableStreamDefaultWriter/write")
Writes @racket[chunk] and returns the browser Promise that completes after
the stream accepts it.
}

@defproc[(writable-stream-writer-close [writer writable-stream-writer?])
         js-promise?]{
@(mdn-bar "WritableStreamDefaultWriter: close()"
          "https://developer.mozilla.org/en-US/docs/Web/API/WritableStreamDefaultWriter/close")
Closes @racket[writer] and returns the browser completion Promise.
}

@defproc[(writable-stream-writer-release-lock! [writer writable-stream-writer?])
         void?]{
Releases @racket[writer]'s lock on its stream.
}

@section{Read Results}

@defproc[(readable-stream-read-result-wrap [raw external/raw])
         readable-stream-read-result?]{
Wraps the raw host object delivered to a reader-read Promise callback. This
is the sole intentional raw-value boundary in the public API.
}

@defproc[(readable-stream-read-result? [value any/c]) boolean?]{
Returns @racket[#t] for wrapped read results.
}

@defproc[(readable-stream-read-result-done? [result readable-stream-read-result?])
         boolean?]{
Returns whether the read result represents the end of its stream.
}

@defproc[(readable-stream-read-result-value [result readable-stream-read-result?])
         stream-chunk?]{
Returns the chunk from @racket[result]. Do not use it after a true
@racket[readable-stream-read-result-done?] result.
}
