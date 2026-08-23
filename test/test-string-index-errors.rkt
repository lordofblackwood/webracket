;; Focused no-stdlib generated-output checks for string index/range errors.
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
 (list "string take/drop type errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string-take 42 1))
                                  "string-take"
                                  "string?"
                                  "given: 42")
        (catch-contract/contains? (lambda () (string-take-right 42 1))
                                  "string-take-right"
                                  "string?"
                                  "given: 42")
        (catch-contract/contains? (lambda () (string-drop 42 1))
                                  "string-drop"
                                  "string?"
                                  "given: 42")
        (catch-contract/contains? (lambda () (string-drop-right 42 1))
                                  "string-drop-right"
                                  "string?"
                                  "given: 42")))
 (list "string take/drop non-integer count errors preserve who"
       (and
        (catch-contract/contains? (lambda () (string-take "abc" #f))
                                  "string-take"
                                  "exact-nonnegative-integer?"
                                  "given: #f")
        (catch-contract/contains? (lambda () (string-take-right "abc" #f))
                                  "string-take-right"
                                  "exact-nonnegative-integer?"
                                  "given: #f")
        (catch-contract/contains? (lambda () (string-drop "abc" #f))
                                  "string-drop"
                                  "exact-nonnegative-integer?"
                                  "given: #f")
        (catch-contract/contains? (lambda () (string-drop-right "abc" #f))
                                  "string-drop-right"
                                  "exact-nonnegative-integer?"
                                  "given: #f")))
 (list "string take/drop negative count errors preserve who"
       (and
        (catch-contract/contains? (lambda () (string-take "abc" -1))
                                  "string-take"
                                  "exact-nonnegative-integer?"
                                  "given: -1")
        (catch-contract/contains? (lambda () (string-take-right "abc" -1))
                                  "string-take-right"
                                  "exact-nonnegative-integer?"
                                  "given: -1")
        (catch-contract/contains? (lambda () (string-drop "abc" -1))
                                  "string-drop"
                                  "exact-nonnegative-integer?"
                                  "given: -1")
        (catch-contract/contains? (lambda () (string-drop-right "abc" -1))
                                  "string-drop-right"
                                  "exact-nonnegative-integer?"
                                  "given: -1")))
 (list "string-set! out-of-range errors are catchable with who"
       (catch-contract/contains?
        (lambda ()
          (let ([s (string #\a)])
            (string-set! s 2 #\b)))
        "string-set!"
        "index is out of range"
        "index: 2"
        "valid range: [0, 0]"
        "string: \"a\""))
 (list "string bignum index errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string-ref "abc" too-large-string-index))
         "string-ref"
         "index is out of range"
         "valid range: [0, 2]"
         "string: \"abc\"")
        (catch-contract/contains?
         (lambda ()
           (let ([s (string #\a)])
             (string-set! s too-large-string-index #\b)))
         "string-set!"
         "index is out of range"
         "valid range: [0, 0]"
         "string: \"a\"")
        (catch-contract/contains?
         (lambda () (substring "abc" too-large-string-index))
         "substring"
         "starting index is out of range"
         "valid range: [0, 3]"
         "string: \"abc\"")
        (catch-contract/contains?
         (lambda () (substring "abc" 0 too-large-string-index))
         "substring"
         "ending index is out of range"
         "valid range: [0, 3]"
         "string: \"abc\"")))
 (list "string take/drop bignum count errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string-take "abc" too-large-string-index))
                                  "string-take"
                                  "index is out of range"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")
        (catch-contract/contains? (lambda () (string-take-right "abc" too-large-string-index))
                                  "string-take-right"
                                  "index is out of range"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")
        (catch-contract/contains? (lambda () (string-drop "abc" too-large-string-index))
                                  "string-drop"
                                  "index is out of range"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")
        (catch-contract/contains? (lambda () (string-drop-right "abc" too-large-string-index))
                                  "string-drop-right"
                                  "index is out of range"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")))
 (list "string take/drop out-of-range errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string-take "abc" 4))
                                  "string-take"
                                  "index is out of range"
                                  "index: 4"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")
        (catch-contract/contains? (lambda () (string-take-right "abc" 4))
                                  "string-take-right"
                                  "index is out of range"
                                  "index: 4"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")
        (catch-contract/contains? (lambda () (string-drop "abc" 4))
                                  "string-drop"
                                  "index is out of range"
                                  "index: 4"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")
        (catch-contract/contains? (lambda () (string-drop-right "abc" 4))
                                  "string-drop-right"
                                  "index is out of range"
                                  "index: 4"
                                  "valid range: [0, 3]"
                                  "string: \"abc\"")))
 (list "string index success still works"
       (let ([s (string #\a #\b #\c)])
         (string-set! s 1 #\z)
         (and (equal? s "azc")
              (equal? (string-take s 2) "az")
              (equal? (string-take-right s 2) "zc")
              (equal? (string-drop s 1) "zc")
              (equal? (string-drop-right s 1) "az")))))
