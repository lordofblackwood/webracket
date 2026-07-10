;; Focused no-stdlib generated-output checks for character errors.
;;
;; Compile this file with `--no-stdlib`.

(list
 (list "integer->char errors are catchable with who"
       (let ([catch-contract/who+expected+given?
              (lambda (expected-given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "integer->char")
                       (string-contains? message "valid-unicode-scalar-value?")
                       (string-contains? message expected-given))))])
         (and
          (catch-contract/who+expected+given?
           "given: #f"
           (lambda () (integer->char #f)))
          (catch-contract/who+expected+given?
           "given: 1114112"
           (lambda () (integer->char #x110000)))
          (catch-contract/who+expected+given?
           "given: 55296"
           (lambda () (integer->char #xD800))))))
 (list "character predicate errors are catchable with who"
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
                       (string-contains? message "char?")
                       (string-contains? message "given: 42"))))])
         (and
          (catch-contract/who+expected+given?
           "char-alphabetic?"
           (lambda () (char-alphabetic? 42)))
          (catch-contract/who+expected+given?
           "char-blank?"
           (lambda () (char-blank? 42)))
          (catch-contract/who+expected+given?
           "char-general-category"
           (lambda () (char-general-category 42))))))
 (list "character comparison errors are catchable with who"
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
                       (string-contains? message "char?")
                       (string-contains? message "given: 42"))))])
         (and
          (catch-contract/who+expected+given?
           "char=?"
           (lambda () (char=? #\a 42)))
          (catch-contract/who+expected+given?
           "char-ci<?"
           (lambda () (char-ci<? #\a 42))))))
 (list "char-grapheme-step state errors are catchable with who"
       (let ([message
              (with-handlers ([exn:fail:contract?
                               (lambda (exn)
                                 (exn-message exn))])
                (char-grapheme-step #\a #f)
                #f)])
         (and message
              (string-contains? message "char-grapheme-step")
              (string-contains? message "grapheme-cluster-state?")
              (string-contains? message "given: #f")))))
