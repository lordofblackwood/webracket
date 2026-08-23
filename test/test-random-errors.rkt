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
         "(or/c (integer-in 1 536870911) pseudo-random-generator?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (random 0))
         "random"
         "(or/c (integer-in 1 536870911) pseudo-random-generator?)"
         "given: 0")
        (catch-contract/contains?
         (lambda () (random 536870912))
         "random"
         "(or/c (integer-in 1 536870911) pseudo-random-generator?)"
         "given: 536870912")
        (catch-contract/contains?
         (lambda () (random #f 10))
         "random"
         "fixnum?"
         "given: #f"
         "argument position: 1st"
         "other arguments...")
        (catch-contract/contains?
         (lambda () (random 1 #f))
         "random"
         "(or/c fixnum? pseudo-random-generator?)"
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
            "(integer-in 1 536870911)"
            "given: #f"
            "argument position: 1st"
            "other arguments...")
           (catch-contract/contains?
            (lambda () (random 0 g))
            "random"
            "(integer-in 1 536870911)"
            "given: 0"
            "argument position: 1st"
            "other arguments...")
           (catch-contract/contains?
            (lambda () (random 536870912 g))
            "random"
            "(integer-in 1 536870911)"
            "given: 536870912"
            "argument position: 1st"
            "other arguments...")))))
 (list "random bignum two-argument errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (random 536870912 536870913))
         "random"
         "fixnum?"
         "given: 536870912"
         "argument position: 1st"
         "other arguments...")
        (catch-contract/contains?
         (lambda () (random 0 536870912))
         "random"
         "(or/c fixnum? pseudo-random-generator?)"
         "given: 536870912"
         "argument position: 2nd"
         "other arguments...")))
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
                     "fixnum?"
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
         "(integer-in 0 536870911)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (random-seed -1))
         "random-seed"
         "(integer-in 0 536870911)"
         "given: -1")
        (catch-contract/contains?
         (lambda () (random-seed 536870912))
         "random-seed"
         "(integer-in 0 536870911)"
         "given: 536870912")))
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
              (void? (random-seed 536870911))
              (let ([v (random 536870911)])
                (and (exact-integer? v) (>= v 0) (< v 536870911)))
              (let ([v (random 536870911 g)])
                (and (exact-integer? v) (>= v 0) (< v 536870911)))
              (let ([v (flrandom)])
                (and (flonum? v) (> v 0.0) (< v 1.0)))
              (let ([v (flrandom g)])
                (and (flonum? v) (> v 0.0) (< v 1.0)))))))
