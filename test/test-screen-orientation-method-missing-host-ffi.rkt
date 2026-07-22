#lang webracket/base

;; Browser smoke for ScreenOrientation wrapper host-boundary errors.

(require screen-orientation
         (only-in webracket/unsafe/dom
                  js-eval
                  js-null
                  js-undefined))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-false got label)
  (when got
    (error 'check-false label)))

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
 "globalThis.__wrScreenOrientationWindowBoundary = {
    screen: Object.getOwnPropertyDescriptor(globalThis, 'screen') || null,
    hideScreen() {
      Object.defineProperty(globalThis, 'screen', {
        value: undefined,
        configurable: true
      });
    },
    setScreenWithoutOrientation() {
      Object.defineProperty(globalThis, 'screen', {
        value: {},
        configurable: true
      });
    },
    setScreenWithOrientation(missing) {
      Object.defineProperty(globalThis, 'screen', {
        value: {
          orientation: globalThis.__wrScreenOrientationBoundaryFake(missing)
        },
        configurable: true
      });
    },
    restoreScreen() {
      const descriptor = globalThis.__wrScreenOrientationWindowBoundary.screen;
      if (descriptor) {
        Object.defineProperty(globalThis, 'screen', descriptor);
      } else {
        delete globalThis.screen;
      }
    }
  };")

(define missing-screen-supported?
  (let ()
    (js-eval "__wrScreenOrientationWindowBoundary.hideScreen();")
    (define supported? (screen-orientation-supported?))
    (js-eval "__wrScreenOrientationWindowBoundary.restoreScreen();")
    supported?))

(define missing-screen-orientation
  (let ()
    (js-eval "__wrScreenOrientationWindowBoundary.hideScreen();")
    (define value (screen-orientation))
    (js-eval "__wrScreenOrientationWindowBoundary.restoreScreen();")
    value))

(define missing-orientation-supported?
  (let ()
    (js-eval "__wrScreenOrientationWindowBoundary.setScreenWithoutOrientation();")
    (define supported? (screen-orientation-supported?))
    (js-eval "__wrScreenOrientationWindowBoundary.restoreScreen();")
    supported?))

(define missing-orientation-value
  (let ()
    (js-eval "__wrScreenOrientationWindowBoundary.setScreenWithoutOrientation();")
    (define value (screen-orientation))
    (js-eval "__wrScreenOrientationWindowBoundary.restoreScreen();")
    value))

(js-eval
 "globalThis.__wrScreenOrientationBoundaryFake = (missing) => {
    const thenable = {
      then(fn) { fn(undefined); return this; },
      catch(_fn) { return this; }
    };
    const orientation = {
      type: 'portrait-primary',
      angle: 0,
      onchange: null,
      lock(_type) { return thenable; },
      unlock() {},
      addEventListener(_name, _callback) {},
      removeEventListener(_name, _callback) {}
    };
    if (missing === 'lockBadResult') {
      orientation.lock = (_type) => 42;
    }
    delete orientation[missing];
    return orientation;
  };")

(define (fake-orientation missing)
  (screen-orientation-info
   (js-eval (string-append "__wrScreenOrientationBoundaryFake('"
                           missing
                           "')"))))

(define (with-fake-screen-orientation missing thunk)
  (js-eval
   (string-append "__wrScreenOrientationWindowBoundary.setScreenWithOrientation('"
                  missing
                  "');"))
  (define result (thunk))
  (js-eval "__wrScreenOrientationWindowBoundary.restoreScreen();")
  result)

(define complete-fake-supported?
  (with-fake-screen-orientation
   "notAProperty"
   (lambda ()
     (screen-orientation-supported?))))

(define complete-fake-current-orientation
  (with-fake-screen-orientation
   "notAProperty"
   (lambda ()
     (screen-orientation))))

(define missing-type-supported?
  (with-fake-screen-orientation
   "type"
   (lambda ()
     (screen-orientation-supported?))))

(define missing-type-current-orientation
  (with-fake-screen-orientation
   "type"
   (lambda ()
     (screen-orientation))))

(define missing-angle-supported?
  (with-fake-screen-orientation
   "angle"
   (lambda ()
     (screen-orientation-supported?))))

(define missing-angle-current-orientation
  (with-fake-screen-orientation
   "angle"
   (lambda ()
     (screen-orientation))))

(define missing-onchange-supported?
  (with-fake-screen-orientation
   "onchange"
   (lambda ()
     (screen-orientation-supported?))))

(define missing-onchange-current-orientation
  (with-fake-screen-orientation
   "onchange"
   (lambda ()
     (screen-orientation))))

(define complete-orientation
  (fake-orientation "notAProperty"))

(define missing-lock-orientation
  (fake-orientation "lock"))

(define bad-lock-result-orientation
  (fake-orientation "lockBadResult"))

(define missing-unlock-orientation
  (fake-orientation "unlock"))

(define missing-add-listener-orientation
  (fake-orientation "addEventListener"))

(define missing-remove-listener-orientation
  (fake-orientation "removeEventListener"))

(define missing-type-orientation
  (fake-orientation "type"))

(define missing-angle-orientation
  (fake-orientation "angle"))

(define missing-onchange-orientation
  (fake-orientation "onchange"))

(define null-raw-orientation
  (screen-orientation-info (js-null)))

(define undefined-raw-orientation
  (screen-orientation-info (js-undefined)))

(check-true complete-fake-supported?
            "screen-orientation-supported? accepts complete fake orientation")
(check-true (screen-orientation? complete-fake-current-orientation)
            "screen-orientation returns complete fake orientation")
(check-true missing-type-supported?
            "screen-orientation-supported? accepts available orientation missing type")
(check-true (screen-orientation-info? missing-type-current-orientation)
            "screen-orientation returns wrapper when orientation is missing type")
(check-false (screen-orientation? missing-type-current-orientation)
             "screen-orientation? rejects current orientation missing type")
(check-true missing-angle-supported?
            "screen-orientation-supported? accepts available orientation missing angle")
(check-true (screen-orientation-info? missing-angle-current-orientation)
            "screen-orientation returns wrapper when orientation is missing angle")
(check-false (screen-orientation? missing-angle-current-orientation)
             "screen-orientation? rejects current orientation missing angle")
(check-true missing-onchange-supported?
            "screen-orientation-supported? accepts available orientation missing onchange")
(check-true (screen-orientation-info? missing-onchange-current-orientation)
            "screen-orientation returns wrapper when orientation is missing onchange")
(check-false (screen-orientation? missing-onchange-current-orientation)
             "screen-orientation? rejects current orientation missing onchange")
(check-true (screen-orientation? complete-orientation)
            "screen-orientation? accepts present falsy ScreenOrientation properties")
(check-true (screen-orientation? missing-lock-orientation)
            "screen-orientation? accepts external orientation-like value")
(check-false (screen-orientation? missing-type-orientation)
             "screen-orientation? rejects raw ScreenOrientation missing type")
(check-false (screen-orientation? missing-angle-orientation)
             "screen-orientation? rejects raw ScreenOrientation missing angle")
(check-false (screen-orientation? missing-onchange-orientation)
             "screen-orientation? rejects raw ScreenOrientation missing onchange")
(check-false (screen-orientation-raw-host-value? (js-null))
             "screen orientation raw host value rejects null")
(check-false (screen-orientation-raw-host-value? (js-undefined))
             "screen orientation raw host value rejects undefined")
(check-false (screen-orientation-method-present? (js-null) "lock")
             "screen orientation method present rejects null target")
(check-false (screen-orientation-method-present? (js-undefined) "lock")
             "screen orientation method present rejects undefined target")
(check-false (screen-orientation-property-present? (js-null) "type")
             "screen orientation property present rejects null target")
(check-false (screen-orientation-property-present? (js-undefined) "type")
             "screen orientation property present rejects undefined target")
(check-false (screen-orientation? null-raw-orientation)
             "screen-orientation? rejects null raw")
(check-false (screen-orientation? undefined-raw-orientation)
             "screen-orientation? rejects undefined raw")

(define lock-message
  (catch-message
   (lambda ()
     (screen-orientation-lock! missing-lock-orientation 'portrait))))

(define lock-result-message
  (catch-message
   (lambda ()
     (screen-orientation-lock! bad-lock-result-orientation 'portrait))))

(define unlock-message
  (catch-message
   (lambda ()
     (screen-orientation-unlock! missing-unlock-orientation))))

(define add-listener-message
  (catch-message
   (lambda ()
     (screen-orientation-add-change-listener!
      missing-add-listener-orientation
      (lambda () (void))))))

(define remove-listener-message
  (catch-message
   (lambda ()
     (screen-orientation-remove-change-listener!
      missing-remove-listener-orientation
      (lambda () (void))))))

(define invalid-raw-message
  (catch-message
   (lambda ()
     (screen-orientation-type (screen-orientation-info #f)))))

(define null-raw-message
  (catch-message
   (lambda ()
     (screen-orientation-type null-raw-orientation))))

(define undefined-raw-message
  (catch-message
   (lambda ()
     (screen-orientation-type undefined-raw-orientation))))

(define type-message
  (catch-message
   (lambda ()
     (screen-orientation-type missing-type-orientation))))

(define angle-message
  (catch-message
   (lambda ()
     (screen-orientation-angle missing-angle-orientation))))

(define on-change-message
  (catch-message
   (lambda ()
     (screen-orientation-on-change!
      missing-onchange-orientation
      (lambda () (void))))))

(check-false missing-screen-supported?
             "screen-orientation-supported? returns #f when screen is missing")
(check-false missing-screen-orientation
             "screen-orientation returns #f when screen is missing")
(check-false missing-orientation-supported?
             "screen-orientation-supported? returns #f when screen.orientation is missing")
(check-false missing-orientation-value
             "screen-orientation returns #f when screen.orientation is missing")
(check-message lock-message
               "ScreenOrientation.lock is not available"
               "missing ScreenOrientation.lock message")
(check-message lock-result-message
               "ScreenOrientation.lock result must be Promise-like"
               "bad ScreenOrientation.lock result message")
(check-message unlock-message
               "ScreenOrientation.unlock is not available"
               "missing ScreenOrientation.unlock message")
(check-message add-listener-message
               "ScreenOrientation.addEventListener is not available"
               "missing ScreenOrientation.addEventListener message")
(check-message remove-listener-message
               "ScreenOrientation.removeEventListener is not available"
               "missing ScreenOrientation.removeEventListener message")
(check-message invalid-raw-message
               "screen-orientation?"
               "missing screen-orientation invalid raw message")
(check-message null-raw-message
               "screen-orientation?"
               "missing screen-orientation null raw message")
(check-message undefined-raw-message
               "screen-orientation?"
               "missing screen-orientation undefined raw message")
(check-message type-message
               "ScreenOrientation.type is not available"
               "missing ScreenOrientation.type message")
(check-message angle-message
               "ScreenOrientation.angle is not available"
               "missing ScreenOrientation.angle message")
(check-message on-change-message
               "ScreenOrientation.onchange is not available"
               "missing ScreenOrientation.onchange message")

(js-eval
 "delete globalThis.__wrScreenOrientationBoundaryFake;
  delete globalThis.__wrScreenOrientationWindowBoundary;")

(js-log "screen-orientation-method-missing-host-ffi-ok")
#t
