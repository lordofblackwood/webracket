#lang racket/base

(provide ffi-module-registry-row
         ffi-module-registry-row?
         ffi-module-registry-row-module
         ffi-module-registry-row-ffi-filename
         ffi-module-registry-row-ffi-path
         ffi-module-registry-rows
         module-provider->ffi-filename
         module-provider->ffi-path
         migrated-unsafe-ffi-modules)

(require racket/file
         racket/list
         racket/path
         racket/runtime-path)

(define-runtime-path repo-root "..")
(define-runtime-path ffi-root "../ffi")
(define-runtime-path js-root "../js")
(define-runtime-path unsafe-root "../unsafe")

(struct ffi-module-registry-row (module ffi-filename ffi-path)
  #:transparent)

;; path-basename-string : path-string? -> string?
;;   Return the final path element as a string.
(define (path-basename-string path)
  (path->string (file-name-from-path path)))

;; ffi-path->stem : path-string? -> string?
;;   Return a declaration filename without its `.ffi` suffix.
(define (ffi-path->stem path)
  (path->string
   (path-replace-extension
    (string->path (path-basename-string path))
    #"")))

;; module-file-exists? : path? string? -> boolean?
;;   Check whether the module file for an ffi stem exists.
(define (module-file-exists? root stem)
  (file-exists? (build-path root (string-append stem ".rkt"))))

;; ffi-stem->public-module : string? -> symbol?
;;   Derive the public module path for an ffi stem.
(define (ffi-stem->public-module stem)
  (string->symbol (format "js/~a" stem)))

;; ffi-stem->unsafe-module : string? -> symbol?
;;   Derive the unsafe module path for an ffi stem.
(define (ffi-stem->unsafe-module stem)
  (string->symbol (format "webracket/unsafe/~a" stem)))

;; ffi-path->module-registry-rows : path? -> (listof ffi-module-registry-row?)
;;   Generate registry rows for migrated modules backed by this declaration file.
(define (ffi-path->module-registry-rows ffi-path)
  (define stem         (ffi-path->stem ffi-path))
  (define ffi-filename (path-basename-string ffi-path))
  (append
   (if (module-file-exists? js-root stem)
       (list (ffi-module-registry-row (ffi-stem->public-module stem)
                                      ffi-filename
                                      ffi-path))
       '())
   (if (module-file-exists? unsafe-root stem)
       (list (ffi-module-registry-row (ffi-stem->unsafe-module stem)
                                      ffi-filename
                                      ffi-path))
       '())))

;; ffi-module-registry-rows : (listof ffi-module-registry-row?)
;;   Discover migrated module providers from `ffi/*.ffi` and existing modules.
(define ffi-module-registry-rows
  (sort
   (append-map ffi-path->module-registry-rows
               (find-files (lambda (path)
                             (equal? (path-get-extension path) #".ffi"))
                           ffi-root))
   symbol<?
   #:key ffi-module-registry-row-module))

;; module-provider->registry-row : symbol? -> (or/c ffi-module-registry-row? #f)
;;   Find the registry row for a module provider.
(define (module-provider->registry-row module-name)
  (for/first ([row (in-list ffi-module-registry-rows)]
              #:when (eq? module-name (ffi-module-registry-row-module row)))
    row))

;; module-provider->ffi-filename : symbol? -> (or/c path-string? #f)
;;   Return the ffi bundle that a WebRacket module provider needs at runtime.
(define (module-provider->ffi-filename module-name)
  (define row (module-provider->registry-row module-name))
  (and row (ffi-module-registry-row-ffi-filename row)))

;; module-provider->ffi-path : symbol? -> (or/c path? #f)
;;   Return the source `.ffi` path for a WebRacket module provider.
(define (module-provider->ffi-path module-name)
  (define row (module-provider->registry-row module-name))
  (and row (ffi-module-registry-row-ffi-path row)))

;; migrated-unsafe-ffi-modules : -> (listof symbol?)
;;   List unsafe modules that are expected to match their `.ffi` declarations.
(define (migrated-unsafe-ffi-modules)
  (for/list ([row (in-list ffi-module-registry-rows)]
             #:do [(define module-name
                     (ffi-module-registry-row-module row))]
             #:when (regexp-match? #rx"^webracket/unsafe/"
                                   (symbol->string module-name)))
    module-name))
