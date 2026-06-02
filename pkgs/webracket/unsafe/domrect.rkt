#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-dom-rect-left
 js-dom-rect-top
 js-dom-rect-width
 js-dom-rect-height)

;; js-dom-rect-left : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/domrect.
(define js-dom-rect-left (unsafe-ffi-primitive 'js-dom-rect-left))

;; js-dom-rect-top : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/domrect.
(define js-dom-rect-top (unsafe-ffi-primitive 'js-dom-rect-top))

;; js-dom-rect-width : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/domrect.
(define js-dom-rect-width (unsafe-ffi-primitive 'js-dom-rect-width))

;; js-dom-rect-height : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/domrect.
(define js-dom-rect-height (unsafe-ffi-primitive 'js-dom-rect-height))
