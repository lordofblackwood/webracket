#lang racket/base

(provide ffi-file->unsafe-export-symbols
         ffi-file->unsafe-binding-datums
         ffi-file->unsafe-module-source
         write-unsafe-ffi-module-source
         unsafe-ffi-module-parity-row
         unsafe-ffi-module-parity-row?
         unsafe-ffi-module-parity-row-module
         unsafe-ffi-module-parity-row-ffi-path
         unsafe-ffi-module-parity-row-declared-exports
         unsafe-ffi-module-parity-row-actual-exports
         unsafe-ffi-module-parity-row-missing
         unsafe-ffi-module-parity-row-extra
         unsafe-ffi-module-parity-row-ok?
         unsafe-ffi-module-parity-rows
         unsafe-console-ffi-export-symbols
         unsafe-math-ffi-export-symbols
         unsafe-temp-ffi-export-symbols)

(require (only-in "../private/define-foreign.rkt" ffi-file->foreigns)
         (only-in "../private/structs.rkt"
                  foreign-racket-name
                  foreign-argument-types
                  foreign-result-types)
         "ffi-module-registry.rkt"
         racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/port
         racket/string)

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
   ";; Raw exports are compiler-recognized aliases for active .ffi primitives.\n\n"
   (format "(require (only-in ~s unsafe-ffi-primitive))\n\n" require-path)
   "(provide"
   (apply string-append
          (for/list ([binding (in-list bindings)])
            (format "\n ~a" (car binding))))
   ")\n\n"
   (string-join
    (for/list ([binding (in-list bindings)])
      (define name (car binding))
      (define arg-types (cadr binding))
      (define result-types (caddr binding))
      (format ";; ~a : ffi ~s -> ~s\n;;   Raw binding generated for ~a.\n(define ~a (unsafe-ffi-primitive '~a))"
              name
              arg-types
              result-types
              module-name
              name
              name))
    "\n\n")
   "\n"))

;; write-unsafe-ffi-module-source : path-string? symbol? path-string? path-string? -> void?
;;   Write the generated unsafe module source for a `.ffi` declaration file.
(define (write-unsafe-ffi-module-source ffi-path module-name require-path output-path)
  (call-with-output-file output-path
    (lambda (out)
      (display (ffi-file->unsafe-module-source ffi-path module-name require-path)
               out))
    #:exists 'truncate/replace))

(struct unsafe-ffi-module-parity-row
  (module ffi-path declared-exports actual-exports missing extra)
  #:transparent)

;; unsafe-ffi-module-parity-row-ok? : row? -> boolean?
;;   Check whether one unsafe module exactly matches its `.ffi` declarations.
(define (unsafe-ffi-module-parity-row-ok? row)
  (and (null? (unsafe-ffi-module-parity-row-missing row))
       (null? (unsafe-ffi-module-parity-row-extra row))))

;; unsafe-module-runtime-exports : module-path? -> (listof symbol?)
;;   Reflect phase-0 value exports for a loadable unsafe module.
(define (unsafe-module-runtime-exports module-path)
  (define collection-paths (current-library-collection-paths))
  (parameterize ([current-namespace (make-base-namespace)])
    (current-library-collection-paths collection-paths)
    (namespace-require module-path)
    (define-values (value-exports _syntax-exports)
      (module->exports module-path))
    (define phase-0 (assoc 0 value-exports))
    (if phase-0
        (map car (cdr phase-0))
        '())))

;; build-unsafe-ffi-module-parity-row : module-path? path-string? -> row?
;;   Compare one migrated unsafe module's exports against its `.ffi` file.
(define (build-unsafe-ffi-module-parity-row module-path ffi-path)
  (define declared (sort (ffi-file->unsafe-export-symbols ffi-path) symbol<?))
  (define actual   (sort (unsafe-module-runtime-exports module-path) symbol<?))
  (unsafe-ffi-module-parity-row
   module-path
   ffi-path
   declared
   actual
   (remove* actual declared)
   (remove* declared actual)))

;; unsafe-ffi-module-parity-rows : -> (listof row?)
;;   Compare all migrated unsafe FFI modules that currently have `.ffi` owners.
(define (unsafe-ffi-module-parity-rows)
  (for/list ([module-name (in-list (migrated-unsafe-ffi-modules))])
    (build-unsafe-ffi-module-parity-row module-name
                                        (module-provider->ffi-path module-name))))

;; unsafe-console-ffi-export-symbols : -> (listof symbol?)
;;   Return the raw console binding names declared by ffi/console.ffi.
(define (unsafe-console-ffi-export-symbols)
  (ffi-file->unsafe-export-symbols
   (module-provider->ffi-path 'webracket/unsafe/console)))

;; unsafe-math-ffi-export-symbols : -> (listof symbol?)
;;   Return the raw Math binding names declared by ffi/math.ffi.
(define (unsafe-math-ffi-export-symbols)
  (ffi-file->unsafe-export-symbols
   (module-provider->ffi-path 'webracket/unsafe/math)))

;; unsafe-temp-ffi-export-symbols : -> (listof symbol?)
;;   Return the raw temp binding names declared by ffi/temp.ffi.
(define (unsafe-temp-ffi-export-symbols)
  (ffi-file->unsafe-export-symbols
   (module-provider->ffi-path 'webracket/unsafe/temp)))

;; generated-source-matches? : path-string? path-string? symbol? string? -> boolean?
;;   Check whether output-path already matches generated source.
(define (generated-source-matches? ffi-path output-path module-name require-path)
  (and (file-exists? output-path)
       (string=? (file->string output-path)
                 (ffi-file->unsafe-module-source ffi-path module-name require-path))))

;; print-unsafe-ffi-module-cli-help : -> void?
;;   Print the supported command forms.
(define (print-unsafe-ffi-module-cli-help)
  (displayln "usage:")
  (displayln "  racket unsafe-ffi-module.rkt generate ffi-path module-name require-path output-path")
  (displayln "  racket unsafe-ffi-module.rkt check ffi-path module-name require-path output-path"))

(module+ main
  (define args
    (command-line
     #:program "unsafe-ffi-module"
     #:args args
     args))
  (match args
    [(list "generate" ffi-path module-name require-path output-path)
     (write-unsafe-ffi-module-source ffi-path
                                     (string->symbol module-name)
                                     require-path
                                     output-path)]
    [(list "check" ffi-path module-name require-path output-path)
     (unless (generated-source-matches? ffi-path
                                        output-path
                                        (string->symbol module-name)
                                        require-path)
       (define generated
         (ffi-file->unsafe-module-source ffi-path
                                         (string->symbol module-name)
                                         require-path))
       (define existing
         (if (file-exists? output-path)
             (file->string output-path)
             ""))
       (eprintf "unsafe FFI module is out of date: ~a\n" output-path)
       (eprintf "generated bytes: ~a existing bytes: ~a\n"
                (string-length generated)
                (string-length existing))
       (exit 1))]
    [_
     (print-unsafe-ffi-module-cli-help)
     (exit 2)]))
