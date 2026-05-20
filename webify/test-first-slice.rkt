#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/first-slice.rkt"
         "../pkgs/webracket-lib/compiler/webify/known.rkt"
         "../pkgs/webracket-lib/compiler/webify/wrap.rkt")

;; test-prim-knowns : hash?
;;   Minimal primitive facts for first-slice integration tests.
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

(test-case "first-slice wrapper lowers constant export and preserves metadata"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet () (x)
                        (define-values (x) (+ 1 2)))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 3)
                  ("module-variable-define!" "x1" "x" ("quote" "consistent"))))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 3))

(test-case "first-slice wrapper handles import-free linklet with no exports"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet () ()
                        (define-values (x) 1))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference")
                  ("define" "x" 1)
                  ("void")))
  (check-equal? importss '())
  (check-equal? exports '())
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-equal? exports-info '#hasheq()))

(test-case "first-slice wrapper simplifies trivial mutation prompt"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet () (x)
                        (define-values (x) 1)
                        (set! x 2))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 1)
                  ("module-variable-define!" "x1" "x" ("quote" #f))
                  ("module-variable-set!" "x1" 2)))
  (check-equal? importss '())
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '())
  (check-false (hash-ref exports-info 'x #f)))

(test-case "first-slice wrapper erases singleton metadata prompt for imported value"
  (define-values (webified importss exports import-keys imports-abis exports-info)
    (run-first-slice '(linklet (([ext-a a])) (x)
                       (define-values (x) a))))
  (check-equal? (normalize-symbols webified)
                '("lambda" ("instance-variable-reference" "a1" "x2")
                  ("define" "effect3"
                    ("begin"
                     ("module-variable-define!"
                      "x2"
                      ("module-variable-ref/no-check" "a1")
                      ("quote" "constant"))
                     ("void")))
                  ("define" "x" ("module-variable-ref/no-check" "x2"))
                  ("void")))
  (check-equal? importss '((ext-a)))
  (check-equal? exports '(x))
  (check-false import-keys)
  (check-equal? imports-abis '((#f)))
  (check-true (known-constant? (hash-ref exports-info 'x))))
