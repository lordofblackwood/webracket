;; Focused no-stdlib generated-output checks for string-copy! errors.
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

(define too-large-string-index 536870912)

(list
 (list "string-copy! argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-copy! 42 0 "abc"))
         "string-copy!"
         "(and/c string? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) #f "abc"))
         "string-copy!"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) -1 "abc"))
         "string-copy!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) 0 42))
         "string-copy!"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) 0 "abc" #f))
         "string-copy!"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) 0 "abc" 0 #f))
         "string-copy!"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (string-copy! "abc" 0 "x"))
         "string-copy!"
         "(and/c string? (not/c immutable?))")))
 (list "string-copy! range errors are catchable with details"
       (and
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 5 #\_) 0 "abc" 4))
         "string-copy!"
         "starting index is out of range"
         "starting index: 4"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 5 #\_) 0 "abc" 2 1))
         "string-copy!"
         "ending index is smaller than starting index"
         "ending index: 1"
         "starting index: 2")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 5 #\_) 0 "abc" 0 4))
         "string-copy!"
         "ending index is out of range"
         "ending index: 4"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 5 #\_) 6 "abc"))
         "string-copy!"
         "starting index is out of range"
         "starting index: 6"
         "valid range: [0, 5]")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) 0 "abc" 0 2))
         "string-copy!"
         "not enough room in target string"
         "target length: 1"
         "needed length: 2")))
 (list "string-copy! bignum range errors are catchable with details"
       (and
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 1 #\_) too-large-string-index "abc"))
         "string-copy!"
         "starting index is out of range"
         "valid range: [0, 1]"
         "string: \"_\"")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 5 #\_) 0 "abc" too-large-string-index))
         "string-copy!"
         "starting index is out of range"
         "valid range: [0, 3]"
         "string: \"abc\"")
        (catch-contract/contains?
         (lambda () (string-copy! (make-string 5 #\_) 0 "abc" 0 too-large-string-index))
         "string-copy!"
         "ending index is out of range"
         "valid range: [0, 3]"
         "string: \"abc\"")))
 (list "string-copy! success still works"
       (let ([s (make-string 5 #\_)])
         (string-copy! s 1 "abc" 1 3)
         (equal? s "_bc__"))))
