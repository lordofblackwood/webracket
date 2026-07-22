#lang racket/base

(require racket/include
         racket/list
         webracket/unsafe/element
         webracket/unsafe/js
         webracket/unsafe/standard
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (except-out (all-defined-out)
                     media-stream?
                     media-source?
                     media-keys-info?
                     audio-track?
                     text-track?
                     video-track?
                     media-error-info?
                     audio-track-list?
                     text-track-list?
                     video-track-list?
                     time-ranges?)
         (rename-out [media-stream/surface? media-stream?]
                     [media-source/surface? media-source?]
                     [media-keys-info/surface? media-keys-info?]
                     [audio-track/surface? audio-track?]
                     [text-track/surface? text-track?]
                     [video-track/surface? video-track?]
                     [media-error-info/surface? media-error-info?]
                     [audio-track-list/surface? audio-track-list?]
                     [text-track-list/surface? text-track-list?]
                     [video-track-list/surface? video-track-list?]
                     [time-ranges/surface? time-ranges?])
         (all-from-out webracket/unsafe/element))

(include "private/shared-library-structs-body.rkt")

;;;
;;; Element wrappers
;;;
;; element-stringish->string : symbol? any/c -> string?
;;   Normalize a string-like wrapper argument to a browser string.
(define (element-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else (raise-argument-error who "(or/c string? symbol?)" v)]))

;; element-i32->boolean : integer? -> boolean?
;;   Convert a browser i32 flag to a boolean.
(define (element-i32->boolean v)
  (not (zero? v)))

;; element-real->flonum : symbol? any/c -> real?
;;   Validate a real coordinate and coerce it to an inexact value for FFI calls.
(define (element-real->flonum who v)
  (unless (real? v)
    (raise-argument-error who "real?" v))
  (exact->inexact v))

;; element-host-raw/checked : symbol? string? any/c any/c -> external/raw
;;   Validate a raw DOM host value before passing it to browser host calls.
(define (element-host-raw/checked who expected value raw)
  (unless (shared-dom-raw-host-value? raw)
    (raise-argument-error who expected value))
  raw)

;; element-raw/checked : symbol? any/c -> external/raw
;;   Unwrap and validate an Element-like host value.
(define (element-raw/checked who value)
  (element-host-raw/checked who
                            "Element host value"
                            value
                            (element-unwrap value)))

;; dom-token-list-raw/checked : symbol? any/c -> external/raw
;;   Unwrap and validate a DOMTokenList host value.
(define (dom-token-list-raw/checked who value)
  (element-host-raw/checked who
                            "DOMTokenList host value"
                            value
                            (dom-token-list-unwrap value)))

;; node-list-raw/checked : symbol? any/c -> external/raw
;;   Unwrap and validate a NodeList host value.
(define (node-list-raw/checked who value)
  (element-host-raw/checked who
                            "NodeList host value"
                            value
                            (node-list-unwrap value)))

;; html-collection-raw/checked : symbol? any/c -> external/raw
;;   Unwrap and validate an HTMLCollection host value.
(define (html-collection-raw/checked who value)
  (element-host-raw/checked who
                            "HTMLCollection host value"
                            value
                            (html-collection-unwrap value)))

;; shadow-root-raw/checked : symbol? any/c -> external/raw
;;   Unwrap and validate a ShadowRoot host value.
(define (shadow-root-raw/checked who value)
  (element-host-raw/checked who
                            "ShadowRoot host value"
                            value
                            (shadow-root-unwrap value)))

;; dom-rect-list-raw/checked : symbol? any/c -> external/raw
;;   Unwrap and validate a DOMRectList host value.
(define (dom-rect-list-raw/checked who value)
  (element-host-raw/checked who
                            "DOMRectList host value"
                            value
                            (dom-rect-list-unwrap value)))

