#lang racket/base

(require racket/string
         racket/match
         racket/file
         racket/path
         racket/runtime-path
         racket/system
         rackunit
         (only-in "../compiler.rkt" comp)
         "known.rkt"
         "module-adapter.rkt"
         "module-composer.rkt"
         "module-instance.rkt"
         "module-registry.rkt")

(define-runtime-path webracket-rkt "../webracket.rkt")

;; test-prim-knowns : hash?
;;   Minimal primitive facts for first-slice top-level adapter tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +))

;; run-first-slice-top-level : any/c -> values
;;   Webify, lower, and top-level-wrap a hand-written linklet.
(define (run-first-slice-top-level lk)
  (webify-linklet-first-slice-top-level
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

;; run-first-slice-top-level/imports : any/c (listof any/c) #:reserved (listof symbol?) -> values
;;   Webify, lower, and top-level-wrap a hand-written linklet with import cells.
(define (run-first-slice-top-level/imports lk import-args #:reserved [reserved '()])
  (webify-linklet-first-slice-top-level/imports
   lk
   import-args
   #:reserved             reserved
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

;; compose-linklet-first-slices : (listof webify-linklet-slice-spec?) #:tail (listof any/c) -> values
;;   Compose hand-written linklets with the same minimal compiler context as adapter tests.
(define (compose-linklet-first-slices specs #:tail [tail-forms '((void))])
  (webify-compose-linklet-first-slices
   specs
   #:tail                  tail-forms
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

;; compose-module-registry : webify-module-registry? (listof symbol?) #:tail (listof any/c) -> values
;;   Compose registry entries with the same minimal compiler context as adapter tests.
(define (compose-module-registry registry order #:tail [tail-forms '((void))])
  (webify-compose-module-registry
   registry
   order
   #:tail                  tail-forms
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

;; wat-string : any/c -> string?
;;   Render compiler output into a string for focused smoke assertions.
(define (wat-string wat)
  (format "~s" wat))

;; run-webracket : (listof string?) path? -> (values exact-integer? string?)
;;   Run the local webracket command and capture combined output.
(define (run-webracket args cwd)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr]
                   [current-directory cwd])
      (apply system*/exit-code
             (find-executable-path "racket")
             (path->string webracket-rkt)
             args)))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; write-datum-program! : path-string? any/c -> void?
;;   Write one generated top-level datum as a source file.
(define (write-datum-program! path datum)
  (call-with-output-file path
    (lambda (out)
      (write datum out)
      (newline out))
    #:exists 'truncate/replace))

;; append-top-level-form : any/c any/c -> any/c
;;   Append one observable form to a generated top-level begin program.
(define (append-top-level-form datum form)
  (match datum
    [`(begin ,body ...)
     `(begin ,@body ,form)]
    [_
     (error 'append-top-level-form
            "expected generated adapter datum to be a begin form")]))

;; begin-body : any/c -> (listof any/c)
;;   Extract body forms from a generated top-level begin program.
(define (begin-body datum)
  (match datum
    [`(begin ,body ...)
     body]
    [_
     (error 'begin-body
            "expected generated adapter datum to be a begin form")]))

;; normalize-symbols : any/c -> any/c
;;   Compare generated top-level datums by symbol spelling instead of identity.
(define (normalize-symbols v)
  (cond
    [(symbol? v) (symbol->string v)]
    [(pair? v)   (cons (normalize-symbols (car v))
                       (normalize-symbols (cdr v)))]
    [(vector? v) (list->vector (map normalize-symbols (vector->list v)))]
    [else        v]))

(test-case "first-slice adapter builds top-level syntax"
  (define-values (stx exports exports-info)
    (run-first-slice-top-level '(linklet () (x)
                                  (define-values (x) (+ 1 2)))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id
         ("lambda" ("instance-variable-reference" "x1")
           ("define" "x" 3)
           ("module-variable-define!" "x1" "x" ("quote" "consistent"))))
       ("define" ,cell-id ("module-variable-make" ("quote" "x")))
       (,proc-call-id ("quote" "webify-instance") ,cell-arg-id)
       ("define" "x" ("module-variable-ref" ,cell-ref-id))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$0")
     (check-equal? proc-call-id proc-id)
     (check-equal? cell-id "webify-export-cell0$0")
     (check-equal? cell-arg-id cell-id)
     (check-equal? cell-ref-id cell-id)]
    [other
     (fail-check (format "unexpected top-level shape: ~s" other))])
  (check-equal? exports '(x))
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 3))

(test-case "first-slice adapter output compiles through normal compiler"
  (define-values (stx _exports _exports-info)
    (run-first-slice-top-level '(linklet () (x)
                                  (define-values (x) 1)
                                  (set! x 2))))
  (define wat (wat-string (comp stx)))
  (check-true (string-contains? wat "$ModuleVariable"))
  (check-true (string-contains? wat "$module-variable-make"))
  (check-true (string-contains? wat "$module-variable-ref"))
  (check-true (string-contains? wat "$module-variable-set!")))

(test-case "first-slice adapter handles import-free linklet with no exports"
  (define-values (stx exports exports-info)
    (run-first-slice-top-level '(linklet () ()
                                  (define-values (x) 1))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id
         ("lambda" ("instance-variable-reference")
           ("define" "x" 1)
           ("void")))
       (,proc-call-id ("quote" "webify-instance"))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$0")
     (check-equal? proc-call-id proc-id)]
    [other
     (fail-check (format "unexpected no-export shape: ~s" other))])
  (check-equal? exports '())
  (check-equal? exports-info '#hasheq())
  (define wat (wat-string (comp stx)))
  (check-false (string-contains? wat "$module-variable-make"))
  (check-false (string-contains? wat "$module-variable-ref")))

(test-case "first-slice adapter exposes multiple exports in order"
  (define-values (stx exports exports-info)
    (run-first-slice-top-level '(linklet () (x y)
                                  (define-values (x) 1)
                                  (define-values (y) 2))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id ,_)
       ("define" ,cell0-id ("module-variable-make" ("quote" "x")))
       ("define" ,cell1-id ("module-variable-make" ("quote" "y")))
       (,proc-call-id ("quote" "webify-instance") ,cell0-arg-id ,cell1-arg-id)
       ("define" "x" ("module-variable-ref" ,cell0-ref-id))
       ("define" "y" ("module-variable-ref" ,cell1-ref-id))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$0")
     (check-equal? proc-call-id proc-id)
     (check-equal? cell0-id "webify-export-cell0$0")
     (check-equal? cell1-id "webify-export-cell1$0")
     (check-equal? cell0-arg-id cell0-id)
     (check-equal? cell1-arg-id cell1-id)
     (check-equal? cell0-ref-id cell0-id)
     (check-equal? cell1-ref-id cell1-id)]
    [other
     (fail-check (format "unexpected multi-export shape: ~s" other))])
  (check-equal? exports '(x y))
  (check-equal? (known-literal-value (hash-ref exports-info 'x)) 1)
  (check-equal? (known-literal-value (hash-ref exports-info 'y)) 2))

(test-case "first-slice adapter reads final mutated export value"
  (define-values (stx exports exports-info)
    (run-first-slice-top-level '(linklet () (x)
                                  (define-values (x) 1)
                                  (set! x 2))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id ,_)
       ("define" ,cell-id ("module-variable-make" ("quote" "x")))
       (,proc-call-id ("quote" "webify-instance") ,cell-arg-id)
       ("define" "x" ("module-variable-ref" ,cell-ref-id))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$0")
     (check-equal? proc-call-id proc-id)
     (check-equal? cell-id "webify-export-cell0$0")
     (check-equal? cell-arg-id cell-id)
     (check-equal? cell-ref-id cell-id)]
    [other
     (fail-check (format "unexpected mutated-export shape: ~s" other))])
  (check-equal? exports '(x))
  (check-false (hash-ref exports-info 'x #f)))

(test-case "first-slice adapter exposes callable export binding"
  (define-values (stx exports exports-info)
    (run-first-slice-top-level '(linklet () (f)
                                  (define-values (f)
                                    (lambda (x) (+ x 1))))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id ,_)
       ("define" ,cell-id ("module-variable-make" ("quote" "f")))
       (,proc-call-id ("quote" "webify-instance") ,cell-arg-id)
       ("define" "f" ("module-variable-ref" ,cell-ref-id))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$0")
     (check-equal? proc-call-id proc-id)
     (check-equal? cell-id "webify-export-cell0$0")
     (check-equal? cell-arg-id cell-id)
     (check-equal? cell-ref-id cell-id)]
    [other
     (fail-check (format "unexpected callable-export shape: ~s" other))])
  (check-equal? exports '(f))
  (check-true (known-procedure/can-inline? (hash-ref exports-info 'f)))
  (define wat (wat-string (comp stx)))
  (check-true (string-contains? wat "$module-variable-ref"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "first-slice adapter avoids helper/export name collisions"
  (define-values (stx exports _exports-info)
    (run-first-slice-top-level '(linklet () (webify-linklet-proc)
                                  (define-values (webify-linklet-proc) 1))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id ,_)
       ("define" ,cell-id ("module-variable-make" ("quote" "webify-linklet-proc")))
       (,proc-call-id ("quote" "webify-instance") ,cell-arg-id)
       ("define" "webify-linklet-proc" ("module-variable-ref" ,cell-ref-id))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$0")
     (check-equal? proc-call-id proc-id)
     (check-equal? cell-id "webify-export-cell0$0")
     (check-equal? cell-arg-id cell-id)
     (check-equal? cell-ref-id cell-id)]
    [other
     (fail-check (format "unexpected collision shape: ~s" other))])
  (check-equal? exports '(webify-linklet-proc)))

(test-case "first-slice adapter increments helper names on deterministic collisions"
  (define-values (stx exports _exports-info)
    (run-first-slice-top-level '(linklet () (webify-linklet-proc$0 webify-export-cell0$0)
                                  (define-values (webify-linklet-proc$0) 1)
                                  (define-values (webify-export-cell0$0) 2))))
  (match (normalize-symbols (syntax->datum stx))
    [`("begin"
       ("define" ,proc-id ,_)
       ("define" ,cell0-id ("module-variable-make" ("quote" "webify-linklet-proc$0")))
       ("define" ,cell1-id ("module-variable-make" ("quote" "webify-export-cell0$0")))
       (,proc-call-id ("quote" "webify-instance") ,cell0-arg-id ,cell1-arg-id)
       ("define" "webify-linklet-proc$0" ("module-variable-ref" ,cell0-ref-id))
       ("define" "webify-export-cell0$0" ("module-variable-ref" ,cell1-ref-id))
       ("void"))
     (check-equal? proc-id "webify-linklet-proc$1")
     (check-equal? proc-call-id proc-id)
     (check-equal? cell0-id "webify-export-cell0$1")
     (check-equal? cell1-id "webify-export-cell1$0")
     (check-equal? cell0-arg-id cell0-id)
     (check-equal? cell1-arg-id cell1-id)
     (check-equal? cell0-ref-id cell0-id)
     (check-equal? cell1-ref-id cell1-id)]
    [other
     (fail-check (format "unexpected deterministic-collision shape: ~s" other))])
  (check-equal? exports '(webify-linklet-proc$0 webify-export-cell0$0)))

(test-case "first-slice adapter exposes helper ids for sequential composition"
  (check-equal? (first-slice-top-level-helper-ids '(x))
                '(webify-linklet-proc$0 webify-export-cell0$0))
  (check-equal? (first-slice-top-level-export-cell-ids '(x))
                '#hasheq((x . webify-export-cell0$0)))
  (check-equal? (first-slice-top-level-helper-ids
                 '(y)
                 #:reserved '(webify-linklet-proc$0 webify-export-cell0$0))
                '(webify-linklet-proc$1 webify-export-cell0$1))
  (check-equal? (first-slice-top-level-export-cell-ids
                 '(y)
                 #:reserved '(webify-linklet-proc$0 webify-export-cell0$0))
                '#hasheq((y . webify-export-cell0$1))))

(test-case "module instance records generated export cells"
  (define instance (make-webify-module-instance 'a '(x y)))
  (check-equal? (webify-module-instance-name instance) 'a)
  (check-equal? (webify-module-instance-exports instance) '(x y))
  (check-equal? (webify-module-instance-helper-ids instance)
                '(webify-linklet-proc$0 webify-export-cell0$0 webify-export-cell1$0))
  (check-equal? (webify-module-instance-export-cell-id instance 'x)
                'webify-export-cell0$0)
  (check-equal? (webify-module-instance-export-cell-id instance 'y)
                'webify-export-cell1$0)
  (check-equal? (webify-module-instance-reserved-ids instance)
                '(x y webify-linklet-proc$0 webify-export-cell0$0 webify-export-cell1$0)))

(test-case "module instance builds renamed import cell environments"
  (define instance (make-webify-module-instance 'a '(x y)))
  (check-equal? (webify-module-instance-import-env instance
                                                   '((ext-x . x) y))
                '#hasheq((ext-x . webify-export-cell0$0)
                          (y . webify-export-cell1$0))))

(test-case "first-slice adapter composes sequential slices with reserved helpers"
  (define first-datum
    (first-slice->top-level-datum '(lambda (instance-variable-reference x1)
                                     (define x 10)
                                     (module-variable-define! x1 x 'consistent))
                                   '(x)))
  (define first-reserved
    (append '(x)
            (first-slice-top-level-helper-ids '(x))))
  (define second-datum
    (first-slice->top-level-datum '(lambda (instance-variable-reference y1)
                                     (define y 20)
                                     (module-variable-define! y1 y 'consistent))
                                   '(y)
                                   #:reserved first-reserved))
  (define combined
    `(begin
       ,@(begin-body first-datum)
       ,@(begin-body second-datum)
       (void)))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1" ("quote" "webify-instance") "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected composed shape: ~s" other))])
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-make"))
  (check-true (string-contains? wat "$module-variable-ref")))

(test-case "first-slice adapter composes explicit import cells"
  (define first-datum
    (first-slice->top-level-datum '(lambda (instance-variable-reference x1)
                                     (define x 10)
                                     (module-variable-define! x1 x 'consistent))
                                   '(x)))
  (define first-helper-ids
    (first-slice-top-level-helper-ids '(x)))
  (define first-export-cell-id
    (hash-ref (first-slice-top-level-export-cell-ids '(x)) 'x))
  (define second-datum
    (first-slice->top-level-datum/imports
     '(lambda (instance-variable-reference imported-x y1)
        (define effect
          (begin
            (module-variable-define!
             y1
             (module-variable-ref/no-check imported-x)
             'constant)
            (void)))
        (define y (module-variable-ref/no-check y1))
        (void))
     (list first-export-cell-id)
     '(y)
     #:reserved (append '(x) first-helper-ids)))
  (define combined
    `(begin
       ,@(begin-body first-datum)
       ,@(begin-body second-datum)
       (void)))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("quote" "webify-instance")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected explicit-import composition shape: ~s" other))])
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "module instances compose explicit import cells"
  (define-values (first-datum first-instance)
    (first-slice->module-instance-datum
     'a
     '(lambda (instance-variable-reference x1)
        (define x 10)
        (module-variable-define! x1 x 'consistent))
     '(x)))
  (define second-import-env
    (webify-module-instance-import-env first-instance '((ext-x . x))))
  (define-values (second-datum second-instance)
    (first-slice->module-instance-datum/imports
     'b
     '(lambda (instance-variable-reference imported-x y1)
        (define effect
          (begin
            (module-variable-define!
             y1
             (module-variable-ref/no-check imported-x)
             'constant)
            (void)))
        (define y (module-variable-ref/no-check y1))
        (void))
     '((ext-x))
     (list second-import-env)
     '(y)
     #:reserved (webify-module-instance-reserved-ids first-instance)))
  (define combined
    `(begin
       ,@(begin-body first-datum)
       ,@(begin-body second-datum)
       (void)))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("quote" "webify-instance")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected module-instance composition shape: ~s" other))])
  (check-equal? (webify-module-instance-name second-instance) 'b)
  (check-equal? (webify-module-instance-export-cell-id second-instance 'y)
                'webify-export-cell0$1)
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "module composer splices adapted fragments"
  (define-values (first-datum first-instance)
    (first-slice->module-instance-datum
     'a
     '(lambda (instance-variable-reference x1)
        (define x 10)
        (module-variable-define! x1 x 'consistent))
     '(x)))
  (define-values (second-datum second-instance)
    (first-slice->module-instance-datum
     'b
     '(lambda (instance-variable-reference y1)
        (define y 20)
        (module-variable-define! y1 y 'consistent))
     '(y)
     #:reserved (webify-module-instance-reserved-ids first-instance)))
  (define combined
    (webify-compose-module-fragments
     (list (webify-module-fragment first-datum first-instance)
           (webify-module-fragment second-datum second-instance))))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1" ("quote" "webify-instance") "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected composed-fragment shape: ~s" other))])
  (check-true (string-contains? (wat-string (comp (datum->syntax #f combined)))
                                "$module-variable-ref"))
  (check-true (string-contains?
               (wat-string
                (comp (webify-compose-module-fragments-syntax
                       (list (webify-module-fragment first-datum first-instance)
                             (webify-module-fragment second-datum second-instance)))))
               "$module-variable-ref")))

(test-case "module composer adapts lowered slices and resolves prior-instance imports"
  (define-values (combined fragments instances)
    (webify-compose-lowered-first-slices
     (list
      (webify-lowered-slice-spec
       'a
       '(lambda (instance-variable-reference x1)
          (define x 10)
          (module-variable-define! x1 x 'consistent))
       '()
       '()
       '(x))
      (webify-lowered-slice-spec
       'b
       '(lambda (instance-variable-reference imported-x y1)
          (define effect
            (begin
              (module-variable-define!
               y1
               (module-variable-ref/no-check imported-x)
               'constant)
              (void)))
          (define y (module-variable-ref/no-check y1))
          (void))
       '((ext-x))
       '(((ext-x a x)))
       '(y)))))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("quote" "webify-instance")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected lowered-composer shape: ~s" other))])
  (check-equal? (length fragments) 2)
  (check-equal? (sort (hash-keys instances) symbol<?) '(a b))
  (check-equal? (webify-module-instance-export-cell-id (hash-ref instances 'b) 'y)
                'webify-export-cell0$1)
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "module composer adapts linklet slices and resolves prior-instance imports"
  (define-values (combined fragments instances exports-infos)
    (compose-linklet-first-slices
     (list
      (webify-linklet-slice-spec
       'a
       '(linklet () (x)
          (define-values (x) 10))
       '())
      (webify-linklet-slice-spec
       'b
       '(linklet (([ext-x x])) (y)
          (define-values (y) x))
       '(((ext-x a x)))))))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("quote" "webify-instance")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected linklet-composer shape: ~s" other))])
  (check-equal? (length fragments) 2)
  (check-equal? (sort (hash-keys instances) symbol<?) '(a b))
  (check-true (known-constant? (hash-ref (hash-ref exports-infos 'b) 'y)))
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "module registry stores named linklets"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'a
   '(linklet () (x)
      (define-values (x) 10)))
  (webify-module-registry-add!
   registry
   'b
   '(linklet (([ext-x x])) (y)
      (define-values (y) x))
   #:imports '((ext-x a x)))
  (check-equal? (webify-module-registry-names registry) '(a b))
  (define b-entry (webify-module-registry-ref registry 'b))
  (check-equal? (webify-module-registry-entry-name b-entry) 'b)
  (check-equal? (webify-module-registry-entry-imports b-entry)
                '((ext-x a x))))

(test-case "module registry composes named linklets"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'a
   '(linklet () (x)
      (define-values (x) 10)))
  (webify-module-registry-add!
   registry
   'b
   '(linklet (([ext-x x])) (y)
      (define-values (y) x))
   #:imports '((ext-x a x)))
  (define-values (combined fragments instances exports-infos)
    (compose-module-registry registry '(a b)))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("quote" "webify-instance")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected registry-composer shape: ~s" other))])
  (check-equal? (length fragments) 2)
  (check-equal? (sort (hash-keys instances) symbol<?) '(a b))
  (check-true (known-constant? (hash-ref (hash-ref exports-infos 'b) 'y)))
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "first-slice adapter wraps imported linklet with explicit cells"
  (define-values (first-stx first-exports _first-exports-info)
    (run-first-slice-top-level '(linklet () (x)
                                  (define-values (x) 10))))
  (define first-helper-ids
    (first-slice-top-level-helper-ids first-exports))
  (define first-export-cell-id
    (hash-ref (first-slice-top-level-export-cell-ids first-exports) 'x))
  (define import-args
    (first-slice-import-cell-args '((ext-x))
                                  (list (hasheq 'ext-x first-export-cell-id))))
  (define-values (second-stx importss exports exports-info)
    (run-first-slice-top-level/imports
     '(linklet (([ext-x x])) (y)
        (define-values (y) x))
     import-args
     #:reserved (append first-exports first-helper-ids)))
  (define combined
    `(begin
       ,@(begin-body (syntax->datum first-stx))
       ,@(begin-body (syntax->datum second-stx))
       (void)))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("quote" "webify-instance") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("quote" "webify-instance")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected imported-wrapper composition shape: ~s" other))])
  (check-equal? importss '((ext-x)))
  (check-equal? exports '(y))
  (check-true (known-constant? (hash-ref exports-info 'y)))
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "first-slice import cell resolver preserves grouped order"
  (check-equal? (first-slice-import-cell-args
                 '((a b) (a))
                 (list (hasheq 'a 'a0-cell
                               'b 'b0-cell)
                       (hasheq 'a 'a1-cell)))
                '(a0-cell b0-cell a1-cell)))

(test-case "first-slice adapter rejects duplicate top-level exports"
  (check-exn
   #rx"duplicate exports are not supported"
   (lambda ()
     (first-slice->top-level-datum '(lambda (instance-variable-reference x1 x2)
                                      (void))
                                    '(x x)))))

(test-case "first-slice adapter rejects non-symbol top-level exports"
  (check-exn
   #rx"\\(listof symbol\\?\\)"
   (lambda ()
     (first-slice->top-level-datum '(lambda (instance-variable-reference x1)
                                      (void))
                                    '(x 1)))))

(test-case "first-slice adapter rejects non-symbol reserved helper ids"
  (check-exn
   #rx"\\(listof symbol\\?\\)"
   (lambda ()
     (first-slice->top-level-datum '(lambda (instance-variable-reference x1)
                                      (void))
                                    '(x)
                                    #:reserved '(not-a-problem 1)))))

(test-case "first-slice adapter rejects non-list import args"
  (check-exn
   #rx"list\\?"
   (lambda ()
     (first-slice->top-level-datum/imports
      '(lambda (instance-variable-reference imported-x x1)
         (void))
      'not-a-list
      '(x)))))

(test-case "first-slice adapter rejects imported linklet import count mismatch"
  (check-exn
   #rx"explicit import cell count does not match linklet imports"
   (lambda ()
     (run-first-slice-top-level/imports
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      '()))))

(test-case "first-slice import cell resolver rejects group count mismatch"
  (check-exn
   #rx"import cell environment count does not match import groups"
   (lambda ()
     (first-slice-import-cell-args '((a) (b))
                                   (list (hasheq 'a 'a-cell))))))

(test-case "first-slice import cell resolver rejects missing import cell"
  (check-exn
   #rx"missing import cell"
   (lambda ()
     (first-slice-import-cell-args '((a b))
                                   (list (hasheq 'a 'a-cell))))))

(test-case "module instance rejects missing exports"
  (check-exn
   #rx"module instance has no such export"
   (lambda ()
     (webify-module-instance-export-cell-id
      (make-webify-module-instance 'a '(x))
      'missing))))

(test-case "module instance rejects duplicate renamed imports"
  (check-exn
   #rx"duplicate import names are not supported"
   (lambda ()
     (webify-module-instance-import-env
      (make-webify-module-instance 'a '(x y))
      '((same . x) (same . y))))))

(test-case "module composer rejects unknown import source instances"
  (check-exn
   #rx"import source references an unknown instance"
   (lambda ()
     (webify-compose-lowered-first-slices
      (list
       (webify-lowered-slice-spec
        'b
        '(lambda (instance-variable-reference imported-x y1)
           (void))
        '((ext-x))
        '(((ext-x missing x)))
        '(y)))))))

(test-case "module composer rejects duplicate instance names"
  (check-exn
   #rx"duplicate module instance names are not supported"
   (lambda ()
     (webify-compose-lowered-first-slices
      (list
       (webify-lowered-slice-spec
        'a
        '(lambda (instance-variable-reference x1)
           (void))
        '()
        '()
        '(x))
       (webify-lowered-slice-spec
        'a
        '(lambda (instance-variable-reference y1)
           (void))
        '()
        '()
        '(y)))))))

(test-case "module composer rejects import sources on import-free slices"
  (check-exn
   #rx"import-free slices cannot have import sources"
   (lambda ()
     (webify-compose-lowered-first-slices
      (list
       (webify-lowered-slice-spec
        'a
        '(lambda (instance-variable-reference x1)
           (void))
        '()
        '(((ext-x a x)))
        '(x)))))))

(test-case "module composer rejects import sources on import-free linklets"
  (check-exn
   #rx"import-free linklets cannot have import sources"
   (lambda ()
     (compose-linklet-first-slices
      (list
       (webify-linklet-slice-spec
        'a
        '(linklet () (x)
           (define-values (x) 1))
        '(((ext-x a x)))))))))

(test-case "module composer rejects linklet import source group mismatches"
  (check-exn
   #rx"import source group count does not match linklet imports"
   (lambda ()
     (compose-linklet-first-slices
      (list
       (webify-linklet-slice-spec
        'a
        '(linklet () (x)
           (define-values (x) 1))
        '())
       (webify-linklet-slice-spec
        'b
        '(linklet (([ext-x x])) (y)
           (define-values (y) x))
        '()))))))

(test-case "module registry rejects duplicate entries"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'a
   '(linklet () (x)
      (define-values (x) 1)))
  (check-exn
   #rx"duplicate module registry entries are not supported"
   (lambda ()
     (webify-module-registry-add!
      registry
      'a
      '(linklet () (y)
         (define-values (y) 2))))))

(test-case "module registry rejects unknown entries"
  (define registry (make-webify-module-registry))
  (check-exn
   #rx"unknown module registry entry"
   (lambda ()
     (webify-module-registry-ref registry 'missing))))

(test-case "module registry rejects dependencies not earlier in composition order"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'a
   '(linklet () (x)
      (define-values (x) 1)))
  (webify-module-registry-add!
   registry
   'b
   '(linklet (([ext-x x])) (y)
      (define-values (y) x))
   #:imports '((ext-x a x)))
  (check-exn
   #rx"registry import dependency must appear earlier in the composition order"
   (lambda ()
     (compose-module-registry registry '(b))))
  (check-exn
   #rx"registry import dependency must appear earlier in the composition order"
   (lambda ()
     (compose-module-registry registry '(b a)))))

(test-case "module registry rejects duplicate flat import names"
  (define registry (make-webify-module-registry))
  (check-exn
   #rx"duplicate registry import names are not supported"
   (lambda ()
     (webify-module-registry-add!
      registry
      'b
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      #:imports '((ext-x a x) (ext-x c x))))))

(test-case "first-slice adapter rejects non-lambda lowered values"
  (check-exn
   #rx"expected lowered first-slice value to be a lambda"
   (lambda ()
     (first-slice->top-level-datum '(begin (void)) '(x)))))

(test-case "first-slice adapter rejects variable-arity lowered lambdas"
  (check-exn
   #rx"expected lowered first-slice lambda to have fixed arity"
   (lambda ()
     (first-slice->top-level-datum '(lambda args (void)) '(x)))))

(test-case "first-slice adapter rejects non-symbol lowered lambda formals"
  (check-exn
   #rx"expected lowered first-slice lambda formals to be symbols"
   (lambda ()
     (first-slice->top-level-datum '(lambda (instance-variable-reference 1)
                                      (void))
                                    '(x)))))

(test-case "first-slice adapter rejects duplicate lowered lambda formals"
  (check-exn
   #rx"duplicate lowered first-slice lambda formals are not supported"
   (lambda ()
     (first-slice->top-level-datum '(lambda (x x)
                                      (void))
                                    '(y)))))

(test-case "first-slice adapter rejects lowered lambda export arity mismatch"
  (check-exn
   #rx"lowered first-slice lambda arity does not match imports and exports"
   (lambda ()
     (first-slice->top-level-datum '(lambda (instance-variable-reference)
                                      (void))
                                    '(x)))))

(unless (getenv "WEBIFY_SKIP_CLI_SMOKE")
  (test-case "first-slice adapter output compiles through webracket CLI"
    (define source-dir (make-temporary-file "webracket-first-slice-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-first-slice-dest-~a" 'directory))
    (define source-path (build-path source-dir "first-slice-module.rkt"))
    (define wat-path    (build-path dest-dir "first-slice-module.wat"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (stx _exports _exports-info)
          (run-first-slice-top-level '(linklet () (x)
                                        (define-values (x) 1)
                                        (set! x 2))))
        (write-datum-program! source-path (syntax->datum stx))
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-true (file-exists? wat-path))
        (define wat (file->string wat-path))
        (check-true (string-contains? wat "(type $ModuleVariable "))
        (check-true (string-contains? wat "(call $module-variable-make"))
        (check-true (string-contains? wat "(call $module-variable-ref"))
        (check-true (string-contains? wat "(call $module-variable-set!")))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "first-slice adapter output runs and exposes final export value"
    (define source-dir (make-temporary-file "webracket-first-slice-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-first-slice-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "first-slice-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (stx _exports _exports-info)
          (run-first-slice-top-level '(linklet () (x)
                                        (define-values (x) 1)
                                        (set! x 2))))
        (write-datum-program!
         source-path
         (append-top-level-form (syntax->datum stx) '(js-log x)))
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^2$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "first-slice adapter imported composition runs and exposes final export value"
    (define source-dir (make-temporary-file "webracket-first-slice-import-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-first-slice-import-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "first-slice-import-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (first-stx first-exports _first-exports-info)
          (run-first-slice-top-level '(linklet () (x)
                                        (define-values (x) 10))))
        (define first-helper-ids
          (first-slice-top-level-helper-ids first-exports))
        (define first-export-cell-id
          (hash-ref (first-slice-top-level-export-cell-ids first-exports) 'x))
        (define import-args
          (first-slice-import-cell-args '((ext-x))
                                        (list (hasheq 'ext-x first-export-cell-id))))
        (define-values (second-stx _importss _exports _exports-info)
          (run-first-slice-top-level/imports
           '(linklet (([ext-x x])) (y)
              (define-values (y) x))
           import-args
           #:reserved (append first-exports first-helper-ids)))
        (define combined
          (webify-compose-module-fragments
           (list
            (webify-module-fragment
             (syntax->datum first-stx)
             (make-webify-module-instance 'a first-exports))
            (webify-module-fragment
             (syntax->datum second-stx)
             (make-webify-module-instance
              'b
              '(y)
              #:reserved (append first-exports first-helper-ids))))
           #:tail '((js-log y))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer output runs and exposes imported export value"
    (define source-dir (make-temporary-file "webracket-linklet-composer-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-linklet-composer-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "linklet-composer-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'a
             '(linklet () (x)
                (define-values (x) 10))
             '())
            (webify-linklet-slice-spec
             'b
             '(linklet (([ext-x x])) (y)
                (define-values (y) x))
             '(((ext-x a x)))))
           #:tail '((js-log y))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "module registry output runs and exposes imported export value"
    (define source-dir (make-temporary-file "webracket-registry-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-registry-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "registry-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define registry (make-webify-module-registry))
        (webify-module-registry-add!
         registry
         'a
         '(linklet () (x)
            (define-values (x) 10)))
        (webify-module-registry-add!
         registry
         'b
         '(linklet (([ext-x x])) (y)
            (define-values (y) x))
         #:imports '((ext-x a x)))
        (define-values (combined _fragments _instances _exports-infos)
          (compose-module-registry registry '(a b) #:tail '((js-log y))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(test-case "first-slice adapter rejects imports for now"
  (check-exn
   #rx"module prompts are not supported|imported linklets are not supported"
   (lambda ()
     (run-first-slice-top-level '(linklet (([ext-a a])) (x)
                                   (define-values (x) a))))))

(module+ main
  (void))
