#lang racket/base

(require racket/contract/base)

(provide history
         history-raw
         history?
         history-supported?
         history-length
         history-state
         history-back!
         history-forward!
         history-go!
         history-push-state!
         history-replace-state!
         history-on-popstate!
         history-add-popstate-listener!
         history-remove-popstate-listener!
         (struct-out history-info)
         (for-label (all-defined-out)))

(define history any/c)
(define history-raw any/c)
(define history? any/c)
(define history-supported? any/c)
(define history-length any/c)
(define history-state any/c)
(define history-back! any/c)
(define history-forward! any/c)
(define history-go! any/c)
(define history-push-state! any/c)
(define history-replace-state! any/c)
(define history-on-popstate! any/c)
(define history-add-popstate-listener! any/c)
(define history-remove-popstate-listener! any/c)
(struct history-info (raw) #:transparent)
