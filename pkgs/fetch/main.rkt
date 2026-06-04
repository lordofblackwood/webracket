#lang webracket/base

(require racket/include
         racket/vector
         webracket/unsafe/dom
         (only-in webracket/primitives
                  external?
                  procedure->external)
         (for-syntax racket/base))

;; Public module wrapper for the legacy Fetch helper library.
;;
;; The included file is intentionally kept as the single implementation for now:
;; it already defines the safe wrapper surface, while this module supplies the
;; unsafe JS bindings explicitly for module-based programs.

(provide (all-defined-out))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(include/reader "../../lib/libs/fetch.rkt" read-syntax/skip-first-line)
