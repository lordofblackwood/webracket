#lang racket/base

(require rackunit
         "module-extractor.rkt"
         "module-input.rkt"
         "primitive-demands.rkt")

(test-case "primitive demand audit collects resolved primitive imports"
  (define input
    (webify-module-linklet-input
     'uses-primitives
     '(linklet (((cons cons)
                 (raise-argument-error raise-argument-error)))
        (out)
        (define-values (out) cons))
     '((cons #%kernel cons)
       (raise-argument-error #%kernel raise-argument-error)
       (ordinary racket/list reverse))))
  (define report
    (webify-module-linklet-inputs->primitive-demands (list input)))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        (webify-primitive-demand-report-demands report))
   '((#%kernel cons (uses-primitives))
     (#%kernel raise-argument-error (uses-primitives))))
  (check-equal? (webify-primitive-demand-report-table-requests report) '()))

(test-case "primitive demand audit records literal primitive-table requests"
  (define requests
    (webify-linklet-primitive-table-requests
     '(linklet () (out)
        (define-values (kernel-table) (primitive-table '#%kernel))
        (define-values (unsafe-table) (primitive-table (quote #%unsafe)))
        (define-values (ignored) (primitive-table dynamic-name)))
     'literal-probe))
  (check-equal?
   (map (lambda (request)
          (list (webify-primitive-table-request-module request)
                (webify-primitive-table-request-sources request)))
        requests)
   '((#%kernel (literal-probe))
     (#%unsafe (literal-probe)))))

(test-case "primitive demand audit compares explicit imports against availability"
  (define input
    (webify-module-linklet-input
     'availability-probe
     '(linklet (((present present) (missing missing))) (out)
        (define-values (out) present))
     '((present #%kernel present)
       (missing #%kernel missing))))
  (define report
    (webify-module-linklet-inputs->primitive-demands (list input)))
  (define missing
    (webify-primitive-demand-report-missing
     report
     #:available
     (lambda (module)
       (case module
         [(#%kernel) '(present)]
         [else '()]))))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        missing)
   '((#%kernel missing (availability-probe)))))

(test-case "primitive demand audit combines reports and resolved inputs"
  (define module-report
    (webify-module-report
     'table-user
     '(#f)
     '(0)
     (list
      (webify-module-bundle-entry
       0
       'linklet
       '()
       '(out)
       '(linklet () (out)
          (define-values (out) (primitive-table '#%linklet)))
       #f))
     '()
     '(out)
     '(linklet () (out)
        (define-values (out) (primitive-table '#%linklet)))
     #t
     '()))
  (define input
    (webify-module-linklet-input
     'input-user
     '(linklet (((primitive-table primitive-table))) (out)
        (define-values (out) primitive-table))
     '((primitive-table #%linklet primitive-table))))
  (define report
    (webify-module-reports->primitive-demands
     (list module-report)
     #:inputs (list input)))
  (check-equal?
   (map webify-primitive-demand-name
        (webify-primitive-demand-report-demands report))
   '(primitive-table))
  (check-equal?
   (map webify-primitive-table-request-module
        (webify-primitive-demand-report-table-requests report))
   '(#%linklet)))
