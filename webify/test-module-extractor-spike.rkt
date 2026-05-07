#lang racket/base

(require rackunit
         racket/list
         racket/match
         "module-input.rkt"
         "module-extractor-spike.rkt")

;; normalized-linklet-imports : linklet-datum -> (listof any/c)
;;   Pull normalized import bindings out of a linklet datum for tests.
(define (normalized-linklet-imports linklet)
  (match linklet
    [`(linklet ,importss ,_exports . ,_body)
     (apply append importss)]))

(test-case "extractor spike reports compiled module linklet metadata"
  (define report
    (webify-compile-module-extractor-spike
     '(module a racket/base
        (provide x)
        (define x 10))))
  (check-true (webify-module-extractor-spike? report))
  (check-equal? (webify-module-extractor-spike-name report) 'a)
  (check-equal? (webify-module-extractor-spike-directory-keys report)
                '(#f configure-runtime))
  (check-not-false
   (andmap (lambda (key)
             (member key (webify-module-extractor-spike-bundle-keys report)))
           '(0 decl data)))
  (check-not-false
   (andmap webify-module-bundle-entry?
           (webify-module-extractor-spike-bundle-entries report)))
  (define phase0-entry (webify-module-bundle-entry-ref report 0))
  (define decl-entry (webify-module-bundle-entry-ref report 'decl))
  (define data-entry (webify-module-bundle-entry-ref report 'data))
  (check-equal? (webify-module-bundle-entry-kind phase0-entry) 'linklet)
  (check-equal? (webify-module-bundle-entry-kind decl-entry) 'linklet)
  (check-equal? (webify-module-bundle-entry-kind data-entry) 'linklet)
  (check-equal? (webify-module-bundle-entry-imports phase0-entry)
                (webify-module-extractor-spike-phase0-imports report))
  (check-equal? (webify-module-bundle-entry-exports phase0-entry)
                (webify-module-extractor-spike-phase0-exports report))
  (define import-map (webify-module-extractor-spike-import-map report))
  (check-true (webify-module-import-map? import-map))
  (check-equal? (webify-module-import-map-phase0-import-groups import-map)
                '(((.get-syntax-literal! .get-syntax-literal!))
                  ((.set-transformer! .set-transformer!))))
  (check-equal? (webify-module-import-map-phase0-structured-import-groups import-map)
                (webify-module-import-map-phase0-import-groups import-map))
  (check-equal? (webify-module-import-map-phase0-decompiled-import-groups import-map)
                (webify-module-import-map-phase0-import-groups import-map))
  (check-equal? (webify-module-import-map-module-protocol-import-groups import-map)
                (webify-module-import-map-phase0-import-groups import-map))
  (check-equal? (webify-module-import-map-unresolved-import-groups import-map)
                '())
  (check-equal? (webify-module-import-map-import-aliases import-map)
                '())
  (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                '())
  (check-equal? (webify-module-extractor-spike-phase0-exports report) '(x))
  (check-not-false
   (member '(.get-syntax-literal!)
           (webify-module-extractor-spike-phase0-imports report)))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-match (webify-module-extractor-spike-phase0-linklet-datum report)
                  `(linklet ,_ ,exports . ,_))
     (check-match (webify-module-bundle-entry-datum decl-entry)
                  `(linklet ,_ ,_ . ,_))
     (check-match (webify-module-bundle-entry-datum data-entry)
                  `(linklet ,_ ,_ . ,_))
     (check-true (vector? (webify-module-import-map-data-module-path-indexes import-map)))
     (check-match (webify-module-import-map-decl-requires-expression import-map)
                  `(let-values ,_ . ,_))
     (check-match (webify-module-import-map-decl-provides-expression import-map)
                  `(let-values ,_ . ,_))
     (check-match (webify-module-import-map-decl-phase-to-link-modules-expression import-map)
                  `(hasheqv . ,_))
     (check-equal? (caddr (webify-module-extractor-spike-phase0-linklet-datum report))
                   '(x))
     (check-not-false
      (member "machine-independent compilation exposes a decompilable phase-0 linklet datum"
              (webify-module-extractor-spike-notes report)))]
    [else
     (check-false (webify-module-extractor-spike-phase0-linklet-datum report))
     (check-false (webify-module-bundle-entry-datum phase0-entry))
     (check-false (webify-module-bundle-entry-datum decl-entry))
     (check-false (webify-module-bundle-entry-datum data-entry))
     (check-false (webify-module-import-map-data-module-path-indexes import-map))
     (check-false (webify-module-import-map-decl-requires-expression import-map))
     (check-false (webify-module-import-map-decl-provides-expression import-map))
     (check-false (webify-module-import-map-decl-phase-to-link-modules-expression import-map))
     (check-not-false
      (member "host Racket does not provide decompile-linklet"
              (webify-module-extractor-spike-notes report)))]))

(test-case "extractor spike rejects non-module data"
  (check-exn
   #rx"expected a source module datum"
   (lambda ()
     (webify-compile-module-extractor-spike
      '(define x 10)))))

(test-case "extractor report derives provider dependency exports"
  (define provider-report
    (webify-compile-module-extractor-spike
     '(module dep racket/base
        (provide x y)
        (define x 1)
        (define y 2))))
  (define report-exports (webify-module-extractor-spike-dependency-exports provider-report))
  (check-equal? (car report-exports) 'dep)
  (check-equal? (sort (cadr report-exports) symbol<?) '(x y))
  (define source-exports
    (webify-source-module->dependency-exports
     '(module dep racket/base
        (provide x y)
        (define x 1)
        (define y 2))))
  (check-equal? (car source-exports) 'dep)
  (check-equal? (sort (cadr source-exports) symbol<?) '(x y)))

(test-case "provider compiled exports resolve internalized importer names"
  (define provider-report
    (webify-module-extractor-spike
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
  (define importer-linklet
    '(linklet (((string-join.1 string-join.1)
                (string-join9.1 string-join9.1)))
       (y)
       (define-values (y) string-join.1)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    (list (webify-module-extractor-spike-dependency-exports provider-report)))
   '((string-join.1 racket/string string-join.1)
     (string-join9.1 racket/string string-join9.1))))

(test-case "dependency export tables derive from extractor reports"
  (define dep-report
    (webify-module-extractor-spike
     'dep
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x) (define-values (x) 1))
     #t
     '()))
  (define string-report
    (webify-module-extractor-spike
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
  (define dependency-exports
    (webify-module-extractor-spikes-dependency-exports
     (list dep-report string-report)))
  (check-equal? dependency-exports
                '((dep (x))
                  (racket/string (string-join9.1 string-join.2 string-join.1))))
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((string-join.1 string-join.1))) (y)
       (define-values (y) string-join.1))
    dependency-exports)
   '((string-join.1 racket/string string-join.1)))
  (check-exn
   #rx"duplicate dependency export entries"
   (lambda ()
     (webify-module-extractor-spikes-dependency-exports
      (list dep-report dep-report)))))

(test-case "provider reports resolve importer report imports"
  (define importer-report
    (webify-module-extractor-spike
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
    (webify-module-extractor-spike
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
    (webify-module-extractor-spike->resolved-linklet-input/providers
     importer-report
     (list string-report)))
  (check-equal? (webify-module-linklet-input-name input) 'use-string)
  (check-equal? (webify-module-linklet-input-imports input)
                '((string-join.1 racket/string string-join.1))))

(test-case "extractor report graph resolves module inputs"
  (define dep-report
    (webify-module-extractor-spike
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
    (webify-module-extractor-spike
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
    (webify-module-extractor-spikes->resolved-linklet-inputs
     (list dep-report use-report)))
  (check-equal? (map webify-module-linklet-input-name inputs)
                '(dep use-dep))
  (check-equal? (map webify-module-linklet-input-imports inputs)
                '(() ((x dep x)))))

(test-case "extractor report graph rejects bad dependency shapes"
  (define provider-a
    (webify-module-extractor-spike
     'a
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x) (define-values (x) 1))
     #t
     '()))
  (define provider-b
    (webify-module-extractor-spike
     'b
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x) (define-values (x) 2))
     #t
     '()))
  (define use-report
    (webify-module-extractor-spike
     'use-x
     '(#f)
     '(0)
     '()
     '((x))
     '(y)
     '(linklet (((x x))) (y)
        (define-values (y) x))
     #t
     '()))
  (check-exn
   #rx"could not resolve import dependency"
   (lambda ()
     (webify-module-extractor-spikes->resolved-linklet-inputs
      (list use-report))))
  (check-exn
   #rx"ambiguous import dependency"
   (lambda ()
     (webify-module-extractor-spikes->resolved-linklet-inputs
      (list provider-a provider-b use-report))))
  (check-exn
   #rx"duplicate dependency export entries"
   (lambda ()
     (webify-module-extractor-spikes->resolved-linklet-inputs
      (list provider-a provider-a)))))

(test-case "source module graph wrapper resolves available source reports"
  (define module-data
    '((module a racket/base
        (provide x)
        (define x 1))
      (module b racket/base
        (provide y)
        (define y 2))))
  (define reports (map webify-compile-module-extractor-spike module-data))
  (cond
    [(andmap webify-module-extractor-spike-manifest-ready? reports)
     (define inputs
       (webify-source-modules->resolved-linklet-inputs
        module-data
        #:module-protocol-dependency 'module-protocol))
     (check-equal? (map webify-module-linklet-input-name inputs) '(a b))
     (check-equal?
      (map webify-module-linklet-input-imports inputs)
      '(((.get-syntax-literal! module-protocol .get-syntax-literal!)
         (.set-transformer! module-protocol .set-transformer!))
        ((.get-syntax-literal! module-protocol .get-syntax-literal!)
         (.set-transformer! module-protocol .set-transformer!))))]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-modules->resolved-linklet-inputs
         module-data
         #:module-protocol-dependency 'module-protocol)))]))

(test-case "source module extractor returns linklet input when available"
  (define module-datum
    '(module a racket/base
       (provide x)
       (define x 10)))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (define input (webify-source-module->linklet-input module-datum))
     (check-true (webify-module-linklet-input? input))
     (check-equal? (webify-module-linklet-input-name input) 'a)
     (check-false (webify-module-linklet-input-imports input))
     (check-match (webify-module-linklet-input-linklet input)
                  `(linklet ,_ ,_ . ,_))
     (check-not-false
      (andmap (lambda (binding)
                (match binding
                  [(list (? symbol?) (? symbol?)) #t]
                  [_                              #f]))
              (normalized-linklet-imports
               (webify-module-linklet-input-linklet input))))
     (check-equal? (caddr (webify-module-linklet-input-linklet input))
                   '(x))

     (define import-triples
       '((.get-syntax-literal! module-protocol .get-syntax-literal!)
         (.set-transformer! module-protocol .set-transformer!)))
     (define explicit-input
       (webify-source-module->linklet-input module-datum
                                            #:imports import-triples))
     (check-equal? (webify-module-linklet-input-imports explicit-input)
                   import-triples)]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->linklet-input module-datum)))]))

(test-case "source module import resolver classifies module protocol imports"
  (define module-datum
    '(module a racket/base
       (provide x)
       (define x 10)))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-exn
      #rx"module protocol dependency"
      (lambda ()
        (webify-source-module->resolved-linklet-input module-datum)))
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:module-protocol-dependency 'module-protocol))
     (check-true (webify-module-linklet-input? input))
     (check-equal? (webify-module-linklet-input-imports input)
                   '((.get-syntax-literal! module-protocol .get-syntax-literal!)
                     (.set-transformer! module-protocol .set-transformer!)))]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->resolved-linklet-input module-datum)))]))

