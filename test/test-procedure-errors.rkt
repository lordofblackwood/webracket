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

(struct procedure-plain ())

(define (procedure-plain-given)
  (procedure-plain))

(list
 (list "procedure reflection errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (procedure-specialize 42))
         "procedure-specialize"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (procedure-extract-target 42))
         "procedure-extract-target"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (procedure-reduce-arity 42 1))
         "procedure-reduce-arity"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (procedure-reduce-arity-mask 42 2))
         "procedure-reduce-arity-mask"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (procedure-arity 42))
         "procedure-arity"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (procedure-result-arity 42))
         "procedure-result-arity"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (procedure-arity-mask 42))
         "procedure-arity-mask"
         "procedure?"
         "given: 42")))
 (list "procedure-valued reflection rejects plain structs as non-procedures"
       (and
        (catch-contract/contains?
         (lambda () (procedure-specialize (procedure-plain-given)))
         "procedure-specialize"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (procedure-extract-target (procedure-plain-given)))
         "procedure-extract-target"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (procedure-reduce-arity (procedure-plain-given) 1))
         "procedure-reduce-arity"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (procedure-reduce-arity-mask (procedure-plain-given) 2))
         "procedure-reduce-arity-mask"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (procedure-result-arity (procedure-plain-given)))
         "procedure-result-arity"
         "procedure?"
         "given:")))
 (list "procedure arity queries treat plain structs as accepting no arguments"
       (and
        (equal? (procedure-arity (procedure-plain-given)) '())
        (equal? (procedure-arity-mask (procedure-plain-given)) 0)
        (equal? (procedure-arity-includes? (procedure-plain-given) 0) #f)
        (equal? (procedure-arity-includes? (procedure-plain-given) 1) #f)
        (catch-contract/contains?
         (lambda () (procedure-arity-includes? (procedure-plain-given) 'x))
         "procedure-arity-includes?"
         "exact-nonnegative-integer?"
         "given:"
         "x")))
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
        "given: 42"))
 (list "procedure composition errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (compose 42))
         "compose"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (compose1 42))
         "compose1"
         "procedure?"
         "given: 42")))
 (list "procedure composition rejects plain structs as non-procedures"
       (and
        (catch-contract/contains?
         (lambda () (compose (procedure-plain-given)))
         "compose"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (compose1 (procedure-plain-given)))
         "compose1"
         "procedure?"
         "given:")))
 (list "apply non-procedure errors match application errors"
       (catch-contract/contains?
        (lambda () (apply 42 '(1 2)))
        "application: not a procedure"
        "expected a procedure that can be applied to arguments"
        "given: 42"))
 (list "apply final argument errors print non-list values"
       (and
        (catch-contract/contains?
         (lambda () (apply + 1 2 "x"))
         "apply"
         "list?"
         "given: \"x\"")
        (catch-contract/contains?
         (lambda () (apply + 1 2 'bad))
         "apply"
         "list?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (apply + 1 2 (cons 3 4)))
         "apply"
         "list?"
         "given: '(3 . 4)"))))
