#lang webracket/base

(require js/promise
         webracket/unsafe/device-orientation
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide device-orientation-supported?
         device-motion-supported?
         device-orientation-permission-requestable?
         device-motion-permission-requestable?
         device-orientation-permission-status
         device-orientation-event?
         device-motion-event?
         device-orientation-event-wrap
         device-motion-event-wrap
         device-orientation-request-permission
         device-motion-request-permission
         device-orientation-add-listener!
         device-orientation-remove-listener!
         device-orientation-add-absolute-listener!
         device-orientation-remove-absolute-listener!
         device-motion-add-listener!
         device-motion-remove-listener!
         device-orientation-event-absolute?
         device-orientation-event-alpha
         device-orientation-event-beta
         device-orientation-event-gamma
         device-orientation-event-compass-heading
         device-orientation-event-compass-accuracy
         device-motion-event-acceleration-x
         device-motion-event-acceleration-y
         device-motion-event-acceleration-z
         device-motion-event-gravity-acceleration-x
         device-motion-event-gravity-acceleration-y
         device-motion-event-gravity-acceleration-z
         device-motion-event-rotation-alpha
         device-motion-event-rotation-beta
         device-motion-event-rotation-gamma
         device-motion-event-interval)

;; Browser events are delivered as raw callback values. The two wrapper structs
;; keep those objects at the API boundary while the public accessors return
;; Racket booleans, numbers, and #f for unavailable sensor readings.

