#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-screen-orientation-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[screen-orientation]}
@declare-exporting[(lib "scribblings/lib-screen-orientation-labels.rkt" "webracket-doc")]

@defmodule[screen-orientation]

The @racketmodname[screen-orientation] module wraps the browser
@tt{screen.orientation} object. Use it to read the current orientation,
watch for orientation changes, and request an orientation lock when the
browser allows it.

@(mdn-bar "Screen Orientation API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Screen_Orientation_API")

@bold{Read MDN first.} Screen-orientation locking has browser and context
restrictions. In particular, MDN notes that locking is usually limited to
mobile devices and browsers commonly require fullscreen or a similar
installed-app context.

@section{Screen Orientation Quick Start}

@racketblock[
(require browser/dom
         screen-orientation)

(define orientation (screen-orientation))

(when orientation
  (js-log (screen-orientation-type orientation))
  (screen-orientation-add-change-listener!
   orientation
   (lambda (_event)
     (js-log (screen-orientation-type orientation))
     (void))))
]

@section{Screen Orientation API}

@defproc[(screen-orientation-supported?) boolean?]{
@(mdn-bar "Screen: orientation property"
          "https://developer.mozilla.org/en-US/docs/Web/API/Screen/orientation")
Returns @racket[#t] when @tt{screen.orientation} is available.
}

@defproc[(screen-orientation) (or/c #f screen-orientation?)]{
Returns the current @tt{ScreenOrientation} object wrapped in a checked
value, or @racket[#f] when unsupported.
}

@defproc[(screen-orientation? [v any/c]) boolean?]{
Returns @racket[#t] for wrapped @tt{ScreenOrientation} values.
}

@defproc[(screen-orientation-raw [value screen-orientation?]) external/raw]{
Returns the wrapped raw browser object.
}

@defproc[(screen-orientation-type [value screen-orientation?]) string?]{
@(mdn-bar "ScreenOrientation: type property"
          "https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/type")
Returns an orientation type such as @racket["portrait-primary"] or
@racket["landscape-primary"].
}

@defproc[(screen-orientation-angle [value screen-orientation?]) number?]{
@(mdn-bar "ScreenOrientation: angle property"
          "https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/angle")
Returns the orientation angle in degrees.
}

@defproc[(screen-orientation-lock-type? [v any/c]) boolean?]{
Returns @racket[#t] for strings or symbols accepted by
@tt{ScreenOrientation.lock}: @racket['any], @racket['natural],
@racket['landscape], @racket['portrait], @racket['portrait-primary],
@racket['portrait-secondary], @racket['landscape-primary], and
@racket['landscape-secondary].
}

@defproc[(screen-orientation-lock! [value screen-orientation?]
                                  [lock-type screen-orientation-lock-type?])
         js-promise?]{
@(mdn-bar "ScreenOrientation: lock() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/lock")
Requests an orientation lock and returns the browser Promise.
}

@defproc[(screen-orientation-unlock! [value screen-orientation?]) void?]{
@(mdn-bar "ScreenOrientation: unlock() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/unlock")
Removes an active orientation lock.
}

@defproc[(screen-orientation-on-change! [value screen-orientation?]
                                        [callback (or/c procedure? external? #f)])
         void?]{
Sets the @tt{onchange} handler. Pass @racket[#f] to clear it.
}

@defproc[(screen-orientation-add-change-listener! [value screen-orientation?]
                                                  [callback (or/c procedure? external?)])
         external/raw]{
Adds a @tt{change} listener and returns the installed external callback.
}

@defproc[(screen-orientation-remove-change-listener! [value screen-orientation?]
                                                     [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed @tt{change} listener.
}
