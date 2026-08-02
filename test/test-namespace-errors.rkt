;; Focused no-stdlib generated-output checks for namespace primitive errors.
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

(define (namespace-contract-error? thunk . needles)
  (apply catch-contract/contains? thunk needles))

(list
 (list "namespace-call-with-registry-lock rejects non-namespace values"
       (namespace-contract-error?
        (lambda ()
          (namespace-call-with-registry-lock 42
                                            (lambda () 'ok)))
        "namespace-call-with-registry-lock"
        "namespace?"
        "given: 42"))
 (list "namespace-call-with-registry-lock rejects non-procedure thunks"
       (namespace-contract-error?
        (lambda ()
          (namespace-call-with-registry-lock (make-empty-namespace)
                                            42))
        "namespace-call-with-registry-lock"
        "(procedure-arity-includes/c 0)"
        "given: 42"))
 (list "namespace-call-with-registry-lock rejects wrong-arity thunks"
       (namespace-contract-error?
        (lambda ()
          (namespace-call-with-registry-lock (make-empty-namespace)
                                            (lambda (x) x)))
        "namespace-call-with-registry-lock"
        "(procedure-arity-includes/c 0)"
        "given:"))
 (list "namespace-call-with-registry-lock accepts namespace and zero-arity thunk"
       (equal?
        (namespace-call-with-registry-lock (make-empty-namespace)
                                          (lambda () 'locked))
        'locked)))
