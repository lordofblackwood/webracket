;; Focused no-stdlib generated-output checks for control-flow errors.
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

(define (catch-unsupported/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:unsupported?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(struct control-plain ())

(define control-plain-given "given: #(struct control-plain)")

(list
 (list "call-with-values procedure errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (call-with-values 42 values))
         "call-with-values"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-values (control-plain) values))
         "call-with-values"
         "procedure?"
         control-plain-given)
        (catch-contract/contains?
         (lambda () (call-with-values (lambda () 'ok) 42))
         "call-with-values"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-values (lambda () 'ok) (control-plain)))
         "call-with-values"
         "procedure?"
         control-plain-given)))
 (list "dynamic-wind thunk errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (dynamic-wind 42
                                  (lambda () 'body)
                                  (lambda () 'after)))
         "dynamic-wind"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (dynamic-wind (control-plain)
                                  (lambda () 'body)
                                  (lambda () 'after)))
         "dynamic-wind"
         "(procedure-arity-includes/c 0)"
         control-plain-given)
        (catch-contract/contains?
         (lambda () (dynamic-wind (lambda () 'before)
                                  42
                                  (lambda () 'after)))
         "dynamic-wind"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (dynamic-wind (lambda () 'before)
                                  (control-plain)
                                  (lambda () 'after)))
         "dynamic-wind"
         "(procedure-arity-includes/c 0)"
         control-plain-given)
        (catch-contract/contains?
         (lambda () (dynamic-wind (lambda () 'before)
                                  (lambda () 'body)
                                  42))
         "dynamic-wind"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (dynamic-wind (lambda () 'before)
                                  (lambda () 'body)
                                  (control-plain)))
         "dynamic-wind"
         "(procedure-arity-includes/c 0)"
         control-plain-given)))
 (list "continuation barrier checks zero-arity thunk contract"
       (and
        (catch-contract/contains?
         (lambda () (call-with-continuation-barrier 42))
         "call-with-continuation-barrier"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-continuation-barrier (control-plain)))
         "call-with-continuation-barrier"
         "(procedure-arity-includes/c 0)"
         control-plain-given)
        (catch-contract/contains?
         (lambda () (call-with-continuation-barrier add1))
         "call-with-continuation-barrier"
         "(procedure-arity-includes/c 0)"
         "given:")))
 (list "call-with-escape-continuation checks one-arity procedure contract"
       (and
        (catch-contract/contains?
         (lambda () (call-with-escape-continuation 42))
         "call-with-escape-continuation"
         "(procedure-arity-includes/c 1)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-escape-continuation (control-plain)))
         "call-with-escape-continuation"
         "(procedure-arity-includes/c 1)"
         control-plain-given)
        (catch-contract/contains?
         (lambda () (call-with-escape-continuation (lambda () 'bad)))
         "call-with-escape-continuation"
         "(procedure-arity-includes/c 1)"
         "given:")))
 (list "call-with-immediate-continuation-mark checks one-arity receiver contract"
       (and
        (catch-contract/contains?
         (lambda () (call-with-immediate-continuation-mark 'key 42))
         "call-with-immediate-continuation-mark"
         "(procedure-arity-includes/c 1)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-immediate-continuation-mark 'key (control-plain)))
         "call-with-immediate-continuation-mark"
         "(procedure-arity-includes/c 1)"
         control-plain-given)
        (catch-contract/contains?
         (lambda () (call-with-immediate-continuation-mark 'key (lambda () 'bad)))
         "call-with-immediate-continuation-mark"
         "(procedure-arity-includes/c 1)"
         "given:")))
 (list "make-continuation-mark-key accepts optional names"
       (and
        (continuation-mark-key? (make-continuation-mark-key))
        (continuation-mark-key? (make-continuation-mark-key 'named))
        (continuation-mark-key? (make-continuation-mark-key #f))
        (continuation-mark-key? (make-continuation-mark-key 42))))
 (list "continuation prompt placeholder contracts are checked"
       (and
        (catch-contract/contains?
         (lambda () (current-continuation-marks 42))
         "current-continuation-marks"
         "continuation-prompt-tag?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-continuation-marks #f))
         "current-continuation-marks"
         "continuation-prompt-tag?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (continuation-prompt-available? 42))
         "continuation-prompt-available?"
         "continuation-prompt-tag?"
         "given: 42")
        (catch-contract/contains?
         (lambda ()
           (continuation-prompt-available?
            (unsafe-root-continuation-prompt-tag)
            42))
         "continuation-prompt-available?"
         "continuation?"
         "given: 42")
        (equal? (continuation-prompt-available?
                 (unsafe-root-continuation-prompt-tag))
                #t)))
 (list "continuation-mark-set-first placeholder contracts are checked"
       (and
        (catch-contract/contains?
         (lambda () (continuation-mark-set-first 42 'key))
         "continuation-mark-set-first"
         "(or/c continuation-mark-set? #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (continuation-mark-set-first #f 'key 'none 42))
         "continuation-mark-set-first"
         "continuation-prompt-tag?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (continuation-mark-set-first #f 'key 'none #f))
         "continuation-mark-set-first"
         "continuation-prompt-tag?"
         "given: #f")
        (equal? (continuation-mark-set-first
                 (current-continuation-marks)
                 'missing
                 'none
                 (unsafe-root-continuation-prompt-tag))
                'none)))
 (list "dynamic-require checks failure thunk contract"
       (and
        (catch-contract/contains?
         (lambda () (dynamic-require 'racket/base 'car 42))
         "dynamic-require"
         "(or/c 'error (-> any))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (dynamic-require 'racket/base 'car add1))
         "dynamic-require"
         "(or/c 'error (-> any))"
         "given:")))
 (list "dynamic-require without fallback is catchable unsupported"
       (catch-unsupported/contains?
        (lambda () (dynamic-require 'racket/base 'car))
        "dynamic-require"
        "dynamic module loading is not supported"))
 (list "module-call-with-prompt runtime primitive is catchable unsupported"
       (catch-unsupported/contains?
        (lambda ()
          (let ([call-with-module-prompt module-call-with-prompt])
            (call-with-module-prompt (lambda () 'ok))))
        "module-call-with-prompt"
        "module prompts are not supported")))
