#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/domrect))

(provide dom-rect-height
         dom-rect-left
         dom-rect-top
         dom-rect-width)

(define dom-rect-left unsafe:js-dom-rect-left)
(define dom-rect-top unsafe:js-dom-rect-top)
(define dom-rect-width unsafe:js-dom-rect-width)
(define dom-rect-height unsafe:js-dom-rect-height)
