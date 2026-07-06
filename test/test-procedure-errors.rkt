;; Focused no-stdlib generated-output checks for procedure reflection errors.
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
 (list "procedure-arity-includes? k errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (procedure-arity-includes? add1 'x))
         "procedure-arity-includes?"
         "exact-nonnegative-integer?"
         "given:"
         "x")
        (catch-contract/contains?
         (lambda () (procedure-arity-includes? add1 #f))
         "procedure-arity-includes?"
         "exact-nonnegative-integer?"
         "given: #f")))
 (list "procedure-arity-includes? procedure errors are catchable"
       (catch-contract/contains?
        (lambda () (procedure-arity-includes? 42 1))
        "procedure-arity-includes?"
        "procedure?"
        "given: 42"))
 (list "primitive-result-arity procedure errors are catchable"
       (catch-contract/contains?
        (lambda () (primitive-result-arity 42))
        "primitive-result-arity"
        "primitive?"
        "given: 42")))
