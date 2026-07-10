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
 (list "make-struct-type optional argument errors are catchable with who"
       (and
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'ins-current #f 0 0 #f null 'current)])
          (procedure? make-p))
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'ins-prefab #f 0 0 #f null 'prefab)])
          (procedure? make-p))
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f null 42))
         "make-struct-type"
         "(or/c #f procedure?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null 42))
         "make-struct-type"
         "(or/c inspector? #f 'current 'prefab)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null 'other))
         "make-struct-type"
         "(or/c inspector? #f 'current 'prefab)"
         "other")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f 42))
         "make-struct-type"
         "(listof (cons/c struct-type-property? any/c))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f (list 42)))
         "make-struct-type"
         "(listof (cons/c struct-type-property? any/c))"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f (list (cons 42 1))))
         "make-struct-type"
         "(listof (cons/c struct-type-property? any/c))"
         "given:")))
 (list "make-struct-type immutable and constructor name errors are catchable with who"
       (and
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'named #f 1 0 #f null #f #f null #f 'make-named)])
          (procedure? make-p))
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f #f))
         "make-struct-type"
         "(listof exact-nonnegative-integer?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f 'x))
         "make-struct-type"
         "(listof exact-nonnegative-integer?)"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f (list -1)))
         "make-struct-type"
         "(listof exact-nonnegative-integer?)"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f (list 1)))
         "make-struct-type"
         "index for immutable field"
         "index: 1"
         "initialized-field count: 1")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f null #f 42))
         "make-struct-type"
         "(or/c #f symbol?)"
         "given: 42")))
 (list "make-struct-type procedure spec errors are catchable with who"
       (and
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'proc-index #f 1 0 #f null #f 0)])
          (procedure? make-p))
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'proc-procedure
                                        #f
                                        1
                                        0
                                        #f
                                        null
                                        #f
                                        (lambda (self arg) arg))])
          (procedure? make-p))
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f 'x))
         "make-struct-type"
         "(or/c procedure? exact-nonnegative-integer? #f)"
         "given:")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f -1))
         "make-struct-type"
         "(or/c procedure? exact-nonnegative-integer? #f)"
         "given: -1")
        (catch-contract/contains?
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f 1))
         "make-struct-type"
         "index for procedure"
         "index: 1"
         "field count: 1")))
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
 (list "struct type property predicate procedure property errors are catchable with who"
       (let-values ([(prop:p p? p-ref) (make-struct-type-property 'p)])
         (and
          (struct-type-property-predicate-procedure? p?)
          (struct-type-property-predicate-procedure? p? prop:p)
          (struct-type-property-predicate-procedure? p? #f)
          (catch-contract/contains?
           (lambda () (struct-type-property-predicate-procedure? p? 42))
           "struct-type-property-predicate-procedure?"
           "(or/c struct-type-property? #f)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (struct-type-property-predicate-procedure? 42 42))
           "struct-type-property-predicate-procedure?"
           "(or/c struct-type-property? #f)"
           "given: 42"))))
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
           "given: #f"))))
 (list "generic struct accessor/mutator errors are catchable with who"
       (let-values ([(pst make-p p? p-ref p-set!)
                     (make-struct-type 'p #f 2 0 #f null #f #f (list 1))]
                    [(qst make-q q? q-ref q-set!)
                     (make-struct-type 'q #f 1 0)])
         (let ([p (make-p 10 20)]
               [q (make-q 99)])
           (list
            (= (p-ref p 1) 20)
            (catch-contract/contains?
             (lambda () (p-ref 42 0))
             "p-ref"
             "p?"
             "given: 42")
            (catch-contract/contains?
             (lambda () (p-ref q 0))
             "p-ref"
             "p?")
            (catch-contract/contains?
             (lambda () (p-ref p #f))
             "p-ref"
             "exact-nonnegative-integer?"
             "given: #f")
            (catch-contract/contains?
             (lambda () (p-ref p 2))
             "p-ref"
             "index too large"
             "index: 2"
             "maximum allowed index: 1")
            (let ()
              (p-set! p 0 9)
              (= (p-ref p 0) 9))
            (catch-contract/contains?
             (lambda () (p-set! 42 0 9))
             "p-set!"
             "p?"
             "given: 42")
            (catch-contract/contains?
             (lambda () (p-set! q 0 9))
             "p-set!"
             "p?")
            (catch-contract/contains?
             (lambda () (p-set! p #f 9))
             "p-set!"
             "exact-nonnegative-integer?"
             "given: #f")
            (catch-contract/contains?
             (lambda () (p-set! p 2 9))
             "p-set!"
             "index too large"
             "index: 2"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (p-set! p 1 9))
             "p-set!"
             "cannot modify value of immutable field"
             "field index: 1")))))
 (list "struct field accessor/mutator range and call errors are catchable"
       (let-values ([(pst make-p p? p-ref p-set!)
                     (make-struct-type 'p #f 2 0 #f null #f #f (list 0))]
                    [(zst make-z z? z-ref z-set!)
                     (make-struct-type 'z #f 0 0)])
         (let ([p (make-p 10 20)])
           (list
            (catch-contract/contains?
             (lambda () (make-struct-field-accessor p-ref 2))
             "make-struct-field-accessor"
             "index too large"
             "index: 2"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (make-struct-field-mutator p-set! 2))
             "make-struct-field-mutator"
             "index too large"
             "index: 2"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (make-struct-field-accessor z-ref 0))
             "make-struct-field-accessor"
             "index too large"
             "no fields accessible"
             "index: 0")
            (catch-contract/contains?
             (lambda () (make-struct-field-mutator z-set! 0))
             "make-struct-field-mutator"
             "index too large"
             "no fields accessible"
             "index: 0")
            (let ([set-p-field0! (make-struct-field-mutator p-set! 0)])
              (catch-contract/contains?
               (lambda () (set-p-field0! p 9))
               "set-p-field0!"
               "cannot modify value of immutable field"
               "field index: 0")))))))
