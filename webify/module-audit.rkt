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

;; normalize-module-export-entry : any/c any/c -> webify-module-export-binding?
;;   Normalize one module->exports-style entry while preserving provider path data.
(define (normalize-module-export-entry phase entry)
  (match entry
    [(? symbol? external)
     (simple-export-binding phase external)]
    [(list (? symbol? external) provider-path ... (? symbol? internal))
     (webify-module-export-binding phase external provider-path internal)]
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
       [(list phase entries)
        (unless (list? entries)
          (raise-argument-error who "module export entry list?" entries))
        (for/list ([entry (in-list entries)])
          (normalize-module-export-entry phase entry))]
       [(cons phase entries)
        (unless (list? entries)
          (raise-argument-error who "module export entry list?" entries))
        (for/list ([entry (in-list entries)])
          (normalize-module-export-entry phase entry))]
       [(? symbol? export)
        (list (simple-export-binding 0 export))]
       [_
        (raise-argument-error who "module export row?" row)]))))

;; report-reflection-row : report -> webify-module-reflection-row?
;;   Normalize one extracted report into graph metadata for diagnostics.
(define (report-reflection-row report)
  (define import-map (webify-module-extractor-spike-import-map report))
  (define exports (webify-module-extractor-spike-phase0-exports report))
  (webify-module-reflection-row
   (webify-module-extractor-spike-name report)
   (webify-module-extractor-spike-phase0-imports report)
   exports
   (webify-normalize-module-export-metadata exports)
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

;; compute-reflection-import-hints : rows -> (listof (list/c importer local provider internal))
;;   Infer unambiguous provider hints from reflection rows before broad scanning.
(define (compute-reflection-import-hints rows)
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
                             (list (webify-module-reflection-row-name provider-row)
                                   (webify-module-export-binding-internal export-binding))))])
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
      (report-reflection-row report)))
  (define reflection-import-hints
    (filter values (compute-reflection-import-hints reflection-rows)))
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
