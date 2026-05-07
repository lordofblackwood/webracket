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

(module+ main
  (void))
