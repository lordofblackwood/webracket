#lang racket/base

(provide ffi-file->unsafe-export-symbols
         unsafe-console-ffi-export-symbols)

(require (only-in "../define-foreign.rkt" ffi-file->foreigns)
         (only-in "../structs.rkt" foreign-racket-name)
         racket/runtime-path)

(define-runtime-path console-ffi-path "../ffi/console.ffi")

;; ffi-file->unsafe-export-symbols : path-string? -> (listof symbol?)
;;   Return the raw binding names that an unsafe module must export.
(define (ffi-file->unsafe-export-symbols path)
  (map foreign-racket-name (ffi-file->foreigns path)))

;; unsafe-console-ffi-export-symbols : -> (listof symbol?)
;;   Return the raw console binding names declared by ffi/console.ffi.
(define (unsafe-console-ffi-export-symbols)
  (ffi-file->unsafe-export-symbols console-ffi-path))
