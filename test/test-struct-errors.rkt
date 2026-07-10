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
         "given: 42"))))
