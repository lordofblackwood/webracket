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

(define too-large-fixnum 536870912)

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
 (list "bitwise-bit-field handles bignum operands and indexes"
       (and
        (equal? (bitwise-bit-field too-large-fixnum 0 30)
                too-large-fixnum)
        (equal? (bitwise-bit-field too-large-fixnum 29 30)
                1)
        (equal? (bitwise-bit-field (- too-large-fixnum) 0 30)
                too-large-fixnum)
        (equal? (bitwise-bit-set? -1 too-large-fixnum)
                #t)
        (equal? (bitwise-bit-set? 13 too-large-fixnum)
                #f)
        (equal? (bitwise-bit-field 13 too-large-fixnum too-large-fixnum)
                0)
        (equal? (bitwise-bit-field -1 too-large-fixnum (+ too-large-fixnum 1))
                1)
        (catch-contract/contains?
         (lambda () (bitwise-bit-field 7 (+ too-large-fixnum 1) too-large-fixnum))
         "bitwise-bit-field"
         "ending index is smaller than starting index")))
 (list "bitwise type errors are catchable with who"
       (list "bitwise-and one-arg fast path"
             (catch-contract/contains?
              (lambda () (bitwise-and #f))
              "bitwise-and"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-and two-arg fast path"
             (catch-contract/contains?
              (lambda () (bitwise-and 1 #f))
              "bitwise-and"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-ior"
             (catch-contract/contains?
              (lambda () (bitwise-ior 1 #f))
              "bitwise-ior"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-xor"
             (catch-contract/contains?
              (lambda () (bitwise-xor #f 1))
              "bitwise-xor"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-not"
             (catch-contract/contains?
              (lambda () (bitwise-not #f))
              "bitwise-not"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-bit-set? value"
             (catch-contract/contains?
              (lambda () (bitwise-bit-set? #f 0))
              "bitwise-bit-set?"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-bit-set? position"
             (catch-contract/contains?
              (lambda () (bitwise-bit-set? 1 -1))
              "bitwise-bit-set?"
              "exact-nonnegative-integer?"
              "given: -1"))
       (list "bitwise-first-bit-set"
             (catch-contract/contains?
              (lambda () (bitwise-first-bit-set #f))
              "bitwise-first-bit-set"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-bit-field value"
             (catch-contract/contains?
              (lambda () (bitwise-bit-field #f 0 1))
              "bitwise-bit-field"
              "exact-integer?"
              "given: #f"))
       (list "bitwise-bit-field start"
             (catch-contract/contains?
              (lambda () (bitwise-bit-field 1 #f 1))
              "bitwise-bit-field"
              "exact-nonnegative-integer?"
              "given: #f"))
       (list "arithmetic-shift value"
             (catch-contract/contains?
              (lambda () (arithmetic-shift #f 1))
              "arithmetic-shift"
              "exact-integer?"
              "given: #f"))
       (list "arithmetic-shift count"
             (catch-contract/contains?
              (lambda () (arithmetic-shift 1 #f))
              "arithmetic-shift"
              "exact-integer?"
              "given: #f"))
       (list "integer-length"
             (catch-contract/contains?
              (lambda () (integer-length #f))
              "integer-length"
              "exact-integer?"
              "given: #f")))
 (list "numeric range and type errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(boolean? v) "CUSTOM-BOOLEAN"]
              [(symbol? v) "CUSTOM-SYMBOL"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (order-of-magnitude 'bad))
                     "order-of-magnitude"
                     "(and/c (>/c 0.0) (not/c +inf.0))"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (bitwise-and #f))
                     "bitwise-and"
                     "exact-integer?"
                     "given: CUSTOM-BOOLEAN")
                    (catch-contract/contains?
                     (lambda () (bitwise-bit-field 7 -1 2))
                     "bitwise-bit-field"
                     "exact-nonnegative-integer?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (flbit-field 1.0 65 66))
                     "flbit-field"
                     "(integer-in 0 64)"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
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
