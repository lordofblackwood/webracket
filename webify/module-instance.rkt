#lang racket/base

(provide webify-module-instance
         webify-module-instance?
         webify-module-instance-name
         webify-module-instance-exports
         webify-module-instance-export-cell-ids
         webify-module-instance-helper-ids
         make-webify-module-instance
         webify-module-instance-export-cell-id
         webify-module-instances-export-cell-id
         webify-module-instance-import-env
         webify-module-instance-reserved-ids
         first-slice->module-instance-datum
         first-slice->module-instance-datum/imports)

(require racket/list
         racket/match
         "module-adapter.rkt")

(struct webify-module-instance (name exports export-cell-ids helper-ids) #:transparent)

;; validate-instance-name! : symbol? any/c -> void?
;;   Reject instance names that cannot identify generated module-instance plans.
(define (validate-instance-name! who name)
  (unless (symbol? name)
    (raise-argument-error who "symbol?" name)))

;; validate-instance-exports! : symbol? any/c -> void?
;;   Reject export lists that cannot be represented by a module instance.
(define (validate-instance-exports! who exports)
  (unless (and (list? exports)
               (andmap symbol? exports))
    (raise-argument-error who "(listof symbol?)" exports))
  (define duplicate (check-duplicates exports))
  (when duplicate
    (raise-arguments-error who
                           "duplicate module instance exports are not supported"
                           "export" duplicate)))

;; make-webify-module-instance : symbol? (listof symbol?) [#:reserved (listof symbol?)] -> webify-module-instance?
;;   Describe the helper ids and export cells generated for one adapted slice.
(define (make-webify-module-instance name exports #:reserved [reserved '()])
  (define who 'make-webify-module-instance)
  (validate-instance-name! who name)
  (validate-instance-exports! who exports)
  (define helper-ids (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define export-cell-ids (first-slice-top-level-export-cell-ids exports #:reserved reserved))
  (webify-module-instance name exports export-cell-ids helper-ids))

;; webify-module-instance-export-cell-id : webify-module-instance? symbol? -> symbol?
;;   Look up the generated cell id for one module-instance export.
(define (webify-module-instance-export-cell-id instance export)
  (unless (webify-module-instance? instance)
    (raise-argument-error 'webify-module-instance-export-cell-id
                          "webify-module-instance?"
                          instance))
  (unless (symbol? export)
    (raise-argument-error 'webify-module-instance-export-cell-id "symbol?" export))
  (hash-ref (webify-module-instance-export-cell-ids instance)
            export
            (lambda ()
              (raise-arguments-error 'webify-module-instance-export-cell-id
                                     "module instance has no such export"
                                     "instance" (webify-module-instance-name instance)
                                     "export" export
                                     "available exports" (webify-module-instance-exports instance)))))

;; webify-module-instances-export-cell-id : hash? symbol? symbol? -> symbol?
;;   Look up one export cell through a composed module-instance map.
(define (webify-module-instances-export-cell-id instances name export)
  (define who 'webify-module-instances-export-cell-id)
  (unless (hash? instances)
    (raise-argument-error who "hash?" instances))
  (validate-instance-name! who name)
  (define instance
    (hash-ref instances
              name
              (lambda ()
                (raise-arguments-error who
                                       "module instance map has no such instance"
                                       "instance" name
                                       "available instances" (hash-keys instances)))))
  (webify-module-instance-export-cell-id instance export))

;; normalize-import-mapping : symbol? any/c -> values symbol? symbol?
;;   Convert a shorthand import mapping into imported-name/exported-name values.
(define (normalize-import-mapping who mapping)
  (match mapping
    [(? symbol? name)
     (values name name)]
    [(cons (? symbol? import) (? symbol? export))
     (values import export)]
    [_
     (raise-argument-error who "(or/c symbol? (cons/c symbol? symbol?))" mapping)]))

;; webify-module-instance-import-env : webify-module-instance? (listof mapping?) -> hasheq?
;;   Build an import-cell environment from one instance's export cells.
(define (webify-module-instance-import-env instance mappings)
  (define who 'webify-module-instance-import-env)
  (unless (webify-module-instance? instance)
    (raise-argument-error who "webify-module-instance?" instance))
  (unless (list? mappings)
    (raise-argument-error who "list?" mappings))
  (define entries
    (for/list ([mapping (in-list mappings)])
      (define-values (import export) (normalize-import-mapping who mapping))
      (cons import (webify-module-instance-export-cell-id instance export))))
  (define duplicate (check-duplicates (map car entries)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate import names are not supported"
                           "import" duplicate))
  (for/hasheq ([entry (in-list entries)])
    (values (car entry) (cdr entry))))

;; webify-module-instance-reserved-ids : webify-module-instance? -> (listof symbol?)
;;   Return names that later generated slices should avoid.
(define (webify-module-instance-reserved-ids instance)
  (unless (webify-module-instance? instance)
    (raise-argument-error 'webify-module-instance-reserved-ids
                          "webify-module-instance?"
                          instance))
  (append (webify-module-instance-exports instance)
          (webify-module-instance-helper-ids instance)))

;; first-slice->module-instance-datum : symbol? any/c (listof symbol?) [#:reserved (listof symbol?)] -> values
;;   Adapt an import-free lowered slice and return its top-level datum plus instance plan.
(define (first-slice->module-instance-datum name expr exports #:reserved [reserved '()])
  (define instance (make-webify-module-instance name exports #:reserved reserved))
  (values (first-slice->top-level-datum expr exports #:reserved reserved)
          instance))

;; first-slice->module-instance-datum/imports : symbol? any/c (listof (listof symbol?)) (listof hash?) (listof symbol?) [#:reserved (listof symbol?)] -> values
;;   Adapt a lowered slice by resolving imports through module-instance cell environments.
(define (first-slice->module-instance-datum/imports name
                                                    expr
                                                    importss
                                                    import-cell-envs
                                                    exports
                                                    #:reserved [reserved '()])
  (define import-args (first-slice-import-cell-args importss import-cell-envs))
  (define instance (make-webify-module-instance name exports #:reserved reserved))
  (values (first-slice->top-level-datum/imports expr import-args exports #:reserved reserved)
          instance))
