#lang racket/base

(require racket/contract/base)

(provide fullscreen-supported?
         fullscreen-enabled?
         fullscreen-element
         fullscreen-active?
         fullscreen-request!
         fullscreen-exit!
         fullscreen-add-change-listener!
         fullscreen-remove-change-listener!
         fullscreen-add-error-listener!
         fullscreen-remove-error-listener!
         (for-label (all-defined-out)))

(define fullscreen-supported? any/c)
(define fullscreen-enabled? any/c)
(define fullscreen-element any/c)
(define fullscreen-active? any/c)
(define fullscreen-request! any/c)
(define fullscreen-exit! any/c)
(define fullscreen-add-change-listener! any/c)
(define fullscreen-remove-change-listener! any/c)
(define fullscreen-add-error-listener! any/c)
(define fullscreen-remove-error-listener! any/c)
