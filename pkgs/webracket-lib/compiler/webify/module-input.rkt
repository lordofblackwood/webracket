#lang racket/base

(provide webify-module-linklet-input
         webify-module-linklet-input?
         webify-module-linklet-input-name
         webify-module-linklet-input-linklet
         webify-module-linklet-input-imports
         webify-module-linklet-manifest
         webify-module-linklet-manifest?
         webify-module-linklet-manifest-inputs
         webify-module-linklet-manifest-roots
         datum->webify-module-linklet-manifest
         read-webify-module-linklet-manifest
         webify-module-linklet-manifest->registry
         webify-module-linklet-input-dependency-exports
         webify-module-linklet-inputs-dependency-exports
         webify-resolve-module-linklet-imports
         webify-module-resolution-outcome
         webify-module-resolution-outcome?
         webify-module-resolution-outcome-local
         webify-module-resolution-outcome-dependency
         webify-module-resolution-outcome-provider-export
         webify-module-resolution-outcome-status
         compiled-primitive-alias-hint
         webify-resolve-module-linklet-imports/outcomes
         webify-module-linklet-input/resolve-imports
         webify-register-module-linklet-input!
         webify-module-linklet-inputs->registry)

(require racket/list
         racket/match
         "../private/primitives-db.rkt"
         "primitive-modules.rkt"
         "module-registry.rkt")

