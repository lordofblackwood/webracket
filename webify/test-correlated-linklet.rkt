#lang racket/base

(require rackunit
         racket/list
         "correlated-linklet.rkt"
         "correlated-runner.rkt"
         "first-slice.rkt"
         "known.rkt"
         "module-variable.rkt"
         "wrap.rkt")

;; Synthetic same-named struct for adapter tests.
(struct correlated-linklet (expr name compiled) #:transparent)

;; test-prim-knowns : hash?
;;   Minimal primitive facts for correlated-linklet lowering tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +))

;; real-expander-import-groups : list?
;;   Import groups observed in serializable machine-independent phase-0 output.
(define real-expander-import-groups
  '((.top-level-bind! .top-level-require!)
    (.mpi-vector .syntax-literals)
    (.namespace .phase .self .inspector .bulk-binding-registry .set-transformer!)))

;; real-expander-definition-linklet : any/c
;;   Phase-0 correlated linklet extracted from `(define-values (webify-top-x) 1)`.
(define real-expander-definition-linklet
  `(linklet ,real-expander-import-groups
     (webify-top-x.1)
     (define-values (webify-top-x.1) 1)
     (if #f (begin (set! webify-top-x.1 #f)) (void))
     (begin
       (.top-level-bind!
        (unsafe-vector*-ref .syntax-literals 0)
        (unsafe-vector*-ref .mpi-vector 0)
        0
        .phase
        .namespace
        (quote webify-top-x.1)
        #f
        (quote #f)))))

;; real-expander-begin-directory-summary : any/c
;;   Probe summary for `(begin (define-values (webify-top-x) 1) webify-top-x)`.
(define real-expander-begin-directory-summary
  '((datum (begin (define-values (webify-top-x) 1) webify-top-x))
    (directory-object-name linklet-directory)
    (directory-keys (data 0 1))
    (bundle-object-name #f)
    (bundle-entries #f)))

;; make-correlated-linklet : any/c -> any/c
;;   Wrap a linklet datum as an inspectable correlated-linklet-shaped value.
(define (make-correlated-linklet expr)
  (correlated-linklet expr #f #f))

;; correlated-first-slice : any/c -> values
;;   Extract, webify, and lower a correlated-linklet-shaped source expression.
(define (correlated-first-slice expr)
  (webify-linklet-first-slice
   (webify-correlated-linklet->datum (make-correlated-linklet expr))
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
   #:compiler-query        (lambda (_v) #f)
   #:get-import-knowns     (lambda (_key) (values #f #f #f))
   #:import-keys           #f))

;; normalize-symbols : any/c -> any/c
;;   Make correlated terms and generated symbols easy to compare.
(define (normalize-symbols v)
  (let ([v (unwrap v)])
    (cond
      [(symbol? v) (symbol->string v)]
      [(pair? v)   (cons (normalize-symbols (car v))
                         (normalize-symbols (cdr v)))]
      [(vector? v) (list->vector (map normalize-symbols (vector->list v)))]
      [else        v])))

;; eval-lowered-first-slice : any/c -> procedure?
;;   Evaluate a lowered first-slice lambda in a small host namespace.
(define (eval-lowered-first-slice expr)
  (parameterize ([current-namespace (make-base-namespace)])
    (namespace-set-variable-value! 'module-variable-define! module-variable-define!)
    (namespace-set-variable-value! 'module-variable-ref/no-check module-variable-ref/no-check)
    (namespace-set-variable-value! 'unsafe-vector*-ref vector-ref)
    (eval (webify-strip-correlated-linklet-datum expr))))

(test-case "correlated-linklet adapter extracts synthetic linklet source"
  (define datum '(linklet () (x)
                   (define-values (x) 1)))
  (define linklet (make-correlated-linklet datum))
  (check-true (webify-correlated-linklet? linklet))
  (check-equal? (webify-correlated-linklet->datum linklet) datum)
  (check-equal? (webify-correlated-linklet->datum/catch linklet) datum)
  (check-false (webify-correlated-linklet->datum/catch '(not-a-linklet))))

(test-case "correlated-linklet source lowers constant expression"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (correlated-first-slice '(linklet () (x)
                               (define-values (x) 42))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 42)
                  ("module-variable-define!" "x1" "x" ("quote" "consistent"))))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 42))

(test-case "correlated-linklet expression matrix lowers through first slice"
  (for ([case (in-list
               `((constant
                  (linklet () (x)
                    (define-values (x) 42))
                  42)
                 (primitive-app
                  (linklet () (x)
                    (define-values (x) (+ 1 2)))
                  3)
                 (lambda
                  (linklet () (f)
                    (define-values (f) (lambda (x) x)))
                  #f)
                 (let-values
                  (linklet () (x)
                    (define-values (x) (let-values ([(v) 1]) v)))
                  1)))])
    (define name (car case))
    (define datum (cadr case))
    (define expected-literal (caddr case))
    (define-values (webified importss exports import-keys imports-abis exports-info)
      (correlated-first-slice datum))
    (define message (format "~a" name))
    (check-equal? (car (normalize-symbols webified)) "lambda" message)
    (check-equal? importss '() message)
    (check-equal? exports (caddr datum) message)
    (check-false import-keys message)
    (check-equal? imports-abis '() message)
    (when expected-literal
      (check-equal? (known-literal-value (hash-ref exports-info (car (caddr datum))))
                    expected-literal
                    message))))

