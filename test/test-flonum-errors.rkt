;; Focused no-stdlib generated-output checks for flonum errors.
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
 (list "flonum arithmetic errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (fl+ 1 2.0))
         "fl+"
         "flonum?"
         "given: 1")
        (catch-contract/contains?
         (lambda () (fl- 1.0 2))
         "fl-"
         "flonum?"
         "given: 2")
        (catch-contract/contains?
         (lambda () (fl* #f 2.0))
         "fl*"
         "flonum?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (fl/ 1.0 #f))
         "fl/"
         "flonum?"
         "given: #f")))
 (list "flonum conversion errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (->fl #f))
         "->fl"
         "exact-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (fl->fx #f))
         "fl->fx"
         "flonum?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (fl->fx +nan.0))
         "fl->fx"
         "outside of fixnum range")
        (catch-contract/contains?
         (lambda () (fl->exact-integer #f))
         "fl->exact-integer"
         "(and/c flonum? integer?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (fl->exact-integer 1.5))
         "fl->exact-integer"
         "(and/c flonum? integer?)"
         "given: 1.5")))
 (list "flonum math errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (flsin #f))
         "flsin"
         "flonum?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (flexpt 2.0 #f))
         "flexpt"
         "flonum?"
         "given: #f")))
 (list "flbit-field rejects non-flonums with who"
       (catch-contract/contains?
        (lambda () (flbit-field 1 0 1))
        "flbit-field"
        "flonum?"
        "given: 1"))
 (list "flbit-field start errors preserve public contract"
       (and
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 #f 1))
         "flbit-field"
         "(integer-in 0 64)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 -1 1))
         "flbit-field"
         "(integer-in 0 64)"
         "given: -1")))
 (list "flbit-field end errors preserve public contract"
       (and
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 0 #f))
         "flbit-field"
         "(integer-in 0 64)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 0 -1))
         "flbit-field"
         "(integer-in 0 64)"
         "given: -1")))
 (list "flbit-field range errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 65 66))
         "flbit-field"
         "(integer-in 0 64)"
         "given: 65")
        (catch-contract/contains?
         (lambda () (flbit-field 1.0 2 1))
         "flbit-field"
         "start must be <= end")))
 (list "flbit-field success still works"
       (and (equal? (flbit-field 1.0 0 1) 0)
            (equal? (flbit-field 1.0 52 63) 1023))))
