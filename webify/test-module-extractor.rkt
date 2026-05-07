#lang racket/base

(require rackunit
         "module-extractor.rkt"
         "module-input.rkt")

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
