;; Focused no-stdlib generated-output checks for miscellaneous primitive errors.
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
 (list "ordinal list accessors check non-empty lists"
       (and
        (catch-contract/contains?
         (lambda () (first '()))
         "first"
         "(and/c list? (not/c empty?))"
         "given: '()")
        (catch-contract/contains?
         (lambda () (first 42))
         "first"
         "(and/c list? (not/c empty?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (last '()))
         "last"
         "(and/c list? (not/c empty?))"
         "given: '()")
        (catch-contract/contains?
         (lambda () (last 42))
         "last"
         "(and/c list? (not/c empty?))"
         "given: 42")))
 (list "string-replace all? errors are catchable"
       (catch-contract/contains?
        (lambda () (string-replace "aaa" "a" "b" 'bad))
        "string-replace"
        "boolean?"
        "given: 'bad"))
 (list "fasl->s-exp input errors are catchable"
       (catch-contract/contains?
        (lambda () (fasl->s-exp 42))
        "fasl->s-exp"
        "(or/c bytes? input-port?)"
        "given: 42"))
 (list "external conversion argument errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (external-number->flonum 42))
         "external-number->flonum"
         "external?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (external-string->string "x"))
         "external-string->string"
         "external?"
         "given: \"x\"")))
 (list "keyword contract errors print symbolic values"
       (and
        (catch-contract/contains?
         (lambda () (keyword<? '#:a 'bad))
         "keyword<?"
         "keyword?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (keyword<? '#:a "bad"))
         "keyword<?"
         "keyword?"
         "given: \"bad\"")))
 (list "misc primitive success cases still work"
       (and (equal? (first '(a b c)) 'a)
            (equal? (last '(a b c)) 'c)
            (equal? (string-replace "aaa" "a" "b" #f) "baa")
            (equal? (string-replace "aaa" "a" "b" #t) "bbb")
            (equal? (fasl->s-exp (s-exp->fasl '(1 . 2))) '(1 . 2)))))
