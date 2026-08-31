#lang webracket/base

(require js/promise
         webracket/unsafe/web-midi
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide web-midi-supported?
         web-midi-message?
         web-midi-timestamp?
         web-midi-access?
         web-midi-input?
         web-midi-output?
         web-midi-port?
         web-midi-message-event?
         web-midi-connection-event?
         web-midi-access-wrap
         web-midi-input-wrap
         web-midi-output-wrap
         web-midi-port-wrap
         web-midi-message-event-wrap
         web-midi-connection-event-wrap
         web-midi-request-access
         web-midi-access-sysex-enabled?
         web-midi-access-input-port-ids
         web-midi-access-output-port-ids
         web-midi-access-input
         web-midi-access-output
         web-midi-port-id
         web-midi-port-name
         web-midi-port-manufacturer
         web-midi-port-version
         web-midi-port-state
         web-midi-port-connection
         web-midi-port-open
         web-midi-port-close
         web-midi-output-send!
         web-midi-input-add-message-listener!
         web-midi-input-remove-message-listener!
         web-midi-access-add-state-change-listener!
         web-midi-access-remove-state-change-listener!
         web-midi-message-event-data
         web-midi-connection-event-port)

;; Browser values remain internal to the wrapper. Promise fulfillment and event
;; callbacks supply raw values, which the corresponding `...-wrap` procedure
;; validates before they enter the checked API.

