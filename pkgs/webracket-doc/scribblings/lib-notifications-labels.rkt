#lang racket/base

(require racket/contract/base)

(provide
  notification
  notification-raw
  notification?
  notifications-supported?
  notification-permission
  notification-request-permission
  make-notification-options
  notification-options?
  notification-options-body
  notification-options-icon
  notification-options-tag
  notification-options-data
  notification-options-silent
  notification-options-require-interaction
  notification-options-renotify
  make-notification
  notification-close!
  notification-title
  notification-body
  notification-tag
  notification-data
  notification-icon
  notification-require-interaction?
  notification-renotify?
  notification-silent?
  (for-label (all-defined-out)))

(define notification any/c)
(define notification-raw any/c)
(define notification? any/c)
(define notifications-supported? any/c)
(define notification-permission any/c)
(define notification-request-permission any/c)
(define make-notification-options any/c)
(define notification-options? any/c)
(define notification-options-body any/c)
(define notification-options-icon any/c)
(define notification-options-tag any/c)
(define notification-options-data any/c)
(define notification-options-silent any/c)
(define notification-options-require-interaction any/c)
(define notification-options-renotify any/c)
(define make-notification any/c)
(define notification-close! any/c)
(define notification-title any/c)
(define notification-body any/c)
(define notification-tag any/c)
(define notification-data any/c)
(define notification-icon any/c)
(define notification-require-interaction? any/c)
(define notification-renotify? any/c)
(define notification-silent? any/c)
