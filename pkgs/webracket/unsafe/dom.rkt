#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-window-window
 js-window-self
 js-window-document
 js-window-name
 js-set-window-name!
 js-window-location
 js-set-window-location!
 js-window-custom-elements
 js-window-history
 js-window-locationbar
 js-window-menubar
 js-window-personalbar
 js-window-scrollbars
 js-window-statusbar
 js-window-toolbar
 js-window-closed
 js-window-frames
 js-window-length
 js-window-opener
 js-set-window-opener!
 js-window-parent
 js-window-top
 js-window-visual-viewport
 js-window-navigator
 js-window-origin
 js-window-crypto
 js-window-device-pixel-ratio
 js-window-frame-element
 js-window-inner-height
 js-window-inner-width
 js-window-outer-height
 js-window-outer-width
 js-window-screen-x
 js-window-screen-y
 js-window-screen-left
 js-window-screen-top
 js-window-page-x-offset
 js-window-page-y-offset
 js-window-scroll-x
 js-window-scroll-y
 js-window-screen
 js-window-local-storage
 js-window-session-storage
 js-window-performance
 js-window-indexed-db
 js-window-is-secure-context
 js-window-cross-origin-isolated
 js-window-caches
 js-window-speech-synthesis
 js-window-style-media
 js-window-alert
 js-window-atob
 js-window-btoa
 js-window-blur
 js-window-cancel-animation-frame
 js-window-cancel-idle-callback
 js-window-clear-interval
 js-window-clear-timeout
 js-window-close
 js-window-confirm
 js-window-create-image-bitmap
 js-window-fetch
 js-window-focus
 js-window-get-computed-style
 js-window-get-selection
 js-window-match-media
 js-window-move-by
 js-window-move-to
 js-window-open
 js-window-post-message
 js-window-print
 js-window-prompt
 js-window-request-animation-frame
 js-window-request-idle-callback
 js-window-resize-by
 js-window-resize-to
 js-window-scroll
 js-window-scroll-by
 js-window-scroll-to
 js-window-set-interval
 js-window-set-timeout
 js-window-set-timeout/delay
 js-window-stop
 js-window-structured-clone
 js-window-queue-microtask
 js-window-report-error
 js-performance-event-counts
 js-performance-event-count-map-size
 js-performance-interaction-count
 js-performance-memory
 js-performance-memory-info-js-heap-size-limit
 js-performance-memory-info-total-js-heap-size
 js-performance-memory-info-used-js-heap-size
 js-performance-time-origin
 js-performance-now
 js-performance-clear-marks
 js-performance-clear-measures
 js-performance-clear-resource-timings
 js-performance-get-entries
 js-performance-get-entries-by-name
 js-performance-get-entries-by-type
 js-performance-mark
 js-performance-measure
 js-performance-measure-user-agent-specific-memory
 js-performance-set-resource-timing-buffer-size
 js-performance-to-json
 js-document
 js-document-head
 js-document-body
 js-document-element
 js-create-element
 js-create-text-node
 js-adopt-node
 js-caret-range-from-point
 js-close
 js-create-attribute
 js-create-attribute-ns
 js-create-cdata-section
 js-create-comment
 js-create-document-fragment
 js-create-element-ns
 js-create-expression
 js-create-node-iterator
 js-create-processing-instruction
 js-create-range
 js-create-tree-walker
 js-element-from-point
 js-elements-from-point
 js-enable-style-sheets-for-set
 js-evaluate
 js-exit-fullscreen
 js-exit-picture-in-picture
 js-exit-pointer-lock
 js-get-element-by-id
 js-get-elements-by-class-name
 js-get-elements-by-name
 js-get-elements-by-tag-name
 js-get-elements-by-tag-name-ns
 js-get-selection
 js-has-focus
 js-import-node
 js-open
 js-query-selector
 js-query-selector-all
 js-release-events
 js-add-event-listener!
 js-event-new
 js-event?
 js-event-type
 js-event-target
 js-event-current-target
 js-event-event-phase
 js-event-bubbles
 js-event-cancelable
 js-event-default-prevented
 js-event-composed
 js-event-is-trusted
 js-event-time-stamp
 js-event-composed-path
 js-event-prevent-default
 js-event-stop-propagation
 js-event-stop-immediate-propagation
 js-message-event?
 js-message-event-data
 js-message-event-origin
 js-message-event-last-event-id
 js-message-event-source
 js-message-event-ports
 js-close-event?
 js-close-event-was-clean
 js-close-event-code
 js-close-event-reason
 js-mouse-event?
 js-mouse-event-offset-x
 js-mouse-event-offset-y
 js-mouse-event-client-x
 js-mouse-event-client-y
 js-mouse-event-page-x
 js-mouse-event-page-y
 js-mouse-event-screen-x
 js-mouse-event-screen-y
 js-mouse-event-button
 js-mouse-event-buttons
 js-mouse-event-alt-key
 js-mouse-event-ctrl-key
 js-mouse-event-meta-key
 js-mouse-event-shift-key
 js-keyboard-event?
 js-keyboard-event-key
 js-keyboard-event-code
 js-keyboard-event-alt-key
 js-keyboard-event-ctrl-key
 js-keyboard-event-meta-key
 js-keyboard-event-shift-key
 js-keyboard-event-repeat
 js-pointer-event?
 js-focus-event?
 js-input-event?
 js-submit-event?
 js-wheel-event?
 js-touch-event?
 js-touch-event-touches
 js-touch-event-target-touches
 js-touch-event-changed-touches
 js-touch-list?
 js-touch-list-length
 js-touch-list-ref
 js-touch?
 js-touch-identifier
 js-touch-client-x
 js-touch-client-y
 js-touch-page-x
 js-touch-page-y
 js-touch-screen-x
 js-touch-screen-y
 js-dom-rect-left
 js-dom-rect-top
 js-dom-rect-width
 js-dom-rect-height
 js-element-class-list
 js-element-id
 js-set-element-id!
 js-element-class-name
 js-set-element-class-name!
 js-element-tag-name
 js-element-local-name
 js-element-namespace-uri
 js-element-prefix
 js-element-is-connected
 js-element-children
 js-element-scroll-top
 js-set-element-scroll-top!
 js-element-scroll-left
 js-set-element-scroll-left!
 js-element-scroll-width
 js-element-scroll-height
 js-element-client-width
 js-element-client-height
 js-element-offset-width
 js-element-offset-height
 js-element-child-element-count
 js-element-first-element-child
 js-element-last-element-child
 js-element-parent-element
 js-element-previous-element-sibling
 js-element-next-element-sibling
 js-element-inner-html
 js-set-element-inner-html!
 js-element-outer-html
 js-set-element-outer-html!
 js-element-text-content
 js-set-element-text-content!
 js-element-shadow-root
 js-dom-token-list-value
 js-dom-token-list-length
 js-node-list-length
 js-node-list-item
 js-html-collection-length
 js-html-collection-item
 js-html-collection-named-item
 js-shadow-root-host
 js-shadow-root-mode
 js-shadow-root-delegates-focus
 js-dom-rect-list-length
 js-dom-rect-list-item
 js-append-child!
 js-set-attribute!
 js-after!
 js-animate
 js-append!
 js-attach-shadow!
 js-before!
 js-closest
 js-computed-style-map
 js-get-animations
 js-get-attribute
 js-get-attribute-ns
 js-get-attribute-names
 js-dom-token-list-item
 js-get-attribute-node
 js-get-attribute-node-ns
 js-get-bounding-client-rect
 js-get-client-rects
 js-element-get-elements-by-class-name
 js-element-get-elements-by-tag-name
 js-element-get-elements-by-tag-name-ns
 js-has-attribute
 js-has-attribute-ns
 js-has-attributes
 js-has-pointer-capture
 js-insert-adjacent-element!
 js-insert-adjacent-html!
 js-insert-adjacent-text!
 js-matches
 js-prepend!
 js-element-query-selector
 js-element-query-selector-all
 js-release-pointer-capture!
 js-remove!
 js-remove-attribute!
 js-remove-attribute-ns!
 js-remove-attribute-node!
 js-replace-children!
 js-replace-with!
 js-request-fullscreen
 js-request-pointer-lock
 js-scroll!
 js-scroll-by!
 js-scroll-into-view!
 js-scroll-to!
 js-set-attribute-ns!
 js-set-attribute-node!
 js-set-attribute-node-ns!
 js-set-pointer-capture!
 js-toggle-attribute!
 js-toggle-attribute
 js-global-this
 js-infinity
 js-nan
 js-undefined
 js-nullish?
 js-null?
 js-undefined?
 js-truthy?
 js-eval
 js-is-finite
 js-finite?
 js-is-nan
 js-nan?
 js-parse-float
 js-parse-int
 js-decode-uri
 js-decode-uri-component
 js-encode-uri
 js-encode-uri-component
 js-var
 js-ref/extern
 js-ref
 js-set!
 js-index
 js-assign!
 js-new
 js-send
 js-send/extern
 js-send/extern/null
 js-send/extern/undefined
 js-send/extern/nullish
 js-send/value
 js-send/boolean
 js-send/truthy
 js-send/flonum
 js-throw
 js-null
 js-this
 js-object
 js-Array
 js-typeof
 js-constructible?
 js-value->string
 js-instanceof
 js-operator
 js-Object
 js-Function
 js-Boolean
 js-Symbol
 js-Error
 js-AggregateError
 js-EvalError
 js-RangeError
 js-ReferenceError
 js-SuppressedError
 js-SyntaxError
 js-TypeError
 js-URIError
 js-InternalError
 js-Number
 js-BigInt
 js-Math
 js-Date
 js-Temporal
 js-number-epsilon
 js-number-max-safe-integer
 js-number-max-value
 js-number-min-safe-integer
 js-number-min-value
 js-number-nan
 js-number-negative-infinity
 js-number-positive-infinity
 js-number-finite?
 js-number-integer?
 js-number-nan?
 js-number-safe-integer?
 js-number-parse-float
 js-number-parse-int
 js-number-to-exponential
 js-number-to-fixed
 js-number-to-locale-string
 js-number-to-precision
 js-number-to-string
 js-number-value-of
 js-String
 js-RegExp
 js-array
 js-array/extern
 js-TypedArray
 js-Int8Array
 js-Uint8Array
 js-Uint8ClampedArray
 js-Int16Array
 js-Uint16Array
 js-Int32Array
 js-Uint32Array
 js-BigInt64Array
 js-BigUint64Array
 js-Float16Array
 js-Float32Array
 js-Float64Array
 js-Map
 js-Set
 js-WeakMap
 js-WeakSet
 js-ArrayBuffer
 js-SharedArrayBuffer
 js-DataView
 js-Atomics
 js-JSON
 js-WeakRef
 js-FinalizationRegistry
 js-Iterator
 js-AsyncIterator
 js-Promise
 js-GeneratorFunction
 js-AsyncGeneratorFunction
 js-Generator
 js-AsyncGenerator
 js-AsyncFunction
 js-DisposableStack
 js-AsyncDisposableStack
 js-Reflect
 js-Proxy
 js-Intl
 js-IntlCollator
 js-IntlDateTimeFormat
 js-IntlDisplayNames
 js-IntlDurationFormat
 js-IntlListFormat
 js-IntlLocale
 js-IntlNumberFormat
 js-IntlPluralRules
 js-IntlRelativeTimeFormat
 js-IntlSegmenter
 js-array-from
 js-array-from-async
 js-array-is-array
 js-array->vector
 js-array->bytes
 js-array-of
 js-array-length
 js-set-array-length!
 js-array-ref
 js-array-at
 js-array-concat
 js-array-copy-within
 js-array-entries
 js-array-every
 js-array-fill
 js-array-filter
 js-array-find
 js-array-find-index
 js-array-find-last
 js-array-find-last-index
 js-array-flat
 js-array-flat-map
 js-array-for-each
 js-array-includes
 js-array-index-of
 js-array-join
 js-array-keys
 js-array-last-index-of
 js-array-map
 js-array-pop
 js-array-push
 js-array-reduce
 js-array-reduce-right
 js-array-reverse
 js-array-shift
 js-array-slice
 js-array-some
 js-array-sort
 js-array-splice
 js-array-to-locale-string
 js-array-to-string
 js-array-unshift
 js-array-values
 js-array-to-reversed
 js-array-to-sorted
 js-array-to-spliced
 js-array-with
 js-media-audio-tracks
 js-media-autoplay
 js-set-media-autoplay!
 js-media-buffered
 js-media-controls
 js-set-media-controls!
 js-media-controls-list
 js-media-cross-origin
 js-set-media-cross-origin!
 js-media-current-src
 js-media-current-time
 js-set-media-current-time!
 js-media-default-muted
 js-set-media-default-muted!
 js-media-default-playback-rate
 js-set-media-default-playback-rate!
 js-media-disable-remote-playback
 js-set-media-disable-remote-playback!
 js-media-duration
 js-media-ended
 js-media-error
 js-media-loop
 js-set-media-loop!
 js-media-media-keys
 js-media-media-group
 js-set-media-media-group!
 js-media-muted
 js-set-media-muted!
 js-media-network-state
 js-media-paused
 js-media-playback-rate
 js-set-media-playback-rate!
 js-media-played
 js-media-preload
 js-set-media-preload!
 js-media-preserves-pitch
 js-set-media-preserves-pitch!
 js-media-ready-state
 js-media-seekable
 js-media-seeking
 js-media-sink-id
 js-media-src
 js-set-media-src!
 js-media-src-object
 js-set-media-src-object!
 js-media-text-tracks
 js-media-video-tracks
 js-media-volume
 js-set-media-volume!
 js-media-add-text-track!
 js-media-can-play-type
 js-media-capture-stream
 js-media-fast-seek!
 js-media-load!
 js-media-pause
 js-media-play
 js-media-set-media-keys!
 js-media-set-sink-id!
 js-canvas-capture-stream
 js-canvas-get-context
 js-canvas-height
 js-set-canvas-height!
 js-canvas-to-blob
 js-canvas-to-data-url
 js-canvas-transfer-control-to-offscreen
 js-canvas-width
 js-set-canvas-width!
 js-canvas2d-canvas
 js-canvas2d-direction
 js-set-canvas2d-direction!
 js-canvas2d-fill-style
 js-set-canvas2d-fill-style!
 js-canvas2d-filter
 js-set-canvas2d-filter!
 js-canvas2d-font
 js-set-canvas2d-font!
 js-canvas2d-global-alpha
 js-set-canvas2d-global-alpha!
 js-canvas2d-global-composite-operation
 js-set-canvas2d-global-composite-operation!
 js-canvas2d-image-smoothing-enabled
 js-set-canvas2d-image-smoothing-enabled!
 js-canvas2d-image-smoothing-quality
 js-set-canvas2d-image-smoothing-quality!
 js-canvas2d-line-cap
 js-set-canvas2d-line-cap!
 js-canvas2d-line-dash-offset
 js-set-canvas2d-line-dash-offset!
 js-canvas2d-line-join
 js-set-canvas2d-line-join!
 js-canvas2d-line-width
 js-set-canvas2d-line-width!
 js-canvas2d-miter-limit
 js-set-canvas2d-miter-limit!
 js-canvas2d-shadow-blur
 js-set-canvas2d-shadow-blur!
 js-canvas2d-shadow-color
 js-set-canvas2d-shadow-color!
 js-canvas2d-shadow-offset-x
 js-set-canvas2d-shadow-offset-x!
 js-canvas2d-shadow-offset-y
 js-set-canvas2d-shadow-offset-y!
 js-canvas2d-stroke-style
 js-set-canvas2d-stroke-style!
 js-canvas2d-text-align
 js-set-canvas2d-text-align!
 js-canvas2d-text-baseline
 js-set-canvas2d-text-baseline!
 js-canvas2d-text-rendering
 js-set-canvas2d-text-rendering!
 js-canvas2d-font-kerning
 js-set-canvas2d-font-kerning!
 js-canvas2d-font-stretch
 js-set-canvas2d-font-stretch!
 js-canvas2d-font-variant-caps
 js-set-canvas2d-font-variant-caps!
 js-canvas2d-font-variant-ligatures
 js-set-canvas2d-font-variant-ligatures!
 js-canvas2d-font-variant-numeric
 js-set-canvas2d-font-variant-numeric!
 js-canvas2d-letter-spacing
 js-set-canvas2d-letter-spacing!
 js-canvas2d-word-spacing
 js-set-canvas2d-word-spacing!
 js-canvas2d-arc
 js-canvas2d-arc-to
 js-canvas2d-begin-path
 js-canvas2d-bezier-curve-to
 js-canvas2d-clear-rect
 js-canvas2d-clip
 js-canvas2d-close-path
 js-canvas2d-create-image-data
 js-canvas2d-create-image-data-from
 js-canvas-image-data-width
 js-canvas-image-data-height
 js-canvas-image-data-data
 js-canvas-text-metrics-width
 js-canvas-dom-matrix-a
 js-canvas-dom-matrix-b
 js-canvas-dom-matrix-c
 js-canvas-dom-matrix-d
 js-canvas-dom-matrix-e
 js-canvas-dom-matrix-f
 js-canvas2d-create-linear-gradient
 js-canvas2d-create-pattern
 js-canvas2d-create-radial-gradient
 js-canvas2d-create-conic-gradient
 js-canvas2d-draw-focus-if-needed!
 js-canvas2d-draw-focus-if-needed-path!
 js-canvas2d-draw-image
 js-canvas2d-draw-image-5
 js-canvas2d-draw-image-9
 js-canvas2d-ellipse
 js-canvas2d-fill
 js-canvas2d-fill-rect
 js-canvas2d-fill-text
 js-canvas2d-get-image-data
 js-canvas2d-get-line-dash
 js-canvas2d-get-transform
 js-canvas2d-is-point-in-path
 js-canvas2d-is-point-in-stroke
 js-canvas2d-line-to
 js-canvas2d-measure-text
 js-canvas2d-move-to
 js-canvas2d-put-image-data
 js-canvas2d-quadratic-curve-to
 js-canvas2d-rect
 js-canvas2d-reset
 js-canvas2d-reset-transform
 js-canvas2d-restore
 js-canvas2d-rotate
 js-canvas2d-round-rect
 js-canvas2d-save
 js-canvas2d-scale
 js-canvas2d-set-line-dash
 js-canvas2d-set-transform!
 js-canvas2d-set-transform-matrix!
 js-canvas2d-stroke
 js-canvas2d-stroke-rect
 js-canvas2d-stroke-text
 js-canvas2d-transform
 js-canvas2d-translate
 js-image-new
 js-image-alt
 js-set-image-alt!
 js-image-src
 js-set-image-src!
 js-image-srcset
 js-set-image-srcset!
 js-image-sizes
 js-set-image-sizes!
 js-image-cross-origin
 js-set-image-cross-origin!
 js-image-use-map
 js-set-image-use-map!
 js-image-is-map
 js-set-image-is-map!
 js-image-width
 js-set-image-width!
 js-image-height
 js-set-image-height!
 js-image-natural-width
 js-image-natural-height
 js-image-complete
 js-image-current-src
 js-image-decoding
 js-set-image-decoding!
 js-image-fetch-priority
 js-set-image-fetch-priority!
 js-image-loading
 js-set-image-loading!
 js-image-referrer-policy
 js-set-image-referrer-policy!
 js-image-name
 js-set-image-name!
 js-image-x
 js-image-y
 js-image-decode)

