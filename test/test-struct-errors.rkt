;; Focused no-stdlib generated-output checks for struct errors.
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
 (list "make-struct-type required argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (make-struct-type 42 #f 1 0))
         "make-struct-type"
         "symbol?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type 'child 42 1 0))
         "make-struct-type"
         "(or/c #f struct-type?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f #f 0))
         "make-struct-type"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f -1 0))
         "make-struct-type"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 #f))
         "make-struct-type"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 -1))
         "make-struct-type"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "make-struct-type-property argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (make-struct-type-property 42))
         "make-struct-type-property"
         "symbol?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p 42))
         "make-struct-type-property"
         "procedure-arity-includes/c 2"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p (lambda (x) x)))
         "make-struct-type-property"
         "procedure-arity-includes/c 2"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p #f (list 42)))
         "make-struct-type-property"
         "listof"
         "struct-type-property?"
         "procedure-arity-includes/c 1"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (let-values ([(prop:p p? p-ref) (make-struct-type-property 'p)])
             (make-struct-type-property 'q #f (list (cons prop:p (lambda (x y) x))))))
         "make-struct-type-property"
         "listof"
         "struct-type-property?"
         "procedure-arity-includes/c 1"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p #f null #f 42))
         "make-struct-type-property"
         "(or/c symbol? #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p #f null #f "x"))
         "make-struct-type-property"
         "(or/c symbol? #f)"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p #f null #f #f 42))
         "make-struct-type-property"
         "(or/c symbol? string? #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type-property 'p #f null #f #f #f 42))
         "make-struct-type-property"
         "symbol?"
         "given: 42")))
 (list "struct field accessor/mutator maker errors are catchable with who"
       (let-values ([(st make-p p? p-ref p-set!) (make-struct-type 'p #f 2 0)])
         (and
          (procedure? (make-struct-field-accessor p-ref 0))
          (procedure? (make-struct-field-mutator p-set! 0))
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor 42 0))
           "make-struct-field-accessor"
           "struct-accessor-procedure?"
           "procedure-arity-includes/c 2"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor (lambda (s i) s) 0))
           "make-struct-field-accessor"
           "struct-accessor-procedure?"
           "procedure-arity-includes/c 2"
           "given:")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref #f))
           "make-struct-field-accessor"
           "exact-nonnegative-integer?"
           "given: #f")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref -1))
           "make-struct-field-accessor"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref 0 42))
           "make-struct-field-accessor"
           "(or/c symbol? #f)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref 0 "x"))
           "make-struct-field-accessor"
           "(or/c symbol? #f)"
           "given:")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref 0 #f 42))
           "make-struct-field-accessor"
           "(or/c symbol? string? #f)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref 0 #f #f 42))
           "make-struct-field-accessor"
           "symbol?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-accessor p-ref 0 #f #f #f))
           "make-struct-field-accessor"
           "symbol?"
           "given: #f")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator 42 0))
           "make-struct-field-mutator"
           "struct-mutator-procedure?"
           "procedure-arity-includes/c 3"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator (lambda (s i v) v) 0))
           "make-struct-field-mutator"
           "struct-mutator-procedure?"
           "procedure-arity-includes/c 3"
           "given:")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! #f))
           "make-struct-field-mutator"
           "exact-nonnegative-integer?"
           "given: #f")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! -1))
           "make-struct-field-mutator"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! 0 42))
           "make-struct-field-mutator"
           "(or/c symbol? #f)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! 0 "x"))
           "make-struct-field-mutator"
           "(or/c symbol? #f)"
           "given:")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! 0 #f 42))
           "make-struct-field-mutator"
           "(or/c symbol? string? #f)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! 0 #f #f 42))
           "make-struct-field-mutator"
           "symbol?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (make-struct-field-mutator p-set! 0 #f #f #f))
           "make-struct-field-mutator"
           "symbol?"
           "given: #f")))))
