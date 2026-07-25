#lang webracket/base

(require (only-in webracket/unsafe/dom
                  js-array->vector
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-typeof
                  js-undefined?
                  js-window-navigator
                  js-window-window)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (all-defined-out))

;;;
;;; Gamepad wrappers
;;;

(define gamepad-callback-cache (make-hasheq))

;; gamepad-info : external/raw -> gamepad-info?
;;   Wrap a browser Gamepad object.
(struct gamepad-info (raw) #:transparent)

;; gamepad-button-info : external/raw -> gamepad-button-info?
;;   Wrap a browser GamepadButton object.
(struct gamepad-button-info (raw) #:transparent)

;; gamepad-raw : gamepad-info? -> external/raw
;;   Extract the raw Gamepad object.
(define (gamepad-raw value)
  (gamepad-info-raw value))

;; gamepad-button-raw : gamepad-button-info? -> external/raw
;;   Extract the raw GamepadButton object.
(define (gamepad-button-raw value)
  (gamepad-button-info-raw value))

;; gamepad-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (gamepad-method-present? raw method-name)
  (and (gamepad-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; gamepad-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (gamepad-property-present? raw property-name)
  (and (gamepad-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; gamepad-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (gamepad-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; gamepad-array-like-result? : any/c -> boolean?
;;   Report whether raw is a non-nullish host value with an array-like length.
(define (gamepad-array-like-result? raw)
  (and (gamepad-raw-host-value? raw)
       (exact-nonnegative-integer? (js-ref raw "length"))))

;; gamepad-check-array-like-result : symbol? string? any/c -> external/raw
;;   Validate a host result before converting it with js-array->vector.
(define (gamepad-check-array-like-result who display-name raw)
  (unless (gamepad-array-like-result? raw)
    (raise-arguments-error who
                           (string-append display-name
                                          " result must be array-like")))
  raw)

;; gamepad-wrap/checked : symbol? string? any/c -> (or/c #f gamepad-info?)
;;   Wrap a nullable Gamepad result and reject malformed non-null slots.
(define (gamepad-wrap/checked who display-name raw)
  (cond
    [(or (not raw)
         (null? raw)
         (eq? raw (void))
         (and (external? raw)
              (js-nullish? raw)))
     #f]
    [else
     (define value (gamepad-info raw))
     (unless (gamepad? value)
       (raise-arguments-error who
                              (string-append display-name
                                             " result must be Gamepad")))
     value]))

;; gamepad-button-wrap/checked : symbol? string? any/c -> gamepad-button-info?
;;   Wrap a GamepadButton result and reject malformed button objects.
(define (gamepad-button-wrap/checked who display-name raw)
  (define value (gamepad-button-info raw))
  (unless (gamepad-button? value)
    (raise-arguments-error who
                           (string-append display-name
                                          " result must be GamepadButton")))
  value)

;; gamepad-required-properties-present? : external/raw -> boolean?
;;   Report whether raw exposes the required Gamepad data properties.
(define (gamepad-required-properties-present? raw)
  (and (gamepad-property-present? raw "id")
       (gamepad-property-present? raw "index")
       (gamepad-property-present? raw "connected")
       (gamepad-property-present? raw "timestamp")
       (gamepad-property-present? raw "mapping")
       (gamepad-property-present? raw "axes")
       (gamepad-property-present? raw "buttons")))

;; gamepad-button-required-properties-present? : external/raw -> boolean?
;;   Report whether raw exposes the required GamepadButton data properties.
(define (gamepad-button-required-properties-present? raw)
  (and (gamepad-property-present? raw "pressed")
       (gamepad-property-present? raw "touched")
       (gamepad-property-present? raw "value")))

;; gamepad-vector-map : procedure? vector? -> vector?
;;   Map proc over vec without depending on racket/vector.
(define (gamepad-vector-map proc vec)
  (define len (vector-length vec))
  (define out (make-vector len))
  (let loop ([i 0])
    (when (< i len)
      (vector-set! out i (proc (vector-ref vec i)))
      (loop (add1 i))))
  out)

;; gamepad-supported? : -> boolean?
;;   Report whether navigator.getGamepads is available.
(define (gamepad-supported?)
  (with-handlers ([exn:fail? (lambda (_e) #f)])
    (gamepad-method-present? (js-window-navigator) "getGamepads")))

;; check-gamepad-navigator-method : symbol? string? -> void?
;;   Ensure navigator exposes a required Gamepad API method.
(define (check-gamepad-navigator-method who method-name)
  (unless (gamepad-method-present? (js-window-navigator) method-name)
    (raise-arguments-error who
                           (string-append "navigator." method-name " is not available"))))

;; check-gamepad-window-method : symbol? string? -> void?
;;   Ensure window exposes a required event listener method.
(define (check-gamepad-window-method who method-name)
  (unless (gamepad-method-present? (js-window-window) method-name)
    (raise-arguments-error who
                           (string-append "window." method-name " is not available"))))

;; check-gamepad-property : symbol? gamepad-info? string? -> void?
;;   Ensure a required Gamepad property is available.
(define (check-gamepad-property who value property-name)
  (unless (gamepad-property-present? (gamepad-raw value) property-name)
    (raise-arguments-error who
                           (string-append "Gamepad." property-name " is not available"))))

;; check-gamepad-button-property : symbol? gamepad-button-info? string? -> void?
;;   Ensure a required GamepadButton property is available.
(define (check-gamepad-button-property who value property-name)
  (unless (gamepad-property-present? (gamepad-button-raw value) property-name)
    (raise-arguments-error who
                           (string-append "GamepadButton." property-name " is not available"))))

;; check-gamepad-event-property : symbol? external/raw string? -> void?
;;   Ensure a required GamepadEvent property is available.
(define (check-gamepad-event-property who raw property-name)
  (when (js-undefined? (js-ref/extern raw property-name))
    (raise-arguments-error who
                           (string-append "GamepadEvent." property-name " is not available"))))

;; gamepad? : any/c -> boolean?
;;   Report whether v is a wrapped Gamepad object.
(define (gamepad? v)
  (and (gamepad-host-value? v)
       (gamepad-required-properties-present? (gamepad-raw v))))

;; gamepad-host-value? : any/c -> boolean?
;;   Report whether v wraps an external Gamepad-like host value.
(define (gamepad-host-value? v)
  (and (gamepad-info? v)
       (gamepad-raw-host-value? (gamepad-raw v))))

;; gamepad-button? : any/c -> boolean?
;;   Report whether v is a wrapped GamepadButton object.
(define (gamepad-button? v)
  (and (gamepad-button-host-value? v)
       (gamepad-button-required-properties-present? (gamepad-button-raw v))))

;; gamepad-button-host-value? : any/c -> boolean?
;;   Report whether v wraps an external GamepadButton-like host value.
(define (gamepad-button-host-value? v)
  (and (gamepad-button-info? v)
       (gamepad-raw-host-value? (gamepad-button-raw v))))

;; check-gamepad : symbol? any/c -> void?
;;   Ensure value wraps an external Gamepad-like host value.
(define (check-gamepad who value)
  (unless (gamepad-host-value? value)
    (raise-argument-error who "gamepad?" value)))

;; check-gamepad-button : symbol? any/c -> void?
;;   Ensure value wraps an external GamepadButton-like host value.
(define (check-gamepad-button who value)
  (unless (gamepad-button-host-value? value)
    (raise-argument-error who "gamepad-button?" value)))

;; gamepad-wrap : any/c -> (or/c #f gamepad-info?)
;;   Wrap a raw Gamepad slot, preserving disconnected/null slots as #f.
(define (gamepad-wrap raw)
  (and (gamepad-raw-host-value? raw)
       (gamepad-info raw)))

;; gamepad-button-wrap : external/raw -> gamepad-button-info?
;;   Wrap a raw GamepadButton value.
(define (gamepad-button-wrap raw)
  (gamepad-button-info raw))

;; gamepads : -> vector?
;;   Return the current gamepad slots, with disconnected/null slots as #f.
(define (gamepads)
  (check-gamepad-navigator-method 'gamepads "getGamepads")
  (define raw-gamepads (js-send/extern (js-window-navigator) "getGamepads" (vector)))
  (gamepad-vector-map
   (lambda (raw-gamepad)
     (gamepad-wrap/checked 'gamepads
                           "navigator.getGamepads slot"
                           raw-gamepad))
   (js-array->vector
    (gamepad-check-array-like-result 'gamepads
                                     "navigator.getGamepads"
                                     raw-gamepads))))

;; gamepad-event-gamepad : external/raw -> (or/c #f gamepad?)
;;   Extract the gamepad from a gamepadconnected or gamepaddisconnected event.
(define (gamepad-event-gamepad event)
  (unless (gamepad-raw-host-value? event)
    (raise-argument-error 'gamepad-event-gamepad "external?" event))
  (check-gamepad-event-property 'gamepad-event-gamepad event "gamepad")
  (gamepad-wrap/checked 'gamepad-event-gamepad
                        "GamepadEvent.gamepad"
                        (js-ref/extern event "gamepad")))

;; gamepad-id : gamepad? -> string?
;;   Read the browser-provided gamepad id.
(define (gamepad-id value)
  (check-gamepad 'gamepad-id value)
  (check-gamepad-property 'gamepad-id value "id")
  (js-ref (gamepad-raw value) "id"))

;; gamepad-index : gamepad? -> exact-nonnegative-integer?
;;   Read the gamepad slot index.
(define (gamepad-index value)
  (check-gamepad 'gamepad-index value)
  (check-gamepad-property 'gamepad-index value "index")
  (js-ref (gamepad-raw value) "index"))

;; gamepad-connected? : gamepad? -> boolean?
;;   Report whether the gamepad is still connected.
(define (gamepad-connected? value)
  (check-gamepad 'gamepad-connected? value)
  (check-gamepad-property 'gamepad-connected? value "connected")
  (js-ref (gamepad-raw value) "connected"))

;; gamepad-timestamp : gamepad? -> number?
;;   Read the most recent gamepad data timestamp.
(define (gamepad-timestamp value)
  (check-gamepad 'gamepad-timestamp value)
  (check-gamepad-property 'gamepad-timestamp value "timestamp")
  (js-ref (gamepad-raw value) "timestamp"))

;; gamepad-mapping : gamepad? -> string?
;;   Read the gamepad mapping string, commonly "standard".
(define (gamepad-mapping value)
  (check-gamepad 'gamepad-mapping value)
  (check-gamepad-property 'gamepad-mapping value "mapping")
  (js-ref (gamepad-raw value) "mapping"))

;; gamepad-axes : gamepad? -> vector?
;;   Return the current axis values as a vector of numbers.
(define (gamepad-axes value)
  (check-gamepad 'gamepad-axes value)
  (check-gamepad-property 'gamepad-axes value "axes")
  (js-array->vector
   (gamepad-check-array-like-result
    'gamepad-axes
    "Gamepad.axes"
    (js-ref/extern (gamepad-raw value) "axes"))))

;; gamepad-buttons : gamepad? -> vector?
;;   Return the current buttons as wrapped GamepadButton values.
(define (gamepad-buttons value)
  (check-gamepad 'gamepad-buttons value)
  (check-gamepad-property 'gamepad-buttons value "buttons")
  (gamepad-vector-map
   (lambda (raw-button)
     (gamepad-button-wrap/checked 'gamepad-buttons
                                  "Gamepad.buttons item"
                                  raw-button))
   (js-array->vector
    (gamepad-check-array-like-result
     'gamepad-buttons
     "Gamepad.buttons"
     (js-ref/extern (gamepad-raw value) "buttons")))))

;; gamepad-button-pressed? : gamepad-button? -> boolean?
;;   Report whether the button is currently pressed.
(define (gamepad-button-pressed? value)
  (check-gamepad-button 'gamepad-button-pressed? value)
  (check-gamepad-button-property 'gamepad-button-pressed? value "pressed")
  (js-ref (gamepad-button-raw value) "pressed"))

;; gamepad-button-touched? : gamepad-button? -> boolean?
;;   Report whether the button is currently touched.
(define (gamepad-button-touched? value)
  (check-gamepad-button 'gamepad-button-touched? value)
  (check-gamepad-button-property 'gamepad-button-touched? value "touched")
  (js-ref (gamepad-button-raw value) "touched"))

;; gamepad-button-value : gamepad-button? -> number?
;;   Read the analog button value between 0 and 1.
(define (gamepad-button-value value)
  (check-gamepad-button 'gamepad-button-value value)
  (check-gamepad-button-property 'gamepad-button-value value "value")
  (js-ref (gamepad-button-raw value) "value"))

;; gamepad-callback->external : symbol? any/c -> external/raw
;;   Convert a callback to a stable external callback wrapper.
(define (gamepad-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref gamepad-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply callback args)
             (void))))
        (hash-set! gamepad-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; gamepad-add-connected-listener! : (or/c procedure? external?) -> external/raw
;;   Add a gamepadconnected listener to window.
(define (gamepad-add-connected-listener! callback)
  (check-gamepad-window-method 'gamepad-add-connected-listener! "addEventListener")
  (define callback* (gamepad-callback->external 'gamepad-add-connected-listener! callback))
  (js-send/extern/nullish (js-window-window)
                          "addEventListener"
                          (vector "gamepadconnected" callback*))
  callback*)

;; gamepad-remove-connected-listener! : (or/c procedure? external?) -> void?
;;   Remove a previously installed gamepadconnected listener.
(define (gamepad-remove-connected-listener! callback)
  (check-gamepad-window-method 'gamepad-remove-connected-listener! "removeEventListener")
  (define callback* (gamepad-callback->external 'gamepad-remove-connected-listener! callback))
  (js-send/extern/nullish (js-window-window)
                          "removeEventListener"
                          (vector "gamepadconnected" callback*))
  (void))

;; gamepad-add-disconnected-listener! : (or/c procedure? external?) -> external/raw
;;   Add a gamepaddisconnected listener to window.
(define (gamepad-add-disconnected-listener! callback)
  (check-gamepad-window-method 'gamepad-add-disconnected-listener! "addEventListener")
  (define callback* (gamepad-callback->external 'gamepad-add-disconnected-listener! callback))
  (js-send/extern/nullish (js-window-window)
                          "addEventListener"
                          (vector "gamepaddisconnected" callback*))
  callback*)

;; gamepad-remove-disconnected-listener! : (or/c procedure? external?) -> void?
;;   Remove a previously installed gamepaddisconnected listener.
(define (gamepad-remove-disconnected-listener! callback)
  (check-gamepad-window-method 'gamepad-remove-disconnected-listener! "removeEventListener")
  (define callback* (gamepad-callback->external 'gamepad-remove-disconnected-listener! callback))
  (js-send/extern/nullish (js-window-window)
                          "removeEventListener"
                          (vector "gamepaddisconnected" callback*))
  (void))