;; js-window-window : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-window (unsafe-ffi-primitive 'js-window-window))

;; js-window-self : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-self (unsafe-ffi-primitive 'js-window-self))

;; js-window-document : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-document (unsafe-ffi-primitive 'js-window-document))

;; js-window-name : ffi () -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-name (unsafe-ffi-primitive 'js-window-name))

;; js-set-window-name! : ffi (string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-window-name! (unsafe-ffi-primitive 'js-set-window-name!))

;; js-window-location : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-location (unsafe-ffi-primitive 'js-window-location))

;; js-set-window-location! : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-window-location! (unsafe-ffi-primitive 'js-set-window-location!))

;; js-window-custom-elements : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-custom-elements (unsafe-ffi-primitive 'js-window-custom-elements))

;; js-window-history : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-history (unsafe-ffi-primitive 'js-window-history))

;; js-window-locationbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-locationbar (unsafe-ffi-primitive 'js-window-locationbar))

;; js-window-menubar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-menubar (unsafe-ffi-primitive 'js-window-menubar))

;; js-window-personalbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-personalbar (unsafe-ffi-primitive 'js-window-personalbar))

;; js-window-scrollbars : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-scrollbars (unsafe-ffi-primitive 'js-window-scrollbars))

;; js-window-statusbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-statusbar (unsafe-ffi-primitive 'js-window-statusbar))

;; js-window-toolbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-toolbar (unsafe-ffi-primitive 'js-window-toolbar))

;; js-window-closed : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-closed (unsafe-ffi-primitive 'js-window-closed))

;; js-window-frames : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-frames (unsafe-ffi-primitive 'js-window-frames))

;; js-window-length : ffi () -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-length (unsafe-ffi-primitive 'js-window-length))

;; js-window-opener : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-opener (unsafe-ffi-primitive 'js-window-opener))

;; js-set-window-opener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-window-opener! (unsafe-ffi-primitive 'js-set-window-opener!))

;; js-window-parent : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-parent (unsafe-ffi-primitive 'js-window-parent))

;; js-window-top : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-top (unsafe-ffi-primitive 'js-window-top))

;; js-window-visual-viewport : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-visual-viewport (unsafe-ffi-primitive 'js-window-visual-viewport))

;; js-window-navigator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-navigator (unsafe-ffi-primitive 'js-window-navigator))

;; js-window-origin : ffi () -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-origin (unsafe-ffi-primitive 'js-window-origin))

;; js-window-crypto : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-crypto (unsafe-ffi-primitive 'js-window-crypto))

;; js-window-device-pixel-ratio : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-device-pixel-ratio (unsafe-ffi-primitive 'js-window-device-pixel-ratio))

;; js-window-frame-element : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-frame-element (unsafe-ffi-primitive 'js-window-frame-element))

;; js-window-inner-height : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-inner-height (unsafe-ffi-primitive 'js-window-inner-height))

;; js-window-inner-width : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-inner-width (unsafe-ffi-primitive 'js-window-inner-width))

;; js-window-outer-height : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-outer-height (unsafe-ffi-primitive 'js-window-outer-height))

;; js-window-outer-width : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-outer-width (unsafe-ffi-primitive 'js-window-outer-width))

;; js-window-screen-x : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-screen-x (unsafe-ffi-primitive 'js-window-screen-x))

;; js-window-screen-y : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-screen-y (unsafe-ffi-primitive 'js-window-screen-y))

;; js-window-screen-left : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-screen-left (unsafe-ffi-primitive 'js-window-screen-left))

;; js-window-screen-top : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-screen-top (unsafe-ffi-primitive 'js-window-screen-top))

;; js-window-page-x-offset : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-page-x-offset (unsafe-ffi-primitive 'js-window-page-x-offset))

;; js-window-page-y-offset : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-page-y-offset (unsafe-ffi-primitive 'js-window-page-y-offset))

;; js-window-scroll-x : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-scroll-x (unsafe-ffi-primitive 'js-window-scroll-x))

;; js-window-scroll-y : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-scroll-y (unsafe-ffi-primitive 'js-window-scroll-y))

;; js-window-screen : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-screen (unsafe-ffi-primitive 'js-window-screen))

;; js-window-local-storage : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-local-storage (unsafe-ffi-primitive 'js-window-local-storage))

;; js-window-session-storage : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-session-storage (unsafe-ffi-primitive 'js-window-session-storage))

;; js-window-performance : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-performance (unsafe-ffi-primitive 'js-window-performance))

;; js-window-indexed-db : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-indexed-db (unsafe-ffi-primitive 'js-window-indexed-db))

;; js-window-is-secure-context : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-is-secure-context (unsafe-ffi-primitive 'js-window-is-secure-context))

;; js-window-cross-origin-isolated : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-cross-origin-isolated (unsafe-ffi-primitive 'js-window-cross-origin-isolated))

;; js-window-caches : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-caches (unsafe-ffi-primitive 'js-window-caches))

;; js-window-speech-synthesis : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-speech-synthesis (unsafe-ffi-primitive 'js-window-speech-synthesis))

;; js-window-style-media : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-style-media (unsafe-ffi-primitive 'js-window-style-media))

;; js-window-alert : ffi (string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-alert (unsafe-ffi-primitive 'js-window-alert))

;; js-window-atob : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-atob (unsafe-ffi-primitive 'js-window-atob))

;; js-window-btoa : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-btoa (unsafe-ffi-primitive 'js-window-btoa))

;; js-window-blur : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-blur (unsafe-ffi-primitive 'js-window-blur))

;; js-window-cancel-animation-frame : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-cancel-animation-frame (unsafe-ffi-primitive 'js-window-cancel-animation-frame))

;; js-window-cancel-idle-callback : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-cancel-idle-callback (unsafe-ffi-primitive 'js-window-cancel-idle-callback))

;; js-window-clear-interval : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-clear-interval (unsafe-ffi-primitive 'js-window-clear-interval))

;; js-window-clear-timeout : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-clear-timeout (unsafe-ffi-primitive 'js-window-clear-timeout))

;; js-window-close : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-close (unsafe-ffi-primitive 'js-window-close))

;; js-window-confirm : ffi (string) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-confirm (unsafe-ffi-primitive 'js-window-confirm))

;; js-window-create-image-bitmap : ffi (extern value value value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-create-image-bitmap (unsafe-ffi-primitive 'js-window-create-image-bitmap))

;; js-window-fetch : ffi (value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-fetch (unsafe-ffi-primitive 'js-window-fetch))

;; js-window-focus : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-focus (unsafe-ffi-primitive 'js-window-focus))

;; js-window-get-computed-style : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-get-computed-style (unsafe-ffi-primitive 'js-window-get-computed-style))

;; js-window-get-selection : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-get-selection (unsafe-ffi-primitive 'js-window-get-selection))

;; js-window-match-media : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-match-media (unsafe-ffi-primitive 'js-window-match-media))

;; js-window-move-by : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-move-by (unsafe-ffi-primitive 'js-window-move-by))

;; js-window-move-to : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-move-to (unsafe-ffi-primitive 'js-window-move-to))

;; js-window-open : ffi (string value value value) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-open (unsafe-ffi-primitive 'js-window-open))

;; js-window-post-message : ffi (value string value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-post-message (unsafe-ffi-primitive 'js-window-post-message))

;; js-window-print : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-print (unsafe-ffi-primitive 'js-window-print))

;; js-window-prompt : ffi (string value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-prompt (unsafe-ffi-primitive 'js-window-prompt))

;; js-window-request-animation-frame : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-request-animation-frame (unsafe-ffi-primitive 'js-window-request-animation-frame))

;; js-window-request-idle-callback : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-request-idle-callback (unsafe-ffi-primitive 'js-window-request-idle-callback))

;; js-window-resize-by : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-resize-by (unsafe-ffi-primitive 'js-window-resize-by))

;; js-window-resize-to : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-resize-to (unsafe-ffi-primitive 'js-window-resize-to))

;; js-window-scroll : ffi (f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-scroll (unsafe-ffi-primitive 'js-window-scroll))

;; js-window-scroll-by : ffi (f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-scroll-by (unsafe-ffi-primitive 'js-window-scroll-by))

;; js-window-scroll-to : ffi (f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-scroll-to (unsafe-ffi-primitive 'js-window-scroll-to))

;; js-window-set-interval : ffi (extern f64) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-set-interval (unsafe-ffi-primitive 'js-window-set-interval))

;; js-window-set-timeout : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-set-timeout (unsafe-ffi-primitive 'js-window-set-timeout))

;; js-window-set-timeout/delay : ffi (extern f64) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-set-timeout/delay (unsafe-ffi-primitive 'js-window-set-timeout/delay))

;; js-window-stop : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-stop (unsafe-ffi-primitive 'js-window-stop))

;; js-window-structured-clone : ffi (value value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-structured-clone (unsafe-ffi-primitive 'js-window-structured-clone))

;; js-window-queue-microtask : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-queue-microtask (unsafe-ffi-primitive 'js-window-queue-microtask))

;; js-window-report-error : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-window-report-error (unsafe-ffi-primitive 'js-window-report-error))

;; js-performance-event-counts : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-event-counts (unsafe-ffi-primitive 'js-performance-event-counts))

;; js-performance-event-count-map-size : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-event-count-map-size (unsafe-ffi-primitive 'js-performance-event-count-map-size))

;; js-performance-interaction-count : ffi () -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-interaction-count (unsafe-ffi-primitive 'js-performance-interaction-count))

;; js-performance-memory : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-memory (unsafe-ffi-primitive 'js-performance-memory))

;; js-performance-memory-info-js-heap-size-limit : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-memory-info-js-heap-size-limit (unsafe-ffi-primitive 'js-performance-memory-info-js-heap-size-limit))

;; js-performance-memory-info-total-js-heap-size : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-memory-info-total-js-heap-size (unsafe-ffi-primitive 'js-performance-memory-info-total-js-heap-size))

;; js-performance-memory-info-used-js-heap-size : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-memory-info-used-js-heap-size (unsafe-ffi-primitive 'js-performance-memory-info-used-js-heap-size))

;; js-performance-time-origin : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-time-origin (unsafe-ffi-primitive 'js-performance-time-origin))

;; js-performance-now : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-now (unsafe-ffi-primitive 'js-performance-now))

;; js-performance-clear-marks : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-clear-marks (unsafe-ffi-primitive 'js-performance-clear-marks))

;; js-performance-clear-measures : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-clear-measures (unsafe-ffi-primitive 'js-performance-clear-measures))

;; js-performance-clear-resource-timings : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-clear-resource-timings (unsafe-ffi-primitive 'js-performance-clear-resource-timings))

;; js-performance-get-entries : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-get-entries (unsafe-ffi-primitive 'js-performance-get-entries))

;; js-performance-get-entries-by-name : ffi (string value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-get-entries-by-name (unsafe-ffi-primitive 'js-performance-get-entries-by-name))

;; js-performance-get-entries-by-type : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-get-entries-by-type (unsafe-ffi-primitive 'js-performance-get-entries-by-type))

;; js-performance-mark : ffi (string value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-mark (unsafe-ffi-primitive 'js-performance-mark))

;; js-performance-measure : ffi (string value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-measure (unsafe-ffi-primitive 'js-performance-measure))

;; js-performance-measure-user-agent-specific-memory : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-measure-user-agent-specific-memory (unsafe-ffi-primitive 'js-performance-measure-user-agent-specific-memory))

;; js-performance-set-resource-timing-buffer-size : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-set-resource-timing-buffer-size (unsafe-ffi-primitive 'js-performance-set-resource-timing-buffer-size))

;; js-performance-to-json : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-performance-to-json (unsafe-ffi-primitive 'js-performance-to-json))

;; js-document : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-document (unsafe-ffi-primitive 'js-document))

;; js-document-head : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-document-head (unsafe-ffi-primitive 'js-document-head))

;; js-document-body : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-document-body (unsafe-ffi-primitive 'js-document-body))

;; js-document-element : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-document-element (unsafe-ffi-primitive 'js-document-element))

;; js-create-element : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-element (unsafe-ffi-primitive 'js-create-element))

;; js-create-text-node : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-text-node (unsafe-ffi-primitive 'js-create-text-node))

;; js-adopt-node : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-adopt-node (unsafe-ffi-primitive 'js-adopt-node))

;; js-caret-range-from-point : ffi (f64 f64) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-caret-range-from-point (unsafe-ffi-primitive 'js-caret-range-from-point))

;; js-close : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-close (unsafe-ffi-primitive 'js-close))

;; js-create-attribute : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-attribute (unsafe-ffi-primitive 'js-create-attribute))

;; js-create-attribute-ns : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-attribute-ns (unsafe-ffi-primitive 'js-create-attribute-ns))

;; js-create-cdata-section : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-cdata-section (unsafe-ffi-primitive 'js-create-cdata-section))

;; js-create-comment : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-comment (unsafe-ffi-primitive 'js-create-comment))

;; js-create-document-fragment : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-document-fragment (unsafe-ffi-primitive 'js-create-document-fragment))

;; js-create-element-ns : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-element-ns (unsafe-ffi-primitive 'js-create-element-ns))

;; js-create-expression : ffi (string extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-expression (unsafe-ffi-primitive 'js-create-expression))

;; js-create-node-iterator : ffi (extern u32 extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-node-iterator (unsafe-ffi-primitive 'js-create-node-iterator))

;; js-create-processing-instruction : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-processing-instruction (unsafe-ffi-primitive 'js-create-processing-instruction))

;; js-create-range : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-range (unsafe-ffi-primitive 'js-create-range))

;; js-create-tree-walker : ffi (extern u32 extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-create-tree-walker (unsafe-ffi-primitive 'js-create-tree-walker))

;; js-element-from-point : ffi (f64 f64) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-from-point (unsafe-ffi-primitive 'js-element-from-point))

;; js-elements-from-point : ffi (f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-elements-from-point (unsafe-ffi-primitive 'js-elements-from-point))

;; js-enable-style-sheets-for-set : ffi (string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-enable-style-sheets-for-set (unsafe-ffi-primitive 'js-enable-style-sheets-for-set))

;; js-evaluate : ffi (string extern extern i32 extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-evaluate (unsafe-ffi-primitive 'js-evaluate))

;; js-exit-fullscreen : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-exit-fullscreen (unsafe-ffi-primitive 'js-exit-fullscreen))

;; js-exit-picture-in-picture : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-exit-picture-in-picture (unsafe-ffi-primitive 'js-exit-picture-in-picture))

;; js-exit-pointer-lock : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-exit-pointer-lock (unsafe-ffi-primitive 'js-exit-pointer-lock))

;; js-get-element-by-id : ffi (string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-element-by-id (unsafe-ffi-primitive 'js-get-element-by-id))

;; js-get-elements-by-class-name : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-elements-by-class-name (unsafe-ffi-primitive 'js-get-elements-by-class-name))

;; js-get-elements-by-name : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-elements-by-name (unsafe-ffi-primitive 'js-get-elements-by-name))

;; js-get-elements-by-tag-name : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-elements-by-tag-name (unsafe-ffi-primitive 'js-get-elements-by-tag-name))

;; js-get-elements-by-tag-name-ns : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-elements-by-tag-name-ns (unsafe-ffi-primitive 'js-get-elements-by-tag-name-ns))

;; js-get-selection : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-selection (unsafe-ffi-primitive 'js-get-selection))

;; js-has-focus : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-has-focus (unsafe-ffi-primitive 'js-has-focus))

;; js-import-node : ffi (extern i32) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-import-node (unsafe-ffi-primitive 'js-import-node))

;; js-open : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-open (unsafe-ffi-primitive 'js-open))

;; js-query-selector : ffi (string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-query-selector (unsafe-ffi-primitive 'js-query-selector))

;; js-query-selector-all : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-query-selector-all (unsafe-ffi-primitive 'js-query-selector-all))

;; js-release-events : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-release-events (unsafe-ffi-primitive 'js-release-events))

;; js-add-event-listener! : ffi (extern string extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-add-event-listener! (unsafe-ffi-primitive 'js-add-event-listener!))

;; js-event-new : ffi (string value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-new (unsafe-ffi-primitive 'js-event-new))

;; js-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event? (unsafe-ffi-primitive 'js-event?))

;; js-event-type : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-type (unsafe-ffi-primitive 'js-event-type))

;; js-event-target : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-target (unsafe-ffi-primitive 'js-event-target))

;; js-event-current-target : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-current-target (unsafe-ffi-primitive 'js-event-current-target))

;; js-event-event-phase : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-event-phase (unsafe-ffi-primitive 'js-event-event-phase))

;; js-event-bubbles : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-bubbles (unsafe-ffi-primitive 'js-event-bubbles))

;; js-event-cancelable : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-cancelable (unsafe-ffi-primitive 'js-event-cancelable))

;; js-event-default-prevented : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-default-prevented (unsafe-ffi-primitive 'js-event-default-prevented))

;; js-event-composed : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-composed (unsafe-ffi-primitive 'js-event-composed))

;; js-event-is-trusted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-is-trusted (unsafe-ffi-primitive 'js-event-is-trusted))

;; js-event-time-stamp : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-time-stamp (unsafe-ffi-primitive 'js-event-time-stamp))

;; js-event-composed-path : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-composed-path (unsafe-ffi-primitive 'js-event-composed-path))

;; js-event-prevent-default : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-prevent-default (unsafe-ffi-primitive 'js-event-prevent-default))

;; js-event-stop-propagation : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-stop-propagation (unsafe-ffi-primitive 'js-event-stop-propagation))

;; js-event-stop-immediate-propagation : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-event-stop-immediate-propagation (unsafe-ffi-primitive 'js-event-stop-immediate-propagation))

;; js-message-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-message-event? (unsafe-ffi-primitive 'js-message-event?))

;; js-message-event-data : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-message-event-data (unsafe-ffi-primitive 'js-message-event-data))

;; js-message-event-origin : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-message-event-origin (unsafe-ffi-primitive 'js-message-event-origin))

;; js-message-event-last-event-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-message-event-last-event-id (unsafe-ffi-primitive 'js-message-event-last-event-id))

;; js-message-event-source : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-message-event-source (unsafe-ffi-primitive 'js-message-event-source))

;; js-message-event-ports : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-message-event-ports (unsafe-ffi-primitive 'js-message-event-ports))

;; js-close-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-close-event? (unsafe-ffi-primitive 'js-close-event?))

;; js-close-event-was-clean : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-close-event-was-clean (unsafe-ffi-primitive 'js-close-event-was-clean))

;; js-close-event-code : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-close-event-code (unsafe-ffi-primitive 'js-close-event-code))

;; js-close-event-reason : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-close-event-reason (unsafe-ffi-primitive 'js-close-event-reason))

;; js-mouse-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event? (unsafe-ffi-primitive 'js-mouse-event?))

;; js-mouse-event-offset-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-offset-x (unsafe-ffi-primitive 'js-mouse-event-offset-x))

;; js-mouse-event-offset-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-offset-y (unsafe-ffi-primitive 'js-mouse-event-offset-y))

;; js-mouse-event-client-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-client-x (unsafe-ffi-primitive 'js-mouse-event-client-x))

;; js-mouse-event-client-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-client-y (unsafe-ffi-primitive 'js-mouse-event-client-y))

;; js-mouse-event-page-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-page-x (unsafe-ffi-primitive 'js-mouse-event-page-x))

;; js-mouse-event-page-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-page-y (unsafe-ffi-primitive 'js-mouse-event-page-y))

;; js-mouse-event-screen-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-screen-x (unsafe-ffi-primitive 'js-mouse-event-screen-x))

;; js-mouse-event-screen-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-screen-y (unsafe-ffi-primitive 'js-mouse-event-screen-y))

;; js-mouse-event-button : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-button (unsafe-ffi-primitive 'js-mouse-event-button))

;; js-mouse-event-buttons : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-buttons (unsafe-ffi-primitive 'js-mouse-event-buttons))

;; js-mouse-event-alt-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-alt-key (unsafe-ffi-primitive 'js-mouse-event-alt-key))

;; js-mouse-event-ctrl-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-ctrl-key (unsafe-ffi-primitive 'js-mouse-event-ctrl-key))

;; js-mouse-event-meta-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-meta-key (unsafe-ffi-primitive 'js-mouse-event-meta-key))

;; js-mouse-event-shift-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-mouse-event-shift-key (unsafe-ffi-primitive 'js-mouse-event-shift-key))

;; js-keyboard-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event? (unsafe-ffi-primitive 'js-keyboard-event?))

;; js-keyboard-event-key : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-key (unsafe-ffi-primitive 'js-keyboard-event-key))

;; js-keyboard-event-code : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-code (unsafe-ffi-primitive 'js-keyboard-event-code))

;; js-keyboard-event-alt-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-alt-key (unsafe-ffi-primitive 'js-keyboard-event-alt-key))

;; js-keyboard-event-ctrl-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-ctrl-key (unsafe-ffi-primitive 'js-keyboard-event-ctrl-key))

;; js-keyboard-event-meta-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-meta-key (unsafe-ffi-primitive 'js-keyboard-event-meta-key))

;; js-keyboard-event-shift-key : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-shift-key (unsafe-ffi-primitive 'js-keyboard-event-shift-key))

;; js-keyboard-event-repeat : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-keyboard-event-repeat (unsafe-ffi-primitive 'js-keyboard-event-repeat))

;; js-pointer-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-pointer-event? (unsafe-ffi-primitive 'js-pointer-event?))

;; js-focus-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-focus-event? (unsafe-ffi-primitive 'js-focus-event?))

;; js-input-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-input-event? (unsafe-ffi-primitive 'js-input-event?))

;; js-submit-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-submit-event? (unsafe-ffi-primitive 'js-submit-event?))

;; js-wheel-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-wheel-event? (unsafe-ffi-primitive 'js-wheel-event?))

;; js-touch-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-event? (unsafe-ffi-primitive 'js-touch-event?))

;; js-touch-event-touches : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-event-touches (unsafe-ffi-primitive 'js-touch-event-touches))

;; js-touch-event-target-touches : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-event-target-touches (unsafe-ffi-primitive 'js-touch-event-target-touches))

;; js-touch-event-changed-touches : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-event-changed-touches (unsafe-ffi-primitive 'js-touch-event-changed-touches))

;; js-touch-list? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-list? (unsafe-ffi-primitive 'js-touch-list?))

;; js-touch-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-list-length (unsafe-ffi-primitive 'js-touch-list-length))

;; js-touch-list-ref : ffi (extern u32) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-list-ref (unsafe-ffi-primitive 'js-touch-list-ref))

;; js-touch? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch? (unsafe-ffi-primitive 'js-touch?))

;; js-touch-identifier : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-identifier (unsafe-ffi-primitive 'js-touch-identifier))

;; js-touch-client-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-client-x (unsafe-ffi-primitive 'js-touch-client-x))

;; js-touch-client-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-client-y (unsafe-ffi-primitive 'js-touch-client-y))

;; js-touch-page-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-page-x (unsafe-ffi-primitive 'js-touch-page-x))

;; js-touch-page-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-page-y (unsafe-ffi-primitive 'js-touch-page-y))

;; js-touch-screen-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-screen-x (unsafe-ffi-primitive 'js-touch-screen-x))

;; js-touch-screen-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-touch-screen-y (unsafe-ffi-primitive 'js-touch-screen-y))

;; js-dom-rect-left : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-rect-left (unsafe-ffi-primitive 'js-dom-rect-left))

;; js-dom-rect-top : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-rect-top (unsafe-ffi-primitive 'js-dom-rect-top))

;; js-dom-rect-width : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-rect-width (unsafe-ffi-primitive 'js-dom-rect-width))

;; js-dom-rect-height : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-rect-height (unsafe-ffi-primitive 'js-dom-rect-height))

;; js-element-class-list : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-class-list (unsafe-ffi-primitive 'js-element-class-list))

;; js-element-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-id (unsafe-ffi-primitive 'js-element-id))

;; js-set-element-id! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-id! (unsafe-ffi-primitive 'js-set-element-id!))

;; js-element-class-name : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-class-name (unsafe-ffi-primitive 'js-element-class-name))

;; js-set-element-class-name! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-class-name! (unsafe-ffi-primitive 'js-set-element-class-name!))

;; js-element-tag-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-tag-name (unsafe-ffi-primitive 'js-element-tag-name))

;; js-element-local-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-local-name (unsafe-ffi-primitive 'js-element-local-name))

;; js-element-namespace-uri : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-namespace-uri (unsafe-ffi-primitive 'js-element-namespace-uri))

;; js-element-prefix : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-prefix (unsafe-ffi-primitive 'js-element-prefix))

;; js-element-is-connected : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-is-connected (unsafe-ffi-primitive 'js-element-is-connected))

;; js-element-children : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-children (unsafe-ffi-primitive 'js-element-children))

;; js-element-scroll-top : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-scroll-top (unsafe-ffi-primitive 'js-element-scroll-top))

;; js-set-element-scroll-top! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-scroll-top! (unsafe-ffi-primitive 'js-set-element-scroll-top!))

;; js-element-scroll-left : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-scroll-left (unsafe-ffi-primitive 'js-element-scroll-left))

;; js-set-element-scroll-left! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-scroll-left! (unsafe-ffi-primitive 'js-set-element-scroll-left!))

;; js-element-scroll-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-scroll-width (unsafe-ffi-primitive 'js-element-scroll-width))

;; js-element-scroll-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-scroll-height (unsafe-ffi-primitive 'js-element-scroll-height))

;; js-element-client-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-client-width (unsafe-ffi-primitive 'js-element-client-width))

;; js-element-client-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-client-height (unsafe-ffi-primitive 'js-element-client-height))

;; js-element-offset-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-offset-width (unsafe-ffi-primitive 'js-element-offset-width))

;; js-element-offset-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-offset-height (unsafe-ffi-primitive 'js-element-offset-height))

;; js-element-child-element-count : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-child-element-count (unsafe-ffi-primitive 'js-element-child-element-count))

;; js-element-first-element-child : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-first-element-child (unsafe-ffi-primitive 'js-element-first-element-child))

;; js-element-last-element-child : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-last-element-child (unsafe-ffi-primitive 'js-element-last-element-child))

;; js-element-parent-element : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-parent-element (unsafe-ffi-primitive 'js-element-parent-element))

;; js-element-previous-element-sibling : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-previous-element-sibling (unsafe-ffi-primitive 'js-element-previous-element-sibling))

;; js-element-next-element-sibling : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-next-element-sibling (unsafe-ffi-primitive 'js-element-next-element-sibling))

;; js-element-inner-html : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-inner-html (unsafe-ffi-primitive 'js-element-inner-html))

;; js-set-element-inner-html! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-inner-html! (unsafe-ffi-primitive 'js-set-element-inner-html!))

;; js-element-outer-html : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-outer-html (unsafe-ffi-primitive 'js-element-outer-html))

;; js-set-element-outer-html! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-outer-html! (unsafe-ffi-primitive 'js-set-element-outer-html!))

;; js-element-text-content : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-text-content (unsafe-ffi-primitive 'js-element-text-content))

;; js-set-element-text-content! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-element-text-content! (unsafe-ffi-primitive 'js-set-element-text-content!))

;; js-element-shadow-root : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-shadow-root (unsafe-ffi-primitive 'js-element-shadow-root))

;; js-dom-token-list-value : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-token-list-value (unsafe-ffi-primitive 'js-dom-token-list-value))

;; js-dom-token-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-token-list-length (unsafe-ffi-primitive 'js-dom-token-list-length))

;; js-node-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-node-list-length (unsafe-ffi-primitive 'js-node-list-length))

;; js-node-list-item : ffi (extern i32) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-node-list-item (unsafe-ffi-primitive 'js-node-list-item))

;; js-html-collection-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-html-collection-length (unsafe-ffi-primitive 'js-html-collection-length))

;; js-html-collection-item : ffi (extern i32) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-html-collection-item (unsafe-ffi-primitive 'js-html-collection-item))

;; js-html-collection-named-item : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-html-collection-named-item (unsafe-ffi-primitive 'js-html-collection-named-item))

;; js-shadow-root-host : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-shadow-root-host (unsafe-ffi-primitive 'js-shadow-root-host))

;; js-shadow-root-mode : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-shadow-root-mode (unsafe-ffi-primitive 'js-shadow-root-mode))

;; js-shadow-root-delegates-focus : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-shadow-root-delegates-focus (unsafe-ffi-primitive 'js-shadow-root-delegates-focus))

;; js-dom-rect-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-rect-list-length (unsafe-ffi-primitive 'js-dom-rect-list-length))

;; js-dom-rect-list-item : ffi (extern i32) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-rect-list-item (unsafe-ffi-primitive 'js-dom-rect-list-item))

;; js-append-child! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-append-child! (unsafe-ffi-primitive 'js-append-child!))

;; js-set-attribute! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-attribute! (unsafe-ffi-primitive 'js-set-attribute!))

;; js-after! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-after! (unsafe-ffi-primitive 'js-after!))

;; js-animate : ffi (extern extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-animate (unsafe-ffi-primitive 'js-animate))

;; js-append! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-append! (unsafe-ffi-primitive 'js-append!))

;; js-attach-shadow! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-attach-shadow! (unsafe-ffi-primitive 'js-attach-shadow!))

;; js-before! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-before! (unsafe-ffi-primitive 'js-before!))

;; js-closest : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-closest (unsafe-ffi-primitive 'js-closest))

;; js-computed-style-map : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-computed-style-map (unsafe-ffi-primitive 'js-computed-style-map))

;; js-get-animations : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-animations (unsafe-ffi-primitive 'js-get-animations))

;; js-get-attribute : ffi (extern string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-attribute (unsafe-ffi-primitive 'js-get-attribute))

;; js-get-attribute-ns : ffi (extern string string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-attribute-ns (unsafe-ffi-primitive 'js-get-attribute-ns))

;; js-get-attribute-names : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-attribute-names (unsafe-ffi-primitive 'js-get-attribute-names))

;; js-dom-token-list-item : ffi (extern i32) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-dom-token-list-item (unsafe-ffi-primitive 'js-dom-token-list-item))

;; js-get-attribute-node : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-attribute-node (unsafe-ffi-primitive 'js-get-attribute-node))

;; js-get-attribute-node-ns : ffi (extern string string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-attribute-node-ns (unsafe-ffi-primitive 'js-get-attribute-node-ns))

;; js-get-bounding-client-rect : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-bounding-client-rect (unsafe-ffi-primitive 'js-get-bounding-client-rect))

;; js-get-client-rects : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-get-client-rects (unsafe-ffi-primitive 'js-get-client-rects))

;; js-element-get-elements-by-class-name : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-get-elements-by-class-name (unsafe-ffi-primitive 'js-element-get-elements-by-class-name))

;; js-element-get-elements-by-tag-name : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-get-elements-by-tag-name (unsafe-ffi-primitive 'js-element-get-elements-by-tag-name))

;; js-element-get-elements-by-tag-name-ns : ffi (extern string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-get-elements-by-tag-name-ns (unsafe-ffi-primitive 'js-element-get-elements-by-tag-name-ns))

;; js-has-attribute : ffi (extern string) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-has-attribute (unsafe-ffi-primitive 'js-has-attribute))

;; js-has-attribute-ns : ffi (extern string string) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-has-attribute-ns (unsafe-ffi-primitive 'js-has-attribute-ns))

;; js-has-attributes : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-has-attributes (unsafe-ffi-primitive 'js-has-attributes))

;; js-has-pointer-capture : ffi (extern i32) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-has-pointer-capture (unsafe-ffi-primitive 'js-has-pointer-capture))

;; js-insert-adjacent-element! : ffi (extern string extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-insert-adjacent-element! (unsafe-ffi-primitive 'js-insert-adjacent-element!))

;; js-insert-adjacent-html! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-insert-adjacent-html! (unsafe-ffi-primitive 'js-insert-adjacent-html!))

;; js-insert-adjacent-text! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-insert-adjacent-text! (unsafe-ffi-primitive 'js-insert-adjacent-text!))

;; js-matches : ffi (extern string) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-matches (unsafe-ffi-primitive 'js-matches))

;; js-prepend! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-prepend! (unsafe-ffi-primitive 'js-prepend!))

;; js-element-query-selector : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-query-selector (unsafe-ffi-primitive 'js-element-query-selector))

;; js-element-query-selector-all : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-element-query-selector-all (unsafe-ffi-primitive 'js-element-query-selector-all))

;; js-release-pointer-capture! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-release-pointer-capture! (unsafe-ffi-primitive 'js-release-pointer-capture!))

;; js-remove! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-remove! (unsafe-ffi-primitive 'js-remove!))

;; js-remove-attribute! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-remove-attribute! (unsafe-ffi-primitive 'js-remove-attribute!))

;; js-remove-attribute-ns! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-remove-attribute-ns! (unsafe-ffi-primitive 'js-remove-attribute-ns!))

;; js-remove-attribute-node! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-remove-attribute-node! (unsafe-ffi-primitive 'js-remove-attribute-node!))

;; js-replace-children! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-replace-children! (unsafe-ffi-primitive 'js-replace-children!))

;; js-replace-with! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-replace-with! (unsafe-ffi-primitive 'js-replace-with!))

;; js-request-fullscreen : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-request-fullscreen (unsafe-ffi-primitive 'js-request-fullscreen))

;; js-request-pointer-lock : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-request-pointer-lock (unsafe-ffi-primitive 'js-request-pointer-lock))

;; js-scroll! : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-scroll! (unsafe-ffi-primitive 'js-scroll!))

;; js-scroll-by! : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-scroll-by! (unsafe-ffi-primitive 'js-scroll-by!))

;; js-scroll-into-view! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-scroll-into-view! (unsafe-ffi-primitive 'js-scroll-into-view!))

;; js-scroll-to! : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-scroll-to! (unsafe-ffi-primitive 'js-scroll-to!))

;; js-set-attribute-ns! : ffi (extern string string string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-attribute-ns! (unsafe-ffi-primitive 'js-set-attribute-ns!))

;; js-set-attribute-node! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-attribute-node! (unsafe-ffi-primitive 'js-set-attribute-node!))

;; js-set-attribute-node-ns! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-attribute-node-ns! (unsafe-ffi-primitive 'js-set-attribute-node-ns!))

;; js-set-pointer-capture! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-pointer-capture! (unsafe-ffi-primitive 'js-set-pointer-capture!))

;; js-toggle-attribute! : ffi (extern string i32) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-toggle-attribute! (unsafe-ffi-primitive 'js-toggle-attribute!))

;; js-toggle-attribute : ffi (extern string) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-toggle-attribute (unsafe-ffi-primitive 'js-toggle-attribute))

;; js-global-this : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-global-this (unsafe-ffi-primitive 'js-global-this))

;; js-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-infinity (unsafe-ffi-primitive 'js-infinity))

;; js-nan : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-nan (unsafe-ffi-primitive 'js-nan))

;; js-undefined : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-undefined (unsafe-ffi-primitive 'js-undefined))

;; js-nullish? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-nullish? (unsafe-ffi-primitive 'js-nullish?))

;; js-null? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-null? (unsafe-ffi-primitive 'js-null?))

;; js-undefined? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-undefined? (unsafe-ffi-primitive 'js-undefined?))

;; js-truthy? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-truthy? (unsafe-ffi-primitive 'js-truthy?))

;; js-eval : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-eval (unsafe-ffi-primitive 'js-eval))

;; js-is-finite : ffi (f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-is-finite (unsafe-ffi-primitive 'js-is-finite))

;; js-finite? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-finite? (unsafe-ffi-primitive 'js-finite?))

;; js-is-nan : ffi (f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-is-nan (unsafe-ffi-primitive 'js-is-nan))

;; js-nan? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-nan? (unsafe-ffi-primitive 'js-nan?))

;; js-parse-float : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-parse-float (unsafe-ffi-primitive 'js-parse-float))

;; js-parse-int : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-parse-int (unsafe-ffi-primitive 'js-parse-int))

;; js-decode-uri : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-decode-uri (unsafe-ffi-primitive 'js-decode-uri))

;; js-decode-uri-component : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-decode-uri-component (unsafe-ffi-primitive 'js-decode-uri-component))

;; js-encode-uri : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-encode-uri (unsafe-ffi-primitive 'js-encode-uri))

;; js-encode-uri-component : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-encode-uri-component (unsafe-ffi-primitive 'js-encode-uri-component))

;; js-var : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-var (unsafe-ffi-primitive 'js-var))

;; js-ref/extern : ffi (extern string/symbol) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-ref/extern (unsafe-ffi-primitive 'js-ref/extern))

;; js-ref : ffi (extern string/symbol) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-ref (unsafe-ffi-primitive 'js-ref))

;; js-set! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set! (unsafe-ffi-primitive 'js-set!))

;; js-index : ffi (extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-index (unsafe-ffi-primitive 'js-index))

;; js-assign! : ffi (string/symbol value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-assign! (unsafe-ffi-primitive 'js-assign!))

;; js-new : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-new (unsafe-ffi-primitive 'js-new))

;; js-send : ffi (extern string/symbol value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send (unsafe-ffi-primitive 'js-send))

;; js-send/extern : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/extern (unsafe-ffi-primitive 'js-send/extern))

;; js-send/extern/null : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/extern/null (unsafe-ffi-primitive 'js-send/extern/null))

;; js-send/extern/undefined : ffi (extern string/symbol value) -> (extern/undefined)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/extern/undefined (unsafe-ffi-primitive 'js-send/extern/undefined))

;; js-send/extern/nullish : ffi (extern string/symbol value) -> (extern/nullish)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/extern/nullish (unsafe-ffi-primitive 'js-send/extern/nullish))

;; js-send/value : ffi (extern string/symbol value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/value (unsafe-ffi-primitive 'js-send/value))

;; js-send/boolean : ffi (extern string/symbol value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/boolean (unsafe-ffi-primitive 'js-send/boolean))

;; js-send/truthy : ffi (extern string/symbol value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/truthy (unsafe-ffi-primitive 'js-send/truthy))

;; js-send/flonum : ffi (extern string/symbol value) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-send/flonum (unsafe-ffi-primitive 'js-send/flonum))

;; js-throw : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-throw (unsafe-ffi-primitive 'js-throw))

;; js-null : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-null (unsafe-ffi-primitive 'js-null))

;; js-this : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-this (unsafe-ffi-primitive 'js-this))

;; js-object : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-object (unsafe-ffi-primitive 'js-object))

;; js-Array : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Array (unsafe-ffi-primitive 'js-Array))

;; js-typeof : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-typeof (unsafe-ffi-primitive 'js-typeof))

;; js-constructible? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-constructible? (unsafe-ffi-primitive 'js-constructible?))

;; js-value->string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-value->string (unsafe-ffi-primitive 'js-value->string))

;; js-instanceof : ffi (extern extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-instanceof (unsafe-ffi-primitive 'js-instanceof))

;; js-operator : ffi (string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-operator (unsafe-ffi-primitive 'js-operator))

;; js-Object : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Object (unsafe-ffi-primitive 'js-Object))

;; js-Function : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Function (unsafe-ffi-primitive 'js-Function))

;; js-Boolean : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Boolean (unsafe-ffi-primitive 'js-Boolean))

;; js-Symbol : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Symbol (unsafe-ffi-primitive 'js-Symbol))

;; js-Error : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Error (unsafe-ffi-primitive 'js-Error))

;; js-AggregateError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-AggregateError (unsafe-ffi-primitive 'js-AggregateError))

;; js-EvalError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-EvalError (unsafe-ffi-primitive 'js-EvalError))

;; js-RangeError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-RangeError (unsafe-ffi-primitive 'js-RangeError))

;; js-ReferenceError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-ReferenceError (unsafe-ffi-primitive 'js-ReferenceError))

;; js-SuppressedError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-SuppressedError (unsafe-ffi-primitive 'js-SuppressedError))

;; js-SyntaxError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-SyntaxError (unsafe-ffi-primitive 'js-SyntaxError))

;; js-TypeError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-TypeError (unsafe-ffi-primitive 'js-TypeError))

;; js-URIError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-URIError (unsafe-ffi-primitive 'js-URIError))

;; js-InternalError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-InternalError (unsafe-ffi-primitive 'js-InternalError))

;; js-Number : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Number (unsafe-ffi-primitive 'js-Number))

;; js-BigInt : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-BigInt (unsafe-ffi-primitive 'js-BigInt))

;; js-Math : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Math (unsafe-ffi-primitive 'js-Math))

;; js-Date : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Date (unsafe-ffi-primitive 'js-Date))

;; js-Temporal : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Temporal (unsafe-ffi-primitive 'js-Temporal))

;; js-number-epsilon : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-epsilon (unsafe-ffi-primitive 'js-number-epsilon))

;; js-number-max-safe-integer : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-max-safe-integer (unsafe-ffi-primitive 'js-number-max-safe-integer))

;; js-number-max-value : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-max-value (unsafe-ffi-primitive 'js-number-max-value))

;; js-number-min-safe-integer : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-min-safe-integer (unsafe-ffi-primitive 'js-number-min-safe-integer))

;; js-number-min-value : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-min-value (unsafe-ffi-primitive 'js-number-min-value))

;; js-number-nan : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-nan (unsafe-ffi-primitive 'js-number-nan))

;; js-number-negative-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-negative-infinity (unsafe-ffi-primitive 'js-number-negative-infinity))

;; js-number-positive-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-positive-infinity (unsafe-ffi-primitive 'js-number-positive-infinity))

;; js-number-finite? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-finite? (unsafe-ffi-primitive 'js-number-finite?))

;; js-number-integer? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-integer? (unsafe-ffi-primitive 'js-number-integer?))

;; js-number-nan? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-nan? (unsafe-ffi-primitive 'js-number-nan?))

;; js-number-safe-integer? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-safe-integer? (unsafe-ffi-primitive 'js-number-safe-integer?))

;; js-number-parse-float : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-parse-float (unsafe-ffi-primitive 'js-number-parse-float))

;; js-number-parse-int : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-parse-int (unsafe-ffi-primitive 'js-number-parse-int))

;; js-number-to-exponential : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-to-exponential (unsafe-ffi-primitive 'js-number-to-exponential))

;; js-number-to-fixed : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-to-fixed (unsafe-ffi-primitive 'js-number-to-fixed))

;; js-number-to-locale-string : ffi (f64 value value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-to-locale-string (unsafe-ffi-primitive 'js-number-to-locale-string))

;; js-number-to-precision : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-to-precision (unsafe-ffi-primitive 'js-number-to-precision))

;; js-number-to-string : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-to-string (unsafe-ffi-primitive 'js-number-to-string))

;; js-number-value-of : ffi (f64) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-number-value-of (unsafe-ffi-primitive 'js-number-value-of))

;; js-String : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-String (unsafe-ffi-primitive 'js-String))

;; js-RegExp : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-RegExp (unsafe-ffi-primitive 'js-RegExp))

;; js-array : ffi (value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array (unsafe-ffi-primitive 'js-array))

;; js-array/extern : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array/extern (unsafe-ffi-primitive 'js-array/extern))

;; js-TypedArray : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-TypedArray (unsafe-ffi-primitive 'js-TypedArray))

;; js-Int8Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Int8Array (unsafe-ffi-primitive 'js-Int8Array))

;; js-Uint8Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Uint8Array (unsafe-ffi-primitive 'js-Uint8Array))

;; js-Uint8ClampedArray : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Uint8ClampedArray (unsafe-ffi-primitive 'js-Uint8ClampedArray))

;; js-Int16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Int16Array (unsafe-ffi-primitive 'js-Int16Array))

;; js-Uint16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Uint16Array (unsafe-ffi-primitive 'js-Uint16Array))

;; js-Int32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Int32Array (unsafe-ffi-primitive 'js-Int32Array))

;; js-Uint32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Uint32Array (unsafe-ffi-primitive 'js-Uint32Array))

;; js-BigInt64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-BigInt64Array (unsafe-ffi-primitive 'js-BigInt64Array))

;; js-BigUint64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-BigUint64Array (unsafe-ffi-primitive 'js-BigUint64Array))

;; js-Float16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Float16Array (unsafe-ffi-primitive 'js-Float16Array))

;; js-Float32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Float32Array (unsafe-ffi-primitive 'js-Float32Array))

;; js-Float64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Float64Array (unsafe-ffi-primitive 'js-Float64Array))

;; js-Map : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Map (unsafe-ffi-primitive 'js-Map))

;; js-Set : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Set (unsafe-ffi-primitive 'js-Set))

;; js-WeakMap : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-WeakMap (unsafe-ffi-primitive 'js-WeakMap))

;; js-WeakSet : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-WeakSet (unsafe-ffi-primitive 'js-WeakSet))

;; js-ArrayBuffer : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-ArrayBuffer (unsafe-ffi-primitive 'js-ArrayBuffer))

;; js-SharedArrayBuffer : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-SharedArrayBuffer (unsafe-ffi-primitive 'js-SharedArrayBuffer))

;; js-DataView : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-DataView (unsafe-ffi-primitive 'js-DataView))

;; js-Atomics : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Atomics (unsafe-ffi-primitive 'js-Atomics))

;; js-JSON : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-JSON (unsafe-ffi-primitive 'js-JSON))

;; js-WeakRef : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-WeakRef (unsafe-ffi-primitive 'js-WeakRef))

;; js-FinalizationRegistry : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-FinalizationRegistry (unsafe-ffi-primitive 'js-FinalizationRegistry))

;; js-Iterator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Iterator (unsafe-ffi-primitive 'js-Iterator))

;; js-AsyncIterator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-AsyncIterator (unsafe-ffi-primitive 'js-AsyncIterator))

;; js-Promise : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Promise (unsafe-ffi-primitive 'js-Promise))

;; js-GeneratorFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-GeneratorFunction (unsafe-ffi-primitive 'js-GeneratorFunction))

;; js-AsyncGeneratorFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-AsyncGeneratorFunction (unsafe-ffi-primitive 'js-AsyncGeneratorFunction))

;; js-Generator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Generator (unsafe-ffi-primitive 'js-Generator))

;; js-AsyncGenerator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-AsyncGenerator (unsafe-ffi-primitive 'js-AsyncGenerator))

;; js-AsyncFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-AsyncFunction (unsafe-ffi-primitive 'js-AsyncFunction))

;; js-DisposableStack : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-DisposableStack (unsafe-ffi-primitive 'js-DisposableStack))

;; js-AsyncDisposableStack : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-AsyncDisposableStack (unsafe-ffi-primitive 'js-AsyncDisposableStack))

;; js-Reflect : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Reflect (unsafe-ffi-primitive 'js-Reflect))

;; js-Proxy : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Proxy (unsafe-ffi-primitive 'js-Proxy))

;; js-Intl : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-Intl (unsafe-ffi-primitive 'js-Intl))

;; js-IntlCollator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlCollator (unsafe-ffi-primitive 'js-IntlCollator))

;; js-IntlDateTimeFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlDateTimeFormat (unsafe-ffi-primitive 'js-IntlDateTimeFormat))

;; js-IntlDisplayNames : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlDisplayNames (unsafe-ffi-primitive 'js-IntlDisplayNames))

;; js-IntlDurationFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlDurationFormat (unsafe-ffi-primitive 'js-IntlDurationFormat))

;; js-IntlListFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlListFormat (unsafe-ffi-primitive 'js-IntlListFormat))

;; js-IntlLocale : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlLocale (unsafe-ffi-primitive 'js-IntlLocale))

;; js-IntlNumberFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlNumberFormat (unsafe-ffi-primitive 'js-IntlNumberFormat))

;; js-IntlPluralRules : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlPluralRules (unsafe-ffi-primitive 'js-IntlPluralRules))

;; js-IntlRelativeTimeFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlRelativeTimeFormat (unsafe-ffi-primitive 'js-IntlRelativeTimeFormat))

;; js-IntlSegmenter : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-IntlSegmenter (unsafe-ffi-primitive 'js-IntlSegmenter))

;; js-array-from : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-from (unsafe-ffi-primitive 'js-array-from))

;; js-array-from-async : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-from-async (unsafe-ffi-primitive 'js-array-from-async))

;; js-array-is-array : ffi (value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-is-array (unsafe-ffi-primitive 'js-array-is-array))

;; js-array->vector : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array->vector (unsafe-ffi-primitive 'js-array->vector))

;; js-array->bytes : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array->bytes (unsafe-ffi-primitive 'js-array->bytes))

;; js-array-of : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-of (unsafe-ffi-primitive 'js-array-of))

;; js-array-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-length (unsafe-ffi-primitive 'js-array-length))

;; js-set-array-length! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-array-length! (unsafe-ffi-primitive 'js-set-array-length!))

;; js-array-ref : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-ref (unsafe-ffi-primitive 'js-array-ref))

;; js-array-at : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-at (unsafe-ffi-primitive 'js-array-at))

;; js-array-concat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-concat (unsafe-ffi-primitive 'js-array-concat))

;; js-array-copy-within : ffi (extern i32 i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-copy-within (unsafe-ffi-primitive 'js-array-copy-within))

;; js-array-entries : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-entries (unsafe-ffi-primitive 'js-array-entries))

;; js-array-every : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-every (unsafe-ffi-primitive 'js-array-every))

;; js-array-fill : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-fill (unsafe-ffi-primitive 'js-array-fill))

;; js-array-filter : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-filter (unsafe-ffi-primitive 'js-array-filter))

;; js-array-find : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-find (unsafe-ffi-primitive 'js-array-find))

;; js-array-find-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-find-index (unsafe-ffi-primitive 'js-array-find-index))

;; js-array-find-last : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-find-last (unsafe-ffi-primitive 'js-array-find-last))

;; js-array-find-last-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-find-last-index (unsafe-ffi-primitive 'js-array-find-last-index))

;; js-array-flat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-flat (unsafe-ffi-primitive 'js-array-flat))

;; js-array-flat-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-flat-map (unsafe-ffi-primitive 'js-array-flat-map))

;; js-array-for-each : ffi (extern extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-for-each (unsafe-ffi-primitive 'js-array-for-each))

;; js-array-includes : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-includes (unsafe-ffi-primitive 'js-array-includes))

;; js-array-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-index-of (unsafe-ffi-primitive 'js-array-index-of))

;; js-array-join : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-join (unsafe-ffi-primitive 'js-array-join))

;; js-array-keys : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-keys (unsafe-ffi-primitive 'js-array-keys))

;; js-array-last-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-last-index-of (unsafe-ffi-primitive 'js-array-last-index-of))

;; js-array-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-map (unsafe-ffi-primitive 'js-array-map))

;; js-array-pop : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-pop (unsafe-ffi-primitive 'js-array-pop))

;; js-array-push : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-push (unsafe-ffi-primitive 'js-array-push))

;; js-array-reduce : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-reduce (unsafe-ffi-primitive 'js-array-reduce))

;; js-array-reduce-right : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-reduce-right (unsafe-ffi-primitive 'js-array-reduce-right))

;; js-array-reverse : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-reverse (unsafe-ffi-primitive 'js-array-reverse))

;; js-array-shift : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-shift (unsafe-ffi-primitive 'js-array-shift))

;; js-array-slice : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-slice (unsafe-ffi-primitive 'js-array-slice))

;; js-array-some : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-some (unsafe-ffi-primitive 'js-array-some))

;; js-array-sort : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-sort (unsafe-ffi-primitive 'js-array-sort))

;; js-array-splice : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-splice (unsafe-ffi-primitive 'js-array-splice))

;; js-array-to-locale-string : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-to-locale-string (unsafe-ffi-primitive 'js-array-to-locale-string))

;; js-array-to-string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-to-string (unsafe-ffi-primitive 'js-array-to-string))

;; js-array-unshift : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-unshift (unsafe-ffi-primitive 'js-array-unshift))

;; js-array-values : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-values (unsafe-ffi-primitive 'js-array-values))

;; js-array-to-reversed : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-to-reversed (unsafe-ffi-primitive 'js-array-to-reversed))

;; js-array-to-sorted : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-to-sorted (unsafe-ffi-primitive 'js-array-to-sorted))

;; js-array-to-spliced : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-to-spliced (unsafe-ffi-primitive 'js-array-to-spliced))

;; js-array-with : ffi (extern i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-array-with (unsafe-ffi-primitive 'js-array-with))

;; js-media-audio-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-audio-tracks (unsafe-ffi-primitive 'js-media-audio-tracks))

;; js-media-autoplay : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-autoplay (unsafe-ffi-primitive 'js-media-autoplay))

;; js-set-media-autoplay! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-autoplay! (unsafe-ffi-primitive 'js-set-media-autoplay!))

;; js-media-buffered : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-buffered (unsafe-ffi-primitive 'js-media-buffered))

;; js-media-controls : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-controls (unsafe-ffi-primitive 'js-media-controls))

;; js-set-media-controls! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-controls! (unsafe-ffi-primitive 'js-set-media-controls!))

;; js-media-controls-list : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-controls-list (unsafe-ffi-primitive 'js-media-controls-list))

;; js-media-cross-origin : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-cross-origin (unsafe-ffi-primitive 'js-media-cross-origin))

;; js-set-media-cross-origin! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-cross-origin! (unsafe-ffi-primitive 'js-set-media-cross-origin!))

;; js-media-current-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-current-src (unsafe-ffi-primitive 'js-media-current-src))

;; js-media-current-time : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-current-time (unsafe-ffi-primitive 'js-media-current-time))

;; js-set-media-current-time! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-current-time! (unsafe-ffi-primitive 'js-set-media-current-time!))

;; js-media-default-muted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-default-muted (unsafe-ffi-primitive 'js-media-default-muted))

;; js-set-media-default-muted! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-default-muted! (unsafe-ffi-primitive 'js-set-media-default-muted!))

;; js-media-default-playback-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-default-playback-rate (unsafe-ffi-primitive 'js-media-default-playback-rate))

;; js-set-media-default-playback-rate! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-default-playback-rate! (unsafe-ffi-primitive 'js-set-media-default-playback-rate!))

;; js-media-disable-remote-playback : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-disable-remote-playback (unsafe-ffi-primitive 'js-media-disable-remote-playback))

;; js-set-media-disable-remote-playback! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-disable-remote-playback! (unsafe-ffi-primitive 'js-set-media-disable-remote-playback!))

;; js-media-duration : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-duration (unsafe-ffi-primitive 'js-media-duration))

;; js-media-ended : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-ended (unsafe-ffi-primitive 'js-media-ended))

;; js-media-error : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-error (unsafe-ffi-primitive 'js-media-error))

;; js-media-loop : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-loop (unsafe-ffi-primitive 'js-media-loop))

;; js-set-media-loop! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-loop! (unsafe-ffi-primitive 'js-set-media-loop!))

;; js-media-media-keys : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-media-keys (unsafe-ffi-primitive 'js-media-media-keys))

;; js-media-media-group : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-media-group (unsafe-ffi-primitive 'js-media-media-group))

;; js-set-media-media-group! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-media-group! (unsafe-ffi-primitive 'js-set-media-media-group!))

;; js-media-muted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-muted (unsafe-ffi-primitive 'js-media-muted))

;; js-set-media-muted! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-muted! (unsafe-ffi-primitive 'js-set-media-muted!))

;; js-media-network-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-network-state (unsafe-ffi-primitive 'js-media-network-state))

;; js-media-paused : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-paused (unsafe-ffi-primitive 'js-media-paused))

;; js-media-playback-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-playback-rate (unsafe-ffi-primitive 'js-media-playback-rate))

;; js-set-media-playback-rate! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-playback-rate! (unsafe-ffi-primitive 'js-set-media-playback-rate!))

;; js-media-played : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-played (unsafe-ffi-primitive 'js-media-played))

;; js-media-preload : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-preload (unsafe-ffi-primitive 'js-media-preload))

;; js-set-media-preload! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-preload! (unsafe-ffi-primitive 'js-set-media-preload!))

;; js-media-preserves-pitch : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-preserves-pitch (unsafe-ffi-primitive 'js-media-preserves-pitch))

;; js-set-media-preserves-pitch! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-preserves-pitch! (unsafe-ffi-primitive 'js-set-media-preserves-pitch!))

;; js-media-ready-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-ready-state (unsafe-ffi-primitive 'js-media-ready-state))

;; js-media-seekable : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-seekable (unsafe-ffi-primitive 'js-media-seekable))

;; js-media-seeking : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-seeking (unsafe-ffi-primitive 'js-media-seeking))

;; js-media-sink-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-sink-id (unsafe-ffi-primitive 'js-media-sink-id))

;; js-media-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-src (unsafe-ffi-primitive 'js-media-src))

;; js-set-media-src! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-src! (unsafe-ffi-primitive 'js-set-media-src!))

;; js-media-src-object : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-src-object (unsafe-ffi-primitive 'js-media-src-object))

;; js-set-media-src-object! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-src-object! (unsafe-ffi-primitive 'js-set-media-src-object!))

;; js-media-text-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-text-tracks (unsafe-ffi-primitive 'js-media-text-tracks))

;; js-media-video-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-video-tracks (unsafe-ffi-primitive 'js-media-video-tracks))

;; js-media-volume : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-volume (unsafe-ffi-primitive 'js-media-volume))

;; js-set-media-volume! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-media-volume! (unsafe-ffi-primitive 'js-set-media-volume!))

;; js-media-add-text-track! : ffi (extern string value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-add-text-track! (unsafe-ffi-primitive 'js-media-add-text-track!))

;; js-media-can-play-type : ffi (extern string) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-can-play-type (unsafe-ffi-primitive 'js-media-can-play-type))

;; js-media-capture-stream : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-capture-stream (unsafe-ffi-primitive 'js-media-capture-stream))

;; js-media-fast-seek! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-fast-seek! (unsafe-ffi-primitive 'js-media-fast-seek!))

;; js-media-load! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-load! (unsafe-ffi-primitive 'js-media-load!))

;; js-media-pause : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-pause (unsafe-ffi-primitive 'js-media-pause))

;; js-media-play : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-play (unsafe-ffi-primitive 'js-media-play))

;; js-media-set-media-keys! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-set-media-keys! (unsafe-ffi-primitive 'js-media-set-media-keys!))

;; js-media-set-sink-id! : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-media-set-sink-id! (unsafe-ffi-primitive 'js-media-set-sink-id!))

;; js-canvas-capture-stream : ffi (extern f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-capture-stream (unsafe-ffi-primitive 'js-canvas-capture-stream))

;; js-canvas-get-context : ffi (extern string extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-get-context (unsafe-ffi-primitive 'js-canvas-get-context))

;; js-canvas-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-height (unsafe-ffi-primitive 'js-canvas-height))

;; js-set-canvas-height! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas-height! (unsafe-ffi-primitive 'js-set-canvas-height!))

;; js-canvas-to-blob : ffi (extern extern string f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-to-blob (unsafe-ffi-primitive 'js-canvas-to-blob))

;; js-canvas-to-data-url : ffi (extern string f64) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-to-data-url (unsafe-ffi-primitive 'js-canvas-to-data-url))

;; js-canvas-transfer-control-to-offscreen : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-transfer-control-to-offscreen (unsafe-ffi-primitive 'js-canvas-transfer-control-to-offscreen))

;; js-canvas-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-width (unsafe-ffi-primitive 'js-canvas-width))

;; js-set-canvas-width! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas-width! (unsafe-ffi-primitive 'js-set-canvas-width!))

;; js-canvas2d-canvas : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-canvas (unsafe-ffi-primitive 'js-canvas2d-canvas))

;; js-canvas2d-direction : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-direction (unsafe-ffi-primitive 'js-canvas2d-direction))

;; js-set-canvas2d-direction! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-direction! (unsafe-ffi-primitive 'js-set-canvas2d-direction!))

;; js-canvas2d-fill-style : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-fill-style (unsafe-ffi-primitive 'js-canvas2d-fill-style))

;; js-set-canvas2d-fill-style! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-fill-style! (unsafe-ffi-primitive 'js-set-canvas2d-fill-style!))

;; js-canvas2d-filter : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-filter (unsafe-ffi-primitive 'js-canvas2d-filter))

;; js-set-canvas2d-filter! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-filter! (unsafe-ffi-primitive 'js-set-canvas2d-filter!))

;; js-canvas2d-font : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-font (unsafe-ffi-primitive 'js-canvas2d-font))

;; js-set-canvas2d-font! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-font! (unsafe-ffi-primitive 'js-set-canvas2d-font!))

;; js-canvas2d-global-alpha : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-global-alpha (unsafe-ffi-primitive 'js-canvas2d-global-alpha))

;; js-set-canvas2d-global-alpha! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-global-alpha! (unsafe-ffi-primitive 'js-set-canvas2d-global-alpha!))

;; js-canvas2d-global-composite-operation : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-global-composite-operation (unsafe-ffi-primitive 'js-canvas2d-global-composite-operation))

;; js-set-canvas2d-global-composite-operation! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-global-composite-operation! (unsafe-ffi-primitive 'js-set-canvas2d-global-composite-operation!))

;; js-canvas2d-image-smoothing-enabled : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-image-smoothing-enabled (unsafe-ffi-primitive 'js-canvas2d-image-smoothing-enabled))

;; js-set-canvas2d-image-smoothing-enabled! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-image-smoothing-enabled! (unsafe-ffi-primitive 'js-set-canvas2d-image-smoothing-enabled!))

;; js-canvas2d-image-smoothing-quality : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-image-smoothing-quality (unsafe-ffi-primitive 'js-canvas2d-image-smoothing-quality))

;; js-set-canvas2d-image-smoothing-quality! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-image-smoothing-quality! (unsafe-ffi-primitive 'js-set-canvas2d-image-smoothing-quality!))

;; js-canvas2d-line-cap : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-line-cap (unsafe-ffi-primitive 'js-canvas2d-line-cap))

;; js-set-canvas2d-line-cap! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-line-cap! (unsafe-ffi-primitive 'js-set-canvas2d-line-cap!))

;; js-canvas2d-line-dash-offset : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-line-dash-offset (unsafe-ffi-primitive 'js-canvas2d-line-dash-offset))

;; js-set-canvas2d-line-dash-offset! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-line-dash-offset! (unsafe-ffi-primitive 'js-set-canvas2d-line-dash-offset!))

;; js-canvas2d-line-join : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-line-join (unsafe-ffi-primitive 'js-canvas2d-line-join))

;; js-set-canvas2d-line-join! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-line-join! (unsafe-ffi-primitive 'js-set-canvas2d-line-join!))

;; js-canvas2d-line-width : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-line-width (unsafe-ffi-primitive 'js-canvas2d-line-width))

;; js-set-canvas2d-line-width! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-line-width! (unsafe-ffi-primitive 'js-set-canvas2d-line-width!))

;; js-canvas2d-miter-limit : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-miter-limit (unsafe-ffi-primitive 'js-canvas2d-miter-limit))

;; js-set-canvas2d-miter-limit! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-miter-limit! (unsafe-ffi-primitive 'js-set-canvas2d-miter-limit!))

;; js-canvas2d-shadow-blur : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-shadow-blur (unsafe-ffi-primitive 'js-canvas2d-shadow-blur))

;; js-set-canvas2d-shadow-blur! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-shadow-blur! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-blur!))

;; js-canvas2d-shadow-color : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-shadow-color (unsafe-ffi-primitive 'js-canvas2d-shadow-color))

;; js-set-canvas2d-shadow-color! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-shadow-color! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-color!))

;; js-canvas2d-shadow-offset-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-shadow-offset-x (unsafe-ffi-primitive 'js-canvas2d-shadow-offset-x))

;; js-set-canvas2d-shadow-offset-x! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-shadow-offset-x! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-offset-x!))

;; js-canvas2d-shadow-offset-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-shadow-offset-y (unsafe-ffi-primitive 'js-canvas2d-shadow-offset-y))

;; js-set-canvas2d-shadow-offset-y! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-shadow-offset-y! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-offset-y!))

;; js-canvas2d-stroke-style : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-stroke-style (unsafe-ffi-primitive 'js-canvas2d-stroke-style))

;; js-set-canvas2d-stroke-style! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-stroke-style! (unsafe-ffi-primitive 'js-set-canvas2d-stroke-style!))

;; js-canvas2d-text-align : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-text-align (unsafe-ffi-primitive 'js-canvas2d-text-align))

;; js-set-canvas2d-text-align! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-text-align! (unsafe-ffi-primitive 'js-set-canvas2d-text-align!))

;; js-canvas2d-text-baseline : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-text-baseline (unsafe-ffi-primitive 'js-canvas2d-text-baseline))

;; js-set-canvas2d-text-baseline! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-text-baseline! (unsafe-ffi-primitive 'js-set-canvas2d-text-baseline!))

;; js-canvas2d-text-rendering : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-text-rendering (unsafe-ffi-primitive 'js-canvas2d-text-rendering))

;; js-set-canvas2d-text-rendering! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-text-rendering! (unsafe-ffi-primitive 'js-set-canvas2d-text-rendering!))

;; js-canvas2d-font-kerning : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-font-kerning (unsafe-ffi-primitive 'js-canvas2d-font-kerning))

;; js-set-canvas2d-font-kerning! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-font-kerning! (unsafe-ffi-primitive 'js-set-canvas2d-font-kerning!))

;; js-canvas2d-font-stretch : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-font-stretch (unsafe-ffi-primitive 'js-canvas2d-font-stretch))

;; js-set-canvas2d-font-stretch! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-font-stretch! (unsafe-ffi-primitive 'js-set-canvas2d-font-stretch!))

;; js-canvas2d-font-variant-caps : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-font-variant-caps (unsafe-ffi-primitive 'js-canvas2d-font-variant-caps))

;; js-set-canvas2d-font-variant-caps! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-font-variant-caps! (unsafe-ffi-primitive 'js-set-canvas2d-font-variant-caps!))

;; js-canvas2d-font-variant-ligatures : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-font-variant-ligatures (unsafe-ffi-primitive 'js-canvas2d-font-variant-ligatures))

;; js-set-canvas2d-font-variant-ligatures! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-font-variant-ligatures! (unsafe-ffi-primitive 'js-set-canvas2d-font-variant-ligatures!))

;; js-canvas2d-font-variant-numeric : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-font-variant-numeric (unsafe-ffi-primitive 'js-canvas2d-font-variant-numeric))

;; js-set-canvas2d-font-variant-numeric! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-font-variant-numeric! (unsafe-ffi-primitive 'js-set-canvas2d-font-variant-numeric!))

;; js-canvas2d-letter-spacing : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-letter-spacing (unsafe-ffi-primitive 'js-canvas2d-letter-spacing))

;; js-set-canvas2d-letter-spacing! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-letter-spacing! (unsafe-ffi-primitive 'js-set-canvas2d-letter-spacing!))

;; js-canvas2d-word-spacing : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-word-spacing (unsafe-ffi-primitive 'js-canvas2d-word-spacing))

;; js-set-canvas2d-word-spacing! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-canvas2d-word-spacing! (unsafe-ffi-primitive 'js-set-canvas2d-word-spacing!))

;; js-canvas2d-arc : ffi (extern f64 f64 f64 f64 f64 i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-arc (unsafe-ffi-primitive 'js-canvas2d-arc))

;; js-canvas2d-arc-to : ffi (extern f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-arc-to (unsafe-ffi-primitive 'js-canvas2d-arc-to))

;; js-canvas2d-begin-path : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-begin-path (unsafe-ffi-primitive 'js-canvas2d-begin-path))

;; js-canvas2d-bezier-curve-to : ffi (extern f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-bezier-curve-to (unsafe-ffi-primitive 'js-canvas2d-bezier-curve-to))

;; js-canvas2d-clear-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-clear-rect (unsafe-ffi-primitive 'js-canvas2d-clear-rect))

;; js-canvas2d-clip : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-clip (unsafe-ffi-primitive 'js-canvas2d-clip))

;; js-canvas2d-close-path : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-close-path (unsafe-ffi-primitive 'js-canvas2d-close-path))

;; js-canvas2d-create-image-data : ffi (extern f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-create-image-data (unsafe-ffi-primitive 'js-canvas2d-create-image-data))

;; js-canvas2d-create-image-data-from : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-create-image-data-from (unsafe-ffi-primitive 'js-canvas2d-create-image-data-from))

;; js-canvas-image-data-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-image-data-width (unsafe-ffi-primitive 'js-canvas-image-data-width))

;; js-canvas-image-data-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-image-data-height (unsafe-ffi-primitive 'js-canvas-image-data-height))

;; js-canvas-image-data-data : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-image-data-data (unsafe-ffi-primitive 'js-canvas-image-data-data))

;; js-canvas-text-metrics-width : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-text-metrics-width (unsafe-ffi-primitive 'js-canvas-text-metrics-width))

;; js-canvas-dom-matrix-a : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-dom-matrix-a (unsafe-ffi-primitive 'js-canvas-dom-matrix-a))

;; js-canvas-dom-matrix-b : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-dom-matrix-b (unsafe-ffi-primitive 'js-canvas-dom-matrix-b))

;; js-canvas-dom-matrix-c : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-dom-matrix-c (unsafe-ffi-primitive 'js-canvas-dom-matrix-c))

;; js-canvas-dom-matrix-d : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-dom-matrix-d (unsafe-ffi-primitive 'js-canvas-dom-matrix-d))

;; js-canvas-dom-matrix-e : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-dom-matrix-e (unsafe-ffi-primitive 'js-canvas-dom-matrix-e))

;; js-canvas-dom-matrix-f : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas-dom-matrix-f (unsafe-ffi-primitive 'js-canvas-dom-matrix-f))

;; js-canvas2d-create-linear-gradient : ffi (extern f64 f64 f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-create-linear-gradient (unsafe-ffi-primitive 'js-canvas2d-create-linear-gradient))

;; js-canvas2d-create-pattern : ffi (extern extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-create-pattern (unsafe-ffi-primitive 'js-canvas2d-create-pattern))

;; js-canvas2d-create-radial-gradient : ffi (extern f64 f64 f64 f64 f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-create-radial-gradient (unsafe-ffi-primitive 'js-canvas2d-create-radial-gradient))

;; js-canvas2d-create-conic-gradient : ffi (extern f64 f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-create-conic-gradient (unsafe-ffi-primitive 'js-canvas2d-create-conic-gradient))

;; js-canvas2d-draw-focus-if-needed! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-draw-focus-if-needed! (unsafe-ffi-primitive 'js-canvas2d-draw-focus-if-needed!))

;; js-canvas2d-draw-focus-if-needed-path! : ffi (extern extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-draw-focus-if-needed-path! (unsafe-ffi-primitive 'js-canvas2d-draw-focus-if-needed-path!))

;; js-canvas2d-draw-image : ffi (extern extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-draw-image (unsafe-ffi-primitive 'js-canvas2d-draw-image))

;; js-canvas2d-draw-image-5 : ffi (extern extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-draw-image-5 (unsafe-ffi-primitive 'js-canvas2d-draw-image-5))

;; js-canvas2d-draw-image-9 : ffi (extern extern f64 f64 f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-draw-image-9 (unsafe-ffi-primitive 'js-canvas2d-draw-image-9))

;; js-canvas2d-ellipse : ffi (extern f64 f64 f64 f64 f64 f64 f64 i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-ellipse (unsafe-ffi-primitive 'js-canvas2d-ellipse))

;; js-canvas2d-fill : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-fill (unsafe-ffi-primitive 'js-canvas2d-fill))

;; js-canvas2d-fill-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-fill-rect (unsafe-ffi-primitive 'js-canvas2d-fill-rect))

;; js-canvas2d-fill-text : ffi (extern string f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-fill-text (unsafe-ffi-primitive 'js-canvas2d-fill-text))

;; js-canvas2d-get-image-data : ffi (extern f64 f64 f64 f64 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-get-image-data (unsafe-ffi-primitive 'js-canvas2d-get-image-data))

;; js-canvas2d-get-line-dash : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-get-line-dash (unsafe-ffi-primitive 'js-canvas2d-get-line-dash))

;; js-canvas2d-get-transform : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-get-transform (unsafe-ffi-primitive 'js-canvas2d-get-transform))

;; js-canvas2d-is-point-in-path : ffi (extern value f64 f64 value) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-is-point-in-path (unsafe-ffi-primitive 'js-canvas2d-is-point-in-path))

;; js-canvas2d-is-point-in-stroke : ffi (extern value f64 f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-is-point-in-stroke (unsafe-ffi-primitive 'js-canvas2d-is-point-in-stroke))

;; js-canvas2d-line-to : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-line-to (unsafe-ffi-primitive 'js-canvas2d-line-to))

;; js-canvas2d-measure-text : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-measure-text (unsafe-ffi-primitive 'js-canvas2d-measure-text))

;; js-canvas2d-move-to : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-move-to (unsafe-ffi-primitive 'js-canvas2d-move-to))

;; js-canvas2d-put-image-data : ffi (extern extern f64 f64 value value value value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-put-image-data (unsafe-ffi-primitive 'js-canvas2d-put-image-data))

;; js-canvas2d-quadratic-curve-to : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-quadratic-curve-to (unsafe-ffi-primitive 'js-canvas2d-quadratic-curve-to))

;; js-canvas2d-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-rect (unsafe-ffi-primitive 'js-canvas2d-rect))

;; js-canvas2d-reset : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-reset (unsafe-ffi-primitive 'js-canvas2d-reset))

;; js-canvas2d-reset-transform : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-reset-transform (unsafe-ffi-primitive 'js-canvas2d-reset-transform))

;; js-canvas2d-restore : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-restore (unsafe-ffi-primitive 'js-canvas2d-restore))

;; js-canvas2d-rotate : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-rotate (unsafe-ffi-primitive 'js-canvas2d-rotate))

;; js-canvas2d-round-rect : ffi (extern f64 f64 f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-round-rect (unsafe-ffi-primitive 'js-canvas2d-round-rect))

;; js-canvas2d-save : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-save (unsafe-ffi-primitive 'js-canvas2d-save))

;; js-canvas2d-scale : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-scale (unsafe-ffi-primitive 'js-canvas2d-scale))

;; js-canvas2d-set-line-dash : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-set-line-dash (unsafe-ffi-primitive 'js-canvas2d-set-line-dash))

;; js-canvas2d-set-transform! : ffi (extern f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-set-transform! (unsafe-ffi-primitive 'js-canvas2d-set-transform!))

;; js-canvas2d-set-transform-matrix! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-set-transform-matrix! (unsafe-ffi-primitive 'js-canvas2d-set-transform-matrix!))

;; js-canvas2d-stroke : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-stroke (unsafe-ffi-primitive 'js-canvas2d-stroke))

;; js-canvas2d-stroke-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-stroke-rect (unsafe-ffi-primitive 'js-canvas2d-stroke-rect))

;; js-canvas2d-stroke-text : ffi (extern string f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-stroke-text (unsafe-ffi-primitive 'js-canvas2d-stroke-text))

;; js-canvas2d-transform : ffi (extern f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-transform (unsafe-ffi-primitive 'js-canvas2d-transform))

;; js-canvas2d-translate : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-canvas2d-translate (unsafe-ffi-primitive 'js-canvas2d-translate))

;; js-image-new : ffi (value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-new (unsafe-ffi-primitive 'js-image-new))

;; js-image-alt : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-alt (unsafe-ffi-primitive 'js-image-alt))

;; js-set-image-alt! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-alt! (unsafe-ffi-primitive 'js-set-image-alt!))

;; js-image-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-src (unsafe-ffi-primitive 'js-image-src))

;; js-set-image-src! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-src! (unsafe-ffi-primitive 'js-set-image-src!))

;; js-image-srcset : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-srcset (unsafe-ffi-primitive 'js-image-srcset))

;; js-set-image-srcset! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-srcset! (unsafe-ffi-primitive 'js-set-image-srcset!))

;; js-image-sizes : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-sizes (unsafe-ffi-primitive 'js-image-sizes))

;; js-set-image-sizes! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-sizes! (unsafe-ffi-primitive 'js-set-image-sizes!))

;; js-image-cross-origin : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-cross-origin (unsafe-ffi-primitive 'js-image-cross-origin))

;; js-set-image-cross-origin! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-cross-origin! (unsafe-ffi-primitive 'js-set-image-cross-origin!))

;; js-image-use-map : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-use-map (unsafe-ffi-primitive 'js-image-use-map))

;; js-set-image-use-map! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-use-map! (unsafe-ffi-primitive 'js-set-image-use-map!))

;; js-image-is-map : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-is-map (unsafe-ffi-primitive 'js-image-is-map))

;; js-set-image-is-map! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-is-map! (unsafe-ffi-primitive 'js-set-image-is-map!))

;; js-image-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-width (unsafe-ffi-primitive 'js-image-width))

;; js-set-image-width! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-width! (unsafe-ffi-primitive 'js-set-image-width!))

;; js-image-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-height (unsafe-ffi-primitive 'js-image-height))

;; js-set-image-height! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-height! (unsafe-ffi-primitive 'js-set-image-height!))

;; js-image-natural-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-natural-width (unsafe-ffi-primitive 'js-image-natural-width))

;; js-image-natural-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-natural-height (unsafe-ffi-primitive 'js-image-natural-height))

;; js-image-complete : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-complete (unsafe-ffi-primitive 'js-image-complete))

;; js-image-current-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-current-src (unsafe-ffi-primitive 'js-image-current-src))

;; js-image-decoding : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-decoding (unsafe-ffi-primitive 'js-image-decoding))

;; js-set-image-decoding! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-decoding! (unsafe-ffi-primitive 'js-set-image-decoding!))

;; js-image-fetch-priority : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-fetch-priority (unsafe-ffi-primitive 'js-image-fetch-priority))

;; js-set-image-fetch-priority! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-fetch-priority! (unsafe-ffi-primitive 'js-set-image-fetch-priority!))

;; js-image-loading : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-loading (unsafe-ffi-primitive 'js-image-loading))

;; js-set-image-loading! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-loading! (unsafe-ffi-primitive 'js-set-image-loading!))

;; js-image-referrer-policy : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-referrer-policy (unsafe-ffi-primitive 'js-image-referrer-policy))

;; js-set-image-referrer-policy! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-referrer-policy! (unsafe-ffi-primitive 'js-set-image-referrer-policy!))

;; js-image-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-name (unsafe-ffi-primitive 'js-image-name))

;; js-set-image-name! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/dom.
(define js-set-image-name! (unsafe-ffi-primitive 'js-set-image-name!))

;; js-image-x : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-x (unsafe-ffi-primitive 'js-image-x))

;; js-image-y : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-y (unsafe-ffi-primitive 'js-image-y))

;; js-image-decode : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/dom.
(define js-image-decode (unsafe-ffi-primitive 'js-image-decode))
