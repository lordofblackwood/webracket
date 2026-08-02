;; Focused no-stdlib generated-output checks for byte comparison errors.
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
 (list "byte comparison contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (bytes=? 42 #"a"))
                     "bytes=?"
                     "bytes?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (bytes<? #"a" 42))
                     "bytes<?"
                     "bytes?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (bytes>? 42 #"a"))
                     "bytes>?"
                     "bytes?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "byte comparison basics still work"
       (and (equal? (bytes=? #"a" #"a") #t)
            (equal? (bytes=? #"a" #"b") #f)
            (equal? (bytes<? #"a" #"b") #t)
            (equal? (bytes>? #"b" #"a") #t))))
