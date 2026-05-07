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
         webify-resolve-module-linklet-imports
         webify-module-linklet-input/resolve-imports
         webify-register-module-linklet-input!
         webify-module-linklet-inputs->registry)

(require racket/list
         racket/match
         "module-registry.rkt")

(struct webify-module-linklet-input (name linklet imports) #:transparent)
(struct webify-module-linklet-manifest (inputs roots) #:transparent)

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

;; dependency-exports-ref : symbol? (listof dependency-exports?) symbol? -> (listof symbol?)
;;   Look up the exports declared for one dependency module.
(define (dependency-exports-ref who dependency-exports name)
  (define found (assoc name dependency-exports))
  (unless found
    (raise-arguments-error who
                           "import dependency has no export table entry"
                           "dependency" name))
  (cadr found))

;; resolve-import-dependency : symbol? (listof dependency-exports?) hash? symbol? symbol? -> symbol?
;;   Resolve one import binding to a dependency module.
(define (resolve-import-dependency who dependency-exports dependencies local external)
  (define explicit (hash-ref dependencies local #f))
  (cond
    [explicit
     (define exports (dependency-exports-ref who dependency-exports explicit))
     (unless (memq external exports)
       (raise-arguments-error who
                              "explicit import dependency does not export required name"
                              "import" local
                              "dependency" explicit
                              "export" external))
     explicit]
    [else
     (define candidates
       (for/list ([entry (in-list dependency-exports)]
                  #:when (memq external (cadr entry)))
         (car entry)))
     (cond
       [(null? candidates)
        (raise-arguments-error who
                               "could not resolve import dependency"
                               "import" local
                               "export" external)]
       [(null? (cdr candidates))
        (car candidates)]
       [else
        (raise-arguments-error who
                               "ambiguous import dependency"
                               "import" local
                               "export" external
                               "candidates" candidates)])]))

;; webify-resolve-module-linklet-imports : linklet dependency-exports [#:dependencies dependencies] -> imports
;;   Derive flat registry import triples from linklet imports and dependency exports.
(define (webify-resolve-module-linklet-imports linklet
                                               dependency-exports
                                               #:dependencies [dependencies '()])
  (define who 'webify-resolve-module-linklet-imports)
  (define bindings (linklet-import-bindings who linklet))
  (validate-dependency-exports! who dependency-exports)
  (validate-import-dependencies! who dependencies)
  (define imports (map car bindings))
  (for ([dependency (in-list dependencies)])
    (match-define (list import _module) dependency)
    (unless (memq import imports)
      (raise-arguments-error who
                             "import dependency references a name not imported by the linklet"
                             "import" import
                             "linklet imports" imports)))
  (define dependency-map
    (for/hasheq ([dependency (in-list dependencies)])
      (match-define (list import module) dependency)
      (values import module)))
  (for/list ([binding (in-list bindings)])
    (match-define (list local external) binding)
    (list local
          (resolve-import-dependency who dependency-exports dependency-map local external)
          external)))

;; webify-module-linklet-input/resolve-imports : symbol? linklet dependency-exports [#:dependencies dependencies] -> input
;;   Build one module-linklet input while deriving its flat import triples.
(define (webify-module-linklet-input/resolve-imports name
                                                     linklet
                                                     dependency-exports
                                                     #:dependencies [dependencies '()])
  (webify-module-linklet-input
   name
   linklet
   (webify-resolve-module-linklet-imports
    linklet
    dependency-exports
    #:dependencies dependencies)))

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
