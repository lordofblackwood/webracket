#lang scribble/manual

@(require "browser-api-docs.rkt"
          (lib "scribblings/ffi-window-labels.rkt" "webracket-doc")
          (for-label (lib "scribblings/ffi-window-labels.rkt" "webracket-doc")))

@title{Window}
@declare-exporting[(lib "scribblings/ffi-window-labels.rkt" "webracket-doc")]

The Window API is the browser entry point for dialogs, timers, scrolling,
and access to the current document.

This page documents the low-level @racket[js-window-*] bindings from
@tt{ffi/window.ffi}.

@(render-ffi-docs "ffi/window.ffi" "window.ffi")
