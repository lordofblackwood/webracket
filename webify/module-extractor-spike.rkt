#lang racket/base

(provide webify-module-extractor-spike
         webify-module-extractor-spike?
         webify-module-extractor-spike-name
         webify-module-extractor-spike-directory-keys
         webify-module-extractor-spike-bundle-keys
         webify-module-extractor-spike-bundle-entries
         webify-module-extractor-spike-phase0-imports
         webify-module-extractor-spike-phase0-exports
         webify-module-extractor-spike-phase0-linklet-datum
         webify-module-extractor-spike-manifest-ready?
         webify-module-extractor-spike-notes
         webify-module-import-map
         webify-module-import-map?
         webify-module-import-map-phase0-import-groups
         webify-module-import-map-phase0-structured-import-groups
         webify-module-import-map-phase0-decompiled-import-groups
         webify-module-import-map-module-protocol-import-groups
         webify-module-import-map-unresolved-import-groups
         webify-module-import-map-data-module-path-indexes
         webify-module-import-map-decl-requires-expression
         webify-module-import-map-decl-provides-expression
         webify-module-import-map-decl-phase-to-link-modules-expression
         webify-module-import-map-required-module-candidates
         webify-module-import-map-import-aliases
         webify-module-import-map-missing-alias-import-groups
         webify-module-import-map-notes
         webify-module-bundle-entry
         webify-module-bundle-entry?
         webify-module-bundle-entry-key
         webify-module-bundle-entry-kind
         webify-module-bundle-entry-imports
         webify-module-bundle-entry-exports
         webify-module-bundle-entry-datum
         webify-module-bundle-entry-value
         webify-module-bundle-entry-ref
         webify-module-extractor-spike-import-map
         webify-normalize-linklet-imports
         webify-linklet-import-bindings
         webify-source-module->linklet-input
         webify-source-module->resolved-linklet-input
         webify-compile-module-extractor-spike)

(require racket/linklet
         racket/list
         racket/match
         racket/string
         "module-input.rkt")

