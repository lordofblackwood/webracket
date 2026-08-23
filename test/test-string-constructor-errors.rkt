;; Focused no-stdlib generated-output checks for string constructor errors.
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

(define too-large-string-length 536870912)

(list
 (list "string constructor direct errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (string 42))
                                  "string" "char?" "given: 42")
        (catch-contract/contains? (lambda () (string #\a 42))
                                  "string" "char?" "given: 42")))
 (list "string constructor apply errors are catchable with who"
       (and
        (catch-contract/contains? (lambda () (apply string (list 42)))
                                  "string" "char?" "given: 42")
        (catch-contract/contains? (lambda () (apply string (list #\a 42)))
                                  "string" "char?" "given: 42")))
 (list "string constructor success still works"
       (and (equal? (string) "")
            (equal? (string #\a #\b #\c) "abc")
            (equal? (apply string (list #\x #\y)) "xy")))
 (list "string length contracts match Racket docs"
       (and
        (catch-contract/contains? (lambda () (make-string -1))
                                  "make-string" "exact-nonnegative-integer?" "given: -1")
        (catch-contract/contains? (lambda () (build-string -1 (lambda (i) #\x)))
                                  "build-string" "exact-nonnegative-integer?" "given: -1")))
 (list "string constructor bignum lengths fail catchably"
       (and
        (catch-fail/contains? (lambda () (make-string too-large-string-length))
                              "make-string" "requested length is too large for WebRacket")
        (catch-fail/contains? (lambda () (build-string too-large-string-length
                                                        (lambda (i) #\x)))
                              "build-string" "requested length is too large for WebRacket"))))