;; element-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable browser method.
(define (element-host-method-present? raw method-name)
  (and (shared-dom-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; check-element-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required Element-family host method is available.
(define (check-element-host-method who raw receiver-name method-name)
  (unless (element-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " not available in this environment"))))

;; define-element-getter : (name binding) -> syntax
;;   Define a direct getter for an element property binding.
(define-syntax-rule (define-element-getter name binding)
  (define (name element)
    (binding (element-unwrap element))))

;; define-element-setter : (name binding convert) -> syntax
;;   Define a direct setter for an element property binding.
(define-syntax-rule (define-element-setter name binding convert)
  (define (name element value)
    (binding (element-unwrap element) (convert value))
    (void)))

;; define-element-wrap-getter : (name binding wrap) -> syntax
;;   Define a getter that wraps a browser object result.
(define-syntax-rule (define-element-wrap-getter name binding wrap)
  (define (name element)
    (wrap (binding (element-unwrap element)))))

;; define-element-boolean-getter : (name binding) -> syntax
;;   Define a getter that converts a browser flag to a boolean.
(define-syntax-rule (define-element-boolean-getter name binding)
  (define (name element)
    (element-i32->boolean (binding (element-unwrap element)))))

;; Element property access in this library should stay on the direct
;; js-element-* bindings instead of routing through reflective lookup.

;; element-node-wrapper-raw/checked : symbol? any/c any/c -> external/raw
;;   Validate a wrapped node-like value before passing it to browser host calls.
(define (element-node-wrapper-raw/checked who value raw)
  (element-host-raw/checked who
                            "DOM node wrapper with non-null host value"
                            value
                            raw))

;; element-nodeish->value : symbol? any/c -> any/c
;;   Normalize a node-like value for DOM insertion helpers.
(define (element-nodeish->value who value)
  (cond
    [(symbol? value) (symbol->string value)]
    [(string? value) value]
    [(dom-node? value)
     (element-node-wrapper-raw/checked who value (dom-node-raw value))]
    [(dom-element? value)
     (element-node-wrapper-raw/checked who value (dom-element-raw value))]
    [(dom-text? value)
     (element-node-wrapper-raw/checked who value (dom-text-raw value))]
    [(dom-attr? value)
     (element-node-wrapper-raw/checked who value (dom-attr-raw value))]
    [else value]))

;; element-event-listener-cache : hash?
;;   Reuse stable external callbacks for event listeners.
(define element-event-listener-cache (make-hasheq))

;; element-event-name->string : symbol? any/c -> string?
;;   Normalize a DOM event name to a browser string.
(define (element-event-name->string who event-name)
  (cond
    [(string? event-name) event-name]
    [(symbol? event-name) (symbol->string event-name)]
    [else (raise-argument-error who "(or/c string? symbol?)" event-name)]))

;; element-event-listener->external : symbol? any/c -> external?
;;   Convert a listener to a stable external callback.
(define (element-event-listener->external who listener)
  (cond
    [(external? listener) listener]
    [(procedure? listener)
     (define cached (hash-ref element-event-listener-cache listener #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply listener args)
             (void))))
        (hash-set! element-event-listener-cache listener external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" listener)]))

;; element-event-listener-option? : any/c -> boolean?
;;   Check whether a listener option is acceptable for add/removeEventListener.
(define (element-event-listener-option? option)
  (or (boolean? option)
      (external? option)))

;; element-add-event-listener! : element? (or/c string? symbol?) (or/c procedure? external?) (or/c boolean? external?) ... -> external?
;;   Add an event listener to an element and return the installed listener.
(define (element-add-event-listener! element event-name listener . options)
  (define raw (element-unwrap element))
  (define event-name* (element-event-name->string 'element-add-event-listener! event-name))
  (define listener* (element-event-listener->external 'element-add-event-listener! listener))
  (for-each
   (lambda (option)
     (unless (element-event-listener-option? option)
       (raise-argument-error 'element-add-event-listener! "(or/c boolean? external?)" option)))
   options)
  (define args
    (if (null? options)
        (vector event-name* listener*)
        (list->vector (list* event-name* listener* options))))
  (check-element-host-method 'element-add-event-listener! raw "EventTarget" "addEventListener")
  (js-send/extern/nullish raw "addEventListener" args)
  listener*)

;; element-remove-event-listener! : element? (or/c string? symbol?) (or/c procedure? external?) (or/c boolean? external?) ... -> void?
;;   Remove an event listener from an element.
(define (element-remove-event-listener! element event-name listener . options)
  (define raw (element-unwrap element))
  (define event-name* (element-event-name->string 'element-remove-event-listener! event-name))
  (define listener* (element-event-listener->external 'element-remove-event-listener! listener))
  (for-each
   (lambda (option)
     (unless (element-event-listener-option? option)
       (raise-argument-error 'element-remove-event-listener! "(or/c boolean? external?)" option)))
   options)
  (define args
    (if (null? options)
        (vector event-name* listener*)
        (list->vector (list* event-name* listener* options))))
  (check-element-host-method 'element-remove-event-listener! raw "EventTarget" "removeEventListener")
  (js-send/extern/nullish raw "removeEventListener" args)
  (void))

;; element-id : element? -> (or/c #f string?)
;;   Read an element id.
(define-element-getter element-id js-element-id)

;; element-set-id! : element? (or/c string? symbol?) -> void?
;;   Set an element id.
(define-element-setter element-set-id! js-set-element-id! (lambda (id)
                                                            (element-stringish->string 'element-set-id! id)))

;; element-class-name : element? -> (or/c #f string?)
;;   Read an element class name.
(define-element-getter element-class-name js-element-class-name)

;; element-set-class-name! : element? (or/c string? symbol?) -> void?
;;   Set an element class name.
(define-element-setter element-set-class-name! js-set-element-class-name!
  (lambda (class-name)
    (element-stringish->string 'element-set-class-name! class-name)))

;; element-class-list : element? -> (or/c #f dom-token-list?)
;;   Read an element class list.
(define-element-wrap-getter element-class-list js-element-class-list dom-token-list-wrap)

;; element-tag-name : element? -> string?
;;   Read the element tag name.
(define-element-getter element-tag-name js-element-tag-name)

;; element-local-name : element? -> string?
;;   Read the element local name.
(define-element-getter element-local-name js-element-local-name)

;; element-namespace-uri : element? -> (or/c #f string?)
;;   Read the element namespace URI.
(define-element-getter element-namespace-uri js-element-namespace-uri)

;; element-prefix : element? -> (or/c #f string?)
;;   Read the element namespace prefix.
(define-element-getter element-prefix js-element-prefix)

;; element-is-connected? : element? -> boolean?
;;   Report whether the element is connected to a document.
(define (element-is-connected? element)
  (js-element-is-connected (element-unwrap element)))

;; append-child! : external? external? -> void?
;;   Append a child node.
(define (append-child! parent child)
  (js-append-child! (element-unwrap parent)
                    (element-nodeish->value 'append-child! child))
  (void))

;; element-append! : element? any/c -> void?
;;   Append a node or text to an element.
(define (element-append! element child)
  (define raw (element-unwrap element))
  (check-element-host-method 'element-append! raw "Element" "append")
  (js-send/extern/nullish raw "append"
                          (vector (element-nodeish->value 'element-append! child)))
  (void))

;; element-prepend! : element? any/c -> void?
;;   Prepend a node or text to an element.
(define (element-prepend! element child)
  (define raw (element-unwrap element))
  (check-element-host-method 'element-prepend! raw "Element" "prepend")
  (js-send/extern/nullish raw "prepend"
                          (vector (element-nodeish->value 'element-prepend! child)))
  (void))

;; element-before! : element? any/c -> void?
;;   Insert a node or text before an element.
(define (element-before! element sibling)
  (define raw (element-unwrap element))
  (check-element-host-method 'element-before! raw "Element" "before")
  (js-send/extern/nullish raw "before"
                          (vector (element-nodeish->value 'element-before! sibling)))
  (void))

;; element-after! : element? any/c -> void?
;;   Insert a node or text after an element.
(define (element-after! element sibling)
  (define raw (element-unwrap element))
  (check-element-host-method 'element-after! raw "Element" "after")
  (js-send/extern/nullish raw "after"
                          (vector (element-nodeish->value 'element-after! sibling)))
  (void))

;; set-attribute! : external? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Set an element attribute.
(define (set-attribute! element name value)
  (define name* (element-stringish->string 'set-attribute! name))
  (define value* (element-stringish->string 'set-attribute! value))
  (js-set-attribute! (element-unwrap element) name* value*)
  (void))

;; element-set-attribute! : element? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Set an element attribute.
(define (element-set-attribute! element name value)
  (set-attribute! element name value))

;; get-attribute : external? (or/c string? symbol?) -> (or/c #f string?)
;;   Read an element attribute.
(define (get-attribute element name)
  (define name* (element-stringish->string 'get-attribute name))
  (js-get-attribute (element-unwrap element) name*))

;; element-get-attribute : element? (or/c string? symbol?) -> (or/c #f string?)
;;   Read an element attribute.
(define (element-get-attribute element name)
  (get-attribute element name))

;; element-has-attribute? : element? (or/c string? symbol?) -> boolean?
;;   Report whether an element has an attribute.
(define (element-has-attribute? element name)
  (define name* (element-stringish->string 'element-has-attribute? name))
  (element-i32->boolean (js-has-attribute (element-unwrap element) name*)))

;; element-has-attributes? : element? -> boolean?
;;   Report whether an element has any attributes.
(define (element-has-attributes? element)
  (element-i32->boolean (js-has-attributes (element-unwrap element))))

;; element-has-pointer-capture? : element? exact-nonnegative-integer? -> boolean?
;;   Report whether this element has pointer capture for a pointer id.
(define (element-has-pointer-capture? element pointer-id)
  (unless (exact-nonnegative-integer? pointer-id)
    (raise-argument-error 'element-has-pointer-capture? "exact-nonnegative-integer?" pointer-id))
  (element-i32->boolean
   (js-has-pointer-capture (element-unwrap element) pointer-id)))

;; element-remove-attribute! : element? (or/c string? symbol?) -> void?
;;   Remove an attribute from an element.
(define (element-remove-attribute! element name)
  (define name* (element-stringish->string 'element-remove-attribute! name))
  (js-remove-attribute! (element-unwrap element) name*)
  (void))

;; element-remove-attribute-ns! : element? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Remove a namespaced attribute from an element.
(define (element-remove-attribute-ns! element ns name)
  (define ns* (element-stringish->string 'element-remove-attribute-ns! ns))
  (define name* (element-stringish->string 'element-remove-attribute-ns! name))
  (js-remove-attribute-ns! (element-unwrap element) ns* name*)
  (void))

;; element-matches? : element? (or/c string? symbol?) -> boolean?
;;   Report whether an element matches a CSS selector.
(define (element-matches? element selector)
  (define selector* (element-stringish->string 'element-matches? selector))
  (element-i32->boolean (js-matches (element-unwrap element) selector*)))

;; element-closest : element? (or/c string? symbol?) -> (or/c #f element?)
;;   Find the closest ancestor matching a CSS selector.
(define (element-closest element selector)
  (define selector* (element-stringish->string 'element-closest selector))
  (element-wrap (js-closest (element-unwrap element) selector*)))

;; element-get-attribute-names : element? -> vector?
;;   Read the names of the element's attributes.
(define (element-get-attribute-names element)
  (array-like->vector 'element-get-attribute-names
                      (js-get-attribute-names (element-unwrap element))
                      values))

;; dom-token-list-value : dom-token-list? -> (or/c #f string?)
;;   Read the class list value.
(define (dom-token-list-value class-list)
  (js-dom-token-list-value
   (dom-token-list-raw/checked 'dom-token-list-value class-list)))

;; dom-token-list-length : dom-token-list? -> exact-nonnegative-integer?
;;   Read the number of class tokens.
(define (dom-token-list-length class-list)
  (js-dom-token-list-length
   (dom-token-list-raw/checked 'dom-token-list-length class-list)))

;; dom-token-list-item : dom-token-list? exact-nonnegative-integer? -> (or/c #f string?)
;;   Read the class token at an index.
(define (dom-token-list-item class-list index)
  (js-dom-token-list-item
   (dom-token-list-raw/checked 'dom-token-list-item class-list)
   index))

;; dom-token-list-contains? : dom-token-list? (or/c string? symbol?) -> boolean?
;;   Report whether a token is present in the class list.
(define (dom-token-list-contains? class-list token)
  (define raw (dom-token-list-raw/checked 'dom-token-list-contains? class-list))
  (define token* (element-stringish->string 'dom-token-list-contains? token))
  (check-element-host-method 'dom-token-list-contains? raw "DOMTokenList" "contains")
  (js-send/boolean raw "contains" (vector token*)))

;; dom-token-list-add! : dom-token-list? (or/c string? symbol?) ... -> void?
;;   Add one or more tokens to the class list.
(define (dom-token-list-add! class-list token . more-tokens)
  (define raw (dom-token-list-raw/checked 'dom-token-list-add! class-list))
  (define tokens (cons token more-tokens))
  (define token-values
    (list->vector (map (lambda (tok)
                         (element-stringish->string 'dom-token-list-add! tok))
                       tokens)))
  (check-element-host-method 'dom-token-list-add! raw "DOMTokenList" "add")
  (js-send/extern/nullish raw "add" token-values)
  (void))

;; dom-token-list-remove! : dom-token-list? (or/c string? symbol?) ... -> void?
;;   Remove one or more tokens from the class list.
(define (dom-token-list-remove! class-list token . more-tokens)
  (define raw (dom-token-list-raw/checked 'dom-token-list-remove! class-list))
  (define tokens (cons token more-tokens))
  (define token-values
    (list->vector (map (lambda (tok)
                         (element-stringish->string 'dom-token-list-remove! tok))
                       tokens)))
  (check-element-host-method 'dom-token-list-remove! raw "DOMTokenList" "remove")
  (js-send/extern/nullish raw "remove" token-values)
  (void))

;; dom-token-list-toggle! : dom-token-list? (or/c string? symbol?) [force] -> boolean?
;;   Toggle a token, or force a specific state when provided.
(define (dom-token-list-toggle! class-list token [force #f])
  (define raw (dom-token-list-raw/checked 'dom-token-list-toggle! class-list))
  (define token* (element-stringish->string 'dom-token-list-toggle! token))
  (check-element-host-method 'dom-token-list-toggle! raw "DOMTokenList" "toggle")
  (cond
    [(eq? force #f)
     (js-send/boolean raw "toggle" (vector token*))]
    [(procedure? force)
     (js-send/boolean raw "toggle"
                      (vector token* (if (force) #t #f)))]
    [else
     (js-send/boolean raw "toggle"
                      (vector token* (if force #t #f)))]))

;; dom-token-list-replace! : dom-token-list? (or/c string? symbol?) (or/c string? symbol?) -> boolean?
;;   Replace one class token with another.
(define (dom-token-list-replace! class-list old-token new-token)
  (define raw (dom-token-list-raw/checked 'dom-token-list-replace! class-list))
  (define old-token* (element-stringish->string 'dom-token-list-replace! old-token))
  (define new-token* (element-stringish->string 'dom-token-list-replace! new-token))
  (check-element-host-method 'dom-token-list-replace! raw "DOMTokenList" "replace")
  (js-send/boolean raw "replace" (vector old-token* new-token*)))

;; node-list-length : node-list? -> exact-nonnegative-integer?
;;   Read the number of nodes in a NodeList.
(define (node-list-length node-list)
  (js-node-list-length
   (node-list-raw/checked 'node-list-length node-list)))

;; node-list-item : node-list? exact-nonnegative-integer? -> (or/c #f dom-node?)
;;   Read the node at a given index.
(define (node-list-item node-list index)
  (dom-node-wrap
   (js-node-list-item
    (node-list-raw/checked 'node-list-item node-list)
    index)))

;; html-collection-length : html-collection? -> exact-nonnegative-integer?
;;   Read the number of elements in an HTMLCollection.
(define (html-collection-length collection)
  (js-html-collection-length
   (html-collection-raw/checked 'html-collection-length collection)))

;; html-collection-item : html-collection? exact-nonnegative-integer? -> (or/c #f element?)
;;   Read the element at a given index.
(define (html-collection-item collection index)
  (element-wrap
   (js-html-collection-item
    (html-collection-raw/checked 'html-collection-item collection)
    index)))

;; html-collection-named-item : html-collection? (or/c string? symbol?) -> (or/c #f element?)
;;   Read the named element, if present.
(define (html-collection-named-item collection name)
  (define name* (element-stringish->string 'html-collection-named-item name))
  (element-wrap
   (js-html-collection-named-item
    (html-collection-raw/checked 'html-collection-named-item collection)
    name*)))

;; element-get-attribute-ns : element? (or/c string? symbol?) (or/c string? symbol?) -> (or/c #f string?)
;;   Read a namespaced element attribute.
(define (element-get-attribute-ns element ns name)
  (define ns* (element-stringish->string 'element-get-attribute-ns ns))
  (define name* (element-stringish->string 'element-get-attribute-ns name))
  (js-get-attribute-ns (element-unwrap element) ns* name*))

;; element-has-attribute-ns? : element? (or/c string? symbol?) (or/c string? symbol?) -> boolean?
;;   Report whether an element has a namespaced attribute.
(define (element-has-attribute-ns? element ns name)
  (define ns* (element-stringish->string 'element-has-attribute-ns? ns))
  (define name* (element-stringish->string 'element-has-attribute-ns? name))
  (element-i32->boolean
   (js-has-attribute-ns (element-unwrap element) ns* name*)))

;; element-parent-element : element? -> (or/c #f element?)
;;   Read the parent element.
(define-element-wrap-getter element-parent-element js-element-parent-element element-wrap)

;; element-previous-element-sibling : element? -> (or/c #f element?)
;;   Read the previous element sibling.
(define-element-wrap-getter
  element-previous-element-sibling
  js-element-previous-element-sibling
  element-wrap)

;; element-next-element-sibling : element? -> (or/c #f element?)
;;   Read the next element sibling.
(define-element-wrap-getter
  element-next-element-sibling
  js-element-next-element-sibling
  element-wrap)

;; element-get-elements-by-class-name : element? (or/c string? symbol?) -> html-collection?
;;   Read descendant elements with matching class names as a wrapped HTMLCollection.
(define (element-get-elements-by-class-name element class-name)
  (define class-name* (element-stringish->string 'element-get-elements-by-class-name class-name))
  (html-collection-wrap
   (js-element-get-elements-by-class-name (element-unwrap element) class-name*)))

;; element-get-elements-by-tag-name : element? (or/c string? symbol?) -> html-collection?
;;   Read descendant elements with a matching tag name as a wrapped HTMLCollection.
(define (element-get-elements-by-tag-name element tag-name)
  (define tag-name* (element-stringish->string 'element-get-elements-by-tag-name tag-name))
  (html-collection-wrap
   (js-element-get-elements-by-tag-name (element-unwrap element) tag-name*)))

;; element-get-elements-by-tag-name-ns : element? (or/c string? symbol?) (or/c string? symbol?) -> html-collection?
;;   Read descendant elements with a matching namespaced tag name as a wrapped HTMLCollection.
(define (element-get-elements-by-tag-name-ns element ns tag-name)
  (define ns* (element-stringish->string 'element-get-elements-by-tag-name-ns ns))
  (define tag-name* (element-stringish->string 'element-get-elements-by-tag-name-ns tag-name))
  (html-collection-wrap
   (js-element-get-elements-by-tag-name-ns (element-unwrap element) ns* tag-name*)))

;; element-children : element? -> html-collection?
;;   Read the child elements as a wrapped HTMLCollection.
(define-element-wrap-getter element-children js-element-children html-collection-wrap)

;; element-scroll-top : element? -> real?
;;   Read an element's vertical scroll offset.
(define-element-getter element-scroll-top js-element-scroll-top)

;; element-set-scroll-top! : element? real? -> void?
;;   Set an element's vertical scroll offset.
(define (element-set-scroll-top! element value)
  (js-set-element-scroll-top! (element-unwrap element)
                              (element-real->flonum 'element-set-scroll-top! value))
  (void))

;; element-scroll-left : element? -> real?
;;   Read an element's horizontal scroll offset.
(define-element-getter element-scroll-left js-element-scroll-left)

;; element-set-scroll-left! : element? real? -> void?
;;   Set an element's horizontal scroll offset.
(define (element-set-scroll-left! element value)
  (js-set-element-scroll-left! (element-unwrap element)
                               (element-real->flonum 'element-set-scroll-left! value))
  (void))

;; element-scroll-width : element? -> exact-nonnegative-integer?
;;   Read an element's scroll width.
(define-element-getter element-scroll-width js-element-scroll-width)

;; element-scroll-height : element? -> exact-nonnegative-integer?
;;   Read an element's scroll height.
(define-element-getter element-scroll-height js-element-scroll-height)

;; element-client-width : element? -> exact-nonnegative-integer?
;;   Read an element's client width.
(define-element-getter element-client-width js-element-client-width)

;; element-client-height : element? -> exact-nonnegative-integer?
;;   Read an element's client height.
(define-element-getter element-client-height js-element-client-height)

;; element-offset-width : element? -> exact-nonnegative-integer?
;;   Read an element's offset width.
(define-element-getter element-offset-width js-element-offset-width)

;; element-offset-height : element? -> exact-nonnegative-integer?
;;   Read an element's offset height.
(define-element-getter element-offset-height js-element-offset-height)

;; element-child-element-count : element? -> exact-nonnegative-integer?
;;   Read the number of child elements.
(define-element-getter element-child-element-count js-element-child-element-count)

;; element-first-element-child : element? -> (or/c #f element?)
;;   Read the first child element, if any.
(define-element-wrap-getter element-first-element-child js-element-first-element-child element-wrap)

;; element-last-element-child : element? -> (or/c #f element?)
;;   Read the last child element, if any.
(define-element-wrap-getter element-last-element-child js-element-last-element-child element-wrap)

;; element-inner-html : element? -> string?
;;   Read an element's HTML contents.
(define-element-getter element-inner-html js-element-inner-html)

;; element-set-inner-html! : element? (or/c string? symbol?) -> void?
;;   Replace an element's HTML contents.
(define-element-setter element-set-inner-html! js-set-element-inner-html!
  (lambda (html)
    (element-stringish->string 'element-set-inner-html! html)))

;; element-outer-html : element? -> string?
;;   Read an element's outer HTML.
(define-element-getter element-outer-html js-element-outer-html)

;; element-set-outer-html! : element? (or/c string? symbol?) -> void?
;;   Replace an element's outer HTML.
(define-element-setter element-set-outer-html! js-set-element-outer-html!
  (lambda (html)
    (element-stringish->string 'element-set-outer-html! html)))

;; element-text-content : element? -> (or/c #f string?)
;;   Read an element's text content.
(define-element-getter element-text-content js-element-text-content)

;; element-set-text-content! : element? (or/c string? symbol?) -> void?
;;   Replace an element's text content.
(define-element-setter element-set-text-content! js-set-element-text-content!
  (lambda (text)
    (element-stringish->string 'element-set-text-content! text)))

;; element-value : element? -> (or/c #f string?)
;;   Read an element's value property.
(define (element-value element)
  (define raw (element-unwrap element))
  (check-shared-dom-host-property 'element-value raw "Element" "value")
  (js-ref raw "value"))

;; element-set-value! : element? (or/c string? symbol?) -> void?
;;   Set an element's value property.
(define (element-set-value! element value)
  (define raw (element-unwrap element))
  (check-shared-dom-host-property 'element-set-value! raw "Element" "value")
  (js-set! raw "value" (element-stringish->string 'element-set-value! value))
  (void))

;; element-computed-style-map : element? -> external/raw
;;   Read the computed style map for an element.
(define (element-computed-style-map element)
  (computed-style-map-wrap (js-computed-style-map (element-unwrap element))))

;; element-get-animations : element? -> vector?
;;   Read animations affecting an element.
(define (element-get-animations element)
  (array-like->vector 'element-get-animations
                      (js-get-animations (element-unwrap element))
                      animation-wrap))

;; element-shadow-root : element? -> (or/c #f shadow-root?)
;;   Read an element's shadow root, if one is attached.
(define (element-shadow-root element)
  (shadow-root-wrap (js-element-shadow-root (element-unwrap element))))

;; element-attach-shadow! : element? any/c -> shadow-root?
;;   Attach a shadow root to an element.
(define (element-attach-shadow! element options)
  (shadow-root-wrap (js-attach-shadow! (element-unwrap element) options)))

;; shadow-root-host : shadow-root? -> element?
;;   Read the host element for a shadow root.
(define (shadow-root-host shadow-root)
  (element-wrap
   (js-shadow-root-host
    (shadow-root-raw/checked 'shadow-root-host shadow-root))))

;; shadow-root-mode : shadow-root? -> string?
;;   Read the shadow root mode.
(define (shadow-root-mode shadow-root)
  (js-shadow-root-mode
   (shadow-root-raw/checked 'shadow-root-mode shadow-root)))

;; shadow-root-delegates-focus? : shadow-root? -> boolean?
;;   Report whether the shadow root delegates focus.
(define (shadow-root-delegates-focus? shadow-root)
  (js-shadow-root-delegates-focus
   (shadow-root-raw/checked 'shadow-root-delegates-focus? shadow-root)))

;; element-animate : element? any/c [any/c] -> animation?
;;   Start an animation on an element.
(define (element-animate element keyframes [options #f])
  (animation-wrap
   (js-animate (element-unwrap element)
               keyframes
               (if (eq? options #f) (js-undefined) options))))

;; element-get-attribute-node : element? (or/c string? symbol?) -> (or/c #f dom-attr?)
;;   Read the attribute node for a given name.
(define (element-get-attribute-node element name)
  (define name* (element-stringish->string 'element-get-attribute-node name))
  (dom-attr-wrap (js-get-attribute-node (element-unwrap element) name*)))

;; element-get-attribute-node-ns : element? (or/c string? symbol?) (or/c string? symbol?) -> (or/c #f dom-attr?)
;;   Read the namespaced attribute node for an element.
(define (element-get-attribute-node-ns element ns name)
  (define ns* (element-stringish->string 'element-get-attribute-node-ns ns))
  (define name* (element-stringish->string 'element-get-attribute-node-ns name))
  (dom-attr-wrap (js-get-attribute-node-ns (element-unwrap element) ns* name*)))

;; element-set-attribute-node! : element? any/c -> (or/c #f dom-attr?)
;;   Attach an attribute node to an element.
(define (element-set-attribute-node! element node)
  (dom-attr-wrap
   (js-set-attribute-node! (element-unwrap element)
                           (element-nodeish->value 'element-set-attribute-node! node))))

;; element-set-attribute-node-ns! : element? any/c -> (or/c #f dom-attr?)
;;   Attach a namespaced attribute node to an element.
(define (element-set-attribute-node-ns! element node)
  (dom-attr-wrap
   (js-set-attribute-node-ns! (element-unwrap element)
                              (element-nodeish->value 'element-set-attribute-node-ns! node))))

;; element-remove-attribute-node! : element? any/c -> (or/c #f dom-attr?)
;;   Remove an attribute node from an element.
(define (element-remove-attribute-node! element node)
  (dom-attr-wrap
   (js-remove-attribute-node! (element-unwrap element)
                              (element-nodeish->value 'element-remove-attribute-node! node))))

;; get-bounding-client-rect : element? -> dom-rect?
;;   Read the element bounding box.
(define (get-bounding-client-rect element)
  (dom-rect-wrap (js-get-bounding-client-rect (element-unwrap element))))

;; element-get-bounding-client-rect : element? -> dom-rect?
;;   Read the element bounding box.
(define (element-get-bounding-client-rect element)
  (get-bounding-client-rect element))

;; dom-rect-list-length : dom-rect-list? -> exact-nonnegative-integer?
;;   Read the number of rectangles in a DOMRectList.
(define (dom-rect-list-length rect-list)
  (js-dom-rect-list-length
   (dom-rect-list-raw/checked 'dom-rect-list-length rect-list)))

;; dom-rect-list-item : dom-rect-list? exact-nonnegative-integer? -> (or/c #f dom-rect?)
;;   Read a rectangle at a given index.
(define (dom-rect-list-item rect-list index)
  (dom-rect-wrap
   (js-dom-rect-list-item
    (dom-rect-list-raw/checked 'dom-rect-list-item rect-list)
    index)))

;; get-client-rects : external? -> dom-rect-list?
;;   Read the client rect list as a wrapped DOMRectList.
(define (get-client-rects element)
  (dom-rect-list-wrap (js-get-client-rects (element-unwrap element))))

;; element-get-client-rects : element? -> dom-rect-list?
;;   Read the client rect list as a wrapped DOMRectList.
(define (element-get-client-rects element)
  (get-client-rects element))

;; query-selector : external? (or/c string? symbol?) -> (or/c #f element?)
;;   Find the first matching descendant.
(define (query-selector element selector)
  (define selector* (element-stringish->string 'query-selector selector))
  (element-wrap (js-element-query-selector (element-unwrap element) selector*)))

;; element-query-selector : element? (or/c string? symbol?) -> (or/c #f element?)
;;   Find the first matching descendant.
(define (element-query-selector element selector)
  (query-selector element selector))

;; query-selector-all : external? (or/c string? symbol?) -> node-list?
;;   Find all matching descendants as a wrapped NodeList.
(define (query-selector-all element selector)
  (define selector* (element-stringish->string 'query-selector-all selector))
  (node-list-wrap
   (js-element-query-selector-all (element-unwrap element) selector*)))

;; element-query-selector-all : element? (or/c string? symbol?) -> node-list?
;;   Find all matching descendants as a wrapped NodeList.
(define (element-query-selector-all element selector)
  (query-selector-all element selector))

;; element-insert-adjacent-element! : element? (or/c string? symbol?) any/c -> (or/c #f element?)
;;   Insert an element relative to another element.
(define (element-insert-adjacent-element! element position child)
  (define position* (element-stringish->string 'element-insert-adjacent-element! position))
  (element-wrap
   (js-insert-adjacent-element! (element-unwrap element)
                                position*
                                (element-nodeish->value
                                 'element-insert-adjacent-element!
                                 child))))

;; element-insert-adjacent-html! : element? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Insert HTML relative to an element.
(define (element-insert-adjacent-html! element position html)
  (define position* (element-stringish->string 'element-insert-adjacent-html! position))
  (define html* (element-stringish->string 'element-insert-adjacent-html! html))
  (js-insert-adjacent-html! (element-unwrap element) position* html*)
  (void))

;; element-insert-adjacent-text! : element? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Insert text relative to an element.
(define (element-insert-adjacent-text! element position text)
  (define position* (element-stringish->string 'element-insert-adjacent-text! position))
  (define text* (element-stringish->string 'element-insert-adjacent-text! text))
  (js-insert-adjacent-text! (element-unwrap element) position* text*)
  (void))

;; remove! : external? -> void?
;;   Remove the element from the DOM.
(define (remove! element)
  (js-remove! (element-unwrap element))
  (void))

;; element-remove! : element? -> void?
;;   Remove the element from the DOM.
(define (element-remove! element)
  (remove! element))

;; replace-children*/who! : symbol? external? any/c -> void?
;;   Replace the child list with one normalized node or text value.
(define (replace-children*/who! who element child)
  (js-replace-children! (element-unwrap element)
                        (element-nodeish->value who child))
  (void))

;; replace-children! : external? any/c -> void?
;;   Replace the child list with one node or text value.
(define (replace-children! element child)
  (replace-children*/who! 'replace-children! element child))

;; element-replace-children! : element? any/c -> void?
;;   Replace the child list with one node or text value.
(define (element-replace-children! element child)
  (replace-children*/who! 'element-replace-children! element child))

;; replace-with*/who! : symbol? external? any/c -> void?
;;   Replace the element with one normalized node or text value.
(define (replace-with*/who! who element sibling)
  (js-replace-with! (element-unwrap element)
                    (element-nodeish->value who sibling))
  (void))

;; replace-with! : external? any/c -> void?
;;   Replace the element with another node or text value.
(define (replace-with! element sibling)
  (replace-with*/who! 'replace-with! element sibling))

;; element-replace-with! : element? any/c -> void?
;;   Replace the element with another node or text value.
(define (element-replace-with! element sibling)
  (replace-with*/who! 'element-replace-with! element sibling))

;; request-fullscreen : external? -> external/raw
;;   Request fullscreen for the element.
(define (request-fullscreen element)
  (js-request-fullscreen (element-unwrap element)))

;; element-request-fullscreen : element? -> external/raw
;;   Request fullscreen for the element.
(define (element-request-fullscreen element)
  (request-fullscreen element))

;; request-pointer-lock : external? -> void?
;;   Request pointer lock.
(define (request-pointer-lock element)
  (js-request-pointer-lock (element-unwrap element))
  (void))

;; element-request-pointer-lock : element? -> void?
;;   Request pointer lock.
(define (element-request-pointer-lock element)
  (request-pointer-lock element))

;; element-set-pointer-capture! : element? exact-nonnegative-integer? -> void?
;;   Capture pointer events for a pointer id.
(define (element-set-pointer-capture! element pointer-id)
  (unless (exact-nonnegative-integer? pointer-id)
    (raise-argument-error 'element-set-pointer-capture! "exact-nonnegative-integer?" pointer-id))
  (js-set-pointer-capture! (element-unwrap element) pointer-id)
  (void))

;; element-release-pointer-capture! : element? exact-nonnegative-integer? -> void?
;;   Release pointer capture for a pointer id.
(define (element-release-pointer-capture! element pointer-id)
  (unless (exact-nonnegative-integer? pointer-id)
    (raise-argument-error 'element-release-pointer-capture! "exact-nonnegative-integer?" pointer-id))
  (js-release-pointer-capture! (element-unwrap element) pointer-id)
  (void))

;; scroll! : external? real? real? -> void?
;;   Scroll an element to an absolute position.
(define (scroll! element x y)
  (js-scroll! (element-unwrap element) x y)
  (void))

;; element-scroll! : element? real? real? -> void?
;;   Scroll an element to an absolute position.
(define (element-scroll! element x y)
  (scroll! element x y))

;; scroll-by! : external? real? real? -> void?
;;   Scroll an element by a relative offset.
(define (scroll-by! element x y)
  (js-scroll-by! (element-unwrap element) x y)
  (void))

;; element-scroll-by! : element? real? real? -> void?
;;   Scroll an element by a relative offset.
(define (element-scroll-by! element x y)
  (scroll-by! element x y))

;; scroll-into-view! : element? [boolean?] -> void?
;;   Scroll ancestors until the element is visible.
(define (scroll-into-view! element [align-to-top? #t])
  (js-scroll-into-view! (element-unwrap element) (if align-to-top? 1 0))
  (void))

;; element-scroll-into-view! : element? [boolean?] -> void?
;;   Scroll ancestors until the element is visible.
(define (element-scroll-into-view! element [align-to-top? #t])
  (scroll-into-view! element align-to-top?))

;; scroll-to! : external? real? real? -> void?
;;   Scroll an element to an absolute position.
(define (scroll-to! element x y)
  (js-scroll-to! (element-unwrap element) x y)
  (void))

;; element-scroll-to! : element? real? real? -> void?
;;   Scroll an element to an absolute position.
(define (element-scroll-to! element x y)
  (scroll-to! element x y))

;; set-attribute-ns! : external? (or/c string? symbol?) (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Set a namespaced attribute.
(define (set-attribute-ns! element ns name value)
  (define ns* (element-stringish->string 'set-attribute-ns! ns))
  (define name* (element-stringish->string 'set-attribute-ns! name))
  (define value* (element-stringish->string 'set-attribute-ns! value))
  (js-set-attribute-ns! (element-unwrap element) ns* name* value*)
  (void))

;; element-set-attribute-ns! : element? (or/c string? symbol?) (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Set a namespaced attribute.
(define (element-set-attribute-ns! element ns name value)
  (set-attribute-ns! element ns name value))

;; toggle-attribute! : external? (or/c string? symbol?) (or/c boolean? procedure?) -> boolean?
;;   Toggle an attribute, or force a specific state when provided.
(define (toggle-attribute! element name [force #f])
  (define name* (element-stringish->string 'toggle-attribute! name))
  (cond
    [(eq? force #f)
     (element-i32->boolean
      (js-toggle-attribute (element-unwrap element) name*))]
    [(procedure? force)
     (element-i32->boolean
      (js-toggle-attribute! (element-unwrap element) name* (if (force) 1 0)))]
    [else
     (element-i32->boolean
      (js-toggle-attribute! (element-unwrap element) name* (if force 1 0)))]))

;; element-toggle-attribute! : element? (or/c string? symbol?) (or/c boolean? procedure?) -> boolean?
;;   Toggle an attribute, or force a specific state when provided.
(define (element-toggle-attribute! element name [force #f])
  (toggle-attribute! element name force))
