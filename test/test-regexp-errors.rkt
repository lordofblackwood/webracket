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

(list
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
 (list "byte regexp constructor success cases still work"
       (list "byte-regexp constructs byte-regexp?"
             (byte-regexp? (byte-regexp #"a")))
       (list "byte-pregexp constructs byte-pregexp?"
             (byte-pregexp? (byte-pregexp #"a")))
       (list "byte-regexp matching positive case"
             (regexp-match? (byte-regexp #"a") #"cat"))
       (list "byte-regexp matching negative case"
             (not (regexp-match? (byte-regexp #"z") #"cat")))))
