#lang racket/base

(provide strip-correlated
         (struct-out bridge-export-entry)
         (struct-out first-slice-export-plan)
         bridge-export-entry-cell-backed?
         bridge-export-entry-plain-value?
         bridge-export-entry-ref-expression
         bridge-export-entry-boundary-expression
         default-export-entry-map
         first-slice-import-args
         first-slice-import-cell-args
         build-first-slice-export-plan
         first-slice-top-level-helper-ids
         first-slice-top-level-export-cell-ids
         first-slice-top-level-export-value-ids
         first-slice->top-level-datum
         first-slice->top-level-datum/imports
         first-slice->top-level-syntax
         webify-linklet-first-slice-top-level/imports
         webify-linklet-first-slice-top-level)

(require racket/list
         racket/match
         "../private/parameters.rkt"
         "bridge-stats.rkt"
         "first-slice.rkt"
         "wrap.rkt")

(struct bridge-export-entry (name kind binding metadata) #:transparent)
(struct first-slice-export-plan (adapted-expr helper-ids cell-ids value-id-map value-ids export-args candidate-specs entry-map)
  #:transparent)

;; bridge-export-entry-cell-backed? : bridge-export-entry? -> boolean?
;;   Check whether entry exposes a module-variable cell at the public boundary.
(define (bridge-export-entry-cell-backed? entry)
  (eq? (bridge-export-entry-kind entry) 'cell))

;; bridge-export-entry-plain-value? : bridge-export-entry? -> boolean?
;;   Check whether entry exposes a plain lexical value at the public boundary.
(define (bridge-export-entry-plain-value? entry)
  (eq? (bridge-export-entry-kind entry) 'value))

;; bridge-export-entry-ref-expression : bridge-export-entry? -> any/c
;;   Read one export through the mixed boundary ABI.
(define (bridge-export-entry-ref-expression entry)
  (if (bridge-export-entry-cell-backed? entry)
      `(module-variable-ref/no-check ,(bridge-export-entry-binding entry))
      (bridge-export-entry-binding entry)))

;; bridge-export-entry-boundary-expression : bridge-export-entry? -> any/c
;;   Return the boundary binding passed to downstream importers.
(define (bridge-export-entry-boundary-expression entry)
  (bridge-export-entry-binding entry))

;; module-provider-kind : (or/c symbol? #f) -> symbol?
;;   Classify one module name using the active bridge graph, if available.
(define (module-provider-kind module-name)
  (define module-kinds
    (current-module-bridge-module-kinds))
  (cond
    [(not (symbol? module-name)) 'unknown-provider]
    [(and module-kinds
          (hash-has-key? module-kinds module-name))
     (hash-ref module-kinds module-name)]
    [else 'unknown-provider]))

;; quote-like-form? : any/c -> boolean?
;;   Recognize datum forms that should not count as executable bridge code.
(define (quote-like-form? v)
  (match v
    [`(,(or 'quote 'quote-syntax 'syntax 'quasiquote) . ,_) #t]
    [_ #f]))

;; strip-quote : any/c -> any/c
;;   Decode one quoted datum layer when bridge metadata stores literal symbols.
(define (strip-quote v)
  (match v
    [`(quote ,inner) inner]
    [_ v]))

;; export-arg-metadata-list : any/c (listof symbol?) (listof symbol?) (or/c symbol? #f) any/c -> (listof hash?)
;;   Build conservative metadata rows for each public export argument.
(define (export-arg-metadata-list expr exports export-args module-name importss)
  (define usage (lowered-export-usage-summary expr export-args))
  (define mutated (hash-ref usage 'mutated))
  (define undefined-sensitive (hash-ref usage 'undefined-sensitive))
  (define reflection-visible (hash-ref usage 'reflection-visible))
  (define define-constances (hash-ref usage 'define-constances))
  (define imported-names
    (if importss
        (flatten-groups importss)
        '()))
  (for/list ([export (in-list exports)]
             [export-arg (in-list export-args)])
    (define reexport?
      (memq export imported-names))
    (define constance
      (hash-ref define-constances export-arg #f))
    (hasheq 'module-name module-name
            'export export
            'public-boundary? #t
            'internal? #f
            'immutable? (and constance #t)
            'constance constance
            'reexport? (and reexport? #t)
            'mutated? (and (hash-ref mutated export-arg #f) #t)
            'undefined-sensitive? (and (hash-ref undefined-sensitive export-arg #f) #t)
            'reflection-visible? (and (hash-ref reflection-visible export-arg #f) #t)
            'phase0-value-space-only? #t
            'dynamic-require-sensitive? #f)))

;; plain-value-export-base-candidate? : hash? -> boolean?
;;   Check the conservative safety preconditions for eliding one public export cell.
(define (plain-value-export-base-candidate? meta)
  (define module-name (hash-ref meta 'module-name #f))
  (and module-name
       (symbol? module-name)
       (hash-ref meta 'public-boundary? #f)
       (hash-ref meta 'immutable? #f)
       (not (hash-ref meta 'reexport? #f))
       (not (hash-ref meta 'mutated? #f))
       (not (hash-ref meta 'undefined-sensitive? #f))
       (not (hash-ref meta 'reflection-visible? #f))
       (not (hash-ref meta 'dynamic-require-sensitive? #f))
       (hash-ref meta 'phase0-value-space-only? #f)))

;; plain-value-export-policy-eligible? : hash? -> boolean?
;;   Check whether the current public-cell elision policy allows this module.
(define (plain-value-export-policy-eligible? meta)
  (define module-name (hash-ref meta 'module-name #f))
  (define allowed-modules
    (current-module-bridge-elidable-module-names))
  (define provider-kind
    (hash-ref meta 'provider-kind (module-provider-kind module-name)))
  (and module-name
       (symbol? module-name)
       (or (memq provider-kind '(local-user support-provider))
           (and allowed-modules
                (memq module-name allowed-modules)))))

;; plain-value-export-candidate? : hash? -> boolean?
;;   Check whether one public export satisfies both safety and policy checks.
(define (plain-value-export-candidate? meta)
  (and (plain-value-export-base-candidate? meta)
       (plain-value-export-policy-eligible? meta)))

;; export-entry-kind : hash? hash? -> symbol?
;;   Decide whether one public export should stay cell-backed or become a plain value.
(define (export-entry-kind meta forced-cell-exports)
  (define export (hash-ref meta 'export #f))
  (if (and (current-module-bridge-elide-public-cells?)
           export
           (not (hash-ref forced-cell-exports export #f))
           (plain-value-export-candidate? meta))
      'value
      'cell))

;; default-export-entry-map : (listof symbol?) hash? hash? -> hasheq?
;;   Build the legacy all-cell export-entry map when no expression analysis is available.
(define (default-export-entry-map exports cell-id-map value-id-map)
  (for/hasheq ([export (in-list exports)])
    (define cell-id (hash-ref cell-id-map export))
    (define value-id (hash-ref value-id-map export))
    (values export
            (bridge-export-entry
             export
             'cell
             cell-id
             (hasheq 'cell-id cell-id
                     'value-id value-id)))))

;; lowered-export-usage-summary : any/c (listof symbol?) -> hasheq?
;;   Collect conservative per-export usage flags from one lowered first slice.
(define (lowered-export-usage-summary expr export-args)
  (define export-set
    (for/hasheq ([arg (in-list export-args)])
      (values arg #t)))
  (define mutated (make-hasheq))
  (define undefined-sensitive (make-hasheq))
  (define reflection-visible (make-hasheq))
  (define define-constances (make-hasheq))
  (define defined (make-hasheq))
  (define (record! table id)
    (when (hash-ref export-set id #f)
      (hash-set! table id #t)))
  (define (walk v)
    (cond
      [(pair? v)
       (unless (quote-like-form? v)
         (match v
           [`(,(or 'variable-set! 'variable-set!/check-undefined) ,cell ,rhs)
            (record! mutated cell)
            (when (eq? (car v) 'variable-set!/check-undefined)
              (record! undefined-sensitive cell))
            (walk rhs)]
           [`(module-variable-set! ,cell ,rhs)
            (record! mutated cell)
            (walk rhs)]
           [`(module-variable-set!/check-undefined! ,cell ,rhs)
            (record! mutated cell)
            (record! undefined-sensitive cell)
            (walk rhs)]
           [`(variable-set!/define ,cell ,rhs ,_constance)
            (walk rhs)
            (when (hash-ref export-set cell #f)
              (hash-set! define-constances cell (strip-quote _constance)))
            (hash-set! defined cell #t)]
           [`(module-variable-define! ,cell ,rhs ,_constance)
            (walk rhs)
            (when (hash-ref export-set cell #f)
              (hash-set! define-constances cell (strip-quote _constance)))
            (hash-set! defined cell #t)]
           [`(,(or 'variable-ref 'variable-ref/no-check) ,cell)
            (unless (hash-ref defined cell #f)
              (record! undefined-sensitive cell))]
           [`(,(or 'module-variable-ref 'module-variable-ref/no-check) ,cell)
            (unless (hash-ref defined cell #f)
              (record! undefined-sensitive cell))]
           [`(module-variable-reference ,instance ,cell)
            (walk instance)
            (record! reflection-visible cell)]
           [`(begin ,es ...)
            (for ([e (in-list es)])
              (walk e))]
           [`(,head . ,rest)
            (walk head)
            (walk rest)]
           [_ (void)]))]
      [(vector? v)
       (for ([entry (in-vector v)])
         (walk entry))]
      [else
       (void)]))
  (walk expr)
  (hasheq 'mutated mutated
          'undefined-sensitive undefined-sensitive
          'reflection-visible reflection-visible
          'define-constances define-constances))

;; record-export-cell-stats! : any/c (listof symbol?) (listof symbol?) (or/c symbol? #f) -> void?
;;   Publish conservative export-cell metadata for dry-run bridge analysis.
(define (record-export-cell-stats! expr
                                   exports
                                   export-args
                                   module-name
                                   importss
                                   #:export-entries [export-entries #f])
  (define metas
    (if export-entries
        (for/list ([export (in-list exports)])
          (bridge-export-entry-metadata
           (hash-ref export-entries export)))
        (export-arg-metadata-list expr exports export-args module-name importss)))
  (for ([meta (in-list metas)])
    (define export (hash-ref meta 'export))
    (webify-bridge-stats-set! (list 'bridge-export-cell-meta module-name export) meta)
    (when module-name
      (webify-bridge-stats-inc! (list 'bridge-export-cell-module module-name)))
    (webify-bridge-stats-inc! (list 'bridge-export-cell-name export)))
  (webify-bridge-stats-inc! 'bridge-export-cell-public-boundary-count (length exports))
  (webify-bridge-stats-inc! 'bridge-export-cell-reexport-count
                            (for/sum ([meta (in-list metas)])
                              (if (hash-ref meta 'reexport? #f) 1 0)))
  (webify-bridge-stats-inc! 'bridge-export-cell-mutated-count
                            (for/sum ([meta (in-list metas)])
                              (if (hash-ref meta 'mutated? #f) 1 0)))
  (webify-bridge-stats-inc! 'bridge-export-cell-undefined-sensitive-count
                            (for/sum ([meta (in-list metas)])
                              (if (hash-ref meta 'undefined-sensitive? #f) 1 0)))
  (webify-bridge-stats-inc! 'bridge-export-cell-reflection-visible-count
                            (for/sum ([meta (in-list metas)])
                              (if (hash-ref meta 'reflection-visible? #f) 1 0))))

;; late-materializable-export-specs : any/c (listof symbol?) (listof symbol?) (listof symbol?) any/c -> (listof vector?)
;;   Identify exports that can use lexical values internally before cell materialization.
(define (late-materializable-export-specs expr exports export-args value-ids importss)
  (define usage (lowered-export-usage-summary expr export-args))
  (define mutated (hash-ref usage 'mutated))
  (define undefined-sensitive (hash-ref usage 'undefined-sensitive))
  (define reflection-visible (hash-ref usage 'reflection-visible))
  (define define-constances (hash-ref usage 'define-constances))
  (define imported-names
    (if importss
        (flatten-groups importss)
        '()))
  (for/list ([export (in-list exports)]
             [export-arg (in-list export-args)]
             [value-id (in-list value-ids)]
             #:unless (or (hash-ref mutated export-arg #f)
                          (hash-ref undefined-sensitive export-arg #f)
                          (hash-ref reflection-visible export-arg #f)
                          (not (hash-has-key? define-constances export-arg))))
    (vector export export-arg value-id (hash-ref define-constances export-arg) (memq export imported-names))))

;; rewrite-late-materialized-export : any/c hasheq? -> any/c
;;   Replace candidate export-cell references with lexical value bindings.
(define (rewrite-late-materialized-export v candidate-map)
  (define (rewrite-list xs)
    (map (lambda (entry) (rewrite-late-materialized-export entry candidate-map)) xs))
  (cond
    [(pair? v)
     (if (quote-like-form? v)
         v
         (match v
           [`(variable-set!/define ,cell ,rhs ,_constance)
            (define candidate (hash-ref candidate-map cell #f))
            (if candidate
                `(define ,candidate ,(rewrite-late-materialized-export rhs candidate-map))
                `(variable-set!/define
                  ,cell
                  ,(rewrite-late-materialized-export rhs candidate-map)
                  ,_constance))]
           [`(variable-ref ,cell)
            (or (hash-ref candidate-map cell #f) v)]
           [`(variable-ref/no-check ,cell)
            (or (hash-ref candidate-map cell #f) v)]
           [`(module-variable-ref ,cell)
            (or (hash-ref candidate-map cell #f) v)]
           [`(module-variable-ref/no-check ,cell)
            (or (hash-ref candidate-map cell #f) v)]
           [`(,head . ,rest)
            (cons (rewrite-late-materialized-export head candidate-map)
                  (rewrite-late-materialized-export rest candidate-map))]
           [_ v]))]
    [(vector? v)
     (list->vector (rewrite-list (vector->list v)))]
    [else
     v]))

;; late-materialized-body-forms : (listof any/c) hasheq? -> (listof any/c)
;;   Rewrite the top-level slice body while hoisting candidate export definitions.
(define (late-materialized-body-forms body candidate-map)
  (apply
   append
   (for/list ([form (in-list body)])
     (match form
       [`(define ,id
           (begin
             (module-variable-define! ,cell ,rhs ,_constance)
             (void)))
        (define candidate (hash-ref candidate-map cell #f))
        (if candidate
            (list `(define ,candidate
                     ,(rewrite-late-materialized-export rhs candidate-map)))
            (list `(define ,id
                     (begin
                       (module-variable-define!
                        ,cell
                        ,(rewrite-late-materialized-export rhs candidate-map)
                        ,_constance)
                       (void)))))]
       [`(define ,id (,(or 'module-variable-ref 'module-variable-ref/no-check) ,cell))
        (define candidate (hash-ref candidate-map cell #f))
        (list (if candidate
                  `(define ,id ,candidate)
                  form))]
       [_ (list (rewrite-late-materialized-export form candidate-map))]))))

;; late-materialize-exports : any/c (listof vector?) -> any/c
;;   Make candidate exports lexical inside the slice and return their values.
(define (late-materialize-exports expr candidate-specs)
  (if (null? candidate-specs)
      expr
      (match expr
        [`(lambda ,args ,body ...)
         (define candidate-map
           (for/hasheq ([spec (in-list candidate-specs)])
             (values (vector-ref spec 1)
                     (vector-ref spec 2))))
         `(lambda ,args
            ,@(late-materialized-body-forms body candidate-map)
            (values ,@(for/list ([spec (in-list candidate-specs)])
                        (vector-ref spec 2))))]
        [_ expr])))

;; strip-correlated : any/c -> any/c
;;   Remove correlated wrappers so compiler terms can become source datums.
(define (strip-correlated v)
  (let ([v (unwrap v)])
    (cond
      [(pair? v)   (cons (strip-correlated (car v))
                         (strip-correlated (cdr v)))]
      [(vector? v) (list->vector (map strip-correlated (vector->list v)))]
      [else        v])))

;; validate-top-level-exports! : symbol? any/c -> void?
;;   Reject export lists the current top-level adapter cannot represent safely.
(define (validate-top-level-exports! who exports)
  (unless (and (list? exports)
               (andmap symbol? exports))
    (raise-argument-error who "(listof symbol?)" exports))
  (define duplicate (check-duplicates exports))
  (when duplicate
    (raise-arguments-error who
                           "duplicate exports are not supported by the top-level adapter"
                           "export" duplicate)))

;; validate-first-slice-lambda! : symbol? any/c exact-nonnegative-integer? (listof symbol?) -> void?
;;   Reject lowered values that cannot be invoked with instance plus export cells.
(define (validate-first-slice-lambda! who expr import-count exports)
  (match expr
    [`(lambda ,args ,_body ...)
     (unless (list? args)
       (raise-arguments-error who
                              "expected lowered first-slice lambda to have fixed arity"
                              "form" expr))
     (unless (andmap symbol? args)
       (raise-arguments-error who
                              "expected lowered first-slice lambda formals to be symbols"
                              "formals" args))
     (define duplicate-arg (check-duplicates args))
     (when duplicate-arg
       (raise-arguments-error who
                              "duplicate lowered first-slice lambda formals are not supported"
                              "formal" duplicate-arg))
     (define expected-arity (+ 1 import-count (length exports)))
     (define actual-arity   (length args))
     (unless (= actual-arity expected-arity)
       (raise-arguments-error who
                              "lowered first-slice lambda arity does not match imports and exports"
                              "expected arity" expected-arity
                              "actual arity" actual-arity
                              "import count" import-count
                              "exports" exports))]
    [_
     (raise-arguments-error who
                            "expected lowered first-slice value to be a lambda"
                            "form" expr)]))

;; validate-importss! : symbol? any/c -> void?
;;   Reject grouped import names that cannot become lexical bindings.
(define (validate-importss! who importss)
  (unless (and (list? importss)
               (for/and ([group (in-list importss)])
                 (and (list? group)
                      (andmap symbol? group))))
    (raise-argument-error who "(listof (listof symbol?))" importss))
  (define duplicate (check-duplicates (flatten-groups importss)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate import names are not supported"
                           "import" duplicate)))

;; validate-imports-abis! : symbol? any/c (listof (listof symbol?)) -> void?
;;   Reject import ABI metadata that does not match grouped import names.
(define (validate-imports-abis! who imports-abis importss)
  (define valid?
    (and (list? imports-abis)
         (= (length imports-abis) (length importss))
         (for/and ([group      (in-list imports-abis)]
                   [name-group (in-list importss)])
           (and (list? group)
                (= (length group) (length name-group))))))
  (unless valid?
    (raise-arguments-error who
                           "import ABI metadata does not match grouped imports"
                           "imports-abis" imports-abis
                           "imports" importss)))

;; default-imports-abis : (listof (listof symbol?)) -> (listof (listof #f))
;;   Treat every import as a cell-backed binding when no ABI metadata is present.
(define (default-imports-abis importss)
  (for/list ([group (in-list importss)])
    (for/list ([name (in-list group)])
      #f)))

;; bind-imports : any/c (listof (listof symbol?)) any/c exact-nonnegative-integer? -> any/c
;;   Introduce lexical imports from either direct values or module-variable cells.
(define (bind-imports expr importss imports-abis import-count)
  (validate-importss! 'bind-imports importss)
  (validate-imports-abis! 'bind-imports imports-abis importss)
  (define import-names (flatten-groups importss))
  (define import-abis  (flatten-groups imports-abis))
  (define direct-import-count
    (for/sum ([abi (in-list import-abis)])
      (if abi 1 0)))
  (define cell-import-count
    (- (length import-abis) direct-import-count))
  (webify-bridge-stats-inc! 'bridge-direct-import-count direct-import-count)
  (webify-bridge-stats-inc! 'bridge-import-cell-count cell-import-count)
  (webify-bridge-stats-inc! 'bridge-cell-elision-count direct-import-count)
  (unless (= (length import-names) import-count)
    (raise-arguments-error 'bind-imports
                           "import metadata count does not match lowered lambda"
                           "metadata count" (length import-names)
                           "lambda import count" import-count
                           "imports" importss))
  (match expr
    [`(lambda ,args ,body ...)
     (define import-args (take (cdr args) import-count))
     (define duplicate (check-duplicates (append import-names args)))
     (when duplicate
       (raise-arguments-error 'bind-imports
                              "import name collides with generated lambda argument"
                              "name" duplicate))
     `(lambda ,args
        ,@(for/list ([name (in-list import-names)]
                     [arg  (in-list import-args)]
                     [abi  (in-list import-abis)])
            `(define ,name ,(if abi
                                arg
                                `(module-variable-ref ,arg))))
        ,@body)]
    [_
     (raise-arguments-error 'bind-imports
                            "expected lowered first-slice value to be a lambda"
                            "form" expr)]))

;; fresh-internal-id : symbol? (listof symbol?) -> symbol?
;;   Build a deterministic helper name that does not collide with exports.
(define (fresh-internal-id base reserved)
  (let loop ([n 0])
    (define candidate
      (string->symbol (format "~a$~a" base n)))
    (if (memq candidate reserved)
        (loop (add1 n))
        candidate)))

;; generated-linklet-proc-id : (listof symbol?) -> symbol?
;;   Build an internal binding name for the lowered linklet procedure.
(define (generated-linklet-proc-id reserved)
  (fresh-internal-id 'webify-linklet-proc reserved))

;; generated-cell-id : exact-nonnegative-integer? (listof symbol?) -> symbol?
;;   Build an internal cell binding name for an export argument.
(define (generated-cell-id index reserved)
  (fresh-internal-id (string->symbol (format "webify-export-cell~a" index))
                     reserved))

;; generated-value-id : exact-nonnegative-integer? (listof symbol?) -> symbol?
;;   Build an internal lexical binding name for one exported value.
(define (generated-value-id index reserved)
  (fresh-internal-id (string->symbol (format "webify-export-value~a" index))
                     reserved))

;; validate-reserved-ids! : symbol? any/c -> void?
;;   Reject reserved-name lists that cannot be used for deterministic avoidance.
(define (validate-reserved-ids! who reserved)
  (unless (and (list? reserved)
               (andmap symbol? reserved))
    (raise-argument-error who "(listof symbol?)" reserved)))

;; flatten-groups : (listof list?) -> list?
;;   Flatten grouped import metadata while preserving group order.
(define (flatten-groups groups)
  (apply append groups))

;; first-slice-import-args : (listof (listof symbol?)) (listof hash?) -> (listof any/c)
;;   Resolve grouped import metadata to the flat explicit-import argument order.
(define (first-slice-import-args importss import-envs)
  (define who 'first-slice-import-args)
  (unless (and (list? importss)
               (for/and ([group (in-list importss)])
                 (and (list? group)
                      (andmap symbol? group))))
    (raise-argument-error who "(listof (listof symbol?))" importss))
  (unless (and (list? import-envs)
               (andmap hash? import-envs))
    (raise-argument-error who "(listof hash?)" import-envs))
  (unless (= (length importss) (length import-envs))
    (raise-arguments-error who
                           "import argument environment count does not match import groups"
                           "expected count" (length importss)
                           "actual count" (length import-envs)
                           "imports" importss))
  (apply
   append
   (for/list ([imports (in-list importss)]
              [env     (in-list import-envs)])
     (for/list ([import (in-list imports)])
       (hash-ref env
                 import
                 (lambda ()
                   (raise-arguments-error who
                                          "missing import argument"
                                          "import" import
                                          "available imports" (hash-keys env))))))))

;; first-slice-import-cell-args : (listof (listof symbol?)) (listof hash?) -> (listof any/c)
;;   Backward-compatible alias for explicit import argument resolution.
(define first-slice-import-cell-args
  first-slice-import-args)

;; first-slice-top-level-helper-ids : (listof symbol?) [#:reserved (listof symbol?)] -> (listof symbol?)
;;   Return the internal helper ids that the adapter would reserve for exports.
(define (first-slice-top-level-helper-ids exports #:reserved [reserved '()])
  (define who 'first-slice-top-level-helper-ids)
  (validate-top-level-exports! who exports)
  (validate-reserved-ids! who reserved)
  (define reserved* (append exports reserved))
  (define proc-id (generated-linklet-proc-id reserved*))
  (define cell-ids
    (for/list ([_export (in-list exports)]
               [index   (in-naturals)])
      (generated-cell-id index (append (list proc-id) reserved*))))
  (cons proc-id cell-ids))

;; first-slice-top-level-export-cell-ids : (listof symbol?) [#:reserved (listof symbol?)] -> hasheq?
;;   Map export names to the internal cell ids that the adapter would create.
(define (first-slice-top-level-export-cell-ids exports #:reserved [reserved '()])
  (define cell-ids (cdr (first-slice-top-level-helper-ids exports #:reserved reserved)))
  (for/hasheq ([export  (in-list exports)]
               [cell-id (in-list cell-ids)])
    (values export cell-id)))

;; first-slice-top-level-export-value-ids : (listof symbol?) [#:reserved (listof symbol?)] -> hasheq?
;;   Map export names to internal lexical bindings that cache exported values.
(define (first-slice-top-level-export-value-ids exports #:reserved [reserved '()])
  (define helper-ids (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define reserved* (append exports reserved helper-ids))
  (define value-ids
    (for/list ([_export (in-list exports)]
               [index   (in-naturals)])
      (generated-value-id index reserved*)))
  (for/hasheq ([export   (in-list exports)]
               [value-id (in-list value-ids)])
    (values export value-id)))

;; build-first-slice-export-plan : any/c (listof symbol?) keyword-args -> first-slice-export-plan?
;;   Analyze one lowered first slice and compute the mixed public export plan.
(define (build-first-slice-export-plan expr
                                       exports
                                       #:import-count [import-count 0]
                                       #:reserved [reserved '()]
                                       #:module-name [module-name #f]
                                       #:importss [importss #f]
                                       #:imports-abis [imports-abis #f]
                                       #:forced-cell-exports [forced-cell-exports (hasheq)])
  (validate-top-level-exports! 'build-first-slice-export-plan exports)
  (validate-reserved-ids! 'build-first-slice-export-plan reserved)
  (unless (exact-nonnegative-integer? import-count)
    (raise-argument-error 'build-first-slice-export-plan "exact-nonnegative-integer?" import-count))
  (unless (hash? forced-cell-exports)
    (raise-argument-error 'build-first-slice-export-plan "hash?" forced-cell-exports))
  (define clean-expr (strip-correlated expr))
  (validate-first-slice-lambda! 'build-first-slice-export-plan clean-expr import-count exports)
  (define adapted-expr
    (if importss
        (bind-imports clean-expr
                      importss
                      (or imports-abis
                          (default-imports-abis importss))
                      import-count)
        clean-expr))
  (define helper-ids (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define cell-id-map (first-slice-top-level-export-cell-ids exports #:reserved reserved))
  (define value-id-map (first-slice-top-level-export-value-ids exports #:reserved reserved))
  (define value-ids
    (for/list ([export (in-list exports)])
      (hash-ref value-id-map export)))
  (define export-args
    (match adapted-expr
      [`(lambda ,args ,_body ...)
       (take-right args (length exports))]))
  (define candidate-specs
    (late-materializable-export-specs adapted-expr
                                      exports
                                      export-args
                                      value-ids
                                      importss))
  (define metas
    (export-arg-metadata-list adapted-expr exports export-args module-name importss))
  (define entry-map
    (for/hasheq ([export (in-list exports)]
                 [meta (in-list metas)])
      (define cell-id (hash-ref cell-id-map export))
      (define value-id (hash-ref value-id-map export))
      (define selected-kind
        (export-entry-kind meta forced-cell-exports))
      (define enriched-meta
        (hash-set* meta
                   'cell-id cell-id
                   'value-id value-id
                   'provider-kind (module-provider-kind module-name)
                   'plain-value-base-candidate? (plain-value-export-base-candidate? meta)
                   'plain-value-policy-eligible? (plain-value-export-policy-eligible? meta)
                   'forced-cell? (and export
                                      (hash-ref forced-cell-exports export #f)
                                      #t)
                   'selected-export-kind selected-kind))
      (values export
              (bridge-export-entry
               export
               selected-kind
               (if (eq? selected-kind 'value)
                   value-id
                   cell-id)
               enriched-meta))))
  (first-slice-export-plan adapted-expr
                           helper-ids
                           (cdr helper-ids)
                           value-id-map
                           value-ids
                           export-args
                           candidate-specs
                           entry-map))

;; export-alias-enabled? : any/c symbol? -> boolean?
;;   Decide whether to define a top-level alias for an exported cell.
(define (export-alias-enabled? mode export)
  (cond
    [(procedure? mode) (and (mode export) #t)]
    [else             (and mode #t)]))

;; first-slice->top-level-datum : any/c (listof symbol?) -> any/c
;;   Wrap a lowered import-free first-slice lambda in top-level forms.
(define (first-slice->top-level-datum expr
                                      exports
                                      #:reserved [reserved '()]
                                      #:module-name [module-name #f]
                                      #:export-entries [export-entries #f]
                                      #:define-export-aliases? [define-export-aliases? #t])
  (first-slice->top-level-datum/imports
   expr
   '()
   exports
   #:reserved reserved
   #:module-name module-name
   #:export-entries export-entries
   #:define-export-aliases? define-export-aliases?))

;; first-slice->top-level-datum/imports : any/c (listof any/c) (listof symbol?) -> any/c
;;   Wrap a lowered first-slice lambda with explicit import argument expressions.
(define (first-slice->top-level-datum/imports expr
                                             import-args
                                             exports
                                             #:reserved [reserved '()]
                                             #:module-name [module-name #f]
                                             #:importss [importss #f]
                                             #:imports-abis [imports-abis #f]
                                             #:export-entries [export-entries #f]
                                             #:define-export-aliases? [define-export-aliases? #t])
  (unless (list? import-args)
    (raise-argument-error 'first-slice->top-level-datum/imports "list?" import-args))
  (define plan
    (build-first-slice-export-plan expr
                                   exports
                                   #:import-count (length import-args)
                                   #:reserved reserved
                                   #:module-name module-name
                                   #:importss importss
                                   #:imports-abis imports-abis))
  (define adapted-expr
    (first-slice-export-plan-adapted-expr plan))
  (define helper-ids
    (first-slice-export-plan-helper-ids plan))
  (define proc-id (car helper-ids))
  (define cell-ids
    (first-slice-export-plan-cell-ids plan))
  (define value-id-map
    (first-slice-export-plan-value-id-map plan))
  (define value-ids
    (first-slice-export-plan-value-ids plan))
  (define export-args
    (first-slice-export-plan-export-args plan))
  (define candidate-specs
    (first-slice-export-plan-candidate-specs plan))
  (define chosen-export-entries
    (or export-entries
        (first-slice-export-plan-entry-map plan)))
  (define candidate-export-args
    (for/list ([spec (in-list candidate-specs)])
      (vector-ref spec 1)))
  (define candidate-value-ids
    (for/list ([spec (in-list candidate-specs)])
      (vector-ref spec 2)))
  (define candidate-constances
    (for/list ([spec (in-list candidate-specs)])
      (vector-ref spec 3)))
  (define candidate-arg-set
    (for/hasheq ([arg (in-list candidate-export-args)])
      (values arg #t)))
  (define late-adapted-expr
    (late-materialize-exports adapted-expr candidate-specs))
  (define cell-backed-exports
    (for/list ([export (in-list exports)]
               #:when (bridge-export-entry-cell-backed?
                       (hash-ref chosen-export-entries export)))
      export))
  (define value-backed-exports
    (for/list ([export (in-list exports)]
               #:when (bridge-export-entry-plain-value?
                       (hash-ref chosen-export-entries export)))
      export))
  (webify-bridge-stats-inc! 'bridge-export-cell-count (length cell-backed-exports))
  (webify-bridge-stats-inc! 'bridge-module-variable-make-count (length cell-backed-exports))
  (webify-bridge-stats-inc! 'bridge-export-cell-late-materialization-candidate-count
                            (length candidate-specs))
  (webify-bridge-stats-inc! 'bridge-public-cell-elided-count (length value-backed-exports))
  (webify-bridge-stats-inc! 'bridge-public-cell-kept-count (length cell-backed-exports))
  (when (current-module-bridge-elide-public-cells?)
    (for ([export (in-list exports)])
      (define entry (hash-ref chosen-export-entries export))
      (when (bridge-export-entry-cell-backed? entry)
        (define meta (bridge-export-entry-metadata entry))
        (define required?
          (or (not (plain-value-export-candidate? meta))
              (bridge-export-entry-plain-value?
               (hash-ref (first-slice-export-plan-entry-map plan) export))))
        (when required?
          (webify-bridge-stats-inc! 'bridge-public-cell-kept-required-count))
        (cond
          [(hash-ref meta 'reflection-visible? #f)
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-reflection-count)]
          [(hash-ref meta 'dynamic-require-sensitive? #f)
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-dynamic-require-count)]
          [(or (not (hash-ref meta 'immutable? #f))
               (hash-ref meta 'mutated? #f))
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-mutation-count)]
          [(hash-ref meta 'undefined-sensitive? #f)
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-undefined-count)]
          [(hash-ref meta 'reexport? #f)
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-reexport-count)]
          [(not (hash-ref meta 'phase0-value-space-only? #f))
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-phase-space-count)]
          [(plain-value-export-candidate? meta)
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-unknown-count)]
          [else
           (webify-bridge-stats-inc! 'bridge-public-cell-kept-unknown-count)]))))
  (record-export-cell-stats! adapted-expr
                            exports
                            export-args
                            module-name
                            importss
                            #:export-entries chosen-export-entries)
  `(begin
     (define ,proc-id ,late-adapted-expr)
     ,@(for/list ([export     (in-list exports)]
                  [export-arg (in-list export-args)]
                  #:when (and (bridge-export-entry-cell-backed?
                               (hash-ref chosen-export-entries export))
                              (not (hash-ref candidate-arg-set export-arg #f))))
         (define entry (hash-ref chosen-export-entries export))
         (define cell-id (bridge-export-entry-binding entry))
         `(define ,cell-id (module-variable-make ',export)))
     ,(if (null? candidate-value-ids)
          `(,proc-id (#%variable-reference)
                     ,@import-args
                     ,@(for/list ([export     (in-list exports)]
                                  [export-arg (in-list export-args)])
                         (define entry (hash-ref chosen-export-entries export))
                         (if (hash-ref candidate-arg-set export-arg #f)
                             '(void)
                             (bridge-export-entry-binding entry))))
          `(define-values ,candidate-value-ids
             (,proc-id (#%variable-reference)
                       ,@import-args
                       ,@(for/list ([export     (in-list exports)]
                                    [export-arg (in-list export-args)])
                           (define entry (hash-ref chosen-export-entries export))
                           (if (hash-ref candidate-arg-set export-arg #f)
                               '(void)
                               (bridge-export-entry-binding entry))))))
     ,@(for/list ([spec (in-list candidate-specs)])
         (define export (vector-ref spec 0))
         (define value-id (vector-ref spec 2))
         (define constance (vector-ref spec 3))
         (define entry (hash-ref chosen-export-entries export))
         (and (bridge-export-entry-cell-backed? entry)
              `(begin
                 (define ,(bridge-export-entry-binding entry) (module-variable-make ',export))
                 (module-variable-define! ,(bridge-export-entry-binding entry) ,value-id ',constance))))
     ,@(filter values
               (for/list ([export (in-list exports)]
                          [value-id  (in-list value-ids)]
                          [export-arg (in-list export-args)]
                          #:unless (hash-ref candidate-arg-set export-arg #f))
                 (define entry (hash-ref chosen-export-entries export))
                 (and (bridge-export-entry-cell-backed? entry)
                      `(define ,value-id (module-variable-ref ,(bridge-export-entry-binding entry))))))
     ,@(for/list ([export  (in-list exports)]
                  [value-id (in-list value-ids)]
                  #:when (export-alias-enabled? define-export-aliases? export))
         `(define ,export ,value-id))
     (void)))

;; first-slice->top-level-syntax : any/c (listof symbol?) keyword-args -> syntax?
;;   Convert a lowered first-slice expression to top-level syntax for `comp`.
(define (first-slice->top-level-syntax expr
                                       exports
                                       #:reserved [reserved '()]
                                       #:define-export-aliases? [define-export-aliases? #t])
  (datum->syntax
   #f
   (first-slice->top-level-datum
    expr
    exports
    #:reserved reserved
    #:define-export-aliases? define-export-aliases?)))

;; webify-linklet-first-slice-top-level/imports : linklet (listof any/c) keyword-args ... -> syntax?
;;   Webify, lower, and wrap a first-slice linklet with explicit import cells.
(define (webify-linklet-first-slice-top-level/imports lk
                                                       import-args
                                                       #:reserved             [reserved '()]
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
  (unless (list? import-args)
    (raise-argument-error 'webify-linklet-first-slice-top-level/imports
                          "list?"
                          import-args))
  (define-values (expr importss exports new-import-keys imports-abis exports-info)
    (webify-linklet-first-slice
     lk
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
  (when new-import-keys
    (error 'webify-linklet-first-slice-top-level/imports
           "inlining-added import groups are not supported by the explicit-import adapter yet"))
  (define import-count (length (flatten-groups importss)))
  (unless (= import-count (length import-args))
    (raise-arguments-error 'webify-linklet-first-slice-top-level/imports
                           "explicit import cell count does not match linklet imports"
                           "expected count" import-count
                           "actual count" (length import-args)
                           "imports" importss))
  (values (datum->syntax
           #f
           (first-slice->top-level-datum/imports
            expr
            import-args
            exports
            #:reserved reserved
            #:importss importss
            #:imports-abis imports-abis
            #:define-export-aliases? define-export-aliases?))
          importss
          exports
          exports-info))

;; webify-linklet-first-slice-top-level : linklet keyword-args ... -> syntax?
;;   Webify, lower, and wrap an import-free first-slice linklet as top-level forms.
(define (webify-linklet-first-slice-top-level lk
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
  (define-values (expr importss exports new-import-keys imports-abis exports-info)
    (webify-linklet-first-slice
     lk
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
  (unless (and (null? importss)
               (not new-import-keys)
               (null? imports-abis))
    (error 'webify-linklet-first-slice-top-level
           "imported linklets are not supported by the first top-level adapter yet"))
  (values (first-slice->top-level-syntax
           expr
           exports
           #:define-export-aliases? define-export-aliases?)
          exports
          exports-info))
