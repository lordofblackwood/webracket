;; Focused no-stdlib generated-output checks for logger errors.
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
 (list "logger constructors reject invalid contracts"
       (and
        (catch-contract/contains?
         (lambda () (make-logger 42))
         "make-logger"
         "(or/c symbol? #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-log-receiver 42 'info))
         "make-log-receiver"
         "logger?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-log-receiver (current-logger) 42))
         "make-log-receiver"
         "(or/c 'none 'fatal 'error 'warning 'info 'debug)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-log-receiver (current-logger) 'info 42))
         "make-log-receiver"
         "(or/c #f symbol?)"
         "given: 42")))
 (list "logger accessors reject invalid contracts"
       (and
        (catch-contract/contains?
         (lambda () (logger-name 42))
         "logger-name"
         "logger?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-logger 42))
         "current-logger"
         "logger?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-level? 42 'info))
         "log-level?"
         "logger?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-level? (current-logger) 42))
         "log-level?"
         "(or/c 'none 'fatal 'error 'warning 'info 'debug)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-level? (current-logger) 'info 42))
         "log-level?"
         "(or/c #f symbol?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-max-level 42))
         "log-max-level"
         "logger?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-max-level (current-logger) 42))
         "log-max-level"
         "(or/c #f symbol?)"
         "given: 42")))
 (list "log-message rejects invalid contracts"
       (and
        (catch-contract/contains?
         (lambda () (log-message 42 'info "m" 1))
         "log-message"
         "logger?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-message (current-logger) 42 "m" 1))
         "log-message"
         "(or/c 'none 'fatal 'error 'warning 'info 'debug)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (log-message (current-logger) 'info 42 1))
         "log-message"
         "(or/c string? symbol?)"
         "given: 42")))
 (list "logger contract errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (make-logger 42))
                     "make-logger"
                     "(or/c symbol? #f)"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (make-log-receiver 42 'info))
                     "make-log-receiver"
                     "logger?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (make-log-receiver (current-logger) 42))
                     "make-log-receiver"
                     "(or/c 'none 'fatal 'error 'warning 'info 'debug)"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (log-message (current-logger) 'info 42 1))
                     "log-message"
                     "(or/c string? symbol?)"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "logger success cases still work"
       (let* ([logger (make-logger 'goal)]
              [recv   (make-log-receiver logger 'info)]
              [recv2  (make-log-receiver logger 'debug #f 'topic)])
         (and (logger? logger)
              (equal? (logger-name logger) 'goal)
              (log-receiver? recv)
              (log-receiver? recv2)
              (equal? (log-level? logger 'info) #f)
              (equal? (log-level? logger 'debug 'topic) #f)
              (equal? (log-max-level logger) #f)
              (equal? (log-max-level logger 'topic) #f)
              (equal? (log-message logger 'info "hello" 1) (void))
              (equal? (log-message logger 'warning 'hello 1 #f 42) (void))))))
