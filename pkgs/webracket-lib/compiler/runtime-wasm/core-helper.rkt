#lang racket

(provide (struct-out core-runtime-helper)
         make-core-runtime-helper-index
         core-runtime-helper-ref
         core-runtime-helper->form
         core-runtime-helper-form
         core-runtime-helper-forms
         function-forms->runtime-helpers)

;; A core runtime helper is a runtime function that can be emitted in the
;; monolithic runtime or exported from the experimental core runtime module.
;; When moving a function into this table, move its contract, purpose, and
;; representation notes with the registry row, and preserve the original
;; WAT-expression indentation where possible.
(struct core-runtime-helper (name export-name make-form) #:transparent)

;; function-forms->runtime-helpers : symbol? (listof datum?) -> (listof core-runtime-helper?)
;;   Register quoted WAT function forms as core runtime helpers.
(define (function-forms->runtime-helpers who forms)
  (for/list ([form (in-list forms)])
    (define name
      (and (pair? form)
           (eq? 'func (car form))
           (pair? (cdr form))
           (cadr form)))
    (unless (symbol? name)
      (error who "expected a function form, got: ~s" form))
    (core-runtime-helper name
                         (symbol->string name)
                         (lambda () form))))

;; make-core-runtime-helper-index : (listof core-runtime-helper?) -> hasheq?
;;   Build an index from Wasm function names to registered core helpers.
(define (make-core-runtime-helper-index helpers)
  (define index (make-hasheq))
  (for ([helper (in-list helpers)])
    (define name (core-runtime-helper-name helper))
    (when (hash-has-key? index name)
      (error 'make-core-runtime-helper-index
             "duplicate core runtime helper: ~a"
             name))
    (hash-set! index name helper))
  index)

;; core-runtime-helper-ref : hasheq? symbol? -> core-runtime-helper?
;;   Return the registered helper with the given Wasm function name.
(define (core-runtime-helper-ref helper-index name)
  (or (hash-ref helper-index name #f)
      (error 'core-runtime-helper-ref
             "unknown core runtime helper: ~a"
             name)))

;; export-function-form : datum? string? -> datum?
;;   Add an export declaration to a generated function form.
(define (export-function-form form export-name)
  (match form
    [`(func ,name ,body ...)
     `(func ,name (export ,export-name) ,@body)]
    [_
     (error 'export-function-form
            "expected a function form, got: ~s"
            form)]))

;; core-runtime-helper->form : core-runtime-helper? [#:export? boolean?] [#:export-name (or/c string? #f)] -> datum?
;;   Render a registered helper as a WAT function form.
(define (core-runtime-helper->form helper
                                   #:export? [export? #f]
                                   #:export-name [export-name #f])
  (define form ((core-runtime-helper-make-form helper)))
  (if export?
      (export-function-form form (or export-name
                                     (core-runtime-helper-export-name helper)))
      form))

;; core-runtime-helper-form : hasheq? symbol? [#:export? boolean?] [#:export-name (or/c string? #f)] -> datum?
;;   Render a named registered helper as a WAT function form.
(define (core-runtime-helper-form helper-index
                                  name
                                  #:export? [export? #f]
                                  #:export-name [export-name #f])
  (core-runtime-helper->form (core-runtime-helper-ref helper-index name)
                             #:export? export?
                             #:export-name export-name))

;; core-runtime-helper-forms : (listof core-runtime-helper?) [#:export? boolean?] -> (listof datum?)
;;   Render all registered core helper function forms.
(define (core-runtime-helper-forms helpers #:export? [export? #f])
  (for/list ([helper (in-list helpers)])
    (core-runtime-helper->form helper #:export? export?)))
