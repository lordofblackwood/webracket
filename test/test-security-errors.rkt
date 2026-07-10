;; Focused no-stdlib generated-output checks for security/custodian errors.
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
 (list "inspector placeholder APIs reject non-inspectors"
       (and
        (catch-contract/contains?
         (lambda () (make-inspector 42))
         "make-inspector"
         "inspector?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (inspector-superior? 42 (current-inspector)))
         "inspector-superior?"
         "inspector?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (inspector-superior? (current-inspector) 42))
         "inspector-superior?"
         "inspector?"
         "given: 42")))
 (list "inspector placeholder success cases still work"
       (let ([root (current-inspector)]
             [code (current-code-inspector)])
         (and (inspector? root)
              (inspector? code)
              (inspector? (make-inspector root))
              (equal? (inspector? 42) #f)
              (equal? (inspector-superior? root code) #t))))
 (list "custodian APIs reject non-custodians"
       (and
        (catch-contract/contains?
         (lambda () (make-custodian 42))
         "make-custodian"
         "custodian?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (custodian-shutdown-all 42))
         "custodian-shutdown-all"
         "custodian?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (custodian-shut-down? 42))
         "custodian-shut-down?"
         "custodian?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-custodian-box 42 'value))
         "make-custodian-box"
         "custodian?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (custodian-box-value 42))
         "custodian-box-value"
         "custodian-box?"
         "given: 42")))
 (list "security guard APIs reject invalid hooks"
       (and
        (catch-contract/contains?
         (lambda () (make-security-guard 42 void void))
         "make-security-guard"
         "security-guard?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-security-guard (current-security-guard) 42 void))
         "make-security-guard"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-security-guard 42))
         "current-security-guard"
         "security-guard?"
         "given: 42"))))
