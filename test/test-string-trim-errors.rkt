;; Focused no-stdlib generated-output checks for string-trim errors.
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
 (list "string-trim argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-trim 42))
         "string-trim"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-trim " abc " 42))
         "string-trim"
         "(or/c string? regexp?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-trim "xxabxx" #\x))
         "string-trim"
         "(or/c string? regexp?)"
         "given: #\\x")))
 (list "string-trim success still works"
       (and (equal? (string-trim "  alpha  ") "alpha")
            (equal? (string-trim "xxalphaxx" "xx") "alpha"))))
