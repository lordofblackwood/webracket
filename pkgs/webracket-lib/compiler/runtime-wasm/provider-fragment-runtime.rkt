#lang racket/base

;;; Provider Fragment Runtime Merge
;;;
;;; Experimental helpers for moving a cacheable module-bridge provider fragment
;;; into the split runtime module while leaving the user program as a separate
;;; Wasm module.

(provide (struct-out provider-runtime-merge-info)
         merge-provider-fragment-into-runtime
         retarget-provider-imports-to-runtime)

(require racket/list
         racket/match
         racket/set)

(struct provider-runtime-merge-info
  (core-form-count
   provider-form-count
   provider-import-count
   provider-colliding-definition-names
   merged-runtime-form-count)
  #:transparent)

;; module-datum? : any/c -> boolean?
;;   Check whether v is a WAT module datum.
(define (module-datum? v)
  (match v
    [`(module ,_ ...) #t]
    [_ #f]))

;; type-form? : any/c -> boolean?
;;   Check whether form is part of the shared type prefix.
(define (type-form? form)
  (match form
    [`(type ,_ ...) #t]
    [`(rec ,_ ...) #t]
    [_ #f]))

;; import-form? : any/c -> boolean?
;;   Check whether form introduces an imported Wasm item.
(define (import-form? form)
  (match form
    [`(import ,_ ...) #t]
    [`(func ,_ ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string?) ,(? string?)) #t]
         [_ #f]))]
    [`(global ,_ ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string?) ,(? string?)) #t]
         [_ #f]))]
    [`(tag ,_ ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string?) ,(? string?)) #t]
         [_ #f]))]
    [_ #f]))

;; import-from-module? : any/c string? -> boolean?
;;   Check whether form imports from module-name.
(define (import-from-module? form module-name)
  (match form
    [`(import ,(? string? imported-module) ,_ ...)
     (equal? imported-module module-name)]
    [`(func ,_ ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string? imported-module) ,_)
          (equal? imported-module module-name)]
         [_ #f]))]
    [`(global ,_ ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string? imported-module) ,_)
          (equal? imported-module module-name)]
         [_ #f]))]
    [`(tag ,_ ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string? imported-module) ,_)
          (equal? imported-module module-name)]
         [_ #f]))]
    [_ #f]))

;; provider-global-import-form? : any/c string? -> boolean?
;;   Check whether a program form imports one provider-owned global.
(define (provider-global-import-form? form provider-module-name)
  (match form
    [`(global ,_ (import ,(? string? imported-module) ,_) ,_ ...)
     (equal? imported-module provider-module-name)]
    [_ #f]))

;; retarget-provider-import-form : any/c string? string? -> any/c
;;   Retarget provider global imports from old-module-name to new-module-name.
(define (retarget-provider-import-form form old-module-name new-module-name)
  (match form
    [`(global ,name (import ,(? string? imported-module) ,export-name) ,rest ...)
     (if (equal? imported-module old-module-name)
         `(global ,name (import ,new-module-name ,export-name) ,@rest)
         form)]
    [_ form]))

;; retarget-provider-imports-to-runtime :
;;   datum? [#:provider-module string?] [#:runtime-module string?] -> datum?
;;   Return a program module whose provider globals import from runtime-module.
(define (retarget-provider-imports-to-runtime module
                                             #:provider-module
                                             [provider-module-name "provider"]
                                             #:runtime-module
                                             [runtime-module-name "core"])
  (unless (module-datum? module)
    (raise-argument-error 'retarget-provider-imports-to-runtime
                          "WAT module datum"
                          module))
  `(module
    ,@(for/list ([form (in-list (cdr module))])
        (retarget-provider-import-form form
                                       provider-module-name
                                       runtime-module-name))))

;; named-form-name : any/c symbol? -> (or/c symbol? #f)
;;   Return the name for a named top-level form of kind.
(define (named-form-name form kind)
  (and (pair? form)
       (eq? (car form) kind)
       (pair? (cdr form))
       (symbol? (cadr form))
       (cadr form)))

;; definition-name : any/c -> (or/c symbol? #f)
;;   Return the top-level definition name for non-import definitions.
(define (definition-name form)
  (and (not (import-form? form))
       (for/or ([kind (in-list '(func global data tag))])
         (named-form-name form kind))))

;; definition-names : (listof any/c) -> (set/c symbol?)
;;   Collect top-level definition names.
(define (definition-names forms)
  (for/seteq ([form (in-list forms)]
              #:do [(define name (definition-name form))]
              #:when name)
    name))

;; rename-symbol : string? symbol? -> symbol?
;;   Prefix a WAT symbol while preserving a readable base name.
(define (rename-symbol prefix sym)
  (string->symbol
   (format "$~a:~a"
           prefix
           (regexp-replace #rx"^\\$" (symbol->string sym) ""))))

;; rewrite-symbols : any/c hash? -> any/c
;;   Rewrite every symbol that appears in renames.
(define (rewrite-symbols datum renames)
  (cond
    [(symbol? datum) (hash-ref renames datum datum)]
    [(pair? datum)
     (cons (rewrite-symbols (car datum) renames)
           (rewrite-symbols (cdr datum) renames))]
    [(vector? datum)
     (list->vector
      (for/list ([item (in-vector datum)])
        (rewrite-symbols item renames)))]
    [else datum]))

;; replace-provider-entry-export : any/c symbol? string? -> any/c
;;   Rename the provider entry export so the loader can initialize providers.
(define (replace-provider-entry-export form provider-entry-name export-name)
  (match form
    [`(func ,(? (lambda (name) (eq? name provider-entry-name)) name) ,parts ...)
     `(func ,name
            ,@(for/list ([part (in-list parts)])
                (match part
                  [`(export "entry") `(export ,export-name)]
                  [_ part])))]
    [`(export "entry" (func ,(? (lambda (name) (eq? name provider-entry-name)) name)))
     `(export ,export-name (func ,name))]
    [_ form]))

;; merge-provider-fragment-into-runtime :
;;   datum? datum? [#:core-module string?] [#:provider-entry-export string?]
;;   [#:who symbol?] -> (values datum? provider-runtime-merge-info?)
;;   Return a runtime module that also contains the compiled provider fragment.
(define (merge-provider-fragment-into-runtime core-module
                                              provider-module
                                              #:core-module
                                              [core-module-name "core"]
                                              #:provider-entry-export
                                              [provider-entry-export
                                               "provider-entry"]
                                              #:who
                                              [who
                                               'merge-provider-fragment-into-runtime])
  (unless (module-datum? core-module)
    (raise-argument-error who "runtime WAT module datum" core-module))
  (unless (module-datum? provider-module)
    (raise-argument-error who "provider WAT module datum" provider-module))
  (define core-forms (cdr core-module))
  (define provider-forms (cdr provider-module))
  (define-values (core-type-prefix core-after-types)
    (splitf-at core-forms type-form?))
  (define-values (core-import-prefix core-body)
    (splitf-at core-after-types import-form?))
  (define provider-body-candidates
    (filter (lambda (form)
              (not (or (type-form? form)
                       (import-from-module? form core-module-name))))
            provider-forms))
  (define provider-imports
    (filter import-form? provider-body-candidates))
  (define provider-body/raw
    (filter (lambda (form) (not (import-form? form)))
            provider-body-candidates))
  (define core-definition-names (definition-names core-body))
  (define provider-definition-names (definition-names provider-body/raw))
  (define provider-collisions
    (sort (remove '$entry
                  (set->list (set-intersect core-definition-names
                                            provider-definition-names))
                  eq?)
          symbol<?))
  (define provider-entry-name '$provider-fragment:entry)
  (define provider-renames
    (for/hasheq ([name (in-list (cons '$entry provider-collisions))])
      (values name
              (if (eq? name '$entry)
                  provider-entry-name
                  (rename-symbol "provider-fragment" name)))))
  (define provider-body
    (for/list ([form (in-list provider-body/raw)])
      (replace-provider-entry-export
       (rewrite-symbols form provider-renames)
       provider-entry-name
       provider-entry-export)))
  (define merged-runtime-module
    `(module
      ,@core-type-prefix
      ,@(remove-duplicates (append core-import-prefix provider-imports)
                           equal?)
      ,@core-body
      ,@provider-body))
  (values merged-runtime-module
          (provider-runtime-merge-info
           (length core-forms)
           (length provider-forms)
           (length provider-imports)
           provider-collisions
           (length (cdr merged-runtime-module)))))

(module+ test
  (require rackunit)

  (define sample-core
    '(module
      (type $T (func))
      (import "js" "host" (func $host))
      (global $shared (mut i32) (i32.const 0))
      (global $core-only (mut i32) (i32.const 10))
      (func $entry (result i32) (i32.const 0))))

  (define sample-provider
    '(module
      (type $T (func))
      (func $host (import "core" "$host"))
      (global $core-only (import "core" "global:$core-only") (mut i32))
      (import "env" "extra" (func $extra))
      (global $shared (export "global:$shared") (mut i32) (i32.const 1))
      (global $provider-value
              (export "global:$provider-value")
              (mut i32)
              (i32.const 2))
      (func $entry (export "entry") (result i32)
            (global.set $provider-value (i32.const 42))
            (i32.const 0))))

  (define-values (merged info)
    (merge-provider-fragment-into-runtime sample-core sample-provider))

  (check-equal? (provider-runtime-merge-info-provider-import-count info) 1)
  (check-equal? (provider-runtime-merge-info-provider-colliding-definition-names
                 info)
                '($shared))
  (check-not-false
   (member '(import "env" "extra" (func $extra)) (cdr merged)))
  (check-false
   (member '(global $core-only
                    (import "core" "global:$core-only")
                    (mut i32))
           (cdr merged)))
  (check-not-false
   (member '(global $provider-fragment:shared
                    (export "global:$shared")
                    (mut i32)
                    (i32.const 1))
           (cdr merged)))
  (check-not-false
   (member '(func $provider-fragment:entry
                  (export "provider-entry")
                  (result i32)
                  (global.set $provider-value (i32.const 42))
                  (i32.const 0))
           (cdr merged)))
  (check-equal?
   (retarget-provider-imports-to-runtime
    '(module
      (global $provider-value
              (import "provider" "global:$provider-value")
              (mut i32))
      (global $other (import "env" "other") (mut i32))))
   '(module
     (global $provider-value
             (import "core" "global:$provider-value")
             (mut i32))
     (global $other (import "env" "other") (mut i32)))))
