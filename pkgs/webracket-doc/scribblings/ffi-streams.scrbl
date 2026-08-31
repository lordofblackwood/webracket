#lang scribble/manual

@(require "browser-api-docs.rkt"
          (for-label (lib "scribblings/ffi-streams-labels.rkt" "webracket-doc")))

@title{Streams API}
@declare-exporting[(lib "scribblings/ffi-streams-labels.rkt" "webracket-doc")]

This page documents the low-level static @racket[js-*-stream-*] bindings in
@tt{ffi/streams.ffi}. Each import performs one named browser operation; no
JavaScript property name is passed at run time. The checked public API is
documented in the @racketid[streams] library chapter.

@(render-ffi-docs "ffi/streams.ffi" "streams.ffi")
