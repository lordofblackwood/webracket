;; Focused no-stdlib generated-output checks for vector constructor errors.
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
 (list "make-vector length errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (make-vector #f))
         "make-vector"
         "valid-vector-length?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-vector -1))
         "make-vector"
         "valid-vector-length?"
         "given: -1")))
 (list "build-vector length errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (build-vector #f values))
         "build-vector"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (build-vector -1 values))
         "build-vector"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "build-vector procedure errors are catchable with who"
       (catch-contract/contains?
        (lambda () (build-vector 1 #f))
        "build-vector"
        "(exact-nonnegative-integer? . -> . any/c)"
        "given: #f"))
 (list "vector constructors still work"
       (and (equal? (make-vector 3 'x) '#(x x x))
            (equal? (build-vector 3 values) '#(0 1 2)))))
