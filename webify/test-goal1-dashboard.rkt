#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/runtime-path
         racket/string
         rackunit
         "for-provider-surface.rkt"
         "goal1-dashboard.rkt"
         "test-module-support.rkt"
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  current-webracket/base-provider-substitutions?
                  webracket/base-provider-substitution-classification
                  webracket/base-provider-substitution-disposition
                  webracket/base-provider-substitution-pressure
                  webracket/base-provider-substitute
                  webracket/base-provider-substitution-pairs
                  webracket/base-provider-substitution-records
                  webracket/base-provider-substitution-requested
                  webracket/base-provider-substitution-routed)
         (only-in "../pkgs/webracket-lib/compiler/webify/provider-trials.rkt"
                  webify-provider-trial-default-bridge-modules
                  webify-provider-trial-module-allowlist)
         "../pkgs/webracket-lib/compiler/webify/webracket-full-surface.rkt")

(define-runtime-path webracket-full-main "../pkgs/webracket/full/main.rkt")
(define-runtime-path goal1-providers-doc "GOAL1-PROVIDERS.md")
(define-runtime-path goal1-status-doc "GOAL1-STATUS.md")

;; datum-contains-symbol? : any/c symbol? -> boolean?
;;   Check whether an expanded datum contains sym anywhere.
(define (datum-contains-symbol? datum sym)
  (cond
    [(symbol? datum) (eq? datum sym)]
    [(pair? datum)
     (or (datum-contains-symbol? (car datum) sym)
         (datum-contains-symbol? (cdr datum) sym))]
    [(vector? datum)
     (for/or ([elem (in-vector datum)])
       (datum-contains-symbol? elem sym))]
    [else #f]))

;; expanded-for-helper-datum : -> any/c
;;   Expand representative for forms so we can track imported helper demands.
(define (expanded-for-helper-datum)
  (syntax->datum
   (expand
    #'(module m webracket/base
        (define xs '(1 2 3))
        (define vec '#(1 2 3))
        (define ht (hash 'a 1 'b 2))
        (define in (open-input-string "a\nb"))
        (for/list ([x (in-list xs)]) x)
        (for/list ([x (in-vector vec)]) x)
        (for/list ([x (in-range 3)]) x)
        (for/list ([(k v) (in-hash ht)]) v)
        (for/list ([line (in-lines in)]) line)
        (for/list ([(x y) (in-parallel (list 1) (list 2))]) (+ x y))))))

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
  (check-not-false (memq 'installed-provider-diagnostic categories))
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
                            webracket/sequence
                            webracket/stream
                            js/math
                            js/console))])
    (check-not-false (memq library covered)
                     (symbol->string library))))

