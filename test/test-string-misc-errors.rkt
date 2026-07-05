;; Focused no-stdlib generated-output checks for miscellaneous string errors.
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
 (list "string->immutable-string type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (string->immutable-string 42))
        "string->immutable-string"
        "string?"
        "given: 42"))
 (list "string-split string argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-split 42))
         "string-split"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-split "a,b" 42))
         "string-split"
         "string?"
         "given: 42")))
 (list "string-replace string argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-replace 42 "a" "b"))
         "string-replace"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-replace "abc" 42 "b"))
         "string-replace"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-replace "abc" "a" 42))
         "string-replace"
         "string?"
         "given: 42")))
 (list "string->immutable-string success still works"
       (equal? (string->immutable-string "abc") "abc"))
 (list "string-split success still works"
       (equal? (string-split "a b") (list "a" "b")))
 (list "string-replace success still works"
       (equal? (string-replace "banana" "na" "NA") "baNANA")))
