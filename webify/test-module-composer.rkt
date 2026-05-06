#lang racket/base

(require racket/string
         racket/match
         racket/file
         racket/path
         rackunit
         "test-module-support.rkt")

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
  (test-case "linklet composer output runs preserved struct primitives"
    (define source-dir (make-temporary-file "webracket-struct-composer-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-struct-composer-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "struct-composer-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'struct-demo
             '(linklet () (out)
                (define-values (struct:posn make-posn posn? posn-ref posn-set!)
                  (make-struct-type 'posn #f 2 0 #f))
                (define-values (posn-x)
                  (make-struct-field-accessor posn-ref 0 'x))
                (define-values (posn-y)
                  (make-struct-field-accessor posn-ref 1 'y))
                (define-values (set-posn-y!)
                  (make-struct-field-mutator posn-set! 1 'y))
                (define-values (p)
                  (make-posn 10 20))
                (define-values (effect)
                  (begin
                    (set-posn-y! p 30)
                    (void)))
                (define-values (out)
                  (posn-y p)))
             '()))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-true (string-contains? wat "$make-struct-field-accessor"))
        (check-true (string-contains? wat "$make-struct-field-mutator"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^30$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer carries struct exports across slices"
    (define source-dir (make-temporary-file "webracket-struct-import-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-struct-import-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "struct-import-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'struct-provider
             '(linklet () (make-posn posn-y set-posn-y!)
                (define-values (struct:posn make-posn posn? posn-ref posn-set!)
                  (make-struct-type 'posn #f 2 0 #f))
                (define-values (posn-y)
                  (make-struct-field-accessor posn-ref 1 'y))
                (define-values (set-posn-y!)
                  (make-struct-field-mutator posn-set! 1 'y)))
             '())
            (webify-linklet-slice-spec
             'struct-user
             '(linklet (([make-posn make-posn]
                         [posn-y posn-y]
                         [set-posn-y! set-posn-y!])) (out)
                (define-values (p)
                  (make-posn 10 20))
                (define-values (effect)
                  (begin
                    (set-posn-y! p 30)
                    (void)))
                (define-values (out)
                  (posn-y p)))
             '((make-posn struct-provider make-posn)
               (posn-y struct-provider posn-y)
               (set-posn-y! struct-provider set-posn-y!))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-true (string-contains? wat "$make-struct-field-accessor"))
        (check-true (string-contains? wat "$make-struct-field-mutator"))
        (check-true (string-contains? wat "$module-variable-ref/no-check"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^30$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer carries sealed struct property across slices"
    (define source-dir (make-temporary-file "webracket-sealed-struct-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-sealed-struct-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "sealed-struct-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'sealed-provider
             '(linklet () (make-base base?)
                (define-values (struct:base make-base base? base-ref base-set!)
                  (make-struct-type 'base #f 1 0 #f (list (cons prop:sealed #t)))))
             '())
            (webify-linklet-slice-spec
             'sealed-user
             '(linklet (([make-base make-base]
                         [base? base?])) (out)
                (define-values (b)
                  (make-base 41))
                (define-values (out)
                  (if (and (struct-type-property? prop:sealed)
                           (base? b))
                      42
                      0)))
             '((make-base sealed-provider make-base)
               (base? sealed-provider base?))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$prop:sealed"))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-true (string-contains? wat "$struct-type-property?"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^42$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer creates child struct from imported parent type"
    (define source-dir (make-temporary-file "webracket-child-struct-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-child-struct-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "child-struct-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'parent-provider
             '(linklet () (struct:parent make-parent)
                (define-values (struct:parent make-parent parent? parent-ref parent-set!)
                  (make-struct-type 'parent #f 1 0 #f)))
             '())
            (webify-linklet-slice-spec
             'child-user
             '(linklet (([struct:parent struct:parent])) (out)
                (define-values (struct:child make-child child? child-ref child-set!)
                  (make-struct-type 'child struct:parent 1 0 #f))
                (define-values (c)
                  (make-child 10 32))
                (define-values (out)
                  (if (child? c) 42 0)))
             '((struct:parent parent-provider struct:parent))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-true (string-contains? wat "$module-variable-ref/no-check"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^42$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer rejects child struct from imported sealed parent type"
    (define source-dir (make-temporary-file "webracket-sealed-child-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-sealed-child-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "sealed-child-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'sealed-parent-provider
             '(linklet () (struct:sealed-parent)
                (define-values (struct:sealed-parent make-sealed-parent sealed-parent?
                                                     sealed-parent-ref sealed-parent-set!)
                  (make-struct-type 'sealed-parent #f 1 0 #f
                                    (list (cons prop:sealed #t)))))
             '())
            (webify-linklet-slice-spec
             'sealed-child-user
             '(linklet (([struct:sealed-parent struct:sealed-parent])) (out)
                (define-values (struct:bad-child make-bad-child bad-child?
                                                 bad-child-ref bad-child-set!)
                  (make-struct-type 'bad-child struct:sealed-parent 1 0 #f))
                (define-values (out) 0))
             '((struct:sealed-parent sealed-parent-provider struct:sealed-parent))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$prop:sealed"))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-not-equal? status 0 output)
        (check-regexp-match #rx"sealed structure type cannot be used as a supertype" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer inherits custom struct property across slices"
    (define source-dir (make-temporary-file "webracket-struct-prop-inherit-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-struct-prop-inherit-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "struct-prop-inherit-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'property-provider
             '(linklet () (prop:tag tag? tag-ref)
                (define-values (prop:tag tag? tag-ref)
                  (make-struct-type-property 'tag)))
             '())
            (webify-linklet-slice-spec
             'tagged-parent-provider
             '(linklet (([prop:tag prop:tag])) (struct:tagged-parent)
                (define-values (struct:tagged-parent make-tagged-parent tagged-parent?
                                                     tagged-parent-ref tagged-parent-set!)
                  (make-struct-type 'tagged-parent #f 1 0 #f
                                    (list (cons prop:tag 42)))))
             '((prop:tag property-provider prop:tag)))
            (webify-linklet-slice-spec
             'tagged-child-provider
             '(linklet (([struct:tagged-parent struct:tagged-parent])) (make-tagged-child tagged-child?)
                (define-values (struct:tagged-child make-tagged-child tagged-child?
                                                    tagged-child-ref tagged-child-set!)
                  (make-struct-type 'tagged-child struct:tagged-parent 1 0 #f)))
             '((struct:tagged-parent tagged-parent-provider struct:tagged-parent)))
            (webify-linklet-slice-spec
             'property-user
             '(linklet (([make-tagged-child make-tagged-child]
                         [tagged-child? tagged-child?]
                         [tag? tag?]
                         [tag-ref tag-ref])) (out)
                (define-values (child)
                  (make-tagged-child 10 32))
                (define-values (out)
                  (if (and (tagged-child? child)
                           (tag? child))
                      (tag-ref child)
                      0)))
             '((make-tagged-child tagged-child-provider make-tagged-child)
               (tagged-child? tagged-child-provider tagged-child?)
               (tag? property-provider tag?)
               (tag-ref property-provider tag-ref))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$make-struct-type-property"))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-true (string-contains? wat "$module-variable-ref/no-check"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^42$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer runs struct constructor guard across slices"
    (define source-dir (make-temporary-file "webracket-struct-guard-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-struct-guard-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "struct-guard-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'guarded-point-provider
             '(linklet () (make-guarded-point guarded-point-ref)
                (define-values (struct:guarded-point make-guarded-point guarded-point?
                                                     guarded-point-ref guarded-point-set!)
                  (make-struct-type 'guarded-point #f 2 0 #f null #f #f #f
                                    (lambda (x y name)
                                      (values (+ x 1) (+ y 2))))))
             '())
            (webify-linklet-slice-spec
             'guarded-point-user
             '(linklet (([make-guarded-point make-guarded-point]
                         [guarded-point-ref guarded-point-ref])) (out)
                (define-values (p)
                  (make-guarded-point 3 8))
                (define-values (out)
                  (+ (guarded-point-ref p 0)
                     (guarded-point-ref p 1))))
             '((make-guarded-point guarded-point-provider make-guarded-point)
               (guarded-point-ref guarded-point-provider guarded-point-ref))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$struct-constructor/with-guard"))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "unsafe-struct*"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^14$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer rejects wrong arity struct guard results"
    (define source-dir (make-temporary-file "webracket-struct-guard-bad-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-struct-guard-bad-dest-~a" 'directory))
    (define source-path (build-path source-dir "struct-guard-bad.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'bad-guard-provider
             '(linklet () (make-bad-guarded)
                (define-values (struct:bad-guarded make-bad-guarded bad-guarded?
                                                   bad-guarded-ref bad-guarded-set!)
                  (make-struct-type 'bad-guarded #f 2 0 #f null #f #f #f
                                    (lambda (x y name)
                                      (values x)))))
             '())
            (webify-linklet-slice-spec
             'bad-guard-user
             '(linklet (([make-bad-guarded make-bad-guarded])) (out)
                (define-values (out)
                  (make-bad-guarded 1 2)))
             '((make-bad-guarded bad-guard-provider make-bad-guarded))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$struct-constructor/with-guard"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-not-equal? status 0 output)
        (check-regexp-match #rx"expect-n-values|raise-wrong-number-of-values-received" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer interns simple prefab struct type across slices"
    (define source-dir (make-temporary-file "webracket-prefab-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-prefab-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "prefab-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'prefab-maker-a
             '(linklet () (a-point auto-point one-point-value)
                (define-values (struct:prefab-point/one make-prefab-point/one prefab-point/one?
                                                        prefab-point/one-ref prefab-point/one-set!)
                  (make-struct-type 'prefab-point #f 1 0 #f #f 'prefab))
                (define-values (struct:prefab-point make-prefab-point prefab-point?
                                                    prefab-point-ref prefab-point-set!)
                  (make-struct-type 'prefab-point #f 2 0 #f #f 'prefab))
                (define-values (one-point)
                  (make-prefab-point/one 5))
                (define-values (one-point-value)
                  (prefab-point/one-ref one-point 0))
                (define-values (a-point)
                  (make-prefab-struct '(prefab-point 2 (0 #f) #()) 11 31))
                (define-values (auto-point)
                  (make-prefab-struct '(prefab-auto 1 (1 #f) #()) 42)))
             '())
            (webify-linklet-slice-spec
             'prefab-maker-b
             '(linklet (([a-point a-point]
                         [auto-point auto-point])) (out)
                (define-values (struct:prefab-point make-prefab-point prefab-point?
                                                    prefab-point-ref prefab-point-set!)
                  (make-struct-type 'prefab-point #f 2 0 #f #f 'prefab))
                (define-values (struct:prefab-auto make-prefab-auto prefab-auto?
                                                   prefab-auto-ref prefab-auto-set!)
                  (make-struct-type 'prefab-auto #f 1 1 #f #f 'prefab))
                (define-values (type-info)
                  (prefab-struct-type-key+field-count struct:prefab-point))
                (define-values (auto-type-info)
                  (prefab-struct-type-key+field-count struct:prefab-auto))
                (define-values (made-here)
                  (make-prefab-struct '(prefab-point) 6 7))
                (define-values (out)
                  (if (and (prefab-key? 'prefab-point)
                           (prefab-key? '(prefab-point))
                           (prefab-key? '(prefab-point 2))
                           (prefab-key? '(prefab-point 2 (0 #f) #()))
                           (prefab-key? '(prefab-auto 1 (1 #f) #()))
                           (eq? (prefab-struct-key a-point) 'prefab-point)
                           (eq? (prefab-struct-key made-here) 'prefab-point)
                           (equal? (prefab-struct-key auto-point)
                                   '(prefab-auto 1 (1 #f) #()))
                           (eq? (car type-info) 'prefab-point)
                           (= (cdr type-info) 2)
                           (equal? (car auto-type-info)
                                   '(prefab-auto 1 (1 #f) #()))
                           (= (cdr auto-type-info) 2)
                           (eq? (prefab-auto-ref auto-point 1) #f))
                      (prefab-auto-ref auto-point 0)
                      0)))
             '((a-point prefab-maker-a a-point)
               (auto-point prefab-maker-a auto-point))))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$prefab-struct-type-registry"))
        (check-true (string-contains? wat "$simple-prefab-registry-key"))
        (check-true (string-contains? wat "$simple-prefab-type-metadata"))
        (check-true (string-contains? wat "$make-prefab-struct"))
        (check-true (string-contains? wat "$prefab-struct-key"))
        (check-true (string-contains? wat "$make-struct-type"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (check-false (string-contains? wat "structure-type-lookup-prefab-uid"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^42$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "linklet composer rejects unsupported prefab struct shape"
    (define source-dir (make-temporary-file "webracket-prefab-bad-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-prefab-bad-dest-~a" 'directory))
    (define source-path (build-path source-dir "prefab-bad.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define-values (combined _fragments _instances _exports-infos)
          (compose-linklet-first-slices
           (list
            (webify-linklet-slice-spec
             'bad-prefab
             '(linklet () (out)
                (define-values (struct:bad-prefab make-bad-prefab bad-prefab?
                                                  bad-prefab-ref bad-prefab-set!)
                  (make-struct-type 'bad-prefab #f 1 1 'auto #f 'prefab))
                (define-values (out)
                  (make-bad-prefab 1)))
             '()))
           #:tail '((js-log out))))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$prefab-struct-type-registry"))
        (check-false (string-contains? wat "make-record-type-descriptor"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-not-equal? status 0 output)
        (check-regexp-match #rx"contract violation|raise-argument-error|RuntimeError" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))


(module+ main
  (void))
