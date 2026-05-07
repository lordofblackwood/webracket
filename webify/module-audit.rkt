#lang racket/base

(provide webify-module-graph-audit
         webify-module-graph-audit?
         webify-module-graph-audit-reports
         webify-module-graph-audit-required-provider-names
         webify-module-graph-audit-dependency-exports
         webify-module-graph-audit-unresolved-import-groups
         webify-module-graph-audit-resolved-inputs
         webify-module-graph-audit-failures
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
   resolved-inputs
   failures)
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

;; webify-module-reports->graph-audit : reports ... -> webify-module-graph-audit?
;;   Inspect a report graph and attempt import resolution without hiding failures.
(define (webify-module-reports->graph-audit
         reports
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:dependencies [dependencies '()])
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
   resolved-inputs
   (append dependency-failures resolution-failures)))
