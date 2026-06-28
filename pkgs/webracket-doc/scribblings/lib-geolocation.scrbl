#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-geolocation-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[geolocation]}
@declare-exporting[(lib "scribblings/lib-geolocation-labels.rkt" "webracket-doc")]

@defmodule[geolocation]

The @racketmodname[geolocation] module wraps the browser Geolocation API.
It provides a checked wrapper around @tt{navigator.geolocation} and
converts browser success/error callbacks into wrapped values.

@(mdn-bar "Geolocation API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API")

@bold{Important browser constraints}

@itemlist[
  @item{Geolocation normally requires HTTPS or localhost.}
  @item{Browsers may prompt the user before exposing location data.}
  @item{Position reads are asynchronous and callback-driven.}
]

@section{Quick Start}

@racketblock[
(require geolocation)

(define geo (geolocation))

(when geo
  (geolocation-get-current-position
   geo
   (lambda (position)
     (define coords
       (geolocation-position-coordinates position))
     (js-log (geolocation-coordinates-latitude coords)
             (geolocation-coordinates-longitude coords)))))
]

@section{API}

@defproc[(geolocation-supported?) boolean?]{
Returns @racket[#t] when the browser exposes @tt{navigator.geolocation}.
}

@defproc[(geolocation) (or/c #f geolocation?)]{
Returns the current browser geolocation object as a wrapped value, or
@racket[#f] when it is unavailable.
}

@defproc[(geolocation? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a wrapped geolocation object.
}

@defproc[(geolocation-raw [value geolocation?]) external/raw]{
Returns the wrapped raw browser geolocation object.
}

@defproc[(make-geolocation-options [enable-high-accuracy (or/c #f boolean?) #f]
                                   [timeout (or/c #f exact-nonnegative-integer?) #f]
                                   [maximum-age (or/c #f exact-nonnegative-integer?) #f])
         geolocation-options?]{
Creates options for current-position and watch-position requests.
}

@defproc[(geolocation-get-current-position [geo geolocation?]
                                           [on-success (or/c procedure? external?)]
                                           [on-error (or/c #f procedure? external?) #f]
                                           [options (or/c #f geolocation-options?) #f])
         void?]{
Starts an asynchronous current-position request.
}

@defproc[(geolocation-watch-position [geo geolocation?]
                                     [on-success (or/c procedure? external?)]
                                     [on-error (or/c #f procedure? external?) #f]
                                     [options (or/c #f geolocation-options?) #f])
         exact-nonnegative-integer?]{
Starts a watch request and returns the browser watch id.
}

@defproc[(geolocation-clear-watch! [geo geolocation?]
                                   [watch-id exact-nonnegative-integer?])
         void?]{
Stops a watch created by @racket[geolocation-watch-position].
}

@defstruct[geolocation-position ([raw external/raw])]{
Wraps a browser @tt{GeolocationPosition} value.
}

@defproc[(geolocation-position-coordinates [position geolocation-position?]) geolocation-coordinates?]{
Returns wrapped coordinate data.
}

@defproc[(geolocation-position-timestamp [position geolocation-position?]) real?]{
Returns the browser timestamp for the position.
}

@defstruct[geolocation-coordinates ([raw external/raw])]{
Wraps a browser @tt{GeolocationCoordinates} value.
}

@defproc[(geolocation-coordinates-latitude [coords geolocation-coordinates?]) real?]{
Returns the latitude.
}

@defproc[(geolocation-coordinates-longitude [coords geolocation-coordinates?]) real?]{
Returns the longitude.
}

@defproc[(geolocation-coordinates-accuracy [coords geolocation-coordinates?]) real?]{
Returns the horizontal accuracy in meters.
}

@defproc[(geolocation-coordinates-altitude [coords geolocation-coordinates?]) (or/c #f real?)]{
Returns the altitude when the browser provides it.
}

@defproc[(geolocation-coordinates-altitude-accuracy [coords geolocation-coordinates?]) (or/c #f real?)]{
Returns the altitude accuracy when the browser provides it.
}

@defproc[(geolocation-coordinates-heading [coords geolocation-coordinates?]) (or/c #f real?)]{
Returns the heading when the browser provides it.
}

@defproc[(geolocation-coordinates-speed [coords geolocation-coordinates?]) (or/c #f real?)]{
Returns the speed when the browser provides it.
}

@defstruct[geolocation-position-error ([raw external/raw])]{
Wraps a browser @tt{GeolocationPositionError} value.
}

@defproc[(geolocation-position-error-code [err geolocation-position-error?]) exact-nonnegative-integer?]{
Returns the browser error code.
}

@defproc[(geolocation-position-error-message [err geolocation-position-error?]) string?]{
Returns the browser error message.
}
