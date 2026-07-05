;; Focused no-stdlib generated-output checks for string constructor errors.
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
 (list "string constructor direct errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string 42))
                                  "string" "char?" "given: 42")
        (catch-contract/contains? (lambda () (string #\a 42))
                                  "string" "char?" "given: 42")))
 (list "string constructor apply errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (apply string (list 42)))
                                  "string" "char?" "given: 42")
        (catch-contract/contains? (lambda () (apply string (list #\a 42)))
                                  "string" "char?" "given: 42")))
 (list "string constructor success still works"
       (and (equal? (string) "")
            (equal? (string #\a #\b #\c) "abc")
            (equal? (apply string (list #\x #\y)) "xy"))))
