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
         "given: 42")))
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
         (lambda () (cache-configuration 0 42))
         "cache-configuration"
         "procedure?"
         "given: 42")))
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
              (void? (current-environment-variables env))))))
