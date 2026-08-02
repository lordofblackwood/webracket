;; Focused no-stdlib generated-output checks for range errors.
;;
;; Compile this file with `--no-stdlib`.
;; Native Racket in this checkout does not raise quickly for zero-step ranges,
;; so use generated-output execution as the semantic check.

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
 (list "range real argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (range 'bad 3))
         "in-range"
         "real?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (range 0 'bad))
         "in-range"
         "real?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (range 0 3 'bad))
         "in-range"
         "real?"
         "given: 'bad")))
 (list "range zero-step errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (range 0 3 0))
         "in-range"
         "(and/c real? (not/c zero?))"
         "given: 0")
        (catch-contract/contains?
         (lambda () (range 0.0 3.0 0.0))
         "in-range"
         "(and/c real? (not/c zero?))"
         "given: 0.0")))
 (list "inclusive-range real argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (inclusive-range 'bad 3))
         "in-inclusive-range"
         "real?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (inclusive-range 0 'bad))
         "in-inclusive-range"
         "real?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (inclusive-range 0 3 'bad))
         "in-inclusive-range"
         "real?"
         "given: 'bad")))
 (list "inclusive-range zero-step errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (inclusive-range 0 3 0))
         "in-inclusive-range"
         "(and/c real? (not/c zero?))"
         "given: 0")
        (catch-contract/contains?
         (lambda () (inclusive-range 0.0 3.0 0.0))
         "in-inclusive-range"
         "(and/c real? (not/c zero?))"
         "given: 0.0")))
 (list "range errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(symbol? v) "CUSTOM-SYMBOL"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (range 'bad 3))
                     "in-range"
                     "real?"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (range 0 3 0))
                     "in-range"
                     "(and/c real? (not/c zero?))"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (inclusive-range 0 'bad))
                     "in-inclusive-range"
                     "real?"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (inclusive-range 0.0 3.0 0.0))
                     "in-inclusive-range"
                     "(and/c real? (not/c zero?))"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "range success still works"
       (and (equal? (range 3) '(0 1 2))
            (equal? (range 1 5 2) '(1 3))
            (equal? (range 3 0 -1) '(3 2 1))))
 (list "inclusive-range success still works"
       (and (equal? (inclusive-range 1 3) '(1 2 3))
            (equal? (inclusive-range 3 1) '(3 2 1))
            (equal? (inclusive-range 1 5 2) '(1 3 5)))))
