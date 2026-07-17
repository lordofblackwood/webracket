#lang webracket/base

;; Browser smoke for event constructor and predicate host-boundary errors.

(require (only-in webracket/unsafe/event
                  js-close-event?
                  js-event-new
                  js-event?
                  js-keyboard-event?
                  js-message-event?
                  js-mouse-event?)
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
    'MessageEvent',
    'CloseEvent'
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
(check-false/no-error (lambda () (js-message-event? dummy))
                      "message-event? with missing MessageEvent")
(check-false/no-error (lambda () (js-close-event? dummy))
                      "close-event? with missing CloseEvent")

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

(js-log "event-constructor-missing-host-ffi-ok")
#t
