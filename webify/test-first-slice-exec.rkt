#lang racket/base

(require racket/runtime-path
         rackunit
         "first-slice.rkt"
         "known.rkt"
         "wrap.rkt")

(define-runtime-path module-variable-path "module-variable.rkt")

;; test-prim-knowns : hash?
;;   Minimal primitive facts for first-slice execution tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +))

;; run-first-slice : any/c -> values
;;   Webify and lower a hand-written linklet with stable test defaults.
(define (run-first-slice lk)
  (webify-linklet-first-slice
   lk
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; strip-correlated : any/c -> any/c
;;   Convert a compiler term with correlated wrappers into an evaluable datum.
(define (strip-correlated v)
  (let ([v (unwrap v)])
    (cond
      [(pair? v)   (cons (strip-correlated (car v))
                         (strip-correlated (cdr v)))]
      [(vector? v) (list->vector (map strip-correlated (vector->list v)))]
      [else        v])))

;; eval-first-slice : any/c -> namespace? procedure?
;;   Evaluate a lowered first-slice lambda with the reference runtime available.
(define (eval-first-slice expr)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (namespace-require `(file ,(path->string module-variable-path)))
    (values ns (eval (strip-correlated expr)))))

;; namespace-value : namespace? symbol? -> any/c
;;   Get a value from the namespace used to evaluate a first-slice lambda.
(define (namespace-value ns id)
  (parameterize ([current-namespace ns])
    (eval id)))

(test-case "execute constant export first slice"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet () (x)
                        (define-values (x) (+ 1 2)))))
  (define-values (ns proc) (eval-first-slice webified))
  (define module-variable-make (namespace-value ns 'module-variable-make))
  (define module-variable-ref (namespace-value ns 'module-variable-ref))
  (define module-variable-constance (namespace-value ns 'module-variable-constance))
  (define x-cell (module-variable-make 'x))
  (check-equal? (proc 'instance x-cell) (void))
  (check-equal? (module-variable-ref x-cell) 3)
  (check-equal? (module-variable-constance x-cell) 'consistent)
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 3))

(test-case "execute mutated export first slice"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet () (x)
                        (define-values (x) 1)
                        (set! x 2))))
  (define-values (ns proc) (eval-first-slice webified))
  (define module-variable-make (namespace-value ns 'module-variable-make))
  (define module-variable-ref (namespace-value ns 'module-variable-ref))
  (define module-variable-constance (namespace-value ns 'module-variable-constance))
  (define x-cell (module-variable-make 'x))
  (check-equal? (proc 'instance x-cell) (void))
  (check-equal? (module-variable-ref x-cell) 2)
  (check-false (module-variable-constance x-cell))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-false (hash-ref exports-info 'x #f)))

(test-case "execute imported value copied to export first slice"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet (([ext-a a])) (x)
                        (define-values (x) a))))
  (define-values (ns proc) (eval-first-slice webified))
  (define module-variable-make (namespace-value ns 'module-variable-make))
  (define module-variable-define! (namespace-value ns 'module-variable-define!))
  (define module-variable-ref (namespace-value ns 'module-variable-ref))
  (define module-variable-constance (namespace-value ns 'module-variable-constance))
  (define a-cell (module-variable-make 'a))
  (define x-cell (module-variable-make 'x))
  (module-variable-define! a-cell 42 'constant)
  (check-equal? (proc 'instance a-cell x-cell) (void))
  (check-equal? (module-variable-ref x-cell) 42)
  (check-equal? (module-variable-constance x-cell) 'constant)
  (check-equal? importss '((ext-a)))
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '((#f)))
  (check-true (known-constant? (hash-ref exports-info 'x))))

(test-case "execute lambda export first slice"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet () (f)
                        (define-values (f) (lambda (x) (+ x 1))))))
  (define-values (ns proc) (eval-first-slice webified))
  (define module-variable-make (namespace-value ns 'module-variable-make))
  (define module-variable-ref (namespace-value ns 'module-variable-ref))
  (define module-variable-constance (namespace-value ns 'module-variable-constance))
  (define f-cell (module-variable-make 'f))
  (check-equal? (proc 'instance f-cell) (void))
  (define f (module-variable-ref f-cell))
  (check-true (procedure? f))
  (check-equal? (f 41) 42)
  (check-equal? (module-variable-constance f-cell) 'consistent)
  (check-equal? importss '())
  (check-equal? exports '(f))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-true (known-procedure/can-inline? (hash-ref exports-info 'f))))
