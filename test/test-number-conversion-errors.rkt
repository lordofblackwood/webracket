;; Focused no-stdlib generated-output checks for number conversion errors.
;;
;; Compile this file with `--no-stdlib`.

(list
 (list "number->string errors are catchable with who"
       (let ([catch-contract/who+expected+given?
              (lambda (expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "number->string")
                       (string-contains? message expected)
                       (string-contains? message given))))])
         (and
          (catch-contract/who+expected+given?
           "number?"
           "given: #f"
           (lambda () (number->string #f)))
          (catch-contract/who+expected+given?
           "(or/c 2 8 10 16)"
           "given: 3"
           (lambda () (number->string 1 3))))))
 (list "string->number errors are catchable with who"
       (let ([catch-contract/who+expected+given?
              (lambda (expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "string->number")
                       (string-contains? message expected)
                       (string-contains? message given))))])
         (and
          (catch-contract/who+expected+given?
           "string?"
           "given: 42"
           (lambda () (string->number 42)))
          (catch-contract/who+expected+given?
           "(integer-in 2 16)"
           "given: #f"
           (lambda () (string->number "1" #f)))
          (catch-contract/who+expected+given?
           "(integer-in 2 16)"
           "given: 1"
           (lambda () (string->number "1" 1)))
          (catch-contract/who+expected+given?
           "(integer-in 2 16)"
           "given: 17"
           (lambda () (string->number "1" 17))))))
 (list "number conversion basics still work"
       (and (equal? (number->string 42) "42")
            (equal? (number->string 16 16) "10")
            (equal? (number->string 1.25) "1.25")
            (equal? (string->number "42") 42)
            (equal? (string->number "111" 7) 57)
            (equal? (string->number ".") #f))))
