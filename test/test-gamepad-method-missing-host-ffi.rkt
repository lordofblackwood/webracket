#lang webracket/base

;; Browser smoke for Gamepad wrapper host boundary errors.

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
  globalThis.__wrGamepadBoundaryFakeGamepad = (missing) => {
    const gamepad = {
      id: 'wr-gamepad',
      index: 0,
      connected: true,
      timestamp: 1.5,
      mapping: 'standard',
      axes: [0.0],
      buttons: [{ pressed: false, touched: false, value: 0.0 }]
    };
    delete gamepad[missing];
    return gamepad;
  };
  globalThis.__wrGamepadBoundaryFakeButton = (missing) => {
    const button = {
      pressed: false,
      touched: false,
      value: 0.0
    };
    delete button[missing];
    return button;
  };
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
    delete globalThis.__wrGamepadBoundaryFakeGamepad;
    delete globalThis.__wrGamepadBoundaryFakeButton;
    delete globalThis.__wrGamepadBoundaryPatch;
    delete globalThis.__wrGamepadBoundaryRestore;
    delete globalThis.__wrGamepadBoundaryRestoreAll;
  };")

(define (fake-gamepad missing-property)
  (gamepad-wrap
   (js-eval
    (string-append "__wrGamepadBoundaryFakeGamepad('"
                   missing-property
                   "')"))))

(define (fake-button missing-property)
  (gamepad-button-wrap
   (js-eval
    (string-append "__wrGamepadBoundaryFakeButton('"
                   missing-property
                   "')"))))

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

(define id-message
  (catch-message
   (lambda ()
     (gamepad-id (fake-gamepad "id")))))

(define index-message
  (catch-message
   (lambda ()
     (gamepad-index (fake-gamepad "index")))))

(define connected-message
  (catch-message
   (lambda ()
     (gamepad-connected? (fake-gamepad "connected")))))

(define timestamp-message
  (catch-message
   (lambda ()
     (gamepad-timestamp (fake-gamepad "timestamp")))))

(define mapping-message
  (catch-message
   (lambda ()
     (gamepad-mapping (fake-gamepad "mapping")))))

(define axes-message
  (catch-message
   (lambda ()
     (gamepad-axes (fake-gamepad "axes")))))

(define buttons-message
  (catch-message
   (lambda ()
     (gamepad-buttons (fake-gamepad "buttons")))))

(define button-pressed-message
  (catch-message
   (lambda ()
     (gamepad-button-pressed? (fake-button "pressed")))))

(define button-touched-message
  (catch-message
   (lambda ()
     (gamepad-button-touched? (fake-button "touched")))))

(define button-value-message
  (catch-message
   (lambda ()
     (gamepad-button-value (fake-button "value")))))

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
(check-message id-message
               "Gamepad.id is not available"
               "missing Gamepad.id message")
(check-message index-message
               "Gamepad.index is not available"
               "missing Gamepad.index message")
(check-message connected-message
               "Gamepad.connected is not available"
               "missing Gamepad.connected message")
(check-message timestamp-message
               "Gamepad.timestamp is not available"
               "missing Gamepad.timestamp message")
(check-message mapping-message
               "Gamepad.mapping is not available"
               "missing Gamepad.mapping message")
(check-message axes-message
               "Gamepad.axes is not available"
               "missing Gamepad.axes message")
(check-message buttons-message
               "Gamepad.buttons is not available"
               "missing Gamepad.buttons message")
(check-message button-pressed-message
               "GamepadButton.pressed is not available"
               "missing GamepadButton.pressed message")
(check-message button-touched-message
               "GamepadButton.touched is not available"
               "missing GamepadButton.touched message")
(check-message button-value-message
               "GamepadButton.value is not available"
               "missing GamepadButton.value message")

(js-eval "__wrGamepadBoundaryRestoreAll();")

(js-log "gamepad-method-missing-host-ffi-ok")
#t
