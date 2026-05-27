#lang racket/base

(provide webify-provider-trial
         webify-provider-trial?
         webify-provider-trial-module
         webify-provider-trial-exports
         webify-provider-trial-source
         webify-provider-trial-report
         webify-provider-trial-report?
         webify-provider-trial-report-trial
         webify-provider-trial-report-status
         webify-provider-trial-report-elapsed-ms
         webify-provider-trial-report-export-demands
         webify-provider-trial-report-input-names
         webify-provider-trial-report-demand-summary
         webify-provider-trial-report-full-summary
         webify-provider-trial-report-primitive-report
         webify-provider-trial-report-missing-primitives
         webify-provider-trial-report-provider-cache-hits
         webify-provider-trial-report-provider-cache-misses
         webify-provider-trial-report-error-message
         webify-provider-trials
         webify-provider-trial-support-modules
         webify-provider-trial-default-bridge-modules
         webify-provider-trial-module-allowlist
         webify-provider-trial-module-allowed?
         webify-provider-trial-default-bridge-module-allowed?
         webify-provider-trial-ref
         webify-provider-trial-run
         webify-provider-trial-run-all
         webify-provider-trial-input-summary
         webify-provider-trial-input-summary?
         webify-provider-trial-input-summary-name
         webify-provider-trial-input-summary-import-count
         webify-provider-trial-input-summary-export-count
         webify-provider-trial-closure-summary
         webify-provider-trial-closure-summary?
         webify-provider-trial-closure-summary-input-count
         webify-provider-trial-closure-summary-linklet-count
         webify-provider-trial-closure-summary-import-count
         webify-provider-trial-closure-summary-export-count
         webify-provider-trial-closure-summary-largest-inputs
         webify-provider-trial-closure-summary-delta
         webify-provider-trial-report-primitive-ownership-counts
         webify-provider-trial-report->summary-datum)

(require racket/list
         "module-input.rkt"
         "module-extractor.rkt"
         "module-protocol.rkt")

