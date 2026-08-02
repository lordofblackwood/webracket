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
 (list "string prefix/suffix/contains first arguments are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string-prefix? 42 "x"))
                                  "string-prefix?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-suffix? 42 "x"))
                                  "string-suffix?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-contains? 42 "x"))
                                  "string-contains?" "string?" "given: 42")))
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
 (list "string prefix/suffix/contains second arguments are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string-prefix? "x" 42))
                                  "string-prefix?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-suffix? "x" 42))
                                  "string-suffix?" "string?" "given: 42")
        (catch-contract/contains? (lambda () (string-contains? "x" 42))
                                  "string-contains?" "string?" "given: 42")))
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
            (string-ci>=? "A" "a")))
 (list "string prefix/suffix/contains success still works"
       (and (string-prefix? "alphabet" "alpha")
            (string-suffix? "alphabet" "bet")
            (string-contains? "alphabet" "ph")
            (not (string-contains? "alphabet" "zz")))))
