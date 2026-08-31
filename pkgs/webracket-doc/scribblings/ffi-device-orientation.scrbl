#lang scribble/manual

@(require "browser-api-docs.rkt"
          (for-label (lib "scribblings/ffi-device-orientation-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-device-orientation-labels.rkt" "webracket-doc")))

@title{Device Orientation and Motion API}
@declare-exporting[(lib "scribblings/ffi-device-orientation-labels.rkt" "webracket-doc")]

This page documents the low-level static @racket[js-device-orientation-*] and
@racket[js-device-motion-*] bindings in @tt{ffi/device-orientation.ffi}. Each
import has a fixed browser operation: support check, permission request, event
name, or sensor field. Ordinary programs should use the checked
@racketid[device-orientation] library chapter instead.

The nullable sensor fields cross the boundary as FASL values: a finite number
when available and @racket[#f] when the browser reports @tt{null}. Permission
requests return raw browser Promises. Their fulfilled values are normal strings
that the public @racket[device-orientation-permission-status] procedure turns
into symbols.

@(render-ffi-docs "ffi/device-orientation.ffi" "device-orientation.ffi")
