#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-device-orientation-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))
          "browser-api-docs.rkt"
          "webracket-scribble-utils.rkt")

@title{Library: @racketmodname[device-orientation]}
@declare-exporting[(lib "scribblings/lib-device-orientation-labels.rkt" "webracket-doc")]

@defmodule[device-orientation]

@nested[#:style 'inset]{
 @bold{Important: read the MDN Device Orientation Events documentation before using this library.}
 Sensor data is available only in secure contexts. Some browsers require a
 permission request triggered directly by a user action, and desktop browsers
 commonly have no sensor hardware to report. Check support at run time and make
 permission requests from a button or another user-activated event.

 @(mdn-bar "Device orientation events"
           "https://developer.mozilla.org/en-US/docs/Web/API/Device_orientation_events")}

This library provides checked wrappers for the practical event-driven subset of
the Device Orientation and Motion API: availability and permission checks,
fixed listeners for the three browser event types, orientation angles, Safari's
optional compass data, acceleration, gravity-inclusive acceleration, rotation
rate, and the sampling interval.

The static imports come from @tt{ffi/device-orientation.ffi}. Browser property
names and event names remain in the JavaScript helper rather than crossing the
Racket/JavaScript boundary dynamically.

@section{Quick Start}

The callbacks receive a raw browser event. Wrap that event immediately before
reading its checked numeric fields. On browsers that do not expose
@tt{requestPermission()}, start listening directly; that absence means the
extra request is not needed or not provided, not that sensors are available.

