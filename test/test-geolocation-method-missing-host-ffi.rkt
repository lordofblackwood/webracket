#lang webracket/base

;; Browser smoke for Geolocation wrapper host-boundary errors.

(require geolocation
         (only-in webracket/unsafe/dom
                  js-eval))

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

(define position-coordinates-message
  (catch-message
   (lambda ()
     (geolocation-position-coordinates (fake-position "coords")))))

(define position-timestamp-message
  (catch-message
   (lambda ()
     (geolocation-position-timestamp (fake-position "timestamp")))))

(define coordinates-latitude-message
  (catch-message
   (lambda ()
     (geolocation-coordinates-latitude (fake-coordinates "latitude")))))

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
(check-message position-coordinates-message
               "GeolocationPosition.coords is not available"
               "missing GeolocationPosition.coords message")
(check-message position-timestamp-message
               "GeolocationPosition.timestamp is not available"
               "missing GeolocationPosition.timestamp message")
(check-message coordinates-latitude-message
               "GeolocationCoordinates.latitude is not available"
               "missing GeolocationCoordinates.latitude message")
(check-message coordinates-longitude-message
               "GeolocationCoordinates.longitude is not available"
               "missing GeolocationCoordinates.longitude message")
(check-message coordinates-accuracy-message
               "GeolocationCoordinates.accuracy is not available"
               "missing GeolocationCoordinates.accuracy message")
(check-message error-code-message
               "GeolocationPositionError.code is not available"
               "missing GeolocationPositionError.code message")
(check-message error-message-message
               "GeolocationPositionError.message is not available"
               "missing GeolocationPositionError.message message")

(js-eval
 "delete globalThis.__wrGeolocationBoundaryFake;
  delete globalThis.__wrGeolocationBoundaryFakePosition;
  delete globalThis.__wrGeolocationBoundaryFakeCoordinates;
  delete globalThis.__wrGeolocationBoundaryFakeError;
  delete globalThis.__wrGeolocationBoundarySavedNavigator;
  delete globalThis.__wrGeolocationBoundaryHideNavigator;
  delete globalThis.__wrGeolocationBoundaryRestoreNavigator;")

(js-log "geolocation-method-missing-host-ffi-ok")
#t
