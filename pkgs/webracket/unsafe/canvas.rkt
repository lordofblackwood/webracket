#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
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
 js-canvas2d-translate)

;; js-global-this : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-global-this (unsafe-ffi-primitive 'js-global-this))

;; js-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-infinity (unsafe-ffi-primitive 'js-infinity))

;; js-nan : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-nan (unsafe-ffi-primitive 'js-nan))

;; js-undefined : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-undefined (unsafe-ffi-primitive 'js-undefined))

;; js-nullish? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-nullish? (unsafe-ffi-primitive 'js-nullish?))

;; js-null? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-null? (unsafe-ffi-primitive 'js-null?))

;; js-undefined? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-undefined? (unsafe-ffi-primitive 'js-undefined?))

;; js-truthy? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-truthy? (unsafe-ffi-primitive 'js-truthy?))

;; js-eval : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-eval (unsafe-ffi-primitive 'js-eval))

;; js-is-finite : ffi (f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-is-finite (unsafe-ffi-primitive 'js-is-finite))

;; js-finite? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-finite? (unsafe-ffi-primitive 'js-finite?))

;; js-is-nan : ffi (f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-is-nan (unsafe-ffi-primitive 'js-is-nan))

;; js-nan? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-nan? (unsafe-ffi-primitive 'js-nan?))

;; js-parse-float : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-parse-float (unsafe-ffi-primitive 'js-parse-float))

;; js-parse-int : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-parse-int (unsafe-ffi-primitive 'js-parse-int))

;; js-decode-uri : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-decode-uri (unsafe-ffi-primitive 'js-decode-uri))

;; js-decode-uri-component : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-decode-uri-component (unsafe-ffi-primitive 'js-decode-uri-component))

;; js-encode-uri : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-encode-uri (unsafe-ffi-primitive 'js-encode-uri))

;; js-encode-uri-component : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-encode-uri-component (unsafe-ffi-primitive 'js-encode-uri-component))

;; js-var : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-var (unsafe-ffi-primitive 'js-var))

;; js-ref/extern : ffi (extern string/symbol) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-ref/extern (unsafe-ffi-primitive 'js-ref/extern))

;; js-ref : ffi (extern string/symbol) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-ref (unsafe-ffi-primitive 'js-ref))

;; js-set! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set! (unsafe-ffi-primitive 'js-set!))

;; js-index : ffi (extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-index (unsafe-ffi-primitive 'js-index))

;; js-assign! : ffi (string/symbol value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-assign! (unsafe-ffi-primitive 'js-assign!))

;; js-new : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-new (unsafe-ffi-primitive 'js-new))

;; js-send : ffi (extern string/symbol value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send (unsafe-ffi-primitive 'js-send))

;; js-send/extern : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/extern (unsafe-ffi-primitive 'js-send/extern))

;; js-send/extern/null : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/extern/null (unsafe-ffi-primitive 'js-send/extern/null))

;; js-send/extern/undefined : ffi (extern string/symbol value) -> (extern/undefined)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/extern/undefined (unsafe-ffi-primitive 'js-send/extern/undefined))

;; js-send/extern/nullish : ffi (extern string/symbol value) -> (extern/nullish)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/extern/nullish (unsafe-ffi-primitive 'js-send/extern/nullish))

;; js-send/value : ffi (extern string/symbol value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/value (unsafe-ffi-primitive 'js-send/value))

;; js-send/boolean : ffi (extern string/symbol value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/boolean (unsafe-ffi-primitive 'js-send/boolean))

;; js-send/truthy : ffi (extern string/symbol value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/truthy (unsafe-ffi-primitive 'js-send/truthy))

;; js-send/flonum : ffi (extern string/symbol value) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-send/flonum (unsafe-ffi-primitive 'js-send/flonum))

;; js-throw : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-throw (unsafe-ffi-primitive 'js-throw))

;; js-null : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-null (unsafe-ffi-primitive 'js-null))

;; js-this : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-this (unsafe-ffi-primitive 'js-this))

;; js-object : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-object (unsafe-ffi-primitive 'js-object))

;; js-Array : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Array (unsafe-ffi-primitive 'js-Array))

;; js-typeof : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-typeof (unsafe-ffi-primitive 'js-typeof))

;; js-value->string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-value->string (unsafe-ffi-primitive 'js-value->string))

;; js-instanceof : ffi (extern extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-instanceof (unsafe-ffi-primitive 'js-instanceof))

;; js-operator : ffi (string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-operator (unsafe-ffi-primitive 'js-operator))

;; js-Object : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Object (unsafe-ffi-primitive 'js-Object))

;; js-Function : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Function (unsafe-ffi-primitive 'js-Function))

;; js-Boolean : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Boolean (unsafe-ffi-primitive 'js-Boolean))

;; js-Symbol : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Symbol (unsafe-ffi-primitive 'js-Symbol))

;; js-Error : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Error (unsafe-ffi-primitive 'js-Error))

;; js-AggregateError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-AggregateError (unsafe-ffi-primitive 'js-AggregateError))

;; js-EvalError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-EvalError (unsafe-ffi-primitive 'js-EvalError))

;; js-RangeError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-RangeError (unsafe-ffi-primitive 'js-RangeError))

;; js-ReferenceError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-ReferenceError (unsafe-ffi-primitive 'js-ReferenceError))

;; js-SuppressedError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-SuppressedError (unsafe-ffi-primitive 'js-SuppressedError))

;; js-SyntaxError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-SyntaxError (unsafe-ffi-primitive 'js-SyntaxError))

;; js-TypeError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-TypeError (unsafe-ffi-primitive 'js-TypeError))

;; js-URIError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-URIError (unsafe-ffi-primitive 'js-URIError))

;; js-InternalError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-InternalError (unsafe-ffi-primitive 'js-InternalError))

;; js-Number : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Number (unsafe-ffi-primitive 'js-Number))

;; js-BigInt : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-BigInt (unsafe-ffi-primitive 'js-BigInt))

;; js-Math : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Math (unsafe-ffi-primitive 'js-Math))

;; js-Date : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Date (unsafe-ffi-primitive 'js-Date))

;; js-Temporal : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Temporal (unsafe-ffi-primitive 'js-Temporal))

;; js-number-epsilon : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-epsilon (unsafe-ffi-primitive 'js-number-epsilon))

;; js-number-max-safe-integer : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-max-safe-integer (unsafe-ffi-primitive 'js-number-max-safe-integer))

;; js-number-max-value : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-max-value (unsafe-ffi-primitive 'js-number-max-value))

;; js-number-min-safe-integer : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-min-safe-integer (unsafe-ffi-primitive 'js-number-min-safe-integer))

;; js-number-min-value : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-min-value (unsafe-ffi-primitive 'js-number-min-value))

;; js-number-nan : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-nan (unsafe-ffi-primitive 'js-number-nan))

;; js-number-negative-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-negative-infinity (unsafe-ffi-primitive 'js-number-negative-infinity))

;; js-number-positive-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-positive-infinity (unsafe-ffi-primitive 'js-number-positive-infinity))

;; js-number-finite? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-finite? (unsafe-ffi-primitive 'js-number-finite?))

;; js-number-integer? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-integer? (unsafe-ffi-primitive 'js-number-integer?))

;; js-number-nan? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-nan? (unsafe-ffi-primitive 'js-number-nan?))

;; js-number-safe-integer? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-safe-integer? (unsafe-ffi-primitive 'js-number-safe-integer?))

;; js-number-parse-float : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-parse-float (unsafe-ffi-primitive 'js-number-parse-float))

;; js-number-parse-int : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-parse-int (unsafe-ffi-primitive 'js-number-parse-int))

;; js-number-to-exponential : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-to-exponential (unsafe-ffi-primitive 'js-number-to-exponential))

;; js-number-to-fixed : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-to-fixed (unsafe-ffi-primitive 'js-number-to-fixed))

;; js-number-to-locale-string : ffi (f64 value value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-to-locale-string (unsafe-ffi-primitive 'js-number-to-locale-string))

;; js-number-to-precision : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-to-precision (unsafe-ffi-primitive 'js-number-to-precision))

;; js-number-to-string : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-to-string (unsafe-ffi-primitive 'js-number-to-string))

;; js-number-value-of : ffi (f64) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-number-value-of (unsafe-ffi-primitive 'js-number-value-of))

;; js-String : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-String (unsafe-ffi-primitive 'js-String))

;; js-RegExp : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-RegExp (unsafe-ffi-primitive 'js-RegExp))

;; js-array : ffi (value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array (unsafe-ffi-primitive 'js-array))

;; js-array/extern : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array/extern (unsafe-ffi-primitive 'js-array/extern))

;; js-TypedArray : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-TypedArray (unsafe-ffi-primitive 'js-TypedArray))

;; js-Int8Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Int8Array (unsafe-ffi-primitive 'js-Int8Array))

;; js-Uint8Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Uint8Array (unsafe-ffi-primitive 'js-Uint8Array))

;; js-Uint8ClampedArray : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Uint8ClampedArray (unsafe-ffi-primitive 'js-Uint8ClampedArray))

;; js-Int16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Int16Array (unsafe-ffi-primitive 'js-Int16Array))

;; js-Uint16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Uint16Array (unsafe-ffi-primitive 'js-Uint16Array))

;; js-Int32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Int32Array (unsafe-ffi-primitive 'js-Int32Array))

;; js-Uint32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Uint32Array (unsafe-ffi-primitive 'js-Uint32Array))

;; js-BigInt64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-BigInt64Array (unsafe-ffi-primitive 'js-BigInt64Array))

;; js-BigUint64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-BigUint64Array (unsafe-ffi-primitive 'js-BigUint64Array))

;; js-Float16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Float16Array (unsafe-ffi-primitive 'js-Float16Array))

;; js-Float32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Float32Array (unsafe-ffi-primitive 'js-Float32Array))

;; js-Float64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Float64Array (unsafe-ffi-primitive 'js-Float64Array))

;; js-Map : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Map (unsafe-ffi-primitive 'js-Map))

;; js-Set : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Set (unsafe-ffi-primitive 'js-Set))

;; js-WeakMap : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-WeakMap (unsafe-ffi-primitive 'js-WeakMap))

;; js-WeakSet : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-WeakSet (unsafe-ffi-primitive 'js-WeakSet))

;; js-ArrayBuffer : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-ArrayBuffer (unsafe-ffi-primitive 'js-ArrayBuffer))

;; js-SharedArrayBuffer : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-SharedArrayBuffer (unsafe-ffi-primitive 'js-SharedArrayBuffer))

;; js-DataView : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-DataView (unsafe-ffi-primitive 'js-DataView))

;; js-Atomics : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Atomics (unsafe-ffi-primitive 'js-Atomics))

;; js-JSON : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-JSON (unsafe-ffi-primitive 'js-JSON))

;; js-WeakRef : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-WeakRef (unsafe-ffi-primitive 'js-WeakRef))

;; js-FinalizationRegistry : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-FinalizationRegistry (unsafe-ffi-primitive 'js-FinalizationRegistry))

;; js-Iterator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Iterator (unsafe-ffi-primitive 'js-Iterator))

;; js-AsyncIterator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-AsyncIterator (unsafe-ffi-primitive 'js-AsyncIterator))

;; js-Promise : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Promise (unsafe-ffi-primitive 'js-Promise))

;; js-GeneratorFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-GeneratorFunction (unsafe-ffi-primitive 'js-GeneratorFunction))

;; js-AsyncGeneratorFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-AsyncGeneratorFunction (unsafe-ffi-primitive 'js-AsyncGeneratorFunction))

;; js-Generator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Generator (unsafe-ffi-primitive 'js-Generator))

;; js-AsyncGenerator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-AsyncGenerator (unsafe-ffi-primitive 'js-AsyncGenerator))

;; js-AsyncFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-AsyncFunction (unsafe-ffi-primitive 'js-AsyncFunction))

;; js-DisposableStack : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-DisposableStack (unsafe-ffi-primitive 'js-DisposableStack))

;; js-AsyncDisposableStack : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-AsyncDisposableStack (unsafe-ffi-primitive 'js-AsyncDisposableStack))

;; js-Reflect : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Reflect (unsafe-ffi-primitive 'js-Reflect))

;; js-Proxy : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Proxy (unsafe-ffi-primitive 'js-Proxy))

;; js-Intl : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-Intl (unsafe-ffi-primitive 'js-Intl))

;; js-IntlCollator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlCollator (unsafe-ffi-primitive 'js-IntlCollator))

;; js-IntlDateTimeFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlDateTimeFormat (unsafe-ffi-primitive 'js-IntlDateTimeFormat))

;; js-IntlDisplayNames : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlDisplayNames (unsafe-ffi-primitive 'js-IntlDisplayNames))

;; js-IntlDurationFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlDurationFormat (unsafe-ffi-primitive 'js-IntlDurationFormat))

;; js-IntlListFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlListFormat (unsafe-ffi-primitive 'js-IntlListFormat))

;; js-IntlLocale : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlLocale (unsafe-ffi-primitive 'js-IntlLocale))

;; js-IntlNumberFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlNumberFormat (unsafe-ffi-primitive 'js-IntlNumberFormat))

;; js-IntlPluralRules : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlPluralRules (unsafe-ffi-primitive 'js-IntlPluralRules))

;; js-IntlRelativeTimeFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlRelativeTimeFormat (unsafe-ffi-primitive 'js-IntlRelativeTimeFormat))

;; js-IntlSegmenter : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-IntlSegmenter (unsafe-ffi-primitive 'js-IntlSegmenter))

;; js-array-from : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-from (unsafe-ffi-primitive 'js-array-from))

;; js-array-from-async : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-from-async (unsafe-ffi-primitive 'js-array-from-async))

;; js-array-is-array : ffi (value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-is-array (unsafe-ffi-primitive 'js-array-is-array))

;; js-array->vector : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array->vector (unsafe-ffi-primitive 'js-array->vector))

;; js-array->bytes : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array->bytes (unsafe-ffi-primitive 'js-array->bytes))

;; js-array-of : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-of (unsafe-ffi-primitive 'js-array-of))

;; js-array-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-length (unsafe-ffi-primitive 'js-array-length))

;; js-set-array-length! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-array-length! (unsafe-ffi-primitive 'js-set-array-length!))

;; js-array-ref : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-ref (unsafe-ffi-primitive 'js-array-ref))

;; js-array-at : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-at (unsafe-ffi-primitive 'js-array-at))

;; js-array-concat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-concat (unsafe-ffi-primitive 'js-array-concat))

;; js-array-copy-within : ffi (extern i32 i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-copy-within (unsafe-ffi-primitive 'js-array-copy-within))

;; js-array-entries : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-entries (unsafe-ffi-primitive 'js-array-entries))

;; js-array-every : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-every (unsafe-ffi-primitive 'js-array-every))

;; js-array-fill : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-fill (unsafe-ffi-primitive 'js-array-fill))

;; js-array-filter : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-filter (unsafe-ffi-primitive 'js-array-filter))

;; js-array-find : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-find (unsafe-ffi-primitive 'js-array-find))

;; js-array-find-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-find-index (unsafe-ffi-primitive 'js-array-find-index))

;; js-array-find-last : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-find-last (unsafe-ffi-primitive 'js-array-find-last))

;; js-array-find-last-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-find-last-index (unsafe-ffi-primitive 'js-array-find-last-index))

;; js-array-flat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-flat (unsafe-ffi-primitive 'js-array-flat))

;; js-array-flat-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-flat-map (unsafe-ffi-primitive 'js-array-flat-map))

;; js-array-for-each : ffi (extern extern value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-for-each (unsafe-ffi-primitive 'js-array-for-each))

;; js-array-includes : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-includes (unsafe-ffi-primitive 'js-array-includes))

;; js-array-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-index-of (unsafe-ffi-primitive 'js-array-index-of))

;; js-array-join : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-join (unsafe-ffi-primitive 'js-array-join))

;; js-array-keys : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-keys (unsafe-ffi-primitive 'js-array-keys))

;; js-array-last-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-last-index-of (unsafe-ffi-primitive 'js-array-last-index-of))

;; js-array-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-map (unsafe-ffi-primitive 'js-array-map))

;; js-array-pop : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-pop (unsafe-ffi-primitive 'js-array-pop))

;; js-array-push : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-push (unsafe-ffi-primitive 'js-array-push))

;; js-array-reduce : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-reduce (unsafe-ffi-primitive 'js-array-reduce))

;; js-array-reduce-right : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-reduce-right (unsafe-ffi-primitive 'js-array-reduce-right))

;; js-array-reverse : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-reverse (unsafe-ffi-primitive 'js-array-reverse))

;; js-array-shift : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-shift (unsafe-ffi-primitive 'js-array-shift))

;; js-array-slice : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-slice (unsafe-ffi-primitive 'js-array-slice))

;; js-array-some : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-some (unsafe-ffi-primitive 'js-array-some))

;; js-array-sort : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-sort (unsafe-ffi-primitive 'js-array-sort))

;; js-array-splice : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-splice (unsafe-ffi-primitive 'js-array-splice))

;; js-array-to-locale-string : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-to-locale-string (unsafe-ffi-primitive 'js-array-to-locale-string))

;; js-array-to-string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-to-string (unsafe-ffi-primitive 'js-array-to-string))

;; js-array-unshift : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-unshift (unsafe-ffi-primitive 'js-array-unshift))

;; js-array-values : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-values (unsafe-ffi-primitive 'js-array-values))

;; js-array-to-reversed : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-to-reversed (unsafe-ffi-primitive 'js-array-to-reversed))

;; js-array-to-sorted : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-to-sorted (unsafe-ffi-primitive 'js-array-to-sorted))

;; js-array-to-spliced : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-to-spliced (unsafe-ffi-primitive 'js-array-to-spliced))

;; js-array-with : ffi (extern i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-array-with (unsafe-ffi-primitive 'js-array-with))

;; js-media-audio-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-audio-tracks (unsafe-ffi-primitive 'js-media-audio-tracks))

;; js-media-autoplay : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-autoplay (unsafe-ffi-primitive 'js-media-autoplay))

;; js-set-media-autoplay! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-autoplay! (unsafe-ffi-primitive 'js-set-media-autoplay!))

;; js-media-buffered : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-buffered (unsafe-ffi-primitive 'js-media-buffered))

;; js-media-controls : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-controls (unsafe-ffi-primitive 'js-media-controls))

;; js-set-media-controls! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-controls! (unsafe-ffi-primitive 'js-set-media-controls!))

;; js-media-controls-list : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-controls-list (unsafe-ffi-primitive 'js-media-controls-list))

;; js-media-cross-origin : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-cross-origin (unsafe-ffi-primitive 'js-media-cross-origin))

;; js-set-media-cross-origin! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-cross-origin! (unsafe-ffi-primitive 'js-set-media-cross-origin!))

;; js-media-current-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-current-src (unsafe-ffi-primitive 'js-media-current-src))

;; js-media-current-time : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-current-time (unsafe-ffi-primitive 'js-media-current-time))

;; js-set-media-current-time! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-current-time! (unsafe-ffi-primitive 'js-set-media-current-time!))

;; js-media-default-muted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-default-muted (unsafe-ffi-primitive 'js-media-default-muted))

;; js-set-media-default-muted! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-default-muted! (unsafe-ffi-primitive 'js-set-media-default-muted!))

;; js-media-default-playback-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-default-playback-rate (unsafe-ffi-primitive 'js-media-default-playback-rate))

;; js-set-media-default-playback-rate! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-default-playback-rate! (unsafe-ffi-primitive 'js-set-media-default-playback-rate!))

;; js-media-disable-remote-playback : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-disable-remote-playback (unsafe-ffi-primitive 'js-media-disable-remote-playback))

;; js-set-media-disable-remote-playback! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-disable-remote-playback! (unsafe-ffi-primitive 'js-set-media-disable-remote-playback!))

;; js-media-duration : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-duration (unsafe-ffi-primitive 'js-media-duration))

;; js-media-ended : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-ended (unsafe-ffi-primitive 'js-media-ended))

;; js-media-error : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-error (unsafe-ffi-primitive 'js-media-error))

;; js-media-loop : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-loop (unsafe-ffi-primitive 'js-media-loop))

;; js-set-media-loop! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-loop! (unsafe-ffi-primitive 'js-set-media-loop!))

;; js-media-media-keys : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-media-keys (unsafe-ffi-primitive 'js-media-media-keys))

;; js-media-media-group : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-media-group (unsafe-ffi-primitive 'js-media-media-group))

;; js-set-media-media-group! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-media-group! (unsafe-ffi-primitive 'js-set-media-media-group!))

;; js-media-muted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-muted (unsafe-ffi-primitive 'js-media-muted))

;; js-set-media-muted! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-muted! (unsafe-ffi-primitive 'js-set-media-muted!))

;; js-media-network-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-network-state (unsafe-ffi-primitive 'js-media-network-state))

;; js-media-paused : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-paused (unsafe-ffi-primitive 'js-media-paused))

;; js-media-playback-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-playback-rate (unsafe-ffi-primitive 'js-media-playback-rate))

;; js-set-media-playback-rate! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-playback-rate! (unsafe-ffi-primitive 'js-set-media-playback-rate!))

;; js-media-played : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-played (unsafe-ffi-primitive 'js-media-played))

;; js-media-preload : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-preload (unsafe-ffi-primitive 'js-media-preload))

;; js-set-media-preload! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-preload! (unsafe-ffi-primitive 'js-set-media-preload!))

;; js-media-preserves-pitch : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-preserves-pitch (unsafe-ffi-primitive 'js-media-preserves-pitch))

;; js-set-media-preserves-pitch! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-preserves-pitch! (unsafe-ffi-primitive 'js-set-media-preserves-pitch!))

;; js-media-ready-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-ready-state (unsafe-ffi-primitive 'js-media-ready-state))

;; js-media-seekable : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-seekable (unsafe-ffi-primitive 'js-media-seekable))

;; js-media-seeking : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-seeking (unsafe-ffi-primitive 'js-media-seeking))

;; js-media-sink-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-sink-id (unsafe-ffi-primitive 'js-media-sink-id))

;; js-media-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-src (unsafe-ffi-primitive 'js-media-src))

;; js-set-media-src! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-src! (unsafe-ffi-primitive 'js-set-media-src!))

;; js-media-src-object : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-src-object (unsafe-ffi-primitive 'js-media-src-object))

;; js-set-media-src-object! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-src-object! (unsafe-ffi-primitive 'js-set-media-src-object!))

;; js-media-text-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-text-tracks (unsafe-ffi-primitive 'js-media-text-tracks))

;; js-media-video-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-video-tracks (unsafe-ffi-primitive 'js-media-video-tracks))

;; js-media-volume : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-volume (unsafe-ffi-primitive 'js-media-volume))

;; js-set-media-volume! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-media-volume! (unsafe-ffi-primitive 'js-set-media-volume!))

;; js-media-add-text-track! : ffi (extern string value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-add-text-track! (unsafe-ffi-primitive 'js-media-add-text-track!))

;; js-media-can-play-type : ffi (extern string) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-can-play-type (unsafe-ffi-primitive 'js-media-can-play-type))

;; js-media-capture-stream : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-capture-stream (unsafe-ffi-primitive 'js-media-capture-stream))

;; js-media-fast-seek! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-fast-seek! (unsafe-ffi-primitive 'js-media-fast-seek!))

;; js-media-load! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-load! (unsafe-ffi-primitive 'js-media-load!))

;; js-media-pause : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-pause (unsafe-ffi-primitive 'js-media-pause))

;; js-media-play : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-play (unsafe-ffi-primitive 'js-media-play))

;; js-media-set-media-keys! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-set-media-keys! (unsafe-ffi-primitive 'js-media-set-media-keys!))

;; js-media-set-sink-id! : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-media-set-sink-id! (unsafe-ffi-primitive 'js-media-set-sink-id!))

;; js-canvas-capture-stream : ffi (extern f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-capture-stream (unsafe-ffi-primitive 'js-canvas-capture-stream))

;; js-canvas-get-context : ffi (extern string extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-get-context (unsafe-ffi-primitive 'js-canvas-get-context))

;; js-canvas-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-height (unsafe-ffi-primitive 'js-canvas-height))

;; js-set-canvas-height! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas-height! (unsafe-ffi-primitive 'js-set-canvas-height!))

;; js-canvas-to-blob : ffi (extern extern string f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-to-blob (unsafe-ffi-primitive 'js-canvas-to-blob))

;; js-canvas-to-data-url : ffi (extern string f64) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-to-data-url (unsafe-ffi-primitive 'js-canvas-to-data-url))

;; js-canvas-transfer-control-to-offscreen : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-transfer-control-to-offscreen (unsafe-ffi-primitive 'js-canvas-transfer-control-to-offscreen))

;; js-canvas-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-width (unsafe-ffi-primitive 'js-canvas-width))

;; js-set-canvas-width! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas-width! (unsafe-ffi-primitive 'js-set-canvas-width!))

;; js-canvas2d-canvas : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-canvas (unsafe-ffi-primitive 'js-canvas2d-canvas))

;; js-canvas2d-direction : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-direction (unsafe-ffi-primitive 'js-canvas2d-direction))

;; js-set-canvas2d-direction! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-direction! (unsafe-ffi-primitive 'js-set-canvas2d-direction!))

;; js-canvas2d-fill-style : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-fill-style (unsafe-ffi-primitive 'js-canvas2d-fill-style))

;; js-set-canvas2d-fill-style! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-fill-style! (unsafe-ffi-primitive 'js-set-canvas2d-fill-style!))

;; js-canvas2d-filter : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-filter (unsafe-ffi-primitive 'js-canvas2d-filter))

;; js-set-canvas2d-filter! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-filter! (unsafe-ffi-primitive 'js-set-canvas2d-filter!))

;; js-canvas2d-font : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-font (unsafe-ffi-primitive 'js-canvas2d-font))

;; js-set-canvas2d-font! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-font! (unsafe-ffi-primitive 'js-set-canvas2d-font!))

;; js-canvas2d-global-alpha : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-global-alpha (unsafe-ffi-primitive 'js-canvas2d-global-alpha))

;; js-set-canvas2d-global-alpha! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-global-alpha! (unsafe-ffi-primitive 'js-set-canvas2d-global-alpha!))

;; js-canvas2d-global-composite-operation : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-global-composite-operation (unsafe-ffi-primitive 'js-canvas2d-global-composite-operation))

;; js-set-canvas2d-global-composite-operation! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-global-composite-operation! (unsafe-ffi-primitive 'js-set-canvas2d-global-composite-operation!))

;; js-canvas2d-image-smoothing-enabled : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-image-smoothing-enabled (unsafe-ffi-primitive 'js-canvas2d-image-smoothing-enabled))

;; js-set-canvas2d-image-smoothing-enabled! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-image-smoothing-enabled! (unsafe-ffi-primitive 'js-set-canvas2d-image-smoothing-enabled!))

;; js-canvas2d-image-smoothing-quality : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-image-smoothing-quality (unsafe-ffi-primitive 'js-canvas2d-image-smoothing-quality))

;; js-set-canvas2d-image-smoothing-quality! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-image-smoothing-quality! (unsafe-ffi-primitive 'js-set-canvas2d-image-smoothing-quality!))

;; js-canvas2d-line-cap : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-line-cap (unsafe-ffi-primitive 'js-canvas2d-line-cap))

;; js-set-canvas2d-line-cap! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-line-cap! (unsafe-ffi-primitive 'js-set-canvas2d-line-cap!))

;; js-canvas2d-line-dash-offset : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-line-dash-offset (unsafe-ffi-primitive 'js-canvas2d-line-dash-offset))

;; js-set-canvas2d-line-dash-offset! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-line-dash-offset! (unsafe-ffi-primitive 'js-set-canvas2d-line-dash-offset!))

;; js-canvas2d-line-join : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-line-join (unsafe-ffi-primitive 'js-canvas2d-line-join))

;; js-set-canvas2d-line-join! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-line-join! (unsafe-ffi-primitive 'js-set-canvas2d-line-join!))

;; js-canvas2d-line-width : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-line-width (unsafe-ffi-primitive 'js-canvas2d-line-width))

;; js-set-canvas2d-line-width! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-line-width! (unsafe-ffi-primitive 'js-set-canvas2d-line-width!))

;; js-canvas2d-miter-limit : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-miter-limit (unsafe-ffi-primitive 'js-canvas2d-miter-limit))

;; js-set-canvas2d-miter-limit! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-miter-limit! (unsafe-ffi-primitive 'js-set-canvas2d-miter-limit!))

;; js-canvas2d-shadow-blur : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-shadow-blur (unsafe-ffi-primitive 'js-canvas2d-shadow-blur))

;; js-set-canvas2d-shadow-blur! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-shadow-blur! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-blur!))

;; js-canvas2d-shadow-color : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-shadow-color (unsafe-ffi-primitive 'js-canvas2d-shadow-color))

;; js-set-canvas2d-shadow-color! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-shadow-color! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-color!))

;; js-canvas2d-shadow-offset-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-shadow-offset-x (unsafe-ffi-primitive 'js-canvas2d-shadow-offset-x))

;; js-set-canvas2d-shadow-offset-x! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-shadow-offset-x! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-offset-x!))

;; js-canvas2d-shadow-offset-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-shadow-offset-y (unsafe-ffi-primitive 'js-canvas2d-shadow-offset-y))

;; js-set-canvas2d-shadow-offset-y! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-shadow-offset-y! (unsafe-ffi-primitive 'js-set-canvas2d-shadow-offset-y!))

;; js-canvas2d-stroke-style : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-stroke-style (unsafe-ffi-primitive 'js-canvas2d-stroke-style))

;; js-set-canvas2d-stroke-style! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-stroke-style! (unsafe-ffi-primitive 'js-set-canvas2d-stroke-style!))

;; js-canvas2d-text-align : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-text-align (unsafe-ffi-primitive 'js-canvas2d-text-align))

;; js-set-canvas2d-text-align! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-text-align! (unsafe-ffi-primitive 'js-set-canvas2d-text-align!))

;; js-canvas2d-text-baseline : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-text-baseline (unsafe-ffi-primitive 'js-canvas2d-text-baseline))

;; js-set-canvas2d-text-baseline! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-text-baseline! (unsafe-ffi-primitive 'js-set-canvas2d-text-baseline!))

;; js-canvas2d-text-rendering : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-text-rendering (unsafe-ffi-primitive 'js-canvas2d-text-rendering))

;; js-set-canvas2d-text-rendering! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-text-rendering! (unsafe-ffi-primitive 'js-set-canvas2d-text-rendering!))

;; js-canvas2d-font-kerning : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-font-kerning (unsafe-ffi-primitive 'js-canvas2d-font-kerning))

;; js-set-canvas2d-font-kerning! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-font-kerning! (unsafe-ffi-primitive 'js-set-canvas2d-font-kerning!))

;; js-canvas2d-font-stretch : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-font-stretch (unsafe-ffi-primitive 'js-canvas2d-font-stretch))

;; js-set-canvas2d-font-stretch! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-font-stretch! (unsafe-ffi-primitive 'js-set-canvas2d-font-stretch!))

;; js-canvas2d-font-variant-caps : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-font-variant-caps (unsafe-ffi-primitive 'js-canvas2d-font-variant-caps))

;; js-set-canvas2d-font-variant-caps! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-font-variant-caps! (unsafe-ffi-primitive 'js-set-canvas2d-font-variant-caps!))

;; js-canvas2d-font-variant-ligatures : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-font-variant-ligatures (unsafe-ffi-primitive 'js-canvas2d-font-variant-ligatures))

;; js-set-canvas2d-font-variant-ligatures! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-font-variant-ligatures! (unsafe-ffi-primitive 'js-set-canvas2d-font-variant-ligatures!))

;; js-canvas2d-font-variant-numeric : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-font-variant-numeric (unsafe-ffi-primitive 'js-canvas2d-font-variant-numeric))

;; js-set-canvas2d-font-variant-numeric! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-font-variant-numeric! (unsafe-ffi-primitive 'js-set-canvas2d-font-variant-numeric!))

;; js-canvas2d-letter-spacing : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-letter-spacing (unsafe-ffi-primitive 'js-canvas2d-letter-spacing))

;; js-set-canvas2d-letter-spacing! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-letter-spacing! (unsafe-ffi-primitive 'js-set-canvas2d-letter-spacing!))

;; js-canvas2d-word-spacing : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-word-spacing (unsafe-ffi-primitive 'js-canvas2d-word-spacing))

;; js-set-canvas2d-word-spacing! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-set-canvas2d-word-spacing! (unsafe-ffi-primitive 'js-set-canvas2d-word-spacing!))

;; js-canvas2d-arc : ffi (extern f64 f64 f64 f64 f64 i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-arc (unsafe-ffi-primitive 'js-canvas2d-arc))

;; js-canvas2d-arc-to : ffi (extern f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-arc-to (unsafe-ffi-primitive 'js-canvas2d-arc-to))

;; js-canvas2d-begin-path : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-begin-path (unsafe-ffi-primitive 'js-canvas2d-begin-path))

;; js-canvas2d-bezier-curve-to : ffi (extern f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-bezier-curve-to (unsafe-ffi-primitive 'js-canvas2d-bezier-curve-to))

;; js-canvas2d-clear-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-clear-rect (unsafe-ffi-primitive 'js-canvas2d-clear-rect))

;; js-canvas2d-clip : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-clip (unsafe-ffi-primitive 'js-canvas2d-clip))

;; js-canvas2d-close-path : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-close-path (unsafe-ffi-primitive 'js-canvas2d-close-path))

;; js-canvas2d-create-image-data : ffi (extern f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-create-image-data (unsafe-ffi-primitive 'js-canvas2d-create-image-data))

;; js-canvas2d-create-image-data-from : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-create-image-data-from (unsafe-ffi-primitive 'js-canvas2d-create-image-data-from))

;; js-canvas-image-data-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-image-data-width (unsafe-ffi-primitive 'js-canvas-image-data-width))

;; js-canvas-image-data-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-image-data-height (unsafe-ffi-primitive 'js-canvas-image-data-height))

;; js-canvas-image-data-data : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-image-data-data (unsafe-ffi-primitive 'js-canvas-image-data-data))

;; js-canvas-text-metrics-width : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-text-metrics-width (unsafe-ffi-primitive 'js-canvas-text-metrics-width))

;; js-canvas-dom-matrix-a : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-dom-matrix-a (unsafe-ffi-primitive 'js-canvas-dom-matrix-a))

;; js-canvas-dom-matrix-b : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-dom-matrix-b (unsafe-ffi-primitive 'js-canvas-dom-matrix-b))

;; js-canvas-dom-matrix-c : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-dom-matrix-c (unsafe-ffi-primitive 'js-canvas-dom-matrix-c))

;; js-canvas-dom-matrix-d : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-dom-matrix-d (unsafe-ffi-primitive 'js-canvas-dom-matrix-d))

;; js-canvas-dom-matrix-e : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-dom-matrix-e (unsafe-ffi-primitive 'js-canvas-dom-matrix-e))

;; js-canvas-dom-matrix-f : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas-dom-matrix-f (unsafe-ffi-primitive 'js-canvas-dom-matrix-f))

;; js-canvas2d-create-linear-gradient : ffi (extern f64 f64 f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-create-linear-gradient (unsafe-ffi-primitive 'js-canvas2d-create-linear-gradient))

;; js-canvas2d-create-pattern : ffi (extern extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-create-pattern (unsafe-ffi-primitive 'js-canvas2d-create-pattern))

;; js-canvas2d-create-radial-gradient : ffi (extern f64 f64 f64 f64 f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-create-radial-gradient (unsafe-ffi-primitive 'js-canvas2d-create-radial-gradient))

;; js-canvas2d-create-conic-gradient : ffi (extern f64 f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-create-conic-gradient (unsafe-ffi-primitive 'js-canvas2d-create-conic-gradient))

;; js-canvas2d-draw-focus-if-needed! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-draw-focus-if-needed! (unsafe-ffi-primitive 'js-canvas2d-draw-focus-if-needed!))

;; js-canvas2d-draw-focus-if-needed-path! : ffi (extern extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-draw-focus-if-needed-path! (unsafe-ffi-primitive 'js-canvas2d-draw-focus-if-needed-path!))

;; js-canvas2d-draw-image : ffi (extern extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-draw-image (unsafe-ffi-primitive 'js-canvas2d-draw-image))

;; js-canvas2d-draw-image-5 : ffi (extern extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-draw-image-5 (unsafe-ffi-primitive 'js-canvas2d-draw-image-5))

;; js-canvas2d-draw-image-9 : ffi (extern extern f64 f64 f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-draw-image-9 (unsafe-ffi-primitive 'js-canvas2d-draw-image-9))

;; js-canvas2d-ellipse : ffi (extern f64 f64 f64 f64 f64 f64 f64 i32) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-ellipse (unsafe-ffi-primitive 'js-canvas2d-ellipse))

;; js-canvas2d-fill : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-fill (unsafe-ffi-primitive 'js-canvas2d-fill))

;; js-canvas2d-fill-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-fill-rect (unsafe-ffi-primitive 'js-canvas2d-fill-rect))

;; js-canvas2d-fill-text : ffi (extern string f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-fill-text (unsafe-ffi-primitive 'js-canvas2d-fill-text))

;; js-canvas2d-get-image-data : ffi (extern f64 f64 f64 f64 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-get-image-data (unsafe-ffi-primitive 'js-canvas2d-get-image-data))

;; js-canvas2d-get-line-dash : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-get-line-dash (unsafe-ffi-primitive 'js-canvas2d-get-line-dash))

;; js-canvas2d-get-transform : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-get-transform (unsafe-ffi-primitive 'js-canvas2d-get-transform))

;; js-canvas2d-is-point-in-path : ffi (extern value f64 f64 value) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-is-point-in-path (unsafe-ffi-primitive 'js-canvas2d-is-point-in-path))

;; js-canvas2d-is-point-in-stroke : ffi (extern value f64 f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-is-point-in-stroke (unsafe-ffi-primitive 'js-canvas2d-is-point-in-stroke))

;; js-canvas2d-line-to : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-line-to (unsafe-ffi-primitive 'js-canvas2d-line-to))

;; js-canvas2d-measure-text : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-measure-text (unsafe-ffi-primitive 'js-canvas2d-measure-text))

;; js-canvas2d-move-to : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-move-to (unsafe-ffi-primitive 'js-canvas2d-move-to))

;; js-canvas2d-put-image-data : ffi (extern extern f64 f64 value value value value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-put-image-data (unsafe-ffi-primitive 'js-canvas2d-put-image-data))

;; js-canvas2d-quadratic-curve-to : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-quadratic-curve-to (unsafe-ffi-primitive 'js-canvas2d-quadratic-curve-to))

;; js-canvas2d-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-rect (unsafe-ffi-primitive 'js-canvas2d-rect))

;; js-canvas2d-reset : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-reset (unsafe-ffi-primitive 'js-canvas2d-reset))

;; js-canvas2d-reset-transform : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-reset-transform (unsafe-ffi-primitive 'js-canvas2d-reset-transform))

;; js-canvas2d-restore : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-restore (unsafe-ffi-primitive 'js-canvas2d-restore))

;; js-canvas2d-rotate : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-rotate (unsafe-ffi-primitive 'js-canvas2d-rotate))

;; js-canvas2d-round-rect : ffi (extern f64 f64 f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-round-rect (unsafe-ffi-primitive 'js-canvas2d-round-rect))

;; js-canvas2d-save : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-save (unsafe-ffi-primitive 'js-canvas2d-save))

;; js-canvas2d-scale : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-scale (unsafe-ffi-primitive 'js-canvas2d-scale))

;; js-canvas2d-set-line-dash : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-set-line-dash (unsafe-ffi-primitive 'js-canvas2d-set-line-dash))

;; js-canvas2d-set-transform! : ffi (extern f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-set-transform! (unsafe-ffi-primitive 'js-canvas2d-set-transform!))

;; js-canvas2d-set-transform-matrix! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-set-transform-matrix! (unsafe-ffi-primitive 'js-canvas2d-set-transform-matrix!))

;; js-canvas2d-stroke : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-stroke (unsafe-ffi-primitive 'js-canvas2d-stroke))

;; js-canvas2d-stroke-rect : ffi (extern f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-stroke-rect (unsafe-ffi-primitive 'js-canvas2d-stroke-rect))

;; js-canvas2d-stroke-text : ffi (extern string f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-stroke-text (unsafe-ffi-primitive 'js-canvas2d-stroke-text))

;; js-canvas2d-transform : ffi (extern f64 f64 f64 f64 f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-transform (unsafe-ffi-primitive 'js-canvas2d-transform))

;; js-canvas2d-translate : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/canvas.
(define js-canvas2d-translate (unsafe-ffi-primitive 'js-canvas2d-translate))
