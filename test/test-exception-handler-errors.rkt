;; Focused no-stdlib generated-output checks for exception-handler errors.
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
 (list "call-with-exception-handler procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (call-with-exception-handler 42 (lambda () (raise 'boom))))
         "call-with-exception-handler"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-exception-handler (lambda (exn) exn) 42))
         "call-with-exception-handler"
         "procedure?"
         "given: 42")))
 (list "catch procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (catch 42 (lambda (exn) exn) (lambda () 'ok)))
         "catch"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch exn? 42 (lambda () (raise 'boom))))
         "catch"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch exn? (lambda (exn) exn) 42))
         "catch"
         "procedure?"
         "given: 42")))
 (list "catch* procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (catch* (list 42)
                            (list (lambda (exn) exn))
                            (lambda () 'ok)))
         "catch*"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (list 42)
                            (lambda () (raise 'boom))))
         "catch*"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (list (lambda (exn) exn))
                            42))
         "catch*"
         "procedure?"
         "given: 42")))
 (list "with-handlers procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda ()
           (with-handlers ([42 (lambda (exn) exn)])
             (raise 'boom)))
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda ()
           (with-handlers ([exn? 42])
             (raise 'boom)))
         "procedure?"
         "given: 42"))))
