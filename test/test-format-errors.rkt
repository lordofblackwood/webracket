;; Focused no-stdlib generated-output checks for format errors.
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
 (list "format string type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (format 42))
        "format"
        "string?"
        "given: 42"))
 (list "fprintf string type errors are catchable with who"
       (catch-contract/contains?
        (lambda ()
          (let ([out (open-output-string)])
            (fprintf out 42)))
        "fprintf"
        "string?"
        "given: 42"))
 (list "format renders mutable pairs without traps"
       (and (equal? (format "~a" (mcons 'x 'y)) "{x . y}")
            (equal? (format "~s" (mcons 'x 'y)) "{x . y}")
            (equal? (format "~a" (mcons 1 (mcons 2 '()))) "{1 2}")))
 (list "format renders opaque runtime values without traps"
       (let ([sema (make-semaphore)]
             [will (make-will-executor)]
             [logger (make-logger)]
             [receiver (make-log-receiver (current-logger) 'debug)]
             [converter (bytes-open-converter "UTF-8" "UTF-8")]
             [lock (unsafe-make-uninterruptible-lock)])
         (and (equal? (format "~a" sema) "#<semaphore>")
              (equal? (format "~s" (semaphore-peek-evt sema)) "#<semaphore-peek-evt>")
              (equal? (format "~a" will) "#<will-executor>")
              (equal? (format "~a" logger) "#<logger>")
              (equal? (format "~a" receiver) "#<log-receiver>")
              (equal? (format "~a" converter) "#<bytes-converter>")
              (equal? (format "~a" lock) "#<uninterruptible-lock>"))))
 (list "format renders thread and custodian values without traps"
       (let ([thread-text (format "~a" (current-thread))]
             [cust (current-custodian)])
         (and (string-contains? thread-text "#<thread")
              (equal? (format "~a" (current-thread-group)) "#<thread-group>")
              (equal? (format "~a" (make-thread-cell 1)) "#<thread-cell>")
              (equal? (format "~a" cust) "#<custodian>")
              (equal? (format "~a" (make-custodian-box cust 1)) "#<custodian-box>")
              (equal? (format "~a" (current-security-guard)) "#<security-guard>"))))
 (list "format renders module-path reflection values without traps"
       (let* ([mpi (module-path-index-join 'racket/base #f)]
              [resolved (module-path-index-resolve mpi)])
         (and (equal? (format "~a" mpi) "#<module-path-index>")
              (equal? (format "~s" resolved) "#<resolved-module-path>"))))
 (list "format renders date and environment values without traps"
       (let ([d (date 0 0 0 1 1 1970 4 0 #f 0)]
             [ds (seconds->date 0 #f)]
             [env (current-environment-variables)])
         (and (equal? (format "~a" d)
                      "#(struct:date 0 0 0 1 1 1970 4 0 #f 0)")
              (equal? (format "~a" ds)
                      "#(struct:date* 0 0 0 1 1 1970 4 0 #f 0 0 UTC)")
              (equal? (format "~s" ds)
                      "#(struct:date* 0 0 0 1 1 1970 4 0 #f 0 0 \"UTC\")")
              (equal? (format "~a" env) "#<environment-variables>")
              (equal? (format "~s" env) "#<environment-variables>"))))
 (list "format error messages render date and environment values"
       (and
        (catch-contract/contains?
         (lambda () (format (seconds->date 0 #f)))
         "format" "string?" "given: #(struct:date*" "UTC")
        (catch-contract/contains?
         (lambda () (format (current-environment-variables)))
         "format" "string?" "given: #<environment-variables>")))
 (list "format renders regexp values without traps"
       (and (equal? (format "~a" (webracket-literal-regexp "a")) "#rx\"a\"")
            (equal? (format "~a" (webracket-literal-pregexp "a")) "#px\"a\"")
            (equal? (format "~a" (webracket-literal-byte-regexp #"a")) "#rx#\"a\"")
            (equal? (format "~a" (webracket-literal-byte-pregexp #"a")) "#px#\"a\"")))
 (list "format renders event values without traps"
       (let ([ch (make-channel)])
         (and (equal? (format "~a" always-evt) "#<always-evt>")
              (equal? (format "~s" never-evt) "#<never-evt>")
              (equal? (format "~a" ch) "#<channel>")
              (equal? (format "~s" (channel-put-evt ch 'x)) "#<channel-put-evt>")
              (equal? (format "~a" (handle-evt always-evt values)) "#<handle-evt>"))))
 (list "unquoted-printing-string-value errors are catchable with who"
       (catch-contract/contains?
        (lambda () (unquoted-printing-string-value 42))
        "unquoted-printing-string-value"
        "unquoted-printing-string?"
        "given: 42"))
 (list "format success still works"
       (equal? (format "~a/~s" "x" "y") "x/\"y\"")))
