#lang racket/base

(require rackunit
         "known.rkt"
         "wrap.rkt"
         "webify.rkt")

;; test-prim-knowns : hash?
;;   Minimal primitive facts for focused webify-linklet tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))
          'list (known-procedure (procedure-arity-mask list))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +
          'list list))

;; run-webify : any/c -> values
;;   Webify a hand-written linklet with stable test defaults.
(define (run-webify lk)
  (webify-linklet lk
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

;; normalize-symbols : any/c -> any/c
;;   Make deterministic gensyms comparable as ordinary strings.
(define (normalize-symbols v)
  (let ([v (unwrap v)])
    (cond
      [(symbol? v) (symbol->string v)]
      [(pair? v)   (cons (normalize-symbols (car v))
                         (normalize-symbols (cdr v)))]
      [(vector? v) (list->vector (map normalize-symbols (vector->list v)))]
      [else        v])))

(test-case "constant export"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-webify '(linklet () (x)
                   (define-values (x) 1))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "x1")
                   ("define" "x" 1)
                   ("variable-set!/define" "x1" "x" ("quote" "consistent"))))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 1))

(test-case "folding primitive rhs"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-webify '(linklet () (x)
                   (define-values (x) (+ 1 2)))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "x1")
                   ("define" "x" 3)
                   ("variable-set!/define" "x1" "x" ("quote" "consistent"))))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 3))

(test-case "imported value copied to export"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-webify '(linklet (([ext-a a])) (x)
                   (define-values (x) a))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "a1" "x2")
                   ("define" "effect3"
                     ("begin"
                      ("call-with-module-prompt"
                       ("lambda" () ("variable-ref/no-check" "a1"))
                       ("quote" ("x"))
                       ("quote" ("constant"))
                       "x2")
                      ("void")))
                   ("define" "x" ("variable-ref/no-check" "x2"))
                   ("void")))
  (check-equal? importss '((ext-a)))
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '((#f)))
  (check-true (known-constant? (hash-ref exports-info 'x))))

(test-case "lambda export preserves inlineable procedure shape"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-webify '(linklet () (f)
                   (define-values (f) (lambda (x) x)))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "f1")
                   ("define" "f" ("lambda" ("x") "x"))
                   ("variable-set!/define" "f1" "f" ("quote" "consistent"))))
  (check-equal? importss '())
  (check-equal? exports '(f))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (define f-info (hash-ref exports-info 'f))
  (check-true (known-procedure/can-inline? f-info))
  (check-equal? (normalize-symbols (known-procedure/can-inline-expr f-info))
                '("lambda" ("x") "x")))

(test-case "mutated export uses variable cell"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-webify '(linklet () (x)
                   (define-values (x) 1)
                   (set! x 2))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "x1")
                   ("define" "x" 1)
                   ("variable-set!/define" "x1" "x" ("quote" #f))
                   ("call-with-module-prompt"
                    ("lambda" () ("variable-set!" "x1" 2)))))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-false (hash-ref exports-info 'x #f)))
