;; Focused no-stdlib generated-output checks for will-executor errors.
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

(struct will-plain ())

(define will-plain-given "given: #(struct will-plain)")

(list
 (list "will-executor argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (will-register 42 'value (lambda (v) v)))
         "will-register"
         "will-executor?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (will-try-execute 42))
         "will-try-execute"
         "will-executor?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (will-execute 42))
         "will-execute"
         "will-executor?"
         "given: 42")))
 (list "will-register procedure errors report arity-one contract"
       (let ([executor (make-will-executor)])
         (and
          (catch-contract/contains?
           (lambda () (will-register executor 'value 42))
           "will-register"
           "(procedure-arity-includes/c 1)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (will-register executor 'value (will-plain)))
           "will-register"
           "(procedure-arity-includes/c 1)"
           will-plain-given)
          (catch-contract/contains?
           (lambda () (will-register executor 'value (lambda () (void))))
           "will-register"
           "(procedure-arity-includes/c 1)"
           "given:"))))
 (list "will-executor success cases still work"
       (let ([executor (make-will-executor)])
         (and (will-executor? executor)
              (void? (will-register executor 'value (lambda (v) v)))
              (equal? (will-try-execute executor) #f)
              (equal? (will-try-execute executor 'none) 'none)
              (equal? (will-execute executor) #f)))))
