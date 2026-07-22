#lang webracket/base

;; Browser smoke for Geolocation wrapper host-boundary errors.

(require geolocation
         (only-in webracket/unsafe/dom
                  js-eval
                  js-null
                  js-undefined))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(js-eval
 "globalThis.__wrGeolocationBoundaryFake = (missing) => {
    const geo = {
      getCurrentPosition(_success, _error, _options) {},
      watchPosition(_success, _error, _options) { return 1; },
      clearWatch(_watchId) {}
    };
    delete geo[missing];
    return geo;
  };
  globalThis.__wrGeolocationBoundaryFakePosition = (missing) => {
    const position = {
      coords: {
        latitude: 55.6761,
        longitude: 12.5683,
        accuracy: 10,
        altitude: null,
        altitudeAccuracy: null,
        heading: null,
        speed: null
      },
      timestamp: 12345
    };
    delete position[missing];
    return position;
  };
  globalThis.__wrGeolocationBoundaryFakePositionCoordinates = (missing) => {
    const position = {
      coords: {
        latitude: 55.6761,
        longitude: 12.5683,
        accuracy: 10,
        altitude: null,
        altitudeAccuracy: null,
        heading: null,
        speed: null
      },
      timestamp: 12345
    };
    delete position.coords[missing];
    return position;
  };
  globalThis.__wrGeolocationBoundaryFakeCoordinates = (missing) => {
    const coords = {
      latitude: 55.6761,
      longitude: 12.5683,
      accuracy: 10,
      altitude: null,
      altitudeAccuracy: null,
      heading: null,
      speed: null
    };
    delete coords[missing];
    return coords;
  };
  globalThis.__wrGeolocationBoundaryFakeError = (missing) => {
    const err = {
      code: 1,
      message: 'permission denied'
    };
    delete err[missing];
    return err;
  };
  globalThis.__wrGeolocationBoundarySavedNavigator =
    Object.getOwnPropertyDescriptor(window, 'navigator') || null;
  globalThis.__wrGeolocationBoundaryHideNavigator = () => {
    Object.defineProperty(window, 'navigator', {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrGeolocationBoundaryRestoreNavigator = () => {
    const descriptor = globalThis.__wrGeolocationBoundarySavedNavigator;
    if (descriptor) {
      Object.defineProperty(window, 'navigator', descriptor);
    } else {
      delete window.navigator;
    }
  };")

(define (fake-geolocation missing)
  (geolocation-info (js-eval (string-append "__wrGeolocationBoundaryFake('"
                                            missing
                                            "')"))))

(define (fake-position missing)
  (geolocation-position
   (js-eval
    (string-append "__wrGeolocationBoundaryFakePosition('"
                   missing
                   "')"))))

(define (fake-position-coordinates missing)
  (geolocation-position
   (js-eval
    (string-append "__wrGeolocationBoundaryFakePositionCoordinates('"
                   missing
                   "')"))))

(define (fake-coordinates missing)
  (geolocation-coordinates
   (js-eval
    (string-append "__wrGeolocationBoundaryFakeCoordinates('"
                   missing
                   "')"))))

(define (fake-error missing)
  (geolocation-position-error
   (js-eval
    (string-append "__wrGeolocationBoundaryFakeError('"
                   missing
                   "')"))))

(define missing-current-position-geolocation
  (fake-geolocation "getCurrentPosition"))

(define missing-watch-position-geolocation
  (fake-geolocation "watchPosition"))

(define missing-clear-watch-geolocation
  (fake-geolocation "clearWatch"))

(define null-raw-geolocation
  (geolocation-info (js-null)))

(define undefined-raw-geolocation
  (geolocation-info (js-undefined)))

(define null-raw-position
  (geolocation-position (js-null)))

(define undefined-raw-position
  (geolocation-position (js-undefined)))

(define null-raw-coordinates
  (geolocation-coordinates (js-null)))

(define undefined-raw-coordinates
  (geolocation-coordinates (js-undefined)))

(define null-raw-error
  (geolocation-position-error (js-null)))

(define undefined-raw-error
  (geolocation-position-error (js-undefined)))

(define (with-missing-navigator thunk)
  (js-eval "__wrGeolocationBoundaryHideNavigator();")
  (define result (thunk))
  (js-eval "__wrGeolocationBoundaryRestoreNavigator();")
  result)

(check-true (not (geolocation? missing-current-position-geolocation))
            "geolocation? rejects missing getCurrentPosition")
(check-true (not (geolocation? missing-watch-position-geolocation))
            "geolocation? rejects missing watchPosition")
(check-true (not (geolocation? missing-clear-watch-geolocation))
            "geolocation? rejects missing clearWatch")
(check-true (not (geolocation? null-raw-geolocation))
            "geolocation? rejects null raw")
(check-true (not (geolocation? undefined-raw-geolocation))
            "geolocation? rejects undefined raw")
(check-true (geolocation-position? (fake-position "none"))
            "geolocation-position? accepts complete fake position")
(check-true (not (geolocation-position? (fake-position "coords")))
            "geolocation-position? rejects missing coords")
(check-true (not (geolocation-position? (fake-position "timestamp")))
            "geolocation-position? rejects missing timestamp")
(check-true (not (geolocation-position? (fake-position-coordinates "latitude")))
            "geolocation-position? rejects nested missing latitude")
(check-true (not (geolocation-position? null-raw-position))
            "geolocation-position? rejects null raw")
(check-true (not (geolocation-position? undefined-raw-position))
            "geolocation-position? rejects undefined raw")
(check-true (geolocation-coordinates? (fake-coordinates "none"))
            "geolocation-coordinates? accepts complete fake coordinates")
(check-true (not (geolocation-coordinates? (fake-coordinates "latitude")))
            "geolocation-coordinates? rejects missing latitude")
(check-true (not (geolocation-coordinates? (fake-coordinates "longitude")))
            "geolocation-coordinates? rejects missing longitude")
(check-true (not (geolocation-coordinates? (fake-coordinates "accuracy")))
            "geolocation-coordinates? rejects missing accuracy")
(check-true (geolocation-coordinates? (fake-coordinates "altitude"))
            "geolocation-coordinates? accepts missing optional altitude")
(check-true (not (geolocation-coordinates? null-raw-coordinates))
            "geolocation-coordinates? rejects null raw")
(check-true (not (geolocation-coordinates? undefined-raw-coordinates))
            "geolocation-coordinates? rejects undefined raw")
(check-true (geolocation-position-error? (fake-error "none"))
            "geolocation-position-error? accepts complete fake error")
(check-true (not (geolocation-position-error? (fake-error "code")))
            "geolocation-position-error? rejects missing code")
(check-true (not (geolocation-position-error? (fake-error "message")))
            "geolocation-position-error? rejects missing message")
(check-true (not (geolocation-position-error? null-raw-error))
            "geolocation-position-error? rejects null raw")
(check-true (not (geolocation-position-error? undefined-raw-error))
            "geolocation-position-error? rejects undefined raw")

(check-true (eq? (with-missing-navigator
                  (lambda ()
                    (geolocation-supported?)))
                 #f)
            "geolocation-supported? returns #f when window.navigator is missing")
(check-true (eq? (with-missing-navigator
                  (lambda ()
                    (geolocation)))
                 #f)
            "geolocation returns #f when window.navigator is missing")

(define current-position-message
  (catch-message
   (lambda ()
     (geolocation-get-current-position missing-current-position-geolocation
                                       (lambda (_position) (void))))))

(define watch-position-message
  (catch-message
   (lambda ()
     (geolocation-watch-position missing-watch-position-geolocation
                                 (lambda (_position) (void))))))

(define clear-watch-message
  (catch-message
   (lambda ()
     (geolocation-clear-watch! missing-clear-watch-geolocation 1))))

(define invalid-raw-message
  (catch-message
   (lambda ()
     (geolocation-clear-watch! (geolocation-info #f) 1))))

(define null-raw-message
  (catch-message
   (lambda ()
     (geolocation-clear-watch! null-raw-geolocation 1))))

(define undefined-raw-message
  (catch-message
   (lambda ()
     (geolocation-clear-watch! undefined-raw-geolocation 1))))

(define position-coordinates-message
  (catch-message
   (lambda ()
     (geolocation-position-coordinates (fake-position "coords")))))

(define position-null-raw-message
  (catch-message
   (lambda ()
     (geolocation-position-coordinates null-raw-position))))

(define position-undefined-raw-message
  (catch-message
   (lambda ()
     (geolocation-position-coordinates undefined-raw-position))))

(define position-timestamp-message
  (catch-message
   (lambda ()
     (geolocation-position-timestamp (fake-position "timestamp")))))

(define coordinates-latitude-message
  (catch-message
   (lambda ()
     (geolocation-coordinates-latitude (fake-coordinates "latitude")))))

(define coordinates-null-raw-message
  (catch-message
   (lambda ()
     (geolocation-coordinates-latitude null-raw-coordinates))))

(define coordinates-undefined-raw-message
  (catch-message
   (lambda ()
     (geolocation-coordinates-latitude undefined-raw-coordinates))))

(define coordinates-longitude-message
  (catch-message
   (lambda ()
     (geolocation-coordinates-longitude (fake-coordinates "longitude")))))

(define coordinates-accuracy-message
  (catch-message
   (lambda ()
     (geolocation-coordinates-accuracy (fake-coordinates "accuracy")))))

(define error-code-message
  (catch-message
   (lambda ()
     (geolocation-position-error-code (fake-error "code")))))

(define error-null-raw-message
  (catch-message
   (lambda ()
     (geolocation-position-error-code null-raw-error))))

(define error-undefined-raw-message
  (catch-message
   (lambda ()
     (geolocation-position-error-code undefined-raw-error))))

(define error-message-message
  (catch-message
   (lambda ()
     (geolocation-position-error-message (fake-error "message")))))

(check-true (eq? (geolocation-coordinates-altitude (fake-coordinates "altitude"))
                 #f)
            "missing optional altitude returns #f")

(check-message current-position-message
               "Geolocation.getCurrentPosition is not available"
               "missing Geolocation.getCurrentPosition message")
(check-message watch-position-message
               "Geolocation.watchPosition is not available"
               "missing Geolocation.watchPosition message")
(check-message clear-watch-message
               "Geolocation.clearWatch is not available"
               "missing Geolocation.clearWatch message")
(check-message invalid-raw-message
               "geolocation-info?"
               "missing geolocation-info invalid raw message")
(check-message null-raw-message
               "geolocation-info?"
               "missing geolocation-info null raw message")
(check-message undefined-raw-message
               "geolocation-info?"
               "missing geolocation-info undefined raw message")
(check-message position-coordinates-message
               "GeolocationPosition.coords is not available"
               "missing GeolocationPosition.coords message")
(check-message position-null-raw-message
               "geolocation-position?"
               "missing geolocation-position null raw message")
(check-message position-undefined-raw-message
               "geolocation-position?"
               "missing geolocation-position undefined raw message")
(check-message position-timestamp-message
               "GeolocationPosition.timestamp is not available"
               "missing GeolocationPosition.timestamp message")
(check-message coordinates-latitude-message
               "GeolocationCoordinates.latitude is not available"
               "missing GeolocationCoordinates.latitude message")
(check-message coordinates-null-raw-message
               "geolocation-coordinates?"
               "missing geolocation-coordinates null raw message")
(check-message coordinates-undefined-raw-message
               "geolocation-coordinates?"
               "missing geolocation-coordinates undefined raw message")
(check-message coordinates-longitude-message
               "GeolocationCoordinates.longitude is not available"
               "missing GeolocationCoordinates.longitude message")
(check-message coordinates-accuracy-message
               "GeolocationCoordinates.accuracy is not available"
               "missing GeolocationCoordinates.accuracy message")
(check-message error-code-message
               "GeolocationPositionError.code is not available"
               "missing GeolocationPositionError.code message")
(check-message error-null-raw-message
               "geolocation-position-error?"
               "missing geolocation-position-error null raw message")
(check-message error-undefined-raw-message
               "geolocation-position-error?"
               "missing geolocation-position-error undefined raw message")
(check-message error-message-message
               "GeolocationPositionError.message is not available"
               "missing GeolocationPositionError.message message")

(js-eval
 "delete globalThis.__wrGeolocationBoundaryFake;
  delete globalThis.__wrGeolocationBoundaryFakePosition;
  delete globalThis.__wrGeolocationBoundaryFakePositionCoordinates;
  delete globalThis.__wrGeolocationBoundaryFakeCoordinates;
  delete globalThis.__wrGeolocationBoundaryFakeError;
  delete globalThis.__wrGeolocationBoundarySavedNavigator;
  delete globalThis.__wrGeolocationBoundaryHideNavigator;
  delete globalThis.__wrGeolocationBoundaryRestoreNavigator;")

(js-log "geolocation-method-missing-host-ffi-ok")
#t
