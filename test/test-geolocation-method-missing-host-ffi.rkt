#lang webracket/base

;; Browser smoke for Geolocation wrapper host-method boundary errors.

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
  };")

(define (fake-geolocation missing)
  (geolocation-info (js-eval (string-append "__wrGeolocationBoundaryFake('"
                                            missing
                                            "')"))))

(define missing-current-position-geolocation
  (fake-geolocation "getCurrentPosition"))

(define missing-watch-position-geolocation
  (fake-geolocation "watchPosition"))

(define missing-clear-watch-geolocation
  (fake-geolocation "clearWatch"))

(check-true (not (geolocation? missing-current-position-geolocation))
            "geolocation? rejects missing getCurrentPosition")
(check-true (not (geolocation? missing-watch-position-geolocation))
            "geolocation? rejects missing watchPosition")
(check-true (not (geolocation? missing-clear-watch-geolocation))
            "geolocation? rejects missing clearWatch")

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

(js-eval "delete globalThis.__wrGeolocationBoundaryFake;")

(js-log "geolocation-method-missing-host-ffi-ok")
#t
