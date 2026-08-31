#lang racket/base

(provide webify-module-registry
         webify-module-registry?
         make-webify-module-registry
         webify-module-registry-entry
         webify-module-registry-entry?
         webify-module-registry-entry-name
         webify-module-registry-entry-linklet
         webify-module-registry-entry-importss
         webify-module-registry-entry-imports
         webify-module-registry-entry-exports
         webify-module-registry-add!
         webify-module-registry-ref
         webify-module-registry-names
         webify-module-registry-plan
         (struct-out webify-module-composition)
         webify-module-composition-export-cell-id
         webify-module-composition-with-tail
         webify-compose-module-registry/composition
         webify-compose-module-registry/roots/composition
         webify-compose-module-registry
         webify-compose-module-registry/roots
         webify-compose-module-registry/roots+observations)

(require racket/list
         racket/match
         racket/string
         "module-composer.rkt"
         "module-instance.rkt"
         "primitive-modules.rkt")

(struct webify-module-registry (entries) #:transparent)
(struct webify-module-registry-entry (name linklet importss imports exports) #:transparent)
(struct webify-module-composition (datum fragments instances exports-infos) #:transparent)

;; symbolic-import-name=? : symbol? symbol? -> boolean?
;;   Treat decompiler-generated import prefixes such as `1/reverse` as aliases.
(define (symbolic-import-name=? a b)
  (define (base-name name)
    (regexp-replace #rx"^[0-9]+/" (symbol->string name) ""))
  (or (eq? a b)
      (string=? (base-name a) (base-name b))))

;; canonical-module-registry-name : symbol? -> symbol?
;;   Store file-backed provider names without the trailing `.rkt`.
(define (canonical-module-registry-name name)
  (define text (symbol->string name))
  (if (string-suffix? text ".rkt")
      (string->symbol (substring text 0 (- (string-length text) 4)))
      name))

;; canonical-import-source : (list/c symbol? symbol? symbol?) -> source?
;;   Canonicalize only the dependency module name in import metadata.
(define (canonical-import-source source)
  (match-define (list import dependency export) source)
  (list import (canonical-module-registry-name dependency) export))

;; make-webify-module-registry : -> webify-module-registry?
;;   Create an empty mutable registry of named linklet slices.
(define (make-webify-module-registry)
  (webify-module-registry (make-hasheq)))

;; validate-registry! : symbol? any/c -> void?
;;   Reject values that cannot store webify module registry entries.
(define (validate-registry! who registry)
  (unless (webify-module-registry? registry)
    (raise-argument-error who "webify-module-registry?" registry)))

;; validate-entry-name! : symbol? any/c -> void?
;;   Reject module registry names that cannot be used for composition.
(define (validate-entry-name! who name)
  (unless (symbol? name)
    (raise-argument-error who "symbol?" name)))

;; validate-import-source! : symbol? any/c -> void?
;;   Reject flat import-source triples for registry entries.
(define (validate-import-source! who source)
  (match source
    [(list (? symbol?) (? symbol?) (? symbol?))
     (void)]
    [_
     (raise-argument-error who "(list/c symbol? symbol? symbol?)" source)]))

;; validate-imports! : symbol? any/c -> void?
;;   Reject registry import metadata before composition.
(define (validate-imports! who imports)
  (unless (list? imports)
    (raise-argument-error who "(listof (list/c symbol? symbol? symbol?))" imports))
  (for ([source (in-list imports)])
    (validate-import-source! who source))
  (define duplicate (check-duplicates (map car imports)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate registry import names are not supported"
                           "import" duplicate)))

;; linklet-importss+exports : symbol? any/c -> values
;;   Extract and validate the import groups and external exports from a linklet datum.
(define (linklet-importss+exports who linklet)
  (match linklet
    [`(linklet ,importss ,exports . ,_body)
     (unless (and (list? importss)
                  (for/and ([group (in-list importss)])
                    (and (list? group)
                         (for/and ([binding (in-list group)])
                           (match binding
                             [(list (? symbol?) (? symbol?)) #t]
                             [_                              #f])))))
       (raise-arguments-error who
                              "linklet imports must be grouped pairs of symbols"
                              "linklet" linklet))
     (define normalized-exports
       (and (list? exports)
            (for/list ([export (in-list exports)])
              (match export
                [(list (? symbol?) (? symbol? external)) external]
                [(? symbol? external) external]
                [_ #f]))))
     (unless (and normalized-exports
                  (andmap symbol? normalized-exports))
       (raise-arguments-error who
                              "linklet exports must be symbols or internal/external symbol pairs"
                              "exports" exports))
     (define import-names
       (for*/list ([group   (in-list importss)]
                   [binding (in-list group)])
         (car binding)))
     (define duplicate-import (check-duplicates import-names))
     (when duplicate-import
       (raise-arguments-error who
                              "duplicate linklet import names are not supported"
                              "import" duplicate-import))
     (define duplicate-export (check-duplicates normalized-exports))
     (when duplicate-export
       (raise-arguments-error who
                              "duplicate linklet exports are not supported"
                              "export" duplicate-export))
     (values importss normalized-exports)]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; validate-imports-match-linklet! : symbol? (listof group?) (listof source?) -> void?
;;   Reject registry import metadata that disagrees with the linklet import names.
(define (validate-imports-match-linklet! who importss imports)
  (define linklet-imports
    (apply append
           (for/list ([group (in-list importss)])
             (map car group))))
  (define declared-imports (map car imports))
  (define declared-import-table
    (for/hasheq ([import (in-list declared-imports)])
      (values import #t)))
  (define linklet-import-table
    (for/hasheq ([import (in-list linklet-imports)])
      (values import #t)))
  (define declared-symbolic-cache (make-hasheq))
  (define linklet-symbolic-cache (make-hasheq))
  (define (declared-import? import)
    (or (hash-ref declared-import-table import #f)
        (hash-ref! declared-symbolic-cache
                   import
                   (lambda ()
                     (for/or ([declared (in-list declared-imports)])
                       (symbolic-import-name=? import declared))))))
  (define (linklet-import? import)
    (or (hash-ref linklet-import-table import #f)
        (hash-ref! linklet-symbolic-cache
                   import
                   (lambda ()
                     (for/or ([linklet-import (in-list linklet-imports)])
                       (symbolic-import-name=? import linklet-import))))))
  (define missing-imports
    (filter (lambda (import)
              (not (declared-import? import)))
            linklet-imports))
  (define extra-imports
    (filter (lambda (import)
              (not (linklet-import? import)))
            declared-imports))
  (unless (null? missing-imports)
    (raise-arguments-error who
                           "registry imports are missing linklet imports"
                           "imports" missing-imports
                           "linklet imports" linklet-imports
                           "registry imports" declared-imports))
  (unless (null? extra-imports)
    (raise-arguments-error who
                           "registry imports reference names not imported by the linklet"
                           "imports" extra-imports
                           "linklet imports" linklet-imports
                           "registry imports" declared-imports)))

;; webify-module-registry-add! : webify-module-registry? symbol? any/c [#:imports (listof source?)] -> void?
;;   Add a named linklet slice and its flat import-source metadata.
(define (webify-module-registry-add! registry name linklet #:imports [imports '()])
  (define who 'webify-module-registry-add!)
  (validate-registry! who registry)
  (validate-entry-name! who name)
  (validate-imports! who imports)
  (define canonical-name (canonical-module-registry-name name))
  (define canonical-imports (map canonical-import-source imports))
  (define-values (importss exports)
    (linklet-importss+exports who linklet))
  (validate-imports-match-linklet! who importss canonical-imports)
  (define entries (webify-module-registry-entries registry))
  (when (hash-has-key? entries canonical-name)
    (raise-arguments-error who
                           "duplicate module registry entries are not supported"
                           "name" canonical-name))
  (hash-set! entries
             canonical-name
             (webify-module-registry-entry canonical-name linklet importss canonical-imports exports))
  (void))

;; webify-module-registry-ref : webify-module-registry? symbol? -> webify-module-registry-entry?
;;   Look up one named registry entry.
(define (webify-module-registry-ref registry name)
  (define who 'webify-module-registry-ref)
  (validate-registry! who registry)
  (validate-entry-name! who name)
  (define canonical-name (canonical-module-registry-name name))
  (hash-ref (webify-module-registry-entries registry)
            canonical-name
            (lambda ()
              (raise-arguments-error who
                                     "unknown module registry entry"
                                     "name" name
                                     "canonical name" canonical-name
                                     "available names" (webify-module-registry-names registry)))))

;; webify-module-registry-names : webify-module-registry? -> (listof symbol?)
;;   Return registered module names in deterministic order.
(define (webify-module-registry-names registry)
  (validate-registry! 'webify-module-registry-names registry)
  (sort (hash-keys (webify-module-registry-entries registry)) symbol<?))

;; entry->slice-spec : webify-module-registry-entry? -> webify-linklet-slice-spec?
;;   Convert one registry entry to the composer spec shape.
(define (entry->slice-spec entry)
  (webify-linklet-slice-spec
   (webify-module-registry-entry-name entry)
   (webify-module-registry-entry-linklet entry)
   (webify-module-registry-entry-imports entry)))

;; validate-compose-order! : webify-module-registry? (listof symbol?) -> void?
;;   Reject composition orders that reference missing entries or duplicate names.
(define (validate-compose-order! registry order)
  (define who 'webify-compose-module-registry)
  (unless (and (list? order)
               (andmap symbol? order))
    (raise-argument-error who "(listof symbol?)" order))
  (define canonical-order (map canonical-module-registry-name order))
  (define duplicate (check-duplicates canonical-order))
  (when duplicate
    (raise-arguments-error who
                           "duplicate module names in composition order are not supported"
                           "name" duplicate))
  (for ([name (in-list canonical-order)])
    (webify-module-registry-ref registry name))
  (for/fold ([seen (hasheq)])
            ([name (in-list canonical-order)])
    (define entry (webify-module-registry-ref registry name))
    (for ([source (in-list (webify-module-registry-entry-imports entry))])
      (match-define (list import dependency export) source)
      (unless (or (primitive-module-name? dependency)
                  (eq? dependency name)
                  (hash-has-key? seen dependency))
        (raise-arguments-error who
                               "registry import dependency must appear earlier in the composition order"
                               "name" name
                               "import" import
                               "dependency" dependency
                               "export" export)))
    (hash-set seen name #t)))

;; entry-dependencies : webify-module-registry-entry? -> (listof symbol?)
;;   Return unique dependency names from flat import-source metadata.
(define (entry-dependencies entry)
  (remove-duplicates
   (for/list ([source (in-list (webify-module-registry-entry-imports entry))])
     (match-define (list _import dependency _export) source)
     dependency)
   eq?))

;; entry-module-dependencies : webify-module-registry-entry? -> (listof symbol?)
;;   Return dependencies that require another composed module instance.
(define (entry-module-dependencies entry)
  (define name (webify-module-registry-entry-name entry))
  (filter (lambda (dependency)
            (and (not (primitive-module-name? dependency))
                 (not (eq? dependency name))))
          (entry-dependencies entry)))

;; validate-roots! : symbol? any/c -> void?
;;   Reject root lists that cannot drive a dependency plan.
(define (validate-roots! who roots)
  (unless (and (list? roots)
               (andmap symbol? roots))
    (raise-argument-error who "(listof symbol?)" roots))
  (define duplicate (check-duplicates roots))
  (when duplicate
    (raise-arguments-error who
                           "duplicate module roots are not supported"
                           "name" duplicate)))

;; validate-observations! : symbol? any/c -> void?
;;   Reject module/export observation requests with malformed shape.
(define (validate-observations! who observations)
  (unless (list? observations)
    (raise-argument-error who "(listof (list/c symbol? symbol?))" observations))
  (for ([observation (in-list observations)])
    (match observation
      [(list (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error who "(list/c symbol? symbol?)" observation)])))

;; observations->tail-forms : symbol? hash? (listof observation?) symbol? -> (listof any/c)
;;   Build top-level observer calls that read composed module export cells.
(define (observations->tail-forms who instances observations observer)
  (unless (symbol? observer)
    (raise-argument-error who "symbol?" observer))
  (for/list ([observation (in-list observations)])
    (match-define (list name export) observation)
    (define cell-id (webify-module-instances-export-cell-id instances name export))
    `(,observer (module-variable-ref ,cell-id))))

;; validate-composition! : symbol? any/c -> void?
;;   Reject values that are not reusable module-composition payloads.
(define (validate-composition! who composition)
  (unless (webify-module-composition? composition)
    (raise-argument-error who "webify-module-composition?" composition)))

;; webify-module-composition-export-cell-id : webify-module-composition? symbol? symbol? -> symbol?
;;   Look up one composed module export cell.
(define (webify-module-composition-export-cell-id composition name export)
  (validate-composition! 'webify-module-composition-export-cell-id composition)
  (webify-module-instances-export-cell-id
   (webify-module-composition-instances composition)
   name
   export))

;; webify-module-composition-with-tail : webify-module-composition? (listof any/c) -> any/c
;;   Rebuild a composed top-level datum with a caller-supplied tail.
(define (webify-module-composition-with-tail composition tail-forms)
  (validate-composition! 'webify-module-composition-with-tail composition)
  (webify-compose-module-fragments
   (webify-module-composition-fragments composition)
   #:tail tail-forms))

;; composition->values : webify-module-composition? -> values
;;   Preserve the existing multi-value composition API.
(define (composition->values composition)
  (values (webify-module-composition-datum composition)
          (webify-module-composition-fragments composition)
          (webify-module-composition-instances composition)
          (webify-module-composition-exports-infos composition)))

;; webify-module-registry-plan : webify-module-registry? (listof symbol?) -> (listof symbol?)
;;   Compute a deterministic dependency-first composition order for roots.
(define (webify-module-registry-plan registry roots)
  (define who 'webify-module-registry-plan)
  (validate-registry! who registry)
  (validate-roots! who roots)
  (define planned '())
  (define permanent (hasheq))
  (define temporary (hasheq))
  (define (visit name path)
    (define canonical-name (canonical-module-registry-name name))
    (webify-module-registry-ref registry canonical-name)
    (cond
      [(hash-has-key? permanent canonical-name)
       (void)]
      [(hash-has-key? temporary canonical-name)
       (raise-arguments-error who
                              "cyclic module registry dependencies are not supported"
                              "name" canonical-name
                              "path" (reverse (cons canonical-name path)))]
      [else
       (set! temporary (hash-set temporary canonical-name #t))
       (define entry (webify-module-registry-ref registry canonical-name))
       (for ([dependency (in-list (entry-module-dependencies entry))])
         (visit dependency (cons canonical-name path)))
       (set! temporary (hash-remove temporary canonical-name))
       (set! permanent (hash-set permanent canonical-name #t))
       (set! planned (cons canonical-name planned))]))
  (for ([root (in-list roots)])
    (visit root '()))
  (reverse planned))

;; webify-compose-module-registry/composition : webify-module-registry? (listof symbol?) keyword-args ... -> webify-module-composition?
;;   Compose named registry entries into a reusable payload object.
(define (webify-compose-module-registry/composition registry
                                                    order
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
  (define who 'webify-compose-module-registry)
  (validate-registry! who registry)
  (validate-compose-order! registry order)
  (define-values (datum fragments instances exports-infos)
    (webify-compose-linklet-first-slices
     (for/list ([name (in-list order)])
       (entry->slice-spec (webify-module-registry-ref registry name)))
     #:tail                  tail-forms
     #:define-export-aliases? define-export-aliases?
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
  (webify-module-composition datum fragments instances exports-infos))

;; webify-compose-module-registry : webify-module-registry? (listof symbol?) keyword-args ... -> values
;;   Compose named registry entries through the linklet first-slice composer.
(define (webify-compose-module-registry registry
                                        order
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
  (composition->values
   (webify-compose-module-registry/composition
    registry
    order
    #:tail                  tail-forms
    #:define-export-aliases? define-export-aliases?
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
    #:import-keys           import-keys)))

;; webify-compose-module-registry/roots/composition : webify-module-registry? (listof symbol?) keyword-args ... -> webify-module-composition?
;;   Plan dependencies for roots, then compose into a reusable payload object.
(define (webify-compose-module-registry/roots/composition registry
                                                          roots
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
  (webify-compose-module-registry/composition
   registry
   (webify-module-registry-plan registry roots)
   #:tail                  tail-forms
   #:define-export-aliases? define-export-aliases?
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

;; webify-compose-module-registry/roots : webify-module-registry? (listof symbol?) keyword-args ... -> values
;;   Plan dependencies for roots, then compose named registry entries.
(define (webify-compose-module-registry/roots registry
                                              roots
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
  (composition->values
   (webify-compose-module-registry/roots/composition
    registry
    roots
    #:tail                  tail-forms
    #:define-export-aliases? define-export-aliases?
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
    #:import-keys           import-keys)))

;; webify-compose-module-registry/roots+observations : webify-module-registry? (listof symbol?) (listof observation?) keyword-args ... -> values
;;   Compose planned roots and append observer calls for requested module exports.
(define (webify-compose-module-registry/roots+observations registry
                                                           roots
                                                           observations
                                                           #:observer              [observer 'js-log]
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
  (define who 'webify-compose-module-registry/roots+observations)
  (validate-observations! who observations)
  (define composition
    (webify-compose-module-registry/roots/composition
     registry
     roots
     #:define-export-aliases? define-export-aliases?
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
  (define observation-tail
    (observations->tail-forms
     who
     (webify-module-composition-instances composition)
     observations
     observer))
  (values (webify-module-composition-with-tail
           composition
           (append observation-tail tail-forms))
          (webify-module-composition-fragments composition)
          (webify-module-composition-instances composition)
          (webify-module-composition-exports-infos composition)))
