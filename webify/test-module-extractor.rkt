#lang racket/base

(require rackunit
         racket/string
         "test-module-support.rkt")

;; synthetic-report : symbol? (listof symbol?) -> webify-module-report?
;;   Build a small manifest-ready report with decoded phase-0 provider metadata.
(define (synthetic-report name requires)
  (define phase0-linklet
    `(linklet () (,name)
       (define-values (,name) ',name)))
  (define mpi-vector (list->vector (map (lambda (require)
                                          (list->vector (map string->symbol
                                                             (string-split
                                                              (symbol->string require)
                                                              "/"))))
                                        requires)))
  (define data-linklet
    `(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes ',mpi-vector '#(0)))))
  (define decl-linklet
    `(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list ,@(for/list ([i (in-range (length requires))])
                              `(module-use (unsafe-vector*-ref .mpi-vector ,i) 0)))))))
  (webify-module-report
   name
   '(#f)
   '(0 data decl)
   (list (webify-module-bundle-entry 0 'linklet '() (list name) phase0-linklet #f)
         (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
         (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
   '()
   (list name)
   phase0-linklet
   #t
   '()))

(test-case "stable module report API wraps extractor backend"
  (define report
    (webify-compile-module-report
     '(module a racket/base
        (provide x)
        (define x 10))))
  (check-true (webify-module-report? report))
  (check-equal? (webify-module-report-name report) 'a)
  (check-equal? (webify-module-report-phase0-exports report) '(x))
  (define import-map (webify-module-report-import-map report))
  (check-true (webify-module-import-map? import-map))
  (check-equal? (webify-module-report-dependency-exports report)
                '(a (x))))

(test-case "stable module report graph resolves linklet inputs"
  (define dep-report
    (webify-module-report
     'dep
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x) (define-values (x) 1))
     #t
     '()))
  (define use-report
    (webify-module-report
     'use-dep
     '(#f)
     '(0)
     '()
     '((x))
     '(y)
     '(linklet (((x x))) (y)
        (define-values (y) x))
     #t
     '()))
  (define inputs
    (webify-module-reports->resolved-linklet-inputs
     (list dep-report use-report)))
  (check-equal? (map webify-module-linklet-input-name inputs)
                '(dep use-dep))
  (check-equal? (map webify-module-linklet-input-imports inputs)
                '(() ((x dep x)))))

(test-case "stable provider-report resolver handles internalized imports"
  (define importer-report
    (webify-module-report
     'use-string
     '(#f)
     '(0)
     '()
     '((string-join.1))
     '(y)
     '(linklet (((string-join.1 string-join.1))) (y)
        (define-values (y) string-join.1))
     #t
     '()))
  (define string-report
    (webify-module-report
     'racket/string
     '(#f)
     '(0)
     '()
     '()
     '(string-join9.1 string-join.2 string-join.1)
     '(linklet () (string-join9.1 string-join.2 string-join.1)
        (define-values (string-join9.1) 'join9)
        (define-values (string-join.2) 'join2)
        (define-values (string-join.1) 'join1))
     #t
     '()))
  (define input
    (webify-module-report->resolved-linklet-input/providers
     importer-report
     (list string-report)))
  (check-equal? (webify-module-linklet-input-imports input)
                '((string-join.1 racket/string string-join.1))))

(test-case "stable module report exposes one-level required providers"
  (define phase0-linklet
    '(linklet (((first first))) (y)
       (define-values (y) first)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#(racket/list)) '#(0)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 0) 0))))))
  (define report
    (webify-module-report
     'use-list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((first first))) '(y) phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
     '(((first first)))
     '(y)
     phase0-linklet
     #t
     '()))
  (check-equal? (webify-module-report-required-provider-names report)
                '(racket/list)))

(test-case "stable module report discovers transitive provider closure"
  (define root-report (synthetic-report 'root '(dep/a dep/b)))
  (define dep-a-report (synthetic-report 'dep/a '(dep/c)))
  (define dep-b-report (synthetic-report 'dep/b '(dep/c)))
  (define dep-c-report (synthetic-report 'dep/c '()))
  (define fetched '())
  (define provider-table
    (hasheq 'dep/a dep-a-report
            'dep/b dep-b-report
            'dep/c dep-c-report))
  (define closure
    (webify-module-reports->required-provider-closure
     (list root-report)
     #:fetch-provider
     (lambda (name)
       (set! fetched (append fetched (list name)))
       (hash-ref provider-table name))))
  (check-equal? (car (map webify-module-report-name closure)) 'root)
  (check-equal? (sort (cdr (map webify-module-report-name closure)) symbol<?)
                '(dep/a dep/b dep/c))
  (check-equal? (sort fetched symbol<?) '(dep/a dep/b dep/c)))

(test-case "stable module report graph registers and composes"
  (define dep-report
    (webify-module-report
     'dep
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x)
        (define-values (x) 10))
     #t
     '()))
  (define use-report
    (webify-module-report
     'use-dep
     '(#f)
     '(0)
     '()
     '((x))
     '(y)
     '(linklet (((x x))) (y)
        (define-values (y) x))
     #t
     '()))
  (define registry
    (webify-module-reports->registry (list dep-report use-report)))
  (check-equal? (webify-module-registry-plan registry '(use-dep))
                '(dep use-dep))
  (define loader (make-webify-module-loader registry))
  (define composition
    (webify-module-loader-instantiate!
     loader
     '(use-dep)
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
  (define y-cell (webify-module-loader-lookup-export-cell loader 'use-dep 'y))
  (check-equal? y-cell 'webify-export-cell0$1)
  (define observed
    (webify-module-loader-observe loader '((use-dep y))))
  (check-not-false
   (member '("js-log" ("module-variable-ref" "webify-export-cell0$1"))
           (normalize-symbols observed)))
  (check-true (string-contains? (wat-string (comp (datum->syntax #f observed)))
                                "$module-variable-ref")))
