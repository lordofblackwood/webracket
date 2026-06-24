#lang scribble/manual

@(require "browser-api-docs.rkt"
          (lib "scribblings/ffi-domrect-labels.rkt" "webracket-doc")
          (for-label (lib "scribblings/ffi-domrect-labels.rkt" "webracket-doc")))

@title{DOMRect}
@declare-exporting[(lib "scribblings/ffi-domrect-labels.rkt" "webracket-doc")]

This page documents the low-level @racket[js-dom-rect-*] bindings from
@tt{ffi/domrect.ffi}.

@(render-ffi-docs "ffi/domrect.ffi" "domrect.ffi")
