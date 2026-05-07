#lang racket/base

(provide
 (rename-out
  [webify-module-extractor-spike webify-module-report]
  [webify-module-extractor-spike? webify-module-report?]
  [webify-module-extractor-spike-name webify-module-report-name]
  [webify-module-extractor-spike-directory-keys webify-module-report-directory-keys]
  [webify-module-extractor-spike-bundle-keys webify-module-report-bundle-keys]
  [webify-module-extractor-spike-bundle-entries webify-module-report-bundle-entries]
  [webify-module-extractor-spike-phase0-imports webify-module-report-phase0-imports]
  [webify-module-extractor-spike-phase0-exports webify-module-report-phase0-exports]
  [webify-module-extractor-spike-phase0-linklet-datum webify-module-report-phase0-linklet-datum]
  [webify-module-extractor-spike-manifest-ready? webify-module-report-manifest-ready?]
  [webify-module-extractor-spike-notes webify-module-report-notes]
  [webify-module-extractor-spike-import-map webify-module-report-import-map]
  [webify-module-extractor-spike-required-provider-names
   webify-module-report-required-provider-names]
  [webify-module-extractor-spike->required-provider-spikes
   webify-module-report->required-provider-reports]
  [webify-module-extractor-spikes->required-provider-closure
   webify-module-reports->required-provider-closure]
  [webify-module-extractor-spikes->discovered-resolved-linklet-inputs
   webify-module-reports->discovered-resolved-linklet-inputs]
  [webify-module-extractor-spike-dependency-exports webify-module-report-dependency-exports]
  [webify-module-extractor-spikes-dependency-exports webify-module-reports-dependency-exports]
  [webify-module-extractor-spike->resolved-linklet-input webify-module-report->resolved-linklet-input]
  [webify-module-extractor-spike->resolved-linklet-input/providers
   webify-module-report->resolved-linklet-input/providers]
  [webify-module-extractor-spikes->resolved-linklet-inputs
   webify-module-reports->resolved-linklet-inputs]
  [webify-module-path->extractor-spike webify-module-path->report]
  [webify-compile-module-extractor-spike webify-compile-module-report])
 webify-module-reports->registry
 webify-source-module->dependency-exports
 webify-source-modules->dependency-exports
 webify-source-module->linklet-input
 webify-source-module->resolved-linklet-input
 webify-source-module->resolved-linklet-input/providers
 webify-source-modules->resolved-linklet-inputs
 webify-source-modules->discovered-resolved-linklet-inputs
 webify-source-modules->registry
 webify-module-reports->discovered-registry
 webify-source-modules->discovered-registry
 webify-module-provider-cache
 webify-module-provider-cache?
 make-webify-module-provider-cache
 webify-module-provider-cache-ref
 webify-module-provider-cache-names
 webify-module-provider-cache-count
 webify-normalize-linklet-imports
 webify-linklet-import-bindings
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
 webify-module-bundle-entry-ref)

(require "module-extractor-spike.rkt"
         "module-input.rkt")

;; webify-module-reports->registry : (listof webify-module-report?) -> webify-module-registry?
;;   Resolve extracted module reports and register their bridge-ready linklet inputs.
(define (webify-module-reports->registry reports
                                         #:dependencies [dependencies '()]
                                         #:module-protocol-dependency [module-protocol-dependency #f])
  (webify-module-linklet-inputs->registry
   (webify-module-extractor-spikes->resolved-linklet-inputs
    reports
    #:dependencies dependencies
    #:module-protocol-dependency module-protocol-dependency)))

;; webify-source-modules->registry : (listof source-module-datum?) -> webify-module-registry?
;;   Compile supplied source modules, resolve their imports, and register them.
(define (webify-source-modules->registry module-data
                                         #:dependencies [dependencies '()]
                                         #:module-protocol-dependency [module-protocol-dependency #f])
  (webify-module-linklet-inputs->registry
   (webify-source-modules->resolved-linklet-inputs
    module-data
    #:dependencies dependencies
    #:module-protocol-dependency module-protocol-dependency)))

;; webify-module-reports->discovered-registry : (listof report?) -> webify-module-registry?
;;   Discover providers, resolve the report graph, and register bridge-ready inputs.
(define (webify-module-reports->discovered-registry
         reports
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f])
  (webify-module-linklet-inputs->registry
   (webify-module-extractor-spikes->discovered-resolved-linklet-inputs
    reports
    #:extra-reports extra-reports
    #:fetch-provider fetch-provider
    #:dependencies dependencies
    #:module-protocol-dependency module-protocol-dependency)))

;; webify-source-modules->discovered-registry : (listof source-module-datum?) -> webify-module-registry?
;;   Compile roots, discover providers, resolve the graph, and register it.
(define (webify-source-modules->discovered-registry
         module-data
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f])
  (webify-module-linklet-inputs->registry
   (webify-source-modules->discovered-resolved-linklet-inputs
    module-data
    #:extra-reports extra-reports
    #:fetch-provider fetch-provider
    #:dependencies dependencies
    #:module-protocol-dependency module-protocol-dependency)))