;; device-orientation-event-info : external/raw -> device-orientation-event-info?
;;   Hold one browser DeviceOrientationEvent.
(struct device-orientation-event-info (raw) #:transparent)

;; device-motion-event-info : external/raw -> device-motion-event-info?
;;   Hold one browser DeviceMotionEvent.
(struct device-motion-event-info (raw) #:transparent)

;; device-orientation-callback-cache : hash?
;;   Reuse stable external callbacks so removal can use the same procedure.
(define device-orientation-callback-cache (make-hasheq))

;; device-orientation-external? : any/c -> boolean?
;;   Recognize a browser value crossing the FFI boundary.
(define (device-orientation-external? value)
  (external? value))

;; device-orientation-supported? : -> boolean?
;;   Report whether the DeviceOrientationEvent constructor is available.
(define (device-orientation-supported?)
  (js-device-orientation-supported?))

;; device-motion-supported? : -> boolean?
;;   Report whether the DeviceMotionEvent constructor is available.
(define (device-motion-supported?)
  (js-device-motion-supported?))

;; device-orientation-permission-requestable? : -> boolean?
;;   Report whether the browser needs and exposes an orientation permission request.
(define (device-orientation-permission-requestable?)
  (js-device-orientation-permission-requestable?))

;; device-motion-permission-requestable? : -> boolean?
;;   Report whether the browser needs and exposes a motion permission request.
(define (device-motion-permission-requestable?)
  (js-device-motion-permission-requestable?))

;; device-orientation-event? : any/c -> boolean?
;;   Report whether value wraps a browser DeviceOrientationEvent.
(define (device-orientation-event? value)
  (and (device-orientation-event-info? value)
       (device-orientation-external? (device-orientation-event-info-raw value))
       (js-device-orientation-event?
        (device-orientation-event-info-raw value))))

;; device-motion-event? : any/c -> boolean?
;;   Report whether value wraps a browser DeviceMotionEvent.
(define (device-motion-event? value)
  (and (device-motion-event-info? value)
       (device-orientation-external? (device-motion-event-info-raw value))
       (js-device-motion-event?
        (device-motion-event-info-raw value))))

;; device-orientation-event-wrap : external/raw -> device-orientation-event?
;;   Validate one raw event delivered to an orientation listener.
(define (device-orientation-event-wrap raw)
  (define value (device-orientation-event-info raw))
  (unless (device-orientation-event? value)
    (raise-argument-error 'device-orientation-event-wrap
                          "DeviceOrientationEvent external/raw"
                          raw))
  value)

;; device-motion-event-wrap : external/raw -> device-motion-event?
;;   Validate one raw event delivered to a motion listener.
(define (device-motion-event-wrap raw)
  (define value (device-motion-event-info raw))
  (unless (device-motion-event? value)
    (raise-argument-error 'device-motion-event-wrap
                          "DeviceMotionEvent external/raw"
                          raw))
  value)

;; check-device-orientation-event : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked orientation event.
(define (check-device-orientation-event who value)
  (unless (device-orientation-event? value)
    (raise-argument-error who "device-orientation-event?" value)))

;; check-device-motion-event : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked motion event.
(define (check-device-motion-event who value)
  (unless (device-motion-event? value)
    (raise-argument-error who "device-motion-event?" value)))

;; check-device-orientation-boolean : symbol? any/c -> void?
;;   Raise an argument error unless value is a boolean option.
(define (check-device-orientation-boolean who value)
  (unless (boolean? value)
    (raise-argument-error who "boolean?" value)))

;; device-orientation-permission-status : (or/c string? symbol?) -> (or/c 'granted 'denied)
;;   Normalize a browser sensor permission result to a Racket symbol.
(define (device-orientation-permission-status value)
  (define status
    (cond
      [(string? value) value]
      [(symbol? value) (symbol->string value)]
      [else
       (raise-argument-error 'device-orientation-permission-status
                             "(or/c string? symbol?)"
                             value)]))
  (cond
    [(string=? status "granted") 'granted]
    [(string=? status "denied")  'denied]
    [else
     (raise-arguments-error 'device-orientation-permission-status
                            "permission result must be granted or denied"
                            "result"
                            value)]))

;; device-orientation-promise : symbol? string? external/raw -> js-promise?
;;   Check and wrap a Promise returned by one device-sensor operation.
(define (device-orientation-promise who operation raw)
  (js-promise-wrap-result who operation raw "Device Orientation API"))

;; device-orientation-request-permission : [boolean?] -> js-promise?
;;   Request permission for orientation readings, optionally including a compass.
(define (device-orientation-request-permission [absolute? #f])
  (check-device-orientation-boolean 'device-orientation-request-permission
                                    absolute?)
  (unless (device-orientation-permission-requestable?)
    (raise-arguments-error 'device-orientation-request-permission
                           "DeviceOrientationEvent.requestPermission is not available"))
  (device-orientation-promise
   'device-orientation-request-permission
   "DeviceOrientationEvent.requestPermission"
   (js-device-orientation-request-permission absolute?)))

;; device-motion-request-permission : -> js-promise?
;;   Request permission for acceleration and rotation-rate readings.
(define (device-motion-request-permission)
  (unless (device-motion-permission-requestable?)
    (raise-arguments-error 'device-motion-request-permission
                           "DeviceMotionEvent.requestPermission is not available"))
  (device-orientation-promise
   'device-motion-request-permission
   "DeviceMotionEvent.requestPermission"
   (js-device-motion-request-permission)))

;; device-orientation-callback->external : symbol? procedure? -> external/raw
;;   Convert one Racket listener to a stable browser callback.
(define (device-orientation-callback->external who callback)
  (unless (procedure? callback)
    (raise-argument-error who "procedure?" callback))
  (define cached (hash-ref device-orientation-callback-cache callback #f))
  (cond
    [cached cached]
    [else
     (define external
       (procedure->external
        (lambda args
          (apply callback args)
          (void))))
     (hash-set! device-orientation-callback-cache callback external)
     external]))

;; device-orientation-add-listener! : procedure? -> void?
;;   Add a listener for ordinary deviceorientation events.
(define (device-orientation-add-listener! callback)
  (js-device-orientation-add-listener!
   (device-orientation-callback->external 'device-orientation-add-listener!
                                           callback))
  (void))

;; device-orientation-remove-listener! : procedure? -> void?
;;   Remove a listener previously added for ordinary deviceorientation events.
(define (device-orientation-remove-listener! callback)
  (js-device-orientation-remove-listener!
   (device-orientation-callback->external 'device-orientation-remove-listener!
                                           callback))
  (void))

;; device-orientation-add-absolute-listener! : procedure? -> void?
;;   Add a listener for deviceorientationabsolute events.
(define (device-orientation-add-absolute-listener! callback)
  (js-device-orientation-add-absolute-listener!
   (device-orientation-callback->external
    'device-orientation-add-absolute-listener!
    callback))
  (void))

;; device-orientation-remove-absolute-listener! : procedure? -> void?
;;   Remove a listener previously added for deviceorientationabsolute events.
(define (device-orientation-remove-absolute-listener! callback)
  (js-device-orientation-remove-absolute-listener!
   (device-orientation-callback->external
    'device-orientation-remove-absolute-listener!
    callback))
  (void))

;; device-motion-add-listener! : procedure? -> void?
;;   Add a listener for devicemotion events.
(define (device-motion-add-listener! callback)
  (js-device-motion-add-listener!
   (device-orientation-callback->external 'device-motion-add-listener! callback))
  (void))

;; device-motion-remove-listener! : procedure? -> void?
;;   Remove a listener previously added for devicemotion events.
(define (device-motion-remove-listener! callback)
  (js-device-motion-remove-listener!
   (device-orientation-callback->external 'device-motion-remove-listener! callback))
  (void))

;; device-orientation-optional-real : symbol? any/c -> (or/c #f real?)
;;   Check an optional finite numeric reading marshalled from JavaScript.
(define (device-orientation-optional-real who value)
  (cond
    [(not value) #f]
    [(real? value) value]
    [else
     (raise-arguments-error who
                            "sensor reading must be a real number or #f"
                            "result"
                            value)]))

;; device-orientation-required-real : symbol? any/c -> real?
;;   Check a required finite numeric reading marshalled from JavaScript.
(define (device-orientation-required-real who value)
  (unless (real? value)
    (raise-arguments-error who
                           "sensor reading must be a real number"
                           "result"
                           value))
  value)

;; device-orientation-event-absolute? : device-orientation-event? -> boolean?
;;   Report whether an event provides Earth-frame orientation data.
(define (device-orientation-event-absolute? event)
  (check-device-orientation-event 'device-orientation-event-absolute? event)
  (js-device-orientation-event-absolute?
   (device-orientation-event-info-raw event)))

;; device-orientation-event-alpha : device-orientation-event? -> (or/c #f real?)
;;   Return the optional z-axis orientation angle in degrees.
(define (device-orientation-event-alpha event)
  (check-device-orientation-event 'device-orientation-event-alpha event)
  (device-orientation-optional-real
   'device-orientation-event-alpha
   (js-device-orientation-event-alpha (device-orientation-event-info-raw event))))

;; device-orientation-event-beta : device-orientation-event? -> (or/c #f real?)
;;   Return the optional x-axis orientation angle in degrees.
(define (device-orientation-event-beta event)
  (check-device-orientation-event 'device-orientation-event-beta event)
  (device-orientation-optional-real
   'device-orientation-event-beta
   (js-device-orientation-event-beta (device-orientation-event-info-raw event))))

;; device-orientation-event-gamma : device-orientation-event? -> (or/c #f real?)
;;   Return the optional y-axis orientation angle in degrees.
(define (device-orientation-event-gamma event)
  (check-device-orientation-event 'device-orientation-event-gamma event)
  (device-orientation-optional-real
   'device-orientation-event-gamma
   (js-device-orientation-event-gamma (device-orientation-event-info-raw event))))

;; device-orientation-event-compass-heading : device-orientation-event? -> (or/c #f real?)
;;   Return the optional Safari WebKit compass heading in degrees.
(define (device-orientation-event-compass-heading event)
  (check-device-orientation-event 'device-orientation-event-compass-heading event)
  (device-orientation-optional-real
   'device-orientation-event-compass-heading
   (js-device-orientation-event-compass-heading
    (device-orientation-event-info-raw event))))

;; device-orientation-event-compass-accuracy : device-orientation-event? -> (or/c #f real?)
;;   Return the optional Safari WebKit compass accuracy in degrees.
(define (device-orientation-event-compass-accuracy event)
  (check-device-orientation-event 'device-orientation-event-compass-accuracy event)
  (device-orientation-optional-real
   'device-orientation-event-compass-accuracy
   (js-device-orientation-event-compass-accuracy
    (device-orientation-event-info-raw event))))

;; device-motion-optional-component : symbol? device-motion-event? procedure? -> (or/c #f real?)
;;   Read and validate one optional component through its fixed static import.
(define (device-motion-optional-component who event accessor)
  (check-device-motion-event who event)
  (device-orientation-optional-real
   who
   (accessor (device-motion-event-info-raw event))))

;; device-motion-event-acceleration-x : device-motion-event? -> (or/c #f real?)
;;   Return optional acceleration without gravity along the x axis.
(define (device-motion-event-acceleration-x event)
  (device-motion-optional-component
   'device-motion-event-acceleration-x
   event
   js-device-motion-event-acceleration-x))

;; device-motion-event-acceleration-y : device-motion-event? -> (or/c #f real?)
;;   Return optional acceleration without gravity along the y axis.
(define (device-motion-event-acceleration-y event)
  (device-motion-optional-component
   'device-motion-event-acceleration-y
   event
   js-device-motion-event-acceleration-y))

;; device-motion-event-acceleration-z : device-motion-event? -> (or/c #f real?)
;;   Return optional acceleration without gravity along the z axis.
(define (device-motion-event-acceleration-z event)
  (device-motion-optional-component
   'device-motion-event-acceleration-z
   event
   js-device-motion-event-acceleration-z))

;; device-motion-event-gravity-acceleration-x : device-motion-event? -> (or/c #f real?)
;;   Return optional gravity-inclusive acceleration along the x axis.
(define (device-motion-event-gravity-acceleration-x event)
  (device-motion-optional-component
   'device-motion-event-gravity-acceleration-x
   event
   js-device-motion-event-gravity-acceleration-x))

;; device-motion-event-gravity-acceleration-y : device-motion-event? -> (or/c #f real?)
;;   Return optional gravity-inclusive acceleration along the y axis.
(define (device-motion-event-gravity-acceleration-y event)
  (device-motion-optional-component
   'device-motion-event-gravity-acceleration-y
   event
   js-device-motion-event-gravity-acceleration-y))

;; device-motion-event-gravity-acceleration-z : device-motion-event? -> (or/c #f real?)
;;   Return optional gravity-inclusive acceleration along the z axis.
(define (device-motion-event-gravity-acceleration-z event)
  (device-motion-optional-component
   'device-motion-event-gravity-acceleration-z
   event
   js-device-motion-event-gravity-acceleration-z))

;; device-motion-event-rotation-alpha : device-motion-event? -> (or/c #f real?)
;;   Return optional z-axis rotation rate in degrees per second.
(define (device-motion-event-rotation-alpha event)
  (device-motion-optional-component
   'device-motion-event-rotation-alpha
   event
   js-device-motion-event-rotation-alpha))

;; device-motion-event-rotation-beta : device-motion-event? -> (or/c #f real?)
;;   Return optional x-axis rotation rate in degrees per second.
(define (device-motion-event-rotation-beta event)
  (device-motion-optional-component
   'device-motion-event-rotation-beta
   event
   js-device-motion-event-rotation-beta))

;; device-motion-event-rotation-gamma : device-motion-event? -> (or/c #f real?)
;;   Return optional y-axis rotation rate in degrees per second.
(define (device-motion-event-rotation-gamma event)
  (device-motion-optional-component
   'device-motion-event-rotation-gamma
   event
   js-device-motion-event-rotation-gamma))

;; device-motion-event-interval : device-motion-event? -> real?
;;   Return the sensor sampling interval in milliseconds.
(define (device-motion-event-interval event)
  (check-device-motion-event 'device-motion-event-interval event)
  (device-orientation-required-real
   'device-motion-event-interval
   (js-device-motion-event-interval (device-motion-event-info-raw event))))
