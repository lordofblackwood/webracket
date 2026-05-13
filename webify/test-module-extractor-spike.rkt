#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/match
         "module-audit.rkt"
         "module-input.rkt"
         "module-extractor-spike.rkt")

;; normalized-linklet-imports : linklet-datum -> (listof any/c)
;;   Pull normalized import bindings out of a linklet datum for tests.
(define (normalized-linklet-imports linklet)
  (match linklet
    [`(linklet ,importss ,_exports . ,_body)
     (apply append importss)]))

;; test-report : symbol? list? list? -> webify-module-extractor-spike?
;;   Build a compact extractor report for graph-audit resolver tests.
(define (test-report name imports exports)
  (define linklet-datum `(linklet ,imports ,exports (void)))
  (webify-module-extractor-spike
   name
   '(#f)
   '(0)
   (list (webify-module-bundle-entry
          0
          'linklet
          imports
          exports
          linklet-datum
          #f))
   imports
   exports
   linklet-datum
   #t
   '()))

;; declared-module-variable-exports : module-datum module-path -> list?
;;   Declare a module and read its variable exports with defined-name metadata.
(define (declared-module-variable-exports module-datum module-path)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (eval module-datum)
    (call-with-values
     (lambda () (module->exports module-path 'defined-names))
     (lambda (variables _syntaxes) variables))))

;; file-module-variable-exports : path? -> list?
;;   Load a file module and read its variable exports with defined-name metadata.
(define (file-module-variable-exports module-path)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (dynamic-require module-path #f)
    (call-with-values
     (lambda () (module->exports module-path 'defined-names))
     (lambda (variables _syntaxes) variables))))

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

(test-case "linklet export pairs normalize to external provider names"
  (check-equal? (webify-normalize-linklet-exports
                 '((internal-value external-name)
                   plain-export))
                '(external-name plain-export))
  (check-exn
   #rx"linklet exports must be symbols or internal/external symbol pairs"
   (lambda ()
     (webify-normalize-linklet-exports
      '((not-a-valid-export-shape))))))

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

(test-case "provider reports expose imported provider export demands"
  (define importer-report
    (webify-module-extractor-spike
     'use-list
     '(#f)
     '(0)
     '()
     '(((first first)))
     '(y)
     '(linklet (((first first))) (y)
        (define-values (y) first))
     #t
     '()))
  (define list-report
    (webify-module-extractor-spike
     'racket/list
     '(#f)
     '(0)
     '()
     '()
     '(first rest)
     '(linklet () (first rest)
        (define-values (first) 'first-proc)
        (define-values (rest) 'rest-proc))
     #t
     '()))
  (check-equal?
   (webify-module-extractor-spike-import-export-demands
    importer-report
    (list list-report))
   (list (webify-module-export-demand 'racket/list '(first)))))

(test-case "provider reports explain imported provider export demands"
  (define importer-report
    (webify-module-extractor-spike
     'use-list
     '(#f)
     '(0)
     '()
     '(((first first)))
     '(y)
     '(linklet (((first first))) (y)
        (define-values (y) first))
     #t
     '()))
  (define list-report
    (webify-module-extractor-spike
     'racket/list
     '(#f)
     '(0)
     '()
     '()
     '(first rest)
     '(linklet () (first rest)
        (define-values (first) 'first-proc)
        (define-values (rest) 'rest-proc))
     #t
     '()))
  (check-equal?
   (webify-module-extractor-spike-import-export-demand-reasons
    importer-report
    (list list-report))
   (list (webify-module-export-demand-reason
          'racket/list
          'first
          'use-list
          'first
          'first))))

(test-case "report slicing keeps only demanded export definitions and imports"
  (define report
    (webify-module-extractor-spike
     'racket/list
     '(#f)
     '(0)
     '()
     '(((pair? pair?) (list? list?) (car car) (raise-argument-error raise-argument-error))
       ((read read)))
     '(first in-port)
     '(linklet (((pair? pair?) (list? list?) (car car) (raise-argument-error raise-argument-error))
                ((read read)))
        (first in-port)
        (define-values (first)
          (lambda (x)
            (if (if (pair? x) (list? x) #f)
                (car x)
                (raise-argument-error 'first "list?" x))))
        (define-values (in-port)
          (lambda () (read))))
     #t
     '()))
  (define sliced (webify-module-extractor-spike/slice-exports report '(first)))
  (check-equal? (webify-module-extractor-spike-phase0-exports sliced) '(first))
  (check-equal?
   (webify-linklet-import-bindings
    (webify-module-extractor-spike-phase0-linklet-datum sliced))
   '((pair? pair?)
     (list? list?)
     (car car)
     (raise-argument-error raise-argument-error)))
  (check-false
   (regexp-match? #rx"read"
                  (format "~s"
                          (webify-module-extractor-spike-phase0-linklet-datum sliced)))))

(test-case "report slicing preserves decl/data rename metadata"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) (uses-reverse)
       (define-values (uses-reverse) 1/reverse)
       (define-values (unused) 'unused)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#("pico.rkt" 0)) '#(0)))))
  (define decl-linklet
    '(linklet () (provides)
       (define-values (provides)
         '(reverse #:module-binding #:mpi 0 alt-reverse 0 #f #f ()))))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '(uses-reverse) phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '() '(provides) decl-linklet #f))
     '(((reverse 1/reverse)))
     '(uses-reverse)
     phase0-linklet
     #t
     '()))
  (define sliced (webify-module-extractor-spike/slice-exports report '(uses-reverse)))
  (check-not-false (webify-module-bundle-entry-ref sliced 'data))
  (check-not-false (webify-module-bundle-entry-ref sliced 'decl))
  (check-equal? (webify-module-import-map-require-rename-aliases
                 (webify-module-extractor-spike-import-map sliced))
                '((1/reverse racket/private/pico alt-reverse))))

(test-case "report slicing follows paired exports to internal definitions"
  (define phase0-linklet
    '(linklet () ((1/reverse reverse) unused)
       (define-values (1/reverse) 'reverse-proc)
       (define-values (unused) 'unused)
       (void)))
  (define report
    (webify-module-extractor-spike
     'racket/private/pico
     '(#f)
     '(0)
     (list (webify-module-bundle-entry 0 'linklet '() '(reverse unused) phase0-linklet #f))
     '()
     '(reverse unused)
     phase0-linklet
     #t
     '()))
  (define sliced (webify-module-extractor-spike/slice-exports report '(reverse)))
  (check-equal? (webify-module-extractor-spike-phase0-exports sliced) '(reverse))
  (check-equal?
   (webify-module-extractor-spike-phase0-linklet-datum sliced)
   '(linklet () ((1/reverse reverse))
      (define-values (1/reverse) 'reverse-proc)
      (void))))

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
   #rx"missing-after-reflection"
   (lambda ()
     (webify-module-extractor-spikes->resolved-linklet-inputs
      (list use-report))))
  (check-exn
   #rx"ambiguous-after-reflection"
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
      #rx"missing-after-reflection"
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

(test-case "source module resolver accepts reflection hints"
  (define module-datum
    '(module a racket/base
       (require racket/list)
       (provide y)
       (define y (first (list 10)))))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:dependency-exports '((racket/list (first))
                               (other/list (first)))
        #:reflection-hints '((a first racket/list first))
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
         #:reflection-hints '((a first racket/list first))
         #:module-protocol-dependency 'module-protocol)))]))

(test-case "source module rename-in path is classified or resolved by hint"
  (define module-datum
    '(module a racket/base
       (require (rename-in racket/list [first head]))
       (provide y)
       (define y (head (list 10)))))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:dependency-exports '((racket/list (first))
                               (other/list (first)))
        #:reflection-hints '((a first racket/list first))
        #:module-protocol-dependency 'module-protocol))
     (check-equal? (drop (webify-module-linklet-input-imports input) 2)
                   '((first racket/list first)))]
    [else
     (check-not-false
      (or (member "source module did not produce a decompilable phase-0 linklet datum"
                  (webify-module-extractor-spike-notes report))
          (member "host Racket does not provide decompile-linklet"
                  (webify-module-extractor-spike-notes report))))]))

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
     (check-equal? (webify-module-import-map-require-rename-aliases import-map)
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
      #rx"missing-after-reflection"
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

(test-case "import map decodes relative phase-to-link module indexes"
  (define phase0-linklet
    '(linklet (((alt-reverse 1/reverse))) () (void)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#("pico.rkt" 0)
                                             #("map.rkt" 0))
                                          '#(0)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 0) 0)
                          (module-use (unsafe-vector*-ref .mpi-vector 1) 0))))))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((alt-reverse 1/reverse))) '() phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
     '(((alt-reverse 1/reverse)))
     '()
     phase0-linklet
     #t
     '()))
  (define import-map (webify-module-extractor-spike-import-map report))
  (check-equal? (webify-module-import-map-required-module-candidates import-map)
                '((0 racket/private/map)
                  (0 racket/private/pico))))

(test-case "import map decodes nested relative module-path indexes"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) () (void)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#(racket/base)
                                             #("private/base.rkt" 0)
                                             #("list.rkt" 1)
                                             #("pico.rkt" 2))
                                          '#(0 1 2 3)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 2) 0)
                          (module-use (unsafe-vector*-ref .mpi-vector 3) 0))))))
  (define report
    (webify-module-extractor-spike
     'racket/list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '() phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
     '(((reverse 1/reverse)))
     '()
     phase0-linklet
     #t
     '()))
  (define import-map (webify-module-extractor-spike-import-map report))
  (check-equal? (webify-module-import-map-required-module-candidates import-map)
                '((0 racket/private/pico)
                  (0 racket/private/list))))

(test-case "import map reports compiled module-binding rename aliases"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) () (void)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#("pico.rkt" 0)) '#(0)))))
  (define decl-linklet
    '(linklet () (provides)
       (define-values (provides)
         '(reverse #:module-binding #:mpi 0 alt-reverse 0 #f #f ()))))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '() phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '() '(provides) decl-linklet #f))
     '(((reverse 1/reverse)))
     '()
     phase0-linklet
     #t
     '()))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define rename-aliases (webify-module-import-map-require-rename-aliases import-map))
  (check-equal? rename-aliases '((1/reverse racket/private/pico alt-reverse)))
  (check-equal? (webify-module-import-map-missing-alias-import-groups import-map)
                '()))

(test-case "compiled module-binding rename aliases resolve private list reverse"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) (uses-reverse)
       (define-values (uses-reverse) 1/reverse)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#("pico.rkt" 0)) '#(0)))))
  (define decl-linklet
    '(linklet () (provides)
       (define-values (provides)
         '(reverse #:module-binding #:mpi 0 alt-reverse 0 #f #f ()))))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '(uses-reverse) phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '() '(provides) decl-linklet #f))
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

(test-case "multi-report resolver threads compiled rename aliases"
  (define phase0-linklet
    '(linklet (((reverse 1/reverse))) (uses-reverse)
       (define-values (uses-reverse) 1/reverse)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#("pico.rkt" 0)) '#(0)))))
  (define decl-linklet
    '(linklet () (provides)
       (define-values (provides)
         '(reverse #:module-binding #:mpi 0 alt-reverse 0 #f #f ()))))
  (define report
    (webify-module-extractor-spike
     'racket/private/list
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((reverse 1/reverse))) '(uses-reverse) phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '() '(provides) decl-linklet #f))
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

(test-case "module graph audit summarizes provider resolution"
  (define provider-report
    (webify-module-extractor-spike
     'racket/string
     '(#f)
     '(0)
     '()
     '()
     '(string-join.1)
     '(linklet () (string-join.1)
        (define-values (string-join.1) 'join))
     #t
     '()))
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
  (define audit
    (webify-module-reports->graph-audit
     (list provider-report importer-report)))
  (check-equal? (webify-module-graph-audit-required-provider-names audit)
                '())
  (check-equal? (webify-module-graph-audit-dependency-exports audit)
                '((racket/string (string-join.1))
                  (use-string (y))))
  (check-equal? (webify-module-graph-audit-unresolved-import-groups audit)
                '((racket/string ())
                  (use-string (((string-join.1 string-join.1))))))
  (check-equal? (webify-module-graph-audit-provider-candidates audit)
                '())
  (check-equal?
   (map (lambda (row)
          (list (webify-module-reflection-row-name row)
                (webify-module-reflection-row-imports row)
                (webify-module-reflection-row-exports row)
                (webify-module-reflection-row-unresolved-import-groups row)))
        (webify-module-graph-audit-reflection-rows audit))
   '((racket/string () (string-join.1) ())
     (use-string ((string-join.1)) (y) (((string-join.1 string-join.1))))))
  (check-equal? (webify-module-graph-audit-reflection-import-hints audit)
                '((use-string string-join.1 racket/string string-join.1)))
  (check-equal? (map webify-module-linklet-input-name
                     (webify-module-graph-audit-resolved-inputs audit))
                '(racket/string use-string))
  (define use-input
    (for/first ([input (in-list (webify-module-graph-audit-resolved-inputs audit))]
                #:when (eq? (webify-module-linklet-input-name input) 'use-string))
      input))
  (check-equal? (webify-module-linklet-input-imports use-input)
                '((string-join.1 racket/string string-join.1)))
  (check-equal? (webify-module-graph-audit-failures audit)
                '()))

(test-case "module graph audit summarizes transitive hand-authored providers"
  (define a-report
    (webify-module-extractor-spike
     'a
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x)
        (define-values (x) '1))
     #t
     '()))
  (define b-report
    (webify-module-extractor-spike
     'b
     '(#f)
     '(0)
     '()
     '((x))
     '(y)
     '(linklet (((x x))) (y)
        (define-values (y) x))
     #t
     '()))
  (define c-report
    (webify-module-extractor-spike
     'c
     '(#f)
     '(0)
     '()
     '((y))
     '(z)
     '(linklet (((y y))) (z)
        (define-values (z) y))
     #t
     '()))
  (define audit
    (webify-module-reports->graph-audit
     (list a-report b-report c-report)))
  (check-equal?
   (map webify-module-linklet-input-name
        (webify-module-graph-audit-resolved-inputs audit))
   '(a b c))
  (check-equal?
   (map webify-module-linklet-input-imports
        (webify-module-graph-audit-resolved-inputs audit))
   '(() ((x a x)) ((y b y))))
  (check-equal?
   (map (lambda (row)
          (list (webify-module-reflection-row-name row)
                (webify-module-reflection-row-imports row)
                (webify-module-reflection-row-exports row)))
        (webify-module-graph-audit-reflection-rows audit))
   '((a () (x))
     (b ((x)) (y))
     (c ((y)) (z))))
  (check-equal? (webify-module-graph-audit-reflection-import-hints audit)
                '((b x a x)
                  (c y b y))))

(test-case "module graph audit preserves renamed provider exports"
  (define provider-report
    (webify-module-extractor-spike
     'provider
     '(#f)
     '(0)
     '()
     '()
     '(internal-x)
     '(linklet () (internal-x)
        (define-values (internal-x) '7))
     #t
     '()))
  (define reexport-report
    (webify-module-extractor-spike
     'reexport
     '(#f)
     '(0)
     '()
     '((internal-x))
     '(public-x)
     '(linklet (((internal-x internal-x))) (public-x)
        (define-values (public-x) internal-x))
     #t
     '()))
  (define consumer-report
    (webify-module-extractor-spike
     'consumer
     '(#f)
     '(0)
     '()
     '((public-x))
     '(answer)
     '(linklet (((public-x public-x))) (answer)
        (define-values (answer) public-x))
     #t
     '()))
  (define audit
    (webify-module-reports->graph-audit
     (list provider-report reexport-report consumer-report)))
  (check-equal?
   (map webify-module-linklet-input-imports
        (webify-module-graph-audit-resolved-inputs audit))
   '(() ((internal-x provider internal-x)) ((public-x reexport public-x))))
  (check-equal?
   (webify-module-graph-audit-dependency-exports audit)
   '((provider (internal-x))
     (reexport (public-x))
     (consumer (answer)))))

(test-case "resolved extractor inputs can use reflection hints before broad scanning"
  (define provider-a
    (webify-module-extractor-spike
     'a
     '(#f)
     '(0)
     '()
     '()
     '(x)
     '(linklet () (x)
        (define-values (x) '1))
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
     '(linklet () (x)
        (define-values (x) '2))
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
   #rx"ambiguous-after-reflection"
   (lambda ()
     (webify-module-extractor-spikes->resolved-linklet-inputs
      (list provider-a provider-b use-report))))
  (define inputs
    (webify-module-extractor-spikes->resolved-linklet-inputs
     (list provider-a provider-b use-report)
     #:reflection-hints '((use-x x b x))))
  (define use-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input) 'use-x))
      input))
  (check-equal? (webify-module-linklet-input-imports use-input)
                '((x b x))))

(test-case "module graph audit classifies reflection-hint resolutions"
  (define provider-report
    (webify-module-extractor-spike
     'provider
     '(#f)
     '(0)
     '()
     '()
     '(only-x)
     '(linklet () (only-x)
        (define-values (only-x) '1))
     #t
     '()))
  (define use-report
    (webify-module-extractor-spike
     'use-only
     '(#f)
     '(0)
     '()
     '((only-x))
     '(y)
     '(linklet (((only-x only-x))) (y)
        (define-values (y) only-x))
     #t
     '()))
  (define audit
    (webify-module-reports->graph-audit
     (list provider-report use-report)))
  (check-equal? (webify-module-graph-audit-reflection-import-hints audit)
                '((use-only only-x provider only-x)))
  (check-equal?
   (map (lambda (outcome)
          (list (webify-module-audit-resolution-outcome-module outcome)
                (webify-module-audit-resolution-outcome-local outcome)
                (webify-module-audit-resolution-outcome-dependency outcome)
                (webify-module-audit-resolution-outcome-provider-export outcome)
                (webify-module-audit-resolution-outcome-status outcome)))
        (webify-module-graph-audit-resolution-outcomes audit))
   '((use-only only-x provider only-x resolved-by-reflection-hint))))

(test-case "module export metadata preserves provider path"
  (define bindings
    (webify-normalize-module-export-metadata
     '((0 ((public-x (provider-mpi 0 internal-x 0) internal-x.1)
           (local-y local-y.1))))))
  (check-equal? (map webify-module-export-binding-phase bindings)
                '(0 0))
  (check-equal? (map webify-module-export-binding-external bindings)
                '(public-x local-y))
  (check-equal? (map webify-module-export-binding-provider-path bindings)
                '(((provider-mpi 0 internal-x 0)) ()))
  (check-equal? (map webify-module-export-binding-internal bindings)
                '(internal-x.1 local-y.1)))

(test-case "reflection hints follow re-provide provider paths"
  (define provider-row
    (webify-module-reflection-row
     'provider
     '()
     '(internal-x)
     (webify-normalize-module-export-metadata '(internal-x))
     '()
     '()))
  (define reexport-row
    (webify-module-reflection-row
     'reexport
     '((internal-x))
     '((0 ((public-x (provider provider internal-x) internal-x.1))))
     (webify-normalize-module-export-metadata
      '((0 ((public-x (provider provider internal-x) internal-x.1)))))
     '()
     '()))
  (define consumer-row
    (webify-module-reflection-row
     'consumer
     '((public-x))
     '(answer)
     (webify-normalize-module-export-metadata '(answer))
     '()
     '(((public-x public-x)))))
  (check-equal?
   (webify-reflection-rows->import-hints
    (list provider-row reexport-row consumer-row))
   '((consumer public-x provider internal-x))))

(test-case "reflection hints follow normalized module->exports provider paths"
  (define provider-row
    (webify-module-reflection-row
     'provider
     '()
     '(internal-x)
     (webify-normalize-module-export-metadata '(internal-x))
     '()
     '()))
  (define reexport-row
    (webify-module-reflection-row
     'reexport
     '((internal-x))
     '((0 ((public-x ((provider 0 internal-x 0)) internal-x))))
     (webify-normalize-module-export-metadata
      '((0 ((public-x ((provider 0 internal-x 0)) internal-x)))))
     '()
     '()))
  (define consumer-row
    (webify-module-reflection-row
     'consumer
     '((public-x))
     '(answer)
     (webify-normalize-module-export-metadata '(answer))
     '()
     '(((public-x public-x)))))
  (check-equal?
   (webify-reflection-rows->import-hints
    (list provider-row reexport-row consumer-row))
   '((consumer public-x provider internal-x))))

(test-case "reflection hints resolve raw module->exports provider paths"
  (define raw-exports
    (declared-module-variable-exports
     '(begin
        (module provider racket/base
          (provide internal-x)
          (define internal-x 23))
        (module reexport racket/base
          (require 'provider)
          (provide (rename-out [internal-x public-x]))))
     ''reexport))
  (define bindings
    (webify-normalize-module-export-metadata
     (webify-resolve-module-export-provider-paths raw-exports)))
  (check-equal? (map webify-module-export-binding-external bindings)
                '(public-x))
  (check-equal? (map webify-module-export-binding-provider-path bindings)
                '(((provider provider internal-x))))
  (define provider-row
    (webify-module-reflection-row
     'provider
     '()
     '(internal-x)
     (webify-normalize-module-export-metadata '(internal-x))
     '()
     '()))
  (define reexport-row
    (webify-module-reflection-row
     'reexport
     '((internal-x))
     '(public-x)
     bindings
     '()
     '()))
  (define consumer-row
    (webify-module-reflection-row
     'consumer
     '((public-x))
     '(answer)
     (webify-normalize-module-export-metadata '(answer))
     '()
     '(((public-x public-x)))))
  (check-equal?
   (webify-reflection-rows->import-hints
    (list provider-row reexport-row consumer-row))
   '((consumer public-x provider internal-x))))

(test-case "graph audit uses raw module->exports metadata for re-provide hints"
  (define raw-exports
    (declared-module-variable-exports
     '(begin
        (module provider racket/base
          (provide internal-x)
          (define internal-x 23))
        (module reexport racket/base
          (require 'provider)
          (provide (rename-out [internal-x public-x]))))
     ''reexport))
  (define provider-report
    (test-report 'provider '() '(internal-x)))
  (define reexport-report
    (test-report 'reexport '(((internal-x internal-x))) '(public-x)))
  (define consumer-report
    (test-report 'consumer '(((public-x public-x))) '(answer)))
  (define audit
    (webify-module-reports->graph-audit
     (list provider-report reexport-report consumer-report)
     #:module-export-metadata `((reexport ,raw-exports))))
  (check-equal? (webify-module-graph-audit-reflection-import-hints audit)
                '((reexport internal-x provider internal-x)
                  (consumer public-x provider internal-x)))
  (check-equal?
   (map (lambda (outcome)
          (list (webify-module-audit-resolution-outcome-module outcome)
                (webify-module-audit-resolution-outcome-local outcome)
                (webify-module-audit-resolution-outcome-dependency outcome)
                (webify-module-audit-resolution-outcome-provider-export outcome)
                (webify-module-audit-resolution-outcome-status outcome)))
        (webify-module-graph-audit-resolution-outcomes audit))
   '((reexport internal-x provider internal-x resolved-by-reflection-hint)
     (consumer public-x provider internal-x resolved-by-reflection-hint))))

(test-case "module export metadata augments dependency exports"
  (define metadata
    '((provider ((0 (public-x ((kernel-provider)) public-x))))))
  (check-equal? (webify-module-export-metadata->dependency-exports metadata)
                '((provider (public-x)))))

(test-case "graph audit resolves metadata-only re-exported dependency exports"
  (define provider-report
    (test-report 'provider '() '()))
  (define consumer-report
    (test-report 'consumer '(((public-x public-x))) '(answer)))
  (define metadata
    '((provider ((0 (public-x ((kernel-provider)) public-x))))))
  (define audit
    (webify-module-reports->graph-audit
     (list provider-report consumer-report)
     #:module-export-metadata metadata))
  (check-equal? (webify-module-graph-audit-dependency-exports audit)
                '((provider (public-x)) (consumer (answer))))
  (check-equal?
   (map (lambda (outcome)
          (list (webify-module-audit-resolution-outcome-module outcome)
                (webify-module-audit-resolution-outcome-local outcome)
                (webify-module-audit-resolution-outcome-dependency outcome)
                (webify-module-audit-resolution-outcome-provider-export outcome)
                (webify-module-audit-resolution-outcome-status outcome)))
        (webify-module-graph-audit-resolution-outcomes audit))
   '((consumer public-x provider public-x resolved-by-reflection-hint))))

(test-case "reflection hints prefer local definitions over duplicate re-export origins"
  (define path-row
    (webify-module-reflection-row
     'racket/private/path
     '()
     '(path-string?)
     (list (webify-module-export-binding 0 'path-string? '() 'path-string?))
     '()
     '()))
  (define misc-row
    (webify-module-reflection-row
     'racket/private/misc
     '()
     '(path-string?)
     (list (webify-module-export-binding
            0
            'path-string?
            '((provider racket/private/path path-string?))
            'path-string?))
     '()
     '()))
  (define consumer-row
    (webify-module-reflection-row
     'consumer
     '(((path-string? path-string?)))
     '(answer)
     (list (webify-module-export-binding 0 'answer '() 'answer))
     '()
     '(((path-string? path-string?)))))
  (check-equal?
   (webify-reflection-rows->import-hints
    (list path-row misc-row consumer-row))
   '((consumer path-string? racket/private/path path-string?))))

(test-case "reflection hints canonicalize reflected file provider keys"
  (define provider-row
    (webify-module-reflection-row
     'racket/private/pico
     '()
     '(reverse)
     (list (webify-module-export-binding 0 'reverse '() 'reverse))
     '()
     '()))
  (define reexport-row
    (webify-module-reflection-row
     'racket/private/list
     '()
     '(reverse)
     (list (webify-module-export-binding
            0
            'reverse
            '((provider |/tmp/webracket/pico.rkt| reverse))
            'reverse))
     '()
     '()))
  (define consumer-row
    (webify-module-reflection-row
     'consumer
     '(((reverse reverse)))
     '(answer)
     (list (webify-module-export-binding 0 'answer '() 'answer))
     '()
     '(((reverse reverse)))))
  (check-equal?
   (webify-reflection-rows->import-hints
    (list provider-row reexport-row consumer-row))
   '((consumer reverse racket/private/pico reverse))))

(test-case "provider-local exports outrank broad metadata re-exports"
  (define phase0-linklet
    '(linklet (((external local))) (answer)
       (define-values (answer) local)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#(broad/reexport)
                                             #(direct/provider))
                                          '#(0 1)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 0) 0)
                          (module-use (unsafe-vector*-ref .mpi-vector 1) 0))))))
  (define importer-report
    (webify-module-extractor-spike
     'consumer
     '(#f)
     '(0 data decl)
     (list (webify-module-bundle-entry 0 'linklet '(((external local))) '(answer) phase0-linklet #f)
           (webify-module-bundle-entry 'data 'linklet '() '(.mpi-vector) data-linklet #f)
           (webify-module-bundle-entry 'decl 'linklet '((.mpi-vector)) '(phase-to-link-modules) decl-linklet #f))
     '(((external local)))
     '(answer)
     phase0-linklet
     #t
     '()))
  (define broad-report
    (test-report 'broad/reexport '() '()))
  (define direct-report
    (test-report 'direct/provider '() '(external)))
  (define input
    (webify-module-extractor-spike->resolved-linklet-input/providers
     importer-report
     (list broad-report direct-report)
     #:dependency-exports '((broad/reexport (external))
                            (direct/provider (external)))))
  (check-equal? (webify-module-linklet-input-imports input)
                '((local direct/provider external))))

(test-case "discovered graph audit collects provider export metadata"
  (define provider-report
    (test-report 'provider '() '(internal-x)))
  (define reexport-report
    (test-report 'reexport '(((internal-x internal-x))) '(public-x)))
  (define consumer-report
    (test-report 'consumer '(((public-x public-x))) '(answer)))
  (define raw-exports
    '((0 (public-x ((provider 0 internal-x 0)) internal-x))))
  (define (fetch-provider name)
    (case name
      [(provider) provider-report]
      [(reexport) reexport-report]
      [(consumer) consumer-report]
      [else (error 'fetch-provider "unexpected provider: ~s" name)]))
  (define (fetch-metadata name)
    (case name
      [(reexport) (list 'reexport raw-exports)]
      [else (list name (webify-module-extractor-spike-phase0-exports
                        (fetch-provider name)))]))
  (define audit
    (webify-module-reports->discovered-graph-audit
     (list consumer-report)
     #:extra-reports (list provider-report reexport-report)
     #:fetch-provider fetch-provider
     #:fetch-module-export-metadata fetch-metadata))
  (check-equal? (webify-module-graph-audit-reflection-import-hints audit)
                '((reexport internal-x provider internal-x)
                  (consumer public-x provider internal-x)))
  (check-equal?
   (map (lambda (outcome)
          (list (webify-module-audit-resolution-outcome-module outcome)
                (webify-module-audit-resolution-outcome-local outcome)
                (webify-module-audit-resolution-outcome-dependency outcome)
                (webify-module-audit-resolution-outcome-provider-export outcome)
                (webify-module-audit-resolution-outcome-status outcome)))
        (webify-module-graph-audit-resolution-outcomes audit))
   '((reexport internal-x provider internal-x resolved-by-reflection-hint)
     (consumer public-x provider internal-x resolved-by-reflection-hint))))

(test-case "raw module->exports provider paths resolve relative file providers"
  (define tmp-dir (make-temporary-file "webify-module-provider-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define provider-path (build-path tmp-dir "provider.rkt"))
      (define reexport-path (build-path tmp-dir "reexport.rkt"))
      (call-with-output-file provider-path
        (lambda (out)
          (display "#lang racket/base\n(provide internal-x)\n(define internal-x 41)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file reexport-path
        (lambda (out)
          (display "#lang racket/base\n(require \"provider.rkt\")\n(provide (rename-out [internal-x public-x]))\n" out))
        #:exists 'truncate/replace)
      (define provider-key (string->symbol (path->string provider-path)))
      (define raw-exports (file-module-variable-exports reexport-path))
      (define bindings
        (webify-normalize-module-export-metadata
         (webify-resolve-module-export-provider-paths raw-exports)))
      (check-equal? (map webify-module-export-binding-external bindings)
                    '(public-x))
      (check-equal? (map webify-module-export-binding-provider-path bindings)
                    (list (list (list 'provider provider-key 'internal-x))))
      (define provider-row
        (webify-module-reflection-row
         provider-key
         '()
         '(internal-x)
         (webify-normalize-module-export-metadata '(internal-x))
         '()
         '()))
      (define reexport-row
        (webify-module-reflection-row
         'reexport
         '((internal-x))
         '(public-x)
         bindings
         '()
         '()))
      (define consumer-row
        (webify-module-reflection-row
         'consumer
         '((public-x))
         '(answer)
         (webify-normalize-module-export-metadata '(answer))
         '()
         '(((public-x public-x)))))
      (check-equal?
       (webify-reflection-rows->import-hints
        (list provider-row reexport-row consumer-row))
       `((consumer public-x ,provider-key internal-x))))
    (lambda ()
      (delete-directory/files tmp-dir))))

(test-case "raw module->exports singleton MPI origins resolve to provider paths"
  (define tmp-dir (make-temporary-file "webify-module-singleton-provider-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define provider-path (build-path tmp-dir "provider.rkt"))
      (define reexport-path (build-path tmp-dir "reexport.rkt"))
      (call-with-output-file provider-path
        (lambda (out)
          (display "#lang racket/base\n(provide public-x)\n(define public-x 41)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file reexport-path
        (lambda (out)
          (display "#lang racket/base\n(require \"provider.rkt\")\n(provide public-x)\n" out))
        #:exists 'truncate/replace)
      (define provider-key (string->symbol (path->string provider-path)))
      (define raw-exports (file-module-variable-exports reexport-path))
      (define bindings
        (webify-normalize-module-export-metadata
         (webify-resolve-module-export-provider-paths raw-exports)))
      (check-equal? (map webify-module-export-binding-provider-path bindings)
                    (list (list (list 'provider provider-key 'public-x)))))
    (lambda ()
      (delete-directory/files tmp-dir))))

(test-case "extractor API collects source module export metadata"
  (define metadata
    (webify-source-module->module-export-metadata
     '(module metadata-source racket/base
        (provide public-x)
        (define public-x 11))))
  (check-equal? (car metadata) 'metadata-source)
  (define bindings
    (webify-normalize-module-export-metadata
     (webify-resolve-module-export-provider-paths (cadr metadata))))
  (check-equal? (map webify-module-export-binding-external bindings)
                '(public-x))
  (check-equal? (map webify-module-export-binding-internal bindings)
                '(public-x)))

(test-case "extractor API collects relative file module export metadata"
  (define tmp-dir (make-temporary-file "webify-module-metadata-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define provider-path (build-path tmp-dir "provider.rkt"))
      (call-with-output-file provider-path
        (lambda (out)
          (display "#lang racket/base\n(provide public-x)\n(define public-x 41)\n" out))
        #:exists 'truncate/replace)
      (define metadata (webify-module-path->module-export-metadata provider-path))
      (check-equal? (car metadata) (string->symbol (path->string provider-path)))
      (define bindings
        (webify-normalize-module-export-metadata
         (webify-resolve-module-export-provider-paths (cadr metadata))))
      (check-equal? (map webify-module-export-binding-external bindings)
                    '(public-x)))
    (lambda ()
      (delete-directory/files tmp-dir))))

(test-case "resolved extractor inputs use re-provide backing provider hints"
  (define provider-report
    (webify-module-extractor-spike
     'provider
     '(#f)
     '(0)
     '()
     '()
     '(internal-x)
     '(linklet () (internal-x)
        (define-values (internal-x) '7))
     #t
     '()))
  (define reexport-report
    (webify-module-extractor-spike
     'reexport
     '(#f)
     '(0)
     '()
     '((internal-x))
     '(public-x)
     '(linklet (((internal-x internal-x))) (public-x)
        (define-values (public-x) internal-x))
     #t
     '()))
  (define consumer-report
    (webify-module-extractor-spike
     'consumer
     '(#f)
     '(0)
     '()
     '((public-x))
     '(answer)
     '(linklet (((public-x public-x))) (answer)
        (define-values (answer) public-x))
     #t
     '()))
  (define inputs
    (webify-module-extractor-spikes->resolved-linklet-inputs
     (list provider-report reexport-report consumer-report)
     #:reflection-hints '((consumer public-x provider internal-x))))
  (define consumer-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input) 'consumer))
      input))
  (check-equal? (webify-module-linklet-input-imports consumer-input)
                '((public-x provider internal-x))))

(test-case "module graph audit records provider candidate fetch status"
  (define phase0-linklet
    '(linklet (((first first))) (y)
       (define-values (y) first)))
  (define data-linklet
    '(linklet () (.mpi-vector)
       (define-values (.mpi-vector)
         (deserialize-module-path-indexes '#(#(racket/list)
                                             #(racket/for))
                                          '#(0 1)))))
  (define decl-linklet
    '(linklet ((.mpi-vector)) (phase-to-link-modules)
       (define-values (phase-to-link-modules)
         (hasheqv 0 (list (module-use (unsafe-vector*-ref .mpi-vector 0) 0)
                          (module-use (unsafe-vector*-ref .mpi-vector 1) 0))))))
  (define report
    (webify-module-extractor-spike
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
  (define (fetch-provider name)
    (case name
      [(racket/list) report]
      [else (raise-arguments-error 'fetch-provider
                                   "no such provider"
                                   "module" name)]))
  (define audit
    (webify-module-reports->graph-audit
     (list report)
     #:fetch-provider fetch-provider))
  (check-equal? (map webify-module-provider-candidate-name
                     (webify-module-graph-audit-provider-candidates audit))
                '(racket/for racket/list))
  (check-equal? (map webify-module-provider-candidate-status
                     (webify-module-graph-audit-provider-candidates audit))
                '(failed fetchable)))

(module+ main
  (void))
