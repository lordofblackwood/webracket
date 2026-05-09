#lang racket/base

(require racket/string
         racket/match
         racket/file
         rackunit
         "first-slice.rkt"
         "test-module-support.rkt")

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

(test-case "first-slice adapter can skip top-level export aliases"
  (define-values (expr _importss exports _new-import-keys _imports-abis _exports-info)
    (webify-linklet-first-slice
     '(linklet () (xor)
        (define-values (xor) (lambda (a b) (if a (if b #f a) b))))
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
  (define datum
    (first-slice->top-level-datum
     expr
     exports
     #:define-export-aliases? #f))
  (check-not-false
   (member '("define" "webify-export-cell0$0" ("module-variable-make" ("quote" "xor")))
           (normalize-symbols datum)))
  (check-false
   (member '("define" "xor" ("module-variable-ref" "webify-export-cell0$0"))
           (normalize-symbols datum))))

(test-case "first-slice adapter can filter top-level export aliases"
  (define-values (expr _importss exports _new-import-keys _imports-abis _exports-info)
    (webify-linklet-first-slice
     '(linklet () (keep skip)
        (define-values (keep) 1)
        (define-values (skip) 2))
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
  (define normalized
    (normalize-symbols
     (first-slice->top-level-datum
      expr
      exports
      #:define-export-aliases? (lambda (export) (eq? export 'keep)))))
  (check-not-false
   (member '("define" "keep" ("module-variable-ref" "webify-export-cell0$0"))
           normalized))
  (check-false
   (member '("define" "skip" ("module-variable-ref" "webify-export-cell1$0"))
           normalized)))

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

(test-case "first-slice adapter binds imported cells to local linklet names"
  (define datum
    (first-slice->top-level-datum/imports
     '(lambda (instance-variable-reference reverse1 y2)
        (define y (1/reverse '(a b)))
        (module-variable-define! y2 y 'constant))
     '(reverse-cell)
     '(y)
     #:importss '((1/reverse))))
  (match (normalize-symbols datum)
    [`("begin"
       ("define" "webify-linklet-proc$0"
         ("lambda" ("instance-variable-reference" "reverse1" "y2")
           ("define" "1/reverse" ("module-variable-ref/no-check" "reverse1"))
           ("define" "y" ("1/reverse" ("quote" ("a" "b"))))
           ("module-variable-define!" "y2" "y" ("quote" "constant"))))
       . ,_)
     (void)]
    [other
     (fail-check (format "unexpected local import binding shape: ~s" other))]))

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

(test-case "first-slice adapter rejects imports for now"
  (check-exn
   #rx"module prompts are not supported|imported linklets are not supported"
   (lambda ()
     (run-first-slice-top-level '(linklet (([ext-a a])) (x)
                                   (define-values (x) a))))))


(module+ main
  (void))
