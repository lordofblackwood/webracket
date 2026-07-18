#lang webracket/base

;; Browser smoke for optional Event method host-boundary errors.

(require (only-in webracket/unsafe/event
                  js-add-event-listener!
                  js-event-composed-path
                  js-event-prevent-default
                  js-event-stop-immediate-propagation
                  js-event-stop-propagation
                  js-event-target
                  js-event-type
                  js-message-event-data
                  js-close-event-code
                  js-touch-identifier
                  js-touch-list-length
                  js-touch-list-ref)
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
(define event-target-without-listener (js-eval "({ addEventListener: undefined })"))
(define touch-list-without-item (js-eval "({ item: undefined })"))
(define listener (js-eval "(() => {})"))
(define js-null (js-eval "null"))

(define add-event-listener-message
  (catch-message
   (lambda ()
     (js-add-event-listener! event-target-without-listener "click" listener))))

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

(define touch-list-ref-message
  (catch-message
   (lambda ()
     (js-touch-list-ref touch-list-without-item 0))))

(define null-event-type-message
  (catch-message
   (lambda ()
     (js-event-type js-null))))

(define null-event-target-message
  (catch-message
   (lambda ()
     (js-event-target js-null))))

(define null-message-event-data-message
  (catch-message
   (lambda ()
     (js-message-event-data js-null))))

(define null-close-event-code-message
  (catch-message
   (lambda ()
     (js-close-event-code js-null))))

(define null-touch-list-length-message
  (catch-message
   (lambda ()
     (js-touch-list-length js-null))))

(define null-touch-identifier-message
  (catch-message
   (lambda ()
     (js-touch-identifier js-null))))

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

(check-message add-event-listener-message
               "EventTarget.addEventListener not available in this environment"
               "missing addEventListener message")

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

(check-message touch-list-ref-message
               "TouchList.item not available in this environment"
               "missing TouchList.item message")

(check-message null-event-type-message
               "Event.type: target object is null or undefined"
               "missing null Event.type message")

(check-message null-event-target-message
               "Event.target: target object is null or undefined"
               "missing null Event.target message")

(check-message null-message-event-data-message
               "MessageEvent.data: target object is null or undefined"
               "missing null MessageEvent.data message")

(check-message null-close-event-code-message
               "CloseEvent.code: target object is null or undefined"
               "missing null CloseEvent.code message")

(check-message null-touch-list-length-message
               "TouchList.length: target object is null or undefined"
               "missing null TouchList.length message")

(check-message null-touch-identifier-message
               "Touch.identifier: target object is null or undefined"
               "missing null Touch.identifier message")

(js-log "event-method-missing-host-ffi-ok")
#t