(struct webify-provider-trial (module exports source) #:transparent)
(struct webify-provider-trial-report
  (trial
   status
   elapsed-ms
   export-demands
   input-names
   demand-summary
   full-summary
   primitive-report
   missing-primitives
   provider-cache-hits
   provider-cache-misses
   error-message)
  #:transparent)
(struct webify-provider-trial-input-summary
  (name import-count export-count)
  #:transparent)
(struct webify-provider-trial-closure-summary
  (input-count linklet-count import-count export-count largest-inputs)
  #:transparent)

;; input-export-count : webify-module-linklet-input? -> exact-nonnegative-integer?
;;   Count linklet exports for a resolved module input.
(define (input-export-count input)
  (with-handlers ([exn:fail? (lambda (_exn) 0)])
    (length
     (webify-normalize-linklet-exports
      (webify-module-linklet-input-linklet input)))))

;; input-summary : webify-module-linklet-input? -> input-summary?
;;   Summarize one resolved input for closure-size diagnostics.
(define (input-summary input)
  (webify-provider-trial-input-summary
   (webify-module-linklet-input-name input)
   (length (webify-module-linklet-input-imports input))
   (input-export-count input)))

;; closure-summary : (listof webify-module-linklet-input?) -> closure-summary?
;;   Summarize a provider closure without retaining full linklets.
(define (closure-summary inputs)
  (define summaries (map input-summary inputs))
  (define largest
    (take (sort summaries
                >
                #:key (lambda (summary)
                        (+ (webify-provider-trial-input-summary-import-count summary)
                           (webify-provider-trial-input-summary-export-count summary))))
          (min 5 (length summaries))))
  (webify-provider-trial-closure-summary
   (length inputs)
   (length inputs)
   (for/sum ([summary (in-list summaries)])
     (webify-provider-trial-input-summary-import-count summary))
   (for/sum ([summary (in-list summaries)])
     (webify-provider-trial-input-summary-export-count summary))
   largest))

;; report-summary : webify-module-report? -> input-summary?
;;   Summarize an extracted report without resolving its imports.
(define (report-summary report)
  (webify-provider-trial-input-summary
   (webify-module-report-name report)
   (length (webify-module-report-phase0-imports report))
   (length (webify-module-report-phase0-exports report))))

;; report-closure-summary : (listof webify-module-report?) -> closure-summary?
;;   Summarize a full extracted provider closure without resolving imports.
(define (report-closure-summary reports)
  (define summaries (map report-summary reports))
  (define largest
    (take (sort summaries
                >
                #:key (lambda (summary)
                        (+ (webify-provider-trial-input-summary-import-count summary)
                           (webify-provider-trial-input-summary-export-count summary))))
          (min 5 (length summaries))))
  (webify-provider-trial-closure-summary
   (length reports)
   (for/sum ([report (in-list reports)])
     (length (webify-module-report-bundle-entries report)))
   (for/sum ([summary (in-list summaries)])
     (webify-provider-trial-input-summary-import-count summary))
   (for/sum ([summary (in-list summaries)])
     (webify-provider-trial-input-summary-export-count summary))
   largest))

;; webify-provider-trial-closure-summary-delta : demand full -> hash?
;;   Compare demand-sliced and full provider closures.
(define (webify-provider-trial-closure-summary-delta demand full)
  (hasheq
   'inputs
   (- (webify-provider-trial-closure-summary-input-count full)
      (webify-provider-trial-closure-summary-input-count demand))
   'imports
   (- (webify-provider-trial-closure-summary-import-count full)
      (webify-provider-trial-closure-summary-import-count demand))
   'exports
   (- (webify-provider-trial-closure-summary-export-count full)
      (webify-provider-trial-closure-summary-export-count demand))))

;; webify-provider-trials : (listof webify-provider-trial?)
;;   Small external-provider discovery-only cases that are not runtime defaults.
(define webify-provider-trials
  (list
   (webify-provider-trial
    'racket/list
    '(first rest filter-map append-map)
    '(module use-list racket/base
       (require (only-in racket/list first rest filter-map append-map))
       (provide answer)
       (define answer (list first rest filter-map append-map))))
   (webify-provider-trial
    'racket/string
    '(string-prefix? string-suffix? string-split string-join)
    '(module use-string racket/base
       (require (only-in racket/string
                         string-prefix?
                         string-suffix?
                         string-split
                         string-join))
       (provide answer)
       (define answer
         (list string-prefix? string-suffix? string-split string-join))))
   (webify-provider-trial
    'racket/bool
    '(xor boolean=?)
    '(module use-bool racket/base
       (require (only-in racket/bool xor boolean=?))
       (provide answer)
       (define answer (list xor boolean=?))))
   (webify-provider-trial
    'racket/vector
    '(vector-map vector-filter vector-count vector-member)
    '(module use-vector racket/base
       (require (only-in racket/vector
                         vector-map
                         vector-filter
                         vector-count
                         vector-member))
       (provide answer)
       (define answer (list vector-map vector-filter vector-count vector-member))))
   (webify-provider-trial
    'racket/function
    '(identity negate const curry curryr conjoin disjoin)
    '(module use-function racket/base
       (require (only-in racket/function
                         identity
                         negate
                         const
                         curry
                         curryr
                         conjoin
                         disjoin))
       (provide answer)
       (define answer (list identity negate const curry curryr conjoin disjoin))))
   (webify-provider-trial
    'racket/hash
    '(hash-union hash-intersect hash-filter)
    '(module use-hash racket/base
       (require (only-in racket/hash hash-union hash-intersect hash-filter))
       (provide answer)
       (define answer (list hash-union hash-intersect hash-filter))))
   (webify-provider-trial
    'racket/dict
    '(dict-ref dict-count dict-map)
    '(module use-dict racket/base
       (require (only-in racket/dict dict-ref dict-count dict-map))
       (provide answer)
       (define answer (list dict-ref dict-count dict-map))))
   (webify-provider-trial
    'racket/format
    '(~a ~s ~v)
    '(module use-format racket/base
       (require (only-in racket/format ~a ~s ~v))
       (provide answer)
       (define answer (list ~a ~s ~v))))
   (webify-provider-trial
    'racket/pretty
    '(pretty-format pretty-print pretty-write pretty-display)
    '(module use-pretty racket/base
       (require (only-in racket/pretty
                         pretty-format
                         pretty-print
                         pretty-write
                         pretty-display))
       (provide answer)
       (define answer (list pretty-format pretty-print pretty-write pretty-display))))
   (webify-provider-trial
    'data/queue
    '(make-queue enqueue! dequeue! queue-empty?)
    '(module use-queue racket/base
       (require (only-in data/queue make-queue enqueue! dequeue! queue-empty?))
       (provide answer)
       (define answer (list make-queue enqueue! dequeue! queue-empty?))))
   (webify-provider-trial
    'racket/logging
    '(log-level/c)
    '(module use-logging racket/base
       (require (only-in racket/logging log-level/c))
       (provide answer)
       (define answer log-level/c)))))

