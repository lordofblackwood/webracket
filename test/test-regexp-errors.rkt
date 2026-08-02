;; Focused no-stdlib generated-output checks for regexp constructor errors.
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

(struct regexp-plain ())

(define regexp-plain-given "given: #(struct regexp-plain)")

(list
 (list "regexp constructors reject non-strings with who"
       (and
        (catch-contract/contains?
         (lambda () (regexp 42))
         "regexp: contract violation"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (pregexp 42))
         "pregexp: contract violation"
         "string?"
         "given: 42")))
 (list "byte regexp constructors reject non-bytes with who"
       (and
        (catch-contract/contains?
         (lambda () (byte-regexp 42))
         "byte-regexp"
         "bytes?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (byte-pregexp 42))
         "byte-pregexp"
         "bytes?"
         "given: 42")))
 (list "literal regexp constructors reject bad source types with constructor who"
       (and
        (catch-contract/contains?
         (lambda () (webracket-literal-regexp 42))
         "regexp"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (webracket-literal-pregexp 42))
         "pregexp"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (webracket-literal-byte-regexp 42))
         "byte-regexp"
         "bytes?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (webracket-literal-byte-pregexp 42))
         "byte-pregexp"
         "bytes?"
         "given: 42")))
 (list "regexp-replace rejects bad argument types with who"
       (and
        (catch-contract/contains?
         (lambda () (regexp-replace 42 "abc" "x"))
         "regexp-replace"
         "(or/c regexp? byte-regexp? string? bytes?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-replace #rx"a" 42 "x"))
         "regexp-replace"
         "(or/c string? bytes?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-replace #rx"a" "abc" 42))
         "regexp-replace"
         "(or/c string? bytes? procedure?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-replace #rx"a" "abc" (regexp-plain)))
         "regexp-replace"
         "(or/c string? bytes? procedure?)"
         regexp-plain-given)
        (catch-contract/contains?
         (lambda () (regexp-replace #rx"a" "abc" "x" 42))
         "regexp-replace"
         "bytes?"
         "given: 42")))
 (list "regexp-replace* rejects bad required argument types with who"
       (and
        (catch-contract/contains?
         (lambda () (regexp-replace* 42 "abc" "x"))
         "regexp-replace*"
         "(or/c regexp? byte-regexp? string? bytes?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-replace* #rx"a" 42 "x"))
         "regexp-replace*"
         "(or/c string? bytes?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-replace* #rx"a" "abc" 42))
         "regexp-replace*"
         "(or/c string? bytes? procedure?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-replace* #rx"a" "abc" (regexp-plain)))
         "regexp-replace*"
         "(or/c string? bytes? procedure?)"
         regexp-plain-given)))
 (list "regexp-match rejects bad argument types with who"
       (and
        (catch-contract/contains?
         (lambda () (regexp-match 42 #"abc"))
         "regexp-match: contract violation"
         "(or/c regexp? byte-regexp? string? bytes?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-match #rx"a" 42))
         "regexp-match: contract violation"
         "(or/c string? bytes? path? input-port?)"
         "given: 42")))
 (list "regexp-match? rejects bad argument types with who"
       (and
        (catch-contract/contains?
         (lambda () (regexp-match? 42 "abc"))
         "regexp-match?: contract violation"
         "(or/c regexp? byte-regexp? string? bytes?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (regexp-match? #rx"a" 42))
         "regexp-match?: contract violation"
         "(or/c string? bytes? path? input-port?)"
         "given: 42")))
 (list "byte regexp constructor success cases still work"
       (list "byte-regexp constructs byte-regexp?"
             (byte-regexp? (byte-regexp #"a")))
       (list "byte-pregexp constructs byte-pregexp?"
             (byte-pregexp? (byte-pregexp #"a")))
       (list "byte-regexp matching positive case"
             (regexp-match? (byte-regexp #"a") #"cat"))
       (list "byte-regexp matching negative case"
             (not (regexp-match? (byte-regexp #"z") #"cat")))
       (list "regexp replacement subset still works"
             (and (equal? (regexp-replace #rx"a" "banana" "A") "bAnana")
                  (equal? (regexp-replace* #rx"a" "banana" "A") "bAnAnA")))))
