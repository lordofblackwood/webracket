#lang webracket/base

;; Browser smoke for ScreenOrientation wrapper host-method boundary errors.

(require screen-orientation
         (only-in webracket/unsafe/standard
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
    delete orientation[missing];
    return orientation;
  };")

(define (fake-orientation missing)
  (screen-orientation-info
   (js-eval (string-append "__wrScreenOrientationBoundaryFake('"
                           missing
                           "')"))))

(define missing-lock-orientation
  (fake-orientation "lock"))

(define missing-unlock-orientation
  (fake-orientation "unlock"))

(define missing-add-listener-orientation
  (fake-orientation "addEventListener"))

(define missing-remove-listener-orientation
  (fake-orientation "removeEventListener"))

(check-true (screen-orientation? missing-lock-orientation)
            "screen-orientation? accepts external orientation-like value")

(define lock-message
  (catch-message
   (lambda ()
     (screen-orientation-lock! missing-lock-orientation 'portrait))))

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

(check-message lock-message
               "ScreenOrientation.lock is not available"
               "missing ScreenOrientation.lock message")
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

(js-eval "delete globalThis.__wrScreenOrientationBoundaryFake;")

(js-log "screen-orientation-method-missing-host-ffi-ok")
#t
