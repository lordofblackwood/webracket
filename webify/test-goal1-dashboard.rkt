#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "goal1-dashboard.rkt"
         "test-module-support.rkt"
         "../pkgs/webracket-lib/compiler/webify/webracket-full-surface.rkt")

(define-runtime-path webracket-full-main "../pkgs/webracket/full/main.rkt")
(define-runtime-path goal1-providers-doc "GOAL1-PROVIDERS.md")

;; module-runtime-export-symbols : symbol? -> (listof symbol?)
;;   List phase-0 value exports for an already-loadable module path.
(define (module-runtime-export-symbols module-path)
  (call-with-webracket-collection-path
   (lambda ()
     (parameterize ([current-namespace (make-base-namespace)])
       (namespace-require module-path)
       (define-values (value-exports _syntax-exports)
         (module->exports module-path))
       (define phase-0 (assoc 0 value-exports))
       (if phase-0
           (map car (cdr phase-0))
           '())))))

(test-case "compact Goal 1 dashboard case set covers required categories"
  (define categories
    (remove-duplicates
     (map goal1-dashboard-case-category goal1-dashboard-cases)
     eq?))
  (check-not-false (memq 'local-module-graph categories))
  (check-not-false (memq 'installed-provider-graph categories))
  (check-not-false (memq 'installed-provider-coverage categories))
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
                            racket/port
                            racket/math
                            racket/path
                            webracket/file
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
                         'basic
                         '(webracket/base)
                         'required
                         'pass
                         'ok
                         ""
                         'miss
                         0
                         2))
  (check-equal? (goal1-dashboard-row-tier row) 'basic)
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

(test-case "compact Goal 1 dashboard selectors filter by tier and expectation"
  (define coverage
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:tiers '(coverage)))
  (check-true (andmap (lambda (c)
                        (eq? (goal1-dashboard-case-tier c) 'coverage))
                      coverage))
  (check-not-false (member 'installed-racket-list-coverage
                           (map goal1-dashboard-case-name coverage)))
  (check-not-false (member 'installed-racket-string-join
                           (map goal1-dashboard-case-name coverage)))
  (define required
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:expectations '(required)))
  (check-true (andmap (lambda (c)
                        (eq? (goal1-dashboard-case-expectation c) 'required))
                      required))
  (check-not-false (member 'installed-racket-port-display
                           (map goal1-dashboard-case-name required)))
  (define fast-required
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:tiers '(basic)
                                  #:expectations '(required)))
  (check-true (andmap (lambda (c)
                        (and (eq? (goal1-dashboard-case-tier c) 'basic)
                             (eq? (goal1-dashboard-case-expectation c) 'required)))
                      fast-required))
  (check-false (member 'installed-racket-string-join
                       (map goal1-dashboard-case-name fast-required))))

(test-case "webracket/full runs statuses have compact dashboard coverage"
  (define covered
    (remove-duplicates
     (append-map goal1-dashboard-case-libraries goal1-dashboard-cases)
     eq?))
  (define coverage-aliases
    '((racket/contract . webracket/contract)
      (webracket/pretty . racket/pretty)
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

(test-case "webracket/full export manifest includes intended add-on names"
  (define full-exports (module-runtime-export-symbols 'webracket/full))
  (for ([name (in-list '(boolean=?
                         bytes-append
                         format
                         compose
                         conjoin
                         first
                         sqr
                         build-path
                         with-output-to-string
                         sequence->list
                         stream-first
                         string-contains?
                         vector-member
                         contract
                         promise?
                         set-count))])
    (check-not-false (memq name full-exports)
                     (symbol->string name))))

(test-case "webracket/full stays curated instead of requiring racket/function directly"
  (define source (file->string webracket-full-main))
  (check-false (regexp-match? #rx"^[ \t]*racket/function\\b" source)
               "webracket/full should route racket/function names through webracket/function")
  (check-true (string-contains? source "../function.rkt")))

(test-case "coverage dashboard rows are separate from basic provider rows"
  (define coverage-names
    (for/list ([c (in-list goal1-dashboard-cases)]
               #:when (eq? (goal1-dashboard-case-category c)
                           'installed-provider-coverage))
      (goal1-dashboard-case-name c)))
  (for ([name (in-list '(installed-racket-list-coverage
                         installed-racket-string-coverage
                         installed-racket-string-join
                         full-bytes-coverage
                         installed-racket-bool-coverage
                         installed-racket-vector-append
                         installed-racket-vector-coverage
                         installed-racket-function-coverage
                         installed-racket-port-coverage
                         installed-racket-port-display
                         full-shared-coverage
                         full-math-coverage
                         full-path-coverage
                         full-match-coverage
                         full-sequence-coverage
                         full-file-coverage
                         installed-racket-pretty-coverage
                         full-set-coverage
                         full-promise-coverage
                         full-stream-coverage
                         installed-racket-hash-coverage
                         installed-racket-format-coverage
                         ffi-js-math-coverage
                         ffi-js-console-coverage
                         regexp-provider-coverage))])
    (check-not-false (memq name coverage-names)
                     (symbol->string name))))

(test-case "Goal 1 provider plan documents staged-provider compatibility policy"
  (define doc (file->string goal1-providers-doc))
  (for ([needle (in-list '("webracket/function"
                           "webracket/set"
                           "webracket/contract"
                           "installed-provider-coverage"
                           "Routing Rule"
                           "io/format"
                           "webracket/string"
                           "External explicit requires"
                           "claim of full"))])
    (check-not-false (regexp-match? (regexp (regexp-quote needle)) doc) needle)))

(module+ main
  (void))
