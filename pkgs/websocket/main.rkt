#lang webracket/base

(require racket/include
         webracket/unsafe/dom
         webracket/unsafe/websocket
         (only-in webracket/primitives
                  external?
                  procedure->external)
         (for-syntax racket/base))

;; Public module wrapper for the legacy WebSocket helper library.
;;
;; The included file owns the safe wrapper surface; this module supplies the
;; unsafe WebSocket and generic JS bindings explicitly for module-based programs.

(provide (all-defined-out))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(include/reader "../../lib/libs/websocket.rkt" read-syntax/skip-first-line)
