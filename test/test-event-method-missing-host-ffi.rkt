#lang webracket/base

;; Browser smoke for optional Event method host-boundary errors.

(require (only-in webracket/unsafe/event
                  js-event-composed-path
                  js-event-prevent-default
                  js-event-stop-immediate-propagation
                  js-event-stop-propagation)
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
 "globalThis.__wrEventMethodBoundaryEvent =
    new Event('webracket-test', { bubbles: true, cancelable: true, composed: true });
  globalThis.__wrEventMethodBoundaryTargets = [
    'composedPath',
    'preventDefault',
    'stopPropagation',
    'stopImmediatePropagation'
  ];
  globalThis.__wrEventMethodBoundary = [];
  for (const name of globalThis.__wrEventMethodBoundaryTargets) {
    globalThis.__wrEventMethodBoundary.push({
      name,
      hadOwn: Object.prototype.hasOwnProperty.call(globalThis.__wrEventMethodBoundaryEvent, name),
      descriptor: Object.getOwnPropertyDescriptor(globalThis.__wrEventMethodBoundaryEvent, name)
    });
    Object.defineProperty(globalThis.__wrEventMethodBoundaryEvent, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define event (js-eval "globalThis.__wrEventMethodBoundaryEvent"))

(define composed-path-message
  (catch-message
   (lambda ()
     (js-event-composed-path event))))

(define prevent-default-message
  (catch-message
   (lambda ()
     (js-event-prevent-default event))))

(define stop-propagation-message
  (catch-message
   (lambda ()
     (js-event-stop-propagation event))))

(define stop-immediate-propagation-message
  (catch-message
   (lambda ()
     (js-event-stop-immediate-propagation event))))

(js-eval
 "for (const saved of globalThis.__wrEventMethodBoundary) {
    if (saved.hadOwn) {
      Object.defineProperty(globalThis.__wrEventMethodBoundaryEvent,
                            saved.name,
                            saved.descriptor);
    } else {
      delete globalThis.__wrEventMethodBoundaryEvent[saved.name];
    }
  }
  delete globalThis.__wrEventMethodBoundary;
  delete globalThis.__wrEventMethodBoundaryTargets;
  delete globalThis.__wrEventMethodBoundaryEvent;")

(check-message composed-path-message
               "Event.composedPath not available in this environment"
               "missing composedPath message")

(check-message prevent-default-message
               "Event.preventDefault not available in this environment"
               "missing preventDefault message")

(check-message stop-propagation-message
               "Event.stopPropagation not available in this environment"
               "missing stopPropagation message")

(check-message stop-immediate-propagation-message
               "Event.stopImmediatePropagation not available in this environment"
               "missing stopImmediatePropagation message")

(js-log "event-method-missing-host-ffi-ok")
#t
