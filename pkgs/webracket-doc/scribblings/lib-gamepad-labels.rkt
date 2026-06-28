#lang racket/base

(require racket/contract/base)

(provide gamepads
         gamepad?
         gamepad-raw
         gamepad-supported?
         gamepad-event-gamepad
         gamepad-id
         gamepad-index
         gamepad-connected?
         gamepad-timestamp
         gamepad-mapping
         gamepad-axes
         gamepad-buttons
         gamepad-button?
         gamepad-button-raw
         gamepad-button-pressed?
         gamepad-button-touched?
         gamepad-button-value
         gamepad-add-connected-listener!
         gamepad-remove-connected-listener!
         gamepad-add-disconnected-listener!
         gamepad-remove-disconnected-listener!
         (struct-out gamepad-info)
         (struct-out gamepad-button-info)
         (for-label (all-defined-out)))

(define gamepads any/c)
(define gamepad? any/c)
(define gamepad-raw any/c)
(define gamepad-supported? any/c)
(define gamepad-event-gamepad any/c)
(define gamepad-id any/c)
(define gamepad-index any/c)
(define gamepad-connected? any/c)
(define gamepad-timestamp any/c)
(define gamepad-mapping any/c)
(define gamepad-axes any/c)
(define gamepad-buttons any/c)
(define gamepad-button? any/c)
(define gamepad-button-raw any/c)
(define gamepad-button-pressed? any/c)
(define gamepad-button-touched? any/c)
(define gamepad-button-value any/c)
(define gamepad-add-connected-listener! any/c)
(define gamepad-remove-connected-listener! any/c)
(define gamepad-add-disconnected-listener! any/c)
(define gamepad-remove-disconnected-listener! any/c)
(struct gamepad-info (raw) #:transparent)
(struct gamepad-button-info (raw) #:transparent)
