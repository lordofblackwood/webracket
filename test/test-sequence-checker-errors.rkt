;; Focused no-stdlib generated-output checks for sequence checker errors.
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
 (list "check-mlist rejects ordinary pairs"
       (and
        (catch-contract/contains?
         (lambda () (check-mlist '(1 2)))
         "in-mlist"
         "(or/c mpair? null?)"
         "given:")
        (catch-contract/contains?
         (lambda () (check-mlist 42))
         "in-mlist"
         "(or/c mpair? null?)"
         "given: 42")))
 (list "in-mlist rejects ordinary lists"
       (catch-contract/contains?
        (lambda () (for/list ([x (in-mlist '(1 2))]) x))
        "in-mlist"
        "(or/c mpair? null?)"
        "given:"))
 (list "in-mlist success still works"
       (equal? (for/list ([x (in-mlist (mcons 1 (mcons 2 '())))])
                 x)
               '(1 2))))
