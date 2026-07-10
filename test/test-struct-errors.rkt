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
         "given: -1"))))
