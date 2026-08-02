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

(define (reflection-contract-error? thunk . needles)
  (apply catch-contract/contains? thunk needles))

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
	              (equal? (variable-reference-from-unsafe? vr) #f))))
	 (list "syntax metadata predicates reject non-syntax values"
	       (and
	        (reflection-contract-error?
	         (lambda () (syntax-original? 42))
	         "syntax-original?"
	         "syntax?"
	         "given: 42")
	        (reflection-contract-error?
	         (lambda () (syntax-tainted? 42))
	         "syntax-tainted?"
	         "syntax?"
	         "given: 42")))
	 (list "syntax metadata predicates accept syntax values"
	       (let ([stx (datum->syntax #f 'x)])
	         (and (equal? (syntax-original? stx) #f)
	              (equal? (syntax-tainted? stx) #f))))
	 (list "module-path-index-join rejects malformed public inputs"
	       (and
	        (reflection-contract-error?
	         (lambda () (module-path-index-join 42 #f))
         "module-path-index-join"
         "(or/c #f module-path?)"
         "given: 42")
        (reflection-contract-error?
         (lambda () (module-path-index-join #f 42))
         "module-path-index-join"
         "(or/c #f resolved-module-path? module-path-index?)"
         "given: 42")
        (reflection-contract-error?
         (lambda () (module-path-index-join #f #f (list 42)))
         "module-path-index-join"
         "(or/c #f (non-empty-listof symbol?))"
         "42")
        (reflection-contract-error?
         (lambda () (module-path-index-join #f #f '()))
         "module-path-index-join"
         "(or/c #f (non-empty-listof symbol?))"
         "given:")))
 (list "module-path-index-join reports invalid combinations"
       (let ([base (module-path-index-join 'racket/base #f)])
         (and
          (reflection-contract-error?
           (lambda () (module-path-index-join #f base))
           "module-path-index-join"
           "cannot combine #f path with non-#f base"
           "given base")
          (reflection-contract-error?
           (lambda () (module-path-index-join 'racket/base #f (list 'a)))
           "module-path-index-join"
           "cannot combine #f submodule list with non-#f module path"
           "given module path"
           "given submodule list"))))
 (list "module-path-index accessors reject non-index values"
       (and
        (reflection-contract-error?
         (lambda () (module-path-index-split 42))
         "module-path-index-split"
         "module-path-index?"
         "given: 42")
        (reflection-contract-error?
         (lambda () (module-path-index-submodule 42))
         "module-path-index-submodule"
         "module-path-index?"
         "given: 42")
        (reflection-contract-error?
         (lambda () (module-path-index-resolve 42))
         "module-path-index-resolve"
         "module-path-index?"
         "given: 42")
        (reflection-contract-error?
         (lambda () (resolved-module-path-name 42))
         "resolved-module-path-name"
         "resolved-module-path?"
         "given: 42")))
 (list "module-path-index success cases still work"
       (let ([submod-mpi (module-path-index-join #f #f (list 'a))]
             [path-mpi (module-path-index-join 'racket/base #f)])
         (and (module-path-index? submod-mpi)
              (equal? (module-path-index-submodule submod-mpi) (list 'a))
              (let ([resolved (module-path-index-resolve path-mpi)])
                (and (resolved-module-path? resolved)
                     (equal? (resolved-module-path-name resolved)
                             'racket/base)))))))
