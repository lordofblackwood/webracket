;; Focused no-stdlib generated-output checks for build-string errors.
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
 (list "build-string length errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (build-string #f values))
         "build-string"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (build-string -1 values))
         "build-string"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "build-string result errors are catchable with who"
       (catch-contract/contains?
        (lambda () (build-string 1 (lambda (i) 42)))
        "string-set!"
        "char?"
        "given: 42"))
 (list "build-string success still works"
       (equal? (build-string 3 (lambda (i) #\x)) "xxx")))
