;; Focused no-stdlib generated-output checks for miscellaneous string errors.
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

(define too-large-string-index 536870912)

(list
 (list "string->immutable-string type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (string->immutable-string 42))
        "string->immutable-string"
        "string?"
        "given: 42"))
 (list "string-split string argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-split 42))
         "string-split"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-split "a,b" 42))
         "string-split"
         "string?"
         "given: 42")))
 (list "string-replace string argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-replace 42 "a" "b"))
         "string-replace"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-replace "abc" 42 "b"))
         "string-replace"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-replace "abc" "a" 42))
         "string-replace"
         "string?"
         "given: 42")))
 (list "string case conversion errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-upcase 42))
         "string-upcase"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-downcase 42))
         "string-downcase"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-foldcase 42))
         "string-foldcase"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (string-titlecase 42))
         "string-titlecase"
         "string?"
         "given: 42")))
 (list "string/list conversion errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string->list 42))
         "string->list"
         "string?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (list->string 42))
         "list->string"
         "list?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (list->string (list #\a 42)))
         "list->string"
         "char?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (list->string (cons #\a 42)))
         "list->string"
         "list?"
         "given: '(#\\a . 42)")))
 (list "string UTF-8 bignum range errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string->bytes/utf-8 "abc" #f too-large-string-index))
         "string->bytes/utf-8"
         "starting index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (string->bytes/utf-8 "abc" #f 0 too-large-string-index))
         "string->bytes/utf-8"
         "ending index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (string-utf-8-length "abc" too-large-string-index))
         "string-utf-8-length"
         "starting index is out of range"
         "valid range: [0, 3]")
        (catch-contract/contains?
         (lambda () (string-utf-8-length "abc" 0 too-large-string-index))
         "string-utf-8-length"
         "ending index is out of range"
         "valid range: [0, 3]")))
 (list "string->immutable-string success still works"
       (equal? (string->immutable-string "abc") "abc"))
 (list "string case conversion success still works"
       (and (equal? (string-upcase "aB") "AB")
            (equal? (string-downcase "aB") "ab")
            (equal? (string-foldcase "aB") "ab")
            (equal? (string-titlecase "hello world") "Hello World")))
 (list "string/list conversion success still works"
       (and (equal? (string->list "ab") (list #\a #\b))
            (equal? (list->string (list #\a #\b)) "ab")))
 (list "string-split success still works"
       (equal? (string-split "a b") (list "a" "b")))
 (list "string-replace success still works"
       (equal? (string-replace "banana" "na" "NA") "baNANA")))
