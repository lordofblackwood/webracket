;; Focused no-stdlib generated-output checks for byte comparison errors.
;;
;; Compile this file with `--no-stdlib`.

(list
 (list "byte comparison errors are catchable with who"
       (let ([catch-contract/who+expected+given?
              (lambda (who thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message "bytes?")
                       (string-contains? message "given: 42"))))])
         (and
          (catch-contract/who+expected+given?
           "bytes=?"
           (lambda () (bytes=? 42 #"a")))
          (catch-contract/who+expected+given?
           "bytes<?"
           (lambda () (bytes<? #"a" 42)))
          (catch-contract/who+expected+given?
           "bytes>?"
           (lambda () (bytes>? 42 #"a")))
          (catch-contract/who+expected+given?
           "bytes=?"
           (lambda () (bytes=? #"a" #"a" 42))))))
 (list "byte comparison basics still work"
       (and (equal? (bytes=? #"a" #"a") #t)
            (equal? (bytes=? #"a" #"b") #f)
            (equal? (bytes<? #"a" #"b") #t)
            (equal? (bytes>? #"b" #"a") #t))))