;; webify-provider-trial-support-modules : (listof symbol?)
;;   Private transitive providers that curated public trials currently demand.
(define webify-provider-trial-support-modules
  '(js/console
    js/math
    js/performance
    js/temp
    data/queue
    racket/bool
    racket/class
    racket/contract
    racket/contract/base
    racket/contract/combinator
    racket/contract/region
    racket/contract/private/list
    racket/contract/private/misc
    racket/generator
    racket/logging
    racket/match
    racket/match/gen-match
    racket/match/runtime
    racket/mpair
    racket/private/define-struct
    racket/private/for
    racket/private/hash
    racket/private/kw
    racket/private/list
    racket/private/map
    racket/private/pico
    racket/private/reqprov
    racket/unsafe/undefined
    racket/require-transform
    syntax/contract
    syntax/location
    webracket/contract
    webracket/class
    webracket/dict
    webracket/file
    webracket/format
    webracket/function
    webracket/generator
    webracket/hash
    webracket/list
    webracket/mpair
    webracket/port
    webracket/pretty
    webracket/promise
    webracket/private/for
    webracket/private/kw
    webracket/sequence
    webracket/syntax/contract
    webracket/set
    webracket/string
    webracket/stream
    webracket/unsafe/console
    webracket/unsafe/math
    webracket/unsafe/performance
    webracket/unsafe/undefined
    webracket/unsafe/temp))

;; webify-provider-trial-default-bridge-modules : (listof symbol?)
;;   External providers safe enough for the default module bridge path.
(define webify-provider-trial-default-bridge-modules
 '(js/console
    js/math
    js/performance
    js/temp
    data/queue
    racket/bool
    racket/class
    racket/contract
    racket/contract/base
    racket/contract/combinator
    racket/contract/region
    racket/format
    racket/generator
    racket/hash
    racket/list
    racket/mpair
    racket/logging
    racket/match
    racket/match/gen-match
    racket/match/runtime
    racket/set
    racket/string
    racket/vector
    racket/function
    racket/contract/private/list
    racket/contract/private/misc
    racket/private/for
    racket/private/hash
    racket/private/kw
    racket/private/list
    racket/private/map
    racket/private/pico
    racket/unsafe/undefined
    syntax/contract
    syntax/location
    webracket/contract
    webracket/class
    webracket/dict
    webracket/file
    webracket/format
    webracket/function
    webracket/generator
    webracket/hash
    webracket/list
    webracket/mpair
    webracket/port
    webracket/pretty
    webracket/promise
    webracket/private/for
    webracket/private/kw
    webracket/sequence
    webracket/syntax/contract
    webracket/set
    webracket/string
    webracket/stream
    webracket/unsafe/console
    webracket/unsafe/math
    webracket/unsafe/performance
    webracket/unsafe/undefined
    webracket/unsafe/temp))

;; webify-provider-trial-module-allowlist : (listof symbol?)
;;   External providers allowed in the temporary #lang webracket/base bridge.
(define webify-provider-trial-module-allowlist
  (append (map webify-provider-trial-module webify-provider-trials)
          webify-provider-trial-support-modules))

