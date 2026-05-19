#lang racket/base

(require racket/list
         rackunit
         "goal1-dashboard.rkt")

(test-case "compact Goal 1 dashboard case set covers required categories"
  (define categories
    (remove-duplicates
     (map goal1-dashboard-case-category goal1-dashboard-cases)
     eq?))
  (check-not-false (memq 'local-module-graph categories))
  (check-not-false (memq 'installed-provider-graph categories))
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
                            js/math
                            js/console))])
    (check-not-false (memq library covered)
                     (symbol->string library))))

(test-case "compact Goal 1 dashboard row accessors expose cache status"
  (define row
    (goal1-dashboard-row 'sample
                         'local-module-graph
                         '(webracket/base)
                         'pass
                         'ok
                         ""
                         'miss
                         0
                         2))
  (check-equal? (goal1-dashboard-row-note row) "")
  (check-equal? (goal1-dashboard-row-cache-events row) 'miss)
  (check-equal? (goal1-dashboard-row-cache-files-before row) 0)
  (check-equal? (goal1-dashboard-row-cache-files-after row) 2))

(module+ main
  (void))