(struct webify-module-linklet-input (name linklet imports) #:transparent)
(struct webify-module-linklet-manifest (inputs roots) #:transparent)
(struct webify-module-resolution-outcome
  (local dependency provider-export status)
  #:transparent)

;; validate-roots! : symbol? any/c -> void?
;;   Reject manifest roots that cannot identify module-linklet inputs.
(define (validate-roots! who roots)
  (unless (and (list? roots)
               (andmap symbol? roots))
    (raise-argument-error who "(listof symbol?)" roots)))

;; datum->webify-module-linklet-input : any/c -> webify-module-linklet-input?
;;   Parse one manifest input clause.
(define (datum->webify-module-linklet-input datum)
  (match datum
    [`(input ,(? symbol? name) ,linklet (imports ,imports))
     (webify-module-linklet-input name linklet imports)]
    [`(input ,(? symbol? name)
             ,linklet
             (resolve-imports (dependency-exports ,dependency-exports)))
     (webify-module-linklet-input/resolve-imports
      name
      linklet
      dependency-exports)]
    [`(input ,(? symbol? name)
             ,linklet
             (resolve-imports (dependency-exports ,dependency-exports)
                              (dependencies ,dependencies)))
     (webify-module-linklet-input/resolve-imports
      name
      linklet
      dependency-exports
      #:dependencies dependencies)]
    [_
     (raise-arguments-error 'datum->webify-module-linklet-manifest
                            "expected module-linklet input clause"
                            "clause" datum)]))

;; datum->webify-module-linklet-manifest : any/c -> webify-module-linklet-manifest?
;;   Parse a datum handoff format for extracted module-linklet inputs.
(define (datum->webify-module-linklet-manifest datum)
  (match datum
    [`(webify-module-linklet-manifest
       (roots ,roots)
       ,input-clauses ...)
     (validate-roots! 'datum->webify-module-linklet-manifest roots)
     (webify-module-linklet-manifest
      (map datum->webify-module-linklet-input input-clauses)
      roots)]
    [_
     (raise-arguments-error 'datum->webify-module-linklet-manifest
                            "expected webify module-linklet manifest datum"
                            "datum" datum)]))

;; read-webify-module-linklet-manifest : path-string? -> webify-module-linklet-manifest?
;;   Read one module-linklet manifest datum from a file.
(define (read-webify-module-linklet-manifest path)
  (call-with-input-file path
    (lambda (in)
      (datum->webify-module-linklet-manifest (read in)))))

;; linklet-import-bindings : symbol? any/c -> (listof (list/c symbol? symbol?))
;;   Extract flat local/external import bindings from a linklet datum.
(define (linklet-import-bindings who linklet)
  (match linklet
    [`(linklet ,importss ,_exports . ,_body)
     (unless (and (list? importss)
                  (for/and ([group (in-list importss)])
                    (and (list? group)
                         (for/and ([binding (in-list group)])
                           (match binding
                             [(list (? symbol?) (? symbol?)) #t]
                             [_                              #f])))))
       (raise-arguments-error who
                              "linklet imports must be grouped pairs of symbols"
                              "linklet" linklet))
     (define seen (make-hasheq))
     (define bindings
       (for/fold ([acc '()]) ([binding (in-list (apply append importss))])
         (match-define (list local external) binding)
         (define prior (hash-ref seen local #f))
         (cond
           [(not prior)
            (hash-set! seen local external)
            (cons binding acc)]
           [(symbolic-name=? prior external) acc]
           [else
            (raise-arguments-error who
                                   "conflicting duplicate linklet import names are not supported"
                                   "import" local
                                   "first external" prior
                                   "second external" external)])))
     (reverse bindings)]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; linklet-exports : symbol? any/c -> (listof symbol?)
;;   Extract flat external exports from a linklet datum.
(define (linklet-exports who linklet)
  (match linklet
    [`(linklet ,_importss ,exports . ,_body)
     (define normalized-exports
       (and (list? exports)
            (for/list ([export (in-list exports)])
              (match export
                [(list (? symbol?) (? symbol? external)) external]
                [(? symbol? external) external]
                [_ #f]))))
     (unless (and normalized-exports
                  (andmap symbol? normalized-exports))
       (raise-arguments-error who
                              "linklet exports must be symbols or internal/external symbol pairs"
                              "exports" exports))
     (define duplicate (check-duplicates normalized-exports))
     (when duplicate
       (raise-arguments-error who
                              "duplicate linklet exports are not supported"
                              "export" duplicate))
     normalized-exports]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; validate-dependency-exports! : symbol? any/c -> void?
;;   Reject dependency export tables that cannot resolve import sources.
(define (validate-dependency-exports! who dependency-exports)
  (unless (list? dependency-exports)
    (raise-argument-error who "(listof (list/c symbol? (listof symbol?)))" dependency-exports))
  (for ([entry (in-list dependency-exports)])
    (match entry
      [(list (? symbol?) exports)
       (unless (and (list? exports)
                    (andmap symbol? exports))
         (raise-argument-error who "(listof symbol?)" exports))]
      [_
       (raise-argument-error who "(list/c symbol? (listof symbol?))" entry)]))
  (define duplicate (check-duplicates (map car dependency-exports)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate dependency export entries are not supported"
                           "dependency" duplicate)))

;; validate-import-dependencies! : symbol? any/c -> void?
;;   Reject explicit local-import to dependency-module mappings.
(define (validate-import-dependencies! who dependencies)
  (unless (list? dependencies)
    (raise-argument-error who "(listof (list/c symbol? symbol?))" dependencies))
  (for ([dependency (in-list dependencies)])
    (match dependency
      [(list (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error who "(list/c symbol? symbol?)" dependency)]))
  (define duplicate (check-duplicates (map car dependencies)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate import dependency entries are not supported"
                           "import" duplicate)))

;; validate-import-aliases! : symbol? any/c -> void?
;;   Reject explicit local-import to dependency export mappings.
(define (validate-import-aliases! who aliases)
  (unless (list? aliases)
    (raise-argument-error who "(listof (list/c symbol? symbol? symbol?))" aliases))
  (for ([alias (in-list aliases)])
    (match alias
      [(list (? symbol?) (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error who "(list/c symbol? symbol? symbol?)" alias)]))
  (define seen (make-hasheq))
  (for ([alias (in-list aliases)])
    (match-define (list import module export) alias)
    (define prior (hash-ref seen import #f))
    (cond
      [(not prior)
       (hash-set! seen import (list module export))]
      [else
       (match-define (list prior-module prior-export) prior)
       (unless (and (eq? module prior-module)
                    (symbolic-name=? export prior-export))
         (raise-arguments-error who
                                "conflicting duplicate import alias entries are not supported"
                                "import" import
                                "first alias" prior
                                "second alias" (list module export)))])))

;; validate-reflection-hints! : symbol? any/c -> void?
;;   Reject metadata-derived local-import provider hints.
(define (validate-reflection-hints! who hints)
  (unless (list? hints)
    (raise-argument-error who "(listof reflection-hint?)" hints))
  (for ([hint (in-list hints)])
    (match hint
      [(list (? symbol?) (? symbol?) (? symbol?))
       (void)]
      [(list (? symbol?) (? symbol?) (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error
        who
        "(or/c (list/c local dependency export) (list/c module local dependency export))"
        hint)])))

;; dependency-exports-ref : symbol? (listof dependency-exports?) symbol? -> (listof symbol?)
;;   Look up the exports declared for one dependency module.
(define (dependency-exports-ref who dependency-exports name)
  (define found (assoc name dependency-exports))
  (cond
    [found (cadr found)]
    [(primitive-module-name? name)
     (for/list ([info (in-list primitive-db)])
       (primitive-info-name info))]
    [else
     (raise-arguments-error who
                            "import dependency has no export table entry"
                            "dependency" name
                            "available dependencies"
                            (map car dependency-exports))]))

;; kernel-dependency? : symbol? -> boolean?
;;   Recognize reflected origins for Racket's primitive kernel module.
(define (kernel-dependency? dependency)
  (primitive-module-name? dependency))

;; generated-base-name : symbol? -> string?
;;   Strip common decompiler-generated prefixes and numeric suffixes.
(define (generated-base-name name)
  (define text (symbol->string name))
  (define without-prefix (regexp-replace #rx"^new[:-]" text ""))
  (define without-index-prefix (regexp-replace #rx"^[0-9]+/" without-prefix ""))
  (regexp-replace #rx"[0-9]*[.][0-9]+$" without-index-prefix ""))

;; symbolic-name=? : symbol? symbol? -> boolean?
;;   Compare generated linklet names by printed identity when eq? is too strict.
(define (symbolic-name=? a b)
  (or (eq? a b)
      (string=? (symbol->string a) (symbol->string b))
      (string=? (generated-base-name a) (generated-base-name b))
      (string=? (generated-base-name a) (symbol->string b))
      (string=? (symbol->string a) (generated-base-name b))))

;; webify-primitive-name? : symbol? -> boolean?
;;   Check whether a kernel-origin binding is already a known Webify primitive.
(define (webify-primitive-name? name)
  (for/or ([info (in-list primitive-db)])
    (symbolic-name=? (primitive-info-name info) name)))

;; kernel-dependency-export-row : -> dependency-export-row
;;   Expose only supported Webify primitives as resolvable #%kernel exports.
(define (kernel-dependency-export-row)
  (list '#%kernel
        (for/list ([info (in-list primitive-db)])
          (primitive-info-name info))))

;; dependency-exports/add-kernel : dependency-exports -> dependency-exports
;;   Add a synthetic #%kernel row so unhinted kernel primitive imports can resolve.
(define (dependency-exports/add-kernel dependency-exports)
  (if (assoc '#%kernel dependency-exports)
      dependency-exports
      (append dependency-exports (list (kernel-dependency-export-row)))))

;; dependency-export-ref : symbol? dependency-name (listof symbol?) symbol? -> symbol?
;;   Find the provider export symbol that corresponds to an import's external name.
(define (dependency-export-ref who dependency exports external)
  (define exact-matches
    (for/list ([export (in-list exports)]
               #:when (eq? export external))
      export))
  (define matches
    (for/list ([export (in-list exports)]
               #:when (symbolic-name=? export external))
      export))
  (define generated-primary
    (string->symbol (format "~a.1" (generated-base-name external))))
  (define generated-primary-matches
    (for/list ([export (in-list matches)]
               #:when (equal? (symbol->string export)
                              (symbol->string generated-primary)))
      export))
  (define public-base
    (string->symbol (generated-base-name external)))
  (define public-base-matches
    (for/list ([export (in-list matches)]
               #:when (eq? export public-base))
      export))
  (define selected-matches
    (cond
      [(pair? exact-matches) exact-matches]
      [(pair? public-base-matches) public-base-matches]
      [(pair? generated-primary-matches) generated-primary-matches]
      [else matches]))
  (match selected-matches
    [(list export) export]
    ['()
     (raise-arguments-error who
                            "dependency does not export required name"
                            "dependency" dependency
                            "export" external)]
    [_
     (raise-arguments-error who
                            "dependency export name is ambiguous"
                            "dependency" dependency
                            "export" external
                            "matches" matches)]))

;; broad-base-reexport-module? : symbol? -> boolean?
;;   Identify base aggregators whose public exports should not outrank private providers.
(define (broad-base-reexport-module? dependency)
  (memq dependency '(racket/base racket/private/base)))

;; provider-candidate-reason : symbol? -> symbol?
;;   Classify broad export-scan candidates for ambiguity diagnostics.
(define (provider-candidate-reason dependency)
  (cond
    [(kernel-dependency? dependency)        'kernel-primitive-fallback]
    [(broad-base-reexport-module? dependency) 'broad-base-reexport]
    [else                                  'export-table-candidate]))

;; prefer-provider-candidates : (listof symbol?) -> (listof symbol?)
;;   Prefer concrete module providers over broad aggregators and kernel fallback.
(define (kernel-runtime-dependency? dependency)
  (eq? dependency '#%kernel))

;; symbol-name-prefix? : symbol? string? -> boolean?
;;   Check whether a module-name symbol starts with a collection prefix.
(define (symbol-name-prefix? sym prefix)
  (define s (symbol->string sym))
  (and (<= (string-length prefix) (string-length s))
       (equal? (substring s 0 (string-length prefix)) prefix)))

;; webracket-owned-provider? : symbol? -> boolean?
;;   Recognize WebRacket collection providers that intentionally replace Racket internals.
(define (webracket-owned-provider? dependency)
  (symbol-name-prefix? dependency "webracket/"))

;; racket-private-provider? : symbol? -> boolean?
;;   Recognize installed Racket private providers that may have WebRacket substitutes.
(define (racket-private-provider? dependency)
  (symbol-name-prefix? dependency "racket/private/"))

(define (prefer-webracket-owned-candidates candidates)
  (define webracket-candidates
    (filter webracket-owned-provider? candidates))
  (define has-racket-private?
    (for/or ([dependency (in-list candidates)])
      (racket-private-provider? dependency)))
  (if (and (pair? webracket-candidates) has-racket-private?)
      webracket-candidates
      candidates))

(define (prefer-provider-candidates candidates [external #f])
  (define kernel-candidates
    (filter kernel-runtime-dependency? candidates))
  (define concrete-candidates
    (filter (lambda (dependency)
              (and (not (broad-base-reexport-module? dependency))
                   (not (kernel-dependency? dependency))))
            candidates))
  (cond
    [(null? concrete-candidates) candidates]
    [else (prefer-webracket-owned-candidates concrete-candidates)]))

;; prefer-exact-export-candidates : dependency-exports symbol? (listof symbol?) -> (listof symbol?)
;;   Prefer providers that export the exact generated import name over providers
;;   that only match after generated-suffix normalization.
(define (prefer-exact-export-candidates dependency-exports external candidates)
  (define exact-candidates
    (filter
     (lambda (dependency)
       (define exports (dependency-exports-ref 'prefer-exact-export-candidates
                                               dependency-exports
                                               dependency))
       (memq external exports))
     candidates))
  (if (null? exact-candidates) candidates exact-candidates))

;; provider-candidate-reasons : (listof symbol?) -> (listof list?)
;;   Explain why export-scan candidates survived far enough to be ambiguous.
(define (provider-candidate-reasons candidates)
  (for/list ([dependency (in-list candidates)])
    (list dependency (provider-candidate-reason dependency))))

;; webify-module-linklet-input-dependency-exports : webify-module-linklet-input? -> dependency-export-row
;;   Derive a resolver export row from the provider linklet's compiled exports.
(define (webify-module-linklet-input-dependency-exports input)
  (define who 'webify-module-linklet-input-dependency-exports)
  (unless (webify-module-linklet-input? input)
    (raise-argument-error who "webify-module-linklet-input?" input))
  (list (webify-module-linklet-input-name input)
        (linklet-exports who (webify-module-linklet-input-linklet input))))

;; webify-module-linklet-inputs-dependency-exports : (listof webify-module-linklet-input?) -> dependency-exports
;;   Derive a resolver export table from provider linklet inputs.
(define (webify-module-linklet-inputs-dependency-exports inputs)
  (define who 'webify-module-linklet-inputs-dependency-exports)
  (unless (list? inputs)
    (raise-argument-error who "(listof webify-module-linklet-input?)" inputs))
  (define dependency-exports
    (for/list ([input (in-list inputs)])
      (unless (webify-module-linklet-input? input)
        (raise-argument-error who "webify-module-linklet-input?" input))
      (webify-module-linklet-input-dependency-exports input)))
  (validate-dependency-exports! who dependency-exports)
  dependency-exports)

;; reflection-hints->map : symbol? (or/c symbol? #f) list? -> hash?
;;   Build a local-import map from reflection hints relevant to one module.
(define (reflection-hints->map who module-name hints)
  (validate-reflection-hints! who hints)
  (define rows
    (filter
     values
     (for/list ([hint (in-list hints)])
       (match hint
         [(list (? symbol? local) (? symbol? dependency) (? symbol? export))
          (list local dependency export)]
         [(list (? symbol? importer) (? symbol? local) (? symbol? dependency) (? symbol? export))
          (and (or (not module-name) (eq? importer module-name))
               (list local dependency export))]))))
  (define duplicate (check-duplicates (map car rows)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate reflection hint entries are not supported"
                           "import" duplicate))
  (for/hasheq ([row (in-list rows)])
    (match-define (list local dependency export) row)
    (values local (list dependency export))))

;; validate-provider-export! : symbol? dependency-exports symbol? symbol? -> symbol?
;;   Validate a selected provider/export pair and return the canonical export symbol.
(define (validate-provider-export! who dependency-exports dependency provider-export)
  (cond
    [(primitive-module-name? dependency)
     (cond
       [(webify-primitive-name? provider-export) provider-export]
       [else
        (raise-arguments-error who
                               "unsupported kernel-origin binding"
                               "dependency" dependency
                               "export" provider-export)])]
    [else
     (define exports (dependency-exports-ref who dependency-exports dependency))
     (unless (for/or ([export (in-list exports)])
               (symbolic-name=? export provider-export))
       (raise-arguments-error who
                              "dependency does not export hinted name"
                              "dependency" dependency
                              "export" provider-export))
     (dependency-export-ref who dependency exports provider-export)]))

;; resolve-import-source : symbol? dependency-exports hash? hash? hash? symbol? symbol? (or/c symbol? #f) -> values
;;   Resolve one import binding to its provider module and provider export symbol.
(define (resolve-import-source who dependency-exports dependencies aliases hints local external module-name)
  (define alias (hash-ref aliases local #f))
  (define explicit (hash-ref dependencies local #f))
  (define hint (hash-ref hints local #f))
  (cond
    [alias
     (match-define (list dependency provider-export) alias)
     (when (and explicit (not (eq? explicit dependency)))
       (raise-arguments-error who
                              "import alias conflicts with explicit dependency"
                              "import" local
                              "dependency" explicit
                              "alias dependency" dependency))
     (define exports (dependency-exports-ref who dependency-exports dependency))
     (unless (for/or ([export (in-list exports)])
               (symbolic-name=? export provider-export))
       (raise-arguments-error who
                              "dependency does not export aliased name"
                              "dependency" dependency
                              "export" provider-export))
     (list dependency
           (dependency-export-ref who dependency exports provider-export)
           'resolved-by-import-alias)]
    [explicit
     (define exports (dependency-exports-ref who dependency-exports explicit))
     (define explicit-alias-hint
       (compiled-primitive-alias-hint module-name local external))
     (define provider-export
       (match explicit-alias-hint
         [(list dependency hinted-export)
          #:when (eq? dependency explicit)
          hinted-export]
         [_ external]))
     (list explicit
           (dependency-export-ref who explicit exports provider-export)
           'resolved-by-explicit-dependency)]
    [hint
     (match-define (list dependency provider-export) hint)
     (list dependency
           (validate-provider-export! who dependency-exports dependency provider-export)
           'resolved-by-reflection-hint)]
    [else
     (define candidates
       (remove-duplicates
        (for/list ([entry (in-list dependency-exports)]
                   #:do [(match-define (list dependency exports) entry)]
                   #:when (for/or ([export (in-list exports)])
                            (symbolic-name=? export external)))
          dependency)
        eq?))
     (define ranked-candidates
       (prefer-exact-export-candidates
        dependency-exports
        external
        (prefer-provider-candidates candidates external)))
     (cond
       [(null? candidates)
        (raise-arguments-error who
                               "missing-after-reflection"
                               "module" module-name
                               "import" local
                               "export" external)]
       [(null? (cdr ranked-candidates))
        (define dependency (car ranked-candidates))
        (define exports (dependency-exports-ref who dependency-exports dependency))
        (list dependency
              (dependency-export-ref who dependency exports external)
              (if (equal? ranked-candidates candidates)
                  'resolved-by-export-scan
                  'resolved-by-export-scan/provider-precedence))]
       [else
        (raise-arguments-error who
                               "ambiguous-after-reflection"
                               "module" module-name
                               "import" local
                               "export" external
                               "candidates" ranked-candidates
                               "candidate reasons"
                               (provider-candidate-reasons candidates))])]))

;; compiled-primitive-alias-hints : (or/c symbol? #f) symbol? symbol? -> (or/c list? #f)
;;   Recover a few primitive-module aliases that compiled metadata currently
;;   exposes only as internalized imports. For example, setup/private/dirs
;;   imports #%utils:get-installation-name as 1/get-installation-name and then
;;   defines its own public get-installation-name, so export scanning alone
;;   incorrectly resolves the import to the module's own export cell.
(define (compiled-primitive-alias-hint module-name local external)
  (cond
    [(and (eq? module-name 'setup/private/dirs)
          (eq? local '1/get-installation-name)
          (eq? external 'get-installation-name))
     '(#%utils get-installation-name)]
    [(and (eq? local '-random)
          (eq? external '-random))
     '(#%kernel random)]
    [(and (eq? local '1/syntax-source)
          (eq? external 'syntax-source))
     '(webracket/primitives syntax-source)]
    [(and (memq module-name '(webracket/contract
                              racket/contract/base
                              racket/contract/combinator
                              racket/contract/region
                              racket/contract/private/base
                              racket/contract/private/blame
                              racket/contract/private/guts
                              racket/contract/private/object
                              racket/contract/private/object-c-wrapper))
          (eq? local '1/datum->syntax)
          (eq? external 'datum->syntax))
     '(webracket/primitives datum->syntax)]
    [(and (memq module-name '(webracket/contract
                              racket/contract/base
                              racket/contract/combinator
                              racket/contract/region
                              racket/contract/private/base
                              racket/contract/private/blame
                              racket/contract/private/guts
                              racket/contract/private/object
                              racket/contract/private/object-c-wrapper))
          (memq local '(1/syntax-span
                         1/syntax-position
                         1/syntax-column
                         1/syntax-line
                         1/syntax-source
                         1/syntax?))
          (memq external '(syntax-span
                           syntax-position
                           syntax-column
                           syntax-line
                           syntax-source
                           syntax?)))
     (list 'webracket/primitives external)]
    [(and (memq module-name '(racket/private/for webracket/private/for))
          (eq? local 'directory-list.1))
     '(#%kernel webracket-directory-list-build-first)]
    [(and (memq module-name '(racket/private/for
                              racket/private/list
                              racket/private/class-struct
                              webracket/list))
          (eq? local '1/reverse)
          (eq? external 'reverse))
     '(racket/private/pico reverse)]
    [(and (eq? module-name 'racket/list)
          (symbolic-name=? external 'sort))
     '(racket/private/sort sort)]
    [(and (memq module-name '(racket/list
                              racket/private/list
                              webracket/list))
          (symbolic-name=? external 'check-list))
     '(#%kernel check-list)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'coerce-contract))
     '(racket/contract/private/guts coerce-contract)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'apply-contract))
     '(racket/contract/private/guts apply-contract)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'blame-swap))
     '(racket/contract/private/blame blame-swap)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'raise-blame-error))
     '(racket/contract/private/blame raise-blame-error)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'contract?))
     '(racket/contract/private/guts contract?)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'contract-continuation-mark-key))
     '(racket/contract/private/guts contract-continuation-mark-key)]
    [(and (memq module-name '(contract racket/private/unit/contract))
          (symbolic-name=? external 'contract-continuation-mark-key))
     '(racket/contract/private/guts contract-continuation-mark-key)]
    [(and (memq module-name '(contract racket/private/unit/contract))
          (symbolic-name=? external 'member))
     ;; `racket/private/unit/contract` gets ordinary list membership from its
     ;; `racket/base` import. Prefer the list layer when full-language provider
     ;; composition also exposes the lower pico helper.
     '(racket/private/list member)]
    [(and (memq module-name '(runtime racket/private/unit/runtime))
          (symbolic-name=? external 'contract-continuation-mark-key))
     '(racket/contract/private/guts contract-continuation-mark-key)]
    [(and (memq module-name '(runtime racket/private/unit/runtime))
          (symbolic-name=? external '-make-blame))
     '(racket/contract/private/blame make-blame)]
    [(and (eq? module-name 'racket/private/unit/contract-syntax)
          (symbolic-name=? external 'unwind-to))
     '(syntax/parse/private/residual/state unwind-to)]
    [(and (eq? module-name 'racket/private/unit/contract-syntax)
          (memq external '(failure*
                           ps-add-cdr
                           ps-add-car
                           ps-add-stx
                           ps-add-post
                           ps-add
                           es-add-thing
                           es-add-literal
                           es-add-atom
                           es-add-proper-pair)))
     (list 'syntax/parse/private/residual/progress external)]
    [(and (eq? module-name 'racket/private/unit/contract-syntax)
          (memq external '(t-resyntax t-subst)))
     (list 'racket/private/template external)]
    [(and (eq? module-name 'racket/private/unit/contract-syntax)
          (symbolic-name=? external 'predicate-ellipsis-parser))
     '(syntax/parse/private/residual/parse-util predicate-ellipsis-parser)]
    [(and (eq? module-name 'syntax/parse/private/residual/parse-util)
          (symbolic-name=? external '2d-stx?.1))
     '(syntax/parse/private/residual/3d-stx 2d-stx?.1)]
    [(and (eq? module-name 'syntax/parse/private/residual/parse-util)
          (symbolic-name=? external 'resolve-paths))
     '(racket/runtime-path resolve-paths)]
    [(and (eq? module-name 'racket/runtime-path)
          (symbolic-name=? external 'table))
     '(racket/private/runtime-path-table table)]
    [(and (eq? module-name 'racket/runtime-path)
          (memq external '(decode-link-path encode-link-path encoded-link-path?)))
     (list 'racket/private/link-path external)]
    [(and (eq? module-name 'racket/runtime-path)
          (memq external '(so-find so-spec?)))
     (list 'webracket/private/so-search external)]
    [(and (eq? module-name 'racket/runtime-path)
          (memq external '(share-find share-spec?)))
     (list 'webracket/private/share-search external)]
    [(and (eq? module-name 'racket/runtime-path)
          (symbolic-name=? external 'new-apply-proc))
     '(webracket/private/pre-base-apply new-apply-proc)]
    [(and (eq? module-name 'syntax/parse/private/residual/parse-util)
          (symbolic-name=? external 'make-lazy-function))
     '(racket/lazy-require make-lazy-function)]
    [(and (eq? module-name 'racket/lazy-require)
          (symbolic-name=? external 'delay/sync))
     '(racket/promise delay/sync/proc)]
    [(and (eq? module-name 'racket/lazy-require)
          (symbolic-name=? external 'register-external-module))
     '(compiler/cm-accomplice register-external-module)]
    [(and (eq? module-name 'racket/private/unit/contract-syntax)
          (symbolic-name=? external 'expr-stx?))
     '(syntax/parse/private/lib expr-stx?)]
    [(and (memq module-name '(exptime/import-export
                               racket/private/unit/exptime/import-export))
          (symbolic-name=? external 's-any))
     '(syntax/parse/private/residual-interp s-any)]
    [(and (memq module-name '(exptime/import-export
                               racket/private/unit/exptime/import-export))
          (symbolic-name=? external 'check-list))
     ;; Source imports this through `racket/list`; prefer the private list
     ;; implementation when the compiled bundle exposes both names.
     '(racket/private/list check-list)]
    [(and (memq module-name '(exptime/import-export
                               racket/private/unit/exptime/import-export))
          (symbolic-name=? external 'empty?))
     ;; `racket/list` re-exports `empty?` from its predicate helper.
     '(racket/private/list-predicates empty?)]
    [(and (memq module-name '(exptime/import-export
                               racket/private/unit/exptime/import-export))
          (symbolic-name=? external 'append-map))
     ;; Source imports this public helper through `racket/list`.
     '(racket/list append-map)]
    [(and (eq? module-name 'syntax/parse/private/residual-interp)
          (symbol? external)
          (regexp-match? #rx"^sim:" (symbol->string external)))
     (list 'syntax/parse/private/rep-patterns/simple external)]
    [(and (eq? module-name 'racket/private/unit/exptime/syntax)
          (symbolic-name=? external 'interp-match))
     '(racket/private/stxcase interp-match)]
    [(and (memq module-name '(exptime/util
                               racket/private/unit/exptime/util))
          (symbolic-name=? external 'make-hygienic-metafunction))
     '(syntax/parse/experimental/template make-hygienic-metafunction)]
    [(and (memq module-name '(exptime/util
                               racket/private/unit/exptime/util))
          (symbolic-name=? external 'check-list))
     ;; This helper uses `for/list`; prefer the check emitted through the for
     ;; implementation when list internals are also visible.
     '(racket/private/for check-list)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'variable-reference->module-source/submod))
     '(syntax/location variable-reference->module-source/submod)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'current-contract-region))
     '(racket/contract/region current-contract-region)]
    [(and (eq? module-name 'racket/private/class-internal)
          (symbolic-name=? external 'contract))
     '(racket/contract/private/guts contract)]
    [(symbolic-name=? external 'struct:keyword-method/arity-error)
     '(racket/private/kw struct:keyword-method/arity-error)]
    [(and (eq? module-name 'racket/private/kw)
          (symbolic-name=? external 'new-prop:procedure))
     '(#%kernel prop:procedure)]
    [(symbolic-name=? external 'find-method/who)
     '(racket/private/class-struct find-method/who)]
    [(symbolic-name=? external 'do-make-object)
     '(racket/private/class-internal do-make-object)]
    [(symbolic-name=? external 'extract-arg)
     '(racket/private/class-internal extract-arg)]
    [(symbolic-name=? external 'compose-class)
     '(racket/private/class-internal compose-class)]
    [(symbolic-name=? external 'is-a?)
     '(racket/private/class-internal is-a?)]
    [(symbolic-name=? external 'object?)
     '(racket/private/class-internal object?)]
    [(symbolic-name=? external 'object%)
     '(racket/private/class-internal object%)]
    [(symbolic-name=? external 'check-inspector)
     '(racket/private/define-struct check-inspector)]
    [(symbolic-name=? external 'check-struct-type)
     '(racket/private/define-struct check-struct-type)]
    [(symbolic-name=? external 'make-serialize-info)
     '(racket/private/serialize-structs make-serialize-info)]
    [(symbolic-name=? external 'make-deserialize-info)
     '(racket/private/serialize-structs make-deserialize-info)]
    [(symbolic-name=? external 'remove-duplicates)
     '(webracket/list remove-duplicates)]
    [(symbolic-name=? external 'andmap2)
     '(racket/private/map andmap2)]
    [(symbolic-name=? external 'ormap2)
     '(racket/private/map ormap2)]
    [(symbolic-name=? external 'normalise-inputs)
     '(racket/private/for normalise-inputs)]
    [(symbolic-name=? external 'unsafe-undefined)
     '(racket/unsafe/undefined unsafe-undefined)]
    [(symbolic-name=? external 'check-not-unsafe-undefined)
     '(racket/unsafe/undefined check-not-unsafe-undefined)]
    [(symbolic-name=? external 'check-not-unsafe-undefined/assign)
     '(racket/unsafe/undefined check-not-unsafe-undefined/assign)]
    [(symbolic-name=? external 'prop:chaperone-unsafe-undefined)
     '(racket/unsafe/undefined prop:chaperone-unsafe-undefined)]
    [(symbolic-name=? external 'chaperone-struct-unsafe-undefined)
     '(racket/unsafe/undefined chaperone-struct-unsafe-undefined)]
    [else #f]))

;; webify-resolve-module-linklet-imports/outcomes : linklet dependency-exports keyword-args ... -> values
;;   Derive flat registry import triples and classify each resolution decision.
(define (webify-resolve-module-linklet-imports/outcomes linklet
                                                        dependency-exports
                                                        #:module-name [module-name #f]
                                                        #:dependencies [dependencies '()]
                                                        #:import-aliases [import-aliases '()]
                                                        #:reflection-hints [reflection-hints '()])
  (define who 'webify-resolve-module-linklet-imports)
  (define bindings (linklet-import-bindings who linklet))
  (define dependency-exports* (dependency-exports/add-kernel dependency-exports))
  (validate-dependency-exports! who dependency-exports*)
  (validate-import-dependencies! who dependencies)
  (validate-import-aliases! who import-aliases)
  (unless (or (not module-name) (symbol? module-name))
    (raise-argument-error who "(or/c symbol? #f)" module-name))
  (define imports (map car bindings))
  (define (canonical-import import kind)
    (cond
      [(memq import imports) import]
      [else
       (match (filter (lambda (candidate)
                        (symbolic-name=? candidate import))
                      imports)
         [(list candidate) candidate]
         [matches
          (raise-arguments-error who
                                 (format "~a references a name not imported by the linklet" kind)
                                 "import" import
                                 "matches" matches
                                 "linklet imports" imports)])]))
  (for ([dependency (in-list dependencies)])
    (match-define (list import _module) dependency)
    (canonical-import import "import dependency"))
  (for ([alias (in-list import-aliases)])
    (match-define (list import _module _export) alias)
    (canonical-import import "import alias"))
  (define dependency-map
    (for/hasheq ([dependency (in-list dependencies)])
      (match-define (list import module) dependency)
      (values (canonical-import import "import dependency") module)))
  (define alias-map
    (for/fold ([aliases (hasheq)]) ([alias (in-list import-aliases)])
      (match-define (list import module export) alias)
      (define canonical (canonical-import import "import alias"))
      (if (hash-has-key? aliases canonical)
          aliases
          (hash-set aliases canonical (list module export)))))
  (define hint-map
    (for/fold ([hints (hasheq)])
              ([(import value) (in-hash (reflection-hints->map who module-name reflection-hints))])
      (define canonical (canonical-import import "reflection hint"))
      (if (hash-has-key? hints canonical)
          hints
          (hash-set hints canonical value))))
  (define resolved
    (for/list ([binding (in-list bindings)])
      (match-define (list local external) binding)
      (define primitive-alias-override?
        (and (memq module-name '(racket/list
                                 racket/private/list
                                 webracket/list))
             (symbolic-name=? external 'check-list)))
      (define candidate-primitive-alias-hint
        (and (not (or (and (not primitive-alias-override?)
                            (hash-has-key? alias-map local))
                      (hash-has-key? hint-map local)))
             (compiled-primitive-alias-hint module-name local external)))
      (define primitive-alias-hint
        (match candidate-primitive-alias-hint
          [(list dependency _provider-export)
           #:when (assoc dependency dependency-exports*)
           candidate-primitive-alias-hint]
          [_ #f]))
      (match-define (list dependency provider-export status)
        (if primitive-alias-hint
            (match primitive-alias-hint
              [(list dependency provider-export)
               (list dependency
                     (validate-provider-export! who
                                                dependency-exports*
                                                dependency
                                                provider-export)
                     'resolved-by-compiled-primitive-alias)])
            (resolve-import-source who dependency-exports* dependency-map alias-map hint-map local external module-name)))
      (list (list local dependency provider-export)
            (webify-module-resolution-outcome local dependency provider-export status))))
  (values (map car resolved)
          (map cadr resolved)))

;; webify-resolve-module-linklet-imports : linklet dependency-exports [#:dependencies dependencies] -> imports
;;   Derive flat registry import triples from linklet imports and dependency exports.
(define (webify-resolve-module-linklet-imports linklet
                                               dependency-exports
                                               #:module-name [module-name #f]
                                               #:dependencies [dependencies '()]
                                               #:import-aliases [import-aliases '()]
                                               #:reflection-hints [reflection-hints '()])
  (define-values (imports outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     linklet
     dependency-exports
     #:module-name module-name
     #:dependencies dependencies
     #:import-aliases import-aliases
     #:reflection-hints reflection-hints))
  imports)

;; webify-module-linklet-input/resolve-imports : symbol? linklet dependency-exports [#:dependencies dependencies] -> input
;;   Build one module-linklet input while deriving its flat import triples.
(define (webify-module-linklet-input/resolve-imports name
                                                     linklet
                                                     dependency-exports
                                                     #:dependencies [dependencies '()]
                                                     #:import-aliases [import-aliases '()]
                                                     #:reflection-hints [reflection-hints '()])
  (webify-module-linklet-input
   name
   linklet
   (webify-resolve-module-linklet-imports
    linklet
    dependency-exports
    #:module-name name
    #:dependencies dependencies
    #:import-aliases import-aliases
    #:reflection-hints reflection-hints)))

;; webify-register-module-linklet-input! : webify-module-registry? webify-module-linklet-input? -> void?
;;   Register one extracted module-linklet input in a module registry.
(define (webify-register-module-linklet-input! registry input)
  (define who 'webify-register-module-linklet-input!)
  (unless (webify-module-linklet-input? input)
    (raise-argument-error who "webify-module-linklet-input?" input))
  (webify-module-registry-add!
   registry
   (webify-module-linklet-input-name input)
   (webify-module-linklet-input-linklet input)
   #:imports (webify-module-linklet-input-imports input)))

;; webify-module-linklet-inputs->registry : (listof webify-module-linklet-input?) -> webify-module-registry?
;;   Build a registry from already-extracted module-linklet inputs.
(define (webify-module-linklet-inputs->registry inputs)
  (define who 'webify-module-linklet-inputs->registry)
  (unless (list? inputs)
    (raise-argument-error who "(listof webify-module-linklet-input?)" inputs))
  (define registry (make-webify-module-registry))
  (for ([input (in-list inputs)])
    (webify-register-module-linklet-input! registry input))
  registry)

;; webify-module-linklet-manifest->registry : webify-module-linklet-manifest? -> webify-module-registry?
;;   Build a registry from a parsed module-linklet manifest.
(define (webify-module-linklet-manifest->registry manifest)
  (unless (webify-module-linklet-manifest? manifest)
    (raise-argument-error 'webify-module-linklet-manifest->registry
                          "webify-module-linklet-manifest?"
                          manifest))
  (webify-module-linklet-inputs->registry
   (webify-module-linklet-manifest-inputs manifest)))
