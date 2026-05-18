#lang racket/base

(provide webify-provider-trial
         webify-provider-trial?
         webify-provider-trial-module
         webify-provider-trial-exports
         webify-provider-trial-source
         webify-provider-trial-report
         webify-provider-trial-report?
         webify-provider-trial-report-trial
         webify-provider-trial-report-status
         webify-provider-trial-report-elapsed-ms
         webify-provider-trial-report-export-demands
         webify-provider-trial-report-input-names
         webify-provider-trial-report-primitive-report
         webify-provider-trial-report-missing-primitives
         webify-provider-trial-report-provider-cache-hits
         webify-provider-trial-report-provider-cache-misses
         webify-provider-trial-report-error-message
         webify-provider-trials
         webify-provider-trial-module-allowlist
         webify-provider-trial-module-allowed?
         webify-provider-trial-ref
         webify-provider-trial-run
         webify-provider-trial-run-all
         webify-provider-trial-report-primitive-ownership-counts)

(require racket/list
         "module-input.rkt"
         "module-extractor.rkt"
         "module-protocol.rkt")

(struct webify-provider-trial (module exports source) #:transparent)
(struct webify-provider-trial-report
  (trial
   status
   elapsed-ms
   export-demands
   input-names
   primitive-report
   missing-primitives
   provider-cache-hits
   provider-cache-misses
   error-message)
  #:transparent)

;; webify-provider-trials : (listof webify-provider-trial?)
;;   Small external-provider discovery-only cases that are not runtime defaults.
(define webify-provider-trials
  (list
   (webify-provider-trial
    'racket/list
    '(first rest filter-map append-map)
    '(module use-list racket/base
       (require (only-in racket/list first rest filter-map append-map))
       (provide answer)
       (define answer (list first rest filter-map append-map))))
   (webify-provider-trial
    'racket/string
    '(string-prefix? string-suffix? string-split string-join)
    '(module use-string racket/base
       (require (only-in racket/string
                         string-prefix?
                         string-suffix?
                         string-split
                         string-join))
       (provide answer)
       (define answer
         (list string-prefix? string-suffix? string-split string-join))))
   (webify-provider-trial
    'racket/bool
    '(xor boolean=?)
    '(module use-bool racket/base
       (require (only-in racket/bool xor boolean=?))
       (provide answer)
       (define answer (list xor boolean=?))))))

;; webify-provider-trial-module-allowlist : (listof symbol?)
;;   External providers allowed in the temporary #lang webracket/base bridge.
(define webify-provider-trial-module-allowlist
  (map webify-provider-trial-module webify-provider-trials))

;; webify-provider-trial-module-allowed? : symbol? -> boolean?
;;   Check whether an external provider is in the discovery trial manifest.
(define (webify-provider-trial-module-allowed? module)
  (and (memq module webify-provider-trial-module-allowlist) #t))

;; webify-provider-trial-ref : symbol? -> webify-provider-trial?
;;   Look up a provider trial by module name.
(define (webify-provider-trial-ref module)
  (define trial
    (findf (lambda (trial)
             (eq? module (webify-provider-trial-module trial)))
           webify-provider-trials))
  (unless trial
    (raise-arguments-error 'webify-provider-trial-ref
                           "unknown provider trial module"
                           "module" module))
  trial)

;; webify-provider-trial-run : webify-provider-trial? -> report?
;;   Run one discovery-only provider trial and collect primitive-demand evidence.
(define (webify-provider-trial-run trial
                                   #:fetch-provider
                                   [fetch-provider webify-module-path->report])
  (define who 'webify-provider-trial-run)
  (unless (webify-provider-trial? trial)
    (raise-argument-error who "webify-provider-trial?" trial))
  (define start-ms (current-inexact-milliseconds))
  (define provider-cache (make-webify-module-provider-cache fetch-provider))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (webify-provider-trial-report
                      trial
                      'failed
                      (- (current-inexact-milliseconds) start-ms)
                      '()
                      '()
                      (webify-primitive-demand-report '() '())
                      '()
                      (webify-module-provider-cache-hit-count provider-cache)
                      (webify-module-provider-cache-miss-count provider-cache)
                      (exn-message exn)))])
    (define importer-report
      (webify-compile-module-report (webify-provider-trial-source trial)))
    (define inputs
      (webify-module-reports->discovered-resolved-linklet-inputs
       (list importer-report)
       #:extra-reports (list webify-module-protocol-report)
       #:fetch-provider
       (lambda (name)
         (webify-module-provider-cache-ref provider-cache name))
       #:module-protocol-dependency webify-module-protocol-dependency
       #:demand-slice? #t))
    (define provider-report
      (webify-module-provider-cache-ref provider-cache
                                        (webify-provider-trial-module trial)))
    (define export-demands
      (webify-module-report-import-export-demands
       importer-report
       (list provider-report)
       #:module-protocol-dependency webify-module-protocol-dependency))
    (define primitive-report
      (webify-module-reports->primitive-demands '() #:inputs inputs))
    (webify-provider-trial-report
     trial
     'ok
     (- (current-inexact-milliseconds) start-ms)
     export-demands
     (map webify-module-linklet-input-name inputs)
     primitive-report
     (webify-primitive-demand-report-missing primitive-report)
     (webify-module-provider-cache-hit-count provider-cache)
     (webify-module-provider-cache-miss-count provider-cache)
     #f)))

;; webify-provider-trial-run-all : -> (listof report?)
;;   Run all discovery-only provider trials in manifest order.
(define (webify-provider-trial-run-all
         #:fetch-provider [fetch-provider webify-module-path->report])
  (for/list ([trial (in-list webify-provider-trials)])
    (webify-provider-trial-run trial #:fetch-provider fetch-provider)))

;; webify-provider-trial-report-primitive-ownership-counts : report? -> alist?
;;   Count primitive demands by ownership for one provider-trial report.
(define (webify-provider-trial-report-primitive-ownership-counts report)
  (define primitive-report
    (webify-provider-trial-report-primitive-report report))
  (webify-primitive-demand-report-ownership-counts primitive-report))
