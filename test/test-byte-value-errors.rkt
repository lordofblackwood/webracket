;; Focused no-stdlib generated-output checks for byte-string value errors.
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
 (list "bytes reports public byte contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes -1))
         "bytes"
         "expected: byte?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes 256))
         "bytes"
         "expected: byte?"
         "given: 256")
        (catch-contract/contains?
         (lambda () (bytes 'bad))
         "bytes"
         "expected: byte?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (apply bytes '(-1)))
         "bytes"
         "expected: byte?"
         "given: -1")))
 (list "bytes-fill! reports public byte contracts"
       (and
        (catch-contract/contains?
         (lambda () (bytes-fill! (bytes 1 2) -1))
         "bytes-fill!"
         "expected: byte?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (bytes-fill! (bytes 1 2) 256))
         "bytes-fill!"
         "expected: byte?"
         "given: 256")
        (catch-contract/contains?
         (lambda () (bytes-fill! (bytes 1 2) 'bad))
         "bytes-fill!"
         "expected: byte?"
         "given: 'bad")))
 (list "list->bytes reports whole-list byte contracts"
       (and
        (catch-contract/contains?
         (lambda () (list->bytes '(-1)))
         "list->bytes"
         "expected: (listof byte?)"
         "given: '(-1)")
        (catch-contract/contains?
         (lambda () (list->bytes '(256)))
         "list->bytes"
         "expected: (listof byte?)"
         "given: '(256)")
        (catch-contract/contains?
         (lambda () (list->bytes '(bad)))
         "list->bytes"
         "expected: (listof byte?)"
         "given: '(bad)")))
 (list "byte-string value successes still work"
       (let ([bs (bytes 1 2 3)])
         (bytes-fill! bs 65)
         (and (equal? bs #"AAA")
              (equal? (bytes 0 127 255) #"\0\177\377")
              (equal? (apply bytes '(0 127 255)) #"\0\177\377")
              (equal? (list->bytes '(65 66 67)) #"ABC")))))
