#lang webracket/base

;; Browser smoke for optional Event method host-boundary errors.

(require (only-in webracket/unsafe/event
                  js-add-event-listener!
                  js-close-event-was-clean
                  js-event-composed-path
                  js-event-bubbles
                  js-event-prevent-default
                  js-event-stop-immediate-propagation
                  js-event-stop-propagation
                  js-event-target
                  js-event-type
                  js-keyboard-event-key
                  js-keyboard-event-repeat
                  js-message-event-data
                  js-mouse-event-alt-key
                  js-mouse-event-client-x
                  js-close-event-code
                  js-touch-event-touches
                  js-touch-identifier
                  js-touch-list-length
                  js-touch-list-ref)
         (only-in webracket/unsafe/domrect
                  js-dom-rect-left)
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
(define fake-object (js-eval "({})"))
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

(define event-type-message
  (catch-message
   (lambda ()
     (js-event-type fake-object))))

(define event-bubbles-message
  (catch-message
   (lambda ()
     (js-event-bubbles fake-object))))

(define mouse-client-x-message
  (catch-message
   (lambda ()
     (js-mouse-event-client-x fake-object))))

(define mouse-alt-key-message
  (catch-message
   (lambda ()
     (js-mouse-event-alt-key fake-object))))

(define keyboard-key-message
  (catch-message
   (lambda ()
     (js-keyboard-event-key fake-object))))

(define keyboard-repeat-message
  (catch-message
   (lambda ()
     (js-keyboard-event-repeat fake-object))))

(define message-event-data-message
  (catch-message
   (lambda ()
     (js-message-event-data fake-object))))

(define close-event-was-clean-message
  (catch-message
   (lambda ()
     (js-close-event-was-clean fake-object))))

(define touch-event-touches-message
  (catch-message
   (lambda ()
     (js-touch-event-touches fake-object))))

(define touch-list-length-message
  (catch-message
   (lambda ()
     (js-touch-list-length fake-object))))

(define touch-identifier-message
  (catch-message
   (lambda ()
     (js-touch-identifier fake-object))))

(define dom-rect-left-message
  (catch-message
   (lambda ()
     (js-dom-rect-left fake-object))))

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

(check-message event-type-message
               "Event.type not available in this environment"
               "missing Event.type message")

(check-message event-bubbles-message
               "Event.bubbles not available in this environment"
               "missing Event.bubbles message")

(check-message mouse-client-x-message
               "MouseEvent.clientX not available in this environment"
               "missing MouseEvent.clientX message")

(check-message mouse-alt-key-message
               "MouseEvent.altKey not available in this environment"
               "missing MouseEvent.altKey message")

(check-message keyboard-key-message
               "KeyboardEvent.key not available in this environment"
               "missing KeyboardEvent.key message")

(check-message keyboard-repeat-message
               "KeyboardEvent.repeat not available in this environment"
               "missing KeyboardEvent.repeat message")

(check-message message-event-data-message
               "MessageEvent.data not available in this environment"
               "missing MessageEvent.data message")

(check-message close-event-was-clean-message
               "CloseEvent.wasClean not available in this environment"
               "missing CloseEvent.wasClean message")

(check-message touch-event-touches-message
               "TouchEvent.touches not available in this environment"
               "missing TouchEvent.touches message")

(check-message touch-list-length-message
               "TouchList.length not available in this environment"
               "missing TouchList.length message")

(check-message touch-identifier-message
               "Touch.identifier not available in this environment"
               "missing Touch.identifier message")

(check-message dom-rect-left-message
               "DOMRect.left not available in this environment"
               "missing DOMRect.left message")

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
