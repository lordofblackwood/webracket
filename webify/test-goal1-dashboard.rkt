#lang racket/base

(require racket/list
         rackunit
         "goal1-dashboard.rkt"
         "../pkgs/webracket-lib/compiler/webify/webracket-full-surface.rkt")

(test-case "compact Goal 1 dashboard case set covers required categories"
  (define categories
    (remove-duplicates
     (map goal1-dashboard-case-category goal1-dashboard-cases)
     eq?))
  (check-not-false (memq 'local-module-graph categories))
  (check-not-false (memq 'installed-provider-graph categories))
  (check-not-false (memq 'language-staged-provider categories))
  (check-not-false (memq 'ffi-module categories))
  (check-not-false (memq 'staged-provider-slice categories)))

(test-case "compact Goal 1 dashboard covers must-have full libraries"
  (define covered
    (remove-duplicates
     (append-map goal1-dashboard-case-libraries goal1-dashboard-cases)
     eq?))
  (for ([library (in-list '(racket/list
                            racket/string
                            racket/set
                            racket/sequence
                            racket/match
                            racket/format
                            racket/promise
                            racket/vector
                            webracket/contract
                            webracket/set
                            webracket/promise
                            webracket/stream
                            js/math
                            js/console))])
    (check-not-false (memq library covered)
                     (symbol->string library))))

(test-case "compact Goal 1 dashboard row accessors expose cache status"
  (define row
    (goal1-dashboard-row 'sample
                         'local-module-graph
                         '(webracket/base)
                         'required
                         'pass
                         'ok
                         ""
                         'miss
                         0
                         2))
  (check-equal? (goal1-dashboard-row-note row) "")
  (check-equal? (goal1-dashboard-row-expectation row) 'required)
  (check-equal? (goal1-dashboard-row-cache-events row) 'miss)
  (check-equal? (goal1-dashboard-row-cache-files-before row) 0)
  (check-equal? (goal1-dashboard-row-cache-files-after row) 2))

(test-case "compact Goal 1 dashboard defaults are bounded"
  (check-equal? goal1-dashboard-default-timeout-seconds 120)
  (check-equal? goal1-dashboard-default-memory-mb 1024))

(test-case "compact Goal 1 dashboard selectors filter by name and category"
  (define by-name
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:names '(full-list-more full-set-list)))
  (check-equal? (map goal1-dashboard-case-name by-name)
                '(full-list-more full-set-list))
  (define by-category
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:categories '(ffi-module)))
  (check-true (andmap (lambda (c)
                        (eq? (goal1-dashboard-case-category c) 'ffi-module))
                      by-category))
  (check-not-false (member 'ffi-js-math (map goal1-dashboard-case-name by-category))))

(test-case "compact Goal 1 dashboard distinguishes diagnostic cases"
  (define required (first goal1-dashboard-cases))
  (define diagnostic
    (for/first ([c (in-list goal1-dashboard-cases)]
                #:when (eq? (goal1-dashboard-case-name c)
                            'installed-racket-set-diagnostic))
      c))
  (check-equal? (goal1-dashboard-case-expectation required) 'required)
  (check-equal? (goal1-dashboard-case-expectation diagnostic) 'diagnostic))

(test-case "webracket/full runs statuses have compact dashboard coverage"
  (define covered
    (remove-duplicates
     (append-map goal1-dashboard-case-libraries goal1-dashboard-cases)
     eq?))
  (define coverage-aliases
    '((racket/contract . webracket/contract)
      (racket/stream . webracket/stream)))
  (define (covered-name name)
    (cond
      [(assoc name coverage-aliases) => cdr]
      [else name]))
  (for ([row (in-list webracket-full-surface-statuses)]
        #:when (eq? (list-ref row 4) 'runs))
    (define name (covered-name (car row)))
    (check-not-false (memq name covered)
                     (format "~a lacks compact dashboard coverage" (car row)))))

(module+ main
  (void))
