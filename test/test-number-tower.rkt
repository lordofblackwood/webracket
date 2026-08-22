#lang racket/base

(require rackunit
         "../tools/check-number-tower-cs.rkt")

(define cs-info (query-number-tower-cs-info))

(test-case "number tower oracle uses Racket CS"
  (validate-number-tower-cs-info! cs-info)
  (check-equal? (number-tower-cs-info-vm cs-info) 'chez-scheme)
  (check-not-false (regexp-match? #px"^[0-9]+\\." (number-tower-cs-info-version cs-info))))

(test-case "number tower oracle smoke group agrees"
  (define summary
    (run-number-tower-oracle #:groups '(oracle-smoke)))
  (check-equal? (summary-failure-count summary) 0))

(test-case "number tower oracle reports deliberate mismatch"
  (check-true (number-tower-self-check-mismatch-detected?)))

(module+ main
  (void))
