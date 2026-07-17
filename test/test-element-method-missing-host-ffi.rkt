#lang webracket/base

;; Browser smoke for optional or browser-version-sensitive Element methods.

(require (only-in webracket/unsafe/dom
                  js-animate
                  js-attach-shadow!
                  js-computed-style-map
                  js-dom-rect-list-item
                  js-dom-token-list-item
                  js-get-animations
                  js-has-pointer-capture
                  js-html-collection-item
                  js-html-collection-named-item
                  js-node-list-item
                  js-release-pointer-capture!
                  js-request-fullscreen
                  js-request-pointer-lock
                  js-scroll!
                  js-scroll-by!
                  js-scroll-into-view!
                  js-scroll-to!
                  js-set-pointer-capture!
                  js-toggle-attribute!
                  js-toggle-attribute
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
 "globalThis.__wrElementMethodBoundaryElement = document.createElement('div');
  globalThis.__wrElementMethodBoundaryElement.style.width = '4px';
  globalThis.__wrElementMethodBoundaryElement.style.height = '4px';
  globalThis.__wrElementMethodBoundaryKeyframes = [];
  globalThis.__wrElementMethodBoundaryOptions = {};
  globalThis.__wrElementMethodBoundaryShadowInit = {mode: 'open'};")

(define element (js-eval "globalThis.__wrElementMethodBoundaryElement"))
(define keyframes (js-eval "globalThis.__wrElementMethodBoundaryKeyframes"))
(define options (js-eval "globalThis.__wrElementMethodBoundaryOptions"))
(define shadow-init (js-eval "globalThis.__wrElementMethodBoundaryShadowInit"))
(define item-list-without-item (js-eval "({ item: undefined })"))
(define collection-without-methods (js-eval "({ item: undefined, namedItem: undefined })"))

(js-eval
 "globalThis.__wrElementMethodBoundaryNames = [
    'animate',
    'attachShadow',
    'computedStyleMap',
    'getAnimations',
    'hasPointerCapture',
    'releasePointerCapture',
    'requestFullscreen',
    'requestPointerLock',
    'scroll',
    'scrollBy',
    'scrollIntoView',
    'scrollTo',
    'setPointerCapture',
    'toggleAttribute'
  ];
  globalThis.__wrElementMethodBoundary = [];
  for (const name of globalThis.__wrElementMethodBoundaryNames) {
    const elem = globalThis.__wrElementMethodBoundaryElement;
    globalThis.__wrElementMethodBoundary.push({
      obj: elem,
      name,
      hadOwn: Object.prototype.hasOwnProperty.call(elem, name),
      descriptor: Object.getOwnPropertyDescriptor(elem, name)
    });
    Object.defineProperty(elem, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define animate-message
  (catch-message
   (lambda ()
     (js-animate element keyframes options))))

(define attach-shadow-message
  (catch-message
   (lambda ()
     (js-attach-shadow! element shadow-init))))

(define computed-style-map-message
  (catch-message
   (lambda ()
     (js-computed-style-map element))))

(define get-animations-message
  (catch-message
   (lambda ()
     (js-get-animations element))))

(define has-pointer-capture-message
  (catch-message
   (lambda ()
     (js-has-pointer-capture element 0))))

(define release-pointer-capture-message
  (catch-message
   (lambda ()
     (js-release-pointer-capture! element 0))))

(define request-fullscreen-message
  (catch-message
   (lambda ()
     (js-request-fullscreen element))))

(define request-pointer-lock-message
  (catch-message
   (lambda ()
     (js-request-pointer-lock element))))

(define scroll-message
  (catch-message
   (lambda ()
     (js-scroll! element 0.0 0.0))))

(define scroll-by-message
  (catch-message
   (lambda ()
     (js-scroll-by! element 0.0 0.0))))

(define scroll-into-view-message
  (catch-message
   (lambda ()
     (js-scroll-into-view! element 1))))

(define scroll-to-message
  (catch-message
   (lambda ()
     (js-scroll-to! element 0.0 0.0))))

(define set-pointer-capture-message
  (catch-message
   (lambda ()
     (js-set-pointer-capture! element 0))))

(define toggle-attribute/force-message
  (catch-message
   (lambda ()
     (js-toggle-attribute! element "data-wr-test" 1))))

(define toggle-attribute-message
  (catch-message
   (lambda ()
     (js-toggle-attribute element "data-wr-test"))))

(define dom-token-list-item-message
  (catch-message
   (lambda ()
     (js-dom-token-list-item item-list-without-item 0))))

(define node-list-item-message
  (catch-message
   (lambda ()
     (js-node-list-item item-list-without-item 0))))

(define html-collection-item-message
  (catch-message
   (lambda ()
     (js-html-collection-item collection-without-methods 0))))

(define html-collection-named-item-message
  (catch-message
   (lambda ()
     (js-html-collection-named-item collection-without-methods "missing"))))

(define dom-rect-list-item-message
  (catch-message
   (lambda ()
     (js-dom-rect-list-item item-list-without-item 0))))

(js-eval
 "for (const saved of globalThis.__wrElementMethodBoundary) {
    if (saved.hadOwn) {
      Object.defineProperty(saved.obj, saved.name, saved.descriptor);
    } else {
      delete saved.obj[saved.name];
    }
  }
  delete globalThis.__wrElementMethodBoundary;
  delete globalThis.__wrElementMethodBoundaryNames;
  delete globalThis.__wrElementMethodBoundaryElement;
  delete globalThis.__wrElementMethodBoundaryKeyframes;
  delete globalThis.__wrElementMethodBoundaryOptions;
  delete globalThis.__wrElementMethodBoundaryShadowInit;")

(check-message animate-message
               "Element.animate not available in this environment"
               "missing animate message")
(check-message attach-shadow-message
               "Element.attachShadow not available in this environment"
               "missing attachShadow message")
(check-message computed-style-map-message
               "Element.computedStyleMap not available in this environment"
               "missing computedStyleMap message")
(check-message get-animations-message
               "Element.getAnimations not available in this environment"
               "missing getAnimations message")
(check-message has-pointer-capture-message
               "Element.hasPointerCapture not available in this environment"
               "missing hasPointerCapture message")
(check-message release-pointer-capture-message
               "Element.releasePointerCapture not available in this environment"
               "missing releasePointerCapture message")
(check-message request-fullscreen-message
               "Element.requestFullscreen not available in this environment"
               "missing requestFullscreen message")
(check-message request-pointer-lock-message
               "Element.requestPointerLock not available in this environment"
               "missing requestPointerLock message")
(check-message scroll-message
               "Element.scroll not available in this environment"
               "missing scroll message")
(check-message scroll-by-message
               "Element.scrollBy not available in this environment"
               "missing scrollBy message")
(check-message scroll-into-view-message
               "Element.scrollIntoView not available in this environment"
               "missing scrollIntoView message")
(check-message scroll-to-message
               "Element.scrollTo not available in this environment"
               "missing scrollTo message")
(check-message set-pointer-capture-message
               "Element.setPointerCapture not available in this environment"
               "missing setPointerCapture message")
(check-message toggle-attribute/force-message
               "Element.toggleAttribute not available in this environment"
               "missing toggleAttribute force message")
(check-message toggle-attribute-message
               "Element.toggleAttribute not available in this environment"
               "missing toggleAttribute message")
(check-message dom-token-list-item-message
               "DOMTokenList.item not available in this environment"
               "missing DOMTokenList.item message")
(check-message node-list-item-message
               "NodeList.item not available in this environment"
               "missing NodeList.item message")
(check-message html-collection-item-message
               "HTMLCollection.item not available in this environment"
               "missing HTMLCollection.item message")
(check-message html-collection-named-item-message
               "HTMLCollection.namedItem not available in this environment"
               "missing HTMLCollection.namedItem message")
(check-message dom-rect-list-item-message
               "DOMRectList.item not available in this environment"
               "missing DOMRectList.item message")

(js-log "element-method-missing-host-ffi-ok")
#t
