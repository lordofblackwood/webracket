#lang racket/base

(require browser/dom
         racket/include
         racket/list
         racket/match
         racket/math
         webracket/define-key
         (only-in webracket/primitives
                  external?
                  js-log
                  procedure->external))

;; Internal entry wrapper for tools that want a private implementation module.
;; Keep this in sync with `web-pict/main.rkt` by including the same boundary.

(provide (all-defined-out))

(include "../entry.rkt")
