#lang racket/base

(require browser/media
         js/array
         (only-in webracket/primitives
                  external?)
         webracket/unsafe/canvas)

(provide (except-out (struct-out html-canvas-element) html-canvas-element?)
         (except-out (struct-out canvas-rendering-context-2d) canvas-rendering-context-2d?)
         (except-out (struct-out image-data) image-data?)
         (except-out (struct-out canvas-gradient) canvas-gradient?)
         (except-out (struct-out canvas-pattern) canvas-pattern?)
         (except-out (struct-out text-metrics) text-metrics?)
         (except-out (struct-out dom-matrix) dom-matrix?)
         (except-out (struct-out offscreen-canvas) offscreen-canvas?)
         (rename-out [html-canvas-element/surface? html-canvas-element?]
                     [canvas-rendering-context-2d/surface? canvas-rendering-context-2d?]
                     [image-data/surface? image-data?]
                     [canvas-gradient/surface? canvas-gradient?]
                     [canvas-pattern/surface? canvas-pattern?]
                     [text-metrics/surface? text-metrics?]
                     [dom-matrix/surface? dom-matrix?]
                     [offscreen-canvas/surface? offscreen-canvas?])
         canvas-wrap
         canvas-unwrap
         canvas-2d-context-wrap
         canvas-2d-context-unwrap
         canvas-image-data-wrap
         canvas-image-data-unwrap
         canvas-gradient-wrap
         canvas-gradient-unwrap
         canvas-pattern-wrap
         canvas-pattern-unwrap
         canvas-text-metrics-wrap
         canvas-text-metrics-unwrap
         canvas-dom-matrix-wrap
         canvas-dom-matrix-unwrap
         offscreen-canvas-wrap
         offscreen-canvas-unwrap
         canvas-capture-stream
         canvas-get-context
         canvas-width
         canvas-set-width!
         canvas-height
         canvas-set-height!
         canvas-to-data-url
         canvas-to-blob
         canvas-transfer-control-to-offscreen
         canvas-2d-canvas
         canvas-2d-direction
         canvas-2d-set-direction!
         canvas-2d-fill-rect
         canvas-2d-stroke-rect
         canvas-2d-begin-path
         canvas-2d-close-path
         canvas-2d-move-to
         canvas-2d-line-to
         canvas-2d-arc
         canvas-2d-clear-rect
         canvas-2d-fill
         canvas-2d-stroke
         canvas-2d-save
         canvas-2d-restore
         canvas-2d-translate
         canvas-2d-scale
         canvas-2d-rotate
         canvas-2d-fill-text
         canvas-2d-stroke-text
         canvas-2d-measure-text
         canvas-image-data-width
         canvas-image-data-height
         canvas-image-data-data
         canvas-text-metrics-width
         canvas-dom-matrix-a
         canvas-dom-matrix-b
         canvas-dom-matrix-c
         canvas-dom-matrix-d
         canvas-dom-matrix-e
         canvas-dom-matrix-f
         canvas-gradient-add-color-stop!
         canvas-pattern-set-transform!
         canvas-2d-filter
         canvas-2d-set-filter!
         canvas-2d-font
         canvas-2d-set-font!
         canvas-2d-global-alpha
         canvas-2d-set-global-alpha!
         canvas-2d-global-composite-operation
         canvas-2d-set-global-composite-operation!
         canvas-2d-image-smoothing-enabled?
         canvas-2d-set-image-smoothing-enabled!
         canvas-2d-image-smoothing-quality
         canvas-2d-set-image-smoothing-quality!
         canvas-2d-line-cap
         canvas-2d-set-line-cap!
         canvas-2d-line-dash-offset
         canvas-2d-set-line-dash-offset!
         canvas-2d-line-join
         canvas-2d-set-line-join!
         canvas-2d-line-width
         canvas-2d-set-line-width!
         canvas-2d-miter-limit
         canvas-2d-set-miter-limit!
         canvas-2d-shadow-blur
         canvas-2d-set-shadow-blur!
         canvas-2d-shadow-color
         canvas-2d-set-shadow-color!
         canvas-2d-shadow-offset-x
         canvas-2d-set-shadow-offset-x!
         canvas-2d-shadow-offset-y
         canvas-2d-set-shadow-offset-y!
         canvas-2d-text-align
         canvas-2d-set-text-align!
         canvas-2d-text-baseline
         canvas-2d-set-text-baseline!
         canvas-2d-text-rendering
         canvas-2d-set-text-rendering!
         canvas-2d-font-kerning
         canvas-2d-set-font-kerning!
         canvas-2d-font-stretch
         canvas-2d-set-font-stretch!
         canvas-2d-font-variant-caps
         canvas-2d-set-font-variant-caps!
         canvas-2d-font-variant-ligatures
         canvas-2d-set-font-variant-ligatures!
         canvas-2d-font-variant-numeric
         canvas-2d-set-font-variant-numeric!
         canvas-2d-letter-spacing
         canvas-2d-set-letter-spacing!
         canvas-2d-word-spacing
         canvas-2d-set-word-spacing!
         canvas-2d-arc-to
         canvas-2d-bezier-curve-to
         canvas-2d-clip
         canvas-2d-create-image-data
         canvas-2d-create-image-data-from
         canvas-2d-create-pattern
         canvas-2d-create-conic-gradient
         canvas-2d-draw-focus-if-needed!
         canvas-2d-draw-focus-if-needed-path!
         canvas-2d-draw-image
         canvas-2d-draw-image-5
         canvas-2d-draw-image-9
         canvas-2d-ellipse
         canvas-2d-get-image-data
         canvas-2d-get-line-dash
         canvas-2d-get-transform
         canvas-2d-is-point-in-path
         canvas-2d-is-point-in-stroke
         canvas-2d-put-image-data
         canvas-2d-quadratic-curve-to
         canvas-2d-rect
         canvas-2d-reset
         canvas-2d-reset-transform
         canvas-2d-round-rect
         canvas-2d-set-line-dash
         canvas-2d-set-transform!
         canvas-2d-set-transform-matrix!
         canvas-2d-transform
         canvas-2d-create-linear-gradient
         canvas-2d-create-radial-gradient
         canvas-2d-fill-style
         canvas-2d-set-fill-style!
         canvas-2d-stroke-style
         canvas-2d-set-stroke-style!)

;; This is the canonical module version of the old `include-lib canvas`
;; safe wrapper. Raw bindings remain in `webracket/unsafe/canvas`.

;;;
;;; Canvas wrappers
;;;

