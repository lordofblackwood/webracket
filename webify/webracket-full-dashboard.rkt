#lang racket/base

(provide webracket-full-dashboard-rows
         print-webracket-full-dashboard)

(require racket/list
         racket/match
         "provider-trials.rkt"
         "webracket-full-surface.rkt")

;; status-ref : symbol? symbol? -> symbol?
;;   Look up one status column for a full-surface library.
(define (status-ref library key)
  (define row (assoc library webracket-full-surface-statuses))
  (match key
    ['exported (if row (cadr row) 'missing)]
    ['extracts (if row (caddr row) 'unknown)]
    ['composes (if row (cadddr row) 'unknown)]
    ['runs     (if row (list-ref row 4) 'unknown)]))

;; provider-trial-status : symbol? -> symbol?
;;   Report whether the temporary external-provider bridge allowlist covers a library.
(define (provider-trial-status library)
  (cond
    [(webify-provider-trial-module-allowed? library) 'allowlisted]
    [(memq library webracket-full-addon-libraries) 'not-allowlisted]
    [else 'not-full-addon]))

;; webracket-full-dashboard-rows : -> (listof (list symbol? symbol? symbol? symbol? symbol? symbol?))
;;   Return dashboard rows for the curated full language surface.
(define (webracket-full-dashboard-rows)
  (for/list ([library (in-list webracket-full-addon-libraries)])
    (list library
          (status-ref library 'exported)
          (status-ref library 'extracts)
          (status-ref library 'composes)
          (status-ref library 'runs)
          (provider-trial-status library))))

;; print-webracket-full-dashboard : [#:tsv? boolean?] -> void?
;;   Print the current full-surface module/provider status.
(define (print-webracket-full-dashboard #:tsv? [tsv? #f])
  (when tsv?
    (displayln "library\texported\textracts\tcomposes\truns\tprovider-trial"))
  (for ([row (in-list (webracket-full-dashboard-rows))])
    (match-define (list library exported extracts composes runs provider-trial) row)
    (if tsv?
        (printf "~a\t~a\t~a\t~a\t~a\t~a\n"
                library exported extracts composes runs provider-trial)
        (printf "~a exported=~a extracts=~a composes=~a runs=~a provider-trial=~a\n"
                library exported extracts composes runs provider-trial))))

(module+ main
  (define tsv? (member "--tsv" (vector->list (current-command-line-arguments))))
  (print-webracket-full-dashboard #:tsv? tsv?))
