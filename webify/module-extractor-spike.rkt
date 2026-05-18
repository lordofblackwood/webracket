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
         webify-module-import-map-require-rename-aliases
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
         webify-module-extractor-spike-required-provider-names
         webify-module-extractor-spike->required-provider-spikes
         webify-module-extractor-spikes->required-provider-closure
         webify-module-export-demand
         webify-module-export-demand?
         webify-module-export-demand-module
         webify-module-export-demand-exports
         webify-module-export-demand-reason
         webify-module-export-demand-reason?
         webify-module-export-demand-reason-module
         webify-module-export-demand-reason-export
         webify-module-export-demand-reason-importer
         webify-module-export-demand-reason-import
         webify-module-export-demand-reason-local
         webify-module-extractor-spike-import-export-demands
         webify-module-extractor-spike-import-export-demand-reasons
         webify-module-extractor-spike/slice-exports
         webify-module-extractor-spikes->discovered-resolved-linklet-inputs
         webify-module-provider-discovery-run-stages
         webify-module-provider-discovery-stages?
         webify-module-provider-discovery-stages-discovered-reports
         webify-module-provider-discovery-stages-resolved-reports
         webify-module-provider-discovery-stages-inputs
         webify-module-provider-discovery-stages-timings
         webify-module-provider-discovery-trace-event
         webify-module-provider-discovery-trace-event?
         webify-module-provider-discovery-trace-event-provider
         webify-module-provider-discovery-trace-event-demander
         webify-module-provider-discovery-trace-event-depth
         webify-module-provider-discovery-trace-event-cached?
         webify-module-provider-discovery-trace-event-reason
         webify-module-provider-discovery-trace-event-elapsed-ms
         webify-module-provider-discovery-trace-event-status
         webify-module-provider-cache
         webify-module-provider-cache?
         make-webify-module-provider-cache
         webify-module-provider-cache-ref
         webify-module-provider-cache-hit-count
         webify-module-provider-cache-miss-count
         webify-module-provider-cache-names
         webify-module-provider-cache-count
         webify-module-extractor-spike-dependency-exports
         webify-module-extractor-spikes-dependency-exports
         webify-module-path->extractor-spike
         webify-module-path->module-export-metadata
         webify-module-paths->module-export-metadata
         webify-source-module->dependency-exports
         webify-source-modules->dependency-exports
         webify-source-module->module-export-metadata
         webify-source-modules->module-export-metadata
         webify-normalize-linklet-imports
         webify-normalize-linklet-exports
         webify-linklet-import-bindings
         webify-source-module->linklet-input
         webify-module-extractor-spike->resolved-linklet-input
         webify-module-extractor-spike->resolved-linklet-input/providers
         webify-module-extractor-spikes->resolved-linklet-inputs
         webify-source-module->resolved-linklet-input
         webify-source-module->resolved-linklet-input/providers
         webify-source-modules->resolved-linklet-inputs
         webify-source-modules->discovered-resolved-linklet-inputs
         webify-compile-module-extractor-spike)

(require racket/linklet
         racket/list
         racket/match
         racket/string
         syntax/modcode
         "faslable-linklet.rkt"
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
   require-rename-aliases
   missing-alias-import-groups
   notes)
  #:transparent)

