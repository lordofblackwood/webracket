#lang racket/base

(require racket/contract/base
         (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))

(provide screen-orientation
         screen-orientation-raw
         screen-orientation?
         screen-orientation-supported?
         screen-orientation-type
         screen-orientation-angle
         screen-orientation-lock-type?
         screen-orientation-lock!
         screen-orientation-unlock!
         screen-orientation-on-change!
         screen-orientation-add-change-listener!
         screen-orientation-remove-change-listener!
         (struct-out screen-orientation-info)
         (for-label (all-defined-out)))

(define screen-orientation any/c)
(define screen-orientation-raw any/c)
(define screen-orientation? any/c)
(define screen-orientation-supported? any/c)
(define screen-orientation-type any/c)
(define screen-orientation-angle any/c)
(define screen-orientation-lock-type? any/c)
(define screen-orientation-lock! any/c)
(define screen-orientation-unlock! any/c)
(define screen-orientation-on-change! any/c)
(define screen-orientation-add-change-listener! any/c)
(define screen-orientation-remove-change-listener! any/c)
(struct screen-orientation-info (raw) #:transparent)
