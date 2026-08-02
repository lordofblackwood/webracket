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

(struct exception-plain ())

(define exception-plain-given "given: #(struct exception-plain)")

(list
 (list "raise-argument-error positional messages are catchable"
       (and
        (catch-contract/contains?
         (lambda () (raise-argument-error 'demo "number?" #f))
         "demo"
         "expected: number?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (raise-argument-error 'demo "number?" 0 #f))
         "demo"
         "expected: number?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (raise-argument-error 'demo "number?" 0 #f 'a))
         "demo"
         "expected: number?"
         "given: #f"
         "argument position: 1st"
         "other arguments..."
         "'a")
        (catch-contract/contains?
         (lambda () (raise-argument-error 'demo "number?" 1 #f 'a))
         "demo"
         "expected: number?"
         "given: 'a"
         "argument position: 2nd"
         "other arguments..."
         "#f")
        (catch-contract/contains?
         (lambda () (raise-argument-error 'demo "number?" 2 #f 'a 'b))
         "demo"
         "expected: number?"
         "given: 'b"
         "argument position: 3rd"
         "other arguments..."
         "#f"
         "'a")
        (catch-contract/contains?
         (lambda () (raise-argument-error 'demo "number?" "bad" #f))
         "raise-argument-error"
         "expected: exact-nonnegative-integer?"
         "given: \"bad\"")
        (catch-contract/contains?
         (lambda () (raise-argument-error* 'demo 'racket "number?" "bad" #f))
         "raise-argument-error*"
         "expected: exact-nonnegative-integer?"
         "given: \"bad\"")
        (catch-contract/contains?
         (lambda () (raise-argument-error* 'demo 'racket "number?" 2 #f 'a 'b))
         "demo"
         "expected: number?"
         "given: 'b"
         "argument position: 3rd"
         "other arguments..."
         "#f"
         "'a")
        (catch-contract/contains?
         (lambda () (raise-argument-error* 'demo "number?" 0 #f))
         "demo"
         "expected: number?"
         "given: #f")))
 (list "raise-arguments-error detail messages are catchable"
       (and
        (catch-contract/contains?
         (lambda () (raise-arguments-error 'demo "bad pair" "left" 1 "right" 2))
         "demo"
         "bad pair"
         "left: 1"
         "right: 2")
        (catch-contract/contains?
         (lambda () (raise-arguments-error 'demo "bad pair" 'left 1))
         "raise-arguments-error"
         "expected: string?"
         "given: 'left")
        (catch-contract/contains?
         (lambda () (raise-arguments-error 'demo "bad pair" "left"))
         "raise-arguments-error"
         "missing value after field string"
         "string: \"left\"")))
 (list "call-with-exception-handler procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (call-with-exception-handler 42 (lambda () (raise 'boom))))
         "call-with-exception-handler"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-exception-handler
                     (exception-plain)
                     (lambda () (raise 'boom))))
         "call-with-exception-handler"
         "procedure?"
         exception-plain-given)
        (catch-contract/contains?
         (lambda () (call-with-exception-handler (lambda (exn) exn) 42))
         "call-with-exception-handler"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-exception-handler
                     (lambda (exn) exn)
                     (exception-plain)))
         "call-with-exception-handler"
         "procedure?"
         exception-plain-given)))
 (list "catch procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (catch 42 (lambda (exn) exn) (lambda () 'ok)))
         "catch"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch (exception-plain) (lambda (exn) exn) (lambda () 'ok)))
         "catch"
         "procedure?"
         exception-plain-given)
        (catch-contract/contains?
         (lambda () (catch exn? 42 (lambda () (raise 'boom))))
         "catch"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch exn? (exception-plain) (lambda () (raise 'boom))))
         "catch"
         "procedure?"
         exception-plain-given)
        (catch-contract/contains?
         (lambda () (catch exn? (lambda (exn) exn) 42))
         "catch"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch exn? (lambda (exn) exn) (exception-plain)))
         "catch"
         "procedure?"
         exception-plain-given)))
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
         (lambda () (catch* (list (exception-plain))
                            (list (lambda (exn) exn))
                            (lambda () 'ok)))
         "catch*"
         "procedure?"
         exception-plain-given)
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (list 42)
                            (lambda () (raise 'boom))))
         "catch*"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (list (exception-plain))
                            (lambda () (raise 'boom))))
         "catch*"
         "procedure?"
         exception-plain-given)
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (list (lambda (exn) exn))
                            42))
         "catch*"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (list (lambda (exn) exn))
                            (exception-plain)))
         "catch*"
         "procedure?"
         exception-plain-given)))
 (list "catch* malformed list errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (catch* 42
                            (list (lambda (exn) exn))
                            (lambda () 'ok)))
         "catch*"
         "list?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            42
                            (lambda () 'ok)))
         "catch*"
         "list?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (cons exn? 42)
                            (list (lambda (exn) exn))
                            (lambda () 'ok)))
         "catch*"
         "list?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (catch* (list exn?)
                            (cons (lambda (exn) exn) 42)
                            (lambda () 'ok)))
         "catch*"
         "list?"
         "given: 42")))
 (list "catch* success still handles matching exceptions"
       (equal? (catch* (list symbol?)
                       (list (lambda (exn) (list 'caught exn)))
                       (lambda () (raise 'boom)))
               '(caught boom)))
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
           (with-handlers ([(exception-plain) (lambda (exn) exn)])
             (raise 'boom)))
         "procedure?"
         exception-plain-given)
        (catch-contract/contains?
         (lambda ()
           (with-handlers ([exn? 42])
             (raise 'boom)))
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda ()
           (with-handlers ([exn? (exception-plain)])
             (raise 'boom)))
         "procedure?"
         exception-plain-given))))
