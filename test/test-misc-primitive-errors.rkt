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

(define (catch-unsupported/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:unsupported?
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
 (list "s-exp->fasl unsupported values are catchable"
       (catch-unsupported/contains?
        (lambda () (s-exp->fasl (lambda (x) x)))
        "s-exp->fasl"
        "unsupported value"))
 (list "s-exp->fasl unsupported values use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(procedure? v) "CUSTOM-PROCEDURE"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (catch-unsupported/contains?
                    (lambda () (s-exp->fasl (lambda (x) x)))
                    "s-exp->fasl"
                    "unsupported value"
                    "CUSTOM-PROCEDURE")])
           (error-value->string-handler old)
           ok)))
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
 (list "internal boxed accessor and mutation argument errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (unboxed 42))
         "unboxed"
         "boxed?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (set-boxed! 42 'value))
         "set-boxed!"
         "boxed?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (initialize-boxed! 42 'value))
         "initialize-boxed!"
         "boxed?"
         "given: 42")))
 (list "misc primitive success cases still work"
       (let ([b (boxed 'old)])
         (and (equal? (first '(a b c)) 'a)
              (equal? (last '(a b c)) 'c)
              (equal? (string-replace "aaa" "a" "b" #f) "baa")
              (equal? (string-replace "aaa" "a" "b" #t) "bbb")
              (equal? (fasl->s-exp (s-exp->fasl '(1 . 2))) '(1 . 2))
              (boxed? b)
              (void? (set-boxed! b 'new))
              (equal? (unboxed b) 'new)
              (void? (initialize-boxed! b 'initialized))
              (equal? (unboxed b) 'initialized)))))
