;; Focused no-stdlib generated-output checks for byte text decoding errors.
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

(define too-large-byte-index 536870912)

(list
 (list "bytes->string/utf-8 errors are catchable with who"
       (let ([catch-contract/who+expected+given?
              (lambda (who expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message expected)
                       (string-contains? message given))))]
             [catch-range/who+reason+index?
              (lambda (who reason index-line thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message reason)
                       (string-contains? message index-line)
                       (string-contains? message "valid range: [0, 3]")
                       (string-contains? message "byte string:"))))])
         (and
          (catch-contract/who+expected+given?
           "bytes->string/utf-8"
           "bytes?"
           "given: 42"
           (lambda () (bytes->string/utf-8 42)))
          (catch-contract/who+expected+given?
           "bytes->string/utf-8"
           "(or/c char? #f)"
           "given: 42"
           (lambda () (bytes->string/utf-8 #"abc" 42)))
          (catch-contract/who+expected+given?
           "bytes->string/utf-8"
           "exact-nonnegative-integer?"
           "given: -1"
           (lambda () (bytes->string/utf-8 #"abc" #f -1)))
          (catch-range/who+reason+index?
           "bytes->string/utf-8"
           "starting index is out of range"
           "starting index: 4"
           (lambda () (bytes->string/utf-8 #"abc" #f 4)))
          (catch-contract/who+expected+given?
           "bytes->string/utf-8"
           "well-formed UTF-8"
           "byte string:"
           (lambda () (bytes->string/utf-8 (bytes 255) #f))))))
 (list "byte text bignum range errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (bytes->string/utf-8 #"abc" #f too-large-byte-index))
         "bytes->string/utf-8"
         "starting index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (bytes->string/utf-8 #"abc" #f 0 too-large-byte-index))
         "bytes->string/utf-8"
         "ending index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (bytes-utf-8-length #"abc" #f too-large-byte-index))
         "bytes-utf-8-length"
         "starting index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (bytes-utf-8-length #"abc" #f 0 too-large-byte-index))
         "bytes-utf-8-length"
         "ending index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (bytes->string/latin-1 #"abc" #f too-large-byte-index))
         "bytes->string/latin-1"
         "starting index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (bytes->string/latin-1 #"abc" #f 0 too-large-byte-index))
         "bytes->string/latin-1"
         "ending index is out of range"
         "valid range: [0, 3]")))
 (list "byte text errors use error-value->string-handler for byte-string values"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(bytes? v) "CUSTOM-BYTES"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (bytes->string/utf-8 #"abc" #f 4))
                     "bytes->string/utf-8"
                     "starting index is out of range"
                     "byte string:"
                     "CUSTOM-BYTES")
                    (catch-contract/contains?
                     (lambda () (bytes->string/utf-8 (bytes 255) #f))
                     "bytes->string/utf-8"
                     "well-formed UTF-8"
                     "byte string:"
                     "CUSTOM-BYTES")
                    (catch-contract/contains?
                     (lambda () (bytes->string/utf-8 42))
                     "bytes->string/utf-8"
                     "bytes?"
                     "given: CUSTOM-VALUE")
                    (catch-contract/contains?
                     (lambda () (bytes-open-converter 42 "UTF-8"))
                     "bytes-open-converter"
                     "string?"
                     "given: CUSTOM-VALUE")
                    (let ([converter (bytes-open-converter "UTF-8" "UTF-8")])
                      (catch-contract/contains?
                       (lambda () (bytes-convert converter 'bad))
                       "bytes-convert"
                       "bytes?"
                       "given: CUSTOM-VALUE")))])
           (error-value->string-handler old)
           ok)))
 (list "bytes->string/utf-8/basic"
       (and (equal? (bytes->string/utf-8 (bytes 65 195 169))
                    (string #\A (integer->char 233)))
            (equal? (bytes->string/utf-8 (bytes 255) #\?) "?")))
 (list "bytes-open-converter string errors are catchable with who"
       (let ([catch-contract/contains?
              (lambda (thunk . needles)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (andmap (lambda (needle)
                                 (string-contains? message needle))
                               needles))))])
         (and
          (catch-contract/contains?
           (lambda () (bytes-open-converter 42 "UTF-8"))
           "bytes-open-converter"
           "string?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (bytes-open-converter "UTF-8" 42))
           "bytes-open-converter"
           "string?"
           "given: 42"))))
 (list "bytes-convert-end destination byte-string errors are catchable with who"
       (let ([catch-contract/contains?
              (lambda (thunk . needles)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (andmap (lambda (needle)
                                 (string-contains? message needle))
                               needles))))])
         (let ([converter (bytes-open-converter "UTF-8" "UTF-8")])
           (catch-contract/contains?
            (lambda () (bytes-convert-end converter 'bad))
            "bytes-convert-end"
            "bytes?"
            "given: 'bad"))))
 (list "bytes-convert byte-string errors are catchable with who"
       (let ([catch-contract/contains?
              (lambda (thunk . needles)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (andmap (lambda (needle)
                                 (string-contains? message needle))
                               needles))))])
         (let ([converter (bytes-open-converter "UTF-8" "UTF-8")])
           (and
            (catch-contract/contains?
             (lambda () (bytes-convert converter 'bad))
             "bytes-convert"
             "bytes?"
             "given: 'bad")
            (catch-contract/contains?
             (lambda () ((lambda (f c) (f c 'bad)) bytes-convert converter))
             "bytes-convert"
             "bytes?"
             "given: 'bad")
            (catch-contract/contains?
             (lambda () (bytes-convert converter #"abc" 0 3 'bad))
             "bytes-convert"
             "bytes?"
             "given: 'bad")
            (catch-contract/contains?
             (lambda () (bytes-convert converter #"abc" too-large-byte-index))
             "bytes-convert"
             "starting index is out of range"
             "valid range: [0, 3]")
            (catch-contract/contains?
             (lambda () (bytes-convert converter #"abc" 0 too-large-byte-index))
             "bytes-convert"
             "ending index is out of range"
             "valid range: [0, 3]")))))
 (list "bytes-convert success still works"
       (let ([converter (bytes-open-converter "UTF-8" "UTF-8")])
         (let-values ([(out read status) (bytes-convert converter #"abc")])
           (and (equal? out #"abc")
                (equal? read 3)
                (equal? status 'complete)))))
 (list "bytes-open-converter success still works"
       (bytes-converter? (bytes-open-converter "UTF-8" "UTF-8"))))
