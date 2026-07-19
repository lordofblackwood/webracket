#lang webracket/base

;; Browser smoke for event constructor and predicate host-boundary errors.

(require (only-in webracket/unsafe/event
                  js-close-event?
                  js-event-new
                  js-event?
                  js-focus-event?
                  js-input-event?
                  js-keyboard-event?
                  js-message-event?
                  js-mouse-event?
                  js-pointer-event?
                  js-submit-event?
                  js-touch-event?
                  js-touch-list?
                  js-touch?
                  js-wheel-event?)
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

(define (check-false/no-error thunk label)
  (define message
    (catch-message
     (lambda ()
       (check-true (not (thunk)) label))))
  (check-true (not message)
              (string-append label " raised unexpectedly")))

(js-eval
 "globalThis.__wrEventConstructorBoundaryNames = [
    'Event',
    'MouseEvent',
    'KeyboardEvent',
    'PointerEvent',
    'FocusEvent',
    'InputEvent',
    'SubmitEvent',
    'TouchEvent',
    'WheelEvent',
    'MessageEvent',
    'CloseEvent',
    'TouchList',
    'Touch'
  ];
  globalThis.__wrEventConstructorBoundary = {};
  for (const name of globalThis.__wrEventConstructorBoundaryNames) {
    globalThis.__wrEventConstructorBoundary[name] = {
      descriptor: Object.getOwnPropertyDescriptor(globalThis, name)
    };
    Object.defineProperty(globalThis, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define dummy (js-eval "({})"))

(define event-new-message
  (catch-message
   (lambda ()
     (js-event-new "webracket-test" (void)))))

(check-false/no-error (lambda () (js-event? dummy))
                      "event? with missing Event")
(check-false/no-error (lambda () (js-mouse-event? dummy))
                      "mouse-event? with missing MouseEvent")
(check-false/no-error (lambda () (js-keyboard-event? dummy))
                      "keyboard-event? with missing KeyboardEvent")
(check-false/no-error (lambda () (js-pointer-event? dummy))
                      "pointer-event? with missing PointerEvent")
(check-false/no-error (lambda () (js-focus-event? dummy))
                      "focus-event? with missing FocusEvent")
(check-false/no-error (lambda () (js-input-event? dummy))
                      "input-event? with missing InputEvent")
(check-false/no-error (lambda () (js-submit-event? dummy))
                      "submit-event? with missing SubmitEvent")
(check-false/no-error (lambda () (js-touch-event? dummy))
                      "touch-event? with missing TouchEvent")
(check-false/no-error (lambda () (js-wheel-event? dummy))
                      "wheel-event? with missing WheelEvent")
(check-false/no-error (lambda () (js-message-event? dummy))
                      "message-event? with missing MessageEvent")
(check-false/no-error (lambda () (js-close-event? dummy))
                      "close-event? with missing CloseEvent")
(check-false/no-error (lambda () (js-touch-list? dummy))
                      "touch-list? with missing TouchList")
(check-false/no-error (lambda () (js-touch? dummy))
                      "touch? with missing Touch")

(js-eval
 "for (const name of globalThis.__wrEventConstructorBoundaryNames) {
    Object.defineProperty(globalThis, name, {
      value: {},
      configurable: true,
      writable: true
    });
  }")

(define event-new-malformed-message
  (catch-message
   (lambda ()
     (js-event-new "webracket-test" (void)))))

(check-false/no-error (lambda () (js-event? dummy))
                      "event? with malformed Event")
(check-false/no-error (lambda () (js-mouse-event? dummy))
                      "mouse-event? with malformed MouseEvent")
(check-false/no-error (lambda () (js-keyboard-event? dummy))
                      "keyboard-event? with malformed KeyboardEvent")
(check-false/no-error (lambda () (js-pointer-event? dummy))
                      "pointer-event? with malformed PointerEvent")
(check-false/no-error (lambda () (js-focus-event? dummy))
                      "focus-event? with malformed FocusEvent")
(check-false/no-error (lambda () (js-input-event? dummy))
                      "input-event? with malformed InputEvent")
(check-false/no-error (lambda () (js-submit-event? dummy))
                      "submit-event? with malformed SubmitEvent")
(check-false/no-error (lambda () (js-touch-event? dummy))
                      "touch-event? with malformed TouchEvent")
(check-false/no-error (lambda () (js-wheel-event? dummy))
                      "wheel-event? with malformed WheelEvent")
(check-false/no-error (lambda () (js-message-event? dummy))
                      "message-event? with malformed MessageEvent")
(check-false/no-error (lambda () (js-close-event? dummy))
                      "close-event? with malformed CloseEvent")
(check-false/no-error (lambda () (js-touch-list? dummy))
                      "touch-list? with malformed TouchList")
(check-false/no-error (lambda () (js-touch? dummy))
                      "touch? with malformed Touch")

(js-eval
 "for (const name of globalThis.__wrEventConstructorBoundaryNames) {
    Object.defineProperty(globalThis, name, {
      value: (() => false),
      configurable: true,
      writable: true
    });
  }")

(define event-new-non-constructor-message
  (catch-message
   (lambda ()
     (js-event-new "webracket-test" (void)))))

(check-false/no-error (lambda () (js-event? dummy))
                      "event? with non-constructible Event")
(check-false/no-error (lambda () (js-mouse-event? dummy))
                      "mouse-event? with non-constructible MouseEvent")
(check-false/no-error (lambda () (js-keyboard-event? dummy))
                      "keyboard-event? with non-constructible KeyboardEvent")
(check-false/no-error (lambda () (js-pointer-event? dummy))
                      "pointer-event? with non-constructible PointerEvent")
(check-false/no-error (lambda () (js-focus-event? dummy))
                      "focus-event? with non-constructible FocusEvent")
(check-false/no-error (lambda () (js-input-event? dummy))
                      "input-event? with non-constructible InputEvent")
(check-false/no-error (lambda () (js-submit-event? dummy))
                      "submit-event? with non-constructible SubmitEvent")
(check-false/no-error (lambda () (js-touch-event? dummy))
                      "touch-event? with non-constructible TouchEvent")
(check-false/no-error (lambda () (js-wheel-event? dummy))
                      "wheel-event? with non-constructible WheelEvent")
(check-false/no-error (lambda () (js-message-event? dummy))
                      "message-event? with non-constructible MessageEvent")
(check-false/no-error (lambda () (js-close-event? dummy))
                      "close-event? with non-constructible CloseEvent")
(check-false/no-error (lambda () (js-touch-list? dummy))
                      "touch-list? with non-constructible TouchList")
(check-false/no-error (lambda () (js-touch? dummy))
                      "touch? with non-constructible Touch")

(js-eval
 "for (const name of globalThis.__wrEventConstructorBoundaryNames) {
    const saved = globalThis.__wrEventConstructorBoundary[name];
    if (saved.descriptor) {
      Object.defineProperty(globalThis, name, saved.descriptor);
    } else {
      delete globalThis[name];
    }
  }
  delete globalThis.__wrEventConstructorBoundary;
  delete globalThis.__wrEventConstructorBoundaryNames;")

(check-message event-new-message
               "Event not available in this environment: new"
               "missing Event constructor message")

(check-message event-new-malformed-message
               "Event not available in this environment: new"
               "malformed Event constructor message")

(check-message event-new-non-constructor-message
               "Event not available in this environment: new"
               "non-constructible Event constructor message")

(js-log "event-constructor-missing-host-ffi-ok")
#t