(test-case "real extracted correlated phase-0 linklet fixtures lower through first slice"
  (for ([case (in-list
               `((constant
                  (linklet ,real-expander-import-groups () 42)
                  42)
                 (primitive-app
                  (linklet ,real-expander-import-groups () (+ 1 2))
                  3)
                 (lambda
                  (linklet ,real-expander-import-groups () (lambda (arg_1) arg_1))
                  lambda)
                 (let-values
                  (linklet ,real-expander-import-groups () (let-values (((loc_2) 1)) loc_2))
                  1)))])
    (define name (car case))
    (define datum (cadr case))
    (define expected-body (caddr case))
    (define-values (webified importss exports import-keys imports-abis exports-info)
      (correlated-first-slice datum))
    (define normalized (normalize-symbols webified))
    (define message (format "~a" name))
    (check-equal? importss real-expander-import-groups message)
    (check-equal? exports '() message)
    (check-false import-keys message)
    (check-equal? imports-abis '((#f #f) (#f #f) (#f #f #f #f #f #f)) message)
    (check-equal? exports-info (hasheq) message)
    (check-equal? (car normalized) "lambda" message)
    (check-equal? (length (cdr (cadr normalized))) 10 message)
    (cond
      [(eq? expected-body 'lambda)
       (check-equal? (caaddr normalized) "lambda" message)]
      [else
       (check-equal? (caddr normalized) expected-body message)])))

(test-case "real extracted correlated phase-0 linklet fixtures run as expressions"
  (for ([case (in-list
               `((constant
                  (linklet ,webify-correlated-top-level-import-groups () 42)
                  42)
                 (primitive-app
                  (linklet ,webify-correlated-top-level-import-groups () (+ 1 2))
                  3)))])
    (define name (car case))
    (define datum (cadr case))
    (define expected-value (caddr case))
    (define-values (webified importss exports import-keys imports-abis exports-info)
      (correlated-first-slice datum))
    (define proc (eval-lowered-first-slice webified))
    (check-equal? importss webify-correlated-top-level-import-groups (format "~a" name))
    (check-equal? exports '() (format "~a" name))
    (check-false import-keys (format "~a" name))
    (check-equal? (webify-run-correlated-top-level-linklet proc)
                  expected-value
                  (format "~a" name))
    (check-equal? exports-info (hasheq) (format "~a" name))))

(test-case "real extracted correlated standalone definition lowers through first slice"
  (define-values (_webified importss exports import-keys imports-abis exports-info)
    (correlated-first-slice real-expander-definition-linklet))
  (check-true (webify-correlated-standalone-definition-linklet?
               real-expander-definition-linklet))
  (check-equal? (webify-correlated-linklet-export-names
                 real-expander-definition-linklet)
                '(webify-top-x.1))
  (check-equal? importss webify-correlated-top-level-import-groups)
  (check-equal? exports '(webify-top-x.1))
  (check-false import-keys)
  (check-equal? imports-abis '((#f #f) (#f #f) (#f #f #f #f #f #f)))
  (check-equal? exports-info (hasheq)))

(test-case "real extracted correlated standalone definition runs and binds top level"
  (define-values (webified _importss exports _import-keys _imports-abis _exports-info)
    (correlated-first-slice real-expander-definition-linklet))
  (define proc (eval-lowered-first-slice webified))
  (define top-level-env (make-hasheq))
  (define-values (result export-env binding-env)
    (webify-run-correlated-top-level-linklet/exports
     proc
     exports
     top-level-env
     #:mpi-vector '#(#%kernel)
     #:syntax-literals '#(webify-top-x)))
  (check-equal? result (void))
  (check-equal? (module-variable-ref (hash-ref export-env 'webify-top-x.1)) 1)
  (check-equal? (module-variable-constance (hash-ref export-env 'webify-top-x.1)) #f)
  (check-true (hash-has-key? binding-env 'webify-top-x))
  (check-equal? (hash-ref binding-env 'webify-top-x)
                '(top-level-binding
                  (mpi #%kernel)
                  (position 0)
                  (phase 0)
                  (namespace webify-namespace)
                  (name webify-top-x.1)
                  (transformer? #f)
                  (mode #f))))

(test-case "definition bridge composes multiple top-level linklets"
  (define-values (definition-webified _definition-importss definition-exports
                                      _definition-import-keys _definition-imports-abis
                                      _definition-exports-info)
    (correlated-first-slice real-expander-definition-linklet))
  (define-values (expression-webified _expression-importss expression-exports
                                      _expression-import-keys _expression-imports-abis
                                      _expression-exports-info)
    (correlated-first-slice
     `(linklet ,webify-correlated-top-level-import-groups () (+ 1 2))))
  (define definition-proc (eval-lowered-first-slice definition-webified))
  (define expression-proc (eval-lowered-first-slice expression-webified))
  (define-values (result export-envs binding-env)
    (webify-run-correlated-top-level-linklets/exports
     (list (list definition-proc definition-exports)
           (list expression-proc expression-exports))
     (make-hasheq)
     #:mpi-vector '#(#%kernel)
     #:syntax-literals '#(webify-top-x)))
  (check-equal? result 3)
  (check-equal? (length export-envs) 2)
  (check-equal? (hash-keys (first export-envs)) '(webify-top-x.1))
  (check-equal? (module-variable-ref
                 (hash-ref (first export-envs) 'webify-top-x.1))
                1)
  (check-equal? (hash-ref binding-env 'webify-top-x)
                '(top-level-binding
                  (mpi #%kernel)
                  (position 0)
                  (phase 0)
                  (namespace webify-namespace)
                  (name webify-top-x.1)
                  (transformer? #f)
                  (mode #f))))

(test-case "begin directory shape decodes as ordered data entries"
  (check-true (webify-correlated-begin-directory-description?
               real-expander-begin-directory-summary))
  (check-equal? (webify-correlated-begin-directory-keys
                 real-expander-begin-directory-summary)
                '(data 0 1))
  (check-false
   (webify-correlated-begin-directory-description?
    '((datum (define-values (webify-top-x) 1))
      (directory-keys (#f))))))

(test-case "definition bridge resolves top-level reference after definition"
  (define-values (definition-webified _definition-importss definition-exports
                                      _definition-import-keys _definition-imports-abis
                                      _definition-exports-info)
    (correlated-first-slice real-expander-definition-linklet))
  (define definition-proc (eval-lowered-first-slice definition-webified))
  (define-values (_result export-envs binding-env)
    (webify-run-correlated-top-level-linklets/exports
     (list (list definition-proc definition-exports))
     (make-hasheq)
     #:mpi-vector '#(#%kernel)
     #:syntax-literals '#(webify-top-x)))
  (check-equal? (webify-correlated-top-level-ref
                 'webify-top-x
                 binding-env
                 export-envs)
                1))

(test-case "begin directory runner composes definition and expression entries"
  (define-values (definition-webified _definition-importss definition-exports
                                      _definition-import-keys _definition-imports-abis
                                      _definition-exports-info)
    (correlated-first-slice real-expander-definition-linklet))
  (define-values (expression-webified _expression-importss expression-exports
                                      _expression-import-keys _expression-imports-abis
                                      _expression-exports-info)
    (correlated-first-slice
     `(linklet ,webify-correlated-top-level-import-groups () (+ 10 5))))
  (define definition-proc (eval-lowered-first-slice definition-webified))
  (define expression-proc (eval-lowered-first-slice expression-webified))
  (define-values (result export-envs binding-env)
    (webify-run-correlated-begin-directory/exports
     real-expander-begin-directory-summary
     (list (list definition-proc definition-exports)
           (list expression-proc expression-exports))
     (make-hasheq)
     #:mpi-vector '#(#%kernel)
     #:syntax-literals '#(webify-top-x)))
  (check-equal? result 15)
  (check-equal? (length export-envs) 2)
  (check-equal? (webify-correlated-top-level-ref
                 'webify-top-x
                 binding-env
                 export-envs)
                1))

(test-case "module-shaped bundle keys differ from top expression bundle keys"
  (define top-expression-keys '(original-phase link max-phase 0))
  (define module-keys '(name decl data stx stx-data pre post cross-phase-persistent?
                             language-info realm min-phase max-phase side-effects
                             module->namespace unsafe? 0))
  (check-true (and (memq 'link top-expression-keys) #t))
  (check-false (memq 'decl top-expression-keys))
  (check-true (and (memq 'decl module-keys) #t))
  (check-true (and (memq 'data module-keys) #t))
  (check-true (and (memq 'stx module-keys) #t))
  (check-true (and (member 0 module-keys) #t)))

(module+ main
  (void))
