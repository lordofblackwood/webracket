#lang scribble/manual

@(require "browser-api-docs.rkt"
          (lib "scribblings/ffi-document-labels.rkt" "webracket-doc")
          (for-label (lib "scribblings/ffi-document-labels.rkt" "webracket-doc")))

@title{Document}
@declare-exporting[(lib "scribblings/ffi-document-labels.rkt" "webracket-doc")]

This page documents the low-level @racket[js-document-*] bindings from
@tt{ffi/document.ffi}.

@(render-ffi-docs "ffi/document.ffi" "document.ffi")
