#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-web-midi-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))
          "browser-api-docs.rkt"
          "webracket-scribble-utils.rkt")

@title{Library: @racketmodname[web-midi]}
@declare-exporting[(lib "scribblings/lib-web-midi-labels.rkt" "webracket-doc")]

@defmodule[web-midi]

@nested[#:style 'inset]{
 @bold{Important: read the MDN Web MIDI API documentation before using this library.}
 Web MIDI has limited browser availability, requires a secure context, and access
 may be blocked by Permission Policy or denied by the user. Request access from
 a user action when a browser may show a permission prompt.

 @(mdn-bar "Web MIDI API"
           "https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API")}

This module provides checked wrappers for a static, practical subset of the Web
MIDI API: requesting @tt{MIDIAccess}, listing and looking up input and output
ports, inspecting port metadata and state, opening or closing ports, receiving
input messages, reacting to port changes, and sending byte-string messages.

The imports come from @tt{ffi/web-midi.ffi}. Each is a fixed browser operation;
the public API does not send JavaScript property names, event names, or arbitrary
options objects across the boundary.

@section{Scope}

@racket[web-midi-request-access] exposes the standard @tt{sysex} and
@tt{software} request flags as booleans. The defaults are @racket[#f]. Passing
@racket[#t] for @racket[sysex?] asks for the more sensitive system-exclusive
MIDI permission. The browser still decides whether to grant it; inspect the
fulfilled access value with @racket[web-midi-access-sysex-enabled?].

Port IDs are browser-assigned opaque strings. The input and output ID procedures
return a snapshot vector, so request it again after a state-change event. This
first wrapper deliberately does not expose the generic map-like JavaScript
objects, arbitrary event names, or non-MIDI typed-array values.

@section{Quick Start}

Every access request and port open/close operation returns a @racket[js-promise?].
The value delivered to a Promise callback is raw; wrap it before calling the
checked procedures. Input listeners similarly receive a raw event, which must be
wrapped before reading its byte string.

@racketblock[
(require web-midi js/promise)

(define (report-message raw-event)
  (define event (web-midi-message-event-wrap raw-event))
  (displayln (web-midi-message-event-data event))
  (void))

(js-promise-then
 (web-midi-request-access)
 (lambda (raw-access)
   (define access (web-midi-access-wrap raw-access))
   (define input-ids (web-midi-access-input-port-ids access))
   (when (positive? (vector-length input-ids))
     (define input
       (web-midi-access-input access (vector-ref input-ids 0)))
     (when input
       (web-midi-input-add-message-listener! input report-message)))
   (void))
 (lambda (_reason) (void)))
(void)
]

@bold{Promise callbacks cross a FASL boundary.} Schedule any next
@racket[js-promise?] operation in the callback, then return @racket[(void)].
Likewise, an event listener should finish with @racket[(void)].

@section{Availability and Input Types}

@defproc[(web-midi-supported?) boolean?]{
Reports whether @tt{navigator.requestMIDIAccess()} exists. It does not mean the
browser will grant access, that a device is connected, or that system-exclusive
messages are permitted.
}

@defproc[(web-midi-message? [value any/c]) boolean?]{
Recognizes output messages accepted by this library: nonempty byte strings.
Every byte is already an unsigned octet; the browser validates MIDI semantics
and system-exclusive permission when @racket[web-midi-output-send!] is called.
}

@defproc[(web-midi-timestamp? [value any/c]) boolean?]{
Recognizes finite nonnegative timestamps accepted by the optional third argument
of @racket[web-midi-output-send!]. The timestamp uses the browser's time base;
omitting it sends immediately.
}

@section{Access Values}

@defproc[(web-midi-access? [value any/c]) boolean?]{
Recognizes wrapped @tt{MIDIAccess} values.
}

@defproc[(web-midi-access-wrap [raw external/raw]) web-midi-access?]{
Validates the raw result received by a successful
@racket[web-midi-request-access] Promise callback.
}

@defproc[(web-midi-request-access [sysex? boolean? #f] [software? boolean? #f])
         js-promise?]{
@(mdn-bar "Navigator: requestMIDIAccess()"
          "https://developer.mozilla.org/en-US/docs/Web/API/Navigator/requestMIDIAccess")
Requests MIDI access. The Promise fulfills with a raw @tt{MIDIAccess} object;
pass that value to @racket[web-midi-access-wrap]. With the default flags, the
request does not ask for system-exclusive messages or software synthesizer ports.
}

@defproc[(web-midi-access-sysex-enabled? [access web-midi-access?]) boolean?]{
Reports whether this granted access value allows system-exclusive messages.
}

@defproc[(web-midi-access-input-port-ids [access web-midi-access?]) vector?]{
@(mdn-bar "MIDIAccess: inputs"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIAccess/inputs")
Returns a snapshot vector whose elements are the current input-port ID strings.
Use an element with @racket[web-midi-access-input].
}

@defproc[(web-midi-access-output-port-ids [access web-midi-access?]) vector?]{
@(mdn-bar "MIDIAccess: outputs"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIAccess/outputs")
Returns a snapshot vector whose elements are the current output-port ID strings.
Use an element with @racket[web-midi-access-output].
}

@defproc[(web-midi-access-input [access web-midi-access?] [id string?])
         (or/c #f web-midi-input?)]{
Looks up an input by one of the strings returned by
@racket[web-midi-access-input-port-ids]. Returns @racket[#f] when that port is
no longer present.
}

@defproc[(web-midi-access-output [access web-midi-access?] [id string?])
         (or/c #f web-midi-output?)]{
Looks up an output by one of the strings returned by
@racket[web-midi-access-output-port-ids]. Returns @racket[#f] when that port is
no longer present.
}

@section{Ports}

@defproc[(web-midi-input? [value any/c]) boolean?]{
Recognizes wrapped @tt{MIDIInput} ports.
}

@defproc[(web-midi-output? [value any/c]) boolean?]{
Recognizes wrapped @tt{MIDIOutput} ports.
}

@defproc[(web-midi-port? [value any/c]) boolean?]{
Recognizes a wrapped MIDI input or output port.
}

@defproc[(web-midi-input-wrap [raw external/raw]) web-midi-input?]{
Validates a raw @tt{MIDIInput} value from a lookup or connection event.
}

@defproc[(web-midi-output-wrap [raw external/raw]) web-midi-output?]{
Validates a raw @tt{MIDIOutput} value from a lookup or connection event.
}

@defproc[(web-midi-port-wrap [raw external/raw]) web-midi-port?]{
Validates a raw MIDI input or output when the port kind is not known in advance.
}

@defproc[(web-midi-port-id [port web-midi-port?]) string?]{
@(mdn-bar "MIDIPort: id"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIPort/id")
Returns the browser-assigned port ID used by the lookup procedures.
}

@defproc[(web-midi-port-name [port web-midi-port?]) (or/c #f string?)]{
Returns the browser-provided port name, or @racket[#f] when it is unavailable.
}

@defproc[(web-midi-port-manufacturer [port web-midi-port?]) (or/c #f string?)]{
Returns the browser-provided manufacturer name, or @racket[#f].
}

@defproc[(web-midi-port-version [port web-midi-port?]) (or/c #f string?)]{
Returns the browser-provided port version, or @racket[#f].
}

@defproc[(web-midi-port-state [port web-midi-port?])
         (or/c 'connected 'disconnected)]{
@(mdn-bar "MIDIPort: state"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIPort/state")
Returns @racket['connected] when the port is available to the system and
@racket['disconnected] otherwise.
}

@defproc[(web-midi-port-connection [port web-midi-port?])
         (or/c 'open 'closed 'pending)]{
@(mdn-bar "MIDIPort: connection"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIPort/connection")
Returns @racket['open], @racket['closed], or @racket['pending].
}

@defproc[(web-midi-port-open [port web-midi-port?]) js-promise?]{
@(mdn-bar "MIDIPort: open()"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIPort/open")
Returns the browser Promise for opening an input or output port.
}

@defproc[(web-midi-port-close [port web-midi-port?]) js-promise?]{
@(mdn-bar "MIDIPort: close()"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIPort/close")
Returns the browser Promise for closing an input or output port.
}

@section{Messages and Events}

@defproc[(web-midi-output-send!
          [output web-midi-output?]
          [message web-midi-message?]
          [timestamp (or/c #f web-midi-timestamp?) #f])
         void?]{
@(mdn-bar "MIDIOutput: send()"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIOutput/send")
Sends @racket[message] immediately when @racket[timestamp] is @racket[#f], or
schedules it at the supplied browser timestamp. A system-exclusive message needs
access granted with @racket[sysex?] enabled.
}

@defproc[(web-midi-message-event? [value any/c]) boolean?]{
Recognizes wrapped @tt{MIDIMessageEvent} values.
}

@defproc[(web-midi-message-event-wrap [raw external/raw]) web-midi-message-event?]{
Validates the one raw event argument supplied to an input-message callback.
}

@defproc[(web-midi-message-event-data [event web-midi-message-event?]) bytes?]{
@(mdn-bar "MIDIMessageEvent: data"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIMessageEvent/data")
Returns the input message's byte string.
}

@defproc[(web-midi-input-add-message-listener!
          [input web-midi-input?]
          [callback procedure?])
         external/raw]{
@(mdn-bar "MIDIInput: midimessage event"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIInput/midimessage_event")
Adds @racket[callback] for @tt{midimessage}. The callback receives exactly one
raw @tt{MIDIMessageEvent}; use @racket[web-midi-message-event-wrap] before
reading it. Returns the stable browser callback that was installed.
}

@defproc[(web-midi-input-remove-message-listener!
          [input web-midi-input?]
          [callback procedure?])
         void?]{
Removes the listener installed with the same Racket procedure value.
}

@defproc[(web-midi-connection-event? [value any/c]) boolean?]{
Recognizes wrapped @tt{MIDIConnectionEvent} values.
}

@defproc[(web-midi-connection-event-wrap [raw external/raw])
         web-midi-connection-event?]{
Validates the one raw event argument supplied to a MIDI access state-change
callback.
}

@defproc[(web-midi-connection-event-port [event web-midi-connection-event?])
         web-midi-port?]{
@(mdn-bar "MIDIConnectionEvent: port"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIConnectionEvent/port")
Returns the wrapped input or output port whose state changed.
}

@defproc[(web-midi-access-add-state-change-listener!
          [access web-midi-access?]
          [callback procedure?])
         external/raw]{
@(mdn-bar "MIDIAccess: statechange event"
          "https://developer.mozilla.org/en-US/docs/Web/API/MIDIAccess/statechange_event")
Adds @racket[callback] for port connection changes. The callback receives exactly
one raw @tt{MIDIConnectionEvent}; wrap it with
@racket[web-midi-connection-event-wrap].
}

@defproc[(web-midi-access-remove-state-change-listener!
          [access web-midi-access?]
          [callback procedure?])
         void?]{
Removes the listener installed with the same Racket procedure value.
}
