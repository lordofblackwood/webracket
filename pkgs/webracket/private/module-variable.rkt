#lang racket/base

(provide module-variable?
         module-variable-name
         module-variable-constance
         module-variable-initialized?
         module-variable-make
         module-variable-ref
         module-variable-ref/no-check
         module-variable-set!
         module-variable-set!/check-undefined!
         module-variable-define!
         module-variables-define-consistent!
         module-variable-reference?
         module-variable-reference-instance
         module-variable-reference-variable
         module-variable-reference
         module-call-with-prompt)

(struct module-variable (name [value #:mutable] [initialized? #:mutable] [constance #:mutable])
  #:authentic)

(struct module-variable-reference-record (instance variable)
  #:authentic)

(struct uninitialized ()
  #:authentic)

(define the-uninitialized (uninitialized))

;; module-variable-reference? : any/c -> boolean?
;;   Check for lowered module variable reference records.
(define (module-variable-reference? v)
  (module-variable-reference-record? v))

;; module-variable-reference-instance : module-variable-reference? -> any/c
;;   Extract the instance field from a lowered module variable reference.
(define (module-variable-reference-instance ref)
  (module-variable-reference-record-instance ref))

;; module-variable-reference-variable : module-variable-reference? -> module-variable?
;;   Extract the cell field from a lowered module variable reference.
(define (module-variable-reference-variable ref)
  (module-variable-reference-record-variable ref))

;; module-variable-reference : any/c module-variable? -> module-variable-reference?
;;   Build a lowered module variable reference record.
(define (module-variable-reference instance variable)
  (unless (module-variable? variable)
    (raise-argument-error 'module-variable-reference "module-variable?" variable))
  (module-variable-reference-record instance variable))

;; module-variable-make : any/c -> module-variable?
;;   Create an uninitialized module variable cell with a debug/source name.
(define (module-variable-make name)
  (module-variable name the-uninitialized #f #f))

;; module-variable-ref : module-variable? -> any/c
;;   Read a module variable, rejecting uninitialized cells.
(define (module-variable-ref cell)
  (check-module-variable-initialized! cell 'module-variable-ref)
  (module-variable-value cell))

;; module-variable-ref/no-check : module-variable? -> any/c
;;   Read a module variable that webify has proven initialized.
(define (module-variable-ref/no-check cell)
  (module-variable-value cell))

;; module-variable-set! : module-variable? any/c -> void?
;;   Mutate a module variable cell.
(define (module-variable-set! cell value)
  (set-module-variable-value! cell value)
  (set-module-variable-initialized?! cell #t)
  (void))

;; module-variable-set!/check-undefined! : module-variable? any/c -> void?
;;   Mutate a cell only after validating that it was initialized.
(define (module-variable-set!/check-undefined! cell value)
  (check-module-variable-initialized! cell 'module-variable-set!/check-undefined!)
  (module-variable-set! cell value))

;; module-variable-define! : module-variable? any/c (or/c #f 'constant 'consistent) -> void?
;;   Initialize or update a module variable definition and record constance.
(define (module-variable-define! cell value constance)
  (set-module-variable-value! cell value)
  (set-module-variable-initialized?! cell #t)
  (set-module-variable-constance! cell constance)
  (void))

;; module-variables-define-consistent! : vector? vector? -> void?
;;   Define a batch of variables with consistent constance.
(define (module-variables-define-consistent! cells values)
  (unless (= (vector-length cells) (vector-length values))
    (raise-arguments-error 'module-variables-define-consistent!
                           "cell and value vectors must have the same length"
                           "cells" cells
                           "values" values))
  (for ([cell (in-vector cells)]
        [value (in-vector values)])
    (module-variable-define! cell value 'consistent))
  (void))

;; module-call-with-prompt : procedure? any/c ... -> any/c
;;   Placeholder for unsupported module-prompt semantics.
(define (module-call-with-prompt thunk . args)
  (error 'module-call-with-prompt "module prompts are not supported by WebRacket yet"))

;; check-module-variable-initialized! : module-variable? symbol? -> void?
;;   Raise a source-name-aware error if cell is uninitialized.
(define (check-module-variable-initialized! cell who)
  (unless (module-variable-initialized? cell)
    (raise-arguments-error who
                           "module variable is not initialized"
                           "name" (module-variable-name cell))))
