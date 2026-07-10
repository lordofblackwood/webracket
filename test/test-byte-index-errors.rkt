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

(list
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
         "given: -1")))
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
