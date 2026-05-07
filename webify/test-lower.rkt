#lang racket/base

(require rackunit
         "known.rkt"
         "lower.rkt"
         "webify.rkt"
         "wrap.rkt")

;; test-prim-knowns : hash?
;;   Minimal primitive facts for webify-to-lower tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +))

;; run-webify : any/c -> any/c
;;   Return only the webified expression for a hand-written linklet.
(define (run-webify lk)
  (define-values (webified importss exports import-keys imports-abis exports-info)
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
  webified)

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

(test-case "direct module variable forms"
  (define lowered
    (lower-module-variable-ops
     '(begin
        (define cell (make-internal-variable 'x))
        (variable-set!/define cell 1 'constant)
        (variable-ref cell)
        (variable-ref/no-check cell)
        (variable-set! cell 2)
        (variable-set!/check-undefined cell 3)
        (set-consistent-variables!/define (vector cell) (vector 4))
        (make-instance-variable-reference instance-variable-reference cell))))
  (check-equal? (normalize-symbols lowered)
                '("begin"
                  ("define" "cell" ("module-variable-make" ("quote" "x")))
                  ("module-variable-define!" "cell" 1 ("quote" "constant"))
                  ("module-variable-ref" "cell")
                  ("module-variable-ref/no-check" "cell")
                  ("module-variable-set!" "cell" 2)
                  ("module-variable-set!/check-undefined!" "cell" 3)
                  ("module-variables-define-consistent!" ("vector" "cell") ("vector" 4))
                  ("module-variable-reference" "instance-variable-reference" "cell")))
  (check-true (schemify-module-variable-free? lowered))
  (check-eq? (assert-schemify-module-variable-free lowered) lowered))

(test-case "module variable reference predicates lower to cell metadata"
  (check-equal?
   (normalize-symbols
    (lower-module-variable-ops
     '(list
       (variable-reference-constant?
        (make-instance-variable-reference instance-variable-reference cell))
       (variable-reference-constant?
        (module-variable-reference instance-variable-reference cell))
       (variable-reference-from-unsafe?
        (make-instance-variable-reference instance-variable-reference cell))
       (variable-reference-from-unsafe?
        (module-variable-reference instance-variable-reference cell)))))
   '("list"
     ("if" ("module-variable-constance" "cell") #t #f)
     ("if" ("module-variable-constance" "cell") #t #f)
     #f
     #f)))

(test-case "schemify module variable assertion catches missed forms"
  (check-false (schemify-module-variable-free? '(begin (variable-ref x))))
  (check-true (schemify-module-variable-free? '(quote (variable-ref x))))
  (check-exn #rx"schemify module variable forms remain"
             (lambda ()
               (assert-schemify-module-variable-free '(begin (variable-ref x))))))

(test-case "first-slice unsupported assertion catches compatibility forms"
  (check-false (first-slice-unsupported-free? '(#%app f x)))
  (check-false (first-slice-unsupported-free? '(with-continuation-mark* push k v body)))
  (check-false (first-slice-unsupported-free? '(unsafe-struct*-ref s 0)))
  (check-true (first-slice-unsupported-free? '(unsafe-struct? s struct:s)))
  (check-true (first-slice-unsupported-free? '(#%app/no-return f x)))
  (check-true (first-slice-unsupported-free? '(raise-binding-result-arity-error 1 args)))
  (check-true (first-slice-unsupported-free? '(raise-definition-result-arity-error '(x) args)))
  (check-true (first-slice-unsupported-free? '(if (impersonator? v)
                                                  (impersonator-val v)
                                                  #f)))
  (check-true (first-slice-unsupported-free? '(quote (#%app f x))))
  (check-exn #rx"unsupported webify compatibility form remains"
             (lambda ()
               (assert-first-slice-unsupported-free '(#%app f x)))))

(test-case "module prompt is preserved as explicit helper"
  (define lowered
    (lower-module-variable-ops
     '(call-with-module-prompt
       (lambda () (variable-set! x 1))
       '(x)
       '(constant)
       x)))
  (check-equal? (normalize-symbols lowered)
                '("module-call-with-prompt"
                  ("lambda" () ("module-variable-set!" "x" 1))
                  ("quote" ("x"))
                  ("quote" ("constant"))
                  "x"))
  (check-false (module-prompt-free? lowered))
  (check-exn #rx"module prompts are not supported"
             (lambda () (assert-module-prompt-free lowered))))

(test-case "trivial module prompt can be simplified"
  (define lowered
    (lower-module-variable-ops
     '(call-with-module-prompt
       (lambda () (variable-set! x 1)))))
  (define simplified (simplify-trivial-module-prompts lowered))
  (check-equal? (normalize-symbols simplified)
                '("module-variable-set!" "x" 1))
  (check-true (module-prompt-free? simplified))
  (check-eq? (assert-module-prompt-free simplified) simplified))

(test-case "multi-body trivial module prompt preserves definition context"
  (define lowered
    (lower-module-variable-ops
     '(call-with-module-prompt
       (lambda ()
         (define x 1)
         (variable-set! cell x)))))
  (check-equal?
   (normalize-symbols (simplify-trivial-module-prompts lowered))
   '("let" ()
     ("define" "x" 1)
     ("module-variable-set!" "cell" "x"))))

(test-case "multi-value metadata module prompt lowers to cell defines"
  (define lowered
    (lower-module-variable-ops
     '(call-with-module-prompt
       (lambda () (values 1 2))
       '(x y)
       '(constant consistent)
       x-cell
       y-cell)))
  (define simplified (simplify-trivial-module-prompts lowered))
  (check-equal? (normalize-symbols simplified)
                '("let-values" ((("x" "y") ("values" 1 2)))
                  ("module-variable-define!" "x-cell" "x" ("quote" "constant"))
                  ("module-variable-define!" "y-cell" "y" ("quote" "consistent"))
                  ("void")))
  (check-true (module-prompt-free? simplified))
  (check-eq? (assert-module-prompt-free simplified) simplified))

(test-case "compatibility app markers are simplified before first-slice rejection"
  (define lowered
    (lower-module-first-slice
     '(lambda (instance-variable-reference x-cell y-cell)
        (module-call-with-prompt
         (lambda () (#%app values 1 2))
         '(x y)
         '(constant consistent)
         x-cell
         y-cell))))
  (check-equal? (normalize-symbols lowered)
                '("lambda" ("instance-variable-reference" "x-cell" "y-cell")
                  ("let-values" ((("x" "y") ("values" 1 2)))
                    ("module-variable-define!" "x-cell" "x" ("quote" "constant"))
                    ("module-variable-define!" "y-cell" "y" ("quote" "consistent"))
                    ("void")))))

(test-case "no-return compatibility app marker lowers to ordinary application"
  (check-equal?
   (normalize-symbols
    (lower-module-first-slice
     '(lambda (instance-variable-reference)
        (#%app/no-return raise-argument-error 'f "integer?" "x"))))
   '("lambda" ("instance-variable-reference")
     ("raise-argument-error" ("quote" "f") "integer?" "x"))))

(test-case "constant export lowers define operation"
  (define lowered
    (lower-module-variable-ops
     (run-webify '(linklet () (x)
                    (define-values (x) 1)))))
  (check-equal? (normalize-symbols lowered)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 1)
                  ("module-variable-define!" "x1" "x" ("quote" "consistent"))))
  (check-true (module-prompt-free? lowered))
  (check-eq? (assert-module-prompt-free lowered) lowered))

(test-case "first-slice helper lowers prompt-free export"
  (define lowered
    (lower-module-first-slice
     (run-webify '(linklet () (x)
                    (define-values (x) (+ 1 2))))))
  (check-equal? (normalize-symbols lowered)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 3)
                  ("module-variable-define!" "x1" "x" ("quote" "consistent"))))
  (check-true (schemify-module-variable-free? lowered)))

(test-case "imported value lowers prompt and no-check reads"
  (check-equal?
   (normalize-symbols
    (lower-module-variable-ops
     (run-webify '(linklet (([ext-a a])) (x)
                    (define-values (x) a)))))
   '("lambda" ("instance-variable-reference" "a1" "x2")
     ("define" "effect3"
       ("begin"
        ("module-call-with-prompt"
         ("lambda" () ("module-variable-ref/no-check" "a1"))
         ("quote" ("x"))
         ("quote" ("constant"))
         "x2")
        ("void")))
     ("define" "x" ("module-variable-ref/no-check" "x2"))
     ("void"))))

(test-case "first-slice helper erases singleton metadata prompt"
  (define lowered
    (lower-module-first-slice
     (run-webify '(linklet (([ext-a a])) (x)
                    (define-values (x) a)))))
  (check-equal? (normalize-symbols lowered)
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
  (check-true (module-prompt-free? lowered)))

(test-case "mutated export lowers set operation"
  (define lowered
    (lower-module-variable-ops
     (run-webify '(linklet () (x)
                    (define-values (x) 1)
                    (set! x 2)))))
  (check-equal? (normalize-symbols lowered)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 1)
                  ("module-variable-define!" "x1" "x" ("quote" #f))
                  ("module-call-with-prompt"
                   ("lambda" () ("module-variable-set!" "x1" 2)))))
  (define simplified (simplify-trivial-module-prompts lowered))
  (check-equal? (normalize-symbols simplified)
                '("lambda" ("instance-variable-reference" "x1")
                  ("define" "x" 1)
                  ("module-variable-define!" "x1" "x" ("quote" #f))
                  ("module-variable-set!" "x1" 2)))
  (check-true (module-prompt-free? simplified))
  (check-eq? (assert-module-prompt-free simplified) simplified))

(test-case "first-slice helper simplifies trivial prompt"
  (check-equal?
   (normalize-symbols
    (lower-module-first-slice
     (run-webify '(linklet () (x)
                    (define-values (x) 1)
                    (set! x 2)))))
   '("lambda" ("instance-variable-reference" "x1")
     ("define" "x" 1)
     ("module-variable-define!" "x1" "x" ("quote" #f))
     ("module-variable-set!" "x1" 2))))

(test-case "first-slice helper rejects unsupported compatibility form"
  (check-exn
   #rx"unsupported webify compatibility form remains"
   (lambda ()
     (lower-module-first-slice
      '(lambda (instance-variable-reference)
         (#%app/value f x))))))
