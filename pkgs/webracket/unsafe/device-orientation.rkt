#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-device-orientation-supported?
 js-device-motion-supported?
 js-device-orientation-permission-requestable?
 js-device-motion-permission-requestable?
 js-device-orientation-event?
 js-device-motion-event?
 js-device-orientation-request-permission
 js-device-motion-request-permission
 js-device-orientation-add-listener!
 js-device-orientation-remove-listener!
 js-device-orientation-add-absolute-listener!
 js-device-orientation-remove-absolute-listener!
 js-device-motion-add-listener!
 js-device-motion-remove-listener!
 js-device-orientation-event-absolute?
 js-device-orientation-event-alpha
 js-device-orientation-event-beta
 js-device-orientation-event-gamma
 js-device-orientation-event-compass-heading
 js-device-orientation-event-compass-accuracy
 js-device-motion-event-acceleration-x
 js-device-motion-event-acceleration-y
 js-device-motion-event-acceleration-z
 js-device-motion-event-gravity-acceleration-x
 js-device-motion-event-gravity-acceleration-y
 js-device-motion-event-gravity-acceleration-z
 js-device-motion-event-rotation-alpha
 js-device-motion-event-rotation-beta
 js-device-motion-event-rotation-gamma
 js-device-motion-event-interval)

;; js-device-orientation-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-supported? (unsafe-ffi-primitive 'js-device-orientation-supported?))

;; js-device-motion-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-supported? (unsafe-ffi-primitive 'js-device-motion-supported?))

;; js-device-orientation-permission-requestable? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-permission-requestable? (unsafe-ffi-primitive 'js-device-orientation-permission-requestable?))

;; js-device-motion-permission-requestable? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-permission-requestable? (unsafe-ffi-primitive 'js-device-motion-permission-requestable?))

;; js-device-orientation-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event? (unsafe-ffi-primitive 'js-device-orientation-event?))

;; js-device-motion-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event? (unsafe-ffi-primitive 'js-device-motion-event?))

;; js-device-orientation-request-permission : ffi (boolean) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-request-permission (unsafe-ffi-primitive 'js-device-orientation-request-permission))

;; js-device-motion-request-permission : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-request-permission (unsafe-ffi-primitive 'js-device-motion-request-permission))

;; js-device-orientation-add-listener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-add-listener! (unsafe-ffi-primitive 'js-device-orientation-add-listener!))

;; js-device-orientation-remove-listener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-remove-listener! (unsafe-ffi-primitive 'js-device-orientation-remove-listener!))

;; js-device-orientation-add-absolute-listener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-add-absolute-listener! (unsafe-ffi-primitive 'js-device-orientation-add-absolute-listener!))

;; js-device-orientation-remove-absolute-listener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-remove-absolute-listener! (unsafe-ffi-primitive 'js-device-orientation-remove-absolute-listener!))

;; js-device-motion-add-listener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-add-listener! (unsafe-ffi-primitive 'js-device-motion-add-listener!))

;; js-device-motion-remove-listener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-remove-listener! (unsafe-ffi-primitive 'js-device-motion-remove-listener!))

;; js-device-orientation-event-absolute? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event-absolute? (unsafe-ffi-primitive 'js-device-orientation-event-absolute?))

;; js-device-orientation-event-alpha : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event-alpha (unsafe-ffi-primitive 'js-device-orientation-event-alpha))

;; js-device-orientation-event-beta : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event-beta (unsafe-ffi-primitive 'js-device-orientation-event-beta))

;; js-device-orientation-event-gamma : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event-gamma (unsafe-ffi-primitive 'js-device-orientation-event-gamma))

;; js-device-orientation-event-compass-heading : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event-compass-heading (unsafe-ffi-primitive 'js-device-orientation-event-compass-heading))

;; js-device-orientation-event-compass-accuracy : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-orientation-event-compass-accuracy (unsafe-ffi-primitive 'js-device-orientation-event-compass-accuracy))

;; js-device-motion-event-acceleration-x : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-acceleration-x (unsafe-ffi-primitive 'js-device-motion-event-acceleration-x))

;; js-device-motion-event-acceleration-y : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-acceleration-y (unsafe-ffi-primitive 'js-device-motion-event-acceleration-y))

;; js-device-motion-event-acceleration-z : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-acceleration-z (unsafe-ffi-primitive 'js-device-motion-event-acceleration-z))

;; js-device-motion-event-gravity-acceleration-x : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-gravity-acceleration-x (unsafe-ffi-primitive 'js-device-motion-event-gravity-acceleration-x))

;; js-device-motion-event-gravity-acceleration-y : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-gravity-acceleration-y (unsafe-ffi-primitive 'js-device-motion-event-gravity-acceleration-y))

;; js-device-motion-event-gravity-acceleration-z : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-gravity-acceleration-z (unsafe-ffi-primitive 'js-device-motion-event-gravity-acceleration-z))

;; js-device-motion-event-rotation-alpha : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-rotation-alpha (unsafe-ffi-primitive 'js-device-motion-event-rotation-alpha))

;; js-device-motion-event-rotation-beta : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-rotation-beta (unsafe-ffi-primitive 'js-device-motion-event-rotation-beta))

;; js-device-motion-event-rotation-gamma : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-rotation-gamma (unsafe-ffi-primitive 'js-device-motion-event-rotation-gamma))

;; js-device-motion-event-interval : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/device-orientation.
(define js-device-motion-event-interval (unsafe-ffi-primitive 'js-device-motion-event-interval))
