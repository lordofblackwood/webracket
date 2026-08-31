#lang scribble/manual

@(require "browser-api-docs.rkt"
          (for-label (lib "scribblings/ffi-web-midi-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-web-midi-labels.rkt" "webracket-doc")))

@title{Web MIDI API}
@declare-exporting[(lib "scribblings/ffi-web-midi-labels.rkt" "webracket-doc")]

This page documents the low-level static @racket[js-web-midi-*] bindings in
@tt{ffi/web-midi.ffi}. Each import performs one named Web MIDI operation; MIDI
option keys, map names, event names, and browser method names do not cross the
Racket/JavaScript boundary dynamically. The checked public API is documented in
the @racketid[web-midi] library chapter.

The message, scheduled timestamp, port-ID vector, and optional metadata values
use FASL marshalling. The JavaScript helper validates a nonempty byte string for
each output message and a finite nonnegative number for a scheduled timestamp.
Normal programs should use the public predicates and wrappers rather than these
raw bindings.

@(render-ffi-docs "ffi/web-midi.ffi" "web-midi.ffi")
