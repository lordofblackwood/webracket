#lang racket/base

(require "../unsafe/standard.rkt")

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
         standard-object
         standard-parse-float
         standard-parse-int
         standard-truthy?)

;; Public wrappers for safe, value-oriented parts of JavaScript's standard
;; global/Number surface. Raw object and eval bindings stay in
;; `webracket/unsafe/standard`.

(define standard-infinity js-infinity)
(define standard-nan js-nan)
(define standard-finite? js-finite?)
(define standard-nan? js-nan?)
(define standard-parse-float js-parse-float)
(define standard-parse-int js-parse-int)
(define standard-decode-uri js-decode-uri)
(define standard-decode-uri-component js-decode-uri-component)
(define standard-encode-uri js-encode-uri)
(define standard-encode-uri-component js-encode-uri-component)
(define standard-truthy? js-truthy?)
(define standard-number-finite? js-number-finite?)
(define standard-number-integer? js-number-integer?)
(define standard-number-nan? js-number-nan?)
(define standard-number-safe-integer? js-number-safe-integer?)
(define standard-number-parse-float js-number-parse-float)
(define standard-number-parse-int js-number-parse-int)
(define standard-object js-object)
