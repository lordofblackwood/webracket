#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/domrect))

(provide (struct-out dom-rect)
         dom-rect-height
         dom-rect-left
         dom-rect-top
         dom-rect-width
         dom-rect-unwrap
         dom-rect-wrap)

;; This is the canonical module version of the old `include-lib domrect` safe
;; wrapper. Raw bindings remain in `webracket/unsafe/domrect`.

(struct dom-rect (raw) #:transparent)

;; dom-rect-wrap : any/c -> dom-rect?
;;   Wrap a browser DOMRect value.
(define (dom-rect-wrap value)
  (dom-rect value))

;; dom-rect-unwrap : any/c -> any/c
;;   Unwrap a browser DOMRect value when available.
(define (dom-rect-unwrap value)
  (if (dom-rect? value)
      (dom-rect-raw value)
      value))

;; dom-rect-left : any/c -> real?
;;   Read the left coordinate of a DOMRect.
(define (dom-rect-left rect)
  (unsafe:js-dom-rect-left (dom-rect-unwrap rect)))

;; dom-rect-top : any/c -> real?
;;   Read the top coordinate of a DOMRect.
(define (dom-rect-top rect)
  (unsafe:js-dom-rect-top (dom-rect-unwrap rect)))

;; dom-rect-width : any/c -> real?
;;   Read the width of a DOMRect.
(define (dom-rect-width rect)
  (unsafe:js-dom-rect-width (dom-rect-unwrap rect)))

;; dom-rect-height : any/c -> real?
;;   Read the height of a DOMRect.
(define (dom-rect-height rect)
  (unsafe:js-dom-rect-height (dom-rect-unwrap rect)))