(test-case "Goal 1 routing does not revive legacy webracket/format"
  (for ([c (in-list goal1-dashboard-cases)])
    (check-false (memq 'webracket/format (goal1-dashboard-case-libraries c))
                 (symbol->string (goal1-dashboard-case-name c))))
  (check-false (memq 'webracket/format webify-provider-trial-module-allowlist))
  (check-false (memq 'webracket/format webify-provider-trial-default-bridge-modules)))

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
  (check-equal? goal1-dashboard-default-memory-mb 1024)
  (check-equal? goal1-dashboard-default-jobs 1)
  (check-equal? goal1-dashboard-default-cache-warmup-timeout-seconds 480)
  (check-equal? goal1-dashboard-composition-timeout-seconds 240))

(test-case "module-language dashboard rows use the module bridge"
  (define module-language-cases
    (filter goal1-dashboard-case-module-language? goal1-dashboard-cases))
  (check-true (positive? (length module-language-cases)))
  (for ([c (in-list module-language-cases)])
    (check-not-false (member goal1-dashboard-module-bridge-arg
                             (goal1-dashboard-case-args c))
                     (symbol->string (goal1-dashboard-case-name c)))))

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

(test-case "compact Goal 1 dashboard exposes named presets"
  (define (names->cases names)
    (goal1-dashboard-select-cases goal1-dashboard-cases #:names names))
  (check-equal?
   (map goal1-dashboard-case-name
        (names->cases goal1-dashboard-fast-required-case-names))
   goal1-dashboard-fast-required-case-names)
  (check-true
   (< (length goal1-dashboard-fast-required-case-names)
      (length (goal1-dashboard-select-cases goal1-dashboard-cases
                                            #:tiers '(basic)
                                            #:expectations '(required)))))
  (check-not-false
   (member 'full-stream-lazy goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'base-sequence-core goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'base-sequence-hash-generate goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'base-for-nested-control-coverage goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'goal1-full-callable-exports goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'goal1-full-list-surface goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'installed-racket-list-edge-coverage goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'installed-racket-list-easy-coverage goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'installed-racket-list-expanded-coverage goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'goal1-base-sort-keywords goal1-dashboard-coverage-core-case-names))
  (check-not-false
   (member 'goal1-vector-sort-keywords goal1-dashboard-coverage-core-case-names))
  (check-false
   (member 'generator-real-diagnostic goal1-dashboard-coverage-core-case-names))
  (for ([name (in-list goal1-dashboard-composition-case-names)])
    (check-false (member name goal1-dashboard-coverage-core-case-names)
                 (symbol->string name)))
  (check-equal? goal1-dashboard-composition-case-names
                '(goal1-real-library-composition
                  goal1-sequence-format-composition
                  goal1-match-set-hash-composition
                  goal1-dict-pretty-sequence-composition))
  (check-equal? goal1-dashboard-checkpoint-case-names
                (append goal1-dashboard-coverage-core-case-names
                        goal1-dashboard-coverage-extended-case-names
                        goal1-dashboard-composition-case-names))
  (check-equal? goal1-dashboard-real-provider-readiness-case-names
                '(real-racket-dict-diagnostic
                  real-racket-dict-coverage-diagnostic
                  real-racket-function-diagnostic
                  real-racket-function-coverage-diagnostic
                  real-racket-list-diagnostic
                  real-racket-string-diagnostic
                  real-racket-sequence-diagnostic
                  real-racket-private-for-diagnostic
                  real-racket-private-kw-diagnostic
                  real-racket-class-diagnostic
                  real-racket-contract-diagnostic
                  real-racket-pretty-diagnostic
                  real-racket-pretty-coverage-diagnostic))
  (check-not-false
   (member 'ffi-js-console-coverage goal1-dashboard-coverage-extended-case-names))
  (check-not-false
   (member 'installed-racket-dict-coverage goal1-dashboard-coverage-extended-case-names))
  (check-not-false
   (member 'installed-data-queue-coverage goal1-dashboard-coverage-extended-case-names))
  (check-equal?
   (sort (append goal1-dashboard-coverage-core-case-names
                 goal1-dashboard-coverage-extended-case-names)
         symbol<?)
   (sort (map goal1-dashboard-case-name
              (goal1-dashboard-select-cases goal1-dashboard-cases
                                            #:tiers '(coverage)
                                            #:expectations '(required)))
         symbol<?)))

(test-case "composition dashboard rows are required but not everyday coverage"
  (define composition-cases
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:names goal1-dashboard-composition-case-names))
  (check-equal? (map goal1-dashboard-case-name composition-cases)
                goal1-dashboard-composition-case-names)
  (for ([c (in-list composition-cases)])
    (check-equal? (goal1-dashboard-case-tier c) 'composition)
    (check-equal? (goal1-dashboard-case-expectation c) 'required)
    (check-equal? (goal1-dashboard-case-category c)
                  'installed-provider-coverage))
  (check-equal?
   (map goal1-dashboard-case-name
        (goal1-dashboard-select-cases goal1-dashboard-cases
                                      #:tiers '(composition)
                                      #:expectations '(required)))
   goal1-dashboard-composition-case-names)
  (check-equal? (goal1-dashboard-recommended-timeout-seconds composition-cases)
                goal1-dashboard-composition-timeout-seconds)
  (check-equal?
   (goal1-dashboard-recommended-timeout-seconds
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:names goal1-dashboard-coverage-core-case-names))
   goal1-dashboard-default-timeout-seconds))

(test-case "for provider surface report classifies staged support"
  (define rows (compare-for-provider-surface))
  (define (status-ref name)
    (for/first ([row (in-list rows)]
                #:when (eq? name (for-provider-surface-row-name row)))
      (for-provider-surface-row-status row)))
  (check-equal? (status-ref 'in-bytes) 'supported)
  (check-equal? (status-ref 'in-range) 'supported)
  (check-equal? (status-ref 'in-list) 'supported)
  (check-equal? (status-ref 'in-vector) 'supported)
  (check-equal? (status-ref 'default-in-hash-keys) 'supported)
  (check-equal? (status-ref 'check-in-mutable-hash-values) 'supported)
  (check-equal? (status-ref 'append-sequences) 'supported)
  (check-equal? (status-ref ':vector-gen) 'supported)
  (check-equal? (status-ref ':hash-gen) 'supported)
  (check-equal? (status-ref 'prop:gen-sequence) 'supported)
  (check-equal? (status-ref 'struct:do-sequence) 'supported)
  (check-equal? (status-ref 'sequence-generate) 'supported)
  (check-equal? (status-ref 'in-directory) 'supported)
  (check-equal? (status-ref 'check-in-weak-hash) 'postponed)
  (check-equal? (status-ref 'stream-first) 'postponed))

(test-case "expanded for forms expose helper imports we must support"
  (define expanded (expanded-for-helper-datum))
  (for ([helper (in-list '(check-list
                           check-vector
                           check-range
                           check-in-hash
                           check-in-lines
                           make-sequence))])
    (check-true (datum-contains-symbol? expanded helper)
                (format "expanded for code should mention ~a" helper))))

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

(test-case "webracket/full surface audit keeps the language curated"
  (define status-names (map car webracket-full-surface-statuses))
  (define audit-public-names (map car webracket-full-surface-audit))
  (define dashboard-case-names (map goal1-dashboard-case-name goal1-dashboard-cases))
  (check-equal? (sort audit-public-names symbol<?)
                (sort webracket-full-addon-libraries symbol<?))
  (check-false (memq 'racket/class webracket-full-addon-libraries))
  (check-false (memq 'racket/class status-names))
  (check-not-false (memq 'racket/class webracket-full-deferred-libraries))
  (for ([row (in-list webracket-full-surface-audit)])
    (match-define (list public-provider implementation-provider owner coverage-case) row)
    (check-not-false (memq owner '(real-provider-proven staged-original webracket-owned))
                     (symbol->string public-provider))
    (check-not-false (memq coverage-case dashboard-case-names)
                     (format "~a lacks dashboard row ~a"
                             public-provider
                             coverage-case))
    (when (eq? owner 'webracket-owned)
      (check-true (regexp-match? #rx"^webracket/"
                                 (symbol->string implementation-provider))
                  (format "~a should route to an explicit WebRacket provider"
                          public-provider)))))

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

(test-case "webracket/full uses real racket/function directly"
  (define source (file->string webracket-full-main))
  (check-true (string-contains? source "racket/function")
              "webracket/full should use the installed racket/function provider")
  (check-false (string-contains? source "../function.rkt")))

(test-case "coverage dashboard rows are separate from basic provider rows"
  (define coverage-names
    (for/list ([c (in-list goal1-dashboard-cases)]
               #:when (eq? (goal1-dashboard-case-category c)
                           'installed-provider-coverage))
      (goal1-dashboard-case-name c)))
  (for ([name (in-list '(installed-racket-list-coverage
                         installed-racket-list-shim-coverage
                         installed-racket-list-edge-coverage
                         installed-racket-list-easy-coverage
                         installed-racket-list-expanded-coverage
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
                         base-for-nested-control-coverage
                         goal1-dict-pretty-sequence-composition
                         base-sequence-coverage
                         base-sequence-early-next
                         base-sequence-add-between-lazy
                         full-sequence-coverage
                         full-file-coverage
                         installed-racket-pretty-coverage
                         installed-racket-pretty-style-coverage
                         full-set-coverage
                         full-promise-coverage
                         full-stream-lazy
                         full-stream-coverage
                         installed-racket-hash-coverage
                         installed-racket-dict-coverage
                         installed-racket-dict-extra-coverage
                         installed-racket-file-coverage
                         installed-data-queue-coverage
                         installed-racket-logging-coverage
                         installed-racket-format-coverage
                         installed-racket-format-print-parameter
                         installed-racket-format-rational-precision
                         goal1-full-callable-exports
                         goal1-full-list-surface
                         goal1-base-sort-keywords
                         goal1-vector-sort-keywords
                         ffi-js-math-coverage
                         ffi-js-console-coverage
                         regexp-provider-coverage))])
    (check-not-false (memq name coverage-names)
                     (symbol->string name))))

(test-case "provider substitution table includes audited staged routes"
  (for ([pair (in-list '((racket/file . webracket/file)))])
    (check-equal? (assoc (car pair) webracket/base-provider-substitution-pairs)
                  pair))
  (check-equal?
   webracket/base-provider-substitution-pairs
   (for/list ([record (in-list webracket/base-provider-substitution-records)])
     (cons (webracket/base-provider-substitution-requested record)
           (webracket/base-provider-substitution-routed record))))
  (for ([record (in-list webracket/base-provider-substitution-records)])
    (check-not-false
     (memq (webracket/base-provider-substitution-classification record)
           '(temporary-shim runtime-owned diagnostic-shim staged-original)))
    (check-not-false
     (memq (webracket/base-provider-substitution-pressure record)
           '(high medium low)))
    (check-not-false
     (memq (webracket/base-provider-substitution-disposition record)
           '(keep-webracket-owned retire-soon postpone))))
  (check-equal? (webracket/base-provider-substitute 'racket/file)
                'webracket/file)
  (check-equal? (webracket/base-provider-substitute 'racket/dict)
                'racket/dict)
  (parameterize ([current-webracket/base-provider-substitutions? #f])
    (check-equal? (webracket/base-provider-substitute 'racket/dict)
                  'racket/dict)))

(test-case "staged provider audit classifies remaining Goal 1 substitutions"
  (define audit
    (for/hasheq ([record (in-list webracket/base-provider-substitution-records)])
      (values (webracket/base-provider-substitution-requested record)
              (list (webracket/base-provider-substitution-routed record)
                    (webracket/base-provider-substitution-disposition record)))))
  (for ([entry (in-list '((racket/hash . (webracket/hash keep-webracket-owned))
                          (racket/set . (webracket/set keep-webracket-owned))
                          (racket/stream . (webracket/stream postpone))
                          (racket/promise . (webracket/promise keep-webracket-owned))))])
    (check-equal? (hash-ref audit (car entry)) (cdr entry))))

(test-case "real provider diagnostics are recorded without becoming required"
  (define by-name
    (for/hasheq ([c (in-list goal1-dashboard-cases)])
      (values (goal1-dashboard-case-name c) c)))
  (for ([name (in-list goal1-dashboard-real-provider-readiness-case-names)])
    (define c (hash-ref by-name name))
    (check-equal? (goal1-dashboard-case-category c)
                  'installed-provider-diagnostic)
    (check-equal? (goal1-dashboard-case-expectation c)
                  'diagnostic)
    (check-not-false (member "--no-provider-substitutions"
                             (goal1-dashboard-case-args c)))))

(test-case "high-pressure temporary shims have real-provider readiness rows"
  (define (row-name requested)
    (case requested
      [(racket/contract racket/contract/base racket/contract/combinator
        racket/contract/region racket/contract/private/list
        racket/contract/private/misc)
       'real-racket-contract-diagnostic]
      [(syntax/contract) 'real-racket-contract-diagnostic]
      [else #f]))
  (for ([record (in-list webracket/base-provider-substitution-records)]
        #:when (and (eq? (webracket/base-provider-substitution-classification record)
                         'temporary-shim)
                    (eq? (webracket/base-provider-substitution-pressure record)
                         'high)))
    (define name (row-name (webracket/base-provider-substitution-requested record)))
    (check-not-false name)
    (check-not-false (memq name goal1-dashboard-real-provider-readiness-case-names)
                     (symbol->string (webracket/base-provider-substitution-requested record)))))

(test-case "compact Goal 1 dashboard classifies provider aliases that are not callable"
  (check-equal?
   (classify-detail 1
                    (string-append
                     "application: not a procedure;\n"
                     " expected a procedure that can be applied to arguments\n"
                     "  given: identity\n")
                    #rx"(?m:^42$)")
   'provider-alias-not-callable))

(test-case "Goal 1 provider plan documents staged-provider compatibility policy"
  (define doc (file->string goal1-providers-doc))
  (for ([needle (in-list '("webracket/set"
                           "webracket/dict"
                           "webracket/contract"
                           "installed-provider-coverage"
                           "Routing Rule"
                           "Provider Substitution Audit"
                           "--no-provider-substitutions"
                           "--real-provider-readiness"
                           "temporary-shim"
                           "runtime-owned"
                           "keep WebRacket-owned"
                           "Retire soon: none"
                           "postpone"
                           "Real Provider Readiness"
                           "real-racket-dict-diagnostic"
                           "real-racket-function-diagnostic"
                           "real-racket-list-diagnostic"
                           "real-racket-string-diagnostic"
                           "real-racket-sequence-diagnostic"
                           "real-racket-private-for-diagnostic"
                           "real-racket-private-kw-diagnostic"
                           "real-racket-contract-diagnostic"
                           "real-racket-class-diagnostic"
                           "real-racket-pretty-diagnostic"
                           "io/format"
                           "real installed providers"
                           "External explicit requires"
                           "claim of full"))])
    (check-not-false (regexp-match? (regexp (regexp-quote needle)) doc) needle)))

(test-case "Goal 1 status report documents dashboard workflow and boundaries"
  (define doc (file->string goal1-status-doc))
  (for ([needle (in-list '("Goal 1 is module-based WebRacket programs"
                           "--fast-required"
                           "--coverage-core"
                           "--coverage-extended"
                           "--composition"
                           "--checkpoint"
                           "--timeout 240"
                           "not a full compatibility claim"
                           "webracket/base should remain small"))])
    (check-not-false (regexp-match? (regexp (regexp-quote needle)) doc) needle)))

(module+ main
  (void))
