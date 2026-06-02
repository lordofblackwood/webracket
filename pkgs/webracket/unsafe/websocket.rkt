#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-websocket-new
 js-websocket-send
 js-websocket-close
 js-websocket-url
 js-websocket-ready-state
 js-websocket-buffered-amount
 js-websocket-protocol
 js-websocket-extensions)

;; js-websocket-new : ffi (string value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-new (unsafe-ffi-primitive 'js-websocket-new))

;; js-websocket-send : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-send (unsafe-ffi-primitive 'js-websocket-send))

;; js-websocket-close : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-close (unsafe-ffi-primitive 'js-websocket-close))

;; js-websocket-url : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-url (unsafe-ffi-primitive 'js-websocket-url))

;; js-websocket-ready-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-ready-state (unsafe-ffi-primitive 'js-websocket-ready-state))

;; js-websocket-buffered-amount : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-buffered-amount (unsafe-ffi-primitive 'js-websocket-buffered-amount))

;; js-websocket-protocol : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-protocol (unsafe-ffi-primitive 'js-websocket-protocol))

;; js-websocket-extensions : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/websocket.
(define js-websocket-extensions (unsafe-ffi-primitive 'js-websocket-extensions))
