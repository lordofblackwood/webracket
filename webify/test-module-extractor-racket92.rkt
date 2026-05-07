#lang racket/base

(require rackunit
         racket/list
         "module-extractor.rkt"
         "module-input.rkt"
         "module-protocol.rkt"
         "module-registry.rkt")

(define (export-name-member? name exports)
  (member name (map symbol->string exports)))

(define (import-triple->printed triple)
  (for/list ([part (in-list triple)])
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
   (export-name-member? "reverse" (webify-module-report-phase0-exports report))))

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
