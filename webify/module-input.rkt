#lang racket/base

(provide webify-module-linklet-input
         webify-module-linklet-input?
         webify-module-linklet-input-name
         webify-module-linklet-input-linklet
         webify-module-linklet-input-imports
         webify-module-linklet-manifest
         webify-module-linklet-manifest?
         webify-module-linklet-manifest-inputs
         webify-module-linklet-manifest-roots
         datum->webify-module-linklet-manifest
         read-webify-module-linklet-manifest
         webify-module-linklet-manifest->registry
         webify-module-linklet-input-dependency-exports
         webify-module-linklet-inputs-dependency-exports
         webify-resolve-module-linklet-imports
         webify-module-resolution-outcome
         webify-module-resolution-outcome?
         webify-module-resolution-outcome-local
         webify-module-resolution-outcome-dependency
         webify-module-resolution-outcome-provider-export
         webify-module-resolution-outcome-status
         webify-resolve-module-linklet-imports/outcomes
         webify-module-linklet-input/resolve-imports
         webify-register-module-linklet-input!
         webify-module-linklet-inputs->registry)

(require racket/list
         racket/match
         "module-registry.rkt")

(struct webify-module-linklet-input (name linklet imports) #:transparent)
(struct webify-module-linklet-manifest (inputs roots) #:transparent)
(struct webify-module-resolution-outcome
  (local dependency provider-export status)
  #:transparent)

;; validate-roots! : symbol? any/c -> void?
;;   Reject manifest roots that cannot identify module-linklet inputs.
(define (validate-roots! who roots)
  (unless (and (list? roots)
               (andmap symbol? roots))
    (raise-argument-error who "(listof symbol?)" roots)))

;; datum->webify-module-linklet-input : any/c -> webify-module-linklet-input?
;;   Parse one manifest input clause.
(define (datum->webify-module-linklet-input datum)
  (match datum
    [`(input ,(? symbol? name) ,linklet (imports ,imports))
     (webify-module-linklet-input name linklet imports)]
    [`(input ,(? symbol? name)
             ,linklet
             (resolve-imports (dependency-exports ,dependency-exports)))
     (webify-module-linklet-input/resolve-imports
      name
      linklet
      dependency-exports)]
    [`(input ,(? symbol? name)
             ,linklet
             (resolve-imports (dependency-exports ,dependency-exports)
                              (dependencies ,dependencies)))
     (webify-module-linklet-input/resolve-imports
      name
      linklet
      dependency-exports
      #:dependencies dependencies)]
    [_
     (raise-arguments-error 'datum->webify-module-linklet-manifest
                            "expected module-linklet input clause"
                            "clause" datum)]))

;; datum->webify-module-linklet-manifest : any/c -> webify-module-linklet-manifest?
;;   Parse a datum handoff format for extracted module-linklet inputs.
(define (datum->webify-module-linklet-manifest datum)
  (match datum
    [`(webify-module-linklet-manifest
       (roots ,roots)
       ,input-clauses ...)
     (validate-roots! 'datum->webify-module-linklet-manifest roots)
     (webify-module-linklet-manifest
      (map datum->webify-module-linklet-input input-clauses)
      roots)]
    [_
     (raise-arguments-error 'datum->webify-module-linklet-manifest
                            "expected webify module-linklet manifest datum"
                            "datum" datum)]))

;; read-webify-module-linklet-manifest : path-string? -> webify-module-linklet-manifest?
;;   Read one module-linklet manifest datum from a file.
(define (read-webify-module-linklet-manifest path)
  (call-with-input-file path
    (lambda (in)
      (datum->webify-module-linklet-manifest (read in)))))

;; linklet-import-bindings : symbol? any/c -> (listof (list/c symbol? symbol?))
;;   Extract flat local/external import bindings from a linklet datum.
(define (linklet-import-bindings who linklet)
  (match linklet
    [`(linklet ,importss ,_exports . ,_body)
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
     (define bindings (apply append importss))
     (define duplicate (check-duplicates (map car bindings)))
     (when duplicate
       (raise-arguments-error who
                              "duplicate linklet import names are not supported"
                              "import" duplicate))
     bindings]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; linklet-exports : symbol? any/c -> (listof symbol?)
;;   Extract flat external exports from a linklet datum.
(define (linklet-exports who linklet)
  (match linklet
    [`(linklet ,_importss ,exports . ,_body)
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
     (define duplicate (check-duplicates normalized-exports))
     (when duplicate
       (raise-arguments-error who
                              "duplicate linklet exports are not supported"
                              "export" duplicate))
     normalized-exports]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; validate-dependency-exports! : symbol? any/c -> void?
;;   Reject dependency export tables that cannot resolve import sources.
(define (validate-dependency-exports! who dependency-exports)
  (unless (list? dependency-exports)
    (raise-argument-error who "(listof (list/c symbol? (listof symbol?)))" dependency-exports))
  (for ([entry (in-list dependency-exports)])
    (match entry
      [(list (? symbol?) exports)
       (unless (and (list? exports)
                    (andmap symbol? exports))
         (raise-argument-error who "(listof symbol?)" exports))]
      [_
       (raise-argument-error who "(list/c symbol? (listof symbol?))" entry)]))
  (define duplicate (check-duplicates (map car dependency-exports)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate dependency export entries are not supported"
                           "dependency" duplicate)))

;; validate-import-dependencies! : symbol? any/c -> void?
;;   Reject explicit local-import to dependency-module mappings.
(define (validate-import-dependencies! who dependencies)
  (unless (list? dependencies)
    (raise-argument-error who "(listof (list/c symbol? symbol?))" dependencies))
  (for ([dependency (in-list dependencies)])
    (match dependency
      [(list (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error who "(list/c symbol? symbol?)" dependency)]))
  (define duplicate (check-duplicates (map car dependencies)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate import dependency entries are not supported"
                           "import" duplicate)))

;; validate-import-aliases! : symbol? any/c -> void?
;;   Reject explicit local-import to dependency export mappings.
(define (validate-import-aliases! who aliases)
  (unless (list? aliases)
    (raise-argument-error who "(listof (list/c symbol? symbol? symbol?))" aliases))
  (for ([alias (in-list aliases)])
    (match alias
      [(list (? symbol?) (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error who "(list/c symbol? symbol? symbol?)" alias)]))
  (define duplicate (check-duplicates (map car aliases)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate import alias entries are not supported"
                           "import" duplicate)))

;; validate-reflection-hints! : symbol? any/c -> void?
;;   Reject metadata-derived local-import provider hints.
(define (validate-reflection-hints! who hints)
  (unless (list? hints)
    (raise-argument-error who "(listof reflection-hint?)" hints))
  (for ([hint (in-list hints)])
    (match hint
      [(list (? symbol?) (? symbol?) (? symbol?))
       (void)]
      [(list (? symbol?) (? symbol?) (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error
        who
        "(or/c (list/c local dependency export) (list/c module local dependency export))"
        hint)])))

;; dependency-exports-ref : symbol? (listof dependency-exports?) symbol? -> (listof symbol?)
;;   Look up the exports declared for one dependency module.
(define (dependency-exports-ref who dependency-exports name)
  (define found (assoc name dependency-exports))
  (unless found
    (raise-arguments-error who
                           "import dependency has no export table entry"
                           "dependency" name
                           "available dependencies"
                           (map car dependency-exports)))
  (cadr found))

;; symbolic-name=? : symbol? symbol? -> boolean?
;;   Compare generated linklet names by printed identity when eq? is too strict.
(define (symbolic-name=? a b)
  (or (eq? a b)
      (string=? (symbol->string a) (symbol->string b))))

;; dependency-export-ref : symbol? dependency-name (listof symbol?) symbol? -> symbol?
;;   Find the provider export symbol that corresponds to an import's external name.
(define (dependency-export-ref who dependency exports external)
  (define matches
    (for/list ([export (in-list exports)]
               #:when (symbolic-name=? export external))
      export))
  (match matches
    [(list export) export]
    ['()
     (raise-arguments-error who
                            "dependency does not export required name"
                            "dependency" dependency
                            "export" external)]
    [_
     (raise-arguments-error who
                            "dependency export name is ambiguous"
                            "dependency" dependency
                            "export" external
                            "matches" matches)]))

;; broad-base-reexport-module? : symbol? -> boolean?
;;   Identify base aggregators whose public exports should not outrank private providers.
(define (broad-base-reexport-module? dependency)
  (memq dependency '(racket/base racket/private/base)))

;; provider-candidate-reason : symbol? -> symbol?
;;   Classify broad export-scan candidates for ambiguity diagnostics.
(define (provider-candidate-reason dependency)
  (if (broad-base-reexport-module? dependency)
      'broad-base-reexport
      'export-table-candidate))

;; prefer-provider-candidates : (listof symbol?) -> (listof symbol?)
;;   Prefer concrete provider candidates over broad base re-export aggregators.
(define (prefer-provider-candidates candidates)
  (define concrete-candidates
    (filter (lambda (dependency)
              (not (broad-base-reexport-module? dependency)))
            candidates))
  (if (null? concrete-candidates) candidates concrete-candidates))

;; provider-candidate-reasons : (listof symbol?) -> (listof list?)
;;   Explain why export-scan candidates survived far enough to be ambiguous.
(define (provider-candidate-reasons candidates)
  (for/list ([dependency (in-list candidates)])
    (list dependency (provider-candidate-reason dependency))))

;; webify-module-linklet-input-dependency-exports : webify-module-linklet-input? -> dependency-export-row
;;   Derive a resolver export row from the provider linklet's compiled exports.
(define (webify-module-linklet-input-dependency-exports input)
  (define who 'webify-module-linklet-input-dependency-exports)
  (unless (webify-module-linklet-input? input)
    (raise-argument-error who "webify-module-linklet-input?" input))
  (list (webify-module-linklet-input-name input)
        (linklet-exports who (webify-module-linklet-input-linklet input))))

;; webify-module-linklet-inputs-dependency-exports : (listof webify-module-linklet-input?) -> dependency-exports
;;   Derive a resolver export table from provider linklet inputs.
(define (webify-module-linklet-inputs-dependency-exports inputs)
  (define who 'webify-module-linklet-inputs-dependency-exports)
  (unless (list? inputs)
    (raise-argument-error who "(listof webify-module-linklet-input?)" inputs))
  (define dependency-exports
    (for/list ([input (in-list inputs)])
      (unless (webify-module-linklet-input? input)
        (raise-argument-error who "webify-module-linklet-input?" input))
      (webify-module-linklet-input-dependency-exports input)))
  (validate-dependency-exports! who dependency-exports)
  dependency-exports)

;; reflection-hints->map : symbol? (or/c symbol? #f) list? -> hash?
;;   Build a local-import map from reflection hints relevant to one module.
(define (reflection-hints->map who module-name hints)
  (validate-reflection-hints! who hints)
  (define rows
    (filter
     values
     (for/list ([hint (in-list hints)])
       (match hint
         [(list (? symbol? local) (? symbol? dependency) (? symbol? export))
          (list local dependency export)]
         [(list (? symbol? importer) (? symbol? local) (? symbol? dependency) (? symbol? export))
          (and (or (not module-name) (eq? importer module-name))
               (list local dependency export))]))))
  (define duplicate (check-duplicates (map car rows)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate reflection hint entries are not supported"
                           "import" duplicate))
  (for/hasheq ([row (in-list rows)])
    (match-define (list local dependency export) row)
    (values local (list dependency export))))

;; validate-provider-export! : symbol? dependency-exports symbol? symbol? -> symbol?
;;   Validate a selected provider/export pair and return the canonical export symbol.
(define (validate-provider-export! who dependency-exports dependency provider-export)
  (define exports (dependency-exports-ref who dependency-exports dependency))
  (unless (for/or ([export (in-list exports)])
            (symbolic-name=? export provider-export))
    (raise-arguments-error who
                           "dependency does not export hinted name"
                           "dependency" dependency
                           "export" provider-export))
  (dependency-export-ref who dependency exports provider-export))

;; resolve-import-source : symbol? dependency-exports hash? hash? hash? symbol? symbol? -> values
;;   Resolve one import binding to its provider module and provider export symbol.
(define (resolve-import-source who dependency-exports dependencies aliases hints local external)
  (define alias (hash-ref aliases local #f))
  (define explicit (hash-ref dependencies local #f))
  (define hint (hash-ref hints local #f))
  (cond
    [alias
     (match-define (list dependency provider-export) alias)
     (when (and explicit (not (eq? explicit dependency)))
       (raise-arguments-error who
                              "import alias conflicts with explicit dependency"
                              "import" local
                              "dependency" explicit
                              "alias dependency" dependency))
     (define exports (dependency-exports-ref who dependency-exports dependency))
     (unless (for/or ([export (in-list exports)])
               (symbolic-name=? export provider-export))
       (raise-arguments-error who
                              "dependency does not export aliased name"
                              "dependency" dependency
                              "export" provider-export))
     (list dependency
           (dependency-export-ref who dependency exports provider-export)
           'resolved-by-import-alias)]
    [explicit
     (define exports (dependency-exports-ref who dependency-exports explicit))
     (list explicit
           (dependency-export-ref who explicit exports external)
           'resolved-by-explicit-dependency)]
    [hint
     (match-define (list dependency provider-export) hint)
     (list dependency
           (validate-provider-export! who dependency-exports dependency provider-export)
           'resolved-by-reflection-hint)]
    [else
     (define candidates
       (for/list ([entry (in-list dependency-exports)]
                  #:do [(match-define (list dependency exports) entry)]
                  #:when (for/or ([export (in-list exports)])
                           (symbolic-name=? export external)))
         dependency))
     (define ranked-candidates (prefer-provider-candidates candidates))
     (cond
       [(null? candidates)
       (raise-arguments-error who
                               "missing-after-reflection"
                               "import" local
                               "export" external)]
       [(null? (cdr ranked-candidates))
        (define dependency (car ranked-candidates))
        (define exports (dependency-exports-ref who dependency-exports dependency))
        (list dependency
              (dependency-export-ref who dependency exports external)
              (if (equal? ranked-candidates candidates)
                  'resolved-by-export-scan
                  'resolved-by-export-scan/provider-precedence))]
       [else
        (raise-arguments-error who
                               "ambiguous-after-reflection"
                               "import" local
                               "export" external
                               "candidates" ranked-candidates
                               "candidate reasons"
                               (provider-candidate-reasons candidates))])]))

;; webify-resolve-module-linklet-imports/outcomes : linklet dependency-exports keyword-args ... -> values
;;   Derive flat registry import triples and classify each resolution decision.
(define (webify-resolve-module-linklet-imports/outcomes linklet
                                                        dependency-exports
                                                        #:module-name [module-name #f]
                                                        #:dependencies [dependencies '()]
                                                        #:import-aliases [import-aliases '()]
                                                        #:reflection-hints [reflection-hints '()])
  (define who 'webify-resolve-module-linklet-imports)
  (define bindings (linklet-import-bindings who linklet))
  (validate-dependency-exports! who dependency-exports)
  (validate-import-dependencies! who dependencies)
  (validate-import-aliases! who import-aliases)
  (unless (or (not module-name) (symbol? module-name))
    (raise-argument-error who "(or/c symbol? #f)" module-name))
  (define imports (map car bindings))
  (for ([dependency (in-list dependencies)])
    (match-define (list import _module) dependency)
    (unless (memq import imports)
      (raise-arguments-error who
                             "import dependency references a name not imported by the linklet"
                             "import" import
                             "linklet imports" imports)))
  (for ([alias (in-list import-aliases)])
    (match-define (list import _module _export) alias)
    (unless (memq import imports)
      (raise-arguments-error who
                             "import alias references a name not imported by the linklet"
                             "import" import
                             "linklet imports" imports)))
  (define dependency-map
    (for/hasheq ([dependency (in-list dependencies)])
      (match-define (list import module) dependency)
      (values import module)))
  (define alias-map
    (for/hasheq ([alias (in-list import-aliases)])
      (match-define (list import module export) alias)
      (values import (list module export))))
  (define hint-map
    (reflection-hints->map who module-name reflection-hints))
  (define resolved
    (for/list ([binding (in-list bindings)])
      (match-define (list local external) binding)
      (match-define (list dependency provider-export status)
        (resolve-import-source who dependency-exports dependency-map alias-map hint-map local external))
      (list (list local dependency provider-export)
            (webify-module-resolution-outcome local dependency provider-export status))))
  (values (map car resolved)
          (map cadr resolved)))

;; webify-resolve-module-linklet-imports : linklet dependency-exports [#:dependencies dependencies] -> imports
;;   Derive flat registry import triples from linklet imports and dependency exports.
(define (webify-resolve-module-linklet-imports linklet
                                               dependency-exports
                                               #:module-name [module-name #f]
                                               #:dependencies [dependencies '()]
                                               #:import-aliases [import-aliases '()]
                                               #:reflection-hints [reflection-hints '()])
  (define-values (imports outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     linklet
     dependency-exports
     #:module-name module-name
     #:dependencies dependencies
     #:import-aliases import-aliases
     #:reflection-hints reflection-hints))
  imports)

;; webify-module-linklet-input/resolve-imports : symbol? linklet dependency-exports [#:dependencies dependencies] -> input
;;   Build one module-linklet input while deriving its flat import triples.
(define (webify-module-linklet-input/resolve-imports name
                                                     linklet
                                                     dependency-exports
                                                     #:dependencies [dependencies '()]
                                                     #:import-aliases [import-aliases '()]
                                                     #:reflection-hints [reflection-hints '()])
  (webify-module-linklet-input
   name
   linklet
   (webify-resolve-module-linklet-imports
    linklet
    dependency-exports
    #:module-name name
    #:dependencies dependencies
    #:import-aliases import-aliases
    #:reflection-hints reflection-hints)))

;; webify-register-module-linklet-input! : webify-module-registry? webify-module-linklet-input? -> void?
;;   Register one extracted module-linklet input in a module registry.
(define (webify-register-module-linklet-input! registry input)
  (define who 'webify-register-module-linklet-input!)
  (unless (webify-module-linklet-input? input)
    (raise-argument-error who "webify-module-linklet-input?" input))
  (webify-module-registry-add!
   registry
   (webify-module-linklet-input-name input)
   (webify-module-linklet-input-linklet input)
   #:imports (webify-module-linklet-input-imports input)))

;; webify-module-linklet-inputs->registry : (listof webify-module-linklet-input?) -> webify-module-registry?
;;   Build a registry from already-extracted module-linklet inputs.
(define (webify-module-linklet-inputs->registry inputs)
  (define who 'webify-module-linklet-inputs->registry)
  (unless (list? inputs)
    (raise-argument-error who "(listof webify-module-linklet-input?)" inputs))
  (define registry (make-webify-module-registry))
  (for ([input (in-list inputs)])
    (webify-register-module-linklet-input! registry input))
  registry)

;; webify-module-linklet-manifest->registry : webify-module-linklet-manifest? -> webify-module-registry?
;;   Build a registry from a parsed module-linklet manifest.
(define (webify-module-linklet-manifest->registry manifest)
  (unless (webify-module-linklet-manifest? manifest)
    (raise-argument-error 'webify-module-linklet-manifest->registry
                          "webify-module-linklet-manifest?"
                          manifest))
  (webify-module-linklet-inputs->registry
   (webify-module-linklet-manifest-inputs manifest)))
