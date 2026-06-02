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
 js-array-with)

;; js-global-this : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-global-this (unsafe-ffi-primitive 'js-global-this))

;; js-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-infinity (unsafe-ffi-primitive 'js-infinity))

;; js-nan : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-nan (unsafe-ffi-primitive 'js-nan))

;; js-undefined : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-undefined (unsafe-ffi-primitive 'js-undefined))

;; js-nullish? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-nullish? (unsafe-ffi-primitive 'js-nullish?))

;; js-null? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-null? (unsafe-ffi-primitive 'js-null?))

;; js-undefined? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-undefined? (unsafe-ffi-primitive 'js-undefined?))

;; js-truthy? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-truthy? (unsafe-ffi-primitive 'js-truthy?))

;; js-eval : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-eval (unsafe-ffi-primitive 'js-eval))

;; js-is-finite : ffi (f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-is-finite (unsafe-ffi-primitive 'js-is-finite))

;; js-finite? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-finite? (unsafe-ffi-primitive 'js-finite?))

;; js-is-nan : ffi (f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-is-nan (unsafe-ffi-primitive 'js-is-nan))

;; js-nan? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-nan? (unsafe-ffi-primitive 'js-nan?))

;; js-parse-float : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-parse-float (unsafe-ffi-primitive 'js-parse-float))

;; js-parse-int : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-parse-int (unsafe-ffi-primitive 'js-parse-int))

;; js-decode-uri : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-decode-uri (unsafe-ffi-primitive 'js-decode-uri))

;; js-decode-uri-component : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-decode-uri-component (unsafe-ffi-primitive 'js-decode-uri-component))

;; js-encode-uri : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-encode-uri (unsafe-ffi-primitive 'js-encode-uri))

;; js-encode-uri-component : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-encode-uri-component (unsafe-ffi-primitive 'js-encode-uri-component))

;; js-var : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-var (unsafe-ffi-primitive 'js-var))

;; js-ref/extern : ffi (extern string/symbol) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-ref/extern (unsafe-ffi-primitive 'js-ref/extern))

;; js-ref : ffi (extern string/symbol) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-ref (unsafe-ffi-primitive 'js-ref))

;; js-set! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/array.
(define js-set! (unsafe-ffi-primitive 'js-set!))

;; js-index : ffi (extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-index (unsafe-ffi-primitive 'js-index))

;; js-assign! : ffi (string/symbol value) -> ()
;;   Raw binding generated for webracket/unsafe/array.
(define js-assign! (unsafe-ffi-primitive 'js-assign!))

;; js-new : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-new (unsafe-ffi-primitive 'js-new))

;; js-send : ffi (extern string/symbol value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send (unsafe-ffi-primitive 'js-send))

;; js-send/extern : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/extern (unsafe-ffi-primitive 'js-send/extern))

;; js-send/extern/null : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/extern/null (unsafe-ffi-primitive 'js-send/extern/null))

;; js-send/extern/undefined : ffi (extern string/symbol value) -> (extern/undefined)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/extern/undefined (unsafe-ffi-primitive 'js-send/extern/undefined))

;; js-send/extern/nullish : ffi (extern string/symbol value) -> (extern/nullish)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/extern/nullish (unsafe-ffi-primitive 'js-send/extern/nullish))

;; js-send/value : ffi (extern string/symbol value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/value (unsafe-ffi-primitive 'js-send/value))

;; js-send/boolean : ffi (extern string/symbol value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/boolean (unsafe-ffi-primitive 'js-send/boolean))

;; js-send/truthy : ffi (extern string/symbol value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/truthy (unsafe-ffi-primitive 'js-send/truthy))

;; js-send/flonum : ffi (extern string/symbol value) -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-send/flonum (unsafe-ffi-primitive 'js-send/flonum))

;; js-throw : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/array.
(define js-throw (unsafe-ffi-primitive 'js-throw))

;; js-null : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-null (unsafe-ffi-primitive 'js-null))

;; js-this : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-this (unsafe-ffi-primitive 'js-this))

;; js-object : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-object (unsafe-ffi-primitive 'js-object))

;; js-Array : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Array (unsafe-ffi-primitive 'js-Array))

;; js-typeof : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-typeof (unsafe-ffi-primitive 'js-typeof))

;; js-value->string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-value->string (unsafe-ffi-primitive 'js-value->string))

;; js-instanceof : ffi (extern extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-instanceof (unsafe-ffi-primitive 'js-instanceof))

;; js-operator : ffi (string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-operator (unsafe-ffi-primitive 'js-operator))

;; js-Object : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Object (unsafe-ffi-primitive 'js-Object))

;; js-Function : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Function (unsafe-ffi-primitive 'js-Function))

;; js-Boolean : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Boolean (unsafe-ffi-primitive 'js-Boolean))

;; js-Symbol : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Symbol (unsafe-ffi-primitive 'js-Symbol))

;; js-Error : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Error (unsafe-ffi-primitive 'js-Error))

;; js-AggregateError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-AggregateError (unsafe-ffi-primitive 'js-AggregateError))

;; js-EvalError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-EvalError (unsafe-ffi-primitive 'js-EvalError))

;; js-RangeError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-RangeError (unsafe-ffi-primitive 'js-RangeError))

;; js-ReferenceError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-ReferenceError (unsafe-ffi-primitive 'js-ReferenceError))

;; js-SuppressedError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-SuppressedError (unsafe-ffi-primitive 'js-SuppressedError))

;; js-SyntaxError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-SyntaxError (unsafe-ffi-primitive 'js-SyntaxError))

;; js-TypeError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-TypeError (unsafe-ffi-primitive 'js-TypeError))

;; js-URIError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-URIError (unsafe-ffi-primitive 'js-URIError))

;; js-InternalError : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-InternalError (unsafe-ffi-primitive 'js-InternalError))

;; js-Number : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Number (unsafe-ffi-primitive 'js-Number))

;; js-BigInt : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-BigInt (unsafe-ffi-primitive 'js-BigInt))

;; js-Math : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Math (unsafe-ffi-primitive 'js-Math))

;; js-Date : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Date (unsafe-ffi-primitive 'js-Date))

;; js-Temporal : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Temporal (unsafe-ffi-primitive 'js-Temporal))

;; js-number-epsilon : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-epsilon (unsafe-ffi-primitive 'js-number-epsilon))

;; js-number-max-safe-integer : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-max-safe-integer (unsafe-ffi-primitive 'js-number-max-safe-integer))

;; js-number-max-value : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-max-value (unsafe-ffi-primitive 'js-number-max-value))

;; js-number-min-safe-integer : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-min-safe-integer (unsafe-ffi-primitive 'js-number-min-safe-integer))

;; js-number-min-value : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-min-value (unsafe-ffi-primitive 'js-number-min-value))

;; js-number-nan : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-nan (unsafe-ffi-primitive 'js-number-nan))

;; js-number-negative-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-negative-infinity (unsafe-ffi-primitive 'js-number-negative-infinity))

;; js-number-positive-infinity : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-positive-infinity (unsafe-ffi-primitive 'js-number-positive-infinity))

;; js-number-finite? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-finite? (unsafe-ffi-primitive 'js-number-finite?))

;; js-number-integer? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-integer? (unsafe-ffi-primitive 'js-number-integer?))

;; js-number-nan? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-nan? (unsafe-ffi-primitive 'js-number-nan?))

;; js-number-safe-integer? : ffi (f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-safe-integer? (unsafe-ffi-primitive 'js-number-safe-integer?))

;; js-number-parse-float : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-parse-float (unsafe-ffi-primitive 'js-number-parse-float))

;; js-number-parse-int : ffi (string) -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-parse-int (unsafe-ffi-primitive 'js-number-parse-int))

;; js-number-to-exponential : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-to-exponential (unsafe-ffi-primitive 'js-number-to-exponential))

;; js-number-to-fixed : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-to-fixed (unsafe-ffi-primitive 'js-number-to-fixed))

;; js-number-to-locale-string : ffi (f64 value value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-to-locale-string (unsafe-ffi-primitive 'js-number-to-locale-string))

;; js-number-to-precision : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-to-precision (unsafe-ffi-primitive 'js-number-to-precision))

;; js-number-to-string : ffi (f64 value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-to-string (unsafe-ffi-primitive 'js-number-to-string))

;; js-number-value-of : ffi (f64) -> (f64)
;;   Raw binding generated for webracket/unsafe/array.
(define js-number-value-of (unsafe-ffi-primitive 'js-number-value-of))

;; js-String : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-String (unsafe-ffi-primitive 'js-String))

;; js-RegExp : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-RegExp (unsafe-ffi-primitive 'js-RegExp))

;; js-array : ffi (value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array (unsafe-ffi-primitive 'js-array))

;; js-array/extern : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array/extern (unsafe-ffi-primitive 'js-array/extern))

;; js-TypedArray : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-TypedArray (unsafe-ffi-primitive 'js-TypedArray))

;; js-Int8Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Int8Array (unsafe-ffi-primitive 'js-Int8Array))

;; js-Uint8Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Uint8Array (unsafe-ffi-primitive 'js-Uint8Array))

;; js-Uint8ClampedArray : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Uint8ClampedArray (unsafe-ffi-primitive 'js-Uint8ClampedArray))

;; js-Int16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Int16Array (unsafe-ffi-primitive 'js-Int16Array))

;; js-Uint16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Uint16Array (unsafe-ffi-primitive 'js-Uint16Array))

;; js-Int32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Int32Array (unsafe-ffi-primitive 'js-Int32Array))

;; js-Uint32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Uint32Array (unsafe-ffi-primitive 'js-Uint32Array))

;; js-BigInt64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-BigInt64Array (unsafe-ffi-primitive 'js-BigInt64Array))

;; js-BigUint64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-BigUint64Array (unsafe-ffi-primitive 'js-BigUint64Array))

;; js-Float16Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Float16Array (unsafe-ffi-primitive 'js-Float16Array))

;; js-Float32Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Float32Array (unsafe-ffi-primitive 'js-Float32Array))

;; js-Float64Array : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Float64Array (unsafe-ffi-primitive 'js-Float64Array))

;; js-Map : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Map (unsafe-ffi-primitive 'js-Map))

;; js-Set : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Set (unsafe-ffi-primitive 'js-Set))

;; js-WeakMap : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-WeakMap (unsafe-ffi-primitive 'js-WeakMap))

;; js-WeakSet : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-WeakSet (unsafe-ffi-primitive 'js-WeakSet))

;; js-ArrayBuffer : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-ArrayBuffer (unsafe-ffi-primitive 'js-ArrayBuffer))

;; js-SharedArrayBuffer : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-SharedArrayBuffer (unsafe-ffi-primitive 'js-SharedArrayBuffer))

;; js-DataView : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-DataView (unsafe-ffi-primitive 'js-DataView))

;; js-Atomics : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Atomics (unsafe-ffi-primitive 'js-Atomics))

;; js-JSON : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-JSON (unsafe-ffi-primitive 'js-JSON))

;; js-WeakRef : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-WeakRef (unsafe-ffi-primitive 'js-WeakRef))

;; js-FinalizationRegistry : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-FinalizationRegistry (unsafe-ffi-primitive 'js-FinalizationRegistry))

;; js-Iterator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Iterator (unsafe-ffi-primitive 'js-Iterator))

;; js-AsyncIterator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-AsyncIterator (unsafe-ffi-primitive 'js-AsyncIterator))

;; js-Promise : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Promise (unsafe-ffi-primitive 'js-Promise))

;; js-GeneratorFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-GeneratorFunction (unsafe-ffi-primitive 'js-GeneratorFunction))

;; js-AsyncGeneratorFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-AsyncGeneratorFunction (unsafe-ffi-primitive 'js-AsyncGeneratorFunction))

;; js-Generator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Generator (unsafe-ffi-primitive 'js-Generator))

;; js-AsyncGenerator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-AsyncGenerator (unsafe-ffi-primitive 'js-AsyncGenerator))

;; js-AsyncFunction : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-AsyncFunction (unsafe-ffi-primitive 'js-AsyncFunction))

;; js-DisposableStack : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-DisposableStack (unsafe-ffi-primitive 'js-DisposableStack))

;; js-AsyncDisposableStack : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-AsyncDisposableStack (unsafe-ffi-primitive 'js-AsyncDisposableStack))

;; js-Reflect : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Reflect (unsafe-ffi-primitive 'js-Reflect))

;; js-Proxy : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Proxy (unsafe-ffi-primitive 'js-Proxy))

;; js-Intl : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-Intl (unsafe-ffi-primitive 'js-Intl))

;; js-IntlCollator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlCollator (unsafe-ffi-primitive 'js-IntlCollator))

;; js-IntlDateTimeFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlDateTimeFormat (unsafe-ffi-primitive 'js-IntlDateTimeFormat))

;; js-IntlDisplayNames : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlDisplayNames (unsafe-ffi-primitive 'js-IntlDisplayNames))

;; js-IntlDurationFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlDurationFormat (unsafe-ffi-primitive 'js-IntlDurationFormat))

;; js-IntlListFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlListFormat (unsafe-ffi-primitive 'js-IntlListFormat))

;; js-IntlLocale : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlLocale (unsafe-ffi-primitive 'js-IntlLocale))

;; js-IntlNumberFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlNumberFormat (unsafe-ffi-primitive 'js-IntlNumberFormat))

;; js-IntlPluralRules : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlPluralRules (unsafe-ffi-primitive 'js-IntlPluralRules))

;; js-IntlRelativeTimeFormat : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlRelativeTimeFormat (unsafe-ffi-primitive 'js-IntlRelativeTimeFormat))

;; js-IntlSegmenter : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-IntlSegmenter (unsafe-ffi-primitive 'js-IntlSegmenter))

;; js-array-from : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-from (unsafe-ffi-primitive 'js-array-from))

;; js-array-from-async : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-from-async (unsafe-ffi-primitive 'js-array-from-async))

;; js-array-is-array : ffi (value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-is-array (unsafe-ffi-primitive 'js-array-is-array))

;; js-array->vector : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array->vector (unsafe-ffi-primitive 'js-array->vector))

;; js-array->bytes : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array->bytes (unsafe-ffi-primitive 'js-array->bytes))

;; js-array-of : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-of (unsafe-ffi-primitive 'js-array-of))

;; js-array-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-length (unsafe-ffi-primitive 'js-array-length))

;; js-set-array-length! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/array.
(define js-set-array-length! (unsafe-ffi-primitive 'js-set-array-length!))

;; js-array-ref : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-ref (unsafe-ffi-primitive 'js-array-ref))

;; js-array-at : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-at (unsafe-ffi-primitive 'js-array-at))

;; js-array-concat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-concat (unsafe-ffi-primitive 'js-array-concat))

;; js-array-copy-within : ffi (extern i32 i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-copy-within (unsafe-ffi-primitive 'js-array-copy-within))

;; js-array-entries : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-entries (unsafe-ffi-primitive 'js-array-entries))

;; js-array-every : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-every (unsafe-ffi-primitive 'js-array-every))

;; js-array-fill : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-fill (unsafe-ffi-primitive 'js-array-fill))

;; js-array-filter : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-filter (unsafe-ffi-primitive 'js-array-filter))

;; js-array-find : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-find (unsafe-ffi-primitive 'js-array-find))

;; js-array-find-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-find-index (unsafe-ffi-primitive 'js-array-find-index))

;; js-array-find-last : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-find-last (unsafe-ffi-primitive 'js-array-find-last))

;; js-array-find-last-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-find-last-index (unsafe-ffi-primitive 'js-array-find-last-index))

;; js-array-flat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-flat (unsafe-ffi-primitive 'js-array-flat))

;; js-array-flat-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-flat-map (unsafe-ffi-primitive 'js-array-flat-map))

;; js-array-for-each : ffi (extern extern value) -> ()
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-for-each (unsafe-ffi-primitive 'js-array-for-each))

;; js-array-includes : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-includes (unsafe-ffi-primitive 'js-array-includes))

;; js-array-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-index-of (unsafe-ffi-primitive 'js-array-index-of))

;; js-array-join : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-join (unsafe-ffi-primitive 'js-array-join))

;; js-array-keys : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-keys (unsafe-ffi-primitive 'js-array-keys))

;; js-array-last-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-last-index-of (unsafe-ffi-primitive 'js-array-last-index-of))

;; js-array-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-map (unsafe-ffi-primitive 'js-array-map))

;; js-array-pop : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-pop (unsafe-ffi-primitive 'js-array-pop))

;; js-array-push : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-push (unsafe-ffi-primitive 'js-array-push))

;; js-array-reduce : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-reduce (unsafe-ffi-primitive 'js-array-reduce))

;; js-array-reduce-right : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-reduce-right (unsafe-ffi-primitive 'js-array-reduce-right))

;; js-array-reverse : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-reverse (unsafe-ffi-primitive 'js-array-reverse))

;; js-array-shift : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-shift (unsafe-ffi-primitive 'js-array-shift))

;; js-array-slice : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-slice (unsafe-ffi-primitive 'js-array-slice))

;; js-array-some : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-some (unsafe-ffi-primitive 'js-array-some))

;; js-array-sort : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-sort (unsafe-ffi-primitive 'js-array-sort))

;; js-array-splice : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-splice (unsafe-ffi-primitive 'js-array-splice))

;; js-array-to-locale-string : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-to-locale-string (unsafe-ffi-primitive 'js-array-to-locale-string))

;; js-array-to-string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-to-string (unsafe-ffi-primitive 'js-array-to-string))

;; js-array-unshift : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-unshift (unsafe-ffi-primitive 'js-array-unshift))

;; js-array-values : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-values (unsafe-ffi-primitive 'js-array-values))

;; js-array-to-reversed : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-to-reversed (unsafe-ffi-primitive 'js-array-to-reversed))

;; js-array-to-sorted : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-to-sorted (unsafe-ffi-primitive 'js-array-to-sorted))

;; js-array-to-spliced : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-to-spliced (unsafe-ffi-primitive 'js-array-to-spliced))

;; js-array-with : ffi (extern i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/array.
(define js-array-with (unsafe-ffi-primitive 'js-array-with))
