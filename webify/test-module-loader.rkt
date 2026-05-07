#lang racket/base

(require racket/file
         racket/path
         rackunit
         "test-module-support.rkt")

;; make-loader-test-registry : -> webify-module-registry?
;;   Build a small two-entry registry for loader tests.
(define (make-loader-test-registry)
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
      (define-values (y) (+ x 1)))
   #:imports '((ext-x a x)))
  registry)

(test-case "module loader instantiates roots once and exposes export cells"
  (define loader (make-webify-module-loader (make-loader-test-registry)))
  (define composition
    (webify-module-loader-instantiate-roots!
     loader
     '(b)
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
  (check-true (webify-module-composition? composition))
  (check-eq? (webify-module-loader-composition loader) composition)
  (check-equal? (webify-module-loader-roots loader) '(b))
  (check-eq?
   (webify-module-loader-instantiate-roots!
    loader
    '(b)
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
    #:import-keys           #f)
   composition)
  (check-equal? (webify-module-loader-export-cell-id loader 'a 'x)
                'webify-export-cell0$0)
  (check-equal? (webify-module-loader-export-cell-id loader 'b 'y)
                'webify-export-cell0$1)
  (define y-cell (webify-module-loader-export-cell-id loader 'b 'y))
  (define combined
    (webify-module-loader-with-tail
     loader
     `((js-log (module-variable-ref ,y-cell)))))
  (check-not-false
   (member '("js-log" ("module-variable-ref" "webify-export-cell0$1"))
           (normalize-symbols combined))))

(test-case "module loader rejects uninstantiated lookups and inconsistent roots"
  (define loader (make-webify-module-loader (make-loader-test-registry)))
  (check-exn
   #rx"module loader has not been instantiated"
   (lambda ()
     (webify-module-loader-export-cell-id loader 'a 'x)))
  (webify-module-loader-instantiate-roots!
   loader
   '(b)
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
   #:import-keys           #f)
  (check-exn
   #rx"module loader already instantiated different roots"
   (lambda ()
     (webify-module-loader-instantiate-roots!
      loader
      '(a)
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
      #:import-keys           #f))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "module loader output runs from export cells"
    (define source-dir (make-temporary-file "webracket-loader-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-loader-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "loader-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define loader (make-webify-module-loader (make-loader-test-registry)))
        (webify-module-loader-instantiate-roots!
         loader
         '(b)
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
         #:import-keys           #f)
        (define x-cell (webify-module-loader-export-cell-id loader 'a 'x))
        (define y-cell (webify-module-loader-export-cell-id loader 'b 'y))
        (define combined
          (webify-module-loader-with-tail
           loader
           `((js-log (module-variable-ref ,x-cell))
             (js-log (module-variable-ref ,y-cell)))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output)
        (check-regexp-match #rx"(?m:^11$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(module+ main
  (void))
