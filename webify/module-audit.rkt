#lang racket/base

(provide webify-module-graph-audit
         webify-module-graph-audit?
         webify-module-graph-audit-reports
         webify-module-graph-audit-required-provider-names
         webify-module-graph-audit-dependency-exports
         webify-module-graph-audit-unresolved-import-groups
         webify-module-graph-audit-provider-candidates
         webify-module-graph-audit-reflection-rows
         webify-module-graph-audit-reflection-import-hints
         webify-module-graph-audit-resolution-outcomes
         webify-module-graph-audit-resolved-inputs
         webify-module-graph-audit-failures
         webify-module-reflection-row
         webify-module-reflection-row?
         webify-module-reflection-row-name
         webify-module-reflection-row-imports
         webify-module-reflection-row-exports
         webify-module-reflection-row-export-bindings
         webify-module-reflection-row-required-provider-names
         webify-module-reflection-row-unresolved-import-groups
         webify-module-export-binding
         webify-module-export-binding?
         webify-module-export-binding-phase
         webify-module-export-binding-external
         webify-module-export-binding-provider-path
         webify-module-export-binding-internal
         webify-module-provider-candidate
         webify-module-provider-candidate?
         webify-module-provider-candidate-requester
         webify-module-provider-candidate-phase
         webify-module-provider-candidate-name
         webify-module-provider-candidate-status
         webify-module-provider-candidate-failure
         webify-module-audit-resolution-outcome
         webify-module-audit-resolution-outcome?
         webify-module-audit-resolution-outcome-module
         webify-module-audit-resolution-outcome-local
         webify-module-audit-resolution-outcome-dependency
         webify-module-audit-resolution-outcome-provider-export
         webify-module-audit-resolution-outcome-status
         webify-normalize-module-export-metadata
         webify-resolve-module-export-provider-paths
         webify-reflection-rows->import-hints
         webify-module-reports->graph-audit)

(require racket/list
         racket/match
         "module-diagnostics.rkt"
         "module-extractor-spike.rkt"
         "module-input.rkt")

