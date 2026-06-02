#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/standard))

(provide standard-decode-uri
         standard-decode-uri-component
         standard-encode-uri
         standard-encode-uri-component
         standard-finite?
         standard-infinity
         standard-nan
         standard-nan?
         standard-number-finite?
         standard-number-integer?
         standard-number-nan?
         standard-number-parse-float
         standard-number-parse-int
         standard-number-safe-integer?
         standard-parse-float
         standard-parse-int
         standard-truthy?)

;; Public wrappers for safe, value-oriented parts of JavaScript's standard
;; global/Number surface. Raw object and eval bindings stay in
;; `webracket/unsafe/standard`.

(define standard-infinity unsafe:js-infinity)
(define standard-nan unsafe:js-nan)
(define standard-finite? unsafe:js-finite?)
(define standard-nan? unsafe:js-nan?)
(define standard-parse-float unsafe:js-parse-float)
(define standard-parse-int unsafe:js-parse-int)
(define standard-decode-uri unsafe:js-decode-uri)
(define standard-decode-uri-component unsafe:js-decode-uri-component)
(define standard-encode-uri unsafe:js-encode-uri)
(define standard-encode-uri-component unsafe:js-encode-uri-component)
(define standard-truthy? unsafe:js-truthy?)
(define standard-number-finite? unsafe:js-number-finite?)
(define standard-number-integer? unsafe:js-number-integer?)
(define standard-number-nan? unsafe:js-number-nan?)
(define standard-number-safe-integer? unsafe:js-number-safe-integer?)
(define standard-number-parse-float unsafe:js-number-parse-float)
(define standard-number-parse-int unsafe:js-number-parse-int)
