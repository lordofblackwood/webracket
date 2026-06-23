#lang racket/base

(require browser/dom
         racket/include
         webracket/list
         racket/unsafe/undefined
         webracket/define-key
         (only-in webracket/primitives
                  external?
                  js-log
                  procedure->external))

;; Public entry point for the `web-pict` collection.
;;
;; The included entry file defines exactly the legacy public surface with one
;; `define-values`, so `(all-defined-out)` exports that surface without
;; re-export facade metadata that Webify currently cannot resolve.

(provide (all-defined-out))

(include "entry.rkt")