;; webify-provider-trial-module-allowed? : symbol? -> boolean?
;;   Check whether an external provider is in the discovery trial manifest.
(define (webify-provider-trial-module-allowed? module)
  (and (memq module webify-provider-trial-module-allowlist) #t))

;; webify-provider-trial-default-bridge-module-allowed? : symbol? -> boolean?
;;   Check whether module may use the module bridge without an explicit flag.
(define (webify-provider-trial-default-bridge-module-allowed? module)
  (and (memq module webify-provider-trial-default-bridge-modules) #t))

;; webify-provider-trial-ref : symbol? -> webify-provider-trial?
;;   Look up a provider trial by module name.
(define (webify-provider-trial-ref module)
  (define trial
    (findf (lambda (trial)
             (eq? module (webify-provider-trial-module trial)))
           webify-provider-trials))
  (unless trial
    (raise-arguments-error 'webify-provider-trial-ref
                           "unknown provider trial module"
                           "module" module))
  trial)

;; webify-provider-trial-run : webify-provider-trial? -> report?
;;   Run one discovery-only provider trial and collect primitive-demand evidence.
(define (webify-provider-trial-run trial
                                   #:fetch-provider
                                   [fetch-provider webify-module-path->report])
  (define who 'webify-provider-trial-run)
  (unless (webify-provider-trial? trial)
    (raise-argument-error who "webify-provider-trial?" trial))
  (define start-ms (current-inexact-milliseconds))
  (define provider-cache (make-webify-module-provider-cache fetch-provider))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (webify-provider-trial-report
                      trial
                      'failed
                      (- (current-inexact-milliseconds) start-ms)
                      '()
                      '()
                      (closure-summary '())
                      (closure-summary '())
                      (webify-primitive-demand-report '() '())
                      '()
                      (webify-module-provider-cache-hit-count provider-cache)
                      (webify-module-provider-cache-miss-count provider-cache)
                      (exn-message exn)))])
    (define importer-report
      (webify-compile-module-report (webify-provider-trial-source trial)))
    (define inputs
      (webify-module-reports->discovered-resolved-linklet-inputs
       (list importer-report)
       #:extra-reports (list webify-module-protocol-report)
       #:fetch-provider
       (lambda (name)
         (webify-module-provider-cache-ref provider-cache name))
       #:module-protocol-dependency webify-module-protocol-dependency
       #:demand-slice? #t))
    (define full-reports
      (webify-module-reports->required-provider-closure
       (list webify-module-protocol-report importer-report)
       #:fetch-provider
       (lambda (name)
         (webify-module-provider-cache-ref provider-cache name))
       #:skip-unfetchable? #t))
    (define export-demands
      (webify-module-report-import-export-demands
       importer-report
       full-reports
       #:module-protocol-dependency webify-module-protocol-dependency))
    (define primitive-report
      (webify-module-reports->primitive-demands '() #:inputs inputs))
    (webify-provider-trial-report
     trial
     'ok
     (- (current-inexact-milliseconds) start-ms)
     export-demands
     (map webify-module-linklet-input-name inputs)
     (closure-summary inputs)
     (report-closure-summary full-reports)
     primitive-report
     (webify-primitive-demand-report-missing primitive-report)
     (webify-module-provider-cache-hit-count provider-cache)
     (webify-module-provider-cache-miss-count provider-cache)
     #f)))

;; webify-provider-trial-run-all : -> (listof report?)
;;   Run all discovery-only provider trials in manifest order.
(define (webify-provider-trial-run-all
         #:fetch-provider [fetch-provider webify-module-path->report])
  (for/list ([trial (in-list webify-provider-trials)])
    (webify-provider-trial-run trial #:fetch-provider fetch-provider)))

;; webify-provider-trial-report-primitive-ownership-counts : report? -> alist?
;;   Count primitive demands by ownership for one provider-trial report.
(define (webify-provider-trial-report-primitive-ownership-counts report)
  (define primitive-report
    (webify-provider-trial-report-primitive-report report))
  (webify-primitive-demand-report-ownership-counts primitive-report))

;; webify-provider-trial-report->summary-datum : report? -> datum?
;;   Convert a trial report to a cacheable dashboard summary.
(define (webify-provider-trial-report->summary-datum report)
  (define trial (webify-provider-trial-report-trial report))
  (define demand-summary (webify-provider-trial-report-demand-summary report))
  (define full-summary (webify-provider-trial-report-full-summary report))
  (define primitive-report
    (webify-provider-trial-report-primitive-report report))
  (hasheq
   'module (webify-provider-trial-module trial)
   'exports (webify-provider-trial-exports trial)
   'status (webify-provider-trial-report-status report)
   'elapsed-ms (webify-provider-trial-report-elapsed-ms report)
   'inputs (webify-provider-trial-report-input-names report)
   'demand-input-count
   (webify-provider-trial-closure-summary-input-count demand-summary)
   'full-input-count
   (webify-provider-trial-closure-summary-input-count full-summary)
   'demand-import-count
   (webify-provider-trial-closure-summary-import-count demand-summary)
   'full-import-count
   (webify-provider-trial-closure-summary-import-count full-summary)
   'demand-export-count
   (webify-provider-trial-closure-summary-export-count demand-summary)
   'full-export-count
   (webify-provider-trial-closure-summary-export-count full-summary)
   'largest-inputs
   (for/list ([summary (in-list
                        (webify-provider-trial-closure-summary-largest-inputs
                         demand-summary))])
     (list (webify-provider-trial-input-summary-name summary)
           (webify-provider-trial-input-summary-import-count summary)
           (webify-provider-trial-input-summary-export-count summary)))
   'primitive-demands
   (length (webify-primitive-demand-report-demands primitive-report))
   'missing-primitives
   (length (webify-provider-trial-report-missing-primitives report))
   'ownership
   (webify-provider-trial-report-primitive-ownership-counts report)
   'cache-hits (webify-provider-trial-report-provider-cache-hits report)
   'cache-misses (webify-provider-trial-report-provider-cache-misses report)
   'error-message (webify-provider-trial-report-error-message report)))
