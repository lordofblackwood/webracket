#lang racket/base

(require racket/contract/base)

(provide device-orientation-supported?
         device-motion-supported?
         device-orientation-permission-requestable?
         device-motion-permission-requestable?
         device-orientation-permission-status
         device-orientation-event?
         device-motion-event?
         device-orientation-event-wrap
         device-motion-event-wrap
         device-orientation-request-permission
         device-motion-request-permission
         device-orientation-add-listener!
         device-orientation-remove-listener!
         device-orientation-add-absolute-listener!
         device-orientation-remove-absolute-listener!
         device-motion-add-listener!
         device-motion-remove-listener!
         device-orientation-event-absolute?
         device-orientation-event-alpha
         device-orientation-event-beta
         device-orientation-event-gamma
         device-orientation-event-compass-heading
         device-orientation-event-compass-accuracy
         device-motion-event-acceleration-x
         device-motion-event-acceleration-y
         device-motion-event-acceleration-z
         device-motion-event-gravity-acceleration-x
         device-motion-event-gravity-acceleration-y
         device-motion-event-gravity-acceleration-z
         device-motion-event-rotation-alpha
         device-motion-event-rotation-beta
         device-motion-event-rotation-gamma
         device-motion-event-interval
         (for-label (all-defined-out)))

(define device-orientation-supported? any/c)
(define device-motion-supported? any/c)
(define device-orientation-permission-requestable? any/c)
(define device-motion-permission-requestable? any/c)
(define device-orientation-permission-status any/c)
(define device-orientation-event? any/c)
(define device-motion-event? any/c)
(define device-orientation-event-wrap any/c)
(define device-motion-event-wrap any/c)
(define device-orientation-request-permission any/c)
(define device-motion-request-permission any/c)
(define device-orientation-add-listener! any/c)
(define device-orientation-remove-listener! any/c)
(define device-orientation-add-absolute-listener! any/c)
(define device-orientation-remove-absolute-listener! any/c)
(define device-motion-add-listener! any/c)
(define device-motion-remove-listener! any/c)
(define device-orientation-event-absolute? any/c)
(define device-orientation-event-alpha any/c)
(define device-orientation-event-beta any/c)
(define device-orientation-event-gamma any/c)
(define device-orientation-event-compass-heading any/c)
(define device-orientation-event-compass-accuracy any/c)
(define device-motion-event-acceleration-x any/c)
(define device-motion-event-acceleration-y any/c)
(define device-motion-event-acceleration-z any/c)
(define device-motion-event-gravity-acceleration-x any/c)
(define device-motion-event-gravity-acceleration-y any/c)
(define device-motion-event-gravity-acceleration-z any/c)
(define device-motion-event-rotation-alpha any/c)
(define device-motion-event-rotation-beta any/c)
(define device-motion-event-rotation-gamma any/c)
(define device-motion-event-interval any/c)
