#lang racket/base

(require rackunit
         racket/list
         racket/match
         "module-extractor.rkt"
         "module-input.rkt"
         "module-protocol.rkt"
         "module-registry.rkt"
         "probe-installed-module-deps.rkt")

(define (export-name-member? name exports)
  (member name (map symbol->string exports)))

(define (import-triple->printed triple)
  (for/list ([part (in-list triple)])
    (symbol->string part)))

(define (import-binding->printed binding)
  (for/list ([part (in-list binding)])
    (symbol->string part)))

(test-case "Racket 9.2 source module graph resolves into registry"
  (define source-module-data
    '((module a racket/base
        (provide x)
        (define x 10))
      (module b racket/base
        (provide y)
        (define y 20))))
  (define source-reports (map webify-compile-module-report source-module-data))
  (check-true (andmap webify-module-report-manifest-ready? source-reports))
  (define registry
    (webify-module-reports->registry
     (cons webify-module-protocol-report source-reports)
     #:module-protocol-dependency webify-module-protocol-dependency))
  (check-equal? (webify-module-registry-plan registry '(a b))
                '(module-protocol a b)))

(test-case "Racket 9.2 installed module path exposes compiled provider exports"
  (define report (webify-module-path->report 'racket/string))
  (check-true (webify-module-report? report))
  (check-equal? (webify-module-report-name report) 'racket/string)
  (check-not-false
   (export-name-member? "string-join.1" (webify-module-report-phase0-exports report)))
  (check-not-false
   (export-name-member? "string-join9.1" (webify-module-report-phase0-exports report))))

(test-case "Racket 9.2 installed direct provider exposes faslable exports"
  (define report (webify-module-path->report 'racket/private/pico))
  (check-true (webify-module-report? report))
  (check-equal? (webify-module-report-name report) 'racket/private/pico)
  (check-true (webify-module-report-manifest-ready? report))
  (check-not-false
   (export-name-member? "reverse" (webify-module-report-phase0-exports report)))
  (check-true
   (andmap symbol? (webify-module-report-phase0-exports report))))

(test-case "Racket 9.2 source use resolves racket/string internal exports"
  (define use-report
    (webify-compile-module-report
     '(module use-string racket/base
        (require racket/string)
        (provide y)
        (define y (string-join '("a" "b") ",")))))
  (define string-report (webify-module-path->report 'racket/string))
  (define input
    (webify-module-report->resolved-linklet-input/providers
     use-report
     (list string-report webify-module-protocol-report)
     #:module-protocol-dependency webify-module-protocol-dependency))
  (check-equal? (map import-triple->printed
                     (webify-module-linklet-input-imports input))
                '((".get-syntax-literal!" "module-protocol" ".get-syntax-literal!")
                  (".set-transformer!" "module-protocol" ".set-transformer!")
                  ("string-join.1" "racket/string" "string-join.1")
                  ("string-join9.1" "racket/string" "string-join9.1"))))

(test-case "Racket 9.2 source report discovers one-level installed providers"
  (define report
    (webify-compile-module-report
     '(module use-list racket/base
        (require racket/list)
        (provide y)
        (define y (first (list 10))))))
  (check-equal? (webify-module-report-required-provider-names report)
                '(racket/list))
  (define providers (webify-module-report->required-provider-reports report))
  (check-equal? (map webify-module-report-name providers)
                '(racket/list))
  (check-not-false
   (export-name-member? "first" (webify-module-report-phase0-exports (car providers)))))

(test-case "Racket 9.2 racket/private/list resolves reverse provider"
  (define list-report (webify-module-path->report 'racket/private/list))
  (define closure
    (cons webify-module-protocol-report
          (webify-module-reports->required-provider-closure
           (list list-report))))
  (define input
    (webify-module-report->resolved-linklet-input/providers
     list-report
     closure
     #:module-protocol-dependency webify-module-protocol-dependency))
  (check-not-false
   (member '("1/reverse" "racket/private/pico" "reverse")
           (map import-triple->printed
                (webify-module-linklet-input-imports input)))))

(test-case "Racket 9.2 racket/list resolves hash-update through more-scheme"
  (define list-report (webify-module-path->report 'racket/list))
  (define closure
    (cons webify-module-protocol-report
          (webify-module-reports->required-provider-closure
           (list list-report))))
  (check-not-false
   (member 'racket/private/more-scheme
           (map webify-module-report-name closure)))
  (define input
    (webify-module-report->resolved-linklet-input/providers
     list-report
     closure
     #:module-protocol-dependency webify-module-protocol-dependency))
  (check-not-false
   (member '("hash-update" "racket/private/more-scheme" "hash-update")
           (map import-triple->printed
                (webify-module-linklet-input-imports input)))))

(test-case "Racket 9.2 racket/set stream? provider choices stay stable"
  (define inputs
    (webify-source-modules->discovered-resolved-linklet-inputs
     '((module use-set racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set 1 2 2)))))
     #:extra-reports (list webify-module-protocol-report)
     #:module-protocol-dependency webify-module-protocol-dependency
     #:demand-slice? #t))
  (define stream-imports
    (for*/list ([input (in-list inputs)]
                [triple (in-list (webify-module-linklet-input-imports input))]
                #:when (eq? (car triple) 'stream?))
      (cons (webify-module-linklet-input-name input)
            (import-triple->printed triple))))
  (check-not-false
   (member '(racket/stream "stream?" "racket/private/stream-cons" "stream?")
           stream-imports))
  (check-not-false
   (member '(racket/sequence "stream?" "racket/private/for" "stream?")
           stream-imports)))

(test-case "Racket 9.2 racket/set operation dependency delta stays classified"
  (define require-inputs (extract-case-inputs 'set-require))
  (define predicate-inputs (extract-case-inputs 'set-predicate))
  (define require-names (input-names require-inputs))
  (define predicate-names (input-names predicate-inputs))
  (check-equal? require-names
                '(module-protocol use-set-require-only))
  (define added (set-diff predicate-names require-names))
  (for ([name (in-list '(racket/private/set
                         racket/private/set-types
                         racket/private/stream-cons
                         racket/stream
                         racket/pretty
                         racket/private/custom-write))])
    (check-not-false (memq name added)))
  (check-equal?
   (set-diff require-names predicate-names)
   '(use-set-require-only)))

(test-case "Racket 9.2 racket/private/for imports read for in-port"
  (define report (webify-module-path->report 'racket/private/for))
  (check-not-false
   (export-name-member? "in-port" (webify-module-report-phase0-exports report)))
  (check-not-false
   (member '("read" "read")
           (map import-binding->printed
                (webify-linklet-import-bindings
                 (webify-module-report-phase0-linklet-datum report))))))

(test-case "Racket 9.2 demand slicing preserves re-export provider path"
  (define list-report (webify-module-path->report 'racket/list))
  (define inputs
    (webify-module-reports->discovered-resolved-linklet-inputs
     (list list-report)
     #:extra-reports (list webify-module-protocol-report)
     #:module-protocol-dependency webify-module-protocol-dependency
     #:demand-slice? #t))
  (define more-scheme-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input)
                            'racket/private/more-scheme))
      input))
  (check-not-false more-scheme-input)
  (check-equal? (webify-module-linklet-input-name more-scheme-input)
                'racket/private/more-scheme)
  (check-equal?
   (match (webify-module-linklet-input-linklet more-scheme-input)
     [`(linklet ,_imports ,exports . ,_body) exports])
   '(hash-update)))
