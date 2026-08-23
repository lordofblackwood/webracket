;; Focused no-stdlib generated-output checks for byte-string index errors.
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

(define (catch-fail/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(define too-large-byte-length 536870912)

(list
 (list "byte-string operations report byte-string contracts with public who"
       (and
        (catch-contract/contains?
         (lambda () (bytes->immutable-bytes 'bad))
         "bytes->immutable-bytes"
         "bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-length 'bad))
         "bytes-length"
         "bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-ref 'bad 0))
         "bytes-ref"
         "bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (subbytes 'bad 0))
         "subbytes"
         "bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-copy 'bad))
         "bytes-copy"
         "bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes-copy! (bytes 1 2) 0 'bad))
         "bytes-copy!"
         "bytes?"
         "given: 'bad")))
 (list "make-bytes errors preserve the public contract"
       (and
        (catch-contract/contains?
         (lambda () (make-bytes -1))
         "make-bytes"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (make-bytes 1 -1))
         "make-bytes"
         "byte?"
         "given: -1")
        (catch-fail/contains?
         (lambda () (make-bytes too-large-byte-length))
         "make-bytes"
         "requested length is too large for WebRacket")))
 (list "byte-string index contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(symbol? v) "CUSTOM-SYMBOL"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (bytes-length 'bad))
                     "bytes-length"
                     "bytes?"
                     "given: CUSTOM-SYMBOL")
                    (catch-contract/contains?
                     (lambda () (make-bytes -1))
                     "make-bytes"
                     "exact-nonnegative-integer?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (bytes-ref #"ab" -1))
                     "bytes-ref"
                     "exact-nonnegative-integer?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (bytes-set! (bytes 1 2) 0 -1))
                     "bytes-set!"
                     "byte?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "negative byte-string element indexes preserve the public contract"
       (and
        (catch-contract/contains?
         (lambda () (bytes-ref #"ab" -1))
         "bytes-ref"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes-set! (bytes 1 2) -1 0))
         "bytes-set!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes-set! (bytes 1 2) 0 -1))
         "bytes-set!"
         "byte?"
         "given: -1")))
 (list "negative byte-string range indexes preserve the public contract"
       (and
        (catch-contract/contains?
         (lambda () (subbytes #"ab" -1))
         "subbytes"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (subbytes #"ab" 0 -1))
         "subbytes"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes-copy! (bytes 1 2) -1 #"x"))
         "bytes-copy!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes-copy! (bytes 1 2) 0 #"xy" -1))
         "bytes-copy!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes-copy! (bytes 1 2) 0 #"xy" 0 -1))
         "bytes-copy!"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "byte-string index successes still work"
       (let ([bs (bytes 1 2)])
         (bytes-set! bs 1 3)
         (and (equal? (make-bytes 2 65) #"AA")
              (equal? (bytes-ref #"ab" 1) 98)
              (equal? bs (bytes 1 3))
              (equal? (subbytes #"abc" 1 3) #"bc")
              (let ([dest (make-bytes 4 0)])
                (bytes-copy! dest 1 #"xy")
                (equal? dest (bytes 0 120 121 0)))))))