(struct webify-module-graph-audit
  (reports
   required-provider-names
   dependency-exports
   unresolved-import-groups
   provider-candidates
   reflection-rows
   reflection-import-hints
   resolution-outcomes
   resolved-inputs
   failures)
  #:transparent)

(struct webify-module-reflection-row
  (name imports exports export-bindings required-provider-names unresolved-import-groups)
  #:transparent)

(struct webify-module-export-binding
  (phase external provider-path internal)
  #:transparent)

(struct webify-module-provider-candidate
  (requester phase name status failure)
  #:transparent)

(struct webify-module-audit-resolution-outcome
  (module local dependency provider-export status)
  #:transparent)

;; resolved-module-name->provider-symbol : any/c -> (or/c symbol? #f)
;;   Convert a resolved module path payload into Webify's dependency key shape.
(define (resolved-module-name->provider-symbol name)
  (cond
    [(symbol? name)
     name]
    [(path? name)
     (string->symbol (path->string name))]
    [(and (pair? name) (symbol? (car name)))
     (string->symbol (format "~s" name))]
    [(and (pair? name) (path? (car name)))
     (string->symbol (format "~s" name))]
    [else
     #f]))

;; module-path-index->provider-symbol : module-path-index? -> (or/c symbol? #f)
;;   Resolve an origin MPI without forcing module loading.
(define (module-path-index->provider-symbol mpi)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (resolved-module-name->provider-symbol
     (resolved-module-path-name
      (module-path-index-resolve mpi #f #f)))))

;; report-unresolved-row : report -> (list/c symbol? list?)
;;   Summarize unresolved non-protocol import groups for one report.
(define (report-unresolved-row report)
  (define import-map (webify-module-extractor-spike-import-map report))
  (list (webify-module-extractor-spike-name report)
        (webify-module-import-map-unresolved-import-groups import-map)))

;; simple-export-binding : symbol? symbol? -> webify-module-export-binding?
;;   Model an ordinary local export as metadata with no provider path.
(define (simple-export-binding phase export)
  (webify-module-export-binding phase export '() export))

;; module-export-row-entries : (listof any/c) -> (listof any/c)
;;   Normalize actual module->exports rows and older test rows to entry lists.
(define (module-export-row-entries entries)
  (match entries
    [(list (and nested (cons (or (? list?) (? vector?)) _)))
     nested]
    [_ entries]))

;; normalize-export-provider-path : (listof any/c) -> (listof any/c)
;;   Keep source-style provider entries and actual module->exports provider paths comparable.
(define (normalize-export-provider-path provider-path)
  (match provider-path
    [(list (and nested (cons (or (? list?) (? vector?)) _)))
     nested]
    [_ provider-path]))

;; resolve-module-export-provider-origin : symbol? any/c -> any/c
;;   Decode a raw module->exports origin into stable provider metadata.
(define (resolve-module-export-provider-origin external origin)
  (cond
    [(module-path-index? origin)
     (define provider (module-path-index->provider-symbol origin))
     (if provider
         (list 'provider provider external)
         origin)]
    [else
     (match origin
       [(list (? module-path-index? mpi) _phase (? symbol? import-name) _nominal-phase)
        (define provider (module-path-index->provider-symbol mpi))
        (if provider
            (list 'provider provider import-name)
            origin)]
       [(vector (? module-path-index? mpi) _phase (? symbol? import-name) _nominal-phase)
        (define provider (module-path-index->provider-symbol mpi))
        (if provider
            (list 'provider provider import-name)
            origin)]
       [_ origin])]))

;; resolve-module-export-provider-path : symbol? (listof any/c) -> (listof any/c)
;;   Resolve all raw origin entries in a module->exports provider path.
(define (resolve-module-export-provider-path external provider-path)
  (for/list ([origin (in-list (normalize-export-provider-path provider-path))])
    (resolve-module-export-provider-origin external origin)))

;; webify-resolve-module-export-provider-paths : exports -> exports
;;   Resolve raw module->exports MPI origins into stable provider/export metadata.
(define (webify-resolve-module-export-provider-paths exports)
  (define who 'webify-resolve-module-export-provider-paths)
  (unless (list? exports)
    (raise-argument-error who "list?" exports))
  (for/list ([row (in-list exports)])
    (match row
      [(cons phase entries)
       (define normalized-entries (module-export-row-entries entries))
       (unless (list? normalized-entries)
         (raise-argument-error who "module export entry list?" normalized-entries))
       (cons phase
             (for/list ([entry (in-list normalized-entries)])
               (match entry
                 [(list (? symbol? external) provider-path ... (? symbol? internal))
                  (list external
                        (resolve-module-export-provider-path external provider-path)
                        internal)]
                 [_ entry])))]
      [(? symbol? export)
       export]
      [_
       (raise-argument-error who "module export row?" row)])))

;; normalize-module-export-entry : any/c any/c -> webify-module-export-binding?
;;   Normalize one module->exports-style entry while preserving provider path data.
(define (normalize-module-export-entry phase entry)
  (match entry
    [(? symbol? external)
     (simple-export-binding phase external)]
    [(list (? symbol? external) provider-path ... (? symbol? internal))
     (webify-module-export-binding
      phase
      external
      (normalize-export-provider-path provider-path)
      internal)]
    [_
     (webify-module-export-binding phase entry '() entry)]))

;; webify-normalize-module-export-metadata : any/c -> (listof webify-module-export-binding?)
;;   Convert module->exports or simple export rows to stable diagnostic metadata.
(define (webify-normalize-module-export-metadata exports)
  (define who 'webify-normalize-module-export-metadata)
  (unless (list? exports)
    (raise-argument-error who "list?" exports))
  (append*
   (for/list ([row (in-list exports)])
     (match row
       [(cons phase entries)
        (define normalized-entries (module-export-row-entries entries))
        (unless (list? normalized-entries)
          (raise-argument-error who "module export entry list?" normalized-entries))
        (for/list ([entry (in-list normalized-entries)])
          (normalize-module-export-entry phase entry))]
       [(? symbol? export)
        (list (simple-export-binding 0 export))]
       [_
        (raise-argument-error who "module export row?" row)]))))

;; module-export-metadata-ref : any/c symbol? any/c -> any/c
;;   Look up optional module->exports metadata for one report.
(define (module-export-metadata-ref metadata name fallback)
  (cond
    [(hash? metadata)
     (hash-ref metadata name fallback)]
    [(list? metadata)
     (match (assoc name metadata)
       [(list _ exports) exports]
       [_ fallback])]
    [else
     fallback]))

;; report-reflection-row : report any/c -> webify-module-reflection-row?
;;   Normalize one extracted report into graph metadata for diagnostics.
(define (report-reflection-row report module-export-metadata)
  (define import-map (webify-module-extractor-spike-import-map report))
  (define exports (webify-module-extractor-spike-phase0-exports report))
  (define reflected-exports
    (module-export-metadata-ref module-export-metadata
                                (webify-module-extractor-spike-name report)
                                exports))
  (webify-module-reflection-row
   (webify-module-extractor-spike-name report)
   (webify-module-extractor-spike-phase0-imports report)
   exports
   (webify-normalize-module-export-metadata
    (webify-resolve-module-export-provider-paths reflected-exports))
   (webify-module-extractor-spike-required-provider-names report)
   (webify-module-import-map-unresolved-import-groups import-map)))

;; import-binding->local+external : any/c -> (or/c (list/c symbol? symbol?) #f)
;;   Normalize one unresolved import binding into local and external names.
(define (import-binding->local+external binding)
  (match binding
    [(list (? symbol? local) (? symbol? external))
     (list local external)]
    [(? symbol? name)
     (list name name)]
    [_
     #f]))

;; export-binding-matches? : webify-module-export-binding? symbol? -> boolean?
;;   Check whether an export binding can satisfy an unresolved external name.
(define (export-binding-matches? binding external)
  (or (eq? (webify-module-export-binding-external binding) external)
      (eq? (webify-module-export-binding-internal binding) external)))

;; provider-path->backing : any/c -> (or/c (list/c symbol? symbol?) #f)
;;   Decode explicit backing-provider metadata when a re-provide path carries it.
(define (provider-path->backing provider-path)
  (for/or ([item (in-list provider-path)])
    (match item
      [(list 'provider (? symbol? dependency) (? symbol? export))
       (list dependency export)]
      [(list 'provider-export (? symbol? dependency) (? symbol? export))
       (list dependency export)]
      [(list (? symbol? dependency) _phase (? symbol? export) _nominal-phase)
       (list dependency export)]
      [(vector (? symbol? dependency) _phase (? symbol? export) _nominal-phase)
       (list dependency export)]
      [(list (? symbol? dependency) (? symbol? export))
       (list dependency export)]
      [_ #f])))

;; export-binding-provider+internal : row binding -> (list/c symbol? symbol?)
;;   Resolve an export binding to the module/export pair that actually supplies it.
(define (export-binding-provider+internal row binding)
  (or (provider-path->backing
       (webify-module-export-binding-provider-path binding))
      (list (webify-module-reflection-row-name row)
            (webify-module-export-binding-internal binding))))

;; compute-reflection-import-hints : rows -> (listof (list/c importer local provider internal))
;;   Infer unambiguous provider hints from reflection rows before broad scanning.
(define (webify-reflection-rows->import-hints rows)
  (unless (list? rows)
    (raise-argument-error 'webify-reflection-rows->import-hints
                          "(listof webify-module-reflection-row?)"
                          rows))
  (for ([row (in-list rows)])
    (unless (webify-module-reflection-row? row)
      (raise-argument-error 'webify-reflection-rows->import-hints
                            "webify-module-reflection-row?"
                            row)))
  (append*
   (for/list ([row (in-list rows)])
     (define importer (webify-module-reflection-row-name row))
     (append*
      (for/list ([group (in-list (webify-module-reflection-row-unresolved-import-groups row))])
        (for/list ([binding (in-list group)]
                   #:do [(define maybe-local+external
                            (import-binding->local+external binding))]
                   #:when maybe-local+external
                   #:do [(match-define (list local external)
                            maybe-local+external)
                         (define candidates
                           (for*/list ([provider-row (in-list rows)]
                                       #:unless (eq? provider-row row)
                                       [export-binding
                                        (in-list (webify-module-reflection-row-export-bindings
                                                  provider-row))]
                                       #:when (export-binding-matches?
                                               export-binding
                                               external))
                             (export-binding-provider+internal provider-row
                                                               export-binding)))])
          (and (= (length candidates) 1)
               (match-let ([(list provider internal) (car candidates)])
                 (list importer local provider internal)))))))))

;; hint-status : symbol? symbol? symbol? symbol? hints dependencies -> symbol?
;;   Classify the source of one resolved provider selection.
(define (hint-status module-name local dependency provider-export reflection-hints dependencies)
  (cond
    [(for/or ([hint (in-list reflection-hints)])
       (match hint
         [(list importer hint-local hint-dependency hint-export)
          (and (eq? importer module-name)
               (eq? hint-local local)
               (eq? hint-dependency dependency)
               (eq? hint-export provider-export))]
         [_ #f]))
     'resolved-by-reflection-hint]
    [(for/or ([dependency-row (in-list dependencies)])
       (match dependency-row
         [(list hint-local hint-dependency)
          (and (eq? hint-local local)
               (eq? hint-dependency dependency))]
         [_ #f]))
     'resolved-by-explicit-dependency]
    [else
     'resolved-by-export-scan]))

;; input-resolution-outcomes : input hints dependencies -> outcomes
;;   Summarize how one resolved input's imports were selected.
(define (input-resolution-outcomes input reflection-hints dependencies)
  (for/list ([triple (in-list (webify-module-linklet-input-imports input))])
    (match-define (list local dependency provider-export) triple)
    (define module-name (webify-module-linklet-input-name input))
    (webify-module-audit-resolution-outcome
     module-name
     local
     dependency
     provider-export
     (hint-status module-name
                  local
                  dependency
                  provider-export
                  reflection-hints
                  dependencies))))

;; report-failure-row : symbol? exn? -> (list/c symbol? webify-module-failure?)
;;   Classify one audit failure without aborting the whole audit.
(define (report-failure-row stage exn)
  (list stage (webify-classify-module-exn stage exn)))

;; report-provider-candidates : report [procedure?] -> candidates
;;   Summarize provider candidates, optionally probing whether each can be fetched.
(define (report-provider-candidates report fetch-provider)
  (define import-map (webify-module-extractor-spike-import-map report))
  (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates
                                  import-map))])
    (match-define (list phase name) candidate)
    (cond
      [(not fetch-provider)
       (webify-module-provider-candidate
        (webify-module-extractor-spike-name report)
        phase
        name
        'not-checked
        #f)]
      [else
       (with-handlers ([exn:fail?
                        (lambda (exn)
                          (webify-module-provider-candidate
                           (webify-module-extractor-spike-name report)
                           phase
                           name
                           'failed
                           (webify-classify-module-exn 'fetch-provider exn)))])
         (fetch-provider name)
         (webify-module-provider-candidate
          (webify-module-extractor-spike-name report)
          phase
          name
          'fetchable
          #f))])))

;; webify-module-reports->graph-audit : reports ... -> webify-module-graph-audit?
;;   Inspect a report graph and attempt import resolution without hiding failures.
(define (webify-module-reports->graph-audit
         reports
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:dependencies [dependencies '()]
         #:module-export-metadata [module-export-metadata '()]
         #:fetch-provider [fetch-provider #f])
  (define who 'webify-module-reports->graph-audit)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (for ([report (in-list reports)])
    (unless (webify-module-extractor-spike? report)
      (raise-argument-error who "webify-module-extractor-spike?" report)))
  (define required-provider-names
    (remove-duplicates
     (append*
      (for/list ([report (in-list reports)])
        (webify-module-extractor-spike-required-provider-names report)))))
  (define-values (dependency-exports dependency-failures)
    (with-handlers ([exn:fail? (lambda (exn)
                                 (values '()
                                         (list (report-failure-row
                                                'dependency-exports
                                                exn))))])
      (values (webify-module-extractor-spikes-dependency-exports reports)
              '())))
  (define unresolved-import-groups
    (for/list ([report (in-list reports)])
      (report-unresolved-row report)))
  (define provider-candidates
    (append*
     (for/list ([report (in-list reports)])
       (report-provider-candidates report fetch-provider))))
  (define reflection-rows
    (for/list ([report (in-list reports)])
      (report-reflection-row report module-export-metadata)))
  (define reflection-import-hints
    (filter values (webify-reflection-rows->import-hints reflection-rows)))
  (define-values (resolved-inputs resolution-failures)
    (with-handlers ([exn:fail? (lambda (exn)
                                 (values '()
                                         (list (report-failure-row
                                                'resolve
                                                exn))))])
      (values
       (webify-module-extractor-spikes->resolved-linklet-inputs
        reports
        #:dependencies dependencies
        #:reflection-hints reflection-import-hints
        #:module-protocol-dependency module-protocol-dependency)
       '())))
  (define resolution-outcomes
    (append*
     (for/list ([input (in-list resolved-inputs)])
       (input-resolution-outcomes input reflection-import-hints dependencies))))
  (webify-module-graph-audit
   reports
   required-provider-names
   dependency-exports
   unresolved-import-groups
   provider-candidates
   reflection-rows
   reflection-import-hints
   resolution-outcomes
   resolved-inputs
   (append dependency-failures resolution-failures)))
