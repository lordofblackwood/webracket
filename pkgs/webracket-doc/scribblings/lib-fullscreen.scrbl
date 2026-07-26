#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-fullscreen-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-element-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[fullscreen]}
@declare-exporting[(lib "scribblings/lib-fullscreen-labels.rkt" "webracket-doc")]

@defmodule[fullscreen]

@(warning-bar
  (bold "Safari warning. ")
  "Do not expect this wrapper to work in Safari. "
  "MDN marks the Fullscreen API as "
  (bold "Limited availability")
  ", and Safari is the main browser to treat as unavailable here.")

The @racketmodname[fullscreen] module wraps the browser Fullscreen API
for the current document and its elements.

@(mdn-bar "Fullscreen API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API")

@bold{Read the MDN page first.} The wrapper below shows the WebRacket
surface, while the MDN documentation explains permission rules, user
activation requirements, and browser differences around fullscreen
behavior.

Use @racketmodname[fullscreen] when you want to:

@itemlist[
  @item{check whether fullscreen requests are available}
  @item{read the current fullscreen element}
  @item{request fullscreen for a specific element}
  @item{exit fullscreen and listen for @tt{fullscreenchange}}
]

@section{Fullscreen Quick Start}

@racketblock[
(require browser/document
         fullscreen)

(define panel (document-get-element-by-id "panel"))

(when panel
  (fullscreen-request! panel))
]

@section{Fullscreen API}

@defproc[(fullscreen-supported?) boolean?]{
Returns @racket[#t] when the current document exposes the core
Fullscreen API methods used by this wrapper.
}

@defproc[(fullscreen-enabled?) boolean?]{
@(mdn-bar "Document: fullscreenEnabled property"
          "https://developer.mozilla.org/en-US/docs/Web/API/Document/fullscreenEnabled")
Returns the current document's @tt{fullscreenEnabled} value.
}

@defproc[(fullscreen-element) (or/c #f dom-element?)]{
@(mdn-bar "Document: fullscreenElement property"
          "https://developer.mozilla.org/en-US/docs/Web/API/Document/fullscreenElement")
Returns the current fullscreen element, or @racket[#f] when no element
is active.
}

@defproc[(fullscreen-active?) boolean?]{
Returns @racket[#t] when @racket[(fullscreen-element)] is non-@racket[#f].
}

@defproc[(fullscreen-request! [element (or/c dom-element? external?)]) js-promise?]{
@(mdn-bar "Element: requestFullscreen() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Element/requestFullscreen")
Requests fullscreen display for @racket[element] and returns the browser
Promise as a wrapped @racket[js-promise?].
}

@defproc[(fullscreen-exit!) js-promise?]{
@(mdn-bar "Document: exitFullscreen() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Document/exitFullscreen")
Requests exit from fullscreen mode and returns the browser Promise as a
wrapped @racket[js-promise?].
}

@defproc[(fullscreen-add-change-listener! [callback (or/c procedure? external?)])
         external/raw]{
@(mdn-bar "Document: fullscreenchange event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Document/fullscreenchange_event")
Adds a @tt{fullscreenchange} listener to the current document and
returns the installed callback value.
}

@defproc[(fullscreen-remove-change-listener! [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed @tt{fullscreenchange} listener.
}

@defproc[(fullscreen-add-error-listener! [callback (or/c procedure? external?)])
         external/raw]{
@(mdn-bar "Document: fullscreenerror event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Document/fullscreenerror_event")
Adds a @tt{fullscreenerror} listener to the current document and
returns the installed callback value.
}

@defproc[(fullscreen-remove-error-listener! [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed @tt{fullscreenerror} listener.
}
