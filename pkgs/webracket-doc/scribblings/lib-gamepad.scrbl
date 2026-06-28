#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-gamepad-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[gamepad]}
@declare-exporting[(lib "scribblings/lib-gamepad-labels.rkt" "webracket-doc")]

@defmodule[gamepad]

The @racketmodname[gamepad] module wraps the browser Gamepad API:
polling @tt{navigator.getGamepads}, reading axes/buttons, and listening
for connect/disconnect events.

@(mdn-bar "Gamepad API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API")

@bold{Read MDN first.} Browsers do not expose gamepad state until the user
has interacted with the page or pressed a button on a connected gamepad.
The live state is normally polled from an animation loop.

@section{Gamepad Quick Start}

@racketblock[
(require browser/dom
         gamepad)

(when (gamepad-supported?)
  (gamepad-add-connected-listener!
   (lambda (event)
     (define gp (gamepad-event-gamepad event))
     (when gp
       (js-log (gamepad-id gp)))
     (void))))
]

@section{Gamepad API}

@defproc[(gamepad-supported?) boolean?]{
@(mdn-bar "Navigator: getGamepads() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Navigator/getGamepads")
Returns @racket[#t] when @tt{navigator.getGamepads} is available.
}

@defproc[(gamepads) vector?]{
Returns a vector of current gamepad slots. Disconnected or empty slots are
represented as @racket[#f], matching the nullable slots in the browser API.
}

@defproc[(gamepad? [v any/c]) boolean?]{
Returns @racket[#t] for wrapped @tt{Gamepad} values.
}

@defproc[(gamepad-raw [value gamepad?]) external/raw]{
Returns the wrapped raw @tt{Gamepad} object.
}

@defproc[(gamepad-event-gamepad [event external/raw]) (or/c #f gamepad?)]{
Extracts the wrapped @tt{Gamepad} from a @tt{gamepadconnected} or
@tt{gamepaddisconnected} event.
}

@defproc[(gamepad-id [value gamepad?]) string?]{Returns the gamepad id string.}
@defproc[(gamepad-index [value gamepad?]) exact-nonnegative-integer?]{Returns the gamepad slot index.}
@defproc[(gamepad-connected? [value gamepad?]) boolean?]{Returns whether the gamepad is connected.}
@defproc[(gamepad-timestamp [value gamepad?]) number?]{Returns the browser gamepad timestamp.}
@defproc[(gamepad-mapping [value gamepad?]) string?]{Returns the mapping string, commonly @racket["standard"].}
@defproc[(gamepad-axes [value gamepad?]) vector?]{Returns axis values as numbers.}
@defproc[(gamepad-buttons [value gamepad?]) vector?]{Returns wrapped @tt{GamepadButton} values.}

@defproc[(gamepad-button? [v any/c]) boolean?]{
Returns @racket[#t] for wrapped @tt{GamepadButton} values.
}

@defproc[(gamepad-button-raw [value gamepad-button?]) external/raw]{
Returns the wrapped raw @tt{GamepadButton} object.
}

@defproc[(gamepad-button-pressed? [value gamepad-button?]) boolean?]{Returns whether the button is pressed.}
@defproc[(gamepad-button-touched? [value gamepad-button?]) boolean?]{Returns whether the button is touched.}
@defproc[(gamepad-button-value [value gamepad-button?]) number?]{Returns the analog button value between @racket[0] and @racket[1].}

@defproc[(gamepad-add-connected-listener! [callback (or/c procedure? external?)])
         external/raw]{
Adds a @tt{gamepadconnected} listener to @tt{window}.
}

@defproc[(gamepad-remove-connected-listener! [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed @tt{gamepadconnected} listener.
}

@defproc[(gamepad-add-disconnected-listener! [callback (or/c procedure? external?)])
         external/raw]{
Adds a @tt{gamepaddisconnected} listener to @tt{window}.
}

@defproc[(gamepad-remove-disconnected-listener! [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed @tt{gamepaddisconnected} listener.
}
