#lang racket/base

(require racket/contract/base)

(provide make-worker
         worker-supported?
         worker-raw
         worker?
         worker-post-message!
         worker-terminate!
         worker-onmessage!
         worker-onerror!
         worker-add-event-listener!
         worker-remove-event-listener!
         make-worker-options
         worker-options?
         worker-options-type
         worker-options-name
         worker-options-credentials
         (for-label (all-defined-out)))

(define make-worker any/c)
(define worker-supported? any/c)
(define worker-raw any/c)
(define worker? any/c)
(define worker-post-message! any/c)
(define worker-terminate! any/c)
(define worker-onmessage! any/c)
(define worker-onerror! any/c)
(define worker-add-event-listener! any/c)
(define worker-remove-event-listener! any/c)
(define make-worker-options any/c)
(define worker-options? any/c)
(define worker-options-type any/c)
(define worker-options-name any/c)
(define worker-options-credentials any/c)
