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
 (list "format renders weak boxes and control values without traps"
       (let-values ([(prop pred acc) (make-impersonator-property 'demo)])
         (and (equal? (format "~a" (make-weak-box 1)) "#<weak-box>")
              (equal? (format "~s" (make-continuation-mark-key 'k))
                      "#<continuation-mark-key>")
              (equal? (format "~a" (current-continuation-marks))
                      "#<continuation-mark-set>")
              (equal? (format "~a" (current-parameterization))
                      "#<parameterization>")
              (equal? (format "~s" prop)
                      "#<impersonator-property>"))))
 (list "format error messages render weak boxes and control values"
       (and
        (catch-contract/contains?
         (lambda () (format (make-weak-box 1)))
         "format" "string?" "given: #<weak-box>")
        (catch-contract/contains?
         (lambda () (format (make-continuation-mark-key 'k)))
         "format" "string?" "given: #<continuation-mark-key>")
        (catch-contract/contains?
         (lambda () (format (current-parameterization)))
         "format" "string?" "given: #<parameterization>")
        (catch-contract/contains?
         (lambda ()
           (let-values ([(prop pred acc) (make-impersonator-property 'demo)])
             (format prop)))
         "format" "string?" "given: #<impersonator-property>")))
 (list "format renders graph and location values without traps"
       (let ([sv       (stencil-vector #b101 'a "b")]
             [empty-sv (stencil-vector 0)]
             [loc      (srcloc "file" 1 2 3 4)])
         (and (equal? (format "~a" (make-ephemeron 'k 'v)) "#<ephemeron>")
              (equal? (format "~s" (make-placeholder 'x)) "#<placeholder>")
              (equal? (format "~a" (make-hash-placeholder '((a . 1)))) "#<hash-placeholder>")
              (equal? (format "~a" sv) "#<stencil 5: a b>")
              (equal? (format "~s" sv) "#<stencil 5: a \"b\">")
              (equal? (format "~a" empty-sv) "#<stencil 0>")
              (equal? (format "~a" loc) "#(struct:srcloc file 1 2 3 4)")
              (equal? (format "~s" loc) "#(struct:srcloc \"file\" 1 2 3 4)"))))
 (list "format error messages render graph and location values"
       (and
        (catch-contract/contains?
         (lambda () (format (make-ephemeron 'k 'v)))
         "format" "string?" "given: #<ephemeron>")
        (catch-contract/contains?
         (lambda () (format (make-placeholder 'x)))
         "format" "string?" "given: #<placeholder>")
        (catch-contract/contains?
         (lambda () (format (make-hash-placeholder '((a . 1)))))
         "format" "string?" "given: #<hash-placeholder>")
        (catch-contract/contains?
         (lambda () (format (stencil-vector #b1 'x)))
         "format" "string?" "given: #<stencil 1: x>")
        (catch-contract/contains?
         (lambda () (format (srcloc "file" 1 2 3 4)))
         "format" "string?" "given: #(struct:srcloc \"file\" 1 2 3 4)")))
 (list "format write mode preserves container element quoting"
       (and (equal? (format "~s" #"abc") "#\"abc\"")
            (equal? (format "~s" (box "x")) "#&\"x\"")
            (equal? (format "~s" (hash 'a "x")) "#hash((a . \"x\"))")
            (equal? (format "~s" (hasheq 'a "x")) "#hasheq((a . \"x\"))")))
 (list "format error messages render write-mode containers"
       (and
        (catch-contract/contains?
         (lambda () (format #"abc"))
         "format" "string?" "given: #\"abc\"")
        (catch-contract/contains?
         (lambda () (format (box "x")))
         "format" "string?" "given: '#&\"x\"")
        (catch-contract/contains?
         (lambda () (format (hash 'a "x")))
         "format" "string?" "given: '#hash((a . \"x\"))")))
 (list "format renders characters in display and write modes"
       (and (equal? (format "~a" #\a) "a")
            (equal? (format "~s" #\a) "#\\a")
            (equal? (format "~a" #\space) " ")
            (equal? (format "~s" #\space) "#\\space")))
 (list "format error messages render characters in write mode"
       (catch-contract/contains?
        (lambda () (format #\a))
        "format" "string?" "given: #\\a"))
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
