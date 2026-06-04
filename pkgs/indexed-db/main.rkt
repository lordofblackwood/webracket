#lang webracket/base

(require racket/include
         webracket/unsafe/dom
         (only-in webracket/primitives
                  external?)
         (for-syntax racket/base))

;; Public module wrapper for the legacy IndexedDB helper library.
;;
;; The included file owns the safe wrapper surface; this module supplies the
;; unsafe IndexedDB/JS bindings explicitly for module-based programs.

(provide (all-defined-out))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(include/reader "../../lib/libs/indexed-db.rkt" read-syntax/skip-first-line)