@racketblock[
(require device-orientation
         js/promise)

(define (show-orientation raw-event)
  (define event (device-orientation-event-wrap raw-event))
  (printf "alpha: ~a, beta: ~a, gamma: ~a~n"
          (device-orientation-event-alpha event)
          (device-orientation-event-beta event)
          (device-orientation-event-gamma event))
  (void))

(define (start!)
  (device-orientation-add-listener! show-orientation)
  (void))

(when (device-orientation-supported?)
  (if (device-orientation-permission-requestable?)
      (js-promise-then
       (device-orientation-request-permission)
       (lambda (raw-status)
         (when (eq? (device-orientation-permission-status raw-status) 'granted)
           (start!))
         (void)))
      (start!)))
]

@bold{Permission requests must come from a user action.} Put the request in a
button-click handler when the browser can prompt. The @racket[js-promise?]
success callback should finish with @racket[(void)], as should every sensor
listener.

@section{Availability and Permission}

@defproc[(device-orientation-supported?) boolean?]{
Reports whether the @tt{DeviceOrientationEvent} constructor is present. It does
not mean the browser has sensor hardware or will produce non-@racket[#f]
angles.
}

@defproc[(device-motion-supported?) boolean?]{
Reports whether the @tt{DeviceMotionEvent} constructor is present. It does not
guarantee that acceleration or rotation-rate readings are available.
}

@defproc[(device-orientation-permission-requestable?) boolean?]{
@(mdn-bar "DeviceOrientationEvent: requestPermission()"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/requestPermission_static")
Reports whether this browser exposes the nonstandard-but-important
@tt{DeviceOrientationEvent.requestPermission()} method. Check this before
calling @racket[device-orientation-request-permission].
}

@defproc[(device-motion-permission-requestable?) boolean?]{
@(mdn-bar "DeviceMotionEvent: requestPermission()"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceMotionEvent/requestPermission_static")
Reports whether this browser exposes @tt{DeviceMotionEvent.requestPermission()}.
Check this before calling @racket[device-motion-request-permission].
}

@defproc[(device-orientation-request-permission [absolute? boolean? #f])
         js-promise?]{
Requests orientation permission and returns the browser Promise. When
@racket[absolute?] is @racket[#t], the browser also requests magnetometer data
for absolute orientation. The Promise fulfills with a string accepted by
@racket[device-orientation-permission-status]. This procedure raises an error
when @racket[device-orientation-permission-requestable?] is @racket[#f].
}

@defproc[(device-motion-request-permission) js-promise?]{
Requests motion permission and returns the browser Promise. The Promise
fulfills with a string accepted by @racket[device-orientation-permission-status].
This procedure raises an error when
@racket[device-motion-permission-requestable?] is @racket[#f].
}

@defproc[(device-orientation-permission-status [value (or/c string? symbol?)])
         (or/c 'granted 'denied)]{
Converts the fulfilled permission result to @racket['granted] or
@racket['denied], and raises an error for any other value.
}

@section{Events and Listeners}

@defproc[(device-orientation-event? [value any/c]) boolean?]{
Recognizes a wrapped @tt{DeviceOrientationEvent}. As a predicate, it accepts
every Racket value.
}

@defproc[(device-motion-event? [value any/c]) boolean?]{
Recognizes a wrapped @tt{DeviceMotionEvent}. As a predicate, it accepts every
Racket value.
}

@defproc[(device-orientation-event-wrap [raw external/raw])
         device-orientation-event?]{
Validates the raw event delivered to an orientation or absolute-orientation
listener.
}

@defproc[(device-motion-event-wrap [raw external/raw]) device-motion-event?]{
Validates the raw event delivered to a motion listener.
}

@defproc[(device-orientation-add-listener! [callback procedure?]) void?]{
@(mdn-bar "Window: deviceorientation event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/deviceorientation_event")
Adds @racket[callback] for @tt{deviceorientation}. The callback receives one
raw event; use @racket[device-orientation-event-wrap] before inspecting it.
}

@defproc[(device-orientation-remove-listener! [callback procedure?]) void?]{
Removes the same procedure previously passed to
@racket[device-orientation-add-listener!].
}

@defproc[(device-orientation-add-absolute-listener! [callback procedure?]) void?]{
@(mdn-bar "Window: deviceorientationabsolute event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/deviceorientationabsolute_event")
Adds @racket[callback] for @tt{deviceorientationabsolute}. The event still uses
@racket[device-orientation-event-wrap].
}

@defproc[(device-orientation-remove-absolute-listener! [callback procedure?]) void?]{
Removes the same procedure previously passed to
@racket[device-orientation-add-absolute-listener!].
}

@defproc[(device-motion-add-listener! [callback procedure?]) void?]{
@(mdn-bar "Window: devicemotion event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/devicemotion_event")
Adds @racket[callback] for @tt{devicemotion}. The callback receives one raw
event; use @racket[device-motion-event-wrap] before inspecting it.
}

@defproc[(device-motion-remove-listener! [callback procedure?]) void?]{
Removes the same procedure previously passed to
@racket[device-motion-add-listener!].
}

@section{Orientation Readings}

Each optional reading below returns @racket[#f] when the browser's event field
is @tt{null}; otherwise it returns a finite real number. Angles are in degrees.

@defproc[(device-orientation-event-absolute? [event device-orientation-event?])
         boolean?]{
@(mdn-bar "DeviceOrientationEvent: absolute"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/absolute")
Reports whether the event uses the Earth coordinate frame.
}

@defproc[(device-orientation-event-alpha [event device-orientation-event?])
         (or/c #f real?)]{
@(mdn-bar "DeviceOrientationEvent: alpha"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/alpha")
Returns the orientation around the z axis, normally from 0 inclusive to 360
exclusive.
}

@defproc[(device-orientation-event-beta [event device-orientation-event?])
         (or/c #f real?)]{
@(mdn-bar "DeviceOrientationEvent: beta"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/beta")
Returns the orientation around the x axis, normally from -180 inclusive to 180
inclusive.
}

@defproc[(device-orientation-event-gamma [event device-orientation-event?])
         (or/c #f real?)]{
@(mdn-bar "DeviceOrientationEvent: gamma"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/gamma")
Returns the orientation around the y axis, normally from -90 inclusive to 90
inclusive.
}

@defproc[(device-orientation-event-compass-heading [event device-orientation-event?])
         (or/c #f real?)]{
Returns Safari's optional @tt{webkitCompassHeading} reading in degrees, or
@racket[#f] when it is not supplied.
}

@defproc[(device-orientation-event-compass-accuracy [event device-orientation-event?])
         (or/c #f real?)]{
Returns Safari's optional @tt{webkitCompassAccuracy} reading in degrees, or
@racket[#f] when it is not supplied.
}

@section{Motion Readings}

The acceleration and rotation-rate procedures all return @racket[#f] when the
corresponding browser field is @tt{null}; otherwise they return a finite real
number. Acceleration units are meters per second squared and rotation-rate units
are degrees per second.

@defproc[(device-motion-event-acceleration-x [event device-motion-event?])
         (or/c #f real?)]{Returns acceleration without gravity along the x axis.}

@defproc[(device-motion-event-acceleration-y [event device-motion-event?])
         (or/c #f real?)]{Returns acceleration without gravity along the y axis.}

@defproc[(device-motion-event-acceleration-z [event device-motion-event?])
         (or/c #f real?)]{Returns acceleration without gravity along the z axis.}

@defproc[(device-motion-event-gravity-acceleration-x [event device-motion-event?])
         (or/c #f real?)]{Returns gravity-inclusive acceleration along the x axis.}

@defproc[(device-motion-event-gravity-acceleration-y [event device-motion-event?])
         (or/c #f real?)]{Returns gravity-inclusive acceleration along the y axis.}

@defproc[(device-motion-event-gravity-acceleration-z [event device-motion-event?])
         (or/c #f real?)]{Returns gravity-inclusive acceleration along the z axis.}

@defproc[(device-motion-event-rotation-alpha [event device-motion-event?])
         (or/c #f real?)]{Returns the rotation rate around the z axis.}

@defproc[(device-motion-event-rotation-beta [event device-motion-event?])
         (or/c #f real?)]{Returns the rotation rate around the x axis.}

@defproc[(device-motion-event-rotation-gamma [event device-motion-event?])
         (or/c #f real?)]{Returns the rotation rate around the y axis.}

@defproc[(device-motion-event-interval [event device-motion-event?]) real?]{
@(mdn-bar "DeviceMotionEvent: interval"
          "https://developer.mozilla.org/en-US/docs/Web/API/DeviceMotionEvent/interval")
Returns the finite sampling interval in milliseconds.
}
