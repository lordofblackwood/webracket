#lang webracket/base

;; Browser smoke for Gamepad wrapper host boundary errors.

(require gamepad
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
  globalThis.__wrGamepadBoundaryFakeEvent = (missing) => {
    const event = {
      gamepad: globalThis.__wrGamepadBoundaryFakeGamepad('notAProperty')
    };
    if (missing === 'gamepad') {
      delete event.gamepad;
    } else if (missing === 'gamepad-null') {
      event.gamepad = null;
    }
    return event;
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
    delete globalThis.__wrGamepadBoundaryFakeEvent;
    delete globalThis.__wrGamepadBoundaryPatch;
    delete globalThis.__wrGamepadBoundaryRestore;
    delete globalThis.__wrGamepadBoundaryRestoreAll;
  };
  globalThis.__wrGamepadBoundarySavedNavigator =
    Object.getOwnPropertyDescriptor(window, 'navigator') || null;
  globalThis.__wrGamepadBoundaryHideNavigator = () => {
    Object.defineProperty(window, 'navigator', {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrGamepadBoundaryRestoreNavigator = () => {
    const descriptor = globalThis.__wrGamepadBoundarySavedNavigator;
    if (descriptor) {
      Object.defineProperty(window, 'navigator', descriptor);
    } else {
      delete window.navigator;
    }
  };")

(define (fake-gamepad missing-property)
  (gamepad-info
   (js-eval
    (string-append "__wrGamepadBoundaryFakeGamepad('"
                   missing-property
                   "')"))))

(define (fake-button missing-property)
  (gamepad-button-info
   (js-eval
    (string-append "__wrGamepadBoundaryFakeButton('"
                   missing-property
                   "')"))))

(define (fake-event missing-property)
  (js-eval
   (string-append "__wrGamepadBoundaryFakeEvent('"
                  missing-property
                  "')")))

(check-true (eq? (gamepad-wrap (js-eval "null")) #f)
            "gamepad-wrap maps null slots to #f")
(check-true (gamepad? (gamepad-wrap (js-eval "__wrGamepadBoundaryFakeGamepad('notAProperty')")))
            "gamepad-wrap preserves complete raw Gamepad objects")
(check-true (gamepad? (gamepad-info
                       (js-eval
                        "({
                           id: '',
                           index: 0,
                           connected: false,
                           timestamp: 0,
                           mapping: '',
                           axes: [],
                           buttons: []
                         })")))
            "gamepad? accepts present falsy Gamepad properties")

(define null-raw-gamepad
  (gamepad-info (js-null)))

(define undefined-raw-gamepad
  (gamepad-info (js-undefined)))

(define null-raw-button
  (gamepad-button-info (js-null)))

(define undefined-raw-button
  (gamepad-button-info (js-undefined)))

(check-true (not (gamepad? null-raw-gamepad))
            "gamepad? rejects null raw")
(check-true (not (gamepad? undefined-raw-gamepad))
            "gamepad? rejects undefined raw")
(check-true (not (gamepad-button? null-raw-button))
            "gamepad-button? rejects null raw")
(check-true (not (gamepad-button? undefined-raw-button))
            "gamepad-button? rejects undefined raw")
(check-true (gamepad-button? (fake-button "notAProperty"))
            "gamepad-button? accepts present falsy GamepadButton properties")
(check-true (not (gamepad? (fake-gamepad "id")))
            "gamepad? rejects raw Gamepad missing id")
(check-true (not (gamepad? (fake-gamepad "index")))
            "gamepad? rejects raw Gamepad missing index")
(check-true (not (gamepad? (fake-gamepad "connected")))
            "gamepad? rejects raw Gamepad missing connected")
(check-true (not (gamepad? (fake-gamepad "timestamp")))
            "gamepad? rejects raw Gamepad missing timestamp")
(check-true (not (gamepad? (fake-gamepad "mapping")))
            "gamepad? rejects raw Gamepad missing mapping")
(check-true (not (gamepad? (fake-gamepad "axes")))
            "gamepad? rejects raw Gamepad missing axes")
(check-true (not (gamepad? (fake-gamepad "buttons")))
            "gamepad? rejects raw Gamepad missing buttons")
(check-true (not (gamepad-button? (fake-button "pressed")))
            "gamepad-button? rejects raw GamepadButton missing pressed")
(check-true (not (gamepad-button? (fake-button "touched")))
            "gamepad-button? rejects raw GamepadButton missing touched")
(check-true (not (gamepad-button? (fake-button "value")))
            "gamepad-button? rejects raw GamepadButton missing value")

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

(define (with-missing-navigator thunk)
  (js-eval "__wrGamepadBoundaryHideNavigator();")
  (define result (thunk))
  (js-eval "__wrGamepadBoundaryRestoreNavigator();")
  result)

(check-true (eq? (with-missing-navigator
                  (lambda ()
                    (gamepad-supported?)))
                 #f)
            "gamepad-supported? returns #f when window.navigator is missing")

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

(define gamepad-null-raw-message
  (catch-message
   (lambda ()
     (gamepad-id null-raw-gamepad))))

(define gamepad-undefined-raw-message
  (catch-message
   (lambda ()
     (gamepad-id undefined-raw-gamepad))))

(define button-null-raw-message
  (catch-message
   (lambda ()
     (gamepad-button-value null-raw-button))))

(define button-undefined-raw-message
  (catch-message
   (lambda ()
     (gamepad-button-value undefined-raw-button))))

(define event-gamepad-message
  (catch-message
   (lambda ()
     (gamepad-event-gamepad (fake-event "gamepad")))))

(define event-null-raw-message
  (catch-message
   (lambda ()
     (gamepad-event-gamepad (js-null)))))

(define event-undefined-raw-message
  (catch-message
   (lambda ()
     (gamepad-event-gamepad (js-undefined)))))

(check-true (eq? (gamepad-event-gamepad (fake-event "gamepad-null")) #f)
            "GamepadEvent.gamepad null still maps to #f")

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
(check-message gamepad-null-raw-message
               "gamepad?"
               "missing gamepad null raw message")
(check-message gamepad-undefined-raw-message
               "gamepad?"
               "missing gamepad undefined raw message")
(check-message button-null-raw-message
               "gamepad-button?"
               "missing gamepad button null raw message")
(check-message button-undefined-raw-message
               "gamepad-button?"
               "missing gamepad button undefined raw message")
(check-message event-gamepad-message
               "GamepadEvent.gamepad is not available"
               "missing GamepadEvent.gamepad message")
(check-message event-null-raw-message
               "external?"
               "missing GamepadEvent null raw message")
(check-message event-undefined-raw-message
               "external?"
               "missing GamepadEvent undefined raw message")

(js-eval "__wrGamepadBoundaryRestoreAll();")
(js-eval
 "delete globalThis.__wrGamepadBoundarySavedNavigator;
  delete globalThis.__wrGamepadBoundaryHideNavigator;
  delete globalThis.__wrGamepadBoundaryRestoreNavigator;")

(js-log "gamepad-method-missing-host-ffi-ok")
#t