(struct html-canvas-element (raw) #:transparent)
(struct canvas-rendering-context-2d (raw) #:transparent)
(struct image-data (raw) #:transparent)
(struct canvas-gradient (raw) #:transparent)
(struct canvas-pattern (raw) #:transparent)
(struct text-metrics (raw) #:transparent)
(struct dom-matrix (raw) #:transparent)
(struct offscreen-canvas (raw) #:transparent)

;; canvas-nullish-value? : any/c -> boolean?
;;   Report whether value is Racket #f or a JavaScript nullish host value.
(define (canvas-nullish-value? value)
  (or (not value)
      (and (external? value)
           (js-nullish? value))))

;; canvas-wrap-value : any/c (any/c -> boolean?) (any/c -> any/c) -> any/c
;;   Preserve wrapped and nullish values, otherwise build a host wrapper.
(define (canvas-wrap-value value wrapped? make-wrapper)
  (cond
    [(wrapped? value) value]
    [(canvas-nullish-value? value) #f]
    [else (make-wrapper value)]))

;; canvas-wrap : any/c -> (or/c #f html-canvas-element?)
;;   Wrap a browser canvas value, preserving nullish values as #f.
(define (canvas-wrap value)
  (canvas-wrap-value value html-canvas-element? html-canvas-element))

;; canvas-unwrap : any/c -> any/c
;;   Unwrap a browser canvas value.
(define (canvas-unwrap value)
  (if (html-canvas-element? value)
      (html-canvas-element-raw value)
      value))

;; canvas-2d-context-wrap : any/c -> (or/c #f canvas-rendering-context-2d?)
;;   Wrap a browser 2D context value, preserving nullish values as #f.
(define (canvas-2d-context-wrap value)
  (canvas-wrap-value value canvas-rendering-context-2d? canvas-rendering-context-2d))

;; canvas-2d-context-unwrap : any/c -> any/c
;;   Unwrap a browser 2D context value.
(define (canvas-2d-context-unwrap value)
  (if (canvas-rendering-context-2d? value)
      (canvas-rendering-context-2d-raw value)
      value))

;; canvas-i32->boolean : integer? -> boolean?
;;   Convert a browser i32 flag to a boolean.
(define (canvas-i32->boolean v)
  (not (zero? v)))

;; canvas-stringish->string : symbol? any/c -> string?
;;   Normalize a browser string argument.
(define (canvas-stringish->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else (raise-argument-error who "(or/c string? symbol?)" value)]))

;; canvas-resolve-optional : any/c -> any/c
;;   Treat #f as omitted for optional browser arguments.
(define (canvas-resolve-optional value)
  (if (eq? value #f)
      (void)
      value))

;; canvas-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable browser method.
(define (canvas-host-method-present? raw method-name)
  (and (external? raw)
       (not (js-nullish? raw))
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; canvas-host-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish browser property.
(define (canvas-host-property-present? raw property-name)
  (and (external? raw)
       (not (js-nullish? raw))
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; canvas-host-properties-present? : external/raw (listof string?) -> boolean?
;;   Report whether raw exposes all named non-nullish browser properties.
(define (canvas-host-properties-present? raw property-names)
  (for/and ([property-name (in-list property-names)])
    (canvas-host-property-present? raw property-name)))

;; canvas-host-methods-present? : external/raw (listof string?) -> boolean?
;;   Report whether raw exposes all named callable browser methods.
(define (canvas-host-methods-present? raw method-names)
  (for/and ([method-name (in-list method-names)])
    (canvas-host-method-present? raw method-name)))

;; canvas-host-surface-present? : external/raw (listof string?) (listof string?) -> boolean?
;;   Report whether raw exposes the requested browser property and method surface.
(define (canvas-host-surface-present? raw property-names method-names)
  (and (canvas-host-properties-present? raw property-names)
       (canvas-host-methods-present? raw method-names)))

;; html-canvas-element/surface? : any/c -> boolean?
;;   Check whether value is a usable HTMLCanvasElement wrapper.
(define (html-canvas-element/surface? value)
  (and (html-canvas-element? value)
       (canvas-host-surface-present?
        (html-canvas-element-raw value)
        '("width" "height")
        '("getContext" "toDataURL" "toBlob"))))

;; canvas-rendering-context-2d/surface? : any/c -> boolean?
;;   Check whether value is a usable CanvasRenderingContext2D wrapper.
(define (canvas-rendering-context-2d/surface? value)
  (and (canvas-rendering-context-2d? value)
       (canvas-host-surface-present?
        (canvas-rendering-context-2d-raw value)
        '("canvas" "direction" "fillStyle" "strokeStyle" "font" "globalAlpha")
        '("fillRect" "strokeRect" "beginPath" "closePath" "moveTo" "lineTo"
          "arc" "clearRect" "fill" "stroke" "save" "restore" "translate"
          "scale" "rotate" "fillText" "strokeText" "measureText"))))

;; image-data/surface? : any/c -> boolean?
;;   Check whether value is a usable ImageData wrapper.
(define (image-data/surface? value)
  (and (image-data? value)
       (canvas-host-surface-present?
        (image-data-raw value)
        '("width" "height" "data")
        '())))

;; canvas-gradient/surface? : any/c -> boolean?
;;   Check whether value is a usable CanvasGradient wrapper.
(define (canvas-gradient/surface? value)
  (and (canvas-gradient? value)
       (canvas-host-surface-present?
        (canvas-gradient-raw value)
        '()
        '("addColorStop"))))

;; canvas-pattern/surface? : any/c -> boolean?
;;   Check whether value is a usable CanvasPattern wrapper.
(define (canvas-pattern/surface? value)
  (and (canvas-pattern? value)
       (canvas-host-surface-present?
        (canvas-pattern-raw value)
        '()
        '("setTransform"))))

;; text-metrics/surface? : any/c -> boolean?
;;   Check whether value is a usable TextMetrics wrapper.
(define (text-metrics/surface? value)
  (and (text-metrics? value)
       (canvas-host-surface-present?
        (text-metrics-raw value)
        '("width")
        '())))

;; dom-matrix/surface? : any/c -> boolean?
;;   Check whether value is a usable DOMMatrix wrapper.
(define (dom-matrix/surface? value)
  (and (dom-matrix? value)
       (canvas-host-surface-present?
        (dom-matrix-raw value)
        '("a" "b" "c" "d" "e" "f")
        '())))

;; offscreen-canvas/surface? : any/c -> boolean?
;;   Check whether value is a usable OffscreenCanvas wrapper.
(define (offscreen-canvas/surface? value)
  (and (offscreen-canvas? value)
       (canvas-host-surface-present?
        (offscreen-canvas-raw value)
        '("width" "height")
        '())))

;; check-canvas-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required canvas host method is available.
(define (check-canvas-host-method who raw receiver-name method-name)
  (unless (canvas-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " not available in this environment"))))

;; canvas-result-wrap/checked : symbol? string? string? any/c (any/c -> any/c) (any/c -> boolean?) boolean? -> any/c
;;   Wrap and validate a browser object returned by a canvas API.
(define (canvas-result-wrap/checked who display-name expected raw wrap surface? nullable?)
  (define wrapped (wrap raw))
  (cond
    [(and nullable? (not wrapped)) #f]
    [(and wrapped (surface? wrapped)) wrapped]
    [else
     (raise-arguments-error who
                            (string-append display-name
                                           " result must be "
                                           expected))]))

;; canvas-array-like-result? : any/c -> boolean?
;;   Report whether raw is a non-nullish host value with an array-like length.
(define (canvas-array-like-result? raw)
  (and (canvas-raw-host-value? raw)
       (exact-nonnegative-integer? (js-ref raw "length"))))

;; canvas-check-array-like-result : symbol? string? any/c -> external/raw
;;   Validate that a canvas API returned an array-like raw value.
(define (canvas-check-array-like-result who display-name raw)
  (unless (canvas-array-like-result? raw)
    (raise-arguments-error who
                           (string-append display-name
                                          " result must be array-like")))
  raw)

;; canvas-paint-style-wrap-result : symbol? string? any/c -> any/c
;;   Wrap and validate a paint style returned by a canvas API.
(define (canvas-paint-style-wrap-result who display-name raw)
  (define value (canvas-paint-style-wrap raw))
  (cond
    [(and (external? raw)
          (not (js-nullish? raw))
          (eq? value raw))
     (raise-arguments-error who
                            (string-append display-name
                                           " result must be a string, CanvasGradient-like, or CanvasPattern-like"))]
    [else value]))

;; canvas-optional->extern : any/c -> any/c
;;   Treat #f as JavaScript undefined for optional extern arguments.
;;   The unsafe FFI binding expects a JS-side omitted value here; Racket
;;   void is a distinct WebRacket value and should not be passed instead.
(define (canvas-optional->extern value)
  (if (eq? value #f)
      (js-undefined)
      value))

;; canvas-boolean->i32 : boolean? -> exact-integer?
;;   Convert a Racket boolean to a browser i32 flag.
(define (canvas-boolean->i32 value)
  (if value 1 0))

;; canvas-real->flonum : symbol? any/c -> flonum?
;;   Normalize a browser real argument to a flonum for FFI calls.
;;   Public canvas wrappers accept ordinary Racket reals, while the unsafe
;;   FFI `f64` path expects a WebRacket flonum value.
(define (canvas-real->flonum who value)
  (cond
    [(flonum? value) value]
    [(real? value)   (exact->inexact value)]
    [else (raise-argument-error who "real?" value)]))

;; canvas-optional-real->flonum : symbol? any/c -> any/c
;;   Normalize supplied numeric arguments while preserving omitted values.
(define (canvas-optional-real->flonum who value)
  (cond
    [(real? value) (canvas-real->flonum who value)]
    [else          (canvas-resolve-optional value)]))

;; canvas-real-sequence->array : symbol? any/c -> external?
;;   Normalize numeric sequence elements and preserve existing browser arrays.
(define (canvas-real-sequence->array who items)
  (cond
    [(or (external? items) (array? items)) (array-unwrap items)]
    [else
     (array-unwrap
      (sequence->array
       (map (lambda (value)
              (if (real? value)
                  (canvas-real->flonum who value)
                  value))
            (if (vector? items) (vector->list items) items))))]))

;; canvas-raw-host-value? : any/c -> boolean?
;;   Report whether value is a non-nullish browser host value.
(define (canvas-raw-host-value? value)
  (and (external? value)
       (not (js-nullish? value))))

;; canvas-wrapper-raw/checked : symbol? string? any/c any/c -> external/raw
;;   Validate a wrapper raw field before passing it to browser host calls.
(define (canvas-wrapper-raw/checked who expected value raw)
  (unless (canvas-raw-host-value? raw)
    (raise-argument-error who expected value))
  raw)

;; canvas-source-unwrap : any/c -> any/c
;;   Unwrap browser canvas-like sources when available.
(define (canvas-source-unwrap value)
  (cond
    [(html-canvas-element? value) (html-canvas-element-raw value)]
    [(image-data? value) (image-data-raw value)]
    [(offscreen-canvas? value) (offscreen-canvas-raw value)]
    [else value]))

;; canvas-source-unwrap/checked : symbol? any/c -> any/c
;;   Validate and unwrap browser canvas-like sources when available.
(define (canvas-source-unwrap/checked who value)
  (cond
    [(html-canvas-element? value)
     (canvas-wrapper-raw/checked who
                                 "html-canvas-element with non-nullish raw value"
                                 value
                                 (html-canvas-element-raw value))]
    [(image-data? value)
     (canvas-wrapper-raw/checked who
                                 "image-data with non-nullish raw value"
                                 value
                                 (image-data-raw value))]
    [(offscreen-canvas? value)
     (canvas-wrapper-raw/checked who
                                 "offscreen-canvas with non-nullish raw value"
                                 value
                                 (offscreen-canvas-raw value))]
    [else value]))

;; canvas-paint-style-unwrap : any/c -> any/c
;;   Unwrap wrapper values used for paint styles.
(define (canvas-paint-style-unwrap value)
  (cond
    [(canvas-gradient? value) (canvas-gradient-raw value)]
    [(canvas-pattern? value) (canvas-pattern-raw value)]
    [else value]))

;; canvas-paint-style-unwrap/checked : symbol? any/c -> any/c
;;   Validate and unwrap wrapper values used for paint styles.
(define (canvas-paint-style-unwrap/checked who value)
  (cond
    [(canvas-gradient? value)
     (canvas-wrapper-raw/checked who
                                 "canvas-gradient with non-nullish raw value"
                                 value
                                 (canvas-gradient-raw value))]
    [(canvas-pattern? value)
     (canvas-wrapper-raw/checked who
                                 "canvas-pattern with non-nullish raw value"
                                 value
                                 (canvas-pattern-raw value))]
    [else value]))

;; canvas-paint-style-wrap : any/c -> any/c
;;   Wrap browser paint-style values when possible.
(define (canvas-paint-style-wrap value)
  (cond
    [(canvas-nullish-value? value) #f]
    [(and (external? value)
          (canvas-host-method-present? value "addColorStop"))
     (canvas-gradient-wrap value)]
    [(and (external? value)
          (canvas-host-method-present? value "setTransform"))
     (canvas-pattern-wrap value)]
    [else value]))

;; canvas-fill-rule->js : any/c -> any/c
;;   Normalize optional fill rule values.
(define (canvas-fill-rule->js value)
  (cond
    [(eq? value #f) (void)]
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else (raise-argument-error 'canvas-fill-rule->js "(or/c string? symbol? #f)" value)]))

;; canvas-matrix->raw : any/c -> any/c
;;   Unwrap a DOMMatrix wrapper when available.
(define (canvas-matrix->raw value)
  (if (dom-matrix? value)
      (dom-matrix-raw value)
      value))

;; canvas-matrix->raw/checked : symbol? any/c -> any/c
;;   Validate and unwrap a DOMMatrix wrapper when available.
(define (canvas-matrix->raw/checked who value)
  (if (dom-matrix? value)
      (canvas-wrapper-raw/checked who
                                  "dom-matrix with non-nullish raw value"
                                  value
                                  (dom-matrix-raw value))
      value))

;; canvas-image-data-wrap : any/c -> (or/c #f image-data?)
;;   Wrap a browser ImageData value, preserving nullish values as #f.
(define (canvas-image-data-wrap value)
  (canvas-wrap-value value image-data? image-data))

;; canvas-image-data-unwrap : any/c -> any/c
;;   Unwrap a browser ImageData value.
(define (canvas-image-data-unwrap value)
  (if (image-data? value)
      (image-data-raw value)
      value))

;; canvas-image-data-unwrap/checked : symbol? any/c -> any/c
;;   Validate and unwrap a browser ImageData value when available.
(define (canvas-image-data-unwrap/checked who value)
  (if (image-data? value)
      (canvas-wrapper-raw/checked who
                                  "image-data with non-nullish raw value"
                                  value
                                  (image-data-raw value))
      value))

;; canvas-gradient-wrap : any/c -> (or/c #f canvas-gradient?)
;;   Wrap a browser gradient value, preserving nullish values as #f.
(define (canvas-gradient-wrap value)
  (canvas-wrap-value value canvas-gradient? canvas-gradient))

;; canvas-gradient-unwrap : any/c -> any/c
;;   Unwrap a browser gradient value.
(define (canvas-gradient-unwrap value)
  (if (canvas-gradient? value)
      (canvas-gradient-raw value)
      value))

;; canvas-pattern-wrap : any/c -> (or/c #f canvas-pattern?)
;;   Wrap a browser pattern value, preserving nullish values as #f.
(define (canvas-pattern-wrap value)
  (canvas-wrap-value value canvas-pattern? canvas-pattern))

;; canvas-pattern-unwrap : any/c -> any/c
;;   Unwrap a browser pattern value.
(define (canvas-pattern-unwrap value)
  (if (canvas-pattern? value)
      (canvas-pattern-raw value)
      value))

;; canvas-text-metrics-wrap : any/c -> (or/c #f text-metrics?)
;;   Wrap a browser TextMetrics value, preserving nullish values as #f.
(define (canvas-text-metrics-wrap value)
  (canvas-wrap-value value text-metrics? text-metrics))

;; canvas-text-metrics-unwrap : any/c -> any/c
;;   Unwrap a browser TextMetrics value.
(define (canvas-text-metrics-unwrap value)
  (if (text-metrics? value)
      (text-metrics-raw value)
      value))

;; canvas-dom-matrix-wrap : any/c -> (or/c #f dom-matrix?)
;;   Wrap a browser DOMMatrix value, preserving nullish values as #f.
(define (canvas-dom-matrix-wrap value)
  (canvas-wrap-value value dom-matrix? dom-matrix))

;; canvas-dom-matrix-unwrap : any/c -> any/c
;;   Unwrap a browser DOMMatrix value.
(define (canvas-dom-matrix-unwrap value)
  (if (dom-matrix? value)
      (dom-matrix-raw value)
      value))

;; canvas-js-array->bytes : any/c -> bytes?
;;   Convert a browser byte array to a Racket bytes value.
(define (canvas-js-array->bytes arr)
  (array->bytes arr))

;; offscreen-canvas-wrap : any/c -> (or/c #f offscreen-canvas?)
;;   Wrap a browser OffscreenCanvas value, preserving nullish values as #f.
(define (offscreen-canvas-wrap value)
  (canvas-wrap-value value offscreen-canvas? offscreen-canvas))

;; offscreen-canvas-unwrap : any/c -> any/c
;;   Unwrap a browser OffscreenCanvas value.
(define (offscreen-canvas-unwrap value)
  (if (offscreen-canvas? value)
      (offscreen-canvas-raw value)
      value))

;; canvas-capture-stream : (or/c html-canvas-element? external?) [real? #f] -> media-stream?
;;   Capture the canvas stream.
(define (canvas-capture-stream canvas [frame-rate #f])
  (media-stream-wrap (js-canvas-capture-stream (canvas-unwrap canvas)
                                               (canvas-optional-real->flonum 'canvas-capture-stream frame-rate))))

;; canvas-get-context : (or/c html-canvas-element? external?) (or/c string? symbol?) [any/c #f]
;;   -> (or/c #f canvas-rendering-context-2d?)
;;   Read a drawing context from a canvas.
(define (canvas-get-context canvas context-id [options #f])
  (define context-id* (canvas-stringish->string 'canvas-get-context context-id))
  (define ctx (js-canvas-get-context (canvas-unwrap canvas)
                                     context-id*
                                     (canvas-optional->extern options)))
  (canvas-result-wrap/checked 'canvas-get-context
                              "canvas.getContext"
                              "CanvasRenderingContext2D-like"
                              ctx
                              canvas-2d-context-wrap
                              canvas-rendering-context-2d/surface?
                              #t))

;; canvas-width : (or/c html-canvas-element? external?) -> exact-nonnegative-integer?
;;   Read the canvas width.
(define (canvas-width canvas)
  (js-canvas-width (canvas-unwrap canvas)))

;; canvas-set-width! : (or/c html-canvas-element? external?) exact-nonnegative-integer? -> void?
;;   Set the canvas width.
(define (canvas-set-width! canvas width)
  (js-set-canvas-width! (canvas-unwrap canvas) width)
  (void))

;; canvas-height : (or/c html-canvas-element? external?) -> exact-nonnegative-integer?
;;   Read the canvas height.
(define (canvas-height canvas)
  (js-canvas-height (canvas-unwrap canvas)))

;; canvas-set-height! : (or/c html-canvas-element? external?) exact-nonnegative-integer? -> void?
;;   Set the canvas height.
(define (canvas-set-height! canvas height)
  (js-set-canvas-height! (canvas-unwrap canvas) height)
  (void))

;; canvas-to-data-url : (or/c html-canvas-element? external?) (or/c string? symbol?) [any/c #f] -> string?
;;   Encode a canvas as a data URL.
(define (canvas-to-data-url canvas [type "image/png"] [quality #f])
  (define type* (canvas-stringish->string 'canvas-to-data-url type))
  (js-canvas-to-data-url (canvas-unwrap canvas) type* (canvas-optional-real->flonum 'canvas-to-data-url quality)))

;; canvas-to-blob : (or/c html-canvas-element? external?) external? (or/c string? symbol?) [any/c #f] -> void?
;;   Encode a canvas into a Blob callback.
(define (canvas-to-blob canvas callback [type "image/png"] [quality #f])
  (define type* (canvas-stringish->string 'canvas-to-blob type))
  (js-canvas-to-blob (canvas-unwrap canvas) callback type* (canvas-optional-real->flonum 'canvas-to-blob quality))
  (void))

;; canvas-transfer-control-to-offscreen : (or/c html-canvas-element? external?) -> external/raw
;;   Transfer control to an OffscreenCanvas.
(define (canvas-transfer-control-to-offscreen canvas)
  (canvas-result-wrap/checked
   'canvas-transfer-control-to-offscreen
   "canvas.transferControlToOffscreen"
   "OffscreenCanvas-like"
   (js-canvas-transfer-control-to-offscreen (canvas-unwrap canvas))
   offscreen-canvas-wrap
   offscreen-canvas/surface?
   #f))

;; canvas-2d-canvas : (or/c canvas-rendering-context-2d? external?) -> html-canvas-element?
;;   Read the backing canvas from a 2D context.
(define (canvas-2d-canvas ctx)
  (canvas-result-wrap/checked 'canvas-2d-canvas
                              "CanvasRenderingContext2D.canvas"
                              "HTMLCanvasElement-like"
                              (js-canvas2d-canvas (canvas-2d-context-unwrap ctx))
                              canvas-wrap
                              html-canvas-element/surface?
                              #f))

;; canvas-2d-direction : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the canvas direction.
(define (canvas-2d-direction ctx)
  (js-canvas2d-direction (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-direction! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the canvas direction.
(define (canvas-2d-set-direction! ctx direction)
  (js-set-canvas2d-direction! (canvas-2d-context-unwrap ctx)
                              (canvas-stringish->string 'canvas-2d-set-direction!
                                                        direction))
  (void))

;; canvas-2d-fill-rect : (or/c canvas-rendering-context-2d? external?) real? real? real? real? -> void?
;;   Fill a rectangle.
(define (canvas-2d-fill-rect ctx x y w h)
  (js-canvas2d-fill-rect (canvas-2d-context-unwrap ctx)
                         (canvas-real->flonum 'canvas-2d-fill-rect x)
                         (canvas-real->flonum 'canvas-2d-fill-rect y)
                         (canvas-real->flonum 'canvas-2d-fill-rect w)
                         (canvas-real->flonum 'canvas-2d-fill-rect h))
  (void))

;; canvas-2d-stroke-rect : (or/c canvas-rendering-context-2d? external?) real? real? real? real? -> void?
;;   Stroke a rectangle.
(define (canvas-2d-stroke-rect ctx x y w h)
  (js-canvas2d-stroke-rect (canvas-2d-context-unwrap ctx)
                           (canvas-real->flonum 'canvas-2d-stroke-rect x)
                           (canvas-real->flonum 'canvas-2d-stroke-rect y)
                           (canvas-real->flonum 'canvas-2d-stroke-rect w)
                           (canvas-real->flonum 'canvas-2d-stroke-rect h))
  (void))

;; canvas-2d-begin-path : (or/c canvas-rendering-context-2d? external?) -> void?
;;   Begin a new path.
(define (canvas-2d-begin-path ctx)
  (js-canvas2d-begin-path (canvas-2d-context-unwrap ctx))
  (void))

;; canvas-2d-close-path : (or/c canvas-rendering-context-2d? external?) -> void?
;;   Close the current path.
(define (canvas-2d-close-path ctx)
  (js-canvas2d-close-path (canvas-2d-context-unwrap ctx))
  (void))

;; canvas-2d-move-to : (or/c canvas-rendering-context-2d? external?) real? real? -> void?
;;   Move the current path cursor.
(define (canvas-2d-move-to ctx x y)
  (js-canvas2d-move-to (canvas-2d-context-unwrap ctx)
                       (canvas-real->flonum 'canvas-2d-move-to x)
                       (canvas-real->flonum 'canvas-2d-move-to y))
  (void))

;; canvas-2d-line-to : (or/c canvas-rendering-context-2d? external?) real? real? -> void?
;;   Add a line segment to the path.
(define (canvas-2d-line-to ctx x y)
  (js-canvas2d-line-to (canvas-2d-context-unwrap ctx)
                       (canvas-real->flonum 'canvas-2d-line-to x)
                       (canvas-real->flonum 'canvas-2d-line-to y))
  (void))

;; canvas-2d-arc : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? -> void?
;;   Add an arc to the path.
(define (canvas-2d-arc ctx x y radius start-angle end-angle)
  (js-canvas2d-arc (canvas-2d-context-unwrap ctx)
                   (canvas-real->flonum 'canvas-2d-arc x)
                   (canvas-real->flonum 'canvas-2d-arc y)
                   (canvas-real->flonum 'canvas-2d-arc radius)
                   (canvas-real->flonum 'canvas-2d-arc start-angle)
                   (canvas-real->flonum 'canvas-2d-arc end-angle)
                   0)
  (void))

;; canvas-2d-clear-rect : (or/c canvas-rendering-context-2d? external?) real? real? real? real? -> void?
;;   Clear a rectangle.
(define (canvas-2d-clear-rect ctx x y w h)
  (js-canvas2d-clear-rect (canvas-2d-context-unwrap ctx)
                          (canvas-real->flonum 'canvas-2d-clear-rect x)
                          (canvas-real->flonum 'canvas-2d-clear-rect y)
                          (canvas-real->flonum 'canvas-2d-clear-rect w)
                          (canvas-real->flonum 'canvas-2d-clear-rect h))
  (void))

;; canvas-2d-fill : (or/c canvas-rendering-context-2d? external?) [any/c #f] [any/c #f] -> void?
;;   Fill the current path.
(define (canvas-2d-fill ctx [path #f] [fill-rule #f])
  (js-canvas2d-fill (canvas-2d-context-unwrap ctx)
                    (canvas-resolve-optional path)
                    (canvas-fill-rule->js fill-rule))
  (void))

;; canvas-2d-stroke : (or/c canvas-rendering-context-2d? external?) [any/c #f] -> void?
;;   Stroke the current path.
(define (canvas-2d-stroke ctx [path #f])
  (js-canvas2d-stroke (canvas-2d-context-unwrap ctx) (canvas-resolve-optional path))
  (void))

;; canvas-2d-save : (or/c canvas-rendering-context-2d? external?) -> void?
;;   Save drawing state.
(define (canvas-2d-save ctx)
  (js-canvas2d-save (canvas-2d-context-unwrap ctx))
  (void))

;; canvas-2d-restore : (or/c canvas-rendering-context-2d? external?) -> void?
;;   Restore drawing state.
(define (canvas-2d-restore ctx)
  (js-canvas2d-restore (canvas-2d-context-unwrap ctx))
  (void))

;; canvas-2d-translate : (or/c canvas-rendering-context-2d? external?) real? real? -> void?
;;   Translate the context.
(define (canvas-2d-translate ctx x y)
  (js-canvas2d-translate (canvas-2d-context-unwrap ctx)
                         (canvas-real->flonum 'canvas-2d-translate x)
                         (canvas-real->flonum 'canvas-2d-translate y))
  (void))

;; canvas-2d-scale : (or/c canvas-rendering-context-2d? external?) real? real? -> void?
;;   Scale the context.
(define (canvas-2d-scale ctx x y)
  (js-canvas2d-scale (canvas-2d-context-unwrap ctx)
                     (canvas-real->flonum 'canvas-2d-scale x)
                     (canvas-real->flonum 'canvas-2d-scale y))
  (void))

;; canvas-2d-rotate : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Rotate the context.
(define (canvas-2d-rotate ctx angle)
  (js-canvas2d-rotate (canvas-2d-context-unwrap ctx)
                      (canvas-real->flonum 'canvas-2d-rotate angle))
  (void))

;; canvas-2d-fill-text : (or/c canvas-rendering-context-2d? external?) string? real? real? [any/c #f] -> void?
;;   Draw filled text.
(define (canvas-2d-fill-text ctx text x y [max-width #f])
  (js-canvas2d-fill-text (canvas-2d-context-unwrap ctx)
                         text
                         (canvas-real->flonum 'canvas-2d-fill-text x)
                         (canvas-real->flonum 'canvas-2d-fill-text y)
                         (canvas-optional-real->flonum 'canvas-2d-fill-text max-width))
  (void))

;; canvas-2d-stroke-text : (or/c canvas-rendering-context-2d? external?) string? real? real? [any/c #f] -> void?
;;   Draw stroked text.
(define (canvas-2d-stroke-text ctx text x y [max-width #f])
  (js-canvas2d-stroke-text (canvas-2d-context-unwrap ctx)
                           text
                           (canvas-real->flonum 'canvas-2d-stroke-text x)
                           (canvas-real->flonum 'canvas-2d-stroke-text y)
                           (canvas-optional-real->flonum 'canvas-2d-stroke-text max-width))
  (void))

;; canvas-2d-measure-text : (or/c canvas-rendering-context-2d? external?) string? -> external/raw
;;   Measure text width and metrics.
(define (canvas-2d-measure-text ctx text)
  (canvas-result-wrap/checked 'canvas-2d-measure-text
                              "CanvasRenderingContext2D.measureText"
                              "TextMetrics-like"
                              (js-canvas2d-measure-text (canvas-2d-context-unwrap ctx) text)
                              canvas-text-metrics-wrap
                              text-metrics/surface?
                              #f))

;; canvas-image-data-width : image-data? -> exact-nonnegative-integer?
;;   Read the width of an image buffer.
(define (canvas-image-data-width data)
  (js-canvas-image-data-width (image-data-raw data)))

;; canvas-image-data-height : image-data? -> exact-nonnegative-integer?
;;   Read the height of an image buffer.
(define (canvas-image-data-height data)
  (js-canvas-image-data-height (image-data-raw data)))

;; canvas-image-data-data : image-data? -> bytes?
;;   Read the pixel bytes of an image buffer.
(define (canvas-image-data-data data)
  (canvas-js-array->bytes
   (canvas-check-array-like-result
    'canvas-image-data-data
    "ImageData.data"
    (js-canvas-image-data-data (image-data-raw data)))))

;; canvas-text-metrics-width : text-metrics? -> real?
;;   Read the measured text width.
(define (canvas-text-metrics-width metrics)
  (js-canvas-text-metrics-width (text-metrics-raw metrics)))

;; canvas-dom-matrix-a : dom-matrix? -> real?
;;   Read the A component of a transform matrix.
(define (canvas-dom-matrix-a matrix)
  (js-canvas-dom-matrix-a (dom-matrix-raw matrix)))

;; canvas-dom-matrix-b : dom-matrix? -> real?
;;   Read the B component of a transform matrix.
(define (canvas-dom-matrix-b matrix)
  (js-canvas-dom-matrix-b (dom-matrix-raw matrix)))

;; canvas-dom-matrix-c : dom-matrix? -> real?
;;   Read the C component of a transform matrix.
(define (canvas-dom-matrix-c matrix)
  (js-canvas-dom-matrix-c (dom-matrix-raw matrix)))

;; canvas-dom-matrix-d : dom-matrix? -> real?
;;   Read the D component of a transform matrix.
(define (canvas-dom-matrix-d matrix)
  (js-canvas-dom-matrix-d (dom-matrix-raw matrix)))

;; canvas-dom-matrix-e : dom-matrix? -> real?
;;   Read the E component of a transform matrix.
(define (canvas-dom-matrix-e matrix)
  (js-canvas-dom-matrix-e (dom-matrix-raw matrix)))

;; canvas-dom-matrix-f : dom-matrix? -> real?
;;   Read the F component of a transform matrix.
(define (canvas-dom-matrix-f matrix)
  (js-canvas-dom-matrix-f (dom-matrix-raw matrix)))

;; canvas-gradient-add-color-stop! : (or/c canvas-gradient? external?) real? (or/c string? symbol?) -> void?
;;   Add a color stop to a gradient.
(define (canvas-gradient-add-color-stop! gradient offset color)
  (define raw (canvas-gradient-unwrap gradient))
  (check-canvas-host-method 'canvas-gradient-add-color-stop! raw "CanvasGradient" "addColorStop")
  (js-send/value raw "addColorStop"
                 (vector (canvas-real->flonum 'canvas-gradient-add-color-stop! offset)
                         (canvas-stringish->string 'canvas-gradient-add-color-stop! color)))
  (void))

;; canvas-pattern-set-transform! : (or/c canvas-pattern? external?) (or/c dom-matrix? external?) -> void?
;;   Set a pattern transform.
(define (canvas-pattern-set-transform! pattern matrix)
  (define raw (canvas-pattern-unwrap pattern))
  (check-canvas-host-method 'canvas-pattern-set-transform! raw "CanvasPattern" "setTransform")
  (js-send/value raw "setTransform"
                 (vector (canvas-matrix->raw/checked 'canvas-pattern-set-transform! matrix)))
  (void))

;; canvas-2d-filter : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the CSS filter value.
(define (canvas-2d-filter ctx)
  (js-canvas2d-filter (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-filter! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the CSS filter value.
(define (canvas-2d-set-filter! ctx filter)
  (js-set-canvas2d-filter! (canvas-2d-context-unwrap ctx)
                           (canvas-stringish->string 'canvas-2d-set-filter! filter))
  (void))

;; canvas-2d-font : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the CSS font value.
(define (canvas-2d-font ctx)
  (js-canvas2d-font (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-font! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the CSS font value.
(define (canvas-2d-set-font! ctx font)
  (js-set-canvas2d-font! (canvas-2d-context-unwrap ctx)
                         (canvas-stringish->string 'canvas-2d-set-font! font))
  (void))

;; canvas-2d-global-alpha : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the global alpha.
(define (canvas-2d-global-alpha ctx)
  (js-canvas2d-global-alpha (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-global-alpha! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the global alpha.
(define (canvas-2d-set-global-alpha! ctx alpha)
  (js-set-canvas2d-global-alpha! (canvas-2d-context-unwrap ctx)
                                 (canvas-real->flonum 'canvas-2d-set-global-alpha! alpha))
  (void))

;; canvas-2d-global-composite-operation : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the global composite operation.
(define (canvas-2d-global-composite-operation ctx)
  (js-canvas2d-global-composite-operation (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-global-composite-operation! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the global composite operation.
(define (canvas-2d-set-global-composite-operation! ctx operation)
  (js-set-canvas2d-global-composite-operation!
   (canvas-2d-context-unwrap ctx)
   (canvas-stringish->string 'canvas-2d-set-global-composite-operation! operation))
  (void))

;; canvas-2d-image-smoothing-enabled? : (or/c canvas-rendering-context-2d? external?) -> boolean?
;;   Report whether image smoothing is enabled.
(define (canvas-2d-image-smoothing-enabled? ctx)
  (canvas-i32->boolean (js-canvas2d-image-smoothing-enabled (canvas-2d-context-unwrap ctx))))

;; canvas-2d-set-image-smoothing-enabled! : (or/c canvas-rendering-context-2d? external?) boolean? -> void?
;;   Set image smoothing on or off.
(define (canvas-2d-set-image-smoothing-enabled! ctx enabled)
  (js-set-canvas2d-image-smoothing-enabled! (canvas-2d-context-unwrap ctx)
                                            (canvas-boolean->i32 enabled))
  (void))

;; canvas-2d-image-smoothing-quality : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the image smoothing quality.
(define (canvas-2d-image-smoothing-quality ctx)
  (js-canvas2d-image-smoothing-quality (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-image-smoothing-quality! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the image smoothing quality.
(define (canvas-2d-set-image-smoothing-quality! ctx quality)
  (js-set-canvas2d-image-smoothing-quality! (canvas-2d-context-unwrap ctx)
                                            (canvas-stringish->string 'canvas-2d-set-image-smoothing-quality! quality))
  (void))

;; canvas-2d-line-cap : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the line cap.
(define (canvas-2d-line-cap ctx)
  (js-canvas2d-line-cap (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-line-cap! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the line cap.
(define (canvas-2d-set-line-cap! ctx value)
  (js-set-canvas2d-line-cap! (canvas-2d-context-unwrap ctx)
                             (canvas-stringish->string 'canvas-2d-set-line-cap! value))
  (void))

;; canvas-2d-line-dash-offset : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the line dash offset.
(define (canvas-2d-line-dash-offset ctx)
  (js-canvas2d-line-dash-offset (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-line-dash-offset! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the line dash offset.
(define (canvas-2d-set-line-dash-offset! ctx offset)
  (js-set-canvas2d-line-dash-offset! (canvas-2d-context-unwrap ctx)
                                     (canvas-real->flonum 'canvas-2d-set-line-dash-offset! offset))
  (void))

;; canvas-2d-line-join : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the line join.
(define (canvas-2d-line-join ctx)
  (js-canvas2d-line-join (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-line-join! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the line join.
(define (canvas-2d-set-line-join! ctx value)
  (js-set-canvas2d-line-join! (canvas-2d-context-unwrap ctx)
                              (canvas-stringish->string 'canvas-2d-set-line-join! value))
  (void))

;; canvas-2d-line-width : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the line width.
(define (canvas-2d-line-width ctx)
  (js-canvas2d-line-width (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-line-width! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the line width.
(define (canvas-2d-set-line-width! ctx width)
  (js-set-canvas2d-line-width! (canvas-2d-context-unwrap ctx)
                               (canvas-real->flonum 'canvas-2d-set-line-width! width))
  (void))

;; canvas-2d-miter-limit : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the miter limit.
(define (canvas-2d-miter-limit ctx)
  (js-canvas2d-miter-limit (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-miter-limit! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the miter limit.
(define (canvas-2d-set-miter-limit! ctx limit)
  (js-set-canvas2d-miter-limit! (canvas-2d-context-unwrap ctx)
                                (canvas-real->flonum 'canvas-2d-set-miter-limit! limit))
  (void))

;; canvas-2d-shadow-blur : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the shadow blur.
(define (canvas-2d-shadow-blur ctx)
  (js-canvas2d-shadow-blur (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-shadow-blur! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the shadow blur.
(define (canvas-2d-set-shadow-blur! ctx blur)
  (js-set-canvas2d-shadow-blur! (canvas-2d-context-unwrap ctx)
                                (canvas-real->flonum 'canvas-2d-set-shadow-blur! blur))
  (void))

;; canvas-2d-shadow-color : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the shadow color.
(define (canvas-2d-shadow-color ctx)
  (js-canvas2d-shadow-color (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-shadow-color! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the shadow color.
(define (canvas-2d-set-shadow-color! ctx color)
  (js-set-canvas2d-shadow-color! (canvas-2d-context-unwrap ctx)
                                 (canvas-stringish->string 'canvas-2d-set-shadow-color! color))
  (void))

;; canvas-2d-shadow-offset-x : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the horizontal shadow offset.
(define (canvas-2d-shadow-offset-x ctx)
  (js-canvas2d-shadow-offset-x (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-shadow-offset-x! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the horizontal shadow offset.
(define (canvas-2d-set-shadow-offset-x! ctx dx)
  (js-set-canvas2d-shadow-offset-x! (canvas-2d-context-unwrap ctx)
                                    (canvas-real->flonum 'canvas-2d-set-shadow-offset-x! dx))
  (void))

;; canvas-2d-shadow-offset-y : (or/c canvas-rendering-context-2d? external?) -> real?
;;   Read the vertical shadow offset.
(define (canvas-2d-shadow-offset-y ctx)
  (js-canvas2d-shadow-offset-y (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-shadow-offset-y! : (or/c canvas-rendering-context-2d? external?) real? -> void?
;;   Set the vertical shadow offset.
(define (canvas-2d-set-shadow-offset-y! ctx dy)
  (js-set-canvas2d-shadow-offset-y! (canvas-2d-context-unwrap ctx)
                                    (canvas-real->flonum 'canvas-2d-set-shadow-offset-y! dy))
  (void))

;; canvas-2d-text-align : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the text alignment.
(define (canvas-2d-text-align ctx)
  (js-canvas2d-text-align (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-text-align! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the text alignment.
(define (canvas-2d-set-text-align! ctx alignment)
  (js-set-canvas2d-text-align! (canvas-2d-context-unwrap ctx)
                               (canvas-stringish->string 'canvas-2d-set-text-align! alignment))
  (void))

;; canvas-2d-text-baseline : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the text baseline.
(define (canvas-2d-text-baseline ctx)
  (js-canvas2d-text-baseline (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-text-baseline! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the text baseline.
(define (canvas-2d-set-text-baseline! ctx baseline)
  (js-set-canvas2d-text-baseline! (canvas-2d-context-unwrap ctx)
                                  (canvas-stringish->string 'canvas-2d-set-text-baseline! baseline))
  (void))

;; canvas-2d-text-rendering : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the text rendering hint.
(define (canvas-2d-text-rendering ctx)
  (js-canvas2d-text-rendering (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-text-rendering! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the text rendering hint.
(define (canvas-2d-set-text-rendering! ctx mode)
  (js-set-canvas2d-text-rendering! (canvas-2d-context-unwrap ctx)
                                   (canvas-stringish->string 'canvas-2d-set-text-rendering! mode))
  (void))

;; canvas-2d-font-kerning : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the font kerning mode.
(define (canvas-2d-font-kerning ctx)
  (js-canvas2d-font-kerning (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-font-kerning! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the font kerning mode.
(define (canvas-2d-set-font-kerning! ctx mode)
  (js-set-canvas2d-font-kerning! (canvas-2d-context-unwrap ctx)
                                 (canvas-stringish->string 'canvas-2d-set-font-kerning! mode))
  (void))

;; canvas-2d-font-stretch : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the font stretch.
(define (canvas-2d-font-stretch ctx)
  (js-canvas2d-font-stretch (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-font-stretch! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the font stretch.
(define (canvas-2d-set-font-stretch! ctx stretch)
  (js-set-canvas2d-font-stretch! (canvas-2d-context-unwrap ctx)
                                 (canvas-stringish->string 'canvas-2d-set-font-stretch! stretch))
  (void))

;; canvas-2d-font-variant-caps : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the font variant caps.
(define (canvas-2d-font-variant-caps ctx)
  (js-canvas2d-font-variant-caps (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-font-variant-caps! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the font variant caps.
(define (canvas-2d-set-font-variant-caps! ctx variant)
  (js-set-canvas2d-font-variant-caps! (canvas-2d-context-unwrap ctx)
                                      (canvas-stringish->string 'canvas-2d-set-font-variant-caps! variant))
  (void))

;; canvas-2d-font-variant-ligatures : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the font variant ligatures.
(define (canvas-2d-font-variant-ligatures ctx)
  (js-canvas2d-font-variant-ligatures (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-font-variant-ligatures! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the font variant ligatures.
(define (canvas-2d-set-font-variant-ligatures! ctx variant)
  (js-set-canvas2d-font-variant-ligatures! (canvas-2d-context-unwrap ctx)
                                           (canvas-stringish->string 'canvas-2d-set-font-variant-ligatures! variant))
  (void))

;; canvas-2d-font-variant-numeric : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the font variant numeric value.
(define (canvas-2d-font-variant-numeric ctx)
  (js-canvas2d-font-variant-numeric (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-font-variant-numeric! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the font variant numeric value.
(define (canvas-2d-set-font-variant-numeric! ctx variant)
  (js-set-canvas2d-font-variant-numeric! (canvas-2d-context-unwrap ctx)
                                         (canvas-stringish->string 'canvas-2d-set-font-variant-numeric! variant))
  (void))

;; canvas-2d-letter-spacing : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the letter spacing.
(define (canvas-2d-letter-spacing ctx)
  (js-canvas2d-letter-spacing (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-letter-spacing! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the letter spacing.
(define (canvas-2d-set-letter-spacing! ctx spacing)
  (js-set-canvas2d-letter-spacing! (canvas-2d-context-unwrap ctx)
                                   (canvas-stringish->string 'canvas-2d-set-letter-spacing! spacing))
  (void))

;; canvas-2d-word-spacing : (or/c canvas-rendering-context-2d? external?) -> string?
;;   Read the word spacing.
(define (canvas-2d-word-spacing ctx)
  (js-canvas2d-word-spacing (canvas-2d-context-unwrap ctx)))

;; canvas-2d-set-word-spacing! : (or/c canvas-rendering-context-2d? external?) (or/c string? symbol?) -> void?
;;   Set the word spacing.
(define (canvas-2d-set-word-spacing! ctx spacing)
  (js-set-canvas2d-word-spacing! (canvas-2d-context-unwrap ctx)
                                 (canvas-stringish->string 'canvas-2d-set-word-spacing! spacing))
  (void))

;; canvas-2d-arc-to : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? -> void?
;;   Add an arc-to segment to the current path.
(define (canvas-2d-arc-to ctx x1 y1 x2 y2 radius)
  (js-canvas2d-arc-to (canvas-2d-context-unwrap ctx)
                      (canvas-real->flonum 'canvas-2d-arc-to x1)
                      (canvas-real->flonum 'canvas-2d-arc-to y1)
                      (canvas-real->flonum 'canvas-2d-arc-to x2)
                      (canvas-real->flonum 'canvas-2d-arc-to y2)
                      (canvas-real->flonum 'canvas-2d-arc-to radius))
  (void))

;; canvas-2d-bezier-curve-to : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? real? -> void?
;;   Add a cubic Bezier curve to the current path.
(define (canvas-2d-bezier-curve-to ctx cp1x cp1y cp2x cp2y x y)
  (js-canvas2d-bezier-curve-to (canvas-2d-context-unwrap ctx)
                               (canvas-real->flonum 'canvas-2d-bezier-curve-to cp1x)
                               (canvas-real->flonum 'canvas-2d-bezier-curve-to cp1y)
                               (canvas-real->flonum 'canvas-2d-bezier-curve-to cp2x)
                               (canvas-real->flonum 'canvas-2d-bezier-curve-to cp2y)
                               (canvas-real->flonum 'canvas-2d-bezier-curve-to x)
                               (canvas-real->flonum 'canvas-2d-bezier-curve-to y))
  (void))

;; canvas-2d-clip : (or/c canvas-rendering-context-2d? external?) [any/c #f] [any/c #f] -> void?
;;   Clip drawing to the current path or the provided path.
(define (canvas-2d-clip ctx [path #f] [fill-rule #f])
  (js-canvas2d-clip (canvas-2d-context-unwrap ctx)
                    (canvas-resolve-optional path)
                    (canvas-fill-rule->js fill-rule))
  (void))

;; canvas-2d-create-image-data : (or/c canvas-rendering-context-2d? external?) exact-nonnegative-integer? exact-nonnegative-integer? -> image-data?
;;   Create a new blank image buffer.
(define (canvas-2d-create-image-data ctx width height)
  (canvas-result-wrap/checked
   'canvas-2d-create-image-data
   "CanvasRenderingContext2D.createImageData"
   "ImageData-like"
   (js-canvas2d-create-image-data (canvas-2d-context-unwrap ctx)
                                  (canvas-real->flonum 'canvas-2d-create-image-data width)
                                  (canvas-real->flonum 'canvas-2d-create-image-data height))
   canvas-image-data-wrap
   image-data/surface?
   #f))

;; canvas-2d-create-image-data-from : (or/c canvas-rendering-context-2d? external?) (or/c image-data? external?) -> image-data?
;;   Copy an image buffer.
(define (canvas-2d-create-image-data-from ctx data)
  (canvas-result-wrap/checked
   'canvas-2d-create-image-data-from
   "CanvasRenderingContext2D.createImageData"
   "ImageData-like"
   (js-canvas2d-create-image-data-from (canvas-2d-context-unwrap ctx)
                                        (canvas-image-data-unwrap/checked
                                         'canvas-2d-create-image-data-from
                                         data))
   canvas-image-data-wrap
   image-data/surface?
   #f))

;; canvas-2d-create-pattern : (or/c canvas-rendering-context-2d? external?) any/c (or/c string? symbol?) -> (or/c #f canvas-pattern?)
;;   Create a pattern from an image or canvas source.
(define (canvas-2d-create-pattern ctx source repetition)
  (define pattern (js-canvas2d-create-pattern (canvas-2d-context-unwrap ctx)
                                              (canvas-source-unwrap/checked
                                               'canvas-2d-create-pattern
                                               source)
                                              (canvas-stringish->string 'canvas-2d-create-pattern repetition)))
  (canvas-result-wrap/checked 'canvas-2d-create-pattern
                              "CanvasRenderingContext2D.createPattern"
                              "CanvasPattern-like"
                              pattern
                              canvas-pattern-wrap
                              canvas-pattern/surface?
                              #t))

;; canvas-2d-create-conic-gradient : (or/c canvas-rendering-context-2d? external?) real? real? real? -> canvas-gradient?
;;   Create a conic gradient.
(define (canvas-2d-create-conic-gradient ctx angle x y)
  (canvas-result-wrap/checked
   'canvas-2d-create-conic-gradient
   "CanvasRenderingContext2D.createConicGradient"
   "CanvasGradient-like"
   (js-canvas2d-create-conic-gradient (canvas-2d-context-unwrap ctx)
                                      (canvas-real->flonum 'canvas-2d-create-conic-gradient angle)
                                      (canvas-real->flonum 'canvas-2d-create-conic-gradient x)
                                      (canvas-real->flonum 'canvas-2d-create-conic-gradient y))
   canvas-gradient-wrap
   canvas-gradient/surface?
   #f))

;; canvas-2d-draw-focus-if-needed! : (or/c canvas-rendering-context-2d? external?) any/c -> void?
;;   Draw a focus ring when needed.
(define (canvas-2d-draw-focus-if-needed! ctx element)
  (js-canvas2d-draw-focus-if-needed! (canvas-2d-context-unwrap ctx) element)
  (void))

;; canvas-2d-draw-focus-if-needed-path! : (or/c canvas-rendering-context-2d? external?) any/c any/c -> void?
;;   Draw a focus ring for the given path and element.
(define (canvas-2d-draw-focus-if-needed-path! ctx path element)
  (js-canvas2d-draw-focus-if-needed-path! (canvas-2d-context-unwrap ctx) path element)
  (void))

;; canvas-2d-draw-image : (or/c canvas-rendering-context-2d? external?) any/c real? real? -> void?
;;   Draw an image source at a point.
(define (canvas-2d-draw-image ctx source dx dy)
  (js-canvas2d-draw-image (canvas-2d-context-unwrap ctx)
                          (canvas-source-unwrap/checked 'canvas-2d-draw-image source)
                          (canvas-real->flonum 'canvas-2d-draw-image dx)
                          (canvas-real->flonum 'canvas-2d-draw-image dy))
  (void))

;; canvas-2d-draw-image-5 : (or/c canvas-rendering-context-2d? external?) any/c real? real? real? real? -> void?
;;   Draw an image source with destination sizing.
(define (canvas-2d-draw-image-5 ctx source dx dy dwidth dheight)
  (js-canvas2d-draw-image-5 (canvas-2d-context-unwrap ctx)
                            (canvas-source-unwrap/checked 'canvas-2d-draw-image-5 source)
                            (canvas-real->flonum 'canvas-2d-draw-image-5 dx)
                            (canvas-real->flonum 'canvas-2d-draw-image-5 dy)
                            (canvas-real->flonum 'canvas-2d-draw-image-5 dwidth)
                            (canvas-real->flonum 'canvas-2d-draw-image-5 dheight))
  (void))

;; canvas-2d-draw-image-9 : (or/c canvas-rendering-context-2d? external?) any/c real? real? real? real? real? real? real? real? -> void?
;;   Draw an image source with source and destination rectangles.
(define (canvas-2d-draw-image-9 ctx source sx sy sw sh dx dy dw dh)
  (js-canvas2d-draw-image-9 (canvas-2d-context-unwrap ctx)
                            (canvas-source-unwrap/checked 'canvas-2d-draw-image-9 source)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 sx)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 sy)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 sw)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 sh)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 dx)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 dy)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 dw)
                            (canvas-real->flonum 'canvas-2d-draw-image-9 dh))
  (void))

;; canvas-2d-ellipse : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? real? real? -> void?
;;   Add an ellipse to the current path.
(define (canvas-2d-ellipse ctx x y rx ry rotation start-angle end-angle [anticlockwise #f])
  (js-canvas2d-ellipse (canvas-2d-context-unwrap ctx)
                       (canvas-real->flonum 'canvas-2d-ellipse x)
                       (canvas-real->flonum 'canvas-2d-ellipse y)
                       (canvas-real->flonum 'canvas-2d-ellipse rx)
                       (canvas-real->flonum 'canvas-2d-ellipse ry)
                       (canvas-real->flonum 'canvas-2d-ellipse rotation)
                       (canvas-real->flonum 'canvas-2d-ellipse start-angle)
                       (canvas-real->flonum 'canvas-2d-ellipse end-angle)
                       (canvas-boolean->i32 anticlockwise))
  (void))

;; canvas-2d-get-image-data : (or/c canvas-rendering-context-2d? external?) real? real? real? real? [any/c #f] -> image-data?
;;   Read pixels from the canvas.
(define (canvas-2d-get-image-data ctx sx sy sw sh [settings #f])
  (canvas-result-wrap/checked
   'canvas-2d-get-image-data
   "CanvasRenderingContext2D.getImageData"
   "ImageData-like"
   (js-canvas2d-get-image-data (canvas-2d-context-unwrap ctx)
                               (canvas-real->flonum 'canvas-2d-get-image-data sx)
                               (canvas-real->flonum 'canvas-2d-get-image-data sy)
                               (canvas-real->flonum 'canvas-2d-get-image-data sw)
                               (canvas-real->flonum 'canvas-2d-get-image-data sh)
                               (canvas-resolve-optional settings))
   canvas-image-data-wrap
   image-data/surface?
   #f))

;; canvas-2d-get-line-dash : (or/c canvas-rendering-context-2d? external?) -> vector?
;;   Read the current dash pattern.
(define (canvas-2d-get-line-dash ctx)
  (array->vector
   (canvas-check-array-like-result
    'canvas-2d-get-line-dash
    "CanvasRenderingContext2D.getLineDash"
    (js-canvas2d-get-line-dash (canvas-2d-context-unwrap ctx)))))

;; canvas-2d-get-transform : (or/c canvas-rendering-context-2d? external?) -> dom-matrix?
;;   Read the current transform matrix.
(define (canvas-2d-get-transform ctx)
  (canvas-result-wrap/checked 'canvas-2d-get-transform
                              "CanvasRenderingContext2D.getTransform"
                              "DOMMatrix-like"
                              (js-canvas2d-get-transform (canvas-2d-context-unwrap ctx))
                              canvas-dom-matrix-wrap
                              dom-matrix/surface?
                              #f))

;; canvas-2d-is-point-in-path : (or/c canvas-rendering-context-2d? external?) [any/c #f] real? real? [any/c #f] -> boolean?
;;   Check whether a point lies within the path.
(define canvas-2d-is-point-in-path
  (case-lambda
    [(ctx x y)
     (canvas-i32->boolean
      (js-canvas2d-is-point-in-path (canvas-2d-context-unwrap ctx)
                                    (void)
                                    (canvas-real->flonum 'canvas-2d-is-point-in-path x)
                                    (canvas-real->flonum 'canvas-2d-is-point-in-path y)
                                    (void)))]
    [(ctx path x y)
     (canvas-i32->boolean
      (js-canvas2d-is-point-in-path (canvas-2d-context-unwrap ctx)
                                    (canvas-resolve-optional path)
                                    (canvas-real->flonum 'canvas-2d-is-point-in-path x)
                                    (canvas-real->flonum 'canvas-2d-is-point-in-path y)
                                    (void)))]
    [(ctx path x y fill-rule)
     (canvas-i32->boolean
      (js-canvas2d-is-point-in-path (canvas-2d-context-unwrap ctx)
                                    (canvas-resolve-optional path)
                                    (canvas-real->flonum 'canvas-2d-is-point-in-path x)
                                    (canvas-real->flonum 'canvas-2d-is-point-in-path y)
                                    (canvas-fill-rule->js fill-rule)))]))

;; canvas-2d-is-point-in-stroke : (or/c canvas-rendering-context-2d? external?) [any/c #f] real? real? -> boolean?
;;   Check whether a point lies within the stroke.
(define canvas-2d-is-point-in-stroke
  (case-lambda
    [(ctx x y)
     (canvas-i32->boolean
      (js-canvas2d-is-point-in-stroke (canvas-2d-context-unwrap ctx)
                                      (void)
                                      (canvas-real->flonum 'canvas-2d-is-point-in-stroke x)
                                      (canvas-real->flonum 'canvas-2d-is-point-in-stroke y)))]
    [(ctx path x y)
     (canvas-i32->boolean
      (js-canvas2d-is-point-in-stroke (canvas-2d-context-unwrap ctx)
                                      (canvas-resolve-optional path)
                                      (canvas-real->flonum 'canvas-2d-is-point-in-stroke x)
                                      (canvas-real->flonum 'canvas-2d-is-point-in-stroke y)))]))

;; canvas-2d-put-image-data : (or/c canvas-rendering-context-2d? external?) (or/c image-data? external?) real? real? [any/c #f] [any/c #f] [any/c #f] [any/c #f] -> void?
;;   Write pixels back to the canvas.
(define (canvas-2d-put-image-data ctx data dx dy [dirty-x #f] [dirty-y #f] [dirty-width #f] [dirty-height #f])
  (js-canvas2d-put-image-data (canvas-2d-context-unwrap ctx)
                              (canvas-image-data-unwrap/checked 'canvas-2d-put-image-data data)
                              (canvas-real->flonum 'canvas-2d-put-image-data dx)
                              (canvas-real->flonum 'canvas-2d-put-image-data dy)
                              (canvas-optional-real->flonum 'canvas-2d-put-image-data dirty-x)
                              (canvas-optional-real->flonum 'canvas-2d-put-image-data dirty-y)
                              (canvas-optional-real->flonum 'canvas-2d-put-image-data dirty-width)
                              (canvas-optional-real->flonum 'canvas-2d-put-image-data dirty-height))
  (void))

;; canvas-2d-quadratic-curve-to : (or/c canvas-rendering-context-2d? external?) real? real? real? real? -> void?
;;   Add a quadratic curve to the current path.
(define (canvas-2d-quadratic-curve-to ctx cpx cpy x y)
  (js-canvas2d-quadratic-curve-to (canvas-2d-context-unwrap ctx)
                                  (canvas-real->flonum 'canvas-2d-quadratic-curve-to cpx)
                                  (canvas-real->flonum 'canvas-2d-quadratic-curve-to cpy)
                                  (canvas-real->flonum 'canvas-2d-quadratic-curve-to x)
                                  (canvas-real->flonum 'canvas-2d-quadratic-curve-to y))
  (void))

;; canvas-2d-rect : (or/c canvas-rendering-context-2d? external?) real? real? real? real? -> void?
;;   Add a rectangle to the current path.
(define (canvas-2d-rect ctx x y width height)
  (js-canvas2d-rect (canvas-2d-context-unwrap ctx)
                    (canvas-real->flonum 'canvas-2d-rect x)
                    (canvas-real->flonum 'canvas-2d-rect y)
                    (canvas-real->flonum 'canvas-2d-rect width)
                    (canvas-real->flonum 'canvas-2d-rect height))
  (void))

;; canvas-2d-reset : (or/c canvas-rendering-context-2d? external?) -> void?
;;   Reset the entire drawing state.
(define (canvas-2d-reset ctx)
  (js-canvas2d-reset (canvas-2d-context-unwrap ctx))
  (void))

;; canvas-2d-reset-transform : (or/c canvas-rendering-context-2d? external?) -> void?
;;   Reset the transform matrix.
(define (canvas-2d-reset-transform ctx)
  (js-canvas2d-reset-transform (canvas-2d-context-unwrap ctx))
  (void))

;; canvas-2d-round-rect : (or/c canvas-rendering-context-2d? external?) real? real? real? real? [any/c #f] -> void?
;;   Add a rounded rectangle to the current path.
(define (canvas-2d-round-rect ctx x y width height [radii #f])
  (js-canvas2d-round-rect (canvas-2d-context-unwrap ctx)
                          (canvas-real->flonum 'canvas-2d-round-rect x)
                          (canvas-real->flonum 'canvas-2d-round-rect y)
                          (canvas-real->flonum 'canvas-2d-round-rect width)
                          (canvas-real->flonum 'canvas-2d-round-rect height)
                          (if (or (list? radii) (vector? radii) (array? radii))
                              (canvas-real-sequence->array 'canvas-2d-round-rect radii)
                              (canvas-optional-real->flonum 'canvas-2d-round-rect radii)))
  (void))

;; canvas-2d-set-line-dash : (or/c canvas-rendering-context-2d? external?) any/c -> void?
;;   Set the dash pattern.
(define (canvas-2d-set-line-dash ctx segments)
  (js-canvas2d-set-line-dash (canvas-2d-context-unwrap ctx)
                             (canvas-real-sequence->array 'canvas-2d-set-line-dash segments))
  (void))

;; canvas-2d-set-transform! : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? real? -> void?
;;   Set the transform matrix using six numbers.
(define (canvas-2d-set-transform! ctx a b c d e f)
  (js-canvas2d-set-transform! (canvas-2d-context-unwrap ctx)
                              (canvas-real->flonum 'canvas-2d-set-transform! a)
                              (canvas-real->flonum 'canvas-2d-set-transform! b)
                              (canvas-real->flonum 'canvas-2d-set-transform! c)
                              (canvas-real->flonum 'canvas-2d-set-transform! d)
                              (canvas-real->flonum 'canvas-2d-set-transform! e)
                              (canvas-real->flonum 'canvas-2d-set-transform! f))
  (void))

;; canvas-2d-set-transform-matrix! : (or/c canvas-rendering-context-2d? external?) (or/c dom-matrix? external?) -> void?
;;   Set the transform matrix from a DOMMatrix.
(define (canvas-2d-set-transform-matrix! ctx matrix)
  (js-canvas2d-set-transform-matrix! (canvas-2d-context-unwrap ctx)
                                     (canvas-matrix->raw/checked
                                      'canvas-2d-set-transform-matrix!
                                      matrix))
  (void))

;; canvas-2d-transform : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? real? -> void?
;;   Apply an affine transform to the current matrix.
(define (canvas-2d-transform ctx a b c d e f)
  (js-canvas2d-transform (canvas-2d-context-unwrap ctx)
                         (canvas-real->flonum 'canvas-2d-transform a)
                         (canvas-real->flonum 'canvas-2d-transform b)
                         (canvas-real->flonum 'canvas-2d-transform c)
                         (canvas-real->flonum 'canvas-2d-transform d)
                         (canvas-real->flonum 'canvas-2d-transform e)
                         (canvas-real->flonum 'canvas-2d-transform f))
  (void))

;; canvas-2d-create-linear-gradient : (or/c canvas-rendering-context-2d? external?) real? real? real? real? -> canvas-gradient?
;;   Create a linear gradient.
(define (canvas-2d-create-linear-gradient ctx x0 y0 x1 y1)
  (canvas-result-wrap/checked
   'canvas-2d-create-linear-gradient
   "CanvasRenderingContext2D.createLinearGradient"
   "CanvasGradient-like"
   (js-canvas2d-create-linear-gradient (canvas-2d-context-unwrap ctx)
                                       (canvas-real->flonum 'canvas-2d-create-linear-gradient x0)
                                       (canvas-real->flonum 'canvas-2d-create-linear-gradient y0)
                                       (canvas-real->flonum 'canvas-2d-create-linear-gradient x1)
                                       (canvas-real->flonum 'canvas-2d-create-linear-gradient y1))
   canvas-gradient-wrap
   canvas-gradient/surface?
   #f))

;; canvas-2d-create-radial-gradient : (or/c canvas-rendering-context-2d? external?) real? real? real? real? real? real? -> canvas-gradient?
;;   Create a radial gradient.
(define (canvas-2d-create-radial-gradient ctx x0 y0 r0 x1 y1 r1)
  (canvas-result-wrap/checked
   'canvas-2d-create-radial-gradient
   "CanvasRenderingContext2D.createRadialGradient"
   "CanvasGradient-like"
   (js-canvas2d-create-radial-gradient (canvas-2d-context-unwrap ctx)
                                       (canvas-real->flonum 'canvas-2d-create-radial-gradient x0)
                                       (canvas-real->flonum 'canvas-2d-create-radial-gradient y0)
                                       (canvas-real->flonum 'canvas-2d-create-radial-gradient r0)
                                       (canvas-real->flonum 'canvas-2d-create-radial-gradient x1)
                                       (canvas-real->flonum 'canvas-2d-create-radial-gradient y1)
                                       (canvas-real->flonum 'canvas-2d-create-radial-gradient r1))
   canvas-gradient-wrap
   canvas-gradient/surface?
   #f))

;; canvas-2d-fill-style : (or/c canvas-rendering-context-2d? external?) -> any/c
;;   Read the fill style.
(define (canvas-2d-fill-style ctx)
  (canvas-paint-style-wrap-result 'canvas-2d-fill-style
                                  "CanvasRenderingContext2D.fillStyle"
                                  (js-canvas2d-fill-style (canvas-2d-context-unwrap ctx))))

;; canvas-2d-set-fill-style! : (or/c canvas-rendering-context-2d? external?) any/c -> void?
;;   Set the fill style.
(define (canvas-2d-set-fill-style! ctx style)
  (js-set-canvas2d-fill-style! (canvas-2d-context-unwrap ctx)
                               (canvas-paint-style-unwrap/checked
                                'canvas-2d-set-fill-style!
                                style))
  (void))

;; canvas-2d-stroke-style : (or/c canvas-rendering-context-2d? external?) -> any/c
;;   Read the stroke style.
(define (canvas-2d-stroke-style ctx)
  (canvas-paint-style-wrap-result 'canvas-2d-stroke-style
                                  "CanvasRenderingContext2D.strokeStyle"
                                  (js-canvas2d-stroke-style (canvas-2d-context-unwrap ctx))))

;; canvas-2d-set-stroke-style! : (or/c canvas-rendering-context-2d? external?) any/c -> void?
;;   Set the stroke style.
(define (canvas-2d-set-stroke-style! ctx style)
  (js-set-canvas2d-stroke-style! (canvas-2d-context-unwrap ctx)
                                 (canvas-paint-style-unwrap/checked
                                  'canvas-2d-set-stroke-style!
                                  style))
  (void))
