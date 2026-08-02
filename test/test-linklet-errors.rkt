;; Focused no-stdlib generated-output checks for linklet errors.
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

(struct linklet-plain ())

(define linklet-plain-given "given: #(struct linklet-plain)")

(list
 (list "make-compiled-linklet procedure errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (make-compiled-linklet 'demo '() '() 42))
         "make-compiled-linklet"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-compiled-linklet 'demo '() '() (linklet-plain)))
         "make-compiled-linklet"
         "procedure?"
         linklet-plain-given)))
 (list "instance-variable-value returns non-procedure failure values"
       (let ([plain (linklet-plain)])
         (eq? (instance-variable-value (make-instance 'demo) 'missing plain)
              plain))))
