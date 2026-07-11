;; Focused no-stdlib generated-output checks for list index and length errors.
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
 (list "list-ref/list-tail index errors include range context"
       (and
        (catch-contract/contains?
         (lambda () (list-ref '(a b) 2))
         "list-ref"
         "index too large for list"
         "index: 2"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-ref '(a . b) 1))
         "list-ref"
         "index reaches a non-pair"
         "index: 1"
         "in: '(a . b)")
        (catch-contract/contains?
         (lambda () (list-tail '(a b) 3))
         "list-tail"
         "index too large for list"
         "index: 3"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-tail '(a . b) 2))
         "list-tail"
         "index reaches a non-pair"
         "index: 2"
         "in: '(a . b)")
        (catch-contract/contains?
         (lambda () (list-tail 'bad 1))
         "list-tail"
         "index reaches a non-pair"
         "index: 1"
         "in: 'bad")))
 (list "list-set/list-update index errors include range context"
       (and
        (catch-contract/contains?
         (lambda () (list-set '(a b) 2 'x))
         "list-set"
         "index too large for list"
         "index: 2"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-update '(a b) 2 values))
         "list-update"
         "index too large for list"
         "index: 2"
         "in: '(a b)")))
 (list "take/drop length errors report required list size"
       (and
        (catch-contract/contains?
         (lambda () (take '(a b) 3))
         "take"
         "a list with at least 3 elements"
         "given: '(a b)")
        (catch-contract/contains?
         (lambda () (drop '(a b) 3))
         "drop"
         "a list with at least 3 elements"
         "given: '(a b)")
        (catch-contract/contains?
         (lambda () (take-right '(a b) 3))
         "take-right"
         "a list with at least 3 elements"
         "given: '(a b)")
        (catch-contract/contains?
         (lambda () (drop-right '(a b) 3))
         "drop-right"
         "a list with at least 3 elements"
         "given: '(a b)")))
 (list "take/drop improper-list errors report required pair count"
       (and
        (catch-contract/contains?
         (lambda () (take '(a . b) 2))
         "take"
         "a (possibly improper) list with at least 2 pairs"
         "given: '(a . b)")
        (catch-contract/contains?
         (lambda () (drop '(a . b) 2))
         "drop"
         "a (possibly improper) list with at least 2 pairs"
         "given: '(a . b)")
        (catch-contract/contains?
         (lambda () (take-right 'bad 1))
         "take-right"
         "a (possibly improper) list with at least 1 pairs"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (drop-right 'bad 1))
         "drop-right"
         "a (possibly improper) list with at least 1 pairs"
         "given: 'bad")))
 (list "list index and slice success cases still work"
       (and (equal? (list-ref '(a b c) 2) 'c)
            (equal? (list-tail '(a b c) 2) '(c))
            (equal? (list-set '(a b c) 1 'x) '(a x c))
            (equal? (list-update '(a b c) 1 symbol->string) '(a "b" c))
            (equal? (take '(a b c) 2) '(a b))
            (equal? (drop '(a b c) 2) '(c))
            (equal? (take-right '(a b c) 2) '(b c))
            (equal? (drop-right '(a b c) 2) '(a)))))
