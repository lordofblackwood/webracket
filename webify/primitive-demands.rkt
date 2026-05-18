#lang racket/base

(provide primitive-module-name?
         primitive-module-names
         webify-primitive-demand
         webify-primitive-demand?
         webify-primitive-demand-module
         webify-primitive-demand-name
         webify-primitive-demand-sources
         webify-primitive-table-request
         webify-primitive-table-request?
         webify-primitive-table-request-module
         webify-primitive-table-request-sources
         webify-primitive-demand-report
         webify-primitive-demand-report?
         webify-primitive-demand-report-demands
         webify-primitive-demand-report-table-requests
         webify-linklet-primitive-table-requests
         webify-linklet-primitive-table-key-demands
         webify-module-linklet-inputs->primitive-demands
         webify-module-reports->primitive-demands
         webify-primitive-demand-report-missing
         webify-primitive-name-ownership
         webify-primitive-demand-report-ownership-counts
         webify-provider-owned-primitive-provider
         webify-primitive-provider-shadowed-status
         webify-primitive-provider-shadowed-names)

(require racket/list
         racket/match
         racket/runtime-path
         racket/set
         (only-in "../primitives-db.rkt"
                  primitive-db
                  primitive-info-name)
         (only-in "read-provider.rkt"
                  webify-read-public-alias-symbols)
         (only-in "regexp-provider.rkt"
                  webify-regexp-provider-owned-symbols)
         (rename-in "module-extractor-spike.rkt"
                    [webify-module-extractor-spike?
                     webify-module-report?]
                    [webify-module-extractor-spike-name
                     webify-module-report-name]
                    [webify-module-extractor-spike-bundle-entries
                     webify-module-report-bundle-entries])
         "primitive-modules.rkt"
         "module-input.rkt")

(define-runtime-path primitives-path "../primitives.rkt")

