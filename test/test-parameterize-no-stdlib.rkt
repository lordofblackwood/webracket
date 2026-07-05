;; Focused no-stdlib regression for `parameterize` lowering.
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
 (list "parameterize current-namespace/basic"
       (let ([ns (make-empty-namespace)])
         (and (namespace? (current-namespace))
              (parameterize ([current-namespace ns])
                (equal? (current-namespace) ns)))))
 (list "parameterize current-namespace/body sequencing"
       (let ([ns (make-empty-namespace)])
         (parameterize ([current-namespace ns])
           (let ([seen (current-namespace)])
             (equal? seen ns)))))
 (list "namespace-variable-value-simple errors are catchable with who"
       (let ([message
              (with-handlers ([exn:fail:contract?
                               (lambda (exn)
                                 (exn-message exn))])
                (namespace-variable-value-simple 42 'x)
                #f)])
         (and message
              (string-contains? message "namespace-variable-value-simple")
              (string-contains? message "namespace?")
              (string-contains? message "given: 42"))))
 (list "namespace-set-variable-value! errors are catchable with who"
       (let ([message
              (with-handlers ([exn:fail:contract?
                               (lambda (exn)
                                 (exn-message exn))])
                (namespace-set-variable-value! 'x 'value 42)
                #f)])
         (and message
              (string-contains? message "namespace-set-variable-value!")
              (string-contains? message "namespace?")
              (string-contains? message "given: 42"))))
 (list "namespace-undefine-variable! errors are catchable with who"
       (let ([message
              (with-handlers ([exn:fail:contract?
                               (lambda (exn)
                                 (exn-message exn))])
                (namespace-undefine-variable! 42 'x)
                #f)])
         (and message
             (string-contains? message "namespace-undefine-variable!")
             (string-contains? message "namespace?")
             (string-contains? message "given: 42"))))
 (list "namespace-variable-value-simple symbol errors are catchable with who"
       (let ([ns (make-empty-namespace)])
         (catch-contract/contains?
          (lambda () (namespace-variable-value-simple ns 42))
          "namespace-variable-value-simple"
          "symbol?"
          "given: 42")))
 (list "namespace-set-variable-value! symbol errors are catchable with who"
       (let ([ns (make-empty-namespace)])
         (catch-contract/contains?
          (lambda () (namespace-set-variable-value! 42 'value ns))
          "namespace-set-variable-value!"
          "symbol?")))
 (list "namespace-undefine-variable! symbol errors are catchable with who"
       (let ([ns (make-empty-namespace)])
         (catch-contract/contains?
          (lambda () (namespace-undefine-variable! ns 42))
          "namespace-undefine-variable!"
          "symbol?"
          "given: 42")))
 (list "primitive-table key errors are catchable with who"
       (catch-contract/contains?
        (lambda () (primitive-table 42))
        "primitive-table"
        "symbol?"
        "given: 42")))
