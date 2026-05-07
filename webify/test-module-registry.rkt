#lang racket/base

(require racket/string
         racket/match
         racket/file
         racket/path
         rackunit
         "test-module-support.rkt")

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

(test-case "module registry plans transitive dependencies"
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
  (webify-module-registry-add!
   registry
   'c
   '(linklet (([ext-y y])) (z)
      (define-values (z) y))
   #:imports '((ext-y b y)))
  (check-equal? (webify-module-registry-plan registry '(c))
                '(a b c))
  (check-equal? (webify-module-registry-plan registry '(b c))
                '(a b c)))

(test-case "module registry composes planned roots"
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
    (compose-module-registry/roots registry '(b)))
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
     (fail-check (format "unexpected planned-registry shape: ~s" other))])
  (check-equal? (length fragments) 2)
  (check-equal? (sort (hash-keys instances) symbol<?) '(a b))
  (check-true (known-constant? (hash-ref (hash-ref exports-infos 'b) 'y)))
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

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

(test-case "module registry planner rejects duplicate roots"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'a
   '(linklet () (x)
      (define-values (x) 1)))
  (check-exn
   #rx"duplicate module roots are not supported"
   (lambda ()
     (webify-module-registry-plan registry '(a a)))))

(test-case "module registry planner rejects unknown dependencies"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'b
   '(linklet (([ext-x x])) (y)
      (define-values (y) x))
   #:imports '((ext-x missing x)))
  (check-exn
   #rx"unknown module registry entry"
   (lambda ()
     (webify-module-registry-plan registry '(b)))))

(test-case "module registry planner rejects dependency cycles"
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'a
   '(linklet (([ext-y y])) (x)
      (define-values (x) y))
   #:imports '((ext-y b y)))
  (webify-module-registry-add!
   registry
   'b
   '(linklet (([ext-x x])) (y)
      (define-values (y) x))
   #:imports '((ext-x a x)))
  (check-exn
   #rx"cyclic module registry dependencies are not supported"
   (lambda ()
     (webify-module-registry-plan registry '(a)))))

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

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "module registry planned roots output runs"
    (define source-dir (make-temporary-file "webracket-registry-roots-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-registry-roots-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "registry-roots-run.rkt"))
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
          (compose-module-registry/roots registry '(b) #:tail '((js-log y))))
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
  (test-case "module registry planned roots output runs imported export mutation"
    (define source-dir (make-temporary-file "webracket-registry-roots-mutate-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-registry-roots-mutate-dest-~a" 'directory))
    (define source-path (build-path source-dir "registry-roots-mutate.rkt"))
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
            (set! x (+ x 1))
            (define-values (y) x))
         #:imports '((ext-x a x)))
        (check-equal? (webify-module-registry-plan registry '(b)) '(a b))
        (define-values (combined fragments instances _exports-infos)
          (compose-module-registry/roots registry '(b) #:tail '((js-log y))))
        (check-equal? (length fragments) 2)
        (check-equal? (sort (hash-keys instances) symbol<?) '(a b))
        (define wat (wat-string (comp (datum->syntax #f combined))))
        (check-true (string-contains? wat "$module-variable-set!"))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^11$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))


(module+ main
  (void))
