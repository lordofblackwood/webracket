#lang racket/base

(provide webracket-full-dashboard-rows
         print-webracket-full-dashboard)

(require json
         racket/list
         racket/match
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  webracket/base-provider-substitute)
         "../pkgs/webracket-lib/compiler/webify/provider-trials.rkt"
         "../pkgs/webracket-lib/compiler/webify/webracket-full-surface.rkt")

;; status-ref : symbol? symbol? -> symbol?
;;   Look up one status column for a full-surface library.
(define (status-ref library key)
  (define row (assoc library webracket-full-surface-statuses))
  (match key
    ['exported (if row (cadr row) 'missing)]
    ['extracts (if row (caddr row) 'unknown)]
    ['composes (if row (cadddr row) 'unknown)]
    ['runs     (if row (list-ref row 4) 'unknown)]))

;; audit-ref : symbol? symbol? -> symbol?
;;   Look up the implementation owner metadata for a full-surface library.
(define (audit-ref library key)
  (define row (assoc library webracket-full-surface-audit))
  (match key
    ['implementation-provider (if row (cadr row) 'unknown)]
    ['owner                   (if row (caddr row) 'unknown)]
    ['dashboard-case          (if row (cadddr row) 'unknown)]))

;; provider-trial-status : symbol? -> symbol?
;;   Report whether the temporary external-provider bridge allowlist covers a library.
(define (provider-trial-status library)
  (define routed-library (webracket/base-provider-substitute library))
  (cond
    [(webify-provider-trial-module-allowed? library) 'allowlisted]
    [(and (not (eq? routed-library library))
          (webify-provider-trial-module-allowed? routed-library))
     'allowlisted-via-substitution]
    [(memq library webracket-full-addon-libraries) 'not-allowlisted]
    [else 'not-full-addon]))

;; direct-runtime-smoke-status : symbol? -> symbol?
;;   Summarize whether the dashboard has a direct runtime smoke for this library.
(define (direct-runtime-smoke-status library)
  (case (status-ref library 'runs)
    [(runs) 'passes]
    [(host-only) 'host-expansion-only]
    [(partial) 'partial]
    [(unknown) 'unknown]
    [else (status-ref library 'runs)]))

;; last-known-blocker : symbol? -> symbol?
;;   Classify the next known reason this row is not fully green.
(define (last-known-blocker library)
  (cond
    [(eq? (status-ref library 'exported) 'missing) 'not-exported]
    [(eq? (status-ref library 'extracts) 'unknown) 'not-extracted]
    [(eq? (status-ref library 'runs) 'host-only) 'host-expander-only]
    [(not (eq? (status-ref library 'composes) 'composes)) 'module-composition-partial]
    [(not (memq (provider-trial-status library)
                '(allowlisted allowlisted-via-substitution)))
     'provider-not-allowlisted]
    [(not (eq? (status-ref library 'runs) 'runs)) 'runtime-partial]
    [else 'none]))

;; dashboard-row->jsexpr : (listof symbol?) -> hash?
;;   Convert one row to a JSON-friendly status object.
(define (dashboard-row->jsexpr row)
  (match-define
    (list library implementation-provider owner dashboard-case
          exported extracts composes runs provider-allowlisted
          direct-runtime-smoke blocker)
    row)
  (hasheq 'library              (symbol->string library)
          'implementation_provider (symbol->string implementation-provider)
          'owner                (symbol->string owner)
          'dashboard_case       (symbol->string dashboard-case)
          'exported             (symbol->string exported)
          'extracts             (symbol->string extracts)
          'composes             (symbol->string composes)
          'runs                 (symbol->string runs)
          'provider_allowlisted (symbol->string provider-allowlisted)
          'direct_runtime_smoke (symbol->string direct-runtime-smoke)
          'last_known_blocker   (symbol->string blocker)))

;; webracket-full-dashboard-rows : -> (listof (list symbol? ...))
;;   Return dashboard rows for the curated full language surface.
(define (webracket-full-dashboard-rows)
  (for/list ([library (in-list webracket-full-addon-libraries)])
    (list library
          (audit-ref library 'implementation-provider)
          (audit-ref library 'owner)
          (audit-ref library 'dashboard-case)
          (status-ref library 'exported)
          (status-ref library 'extracts)
          (status-ref library 'composes)
          (status-ref library 'runs)
          (provider-trial-status library)
          (direct-runtime-smoke-status library)
          (last-known-blocker library))))

;; print-webracket-full-dashboard : [#:tsv? boolean?] [#:json? boolean?] -> void?
;;   Print the current full-surface module/provider status.
(define (print-webracket-full-dashboard #:tsv? [tsv? #f]
                                        #:json? [json? #f])
  (cond
    [json?
     (write-json (map dashboard-row->jsexpr (webracket-full-dashboard-rows)))
     (newline)]
    [else
     (when tsv?
       (displayln
        "library\timplementation-provider\towner\tdashboard-case\texported\textracts\tcomposes\truns\tprovider-allowlisted\tdirect-runtime-smoke\tlast-known-blocker"))
     (for ([row (in-list (webracket-full-dashboard-rows))])
       (match-define
         (list library implementation-provider owner dashboard-case
               exported extracts composes runs provider-allowlisted
               direct-runtime-smoke blocker)
         row)
       (if tsv?
           (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
                   library implementation-provider owner dashboard-case
                   exported extracts composes runs provider-allowlisted direct-runtime-smoke blocker)
           (printf
            "~a implementation-provider=~a owner=~a dashboard-case=~a exported=~a extracts=~a composes=~a runs=~a provider-allowlisted=~a direct-runtime-smoke=~a last-known-blocker=~a\n"
            library implementation-provider owner dashboard-case
            exported extracts composes runs provider-allowlisted direct-runtime-smoke blocker)))]))

(module+ main
  (define args (vector->list (current-command-line-arguments)))
  (define tsv? (member "--tsv" args))
  (define json? (member "--json" args))
  (print-webracket-full-dashboard #:tsv? tsv? #:json? json?))
