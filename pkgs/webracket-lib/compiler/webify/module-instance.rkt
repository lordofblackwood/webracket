#lang racket/base

(provide webify-module-instance
         webify-module-instance?
         webify-module-instance-name
         webify-module-instance-exports
         webify-module-instance-export-entries
         webify-module-instance-export-cell-ids
         webify-module-instance-export-value-ids
         webify-module-instance-helper-ids
         make-webify-module-instance
         webify-module-instance-export-entry
         webify-module-instance-export-plain-value?
         webify-module-instance-export-boundary-expression
         webify-module-instance-export-provider-kind
         webify-module-instance-export-value-expression
         webify-module-instance-export-cell-id
         webify-module-instance-export-value-id
         webify-module-instances-export-cell-id
         webify-module-instance-import-env
         webify-module-instance-reserved-ids
         first-slice->module-instance-datum
         first-slice->module-instance-datum/imports)

(require racket/list
         racket/match
         "module-adapter.rkt")

(struct webify-module-instance (name exports export-entries export-cell-ids export-value-ids helper-ids) #:transparent)

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
(define (make-webify-module-instance name
                                     exports
                                     #:reserved [reserved '()]
                                     #:expr [expr #f]
                                     #:module-name [module-name name]
                                     #:importss [importss #f]
                                     #:imports-abis [imports-abis #f]
                                     #:forced-cell-exports [forced-cell-exports (hasheq)])
  (define who 'make-webify-module-instance)
  (validate-instance-name! who name)
  (validate-instance-exports! who exports)
  (define helper-ids
    (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define export-cell-ids
    (first-slice-top-level-export-cell-ids exports #:reserved reserved))
  (define export-value-ids
    (first-slice-top-level-export-value-ids exports #:reserved reserved))
  (define export-entries
    (if expr
        (first-slice-export-plan-entry-map
         (build-first-slice-export-plan expr
                                        exports
                                        #:import-count (if importss
                                                           (apply + (map length importss))
                                                           0)
                                        #:reserved reserved
                                        #:module-name module-name
                                        #:importss importss
                                        #:imports-abis imports-abis
                                        #:forced-cell-exports forced-cell-exports))
        (default-export-entry-map exports export-cell-ids export-value-ids)))
  (webify-module-instance name exports export-entries export-cell-ids export-value-ids helper-ids))

;; webify-module-instance-export-entry : webify-module-instance? symbol? -> bridge-export-entry?
;;   Look up the mixed-ABI export entry for one module-instance export.
(define (webify-module-instance-export-entry instance export)
  (unless (webify-module-instance? instance)
    (raise-argument-error 'webify-module-instance-export-entry
                          "webify-module-instance?"
                          instance))
  (unless (symbol? export)
    (raise-argument-error 'webify-module-instance-export-entry "symbol?" export))
  (hash-ref (webify-module-instance-export-entries instance)
            export
            (lambda ()
              (raise-arguments-error 'webify-module-instance-export-entry
                                     "module instance has no such export"
                                     "instance" (webify-module-instance-name instance)
                                     "export" export
                                     "available exports" (webify-module-instance-exports instance)))))

;; webify-module-instance-export-plain-value? : webify-module-instance? symbol? -> boolean?
;;   Check whether one module-instance export is publicly value-backed.
(define (webify-module-instance-export-plain-value? instance export)
  (bridge-export-entry-plain-value?
   (webify-module-instance-export-entry instance export)))

;; webify-module-instance-export-boundary-expression : webify-module-instance? symbol? -> any/c
;;   Return the boundary binding used when passing one export to another slice.
(define (webify-module-instance-export-boundary-expression instance export)
  (bridge-export-entry-boundary-expression
   (webify-module-instance-export-entry instance export)))

;; webify-module-instance-export-provider-kind : webify-module-instance? symbol? -> symbol?
;;   Return the recorded provider kind for one export entry.
(define (webify-module-instance-export-provider-kind instance export)
  (hash-ref (bridge-export-entry-metadata
             (webify-module-instance-export-entry instance export))
            'provider-kind
            'unknown-provider))

;; webify-module-instance-export-value-expression : webify-module-instance? symbol? -> any/c
;;   Return the direct value binding for one export, regardless of boundary kind.
(define (webify-module-instance-export-value-expression instance export)
  (define entry
    (webify-module-instance-export-entry instance export))
  (if (bridge-export-entry-plain-value? entry)
      (bridge-export-entry-binding entry)
      (hash-ref (bridge-export-entry-metadata entry)
                'value-id
                (lambda ()
                  (webify-module-instance-export-value-id instance export)))))

;; webify-module-instance-export-cell-id : webify-module-instance? symbol? -> symbol?
;;   Look up the generated cell id for one module-instance export.
(define (webify-module-instance-export-cell-id instance export)
  (define entry
    (webify-module-instance-export-entry instance export))
  (unless (bridge-export-entry-cell-backed? entry)
    (raise-arguments-error 'webify-module-instance-export-cell-id
                           "module instance export is not cell-backed"
                           "instance" (webify-module-instance-name instance)
                           "export" export))
  (bridge-export-entry-binding entry))

;; webify-module-instance-export-value-id : webify-module-instance? symbol? -> symbol?
;;   Look up the generated lexical value id for one module-instance export.
(define (webify-module-instance-export-value-id instance export)
  (unless (webify-module-instance? instance)
    (raise-argument-error 'webify-module-instance-export-value-id
                          "webify-module-instance?"
                          instance))
  (unless (symbol? export)
    (raise-argument-error 'webify-module-instance-export-value-id "symbol?" export))
  (hash-ref (webify-module-instance-export-value-ids instance)
            export
            (lambda ()
              (raise-arguments-error 'webify-module-instance-export-value-id
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
      (cons import (webify-module-instance-export-boundary-expression instance export))))
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
          (hash-values (webify-module-instance-export-value-ids instance))
          (webify-module-instance-helper-ids instance)))

;; first-slice->module-instance-datum : symbol? any/c (listof symbol?) [#:reserved (listof symbol?)] -> values
;;   Adapt an import-free lowered slice and return its top-level datum plus instance plan.
(define (first-slice->module-instance-datum name
                                            expr
                                            exports
                                            #:reserved [reserved '()]
                                            #:define-export-aliases? [define-export-aliases? #t])
  (define instance
    (make-webify-module-instance name
                                 exports
                                 #:reserved reserved
                                 #:expr expr
                                 #:module-name name))
  (values (first-slice->top-level-datum
           expr
           exports
           #:reserved reserved
           #:module-name name
           #:export-entries (webify-module-instance-export-entries instance)
           #:define-export-aliases? define-export-aliases?)
          instance))

;; first-slice->module-instance-datum/imports : symbol? any/c (listof (listof symbol?)) (listof hash?) (listof symbol?) [#:reserved (listof symbol?)] [#:instance instance?] -> values
;;   Adapt a lowered slice by resolving imports through module-instance cell environments.
(define (first-slice->module-instance-datum/imports name
                                                    expr
                                                    importss
                                                    import-envs
                                                    exports
                                                    #:reserved [reserved '()]
                                                    #:instance [instance #f]
                                                    #:imports-abis [imports-abis #f]
                                                    #:define-export-aliases? [define-export-aliases? #t])
  (define import-args (first-slice-import-args importss import-envs))
  (define instance*
    (or instance
        (make-webify-module-instance name
                                     exports
                                     #:reserved reserved
                                     #:expr expr
                                     #:module-name name
                                     #:importss importss
                                     #:imports-abis imports-abis)))
  (values (first-slice->top-level-datum/imports
           expr
           import-args
           exports
           #:reserved reserved
           #:module-name name
           #:importss importss
           #:imports-abis imports-abis
           #:export-entries (webify-module-instance-export-entries instance*)
           #:define-export-aliases? define-export-aliases?)
          instance*))
