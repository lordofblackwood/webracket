;; Focused no-stdlib generated-output checks for date/time errors.
;;
;; Compile this file with `--no-stdlib`.

(define (catch-contract/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:contract?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(list
 (list "date constructor range errors report valid ranges"
       (and
        (catch-contract/contains?
         (lambda () (date 61 0 0 1 1 2024 0 0 #f 0))
         "date"
         "(integer-in 0 60)"
         "given: 61")
        (catch-contract/contains?
         (lambda () (date 0 60 0 1 1 2024 0 0 #f 0))
         "date"
         "(integer-in 0 59)"
         "given: 60")
        (catch-contract/contains?
         (lambda () (date 0 0 24 1 1 2024 0 0 #f 0))
         "date"
         "(integer-in 0 23)"
         "given: 24")
        (catch-contract/contains?
         (lambda () (date 0 0 0 0 1 2024 0 0 #f 0))
         "date"
         "(integer-in 1 31)"
         "given: 0")
        (catch-contract/contains?
         (lambda () (date 0 0 0 1 13 2024 0 0 #f 0))
         "date"
         "(integer-in 1 12)"
         "given: 13")
        (catch-contract/contains?
         (lambda () (date 0 0 0 1 1 2024 7 0 #f 0))
         "date"
         "(integer-in 0 6)"
         "given: 7")
        (catch-contract/contains?
         (lambda () (date 0 0 0 1 1 2024 0 366 #f 0))
         "date"
         "(integer-in 0 365)"
         "given: 366")))
 (list "date* constructor range errors report valid ranges"
       (catch-contract/contains?
        (lambda () (date* 0 0 0 1 1 2024 0 0 #f 0 1000000000 "UTC"))
        "date*"
        "(integer-in 0 999999999)"
        "given: 1000000000"))
 (list "date accessors reject non-date values with who"
       (and
        (catch-contract/contains?
         (lambda () (date-second 42))
         "date-second"
         "date?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (date*-nanosecond 42))
         "date*-nanosecond"
         "date*?"
         "given: 42")))
 (list "date and time contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(symbol? v) "CUSTOM-SYMBOL"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (date 61 0 0 1 1 2024 0 0 #f 0))
                     "date"
                     "(integer-in 0 60)"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (date-second 42))
                     "date-second"
                     "date?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (current-process-milliseconds 'bad))
                     "current-process-milliseconds"
                     "(or/c #f thread? 'subprocesses)"
                     "given: CUSTOM-SYMBOL"))])
           (error-value->string-handler old)
           ok)))
 (list "current-process-milliseconds rejects invalid scopes"
       (and
        (catch-contract/contains?
         (lambda () (current-process-milliseconds 42))
         "current-process-milliseconds"
         "(or/c #f thread? 'subprocesses)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-process-milliseconds 'bad))
         "current-process-milliseconds"
         "(or/c #f thread? 'subprocesses)"
         "given: 'bad")))
 (list "current-process-milliseconds accepts valid scopes"
       (and (exact-integer? (current-process-milliseconds))
            (exact-integer? (current-process-milliseconds #f))
            (exact-integer? (current-process-milliseconds (current-thread)))
            (exact-integer? (current-process-milliseconds 'subprocesses))))
 (list "seconds->date rejects non-finite seconds without trapping"
       (and
        (catch-contract/contains?
         (lambda () (seconds->date +nan.0))
         "inexact->exact"
         "no exact representation"
         "+nan.0")
        (catch-contract/contains?
         (lambda () (seconds->date +inf.0))
         "inexact->exact"
         "no exact representation"
         "+inf.0")
        (catch-contract/contains?
         (lambda () (seconds->date -inf.0))
         "inexact->exact"
         "no exact representation"
         "-inf.0")))
 (list "seconds->date accepts bignum seconds"
       (let ([d (seconds->date 536870912 #f)])
         (and (date*? d)
              (equal? (date-second d) 32)
              (equal? (date-minute d) 48)
              (equal? (date-hour d) 18)
              (equal? (date-day d) 5)
              (equal? (date-month d) 1)
              (equal? (date-year d) 1987)
              (equal? (date-week-day d) 1)
              (equal? (date-year-day d) 4)
              (equal? (date-dst? d) #f)
              (equal? (date-time-zone-offset d) 0)
              (equal? (date*-nanosecond d) 0)
              (equal? (date*-time-zone-name d) "UTC")))))