(test-case "import map reports unresolved required-module groups"
  (define module-datum
    '(module a racket/base
       (require racket/list)
       (provide y)
       (define y (first (list 10)))))
  (define report (webify-compile-module-extractor-spike module-datum))
  (define import-map (webify-module-extractor-spike-import-map report))
  (check-equal? (webify-module-import-map-phase0-import-groups import-map)
                '(((.get-syntax-literal! .get-syntax-literal!))
                  ((.set-transformer! .set-transformer!))
                  ((first first))))
  (check-equal? (webify-module-import-map-module-protocol-import-groups import-map)
                '(((.get-syntax-literal! .get-syntax-literal!))
                  ((.set-transformer! .set-transformer!))))
  (check-equal? (webify-module-import-map-unresolved-import-groups import-map)
                '(((first first))))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-true (vector? (webify-module-import-map-data-module-path-indexes import-map)))
     (check-not-false
      (for/or ([entry (in-vector (webify-module-import-map-data-module-path-indexes import-map))])
        (equal? entry '#(racket/list))))
     (check-match (webify-module-import-map-decl-requires-expression import-map)
                  `(let-values ,_ . ,_))
     (check-match (webify-module-import-map-decl-phase-to-link-modules-expression import-map)
                  `(hasheqv . ,_))
     (check-equal? (webify-module-import-map-required-module-candidates import-map)
                   '((0 racket/list)))
     (check-equal? (webify-module-import-map-import-aliases import-map)
                   '())
     (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                   '())
     (check-not-false
      (member "phase-0 contains non-protocol import groups"
              (webify-module-import-map-notes import-map)))]
    [else
     (check-false (webify-module-import-map-data-module-path-indexes import-map))
     (check-false (webify-module-import-map-decl-requires-expression import-map))
     (check-equal? (webify-module-import-map-required-module-candidates import-map)
                   '())
     (check-equal? (webify-module-import-map-import-aliases import-map)
                   '())
     (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                   '())
     (check-not-false
      (member "decl/data metadata is unavailable on this host because linklet decompilation is unavailable"
              (webify-module-import-map-notes import-map)))]))

(test-case "source module resolver uses simple required-module candidates"
  (define module-datum
    '(module a racket/base
       (require racket/list)
       (provide y)
       (define y (first (list 10)))))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-exn
      #rx"could not resolve import dependency"
      (lambda ()
        (webify-source-module->resolved-linklet-input
         module-datum
         #:module-protocol-dependency 'module-protocol)))
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:dependency-exports '((racket/list (first)))
        #:module-protocol-dependency 'module-protocol))
     (check-equal? (webify-module-linklet-input-imports input)
                   '((.get-syntax-literal! module-protocol .get-syntax-literal!)
                     (.set-transformer! module-protocol .set-transformer!)
                     (first racket/list first)))]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->resolved-linklet-input
         module-datum
         #:dependency-exports '((racket/list (first)))
         #:module-protocol-dependency 'module-protocol)))]))

(test-case "source module resolver handles multiple simple required modules"
  (define module-datum
    '(module a racket/base
       (require racket/list racket/math)
       (provide y)
       (define y (+ (first (list 10)) (sqr 3)))))
  (define report (webify-compile-module-extractor-spike module-datum))
  (define import-map (webify-module-extractor-spike-import-map report))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-equal? (webify-module-import-map-unresolved-import-groups import-map)
                   '(((first first)) ((sqr sqr))))
     (check-equal? (webify-module-import-map-required-module-candidates import-map)
                   '((0 racket/math) (0 racket/list)))
     (check-equal? (webify-module-import-map-import-aliases import-map)
                   '())
     (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                   '())
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:dependency-exports '((racket/list (first))
                               (racket/math (sqr)))
        #:module-protocol-dependency 'module-protocol))
     (check-equal? (webify-module-linklet-input-imports input)
                   '((.get-syntax-literal! module-protocol .get-syntax-literal!)
                     (.set-transformer! module-protocol .set-transformer!)
                     (first racket/list first)
                     (sqr racket/math sqr)))
     (check-exn
      #rx"ambiguous inferred import dependency"
      (lambda ()
        (webify-source-module->resolved-linklet-input
         module-datum
         #:dependency-exports '((racket/list (first))
                                (racket/math (first sqr)))
         #:module-protocol-dependency 'module-protocol)))]
    [else
     (check-equal? (webify-module-import-map-required-module-candidates import-map)
                   '())
     (check-equal? (webify-module-import-map-import-aliases import-map)
                   '())
     (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                   '())
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->resolved-linklet-input
         module-datum
         #:dependency-exports '((racket/list (first))
                                (racket/math (sqr)))
         #:module-protocol-dependency 'module-protocol)))]))

(test-case "source module resolver exposes internalized required imports"
  (define module-datum
    '(module a racket/base
       (require racket/string)
       (provide y)
       (define y (string-join (list "a" "b") ","))))
  (define report (webify-compile-module-extractor-spike module-datum))
  (define import-map (webify-module-extractor-spike-import-map report))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-equal? (webify-module-import-map-required-module-candidates import-map)
                   '((0 racket/string)))
     (check-equal? (webify-module-import-map-phase0-structured-import-groups import-map)
                   (webify-module-import-map-phase0-decompiled-import-groups import-map))
     (define unresolved (webify-module-import-map-unresolved-import-groups import-map))
     (check-equal? (length unresolved) 1)
     (define string-join-group (car unresolved))
     (check-equal? (length string-join-group) 2)
     (check-equal? (webify-module-import-map-import-aliases import-map)
                   '())
     (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                   (list string-join-group))
     (check-not-false
      (member "phase-0 contains internalized non-protocol import groups"
              (webify-module-import-map-notes import-map)))
     (check-not-false
      (andmap (lambda (binding)
                (regexp-match? #rx"^string-join"
                               (symbol->string (car binding))))
              string-join-group))
     (check-exn
      #rx"could not resolve import dependency"
      (lambda ()
        (webify-source-module->resolved-linklet-input
         module-datum
         #:dependency-exports '((racket/string (string-join)))
         #:module-protocol-dependency 'module-protocol)))
     (define explicit-dependencies
       (for/list ([binding (in-list string-join-group)])
         (list (car binding) 'racket/string)))
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:dependency-exports
        `((racket/string ,(map cadr string-join-group)))
        #:dependencies explicit-dependencies
        #:module-protocol-dependency 'module-protocol))
     (check-equal? (drop (webify-module-linklet-input-imports input) 2)
                   (for/list ([binding (in-list string-join-group)])
                     (list (car binding) 'racket/string (cadr binding))))]
    [else
     (check-equal? (webify-module-import-map-required-module-candidates import-map)
                   '())
     (check-equal? (webify-module-import-map-import-aliases import-map)
                   '())
     (check-equal? (length (webify-module-import-map-missing-alias-import-groups import-map))
                   1)
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->resolved-linklet-input
         module-datum
         #:dependency-exports '((racket/string (string-join)))
         #:module-protocol-dependency 'module-protocol)))]))

(test-case "import map reports aliases from explicit import pairs"
  (define phase0-linklet
    '(linklet (((external-name local-name))) () (void)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#(dep/mod)) '#(0)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 0) 0))))))
  (define report
    (webify-module-extractor-spike
     'synthetic
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((external-name local-name))) '() phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
     '(((external-name local-name)))
     '()
     phase0-linklet
     #t
     '()))
  (define import-map (webify-module-extractor-spike-import-map report))
  (check-equal? (webify-module-import-map-phase0-decompiled-import-groups import-map)
                '(((local-name external-name))))
  (check-equal? (webify-module-import-map-required-module-candidates import-map)
                '((0 dep/mod)))
  (check-equal? (webify-module-import-map-import-aliases import-map)
                '((local-name dep/mod external-name)))
  (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                '())
  (define input
    (webify-module-extractor-spike->resolved-linklet-input
     report
     #:dependency-exports '((dep/mod (external-name)))))
  (check-equal? (webify-module-linklet-input-imports input)
                '((local-name dep/mod external-name))))

(test-case "import map reports source-level require rename aliases"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) () (void)))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '() phase0-linklet #f))
     '(((reverse 1/reverse)))
     '()
     phase0-linklet
     #t
     '()))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define rename-aliases (webify-module-import-map-require-rename-aliases import-map))
  (check-not-false
   (or (member '(1/reverse racket/private/pico alt-reverse) rename-aliases)
       (member '(1/reverse racket/private/reverse alt-reverse) rename-aliases)))
  (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                '())
  (define required-provider-names
    (webify-module-extractor-spike-required-provider-names report))
  (check-not-false
   (or (member 'racket/private/pico required-provider-names)
       (member 'racket/private/reverse required-provider-names))))

(test-case "source-level require rename aliases resolve private list reverse"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) (uses-reverse)
       (define-values (uses-reverse) 1/reverse)))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '(uses-reverse) phase0-linklet #f))
     '(((reverse 1/reverse)))
     '(uses-reverse)
     phase0-linklet
     #t
     '()))
  (define import-map (webify-module-extractor-spike-import-map report))
  (match-define (list _local dependency provider-export)
    (car (webify-module-import-map-require-rename-aliases import-map)))
  (define provider-report
    (webify-module-extractor-spike
     dependency
     '(#f)
     '(0)
     '()
     '()
     (list provider-export)
     `(linklet () (,provider-export)
        (define-values (,provider-export) 'reverse-proc))
     #t
     '()))
  (define input
    (webify-module-extractor-spike->resolved-linklet-input/providers
     report
     (list provider-report)))
  (check-equal? (webify-module-linklet-input-imports input)
                `((1/reverse ,dependency ,provider-export))))

(test-case "multi-report resolver threads source-level require rename aliases"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) (uses-reverse)
       (define-values (uses-reverse) 1/reverse)))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '(uses-reverse) phase0-linklet #f))
     '(((reverse 1/reverse)))
     '(uses-reverse)
     phase0-linklet
     #t
     '()))
  (match-define (list _local dependency provider-export)
    (car (webify-module-import-map-require-rename-aliases
          (webify-module-extractor-spike-import-map report))))
  (define provider-report
    (webify-module-extractor-spike
     dependency
     '(#f)
     '(0)
     '()
     '()
     (list provider-export)
     `(linklet () (,provider-export)
        (define-values (,provider-export) 'reverse-proc))
     #t
     '()))
  (define inputs
    (webify-module-extractor-spikes->resolved-linklet-inputs
     (list provider-report report)))
  (define list-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input)
                            'racket/private/list))
      input))
  (check-equal? (webify-module-linklet-input-imports list-input)
                `((1/reverse ,dependency ,provider-export))))

(module+ main
  (void))