;; web-midi-access-info : external/raw -> web-midi-access-info?
;;   Hold one browser MIDIAccess object.
(struct web-midi-access-info (raw) #:transparent)

;; web-midi-input-info : external/raw -> web-midi-input-info?
;;   Hold one browser MIDIInput port.
(struct web-midi-input-info (raw) #:transparent)

;; web-midi-output-info : external/raw -> web-midi-output-info?
;;   Hold one browser MIDIOutput port.
(struct web-midi-output-info (raw) #:transparent)

;; web-midi-message-event-info : external/raw -> web-midi-message-event-info?
;;   Hold one browser MIDIMessageEvent.
(struct web-midi-message-event-info (raw) #:transparent)

;; web-midi-connection-event-info : external/raw -> web-midi-connection-event-info?
;;   Hold one browser MIDIConnectionEvent.
(struct web-midi-connection-event-info (raw) #:transparent)

(define web-midi-callback-cache (make-hasheq))

;; web-midi-external? : any/c -> boolean?
;;   Recognize a browser value crossing the FFI boundary.
(define (web-midi-external? value)
  (external? value))

;; web-midi-message? : any/c -> boolean?
;;   Recognize nonempty MIDI byte messages accepted by MIDIOutput.send.
(define (web-midi-message? value)
  (and (bytes? value)
       (positive? (bytes-length value))))

;; web-midi-timestamp? : any/c -> boolean?
;;   Recognize finite nonnegative timestamps accepted by MIDIOutput.send.
(define (web-midi-timestamp? value)
  (and (real? value)
       (<= 0 value)
       (<= value 1.7976931348623157e308)))

;; web-midi-supported? : -> boolean?
;;   Report whether the browser exposes Navigator.requestMIDIAccess.
(define (web-midi-supported?)
  (js-web-midi-supported?))

;; web-midi-access? : any/c -> boolean?
;;   Report whether value wraps a browser MIDIAccess object.
(define (web-midi-access? value)
  (and (web-midi-access-info? value)
       (web-midi-external? (web-midi-access-info-raw value))
       (js-web-midi-access? (web-midi-access-info-raw value))))

;; web-midi-input? : any/c -> boolean?
;;   Report whether value wraps a browser MIDIInput port.
(define (web-midi-input? value)
  (and (web-midi-input-info? value)
       (web-midi-external? (web-midi-input-info-raw value))
       (js-web-midi-input? (web-midi-input-info-raw value))))

;; web-midi-output? : any/c -> boolean?
;;   Report whether value wraps a browser MIDIOutput port.
(define (web-midi-output? value)
  (and (web-midi-output-info? value)
       (web-midi-external? (web-midi-output-info-raw value))
       (js-web-midi-output? (web-midi-output-info-raw value))))

;; web-midi-port? : any/c -> boolean?
;;   Report whether value wraps a browser MIDI input or output port.
(define (web-midi-port? value)
  (or (web-midi-input? value)
      (web-midi-output? value)))

;; web-midi-message-event? : any/c -> boolean?
;;   Report whether value wraps a browser MIDIMessageEvent.
(define (web-midi-message-event? value)
  (and (web-midi-message-event-info? value)
       (web-midi-external? (web-midi-message-event-info-raw value))
       (js-web-midi-message-event?
        (web-midi-message-event-info-raw value))))

;; web-midi-connection-event? : any/c -> boolean?
;;   Report whether value wraps a browser MIDIConnectionEvent.
(define (web-midi-connection-event? value)
  (and (web-midi-connection-event-info? value)
       (web-midi-external? (web-midi-connection-event-info-raw value))
       (js-web-midi-connection-event?
        (web-midi-connection-event-info-raw value))))

;; web-midi-access-wrap : external/raw -> web-midi-access?
;;   Validate a raw MIDIAccess result from a Promise callback.
(define (web-midi-access-wrap raw)
  (define value (web-midi-access-info raw))
  (unless (web-midi-access? value)
    (raise-argument-error 'web-midi-access-wrap "MIDIAccess external/raw" raw))
  value)

;; web-midi-input-wrap : external/raw -> web-midi-input?
;;   Validate a raw MIDIInput result from a lookup or event callback.
(define (web-midi-input-wrap raw)
  (define value (web-midi-input-info raw))
  (unless (web-midi-input? value)
    (raise-argument-error 'web-midi-input-wrap "MIDIInput external/raw" raw))
  value)

;; web-midi-output-wrap : external/raw -> web-midi-output?
;;   Validate a raw MIDIOutput result from a lookup or event callback.
(define (web-midi-output-wrap raw)
  (define value (web-midi-output-info raw))
  (unless (web-midi-output? value)
    (raise-argument-error 'web-midi-output-wrap "MIDIOutput external/raw" raw))
  value)

;; web-midi-port-wrap : external/raw -> web-midi-port?
;;   Validate a raw MIDI input or output port.
(define (web-midi-port-wrap raw)
  (unless (web-midi-external? raw)
    (raise-argument-error 'web-midi-port-wrap "MIDIPort external/raw" raw))
  (cond
    [(js-web-midi-input? raw)  (web-midi-input-wrap raw)]
    [(js-web-midi-output? raw) (web-midi-output-wrap raw)]
    [else
     (raise-argument-error 'web-midi-port-wrap "MIDIPort external/raw" raw)]))

;; web-midi-message-event-wrap : external/raw -> web-midi-message-event?
;;   Validate a raw event delivered to a MIDI input listener.
(define (web-midi-message-event-wrap raw)
  (define value (web-midi-message-event-info raw))
  (unless (web-midi-message-event? value)
    (raise-argument-error 'web-midi-message-event-wrap
                          "MIDIMessageEvent external/raw"
                          raw))
  value)

;; web-midi-connection-event-wrap : external/raw -> web-midi-connection-event?
;;   Validate a raw event delivered to a MIDI access state-change listener.
(define (web-midi-connection-event-wrap raw)
  (define value (web-midi-connection-event-info raw))
  (unless (web-midi-connection-event? value)
    (raise-argument-error 'web-midi-connection-event-wrap
                          "MIDIConnectionEvent external/raw"
                          raw))
  value)

;; check-web-midi-access : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked MIDI access value.
(define (check-web-midi-access who value)
  (unless (web-midi-access? value)
    (raise-argument-error who "web-midi-access?" value)))

;; check-web-midi-input : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked MIDI input.
(define (check-web-midi-input who value)
  (unless (web-midi-input? value)
    (raise-argument-error who "web-midi-input?" value)))

;; check-web-midi-output : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked MIDI output.
(define (check-web-midi-output who value)
  (unless (web-midi-output? value)
    (raise-argument-error who "web-midi-output?" value)))

;; check-web-midi-port : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked MIDI port.
(define (check-web-midi-port who value)
  (unless (web-midi-port? value)
    (raise-argument-error who "web-midi-port?" value)))

;; check-web-midi-message-event : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked MIDI message event.
(define (check-web-midi-message-event who value)
  (unless (web-midi-message-event? value)
    (raise-argument-error who "web-midi-message-event?" value)))

;; check-web-midi-connection-event : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked MIDI connection event.
(define (check-web-midi-connection-event who value)
  (unless (web-midi-connection-event? value)
    (raise-argument-error who "web-midi-connection-event?" value)))

;; check-web-midi-boolean : symbol? any/c -> void?
;;   Raise an argument error unless value is a boolean option.
(define (check-web-midi-boolean who value)
  (unless (boolean? value)
    (raise-argument-error who "boolean?" value)))

;; check-web-midi-message : symbol? any/c -> void?
;;   Raise an argument error unless value is a nonempty byte string.
(define (check-web-midi-message who value)
  (unless (web-midi-message? value)
    (raise-argument-error who "web-midi-message?" value)))

;; check-web-midi-timestamp : symbol? any/c -> void?
;;   Raise an argument error unless value is a finite nonnegative timestamp.
(define (check-web-midi-timestamp who value)
  (unless (web-midi-timestamp? value)
    (raise-argument-error who "web-midi-timestamp?" value)))

;; web-midi-promise : symbol? string? external/raw -> js-promise?
;;   Validate and wrap one Web MIDI API Promise result.
(define (web-midi-promise who operation raw)
  (js-promise-wrap-result who operation raw "Web MIDI API"))

;; web-midi-request-access : [boolean?] [boolean?] -> js-promise?
;;   Request browser MIDI access with optional system-exclusive or software ports.
(define (web-midi-request-access [sysex? #f] [software? #f])
  (check-web-midi-boolean 'web-midi-request-access sysex?)
  (check-web-midi-boolean 'web-midi-request-access software?)
  (web-midi-promise 'web-midi-request-access
                    "Navigator.requestMIDIAccess"
                    (js-web-midi-request-access sysex? software?)))

;; web-midi-access-sysex-enabled? : web-midi-access? -> boolean?
;;   Report whether a granted access value permits system-exclusive messages.
(define (web-midi-access-sysex-enabled? access)
  (check-web-midi-access 'web-midi-access-sysex-enabled? access)
  (js-web-midi-access-sysex-enabled? (web-midi-access-info-raw access)))

;; web-midi-port-id-vector? : any/c -> boolean?
;;   Recognize vectors whose elements are browser-assigned port IDs.
(define (web-midi-port-id-vector? value)
  (and (vector? value)
       (let loop ([index 0])
         (or (= index (vector-length value))
             (and (string? (vector-ref value index))
                  (loop (add1 index)))))))

;; web-midi-check-port-id-vector : symbol? any/c -> vector?
;;   Validate the FASL-marshalled result of a static port-ID import.
(define (web-midi-check-port-id-vector who value)
  (unless (web-midi-port-id-vector? value)
    (raise-arguments-error who
                           "Web MIDI port ID result must be a vector of strings"
                           "result"
                           value))
  value)

;; web-midi-access-input-port-ids : web-midi-access? -> vector?
;;   Return a snapshot vector of the current MIDI input port IDs.
(define (web-midi-access-input-port-ids access)
  (check-web-midi-access 'web-midi-access-input-port-ids access)
  (web-midi-check-port-id-vector
   'web-midi-access-input-port-ids
   (js-web-midi-access-input-port-ids (web-midi-access-info-raw access))))

;; web-midi-access-output-port-ids : web-midi-access? -> vector?
;;   Return a snapshot vector of the current MIDI output port IDs.
(define (web-midi-access-output-port-ids access)
  (check-web-midi-access 'web-midi-access-output-port-ids access)
  (web-midi-check-port-id-vector
   'web-midi-access-output-port-ids
   (js-web-midi-access-output-port-ids (web-midi-access-info-raw access))))

;; web-midi-access-input : web-midi-access? string? -> (or/c #f web-midi-input?)
;;   Look up an input port by an ID returned by web-midi-access-input-port-ids.
(define (web-midi-access-input access id)
  (check-web-midi-access 'web-midi-access-input access)
  (unless (string? id)
    (raise-argument-error 'web-midi-access-input "string?" id))
  (define raw (js-web-midi-access-input (web-midi-access-info-raw access) id))
  (and raw (web-midi-input-wrap raw)))

;; web-midi-access-output : web-midi-access? string? -> (or/c #f web-midi-output?)
;;   Look up an output port by an ID returned by web-midi-access-output-port-ids.
(define (web-midi-access-output access id)
  (check-web-midi-access 'web-midi-access-output access)
  (unless (string? id)
    (raise-argument-error 'web-midi-access-output "string?" id))
  (define raw (js-web-midi-access-output (web-midi-access-info-raw access) id))
  (and raw (web-midi-output-wrap raw)))

;; web-midi-port-id : web-midi-port? -> string?
;;   Return a port's browser-assigned stable-within-session identifier.
(define (web-midi-port-id port)
  (check-web-midi-port 'web-midi-port-id port)
  (cond
    [(web-midi-input? port) (js-web-midi-port-id (web-midi-input-info-raw port))]
    [else                  (js-web-midi-port-id (web-midi-output-info-raw port))]))

;; web-midi-optional-string : symbol? any/c -> (or/c #f string?)
;;   Validate an optional string returned from the static FASL boundary.
(define (web-midi-optional-string who value)
  (cond
    [(not value) #f]
    [(string? value) value]
    [else
     (raise-arguments-error who
                            "Web MIDI result must be a string or #f"
                            "result"
                            value)]))

;; web-midi-port-raw : web-midi-port? -> external/raw
;;   Extract the checked raw input or output port.
(define (web-midi-port-raw port)
  (cond
    [(web-midi-input? port)  (web-midi-input-info-raw port)]
    [else                    (web-midi-output-info-raw port)]))

;; web-midi-port-name : web-midi-port? -> (or/c #f string?)
;;   Return the browser-provided display name when one is available.
(define (web-midi-port-name port)
  (check-web-midi-port 'web-midi-port-name port)
  (web-midi-optional-string 'web-midi-port-name
                            (js-web-midi-port-name (web-midi-port-raw port))))

;; web-midi-port-manufacturer : web-midi-port? -> (or/c #f string?)
;;   Return the browser-provided manufacturer when one is available.
(define (web-midi-port-manufacturer port)
  (check-web-midi-port 'web-midi-port-manufacturer port)
  (web-midi-optional-string 'web-midi-port-manufacturer
                            (js-web-midi-port-manufacturer
                             (web-midi-port-raw port))))

;; web-midi-port-version : web-midi-port? -> (or/c #f string?)
;;   Return the browser-provided port version when one is available.
(define (web-midi-port-version port)
  (check-web-midi-port 'web-midi-port-version port)
  (web-midi-optional-string 'web-midi-port-version
                            (js-web-midi-port-version (web-midi-port-raw port))))

;; web-midi-port-state : web-midi-port? -> (or/c 'connected 'disconnected)
;;   Return whether a port is currently connected to the system.
(define (web-midi-port-state port)
  (check-web-midi-port 'web-midi-port-state port)
  (define state (js-web-midi-port-state (web-midi-port-raw port)))
  (cond
    [(string=? state "connected")    'connected]
    [(string=? state "disconnected") 'disconnected]
    [else
     (raise-arguments-error 'web-midi-port-state
                            "MIDIPort.state must be connected or disconnected"
                            "result"
                            state)]))

;; web-midi-port-connection : web-midi-port? -> (or/c 'open 'closed 'pending)
;;   Return a port's logical connection state.
(define (web-midi-port-connection port)
  (check-web-midi-port 'web-midi-port-connection port)
  (define connection (js-web-midi-port-connection (web-midi-port-raw port)))
  (cond
    [(string=? connection "open")    'open]
    [(string=? connection "closed")  'closed]
    [(string=? connection "pending") 'pending]
    [else
     (raise-arguments-error 'web-midi-port-connection
                            "MIDIPort.connection must be open, closed, or pending"
                            "result"
                            connection)]))

;; web-midi-port-open : web-midi-port? -> js-promise?
;;   Return a Promise that opens a MIDI port.
(define (web-midi-port-open port)
  (check-web-midi-port 'web-midi-port-open port)
  (web-midi-promise 'web-midi-port-open
                    "MIDIPort.open"
                    (js-web-midi-port-open (web-midi-port-raw port))))

;; web-midi-port-close : web-midi-port? -> js-promise?
;;   Return a Promise that closes a MIDI port.
(define (web-midi-port-close port)
  (check-web-midi-port 'web-midi-port-close port)
  (web-midi-promise 'web-midi-port-close
                    "MIDIPort.close"
                    (js-web-midi-port-close (web-midi-port-raw port))))

;; web-midi-output-send! : web-midi-output? web-midi-message? [web-midi-timestamp?] -> void?
;;   Send a byte-string MIDI message immediately or at a scheduled timestamp.
(define (web-midi-output-send! output message [timestamp #f])
  (check-web-midi-output 'web-midi-output-send! output)
  (check-web-midi-message 'web-midi-output-send! message)
  (cond
    [(not timestamp)
     (js-web-midi-output-send! (web-midi-output-info-raw output) message)]
    [else
     (check-web-midi-timestamp 'web-midi-output-send! timestamp)
     (js-web-midi-output-send-at! (web-midi-output-info-raw output)
                                  message
                                  timestamp)])
  (void))

;; web-midi-callback->external : symbol? procedure? -> external/raw
;;   Convert a Racket event callback to one stable browser callback.
(define (web-midi-callback->external who callback)
  (unless (procedure? callback)
    (raise-argument-error who "procedure?" callback))
  (define cached (hash-ref web-midi-callback-cache callback #f))
  (cond
    [cached cached]
    [else
     (define external
       (procedure->external
        (lambda args
          (apply callback args)
          (void))))
     (hash-set! web-midi-callback-cache callback external)
     external]))

;; web-midi-input-add-message-listener! : web-midi-input? procedure? -> external/raw
;;   Add a callback that receives one raw MIDIMessageEvent.
(define (web-midi-input-add-message-listener! input callback)
  (check-web-midi-input 'web-midi-input-add-message-listener! input)
  (define callback*
    (web-midi-callback->external 'web-midi-input-add-message-listener! callback))
  (js-web-midi-input-add-message-listener! (web-midi-input-info-raw input) callback*)
  callback*)

;; web-midi-input-remove-message-listener! : web-midi-input? procedure? -> void?
;;   Remove a callback previously added to a MIDI input.
(define (web-midi-input-remove-message-listener! input callback)
  (check-web-midi-input 'web-midi-input-remove-message-listener! input)
  (define callback*
    (web-midi-callback->external 'web-midi-input-remove-message-listener! callback))
  (js-web-midi-input-remove-message-listener! (web-midi-input-info-raw input)
                                               callback*)
  (void))

;; web-midi-access-add-state-change-listener! : web-midi-access? procedure? -> external/raw
;;   Add a callback that receives one raw MIDIConnectionEvent.
(define (web-midi-access-add-state-change-listener! access callback)
  (check-web-midi-access 'web-midi-access-add-state-change-listener! access)
  (define callback*
    (web-midi-callback->external 'web-midi-access-add-state-change-listener! callback))
  (js-web-midi-access-add-state-change-listener! (web-midi-access-info-raw access)
                                                  callback*)
  callback*)

;; web-midi-access-remove-state-change-listener! : web-midi-access? procedure? -> void?
;;   Remove a callback previously added to MIDI access state changes.
(define (web-midi-access-remove-state-change-listener! access callback)
  (check-web-midi-access 'web-midi-access-remove-state-change-listener! access)
  (define callback*
    (web-midi-callback->external 'web-midi-access-remove-state-change-listener!
                                 callback))
  (js-web-midi-access-remove-state-change-listener! (web-midi-access-info-raw access)
                                                     callback*)
  (void))

;; web-midi-message-event-data : web-midi-message-event? -> bytes?
;;   Return the byte string carried by a MIDI input message event.
(define (web-midi-message-event-data event)
  (check-web-midi-message-event 'web-midi-message-event-data event)
  (define data
    (js-web-midi-message-event-data (web-midi-message-event-info-raw event)))
  (unless (bytes? data)
    (raise-arguments-error 'web-midi-message-event-data
                           "MIDIMessageEvent.data result must be a byte string"
                           "result"
                           data))
  data)

;; web-midi-connection-event-port : web-midi-connection-event? -> web-midi-port?
;;   Return and wrap the port whose connection state changed.
(define (web-midi-connection-event-port event)
  (check-web-midi-connection-event 'web-midi-connection-event-port event)
  (web-midi-port-wrap
   (js-web-midi-connection-event-port
    (web-midi-connection-event-info-raw event))))