(struct webify-module-provider-cache (fetch-provider table hits misses) #:transparent)
(struct webify-module-export-demand (module exports) #:transparent)
(struct webify-module-export-demand-reason (module export importer import local) #:transparent)
(struct webify-module-provider-discovery-stages
  (discovered-reports resolved-reports inputs timings)
  #:constructor-name make-webify-module-provider-discovery-stages
  #:transparent)
(struct webify-module-provider-discovery-trace-event
  (provider demander depth cached? reason elapsed-ms status)
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
    [(webify-faslable-correlated-linklet? value) 'faslable-linklet]
    [else                      'metadata]))

;; linklet-datum-imports+exports : any/c -> values
;;   Extract raw imports and exports from a plain linklet datum.
(define (webify-normalize-linklet-exports exports)
  (define who 'webify-normalize-linklet-exports)
  (unless (list? exports)
    (raise-argument-error who "list?" exports))
  (define (normalize-export export)
    (match export
      [(list _internal (? symbol? external)) external]
      [(? symbol? external) external]
      [_
       (raise-arguments-error who
                              "linklet exports must be symbols or internal/external symbol pairs"
                              "export" export)]))
  (map normalize-export exports))

;; linklet-export-descriptors : symbol? (listof any/c) -> (listof (list/c symbol? symbol? any/c))
;;   Decode raw linklet export forms as internal name, external name, and raw form.
(define (linklet-export-descriptors who exports)
  (unless (list? exports)
    (raise-argument-error who "list?" exports))
  (for/list ([export (in-list exports)])
    (match export
      [(list (? symbol? internal) (? symbol? external))
       (list internal external export)]
      [(? symbol? external)
       (list external external export)]
      [_
       (raise-arguments-error who
                              "linklet exports must be symbols or internal/external symbol pairs"
                              "export" export)])))

;; linklet-datum-imports+exports : any/c -> values
;;   Extract raw imports and normalized external exports from a plain linklet datum.
(define (linklet-datum-imports+exports datum)
  (match datum
    [`(linklet ,imports ,exports . ,_body)
     (values imports (webify-normalize-linklet-exports exports))]
    [_ (values #f #f)]))

;; bundle-value->entry : any/c any/c -> webify-module-bundle-entry?
;;   Convert one linklet-bundle hash entry into report data.
(define (bundle-value->entry key value)
  (define datum
    (cond
      [(linklet? value) (decompile-linklet-datum value)]
      [(webify-faslable-correlated-linklet? value)
       (webify-faslable-correlated-linklet->datum value)]
      [else #f]))
  (define-values (datum-imports datum-exports)
    (linklet-datum-imports+exports datum))
  (webify-module-bundle-entry
   key
   (bundle-value-kind value)
   (cond
     [(linklet? value) (linklet-import-variables value)]
     [datum-imports datum-imports]
     [else #f])
   (cond
     [(linklet? value) (linklet-export-variables value)]
     [datum-exports datum-exports]
     [else #f])
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

;; maybe-module-bundle-entry-ref : report any/c -> (or/c webify-module-bundle-entry? #f)
;;   Look up an optional bundle entry by key.
(define (maybe-module-bundle-entry-ref report key)
  (for/first ([entry (in-list (webify-module-extractor-spike-bundle-entries report))]
              #:when (equal? key (webify-module-bundle-entry-key entry)))
    entry))

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

;; module-path->dependency-name : any/c -> symbol?
;;   Convert a simple module path to the registry dependency name convention.
(define (module-path->dependency-name module-path)
  (cond
    [(symbol? module-path) module-path]
    [(path? module-path)
     (string->symbol (path->string module-path))]
    [(and (list? module-path)
          (eq? (car module-path) 'lib)
          (pair? (cdr module-path))
          (string? (cadr module-path)))
     (define path (cadr module-path))
     (define no-suffix
       (if (string-suffix? path ".rkt")
           (substring path 0 (- (string-length path) 4))
           path))
     (string->symbol no-suffix)]
    [else
     (raise-arguments-error 'webify-module-path->extractor-spike
                            "expected a simple module path"
                            "module path" module-path)]))

;; relative-module-name : symbol? string? -> symbol?
;;   Resolve a relative module path from compiled metadata against a module name.
(define (relative-module-name base-name relative-path)
  (define (collapse-parts parts)
    (let loop ([parts parts] [acc '()])
      (match parts
        ['() (reverse acc)]
        [(cons "." more)
         (loop more acc)]
        [(cons ".." more)
         (loop more (if (null? acc) acc (cdr acc)))]
        [(cons part more)
         (loop more (cons part acc))])))
  (define base-parts (string-split (symbol->string base-name) "/"))
  (define base-dir (reverse (cdr (reverse base-parts))))
  (define relative-parts
    (filter (lambda (part) (not (string=? part "")))
            (string-split relative-path "/")))
  (define parts (collapse-parts (append base-dir relative-parts)))
  (define last-part (car (reverse parts)))
  (define last-no-suffix
    (if (string-suffix? last-part ".rkt")
        (substring last-part 0 (- (string-length last-part) 4))
        last-part))
  (string->symbol
   (string-join (append (reverse (cdr (reverse parts)))
                        (list last-no-suffix))
                "/")))

;; mpi-index->dependency-name : vector? exact-nonnegative-integer? symbol? -> (or/c symbol? #f)
;;   Resolve a module-path index from compiled metadata when the shape is simple.
(define (mpi-index->dependency-name mpi-vector idx self-name)
  (define resolving (make-hasheqv))
  (define resolved  (make-hasheqv))
  (define (resolve-index idx)
    (cond
      [(hash-has-key? resolved idx) (hash-ref resolved idx)]
      [(hash-has-key? resolving idx) #f]
      [(and (vector? mpi-vector)
            (< idx (vector-length mpi-vector)))
       (hash-set! resolving idx #t)
       (define name (resolve (vector-ref mpi-vector idx)))
       (hash-remove! resolving idx)
       (hash-set! resolved idx name)
       name]
      [else #f]))
  (define (resolve mpi)
    (cond
      [(and (box? mpi) (symbol? (unbox mpi))) self-name]
      [(and (vector? mpi)
            (= (vector-length mpi) 2)
            (string? (vector-ref mpi 0))
            (exact-nonnegative-integer? (vector-ref mpi 1)))
       (define parent-idx (vector-ref mpi 1))
       (define parent-name
         (and (not (eqv? parent-idx idx))
              (resolve-index parent-idx)))
       (relative-module-name (or parent-name self-name) (vector-ref mpi 0))]
      [(symbol? mpi) mpi]
      [else (module-path-index->dependency-name mpi)]))
  (and (vector? mpi-vector)
       (< idx (vector-length mpi-vector))
       (resolve-index idx)))

;; phase-to-link-modules-candidates : any/c any/c symbol? -> (listof (list/c exact-integer? symbol?))
;;   Decode simple phase-to-link-modules expressions into candidate dependencies.
(define (phase-to-link-modules-candidates expr mpi-vector self-name)
  (define (mpi-ref idx)
    (and (exact-nonnegative-integer? idx)
         (or (and (vector? mpi-vector)
                  (< idx (vector-length mpi-vector))
                  (or (module-path-index->dependency-name (vector-ref mpi-vector idx))
                      (mpi-index->dependency-name mpi-vector idx self-name)))
             #f)))
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

;; data-module-path-index-candidates : any/c symbol? -> (listof (list/c 0 symbol?))
;;   Fall back to phase-0 provider candidates from all simple serialized MPIs.
(define (data-module-path-index-candidates mpi-vector self-name)
  (define (candidate? name)
    (and name
         (not (eq? name self-name))
         (not (memq name '(racket/base racket/private/base #%unsafe)))))
  (cond
    [(not (vector? mpi-vector)) '()]
    [else
     (remove-duplicates
      (filter
       values
       (for/list ([idx (in-range (vector-length mpi-vector))])
         (define name (mpi-index->dependency-name mpi-vector idx self-name))
         (and (candidate? name) (list 0 name)))))]))

;; generated-import-name? : symbol? -> boolean?
;;   Heuristically recognize generated internal import names in decompiled linklets.
(define (generated-import-name? name)
  (regexp-match? #rx"[.][0-9]+$" (symbol->string name)))

;; symbolic-name=? : symbol? symbol? -> boolean?
;;   Match generated symbols that print the same but are not necessarily eq?.
(define (symbolic-name=? a b)
  (or (eq? a b)
      (string=? (symbol->string a) (symbol->string b))))

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

;; import-group->require-rename-aliases : import-group rename-specs -> aliases
;;   Use compiled provide metadata to connect local imports to provider exports.
(define (import-group->require-rename-aliases group compiled-rename-specs)
  (for*/list ([binding (in-list group)]
              #:do [(match-define (list local external) binding)]
              [rename-spec (in-list compiled-rename-specs)]
              #:do [(match-define (list local-name maybe-dependency provider-export) rename-spec)]
              #:when (symbolic-name=? external local-name))
    (if maybe-dependency
        (list local maybe-dependency provider-export)
        (list local provider-export))))

;; flatten-datum : any/c -> list?
;;   Flatten a datum/vector tree in source order for simple serialized metadata scans.
(define (flatten-datum v)
  (cond
    [(pair? v)   (append (flatten-datum (car v))
                         (flatten-datum (cdr v)))]
    [(vector? v) (append* (map flatten-datum (vector->list v)))]
    [(null? v)   '()]
    [else        (list v)]))

;; compiled-module-binding-rename-specs : any/c (or/c vector? #f) symbol? -> (listof list?)
;;   Decode provider-export aliases from serialized `provides` module-binding records.
(define (compiled-module-binding-rename-specs provides-expr mpi-vector self-name)
  (define flat (flatten-datum provides-expr))
  (define (first-mpi-index rest)
    (match rest
      [(list* (? keyword? kw) (? exact-nonnegative-integer? idx) more)
       (if (eq? kw '#:mpi)
           idx
           (first-mpi-index more))]
      [(cons _ more) (first-mpi-index more)]
      [_ #f]))
  (define (provider-export-after-module-binding rest)
    (match rest
      [(list* (? symbol? provider-export)
              (? exact-integer?)
              #f
              #f
              _)
       provider-export]
      [(cons _ more) (provider-export-after-module-binding more)]
      [_ #f]))
  (let loop ([items flat]
             [specs '()])
    (match items
      ['() (reverse specs)]
      [(list* (? symbol? local-name) '#:module-binding rest)
       (define provider-export (provider-export-after-module-binding rest))
       (define dependency
         (let ([idx (first-mpi-index rest)])
           (and idx (mpi-index->dependency-name mpi-vector idx self-name))))
       (loop rest
             (if (and provider-export
                      (not (symbolic-name=? local-name provider-export)))
                 (cons (list local-name dependency provider-export) specs)
                 specs))]
      [(cons _ more) (loop more specs)])))

;; compiled-provides-provider-aliases : any/c any/c symbol? symbol? -> aliases
;;   Decode backing providers for a public name from serialized provide metadata.
(define (compiled-provides-provider-aliases provides-expr mpi-vector self-name exported-name)
  (define flat (flatten-datum provides-expr))
  (define (binding-provider rest)
    (match rest
      [(list* (or '#:simple-module-binding '#:module-binding)
              '#:mpi
              (? exact-nonnegative-integer? idx)
              (? symbol? provider-export)
              _)
       (define dependency (mpi-index->dependency-name mpi-vector idx self-name))
       (and dependency (list dependency provider-export))]
      [(cons _ more) (binding-provider more)]
      [_ #f]))
  (let loop ([items flat]
             [aliases '()])
    (match items
      ['() (reverse aliases)]
      [(list* (? symbol? local-name) rest)
       (define alias (and (symbolic-name=? local-name exported-name)
                          (binding-provider rest)))
       (loop rest (if alias (cons alias aliases) aliases))]
      [(cons _ more) (loop more aliases)])))

;; resolve-compiled-rename-aliases : aliases dependency-exports -> aliases
;;   Fill provider modules for compiled rename aliases using provider export rows.
(define (resolve-compiled-rename-aliases aliases dependency-exports)
  (filter
   values
   (for/list ([alias (in-list aliases)])
    (define local (car alias))
    (define provider-export
      (match alias
        [(list _ export) export]
        [(list _ _ export) export]))
    (define maybe-direct-dependency
      (match alias
        [(list _ (? symbol? dependency) _) dependency]
        [_ #f]))
    (define matches
      (cond
        [maybe-direct-dependency
         (match (assoc maybe-direct-dependency dependency-exports)
           [(list dependency exports)
            (if (for/or ([export (in-list exports)])
                  (symbolic-name=? export provider-export))
                (list (list dependency provider-export))
                '())]
           [_ '()])]
        [else
         (for/list ([entry (in-list dependency-exports)]
                    #:do [(match-define (list dependency exports) entry)]
                    #:when (for/or ([export (in-list exports)])
                             (symbolic-name=? export provider-export)))
           (list dependency provider-export))]))
    (match matches
      [(list (list dependency provider-export))
       (list local dependency provider-export)]
      [_ #f]))))

;; import-groups->provider-coverage-aliases : import-groups candidates dependency-exports imports -> aliases
;;   Resolve a whole import group when exactly one required provider exports every name in the group.
(define (import-groups->provider-coverage-aliases groups
                                                  required-module-candidates
                                                  dependency-exports
                                                  explicit-locals)
  (define phase0-modules
    (remove-duplicates
     (for/list ([candidate (in-list required-module-candidates)]
                #:when (= 0 (car candidate)))
       (cadr candidate))
     eq?))
  (define (dependency-exports-external? dependency external)
    (define row (assoc dependency dependency-exports))
    (and row
         (for/or ([export (in-list (cadr row))])
           (symbolic-name=? export external))))
  (append*
   (for/list ([group (in-list groups)])
     (define unresolved-bindings
       (filter (lambda (binding) (not (memq (car binding) explicit-locals)))
               group))
     (cond
       [(null? unresolved-bindings) '()]
       [else
        (define covering-modules
          (for/list ([module (in-list phase0-modules)]
                     #:when (for/and ([binding (in-list unresolved-bindings)])
                              (match-define (list _local external) binding)
                              (dependency-exports-external? module external)))
            module))
        (match covering-modules
          [(list module)
           (for/list ([binding (in-list unresolved-bindings)])
             (match-define (list local external) binding)
             (list local module external))]
          [_ '()])]))))

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
  (define data-entry (maybe-module-bundle-entry-ref report 'data))
  (define decl-entry (maybe-module-bundle-entry-ref report 'decl))
  (define data-linklet (and data-entry (webify-module-bundle-entry-datum data-entry)))
  (define decl-linklet (and decl-entry (webify-module-bundle-entry-datum decl-entry)))
  (define data-module-path-indexes (data-linklet-module-path-indexes data-linklet))
  (define decl-requires-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'requires)))
  (define decl-provides-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'provides)))
  (define decl-phase-to-link-modules-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'phase-to-link-modules)))
  (define required-module-candidates
    (remove-duplicates
     (append
      (phase-to-link-modules-candidates
       decl-phase-to-link-modules-expression
       data-module-path-indexes
       (webify-module-extractor-spike-name report))
      (data-module-path-index-candidates
       data-module-path-indexes
       (webify-module-extractor-spike-name report)))))
  (define compiled-rename-specs
    (compiled-module-binding-rename-specs
     decl-provides-expression
     data-module-path-indexes
     (webify-module-extractor-spike-name report)))
  (define require-rename-aliases
    (apply append
           (for/list ([group (in-list unresolved-groups)])
             (import-group->require-rename-aliases group compiled-rename-specs))))
  (define alias-results
    (for/list ([group (in-list unresolved-groups)])
      (define require-aliases
        (import-group->require-rename-aliases group compiled-rename-specs))
      (cons group
            (and (null? require-aliases)
                 (import-group->aliases group required-module-candidates)))))
  (define import-aliases
    (apply append
           (for/list ([result (in-list alias-results)]
                      #:when (cdr result))
             (cdr result))))
  (define missing-alias-import-groups
    (for/list ([result (in-list alias-results)]
               #:do [(define group (car result))]
               #:when (and (import-group-needs-alias-evidence? group)
                           (not (cdr result))
                           (null? (import-group->require-rename-aliases
                                   group
                                   compiled-rename-specs))))
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
   require-rename-aliases
   missing-alias-import-groups
   (cond
     [(pair? require-rename-aliases)
      '("compiled provide metadata supplies provider export aliases"
        "export tables are still required before resolving imports")]
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

;; webify-module-extractor-spike-required-provider-names : report -> (listof symbol?)
;;   Return phase-0 provider module names decoded from the report's require metadata.
(define (webify-module-extractor-spike-required-provider-names report)
  (define who 'webify-module-extractor-spike-required-provider-names)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (define import-map (webify-module-extractor-spike-import-map report))
  (remove-duplicates
   (append
    (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates
                                    import-map))]
               #:when (= 0 (car candidate)))
      (cadr candidate))
    '())))

;; webify-module-extractor-spike->required-provider-spikes : report -> (listof report)
;;   Compile one-level installed provider reports named by the report's require metadata.
(define (webify-module-extractor-spike->required-provider-spikes report)
  (for/list ([name (in-list (webify-module-extractor-spike-required-provider-names report))])
    (webify-module-path->extractor-spike name)))

;; make-webify-module-provider-cache : [procedure?] -> webify-module-provider-cache?
;;   Create a reusable installed-provider report cache.
(define (make-webify-module-provider-cache [fetch-provider webify-module-path->extractor-spike])
  (unless (procedure? fetch-provider)
    (raise-argument-error 'make-webify-module-provider-cache "procedure?" fetch-provider))
  (webify-module-provider-cache fetch-provider (make-hasheq) (box 0) (box 0)))

;; webify-module-provider-cache-ref : webify-module-provider-cache? symbol? -> report
;;   Fetch and cache an installed-provider report by module name.
(define (webify-module-provider-cache-ref cache name)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-ref
                          "webify-module-provider-cache?"
                          cache))
  (unless (symbol? name)
    (raise-argument-error 'webify-module-provider-cache-ref "symbol?" name))
  (define table (webify-module-provider-cache-table cache))
  (cond
    [(hash-has-key? table name)
     (set-box! (webify-module-provider-cache-hits cache)
               (add1 (unbox (webify-module-provider-cache-hits cache))))
     (hash-ref table name)]
    [else
     (set-box! (webify-module-provider-cache-misses cache)
               (add1 (unbox (webify-module-provider-cache-misses cache))))
     (define report ((webify-module-provider-cache-fetch-provider cache) name))
     (unless (webify-module-extractor-spike? report)
       (raise-arguments-error 'webify-module-provider-cache-ref
                              "provider fetcher did not return an extractor report"
                              "module" name
                              "result" report))
     (unless (eq? name (webify-module-extractor-spike-name report))
       (raise-arguments-error 'webify-module-provider-cache-ref
                              "provider report name does not match requested module"
                              "module" name
                              "report name" (webify-module-extractor-spike-name report)))
     (hash-set! table name report)
     report]))

;; webify-module-provider-cache-hit-count : webify-module-provider-cache? -> exact-nonnegative-integer?
;;   Return the number of provider-cache hits.
(define (webify-module-provider-cache-hit-count cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-hit-count
                          "webify-module-provider-cache?"
                          cache))
  (unbox (webify-module-provider-cache-hits cache)))

;; webify-module-provider-cache-miss-count : webify-module-provider-cache? -> exact-nonnegative-integer?
;;   Return the number of provider-cache misses.
(define (webify-module-provider-cache-miss-count cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-miss-count
                          "webify-module-provider-cache?"
                          cache))
  (unbox (webify-module-provider-cache-misses cache)))

;; webify-module-provider-cache-names : webify-module-provider-cache? -> (listof symbol?)
;;   Return cached module names.
(define (webify-module-provider-cache-names cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-names
                          "webify-module-provider-cache?"
                          cache))
  (sort (hash-keys (webify-module-provider-cache-table cache)) symbol<?))

;; webify-module-provider-cache-count : webify-module-provider-cache? -> exact-nonnegative-integer?
;;   Return the number of cached provider reports.
(define (webify-module-provider-cache-count cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-count
                          "webify-module-provider-cache?"
                          cache))
  (hash-count (webify-module-provider-cache-table cache)))

;; merge-export-demands : (listof webify-module-export-demand?) -> demands
;;   Combine demand rows for the same provider module.
(define (merge-export-demands demands)
  (define table (make-hasheq))
  (for ([demand (in-list demands)])
    (unless (webify-module-export-demand? demand)
      (raise-argument-error 'merge-export-demands
                            "webify-module-export-demand?"
                            demand))
    (hash-update! table
                  (webify-module-export-demand-module demand)
                  (lambda (exports)
                    (remove-duplicates
                     (append exports
                             (webify-module-export-demand-exports demand))))
                  '()))
  (for/list ([module (in-list (sort (hash-keys table) symbol<?))])
    (webify-module-export-demand module (hash-ref table module))))

;; webify-module-extractor-spike-import-export-demands : report reports ... -> demands
;;   Report the provider exports imported by a resolved linklet input.
(define (webify-module-extractor-spike-import-export-demands report
                                                            provider-reports
                                                            #:dependencies [dependencies '()]
                                                            #:module-protocol-dependency [module-protocol-dependency #f])
  (define input
    (webify-module-extractor-spike->resolved-linklet-input/providers
     report
     provider-reports
     #:dependencies dependencies
     #:module-protocol-dependency module-protocol-dependency))
  (merge-export-demands
   (for/list ([import (in-list (webify-module-linklet-input-imports input))])
     (match-define (list _local dependency provider-export) import)
     (webify-module-export-demand dependency (list provider-export)))))

;; webify-module-extractor-spike-import-export-demand-reasons : report reports ... -> reasons
;;   Explain which imports retain provider exports for demand slicing.
(define (webify-module-extractor-spike-import-export-demand-reasons report
                                                                    provider-reports
                                                                    #:dependencies [dependencies '()]
                                                                    #:module-protocol-dependency [module-protocol-dependency #f])
  (define input
    (webify-module-extractor-spike->resolved-linklet-input/providers
     report
     provider-reports
     #:dependencies dependencies
     #:module-protocol-dependency module-protocol-dependency))
  (for/list ([import (in-list (webify-module-linklet-input-imports input))])
    (match-define (list local dependency provider-export) import)
    (webify-module-export-demand-reason
     dependency
     provider-export
     (webify-module-extractor-spike-name report)
     local
     local)))

;; remove-bound : (listof symbol?) (listof symbol?) -> (listof symbol?)
;;   Remove locally bound identifiers from a free-variable list.
(define (remove-bound free bound)
  (filter (lambda (id) (not (memq id bound))) free))

;; linklet-expr-free-vars : any/c -> (listof symbol?)
;;   Approximate free variables well enough to slice first-order linklet definitions.
(define (linklet-expr-free-vars expr)
  (define (free expr bound)
    (cond
      [(symbol? expr)
       (if (memq expr bound) '() (list expr))]
      [(or (null? expr) (not (pair? expr))) '()]
      [else
       (match expr
         [`(quote ,_) '()]
         [`(quote-syntax ,_) '()]
         [`(lambda ,formals . ,body)
          (define formal-ids
            (let loop ([formals formals])
              (cond
                [(symbol? formals) (list formals)]
                [(pair? formals)   (cons (car formals) (loop (cdr formals)))]
                [else              '()])))
          (remove-duplicates
           (append* (for/list ([body-expr (in-list body)])
                      (free body-expr (append formal-ids bound)))))]
         [`(case-lambda [,formalss . ,bodiess] ...)
          (remove-duplicates
           (append*
            (for/list ([formals (in-list formalss)]
                       [body    (in-list bodiess)])
              (define formal-ids
                (let loop ([formals formals])
                  (cond
                    [(symbol? formals) (list formals)]
                    [(pair? formals)   (cons (car formals) (loop (cdr formals)))]
                    [else              '()])))
              (append* (for/list ([body-expr (in-list body)])
                         (free body-expr (append formal-ids bound)))))))]
         [`(let-values ,clauses . ,body)
          (define ids
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,ids ...) ,_) ids]
                 [_ '()]))))
          (remove-duplicates
           (append
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,_ids ...) ,rhs) (free rhs bound)]
                 [_ '()])))
            (append*
             (for/list ([body-expr (in-list body)])
               (free body-expr (append ids bound))))))]
         [`(letrec-values ,clauses . ,body)
          (define ids
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,ids ...) ,_) ids]
                 [_ '()]))))
          (define next-bound (append ids bound))
          (remove-duplicates
           (append
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,_ids ...) ,rhs) (free rhs next-bound)]
                 [_ '()])))
            (append*
             (for/list ([body-expr (in-list body)])
               (free body-expr next-bound)))))]
         [_ (remove-duplicates (append* (map (lambda (part) (free part bound)) expr)))])]))
  (free expr '()))

;; linklet-definition : form -> values
;;   Extract the ids and right-hand side from a define-values form.
(define (linklet-definition form)
  (match form
    [`(define-values (,ids ...) ,rhs)
     (values ids rhs)]
    [_ (values #f #f)]))

;; filter-importss : importss (listof symbol?) -> importss
;;   Keep only raw import bindings whose normalized local name is demanded.
(define (filter-importss importss demanded-imports)
  (filter
   pair?
   (for/list ([group (in-list importss)])
     (filter (lambda (binding)
               (match-define (list local _external)
                 (normalize-linklet-import-binding 'filter-importss binding))
               (memq local demanded-imports))
             group))))

;; webify-module-extractor-spike/slice-exports : report (listof symbol?) -> report
;;   Produce a demand-sliced report containing only needed exports/imports/definitions.
(define (webify-module-extractor-spike/slice-exports report demanded-exports)
  (define who 'webify-module-extractor-spike/slice-exports)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (unless (and (list? demanded-exports) (andmap symbol? demanded-exports))
    (raise-argument-error who "(listof symbol?)" demanded-exports))
  (define raw-linklet (webify-module-extractor-spike-phase0-linklet-datum report))
  (define linklet (webify-normalize-linklet-imports raw-linklet))
  (match-define `(linklet ,raw-importss ,raw-exports . ,_raw-body) raw-linklet)
  (match-define `(linklet ,importss ,_exports . ,body) linklet)
  (define export-descriptors (linklet-export-descriptors who raw-exports))
  (define (demanded-export-descriptor demanded-export)
    (for/first ([descriptor (in-list export-descriptors)]
                #:when (symbolic-name=? (cadr descriptor) demanded-export))
      descriptor))
  (define demanded-export-descriptors
    (for/list ([export (in-list demanded-exports)])
      (define descriptor (demanded-export-descriptor export))
      (unless descriptor
        (raise-arguments-error who
                               "demanded export is not provided by report"
                               "module" (webify-module-extractor-spike-name report)
                               "export" export))
      descriptor))
  (define initializer-forms
    (filter (lambda (form)
              (define-values (ids _rhs) (linklet-definition form))
              (not ids))
            body))
  ;; Linklet initializer forms always run, so their free variables must seed
  ;; the slice just like demanded exports. Otherwise an initializer can survive
  ;; while its imports or helper definitions are removed.
  (define initializer-needed
    (remove-duplicates
     (append*
      (for/list ([form (in-list initializer-forms)])
        (linklet-expr-free-vars form)))))
  (define definition-table (make-hasheq))
  (for ([form (in-list body)])
    (define-values (ids rhs) (linklet-definition form))
    (when ids
      (for ([id (in-list ids)])
        (hash-set! definition-table id (list ids rhs form)))))
  (define needed
    (remove-duplicates
     (append
      (for/list ([descriptor (in-list demanded-export-descriptors)])
        (car descriptor))
      initializer-needed)))
  (let loop ([queue needed])
    (cond
      [(null? queue) (void)]
      [else
       (define id (car queue))
       (define definition (hash-ref definition-table id #f))
       (cond
         [(not definition) (loop (cdr queue))]
         [else
          (match-define (list ids rhs _form) definition)
          (define discovered
            (filter (lambda (free-id) (not (memq free-id needed)))
                    (linklet-expr-free-vars rhs)))
          (set! needed (remove-duplicates (append needed ids discovered)))
          (loop (append (cdr queue) discovered))])]))
  (define kept-body
    (for/list ([form (in-list body)]
               #:do [(define-values (ids _rhs) (linklet-definition form))]
               #:when (or (not ids)
                          (for/or ([id (in-list ids)])
                            (memq id needed))))
      form))
  (define local-definitions
    (filter (lambda (id) (hash-has-key? definition-table id)) needed))
  (define demanded-imports
    (filter (lambda (id) (not (memq id local-definitions))) needed))
  (define sliced-importss (filter-importss raw-importss demanded-imports))
  (define sliced-exports
    (remove-duplicates
     (for/list ([descriptor (in-list demanded-export-descriptors)])
       (caddr descriptor))))
  (define sliced-external-exports
    (webify-normalize-linklet-exports sliced-exports))
  (define sliced-linklet
    `(linklet ,sliced-importss ,sliced-exports . ,kept-body))
  (define phase0-entry
    (webify-module-bundle-entry
     0
     'linklet
     sliced-importss
     sliced-external-exports
     sliced-linklet
     #f))
  (define sliced-bundle-entries
    (cons phase0-entry
          (filter (lambda (entry)
                    (not (equal? 0 (webify-module-bundle-entry-key entry))))
                  (webify-module-extractor-spike-bundle-entries report))))
  (webify-module-extractor-spike
   (webify-module-extractor-spike-name report)
   (webify-module-extractor-spike-directory-keys report)
   (webify-module-extractor-spike-bundle-keys report)
   sliced-bundle-entries
   sliced-importss
   demanded-exports
   sliced-linklet
   #t
   (cons "report was sliced to demanded phase-0 exports"
         (webify-module-extractor-spike-notes report))))

;; webify-module-extractor-spikes->required-provider-closure : reports ... -> (listof report)
;;   Discover transitive provider reports starting from root reports.
(define (webify-module-extractor-spikes->required-provider-closure
         reports
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-unfetchable? [skip-unfetchable? #t]
         #:trace-box [trace-box #f]
         #:frontier-limit [frontier-limit #f])
  (define who 'webify-module-extractor-spikes->required-provider-closure)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (unless (procedure? fetch-provider)
    (raise-argument-error who "procedure?" fetch-provider))
  (unless (boolean? skip-unfetchable?)
    (raise-argument-error who "boolean?" skip-unfetchable?))
  (unless (or (not trace-box) (box? trace-box))
    (raise-argument-error who "(or/c #f box?)" trace-box))
  (unless (or (not frontier-limit) (exact-positive-integer? frontier-limit))
    (raise-argument-error who "(or/c #f exact-positive-integer?)" frontier-limit))
  (for ([report (in-list reports)])
    (unless (webify-module-extractor-spike? report)
      (raise-argument-error who "webify-module-extractor-spike?" report)))
  (define reports-by-name (make-hasheq))
  (define depths-by-name (make-hasheq))
  (define ordered '())
  (define (trace! provider demander depth cached? reason elapsed-ms status)
    (when trace-box
      (set-box!
       trace-box
       (append
        (unbox trace-box)
        (list (webify-module-provider-discovery-trace-event
               provider demander depth cached? reason elapsed-ms status))))))
  (define (check-frontier! reason)
    (when (and frontier-limit (> (hash-count reports-by-name) frontier-limit))
      (raise-arguments-error
       who
       "provider discovery frontier limit reached"
       "limit" frontier-limit
       "reason" reason
       "frontier" (map webify-module-extractor-spike-name ordered))))
  (define (record! report)
    (define name (webify-module-extractor-spike-name report))
    (cond
      [(hash-has-key? reports-by-name name) #f]
      [else
       (hash-set! reports-by-name name report)
       (set! ordered (append ordered (list report)))
       (check-frontier! name)
       #t]))
  (for ([report (in-list reports)])
    (when (record! report)
      (hash-set! depths-by-name
                 (webify-module-extractor-spike-name report)
                 0)))
  (let loop ([queue reports])
    (cond
      [(null? queue) ordered]
      [else
       (define report (car queue))
       (define demander (webify-module-extractor-spike-name report))
       (define demander-depth (hash-ref depths-by-name demander 0))
       (define import-map (webify-module-extractor-spike-import-map report))
       (define new-reports '())
       (define (fetch-report name reason)
         (define cached-report (hash-ref reports-by-name name #f))
         (cond
           [cached-report
            (trace! name demander (hash-ref depths-by-name name demander-depth) #t reason 0 'cached)
            cached-report]
           [else
            (define start-ms (current-inexact-milliseconds))
            (define provider-report
              (with-handlers ([exn:fail?
                               (lambda (exn)
                                 (trace! name demander (add1 demander-depth) #f reason
                                         (- (current-inexact-milliseconds) start-ms)
                                         'failed)
                                 (if skip-unfetchable? #f (raise exn)))])
                (fetch-provider name)))
            (cond
              [(not provider-report)
               (trace! name demander (add1 demander-depth) #f reason
                       (- (current-inexact-milliseconds) start-ms)
                       'skipped)
               #f]
              [else
               (unless (webify-module-extractor-spike? provider-report)
                 (raise-arguments-error who
                                        "provider fetcher did not return an extractor report"
                                        "module" name
                                        "result" provider-report))
               (unless (eq? name (webify-module-extractor-spike-name provider-report))
                 (raise-arguments-error who
                                        "provider report name does not match requested module"
                                        "module" name
                                        "report name" (webify-module-extractor-spike-name provider-report)))
               (hash-set! depths-by-name name (add1 demander-depth))
               (trace! name demander (add1 demander-depth) #f reason
                       (- (current-inexact-milliseconds) start-ms)
                       'fetched)
               (when (record! provider-report)
                 (set! new-reports (append new-reports (list provider-report))))
               provider-report])]))
       (for ([name (in-list (webify-module-extractor-spike-required-provider-names report))])
         (fetch-report name 'required-provider))
       (for* ([group (in-list (webify-module-import-map-unresolved-import-groups import-map))]
              [binding (in-list group)])
         (match-define (list _local external) binding)
         (define candidate-reports
           (filter
            values
            (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates import-map))]
                       #:when (= 0 (car candidate)))
              (fetch-report (cadr candidate) 'unresolved-import-candidate))))
         (define directly-exported?
           (for/or ([candidate-report (in-list candidate-reports)])
             (for/or ([export (in-list (webify-module-extractor-spike-phase0-exports
                                        candidate-report))])
               (symbolic-name=? export external))))
         (unless directly-exported?
           (for ([candidate-report (in-list candidate-reports)])
             (for ([alias (in-list
                           (compiled-provides-provider-aliases
                            (webify-module-import-map-decl-provides-expression
                             (webify-module-extractor-spike-import-map candidate-report))
                            (webify-module-import-map-data-module-path-indexes
                             (webify-module-extractor-spike-import-map candidate-report))
                            (webify-module-extractor-spike-name candidate-report)
                            external))])
               (match-define (list dependency _provider-export) alias)
               (fetch-report dependency 'compiled-provide-alias)))))
       (loop (append (cdr queue) new-reports))])))

;; webify-module-extractor-spikes->discovered-resolved-linklet-inputs : reports ... -> inputs
;;   Discover provider closure, then resolve the resulting graph into bridge inputs.
(define (demand-slice-discovered-reports root-reports
                                         extra-reports
                                         discovered-reports
                                         dependencies
                                         module-protocol-dependency)
  (define root/extra-names
    (for/hasheq ([report (in-list (append root-reports extra-reports))])
      (values (webify-module-extractor-spike-name report) #t)))
  (define reports-by-name
    (for/hasheq ([report (in-list discovered-reports)])
      (values (webify-module-extractor-spike-name report) report)))
  (define final-by-name (make-hasheq))
  (for ([report (in-list (append extra-reports root-reports))])
    (hash-set! final-by-name (webify-module-extractor-spike-name report) report))
  (define (final-reports)
    (filter values
            (for/list ([report (in-list discovered-reports)])
              (hash-ref final-by-name
                        (webify-module-extractor-spike-name report)
                        #f))))
  (define (ordered-final-reports)
    (define final-table
      (for/hasheq ([report (in-list (final-reports))])
        (values (webify-module-extractor-spike-name report) report)))
    (define planned '())
    (define permanent (hasheq))
    (define temporary (hasheq))
    (define (visit report)
      (define name (webify-module-extractor-spike-name report))
      (cond
        [(hash-has-key? permanent name) (void)]
        [(hash-has-key? temporary name)
         ;; The Racket module require graph should be acyclic. If metadata
         ;; disagrees, keep discovery order instead of failing the extractor.
         (void)]
        [else
         (set! temporary (hash-set temporary name #t))
         (for ([module (in-list (runtime-required-modules report))])
           (define dependency (hash-ref final-table module #f))
           (when dependency
             (visit dependency)))
         (set! temporary (hash-remove temporary name))
         (set! permanent (hash-set permanent name #t))
         (set! planned (cons report planned))]))
    (for ([report (in-list (final-reports))])
      (visit report))
    (reverse planned))
  (define (runtime-required-modules report)
    (define self-name (webify-module-extractor-spike-name report))
    (remove-duplicates
     (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates
                                     (webify-module-extractor-spike-import-map report)))]
                #:when (and (= 0 (car candidate))
                            (not (eq? (cadr candidate) self-name))
                            (hash-has-key? reports-by-name (cadr candidate))))
       (cadr candidate))
     eq?))
  (define demanded (make-hasheq))
  (define (new-exports module exports)
    (define old (hash-ref demanded module '()))
    (filter (lambda (export) (not (memq export old))) exports))
  (define (record-demand! demand)
    (define module (webify-module-export-demand-module demand))
    (define exports (webify-module-export-demand-exports demand))
    (define fresh (new-exports module exports))
    (cond
      [(null? fresh) #f]
      [else
       (hash-set! demanded module (remove-duplicates (append (hash-ref demanded module '()) fresh)))
       (webify-module-export-demand module fresh)]))
  (define initial-demands
    (append*
     (for/list ([report (in-list root-reports)])
       (webify-module-extractor-spike-import-export-demands
        report
        discovered-reports
        #:dependencies dependencies
        #:module-protocol-dependency module-protocol-dependency))))
  (define (process-export-demands! demands)
    (let loop ([queue (filter values (map record-demand! demands))])
      (unless (null? queue)
        (define demand (car queue))
        (define module (webify-module-export-demand-module demand))
        (define report (hash-ref reports-by-name module #f))
        (define next-demands '())
        (when (and report (not (hash-ref root/extra-names module #f)))
          (define sliced
            (webify-module-extractor-spike/slice-exports
             report
             (hash-ref demanded module)))
          (hash-set! final-by-name module sliced)
          (set! next-demands
                (webify-module-extractor-spike-import-export-demands
                 sliced
                 discovered-reports
                 #:dependencies dependencies
                 #:module-protocol-dependency module-protocol-dependency)))
        (loop (append (cdr queue)
                      (filter values (map record-demand! next-demands)))))))
  (define (process-init-closure!)
    (let loop ()
      (define changed? #f)
      (define next-demands '())
      (for ([report (in-list (final-reports))])
        (for ([module (in-list (runtime-required-modules report))])
          (unless (hash-has-key? final-by-name module)
            (define provider-report (hash-ref reports-by-name module #f))
            (when provider-report
              (define sliced
                (webify-module-extractor-spike/slice-exports provider-report '()))
              (hash-set! final-by-name module sliced)
              (set! changed? #t)
              (set! next-demands
                    (append
                     (webify-module-extractor-spike-import-export-demands
                      sliced
                      discovered-reports
                      #:dependencies dependencies
                      #:module-protocol-dependency module-protocol-dependency)
                     next-demands))))))
      (when (pair? next-demands)
        (process-export-demands! next-demands))
      (when (or changed? (pair? next-demands))
        (loop))))
  (process-export-demands! initial-demands)
  (process-init-closure!)
  (ordered-final-reports))

(define (webify-module-extractor-spikes->discovered-resolved-linklet-inputs
         reports
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-unfetchable? [skip-unfetchable? #t]
         #:trace-box [trace-box #f]
         #:frontier-limit [frontier-limit #f]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:demand-slice? [demand-slice? #f])
  (define who 'webify-module-extractor-spikes->discovered-resolved-linklet-inputs)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (unless (list? extra-reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" extra-reports))
  (define discovered-reports
    (webify-module-extractor-spikes->required-provider-closure
     (append extra-reports reports)
     #:fetch-provider fetch-provider
     #:skip-unfetchable? skip-unfetchable?
     #:trace-box trace-box
     #:frontier-limit frontier-limit))
  (define resolved-reports
    (if demand-slice?
        (demand-slice-discovered-reports reports
                                         extra-reports
                                         discovered-reports
                                         dependencies
                                         module-protocol-dependency)
        discovered-reports))
  (webify-module-extractor-spikes->resolved-linklet-inputs
   resolved-reports
   #:dependencies dependencies
   #:module-protocol-dependency module-protocol-dependency))

;; webify-module-provider-discovery-run-stages : reports ... -> stages?
;;   Run provider discovery as split stages for diagnostics.
(define (webify-module-provider-discovery-run-stages
         reports
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-unfetchable? [skip-unfetchable? #t]
         #:trace-box [trace-box #f]
         #:frontier-limit [frontier-limit #f]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:demand-slice? [demand-slice? #f])
  (define timings '())
  (define (timed label thunk)
    (define start-ms (current-inexact-milliseconds))
    (define result (thunk))
    (set! timings
          (append timings
                  (list (cons label
                              (- (current-inexact-milliseconds) start-ms)))))
    result)
  (define discovered-reports
    (timed
     'fetch-provider-closure
     (lambda ()
       (webify-module-extractor-spikes->required-provider-closure
        (append extra-reports reports)
        #:fetch-provider fetch-provider
        #:skip-unfetchable? skip-unfetchable?
        #:trace-box trace-box
        #:frontier-limit frontier-limit))))
  (define resolved-reports
    (timed
     'demand-slice
     (lambda ()
       (if demand-slice?
           (demand-slice-discovered-reports reports
                                            extra-reports
                                            discovered-reports
                                            dependencies
                                            module-protocol-dependency)
           discovered-reports))))
  (define inputs
    (timed
     'resolve-inputs
     (lambda ()
       (webify-module-extractor-spikes->resolved-linklet-inputs
        resolved-reports
        #:dependencies dependencies
        #:module-protocol-dependency module-protocol-dependency))))
  (make-webify-module-provider-discovery-stages
   discovered-reports
   resolved-reports
   inputs
   timings))

;; resolve-extracted-linklet-imports : symbol? linklet-datum ... -> imports
;;   Classify extracted imports and turn supported ones into flat bridge triples.
(define (resolve-extracted-linklet-imports who
                                           linklet
                                           dependency-exports
                                           preferred-dependency-exports
                                           dependencies
                                           import-aliases
                                           require-rename-aliases
                                           required-module-candidates
                                           module-protocol-dependency
                                           reflection-hints
                                           module-name)
  (when module-protocol-dependency
    (unless (symbol? module-protocol-dependency)
      (raise-argument-error who "symbol?" module-protocol-dependency)))
  (define bindings (webify-linklet-import-bindings linklet))
  (define unresolved-groups
    (filter (lambda (group) (not (protocol-import-group? group)))
            (linklet-datum-import-groups linklet)))
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
       (define reflection-hint-locals
         (for/list ([hint (in-list reflection-hints)]
                    #:when (match hint
                             [(list (? symbol?) (? symbol?) (? symbol?)) #t]
                             [(list importer _local _dependency _export)
                              (eq? importer module-name)]
                             [_ #f]))
           (match hint
             [(list local _dependency _export) local]
             [(list _importer local _dependency _export) local])))
       (define explicit-locals (map car dependencies))
       (define grouped-provider-aliases
         (import-groups->provider-coverage-aliases
          unresolved-groups
          required-module-candidates
          dependency-exports
          (append explicit-locals
                  reflection-hint-locals
                  (for/list ([alias (in-list (append import-aliases
                                                      (resolve-compiled-rename-aliases
                                                       require-rename-aliases
                                                       dependency-exports)))])
                    (car alias)))))
       (define explicit-or-alias-locals
         (append explicit-locals
                 reflection-hint-locals
                 (map car grouped-provider-aliases)
                 (for/list ([alias (in-list (append import-aliases
                                                     (resolve-compiled-rename-aliases
                                                      require-rename-aliases
                                                      dependency-exports)))]
                            #:do [(match-define (list local _dependency _export) alias)]
                            #:when (assoc local module-bindings))
                   local)))
       (define (dependency-exports-external? exports dependency external)
         (define candidate-exports (assoc dependency exports))
         (and candidate-exports
              (for/or ([export (in-list (cadr candidate-exports))])
                (symbolic-name=? export external))))
       (define (candidate->inferred-dependency binding)
         (match-define (list local external) binding)
         (define candidates
           (for/list ([candidate (in-list required-module-candidates)]
                      #:when (and (= 0 (car candidate))
                                  (dependency-exports-external?
                                   dependency-exports
                                   (cadr candidate)
                                   external)))
             candidate))
         (define preferred-candidates
           (filter (lambda (candidate)
                     (dependency-exports-external?
                      preferred-dependency-exports
                      (cadr candidate)
                      external))
                   candidates))
         (define (prefer-stream-cons candidates)
           (cond
             [(symbolic-name=? external 'stream?)
              (define stream-cons-candidates
                (filter (lambda (candidate)
                          (eq? (cadr candidate) 'racket/private/stream-cons))
                        candidates))
              (if (null? stream-cons-candidates) candidates stream-cons-candidates)]
             [else candidates]))
         (define ranked-candidates
           (prefer-stream-cons
            (if (null? preferred-candidates) candidates preferred-candidates)))
         (define (candidate-reason candidate)
           (list local
                 (cadr candidate)
                 (if (memq candidate preferred-candidates)
                     'provider-local-export
                     'metadata-export-candidate)
                 (if (assoc (cadr candidate) preferred-dependency-exports)
                     'reachable-provider
                     'discovered-candidate)))
         (cond
           [(null? ranked-candidates) #f]
           [(null? (cdr ranked-candidates))
            (list local (cadar ranked-candidates))]
           [else
            (raise-arguments-error who
                                   "ambiguous inferred import dependency"
                                   "importer" module-name
                                   "import" local
                                   "candidates"
                                   (for/list ([candidate (in-list ranked-candidates)])
                                     (list local (cadr candidate)))
                                   "candidate reasons"
                                   (map candidate-reason candidates))]))
       (define inferred-dependencies
         (filter
          values
          (for/list ([binding (in-list module-bindings)]
                     #:do [(match-define (list local _external) binding)]
                     #:unless (memq local explicit-or-alias-locals))
            (candidate->inferred-dependency binding))))
       (define duplicate-inferred (check-duplicates (map car inferred-dependencies)))
       (when duplicate-inferred
         (raise-arguments-error who
                                "ambiguous inferred import dependency"
                                "import" duplicate-inferred
                                "candidates" inferred-dependencies))
       (webify-resolve-module-linklet-imports
        `(linklet (,module-bindings) () (void))
        dependency-exports
        #:module-name module-name
        #:dependencies (append dependencies inferred-dependencies)
        #:reflection-hints reflection-hints
        #:import-aliases
        (append import-aliases
                grouped-provider-aliases
                (resolve-compiled-rename-aliases require-rename-aliases dependency-exports)))]))
  (define triples-by-import
    (for/hasheq ([triple (in-list (append module-protocol-triples module-triples))])
      (values (car triple) triple)))
  (for/list ([binding (in-list bindings)])
    (hash-ref triples-by-import (car binding))))

;; webify-module-extractor-spike-dependency-exports : report -> dependency-export-row
;;   Derive a resolver export row from the extracted provider's compiled phase-0 exports.
(define (webify-module-extractor-spike-dependency-exports report)
  (define who 'webify-module-extractor-spike-dependency-exports)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (list (webify-module-extractor-spike-name report)
        (webify-module-extractor-spike-phase0-exports report)))

;; webify-module-extractor-spikes-dependency-exports : (listof report) -> dependency-exports
;;   Derive a resolver export table from extracted provider reports.
(define (webify-module-extractor-spikes-dependency-exports reports)
  (define who 'webify-module-extractor-spikes-dependency-exports)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (define dependency-exports
    (for/list ([report (in-list reports)])
      (unless (webify-module-extractor-spike? report)
        (raise-argument-error who "webify-module-extractor-spike?" report))
      (webify-module-extractor-spike-dependency-exports report)))
  ;; Reuse the manifest-input validator to reject duplicate provider names.
  (webify-module-linklet-inputs-dependency-exports
   (for/list ([row (in-list dependency-exports)])
     (match-define (list name exports) row)
     (webify-module-linklet-input name `(linklet () ,exports (void)) '()))))

;; dependency-exports/include-self : report dependency-exports -> dependency-exports
;;   Add the report's own export row for compiled linklets that import a
;;   same-module binding under an internalized local name.
(define (dependency-exports/include-self report dependency-exports)
  (define self-row (webify-module-extractor-spike-dependency-exports report))
  (match-define (list self-name _self-exports) self-row)
  (if (assoc self-name dependency-exports)
      dependency-exports
      (cons self-row dependency-exports)))

;; compiled-module->extractor-spike : symbol? any/c -> webify-module-extractor-spike?
;;   Convert one machine-independent compiled module to an extractor report.
(define (compiled-module->extractor-spike who name compiled)
  (cond
    [(webify-faslable-correlated-linklet? compiled)
     (compiled-linklet-datum->extractor-spike
      name
      (webify-faslable-correlated-linklet->datum compiled)
      '("machine-independent compilation exposes a faslable-correlated phase-0 linklet datum"))]
    [(linklet? compiled)
     (define phase0-entry (bundle-value->entry 0 compiled))
     (define phase0-linklet-datum
       (webify-module-bundle-entry-datum phase0-entry))
     (define manifest-ready? (linklet-datum? phase0-linklet-datum))
     (webify-module-extractor-spike
      name
      '(#f)
      '(0)
      (list phase0-entry)
      (linklet-import-variables compiled)
      (linklet-export-variables compiled)
      phase0-linklet-datum
      manifest-ready?
      (cond
        [manifest-ready?
         '("machine-independent compilation exposes a direct decompilable phase-0 linklet datum")]
        [maybe-decompile-linklet
         '("compiled module exposes a direct linklet object"
           "decompile-linklet did not produce a linklet datum for the phase-0 linklet")]
        [else
         '("compiled module exposes a direct linklet object"
           "host Racket does not provide decompile-linklet"
           "use the newer ../racket checkout for the machine-independent decompile spike")]))]
    [(not (linklet-directory? compiled))
     (define parsed (webify-compiled-expression->zo compiled))
     (cond
       [parsed (compiled-zo->extractor-spike who name parsed)]
       [else
        (raise-arguments-error who
                               "compiled module did not produce a linklet directory or direct linklet"
                               "compiled" compiled)])]
    [else
     (compiled-linklet-directory->extractor-spike who name compiled)]))

;; parsed-bundle->extractor-spike : symbol? symbol? hash? any/c any/c -> report
;;   Convert a parsed zo linklet bundle into an extractor report.
(define (parsed-bundle->extractor-spike who name bundle-hash directory-keys)
  (define bundle-entries
    (sort
     (for/list ([(key value) (in-hash bundle-hash)])
       (bundle-value->entry key value))
     bundle-entry<?))
  (define phase0-entry
    (for/first ([entry (in-list bundle-entries)]
                #:when (equal? 0 (webify-module-bundle-entry-key entry)))
      entry))
  (unless phase0-entry
    (raise-arguments-error who
                           "parsed bundle has no phase-0 linklet"
                           "bundle keys" (hash-keys bundle-hash)))
  (define phase0-linklet-datum
    (webify-module-bundle-entry-datum phase0-entry))
  (unless (linklet-datum? phase0-linklet-datum)
    (raise-arguments-error who
                           "parsed phase-0 entry did not contain a linklet datum"
                           "entry" phase0-entry))
  (webify-module-extractor-spike
   name
   directory-keys
   (sort (hash-keys bundle-hash) key<?)
   bundle-entries
   (webify-module-bundle-entry-imports phase0-entry)
   (webify-module-bundle-entry-exports phase0-entry)
   phase0-linklet-datum
   #t
   '("machine-independent compiled expression parses to faslable-correlated linklets")))

;; compiled-zo->extractor-spike : symbol? symbol? any/c -> report
;;   Convert compiler/zo-parse's bundle or directory structures into a report.
(define (compiled-zo->extractor-spike who name parsed)
  (cond
    [(webify-zo-linklet-bundle? parsed)
     (parsed-bundle->extractor-spike
      who
      name
      (webify-zo-linklet-bundle->hash parsed)
      '(#f))]
    [(webify-zo-linklet-directory? parsed)
     (define directory-hash (webify-zo-linklet-directory->hash parsed))
     (define main-bundle
       (or (hash-ref directory-hash #f #f)
           (hash-ref directory-hash '() #f)))
     (unless (webify-zo-linklet-bundle? main-bundle)
       (raise-arguments-error who
                              "parsed directory has no main linklet bundle"
                              "directory keys" (hash-keys directory-hash)))
     (parsed-bundle->extractor-spike
      who
      name
      (webify-zo-linklet-bundle->hash main-bundle)
      (sort (hash-keys directory-hash) key<?))]
    [else
     (raise-arguments-error who
                            "parsed compiled module did not produce a linklet bundle or directory"
                            "parsed" parsed)]))

;; compiled-linklet-datum->extractor-spike : symbol? linklet-datum any/c -> report
;;   Convert a decompiled direct phase-0 linklet datum into an extractor report.
(define (compiled-linklet-datum->extractor-spike name phase0-linklet-datum notes)
  (unless (linklet-datum? phase0-linklet-datum)
    (raise-arguments-error 'compiled-linklet-datum->extractor-spike
                           "faslable-correlated value did not contain a linklet datum"
                           "datum" phase0-linklet-datum))
  (match-define `(linklet ,imports ,exports . ,_body) phase0-linklet-datum)
  (define phase0-entry
    (webify-module-bundle-entry
     0
     'linklet
     imports
     exports
     phase0-linklet-datum
     #f))
  (webify-module-extractor-spike
   name
   '(#f)
   '(0)
   (list phase0-entry)
   imports
   exports
   phase0-linklet-datum
   #t
   notes))

;; compiled-linklet-directory->extractor-spike : symbol? symbol? linklet-directory? -> report
;;   Convert a compiled module directory into an extractor report.
(define (compiled-linklet-directory->extractor-spike who name compiled)
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

;; webify-compile-module-extractor-spike : any/c -> webify-module-extractor-spike?
;;   Probe Racket's compiled-module linklet shape without claiming extraction support.
(define (webify-compile-module-extractor-spike module-datum)
  (define who 'webify-compile-module-extractor-spike)
  (define name (validate-source-module! who module-datum))
  (define compiled
    (parameterize ([current-namespace (make-base-namespace)])
      (parameterize ([current-compile-target-machine #f])
        (compile (datum->syntax #f module-datum)))))
  (compiled-module->extractor-spike who name compiled))

;; webify-compile-module-extractor-spikes/shared-namespace : (listof module-datum) -> reports
;;   Compile source modules in order while installing earlier declarations for quoted requires.
(define (webify-compile-module-extractor-spikes/shared-namespace module-data)
  (define who 'webify-compile-module-extractor-spikes/shared-namespace)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (define namespace (make-base-namespace))
  (parameterize ([current-namespace namespace])
    (for/list ([module-datum (in-list module-data)])
      (define name (validate-source-module! who module-datum))
      (eval module-datum)
      (define compiled
        (parameterize ([current-compile-target-machine #f])
          (compile (datum->syntax #f module-datum))))
      (compiled-module->extractor-spike who name compiled))))

;; webify-module-path->extractor-spike : module-path? -> webify-module-extractor-spike?
;;   Compile an installed module path as machine-independent code and report its linklets.
(define (webify-module-path->extractor-spike module-path)
  (define who 'webify-module-path->extractor-spike)
  (define name (module-path->dependency-name module-path))
  (define source-path
    (resolved-module-path-name
     (module-path-index-resolve
      (module-path-index-join module-path #f)
      #t)))
  (define compiled
    (get-module-code
     source-path
     #:choose (lambda (_src _zo _so) 'src)
     #:compile (lambda (stx)
                 (parameterize ([current-compile-target-machine #f])
                   (compile stx)))))
  (compiled-module->extractor-spike who name compiled))

;; module-path-variable-export-metadata : module-path? -> list?
;;   Declare/load a module and read its variable exports with defined-name metadata.
(define (module-path-variable-export-metadata module-path)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (dynamic-require module-path #f)
    (call-with-values
     (lambda () (module->exports module-path 'defined-names))
     (lambda (variables _syntaxes) variables))))

;; webify-module-path->module-export-metadata : module-path? -> (list/c symbol? list?)
;;   Collect raw module->exports metadata for an installed module path.
(define (webify-module-path->module-export-metadata module-path)
  (list (module-path->dependency-name module-path)
        (module-path-variable-export-metadata module-path)))

;; webify-module-paths->module-export-metadata : (listof module-path?) -> (listof row?)
;;   Collect raw module->exports metadata for installed module paths.
(define (webify-module-paths->module-export-metadata module-paths)
  (define who 'webify-module-paths->module-export-metadata)
  (unless (list? module-paths)
    (raise-argument-error who "(listof module-path?)" module-paths))
  (for/list ([module-path (in-list module-paths)])
    (webify-module-path->module-export-metadata module-path)))

;; source-module-variable-export-metadata : module-datum symbol? -> list?
;;   Declare a source module and read its variable exports with defined-name metadata.
(define (source-module-variable-export-metadata module-datum name)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (eval module-datum)
    (call-with-values
     (lambda () (module->exports (list 'quote name) 'defined-names))
     (lambda (variables _syntaxes) variables))))

;; webify-source-module->module-export-metadata : module-datum -> (list/c symbol? list?)
;;   Collect raw module->exports metadata for a source module declaration.
(define (webify-source-module->module-export-metadata module-datum)
  (define who 'webify-source-module->module-export-metadata)
  (define name (validate-source-module! who module-datum))
  (list name (source-module-variable-export-metadata module-datum name)))

;; webify-source-modules->module-export-metadata : (listof module-datum) -> (listof row?)
;;   Collect raw module->exports metadata for source module declarations.
(define (webify-source-modules->module-export-metadata module-data)
  (define who 'webify-source-modules->module-export-metadata)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (for/list ([module-datum (in-list module-data)])
    (webify-source-module->module-export-metadata module-datum)))

;; webify-source-module->dependency-exports : module-datum -> dependency-export-row
;;   Compile a provider source module and expose its compiled phase-0 exports.
(define (webify-source-module->dependency-exports module-datum)
  (webify-module-extractor-spike-dependency-exports
   (webify-compile-module-extractor-spike module-datum)))

;; webify-source-modules->dependency-exports : (listof module-datum) -> dependency-exports
;;   Compile provider source modules and expose their compiled phase-0 exports.
(define (webify-source-modules->dependency-exports module-data)
  (define who 'webify-source-modules->dependency-exports)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (webify-module-extractor-spikes-dependency-exports
   (webify-compile-module-extractor-spikes/shared-namespace module-data)))

;; validate-extractor-reports! : symbol? any/c -> void?
;;   Reject values that cannot be used as an extracted module graph.
(define (validate-extractor-reports! who reports)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (for ([report (in-list reports)])
    (unless (webify-module-extractor-spike? report)
      (raise-argument-error who "webify-module-extractor-spike?" report)))
  ;; Reuse export-table construction to reject duplicate module names.
  (webify-module-extractor-spikes-dependency-exports reports)
  (void))

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

;; webify-module-extractor-spike->resolved-linklet-input : report ... -> webify-module-linklet-input?
;;   Resolve classified imports from an existing extractor report into bridge triples.
(define (webify-module-extractor-spike->resolved-linklet-input report
                                                               #:dependency-exports [dependency-exports '()]
                                                               #:dependencies [dependencies '()]
                                                               #:reflection-hints [reflection-hints '()]
                                                               #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-module-extractor-spike->resolved-linklet-input)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define raw-linklet (webify-module-extractor-spike-phase0-linklet-datum report))
  (define linklet (webify-normalize-linklet-imports raw-linklet))
  (webify-module-linklet-input
   (webify-module-extractor-spike-name report)
   linklet
   (resolve-extracted-linklet-imports
    who
    raw-linklet
    dependency-exports
    dependency-exports
    dependencies
    (webify-module-import-map-import-aliases import-map)
    (webify-module-import-map-require-rename-aliases import-map)
    (webify-module-import-map-required-module-candidates import-map)
    module-protocol-dependency
    reflection-hints
    (webify-module-extractor-spike-name report))))

;; webify-module-extractor-spike->resolved-linklet-input/providers : report reports ... -> input
;;   Resolve an importer report using compiled export rows from provider reports.
(define (webify-module-extractor-spike->resolved-linklet-input/providers report
                                                                         provider-reports
                                                                         #:dependency-exports [dependency-exports #f]
                                                                         #:dependencies [dependencies '()]
                                                                         #:reflection-hints [reflection-hints '()]
                                                                         #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-module-extractor-spike->resolved-linklet-input/providers)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (unless (list? provider-reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" provider-reports))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define raw-linklet (webify-module-extractor-spike-phase0-linklet-datum report))
  (define provider-dependency-exports
    (webify-module-extractor-spikes-dependency-exports provider-reports))
  (define provider+self-dependency-exports
    (dependency-exports/include-self report provider-dependency-exports))
  (webify-module-linklet-input
   (webify-module-extractor-spike-name report)
   (webify-normalize-linklet-imports raw-linklet)
   (resolve-extracted-linklet-imports
    who
    raw-linklet
    (or dependency-exports
        provider+self-dependency-exports)
    provider+self-dependency-exports
    dependencies
    (webify-module-import-map-import-aliases import-map)
    (webify-module-import-map-require-rename-aliases import-map)
    (webify-module-import-map-required-module-candidates import-map)
    module-protocol-dependency
    reflection-hints
    (webify-module-extractor-spike-name report))))

;; webify-module-extractor-spikes->resolved-linklet-inputs : reports ... -> (listof input?)
;;   Resolve a supplied extracted module graph into registry-ready linklet inputs.
(define (webify-module-extractor-spikes->resolved-linklet-inputs reports
                                                                  #:dependency-exports [dependency-exports #f]
                                                                  #:dependencies [dependencies '()]
                                                                  #:reflection-hints [reflection-hints '()]
                                                                  #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-module-extractor-spikes->resolved-linklet-inputs)
  (validate-extractor-reports! who reports)
  (for/list ([report (in-list reports)])
    (define provider-reports
      (filter (lambda (provider-report)
                (not (eq? provider-report report)))
              reports))
    (webify-module-extractor-spike->resolved-linklet-input/providers
     report
     provider-reports
     #:dependency-exports dependency-exports
     #:dependencies dependencies
     #:reflection-hints reflection-hints
     #:module-protocol-dependency module-protocol-dependency)))

;; webify-source-module->resolved-linklet-input : module-datum ... -> webify-module-linklet-input?
;;   Extract a source module and resolve classified imports into bridge triples.
(define (webify-source-module->resolved-linklet-input module-datum
                                                       #:dependency-exports [dependency-exports '()]
                                                       #:dependencies [dependencies '()]
                                                       #:reflection-hints [reflection-hints '()]
                                                       #:module-protocol-dependency [module-protocol-dependency #f])
  (webify-module-extractor-spike->resolved-linklet-input
   (webify-compile-module-extractor-spike module-datum)
   #:dependency-exports dependency-exports
   #:dependencies dependencies
   #:reflection-hints reflection-hints
   #:module-protocol-dependency module-protocol-dependency))

;; webify-source-module->resolved-linklet-input/providers : module-datum module-data ... -> input
;;   Compile an importer and providers, then resolve imports from provider compiled exports.
(define (webify-source-module->resolved-linklet-input/providers module-datum
                                                                 provider-module-data
                                                                 #:dependencies [dependencies '()]
                                                                 #:reflection-hints [reflection-hints '()]
                                                                 #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-source-module->resolved-linklet-input/providers)
  (unless (list? provider-module-data)
    (raise-argument-error who "(listof source-module-datum?)" provider-module-data))
  (webify-module-extractor-spike->resolved-linklet-input/providers
   (webify-compile-module-extractor-spike module-datum)
   (for/list ([provider-module-datum (in-list provider-module-data)])
     (webify-compile-module-extractor-spike provider-module-datum))
   #:dependencies dependencies
   #:reflection-hints reflection-hints
   #:module-protocol-dependency module-protocol-dependency))

;; webify-source-modules->resolved-linklet-inputs : module-data ... -> (listof input?)
;;   Compile supplied source modules and resolve them as a closed bridge graph.
(define (webify-source-modules->resolved-linklet-inputs module-data
                                                         #:dependencies [dependencies '()]
                                                         #:reflection-hints [reflection-hints '()]
                                                         #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-source-modules->resolved-linklet-inputs)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (webify-module-extractor-spikes->resolved-linklet-inputs
   (webify-compile-module-extractor-spikes/shared-namespace module-data)
   #:dependencies dependencies
   #:reflection-hints reflection-hints
   #:module-protocol-dependency module-protocol-dependency))

;; webify-source-modules->discovered-resolved-linklet-inputs : module-data ... -> (listof input?)
;;   Compile roots, discover installed providers, and resolve the graph.
(define (webify-source-modules->discovered-resolved-linklet-inputs
         module-data
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:demand-slice? [demand-slice? #f])
  (define who 'webify-source-modules->discovered-resolved-linklet-inputs)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (webify-module-extractor-spikes->discovered-resolved-linklet-inputs
   (webify-compile-module-extractor-spikes/shared-namespace module-data)
   #:extra-reports extra-reports
   #:fetch-provider fetch-provider
   #:dependencies dependencies
   #:module-protocol-dependency module-protocol-dependency
   #:demand-slice? demand-slice?))
