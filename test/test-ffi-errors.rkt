;; Focused no-stdlib generated-output checks for FFI lookup errors.
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

(struct ffi-plain ())

(list
 (list "procedure->external procedure errors preserve who"
       (catch-contract/contains?
        (lambda () (procedure->external 42))
        "procedure->external"
        "procedure?"
        "given: 42"))
 (list "procedure->external rejects plain structs as non-procedures"
       (catch-contract/contains?
        (lambda () (procedure->external (ffi-plain)))
        "procedure->external"
        "procedure?"
        "given: #(struct ffi-plain)"))
 (list "unsafe-ffi-primitive missing binding errors are catchable with who"
       (catch-contract/contains?
        (lambda () (unsafe-ffi-primitive 'missing-ffi-binding))
        "unsafe-ffi-primitive"
        "registered unsafe FFI primitive symbol?"
        "given:"
        "missing-ffi-binding")))
