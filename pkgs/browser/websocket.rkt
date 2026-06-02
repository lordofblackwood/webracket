#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/websocket))

(provide websocket-buffered-amount
         websocket-close
         websocket-extensions
         websocket-new
         websocket-protocol
         websocket-ready-state
         websocket-send
         websocket-url)

(define websocket-new unsafe:js-websocket-new)
(define websocket-send unsafe:js-websocket-send)
(define websocket-close unsafe:js-websocket-close)
(define websocket-url unsafe:js-websocket-url)
(define websocket-ready-state unsafe:js-websocket-ready-state)
(define websocket-buffered-amount unsafe:js-websocket-buffered-amount)
(define websocket-protocol unsafe:js-websocket-protocol)
(define websocket-extensions unsafe:js-websocket-extensions)
