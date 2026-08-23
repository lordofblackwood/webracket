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

(struct struct-plain ())
(struct struct-writable ()
  #:property prop:custom-write
  (lambda (_self out _mode)
    (display "writable" out)))

(define (struct-plain-given)
  (struct-plain))

(define too-large-struct-index 536870912)

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
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f #f null (struct-plain-given)))
         "make-struct-type"
         "(or/c #f procedure?)"
         "given:")
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
         (lambda () (make-struct-type 'bad #f 1 0 #f null #f (struct-plain-given)))
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
         (lambda () (make-struct-type-property 'p (struct-plain-given)))
         "make-struct-type-property"
         "procedure-arity-includes/c 2"
         "given:")
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
         (lambda ()
           (let-values ([(prop:p p? p-ref) (make-struct-type-property 'p)])
             (make-struct-type-property 'q #f (list (cons prop:p (struct-plain-given))))))
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
 (list "built-in struct property guards are catchable with who"
       (and
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'procedure-prop
                                        #f
                                        1
                                        0
                                        #f
                                        (list (cons prop:procedure
                                                    (lambda (self arg) arg))))])
          (procedure? make-p))
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'equal-hash-prop
                                        #f
                                        0
                                        0
                                        #f
                                        (list (cons prop:equal+hash
                                                    (list
                                                     (lambda (self other recur)
                                                       #t)
                                                     (lambda (self recur)
                                                       0)
                                               (lambda (self recur)
                                                 0)))))])
          (procedure? make-p))
        (let-values ([(st make-p p? p-ref p-set!)
                      (make-struct-type 'checked-prop
                                        #f
                                        2
                                        0
                                        #f
                                        (list (cons prop:checked-procedure
                                                    #t)))])
          (procedure? make-p))
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:checked-procedure #t))))
         "prop:checked-procedure"
         "need at least two fields in the structure type")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 1 0 #f
                             (list (cons prop:checked-procedure #t))))
         "prop:checked-procedure"
         "need at least two fields in the structure type")
        (catch-contract/contains?
         (lambda ()
           (let-values ([(pst make-p p? p-ref p-set!)
                         (make-struct-type 'parent #f 2 0)])
             (make-struct-type 'child pst 0 0 #f
                               (list (cons prop:checked-procedure #t)))))
         "prop:checked-procedure"
         "not allowed on a structure type with a supertype")
        (equal? (format "~a" (struct-writable)) "writable")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:custom-write
                                         (struct-plain-given)))))
         "guard-for-prop:custom-write"
         "(procedure-arity-includes?/c 3)"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:custom-write
                                         (lambda (a b) (void))))))
         "guard-for-prop:custom-write"
         "(procedure-arity-includes?/c 3)"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:object-name
                                         (struct-plain-given)))))
         "guard-for-prop:object-name"
         "(or/c exact-nonnegative-integer? (procedure-arity-includes/c 1))"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:object-name
                                         (lambda (a b) 'bad)))))
         "guard-for-prop:object-name"
         "(or/c exact-nonnegative-integer? (procedure-arity-includes/c 1))"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:object-name 1))))
         "guard-for-prop:object-name"
         "field index >= initialized-field count"
         "field index: 1"
         "initialized-field count: 0")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:procedure
                                         (struct-plain-given)))))
         "make-struct-type"
         "(or/c procedure? exact-nonnegative-integer?)"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:procedure 1))))
         "make-struct-type"
         "index for procedure"
         "index: 1"
         "field count: 0")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:equal+hash
                                         (struct-plain-given)))))
         "guard-for-prop:equal+hash"
         "procedure-arity-includes/c 4"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:equal+hash
                                         (list (lambda (self other recur equal?)
                                                 #t))))))
         "guard-for-prop:equal+hash"
         "procedure-arity-includes/c 4"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:equal+hash
                                         (list (lambda (self other recur equal?)
                                                 #t)
                                               42)))))
         "guard-for-prop:equal+hash"
         "procedure-arity-includes/c 4"
         "given:")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'bad #f 0 0 #f
                             (list (cons prop:equal+hash
                                         (list (lambda (self) #t)
                                               (lambda (self recur) 0)
                                               (lambda (self recur) 0))))))
         "guard-for-prop:equal+hash"
         "procedure-arity-includes/c 4"
         "given:")))
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
 (list "checked-procedure extraction errors are catchable"
       (let ()
         (struct checked (ok proc)
           #:property prop:checked-procedure #t)
         (define (fallback v kws argc)
           (list 'fallback v kws argc))
         (define accepted-non-proc
           (checked (lambda (kws argc) #t) 42))
         (define rejected-non-proc
           (checked (lambda (kws argc) #f) 42))
         (and
          (catch-contract/contains?
           (lambda () (checked-procedure-check-and-extract 42 1 fallback null 0))
           "checked-procedure-check-and-extract"
           "struct-type?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (checked-procedure-check-and-extract struct:checked 1 42 null 0))
           "checked-procedure-check-and-extract"
           "procedure?"
           "given: 42")
          (catch-contract/contains?
           (lambda ()
             (checked-procedure-check-and-extract
              struct:checked
              (checked 42 (lambda args args))
              fallback
              null
              0))
           "application: not a procedure"
           "given: 42")
          (equal? (checked-procedure-check-and-extract
                   struct:checked
                   accepted-non-proc
                   fallback
                   null
                   0)
                  42)
          (equal? (checked-procedure-check-and-extract
                   struct:checked
                   rejected-non-proc
                   fallback
                   null
                   0)
                  (list 'fallback rejected-non-proc null 0)))))
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
            (catch-contract/contains?
             (lambda () (p-ref p too-large-struct-index))
             "p-ref"
             "index too large"
             "index: 536870912"
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
             (lambda () (p-set! p too-large-struct-index 9))
             "p-set!"
             "index too large"
             "index: 536870912"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (p-set! p 1 9))
             "p-set!"
             "cannot modify value of immutable field"
             "field index: 1")))))
 (list "struct field accessor/mutator range and call errors are catchable"
       (let-values ([(pst make-p p? p-ref p-set!)
                     (make-struct-type 'p #f 2 0 #f null #f #f (list 0))]
                    [(qst make-q q? q-ref q-set!)
                     (make-struct-type 'q #f 1 0)]
                    [(zst make-z z? z-ref z-set!)
                     (make-struct-type 'z #f 0 0)])
         (let ([p (make-p 10 20)]
               [q (make-q 99)])
           (list
            (catch-contract/contains?
             (lambda () (make-struct-field-accessor p-ref 2))
             "make-struct-field-accessor"
             "index too large"
             "index: 2"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (make-struct-field-accessor p-ref too-large-struct-index))
             "make-struct-field-accessor"
             "index too large"
             "index: 536870912"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (make-struct-field-mutator p-set! 2))
             "make-struct-field-mutator"
             "index too large"
             "index: 2"
             "maximum allowed index: 1")
            (catch-contract/contains?
             (lambda () (make-struct-field-mutator p-set! too-large-struct-index))
             "make-struct-field-mutator"
             "index too large"
             "index: 536870912"
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
            (let ([p-field0 (make-struct-field-accessor p-ref 0)])
              (list
               (= (p-field0 p) 10)
               (catch-contract/contains?
                (lambda () (p-field0 42))
                "p-field0"
                "p?"
                "given: 42")
               (catch-contract/contains?
                (lambda () (p-field0 q))
                "p-field0"
                "p?")))
            (let ([field (make-struct-field-accessor p-ref 0 'field "custom-contract")])
              (catch-contract/contains?
               (lambda () (field 42))
               "field"
               "custom-contract"
               "given: 42"))
            (let ([field (make-struct-field-accessor p-ref 0 'field 'contract-symbol)])
              (catch-contract/contains?
               (lambda () (field 42))
               "field"
               "contract-symbol"
               "given: 42"))
            (let ([accessor (make-struct-field-accessor p-ref 0 #f "custom-contract")])
              (catch-contract/contains?
               (lambda () (accessor 42))
               "accessor"
               "custom-contract"
               "given: 42"))
            (let ([set-p-field1! (make-struct-field-mutator p-set! 1)])
              (list
               (begin
                 (set-p-field1! p 30)
                 (= (p-ref p 1) 30))
               (catch-contract/contains?
                (lambda () (set-p-field1! 42 9))
                "set-p-field1!"
                "p?"
                "given: 42")
               (catch-contract/contains?
                (lambda () (set-p-field1! q 9))
                "set-p-field1!"
                "p?")))
            (let ([field (make-struct-field-mutator p-set! 1 'field "custom-contract")])
              (catch-contract/contains?
               (lambda () (field 42 9))
               "field"
               "custom-contract"
               "given: 42"))
            (let ([field (make-struct-field-mutator p-set! 1 'field 'contract-symbol)])
              (catch-contract/contains?
               (lambda () (field 42 9))
               "field"
               "contract-symbol"
               "given: 42"))
            (let ([mutator (make-struct-field-mutator p-set! 1 #f "custom-contract")])
              (catch-contract/contains?
               (lambda () (mutator 42 9))
               "mutator"
               "custom-contract"
               "given: 42"))
            (let ([set-p-field0! (make-struct-field-mutator p-set! 0)])
              (catch-contract/contains?
               (lambda () (set-p-field0! p 9))
               "set-p-field0!"
               "cannot modify value of immutable field"
               "field index: 0"))))))
 (list "prefab struct public errors are catchable with who"
       (and
        (prefab-key? '(prefab-ok 0 (0 #f) #()))
        (let ([p (make-prefab-struct '(prefab-ok 1 (0 #f) #()) 10)])
          (eq? (prefab-struct-key p) 'prefab-ok))
        (equal? (prefab-struct-key 42) #f)
        (catch-contract/contains?
         (lambda () (make-prefab-struct 42))
         "make-prefab-struct"
         "supported simple prefab key"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-prefab-struct '(bad 1)))
         "make-prefab-struct"
         "supported simple prefab key"
         "given:")
        (catch-contract/contains?
         (lambda () (make-prefab-struct '(bad 3 (0 #f) #()) 1 2))
         "make-prefab-struct"
         "supported simple prefab key"
         "given:")
        (catch-contract/contains?
         (lambda () (make-prefab-struct '(child parent 3) 1 2))
         "make-prefab-struct"
         "supported simple prefab key"
         "given:")
        (catch-contract/contains?
         (lambda () (prefab-struct-type-key+field-count 42))
         "prefab-struct-type-key+field-count"
         "struct-type?"
         "given: 42")
        (let-values ([(pst make-p p? p-ref p-set!)
                      (make-struct-type 'prefab-parent #f 0 0)])
          (catch-contract/contains?
           (lambda () (make-struct-type 'prefab-child pst 0 0 #f null 'prefab))
           "make-struct-type"
           "generative supertype disallowed for non-generative structure type"
           "structure type name: 'prefab-child"))
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'prefab-with-property
                             #f
                             0
                             0
                             #f
                             (list (cons prop:custom-write
                                         (lambda (_self _out _mode) (void))))
                             'prefab))
         "make-struct-type"
         "properties disallowed for non-generative structure type"
         "structure type name: 'prefab-with-property")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'prefab-with-proc-spec
                             #f
                             0
                             0
                             #f
                             null
                             'prefab
                             (lambda (_self) (void))))
         "make-struct-type"
         "procedure specification disallowed for non-generative structure type"
         "structure type name: 'prefab-with-proc-spec")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'prefab-with-guard
                             #f
                             0
                             0
                             #f
                             null
                             'prefab
                             #f
                             null
                             (lambda args args)))
         "make-struct-type"
         "guard disallowed for non-generative structure type"
         "structure type name: 'prefab-with-guard")
        (catch-contract/contains?
         (lambda ()
           (make-struct-type 'prefab-with-auto
                             #f
                             0
                             1
                             (lambda (x) x)
                             null
                             'prefab))
         "make-struct-type"
         "unsupported simple prefab auto value"
         "structure type name: 'prefab-with-auto"))))
