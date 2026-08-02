;; Focused no-stdlib generated-output checks for random primitive errors.
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
 (list "random argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (random #f))
         "random"
         "(or/c (integer-in 1 4294967087) pseudo-random-generator?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (random 0))
         "random"
         "(or/c (integer-in 1 4294967087) pseudo-random-generator?)"
         "given: 0")
        (catch-contract/contains?
         (lambda () (random #f 10))
         "random"
         "exact-integer?"
         "given: #f"
         "argument position: 1st"
         "other arguments...")
        (catch-contract/contains?
         (lambda () (random 1 #f))
         "random"
         "(or/c exact-integer? pseudo-random-generator?)"
         "given: #f"
         "argument position: 2nd"
         "other arguments...")
        (catch-contract/contains?
         (lambda () (random 10 1))
         "random"
         "(>/c 10)"
         "given: 1"
         "argument position: 2nd"
         "other arguments...")
        (let ([g (make-pseudo-random-generator)])
          (and
           (catch-contract/contains?
            (lambda () (random #f g))
            "random"
            "(integer-in 1 4294967087)"
            "given: #f"
            "argument position: 1st"
            "other arguments...")
           (catch-contract/contains?
            (lambda () (random 0 g))
            "random"
            "(integer-in 1 4294967087)"
            "given: 0"
            "argument position: 1st"
            "other arguments...")))))
 (list "random two-argument errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (random 10 1))
                     "random"
                     "expected: (>/c 10)"
                     "given: CUSTOM-NUMBER"
                     "other arguments...:"
                     "CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (random #f 10))
                     "random"
                     "exact-integer?"
                     "given: CUSTOM-VALUE"
                     "other arguments...:"
                     "CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "random-seed errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (random-seed #f))
         "random-seed"
         "(integer-in 0 (sub1 (expt 2 31)))"
         "given: #f")
        (catch-contract/contains?
         (lambda () (random-seed -1))
         "random-seed"
         "(integer-in 0 (sub1 (expt 2 31)))"
         "given: -1")))
 (list "current-pseudo-random-generator errors are catchable with who"
       (catch-contract/contains?
        (lambda () (current-pseudo-random-generator 42))
        "current-pseudo-random-generator"
        "pseudo-random-generator?"
        "given: 42"))
 (list "flrandom rejects a bad generator"
       (catch-contract/contains?
        (lambda () (flrandom 42))
        "flrandom"
        "pseudo-random-generator?"
        "given: 42"))
 (list "random success cases still work"
       (let ([g (make-pseudo-random-generator)])
         (and (let ([v (random)])
                (and (flonum? v) (> v 0.0) (< v 1.0)))
              (let ([v (random 5)])
                (and (exact-integer? v) (>= v 0) (< v 5)))
              (let ([v (random -5 5)])
                (and (exact-integer? v) (>= v -5) (< v 5)))
              (let ([v (random g)])
                (and (flonum? v) (> v 0.0) (< v 1.0)))
              (let ([v (random 5 g)])
                (and (exact-integer? v) (>= v 0) (< v 5)))
              (let ([v (flrandom)])
                (and (flonum? v) (> v 0.0) (< v 1.0)))
              (let ([v (flrandom g)])
                (and (flonum? v) (> v 0.0) (< v 1.0)))))))
