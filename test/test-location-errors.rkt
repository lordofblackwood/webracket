;; Focused no-stdlib generated-output checks for source-location errors.
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

(define bignum-source-location-index 536870912)

(list
 (list "srcloc constructor field errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (srcloc 'source 0 #f #f #f))
         "srcloc"
         "(or/c exact-positive-integer? #f)"
         "given: 0")
        (catch-contract/contains?
         (lambda () (make-srcloc 'source 1 -1 #f #f))
         "make-srcloc"
         "(or/c exact-nonnegative-integer? #f)"
         "given: -1")))
 (list "srcloc accessors reject non-srclocs with who"
       (and
        (catch-contract/contains?
         (lambda () (srcloc-source 42))
         "srcloc-source"
         "srcloc?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (srcloc-line 42))
         "srcloc-line"
         "srcloc?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (srcloc->string 42))
         "srcloc->string"
         "srcloc?"
         "given: 42")))
 (list "srcloc contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(symbol? v) "CUSTOM-SYMBOL"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (srcloc 'source 'bad #f #f #f))
                     "srcloc"
                     "(or/c exact-positive-integer? #f)"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (make-srcloc 'source 1 -1 #f #f))
                     "make-srcloc"
                     "(or/c exact-nonnegative-integer? #f)"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (srcloc->string 42))
                     "srcloc->string"
                     "srcloc?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "srcloc success cases still work"
       (let ([loc (make-srcloc 'source 3 0 10 5)])
         (and (srcloc? loc)
              (not (srcloc? 42))
              (equal? (srcloc-source loc) 'source)
              (equal? (srcloc-line loc) 3)
              (equal? (srcloc-column loc) 0)
              (equal? (srcloc-position loc) 10)
              (equal? (srcloc-span loc) 5)
              (equal? (srcloc->string loc) "source:3:0"))))
 (list "srcloc accepts bignum source-location fields"
       (let* ([n bignum-source-location-index]
              [loc (make-srcloc 'source n n n n)])
         (and (srcloc? loc)
              (= (srcloc-line loc) n)
              (= (srcloc-column loc) n)
              (= (srcloc-position loc) n)
              (= (srcloc-span loc) n)
              (equal? (srcloc->string loc)
                      "source:536870912:536870912")))))
