#lang webracket/base

;; Browser smoke for optional or browser-version-sensitive Element methods.

(require (only-in webracket/unsafe/dom
                  js-after!
                  js-animate
                  js-append!
                  js-append-child!
                  js-attach-shadow!
                  js-before!
                  js-closest
                  js-computed-style-map
                  js-dom-rect-list-item
                  js-dom-token-list-item
                  js-element-get-elements-by-class-name
                  js-element-get-elements-by-tag-name
                  js-element-get-elements-by-tag-name-ns
                  js-element-query-selector
                  js-element-query-selector-all
                  js-get-animations
                  js-get-attribute
                  js-get-attribute-names
                  js-get-attribute-node
                  js-get-attribute-node-ns
                  js-get-attribute-ns
                  js-get-bounding-client-rect
                  js-get-client-rects
                  js-has-attribute
                  js-has-attribute-ns
                  js-has-attributes
                  js-has-pointer-capture
                  js-html-collection-item
                  js-html-collection-named-item
                  js-insert-adjacent-element!
                  js-insert-adjacent-html!
                  js-insert-adjacent-text!
                  js-matches
                  js-node-list-item
                  js-prepend!
                  js-release-pointer-capture!
                  js-remove!
                  js-remove-attribute!
                  js-remove-attribute-node!
                  js-remove-attribute-ns!
                  js-replace-children!
                  js-replace-with!
                  js-request-fullscreen
                  js-request-pointer-lock
                  js-scroll!
                  js-scroll-by!
                  js-scroll-into-view!
                  js-scroll-to!
                  js-set-attribute!
                  js-set-attribute-node!
                  js-set-attribute-node-ns!
                  js-set-attribute-ns!
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
(define js-null (js-eval "null"))

(js-eval
 "globalThis.__wrElementMethodBoundaryNames = [
    'after',
    'animate',
    'append',
    'appendChild',
    'attachShadow',
    'before',
    'closest',
    'computedStyleMap',
    'getAnimations',
    'getAttribute',
    'getAttributeNS',
    'getAttributeNames',
    'getAttributeNode',
    'getAttributeNodeNS',
    'getBoundingClientRect',
    'getClientRects',
    'getElementsByClassName',
    'getElementsByTagName',
    'getElementsByTagNameNS',
    'hasAttribute',
    'hasAttributeNS',
    'hasAttributes',
    'hasPointerCapture',
    'insertAdjacentElement',
    'insertAdjacentHTML',
    'insertAdjacentText',
    'matches',
    'prepend',
    'querySelector',
    'querySelectorAll',
    'releasePointerCapture',
    'remove',
    'removeAttribute',
    'removeAttributeNS',
    'removeAttributeNode',
    'replaceChildren',
    'replaceWith',
    'requestFullscreen',
    'requestPointerLock',
    'scroll',
    'scrollBy',
    'scrollIntoView',
    'scrollTo',
    'setAttribute',
    'setAttributeNS',
    'setAttributeNode',
    'setAttributeNodeNS',
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

(define after-message
  (catch-message
   (lambda ()
     (js-after! element "x"))))

(define animate-message
  (catch-message
   (lambda ()
     (js-animate element keyframes options))))

(define append-message
  (catch-message
   (lambda ()
     (js-append! element "x"))))

(define append-child-message
  (catch-message
   (lambda ()
     (js-append-child! element js-null))))

(define attach-shadow-message
  (catch-message
   (lambda ()
     (js-attach-shadow! element shadow-init))))

(define before-message
  (catch-message
   (lambda ()
     (js-before! element "x"))))

(define closest-message
  (catch-message
   (lambda ()
     (js-closest element "body"))))

(define computed-style-map-message
  (catch-message
   (lambda ()
     (js-computed-style-map element))))

(define get-animations-message
  (catch-message
   (lambda ()
     (js-get-animations element))))

(define get-attribute-message
  (catch-message
   (lambda ()
     (js-get-attribute element "data-wr-test"))))

(define get-attribute-ns-message
  (catch-message
   (lambda ()
     (js-get-attribute-ns element "http://www.w3.org/1999/xhtml" "data-wr-test"))))

(define get-attribute-names-message
  (catch-message
   (lambda ()
     (js-get-attribute-names element))))

(define get-attribute-node-message
  (catch-message
   (lambda ()
     (js-get-attribute-node element "data-wr-test"))))

(define get-attribute-node-ns-message
  (catch-message
   (lambda ()
     (js-get-attribute-node-ns element "http://www.w3.org/1999/xhtml" "data-wr-test"))))

(define get-bounding-client-rect-message
  (catch-message
   (lambda ()
     (js-get-bounding-client-rect element))))

(define get-client-rects-message
  (catch-message
   (lambda ()
     (js-get-client-rects element))))

(define get-elements-by-class-name-message
  (catch-message
   (lambda ()
     (js-element-get-elements-by-class-name element "missing"))))

(define get-elements-by-tag-name-message
  (catch-message
   (lambda ()
     (js-element-get-elements-by-tag-name element "div"))))

(define get-elements-by-tag-name-ns-message
  (catch-message
   (lambda ()
     (js-element-get-elements-by-tag-name-ns element "http://www.w3.org/1999/xhtml" "div"))))

(define has-attribute-message
  (catch-message
   (lambda ()
     (js-has-attribute element "data-wr-test"))))

(define has-attribute-ns-message
  (catch-message
   (lambda ()
     (js-has-attribute-ns element "http://www.w3.org/1999/xhtml" "data-wr-test"))))

(define has-attributes-message
  (catch-message
   (lambda ()
     (js-has-attributes element))))

(define has-pointer-capture-message
  (catch-message
   (lambda ()
     (js-has-pointer-capture element 0))))

(define insert-adjacent-element-message
  (catch-message
   (lambda ()
     (js-insert-adjacent-element! element "beforeend" js-null))))

(define insert-adjacent-html-message
  (catch-message
   (lambda ()
     (js-insert-adjacent-html! element "beforeend" "<span></span>"))))

(define insert-adjacent-text-message
  (catch-message
   (lambda ()
     (js-insert-adjacent-text! element "beforeend" "x"))))

(define matches-message
  (catch-message
   (lambda ()
     (js-matches element "body"))))

(define prepend-message
  (catch-message
   (lambda ()
     (js-prepend! element "x"))))

(define query-selector-message
  (catch-message
   (lambda ()
     (js-element-query-selector element "body"))))

(define query-selector-all-message
  (catch-message
   (lambda ()
     (js-element-query-selector-all element "body"))))

(define release-pointer-capture-message
  (catch-message
   (lambda ()
     (js-release-pointer-capture! element 0))))

(define remove-message
  (catch-message
   (lambda ()
     (js-remove! element))))

(define remove-attribute-message
  (catch-message
   (lambda ()
     (js-remove-attribute! element "data-wr-test"))))

(define remove-attribute-ns-message
  (catch-message
   (lambda ()
     (js-remove-attribute-ns! element "http://www.w3.org/1999/xhtml" "data-wr-test"))))

(define remove-attribute-node-message
  (catch-message
   (lambda ()
     (js-remove-attribute-node! element js-null))))

(define replace-children-message
  (catch-message
   (lambda ()
     (js-replace-children! element js-null))))

(define replace-with-message
  (catch-message
   (lambda ()
     (js-replace-with! element js-null))))

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

(define set-attribute-message
  (catch-message
   (lambda ()
     (js-set-attribute! element "data-wr-test" "x"))))

(define set-attribute-ns-message
  (catch-message
   (lambda ()
     (js-set-attribute-ns! element "http://www.w3.org/1999/xhtml" "data-wr-test" "x"))))

(define set-attribute-node-message
  (catch-message
   (lambda ()
     (js-set-attribute-node! element js-null))))

(define set-attribute-node-ns-message
  (catch-message
   (lambda ()
     (js-set-attribute-node-ns! element js-null))))

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

(check-message after-message
               "Element.after not available in this environment"
               "missing after message")
(check-message animate-message
               "Element.animate not available in this environment"
               "missing animate message")
(check-message append-message
               "Element.append not available in this environment"
               "missing append message")
(check-message append-child-message
               "Node.appendChild not available in this environment"
               "missing appendChild message")
(check-message attach-shadow-message
               "Element.attachShadow not available in this environment"
               "missing attachShadow message")
(check-message before-message
               "Element.before not available in this environment"
               "missing before message")
(check-message closest-message
               "Element.closest not available in this environment"
               "missing closest message")
(check-message computed-style-map-message
               "Element.computedStyleMap not available in this environment"
               "missing computedStyleMap message")
(check-message get-animations-message
               "Element.getAnimations not available in this environment"
               "missing getAnimations message")
(check-message get-attribute-message
               "Element.getAttribute not available in this environment"
               "missing getAttribute message")
(check-message get-attribute-ns-message
               "Element.getAttributeNS not available in this environment"
               "missing getAttributeNS message")
(check-message get-attribute-names-message
               "Element.getAttributeNames not available in this environment"
               "missing getAttributeNames message")
(check-message get-attribute-node-message
               "Element.getAttributeNode not available in this environment"
               "missing getAttributeNode message")
(check-message get-attribute-node-ns-message
               "Element.getAttributeNodeNS not available in this environment"
               "missing getAttributeNodeNS message")
(check-message get-bounding-client-rect-message
               "Element.getBoundingClientRect not available in this environment"
               "missing getBoundingClientRect message")
(check-message get-client-rects-message
               "Element.getClientRects not available in this environment"
               "missing getClientRects message")
(check-message get-elements-by-class-name-message
               "Element.getElementsByClassName not available in this environment"
               "missing getElementsByClassName message")
(check-message get-elements-by-tag-name-message
               "Element.getElementsByTagName not available in this environment"
               "missing getElementsByTagName message")
(check-message get-elements-by-tag-name-ns-message
               "Element.getElementsByTagNameNS not available in this environment"
               "missing getElementsByTagNameNS message")
(check-message has-attribute-message
               "Element.hasAttribute not available in this environment"
               "missing hasAttribute message")
(check-message has-attribute-ns-message
               "Element.hasAttributeNS not available in this environment"
               "missing hasAttributeNS message")
(check-message has-attributes-message
               "Element.hasAttributes not available in this environment"
               "missing hasAttributes message")
(check-message has-pointer-capture-message
               "Element.hasPointerCapture not available in this environment"
               "missing hasPointerCapture message")
(check-message insert-adjacent-element-message
               "Element.insertAdjacentElement not available in this environment"
               "missing insertAdjacentElement message")
(check-message insert-adjacent-html-message
               "Element.insertAdjacentHTML not available in this environment"
               "missing insertAdjacentHTML message")
(check-message insert-adjacent-text-message
               "Element.insertAdjacentText not available in this environment"
               "missing insertAdjacentText message")
(check-message matches-message
               "Element.matches not available in this environment"
               "missing matches message")
(check-message prepend-message
               "Element.prepend not available in this environment"
               "missing prepend message")
(check-message query-selector-message
               "Element.querySelector not available in this environment"
               "missing querySelector message")
(check-message query-selector-all-message
               "Element.querySelectorAll not available in this environment"
               "missing querySelectorAll message")
(check-message release-pointer-capture-message
               "Element.releasePointerCapture not available in this environment"
               "missing releasePointerCapture message")
(check-message remove-message
               "Element.remove not available in this environment"
               "missing remove message")
(check-message remove-attribute-message
               "Element.removeAttribute not available in this environment"
               "missing removeAttribute message")
(check-message remove-attribute-ns-message
               "Element.removeAttributeNS not available in this environment"
               "missing removeAttributeNS message")
(check-message remove-attribute-node-message
               "Element.removeAttributeNode not available in this environment"
               "missing removeAttributeNode message")
(check-message replace-children-message
               "Element.replaceChildren not available in this environment"
               "missing replaceChildren message")
(check-message replace-with-message
               "Element.replaceWith not available in this environment"
               "missing replaceWith message")
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
(check-message set-attribute-message
               "Element.setAttribute not available in this environment"
               "missing setAttribute message")
(check-message set-attribute-ns-message
               "Element.setAttributeNS not available in this environment"
               "missing setAttributeNS message")
(check-message set-attribute-node-message
               "Element.setAttributeNode not available in this environment"
               "missing setAttributeNode message")
(check-message set-attribute-node-ns-message
               "Element.setAttributeNodeNS not available in this environment"
               "missing setAttributeNodeNS message")
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
