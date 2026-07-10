;; Focused no-stdlib generated-output checks for reflection primitive errors.
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

(define (variable-reference-error? proc who)
  (catch-contract/contains?
   (lambda () (proc 42))
   who
   "variable-reference?"
   "given: 42"))

(list
 (list "variable-reference accessors reject non-variable-reference values"
       (and
        (variable-reference-error? variable-reference->instance
                                   "variable-reference->instance")
        (variable-reference-error? variable-reference->module-path-index
                                   "variable-reference->module-path-index")
        (variable-reference-error? variable-reference->module-base-phase
                                   "variable-reference->module-base-phase")
        (variable-reference-error? variable-reference->namespace
                                   "variable-reference->namespace")
        (variable-reference-error? variable-reference->module-source
                                   "variable-reference->module-source")
        (variable-reference-error? variable-reference->resolved-module-path
                                   "variable-reference->resolved-module-path")
        (variable-reference-error? variable-reference-constant?
                                   "variable-reference-constant?")
        (variable-reference-error? variable-reference-from-unsafe?
                                   "variable-reference-from-unsafe?")))
 (list "variable-reference success cases still work"
       (let ([vr (#%variable-reference)])
         (and (variable-reference? vr)
              (equal? (variable-reference->instance vr) #f)
              (equal? (variable-reference->instance vr #t) #f)
              (equal? (variable-reference->module-path-index vr) #f)
              (equal? (variable-reference->module-base-phase vr) 0)
              (namespace? (variable-reference->namespace vr))
              (equal? (variable-reference->module-source vr) #f)
              (equal? (variable-reference->module-source/submod vr) #f)
              (equal? (variable-reference->resolved-module-path vr) #f)
              (equal? (variable-reference-constant? vr) #f)
              (equal? (variable-reference-from-unsafe? vr) #f)))))
