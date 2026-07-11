;; Focused no-stdlib generated-output checks for linklet errors.
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
 (list "make-compiled-linklet procedure errors preserve who"
       (catch-contract/contains?
        (lambda () (make-compiled-linklet 'demo '() '() 42))
        "make-compiled-linklet"
        "procedure?"
        "given: 42")))
