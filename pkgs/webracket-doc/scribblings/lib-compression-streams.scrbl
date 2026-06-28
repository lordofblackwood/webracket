#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-compression-streams-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[compression-streams]}
@declare-exporting[(lib "scribblings/lib-compression-streams-labels.rkt" "webracket-doc")]

@defmodule[compression-streams]

The @racketmodname[compression-streams] module wraps the browser
@tt{CompressionStream} and @tt{DecompressionStream} constructors. The API is
stream-based: create a transform stream and pipe a browser
@tt{ReadableStream} through it.

@(mdn-bar "Compression Streams API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Compression_Streams_API")

@bold{Read MDN first.} Compression streams are asynchronous browser streams.
This wrapper intentionally exposes the stream-level API; byte/string
convenience helpers can be layered on later when the surrounding
@tt{ReadableStream}, @tt{Blob}, and typed-array wrappers are broader.

@section{Compression Streams Quick Start}

@racketblock[
(require compression-streams)

(when (compression-stream-supported?)
  (define gz (make-compression-stream 'gzip))
  (compression-stream-readable gz)
  (compression-stream-writable gz))
]

@section{Compression Streams API}

@defproc[(compression-stream-supported?) boolean?]{
@(mdn-bar "CompressionStream"
          "https://developer.mozilla.org/en-US/docs/Web/API/CompressionStream")
Returns @racket[#t] when @tt{CompressionStream} is available.
}

@defproc[(decompression-stream-supported?) boolean?]{
@(mdn-bar "DecompressionStream"
          "https://developer.mozilla.org/en-US/docs/Web/API/DecompressionStream")
Returns @racket[#t] when @tt{DecompressionStream} is available.
}

@defproc[(compression-format? [v any/c]) boolean?]{
Returns @racket[#t] for strings or symbols naming a supported format:
@racket['gzip], @racket['deflate], @racket['deflate-raw],
@racket['brotli], or @racket['zstd].
}

@defproc[(make-compression-stream [format compression-format?])
         compression-stream?]{
@(mdn-bar "CompressionStream: CompressionStream() constructor"
          "https://developer.mozilla.org/en-US/docs/Web/API/CompressionStream/CompressionStream")
Creates a browser @tt{CompressionStream}.
}

@defproc[(make-decompression-stream [format compression-format?])
         decompression-stream?]{
@(mdn-bar "DecompressionStream: DecompressionStream() constructor"
          "https://developer.mozilla.org/en-US/docs/Web/API/DecompressionStream/DecompressionStream")
Creates a browser @tt{DecompressionStream}.
}

@defproc[(compression-stream? [v any/c]) boolean?]{Returns @racket[#t] for wrapped @tt{CompressionStream} values.}
@defproc[(compression-stream-raw [value compression-stream?]) external/raw]{Returns the wrapped raw compression stream.}
@defproc[(decompression-stream? [v any/c]) boolean?]{Returns @racket[#t] for wrapped @tt{DecompressionStream} values.}
@defproc[(decompression-stream-raw [value decompression-stream?]) external/raw]{Returns the wrapped raw decompression stream.}

@defproc[(compression-stream-readable [value compression-stream?]) external/raw]{Returns the readable side.}
@defproc[(compression-stream-writable [value compression-stream?]) external/raw]{Returns the writable side.}
@defproc[(decompression-stream-readable [value decompression-stream?]) external/raw]{Returns the readable side.}
@defproc[(decompression-stream-writable [value decompression-stream?]) external/raw]{Returns the writable side.}

@defproc[(readable-stream-pipe-through-compression [readable external/raw]
                                                   [value compression-stream?])
         external/raw]{
Calls @tt{readable.pipeThrough} with the wrapped compression stream and
returns the resulting @tt{ReadableStream}.
}

@defproc[(readable-stream-pipe-through-decompression [readable external/raw]
                                                     [value decompression-stream?])
         external/raw]{
Calls @tt{readable.pipeThrough} with the wrapped decompression stream and
returns the resulting @tt{ReadableStream}.
}
