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

(provide (all-defined-out))

;;;
;;; Geolocation wrappers
;;;

(struct geolocation-info (raw) #:transparent)
(struct geolocation-position (raw) #:transparent)
(struct geolocation-coordinates (raw) #:transparent)
(struct geolocation-position-error (raw) #:transparent)

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
             (callback (geolocation-position raw-position))
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
             (callback (geolocation-position-error raw-error))
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
  (js-send/value (geolocation-raw geo) "watchPosition" args))

(define (geolocation-clear-watch! geo watch-id)
  (check-geolocation 'geolocation-clear-watch! geo)
  (check-geolocation-method 'geolocation-clear-watch! geo "clearWatch")
  (unless (exact-nonnegative-integer? watch-id)
    (raise-argument-error 'geolocation-clear-watch! "exact-nonnegative-integer?" watch-id))
  (js-send/extern/nullish (geolocation-raw geo) "clearWatch" (vector watch-id))
  (void))

(define (geolocation-position-coordinates position)
  (unless (and (geolocation-position? position)
               (geolocation-raw-host-value? (geolocation-position-raw position)))
    (raise-argument-error 'geolocation-position-coordinates "geolocation-position?" position))
  (check-geolocation-property 'geolocation-position-coordinates
                              (geolocation-position-raw position)
                              "GeolocationPosition"
                              "coords")
  (geolocation-coordinates (js-ref/extern (geolocation-position-raw position) "coords")))

(define (geolocation-position-timestamp position)
  (unless (and (geolocation-position? position)
               (geolocation-raw-host-value? (geolocation-position-raw position)))
    (raise-argument-error 'geolocation-position-timestamp "geolocation-position?" position))
  (check-geolocation-property 'geolocation-position-timestamp
                              (geolocation-position-raw position)
                              "GeolocationPosition"
                              "timestamp")
  (js-ref (geolocation-position-raw position) "timestamp"))

(define (geolocation-coordinates-latitude coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-latitude "geolocation-coordinates?" coords))
  (check-geolocation-property 'geolocation-coordinates-latitude
                              (geolocation-coordinates-raw coords)
                              "GeolocationCoordinates"
                              "latitude")
  (js-ref (geolocation-coordinates-raw coords) "latitude"))

(define (geolocation-coordinates-longitude coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-longitude "geolocation-coordinates?" coords))
  (check-geolocation-property 'geolocation-coordinates-longitude
                              (geolocation-coordinates-raw coords)
                              "GeolocationCoordinates"
                              "longitude")
  (js-ref (geolocation-coordinates-raw coords) "longitude"))

(define (geolocation-coordinates-accuracy coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-accuracy "geolocation-coordinates?" coords))
  (check-geolocation-property 'geolocation-coordinates-accuracy
                              (geolocation-coordinates-raw coords)
                              "GeolocationCoordinates"
                              "accuracy")
  (js-ref (geolocation-coordinates-raw coords) "accuracy"))

(define (geolocation-coordinates-altitude coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-altitude "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "altitude"))

(define (geolocation-coordinates-altitude-accuracy coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-altitude-accuracy "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "altitudeAccuracy"))

(define (geolocation-coordinates-heading coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-heading "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "heading"))

(define (geolocation-coordinates-speed coords)
  (unless (and (geolocation-coordinates? coords)
               (geolocation-raw-host-value? (geolocation-coordinates-raw coords)))
    (raise-argument-error 'geolocation-coordinates-speed "geolocation-coordinates?" coords))
  (geolocation-optional-number (geolocation-coordinates-raw coords) "speed"))

(define (geolocation-position-error-code err)
  (unless (and (geolocation-position-error? err)
               (geolocation-raw-host-value? (geolocation-position-error-raw err)))
    (raise-argument-error 'geolocation-position-error-code "geolocation-position-error?" err))
  (check-geolocation-property 'geolocation-position-error-code
                              (geolocation-position-error-raw err)
                              "GeolocationPositionError"
                              "code")
  (js-ref (geolocation-position-error-raw err) "code"))

(define (geolocation-position-error-message err)
  (unless (and (geolocation-position-error? err)
               (geolocation-raw-host-value? (geolocation-position-error-raw err)))
    (raise-argument-error 'geolocation-position-error-message "geolocation-position-error?" err))
  (check-geolocation-property 'geolocation-position-error-message
                              (geolocation-position-error-raw err)
                              "GeolocationPositionError"
                              "message")
  (js-ref (geolocation-position-error-raw err) "message"))