(struct webify-primitive-demand (module name sources) #:transparent)
(struct webify-primitive-table-request (module sources) #:transparent)
(struct webify-primitive-demand-report (demands table-requests) #:transparent)

(define runtime-preferred-primitive-symbols
  '(call-with-parameterization))

(define io-format-provider-owned-symbols
  '(format fprintf printf eprintf))

(define provider-owned-primitive-symbols
  (remove-duplicates
   (append webify-read-public-alias-symbols
           webify-regexp-provider-owned-symbols
           io-format-provider-owned-symbols)))

(define provider-owned-primitive-provider-table
  (for/hasheq ([name (in-list provider-owned-primitive-symbols)])
    (values name
            (cond
              [(memq name webify-read-public-alias-symbols) 'expander/read]
              [(memq name webify-regexp-provider-owned-symbols) 'regexp]
              [(memq name io-format-provider-owned-symbols) 'io/format]
              [else 'unknown]))))

(define provider-owned-primitive-symbols-set
  (list->seteq provider-owned-primitive-symbols))

(define runtime-preferred-primitive-symbols-set
  (list->seteq runtime-preferred-primitive-symbols))

;; symbol<?* : symbol? symbol? -> boolean?
;;   Sort symbols by printed name.
(define (symbol<?* a b)
  (string<? (symbol->string a) (symbol->string b)))

;; source<? : any/c any/c -> boolean?
;;   Sort mixed source labels deterministically.
(define (source<? a b)
  (string<? (format "~s" a) (format "~s" b)))

;; hash-add-source! : hash? symbol? symbol? any/c -> void?
;;   Add one demand source to a nested module/name/source table.
(define (hash-add-source! table module name source)
  (define names (hash-ref! table module make-hasheq))
  (hash-update! names
                name
                (lambda (sources) (remove-duplicates (cons source sources)))
                '()))

;; hash-add-table-source! : hash? symbol? any/c -> void?
;;   Add one primitive-table request source.
(define (hash-add-table-source! table module source)
  (hash-update! table
                module
                (lambda (sources) (remove-duplicates (cons source sources)))
                '()))

;; demand-table->list : hash? -> (listof webify-primitive-demand?)
;;   Convert a nested mutable table to sorted primitive-demand rows.
(define (demand-table->list table)
  (append*
   (for/list ([module (in-list (sort (hash-keys table) symbol<?*))])
     (define names (hash-ref table module))
     (for/list ([name (in-list (sort (hash-keys names) symbol<?*))])
       (webify-primitive-demand
        module
        name
        (sort (hash-ref names name) source<?))))))

;; table-request-table->list : hash? -> (listof webify-primitive-table-request?)
;;   Convert a mutable table to sorted primitive-table request rows.
(define (table-request-table->list table)
  (for/list ([module (in-list (sort (hash-keys table) symbol<?*))])
    (webify-primitive-table-request
     module
     (sort (hash-ref table module) source<?))))

;; merge-primitive-demand-reports : (listof report?) -> report?
;;   Merge demand and primitive-table request rows.
(define (merge-primitive-demand-reports reports)
  (define demands (make-hasheq))
  (define table-requests (make-hasheq))
  (for ([report (in-list reports)])
    (unless (webify-primitive-demand-report? report)
      (raise-argument-error 'merge-primitive-demand-reports
                            "webify-primitive-demand-report?"
                            report))
    (for ([demand (in-list (webify-primitive-demand-report-demands report))])
      (for ([source (in-list (webify-primitive-demand-sources demand))])
        (hash-add-source! demands
                          (webify-primitive-demand-module demand)
                          (webify-primitive-demand-name demand)
                          source)))
    (for ([request (in-list (webify-primitive-demand-report-table-requests report))])
      (for ([source (in-list (webify-primitive-table-request-sources request))])
        (hash-add-table-source! table-requests
                                (webify-primitive-table-request-module request)
                                source))))
  (webify-primitive-demand-report
   (demand-table->list demands)
   (table-request-table->list table-requests)))

;; webify-linklet-primitive-table-requests : linklet-datum? any/c -> requests
;;   Find literal primitive-table requests in a decompiled linklet body.
(define (webify-linklet-primitive-table-requests linklet [source 'linklet])
  (define table (make-hasheq))
  (define (request! module)
    (when (primitive-module-name? module)
      (hash-add-table-source! table module source)))
  (define (visit v)
    (cond
      [(pair? v)
       (match v
         [`(quote ,_) (void)]
         [`(primitive-table (quote ,module))
          (request! module)]
         [`(primitive-table ',module)
          (request! module)]
         [`(primitive-table ,module)
          (when (symbol? module)
            (request! module))
          (visit module)]
         [_
          (visit (car v))
          (visit (cdr v))])]
      [(vector? v)
       (for ([item (in-vector v)])
         (visit item))]
      [else (void)]))
  (visit linklet)
  (table-request-table->list table))

;; literal-primitive-table-module : any/c -> (or/c symbol? #f)
;;   Extract a literal primitive module from a primitive-table expression.
(define (literal-primitive-table-module expr)
  (match expr
    [`(primitive-table (quote ,module))
     (and (primitive-module-name? module) module)]
    [`(primitive-table ',module)
     (and (primitive-module-name? module) module)]
    [_ #f]))

;; webify-linklet-primitive-table-key-demands : linklet-datum? any/c -> demands
;;   Find literal hash lookups against variables bound to primitive tables.
(define (webify-linklet-primitive-table-key-demands linklet [source 'linklet])
  (define table-vars (make-hasheq))
  (define demands (make-hasheq))
  (define (record-table-var! id module)
    (when (and (symbol? id) (primitive-module-name? module))
      (hash-set! table-vars id module)))
  (define (record-demand! table-expr key)
    (when (and (symbol? table-expr) (symbol? key))
      (define module (hash-ref table-vars table-expr #f))
      (when module
        (hash-add-source! demands module key source))))
  ;; First collect bindings like `(define-values (kernel) (primitive-table '#%kernel))`.
  (define (visit-defs v)
    (cond
      [(pair? v)
       (match v
         [`(define-values (,id) ,expr)
          (define module (literal-primitive-table-module expr))
          (when module (record-table-var! id module))
          (visit-defs expr)]
         [_ (visit-defs (car v))
            (visit-defs (cdr v))])]
      [(vector? v)
       (for ([item (in-vector v)])
         (visit-defs item))]
      [else (void)]))
  ;; Then collect literal key reads from those table variables. This is
  ;; intentionally conservative: computed table/key uses remain runtime probes.
  (define (visit-uses v)
    (cond
      [(pair? v)
       (match v
         [`(hash-ref ,table-expr (quote ,key) . ,_rest)
          (record-demand! table-expr key)
          (visit-uses table-expr)]
         [`(hash-ref ,table-expr ',key . ,_rest)
          (record-demand! table-expr key)
          (visit-uses table-expr)]
         [`(hash-has-key? ,table-expr (quote ,key))
          (record-demand! table-expr key)
          (visit-uses table-expr)]
         [`(hash-has-key? ,table-expr ',key)
          (record-demand! table-expr key)
          (visit-uses table-expr)]
         [_ (visit-uses (car v))
            (visit-uses (cdr v))])]
      [(vector? v)
       (for ([item (in-vector v)])
         (visit-uses item))]
      [else (void)]))
  (visit-defs linklet)
  (visit-uses linklet)
  (demand-table->list demands))

;; webify-module-linklet-inputs->primitive-demands : inputs -> report?
;;   Collect explicit primitive-module imports from resolved linklet inputs.
(define (webify-module-linklet-inputs->primitive-demands inputs)
  (define who 'webify-module-linklet-inputs->primitive-demands)
  (unless (list? inputs)
    (raise-argument-error who "(listof webify-module-linklet-input?)" inputs))
  (define demands (make-hasheq))
  (define table-requests (make-hasheq))
  (for ([input (in-list inputs)])
    (unless (webify-module-linklet-input? input)
      (raise-argument-error who "webify-module-linklet-input?" input))
    (define source (webify-module-linklet-input-name input))
    (for ([import (in-list (webify-module-linklet-input-imports input))])
      (match import
        [(list _local (? primitive-module-name? module) (? symbol? name))
         (hash-add-source! demands module name source)]
        [_ (void)]))
    (for ([request (in-list
                    (webify-linklet-primitive-table-requests
                     (webify-module-linklet-input-linklet input)
                     source))])
      (for ([request-source (in-list (webify-primitive-table-request-sources request))])
        (hash-add-table-source! table-requests
                                (webify-primitive-table-request-module request)
                                request-source)))
    (for ([demand (in-list
                   (webify-linklet-primitive-table-key-demands
                    (webify-module-linklet-input-linklet input)
                    source))])
      (for ([demand-source (in-list (webify-primitive-demand-sources demand))])
        (hash-add-source! demands
                          (webify-primitive-demand-module demand)
                          (webify-primitive-demand-name demand)
                          demand-source))))
  (webify-primitive-demand-report
   (demand-table->list demands)
   (table-request-table->list table-requests)))

;; webify-module-report->primitive-table-requests : report -> report?
;;   Collect literal primitive-table requests from one extracted report.
(define (webify-module-report->primitive-table-requests report)
  (define who 'webify-module-report->primitive-table-requests)
  (unless (webify-module-report? report)
    (raise-argument-error who "webify-module-report?" report))
  (define demands (make-hasheq))
  (define table-requests (make-hasheq))
  (for ([entry (in-list (webify-module-report-bundle-entries report))]
        #:do [(define datum (webify-module-bundle-entry-datum entry))]
        #:when datum)
    (define source (list (webify-module-report-name report)
                         (webify-module-bundle-entry-key entry)))
    (for ([request (in-list (webify-linklet-primitive-table-requests datum source))])
      (for ([request-source (in-list (webify-primitive-table-request-sources request))])
        (hash-add-table-source! table-requests
                                (webify-primitive-table-request-module request)
                                request-source)))
    (for ([demand (in-list (webify-linklet-primitive-table-key-demands datum source))])
      (for ([demand-source (in-list (webify-primitive-demand-sources demand))])
        (hash-add-source! demands
                          (webify-primitive-demand-module demand)
                          (webify-primitive-demand-name demand)
                          demand-source))))
  (webify-primitive-demand-report
   (demand-table->list demands)
   (table-request-table->list table-requests)))

;; webify-module-reports->primitive-demands : reports -> report?
;;   Collect explicit primitive imports and literal primitive-table requests.
(define (webify-module-reports->primitive-demands reports
                                                  #:inputs [inputs #f])
  (define who 'webify-module-reports->primitive-demands)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-report?)" reports))
  (merge-primitive-demand-reports
   (append
    (if inputs
        (list (webify-module-linklet-inputs->primitive-demands inputs))
        '())
    (for/list ([report (in-list reports)])
      (webify-module-report->primitive-table-requests report)))))

;; primitive-db-keys : -> (listof symbol?)
;;   Read the stable primitive database keys without loading primitives.rkt.
(define (primitive-db-keys)
  (for/list ([info (in-list primitive-db)])
    (primitive-info-name info)))

(define primitive-db-keys-set
  (list->seteq (primitive-db-keys)))

;; webify-primitive-provider-shadowed-names : -> (listof symbol?)
;;   Return public provider-owned names that still exist in the primitive DB.
(define (webify-primitive-provider-shadowed-names)
  (sort
   (filter (lambda (name)
             (and (set-member? provider-owned-primitive-symbols-set name)
                  (set-member? primitive-db-keys-set name)))
           provider-owned-primitive-symbols)
   symbol<?*))

;; webify-provider-owned-primitive-provider : symbol? -> (or/c symbol? #f)
;;   Return the staged provider that owns a provider-owned public name.
(define (webify-provider-owned-primitive-provider name)
  (hash-ref provider-owned-primitive-provider-table name #f))

;; webify-primitive-provider-shadowed-status : symbol? -> symbol?
;;   Return cleanup status for provider-owned names still present as primitives.
(define (webify-primitive-provider-shadowed-status name)
  (case (webify-provider-owned-primitive-provider name)
    [(expander/read) 'temporary]
    [(regexp io/format) 'remove-primitive-later]
    [else 'review]))

;; webify-primitive-name-ownership : symbol? -> symbol?
;;   Classify a primitive-like public name for dashboard diagnostics.
(define (webify-primitive-name-ownership name)
  (cond
    [(set-member? runtime-preferred-primitive-symbols-set name)
     'runtime-preferred]
    [(and (set-member? provider-owned-primitive-symbols-set name)
          (set-member? primitive-db-keys-set name))
     'runtime-owned-but-provider-shadowed]
    [(set-member? provider-owned-primitive-symbols-set name)
     'provider-owned]
    [(set-member? primitive-db-keys-set name)
     'runtime-owned]
    [else
     'unknown]))

;; webify-primitive-demand-report-ownership-counts : report? -> (listof pair?)
;;   Count demand names by ownership class for compact dashboards.
(define (webify-primitive-demand-report-ownership-counts report)
  (define counts (make-hasheq))
  (for ([demand (in-list (webify-primitive-demand-report-demands report))])
    (hash-update! counts
                  (webify-primitive-name-ownership
                   (webify-primitive-demand-name demand))
                  add1
                  0))
  (for/list ([key (in-list '(runtime-owned
                             runtime-owned-but-provider-shadowed
                             provider-owned
                             runtime-preferred
                             unknown))]
             #:when (positive? (hash-ref counts key 0)))
    (cons key (hash-ref counts key))))

;; primitive-table-keys : symbol? -> (listof symbol?)
;;   Read available primitive keys for preflight diagnostics.
(define (primitive-table-keys module)
  (cond
    [(primitive-module-name? module)
     (primitive-db-keys)]
    [else
     '()]))

;; webify-primitive-demand-report-missing : report? -> demands
;;   Return explicit primitive imports absent from the current primitive table.
(define (webify-primitive-demand-report-missing report
                                               #:available [available primitive-table-keys])
  (define who 'webify-primitive-demand-report-missing)
  (unless (webify-primitive-demand-report? report)
    (raise-argument-error who "webify-primitive-demand-report?" report))
  (unless (procedure? available)
    (raise-argument-error who "procedure?" available))
  (filter
   values
   (for/list ([demand (in-list (webify-primitive-demand-report-demands report))])
     (define available-names (available (webify-primitive-demand-module demand)))
     (and (not (memq (webify-primitive-demand-name demand) available-names))
          demand))))
