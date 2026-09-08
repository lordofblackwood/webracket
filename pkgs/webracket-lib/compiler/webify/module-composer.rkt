#lang racket/base

(provide webify-lowered-slice-spec
         webify-lowered-slice-spec?
         webify-lowered-slice-spec-name
         webify-lowered-slice-spec-expr
         webify-lowered-slice-spec-importss
         webify-lowered-slice-spec-import-sources
         webify-lowered-slice-spec-exports
         webify-linklet-slice-spec
         webify-linklet-slice-spec?
         webify-linklet-slice-spec-name
         webify-linklet-slice-spec-linklet
         webify-linklet-slice-spec-import-sources
         webify-module-fragment
         webify-module-fragment?
         webify-module-fragment-datum
         webify-module-fragment-instance
         current-composer-primitive-import-cell-overrides
         webify-compose-module-fragments
         webify-compose-module-fragments-syntax
         webify-compose-lowered-first-slices
         webify-compose-linklet-first-slices)

(require racket/list
         racket/match
         "../private/parameters.rkt"
         "bridge-stats.rkt"
         "first-slice.rkt"
         "known.rkt"
         "module-instance.rkt"
         "primitive-modules.rkt")

(struct webify-lowered-slice-spec (name expr importss import-sources exports) #:transparent)
(struct webify-linklet-slice-spec (name linklet import-sources) #:transparent)
(struct webify-module-fragment (datum instance) #:transparent)
(struct analyzed-linklet-slice (name
                                expr
                                importss
                                exports
                                import-sources
                                imports-abis
                                public-cell-imports-abis
                                exports-info)
  #:transparent)

(define current-composer-primitive-import-cell-overrides
  (make-parameter (hasheq)))

;; datum-contains-symbol? : any/c symbol? -> boolean?
;;   Check whether sym appears anywhere inside datum.
(define (datum-contains-symbol? datum sym)
  (or (eq? datum sym)
      (cond
        [(pair? datum)
         (or (datum-contains-symbol? (car datum) sym)
             (datum-contains-symbol? (cdr datum) sym))]
        [(vector? datum)
         (for/or ([entry (in-vector datum)])
           (datum-contains-symbol? entry sym))]
        [else
         #f])))

;; compiled-directory-list-build-first-import? : symbol? -> boolean?
;;   Recognize Racket CS's internal directory-list variant after Webify's
;;   alpha-renaming. Names like `directory-list.1` pass #:build? first, while
;;   names like `directory-list78.1` keep the public argument order.
(define (compiled-directory-list-build-first-import? name)
  (and (symbol? name)
       (regexp-match? #rx"^directory-list\\.[0-9]+$" (symbol->string name))))

;; compiled-primitive-base-name : symbol? -> symbol?
;;   Remove decompiler/internal suffixes such as `sort7.1` from primitive imports.
(define (compiled-primitive-base-name name)
  (string->symbol
   (regexp-replace #rx"[0-9]*[.][0-9]+$"
                   (symbol->string name)
                   "")))

;; compiled-kernel-primitive-export-name : symbol? -> symbol?
;;   Strip the host expander's `kernel:` prefix from primitive export names.
(define (compiled-kernel-primitive-export-name name)
  (string->symbol
   (regexp-replace #rx"^kernel:"
                   (symbol->string name)
                   "")))

;; compiled-keyword-primitive-alias : symbol? symbol? -> (or/c symbol? #f)
;;   Recover canonical primitive names for keyword-capable primitive aliases.
(define (compiled-keyword-primitive-alias import-name export-name)
  (for/or ([name (in-list (list import-name export-name))])
    (define base (compiled-primitive-base-name name))
    (and (memq base '(sort vector-sort vector-sort!))
         base)))

;; compiled-primitive-import-cell-export : symbol? symbol? -> symbol?
;;   Adapt compiled internal primitive imports whose local calling convention
;;   differs from the public WebRacket primitive.
(define (compiled-primitive-import-cell-export import-name export-name)
  (cond
    [(compiled-directory-list-build-first-import? import-name)
     'webracket-directory-list-build-first]
    [(compiled-keyword-primitive-alias import-name export-name)]
    [else
     (compiled-kernel-primitive-export-name export-name)]))

;; symbolic-import-name=? : symbol? symbol? -> boolean?
;;   Compare generated import names after stripping decompiler index prefixes.
(define (symbolic-import-name=? a b)
  (define (base-name name)
    (regexp-replace #rx"^[0-9]+/" (symbol->string name) ""))
  (or (eq? a b)
      (string=? (base-name a) (base-name b))))

;; validate-begin-datum! : symbol? any/c -> void?
;;   Reject generated fragments that cannot be spliced into top-level code.
(define (validate-begin-datum! who datum)
  (match datum
    [`(begin ,_body ...)
     (void)]
    [_
     (raise-arguments-error who
                            "expected generated fragment datum to be a begin form"
                            "datum" datum)]))

;; begin-body : any/c -> (listof any/c)
;;   Extract top-level forms from a generated begin datum.
(define (begin-body datum)
  (validate-begin-datum! 'begin-body datum)
  (cdr datum))

;; validate-fragment! : symbol? any/c -> void?
;;   Reject values that cannot participate in module-fragment composition.
(define (validate-fragment! who fragment)
  (unless (webify-module-fragment? fragment)
    (raise-argument-error who "webify-module-fragment?" fragment))
  (validate-begin-datum! who (webify-module-fragment-datum fragment))
  (unless (webify-module-instance? (webify-module-fragment-instance fragment))
    (raise-arguments-error who
                           "fragment instance is not a webify module instance"
                           "fragment" fragment)))

;; validate-tail-forms! : symbol? any/c -> void?
;;   Reject non-list tail forms before composing top-level code.
(define (validate-tail-forms! who tail-forms)
  (unless (list? tail-forms)
    (raise-argument-error who "list?" tail-forms)))

;; webify-compose-module-fragments : (listof webify-module-fragment?) [#:tail (listof any/c)] -> any/c
;;   Splice adapted module fragments into one top-level begin datum.
(define (webify-compose-module-fragments fragments #:tail [tail-forms '((void))])
  (define who 'webify-compose-module-fragments)
  (unless (list? fragments)
    (raise-argument-error who "list?" fragments))
  (validate-tail-forms! who tail-forms)
  (for ([fragment (in-list fragments)])
    (validate-fragment! who fragment))
  `(begin
     ,@(apply append
              (for/list ([fragment (in-list fragments)])
                (begin-body (webify-module-fragment-datum fragment))))
     ,@tail-forms))

;; webify-compose-module-fragments-syntax : (listof webify-module-fragment?) [#:tail (listof any/c)] -> syntax?
;;   Convert composed module fragments to top-level syntax for the compiler.
(define (webify-compose-module-fragments-syntax fragments #:tail [tail-forms '((void))])
  (datum->syntax #f
                 (webify-compose-module-fragments fragments #:tail tail-forms)))

;; validate-slice-spec! : symbol? any/c -> void?
;;   Reject lowered slice specs with malformed composition metadata.
(define (validate-slice-spec! who spec)
  (unless (webify-lowered-slice-spec? spec)
    (raise-argument-error who "webify-lowered-slice-spec?" spec))
  (unless (symbol? (webify-lowered-slice-spec-name spec))
    (raise-arguments-error who
                           "slice name must be a symbol"
                           "name" (webify-lowered-slice-spec-name spec)))
  (unless (and (list? (webify-lowered-slice-spec-exports spec))
               (andmap symbol? (webify-lowered-slice-spec-exports spec)))
    (raise-arguments-error who
                           "slice exports must be a list of symbols"
                           "exports" (webify-lowered-slice-spec-exports spec))))

;; validate-linklet-slice-spec! : symbol? any/c -> void?
;;   Reject linklet slice specs with malformed composition metadata.
(define (validate-linklet-slice-spec! who spec)
  (unless (webify-linklet-slice-spec? spec)
    (raise-argument-error who "webify-linklet-slice-spec?" spec))
  (unless (symbol? (webify-linklet-slice-spec-name spec))
    (raise-arguments-error who
                           "slice name must be a symbol"
                           "name" (webify-linklet-slice-spec-name spec))))

;; valid-imports-abis? : any/c -> boolean?
;;   Check whether grouped import ABI metadata uses supported boolean/shape tags.
(define (valid-imports-abis? imports-abis)
  (and (list? imports-abis)
       (for/and ([group (in-list imports-abis)])
         (and (list? group)
              (for/and ([abi (in-list group)])
                (or (not abi)
                    (eq? abi #t)
                    (eq? abi 'proc)
                    (exact-nonnegative-integer? abi)))))))

;; validate-import-source! : symbol? any/c -> void?
;;   Reject import source triples that cannot resolve through previous instances.
(define (validate-import-source! who source)
  (match source
    [(list (? symbol?) (? symbol?) (? symbol?))
     (void)]
    [_
     (raise-argument-error who "(list/c symbol? symbol? symbol?)" source)]))

;; import-source? : any/c -> boolean?
;;   Check whether v is one flat import-source triple.
(define (import-source? v)
  (match v
    [(list (? symbol?) (? symbol?) (? symbol?)) #t]
    [_                                         #f]))

;; grouped-import-sources? : any/c -> boolean?
;;   Check whether v is a grouped import-source list.
(define (grouped-import-sources? v)
  (and (list? v)
       (for/and ([group (in-list v)])
         (and (list? group)
              (andmap import-source? group)))))

;; flat-import-sources? : any/c -> boolean?
;;   Check whether v is a flat import-source list.
(define (flat-import-sources? v)
  (and (list? v)
       (andmap import-source? v)))

;; import-source-groups->import-keys : symbol? (listof (listof source?)) -> (vectorof (or/c symbol? #f))
;;   Derive one provider key per import group for on-demand prior export knowns.
(define (import-source-groups->import-keys who grouped-sources)
  (list->vector
   (for/list ([group (in-list grouped-sources)])
     (unless (list? group)
       (raise-argument-error who "(listof list?)" grouped-sources))
     (define dependencies
       (remove-duplicates
        (for/list ([source (in-list group)])
          (validate-import-source! who source)
          (second source))
        eq?))
     (match dependencies
       [(list (? symbol? dependency)) dependency]
       [_ #f]))))

;; import-source-groups->abi-only-knowns : symbol? symbol? (listof (listof source?)) hash? -> values
;;   Build per-group prior-known tables keyed by the importer's own import names.
(define (import-source-groups->abi-only-knowns who importer-name grouped-sources prior-exports-infos)
  (define group-knowns (make-hasheq))
  (define group-keys
    (list->vector
     (for/list ([group (in-list grouped-sources)]
                [index (in-naturals)])
       (unless (list? group)
         (raise-argument-error who "(listof list?)" grouped-sources))
       (define knowns
         (for/fold ([knowns (hasheq)])
                   ([source (in-list group)])
           (validate-import-source! who source)
           (match-define (list import-name provider-name export-name) source)
           (define provider-knowns
             (prior-export-knowns prior-exports-infos provider-name))
           (if (and provider-knowns
                    (hash-has-key? provider-knowns export-name))
               ;; Use the current import name as the key, because compiled linklets
               ;; can preserve readable-but-uninterned symbols like `theme4.1`.
               (hash-set knowns
                         import-name
                         (hash-ref provider-knowns export-name))
               knowns)))
       (and (positive? (hash-count knowns))
            (let ([key (string->uninterned-symbol
                        (format "~a-abi-knowns-group-~a" importer-name index))])
              (hash-set! group-knowns key knowns)
              key)))))
  (values group-keys group-knowns))

;; kernel-known-export-names : (listof symbol?)
;;   Narrow kernel exports currently approved for value-safe ABI classification.
(define kernel-known-export-names
  '(displayln
    error
    external?
    js-log
    print-values
    procedure->external
    procedure-rename
    procedure-reduce-arity-mask
    prop:procedure
    qq-append
    sort/expanded-keywords
    string->number
    unsafe-ffi-primitive
    vector-sort/expanded-keywords
    vector-sort!/expanded-keywords))

;; kernel-provider-knowns : hasheq?
;;   Conservative known table for the observed kernel ABI holdouts.
(define kernel-provider-knowns
  (for/hasheq ([name (in-list kernel-known-export-names)])
    (values name a-known-constant)))

;; current-module-provider-kind : any/c -> symbol?
;;   Classify one module according to the active bridge graph metadata.
(define (current-module-provider-kind module-name)
  (define module-kinds
    (current-module-bridge-module-kinds))
  (cond
    [(kernel-provider-name? module-name) 'kernel-provider]
    [(and module-kinds
          (hash-has-key? module-kinds module-name))
     (hash-ref module-kinds module-name)]
    [else 'unknown-provider]))

;; prior-export-knowns : hash? any/c -> any/c
;;   Look up one provider module's previously analyzed export metadata.
(define (prior-export-knowns prior-exports-infos module-name)
  (cond
    [(kernel-provider-name? module-name)
     kernel-provider-knowns]
    [(symbol? module-name)
     (hash-ref prior-exports-infos module-name #f)]
    [else
     #f]))

;; kernel-prior-known? : hash? any/c symbol? -> boolean?
;;   Check whether one kernel import resolved through the explicit kernel-known table.
(define (kernel-prior-known? prior-exports-infos module-name export-name)
  (and (eq? (current-module-provider-kind module-name) 'kernel-provider)
       (hash-has-key? (prior-export-knowns prior-exports-infos module-name)
                      export-name)))

;; import-abi-false-reason : hash? symbol? symbol? boolean? boolean? -> symbol?
;;   Classify why one import ABI remained `#f`.
(define (import-abi-false-reason prior-exports-infos provider export had-new-imports? had-app-value?)
  (cond
    [had-new-imports? 'import-group-added-by-inlining]
    [had-app-value?    'unsupported-lowered-form]
    [(eq? (current-module-provider-kind provider) 'unknown-provider)
     'unknown-provider-kind]
    [(not (prior-export-knowns prior-exports-infos provider))
     'missing-export-info]
    [(not (hash-has-key? (prior-export-knowns prior-exports-infos provider) export))
     'missing-export-info]
    [else
     'unknown]))

;; rerun-failure-reason : exn:fail? -> symbol?
;;   Classify an analysis-only rerun failure for bridge diagnostics.
(define (rerun-failure-reason e)
  (if (regexp-match? #rx"#%app/value" (exn-message e))
      'unsupported-lowered-form
      'analysis-error))

;; record-import-abi-metadata! : symbol? (listof (listof source?)) (listof (listof any/c)) hash? keyword args -> void?
;;   Record per-import ABI decisions for bridge diagnostics and planning.
(define (record-import-abi-metadata! importer-name
                                     import-sources
                                     imports-abis
                                     prior-exports-infos
                                     #:baseline-imports-abis [baseline-imports-abis #f]
                                     #:group-keys [group-keys #f]
                                     #:false-reason [false-reason #f])
  (define baseline-groups
    (or baseline-imports-abis imports-abis))
  (for ([group (in-list import-sources)]
        [abi-group (in-list imports-abis)]
        [baseline-group (in-list baseline-groups)]
        [group-key (in-list (if group-keys
                                group-keys
                                (make-list (length import-sources) #f)))])
    (for ([source (in-list group)]
          [abi (in-list abi-group)]
          [baseline-abi (in-list baseline-group)])
      (match-define (list import-name provider-name export-name) source)
      (define provider-kind
        (current-module-provider-kind provider-name))
      (define kernel-known?
        (kernel-prior-known? prior-exports-infos provider-name export-name))
      (define prior-knowns
        (prior-export-knowns prior-exports-infos provider-name))
      (define prior-export-known?
        (and prior-knowns (hash-has-key? prior-knowns export-name)))
      (define false-reason*
        (and (not abi)
             (or false-reason
                 (import-abi-false-reason prior-exports-infos
                                          provider-name
                                          export-name
                                          #f
                                          #f))))
      (webify-bridge-stats-set!
       (list 'bridge-import-abi-meta importer-name provider-name import-name export-name)
       (hasheq 'importer-module importer-name
               'provider-module provider-name
               'import-name import-name
               'export-name export-name
               'group-key group-key
               'provider-kind provider-kind
               'abi abi
               'baseline-abi baseline-abi
               'kernel-known? (and kernel-known? #t)
               'prior-export-known? (and prior-export-known? #t)
               'false-reason false-reason*))
      (when (not abi)
        (webify-bridge-stats-inc! 'bridge-import-abi-false-count)
        (webify-bridge-stats-inc! (list 'bridge-import-abi-false-module provider-name))
        (webify-bridge-stats-inc! (list 'bridge-import-abi-false-name export-name))
        (webify-bridge-stats-inc! (list 'bridge-import-abi-false-provider-kind provider-kind))
        (when (eq? provider-kind 'kernel-provider)
          (webify-bridge-stats-inc! 'bridge-import-abi-false-kernel-provider-count))
        (webify-bridge-stats-inc! (list 'bridge-import-abi-false-reason false-reason*))
        (webify-bridge-stats-inc! 'bridge-import-abi-false-cell-forcing-count))
      (when (and (not baseline-abi) abi)
        (webify-bridge-stats-inc! 'bridge-import-abi-resolved-from-prior-export-knowns-count)
        (when kernel-known?
          (webify-bridge-stats-inc! 'bridge-import-abi-resolved-from-kernel-knowns-count)))
      (when (and (not baseline-abi) (not abi) prior-export-known?)
        (webify-bridge-stats-inc! 'bridge-import-abi-still-false-after-prior-knowns-count)
        (when kernel-known?
          (webify-bridge-stats-inc! 'bridge-import-abi-false-kernel-after-knowns-count))))))

;; flat-import-sources->groups : symbol? symbol? (listof (listof symbol?)) (listof source?) -> (listof (listof source?))
;;   Group flat source triples according to linklet import metadata.
(define (flat-import-sources->groups who name importss import-sources)
  (define imports (apply append importss))
  (define duplicate-import (check-duplicates imports))
  (when duplicate-import
    (raise-arguments-error who
                           "flat import sources cannot resolve duplicate linklet import names"
                           "name" name
                           "import" duplicate-import
                           "imports" importss))
  (define entries
    (for/list ([source (in-list import-sources)])
      (validate-import-source! who source)
      (cons (car source) source)))
  (define duplicate-source (check-duplicates (map car entries)))
  (when duplicate-source
    (raise-arguments-error who
                           "duplicate import source names are not supported"
                           "name" name
                           "import" duplicate-source))
  (define source-table
    (for/hasheq ([entry (in-list entries)])
      (values (car entry) (cdr entry))))
  (define import-table
    (for/hasheq ([import (in-list imports)])
      (values import #t)))
  (define symbolic-source-cache (make-hasheq))
  (define import-membership-cache (make-hasheq))
  (define (symbolic-sources import)
    (hash-ref! symbolic-source-cache
               import
               (lambda ()
                 (for/list ([entry (in-list entries)]
                            #:when (symbolic-import-name=? import (car entry)))
                   (cdr entry)))))
  (define (linklet-import? import)
    (or (hash-ref import-table import #f)
        (hash-ref! import-membership-cache
                   import
                   (lambda ()
                     (for/or ([linklet-import (in-list imports)])
                       (symbolic-import-name=? import linklet-import))))))
  (define (lookup-source import)
    (define exact-source (hash-ref source-table import #f))
    (cond
      [exact-source exact-source]
      [else
       (define matches (symbolic-sources import))
       (match matches
         [(list (list _import instance export))
          (list import instance export)]
         ['()
          (raise-arguments-error who
                                 "missing import source"
                                 "name" name
                                 "import" import
                                 "imports" importss
                                 "available imports" (hash-keys source-table))]
         [_
          (raise-arguments-error who
                                 "ambiguous symbolic import source"
                                 "name" name
                                 "import" import
                                 "imports" matches)])]))
  (define grouped
    (for/list ([group (in-list importss)])
      (for/list ([import (in-list group)])
        (lookup-source import))))
  (define extra-imports
    (filter (lambda (import)
              (not (linklet-import? import)))
            (hash-keys source-table)))
  (unless (null? extra-imports)
    (raise-arguments-error who
                           "import sources reference names not imported by the linklet"
                           "name" name
                           "imports" extra-imports
                           "linklet imports" importss))
  grouped)

;; normalize-linklet-import-sources : symbol? symbol? (listof (listof symbol?)) any/c -> (listof (listof source?))
;;   Accept grouped or flat source metadata and return grouped source triples.
(define (normalize-linklet-import-sources who name importss import-sources)
  (cond
    [(null? import-sources) '()]
    [(flat-import-sources? import-sources)
     (flat-import-sources->groups who name importss import-sources)]
    [(grouped-import-sources? import-sources)
     import-sources]
    [else
     (raise-argument-error who
                           "(or/c (listof source-triple?) (listof (listof source-triple?)))"
                           import-sources)]))

;; import-source->mapping : symbol? hash? any/c any/c -> pair?
;;   Resolve one source triple to the explicit import argument expected by a slice.
(define (import-source->mapping who instances source import-abi)
  (define (record-public-import-stat! kind provider-kind)
    (case kind
      [(plain)
       (webify-bridge-stats-inc! 'bridge-import-from-plain-public-value-count)
       (if (eq? provider-kind 'local-user)
           (webify-bridge-stats-inc! 'bridge-import-from-plain-local-value-count)
           (webify-bridge-stats-inc! 'bridge-import-from-plain-provider-value-count))]
      [(cell)
       (webify-bridge-stats-inc! 'bridge-import-from-cell-public-value-count)
       (if (eq? provider-kind 'local-user)
           (webify-bridge-stats-inc! 'bridge-import-from-cell-local-value-count)
           (webify-bridge-stats-inc! 'bridge-import-from-cell-provider-value-count))]))
  (validate-import-source! who source)
  (match-define (list import-name instance-name export-name) source)
  (cons import-name
        (cond
          [(primitive-module-name? instance-name)
           (define cell-export-name
             (compiled-primitive-import-cell-export import-name export-name))
           ;; An explicit override changes the primitive's module-level role,
           ;; so it takes precedence over the direct-value ABI fast path.
           ;; In particular, `print-values` must discard module body results.
           (cond
             [(hash-has-key? (current-composer-primitive-import-cell-overrides)
                             cell-export-name)
              (define override
                (hash-ref (current-composer-primitive-import-cell-overrides)
                          cell-export-name))
              ;; Import-ABI slices receive direct values, whereas the override
              ;; protocol supplies a module-variable cell.
              (if import-abi
                  `(module-variable-ref ,override)
                  override)]
             [import-abi
              (webify-bridge-stats-inc! 'bridge-direct-primitive-import-count)
              cell-export-name]
             [else
              `(let ([cell (module-variable-make ',cell-export-name)])
                 (module-variable-define! cell ,cell-export-name 'constant)
                 cell)])]
          [else
           (define instance
             (hash-ref instances
                       instance-name
                       (lambda ()
                         (raise-arguments-error who
                                                "import source references an unknown instance"
                                                "instance" instance-name
                                                "import" import-name
                                                "available instances" (hash-keys instances)))))
           (if import-abi
               (let ()
                  (webify-bridge-stats-inc! 'bridge-direct-local-ref-count)
                  (define entry
                    (webify-module-instance-export-entry instance export-name))
                  (define provider-kind
                    (webify-module-instance-export-provider-kind instance export-name))
                  (if (webify-module-instance-export-plain-value? instance export-name)
                      (begin
                       (record-public-import-stat! 'plain provider-kind)
                       (webify-module-instance-export-boundary-expression instance export-name))
                     (begin
                       (record-public-import-stat! 'cell provider-kind)
                       (webify-module-instance-export-value-expression instance export-name))))
               (webify-module-instance-export-cell-id instance export-name))])))

;; forced-cell-export-table : (listof analyzed-linklet-slice?) -> hash?
;;   Keep exported cells only for cross-module imports that explicitly need cell ABI.
(define (forced-cell-export-table analyzed-specs)
  (for/fold ([table (hasheq)])
            ([spec (in-list analyzed-specs)])
    (for/fold ([table* table])
              ([group (in-list (analyzed-linklet-slice-import-sources spec))]
               [abi-group (in-list (analyzed-linklet-slice-public-cell-imports-abis spec))])
      (for/fold ([group-table table*])
                ([source (in-list group)]
                 [import-abi (in-list abi-group)])
        (match-define (list _import dependency export) source)
        (if (or import-abi
                (primitive-module-name? dependency)
                (eq? dependency (analyzed-linklet-slice-name spec)))
            group-table
            (hash-update group-table
                         dependency
                         (lambda (exports)
                           (hash-set exports export #t))
                         (hasheq)))))))

;; import-sources->envs : hash? (listof (listof source?)) [(listof (listof any/c))] -> (listof hash?)
;;   Resolve grouped import source triples to grouped explicit-import environments.
(define (import-sources->envs who instances import-sources [imports-abis #f])
  (define imports-abis*
    (or imports-abis
        (for/list ([group (in-list import-sources)])
          (make-list (length group) #f))))
  (unless (list? import-sources)
    (raise-argument-error who "list?" import-sources))
  (unless (valid-imports-abis? imports-abis*)
    (raise-argument-error who "(listof (listof (or/c #f #t 'proc exact-nonnegative-integer?)))" imports-abis))
  (unless (= (length import-sources) (length imports-abis*))
    (raise-arguments-error who
                           "import ABI group count does not match import sources"
                           "import source groups" (length import-sources)
                           "import ABI groups" (length imports-abis*)))
  (for/list ([group     (in-list import-sources)]
             [abi-group (in-list imports-abis*)])
    (unless (list? group)
      (raise-argument-error who "(listof list?)" import-sources))
    (unless (= (length group) (length abi-group))
      (raise-arguments-error who
                             "import ABI count does not match one import group"
                             "import group" group
                             "import ABI group" abi-group))
    (define entries
      (for/list ([source     (in-list group)]
                 [import-abi (in-list abi-group)])
        (import-source->mapping who instances source import-abi)))
    (define duplicate (check-duplicates (map car entries)))
    (when duplicate
      (raise-arguments-error who
                             "duplicate import names are not supported"
                             "import" duplicate))
    (for/hasheq ([entry (in-list entries)])
      (values (car entry) (cdr entry)))))

;; webify-compose-lowered-first-slices : (listof webify-lowered-slice-spec?) [#:tail (listof any/c)] -> values
;;   Adapt lowered slices in order, resolve prior-instance imports, and compose top-level code.
(define (webify-compose-lowered-first-slices specs
                                             #:tail [tail-forms '((void))]
                                             #:define-export-aliases? [define-export-aliases? #t])
  (define who 'webify-compose-lowered-first-slices)
  (unless (list? specs)
    (raise-argument-error who "list?" specs))
  (validate-tail-forms! who tail-forms)
  (define lowered-forced-cell-exports
    (for/fold ([table (hasheq)])
              ([spec (in-list specs)])
      (validate-slice-spec! who spec)
      (for/fold ([table* table])
                ([source (in-list (webify-lowered-slice-spec-import-sources spec))])
        (match-define (list _import dependency export) source)
        (if (or (primitive-module-name? dependency)
                (eq? dependency (webify-lowered-slice-spec-name spec)))
            table*
            (hash-update table*
                         dependency
                         (lambda (exports)
                           (hash-set exports export #t))
                         (hasheq))))))
  (define-values (reverse-fragments instances _reserved)
    (for/fold ([reverse-fragments '()]
               [instances         (hasheq)]
               [reserved          '()])
              ([spec (in-list specs)])
      (validate-slice-spec! who spec)
      (define name (webify-lowered-slice-spec-name spec))
      (when (hash-has-key? instances name)
        (raise-arguments-error who
                               "duplicate module instance names are not supported"
                               "name" name))
      (define importss (webify-lowered-slice-spec-importss spec))
      (define import-sources (webify-lowered-slice-spec-import-sources spec))
      (define exports (webify-lowered-slice-spec-exports spec))
      (define self-instance
        (make-webify-module-instance name
                                     exports
                                     #:reserved reserved
                                     #:expr (webify-lowered-slice-spec-expr spec)
                                     #:module-name name
                                     #:importss importss
                                     #:forced-cell-exports
                                     (hash-ref lowered-forced-cell-exports name (hasheq))))
      (define instances/self
        (hash-set instances name self-instance))
      (when (and (null? importss)
                 (not (null? import-sources)))
        (raise-arguments-error who
                               "import-free slices cannot have import sources"
                               "name" name
                               "import sources" import-sources))
      (define-values (datum instance)
        (if (null? importss)
            (first-slice->module-instance-datum
             name
             (webify-lowered-slice-spec-expr spec)
             exports
             #:reserved reserved
             #:define-export-aliases? define-export-aliases?)
            (first-slice->module-instance-datum/imports
             name
             (webify-lowered-slice-spec-expr spec)
             importss
             (import-sources->envs who instances/self import-sources)
             exports
             #:reserved reserved
             #:instance self-instance
             #:define-export-aliases? define-export-aliases?)))
      (values (cons (webify-module-fragment datum instance) reverse-fragments)
              (hash-set instances name instance)
              (append reserved (webify-module-instance-reserved-ids instance)))))
  (define fragments (reverse reverse-fragments))
  (values (webify-compose-module-fragments fragments #:tail tail-forms)
          fragments
          instances))

;; webify-compose-linklet-first-slices : (listof webify-linklet-slice-spec?) keyword-args ... -> values
;;   Webify linklets in order, resolve prior-instance imports, and compose top-level code.
(define (webify-compose-linklet-first-slices specs
                                             #:tail                  [tail-forms '((void))]
                                             #:define-export-aliases? [define-export-aliases? #t]
                                             #:serializable?-box     serializable?-box
                                             #:datum-intern?         datum-intern?
                                             #:target                target
                                             #:allow-set!-undefined? allow-set!-undefined?
                                             #:unsafe-mode?          unsafe-mode?
                                             #:enforce-constant?     enforce-constant?
                                             #:allow-inline?         allow-inline?
                                             #:no-prompt?            no-prompt?
                                             #:prim-knowns           prim-knowns
                                             #:primitives            primitives
                                             #:compiler-query        compiler-query
                                             #:get-import-knowns     get-import-knowns
                                             #:import-keys           import-keys)
  (define who 'webify-compose-linklet-first-slices)
  (unless (list? specs)
    (raise-argument-error who "list?" specs))
  (validate-tail-forms! who tail-forms)
  (define-values (reverse-analyzed-specs _prior-exports-infos)
    (for/fold ([analyzed '()]
               [prior-exports-infos (hasheq)])
              ([spec (in-list specs)])
       (validate-linklet-slice-spec! who spec)
       (define name (webify-linklet-slice-spec-name spec))
       (define-values (baseline-expr
                       baseline-importss
                       baseline-exports
                       baseline-new-import-keys
                       baseline-imports-abis
                       baseline-exports-info)
         (webify-linklet-first-slice
          (webify-linklet-slice-spec-linklet spec)
          #:serializable?-box     serializable?-box
          #:datum-intern?         datum-intern?
          #:target                target
          #:allow-set!-undefined? allow-set!-undefined?
          #:unsafe-mode?          unsafe-mode?
          #:enforce-constant?     enforce-constant?
          #:allow-inline?         allow-inline?
          #:no-prompt?            no-prompt?
          #:prim-knowns           prim-knowns
          #:primitives            primitives
          #:compiler-query        compiler-query
          #:get-import-knowns     get-import-knowns
          #:import-keys           import-keys))
       (when baseline-new-import-keys
         (error who
                "inlining-added import groups are not supported by the linklet composer yet"))
       (unless (valid-imports-abis? baseline-imports-abis)
         (error who
                "unsupported import ABI metadata in the linklet composer"))
       (define raw-import-sources (webify-linklet-slice-spec-import-sources spec))
       (define import-sources
         (normalize-linklet-import-sources who name baseline-importss raw-import-sources))
       (define diagnostic-group-keys
         (vector->list (import-source-groups->import-keys who import-sources)))
       (define-values (local-import-keys
                       local-prior-known-groups)
         (import-source-groups->abi-only-knowns who
                                                name
                                                import-sources
                                                prior-exports-infos))
       (define use-prior-knowns?
         (positive? (hash-count local-prior-known-groups)))
       (define (compose-get-import-knowns key)
         (define local-knowns
           (and key (hash-ref local-prior-known-groups key #f)))
         (if local-knowns
             (values local-knowns #f #f)
             (get-import-knowns key)))
       (define rerun-failure #f)
       (define rerun-result
         (and use-prior-knowns?
              (parameterize ([current-webify-knowns-mode 'abi-only])
                (with-handlers ([exn:fail?
                                 (lambda (e)
                                   (set! rerun-failure e)
                                   #f)])
                  (call-with-values
                   (lambda ()
                     (webify-linklet-first-slice
                      (webify-linklet-slice-spec-linklet spec)
                      #:serializable?-box     serializable?-box
                      #:datum-intern?         datum-intern?
                      #:target                target
                      #:allow-set!-undefined? allow-set!-undefined?
                      #:unsafe-mode?          unsafe-mode?
                      #:enforce-constant?     enforce-constant?
                      #:allow-inline?         #f
                      #:no-prompt?            no-prompt?
                      #:prim-knowns           prim-knowns
                      #:primitives            primitives
                      #:compiler-query        compiler-query
                      #:get-import-knowns     compose-get-import-knowns
                      #:import-keys           local-import-keys))
                   list)))))
       (define rerun-revised-import-keys
         (and rerun-result (list-ref rerun-result 3)))
       (define rerun-added-import-groups?
         (and rerun-revised-import-keys
              (not (equal? rerun-revised-import-keys local-import-keys))))
       (define rerun-has-app/value?
         (and rerun-result
              (datum-contains-symbol? (list-ref rerun-result 0) '#%app/value)))
       (define rerun-importss-match?
         (and rerun-result
              (equal? (list-ref rerun-result 1) baseline-importss)))
       (define use-rerun-public-cell-abis?
         (and rerun-result
              (not rerun-added-import-groups?)
              rerun-importss-match?))
       (define expr baseline-expr)
       (define importss baseline-importss)
       (define exports baseline-exports)
       ;; Cross-slice knowns are analysis-only here: keep the original lowered
       ;; body, but let a successful rerun refine the import ABI classification
       ;; used by both importer binding and forced-cell export planning.
       (define refined-imports-abis
         (if use-rerun-public-cell-abis?
             (list-ref rerun-result 4)
             baseline-imports-abis))
       (define imports-abis refined-imports-abis)
       (define public-cell-imports-abis refined-imports-abis)
       (define exports-info baseline-exports-info)
       (record-import-abi-metadata! name
                                    import-sources
                                    public-cell-imports-abis
                                    prior-exports-infos
                                    #:baseline-imports-abis baseline-imports-abis
                                    #:group-keys diagnostic-group-keys
                                    #:false-reason
                                    (and use-prior-knowns?
                                         (cond
                                           [rerun-added-import-groups?
                                            'import-group-added-by-inlining]
                                           [rerun-failure
                                            (rerun-failure-reason rerun-failure)]
                                           [(not rerun-importss-match?)
                                            'analysis-shape-changed]
                                           [(and rerun-has-app/value?
                                                 (not use-rerun-public-cell-abis?))
                                            'unsupported-lowered-form]
                                           [else #f])))
       (values (cons (analyzed-linklet-slice
                      name
                      expr
                      importss
                      exports
                      import-sources
                      imports-abis
                      public-cell-imports-abis
                      exports-info)
                     analyzed)
               (hash-set prior-exports-infos name exports-info))))
  (define analyzed-specs
    (reverse reverse-analyzed-specs))
  (define forced-cell-exports
    (forced-cell-export-table analyzed-specs))
  (define-values (reverse-fragments instances _reserved exports-infos)
    (for/fold ([reverse-fragments '()]
               [instances         (hasheq)]
               [reserved          '()]
               [exports-infos     (hasheq)])
              ([spec (in-list analyzed-specs)])
      (define name (analyzed-linklet-slice-name spec))
      (when (hash-has-key? instances name)
        (raise-arguments-error who
                               "duplicate module instance names are not supported"
                               "name" name))
      (define expr (analyzed-linklet-slice-expr spec))
      (define importss (analyzed-linklet-slice-importss spec))
      (define exports (analyzed-linklet-slice-exports spec))
      (define import-sources (analyzed-linklet-slice-import-sources spec))
      (define imports-abis (analyzed-linklet-slice-imports-abis spec))
      (define exports-info (analyzed-linklet-slice-exports-info spec))
      (define self-instance
        (make-webify-module-instance name
                                     exports
                                     #:reserved reserved
                                     #:expr expr
                                     #:module-name name
                                     #:importss importss
                                     #:imports-abis imports-abis
                                     #:forced-cell-exports
                                     (hash-ref forced-cell-exports name (hasheq))))
      (define instances/self
        (hash-set instances name self-instance))
      (when (and (null? importss)
                 (not (null? import-sources)))
        (raise-arguments-error who
                               "import-free linklets cannot have import sources"
                               "name" name
                               "import sources" import-sources))
      (unless (= (length importss) (length import-sources))
        (raise-arguments-error who
                               "import source group count does not match linklet imports"
                               "name" name
                               "expected count" (length importss)
                               "actual count" (length import-sources)
                               "imports" importss))
      (define-values (datum instance)
        (with-handlers ([exn:fail?
                         (lambda (e)
                           (raise-arguments-error
                            who
                            "failed while adapting one analyzed linklet slice"
                            "name" name
                            "imports" importss
                            "import ABI metadata" imports-abis
                            "message" (exn-message e)))])
          (if (null? importss)
              (first-slice->module-instance-datum
               name
               expr
               exports
               #:reserved reserved
               #:define-export-aliases? define-export-aliases?)
              (first-slice->module-instance-datum/imports
               name
               expr
               importss
               (import-sources->envs who instances/self import-sources imports-abis)
               exports
               #:reserved reserved
               #:instance self-instance
               #:imports-abis imports-abis
               #:define-export-aliases? define-export-aliases?))))
      (values (cons (webify-module-fragment datum instance) reverse-fragments)
              (hash-set instances name instance)
              (append reserved (webify-module-instance-reserved-ids instance))
              (hash-set exports-infos name exports-info))))
  (define fragments (reverse reverse-fragments))
  (values (webify-compose-module-fragments fragments #:tail tail-forms)
          fragments
          instances
          exports-infos))
