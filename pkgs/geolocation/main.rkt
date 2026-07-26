#lang webracket/base

(require (only-in webracket/unsafe/dom
                  js-nullish?
                  js-object
                  js-ref
                  js-ref/extern
                  js-send/extern/nullish
                  js-send/value
                  js-typeof
                  js-window-navigator)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (except-out (all-defined-out)
                     geolocation-position-info?
                     geolocation-position-info-raw
                     geolocation-coordinates-info?
                     geolocation-coordinates-info-raw
                     geolocation-position-error-info?
                     geolocation-position-error-info-raw))

;;;
;;; Geolocation wrappers
;;;

(struct geolocation-info (raw) #:transparent)
(struct geolocation-position-info (raw)
  #:transparent
  #:constructor-name geolocation-position)
(struct geolocation-coordinates-info (raw)
  #:transparent
  #:constructor-name geolocation-coordinates)
(struct geolocation-position-error-info (raw)
  #:transparent
  #:constructor-name geolocation-position-error)

(struct geolocation-options (enable-high-accuracy timeout maximum-age)
  #:transparent
  #:constructor-name make-geolocation-options
  #:guard
  (lambda (enable-high-accuracy timeout maximum-age name)
    (unless (or (eq? enable-high-accuracy #f) (boolean? enable-high-accuracy))
      (raise-argument-error name "(or/c #f boolean?)" enable-high-accuracy))
    (unless (or (eq? timeout #f) (exact-nonnegative-integer? timeout))
      (raise-argument-error name "(or/c #f exact-nonnegative-integer?)" timeout))
    (unless (or (eq? maximum-age #f) (exact-nonnegative-integer? maximum-age))
      (raise-argument-error name "(or/c #f exact-nonnegative-integer?)" maximum-age))
    (values enable-high-accuracy timeout maximum-age)))

;; geolocation-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable Geolocation method.
(define (geolocation-method-present? raw method-name)
  (and (geolocation-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; geolocation-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (geolocation-property-present? raw property-name)
  (and (geolocation-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; geolocation-core-methods-present? : external/raw -> boolean?
;;   Report whether raw has the required Geolocation methods.
(define (geolocation-core-methods-present? raw)
  (and (geolocation-method-present? raw "getCurrentPosition")
       (geolocation-method-present? raw "watchPosition")
       (geolocation-method-present? raw "clearWatch")))

;; geolocation-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (geolocation-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; geolocation-check-watch-id-result : symbol? any/c -> exact-nonnegative-integer?
;;   Validate the watch id returned by Geolocation.watchPosition.
(define (geolocation-check-watch-id-result who result)
  (unless (exact-nonnegative-integer? result)
    (raise-arguments-error who
                           "Geolocation.watchPosition result must be an exact nonnegative integer"))
  result)

;; geolocation-position-wrap/checked : symbol? any/c -> geolocation-position?
;;   Validate and wrap a position object supplied by a browser callback.
(define (geolocation-position-wrap/checked who raw)
  (define position (geolocation-position raw))
  (unless (geolocation-position? position)
    (raise-arguments-error who
                           "Geolocation success callback argument must be GeolocationPosition"))
  position)

;; geolocation-position-error-wrap/checked : symbol? any/c -> geolocation-position-error?
;;   Validate and wrap an error object supplied by a browser callback.
(define (geolocation-position-error-wrap/checked who raw)
  (define err (geolocation-position-error raw))
  (unless (geolocation-position-error? err)
    (raise-arguments-error who
                           "Geolocation error callback argument must be GeolocationPositionError"))
  err)

;; geolocation-position-raw : geolocation-position? -> external/raw
;;   Extract the raw GeolocationPosition object.
(define (geolocation-position-raw value)
  (geolocation-position-info-raw value))

;; geolocation-coordinates-raw : geolocation-coordinates? -> external/raw
;;   Extract the raw GeolocationCoordinates object.
(define (geolocation-coordinates-raw value)
  (geolocation-coordinates-info-raw value))

;; geolocation-position-error-raw : geolocation-position-error? -> external/raw
;;   Extract the raw GeolocationPositionError object.
(define (geolocation-position-error-raw value)
  (geolocation-position-error-info-raw value))

;; geolocation-position-host-value? : any/c -> boolean?
;;   Report whether value wraps a non-null GeolocationPosition-like host value.
(define (geolocation-position-host-value? value)
  (and (geolocation-position-info? value)
       (geolocation-raw-host-value? (geolocation-position-raw value))))

;; geolocation-coordinates-host-value? : any/c -> boolean?
;;   Report whether value wraps a non-null GeolocationCoordinates-like host value.
(define (geolocation-coordinates-host-value? value)
  (and (geolocation-coordinates-info? value)
       (geolocation-raw-host-value? (geolocation-coordinates-raw value))))

;; geolocation-position-error-host-value? : any/c -> boolean?
;;   Report whether value wraps a non-null GeolocationPositionError-like host value.
(define (geolocation-position-error-host-value? value)
  (and (geolocation-position-error-info? value)
       (geolocation-raw-host-value? (geolocation-position-error-raw value))))

;; geolocation-coordinates-core-surface-present? : external/raw -> boolean?
;;   Report whether raw has the required GeolocationCoordinates properties.
(define (geolocation-coordinates-core-surface-present? raw)
  (and (geolocation-property-present? raw "latitude")
       (geolocation-property-present? raw "longitude")
       (geolocation-property-present? raw "accuracy")))

;; geolocation-position-core-surface-present? : external/raw -> boolean?
;;   Report whether raw has the required GeolocationPosition properties.
(define (geolocation-position-core-surface-present? raw)
  (and (geolocation-property-present? raw "coords")
       (geolocation-property-present? raw "timestamp")
       (geolocation-coordinates-core-surface-present?
        (js-ref/extern raw "coords"))))

;; geolocation-position-error-core-surface-present? : external/raw -> boolean?
;;   Report whether raw has the required GeolocationPositionError properties.
(define (geolocation-position-error-core-surface-present? raw)
  (and (geolocation-property-present? raw "code")
       (geolocation-property-present? raw "message")))

;; geolocation-position? : any/c -> boolean?
;;   Report whether value is a usable wrapped GeolocationPosition value.
(define (geolocation-position? value)
  (and (geolocation-position-host-value? value)
       (geolocation-position-core-surface-present?
        (geolocation-position-raw value))))

;; geolocation-coordinates? : any/c -> boolean?
;;   Report whether value is a usable wrapped GeolocationCoordinates value.
(define (geolocation-coordinates? value)
  (and (geolocation-coordinates-host-value? value)
       (geolocation-coordinates-core-surface-present?
        (geolocation-coordinates-raw value))))

;; geolocation-position-error? : any/c -> boolean?
;;   Report whether value is a usable wrapped GeolocationPositionError value.
(define (geolocation-position-error? value)
  (and (geolocation-position-error-host-value? value)
       (geolocation-position-error-core-surface-present?
        (geolocation-position-error-raw value))))

;; geolocation-supported-raw : -> (or/c #f external/raw)
;;   Read navigator.geolocation when the required methods are available.
(define (geolocation-supported-raw)
  (with-handlers ([exn:fail? (lambda (_e) #f)])
    (define raw (js-ref/extern (js-window-navigator) "geolocation"))
    (and (not (js-nullish? raw))
         (geolocation-core-methods-present? raw)
         raw)))

(define (geolocation-supported?)
  (not (eq? (geolocation-supported-raw) #f)))

(define (geolocation)
  (define raw (geolocation-supported-raw))
  (and raw (geolocation-info raw)))

(define (geolocation-raw value)
  (geolocation-info-raw value))

(define (geolocation? v)
  (and (geolocation-host-value? v)
       (geolocation-core-methods-present? (geolocation-raw v))))

;; geolocation-host-value? : any/c -> boolean?
;;   Report whether v wraps an external Geolocation-like host value.
(define (geolocation-host-value? v)
  (and (geolocation-info? v)
       (geolocation-raw-host-value? (geolocation-raw v))))

;; check-geolocation : symbol? any/c -> void?
;;   Ensure value wraps an external Geolocation-like host value.
(define (check-geolocation who value)
  (unless (geolocation-host-value? value)
    (raise-argument-error who "geolocation-info?" value)))

;; check-geolocation-method : symbol? geolocation-info? string? -> void?
;;   Ensure a required Geolocation method is available.
(define (check-geolocation-method who value method-name)
  (unless (geolocation-method-present? (geolocation-raw value) method-name)
    (raise-arguments-error who
                           (string-append "Geolocation." method-name " is not available"))))

;; check-geolocation-property : symbol? external/raw string? string? -> void?
;;   Ensure a required Geolocation host property is available.
(define (check-geolocation-property who raw receiver-name property-name)
  (unless (geolocation-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " is not available"))))

(define (geolocation-options->raw options)
  (define enable-high-accuracy (geolocation-options-enable-high-accuracy options))
  (define timeout (geolocation-options-timeout options))
  (define maximum-age (geolocation-options-maximum-age options))
  (define fields
    (append
     (if (eq? enable-high-accuracy #f)
         '()
         (list (vector "enableHighAccuracy" enable-high-accuracy)))
     (if (eq? timeout #f)
         '()
         (list (vector "timeout" timeout)))
     (if (eq? maximum-age #f)
         '()
         (list (vector "maximumAge" maximum-age)))))
  (js-object (list->vector fields)))

(define geolocation-success-callback-cache (make-hasheq))
(define geolocation-error-callback-cache (make-hasheq))

(define (geolocation-success-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref geolocation-success-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda (raw-position)
             (callback (geolocation-position-wrap/checked who raw-position))
             (void))))
        (hash-set! geolocation-success-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

(define (geolocation-error-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref geolocation-error-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda (raw-error)
             (callback (geolocation-position-error-wrap/checked who raw-error))
             (void))))
        (hash-set! geolocation-error-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

(define (geolocation-optional-number raw field)
  (define value (js-ref/extern raw field))
  (if (js-nullish? value) #f value))

(define (geolocation-get-current-position geo on-success [on-error #f] [options #f])
  (check-geolocation 'geolocation-get-current-position geo)
  (check-geolocation-method 'geolocation-get-current-position geo "getCurrentPosition")
  (unless (or (eq? on-error #f) (external? on-error) (procedure? on-error))
    (raise-argument-error 'geolocation-get-current-position "(or/c #f procedure? external?)" on-error))
  (unless (or (eq? options #f) (geolocation-options? options))
    (raise-argument-error 'geolocation-get-current-position "(or/c #f geolocation-options?)" options))
  (define success* (geolocation-success-callback->external 'geolocation-get-current-position on-success))
  (define args
    (cond
      [(and (eq? on-error #f) (eq? options #f))
       (vector success*)]
      [(eq? options #f)
       (vector success*
               (geolocation-error-callback->external 'geolocation-get-current-position on-error))]
      [(eq? on-error #f)
       (vector success*
               (void)
               (geolocation-options->raw options))]
      [else
       (vector success*
               (geolocation-error-callback->external 'geolocation-get-current-position on-error)
               (geolocation-options->raw options))]))
  (js-send/extern/nullish (geolocation-raw geo) "getCurrentPosition" args)
  (void))

(define (geolocation-watch-position geo on-success [on-error #f] [options #f])
  (check-geolocation 'geolocation-watch-position geo)
  (check-geolocation-method 'geolocation-watch-position geo "watchPosition")
  (unless (or (eq? on-error #f) (external? on-error) (procedure? on-error))
    (raise-argument-error 'geolocation-watch-position "(or/c #f procedure? external?)" on-error))
  (unless (or (eq? options #f) (geolocation-options? options))
    (raise-argument-error 'geolocation-watch-position "(or/c #f geolocation-options?)" options))
  (define success* (geolocation-success-callback->external 'geolocation-watch-position on-success))
  (define args
    (cond
      [(and (eq? on-error #f) (eq? options #f))
       (vector success*)]
      [(eq? options #f)
       (vector success*
               (geolocation-error-callback->external 'geolocation-watch-position on-error))]
      [(eq? on-error #f)
       (vector success*
               (void)
               (geolocation-options->raw options))]
      [else
       (vector success*
               (geolocation-error-callback->external 'geolocation-watch-position on-error)
               (geolocation-options->raw options))]))
  (geolocation-check-watch-id-result
   'geolocation-watch-position
   (js-send/value (geolocation-raw geo) "watchPosition" args)))

(define (geolocation-clear-watch! geo watch-id)
  (check-geolocation 'geolocation-clear-watch! geo)
  (check-geolocation-method 'geolocation-clear-watch! geo "clearWatch")
  (unless (exact-nonnegative-integer? watch-id)
    (raise-argument-error 'geolocation-clear-watch! "exact-nonnegative-integer?" watch-id))
  (js-send/extern/nullish (geolocation-raw geo) "clearWatch" (vector watch-id))
  (void))

(define (geolocation-position-coordinates position)
  (unless (geolocation-position-host-value? position)
    (raise-argument-error 'geolocation-position-coordinates "geolocation-position?" position))
  (check-geolocation-property 'geolocation-position-coordinates
                              (geolocation-position-raw position)
                              "GeolocationPosition"
                              "coords")
  (geolocation-coordinates (js-ref/extern (geolocation-position-raw position) "coords")))

(define (geolocation-position-timestamp position)
  (unless (geolocation-position-host-value? position)
    (raise-argument-error 'geolocation-position-timestamp "geolocation-position?" position))
  (check-geolocation-property 'geolocation-position-timestamp
                              (geolocation-position-raw position)
                              "GeolocationPosition"
                              "timestamp")
  (js-ref (geolocation-position-raw position) "timestamp"))

(define (geolocation-coordinates-latitude coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-latitude "geolocation-coordinates?" coords))
  (check-geolocation-property 'geolocation-coordinates-latitude
                              (geolocation-coordinates-raw coords)
                              "GeolocationCoordinates"
                              "latitude")
  (js-ref (geolocation-coordinates-raw coords) "latitude"))

(define (geolocation-coordinates-longitude coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-longitude "geolocation-coordinates?" coords))
  (check-geolocation-property 'geolocation-coordinates-longitude
                              (geolocation-coordinates-raw coords)
                              "GeolocationCoordinates"
                              "longitude")
  (js-ref (geolocation-coordinates-raw coords) "longitude"))

(define (geolocation-coordinates-accuracy coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-accuracy "geolocation-coordinates?" coords))
  (check-geolocation-property 'geolocation-coordinates-accuracy
                              (geolocation-coordinates-raw coords)
                              "GeolocationCoordinates"
                              "accuracy")
  (js-ref (geolocation-coordinates-raw coords) "accuracy"))

(define (geolocation-coordinates-altitude coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-altitude "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "altitude"))

(define (geolocation-coordinates-altitude-accuracy coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-altitude-accuracy "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "altitudeAccuracy"))

(define (geolocation-coordinates-heading coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-heading "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "heading"))

(define (geolocation-coordinates-speed coords)
  (unless (geolocation-coordinates-host-value? coords)
    (raise-argument-error 'geolocation-coordinates-speed "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "speed"))

(define (geolocation-position-error-code err)
  (unless (geolocation-position-error-host-value? err)
    (raise-argument-error 'geolocation-position-error-code "geolocation-position-error?" err))
  (check-geolocation-property 'geolocation-position-error-code
                              (geolocation-position-error-raw err)
                              "GeolocationPositionError"
                              "code")
  (js-ref (geolocation-position-error-raw err) "code"))

(define (geolocation-position-error-message err)
  (unless (geolocation-position-error-host-value? err)
    (raise-argument-error 'geolocation-position-error-message "geolocation-position-error?" err))
  (check-geolocation-property 'geolocation-position-error-message
                              (geolocation-position-error-raw err)
                              "GeolocationPositionError"
                              "message")
  (js-ref (geolocation-position-error-raw err) "message"))
