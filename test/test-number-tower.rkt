#lang racket/base

(require rackunit
         "../tools/check-number-tower-cs.rkt")

(define cs-info (query-number-tower-cs-info))

;; text-record : string? -> list?
;;   Build a normalized text record like the oracle emits.
(define (text-record s)
  (list 'text (map char->integer (string->list s))))

;; ordinary-flonum-record : string? -> list?
;;   Build a normalized finite nonzero flonum record for comparison tests.
(define (ordinary-flonum-record s)
  (list 'number
        (text-record s)
        #t  ; number?
        #t  ; complex?
        #t  ; real?
        #t  ; rational?
        #f  ; integer?
        #f  ; exact-integer?
        #f  ; exact?
        #t  ; inexact?
        #f  ; fixnum?
        'ordinary
        '()))

;; complex-flonum-record : string? string? string? -> list?
;;   Build a normalized non-real complex flonum record for comparison tests.
(define (complex-flonum-record text real imag)
  (list 'number
        (text-record text)
        #t  ; number?
        #t  ; complex?
        #f  ; real?
        #f  ; rational?
        #f  ; integer?
        #f  ; exact-integer?
        #f  ; exact?
        #t  ; inexact?
        #f  ; fixnum?
        'non-real
        (list (ordinary-flonum-record real)
              (ordinary-flonum-record imag))))

(test-case "number tower oracle uses Racket CS"
  (validate-number-tower-cs-info! cs-info)
  (check-equal? (number-tower-cs-info-vm cs-info) 'chez-scheme)
  (check-not-false (regexp-match? #px"^[0-9]+\\." (number-tower-cs-info-version cs-info))))

(test-case "number tower oracle compares inexact values by ULP budget"
  (check-equal? (flonum-ulp-distance 1.25 1.2500000000000002) 1)
  (check-false
   (records-match?
    'exact
    (list 'value (ordinary-flonum-record "1.25"))
    (list 'value (ordinary-flonum-record "1.2500000000000002"))))
  (check-true
   (records-match?
    '(flonum-ulps 1)
    (list 'value (ordinary-flonum-record "1.25"))
    (list 'value (ordinary-flonum-record "1.2500000000000002"))))
  (check-true
   (records-match?
    '(complex-ulps 1)
    (list 'value
          (complex-flonum-record "1.25+1.25i" "1.25" "1.25"))
    (list 'value
          (complex-flonum-record "1.2500000000000002+1.25i"
                                 "1.2500000000000002"
                                 "1.25")))))

(test-case "number tower oracle smoke group agrees"
  (define summary
    (run-number-tower-oracle #:groups '(oracle-smoke)))
  (check-equal? (summary-failure-count summary) 0))

(test-case "number tower oracle reports deliberate mismatch"
  (check-true (number-tower-self-check-mismatch-detected?)))

(module+ main
  (void))
