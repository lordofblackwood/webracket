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
         "module-adapter.rkt")

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
   #rx"lowered first-slice lambda arity does not match exports"
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
