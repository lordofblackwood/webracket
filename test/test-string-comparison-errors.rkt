;; Focused no-stdlib generated-output checks for string comparison errors.
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
 (list "string comparison first arguments are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string=? 42 "x"))
                                  "string=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string<? 42 "x"))
                                  "string<?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string<=? 42 "x"))
                                  "string<=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string>? 42 "x"))
                                  "string>?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string>=? 42 "x"))
                                  "string>=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci=? 42 "x"))
                                  "string-ci=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci<? 42 "x"))
                                  "string-ci<?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci<=? 42 "x"))
                                  "string-ci<=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci>? 42 "x"))
                                  "string-ci>?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci>=? 42 "x"))
                                  "string-ci>=?" "string?" "given: 42")))
 (list "string comparison rest arguments are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string=? "x" 42))
                                  "string=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string<? "x" 42))
                                  "string<?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string<=? "x" 42))
                                  "string<=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string>? "x" 42))
                                  "string>?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string>=? "x" 42))
                                  "string>=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci=? "x" 42))
                                  "string-ci=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci<? "x" 42))
                                  "string-ci<?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci<=? "x" 42))
                                  "string-ci<=?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci>? "x" 42))
                                  "string-ci>?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-ci>=? "x" 42))
                                  "string-ci>=?" "string?" "given: 42")))
 (list "string comparison success still works"
       (and (string=? "x" "x" "x")
            (string<? "a" "b" "c")
            (string<=? "a" "b" "b")
            (string>? "c" "b" "a")
            (string>=? "c" "b" "b")
            (string-ci=? "A" "a")
            (string-ci<? "a" "B")
            (string-ci<=? "A" "a")
            (string-ci>? "B" "a")
            (string-ci>=? "A" "a"))))
