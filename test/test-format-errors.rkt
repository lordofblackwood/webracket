;; Focused no-stdlib generated-output checks for format errors.
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
 (list "format string type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (format 42))
        "format"
        "string?"
        "given: 42"))
 (list "fprintf string type errors are catchable with who"
       (catch-contract/contains?
        (lambda ()
          (let ([out (open-output-string)])
            (fprintf out 42)))
        "fprintf"
        "string?"
        "given: 42"))
 (list "format success still works"
       (equal? (format "~a/~s" "x" "y") "x/\"y\"")))
