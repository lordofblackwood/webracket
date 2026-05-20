#lang racket/base

(provide webify-lowered-slice-spec
         webify-lowered-slice-spec?
         webify-lowered-slice-spec-name
         webify-lowered-slice-spec-expr
         webify-lowered-slice-spec-importss
         webify-lowered-slice-spec-import-sources
         webify-lowered-slice-spec-exports
         webify-linklet-slice-spec
         webify-linklet-slice-spec?
         webify-linklet-slice-spec-name
         webify-linklet-slice-spec-linklet
         webify-linklet-slice-spec-import-sources
         webify-module-fragment
         webify-module-fragment?
         webify-module-fragment-datum
         webify-module-fragment-instance
         current-composer-primitive-import-cell-overrides
         webify-compose-module-fragments
         webify-compose-module-fragments-syntax
         webify-compose-lowered-first-slices
         webify-compose-linklet-first-slices)

(require racket/list
         racket/match
         "first-slice.rkt"
         "module-instance.rkt"
         "primitive-modules.rkt")

(struct webify-lowered-slice-spec (name expr importss import-sources exports) #:transparent)
(struct webify-linklet-slice-spec (name linklet import-sources) #:transparent)
(struct webify-module-fragment (datum instance) #:transparent)

(define current-composer-primitive-import-cell-overrides
  (make-parameter (hasheq)))

;; validate-begin-datum! : symbol? any/c -> void?
;;   Reject generated fragments that cannot be spliced into top-level code.
(define (validate-begin-datum! who datum)
  (match datum
    [`(begin ,_body ...)
     (void)]
    [_
     (raise-arguments-error who
                            "expected generated fragment datum to be a begin form"
                            "datum" datum)]))

;; begin-body : any/c -> (listof any/c)
;;   Extract top-level forms from a generated begin datum.
(define (begin-body datum)
  (validate-begin-datum! 'begin-body datum)
  (cdr datum))

;; validate-fragment! : symbol? any/c -> void?
;;   Reject values that cannot participate in module-fragment composition.
(define (validate-fragment! who fragment)
  (unless (webify-module-fragment? fragment)
    (raise-argument-error who "webify-module-fragment?" fragment))
  (validate-begin-datum! who (webify-module-fragment-datum fragment))
  (unless (webify-module-instance? (webify-module-fragment-instance fragment))
    (raise-arguments-error who
                           "fragment instance is not a webify module instance"
                           "fragment" fragment)))

;; validate-tail-forms! : symbol? any/c -> void?
;;   Reject non-list tail forms before composing top-level code.
(define (validate-tail-forms! who tail-forms)
  (unless (list? tail-forms)
    (raise-argument-error who "list?" tail-forms)))

;; webify-compose-module-fragments : (listof webify-module-fragment?) [#:tail (listof any/c)] -> any/c
;;   Splice adapted module fragments into one top-level begin datum.
(define (webify-compose-module-fragments fragments #:tail [tail-forms '((void))])
  (define who 'webify-compose-module-fragments)
  (unless (list? fragments)
    (raise-argument-error who "list?" fragments))
  (validate-tail-forms! who tail-forms)
  (for ([fragment (in-list fragments)])
    (validate-fragment! who fragment))
  `(begin
     ,@(apply append
              (for/list ([fragment (in-list fragments)])
                (begin-body (webify-module-fragment-datum fragment))))
     ,@tail-forms))

;; webify-compose-module-fragments-syntax : (listof webify-module-fragment?) [#:tail (listof any/c)] -> syntax?
;;   Convert composed module fragments to top-level syntax for the compiler.
(define (webify-compose-module-fragments-syntax fragments #:tail [tail-forms '((void))])
  (datum->syntax #f
                 (webify-compose-module-fragments fragments #:tail tail-forms)))

;; validate-slice-spec! : symbol? any/c -> void?
;;   Reject lowered slice specs with malformed composition metadata.
(define (validate-slice-spec! who spec)
  (unless (webify-lowered-slice-spec? spec)
    (raise-argument-error who "webify-lowered-slice-spec?" spec))
  (unless (symbol? (webify-lowered-slice-spec-name spec))
    (raise-arguments-error who
                           "slice name must be a symbol"
                           "name" (webify-lowered-slice-spec-name spec)))
  (unless (and (list? (webify-lowered-slice-spec-exports spec))
               (andmap symbol? (webify-lowered-slice-spec-exports spec)))
    (raise-arguments-error who
                           "slice exports must be a list of symbols"
                           "exports" (webify-lowered-slice-spec-exports spec))))

;; validate-linklet-slice-spec! : symbol? any/c -> void?
;;   Reject linklet slice specs with malformed composition metadata.
(define (validate-linklet-slice-spec! who spec)
  (unless (webify-linklet-slice-spec? spec)
    (raise-argument-error who "webify-linklet-slice-spec?" spec))
  (unless (symbol? (webify-linklet-slice-spec-name spec))
    (raise-arguments-error who
                           "slice name must be a symbol"
                           "name" (webify-linklet-slice-spec-name spec))))

;; all-cell-import-abis? : any/c -> boolean?
;;   Check whether import ABI metadata says every import is passed as a cell.
(define (all-cell-import-abis? imports-abis)
  (and (list? imports-abis)
       (for/and ([group (in-list imports-abis)])
         (and (list? group)
              (andmap not group)))))

;; validate-import-source! : symbol? any/c -> void?
;;   Reject import source triples that cannot resolve through previous instances.
(define (validate-import-source! who source)
  (match source
    [(list (? symbol?) (? symbol?) (? symbol?))
     (void)]
    [_
     (raise-argument-error who "(list/c symbol? symbol? symbol?)" source)]))

;; import-source? : any/c -> boolean?
;;   Check whether v is one flat import-source triple.
(define (import-source? v)
  (match v
    [(list (? symbol?) (? symbol?) (? symbol?)) #t]
    [_                                         #f]))

;; grouped-import-sources? : any/c -> boolean?
;;   Check whether v is a grouped import-source list.
(define (grouped-import-sources? v)
  (and (list? v)
       (for/and ([group (in-list v)])
         (and (list? group)
              (andmap import-source? group)))))

;; flat-import-sources? : any/c -> boolean?
;;   Check whether v is a flat import-source list.
(define (flat-import-sources? v)
  (and (list? v)
       (andmap import-source? v)))

;; flat-import-sources->groups : symbol? symbol? (listof (listof symbol?)) (listof source?) -> (listof (listof source?))
;;   Group flat source triples according to linklet import metadata.
(define (flat-import-sources->groups who name importss import-sources)
  (define imports (apply append importss))
  (define duplicate-import (check-duplicates imports))
  (when duplicate-import
    (raise-arguments-error who
                           "flat import sources cannot resolve duplicate linklet import names"
                           "name" name
                           "import" duplicate-import
                           "imports" importss))
  (define entries
    (for/list ([source (in-list import-sources)])
      (validate-import-source! who source)
      (cons (car source) source)))
  (define duplicate-source (check-duplicates (map car entries)))
  (when duplicate-source
    (raise-arguments-error who
                           "duplicate import source names are not supported"
                           "name" name
                           "import" duplicate-source))
  (define source-table
    (for/hasheq ([entry (in-list entries)])
      (values (car entry) (cdr entry))))
  (define grouped
    (for/list ([group (in-list importss)])
      (for/list ([import (in-list group)])
        (hash-ref source-table
                  import
                  (lambda ()
                    (raise-arguments-error who
                                           "missing import source"
                                           "name" name
                                           "import" import
                                           "imports" importss
                                           "available imports" (hash-keys source-table)))))))
  (define extra-imports
    (filter (lambda (import) (not (memq import imports)))
            (hash-keys source-table)))
  (unless (null? extra-imports)
    (raise-arguments-error who
                           "import sources reference names not imported by the linklet"
                           "name" name
                           "imports" extra-imports
                           "linklet imports" importss))
  grouped)

;; normalize-linklet-import-sources : symbol? symbol? (listof (listof symbol?)) any/c -> (listof (listof source?))
;;   Accept grouped or flat source metadata and return grouped source triples.
(define (normalize-linklet-import-sources who name importss import-sources)
  (cond
    [(null? import-sources) '()]
    [(flat-import-sources? import-sources)
     (flat-import-sources->groups who name importss import-sources)]
    [(grouped-import-sources? import-sources)
     import-sources]
    [else
     (raise-argument-error who
                           "(or/c (listof source-triple?) (listof (listof source-triple?)))"
                           import-sources)]))

;; import-source->mapping : symbol? hash? any/c -> pair?
;;   Resolve one source triple to the mapping expected by instance import-envs.
(define (import-source->mapping who instances source)
  (validate-import-source! who source)
  (match-define (list import-name instance-name export-name) source)
  (cons import-name
        (cond
          [(primitive-module-name? instance-name)
           (hash-ref
            (current-composer-primitive-import-cell-overrides)
            export-name
            (lambda ()
              `(let ([cell (module-variable-make ',export-name)])
                 (module-variable-define! cell ,export-name 'constant)
                 cell)))]
          [else
           (define instance
             (hash-ref instances
                       instance-name
                       (lambda ()
                         (raise-arguments-error who
                                                "import source references an unknown instance"
                                                "instance" instance-name
                                                "import" import-name
                                                "available instances" (hash-keys instances)))))
           (webify-module-instance-export-cell-id instance export-name)])))

;; import-sources->envs : hash? (listof (listof source?)) -> (listof hash?)
;;   Resolve grouped import source triples to grouped import cell environments.
(define (import-sources->envs who instances import-sources)
  (unless (list? import-sources)
    (raise-argument-error who "list?" import-sources))
  (for/list ([group (in-list import-sources)])
    (unless (list? group)
      (raise-argument-error who "(listof list?)" import-sources))
    (define entries
      (for/list ([source (in-list group)])
        (import-source->mapping who instances source)))
    (define duplicate (check-duplicates (map car entries)))
    (when duplicate
      (raise-arguments-error who
                             "duplicate import names are not supported"
                             "import" duplicate))
    (for/hasheq ([entry (in-list entries)])
      (values (car entry) (cdr entry)))))

;; webify-compose-lowered-first-slices : (listof webify-lowered-slice-spec?) [#:tail (listof any/c)] -> values
;;   Adapt lowered slices in order, resolve prior-instance imports, and compose top-level code.
(define (webify-compose-lowered-first-slices specs
                                             #:tail [tail-forms '((void))]
                                             #:define-export-aliases? [define-export-aliases? #t])
  (define who 'webify-compose-lowered-first-slices)
  (unless (list? specs)
    (raise-argument-error who "list?" specs))
  (validate-tail-forms! who tail-forms)
  (define-values (reverse-fragments instances _reserved)
    (for/fold ([reverse-fragments '()]
               [instances         (hasheq)]
               [reserved          '()])
              ([spec (in-list specs)])
      (validate-slice-spec! who spec)
      (define name (webify-lowered-slice-spec-name spec))
      (when (hash-has-key? instances name)
        (raise-arguments-error who
                               "duplicate module instance names are not supported"
                               "name" name))
      (define importss (webify-lowered-slice-spec-importss spec))
      (define import-sources (webify-lowered-slice-spec-import-sources spec))
      (define exports (webify-lowered-slice-spec-exports spec))
      (define self-instance
        (make-webify-module-instance name exports #:reserved reserved))
      (define instances/self
        (hash-set instances name self-instance))
      (when (and (null? importss)
                 (not (null? import-sources)))
        (raise-arguments-error who
                               "import-free slices cannot have import sources"
                               "name" name
                               "import sources" import-sources))
      (define-values (datum instance)
        (if (null? importss)
            (first-slice->module-instance-datum
             name
             (webify-lowered-slice-spec-expr spec)
             exports
             #:reserved reserved
             #:define-export-aliases? define-export-aliases?)
            (first-slice->module-instance-datum/imports
             name
             (webify-lowered-slice-spec-expr spec)
             importss
             (import-sources->envs who instances/self import-sources)
             exports
             #:reserved reserved
             #:instance self-instance
             #:define-export-aliases? define-export-aliases?)))
      (values (cons (webify-module-fragment datum instance) reverse-fragments)
              (hash-set instances name instance)
              (append reserved (webify-module-instance-reserved-ids instance)))))
  (define fragments (reverse reverse-fragments))
  (values (webify-compose-module-fragments fragments #:tail tail-forms)
          fragments
          instances))

;; webify-compose-linklet-first-slices : (listof webify-linklet-slice-spec?) keyword-args ... -> values
;;   Webify linklets in order, resolve prior-instance imports, and compose top-level code.
(define (webify-compose-linklet-first-slices specs
                                             #:tail                  [tail-forms '((void))]
                                             #:define-export-aliases? [define-export-aliases? #t]
                                             #:serializable?-box     serializable?-box
                                             #:datum-intern?         datum-intern?
                                             #:target                target
                                             #:allow-set!-undefined? allow-set!-undefined?
                                             #:unsafe-mode?          unsafe-mode?
                                             #:enforce-constant?     enforce-constant?
                                             #:allow-inline?         allow-inline?
                                             #:no-prompt?            no-prompt?
                                             #:prim-knowns           prim-knowns
                                             #:primitives            primitives
                                             #:compiler-query        compiler-query
                                             #:get-import-knowns     get-import-knowns
                                             #:import-keys           import-keys)
  (define who 'webify-compose-linklet-first-slices)
  (unless (list? specs)
    (raise-argument-error who "list?" specs))
  (validate-tail-forms! who tail-forms)
  (define-values (reverse-fragments instances _reserved exports-infos)
    (for/fold ([reverse-fragments '()]
               [instances         (hasheq)]
               [reserved          '()]
               [exports-infos     (hasheq)])
              ([spec (in-list specs)])
      (validate-linklet-slice-spec! who spec)
      (define name (webify-linklet-slice-spec-name spec))
      (when (hash-has-key? instances name)
        (raise-arguments-error who
                               "duplicate module instance names are not supported"
                               "name" name))
      (define-values (expr importss exports new-import-keys imports-abis exports-info)
        (webify-linklet-first-slice
         (webify-linklet-slice-spec-linklet spec)
         #:serializable?-box     serializable?-box
         #:datum-intern?         datum-intern?
         #:target                target
         #:allow-set!-undefined? allow-set!-undefined?
         #:unsafe-mode?          unsafe-mode?
         #:enforce-constant?     enforce-constant?
         #:allow-inline?         allow-inline?
         #:no-prompt?            no-prompt?
         #:prim-knowns           prim-knowns
         #:primitives            primitives
         #:compiler-query        compiler-query
         #:get-import-knowns     get-import-knowns
         #:import-keys           import-keys))
      (when new-import-keys
        (error who
               "inlining-added import groups are not supported by the linklet composer yet"))
      (unless (all-cell-import-abis? imports-abis)
        (error who
               "value import ABIs are not supported by the linklet composer yet"))
      (define raw-import-sources (webify-linklet-slice-spec-import-sources spec))
      (define import-sources
        (normalize-linklet-import-sources who name importss raw-import-sources))
      (define self-instance
        (make-webify-module-instance name exports #:reserved reserved))
      (define instances/self
        (hash-set instances name self-instance))
      (when (and (null? importss)
                 (not (null? import-sources)))
        (raise-arguments-error who
                               "import-free linklets cannot have import sources"
                               "name" name
                               "import sources" import-sources))
      (unless (= (length importss) (length import-sources))
        (raise-arguments-error who
                               "import source group count does not match linklet imports"
                               "name" name
                               "expected count" (length importss)
                               "actual count" (length import-sources)
                               "imports" importss))
      (define-values (datum instance)
        (if (null? importss)
            (first-slice->module-instance-datum
             name
             expr
             exports
             #:reserved reserved
             #:define-export-aliases? define-export-aliases?)
            (first-slice->module-instance-datum/imports
             name
             expr
             importss
             (import-sources->envs who instances/self import-sources)
             exports
             #:reserved reserved
             #:instance self-instance
             #:define-export-aliases? define-export-aliases?)))
      (values (cons (webify-module-fragment datum instance) reverse-fragments)
              (hash-set instances name instance)
              (append reserved (webify-module-instance-reserved-ids instance))
              (hash-set exports-infos name exports-info))))
  (define fragments (reverse reverse-fragments))
  (values (webify-compose-module-fragments fragments #:tail tail-forms)
          fragments
          instances
          exports-infos))
