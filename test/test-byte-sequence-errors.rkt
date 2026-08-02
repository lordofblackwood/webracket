;; Focused no-stdlib generated-output checks for byte-string sequence errors.
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
 (list "bytes-append reports per-argument byte-string contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes-append 'bad))
         "bytes-append"
         "expected: bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-append #"a" 'bad))
         "bytes-append"
         "expected: bytes?"
         "given: 'bad")))
 (list "bytes-append* reports final-list contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes-append* 'bad))
         "bytes-append*"
         "expected: (listof bytes?)"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-append* (list #"a" 'bad)))
         "bytes-append*"
         "expected: (listof bytes?)"
         "given: '(#\"a\" bad)")
        (catch-contract/contains?
         (lambda () (bytes-append* #"a" #"b" 'bad))
         "bytes-append*"
         "expected: (listof bytes?)"
         "given: 'bad")))
 (list "bytes-append* reports leading byte-string contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes-append* 'bad (list #"c")))
         "bytes-append*"
         "expected: bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-append* #"a" 'bad (list #"c")))
         "bytes-append*"
         "expected: bytes?"
         "given: 'bad")))
 (list "bytes-join reports list and separator contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes-join 'bad #","))
         "bytes-join"
         "expected: (listof bytes?)"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-join (list #"a" 'bad) #","))
         "bytes-join"
         "expected: (listof bytes?)"
         "given: '(#\"a\" bad)")
        (catch-contract/contains?
         (lambda () (bytes-join (list #"a") 'bad))
         "bytes-join"
         "expected: bytes?"
         "given: 'bad")))
 (list "byte list conversion reports public sequence contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes->list 'bad))
         "bytevector->u8-list"
         "expected: bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (list->bytes 'bad))
         "list->bytes"
         "expected: (listof byte?)"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (list->bytes '(1 . 2)))
         "list->bytes"
         "expected: (listof byte?)"
         "given: '(1 . 2)")))
 (list "byte sequence contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(symbol? v) "CUSTOM-SYMBOL"]
              [(list? v) "CUSTOM-LIST"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (bytes-append 'bad))
                     "bytes-append"
                     "expected: bytes?"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (bytes-append* (list #"a" 'bad)))
                     "bytes-append*"
                     "expected: (listof bytes?)"
                     "given: CUSTOM-LIST")
                    (catch-contract/contains?
                     (lambda () (bytes-join (list #"a") 'bad))
                     "bytes-join"
                     "expected: bytes?"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (bytes->list 'bad))
                     "bytevector->u8-list"
                     "expected: bytes?"
                     "given: CUSTOM-SYMBOL"))])
           (error-value->string-handler old)
           ok)))
 (list "byte sequence successes still work"
       (and (equal? (bytes-append #"foo" #"bar") #"foobar")
            (equal? (bytes-append* #"A" #"B" (list #"C" #"D")) #"ABCD")
            (equal? (bytes-join (list #"a" #"b" #"c") #",") #"a,b,c")
            (equal? (bytes->list #"ABC") '(65 66 67))
            (equal? (list->bytes '(65 66 67)) #"ABC"))))