(struct webify-module-extractor-spike
  (name
   directory-keys
   bundle-keys
   bundle-entries
   phase0-imports
   phase0-exports
   phase0-linklet-datum
   manifest-ready?
   notes)
  #:transparent)

(struct webify-module-bundle-entry
  (key
   kind
   imports
   exports
   datum
   value)
  #:transparent)

(struct webify-module-import-map
  (phase0-import-groups
   phase0-structured-import-groups
   phase0-decompiled-import-groups
   module-protocol-import-groups
   unresolved-import-groups
   data-module-path-indexes
   decl-requires-expression
   decl-provides-expression
   decl-phase-to-link-modules-expression
   required-module-candidates
   import-aliases
   missing-alias-import-groups
   notes)
  #:transparent)

;; maybe-decompile-linklet : (or/c procedure? #f)
;;   Use the newer decompiler API when the host Racket provides it.
(define maybe-decompile-linklet
  (dynamic-require 'racket/linklet 'decompile-linklet (lambda () #f)))

;; known-module-protocol-imports : (listof symbol?)
;;   Module-layer protocol imports seen in decompiled phase-0 source-module linklets.
(define known-module-protocol-imports
  '(.get-syntax-literal!
    .set-transformer!))

;; key<? : any/c any/c -> boolean?
;;   Sort mixed linklet-directory keys deterministically for spike reports.
(define (key<? a b)
  (string<? (format "~s" a) (format "~s" b)))

;; bundle-entry<? : webify-module-bundle-entry? webify-module-bundle-entry? -> boolean?
;;   Sort bundle entries by their mixed key values.
(define (bundle-entry<? a b)
  (key<? (webify-module-bundle-entry-key a)
         (webify-module-bundle-entry-key b)))

;; validate-source-module! : symbol? any/c -> symbol?
;;   Check the tiny source-module shape accepted by this extractor spike.
(define (validate-source-module! who module-datum)
  (match module-datum
    [`(module ,(? symbol? name) ,_language . ,_body)
     name]
    [_
     (raise-arguments-error who
                            "expected a source module datum"
                            "module" module-datum)]))

;; strip-correlated* : any/c -> any/c
;;   Recursively convert correlated objects to plain datum values.
(define (strip-correlated* v)
  (cond
    [(correlated? v) (strip-correlated* (correlated-e v))]
    [(pair? v)       (cons (strip-correlated* (car v))
                           (strip-correlated* (cdr v)))]
    [(vector? v)     (list->vector (map strip-correlated* (vector->list v)))]
    [else            v]))

;; linklet-datum? : any/c -> boolean?
;;   Check whether v has the linklet datum shape consumed by webify manifests.
(define (linklet-datum? v)
  (match v
    [`(linklet ,importss ,exports . ,body)
     (and (list? importss)
          (list? exports)
          (list? body))]
    [_ #f]))

;; decompile-linklet-datum : linklet? -> (or/c linklet-datum? #f)
;;   Recover a plain datum for a linklet when the host Racket supports it.
(define (decompile-linklet-datum linklet)
  (and maybe-decompile-linklet
       (strip-correlated* (maybe-decompile-linklet linklet))))

;; bundle-value-kind : any/c -> symbol?
;;   Classify one compiled bundle value for extractor reports.
(define (bundle-value-kind value)
  (cond
    [(linklet? value)           'linklet]
    [(linklet-bundle? value)    'bundle]
    [(linklet-directory? value) 'directory]
    [else                      'metadata]))

;; bundle-value->entry : any/c any/c -> webify-module-bundle-entry?
;;   Convert one linklet-bundle hash entry into report data.
(define (bundle-value->entry key value)
  (define datum
    (and (linklet? value)
         (decompile-linklet-datum value)))
  (webify-module-bundle-entry
   key
   (bundle-value-kind value)
   (and (linklet? value) (linklet-import-variables value))
   (and (linklet? value) (linklet-export-variables value))
   datum
   value))

;; webify-module-bundle-entry-ref : report any/c -> webify-module-bundle-entry?
;;   Look up a bundle entry by key.
(define (webify-module-bundle-entry-ref report key)
  (define who 'webify-module-bundle-entry-ref)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (or (for/first ([entry (in-list (webify-module-extractor-spike-bundle-entries report))]
                  #:when (equal? key (webify-module-bundle-entry-key entry)))
        entry)
      (raise-arguments-error who
                             "bundle entry not found"
                             "key" key
                             "available keys" (webify-module-extractor-spike-bundle-keys report))))

;; normalize-linklet-import-binding : symbol? any/c -> (list/c symbol? symbol?)
;;   Expand decompiled shorthand to the bridge's explicit local/external pair.
(define (normalize-linklet-import-binding who binding)
  (match binding
    [(? symbol? import)
     (list import import)]
    [(list (? symbol? external) (? symbol? local))
     (list local external)]
    [_
     (raise-arguments-error who
                            "linklet imports must be symbols or local/external symbol pairs"
                            "import" binding)]))

;; normalize-linklet-import-group : symbol? any/c -> (listof (list/c symbol? symbol?))
;;   Normalize one decompiled or metadata import group.
(define (normalize-linklet-import-group who group)
  (unless (list? group)
    (raise-arguments-error who
                           "linklet import group must be a list"
                           "group" group))
  (for/list ([binding (in-list group)])
    (normalize-linklet-import-binding who binding)))

;; webify-normalize-linklet-imports : linklet-datum -> linklet-datum
;;   Normalize import shorthand in a decompiled linklet datum.
(define (webify-normalize-linklet-imports linklet)
  (define who 'webify-normalize-linklet-imports)
  (match linklet
    [`(linklet ,importss ,exports . ,body)
     (unless (list? importss)
       (raise-arguments-error who
                              "linklet imports must be a list of import groups"
                              "imports" importss))
     `(linklet ,(for/list ([group (in-list importss)])
                  (normalize-linklet-import-group who group))
        ,exports
        . ,body)]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; webify-linklet-import-bindings : linklet-datum -> (listof (list/c symbol? symbol?))
;;   Return normalized local/external bindings from a linklet datum.
(define (webify-linklet-import-bindings linklet)
  (match (webify-normalize-linklet-imports linklet)
    [`(linklet ,importss ,_exports . ,_body)
     (define bindings
       (for*/list ([group   (in-list importss)]
                   [binding (in-list group)])
         binding))
     (define duplicate (check-duplicates (map car bindings)))
     (when duplicate
       (raise-arguments-error 'webify-linklet-import-bindings
                              "duplicate linklet import names are not supported"
                              "import" duplicate))
     bindings]))

;; module-protocol-import-binding? : (list/c symbol? symbol?) -> boolean?
;;   Recognize imports currently supplied only by Racket's module protocol.
(define (module-protocol-import-binding? binding)
  (memq (cadr binding) known-module-protocol-imports))

;; linklet-body-definition-expression : linklet-datum symbol? -> any/c
;;   Find the expression for a single-value definition in a decompiled linklet body.
(define (linklet-body-definition-expression linklet id)
  (match linklet
    [`(linklet ,_imports ,_exports . ,body)
     (for/first ([form (in-list body)]
                 #:when (match form
                          [`(define-values (,defined-id) ,_expr)
                           (eq? defined-id id)]
                          [_ #f]))
       (match form
         [`(define-values (,_defined-id) ,expr) expr]))]
    [_ #f]))

;; data-linklet-module-path-indexes : (or/c linklet-datum? #f) -> any/c
;;   Extract the serialized module-path-index seed vector from a data linklet.
(define (data-linklet-module-path-indexes data-linklet)
  (and data-linklet
       (match (linklet-body-definition-expression data-linklet '.mpi-vector)
         [`(deserialize-module-path-indexes ',mpi-vector ',_self-vector)
          mpi-vector]
         [_ #f])))

;; module-path-index->dependency-name : any/c -> (or/c symbol? #f)
;;   Convert a simple quoted module-path vector into a registry dependency name.
(define (module-path-index->dependency-name mpi)
  (cond
    [(and (vector? mpi)
          (positive? (vector-length mpi))
          (for/and ([part (in-vector mpi)])
            (symbol? part)))
     (string->symbol
      (string-join
       (for/list ([part (in-vector mpi)])
         (symbol->string part))
       "/"))]
    [(symbol? mpi) mpi]
    [else #f]))

;; phase-to-link-modules-candidates : any/c any/c -> (listof (list/c exact-integer? symbol?))
;;   Decode simple phase-to-link-modules expressions into candidate dependencies.
(define (phase-to-link-modules-candidates expr mpi-vector)
  (define (mpi-ref idx)
    (and (vector? mpi-vector)
         (exact-nonnegative-integer? idx)
         (< idx (vector-length mpi-vector))
         (module-path-index->dependency-name (vector-ref mpi-vector idx))))
  (define (decode-module-use use)
    (match use
      [`(module-use (unsafe-vector*-ref .mpi-vector ,idx) ,_phase)
       (mpi-ref idx)]
      [_ #f]))
  (define (decode-use-list uses)
    (match uses
      [`(list ,use ...)
       (filter values (map decode-module-use use))]
      [_ '()]))
  (match expr
    [`(hasheqv ,items ...)
     (let loop ([items items]
                [candidates '()])
       (match items
         ['() (reverse candidates)]
         [(list* (? exact-integer? phase) uses rest)
          (loop rest
                (append
                 (for/list ([name (in-list (decode-use-list uses))])
                   (list phase name))
                 candidates))]
         [_ (reverse candidates)]))]
    [_ '()]))

;; generated-import-name? : symbol? -> boolean?
;;   Heuristically recognize generated internal import names in decompiled linklets.
(define (generated-import-name? name)
  (regexp-match? #rx"[.][0-9]+$" (symbol->string name)))

;; phase0-import-groups : webify-module-extractor-spike? -> import-groups
;;   Return normalized phase-0 import groups from metadata.
(define (phase0-import-groups report)
  (for/list ([group (in-list (webify-module-extractor-spike-phase0-imports report))])
    (normalize-linklet-import-group 'webify-module-extractor-spike-import-map group)))

;; linklet-datum-import-groups : linklet-datum -> import-groups
;;   Return normalized import groups from a decompiled linklet datum.
(define (linklet-datum-import-groups linklet)
  (match (webify-normalize-linklet-imports linklet)
    [`(linklet ,importss ,_exports . ,_body) importss]))

;; protocol-import-group? : import-group -> boolean?
;;   Check whether every binding in a group is supplied by the module protocol.
(define (protocol-import-group? group)
  (and (pair? group)
       (andmap module-protocol-import-binding? group)))

;; import-group-needs-alias-evidence? : import-group -> boolean?
;;   Detect groups whose names look internalized and need deeper decl decoding.
(define (import-group-needs-alias-evidence? group)
  (for/or ([binding (in-list group)])
    (match-define (list local external) binding)
    (or (not (eq? local external))
        (generated-import-name? local)
        (generated-import-name? external))))

;; import-group->aliases : import-group candidates -> (or/c aliases #f)
;;   Infer aliases only for one clear phase-0 dependency and non-generated export names.
(define (import-group->aliases group required-module-candidates)
  (define phase0-candidates
    (for/list ([candidate (in-list required-module-candidates)]
               #:when (= 0 (car candidate)))
      (cadr candidate)))
  (and (= 1 (length phase0-candidates))
       (for/and ([binding (in-list group)])
         (match-define (list local external) binding)
         (and (not (eq? local external))
              (not (generated-import-name? external))))
       (for/list ([binding (in-list group)])
         (match-define (list local external) binding)
         (list local (car phase0-candidates) external))))

;; webify-module-extractor-spike-import-map : report -> webify-module-import-map?
;;   Build an observational import-map report from phase-0, data, and decl linklets.
(define (webify-module-extractor-spike-import-map report)
  (define who 'webify-module-extractor-spike-import-map)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (define structured-import-groups (phase0-import-groups report))
  (define decompiled-import-groups
    (cond
      [(webify-module-extractor-spike-phase0-linklet-datum report)
       (linklet-datum-import-groups
        (webify-module-extractor-spike-phase0-linklet-datum report))]
      [else structured-import-groups]))
  (define import-groups decompiled-import-groups)
  (define protocol-groups (filter protocol-import-group? import-groups))
  (define unresolved-groups (filter (lambda (group)
                                      (not (protocol-import-group? group)))
                                    import-groups))
  (define data-entry (webify-module-bundle-entry-ref report 'data))
  (define decl-entry (webify-module-bundle-entry-ref report 'decl))
  (define data-linklet (webify-module-bundle-entry-datum data-entry))
  (define decl-linklet (webify-module-bundle-entry-datum decl-entry))
  (define data-module-path-indexes (data-linklet-module-path-indexes data-linklet))
  (define decl-requires-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'requires)))
  (define decl-provides-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'provides)))
  (define decl-phase-to-link-modules-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'phase-to-link-modules)))
  (define required-module-candidates
    (phase-to-link-modules-candidates
     decl-phase-to-link-modules-expression
     data-module-path-indexes))
  (define alias-results
    (for/list ([group (in-list unresolved-groups)])
      (cons group (import-group->aliases group required-module-candidates))))
  (define import-aliases
    (apply append
           (for/list ([result (in-list alias-results)]
                      #:when (cdr result))
             (cdr result))))
  (define missing-alias-import-groups
    (for/list ([result (in-list alias-results)]
               #:do [(define group (car result))]
               #:when (and (import-group-needs-alias-evidence? group)
                           (not (cdr result))))
      group))
  (webify-module-import-map
   import-groups
   structured-import-groups
   decompiled-import-groups
   protocol-groups
   unresolved-groups
   data-module-path-indexes
   decl-requires-expression
   decl-provides-expression
   decl-phase-to-link-modules-expression
   required-module-candidates
   import-aliases
   missing-alias-import-groups
   (cond
     [(not decl-linklet)
      '("decl/data metadata is unavailable on this host because linklet decompilation is unavailable")]
     [(pair? missing-alias-import-groups)
      '("phase-0 contains internalized non-protocol import groups"
        "decl/data metadata exposes required-module candidates but not public export aliases"
        "deeper decl deserialization is needed before resolving these imports automatically")]
     [(and (pair? unresolved-groups) (pair? required-module-candidates))
      '("phase-0 contains non-protocol import groups"
        "decl/data metadata provides simple required-module candidates"
        "export tables are still required before resolving imports")]
     [(null? unresolved-groups)
      '("phase-0 imports are limited to known module-protocol imports"
        "decl/data metadata is available for future require decoding")]
     [else
      '("phase-0 contains non-protocol import groups"
        "decl/data metadata likely maps those groups to required modules"
        "this spike reports the raw metadata but does not decode it yet")])))

;; resolve-extracted-linklet-imports : symbol? linklet-datum ... -> imports
;;   Classify extracted imports and turn supported ones into flat bridge triples.
(define (resolve-extracted-linklet-imports who
                                           linklet
                                           dependency-exports
                                           dependencies
                                           required-module-candidates
                                           module-protocol-dependency)
  (when module-protocol-dependency
    (unless (symbol? module-protocol-dependency)
      (raise-argument-error who "symbol?" module-protocol-dependency)))
  (define bindings (webify-linklet-import-bindings linklet))
  (define module-protocol-bindings (filter module-protocol-import-binding? bindings))
  (define module-bindings (filter (lambda (binding)
                                    (not (module-protocol-import-binding? binding)))
                                  bindings))
  (when (and (pair? module-protocol-bindings) (not module-protocol-dependency))
    (raise-arguments-error who
                           "extracted linklet imports require WebRacket module protocol dependency support"
                           "imports" (map car module-protocol-bindings)
                           "hint" "pass #:module-protocol-dependency when a module protocol input exists"))
  (define module-protocol-triples
    (for/list ([binding (in-list module-protocol-bindings)])
      (match-define (list local external) binding)
      (list local module-protocol-dependency external)))
  (define module-triples
    (cond
      [(null? module-bindings) '()]
      [else
       (define inferred-dependencies
         (for/list ([binding (in-list module-bindings)]
                    #:do [(match-define (list local external) binding)]
                    #:unless (assoc local dependencies)
                    [candidate (in-list required-module-candidates)]
                    #:do [(define candidate-exports
                            (assoc (cadr candidate) dependency-exports))]
                    #:when (and (= 0 (car candidate))
                                candidate-exports
                                (memq external (cadr candidate-exports))))
           (list local (cadr candidate))))
       (define duplicate-inferred (check-duplicates (map car inferred-dependencies)))
       (when duplicate-inferred
         (raise-arguments-error who
                                "ambiguous inferred import dependency"
                                "import" duplicate-inferred
                                "candidates" inferred-dependencies))
       (webify-resolve-module-linklet-imports
        `(linklet (,module-bindings) () (void))
        dependency-exports
        #:dependencies (append dependencies inferred-dependencies))]))
  (define triples-by-import
    (for/hasheq ([triple (in-list (append module-protocol-triples module-triples))])
      (values (car triple) triple)))
  (for/list ([binding (in-list bindings)])
    (hash-ref triples-by-import (car binding))))

;; webify-compile-module-extractor-spike : any/c -> webify-module-extractor-spike?
;;   Probe Racket's compiled-module linklet shape without claiming extraction support.
(define (webify-compile-module-extractor-spike module-datum)
  (define who 'webify-compile-module-extractor-spike)
  (define name (validate-source-module! who module-datum))
  (define compiled
    (parameterize ([current-namespace (make-base-namespace)])
      (parameterize ([current-compile-target-machine #f])
        (compile (datum->syntax #f module-datum)))))
  (unless (linklet-directory? compiled)
    (raise-arguments-error who
                           "compiled module did not produce a linklet directory"
                           "compiled" compiled))
  (define directory-hash (linklet-directory->hash compiled))
  (define main-bundle
    (hash-ref directory-hash
              #f
              (lambda ()
                (raise-arguments-error who
                                       "compiled module has no main linklet bundle"
                                       "directory keys" (hash-keys directory-hash)))))
  (unless (linklet-bundle? main-bundle)
    (raise-arguments-error who
                           "main directory entry is not a linklet bundle"
                           "entry" main-bundle))
  (define bundle-hash (linklet-bundle->hash main-bundle))
  (define bundle-entries
    (sort
     (for/list ([(key value) (in-hash bundle-hash)])
       (bundle-value->entry key value))
     bundle-entry<?))
  (define phase0-linklet
    (hash-ref bundle-hash
              0
              (lambda ()
                (raise-arguments-error who
                                       "main bundle has no phase-0 linklet"
                                       "bundle keys" (hash-keys bundle-hash)))))
  (unless (linklet? phase0-linklet)
    (raise-arguments-error who
                           "phase-0 bundle entry is not a linklet"
                           "entry" phase0-linklet))
  (define phase0-entry
    (for/first ([entry (in-list bundle-entries)]
                #:when (equal? 0 (webify-module-bundle-entry-key entry)))
      entry))
  (define phase0-linklet-datum
    (webify-module-bundle-entry-datum phase0-entry))
  (define manifest-ready? (linklet-datum? phase0-linklet-datum))
  (webify-module-extractor-spike
   name
   (sort (hash-keys directory-hash) key<?)
   (sort (hash-keys bundle-hash) key<?)
   bundle-entries
   (linklet-import-variables phase0-linklet)
   (linklet-export-variables phase0-linklet)
   phase0-linklet-datum
   manifest-ready?
   (cond
     [manifest-ready?
      '("machine-independent compilation exposes a decompilable phase-0 linklet datum"
        "compiled module import metadata still includes module protocol plumbing")]
     [maybe-decompile-linklet
      '("compiled source modules expose linklet objects and metadata"
        "decompile-linklet did not produce a linklet datum for the phase-0 linklet")]
     [else
      '("compiled source modules expose linklet objects and metadata"
        "host Racket does not provide decompile-linklet"
        "use the newer ../racket checkout for the machine-independent decompile spike")])))

;; webify-source-module->linklet-input : module-datum [#:imports imports] -> webify-module-linklet-input?
;;   Extract the phase-0 linklet datum from a source module into the manifest input shape.
(define (webify-source-module->linklet-input module-datum #:imports [imports #f])
  (define who 'webify-source-module->linklet-input)
  (define report (webify-compile-module-extractor-spike module-datum))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (webify-module-linklet-input
   (webify-module-extractor-spike-name report)
   (webify-normalize-linklet-imports
    (webify-module-extractor-spike-phase0-linklet-datum report))
   imports))

;; webify-source-module->resolved-linklet-input : module-datum ... -> webify-module-linklet-input?
;;   Extract a source module and resolve classified imports into bridge triples.
(define (webify-source-module->resolved-linklet-input module-datum
                                                       #:dependency-exports [dependency-exports '()]
                                                       #:dependencies [dependencies '()]
                                                       #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-source-module->resolved-linklet-input)
  (define report (webify-compile-module-extractor-spike module-datum))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define linklet
    (webify-normalize-linklet-imports
     (webify-module-extractor-spike-phase0-linklet-datum report)))
  (webify-module-linklet-input
   (webify-module-extractor-spike-name report)
   linklet
   (resolve-extracted-linklet-imports who
                                      linklet
                                      dependency-exports
                                      dependencies
                                      (webify-module-import-map-required-module-candidates import-map)
                                      module-protocol-dependency)))
