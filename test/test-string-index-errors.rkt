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
