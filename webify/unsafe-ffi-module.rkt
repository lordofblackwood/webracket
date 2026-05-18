#lang racket/base

(provide ffi-file->unsafe-export-symbols
         ffi-file->unsafe-binding-datums
         ffi-file->unsafe-module-source
         unsafe-console-ffi-export-symbols
         unsafe-math-ffi-export-symbols)

(require (only-in "../define-foreign.rkt" ffi-file->foreigns)
         (only-in "../structs.rkt"
                  foreign-racket-name
                  foreign-argument-types
                  foreign-result-types)
         racket/format
         racket/runtime-path)

(define-runtime-path console-ffi-path "../ffi/console.ffi")
(define-runtime-path math-ffi-path "../ffi/math.ffi")

;; ffi-file->unsafe-export-symbols : path-string? -> (listof symbol?)
;;   Return the raw binding names that an unsafe module must export.
(define (ffi-file->unsafe-export-symbols path)
  (map foreign-racket-name (ffi-file->foreigns path)))

;; ffi-file->unsafe-binding-datums : path-string? -> (listof list?)
;;   Return generated-module metadata for each raw unsafe binding.
(define (ffi-file->unsafe-binding-datums path)
  (for/list ([foreign (in-list (ffi-file->foreigns path))])
    (list (foreign-racket-name foreign)
          (foreign-argument-types foreign)
          (foreign-result-types foreign))))

;; ffi-file->unsafe-module-source : path-string? symbol? string? -> string?
;;   Generate the default unsafe module skeleton for a `.ffi` declaration file.
(define (ffi-file->unsafe-module-source path module-name require-path)
  (define bindings (ffi-file->unsafe-binding-datums path))
  (string-append
   "#lang racket/base\n\n"
   ";; Generated from a WebRacket .ffi declaration file.\n"
   ";; Replace individual placeholder bodies with direct import-backed code\n"
   ";; as the module bridge grows first-class .ffi support.\n\n"
   (format "(require ~s)\n\n" require-path)
   "(provide"
   (apply string-append
          (for/list ([binding (in-list bindings)])
            (format "\n ~a" (car binding))))
   ")\n\n"
   (apply
    string-append
    (for/list ([binding (in-list bindings)])
      (define name (car binding))
      (define arg-types (cadr binding))
      (define result-types (caddr binding))
      (format ";; ~a : ffi ~s -> ~s\n;;   Placeholder raw binding generated for ~a.\n(define ~a\n  (make-unsafe-ffi-placeholder '~a ~a))\n\n"
              name
              arg-types
              result-types
              module-name
              name
              name
              (length arg-types))))))

;; unsafe-console-ffi-export-symbols : -> (listof symbol?)
;;   Return the raw console binding names declared by ffi/console.ffi.
(define (unsafe-console-ffi-export-symbols)
  (ffi-file->unsafe-export-symbols console-ffi-path))

;; unsafe-math-ffi-export-symbols : -> (listof symbol?)
;;   Return the raw Math binding names declared by ffi/math.ffi.
(define (unsafe-math-ffi-export-symbols)
  (ffi-file->unsafe-export-symbols math-ffi-path))
