#lang racket/base

(require (only-in browser/private/shared-library-structs
                  dom-rect
                  dom-rect?
                  dom-rect-raw
                  dom-rect-unwrap
                  dom-rect-wrap)
         (prefix-in unsafe: webracket/unsafe/domrect))

(provide dom-rect
         dom-rect?
         dom-rect-raw
         dom-rect-height
         dom-rect-left
         dom-rect-top
         dom-rect-width
         dom-rect-unwrap
         dom-rect-wrap)

;; This is the canonical module version of the old `include-lib domrect` safe
;; accessor layer. The wrapper struct comes from the shared DOM wrapper module
;; so values produced by `browser/element` and consumed here have one identity.

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
