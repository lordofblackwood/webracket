#lang scribble/manual

@(require "browser-api-docs.rkt"
          (lib "scribblings/ffi-canvas-labels.rkt" "webracket-doc")
          (for-label (lib "scribblings/ffi-canvas-labels.rkt" "webracket-doc")))

@title{Canvas}
@declare-exporting[(lib "scribblings/ffi-canvas-labels.rkt" "webracket-doc")]

This page documents the low-level @racket[js-canvas-*] and
@racket[js-canvas2d-*] bindings from @tt{ffi/canvas.ffi}.

@(render-ffi-docs "ffi/canvas.ffi" "canvas.ffi")
