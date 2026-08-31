#lang scribble/manual

@(require "browser-api-docs.rkt"
          (for-label (lib "scribblings/ffi-file-system-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-file-system-labels.rkt" "webracket-doc")))

@title{File System API}
@declare-exporting[(lib "scribblings/ffi-file-system-labels.rkt" "webracket-doc")]

This page documents the low-level static @racket[js-file-system-*] bindings in
@tt{ffi/file-system.ffi}. Each import is one named browser operation; no
property name or JavaScript options object is accepted dynamically. The
checked public API is documented in the @racketid[file-system] library chapter.

The seek and truncate imports accept a FASL-marshalled value at the raw
boundary, but validate it as a JavaScript-safe nonnegative byte count before
calling the browser. Normal programs should use the checked public procedures,
which expose that restriction as @racket[file-system-byte-count?].

@(render-ffi-docs "ffi/file-system.ffi" "file-system.ffi")
