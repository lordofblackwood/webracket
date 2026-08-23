;; Focused no-stdlib generated-output checks for parameterization errors.
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

(struct parameterization-plain ())

(define parameterization-plain-given
  "given: #(struct parameterization-plain)")

(list
 (list "call-with-parameterization argument errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (call-with-parameterization 42 (lambda () 'ok)))
         "call-with-parameterization"
         "parameterization?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-parameterization (current-parameterization) 42))
         "call-with-parameterization"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-parameterization
                     (current-parameterization)
                     (parameterization-plain)))
         "call-with-parameterization"
         "procedure?"
         parameterization-plain-given)))
 (list "cache-configuration argument errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (cache-configuration #f (lambda () 'ok)))
         "cache-configuration"
         "(integer-in 0 7)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (cache-configuration -1 (lambda () 'ok)))
         "cache-configuration"
         "(integer-in 0 7)"
         "given: -1")
        (catch-contract/contains?
         (lambda () (cache-configuration 8 (lambda () 'ok)))
         "cache-configuration"
         "(integer-in 0 7)"
         "given: 8")
        (catch-contract/contains?
         (lambda () (cache-configuration 536870912 (lambda () 'ok)))
         "cache-configuration"
         "(integer-in 0 7)"
         "given: 536870912")
        (catch-contract/contains?
         (lambda () (cache-configuration 0 42))
         "cache-configuration"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (cache-configuration 0 (parameterization-plain)))
         "cache-configuration"
         "procedure?"
         parameterization-plain-given)))
 (list "cache-configuration caches successful thunk results"
       (let ([calls 0])
         (let ([first (cache-configuration 4
                                           (lambda ()
                                             (set! calls (+ calls 1))
                                             'cached))]
               [second (cache-configuration 4
                                            (lambda ()
                                              (set! calls (+ calls 1))
                                              'fresh))])
           (and (equal? first 'cached)
                (equal? second 'cached)
                (equal? calls 1)))))
 (list "environment variable argument errors preserve who"
       (let ([env (current-environment-variables)])
         (and
          (catch-contract/contains?
           (lambda () (current-environment-variables 42))
           "current-environment-variables"
           "environment-variables?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (environment-variables-ref 42 #"PATH"))
           "environment-variables-ref"
           "environment-variables?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (environment-variables-ref env 42))
           "environment-variables-ref"
           "bytes-environment-variable-name?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (environment-variables-ref env #"A=B"))
           "environment-variables-ref"
           "bytes-environment-variable-name?"
           "given: #\"A=B\""))))
 (list "environment variable success cases still work"
       (let ([env (current-environment-variables)])
         (and (environment-variables? env)
              (equal? (environment-variables-ref env #"") #f)
              (void? (current-environment-variables env)))))
 (list "current-print argument errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (current-print 42))
         "current-print"
         "(procedure-arity-includes/c 1)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-print (parameterization-plain)))
         "current-print"
         "(procedure-arity-includes/c 1)"
         parameterization-plain-given)
        (catch-contract/contains?
         (lambda () (current-print (lambda () 'no-args)))
         "current-print"
         "(procedure-arity-includes/c 1)"
         "given: #<procedure")))
 (list "current-print accepts one-argument printers"
       (let ([old (current-print)])
         (and (void? (current-print (lambda (v) (void))))
              (void? (current-print old)))))
 (list "printer width parameters accept bignums"
       (let ([old-syntax (print-syntax-width)]
             [old-error  (error-print-width)])
         (let ([ok (and (void? (print-syntax-width 536870912))
                        (equal? (print-syntax-width) 536870912)
                        (void? (error-print-width 536870912))
                        (equal? (error-print-width) 536870912))])
           (print-syntax-width old-syntax)
           (error-print-width old-error)
           ok)))
 (list "printer width parameter bounds are catchable"
       (and
        (catch-contract/contains?
         (lambda () (print-syntax-width 2))
         "print-syntax-width"
         "(or/c 0 (and/c exact-integer? (>=/c 3)))"
         "given: 2")
        (catch-contract/contains?
         (lambda () (error-print-width 2))
         "error-print-width"
         "(and/c exact-integer? (>=/c 3))"
         "given: 2")))
 (list "reader and error handler parameters reject plain structs"
       (and
        (catch-contract/contains?
         (lambda () (current-read-interaction (parameterization-plain)))
         "current-read-interaction"
         "procedure?"
         parameterization-plain-given)
        (catch-contract/contains?
         (lambda () (error-syntax->name-handler (parameterization-plain)))
         "error-syntax->name-handler"
         "procedure?"
         parameterization-plain-given)
        (catch-contract/contains?
         (lambda () (error-value->string-handler (parameterization-plain)))
         "error-value->string-handler"
         "procedure?"
         parameterization-plain-given)
        (catch-contract/contains?
         (lambda () (error-syntax->string-handler (parameterization-plain)))
         "error-syntax->string-handler"
         "procedure?"
         parameterization-plain-given)
        (catch-contract/contains?
         (lambda () (error-module-path->string-handler (parameterization-plain)))
         "error-module-path->string-handler"
         "procedure?"
         parameterization-plain-given))))
