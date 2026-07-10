;; Focused no-stdlib generated-output checks for numeric range errors.
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
 (list "order-of-magnitude range errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (order-of-magnitude 0))
         "order-of-magnitude"
         "(and/c (>/c 0.0) (not/c +inf.0))"
         "given: 0")
        (catch-contract/contains?
         (lambda () (order-of-magnitude -1))
         "order-of-magnitude"
         "(and/c (>/c 0.0) (not/c +inf.0))"
         "given: -1")
        (catch-contract/contains?
         (lambda () (order-of-magnitude +inf.0))
         "order-of-magnitude"
         "(and/c (>/c 0.0) (not/c +inf.0))"
         "given: +inf.0")
        (catch-contract/contains?
         (lambda () (order-of-magnitude 'bad))
         "order-of-magnitude"
         "(and/c (>/c 0.0) (not/c +inf.0))"
         "given: 'bad")))
 (list "bitwise-bit-field range errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (bitwise-bit-field 7 -1 2))
         "bitwise-bit-field"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bitwise-bit-field 7 0 -1))
         "bitwise-bit-field"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bitwise-bit-field 7 2 1))
         "bitwise-bit-field"
         "ending index is smaller than starting index")))
 (list "flbit-field range errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 -1 2))
         "flbit-field"
         "(integer-in 0 64)"
         "given: -1")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 0 -1))
         "flbit-field"
         "(integer-in 0 64)"
         "given: -1")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 65 66))
         "flbit-field"
         "(integer-in 0 64)"
         "given: 65")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 2 1))
         "flbit-field"
         "start must be <= end")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 0 64))
         "flbit-field"
         "result would be outside of WebRacket fixnum range")))
 (list "numeric range success cases still work"
       (and (equal? (order-of-magnitude 100) 2)
            (equal? (order-of-magnitude 0.01) -2)
            (equal? (bitwise-bit-field 13 0 3) 5)
            (equal? (bitwise-bit-field 13 2 4) 3)
            (equal? (flbit-field 1.0 0 1) 0))))
