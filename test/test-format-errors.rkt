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
 (list "unquoted-printing-string-value errors are catchable with who"
       (catch-contract/contains?
        (lambda () (unquoted-printing-string-value 42))
        "unquoted-printing-string-value"
        "unquoted-printing-string?"
        "given: 42"))
 (list "format success still works"
       (equal? (format "~a/~s" "x" "y") "x/\"y\"")))
