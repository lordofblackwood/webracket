#lang racket/base

(require webracket/unsafe/standard
         (only-in webracket/primitives
                  external?))

(provide (except-out (all-defined-out)
                     dom-element?
                     dom-text?
                     dom-node?
                     dom-attr?
                     dom-node-list?
                     html-collection?
                     dom-token-list?
                     dom-shadow-root?
                     dom-animation?
                     dom-computed-style-map?
                     audio-listener?
                     audio-periodic-wave?
                     dom-rect?
                     dom-rect-list?
                     dom-selection?
                     media-query-list?
                     css-style-declaration?
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
         (rename-out [dom-element/surface? dom-element?]
                     [dom-text/surface? dom-text?]
                     [dom-node/surface? dom-node?]
                     [dom-attr/surface? dom-attr?]
                     [dom-node-list/surface? dom-node-list?]
                     [html-collection/surface? html-collection?]
                     [dom-token-list/surface? dom-token-list?]
                     [dom-shadow-root/surface? dom-shadow-root?]
                     [dom-animation/surface? dom-animation?]
                     [dom-computed-style-map/surface? dom-computed-style-map?]
                     [audio-listener/surface? audio-listener?]
                     [audio-periodic-wave/surface? audio-periodic-wave?]
                     [dom-rect/surface? dom-rect?]
                     [dom-rect-list/surface? dom-rect-list?]
                     [dom-selection/surface? dom-selection?]
                     [media-query-list/surface? media-query-list?]
                     [css-style-declaration/surface? css-style-declaration?]
                     [media-stream/surface? media-stream?]
                     [media-source/surface? media-source?]
                     [media-keys-info/surface? media-keys-info?]
                     [audio-track/surface? audio-track?]
                     [text-track/surface? text-track?]
                     [video-track/surface? video-track?]
                     [media-error-info/surface? media-error-info?]
                     [audio-track-list/surface? audio-track-list?]
                     [text-track-list/surface? text-track-list?]
                     [video-track-list/surface? video-track-list?]
                     [time-ranges/surface? time-ranges?]))

;;;
;;; Shared DOM structs.
;;;

;; dom-element : external/raw -> dom-element?
;;   Wrap a browser Element object.
(struct dom-element (raw) #:transparent)

;; shared-dom-nullish-value? : any/c -> boolean?
;;   Report whether value is Racket #f or a JavaScript nullish host value.
(define (shared-dom-nullish-value? value)
  (or (not value)
      (and (external? value)
           (js-nullish? value))))

;; shared-dom-raw-host-value? : any/c -> boolean?
;;   Report whether value is a non-nullish external host value.
(define (shared-dom-raw-host-value? value)
  (and (external? value)
       (not (js-nullish? value))))

;; shared-dom-wrapper-with-host? : any/c (any/c -> boolean?) (any/c -> any/c) -> boolean?
;;   Report whether value is a wrapper around a non-nullish host value.
(define (shared-dom-wrapper-with-host? value wrapper? raw-ref)
  (and (wrapper? value)
       (shared-dom-raw-host-value? (raw-ref value))))

;; dom-element/surface? : any/c -> boolean?
;;   Check whether value is a usable Element wrapper.
(define (dom-element/surface? value)
  (shared-dom-wrapper-with-host? value dom-element? dom-element-raw))

;; shared-dom-wrap-value : any/c (any/c -> boolean?) (any/c -> any/c) -> any/c
;;   Preserve wrapped and nullish values, otherwise build a host wrapper.
(define (shared-dom-wrap-value value wrapped? make-wrapper)
  (cond
    [(wrapped? value) value]
    [(shared-dom-nullish-value? value) #f]
    [else (make-wrapper value)]))

;; element-wrap : any/c -> any/c
;;   Wrap a raw browser Element object, leaving wrapped values alone.
(define (element-wrap value)
  (shared-dom-wrap-value value dom-element? dom-element))

;; element-unwrap : any/c -> any/c
;;   Unwrap an element struct to its raw browser object.
(define (element-unwrap value)
  (if (dom-element? value)
      (dom-element-raw value)
      (if (dom-text? value)
          (dom-text-raw value)
          value)))

;; dom-text : external/raw -> dom-text?
;;   Wrap a browser Text node.
(struct dom-text (raw) #:transparent)

;; dom-text/surface? : any/c -> boolean?
;;   Check whether value is a usable Text wrapper.
(define (dom-text/surface? value)
  (shared-dom-wrapper-with-host? value dom-text? dom-text-raw))

;; dom-text-wrap : any/c -> any/c
;;   Wrap a raw browser Text node, leaving wrapped values alone.
(define (dom-text-wrap value)
  (shared-dom-wrap-value value dom-text? dom-text))

;; dom-text-unwrap : any/c -> any/c
;;   Unwrap a dom-text struct to its raw browser object.
(define (dom-text-unwrap value)
  (if (dom-text? value)
      (dom-text-raw value)
      value))

;; dom-node : external/raw -> dom-node?
;;   Wrap a browser Node object.
(struct dom-node (raw) #:transparent)

;; dom-node/surface? : any/c -> boolean?
;;   Check whether value is a usable Node wrapper.
(define (dom-node/surface? value)
  (shared-dom-wrapper-with-host? value dom-node? dom-node-raw))

;; shared-dom-node-wrapper? : any/c -> boolean?
;;   Report whether value is already one of the node-wrapper structs.
(define (shared-dom-node-wrapper? value)
  (or (dom-node? value)
      (dom-element? value)
      (dom-text? value)
      (dom-attr? value)))

;; dom-node-wrap : any/c -> any/c
;;   Wrap a raw browser Node object, leaving wrapped values alone.
(define (dom-node-wrap value)
  (shared-dom-wrap-value value shared-dom-node-wrapper? dom-node))

;; dom-node-unwrap : any/c -> any/c
;;   Unwrap a dom-node struct to its raw browser object.
(define (dom-node-unwrap value)
  (cond
    [(dom-node? value) (dom-node-raw value)]
    [(dom-element? value) (dom-element-raw value)]
    [(dom-text? value) (dom-text-raw value)]
    [(dom-attr? value) (dom-attr-raw value)]
    [else value]))

;; shared-dom-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable DOM method.
(define (shared-dom-host-method-present? raw method-name)
  (and (shared-dom-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; shared-dom-host-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish browser property.
(define (shared-dom-host-property-present? raw property-name)
  (and (shared-dom-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; shared-dom-host-properties-present? : external/raw (listof string?) -> boolean?
;;   Report whether raw exposes all named non-nullish browser properties.
(define (shared-dom-host-properties-present? raw property-names)
  (for/and ([property-name (in-list property-names)])
    (shared-dom-host-property-present? raw property-name)))

;; shared-dom-host-methods-present? : external/raw (listof string?) -> boolean?
;;   Report whether raw exposes all named callable browser methods.
(define (shared-dom-host-methods-present? raw method-names)
  (for/and ([method-name (in-list method-names)])
    (shared-dom-host-method-present? raw method-name)))

;; shared-dom-host-surface-present? : external/raw (listof string?) (listof string?) -> boolean?
;;   Report whether raw exposes the requested browser property and method surface.
(define (shared-dom-host-surface-present? raw property-names method-names)
  (and (shared-dom-host-properties-present? raw property-names)
       (shared-dom-host-methods-present? raw method-names)))

;; check-shared-dom-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required shared DOM host method is available.
(define (check-shared-dom-host-method who raw receiver-name method-name)
  (unless (shared-dom-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " not available in this environment"))))

;; check-shared-dom-host-property : symbol? external/raw string? string? -> void?
;;   Ensure a required shared DOM host property is available.
(define (check-shared-dom-host-property who raw receiver-name property-name)
  (unless (shared-dom-host-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " not available in this environment"))))

;; check-shared-dom-host-nullable-property : symbol? external/raw string? string? -> void?
;;   Ensure a required shared DOM property is present, allowing null values.
(define (check-shared-dom-host-nullable-property who raw receiver-name property-name)
  (when (or (not (shared-dom-raw-host-value? raw))
            (js-undefined? (js-ref/extern raw property-name)))
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " not available in this environment"))))

;; dom-attr : external/raw -> dom-attr?
;;   Wrap a browser Attr node.
(struct dom-attr (raw) #:transparent)

;; dom-attr/surface? : any/c -> boolean?
;;   Check whether value is a usable Attr wrapper.
(define (dom-attr/surface? value)
  (shared-dom-wrapper-with-host? value dom-attr? dom-attr-raw))

;; dom-attr-wrap : any/c -> any/c
;;   Wrap a raw browser Attr node, leaving wrapped values alone.
(define (dom-attr-wrap value)
  (shared-dom-wrap-value value dom-attr? dom-attr))

;; dom-attr-unwrap : any/c -> any/c
;;   Unwrap a dom-attr struct to its raw browser object.
(define (dom-attr-unwrap value)
  (if (dom-attr? value)
      (dom-attr-raw value)
      value))

;; dom-node-list : external/raw -> dom-node-list?
;;   Wrap a browser NodeList object.
(struct dom-node-list (raw) #:transparent)

;; dom-node-list/surface? : any/c -> boolean?
;;   Check whether value is a usable NodeList wrapper.
(define (dom-node-list/surface? value)
  (shared-dom-wrapper-with-host? value dom-node-list? dom-node-list-raw))

;; node-list-wrap : any/c -> any/c
;;   Wrap a raw browser NodeList object, leaving wrapped values alone.
(define (node-list-wrap value)
  (shared-dom-wrap-value value dom-node-list? dom-node-list))

;; node-list-unwrap : any/c -> any/c
;;   Unwrap a node-list struct to its raw browser object.
(define (node-list-unwrap value)
  (if (dom-node-list? value)
      (dom-node-list-raw value)
      value))

;; html-collection : external/raw -> html-collection?
;;   Wrap a browser HTMLCollection object.
(struct html-collection (raw) #:transparent)

;; html-collection/surface? : any/c -> boolean?
;;   Check whether value is a usable HTMLCollection wrapper.
(define (html-collection/surface? value)
  (shared-dom-wrapper-with-host? value html-collection? html-collection-raw))

;; html-collection-wrap : any/c -> any/c
;;   Wrap a raw browser HTMLCollection object, leaving wrapped values alone.
(define (html-collection-wrap value)
  (shared-dom-wrap-value value html-collection? html-collection))

;; html-collection-unwrap : any/c -> any/c
;;   Unwrap an html-collection struct to its raw browser object.
(define (html-collection-unwrap value)
  (if (html-collection? value)
      (html-collection-raw value)
      value))

;; dom-token-list : external/raw -> dom-token-list?
;;   Wrap a browser DOMTokenList object.
(struct dom-token-list (raw) #:transparent)

;; dom-token-list/surface? : any/c -> boolean?
;;   Check whether value is a usable DOMTokenList wrapper.
(define (dom-token-list/surface? value)
  (shared-dom-wrapper-with-host? value dom-token-list? dom-token-list-raw))

;; dom-token-list-wrap : any/c -> any/c
;;   Wrap a raw browser DOMTokenList object, leaving wrapped values alone.
(define (dom-token-list-wrap value)
  (shared-dom-wrap-value value dom-token-list? dom-token-list))

;; dom-token-list-unwrap : any/c -> any/c
;;   Unwrap a DOMTokenList struct to its raw browser object.
(define (dom-token-list-unwrap value)
  (if (dom-token-list? value)
      (dom-token-list-raw value)
      value))

;; dom-shadow-root : external/raw -> dom-shadow-root?
;;   Wrap a browser ShadowRoot object.
(struct dom-shadow-root (raw) #:transparent)

;; dom-shadow-root/surface? : any/c -> boolean?
;;   Check whether value is a usable ShadowRoot wrapper.
(define (dom-shadow-root/surface? value)
  (shared-dom-wrapper-with-host? value dom-shadow-root? dom-shadow-root-raw))

;; shadow-root-wrap : any/c -> any/c
;;   Wrap a raw browser ShadowRoot object, leaving wrapped values alone.
(define (shadow-root-wrap value)
  (shared-dom-wrap-value value dom-shadow-root? dom-shadow-root))

;; shadow-root-unwrap : any/c -> any/c
;;   Unwrap a shadow-root struct to its raw browser object.
(define (shadow-root-unwrap value)
  (if (dom-shadow-root? value)
      (dom-shadow-root-raw value)
      value))

;; dom-animation : external/raw -> dom-animation?
;;   Wrap a browser Animation object.
(struct dom-animation (raw) #:transparent)

;; dom-animation/surface? : any/c -> boolean?
;;   Check whether value is a usable Animation wrapper.
(define (dom-animation/surface? value)
  (shared-dom-wrapper-with-host? value dom-animation? dom-animation-raw))

;; animation-wrap : any/c -> any/c
;;   Wrap a raw browser Animation object, leaving wrapped values alone.
(define (animation-wrap value)
  (shared-dom-wrap-value value dom-animation? dom-animation))

;; animation-unwrap : any/c -> any/c
;;   Unwrap an animation struct to its raw browser object.
(define (animation-unwrap value)
  (if (dom-animation? value)
      (dom-animation-raw value)
      value))

;; dom-computed-style-map : external/raw -> dom-computed-style-map?
;;   Wrap a browser ComputedStyleMap object.
(struct dom-computed-style-map (raw) #:transparent)

;; dom-computed-style-map/surface? : any/c -> boolean?
;;   Check whether value is a usable ComputedStyleMap wrapper.
(define (dom-computed-style-map/surface? value)
  (shared-dom-wrapper-with-host? value dom-computed-style-map? dom-computed-style-map-raw))

;; computed-style-map-wrap : any/c -> any/c
;;   Wrap a raw browser ComputedStyleMap object, leaving wrapped values alone.
(define (computed-style-map-wrap value)
  (shared-dom-wrap-value value dom-computed-style-map? dom-computed-style-map))

;; computed-style-map-unwrap : any/c -> any/c
;;   Unwrap a computed-style-map struct to its raw browser object.
(define (computed-style-map-unwrap value)
  (if (dom-computed-style-map? value)
      (dom-computed-style-map-raw value)
      value))

;; audio-listener : external/raw -> audio-listener?
;;   Wrap a browser AudioListener object.
(struct audio-listener (raw) #:transparent)

;; audio-listener/surface? : any/c -> boolean?
;;   Check whether value is a usable AudioListener wrapper.
(define (audio-listener/surface? value)
  (shared-dom-wrapper-with-host? value audio-listener? audio-listener-raw))

;; audio-listener-wrap : any/c -> any/c
;;   Wrap a raw browser AudioListener object, leaving wrapped values alone.
(define (audio-listener-wrap value)
  (shared-dom-wrap-value value audio-listener? audio-listener))

;; audio-listener-unwrap : any/c -> any/c
;;   Unwrap an audio-listener struct to its raw browser object.
(define (audio-listener-unwrap value)
  (if (audio-listener? value)
      (audio-listener-raw value)
      value))

;; audio-periodic-wave : external/raw -> audio-periodic-wave?
;;   Wrap a browser PeriodicWave object.
(struct audio-periodic-wave (raw) #:transparent)

;; audio-periodic-wave/surface? : any/c -> boolean?
;;   Check whether value is a usable PeriodicWave wrapper.
(define (audio-periodic-wave/surface? value)
  (shared-dom-wrapper-with-host? value audio-periodic-wave? audio-periodic-wave-raw))

;; audio-periodic-wave-wrap : any/c -> any/c
;;   Wrap a raw browser PeriodicWave object, leaving wrapped values alone.
(define (audio-periodic-wave-wrap value)
  (shared-dom-wrap-value value audio-periodic-wave? audio-periodic-wave))

;; audio-periodic-wave-unwrap : any/c -> any/c
;;   Unwrap an audio-periodic-wave struct to its raw browser object.
(define (audio-periodic-wave-unwrap value)
  (if (audio-periodic-wave? value)
      (audio-periodic-wave-raw value)
      value))

;; array-like->vector : symbol? any/c (-> any/c any/c) -> vector?
;;   Convert a browser array-like value into a WebRacket vector.
(define (array-like->vector who value wrap-item)
  (unless (shared-dom-raw-host-value? value)
    (raise-argument-error who "array-like browser value" value))
  (define length (js-ref value "length"))
  (unless (exact-nonnegative-integer? length)
    (raise-argument-error who "array-like browser value" value))
  (let loop ([i 0] [acc '()])
    (if (= i length)
        (list->vector (reverse acc))
        (loop (add1 i)
              (cons (wrap-item (js-index value i)) acc)))))

;; dom-rect : external/raw -> dom-rect?
;;   Wrap a browser DOMRect object.
(struct dom-rect (raw) #:transparent)

;; dom-rect/surface? : any/c -> boolean?
;;   Check whether value is a usable DOMRect wrapper.
(define (dom-rect/surface? value)
  (shared-dom-wrapper-with-host? value dom-rect? dom-rect-raw))

;; dom-rect-wrap : any/c -> any/c
;;   Wrap a raw browser DOMRect object, leaving wrapped values alone.
(define (dom-rect-wrap value)
  (shared-dom-wrap-value value dom-rect? dom-rect))

;; dom-rect-unwrap : any/c -> any/c
;;   Unwrap a DOMRect struct to its raw browser object.
(define (dom-rect-unwrap value)
  (if (dom-rect? value)
      (dom-rect-raw value)
      value))

;; dom-rect-list : external/raw -> dom-rect-list?
;;   Wrap a browser DOMRectList object.
(struct dom-rect-list (raw) #:transparent)

;; dom-rect-list/surface? : any/c -> boolean?
;;   Check whether value is a usable DOMRectList wrapper.
(define (dom-rect-list/surface? value)
  (shared-dom-wrapper-with-host? value dom-rect-list? dom-rect-list-raw))

;; dom-rect-list-wrap : any/c -> any/c
;;   Wrap a raw browser DOMRectList object, leaving wrapped values alone.
(define (dom-rect-list-wrap value)
  (shared-dom-wrap-value value dom-rect-list? dom-rect-list))

;; dom-rect-list-unwrap : any/c -> any/c
;;   Unwrap a dom-rect-list struct to its raw browser object.
(define (dom-rect-list-unwrap value)
  (if (dom-rect-list? value)
      (dom-rect-list-raw value)
      value))

;; dom-selection : external/raw -> dom-selection?
;;   Wrap a browser Selection object.
(struct dom-selection (raw) #:transparent)

;; dom-selection/surface? : any/c -> boolean?
;;   Check whether value is a usable Selection wrapper.
(define (dom-selection/surface? value)
  (shared-dom-wrapper-with-host? value dom-selection? dom-selection-raw))

;; dom-selection-wrap : any/c -> any/c
;;   Wrap a raw browser Selection object, leaving wrapped values alone.
(define (dom-selection-wrap value)
  (shared-dom-wrap-value value dom-selection? dom-selection))

;; dom-selection-unwrap : any/c -> any/c
;;   Unwrap a dom-selection struct to its raw browser object.
(define (dom-selection-unwrap value)
  (if (dom-selection? value)
      (dom-selection-raw value)
      value))

;; selection-range-count : dom-selection? -> exact-nonnegative-integer?
;;   Read the number of ranges in the current selection.
(define (selection-range-count selection)
  (define raw (dom-selection-unwrap selection))
  (check-shared-dom-host-property 'selection-range-count raw "Selection" "rangeCount")
  (js-ref raw "rangeCount"))

;; selection-is-collapsed? : dom-selection? -> boolean?
;;   Report whether the current selection is collapsed.
(define (selection-is-collapsed? selection)
  (define raw (dom-selection-unwrap selection))
  (check-shared-dom-host-property 'selection-is-collapsed? raw "Selection" "isCollapsed")
  (js-ref raw "isCollapsed"))

;; selection-anchor-node : dom-selection? -> (or/c #f dom-node?)
;;   Read the anchor node for the current selection.
(define (selection-anchor-node selection)
  (define raw (dom-selection-unwrap selection))
  (check-shared-dom-host-nullable-property 'selection-anchor-node raw "Selection" "anchorNode")
  (dom-node-wrap (js-ref/extern raw "anchorNode")))

;; selection-focus-node : dom-selection? -> (or/c #f dom-node?)
;;   Read the focus node for the current selection.
(define (selection-focus-node selection)
  (define raw (dom-selection-unwrap selection))
  (check-shared-dom-host-nullable-property 'selection-focus-node raw "Selection" "focusNode")
  (dom-node-wrap (js-ref/extern raw "focusNode")))

;; selection-to-string : dom-selection? -> string?
;;   Convert the current selection to text.
(define (selection-to-string selection)
  (define raw (dom-selection-unwrap selection))
  (check-shared-dom-host-method 'selection-to-string raw "Selection" "toString")
  (js-send/value raw "toString" (vector)))

;; selection-remove-all-ranges! : dom-selection? -> void?
;;   Clear all ranges from the current selection.
(define (selection-remove-all-ranges! selection)
  (define raw (dom-selection-unwrap selection))
  (check-shared-dom-host-method 'selection-remove-all-ranges! raw "Selection" "removeAllRanges")
  (js-send raw "removeAllRanges" (vector))
  (void))

;; media-query-list : external/raw -> media-query-list?
;;   Wrap a browser MediaQueryList object.
(struct media-query-list (raw) #:transparent)

;; media-query-list/surface? : any/c -> boolean?
;;   Check whether value is a usable MediaQueryList wrapper.
(define (media-query-list/surface? value)
  (shared-dom-wrapper-with-host? value media-query-list? media-query-list-raw))

;; media-query-list-wrap : any/c -> any/c
;;   Wrap a raw browser MediaQueryList object, leaving wrapped values alone.
(define (media-query-list-wrap value)
  (shared-dom-wrap-value value media-query-list? media-query-list))

;; media-query-list-unwrap : any/c -> any/c
;;   Unwrap a media-query-list struct to its raw browser object.
(define (media-query-list-unwrap value)
  (if (media-query-list? value)
      (media-query-list-raw value)
      value))

;; media-query-list-media : media-query-list? -> string?
;;   Read the media query string.
(define (media-query-list-media media-query-list)
  (define raw (media-query-list-unwrap media-query-list))
  (check-shared-dom-host-property 'media-query-list-media raw "MediaQueryList" "media")
  (js-ref raw "media"))

;; media-query-list-matches? : media-query-list? -> boolean?
;;   Report whether the media query currently matches.
(define (media-query-list-matches? media-query-list)
  (define raw (media-query-list-unwrap media-query-list))
  (check-shared-dom-host-property 'media-query-list-matches? raw "MediaQueryList" "matches")
  (js-ref raw "matches"))

;; css-style-declaration : external/raw -> css-style-declaration?
;;   Wrap a browser CSSStyleDeclaration object.
(struct css-style-declaration (raw) #:transparent)

;; css-style-declaration/surface? : any/c -> boolean?
;;   Check whether value is a usable CSSStyleDeclaration wrapper.
(define (css-style-declaration/surface? value)
  (shared-dom-wrapper-with-host? value css-style-declaration? css-style-declaration-raw))

;; css-style-declaration-wrap : any/c -> any/c
;;   Wrap a raw browser CSSStyleDeclaration object, leaving wrapped values alone.
(define (css-style-declaration-wrap value)
  (shared-dom-wrap-value value css-style-declaration? css-style-declaration))

;; css-style-declaration-unwrap : any/c -> any/c
;;   Unwrap a css-style-declaration struct to its raw browser object.
(define (css-style-declaration-unwrap value)
  (if (css-style-declaration? value)
      (css-style-declaration-raw value)
      value))

;; css-style-declaration-css-text : css-style-declaration? -> string?
;;   Read the CSS text for a style declaration.
(define (css-style-declaration-css-text decl)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-property 'css-style-declaration-css-text raw "CSSStyleDeclaration" "cssText")
  (js-ref raw "cssText"))

;; css-style-declaration-set-css-text! : css-style-declaration? (or/c string? symbol?) -> void?
;;   Set the CSS text for a style declaration.
(define (css-style-declaration-set-css-text! decl text)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-property 'css-style-declaration-set-css-text! raw "CSSStyleDeclaration" "cssText")
  (js-set! raw
           "cssText"
           (if (symbol? text) (symbol->string text) text))
  (void))

;; css-style-declaration-length : css-style-declaration? -> exact-nonnegative-integer?
;;   Read the number of style properties.
(define (css-style-declaration-length decl)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-property 'css-style-declaration-length raw "CSSStyleDeclaration" "length")
  (js-ref raw "length"))

;; css-style-declaration-item : css-style-declaration? exact-nonnegative-integer? -> (or/c #f string?)
;;   Read the style property name at an index.
(define (css-style-declaration-item decl index)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-method 'css-style-declaration-item raw "CSSStyleDeclaration" "item")
  (js-send/value raw "item" (vector index)))

;; css-style-declaration-get-property-value : css-style-declaration? (or/c string? symbol?) -> string?
;;   Read the value of a style property.
(define (css-style-declaration-get-property-value decl name)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-method 'css-style-declaration-get-property-value
                                raw
                                "CSSStyleDeclaration"
                                "getPropertyValue")
  (js-send/value raw
                 "getPropertyValue"
                 (vector (if (symbol? name) (symbol->string name) name))))

;; css-style-declaration-set-property! : css-style-declaration? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Set the value of a style property.
(define (css-style-declaration-set-property! decl name value)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-method 'css-style-declaration-set-property!
                                raw
                                "CSSStyleDeclaration"
                                "setProperty")
  (js-send raw
           "setProperty"
           (vector (if (symbol? name) (symbol->string name) name)
                   (if (symbol? value) (symbol->string value) value)))
  (void))

;; css-style-declaration-remove-property! : css-style-declaration? (or/c string? symbol?) -> string?
;;   Remove a style property and return its previous value.
(define (css-style-declaration-remove-property! decl name)
  (define raw (css-style-declaration-unwrap decl))
  (check-shared-dom-host-method 'css-style-declaration-remove-property!
                                raw
                                "CSSStyleDeclaration"
                                "removeProperty")
  (js-send/value raw
                 "removeProperty"
                 (vector (if (symbol? name) (symbol->string name) name))))

;; media-stream : external/raw -> media-stream?
;;   Wrap a browser MediaStream object.
(struct media-stream (raw) #:transparent)

;; media-stream-wrapper? : any/c -> boolean?
;;   Report whether value is the internal MediaStream wrapper.
(define media-stream-wrapper? media-stream?)

;; media-stream/surface? : any/c -> boolean?
;;   Check whether value is a usable MediaStream wrapper.
(define (media-stream/surface? value)
  (and (media-stream-wrapper? value)
       (shared-dom-host-surface-present?
        (media-stream-raw value)
        '()
        '("getTracks"))))

;; media-stream-wrap : any/c -> any/c
;;   Wrap a raw browser MediaStream object, leaving wrapped values alone.
(define (media-stream-wrap value)
  (shared-dom-wrap-value value media-stream-wrapper? media-stream))

;; media-stream-unwrap : any/c -> any/c
;;   Unwrap a media-stream struct to its raw browser object.
(define (media-stream-unwrap value)
  (if (media-stream-wrapper? value)
      (media-stream-raw value)
      value))

;; media-source : external/raw -> media-source?
;;   Wrap a browser MediaSource object.
(struct media-source (raw) #:transparent)

;; media-source-wrapper? : any/c -> boolean?
;;   Report whether value is the internal MediaSource wrapper.
(define media-source-wrapper? media-source?)

;; media-source/surface? : any/c -> boolean?
;;   Check whether value is a usable MediaSource wrapper.
(define (media-source/surface? value)
  (and (media-source-wrapper? value)
       (shared-dom-host-surface-present?
        (media-source-raw value)
        '()
        '("addSourceBuffer" "endOfStream"))))

;; media-source-wrap : any/c -> any/c
;;   Wrap a raw browser MediaSource object, leaving wrapped values alone.
(define (media-source-wrap value)
  (shared-dom-wrap-value value media-source-wrapper? media-source))

;; media-source-unwrap : any/c -> any/c
;;   Unwrap a media-source struct to its raw browser object.
(define (media-source-unwrap value)
  (if (media-source-wrapper? value)
      (media-source-raw value)
      value))

;; media-keys-info : external/raw -> media-keys-info?
;;   Wrap a browser MediaKeys object.
(struct media-keys-info (raw) #:transparent)

;; media-keys-info-wrapper? : any/c -> boolean?
;;   Report whether value is the internal MediaKeys wrapper.
(define media-keys-info-wrapper? media-keys-info?)

;; media-keys-info/surface? : any/c -> boolean?
;;   Check whether value is a usable MediaKeys wrapper.
(define (media-keys-info/surface? value)
  (and (media-keys-info-wrapper? value)
       (shared-dom-host-surface-present?
        (media-keys-info-raw value)
        '()
        '("createSession" "setServerCertificate"))))

;; media-keys-info-wrap : any/c -> any/c
;;   Wrap a raw browser MediaKeys object, leaving wrapped values alone.
(define (media-keys-info-wrap value)
  (shared-dom-wrap-value value media-keys-info-wrapper? media-keys-info))

;; media-keys-info-unwrap : any/c -> any/c
;;   Unwrap a media-keys-info struct to its raw browser object.
(define (media-keys-info-unwrap value)
  (if (media-keys-info-wrapper? value)
      (media-keys-info-raw value)
      value))

;; audio-track : external/raw -> audio-track?
;;   Wrap a browser AudioTrack object.
(struct audio-track (raw) #:transparent)

;; audio-track-wrapper? : any/c -> boolean?
;;   Report whether value is the internal AudioTrack wrapper.
(define audio-track-wrapper? audio-track?)

;; audio-track/surface? : any/c -> boolean?
;;   Check whether value is a usable AudioTrack wrapper.
(define (audio-track/surface? value)
  (and (audio-track-wrapper? value)
       (shared-dom-host-surface-present?
        (audio-track-raw value)
        '("kind" "label" "language" "id" "enabled")
        '())))

;; audio-track-wrap : any/c -> any/c
;;   Wrap a raw browser AudioTrack object, leaving wrapped values alone.
(define (audio-track-wrap value)
  (shared-dom-wrap-value value audio-track-wrapper? audio-track))

;; audio-track-unwrap : any/c -> any/c
;;   Unwrap an audio-track struct to its raw browser object.
(define (audio-track-unwrap value)
  (if (audio-track-wrapper? value)
      (audio-track-raw value)
      value))

;; audio-track-kind : audio-track? -> string?
;;   Read the browser track kind.
(define (audio-track-kind track)
  (define raw (audio-track-unwrap track))
  (check-shared-dom-host-property 'audio-track-kind raw "AudioTrack" "kind")
  (js-ref raw "kind"))

;; audio-track-label : audio-track? -> string?
;;   Read the browser track label.
(define (audio-track-label track)
  (define raw (audio-track-unwrap track))
  (check-shared-dom-host-property 'audio-track-label raw "AudioTrack" "label")
  (js-ref raw "label"))

;; audio-track-language : audio-track? -> string?
;;   Read the browser track language.
(define (audio-track-language track)
  (define raw (audio-track-unwrap track))
  (check-shared-dom-host-property 'audio-track-language raw "AudioTrack" "language")
  (js-ref raw "language"))

;; audio-track-id : audio-track? -> string?
;;   Read the browser track id.
(define (audio-track-id track)
  (define raw (audio-track-unwrap track))
  (check-shared-dom-host-property 'audio-track-id raw "AudioTrack" "id")
  (js-ref raw "id"))

;; audio-track-enabled? : audio-track? -> boolean?
;;   Read whether the audio track is enabled.
(define (audio-track-enabled? track)
  (define raw (audio-track-unwrap track))
  (check-shared-dom-host-property 'audio-track-enabled? raw "AudioTrack" "enabled")
  (js-ref raw "enabled"))

;; audio-track-set-enabled! : audio-track? boolean? -> void?
;;   Enable or disable the audio track.
(define (audio-track-set-enabled! track enabled?)
  (define raw (audio-track-unwrap track))
  (check-shared-dom-host-property 'audio-track-set-enabled! raw "AudioTrack" "enabled")
  (js-set! raw "enabled" enabled?)
  (void))

;; text-track : external/raw -> text-track?
;;   Wrap a browser TextTrack object.
(struct text-track (raw) #:transparent)

;; text-track-wrapper? : any/c -> boolean?
;;   Report whether value is the internal TextTrack wrapper.
(define text-track-wrapper? text-track?)

;; text-track/surface? : any/c -> boolean?
;;   Check whether value is a usable TextTrack wrapper.
(define (text-track/surface? value)
  (and (text-track-wrapper? value)
       (shared-dom-host-surface-present?
        (text-track-raw value)
        '("kind" "label" "language" "id" "mode")
        '())))

;; text-track-wrap : any/c -> any/c
;;   Wrap a raw browser TextTrack object, leaving wrapped values alone.
(define (text-track-wrap value)
  (shared-dom-wrap-value value text-track-wrapper? text-track))

;; text-track-unwrap : any/c -> any/c
;;   Unwrap a text-track struct to its raw browser object.
(define (text-track-unwrap value)
  (if (text-track-wrapper? value)
      (text-track-raw value)
      value))

;; text-track-kind : text-track? -> string?
;;   Read the browser track kind.
(define (text-track-kind track)
  (define raw (text-track-unwrap track))
  (check-shared-dom-host-property 'text-track-kind raw "TextTrack" "kind")
  (js-ref raw "kind"))

;; text-track-label : text-track? -> string?
;;   Read the browser track label.
(define (text-track-label track)
  (define raw (text-track-unwrap track))
  (check-shared-dom-host-property 'text-track-label raw "TextTrack" "label")
  (js-ref raw "label"))

;; text-track-language : text-track? -> string?
;;   Read the browser track language.
(define (text-track-language track)
  (define raw (text-track-unwrap track))
  (check-shared-dom-host-property 'text-track-language raw "TextTrack" "language")
  (js-ref raw "language"))

;; text-track-id : text-track? -> string?
;;   Read the browser track id.
(define (text-track-id track)
  (define raw (text-track-unwrap track))
  (check-shared-dom-host-property 'text-track-id raw "TextTrack" "id")
  (js-ref raw "id"))

;; text-track-mode : text-track? -> string?
;;   Read the browser track mode.
(define (text-track-mode track)
  (define raw (text-track-unwrap track))
  (check-shared-dom-host-property 'text-track-mode raw "TextTrack" "mode")
  (js-ref raw "mode"))

;; text-track-set-mode! : text-track? (or/c string? symbol?) -> void?
;;   Set the browser track mode.
(define (text-track-set-mode! track mode)
  (define raw (text-track-unwrap track))
  (check-shared-dom-host-property 'text-track-set-mode! raw "TextTrack" "mode")
  (js-set! raw
           "mode"
           (if (symbol? mode) (symbol->string mode) mode))
  (void))

;; video-track : external/raw -> video-track?
;;   Wrap a browser VideoTrack object.
(struct video-track (raw) #:transparent)

;; video-track-wrapper? : any/c -> boolean?
;;   Report whether value is the internal VideoTrack wrapper.
(define video-track-wrapper? video-track?)

;; video-track/surface? : any/c -> boolean?
;;   Check whether value is a usable VideoTrack wrapper.
(define (video-track/surface? value)
  (and (video-track-wrapper? value)
       (shared-dom-host-surface-present?
        (video-track-raw value)
        '("kind" "label" "language" "id" "selected")
        '())))

;; video-track-wrap : any/c -> any/c
;;   Wrap a raw browser VideoTrack object, leaving wrapped values alone.
(define (video-track-wrap value)
  (shared-dom-wrap-value value video-track-wrapper? video-track))

;; video-track-unwrap : any/c -> any/c
;;   Unwrap a video-track struct to its raw browser object.
(define (video-track-unwrap value)
  (if (video-track-wrapper? value)
      (video-track-raw value)
      value))

;; video-track-kind : video-track? -> string?
;;   Read the browser track kind.
(define (video-track-kind track)
  (define raw (video-track-unwrap track))
  (check-shared-dom-host-property 'video-track-kind raw "VideoTrack" "kind")
  (js-ref raw "kind"))

;; video-track-label : video-track? -> string?
;;   Read the browser track label.
(define (video-track-label track)
  (define raw (video-track-unwrap track))
  (check-shared-dom-host-property 'video-track-label raw "VideoTrack" "label")
  (js-ref raw "label"))

;; video-track-language : video-track? -> string?
;;   Read the browser track language.
(define (video-track-language track)
  (define raw (video-track-unwrap track))
  (check-shared-dom-host-property 'video-track-language raw "VideoTrack" "language")
  (js-ref raw "language"))

;; video-track-id : video-track? -> string?
;;   Read the browser track id.
(define (video-track-id track)
  (define raw (video-track-unwrap track))
  (check-shared-dom-host-property 'video-track-id raw "VideoTrack" "id")
  (js-ref raw "id"))

;; video-track-selected? : video-track? -> boolean?
;;   Read whether the video track is selected.
(define (video-track-selected? track)
  (define raw (video-track-unwrap track))
  (check-shared-dom-host-property 'video-track-selected? raw "VideoTrack" "selected")
  (js-ref raw "selected"))

;; media-error-info : external/raw -> media-error-info?
;;   Wrap a browser MediaError object.
(struct media-error-info (raw) #:transparent)

;; media-error-info-wrapper? : any/c -> boolean?
;;   Report whether value is the internal MediaError wrapper.
(define media-error-info-wrapper? media-error-info?)

;; media-error-info/surface? : any/c -> boolean?
;;   Check whether value is a usable MediaError wrapper.
(define (media-error-info/surface? value)
  (and (media-error-info-wrapper? value)
       (shared-dom-host-surface-present?
        (media-error-info-raw value)
        '("code" "message")
        '())))

;; media-error-info-wrap : any/c -> any/c
;;   Wrap a raw browser MediaError object, leaving wrapped values alone.
(define (media-error-info-wrap value)
  (shared-dom-wrap-value value media-error-info-wrapper? media-error-info))

;; media-error-info-unwrap : any/c -> any/c
;;   Unwrap a media-error-info struct to its raw browser object.
(define (media-error-info-unwrap value)
  (if (media-error-info-wrapper? value)
      (media-error-info-raw value)
      value))

;; media-error-info-code : media-error-info? -> exact-nonnegative-integer?
;;   Read the browser media error code.
(define (media-error-info-code media-error)
  (define raw (media-error-info-unwrap media-error))
  (check-shared-dom-host-property 'media-error-info-code raw "MediaError" "code")
  (js-ref raw "code"))

;; media-error-info-message : media-error-info? -> string?
;;   Read the browser media error message.
(define (media-error-info-message media-error)
  (define raw (media-error-info-unwrap media-error))
  (check-shared-dom-host-property 'media-error-info-message raw "MediaError" "message")
  (js-ref raw "message"))

;; audio-track-list : external/raw -> audio-track-list?
;;   Wrap a browser AudioTrackList object.
(struct audio-track-list (raw) #:transparent)

;; audio-track-list-wrapper? : any/c -> boolean?
;;   Report whether value is the internal AudioTrackList wrapper.
(define audio-track-list-wrapper? audio-track-list?)

;; audio-track-list/surface? : any/c -> boolean?
;;   Check whether value is a usable AudioTrackList wrapper.
(define (audio-track-list/surface? value)
  (and (audio-track-list-wrapper? value)
       (shared-dom-host-surface-present?
        (audio-track-list-raw value)
        '("length")
        '("item"))))

;; audio-track-list-wrap : any/c -> any/c
;;   Wrap a raw browser AudioTrackList object, leaving wrapped values alone.
(define (audio-track-list-wrap value)
  (shared-dom-wrap-value value audio-track-list-wrapper? audio-track-list))

;; audio-track-list-unwrap : any/c -> any/c
;;   Unwrap an audio-track-list struct to its raw browser object.
(define (audio-track-list-unwrap value)
  (if (audio-track-list-wrapper? value)
      (audio-track-list-raw value)
      value))

;; audio-track-list-length : audio-track-list? -> exact-nonnegative-integer?
;;   Read the number of audio tracks.
(define (audio-track-list-length track-list)
  (define raw (audio-track-list-unwrap track-list))
  (check-shared-dom-host-property 'audio-track-list-length raw "AudioTrackList" "length")
  (js-ref raw "length"))

;; audio-track-list-item : audio-track-list? exact-nonnegative-integer? -> (or/c #f audio-track?)
;;   Read an audio track by index.
(define (audio-track-list-item track-list index)
  (define raw (audio-track-list-unwrap track-list))
  (check-shared-dom-host-method 'audio-track-list-item raw "AudioTrackList" "item")
  (audio-track-wrap (js-send/extern/nullish raw "item" (vector index))))

;; text-track-list : external/raw -> text-track-list?
;;   Wrap a browser TextTrackList object.
(struct text-track-list (raw) #:transparent)

;; text-track-list-wrapper? : any/c -> boolean?
;;   Report whether value is the internal TextTrackList wrapper.
(define text-track-list-wrapper? text-track-list?)

;; text-track-list/surface? : any/c -> boolean?
;;   Check whether value is a usable TextTrackList wrapper.
(define (text-track-list/surface? value)
  (and (text-track-list-wrapper? value)
       (shared-dom-host-surface-present?
        (text-track-list-raw value)
        '("length")
        '("item"))))

;; text-track-list-wrap : any/c -> any/c
;;   Wrap a raw browser TextTrackList object, leaving wrapped values alone.
(define (text-track-list-wrap value)
  (shared-dom-wrap-value value text-track-list-wrapper? text-track-list))

;; text-track-list-unwrap : any/c -> any/c
;;   Unwrap a text-track-list struct to its raw browser object.
(define (text-track-list-unwrap value)
  (if (text-track-list-wrapper? value)
      (text-track-list-raw value)
      value))

;; text-track-list-length : text-track-list? -> exact-nonnegative-integer?
;;   Read the number of text tracks.
(define (text-track-list-length track-list)
  (define raw (text-track-list-unwrap track-list))
  (check-shared-dom-host-property 'text-track-list-length raw "TextTrackList" "length")
  (js-ref raw "length"))

;; text-track-list-item : text-track-list? exact-nonnegative-integer? -> (or/c #f text-track?)
;;   Read a text track by index.
(define (text-track-list-item track-list index)
  (define raw (text-track-list-unwrap track-list))
  (check-shared-dom-host-method 'text-track-list-item raw "TextTrackList" "item")
  (text-track-wrap (js-send/extern/nullish raw "item" (vector index))))

;; video-track-list : external/raw -> video-track-list?
;;   Wrap a browser VideoTrackList object.
(struct video-track-list (raw) #:transparent)

;; video-track-list-wrapper? : any/c -> boolean?
;;   Report whether value is the internal VideoTrackList wrapper.
(define video-track-list-wrapper? video-track-list?)

;; video-track-list/surface? : any/c -> boolean?
;;   Check whether value is a usable VideoTrackList wrapper.
(define (video-track-list/surface? value)
  (and (video-track-list-wrapper? value)
       (shared-dom-host-surface-present?
        (video-track-list-raw value)
        '("length")
        '("item"))))

;; video-track-list-wrap : any/c -> any/c
;;   Wrap a raw browser VideoTrackList object, leaving wrapped values alone.
(define (video-track-list-wrap value)
  (shared-dom-wrap-value value video-track-list-wrapper? video-track-list))

;; video-track-list-unwrap : any/c -> any/c
;;   Unwrap a video-track-list struct to its raw browser object.
(define (video-track-list-unwrap value)
  (if (video-track-list-wrapper? value)
      (video-track-list-raw value)
      value))

;; video-track-list-length : video-track-list? -> exact-nonnegative-integer?
;;   Read the number of video tracks.
(define (video-track-list-length track-list)
  (define raw (video-track-list-unwrap track-list))
  (check-shared-dom-host-property 'video-track-list-length raw "VideoTrackList" "length")
  (js-ref raw "length"))

;; video-track-list-item : video-track-list? exact-nonnegative-integer? -> (or/c #f video-track?)
;;   Read a video track by index.
(define (video-track-list-item track-list index)
  (define raw (video-track-list-unwrap track-list))
  (check-shared-dom-host-method 'video-track-list-item raw "VideoTrackList" "item")
  (video-track-wrap (js-send/extern/nullish raw "item" (vector index))))

;; time-ranges : external/raw -> time-ranges?
;;   Wrap a browser TimeRanges object.
(struct time-ranges (raw) #:transparent)

;; time-ranges-wrapper? : any/c -> boolean?
;;   Report whether value is the internal TimeRanges wrapper.
(define time-ranges-wrapper? time-ranges?)

;; time-ranges/surface? : any/c -> boolean?
;;   Check whether value is a usable TimeRanges wrapper.
(define (time-ranges/surface? value)
  (and (time-ranges-wrapper? value)
       (shared-dom-host-surface-present?
        (time-ranges-raw value)
        '("length")
        '("start" "end"))))

;; time-ranges-wrap : any/c -> any/c
;;   Wrap a raw browser TimeRanges object, leaving wrapped values alone.
(define (time-ranges-wrap value)
  (shared-dom-wrap-value value time-ranges-wrapper? time-ranges))

;; time-ranges-unwrap : any/c -> any/c
;;   Unwrap a time-ranges struct to its raw browser object.
(define (time-ranges-unwrap value)
  (if (time-ranges-wrapper? value)
      (time-ranges-raw value)
      value))

;; time-ranges-length : time-ranges? -> exact-nonnegative-integer?
;;   Read the number of time ranges.
(define (time-ranges-length time-ranges)
  (define raw (time-ranges-unwrap time-ranges))
  (check-shared-dom-host-property 'time-ranges-length raw "TimeRanges" "length")
  (js-ref raw "length"))

;; time-ranges-start : time-ranges? exact-nonnegative-integer? -> real?
;;   Read the start time for a range.
(define (time-ranges-start time-ranges index)
  (define raw (time-ranges-unwrap time-ranges))
  (check-shared-dom-host-method 'time-ranges-start raw "TimeRanges" "start")
  (js-send/value raw "start" (vector index)))

;; time-ranges-end : time-ranges? exact-nonnegative-integer? -> real?
;;   Read the end time for a range.
(define (time-ranges-end time-ranges index)
  (define raw (time-ranges-unwrap time-ranges))
  (check-shared-dom-host-method 'time-ranges-end raw "TimeRanges" "end")
  (js-send/value raw "end" (vector index)))
