#lang racket/base

(require rackunit
         "generated-import-origin-report.rkt")

(test-case "synthetic generated export with base-name alternative is reported"
  (define rows
    (generated-import-origin-rows/from-resolved-imports
     'demo
     '((foo.1 foo.1))
     '((foo.1 provider/generated foo.1))
     '((provider/generated (foo.1))
       (provider/base (foo)))))
  (check-equal? (length rows) 1)
  (define row (car rows))
  (check-equal? (generated-import-origin-row-module row) 'demo)
  (check-equal? (generated-import-origin-row-local row) 'foo.1)
  (check-equal? (generated-import-origin-row-external row) 'foo.1)
  (check-equal? (generated-import-origin-row-dependency row) 'provider/generated)
  (check-equal? (generated-import-origin-row-provider-export row) 'foo.1)
  (check-equal? (generated-import-origin-row-base-name row) 'foo)
  (check-equal? (generated-import-origin-row-alternative-providers row)
                '(provider/base)))

(test-case "synthetic generated export without base alternative is ignored"
  (check-equal?
   (generated-import-origin-rows/from-resolved-imports
    'demo
    '((foo.1 foo.1))
    '((foo.1 provider/generated foo.1))
    '((provider/generated (foo.1))))
   '()))

(test-case "racket/list generated sort imports are not suspicious"
  (check-equal? (generated-import-origin-rows '(racket/list)) '()))

(module+ main
  (void))
