#lang racket/base

(provide webify-module-graph-audit
         webify-module-graph-audit?
         webify-module-graph-audit-reports
         webify-module-graph-audit-required-provider-names
         webify-module-graph-audit-dependency-exports
         webify-module-graph-audit-unresolved-import-groups
         webify-module-graph-audit-provider-candidates
         webify-module-graph-audit-resolved-inputs
         webify-module-graph-audit-failures
         webify-module-provider-candidate
         webify-module-provider-candidate?
         webify-module-provider-candidate-requester
         webify-module-provider-candidate-phase
         webify-module-provider-candidate-name
         webify-module-provider-candidate-status
         webify-module-provider-candidate-failure
         webify-module-reports->graph-audit)

(require racket/list
         racket/match
         "module-diagnostics.rkt"
         "module-extractor-spike.rkt")

(struct webify-module-graph-audit
  (reports
   required-provider-names
   dependency-exports
   unresolved-import-groups
   provider-candidates
   resolved-inputs
   failures)
  #:transparent)

(struct webify-module-provider-candidate
  (requester phase name status failure)
  #:transparent)

;; report-unresolved-row : report -> (list/c symbol? list?)
;;   Summarize unresolved non-protocol import groups for one report.
(define (report-unresolved-row report)
  (define import-map (webify-module-extractor-spike-import-map report))
  (list (webify-module-extractor-spike-name report)
        (webify-module-import-map-unresolved-import-groups import-map)))

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
        #:module-protocol-dependency module-protocol-dependency)
       '())))
  (webify-module-graph-audit
   reports
   required-provider-names
   dependency-exports
   unresolved-import-groups
   provider-candidates
   resolved-inputs
   (append dependency-failures resolution-failures)))
