#lang scribble/manual

@(require "browser-api-docs.rkt"
          (lib "scribblings/ffi-image-labels.rkt" "webracket-doc")
          (for-label (lib "scribblings/ffi-image-labels.rkt" "webracket-doc")))

@title{Image}
@declare-exporting[(lib "scribblings/ffi-image-labels.rkt" "webracket-doc")]

This page documents the low-level @racket[js-image-*] bindings from
@tt{ffi/image.ffi}.

@(render-ffi-docs "ffi/image.ffi" "image.ffi")
