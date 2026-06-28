#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-intersection-observer-labels.rkt" "webracket-doc")
                     browser/document
                     browser/element)
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[intersection-observer]}
@declare-exporting[(lib "scribblings/lib-intersection-observer-labels.rkt" "webracket-doc")]

@defmodule[intersection-observer]

The @racketmodname[intersection-observer] module wraps the browser
@tt{IntersectionObserver} API. It is useful when code should react to
whether an element is visible inside the viewport or inside a custom root.

@(mdn-bar "Intersection Observer API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API")

@section{Quick Start}

@racketblock[
(require browser/document
         browser/dom
         intersection-observer)

(define target
  (document-query-selector "#watched"))

(define observer
  (make-intersection-observer
   (lambda (entries _observer)
     (define first-entry (vector-ref entries 0))
     (when (intersection-observer-entry-is-intersecting? first-entry)
       (js-log "target is visible")))))

(intersection-observer-observe! observer target)
]

Use @racketmodname[intersection-observer] when you want to:

@itemlist[
  @item{observe whether an element enters or leaves view}
  @item{react to browser-generated visibility changes instead of polling}
  @item{inspect wrapped @tt{IntersectionObserverEntry} values}
]

@section{API}

@defproc[(intersection-observer-supported?) boolean?]{
Returns @racket[#t] when the browser exposes @tt{IntersectionObserver}.
}

@defproc[(intersection-observer [raw external/raw]) intersection-observer?]{
Wraps a raw browser @tt{IntersectionObserver} value.
}

@defproc[(intersection-observer? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a wrapped observer.
}

@defproc[(intersection-observer-raw [value intersection-observer?]) external/raw]{
Returns the wrapped raw browser observer.
}

@defproc[(make-intersection-observer-options [root (or/c #f dom-element? external?) #f]
                                             [root-margin (or/c #f string? symbol?) #f]
                                             [threshold (or/c #f real? vector?) #f])
         intersection-observer-options?]{
Creates constructor options for @tt{IntersectionObserver}.
}

@defproc[(make-intersection-observer [callback (or/c procedure? external?)]
                                     [options (or/c #f intersection-observer-options?) #f])
         intersection-observer?]{
Creates a wrapped browser observer. The callback receives a vector of
@racket[intersection-observer-entry?] values and the wrapped observer.
}

@defproc[(intersection-observer-observe! [observer intersection-observer?]
                                         [target (or/c dom-element? external?)])
         void?]{
Starts observing @racket[target].
}

@defproc[(intersection-observer-unobserve! [observer intersection-observer?]
                                           [target (or/c dom-element? external?)])
         void?]{
Stops observing @racket[target].
}

@defproc[(intersection-observer-disconnect! [observer intersection-observer?]) void?]{
Disconnects the observer from all targets.
}

@defstruct[intersection-observer-entry ([raw external/raw])]{
Wraps a browser @tt{IntersectionObserverEntry} value.
}

@defproc[(intersection-observer-entry-target [entry intersection-observer-entry?]) dom-element?]{
Returns the observed target element.
}

@defproc[(intersection-observer-entry-is-intersecting? [entry intersection-observer-entry?]) boolean?]{
Reports whether the target currently intersects the root.
}

@defproc[(intersection-observer-entry-intersection-ratio [entry intersection-observer-entry?]) real?]{
Returns the current intersection ratio.
}

@defproc[(intersection-observer-entry-bounding-client-rect [entry intersection-observer-entry?]) dom-rect?]{
Returns the target bounding rectangle.
}

@defproc[(intersection-observer-entry-intersection-rect [entry intersection-observer-entry?]) dom-rect?]{
Returns the current intersection rectangle.
}

@defproc[(intersection-observer-entry-root-bounds [entry intersection-observer-entry?]) (or/c #f dom-rect?)]{
Returns the root bounds when the browser provides them.
}

@defproc[(intersection-observer-entry-time [entry intersection-observer-entry?]) real?]{
Returns the browser timestamp for the observation.
}
