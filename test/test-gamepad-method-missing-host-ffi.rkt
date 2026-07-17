#lang webracket/base

;; Browser smoke for Gamepad wrapper host-method boundary errors.

(require gamepad
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
 "globalThis.__wrGamepadBoundarySaved = {};
  globalThis.__wrGamepadBoundaryTarget = (name) =>
    name === 'navigator' ? navigator : window;
  globalThis.__wrGamepadBoundaryPatch = (targetName, methodName) => {
    const target = globalThis.__wrGamepadBoundaryTarget(targetName);
    const key = `${targetName}.${methodName}`;
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrGamepadBoundarySaved, key)) {
      globalThis.__wrGamepadBoundarySaved[key] =
        Object.getOwnPropertyDescriptor(target, methodName) || null;
    }
    Object.defineProperty(target, methodName, {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrGamepadBoundaryRestore = (targetName, methodName) => {
    const target = globalThis.__wrGamepadBoundaryTarget(targetName);
    const key = `${targetName}.${methodName}`;
    const descriptor = globalThis.__wrGamepadBoundarySaved[key];
    if (descriptor) {
      Object.defineProperty(target, methodName, descriptor);
    } else {
      delete target[methodName];
    }
    delete globalThis.__wrGamepadBoundarySaved[key];
  };
  globalThis.__wrGamepadBoundaryRestoreAll = () => {
    for (const key of Object.keys(globalThis.__wrGamepadBoundarySaved)) {
      const dot = key.indexOf('.');
      globalThis.__wrGamepadBoundaryRestore(key.slice(0, dot), key.slice(dot + 1));
    }
    delete globalThis.__wrGamepadBoundarySaved;
    delete globalThis.__wrGamepadBoundaryTarget;
    delete globalThis.__wrGamepadBoundaryPatch;
    delete globalThis.__wrGamepadBoundaryRestore;
    delete globalThis.__wrGamepadBoundaryRestoreAll;
  };")

(define (missing-method-message target method thunk)
  (js-eval (string-append "__wrGamepadBoundaryPatch('"
                          target
                          "', '"
                          method
                          "')"))
  (define message (catch-message thunk))
  (js-eval (string-append "__wrGamepadBoundaryRestore('"
                          target
                          "', '"
                          method
                          "')"))
  message)

(define callback (lambda args (void)))

(define get-gamepads-message
  (missing-method-message
   "navigator"
   "getGamepads"
   (lambda ()
     (gamepads))))

(define add-connected-message
  (missing-method-message
   "window"
   "addEventListener"
   (lambda ()
     (gamepad-add-connected-listener! callback))))

(define remove-connected-message
  (missing-method-message
   "window"
   "removeEventListener"
   (lambda ()
     (gamepad-remove-connected-listener! callback))))

(define add-disconnected-message
  (missing-method-message
   "window"
   "addEventListener"
   (lambda ()
     (gamepad-add-disconnected-listener! callback))))

(define remove-disconnected-message
  (missing-method-message
   "window"
   "removeEventListener"
   (lambda ()
     (gamepad-remove-disconnected-listener! callback))))

(check-message get-gamepads-message
               "navigator.getGamepads is not available"
               "missing navigator.getGamepads message")
(check-message add-connected-message
               "window.addEventListener is not available"
               "missing add connected listener message")
(check-message remove-connected-message
               "window.removeEventListener is not available"
               "missing remove connected listener message")
(check-message add-disconnected-message
               "window.addEventListener is not available"
               "missing add disconnected listener message")
(check-message remove-disconnected-message
               "window.removeEventListener is not available"
               "missing remove disconnected listener message")

(js-eval "__wrGamepadBoundaryRestoreAll();")

(js-log "gamepad-method-missing-host-ffi-ok")
#t
