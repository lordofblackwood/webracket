#lang racket/base

(require rackunit
         racket/string
         "provider-trials.rkt"
         "test-module-support.rkt")

;; demand-member? : symbol? (listof symbol?) demands -> boolean?
;;   Check a demand by provider and export set, ignoring compiled export order.
(define (demand-member? module exports demands)
  (define (same-export? expected actual)
    (define expected-string (symbol->string expected))
    (define actual-string (symbol->string actual))
    (or (string=? expected-string actual-string)
        (regexp-match? (regexp (format "^~a[0-9]+[.][0-9]+$"
                                        (regexp-quote expected-string)))
                       actual-string)
        (regexp-match? (regexp (format "^~a[.][0-9]+$"
                                        (regexp-quote expected-string)))
                       actual-string)))
  (define (exports-match? actuals)
    (and (= (length exports) (length actuals))
         (andmap (lambda (expected)
                   (for/or ([actual (in-list actuals)])
                     (same-export? expected actual)))
                 exports)))
  (for/or ([demand (in-list demands)])
    (and (eq? module (webify-module-export-demand-module demand))
         (exports-match? (webify-module-export-demand-exports demand)))))

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

(test-case "provider cache reports hits and misses"
  (define fetch-count 0)
  (define cache
    (make-webify-module-provider-cache
     (lambda (name)
       (set! fetch-count (add1 fetch-count))
       (webify-module-report
        name
        '(#f)
        '(0)
        '()
        '()
        '(x)
        '(linklet () (x) (define-values (x) 'x))
        #t
        '()))))
  (void (webify-module-provider-cache-ref cache 'racket/list))
  (void (webify-module-provider-cache-ref cache 'racket/list))
  (check-equal? fetch-count 1)
  (check-equal? (webify-module-provider-cache-miss-count cache) 1)
  (check-equal? (webify-module-provider-cache-hit-count cache) 1)
  (check-equal? (webify-module-provider-cache-count cache) 1)
  (check-equal? (webify-module-provider-cache-names cache) '(racket/list)))

(test-case "provider trial manifest lists initial discovery-only cases"
  (check-equal? (map webify-provider-trial-module webify-provider-trials)
                '(racket/list racket/string racket/bool))
  (check-equal? (webify-provider-trial-exports
                 (webify-provider-trial-ref 'racket/list))
                '(first rest filter-map append-map))
  (check-true (webify-provider-trial-module-allowed? 'racket/list))
  (check-false (webify-provider-trial-module-allowed? 'racket/math)))

(test-case "real racket/list provider discovery stays extraction-only"
  (define trial (webify-provider-trial-ref 'racket/list))
  (define start-ms (current-inexact-milliseconds))
  (define importer-report
    (webify-compile-module-report (webify-provider-trial-source trial)))
  (define provider-report
    (webify-module-path->report (webify-provider-trial-module trial)))
  (define demands
    (webify-module-report-import-export-demands
     importer-report
     (list provider-report)
     #:module-protocol-dependency webify-module-protocol-dependency))
  (define elapsed-ms (- (current-inexact-milliseconds) start-ms))
  (check-true (< elapsed-ms 10000.0))
  (check-equal?
   (car demands)
   (webify-module-export-demand 'module-protocol
                                '(.get-syntax-literal! .set-transformer!)))
  (check-true
   (demand-member? 'racket/list
                   '(first rest filter-map append-map)
                   demands)))

(test-case "real and fake racket/list cluster demands agree"
  (define trial (webify-provider-trial-ref 'racket/list))
  (define importer-report
    (webify-compile-module-report (webify-provider-trial-source trial)))
  (define fake-list-report
    (webify-module-report
     'racket/list
     '(#f)
     '(0)
     '()
     '()
     '(first rest filter-map append-map)
     '(linklet () (first rest filter-map append-map)
        (define-values (first) 'first)
        (define-values (rest) 'rest)
        (define-values (filter-map) 'filter-map)
        (define-values (append-map) 'append-map))
     #t
     '()))
  (define real-list-report
    (webify-module-path->report 'racket/list))
  (define (demands provider-report)
    (webify-module-report-import-export-demands
     importer-report
     (list provider-report)
     #:module-protocol-dependency webify-module-protocol-dependency))
  (check-equal? (demands real-list-report)
                (demands fake-list-report)))

(test-case "provider trial manifest resolves real discovery-only demands"
  (for ([trial (in-list webify-provider-trials)])
    (define importer-report
      (webify-compile-module-report (webify-provider-trial-source trial)))
    (define provider-report
      (webify-module-path->report (webify-provider-trial-module trial)))
    (define demands
      (webify-module-report-import-export-demands
       importer-report
       (list provider-report)
       #:module-protocol-dependency webify-module-protocol-dependency))
    (check-true
     (demand-member? (webify-provider-trial-module trial)
                     (webify-provider-trial-exports trial)
                     demands))))

(test-case "provider trial reports primitive demands and cache counts"
  (for ([report (in-list (webify-provider-trial-run-all))])
    (check-equal? (webify-provider-trial-report-status report) 'ok)
    (check-true (positive? (webify-provider-trial-report-elapsed-ms report)))
    (check-not-false
     (member (webify-provider-trial-module
              (webify-provider-trial-report-trial report))
             (webify-provider-trial-report-input-names report)))
    (check-pred list?
                (webify-provider-trial-report-missing-primitives report))
    (check-pred list?
                (webify-provider-trial-report-primitive-ownership-counts report))
    (check-true (positive?
                 (webify-provider-trial-report-provider-cache-misses report)))))

(test-case "provider trial reports closure size and demand-slice delta"
  (for ([report (in-list (webify-provider-trial-run-all))])
    (define demand-summary
      (webify-provider-trial-report-demand-summary report))
    (define full-summary
      (webify-provider-trial-report-full-summary report))
    (define delta
      (webify-provider-trial-closure-summary-delta demand-summary full-summary))
    (check-true (positive?
                 (webify-provider-trial-closure-summary-input-count
                  demand-summary)))
    (check-true
     (>= (webify-provider-trial-closure-summary-input-count full-summary)
         (webify-provider-trial-closure-summary-input-count demand-summary)))
    (check-true (hash-has-key? delta 'inputs))
    (check-pred list?
                (webify-provider-trial-closure-summary-largest-inputs
                 demand-summary))
    (define summary-datum
      (webify-provider-trial-report->summary-datum report))
    (check-equal? (hash-ref summary-datum 'module)
                  (webify-provider-trial-module
                   (webify-provider-trial-report-trial report)))
    (check-true (hash-has-key? summary-datum 'largest-inputs))))

(test-case "synthetic provider-shaped registry compiles without real provider graph"
  (define provider-input
    (webify-module-linklet-input
     'synthetic/provider
     '(linklet () (fake-first)
        (define-values (fake-first) 'ok))
     '()))
  (define main-input
    (webify-module-linklet-input
     'main
     '(linklet (((fake-first fake-first))) (answer)
        (define-values (answer) fake-first))
     '((fake-first synthetic/provider fake-first))))
  (define registry
    (webify-module-linklet-inputs->registry
     (list provider-input main-input)))
  (define-values (observed _fragments _instances _exports-info)
    (compose-module-registry/roots+observations registry
                                                '(main)
                                                '((main answer))))
  (check-true
   (string-contains? (wat-string (comp (datum->syntax #f observed)))
                     "$module-variable-ref")))

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

(test-case "stable provider closure skips unfetchable candidates"
  (define root-report (synthetic-report 'root '(dep/a dep/missing)))
  (define dep-a-report (synthetic-report 'dep/a '()))
  (define fetched '())
  (define closure
    (webify-module-reports->required-provider-closure
     (list root-report)
     #:fetch-provider
     (lambda (name)
       (set! fetched (append fetched (list name)))
       (case name
         [(dep/a) dep-a-report]
         [else (raise-arguments-error 'fetch-provider
                                      "no such provider"
                                      "module" name)]))))
  (check-equal? (map webify-module-report-name closure)
                '(root dep/a))
  (check-equal? (sort fetched symbol<?)
                '(dep/a dep/missing))
  (check-exn
   #rx"no such provider"
   (lambda ()
     (webify-module-reports->required-provider-closure
      (list root-report)
      #:skip-unfetchable? #f
      #:fetch-provider
      (lambda (name)
        (case name
          [(dep/a) dep-a-report]
          [else (raise-arguments-error 'fetch-provider
                                       "no such provider"
                                       "module" name)]))))))

(test-case "stable provider cache reuses fetched reports across closures"
  (define root-a (synthetic-report 'root/a '(dep/shared)))
  (define root-b (synthetic-report 'root/b '(dep/shared)))
  (define shared (synthetic-report 'dep/shared '()))
  (define fetch-count 0)
  (define cache
    (make-webify-module-provider-cache
     (lambda (name)
       (set! fetch-count (add1 fetch-count))
       (check-equal? name 'dep/shared)
       shared)))
  (define (cached-fetch name)
    (webify-module-provider-cache-ref cache name))
  (void (webify-module-reports->required-provider-closure
         (list root-a)
         #:fetch-provider cached-fetch))
  (void (webify-module-reports->required-provider-closure
         (list root-b)
         #:fetch-provider cached-fetch))
  (check-equal? fetch-count 1)
  (check-equal? (webify-module-provider-cache-count cache) 1)
  (check-equal? (webify-module-provider-cache-names cache) '(dep/shared)))

(test-case "stable module report resolves discovered provider graph"
  (define dep-data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#() '#(0)))))
  (define dep-decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv))))
  (define dep-report
    (webify-module-report
     'dep
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '() '(x) '(linklet () (x) (define-values (x) 1)) #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) dep-data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) dep-decl-linklet #f))
     '()
     '(x)
     '(linklet () (x) (define-values (x) 1))
     #t
     '()))
  (define phase0-linklet
    '(linklet (((x x))) (y)
       (define-values (y) x)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#(dep)) '#(0)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 0) 0))))))
  (define use-report
    (webify-module-report
     'use-dep
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((x x))) '(y) phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
     '(((x x)))
     '(y)
     phase0-linklet
     #t
     '()))
  (define inputs
    (webify-module-reports->discovered-resolved-linklet-inputs
     (list use-report)
     #:fetch-provider (lambda (name)
                        (check-equal? name 'dep)
                        dep-report)))
  (check-equal? (map webify-module-linklet-input-name inputs)
                '(use-dep dep))
  (check-equal? (webify-module-linklet-input-imports (car inputs))
                '((x dep x)))
  (define registry
    (webify-module-reports->discovered-registry
     (list use-report)
     #:fetch-provider (lambda (_name) dep-report)))
  (check-equal? (webify-module-registry-plan registry '(use-dep))
                '(dep use-dep)))

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
