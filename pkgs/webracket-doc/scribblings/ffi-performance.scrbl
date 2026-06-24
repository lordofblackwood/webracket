#lang scribble/manual

@(require "browser-api-docs.rkt"
          (lib "scribblings/ffi-performance-labels.rkt" "webracket-doc")
          (for-label (lib "scribblings/ffi-performance-labels.rkt" "webracket-doc")))

@title{Performance}
@declare-exporting[(lib "scribblings/ffi-performance-labels.rkt" "webracket-doc")]

This page documents the low-level @racket[js-performance-*] bindings
from @tt{ffi/performance.ffi}.

@(render-ffi-docs "ffi/performance.ffi" "performance.ffi")
