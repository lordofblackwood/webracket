#lang racket/base

(provide webify-module-extractor-spike
         webify-module-extractor-spike?
         webify-module-extractor-spike-name
         webify-module-extractor-spike-directory-keys
         webify-module-extractor-spike-bundle-keys
         webify-module-extractor-spike-bundle-entries
         webify-module-extractor-spike-phase0-imports
         webify-module-extractor-spike-phase0-exports
         webify-module-extractor-spike-phase0-linklet-datum
         webify-module-extractor-spike-manifest-ready?
         webify-module-extractor-spike-notes
         webify-module-import-map
         webify-module-import-map?
         webify-module-import-map-phase0-import-groups
         webify-module-import-map-phase0-structured-import-groups
         webify-module-import-map-phase0-decompiled-import-groups
         webify-module-import-map-module-protocol-import-groups
         webify-module-import-map-unresolved-import-groups
         webify-module-import-map-data-module-path-indexes
         webify-module-import-map-decl-requires-expression
         webify-module-import-map-decl-provides-expression
         webify-module-import-map-decl-phase-to-link-modules-expression
         webify-module-import-map-required-module-candidates
         webify-module-import-map-import-aliases
         webify-module-import-map-require-rename-aliases
         webify-module-import-map-missing-alias-import-groups
         webify-module-import-map-notes
         webify-module-bundle-entry
         webify-module-bundle-entry?
         webify-module-bundle-entry-key
         webify-module-bundle-entry-kind
         webify-module-bundle-entry-imports
         webify-module-bundle-entry-exports
         webify-module-bundle-entry-datum
         webify-module-bundle-entry-value
         webify-module-bundle-entry-ref
         webify-module-extractor-spike-import-map
         webify-module-extractor-spike-required-provider-names
         webify-module-extractor-spike->required-provider-spikes
         webify-module-extractor-spikes->required-provider-closure
         webify-module-export-demand
         webify-module-export-demand?
         webify-module-export-demand-module
         webify-module-export-demand-exports
         webify-module-export-demand-reason
         webify-module-export-demand-reason?
         webify-module-export-demand-reason-module
         webify-module-export-demand-reason-export
         webify-module-export-demand-reason-importer
         webify-module-export-demand-reason-import
         webify-module-export-demand-reason-local
         webify-module-extractor-spike-import-export-demands
         webify-module-extractor-spike-import-export-demand-reasons
         webify-module-extractor-spike/slice-exports
         webify-module-extractor-spikes->discovered-resolved-linklet-inputs
         webify-module-provider-discovery-run-stages
         webify-module-provider-discovery-stages?
         webify-module-provider-discovery-stages-discovered-reports
         webify-module-provider-discovery-stages-resolved-reports
         webify-module-provider-discovery-stages-inputs
         webify-module-provider-discovery-stages-timings
         webify-module-provider-discovery-trace-event
         webify-module-provider-discovery-trace-event?
         webify-module-provider-discovery-trace-event-provider
         webify-module-provider-discovery-trace-event-demander
         webify-module-provider-discovery-trace-event-depth
         webify-module-provider-discovery-trace-event-cached?
         webify-module-provider-discovery-trace-event-reason
         webify-module-provider-discovery-trace-event-elapsed-ms
         webify-module-provider-discovery-trace-event-status
         webify-module-provider-cache
         webify-module-provider-cache?
         make-webify-module-provider-cache
         webify-module-provider-cache-ref
         webify-module-provider-cache-hit-count
         webify-module-provider-cache-miss-count
         webify-module-provider-cache-names
         webify-module-provider-cache-count
         make-webify-contract-erasing-namespace
         make-webify-contract-erasing-module-name-resolver
         webify-module-extractor-spike-dependency-exports
         webify-module-extractor-spikes-dependency-exports
         webify-module-path->extractor-spike
         webify-module-path->module-export-metadata
         webify-module-paths->module-export-metadata
         webify-source-module->dependency-exports
         webify-source-modules->dependency-exports
         webify-source-module->module-export-metadata
         webify-source-modules->module-export-metadata
         webify-normalize-linklet-imports
         webify-normalize-linklet-exports
         webify-linklet-import-bindings
         webify-source-module->linklet-input
         webify-module-extractor-spike->resolved-linklet-input
         webify-module-extractor-spike->resolved-linklet-input/providers
         webify-module-extractor-spikes->resolved-linklet-inputs
         webify-source-module->resolved-linklet-input
         webify-source-module->resolved-linklet-input/providers
         webify-source-modules->resolved-linklet-inputs
         webify-source-modules->discovered-resolved-linklet-inputs
         webify-compile-module-extractor-spike)

(require racket/linklet
         racket/list
         racket/match
         racket/runtime-path
         racket/set
         racket/string
         (rename-in racket/unsafe/undefined
                    [unsafe-undefined host-unsafe-undefined])
         syntax/modcode
         (only-in "../private/parameters.rkt"
                  current-module-bridge-local-report-names)
         "faslable-linklet.rkt"
         "module-input.rkt")

(define-runtime-path webify-contract-path "../../../webracket/contract.rkt")
(define-runtime-path webify-private-format-path "../../../webracket/private/format.rkt")
(define-runtime-path webify-private-in-path "../../../webracket/private/in.rkt")
(define-runtime-path webify-private-in-out-path "../../../webracket/private/in-out.rkt")
(define-runtime-path webify-private-module-boundary-ctc-path "../../../webracket/private/module-boundary-ctc.rkt")
(define-runtime-path webify-syntax-contract-path "../../../webracket/syntax/contract.rkt")
(define-runtime-path webify-syntax-srcloc-path "../../../webracket/syntax/srcloc.rkt")
(define-runtime-path webify-unsafe-undefined-path "../../../webracket/unsafe/undefined.rkt")

(define webify-private-in-path/resolved
  (simplify-path webify-private-in-path))
(define webify-private-in-out-path/resolved
  (simplify-path webify-private-in-out-path))
(define webify-private-module-boundary-ctc-path/resolved
  (simplify-path webify-private-module-boundary-ctc-path))
(define webify-private-format-path/resolved
  (simplify-path webify-private-format-path))
(define webify-contract-path/resolved
  (simplify-path webify-contract-path))
(define webify-syntax-contract-path/resolved
  (simplify-path webify-syntax-contract-path))
(define webify-syntax-srcloc-path/resolved
  (simplify-path webify-syntax-srcloc-path))
(define webify-unsafe-undefined-path/resolved
  (simplify-path webify-unsafe-undefined-path))

(define unsafe-undefined-literal-marker 'webracket-internal-unsafe-undefined-literal)

;; module-path-available? : module-path? -> boolean?
;;   Check whether the current host can resolve a module path to an existing source.
(define (module-path-available? module-path)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (define resolved
      (resolved-module-path-name
       (module-path-index-resolve
        (module-path-index-join module-path #f)
        #t)))
    (cond
      [(path-string? resolved) (file-exists? resolved)]
      [else resolved])))

;; readable-linklet-datum : any/c -> any/c
;;   Replace host-only literals with readable markers for manifest output.
(define (readable-linklet-datum v)
  (cond
    [(eq? v host-unsafe-undefined) unsafe-undefined-literal-marker]
    [(pair? v) (cons (readable-linklet-datum (car v))
                     (readable-linklet-datum (cdr v)))]
    [(vector? v)
     (list->vector
      (for/list ([elem (in-vector v)])
        (readable-linklet-datum elem)))]
    [else v]))

;; contract-module-path? : any/c -> boolean?
;;   Recognize module-path spellings for public contract providers.
(define (contract-module-path? module-path)
  (or (eq? module-path 'racket/contract)
      (eq? module-path 'racket/contract/base)
      (eq? module-path 'racket/contract/combinator)
      (eq? module-path 'racket/contract/region)
      (eq? module-path 'racket/contract/private/base)
      (eq? module-path 'racket/contract/private/arr-i)
      (eq? module-path 'racket/contract/private/arrow-collapsible)
      (eq? module-path 'racket/contract/private/arrow-common)
      (eq? module-path 'racket/contract/private/arrow-higher-order)
      (eq? module-path 'racket/contract/private/arrow-val-first)
      (eq? module-path 'racket/contract/private/blame)
      (eq? module-path 'racket/contract/private/case-arrow)
      (eq? module-path 'racket/contract/private/guts)
      (eq? module-path 'racket/contract/private/list)
      (eq? module-path 'racket/contract/private/misc)
      (eq? module-path 'racket/contract/private/module-boundary-ctc)
      (eq? module-path 'racket/contract/private/object-c-wrapper)
      (eq? module-path 'racket/contract/private/opt)
      (eq? module-path 'racket/contract/private/orc)
      (eq? module-path 'racket/contract/private/prop)
      (eq? module-path 'syntax/contract)
      (equal? module-path '(lib "racket/contract.rkt"))
      (equal? module-path '(lib "racket/contract/base.rkt"))
      (equal? module-path '(lib "racket/contract/combinator.rkt"))
      (equal? module-path '(lib "racket/contract/region.rkt"))
      (equal? module-path '(lib "racket/contract/private/base.rkt"))
      (equal? module-path '(lib "racket/contract/private/arr-i.rkt"))
      (equal? module-path '(lib "racket/contract/private/arrow-collapsible.rkt"))
      (equal? module-path '(lib "racket/contract/private/arrow-common.rkt"))
      (equal? module-path '(lib "racket/contract/private/arrow-higher-order.rkt"))
      (equal? module-path '(lib "racket/contract/private/arrow-val-first.rkt"))
      (equal? module-path '(lib "racket/contract/private/blame.rkt"))
      (equal? module-path '(lib "racket/contract/private/case-arrow.rkt"))
      (equal? module-path '(lib "racket/contract/private/guts.rkt"))
      (equal? module-path '(lib "racket/contract/private/list.rkt"))
      (equal? module-path '(lib "racket/contract/private/misc.rkt"))
      (equal? module-path '(lib "racket/contract/private/module-boundary-ctc.rkt"))
      (equal? module-path '(lib "racket/contract/private/object-c-wrapper.rkt"))
      (equal? module-path '(lib "racket/contract/private/opt.rkt"))
      (equal? module-path '(lib "racket/contract/private/orc.rkt"))
      (equal? module-path '(lib "racket/contract/private/prop.rkt"))
      (equal? module-path '(lib "syntax/contract.rkt"))))

;; unsafe-undefined-module-path? : any/c -> boolean?
;;   Recognize module-path spellings for Racket's unsafe undefined provider.
(define (unsafe-undefined-module-path? module-path)
  (or (eq? module-path 'racket/unsafe/undefined)
      (equal? module-path '(lib "racket/unsafe/undefined.rkt"))))

;; syntax-srcloc-module-path? : any/c -> boolean?
;;   Recognize source-location providers that need format-free extraction.
(define (syntax-srcloc-module-path? module-path)
  (or (eq? module-path 'syntax/srcloc)
      (equal? module-path '(lib "syntax/srcloc.rkt"))))

;; staged-format-module-path? : any/c -> boolean?
;;   Recognize public format providers that should route to the staged adapter.
(define (staged-format-module-path? module-path)
  (or (eq? module-path 'racket/format)
      (equal? module-path '(lib "racket/format.rkt"))))

;; staged-format-module-path->resolved : -> resolved-module-path?
;;   Resolve public format imports to the synthetic staged namespace module.
(define (staged-format-module-path->resolved)
  (make-resolved-module-path 'racket/format))

;; syntax-srcloc-export-names : (listof symbol?)
;;   Public source-location helpers used by contract internals.
(define syntax-srcloc-export-names
  '(source-location?
    source-location-list?
    source-location-vector?
    check-source-location!
    build-source-location
    build-source-location-list
    build-source-location-vector
    build-source-location-syntax
    source-location-known?
    source-location-source
    source-location-line
    source-location-column
    source-location-position
    source-location-span
    source-location-end
    update-source-location
    source-location->string
    source-location->prefix))

;; syntax-srcloc-export-name? : symbol? -> boolean?
;;   Recognize source-location helper imports, including generated suffixes.
(define (syntax-srcloc-export-name? external)
  (for/or ([name (in-list syntax-srcloc-export-names)])
    (symbolic-name=? external name)))

;; symbolic-member? : symbol? (listof symbol?) -> boolean?
;;   Match generated/internalized names against public provider names.
(define (symbolic-member? external names)
  (for/or ([name (in-list names)])
    (symbolic-name=? external name)))

;; contract-module-path->resolved : module-path? -> resolved-module-path?
;;   Map public contract providers to symbolic erased declarations.
(define (contract-module-path->resolved module-path)
  (make-resolved-module-path
   (cond
     [(or (eq? module-path 'racket/contract/base)
          (equal? module-path '(lib "racket/contract/base.rkt")))
      'racket/contract/base]
     [(or (eq? module-path 'syntax/contract)
          (equal? module-path '(lib "syntax/contract.rkt")))
      'syntax/contract]
     [(or (eq? module-path 'racket/contract/combinator)
          (equal? module-path '(lib "racket/contract/combinator.rkt")))
      'racket/contract/combinator]
     [(or (eq? module-path 'racket/contract/region)
          (equal? module-path '(lib "racket/contract/region.rkt")))
      'racket/contract/region]
     [(or (eq? module-path 'racket/contract/private/base)
          (equal? module-path '(lib "racket/contract/private/base.rkt")))
      'racket/contract/private/base]
     [(or (eq? module-path 'racket/contract/private/arr-i)
          (equal? module-path '(lib "racket/contract/private/arr-i.rkt")))
      'racket/contract/private/arr-i]
     [(or (eq? module-path 'racket/contract/private/arrow-collapsible)
          (equal? module-path '(lib "racket/contract/private/arrow-collapsible.rkt")))
      'racket/contract/private/arrow-collapsible]
     [(or (eq? module-path 'racket/contract/private/arrow-common)
          (equal? module-path '(lib "racket/contract/private/arrow-common.rkt")))
      'racket/contract/private/arrow-common]
     [(or (eq? module-path 'racket/contract/private/arrow-higher-order)
          (equal? module-path '(lib "racket/contract/private/arrow-higher-order.rkt")))
      'racket/contract/private/arrow-higher-order]
     [(or (eq? module-path 'racket/contract/private/arrow-val-first)
          (equal? module-path '(lib "racket/contract/private/arrow-val-first.rkt")))
      'racket/contract/private/arrow-val-first]
     [(or (eq? module-path 'racket/contract/private/blame)
          (equal? module-path '(lib "racket/contract/private/blame.rkt")))
      'racket/contract/private/blame]
     [(or (eq? module-path 'racket/contract/private/case-arrow)
          (equal? module-path '(lib "racket/contract/private/case-arrow.rkt")))
      'racket/contract/private/case-arrow]
     [(or (eq? module-path 'racket/contract/private/guts)
          (equal? module-path '(lib "racket/contract/private/guts.rkt")))
      'racket/contract/private/guts]
     [(or (eq? module-path 'racket/contract/private/list)
          (equal? module-path '(lib "racket/contract/private/list.rkt")))
      'racket/contract/private/list]
     [(or (eq? module-path 'racket/contract/private/misc)
          (equal? module-path '(lib "racket/contract/private/misc.rkt")))
      'racket/contract/private/misc]
     [(or (eq? module-path 'racket/contract/private/module-boundary-ctc)
          (equal? module-path '(lib "racket/contract/private/module-boundary-ctc.rkt")))
      webify-private-module-boundary-ctc-path/resolved]
     [(or (eq? module-path 'racket/contract/private/object-c-wrapper)
          (equal? module-path '(lib "racket/contract/private/object-c-wrapper.rkt")))
      'racket/contract/private/object-c-wrapper]
     [(or (eq? module-path 'racket/contract/private/opt)
          (equal? module-path '(lib "racket/contract/private/opt.rkt")))
      'racket/contract/private/opt]
     [(or (eq? module-path 'racket/contract/private/orc)
          (equal? module-path '(lib "racket/contract/private/orc.rkt")))
      'racket/contract/private/orc]
     [(or (eq? module-path 'racket/contract/private/prop)
          (equal? module-path '(lib "racket/contract/private/prop.rkt")))
      'racket/contract/private/prop]
     [else 'racket/contract])))

;; contract-relative-source? : any/c -> boolean?
;;   Check whether source resolves inside Racket's contract implementation tree.
(define (contract-relative-source? source)
  (define source-name
    (cond
      [(resolved-module-path? source) (resolved-module-path-name source)]
      [(path-string? source) source]
      [else #f]))
  (or (memq source-name '(racket/contract
                          racket/contract/base
                          racket/contract/combinator
                          racket/contract/region
                          racket/contract/private/base
                          racket/contract/private/arr-i
                          racket/contract/private/arrow-collapsible
                          racket/contract/private/arrow-common
                          racket/contract/private/arrow-higher-order
                          racket/contract/private/arrow-val-first
                          racket/contract/private/blame
                          racket/contract/private/case-arrow
                          racket/contract/private/guts
                          racket/contract/private/list
                          racket/contract/private/misc
                          racket/contract/private/module-boundary-ctc
                          racket/contract/private/object-c-wrapper
                          racket/contract/private/opt
                          racket/contract/private/orc
                          racket/contract/private/prop
                          webracket/private/in
                          webracket/private/in-out
                          webracket/private/module-boundary-ctc))
      (and (path-string? source-name)
           (regexp-match? #rx"(/racket/contract(?:/private)?/|/webracket/contract[.]rkt$|/webracket/syntax/contract[.]rkt$|/webracket/private/(?:in|in-out|module-boundary-ctc)[.]rkt$)"
                          (path->string (simplify-path source-name))))))

;; webracket-contract-source? : any/c -> boolean?
;;   Check whether source resolves to WebRacket's staged contract shim.
(define (webracket-contract-source? source)
  (define source-name
    (cond
      [(resolved-module-path? source) (resolved-module-path-name source)]
      [(path-string? source) source]
      [else #f]))
  (or (eq? source-name 'webracket/contract)
      (and (path-string? source-name)
           (regexp-match? #rx"/webracket/contract[.]rkt$"
                          (path->string (simplify-path source-name))))))

;; contract-relative-module-path->resolved : any/c any/c -> (or/c resolved-module-path? #f)
;;   Map relative contract implementation paths onto seeded synthetic modules.
(define (contract-relative-module-path->resolved module-path source)
  (define key
    (cond
      [(path? module-path) (path->string module-path)]
      [(string? module-path) module-path]
      [else #f]))
  (define maybe-name
    (and key
         (contract-relative-source? source)
         (cond
           [(equal? key "private/base.rkt")
            'racket/contract/private/base]
           [(equal? key "private/arr-i.rkt")
            'racket/contract/private/arr-i]
           [(equal? key "private/arrow-collapsible.rkt")
            'racket/contract/private/arrow-collapsible]
           [(equal? key "private/arrow-common.rkt")
            'racket/contract/private/arrow-common]
           [(equal? key "private/arrow-higher-order.rkt")
            'racket/contract/private/arrow-higher-order]
           [(equal? key "private/arrow-val-first.rkt")
            'racket/contract/private/arrow-val-first]
           [(equal? key "private/blame.rkt")
            'racket/contract/private/blame]
           [(equal? key "private/case-arrow.rkt")
            'racket/contract/private/case-arrow]
           [(equal? key "private/guts.rkt")
            'racket/contract/private/guts]
           [(equal? key "private/list.rkt")
            'racket/contract/private/list]
           [(equal? key "private/misc.rkt")
            'racket/contract/private/misc]
           [(equal? key "private/in.rkt")
            webify-private-in-path/resolved]
           [(or (equal? key "private/in-out.rkt")
                (equal? key "in-out.rkt"))
            webify-private-in-out-path/resolved]
           [(or (equal? key "private/module-boundary-ctc.rkt")
                (equal? key "module-boundary-ctc.rkt"))
            webify-private-module-boundary-ctc-path/resolved]
           [(equal? key "private/object-c-wrapper.rkt")
            'racket/contract/private/object-c-wrapper]
           [(equal? key "private/opt.rkt")
            'racket/contract/private/opt]
           [(equal? key "private/orc.rkt")
            'racket/contract/private/orc]
           [(equal? key "private/prop.rkt")
            'racket/contract/private/prop]
           [else #f])))
  (and maybe-name
       (make-resolved-module-path maybe-name)))

;; resolved-synthetic-module-name : any/c -> (or/c symbol? #f)
;;   Canonicalize resolved host module identities onto seeded synthetic ones.
(define (resolved-synthetic-module-name resolved-name)
  (define (path-matches? rx)
    (and (path-string? resolved-name)
         (regexp-match? rx (path->string (simplify-path resolved-name)))))
  (cond
    [(path-matches? #rx"/racket/format[.]rkt$") 'racket/format]
    [(path-matches? #rx"/webracket/private/format[.]rkt$") 'webracket/private/format]
    [(path-matches? #rx"/webracket/private/in[.]rkt$") 'webracket/private/in]
    [(path-matches? #rx"/webracket/private/in-out[.]rkt$") 'webracket/private/in-out]
    [(path-matches? #rx"/syntax/contract[.]rkt$") 'syntax/contract]
    [(path-matches? #rx"/syntax/srcloc[.]rkt$") 'syntax/srcloc]
    [(path-matches? #rx"/racket/unsafe/undefined[.]rkt$") 'racket/unsafe/undefined]
    [(path-matches? #rx"/racket/contract/private/module-boundary-ctc[.]rkt$")
     'webracket/private/module-boundary-ctc]
    [(path-matches? #rx"/webracket/private/module-boundary-ctc[.]rkt$")
     'webracket/private/module-boundary-ctc]
    [(path-matches? #rx"/racket/contract/private/object-c-wrapper[.]rkt$")
     'racket/contract/private/object-c-wrapper]
    [(path-matches? #rx"/racket/contract/private/arrow-collapsible[.]rkt$")
     'racket/contract/private/arrow-collapsible]
    [(path-matches? #rx"/racket/contract/private/arrow-common[.]rkt$")
     'racket/contract/private/arrow-common]
    [(path-matches? #rx"/racket/contract/private/arrow-higher-order[.]rkt$")
     'racket/contract/private/arrow-higher-order]
    [(path-matches? #rx"/racket/contract/private/arrow-val-first[.]rkt$")
     'racket/contract/private/arrow-val-first]
    [(path-matches? #rx"/racket/contract/private/blame[.]rkt$")
     'racket/contract/private/blame]
    [(path-matches? #rx"/racket/contract/private/case-arrow[.]rkt$")
     'racket/contract/private/case-arrow]
    [(path-matches? #rx"/racket/contract/private/guts[.]rkt$")
     'racket/contract/private/guts]
    [(path-matches? #rx"/racket/contract/private/list[.]rkt$")
     'racket/contract/private/list]
    [(path-matches? #rx"/racket/contract/private/misc[.]rkt$")
     'racket/contract/private/misc]
    [(path-matches? #rx"/racket/contract/private/opt[.]rkt$")
     'racket/contract/private/opt]
    [(path-matches? #rx"/racket/contract/private/orc[.]rkt$")
     'racket/contract/private/orc]
    [(path-matches? #rx"/racket/contract/private/prop[.]rkt$")
     'racket/contract/private/prop]
    [(path-matches? #rx"/racket/contract/private/base[.]rkt$")
     'racket/contract/private/base]
    [(path-matches? #rx"/racket/contract[.]rkt$") 'racket/contract]
    [else #f]))

;; resolved-module-source-path : any/c -> (or/c path-string? #f)
;;   Recover a backing source path for seeded synthetic module identities.
(define (resolved-module-source-path resolved-name)
  (cond
    [(path-string? resolved-name) resolved-name]
    [(memq resolved-name '(racket/contract
                           racket/contract/base
                           racket/contract/combinator
                           racket/contract/region
                           racket/contract/private/base
                           racket/contract/private/arr-i
                           racket/contract/private/arrow-collapsible
                           racket/contract/private/arrow-common
                           racket/contract/private/arrow-higher-order
                           racket/contract/private/arrow-val-first
                           racket/contract/private/blame
                           racket/contract/private/case-arrow
                           racket/contract/private/guts
                           racket/contract/private/list
                           racket/contract/private/misc
                           racket/contract/private/module-boundary-ctc
                           racket/contract/private/object-c-wrapper
                           racket/contract/private/opt
                           racket/contract/private/orc
                           racket/contract/private/prop))
     (path->string webify-contract-path/resolved)]
    [(eq? resolved-name 'webracket/private/module-boundary-ctc)
     (path->string webify-private-module-boundary-ctc-path/resolved)]
    [(memq resolved-name '(racket/format webracket/private/format))
     (path->string webify-private-format-path/resolved)]
    [(eq? resolved-name 'webracket/private/in)
     (path->string webify-private-in-path/resolved)]
    [(eq? resolved-name 'webracket/private/in-out)
     (path->string webify-private-in-out-path/resolved)]
    [(eq? resolved-name 'syntax/contract)
     (path->string webify-syntax-contract-path/resolved)]
    [(eq? resolved-name 'syntax/srcloc)
     (path->string webify-syntax-srcloc-path/resolved)]
    [(eq? resolved-name 'racket/unsafe/undefined)
     (path->string webify-unsafe-undefined-path/resolved)]
    [else #f]))

;; make-webify-contract-erasing-module-name-resolver : [procedure?] -> procedure?
;;   Build a resolver that redirects public contract modules to erased ones.
(define (make-webify-contract-erasing-module-name-resolver
         [base-resolver (current-module-name-resolver)])
  (case-lambda
    [(module-path source syntax load?)
     (cond
       [(contract-module-path? module-path)
        (contract-module-path->resolved module-path)]
       [(contract-relative-module-path->resolved module-path source)
        => values]
       [(syntax-srcloc-module-path? module-path)
        (make-resolved-module-path 'syntax/srcloc)]
       [(staged-format-module-path? module-path)
       (staged-format-module-path->resolved)]
       [(unsafe-undefined-module-path? module-path)
        (make-resolved-module-path 'racket/unsafe/undefined)]
       [else (base-resolver module-path source syntax load?)])]
    [(resolved namespace)
     (define resolved-name
       (cond
         [(resolved-module-path? resolved) (resolved-module-path-name resolved)]
         [else resolved]))
     (define synthetic-name
       (resolved-synthetic-module-name resolved-name))
     (if synthetic-name
         (base-resolver (make-resolved-module-path synthetic-name) namespace)
         (base-resolver resolved namespace))]))

(struct webify-module-extractor-spike
  (name
   directory-keys
   bundle-keys
   bundle-entries
   phase0-imports
   phase0-exports
   phase0-linklet-datum
   manifest-ready?
   notes)
  #:transparent)

(struct webify-module-bundle-entry
  (key
   kind
   imports
   exports
   datum
   value)
  #:transparent)

(struct webify-module-import-map
  (phase0-import-groups
   phase0-structured-import-groups
   phase0-decompiled-import-groups
   module-protocol-import-groups
   unresolved-import-groups
   data-module-path-indexes
   decl-requires-expression
   decl-provides-expression
   decl-phase-to-link-modules-expression
   required-module-candidates
   import-aliases
   require-rename-aliases
   missing-alias-import-groups
  notes)
  #:transparent)

(struct webify-module-provider-cache (fetch-provider table hits misses) #:transparent)
(struct webify-module-export-demand (module exports) #:transparent)
(struct webify-module-export-demand-reason (module export importer import local) #:transparent)
(struct webify-module-provider-discovery-stages
  (discovered-reports resolved-reports inputs timings)
  #:constructor-name make-webify-module-provider-discovery-stages
  #:transparent)
(struct webify-module-provider-discovery-trace-event
  (provider demander depth cached? reason elapsed-ms status)
  #:transparent)
(struct dependency-export-cache
  (rows by-dependency dependency-rank by-export candidates-by-external external-by-dependency exact-by-dependency)
  #:transparent)

;; maybe-decompile-linklet : (or/c procedure? #f)
;;   Use the newer decompiler API when the host Racket provides it.
(define maybe-decompile-linklet
  (dynamic-require 'racket/linklet 'decompile-linklet (lambda () #f)))

;; decompile-linklet-missing-note : string?
;;   Explain the host-Racket requirement without assuming a local ../racket tree.
(define decompile-linklet-missing-note
  (string-append
   "host Racket does not provide decompile-linklet; "
   "use Racket 9.2 or later "
   "(added upstream in racket/racket commit 72b9c65d3f)"))

;; known-module-protocol-imports : (listof symbol?)
;;   Module-layer protocol imports seen in decompiled phase-0 source-module linklets.
(define known-module-protocol-imports
  '(.get-syntax-literal!
    .set-transformer!))

;; key<? : any/c any/c -> boolean?
;;   Sort mixed linklet-directory keys deterministically for spike reports.
(define (key<? a b)
  (string<? (format "~s" a) (format "~s" b)))

;; bundle-entry<? : webify-module-bundle-entry? webify-module-bundle-entry? -> boolean?
;;   Sort bundle entries by their mixed key values.
(define (bundle-entry<? a b)
  (key<? (webify-module-bundle-entry-key a)
         (webify-module-bundle-entry-key b)))

;; validate-source-module! : symbol? any/c -> symbol?
;;   Check the tiny source-module shape accepted by this extractor spike.
(define (validate-source-module! who module-datum)
  (match (if (syntax? module-datum)
             (syntax->datum module-datum)
             module-datum)
    [`(module ,(? symbol? name) ,_language . ,_body)
     name]
    [_
     (raise-arguments-error who
                            "expected a source module datum"
                            "module" module-datum)]))

;; source-module->syntax : any/c -> syntax?
;;   Preserve source context when a caller already has module syntax.
(define (source-module->syntax module)
  (if (syntax? module)
      module
      (datum->syntax #f module)))

;; strip-correlated* : any/c -> any/c
;;   Recursively convert correlated objects to plain datum values.
(define (strip-correlated* v)
  (cond
    [(correlated? v) (strip-correlated* (correlated-e v))]
    [(pair? v)       (cons (strip-correlated* (car v))
                           (strip-correlated* (cdr v)))]
    [(vector? v)     (list->vector (map strip-correlated* (vector->list v)))]
    [else            v]))

;; linklet-datum? : any/c -> boolean?
;;   Check whether v has the linklet datum shape consumed by webify manifests.
(define (linklet-datum? v)
  (match v
    [`(linklet ,importss ,exports . ,body)
     (and (list? importss)
          (list? exports)
          (list? body))]
    [_ #f]))

;; decompile-linklet-datum : linklet? -> (or/c linklet-datum? #f)
;;   Recover a plain datum for a linklet when the host Racket supports it.
(define (decompile-linklet-datum linklet)
  (and maybe-decompile-linklet
       (strip-correlated* (maybe-decompile-linklet linklet))))

;; bundle-value-kind : any/c -> symbol?
;;   Classify one compiled bundle value for extractor reports.
(define (bundle-value-kind value)
  (cond
    [(linklet? value)           'linklet]
    [(linklet-bundle? value)    'bundle]
    [(linklet-directory? value) 'directory]
    [(webify-faslable-correlated-linklet? value) 'faslable-linklet]
    [else                      'metadata]))

;; linklet-datum-imports+exports : any/c -> values
;;   Extract raw imports and exports from a plain linklet datum.
(define (webify-normalize-linklet-exports exports)
  (define who 'webify-normalize-linklet-exports)
  (unless (list? exports)
    (raise-argument-error who "list?" exports))
  (define (normalize-export export)
    (match export
      [(list _internal (? symbol? external)) external]
      [(? symbol? external) external]
      [_
       (raise-arguments-error who
                              "linklet exports must be symbols or internal/external symbol pairs"
                              "export" export)]))
  (map normalize-export exports))

;; linklet-export-descriptors : symbol? (listof any/c) -> (listof (list/c symbol? symbol? any/c))
;;   Decode raw linklet export forms as internal name, external name, and raw form.
(define (linklet-export-descriptors who exports)
  (unless (list? exports)
    (raise-argument-error who "list?" exports))
  (for/list ([export (in-list exports)])
    (match export
      [(list (? symbol? internal) (? symbol? external))
       (list internal external export)]
      [(? symbol? external)
       (list external external export)]
      [_
       (raise-arguments-error who
                              "linklet exports must be symbols or internal/external symbol pairs"
                              "export" export)])))

;; linklet-datum-imports+exports : any/c -> values
;;   Extract raw imports and normalized external exports from a plain linklet datum.
(define (linklet-datum-imports+exports datum)
  (match datum
    [`(linklet ,imports ,exports . ,_body)
     (values imports (webify-normalize-linklet-exports exports))]
    [_ (values #f #f)]))

;; bundle-value->entry : any/c any/c -> webify-module-bundle-entry?
;;   Convert one linklet-bundle hash entry into report data.
(define (bundle-value->entry key value)
  (define datum
    (cond
      [(linklet? value) (decompile-linklet-datum value)]
      [(webify-faslable-correlated-linklet? value)
       (webify-faslable-correlated-linklet->datum value)]
      [else #f]))
  (define-values (datum-imports datum-exports)
    (linklet-datum-imports+exports datum))
  (webify-module-bundle-entry
   key
   (bundle-value-kind value)
   (cond
     [(linklet? value) (linklet-import-variables value)]
     [datum-imports datum-imports]
     [else #f])
   (cond
     [(linklet? value) (linklet-export-variables value)]
     [datum-exports datum-exports]
     [else #f])
   datum
   value))

;; webify-module-bundle-entry-ref : report any/c -> webify-module-bundle-entry?
;;   Look up a bundle entry by key.
(define (webify-module-bundle-entry-ref report key)
  (define who 'webify-module-bundle-entry-ref)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (or (for/first ([entry (in-list (webify-module-extractor-spike-bundle-entries report))]
                  #:when (equal? key (webify-module-bundle-entry-key entry)))
        entry)
      (raise-arguments-error who
                             "bundle entry not found"
                             "key" key
                             "available keys" (webify-module-extractor-spike-bundle-keys report))))

;; maybe-module-bundle-entry-ref : report any/c -> (or/c webify-module-bundle-entry? #f)
;;   Look up an optional bundle entry by key.
(define (maybe-module-bundle-entry-ref report key)
  (for/first ([entry (in-list (webify-module-extractor-spike-bundle-entries report))]
              #:when (equal? key (webify-module-bundle-entry-key entry)))
    entry))

;; webify-module-syntax-literal-provider-name : symbol? -> symbol?
;;   Derive the synthetic per-module syntax-literal provider name.
(define (webify-module-syntax-literal-provider-name name)
  (string->symbol (format "~a:syntax-literals" name)))

;; local-source-module-name? : symbol? -> boolean?
;;   Recognize source modules from probes, as opposed to installed providers.
(define (local-source-module-name? name)
  (not (string-contains? (symbol->string name) "/")))

;; simple-syntax-literal-datum? : any/c -> boolean?
;;   Keep generated syntax-literal providers within WebRacket's quotation
;;   support; complex serialized structs stay unavailable for now.
(define (simple-syntax-literal-datum? v)
  (cond
    [(or (null? v)
         (boolean? v)
         (number? v)
         (symbol? v)
         (keyword? v)
         (char? v)
         (string? v)
         (bytes? v))
     #t]
    [(pair? v)
     (and (simple-syntax-literal-datum? (car v))
          (simple-syntax-literal-datum? (cdr v)))]
    [(vector? v)
     (for/and ([item (in-vector v)])
       (simple-syntax-literal-datum? item))]
    [else #f]))

;; collect-simple-datum->syntax-literals : any/c -> (listof any/c)
;;   Extract eager datum payloads from a stx-data linklet. This is a focused
;;   bridge for source literals like #'(1 2 3); full lazy syntax-literal
;;   instantiation still belongs to the real stx/stx-data linklet path.
(define (collect-simple-datum->syntax-literals datum)
  (define found '())
  (define (walk v)
    (cond
      [(pair? v)
       (when (eq? (car v) '#:datum->syntax)
         (when (pair? (cdr v))
           (set! found (cons (cadr v) found))))
       (walk (car v))
       (walk (cdr v))]
      [(vector? v)
       (for ([item (in-vector v)]
             [i (in-naturals)])
         (when (and (eq? item '#:datum->syntax)
                    (< (add1 i) (vector-length v)))
           (set! found (cons (vector-ref v (add1 i)) found)))
         (walk item))]
      [else (void)]))
  (walk datum)
  (reverse found))

;; webify-module-syntax-literal-input : report -> (or/c webify-module-linklet-input? #f)
;;   Generate a small provider for modules whose stx-data exposes simple
;;   datum->syntax literals that the phase-0 linklet requests by index.
(define (webify-module-syntax-literal-input report)
  (define report-name (webify-module-extractor-spike-name report))
  (define stx-data-entry (maybe-module-bundle-entry-ref report 'stx-data))
  (define literals
    (and (local-source-module-name? report-name)
         stx-data-entry
         (collect-simple-datum->syntax-literals
          (webify-module-bundle-entry-datum stx-data-entry))))
  (and literals
       (pair? literals)
       (let* ([name (webify-module-syntax-literal-provider-name
                     report-name)]
              [body
               (for/foldr ([else-expr #f])
                          ([literal (in-list literals)]
                           [i (in-naturals)])
                 (if (simple-syntax-literal-datum? literal)
                     `(if (= pos ',i)
                          (datum->syntax #f ',literal)
                          ,else-expr)
                     else-expr))])
         (webify-module-linklet-input
          name
          `(linklet () (.get-syntax-literal!)
             (define-values (.get-syntax-literal!)
               (lambda (pos)
                 ,body)))
          '()))))

;; route-syntax-literal-import : linklet-input report -> linklet-input
;;   Point a module's .get-syntax-literal! import at its generated provider
;;   when simple syntax literals were extracted from the same compiled bundle.
(define (route-syntax-literal-import input report)
  (define provider-name (webify-module-syntax-literal-provider-name
                         (webify-module-extractor-spike-name report)))
  (define has-provider?
    (and (webify-module-syntax-literal-input report) #t))
  (if (not has-provider?)
      input
      (webify-module-linklet-input
       (webify-module-linklet-input-name input)
       (webify-module-linklet-input-linklet input)
       (for/list ([import (in-list (webify-module-linklet-input-imports input))])
         (match import
           [`(.get-syntax-literal! ,_provider .get-syntax-literal!)
            `(.get-syntax-literal! ,provider-name .get-syntax-literal!)]
           [_ import])))))

;; normalize-linklet-import-binding : symbol? any/c -> (list/c symbol? symbol?)
;;   Expand decompiled shorthand to the bridge's explicit local/external pair.
(define (normalize-linklet-import-binding who binding)
  (match binding
    [(? symbol? import)
     (list import import)]
    [(list (? symbol? external) (? symbol? local))
     (list local external)]
    [_
     (raise-arguments-error who
                            "linklet imports must be symbols or local/external symbol pairs"
                            "import" binding)]))

;; normalize-linklet-import-group : symbol? any/c -> (listof (list/c symbol? symbol?))
;;   Normalize one decompiled or metadata import group.
(define (normalize-linklet-import-group who group)
  (unless (list? group)
    (raise-arguments-error who
                           "linklet import group must be a list"
                           "group" group))
  (for/list ([binding (in-list group)])
    (normalize-linklet-import-binding who binding)))

;; webify-normalize-linklet-imports : linklet-datum -> linklet-datum
;;   Normalize import shorthand in a decompiled linklet datum.
(define (webify-normalize-linklet-imports linklet)
  (define who 'webify-normalize-linklet-imports)
  (match linklet
    [`(linklet ,importss ,exports . ,body)
     (unless (list? importss)
       (raise-arguments-error who
                              "linklet imports must be a list of import groups"
                              "imports" importss))
     `(linklet ,(for/list ([group (in-list importss)])
                  (normalize-linklet-import-group who group))
        ,exports
        . ,body)]
    [_
     (raise-arguments-error who
                            "expected a linklet datum"
                            "linklet" linklet)]))

;; webify-linklet-import-bindings : linklet-datum -> (listof (list/c symbol? symbol?))
;;   Return normalized local/external bindings from a linklet datum.
(define (webify-linklet-import-bindings linklet)
  (match (webify-normalize-linklet-imports linklet)
    [`(linklet ,importss ,_exports . ,_body)
     (define bindings
       (for*/list ([group   (in-list importss)]
                   [binding (in-list group)])
         binding))
     (define seen (make-hasheq))
     (reverse
      (for/fold ([acc '()]) ([binding (in-list bindings)])
        (match-define (list local external) binding)
        (define prior (hash-ref seen local #f))
        (cond
          [(not prior)
           (hash-set! seen local external)
           (cons binding acc)]
          [(symbolic-name=? prior external) acc]
          [else
           (raise-arguments-error 'webify-linklet-import-bindings
                                  "conflicting duplicate linklet import names are not supported"
                                  "import" local
                                  "first external" prior
                                  "second external" external)])))]))

;; module-protocol-import-binding? : (list/c symbol? symbol?) -> boolean?
;;   Recognize imports currently supplied only by Racket's module protocol.
(define (module-protocol-import-binding? binding)
  (memq (cadr binding) known-module-protocol-imports))

;; linklet-body-definition-expression : linklet-datum symbol? -> any/c
;;   Find the expression for a single-value definition in a decompiled linklet body.
(define (linklet-body-definition-expression linklet id)
  (match linklet
    [`(linklet ,_imports ,_exports . ,body)
     (for/first ([form (in-list body)]
                 #:when (match form
                          [`(define-values (,defined-id) ,_expr)
                           (eq? defined-id id)]
                          [_ #f]))
       (match form
         [`(define-values (,_defined-id) ,expr) expr]))]
    [_ #f]))

;; data-linklet-module-path-indexes : (or/c linklet-datum? #f) -> any/c
;;   Extract the serialized module-path-index seed vector from a data linklet.
(define (data-linklet-module-path-indexes data-linklet)
  (and data-linklet
       (match (linklet-body-definition-expression data-linklet '.mpi-vector)
         [`(deserialize-module-path-indexes ',mpi-vector ',_self-vector)
          mpi-vector]
         [_ #f])))

;; module-path-index->dependency-name : any/c -> (or/c symbol? #f)
;;   Convert a simple quoted module-path vector into a registry dependency name.
(define (module-path-index->dependency-name mpi)
  (cond
    [(and (vector? mpi)
          (positive? (vector-length mpi))
          (for/and ([part (in-vector mpi)])
            (symbol? part)))
     (string->symbol
      (string-join
       (for/list ([part (in-vector mpi)])
         (symbol->string part))
       "/"))]
    [(symbol? mpi) mpi]
    [else #f]))

;; module-path->dependency-name : any/c -> symbol?
;;   Convert a simple module path to the registry dependency name convention.
(define (module-path->dependency-name module-path)
  (define (path->dependency-name path)
    (define text (path->string path))
    (string->symbol
     (if (string-suffix? text ".rkt")
         (substring text 0 (- (string-length text) 4))
         text)))
  (cond
    [(symbol? module-path) module-path]
    [(path? module-path)
     (path->dependency-name module-path)]
    [(and (list? module-path)
          (eq? (car module-path) 'file)
          (= (length module-path) 2)
          (or (string? (cadr module-path))
              (path? (cadr module-path))))
     (define raw-path (cadr module-path))
     (path->dependency-name
      (if (path? raw-path)
          raw-path
          (string->path raw-path)))]
    [(and (list? module-path)
          (eq? (car module-path) 'submod)
          (pair? (cdr module-path))
          (andmap symbol? (cddr module-path)))
     (string->symbol
      (string-append
       (symbol->string (module-path->dependency-name (cadr module-path)))
       "/"
       (string-join (map symbol->string (cddr module-path)) "/")))]
    [(and (list? module-path)
          (eq? (car module-path) 'lib)
          (pair? (cdr module-path))
          (string? (cadr module-path)))
     (define path (cadr module-path))
     (define no-suffix
       (if (string-suffix? path ".rkt")
           (substring path 0 (- (string-length path) 4))
           path))
     (string->symbol no-suffix)]
    [else
     (raise-arguments-error 'webify-module-path->extractor-spike
                            "expected a simple module path"
                            "module path" module-path)]))

;; slash-symbol->submodule-candidates : symbol? -> (listof module-path?)
;;   Interpret slash-separated dependency names as possible root/submodule paths.
(define (slash-symbol->submodule-candidates module-path)
  (define parts (string-split (symbol->string module-path) "/"))
  (cond
    [(< (length parts) 2) '()]
    [else
     (for/list ([root-count (in-range (sub1 (length parts)) 0 -1)])
       (define root
         (string->symbol
          (string-join (take parts root-count) "/")))
       (define submodules
         (map string->symbol (drop parts root-count)))
       `(submod ,root ,@submodules))]))

;; relative-module-name : symbol? string? -> symbol?
;;   Resolve a relative module path from compiled metadata against a module name.
(define (relative-module-name base-name relative-path)
  (define (collapse-parts parts)
    (let loop ([parts parts] [acc '()])
      (match parts
        ['() (reverse acc)]
        [(cons "." more)
         (loop more acc)]
        [(cons ".." more)
         (loop more (if (null? acc) acc (cdr acc)))]
        [(cons part more)
         (loop more (cons part acc))])))
  (define base-parts (string-split (symbol->string base-name) "/"))
  (define base-dir (reverse (cdr (reverse base-parts))))
  (define relative-parts
    (filter (lambda (part) (not (string=? part "")))
            (string-split relative-path "/")))
  (define parts (collapse-parts (append base-dir relative-parts)))
  (define last-part (car (reverse parts)))
  (define last-no-suffix
    (if (string-suffix? last-part ".rkt")
        (substring last-part 0 (- (string-length last-part) 4))
        last-part))
  (string->symbol
   (string-join (append (reverse (cdr (reverse parts)))
                        (list last-no-suffix))
                "/")))

;; mpi-index->dependency-name : vector? exact-nonnegative-integer? symbol? -> (or/c symbol? #f)
;;   Resolve a module-path index from compiled metadata when the shape is simple.
(define (mpi-index->dependency-name mpi-vector idx self-name)
  (define resolving (make-hasheqv))
  (define resolved  (make-hasheqv))
  (define (resolve-index idx)
    (cond
      [(hash-has-key? resolved idx) (hash-ref resolved idx)]
      [(hash-has-key? resolving idx) #f]
      [(and (vector? mpi-vector)
            (< idx (vector-length mpi-vector)))
       (hash-set! resolving idx #t)
       (define name (resolve (vector-ref mpi-vector idx)))
       (hash-remove! resolving idx)
       (hash-set! resolved idx name)
       name]
      [else #f]))
  (define (resolve mpi)
    (cond
      [(and (box? mpi) (symbol? (unbox mpi))) self-name]
      [(and (vector? mpi)
            (= (vector-length mpi) 2)
            (exact-nonnegative-integer? (vector-ref mpi 1)))
       (define path-spec (vector-ref mpi 0))
       (cond
         [(string? path-spec)
          (define parent-idx (vector-ref mpi 1))
          (define parent-name
            (and (not (eqv? parent-idx idx))
                 (resolve-index parent-idx)))
          (relative-module-name (or parent-name self-name) path-spec)]
         [else
          (with-handlers ([exn:fail? (lambda (_exn) #f)])
            (module-path->dependency-name path-spec))])]
      [(symbol? mpi) mpi]
      [else (module-path-index->dependency-name mpi)]))
  (and (vector? mpi-vector)
       (< idx (vector-length mpi-vector))
       (resolve-index idx)))

;; phase-to-link-modules-candidates : any/c any/c symbol? -> (listof (list/c exact-integer? symbol?))
;;   Decode simple phase-to-link-modules expressions into candidate dependencies.
(define (phase-to-link-modules-candidates expr mpi-vector self-name)
  (define (mpi-ref idx)
    (and (exact-nonnegative-integer? idx)
         (or (and (vector? mpi-vector)
                  (< idx (vector-length mpi-vector))
                  (or (module-path-index->dependency-name (vector-ref mpi-vector idx))
                      (mpi-index->dependency-name mpi-vector idx self-name)))
             #f)))
  (define (decode-module-use use)
    (match use
      [`(module-use (unsafe-vector*-ref .mpi-vector ,idx) ,_phase)
       (mpi-ref idx)]
      [_ #f]))
  (define (decode-use-list uses)
    (match uses
      [`(list ,use ...)
       (filter values (map decode-module-use use))]
      [_ '()]))
  (match expr
    [`(hasheqv ,items ...)
     (let loop ([items items]
                [candidates '()])
       (match items
         ['() (reverse candidates)]
         [(list* (? exact-integer? phase) uses rest)
          (loop rest
                (append
                 (for/list ([name (in-list (decode-use-list uses))])
                   (list phase name))
                 candidates))]
         [_ (reverse candidates)]))]
    [_ '()]))

;; data-module-path-index-candidates : any/c symbol? -> (listof (list/c 0 symbol?))
;;   Fall back to phase-0 provider candidates from all simple serialized MPIs.
(define (data-module-path-index-candidates mpi-vector self-name)
  (define (candidate? name)
    (and name
         (not (eq? name self-name))
         (not (memq name '(racket/base racket/private/base #%unsafe)))))
  (cond
    [(not (vector? mpi-vector)) '()]
    [else
     (remove-duplicates
      (filter
       values
       (for/list ([idx (in-range (vector-length mpi-vector))])
         (define name (mpi-index->dependency-name mpi-vector idx self-name))
         (and (candidate? name) (list 0 name)))))]))

;; generated-import-name? : symbol? -> boolean?
;;   Heuristically recognize generated internal import names in decompiled linklets.
(define (generated-import-name? name)
  (and (symbol? name)
       (regexp-match? #rx"[.][0-9]+$" (symbol->string name))))

;; generated-base-name : symbol? -> string?
;;   Strip Racket's generated numeric suffix from a decompiled linklet name.
(define (generated-base-name name)
  (define without-prefix (regexp-replace #rx"^[0-9]+/" (symbol->string name) ""))
  (regexp-replace #rx"[0-9]*[.][0-9]+$" without-prefix ""))

;; symbolic-name=? : symbol? symbol? -> boolean?
;;   Match generated symbols that print the same but are not necessarily eq?.
(define (symbolic-name=? a b)
  (and (symbol? a)
       (symbol? b)
       (or (eq? a b)
           (string=? (symbol->string a) (symbol->string b))
           (string=? (generated-base-name a) (generated-base-name b))
           (string=? (generated-base-name a) (symbol->string b))
           (string=? (symbol->string a) (generated-base-name b)))))

;; dependency-export-key-symbols : symbol? -> (listof symbol?)
;;   Return exact and generated-base lookup keys for dependency export matching.
(define (dependency-export-key-symbols name)
  (remove-duplicates
   (list name
         (string->symbol (symbol->string name))
         (string->symbol (generated-base-name name)))
   eq?))

;; phase0-import-groups : webify-module-extractor-spike? -> import-groups
;;   Return normalized phase-0 import groups from metadata.
(define (phase0-import-groups report)
  (for/list ([group (in-list (webify-module-extractor-spike-phase0-imports report))])
    (normalize-linklet-import-group 'webify-module-extractor-spike-import-map group)))

;; linklet-datum-import-groups : linklet-datum -> import-groups
;;   Return normalized import groups from a decompiled linklet datum.
(define (linklet-datum-import-groups linklet)
  (match (webify-normalize-linklet-imports linklet)
    [`(linklet ,importss ,_exports . ,_body) importss]))

;; protocol-import-group? : import-group -> boolean?
;;   Check whether every binding in a group is supplied by the module protocol.
(define (protocol-import-group? group)
  (and (pair? group)
       (andmap module-protocol-import-binding? group)))

;; import-group-needs-alias-evidence? : import-group -> boolean?
;;   Detect groups whose names look internalized and need deeper decl decoding.
(define (import-group-needs-alias-evidence? group)
  (for/or ([binding (in-list group)])
    (match-define (list local external) binding)
    (or (not (eq? local external))
        (generated-import-name? local)
        (generated-import-name? external))))

(define keyword-runtime-import-names
  '(keyword-apply
    keyword-procedure-extract
    make-keyword-procedure
    procedure-reduce-keyword-arity
    procedure-reduce-keyword-arity-mask
    struct:keyword-procedure
    struct:keyword-procedure/arity-error
    struct:keyword-method
    struct:keyword-method/arity-error
    new-keyword-apply
    procedure-keywords
    make-optional-keyword-procedure
    make-optional-keyword-method
    make-required-keyword-method/arity-error))

;; keyword-runtime-import-group? : import-group -> boolean?
;;   Recognize the helper group generated by keyword lambdas.
(define (keyword-runtime-import-group? group)
  (and (pair? group)
       (for/and ([binding (in-list group)])
         (match-define (list _local external) binding)
         (memq external keyword-runtime-import-names))))

;; import-group->keyword-runtime-aliases : import-group -> (or/c aliases #f)
;;   Map expander-generated keyword helper imports to WebRacket's staged provider.
(define (import-group->keyword-runtime-aliases group)
  (and (keyword-runtime-import-group? group)
       (for/list ([binding (in-list group)])
         (match-define (list local external) binding)
         (list local 'webracket/private/kw external))))

;; import-group->staged-read-aliases : symbol? import-group -> (or/c aliases #f)
;;   Supply hand-authored provider aliases for staged expander/read helpers
;;   whose compiled metadata keeps only generated local names.
(define (import-group->staged-read-aliases module-name group)
  (define (single-binding-names group)
    (and (pair? group)
         (null? (cdr group))
         (let ([binding (car group)])
           (and (pair? binding)
                (pair? (cdr binding))
                (null? (cddr binding))
                (let ([local (car binding)]
                      [external (cadr binding)])
                  (and (symbol? local)
                       (symbol? external)
                       (list local external)))))))
  (define names (single-binding-names group))
  (define (symbol-string=? a b)
    (and (symbol? a)
         (symbol? b)
         (string=? (symbol->string a) (symbol->string b))))
  (cond
    [(and (memq module-name '(racket-src/expander/read/vector
                              racket-src/expander/read/vector.rkt))
          names
          (symbol-string=? (car names) 'not-an-fX.1)
          (symbol-string=? (cadr names) 'not-an-fX.1))
     (list (list (car names) 'racket/fixnum (cadr names)))]
    [(and (memq module-name '(racket-src/expander/read/vector
                              racket-src/expander/read/vector.rkt))
          names
          (symbol-string=? (car names) '1/not-an-fX.1)
          (symbol-string=? (cadr names) 'not-an-fX.1))
     (list (list (car names) 'racket/flonum (cadr names)))]
    [else #f]))

;; import-group->aliases : import-group candidates -> (or/c aliases #f)
;;   Infer aliases only for one clear phase-0 dependency and non-generated export names.
(define (import-group->aliases group required-module-candidates)
  (define phase0-candidates
    (for/list ([candidate (in-list required-module-candidates)]
               #:when (= 0 (car candidate)))
      (cadr candidate)))
  (and (= 1 (length phase0-candidates))
       (for/and ([binding (in-list group)])
         (match-define (list local external) binding)
         (and (not (eq? local external))
              (not (generated-import-name? external))))
       (for/list ([binding (in-list group)])
         (match-define (list local external) binding)
         (list local (car phase0-candidates) external))))

;; import-group->require-rename-aliases : import-group rename-specs -> aliases
;;   Use compiled provide metadata to connect local imports to provider exports.
(define (import-group->require-rename-aliases group compiled-rename-specs)
  (for*/list ([binding (in-list group)]
              #:do [(match-define (list local external) binding)]
              [rename-spec (in-list compiled-rename-specs)]
              #:do [(match-define (list local-name maybe-dependency provider-export) rename-spec)]
              #:when (symbolic-name=? external local-name))
    (if maybe-dependency
        (list local maybe-dependency provider-export)
        (list local provider-export))))

;; compiled-requires-provider-order : any/c any/c symbol? -> (listof symbol?)
;;   Decode the source-order phase-0 providers from serialized require metadata.
(define (compiled-requires-provider-order requires-expr mpi-vector self-name)
  (define flat (flatten-datum requires-expr))
  (let loop ([items flat]
             [providers '()])
    (match items
      ['() (reverse providers)]
      [(list* '#:mpi (? exact-nonnegative-integer? idx) more)
       (define dependency (mpi-index->dependency-name mpi-vector idx self-name))
       (loop more (if dependency (cons dependency providers) providers))]
      [(cons _ more) (loop more providers)])))

;; require-order-provider? : symbol? symbol? -> boolean?
;;   Keep only providers that can plausibly correspond to unresolved import groups.
(define (require-order-provider? self-name name)
  (and (symbol? name)
       (not (eq? name self-name))
       (not (memq name '(webracket/base racket/base racket/private/base)))
       (not (regexp-match? #rx"^racket/private/" (symbol->string name)))))

;; require-order-package-provider? : symbol? -> boolean?
;;   Recognize package/library facades outside the core Racket/WebRacket families.
(define (require-order-package-provider? name)
  (define text (symbol->string name))
  (not (or (regexp-match? #rx"^racket/" text)
           (regexp-match? #rx"^webracket/" text)
           (regexp-match? #rx"^#%" text))))

;; import-groups->require-order-aliases : import-groups providers symbol? -> aliases
;;   Use require provider order when it can disambiguate one import group per provider.
(define (import-groups->require-order-aliases groups provider-order self-name)
  (define providers
    (filter (lambda (name) (require-order-provider? self-name name))
            provider-order))
  (define group-signatures
    (for/list ([group (in-list groups)])
      (for/list ([binding (in-list group)])
        (cadr binding))))
  (define singleton-groups?
    (for/and ([signature (in-list group-signatures)])
      (null? (cdr signature))))
  (cond
    [(and (= (length groups) (length providers))
          (for/or ([provider (in-list providers)])
            (require-order-package-provider? provider))
          (or (check-duplicates group-signatures equal?)
              singleton-groups?))
     (append*
      (for/list ([group (in-list groups)]
                 [provider (in-list providers)])
        (for/list ([binding (in-list group)])
          (match-define (list local external) binding)
          (list local provider external))))]
    [else '()]))

;; import-groups->require-order-coverage-aliases : import-groups providers dependency-export-cache? imports symbol? -> aliases
;;   Align source-order providers with import groups when export coverage validates the match.
(define (import-groups->require-order-coverage-aliases groups
                                                       provider-order
                                                       dependency-cache
                                                       explicit-locals
                                                       self-name)
  (define providers
    (filter (lambda (name) (require-order-provider? self-name name))
            provider-order))
  (define (provider-covers-group? provider group)
    (for/and ([binding (in-list group)])
      (match-define (list _local external) binding)
      (dependency-export-cache-has-external?
       dependency-cache
       provider
       external)))
  (define (group->aliases group provider)
    (for/list ([binding (in-list group)]
               #:unless (memq (car binding) explicit-locals))
      (match-define (list local external) binding)
      (list local provider external)))
  (let loop ([groups groups]
             [providers providers]
             [aliases-reverse '()])
    (cond
      [(null? providers)
       (reverse aliases-reverse)]
      [(null? groups)
       '()]
      [else
       (define group (car groups))
       (define provider (car providers))
       (cond
         [(provider-covers-group? provider group)
          (loop (cdr groups)
                (cdr providers)
                (append (reverse (group->aliases group provider))
                        aliases-reverse))]
         [(import-group-needs-alias-evidence? group)
          '()]
         [else
          (loop (cdr groups) providers aliases-reverse)])])))

;; flatten-datum : any/c -> list?
;;   Flatten a datum/vector tree in source order for simple serialized metadata scans.
(define (flatten-datum v)
  (cond
    [(pair? v)   (append (flatten-datum (car v))
                         (flatten-datum (cdr v)))]
    [(vector? v) (append* (map flatten-datum (vector->list v)))]
    [(null? v)   '()]
    [else        (list v)]))

;; compiled-module-binding-rename-specs : any/c (or/c vector? #f) symbol? -> (listof list?)
;;   Decode provider-export aliases from serialized `provides` module-binding records.
(define (compiled-module-binding-rename-specs provides-expr mpi-vector self-name)
  (define flat (flatten-datum provides-expr))
  (define (first-mpi-index rest)
    (match rest
      [(list* (? keyword? kw) (? exact-nonnegative-integer? idx) more)
       (if (eq? kw '#:mpi)
           idx
           (first-mpi-index more))]
      [(cons _ more) (first-mpi-index more)]
      [_ #f]))
  (define (provider-export-after-module-binding rest)
    (match rest
      [(list* (? symbol? provider-export)
              (? exact-integer?)
              #f
              #f
              _)
       provider-export]
      [(cons _ more) (provider-export-after-module-binding more)]
      [_ #f]))
  (let loop ([items flat]
             [specs '()])
    (match items
      ['() (reverse specs)]
      [(list* (? symbol? local-name) '#:module-binding rest)
       (define provider-export (provider-export-after-module-binding rest))
       (define dependency
         (let ([idx (first-mpi-index rest)])
           (and idx (mpi-index->dependency-name mpi-vector idx self-name))))
       (loop rest
             (if (and provider-export
                      (not (symbolic-name=? local-name provider-export)))
                 (cons (list local-name dependency provider-export) specs)
                 specs))]
      [(cons _ more) (loop more specs)])))

;; compiled-provides-provider-aliases : any/c any/c symbol? symbol? -> aliases
;;   Decode backing providers for a public name from serialized provide metadata.
(define (compiled-provides-provider-aliases provides-expr mpi-vector self-name exported-name)
  (define flat (flatten-datum provides-expr))
  (define (binding-provider rest)
    (match rest
      [(list* (or '#:simple-module-binding '#:module-binding)
              '#:mpi
              (? exact-nonnegative-integer? idx)
              (? symbol? provider-export)
              _)
       (define dependency (mpi-index->dependency-name mpi-vector idx self-name))
       (and dependency (list dependency provider-export))]
      [(cons _ more) (binding-provider more)]
      [_ #f]))
  (let loop ([items flat]
             [aliases '()])
    (match items
      ['() (reverse aliases)]
      [(list* (? symbol? local-name) rest)
       (define alias (and (symbolic-name=? local-name exported-name)
                          (binding-provider rest)))
       (loop rest (if alias (cons alias aliases) aliases))]
      [(cons _ more) (loop more aliases)])))

;; make-dependency-export-cache : dependency-exports -> dependency-export-cache?
;;   Build reusable lookup state for repeated provider export scans.
(define (make-dependency-export-cache dependency-exports)
  (define by-dependency
    (for/hasheq ([entry (in-list dependency-exports)])
      (match-define (list dependency exports) entry)
      (values dependency exports)))
  (define dependency-rank
    (for/hasheq ([entry (in-list dependency-exports)]
                 [rank (in-naturals)])
      (match-define (list dependency _exports) entry)
      (values dependency rank)))
  (dependency-export-cache
   dependency-exports
   by-dependency
   dependency-rank
   (make-dependency-export-reverse-cache dependency-exports)
   (make-hasheq)
   (make-hash)
   (make-hash)))

;; make-dependency-export-reverse-cache : dependency-exports -> hasheq?
;;   Index export-name variants to dependency modules in original row order.
(define (make-dependency-export-reverse-cache dependency-exports)
  (define by-export (make-hasheq))
  (for ([entry (in-list dependency-exports)])
    (match-define (list dependency exports) entry)
    (define seen-keys (make-hasheq))
    (for* ([export (in-list exports)]
           [key (in-list (dependency-export-key-symbols export))]
           #:unless (hash-has-key? seen-keys key))
      (hash-set! seen-keys key #t)
      (hash-update! by-export key (lambda (dependencies)
                                    (cons dependency dependencies))
                    '())))
  (for/hasheq ([(key dependencies) (in-hash by-export)])
    (values key (reverse dependencies))))

;; dependency-export-cache-exports : dependency-export-cache? symbol? -> (or/c list? #f)
;;   Look up the export list for one dependency.
(define (dependency-export-cache-exports cache dependency)
  (hash-ref (dependency-export-cache-by-dependency cache) dependency #f))

;; dependency-export-cache-has-external? : dependency-export-cache? symbol? symbol? -> boolean?
;;   Check symbolic export membership and memoize the dependency/external pair.
(define (dependency-export-cache-has-external? cache dependency external)
  (hash-ref!
   (dependency-export-cache-external-by-dependency cache)
   (list dependency external)
   (lambda ()
     (define exports (dependency-export-cache-exports cache dependency))
     (and exports
          (for/or ([export (in-list exports)])
            (symbolic-name=? export external))))))

;; dependency-export-cache-has-exact-external? : dependency-export-cache? symbol? symbol? -> boolean?
;;   Check exact export membership and memoize the dependency/external pair.
(define (dependency-export-cache-has-exact-external? cache dependency external)
  (hash-ref!
   (dependency-export-cache-exact-by-dependency cache)
   (list dependency external)
   (lambda ()
     (define exports (dependency-export-cache-exports cache dependency))
     (and exports (memq external exports) #t))))

;; dependency-export-cache-candidates : dependency-export-cache? symbol? -> (listof symbol?)
;;   Find provider rows with an export symbolically matching external.
(define (dependency-export-cache-candidates cache external)
  (hash-ref!
   (dependency-export-cache-candidates-by-external cache)
   external
   (lambda ()
     (define seen (make-hasheq))
     (define rough-candidates
       (for*/fold ([candidates '()])
                  ([key (in-list (dependency-export-key-symbols external))]
                   [dependency (in-list
                                (hash-ref (dependency-export-cache-by-export cache)
                                          key
                                          '()))]
                   #:unless (hash-has-key? seen dependency))
         (hash-set! seen dependency #t)
         (cons dependency candidates)))
     (sort
      (filter (lambda (dependency)
                (dependency-export-cache-has-external? cache dependency external))
              rough-candidates)
      <
      #:key (lambda (dependency)
              (hash-ref (dependency-export-cache-dependency-rank cache)
                        dependency
                        +inf.0))))))

;; dependency-export-cache-dependencies : dependency-export-cache? -> (listof symbol?)
;;   Return provider module names in dependency export row order.
(define (dependency-export-cache-dependencies cache)
  (for/list ([row (in-list (dependency-export-cache-rows cache))])
    (car row)))

;; resolve-compiled-rename-aliases : aliases dependency-export-cache? -> aliases
;;   Fill provider modules for compiled rename aliases using cached provider export rows.
(define (resolve-compiled-rename-aliases aliases dependency-cache)
  (filter
   values
   (for/list ([alias (in-list aliases)])
    (define local (car alias))
    (define provider-export
      (match alias
        [(list _ export) export]
        [(list _ _ export) export]))
    (define maybe-direct-dependency
      (match alias
        [(list _ (? symbol? dependency) _) dependency]
        [_ #f]))
    (define matches
      (cond
        [maybe-direct-dependency
         (if (dependency-export-cache-has-external? dependency-cache
                                                    maybe-direct-dependency
                                                    provider-export)
             (list (list maybe-direct-dependency provider-export))
             '())]
        [else
         (for/list ([dependency (in-list (dependency-export-cache-candidates
                                          dependency-cache
                                          provider-export))])
           (list dependency provider-export))]))
    (match matches
      [(list (list dependency provider-export))
       (list local dependency provider-export)]
      [_ #f]))))

;; import-groups->alias-complement-aliases : import-groups candidates dependency-export-cache? aliases imports -> aliases
;;   Resolve unaliased duplicate exports when existing aliases leave exactly one provider unused.
(define (import-groups->alias-complement-aliases groups
                                                 required-module-candidates
                                                 dependency-cache
                                                 known-aliases
                                                 explicit-locals)
  (define phase0-modules
    (remove-duplicates
     (for/list ([candidate (in-list required-module-candidates)]
                #:when (= 0 (car candidate)))
       (cadr candidate))
     eq?))
  (define (candidate-modules external)
    (for/list ([module (in-list phase0-modules)]
               #:when (dependency-export-cache-has-external?
                       dependency-cache
                       module
                       external))
      module))
  (define used-modules
    (remove-duplicates
     (for/list ([alias (in-list known-aliases)])
       (match-define (list _local dependency _provider-export) alias)
       dependency)
     eq?))
  (filter
   values
   (for*/list ([group (in-list groups)]
               [binding (in-list group)])
     (match-define (list local external) binding)
     (cond
       [(memq local explicit-locals) #f]
       [else
        (define remaining
          (filter (lambda (module)
                    (not (memq module used-modules)))
                  (candidate-modules external)))
        (match remaining
          [(list dependency)
           (list local dependency external)]
          [_ #f])]))))

;; import-groups->provider-coverage-aliases : import-groups candidates dependency-export-cache? imports -> aliases
;;   Resolve a whole import group when exactly one required provider exports every name in the group.
(define (import-groups->provider-coverage-aliases groups
                                                  required-module-candidates
                                                  dependency-cache
                                                  explicit-locals
                                                  #:candidate-cache [candidate-cache dependency-cache]
                                                  #:self-name [self-name #f])
  (define required-phase0-modules
    (remove-duplicates
     (for/list ([candidate (in-list required-module-candidates)]
                #:when (= 0 (car candidate)))
       (cadr candidate))
     eq?))
  (define phase0-modules
    (remove-duplicates
     (append required-phase0-modules
             (filter (lambda (dependency)
                       (not (eq? dependency self-name)))
                     (dependency-export-cache-dependencies candidate-cache)))
     eq?))
  (define (unresolved-bindings group)
    (filter (lambda (binding) (not (memq (car binding) explicit-locals)))
            group))
  (define (binding-signature bindings)
    (for/list ([binding (in-list bindings)])
      (cadr binding)))
  (define (covering-modules bindings)
    (for/list ([module (in-list phase0-modules)]
               #:when (for/and ([binding (in-list bindings)])
                        (match-define (list _local external) binding)
                        (dependency-export-cache-has-external?
                         dependency-cache
                         module
                         external)))
      module))
  (define duplicate-signature-counts
    (for/fold ([counts (hash)]) ([group (in-list groups)])
      (define bindings (unresolved-bindings group))
      (define modules (covering-modules bindings))
      (if (and (pair? bindings) (pair? modules) (pair? (cdr modules)))
          (hash-update counts (binding-signature bindings) add1 0)
          counts)))
  (define duplicate-signature-indexes (make-hash))
  (define (duplicate-ordered-module bindings modules)
    (define signature (binding-signature bindings))
    (define count (hash-ref duplicate-signature-counts signature 0))
    (and (> count 1)
         (>= (length modules) count)
         (let ([idx (hash-ref duplicate-signature-indexes signature 0)])
           (hash-set! duplicate-signature-indexes signature (add1 idx))
           (and (< idx (length modules))
                (list-ref modules idx)))))
  (define (bindings->aliases bindings module)
    (for/list ([binding (in-list bindings)])
      (match-define (list local external) binding)
      (list local module external)))
  (append*
   (for/list ([group (in-list groups)])
     (define group-bindings (unresolved-bindings group))
     (cond
       [(null? group-bindings) '()]
       [else
        (define candidate-covering-modules
          (covering-modules group-bindings))
        (match candidate-covering-modules
          [(list module)
           (bindings->aliases group-bindings module)]
          [_
           (define ordered-module
             (duplicate-ordered-module group-bindings candidate-covering-modules))
           (if ordered-module
               (bindings->aliases group-bindings ordered-module)
               '())])]))))

;; webify-module-extractor-spike-import-map : report -> webify-module-import-map?
;;   Build an observational import-map report from phase-0, data, and decl linklets.
(define (webify-module-extractor-spike-import-map report)
  (define who 'webify-module-extractor-spike-import-map)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (define structured-import-groups (phase0-import-groups report))
  (define decompiled-import-groups
    (cond
      [(webify-module-extractor-spike-phase0-linklet-datum report)
       (linklet-datum-import-groups
        (webify-module-extractor-spike-phase0-linklet-datum report))]
      [else structured-import-groups]))
  (define import-groups decompiled-import-groups)
  (define protocol-groups (filter protocol-import-group? import-groups))
  (define unresolved-groups (filter (lambda (group)
                                      (not (protocol-import-group? group)))
                                    import-groups))
  (define data-entry (maybe-module-bundle-entry-ref report 'data))
  (define decl-entry (maybe-module-bundle-entry-ref report 'decl))
  (define data-linklet (and data-entry (webify-module-bundle-entry-datum data-entry)))
  (define decl-linklet (and decl-entry (webify-module-bundle-entry-datum decl-entry)))
  (define data-module-path-indexes (data-linklet-module-path-indexes data-linklet))
  (define decl-requires-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'requires)))
  (define decl-provides-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'provides)))
  (define decl-phase-to-link-modules-expression
    (and decl-linklet (linklet-body-definition-expression decl-linklet 'phase-to-link-modules)))
  (define hinted-required-module-candidates
    (remove-duplicates
     (filter
      values
      (for*/list ([group (in-list unresolved-groups)]
                  [binding (in-list group)])
        (match-define (list local external) binding)
        (match (compiled-primitive-alias-hint
                (webify-module-extractor-spike-name report)
                local
                external)
          [(list dependency _provider-export)
           (list 0 dependency)]
          [_ #f])))
     equal?))
  (define required-module-candidates
    (remove-duplicates
     (append
      (phase-to-link-modules-candidates
       decl-phase-to-link-modules-expression
       data-module-path-indexes
       (webify-module-extractor-spike-name report))
      (data-module-path-index-candidates
       data-module-path-indexes
       (webify-module-extractor-spike-name report))
      hinted-required-module-candidates
      (if (ormap keyword-runtime-import-group? unresolved-groups)
          '((0 webracket/private/kw))
          '()))))
  (define compiled-rename-specs
    (compiled-module-binding-rename-specs
     decl-provides-expression
     data-module-path-indexes
     (webify-module-extractor-spike-name report)))
  (define require-order-aliases
    (import-groups->require-order-aliases
     unresolved-groups
     (compiled-requires-provider-order
      decl-requires-expression
      data-module-path-indexes
      (webify-module-extractor-spike-name report))
     (webify-module-extractor-spike-name report)))
  (define require-rename-aliases
    (apply append
           (for/list ([group (in-list unresolved-groups)])
             (import-group->require-rename-aliases group compiled-rename-specs))))
  (define alias-results
    (for/list ([group (in-list unresolved-groups)])
      (define require-aliases
        (import-group->require-rename-aliases group compiled-rename-specs))
      (cons group
            (and (null? require-aliases)
                 (or (import-group->staged-read-aliases
                      (webify-module-extractor-spike-name report)
                      group)
                     (import-group->keyword-runtime-aliases group)
                     (import-group->aliases group required-module-candidates))))))
  (define import-aliases
    (apply append
           (for/list ([result (in-list alias-results)]
                      #:when (cdr result))
             (cdr result))))
  (define missing-alias-import-groups
    (for/list ([result (in-list alias-results)]
               #:do [(define group (car result))]
               #:when (and (import-group-needs-alias-evidence? group)
                           (not (cdr result))
                           (null? (import-group->require-rename-aliases
                                   group
                                   compiled-rename-specs))))
      group))
  (webify-module-import-map
   import-groups
   structured-import-groups
   decompiled-import-groups
   protocol-groups
   unresolved-groups
   data-module-path-indexes
   decl-requires-expression
   decl-provides-expression
   decl-phase-to-link-modules-expression
   required-module-candidates
   import-aliases
   require-rename-aliases
   missing-alias-import-groups
   (cond
     [(pair? require-rename-aliases)
      '("compiled provide metadata supplies provider export aliases"
        "export tables are still required before resolving imports")]
     [(not decl-linklet)
      '("decl/data metadata is unavailable on this host because linklet decompilation is unavailable")]
     [(pair? missing-alias-import-groups)
      '("phase-0 contains internalized non-protocol import groups"
        "decl/data metadata exposes required-module candidates but not public export aliases"
        "deeper decl deserialization is needed before resolving these imports automatically")]
     [(and (pair? unresolved-groups) (pair? required-module-candidates))
      '("phase-0 contains non-protocol import groups"
        "decl/data metadata provides simple required-module candidates"
        "export tables are still required before resolving imports")]
     [(null? unresolved-groups)
      '("phase-0 imports are limited to known module-protocol imports"
        "decl/data metadata is available for future require decoding")]
     [else
      '("phase-0 contains non-protocol import groups"
        "decl/data metadata likely maps those groups to required modules"
        "this spike reports the raw metadata but does not decode it yet")])))

;; webify-module-import-map-require-provider-order : import-map symbol? -> (listof symbol?)
;;   Recompute the source-order provider list from the compiled require metadata.
(define (webify-module-import-map-require-provider-order import-map self-name)
  (compiled-requires-provider-order
   (webify-module-import-map-decl-requires-expression import-map)
   (webify-module-import-map-data-module-path-indexes import-map)
   self-name))

;; webify-module-import-map-local-provider-order : import-map symbol? -> (listof symbol?)
;;   Return local provider names in module-path-index order when the driver exposes the local graph.
(define (webify-module-import-map-local-provider-order import-map self-name)
  (define local-report-names (current-module-bridge-local-report-names))
  (define mpi-vector
    (webify-module-import-map-data-module-path-indexes import-map))
  (define (path->local-report-name path)
    (define path-text (path->string (simplify-path path)))
    (for/first ([name (in-list (set->list local-report-names))]
                #:do [(define name-text (symbol->string name))]
                #:when (or (string-suffix? path-text
                                           (string-append "/" name-text ".rkt"))
                           (string-suffix? path-text
                                           (string-append "/" name-text))))
      name))
  (define (mpi-index->local-name idx)
    (or (mpi-index->dependency-name mpi-vector idx self-name)
        (match (vector-ref mpi-vector idx)
          [(vector (? path-string? path))
           (path->local-report-name path)]
          [(? path-string? path)
           (path->local-report-name path)]
          [_ #f])))
  (cond
    [(not (and local-report-names (vector? mpi-vector))) '()]
    [else
     (remove-duplicates
      (filter
       values
       (for/list ([idx (in-range (vector-length mpi-vector))])
         (define name (mpi-index->local-name idx))
         (and name
              (not (eq? name self-name))
              (set-member? local-report-names name)
              name)))
      eq?)]))

;; webify-module-import-map-source-provider-order : import-map symbol? -> (listof symbol?)
;;   Prefer precise local graph order, falling back to compiled require metadata.
(define (webify-module-import-map-source-provider-order import-map self-name)
  (define local-order
    (webify-module-import-map-local-provider-order import-map self-name))
  (if (pair? local-order)
      local-order
      (webify-module-import-map-require-provider-order import-map self-name)))

;; webify-module-extractor-spike-required-provider-names : report -> (listof symbol?)
;;   Return phase-0 provider module names decoded from the report's require metadata.
(define (webify-module-extractor-spike-required-provider-names report)
  (define who 'webify-module-extractor-spike-required-provider-names)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define self-name (webify-module-extractor-spike-name report))
  (remove-duplicates
   (append
    (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates
                                    import-map))]
               #:when (= 0 (car candidate))
               #:unless (eq? (cadr candidate) self-name))
      (cadr candidate))
    '())))

;; webify-module-extractor-spike->required-provider-spikes : report -> (listof report)
;;   Compile one-level installed provider reports named by the report's require metadata.
(define (webify-module-extractor-spike->required-provider-spikes report)
  (for/list ([name (in-list (webify-module-extractor-spike-required-provider-names report))])
    (webify-module-path->extractor-spike name)))

;; make-webify-module-provider-cache : [procedure?] -> webify-module-provider-cache?
;;   Create a reusable installed-provider report cache.
(define (make-webify-module-provider-cache [fetch-provider webify-module-path->extractor-spike])
  (unless (procedure? fetch-provider)
    (raise-argument-error 'make-webify-module-provider-cache "procedure?" fetch-provider))
  (webify-module-provider-cache fetch-provider (make-hasheq) (box 0) (box 0)))

;; webify-module-provider-cache-ref : webify-module-provider-cache? symbol? -> report
;;   Fetch and cache an installed-provider report by module name.
(define (webify-module-provider-cache-ref cache name)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-ref
                          "webify-module-provider-cache?"
                          cache))
  (unless (symbol? name)
    (raise-argument-error 'webify-module-provider-cache-ref "symbol?" name))
  (define table (webify-module-provider-cache-table cache))
  (cond
    [(hash-has-key? table name)
     (set-box! (webify-module-provider-cache-hits cache)
               (add1 (unbox (webify-module-provider-cache-hits cache))))
     (hash-ref table name)]
    [else
     (set-box! (webify-module-provider-cache-misses cache)
               (add1 (unbox (webify-module-provider-cache-misses cache))))
     (define report ((webify-module-provider-cache-fetch-provider cache) name))
     (unless (webify-module-extractor-spike? report)
       (raise-arguments-error 'webify-module-provider-cache-ref
                              "provider fetcher did not return an extractor report"
                              "module" name
                              "result" report))
     (unless (eq? name (webify-module-extractor-spike-name report))
       (raise-arguments-error 'webify-module-provider-cache-ref
                              "provider report name does not match requested module"
                              "module" name
                              "report name" (webify-module-extractor-spike-name report)))
     (hash-set! table name report)
     report]))

;; webify-module-provider-cache-hit-count : webify-module-provider-cache? -> exact-nonnegative-integer?
;;   Return the number of provider-cache hits.
(define (webify-module-provider-cache-hit-count cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-hit-count
                          "webify-module-provider-cache?"
                          cache))
  (unbox (webify-module-provider-cache-hits cache)))

;; webify-module-provider-cache-miss-count : webify-module-provider-cache? -> exact-nonnegative-integer?
;;   Return the number of provider-cache misses.
(define (webify-module-provider-cache-miss-count cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-miss-count
                          "webify-module-provider-cache?"
                          cache))
  (unbox (webify-module-provider-cache-misses cache)))

;; webify-module-provider-cache-names : webify-module-provider-cache? -> (listof symbol?)
;;   Return cached module names.
(define (webify-module-provider-cache-names cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-names
                          "webify-module-provider-cache?"
                          cache))
  (sort (hash-keys (webify-module-provider-cache-table cache)) symbol<?))

;; webify-module-provider-cache-count : webify-module-provider-cache? -> exact-nonnegative-integer?
;;   Return the number of cached provider reports.
(define (webify-module-provider-cache-count cache)
  (unless (webify-module-provider-cache? cache)
    (raise-argument-error 'webify-module-provider-cache-count
                          "webify-module-provider-cache?"
                          cache))
  (hash-count (webify-module-provider-cache-table cache)))

;; merge-export-demands : (listof webify-module-export-demand?) -> demands
;;   Combine demand rows for the same provider module.
(define (merge-export-demands demands)
  (define table (make-hasheq))
  (for ([demand (in-list demands)])
    (unless (webify-module-export-demand? demand)
      (raise-argument-error 'merge-export-demands
                            "webify-module-export-demand?"
                            demand))
    (hash-update! table
                  (webify-module-export-demand-module demand)
                  (lambda (exports)
                    (remove-duplicates
                     (append exports
                             (webify-module-export-demand-exports demand))))
                  '()))
  (for/list ([module (in-list (sort (hash-keys table) symbol<?))])
    (webify-module-export-demand module (hash-ref table module))))

;; webify-module-extractor-spike-import-export-demands : report reports ... -> demands
;;   Report the provider exports imported by a resolved linklet input.
(define (webify-module-extractor-spike-import-export-demands report
                                                            provider-reports
                                                            #:provider-dependency-exports
                                                            [precomputed-provider-dependency-exports #f]
                                                            #:dependencies [dependencies '()]
                                                            #:reflection-hints [reflection-hints '()]
                                                            #:module-protocol-dependency [module-protocol-dependency #f])
  (define input
    (webify-module-extractor-spike->resolved-linklet-input/providers
     report
     provider-reports
     #:provider-dependency-exports precomputed-provider-dependency-exports
     #:dependencies dependencies
     #:reflection-hints reflection-hints
     #:module-protocol-dependency module-protocol-dependency))
  (merge-export-demands
   (for/list ([import (in-list (webify-module-linklet-input-imports input))])
     (match-define (list _local dependency provider-export) import)
     (webify-module-export-demand dependency (list provider-export)))))

;; webify-module-extractor-spike-import-export-demand-reasons : report reports ... -> reasons
;;   Explain which imports retain provider exports for demand slicing.
(define (webify-module-extractor-spike-import-export-demand-reasons report
                                                                    provider-reports
                                                                    #:dependencies [dependencies '()]
                                                                    #:reflection-hints [reflection-hints '()]
                                                                    #:module-protocol-dependency [module-protocol-dependency #f])
  (define input
    (webify-module-extractor-spike->resolved-linklet-input/providers
     report
     provider-reports
     #:dependencies dependencies
     #:reflection-hints reflection-hints
     #:module-protocol-dependency module-protocol-dependency))
  (for/list ([import (in-list (webify-module-linklet-input-imports input))])
    (match-define (list local dependency provider-export) import)
    (webify-module-export-demand-reason
     dependency
     provider-export
     (webify-module-extractor-spike-name report)
     local
     local)))

;; remove-bound : (listof symbol?) (listof symbol?) -> (listof symbol?)
;;   Remove locally bound identifiers from a free-variable list.
(define (remove-bound free bound)
  (filter (lambda (id) (not (memq id bound))) free))

;; linklet-expr-free-vars : any/c -> (listof symbol?)
;;   Approximate free variables well enough to slice first-order linklet definitions.
(define (linklet-expr-free-vars expr)
  (define (free expr bound)
    (cond
      [(symbol? expr)
       (if (memq expr bound) '() (list expr))]
      [(or (null? expr) (not (pair? expr))) '()]
      [else
       (match expr
         [`(quote ,_) '()]
         [`(quote-syntax ,_) '()]
         [`(lambda ,formals . ,body)
          (define formal-ids
            (let loop ([formals formals])
              (cond
                [(symbol? formals) (list formals)]
                [(pair? formals)   (cons (car formals) (loop (cdr formals)))]
                [else              '()])))
          (remove-duplicates
           (append* (for/list ([body-expr (in-list body)])
                      (free body-expr (append formal-ids bound)))))]
         [`(case-lambda [,formalss . ,bodiess] ...)
          (remove-duplicates
           (append*
            (for/list ([formals (in-list formalss)]
                       [body    (in-list bodiess)])
              (define formal-ids
                (let loop ([formals formals])
                  (cond
                    [(symbol? formals) (list formals)]
                    [(pair? formals)   (cons (car formals) (loop (cdr formals)))]
                    [else              '()])))
              (append* (for/list ([body-expr (in-list body)])
                         (free body-expr (append formal-ids bound)))))))]
         [`(let-values ,clauses . ,body)
          (define ids
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,ids ...) ,_) ids]
                 [_ '()]))))
          (remove-duplicates
           (append
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,_ids ...) ,rhs) (free rhs bound)]
                 [_ '()])))
            (append*
             (for/list ([body-expr (in-list body)])
               (free body-expr (append ids bound))))))]
         [`(letrec-values ,clauses . ,body)
          (define ids
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,ids ...) ,_) ids]
                 [_ '()]))))
          (define next-bound (append ids bound))
          (remove-duplicates
           (append
            (append*
             (for/list ([clause (in-list clauses)])
               (match clause
                 [`((,_ids ...) ,rhs) (free rhs next-bound)]
                 [_ '()])))
            (append*
             (for/list ([body-expr (in-list body)])
               (free body-expr next-bound)))))]
         [_ (remove-duplicates (append* (map (lambda (part) (free part bound)) expr)))])]))
  (free expr '()))

;; linklet-definition : form -> values
;;   Extract the ids and right-hand side from a define-values form.
(define (linklet-definition form)
  (match form
    [`(define-values (,ids ...) ,rhs)
     (values ids rhs)]
    [_ (values #f #f)]))

;; filter-importss : importss (listof symbol?) -> importss
;;   Keep only raw import bindings whose normalized local name is demanded.
(define (filter-importss importss demanded-imports)
  (define demanded-table
    (for/hasheq ([name (in-list demanded-imports)])
      (values name #t)))
  (filter
   pair?
   (for/list ([group (in-list importss)])
     (filter (lambda (binding)
               (match-define (list local external)
                 (normalize-linklet-import-binding 'filter-importss binding))
               (or (hash-ref demanded-table local #f)
                   (hash-ref demanded-table external #f)))
             group))))

(define unsafe-undefined-import-names
  '(unsafe-undefined
    check-not-unsafe-undefined
    check-not-unsafe-undefined/assign
    prop:chaperone-unsafe-undefined
    chaperone-struct-unsafe-undefined))

(define provider-owned-missing-import-names
  '(format))

;; linklet-import-local-names : importss -> (listof symbol?)
;;   Return the normalized local names already imported by a linklet.
(define (linklet-import-local-names who importss)
  (for*/list ([group   (in-list importss)]
              [binding (in-list group)])
    (car (normalize-linklet-import-binding who binding))))

;; add-missing-imports : importss (listof symbol?) (listof symbol?) -> importss
;;   Repair machine-independent decompile gaps for same-name imports.
(define (add-missing-imports who importss candidate-names needed)
  (define present (linklet-import-local-names who importss))
  (define missing
    (filter (lambda (name)
              (and (memq name needed)
                   (not (memq name present))))
            candidate-names))
  (cond
    [(null? missing) importss]
    [else
     (append importss
             (list
              (for/list ([name (in-list missing)])
                (list name name))))]))

;; generated-effect-definition-name? : symbol? -> boolean?
;;   Recognize module body expressions lowered by webify as effect definitions.
(define (generated-effect-definition-name? name)
  (regexp-match? #rx"^effect[0-9]+$" (symbol->string name)))

;; add-missing-unsafe-undefined-imports : importss (listof symbol?) -> importss
;;   Repair machine-independent decompile gaps for unsafe-undefined imports.
(define (add-missing-unsafe-undefined-imports importss needed)
  (add-missing-imports 'add-missing-unsafe-undefined-imports
                       importss
                       unsafe-undefined-import-names
                       needed))

;; add-missing-provider-owned-imports : importss (listof symbol?) -> importss
;;   Repair decompiled provider linklets that use provider-owned bindings as free ids.
(define (add-missing-provider-owned-imports importss needed)
  (add-missing-imports 'add-missing-provider-owned-imports
                       importss
                       provider-owned-missing-import-names
                       needed))

;; webify-module-extractor-spike/slice-exports : report (listof symbol?) -> report
;;   Produce a demand-sliced report containing only needed exports/imports/definitions.
(define (webify-module-extractor-spike/slice-exports report demanded-exports)
  (define who 'webify-module-extractor-spike/slice-exports)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (unless (and (list? demanded-exports) (andmap symbol? demanded-exports))
    (raise-argument-error who "(listof symbol?)" demanded-exports))
  (define raw-linklet (webify-module-extractor-spike-phase0-linklet-datum report))
  (define linklet (webify-normalize-linklet-imports raw-linklet))
  (match-define `(linklet ,raw-importss ,raw-exports . ,_raw-body) raw-linklet)
  (match-define `(linklet ,importss ,_exports . ,body) linklet)
  (define free-var-cache (make-hasheq))
  (define (free-vars expr)
    (hash-ref! free-var-cache
               expr
               (lambda ()
                 (linklet-expr-free-vars expr))))
  (define export-descriptors (linklet-export-descriptors who raw-exports))
  (define (demanded-export-descriptor demanded-export)
    (or
     (for/first ([descriptor (in-list export-descriptors)]
                 #:when (eq? (cadr descriptor) demanded-export))
       descriptor)
     (for/first ([descriptor (in-list export-descriptors)]
                 #:when (symbolic-name=? (cadr descriptor) demanded-export))
       descriptor)))
  (define demanded-export-descriptors
    (remove-duplicates
     (append*
      (for/list ([export (in-list demanded-exports)])
        (define descriptor (demanded-export-descriptor export))
        (unless descriptor
          (raise-arguments-error who
                                 "demanded export is not provided by report"
                                 "module" (webify-module-extractor-spike-name report)
                                 "export" export))
        (define public-base-descriptors
          (cond
            [(generated-import-name? export)
             (for/list ([candidate (in-list export-descriptors)]
                        #:when (string=? (symbol->string (cadr candidate))
                                          (generated-base-name export)))
               candidate)]
            [else '()]))
        (cons descriptor public-base-descriptors)))))
  (define initializer-forms
    (filter (lambda (form)
              (define-values (ids _rhs) (linklet-definition form))
              (not ids))
            body))
  ;; Linklet initializer forms always run, so their free variables must seed
  ;; the slice just like demanded exports. Otherwise an initializer can survive
  ;; while its imports or helper definitions are removed.
  (define initializer-needed
    (remove-duplicates
     (append*
      (for/list ([form (in-list initializer-forms)])
        (free-vars form)))))
  (define definition-table (make-hasheq))
  (for ([form (in-list body)])
    (define-values (ids rhs) (linklet-definition form))
    (when ids
      (for ([id (in-list ids)])
        (hash-set! definition-table id (list ids rhs form)))))
  (define needed
    (remove-duplicates
     (append
      (for/list ([descriptor (in-list demanded-export-descriptors)])
        (car descriptor))
      ;; Webify lowers top-level module expressions into synthetic
      ;; definitions. They are not exports, but module instantiation must
      ;; still evaluate them for effects.
      (for/list ([form (in-list body)]
                 #:do [(define-values (ids _rhs) (linklet-definition form))]
                 #:when (and ids
                             (for/or ([id (in-list ids)])
                               (generated-effect-definition-name? id))))
        (car ids))
      initializer-needed)))
  (define needed-table (make-hasheq))
  (for ([id (in-list needed)])
    (hash-set! needed-table id #t))
  (define needed-reverse (reverse needed))
  (let loop ([queue needed]
             [pending-reverse '()])
    (cond
      [(null? queue)
       (unless (null? pending-reverse)
         (loop (reverse pending-reverse) '()))]
      [else
       (define id (car queue))
       (define next-pending-reverse pending-reverse)
       (define definition (hash-ref definition-table id #f))
       (cond
         [(not definition) (loop (cdr queue) next-pending-reverse)]
         [else
          (match-define (list ids rhs _form) definition)
          (define discovered
            (filter (lambda (free-id) (not (hash-ref needed-table free-id #f)))
                    (free-vars rhs)))
          (for ([new-id (in-list (append ids discovered))])
            (unless (hash-ref needed-table new-id #f)
              (hash-set! needed-table new-id #t)
              (set! needed-reverse (cons new-id needed-reverse))))
          (for ([free-id (in-list discovered)])
            (set! next-pending-reverse (cons free-id next-pending-reverse)))
          (loop (cdr queue) next-pending-reverse)])]))
  (set! needed (reverse needed-reverse))
  (define kept-body
    (for/list ([form (in-list body)]
               #:do [(define-values (ids _rhs) (linklet-definition form))]
               #:when (or (not ids)
                          (for/or ([id (in-list ids)])
                            (memq id needed))))
      form))
  (define local-definitions
    (filter (lambda (id) (hash-has-key? definition-table id)) needed))
  (define demanded-imports/raw
    (filter (lambda (id) (not (memq id local-definitions))) needed))
  (define kept-body-free-vars
    (remove-duplicates
     (append*
      (for/list ([form (in-list kept-body)])
        (free-vars form)))))
  (define demanded-imports
    (remove-duplicates
     (append demanded-imports/raw
             (if (eq? (webify-module-extractor-spike-name report)
                      'racket/private/class-internal)
                 ;; `class-internal` builds object struct properties in code
                 ;; that survives slicing. Add the repair imports only when
                 ;; the kept body actually references the generated names.
                 (filter (lambda (name) (memq name kept-body-free-vars))
                         unsafe-undefined-import-names)
                 '()))))
  (define sliced-importss
    (add-missing-provider-owned-imports
     (add-missing-unsafe-undefined-imports
      (filter-importss raw-importss demanded-imports)
      demanded-imports)
     demanded-imports))
  (define sliced-exports
    (remove-duplicates
     (for/list ([descriptor (in-list demanded-export-descriptors)])
       (caddr descriptor))))
  (define sliced-external-exports
    (webify-normalize-linklet-exports sliced-exports))
  (define sliced-linklet
    `(linklet ,sliced-importss ,sliced-exports . ,kept-body))
  (define phase0-entry
    (webify-module-bundle-entry
     0
     'linklet
     sliced-importss
     sliced-external-exports
     sliced-linklet
     #f))
  (define sliced-bundle-entries
    (cons phase0-entry
          (filter (lambda (entry)
                    (not (equal? 0 (webify-module-bundle-entry-key entry))))
                  (webify-module-extractor-spike-bundle-entries report))))
  (webify-module-extractor-spike
   (webify-module-extractor-spike-name report)
   (webify-module-extractor-spike-directory-keys report)
   (webify-module-extractor-spike-bundle-keys report)
   sliced-bundle-entries
   sliced-importss
   sliced-external-exports
   sliced-linklet
   #t
   (cons "report was sliced to demanded phase-0 exports"
         (webify-module-extractor-spike-notes report))))

;; repair-extracted-linklet-imports : symbol? linklet-datum? -> linklet-datum?
;;   Repair machine-independent decompile gaps for imports implied by free ids.
(define (repair-extracted-linklet-imports name linklet)
  (define linklet/readable (readable-linklet-datum linklet))
  (match linklet/readable
    [`(linklet ,importss ,exports . ,body)
     (define free-var-cache (make-hasheq))
     (define (free-vars expr)
       (hash-ref! free-var-cache
                  expr
                  (lambda ()
                    (linklet-expr-free-vars expr))))
     (define defined
       (append*
        (for/list ([form (in-list body)])
          (define-values (ids _rhs) (linklet-definition form))
          (or ids '()))))
     (define free
       (remove-bound
        (remove-duplicates
         (append* (for/list ([form (in-list body)])
                    (free-vars form))))
        defined))
     (define repaired-importss
       (add-missing-provider-owned-imports
        (if (eq? name 'racket/private/class-internal)
            (add-missing-unsafe-undefined-imports importss free)
            importss)
        free))
     (define needs-repair?
       (not (equal? repaired-importss importss)))
     (cond
       [(not needs-repair?) linklet/readable]
       [else
        `(linklet
          ,repaired-importss
          ,exports
          ,@body)])]
    [_ linklet]))

;; repaired-phase0-bundle-entry : symbol? webify-module-bundle-entry? -> webify-module-bundle-entry?
;;   Rewrite a phase-0 entry so report metadata and decompiled linklet imports agree.
(define (repaired-phase0-bundle-entry name entry)
  (define datum (webify-module-bundle-entry-datum entry))
  (cond
    [(linklet-datum? datum)
     (define repaired (repair-extracted-linklet-imports name datum))
     (match-define `(linklet ,imports ,exports . ,_body) repaired)
     (struct-copy webify-module-bundle-entry entry
                  [imports imports]
                  [exports exports]
                  [datum repaired])]
    [else entry]))

;; replace-bundle-entry : (listof webify-module-bundle-entry?) webify-module-bundle-entry? -> list?
;;   Replace the entry with the same bundle key while preserving entry order.
(define (replace-bundle-entry entries replacement)
  (for/list ([entry (in-list entries)])
    (if (equal? (webify-module-bundle-entry-key entry)
                (webify-module-bundle-entry-key replacement))
        replacement
        entry)))

;; webify-module-extractor-spikes->required-provider-closure : reports ... -> (listof report)
;;   Discover transitive provider reports starting from root reports.
(define (webify-module-extractor-spikes->required-provider-closure
         reports
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-unfetchable? [skip-unfetchable? #t]
         #:skip-provider? [skip-provider? (lambda (name) #f)]
         #:trace-box [trace-box #f]
         #:frontier-limit [frontier-limit #f])
  (define who 'webify-module-extractor-spikes->required-provider-closure)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (unless (procedure? fetch-provider)
    (raise-argument-error who "procedure?" fetch-provider))
  (unless (boolean? skip-unfetchable?)
    (raise-argument-error who "boolean?" skip-unfetchable?))
  (unless (procedure? skip-provider?)
    (raise-argument-error who "procedure?" skip-provider?))
  (unless (or (not trace-box) (box? trace-box))
    (raise-argument-error who "(or/c #f box?)" trace-box))
  (unless (or (not frontier-limit) (exact-positive-integer? frontier-limit))
    (raise-argument-error who "(or/c #f exact-positive-integer?)" frontier-limit))
  (for ([report (in-list reports)])
    (unless (webify-module-extractor-spike? report)
      (raise-argument-error who "webify-module-extractor-spike?" report)))
  (define reports-by-name (make-hasheq))
  (define depths-by-name (make-hasheq))
  (define unresolved-candidate-reports-cache (make-hasheq))
  (define unresolved-candidate-cache (make-hash))
  (define ordered-reverse '())
  (define trace-base (and trace-box (unbox trace-box)))
  (define trace-events-reverse '())
  (define trace-flushed? #f)
  (define (ordered-reports)
    (reverse ordered-reverse))
  (define (flush-trace!)
    (when (and trace-box (not trace-flushed?))
      (set-box! trace-box
                (append trace-base
                        (reverse trace-events-reverse)))
      (set! trace-flushed? #t)))
  (define (trace! provider demander depth cached? reason elapsed-ms status)
    (when trace-box
      (set! trace-events-reverse
            (cons (webify-module-provider-discovery-trace-event
                   provider demander depth cached? reason elapsed-ms status)
                  trace-events-reverse))))
  (define (check-frontier! reason)
    (when (and frontier-limit (> (hash-count reports-by-name) frontier-limit))
      (raise-arguments-error
       who
       "provider discovery frontier limit reached"
       "limit" frontier-limit
       "reason" reason
       "frontier" (map webify-module-extractor-spike-name (ordered-reports)))))
  (define (record! report)
    (define name (webify-module-extractor-spike-name report))
    (cond
      [(hash-has-key? reports-by-name name) #f]
      [else
       (hash-set! reports-by-name name report)
       (set! ordered-reverse (cons report ordered-reverse))
       (check-frontier! name)
       #t]))
  (for ([report (in-list reports)])
    (when (record! report)
      (hash-set! depths-by-name
                 (webify-module-extractor-spike-name report)
                 0)))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (flush-trace!)
                     (raise exn))])
    (let loop ([queue reports]
               [pending-reverse '()])
      (cond
        [(null? queue)
         (cond
           [(null? pending-reverse)
            (define result (ordered-reports))
            (flush-trace!)
            result]
           [else
            (loop (reverse pending-reverse) '())])]
        [else
         (define report (car queue))
         (define next-pending-reverse pending-reverse)
         (define demander (webify-module-extractor-spike-name report))
         (define demander-depth (hash-ref depths-by-name demander 0))
         (define import-map (webify-module-extractor-spike-import-map report))
         (define (fetch-report name reason)
           (define cached-report (hash-ref reports-by-name name #f))
           (cond
             [cached-report
              (trace! name demander (hash-ref depths-by-name name demander-depth) #t reason 0 'cached)
              cached-report]
             [(skip-provider? name)
              (trace! name demander (add1 demander-depth) #f reason 0 'cut)
              #f]
             [else
              (define start-ms (current-inexact-milliseconds))
              (define provider-report
                (with-handlers ([exn:fail?
                                 (lambda (exn)
                                   (trace! name demander (add1 demander-depth) #f reason
                                           (- (current-inexact-milliseconds) start-ms)
                                           'failed)
                                   (if skip-unfetchable? #f (raise exn)))])
                  (fetch-provider name)))
              (cond
                [(not provider-report)
                 (trace! name demander (add1 demander-depth) #f reason
                         (- (current-inexact-milliseconds) start-ms)
                         'skipped)
                 #f]
                [else
                 (unless (webify-module-extractor-spike? provider-report)
                   (raise-arguments-error who
                                          "provider fetcher did not return an extractor report"
                                          "module" name
                                          "result" provider-report))
                 (unless (eq? name (webify-module-extractor-spike-name provider-report))
                   (raise-arguments-error who
                                          "provider report name does not match requested module"
                                          "module" name
                                          "report name" (webify-module-extractor-spike-name provider-report)))
                 (hash-set! depths-by-name name (add1 demander-depth))
                 (trace! name demander (add1 demander-depth) #f reason
                         (- (current-inexact-milliseconds) start-ms)
                         'fetched)
                 (when (record! provider-report)
                   (set! next-pending-reverse
                         (cons provider-report next-pending-reverse)))
                 provider-report])]))
         (for ([name (in-list (webify-module-extractor-spike-required-provider-names report))])
           (fetch-report name 'required-provider))
         (define (unresolved-candidate-reports)
           (hash-ref!
            unresolved-candidate-reports-cache
            demander
            (lambda ()
              (filter
               values
               (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates import-map))]
                          #:when (= 0 (car candidate)))
                 (fetch-report (cadr candidate) 'unresolved-import-candidate))))))
        (define (process-unresolved-binding! local external)
          (define key (list demander local external))
          (unless (hash-ref unresolved-candidate-cache key #f)
            (hash-set! unresolved-candidate-cache key #t)
            (match (compiled-primitive-alias-hint demander local external)
              [(list dependency _provider-export)
               (fetch-report dependency 'compiled-alias-hint-provider)]
            [_ (void)])
            (when (syntax-srcloc-export-name? external)
              (fetch-report 'syntax/srcloc 'compiled-source-location-helper))
            (when (symbolic-member? external
                                    '(do-make-object
                                      extract-arg
                                      compose-class
                                      is-a?
                                      object?
                                      object%))
              (fetch-report 'racket/private/class-internal
                            'compiled-class-runtime-helper))
            (when (symbolic-name=? external 'find-method/who)
              (fetch-report 'racket/private/class-struct
                            'compiled-class-struct-helper))
            (when (symbolic-member? external
                                    '(check-inspector
                                      check-struct-type))
              (fetch-report 'racket/private/define-struct
                            'compiled-define-struct-helper))
            (when (symbolic-member? external
                                    '(make-serialize-info
                                      make-deserialize-info))
              (fetch-report 'racket/private/serialize-structs
                            'compiled-serialize-structs-helper))
            (when (symbolic-name=? external 'remove-duplicates)
              (fetch-report 'webracket/list 'compiled-list-helper))
            (when (symbolic-member? external
                                    '(andmap2
                                      ormap2))
              (fetch-report 'racket/private/map 'compiled-map-helper))
            (when (symbolic-name=? external 'normalise-inputs)
              (fetch-report 'racket/private/for 'compiled-for-helper))
            (define candidate-reports (unresolved-candidate-reports))
            (define directly-exported?
              (for/or ([candidate-report (in-list candidate-reports)])
                (for/or ([export (in-list (webify-module-extractor-spike-phase0-exports
                                           candidate-report))])
                  (symbolic-name=? export external))))
            (unless directly-exported?
              (for ([candidate-report (in-list candidate-reports)])
                (for ([alias (in-list
                              (compiled-provides-provider-aliases
                               (webify-module-import-map-decl-provides-expression
                                (webify-module-extractor-spike-import-map candidate-report))
                               (webify-module-import-map-data-module-path-indexes
                                (webify-module-extractor-spike-import-map candidate-report))
                               (webify-module-extractor-spike-name candidate-report)
                               external))])
                  (match-define (list dependency _provider-export) alias)
                  (fetch-report dependency 'compiled-provide-alias))))))
         (for* ([group (in-list (webify-module-import-map-unresolved-import-groups import-map))]
                [binding (in-list group)])
           (match-define (list _local external) binding)
           (process-unresolved-binding! _local external))
         (loop (cdr queue) next-pending-reverse)]))))

;; webify-module-extractor-spikes->discovered-resolved-linklet-inputs : reports ... -> inputs
;;   Discover provider closure, then resolve the resulting graph into bridge inputs.
(define (demand-slice-discovered-reports root-reports
                                         extra-reports
                                         discovered-reports
                                         dependencies
                                         module-protocol-dependency)
  (define root/extra-names
    (for/hasheq ([report (in-list (append root-reports extra-reports))])
      (values (webify-module-extractor-spike-name report) #t)))
  (define reports-by-name
    (for/hasheq ([report (in-list discovered-reports)])
      (values (webify-module-extractor-spike-name report) report)))
  (define discovered-dependency-exports
    (webify-module-extractor-spikes-dependency-exports discovered-reports))
  (define final-by-name (make-hasheq))
  (define final-reports-cache #f)
  (define runtime-required-modules-cache (make-hasheq))
  (define (invalidate-final-reports!)
    (set! final-reports-cache #f))
  (define (set-final-report! module report)
    (hash-set! final-by-name module report)
    (invalidate-final-reports!))
  (for ([report (in-list (append extra-reports root-reports))])
    (set-final-report! (webify-module-extractor-spike-name report) report))
  (define (final-reports)
    (or final-reports-cache
        (let ([reports
               (filter values
                       (for/list ([report (in-list discovered-reports)])
                         (hash-ref final-by-name
                                   (webify-module-extractor-spike-name report)
                                   #f)))])
          (set! final-reports-cache reports)
          reports)))
  (define (ordered-final-reports)
    (define final-table
      (for/hasheq ([report (in-list (final-reports))])
        (values (webify-module-extractor-spike-name report) report)))
    (define planned '())
    (define permanent (hasheq))
    (define temporary (hasheq))
    (define (visit report)
      (define name (webify-module-extractor-spike-name report))
      (cond
        [(hash-has-key? permanent name) (void)]
        [(hash-has-key? temporary name)
         ;; The Racket module require graph should be acyclic. If metadata
         ;; disagrees, keep discovery order instead of failing the extractor.
         (void)]
        [else
         (set! temporary (hash-set temporary name #t))
         (for ([module (in-list (runtime-required-modules report))])
           (define dependency (hash-ref final-table module #f))
           (when dependency
             (visit dependency)))
         (set! temporary (hash-remove temporary name))
         (set! permanent (hash-set permanent name #t))
         (set! planned (cons report planned))]))
    (for ([report (in-list (final-reports))])
      (visit report))
    (reverse planned))
  (define (runtime-required-modules report)
    (hash-ref!
     runtime-required-modules-cache
     report
     (lambda ()
       (define self-name (webify-module-extractor-spike-name report))
       (define imported-externals
         (remove-duplicates
          (for/list ([binding (in-list (webify-linklet-import-bindings
                                        (webify-module-extractor-spike-phase0-linklet-datum
                                         report)))])
            (cadr binding))
          eq?))
       (define (provider-exports-imported-name? provider-name)
         (define provider-report (hash-ref reports-by-name provider-name #f))
         (and provider-report
              (for/or ([export (in-list (webify-module-extractor-spike-phase0-exports
                                         provider-report))])
                (for/or ([imported (in-list imported-externals)])
                  (symbolic-name=? export imported)))))
       (remove-duplicates
        (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates
                                        (webify-module-extractor-spike-import-map report)))]
                   #:when (and (= 0 (car candidate))
                               (not (eq? (cadr candidate) self-name))
                               (provider-exports-imported-name? (cadr candidate))))
          (cadr candidate))
        eq?))))
  (define demanded (make-hasheq))
  (define (new-exports module exports)
    (define old (hash-ref demanded module '()))
    (filter (lambda (export) (not (memq export old))) exports))
  (define (record-demand! demand)
    (define module (webify-module-export-demand-module demand))
    (define exports (webify-module-export-demand-exports demand))
    (define fresh (new-exports module exports))
    (cond
      [(null? fresh) #f]
      [else
       (hash-set! demanded module (remove-duplicates (append (hash-ref demanded module '()) fresh)))
       (webify-module-export-demand module fresh)]))
  (define initial-demands
    (append*
     (for/list ([report (in-list (append extra-reports root-reports))])
       (webify-module-extractor-spike-import-export-demands
        report
        discovered-reports
        #:provider-dependency-exports discovered-dependency-exports
        #:dependencies dependencies
        #:module-protocol-dependency module-protocol-dependency))))
  (define (process-export-demands! demands)
    (let loop ([queue (filter values (map record-demand! demands))]
               [pending-reverse '()])
      (cond
        [(null? queue)
         (unless (null? pending-reverse)
           (loop (reverse pending-reverse) '()))]
        [else
         (define demand (car queue))
         (define next-pending-reverse pending-reverse)
         (define module (webify-module-export-demand-module demand))
         (define report (hash-ref reports-by-name module #f))
         (when (and report (not (hash-ref root/extra-names module #f)))
           (define sliced
             (webify-module-extractor-spike/slice-exports
              report
              (hash-ref demanded module)))
           (set-final-report! module sliced)
           (for ([next-demand (in-list (webify-module-extractor-spike-import-export-demands
                                        sliced
                                        discovered-reports
                                        #:provider-dependency-exports discovered-dependency-exports
                                        #:dependencies dependencies
                                        #:module-protocol-dependency module-protocol-dependency))])
             (define recorded (record-demand! next-demand))
             (when recorded
               (set! next-pending-reverse
                     (cons recorded next-pending-reverse)))))
         (loop (cdr queue) next-pending-reverse)])))
  (define (process-init-closure!)
    (let loop ()
      (define changed? #f)
      (define next-demands '())
      (for ([report (in-list (final-reports))])
        (for ([module (in-list (runtime-required-modules report))])
          (unless (hash-has-key? final-by-name module)
            (define provider-report (hash-ref reports-by-name module #f))
            (when provider-report
              (define sliced
                (webify-module-extractor-spike/slice-exports provider-report '()))
              (set-final-report! module sliced)
              (set! changed? #t)
              (for ([next-demand (in-list (webify-module-extractor-spike-import-export-demands
                                           sliced
                                           discovered-reports
                                           #:provider-dependency-exports discovered-dependency-exports
                                           #:dependencies dependencies
                                           #:module-protocol-dependency module-protocol-dependency))])
                (set! next-demands (cons next-demand next-demands)))))))
      (when (pair? next-demands)
        (process-export-demands! (reverse next-demands)))
      (when (or changed? (pair? next-demands))
        (loop))))
  (process-export-demands! initial-demands)
  (process-init-closure!)
  (ordered-final-reports))

(define (webify-module-extractor-spikes->discovered-resolved-linklet-inputs
         reports
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-unfetchable? [skip-unfetchable? #t]
         #:skip-provider? [skip-provider? (lambda (name) #f)]
         #:trace-box [trace-box #f]
         #:frontier-limit [frontier-limit #f]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:demand-slice? [demand-slice? #f])
  (define who 'webify-module-extractor-spikes->discovered-resolved-linklet-inputs)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (unless (list? extra-reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" extra-reports))
  (define discovered-reports
    (webify-module-extractor-spikes->required-provider-closure
     (append extra-reports reports)
     #:fetch-provider fetch-provider
     #:skip-unfetchable? skip-unfetchable?
     #:skip-provider? skip-provider?
     #:trace-box trace-box
     #:frontier-limit frontier-limit))
  (define resolved-reports
    (if demand-slice?
        (demand-slice-discovered-reports reports
                                         extra-reports
                                         discovered-reports
                                         dependencies
                                         module-protocol-dependency)
        discovered-reports))
  (webify-module-extractor-spikes->resolved-linklet-inputs
   resolved-reports
   #:dependencies dependencies
   #:module-protocol-dependency module-protocol-dependency))

;; webify-module-provider-discovery-run-stages : reports ... -> stages?
;;   Run provider discovery as split stages for diagnostics.
(define (webify-module-provider-discovery-run-stages
         reports
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-unfetchable? [skip-unfetchable? #t]
         #:skip-provider? [skip-provider? (lambda (name) #f)]
         #:trace-box [trace-box #f]
         #:frontier-limit [frontier-limit #f]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:demand-slice? [demand-slice? #f])
  (define timings-reverse '())
  (define (timed label thunk)
    (define start-ms (current-inexact-milliseconds))
    (define result (thunk))
    (set! timings-reverse
          (cons (cons label
                      (- (current-inexact-milliseconds) start-ms))
                timings-reverse))
    result)
  (define discovered-reports
    (timed
     'fetch-provider-closure
     (lambda ()
       (webify-module-extractor-spikes->required-provider-closure
        (append extra-reports reports)
        #:fetch-provider fetch-provider
        #:skip-unfetchable? skip-unfetchable?
        #:skip-provider? skip-provider?
        #:trace-box trace-box
        #:frontier-limit frontier-limit))))
  (define resolved-reports
    (timed
     'demand-slice
     (lambda ()
       (if demand-slice?
           (demand-slice-discovered-reports reports
                                            extra-reports
                                            discovered-reports
                                            dependencies
                                            module-protocol-dependency)
           discovered-reports))))
  (define inputs
    (timed
     'resolve-inputs
     (lambda ()
       (webify-module-extractor-spikes->resolved-linklet-inputs
        resolved-reports
        #:dependencies dependencies
        #:module-protocol-dependency module-protocol-dependency))))
  (make-webify-module-provider-discovery-stages
   discovered-reports
   resolved-reports
   inputs
   (reverse timings-reverse)))

;; resolve-extracted-linklet-imports : symbol? linklet-datum ... -> imports
;;   Classify extracted imports and turn supported ones into flat bridge triples.
(define (resolve-extracted-linklet-imports who
                                           linklet
                                           dependency-exports
                                           preferred-dependency-exports
                                           dependencies
                                           import-aliases
                                           require-rename-aliases
                                           required-module-candidates
                                           require-provider-order
                                           module-protocol-dependency
                                           reflection-hints
                                           module-name)
  (when module-protocol-dependency
    (unless (symbol? module-protocol-dependency)
      (raise-argument-error who "symbol?" module-protocol-dependency)))
  (define normalized-import-groups
    (match linklet
      [`(linklet ,importss ,_exports . ,_body)
       (unless (and (list? importss)
                    (for/and ([group (in-list importss)])
                      (and (list? group)
                           (for/and ([binding (in-list group)])
                             (match binding
                               [(list (? symbol?) (? symbol?)) #t]
                               [_ #f])))))
         (raise-arguments-error who
                                "normalized linklet imports must be grouped pairs of symbols"
                                "linklet" linklet))
       importss]
      [_
       (raise-arguments-error who
                              "expected a linklet datum"
                              "linklet" linklet)]))
  (define bindings (apply append normalized-import-groups))
  (define unresolved-groups
    (filter (lambda (group) (not (protocol-import-group? group)))
            normalized-import-groups))
  (define module-protocol-bindings (filter module-protocol-import-binding? bindings))
  (define module-bindings (filter (lambda (binding)
                                    (not (module-protocol-import-binding? binding)))
                                  bindings))
  (when (and (pair? module-protocol-bindings) (not module-protocol-dependency))
    (raise-arguments-error who
                           "extracted linklet imports require WebRacket module protocol dependency support"
                           "imports" (map car module-protocol-bindings)
                           "hint" "pass #:module-protocol-dependency when a module protocol input exists"))
  (define module-protocol-triples
    (for/list ([binding (in-list module-protocol-bindings)])
      (match-define (list local external) binding)
      (list local module-protocol-dependency external)))
  (define module-triples
    (cond
      [(null? module-bindings) '()]
      [else
       (define reflection-hint-locals
         (for/list ([hint (in-list reflection-hints)]
                    #:when (match hint
                             [(list (? symbol?) (? symbol?) (? symbol?)) #t]
                             [(list importer _local _dependency _export)
                              (eq? importer module-name)]
                             [_ #f]))
           (match hint
             [(list local _dependency _export) local]
             [(list _importer local _dependency _export) local])))
       (define explicit-locals (map car dependencies))
       (define racket-list-generated-sort-locals
         (cond
           [(eq? module-name 'racket/list)
            (for/list ([binding (in-list (apply append unresolved-groups))]
                       #:do [(match-define (list local external) binding)]
                       #:when (symbolic-name=? external 'sort))
              local)]
           [else '()]))
       (define dependency-cache
         (make-dependency-export-cache dependency-exports))
       (define preferred-dependency-cache
         (make-dependency-export-cache preferred-dependency-exports))
       (define resolved-require-rename-aliases
         (resolve-compiled-rename-aliases require-rename-aliases dependency-cache))
       (define require-order-coverage-aliases
         (import-groups->require-order-coverage-aliases
          unresolved-groups
          require-provider-order
          preferred-dependency-cache
          (append explicit-locals
                  reflection-hint-locals
                  (for/list ([alias (in-list (append import-aliases
                                                      resolved-require-rename-aliases))])
                    (car alias)))
          module-name))
       (define alias-complement-aliases
         (import-groups->alias-complement-aliases
          unresolved-groups
          required-module-candidates
          dependency-cache
          (append import-aliases
                  resolved-require-rename-aliases
                  require-order-coverage-aliases)
          (append explicit-locals
                  reflection-hint-locals
                  (for/list ([alias (in-list (append import-aliases
                                                      resolved-require-rename-aliases
                                                      require-order-coverage-aliases))])
                    (car alias)))))
       (define grouped-provider-aliases
         (import-groups->provider-coverage-aliases
          unresolved-groups
          required-module-candidates
          dependency-cache
          (append explicit-locals
                  racket-list-generated-sort-locals
                  reflection-hint-locals
                  (for/list ([alias (in-list (append import-aliases
                                                      resolved-require-rename-aliases
                                                      require-order-coverage-aliases
                                                      alias-complement-aliases))])
                    (car alias)))
          #:candidate-cache preferred-dependency-cache
          #:self-name module-name))
       (define explicit-or-alias-locals
         (append explicit-locals
                 reflection-hint-locals
                 (map car require-order-coverage-aliases)
                 (map car alias-complement-aliases)
                 (map car grouped-provider-aliases)
                 (for/list ([alias (in-list (append import-aliases
                                                     resolved-require-rename-aliases))]
                            #:do [(match-define (list local _dependency _export) alias)]
                            #:when (assoc local module-bindings))
                   local)))
       (define (dependency-cache-external? cache dependency external)
         (dependency-export-cache-has-external? cache dependency external))
       (define (dependency-exports-exact-external? dependency external)
         (dependency-export-cache-has-exact-external?
          dependency-cache
          dependency
          external))
       (define (symbolic-member? external names)
         (for/or ([name (in-list names)])
           (symbolic-name=? external name)))
       (define (compiled-provider-hint local external)
         (cond
           [(and (eq? local '-random)
                 (eq? external '-random))
            (list local '#%kernel)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'coerce-contract))
            (list local 'racket/contract/private/guts)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'apply-contract))
            (list local 'racket/contract/private/guts)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'blame-swap))
            (list local 'racket/contract/private/blame)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'raise-blame-error))
           (list local 'racket/contract/private/blame)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'contract?))
            (list local 'racket/contract/private/guts)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'contract-continuation-mark-key))
            (list local 'racket/contract/private/guts)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-member? external
                                   '(wrapped-class-info-blame
                                     wrapped-class-info-neg-extra-arg-vec
                                     wrapped-class-info-neg-acceptors-ht
                                     wrapped-class-info-pos-field-projs
                                     wrapped-class-info-neg-field-projs
                                     wrapped-class-info-init-proj-pairs
                                     wrapped-object
                                     wrapped-object?
                                     wrapped-object-object
                                     wrapped-object-neg-extra-arg-vec
                                     wrapped-object-pos-field-projs
                                     wrapped-object-neg-field-projs
                                     wrapped-object-neg-party
                                     unwrap-object
                                     impersonator-prop:wrapped-class-info
                                     impersonator-prop:has-wrapped-class-info?
                                     impersonator-prop:get-wrapped-class-info
                                     impersonator-prop:wrapped-class-neg-party
                                     impersonator-prop:has-wrapped-class-neg-party?
                                     impersonator-prop:get-wrapped-class-neg-party)))
            (list local 'racket/private/class-wrapped)]
           [(and (memq module-name '(contract racket/private/unit/contract))
                 (symbolic-name=? external 'contract-continuation-mark-key))
            (list local 'racket/contract/private/guts)]
           [(and (memq module-name '(contract racket/private/unit/contract))
                 (symbolic-name=? external 'member))
            ;; `racket/private/unit/contract` gets ordinary list membership from
            ;; its `racket/base` import. In full-language compositions both
            ;; `racket/private/pico` and `racket/private/list` can export a
            ;; matching name, but the source-level provider is the list layer.
            (list local 'racket/private/list)]
           [(and (memq module-name '(runtime racket/private/unit/runtime))
                 (symbolic-name=? external 'contract-continuation-mark-key))
            (list local 'racket/contract/private/guts)]
           [(and (memq module-name '(runtime racket/private/unit/runtime))
                 (symbolic-name=? external '-make-blame))
            (list local 'racket/contract/private/blame)]
           [(and (eq? module-name 'racket/private/unit/contract-syntax)
                 (symbolic-name=? external 'unwind-to))
            (list local 'syntax/parse/private/residual/state)]
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
            (list local 'syntax/parse/private/residual/progress)]
           [(and (eq? module-name 'racket/private/unit/contract-syntax)
                 (memq external '(t-resyntax t-subst)))
            (list local 'racket/private/template)]
           [(and (eq? module-name 'racket/private/unit/contract-syntax)
                 (symbolic-name=? external 'predicate-ellipsis-parser))
            (list local 'syntax/parse/private/residual/parse-util)]
           [(and (eq? module-name 'syntax/parse/private/residual/parse-util)
                 (symbolic-name=? external '2d-stx?.1))
            (list local 'syntax/parse/private/residual/3d-stx)]
           [(and (eq? module-name 'syntax/parse/private/residual/parse-util)
                 (symbolic-name=? external 'resolve-paths))
            (list local 'racket/runtime-path)]
           [(and (eq? module-name 'racket/runtime-path)
                 (symbolic-name=? external 'table))
            (list local 'racket/private/runtime-path-table)]
           [(and (eq? module-name 'racket/runtime-path)
                 (memq external '(decode-link-path encode-link-path encoded-link-path?)))
            (list local 'racket/private/link-path)]
           [(and (eq? module-name 'racket/runtime-path)
                 (memq external '(so-find so-spec?)))
            (list local 'webracket/private/so-search)]
           [(and (eq? module-name 'racket/runtime-path)
                 (memq external '(share-find share-spec?)))
            (list local 'webracket/private/share-search)]
           [(and (eq? module-name 'racket/runtime-path)
                 (symbolic-name=? external 'new-apply-proc))
            (list local 'webracket/private/pre-base-apply)]
           [(and (eq? module-name 'racket/lazy-require)
                 (symbolic-name=? external 'delay/sync))
            (list local 'racket/promise)]
           [(and (eq? module-name 'racket/lazy-require)
                 (symbolic-name=? external 'register-external-module))
            (list local 'compiler/cm-accomplice)]
           [(and (eq? module-name 'racket/private/unit/contract-syntax)
                 (symbolic-name=? external 'expr-stx?))
            (list local 'syntax/parse/private/lib)]
           [(and (memq module-name '(exptime/import-export
                                      racket/private/unit/exptime/import-export))
                 (symbolic-name=? external 's-any))
            (list local 'syntax/parse/private/residual-interp)]
           [(and (memq module-name '(exptime/import-export
                                      racket/private/unit/exptime/import-export))
                 (symbolic-name=? external 'check-list))
            ;; This unit exptime helper imports `racket/list` source-side. The
            ;; compiled provider graph can see both the public list provider
            ;; and its private implementation, so prefer the implementation
            ;; module that actually owns the helper in the extracted bundle.
            (list local 'racket/private/list)]
           [(and (memq module-name '(exptime/import-export
                                      racket/private/unit/exptime/import-export))
                 (symbolic-name=? external 'empty?))
            ;; `racket/list` re-exports `empty?` from its predicate helper.
            (list local 'racket/private/list-predicates)]
           [(and (memq module-name '(exptime/import-export
                                      racket/private/unit/exptime/import-export))
                 (symbolic-name=? external 'append-map))
            ;; Source imports this public helper through `racket/list`.
            (list local 'racket/list)]
           [(and (eq? module-name 'syntax/parse/private/residual-interp)
                 (symbol? external)
                 (regexp-match? #rx"^sim:" (symbol->string external)))
            (list local 'syntax/parse/private/rep-patterns/simple)]
           [(and (eq? module-name 'racket/private/unit/exptime/syntax)
                 (symbolic-name=? external 'interp-match))
            (list local 'racket/private/stxcase)]
           [(and (memq module-name '(exptime/util
                                      racket/private/unit/exptime/util))
                 (symbolic-name=? external 'make-hygienic-metafunction))
            (list local 'syntax/parse/experimental/template)]
           [(and (memq module-name '(exptime/util
                                      racket/private/unit/exptime/util))
                 (symbolic-name=? external 'check-list))
            ;; This helper uses `for/list`; the compiled form can expose list
            ;; checks from both list internals and the for implementation.
            (list local 'racket/private/for)]
           [(and (eq? module-name 'racket-src/expander/read/string)
                 (symbolic-name=? external 'check-list))
            ;; The staged reader string helper only needs the primitive list
            ;; check, and routing through `for` can create registry cycles.
            (list local '#%kernel)]
           [(and (eq? module-name 'webracket/stream)
                 (symbolic-name=? external 'check-list))
            ;; The staged stream provider uses `for` internally for checks.
            ;; Route its generated `check-list` to the for implementation when
            ;; list internals are also present in the composed bundle.
            (list local 'racket/private/for)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'current-contract-region))
            (list local 'racket/contract/region)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'contract))
            (list local 'racket/contract/private/guts)]
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
            (list local 'webracket/primitives)]
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
            (list local 'webracket/primitives)]
           [(and (eq? module-name 'racket-src/expander/read-provider-root.rkt)
                 (eq? local '1/string->number)
                 (eq? external 'string->number))
            (list local 'racket-src/expander/host/string-to-number)]
           [(and (memq module-name '(racket/private/for
                                     racket/private/list
                                     racket/private/class-struct
                                     webracket/list))
                 (eq? local '1/reverse)
                 (eq? external 'reverse))
            ;; On newer hosts this helper lives in pico; on 8.12 it resolves
            ;; through the dedicated private reverse implementation module.
            (list local
                  (if (module-path-available? 'racket/private/pico)
                      'racket/private/pico
                      'racket/private/reverse))]
           [(and (memq module-name '(racket/list
                                     racket/private/list))
                 (symbolic-name=? external 'sort))
            (list local 'webracket/private/sort-public)]
           [(and (memq module-name '(racket-src/io/format/main-web
                                     racket-src/io/format/main-web.rkt))
                 (symbolic-name=? external 'do-printf))
            (list local 'racket-src/io/format/printf-web)]
           [(and (memq module-name '(racket-src/io/format/main-web
                                     racket-src/io/format/main-web.rkt))
                 (symbolic-name=? external 'print-boolean-long-form))
            (list local 'racket-src/io/format/printf-adapter)]
           [(and (memq module-name '(racket/list
                                     racket/private/list
                                     webracket/list))
                 (symbolic-name=? external 'check-list))
            (list local '#%kernel)]
           [(symbolic-name=? external 'struct:keyword-method/arity-error)
            (list local 'webracket/private/kw)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (symbolic-name=? external 'variable-reference->module-source/submod))
            (list local 'syntax/location)]
           [(symbolic-member? external
                              '(apply-contract
                                contract
                                contract?
                                coerce-contract))
            (list local 'racket/contract/private/guts)]
           [(symbolic-name=? external 'raise-blame-error)
            (list local 'racket/contract/private/blame)]
           [(symbolic-member? external
                              '(coerce-contracts
                                coerce-flat-contract
                                coerce-flat-contracts
                                coerce-chaperone-contract
                                coerce-chaperone-contracts))
            (list local 'racket/contract/private/guts)]
           [(symbolic-member? external
                              '(blame?
                                make-blame
                                blame-source
                                blame-positive
                                blame-negative
                                blame-contract
                                blame-value
                                blame-original?
                                blame-swapped?
                                blame-swap
                                blame-replace-negative
                                blame-replaced-negative?
                                blame-update
                                blame-add-context
                                blame-add-unknown-context
                                blame-context
                                blame-add-missing-party
                                blame-missing-party?
                                blame-add-extra-field
                                blame-fmt->-string
                                invariant-assertion-party))
            (list local 'racket/contract/private/blame)]
           [(symbolic-name=? external 'current-contract-region)
            (list local 'racket/contract/region)]
           [(symbolic-name=? external 'real-and/c-name)
            (list local 'racket/contract/private/guts)]
           [(symbolic-name=? external 'or/c-name)
            (list local 'racket/contract/private/guts)]
           [(symbolic-member? external
                              '(add-method-suffix
                                contract-random-generate
                                contract-random-generate-stash
                                contract-random-generate-get-current-environment
                                contract-random-generate/choose
                                contract-random-generate-fail
                                contract-random-generate-fail?
                                contract-random-generate-env?
                                prop:contract
                                prop:chaperone-contract
                                prop:flat-contract
                                prop:contracted
                                impersonator-prop:contracted
                                contract?
                                flat-contract?
                                chaperone-contract?
                                impersonator-contract?
                                contract-name
                                contract-first-order
                                contract-first-order-passes?
                                contract-proc
                                contract-projection
                                contract-val-first-projection
                                contract-late-neg-projection
                                get/build-val-first-projection
                                get/build-late-neg-projection
                                contract-custom-write-property-proc
                                custom-write-property-proc
                                n->th
                                build-contract-property
                                build-chaperone-contract-property
                                build-flat-contract-property
                                trust-me
                                build-context
                                contract-struct-late-neg-projection
                                contract-struct-generate
                                contract-struct-exercise
                                contract-struct-list-contract?
                                wrong-number-of-results-blame))
            (list local 'racket/contract/private/guts)]
           [(symbolic-member? external
                              '(tail-contract-key
                                bad-number-of-results
                                the-unsupplied-arg
                                unsupplied-arg?
                                unspecified-dom
                                check-procedure
                                check-procedure/more))
            (list local 'racket/contract/private/guts)]
           [(symbolic-name=? external 'build->*-plus-one-acceptor)
            (list local 'racket/contract/private/guts)]
           [(symbolic-name=? external 'prop:stream)
            (list local 'racket/private/for)]
           [(and (eq? module-name 'racket/sequence)
                 (symbolic-name=? external 'stream?))
            (list local 'racket/private/for)]
           [(symbolic-member? external
                              '(pos->ord
                                default-arg
                                check-method
                                1/check-method
                                raise-support-error))
            (list local 'racket/private/generic)]
           [(symbolic-name=? external 'arity-includes?)
            (list local 'racket/private/arity)]
           [(symbolic-name=? external 'format)
            (list local 'racket-src/io/format/main-web)]
           [(syntax-srcloc-export-name? external)
            (list local 'racket/contract/private/guts)]
           [(symbolic-name=? external 'find-method/who)
            (list local 'racket/private/class-struct)]
           [(symbolic-member? external
                              '(check-inspector
                                check-struct-type))
            (list local 'racket/private/define-struct)]
           [(symbolic-member? external
                              '(make-serialize-info
                                make-deserialize-info))
            (list local 'racket/private/serialize-structs)]
           [(symbolic-name=? external 'remove-duplicates)
            (list local 'webracket/list)]
           [(symbolic-member? external
                              '(andmap2
                                ormap2))
            (list local 'racket/private/map)]
           [(symbolic-name=? external 'normalise-inputs)
            (list local 'racket/private/for)]
           [(symbolic-member? external
                              '(do-make-object
                                extract-arg
                                compose-class
                                is-a?
                                object?
                                object%))
            (list local 'racket/private/class-internal)]
           [(symbolic-member? external
                              '(keyword-apply
                                make-keyword-procedure
                                new-keyword-apply
                                subsets?
                                make-optional-keyword-procedure
                                make-optional-keyword-method
                                make-required-keyword-method/arity-error
                                keyword-procedure-extract
                                procedure-reduce-keyword-arity
                                procedure-reduce-keyword-arity-mask
                                procedure-keywords
                                struct:keyword-procedure
                                struct:keyword-procedure/arity-error
                                struct:keyword-method
                                struct:keyword-method/arity-error))
            (list local 'webracket/private/kw)]
           [(symbolic-member? external
                              '(return/no-unsupplied
                                return/no-unsupplied/param-mark
                                keyword-return/no-unsupplied
                                keyword-return/no-unsupplied/param-mark
                                un-dep
                                un-dep/chaperone
                                ->i-arg
                                ->i-arg?
                                ->i-arg-name
                                ->i-arg-kwd
                                ->i-arg-optional?
                                ->i-arg-contract))
            (list local 'racket/contract/private/guts)]
           [(and (eq? module-name 'racket/private/class-internal)
                 (or (symbolic-name=? external 'unsafe-undefined)
                     (symbolic-name=? external 'check-not-unsafe-undefined)
                     (symbolic-name=? external 'check-not-unsafe-undefined/assign)
                     (symbolic-name=? external 'prop:chaperone-unsafe-undefined)
                     (symbolic-name=? external 'chaperone-struct-unsafe-undefined)))
            (list local 'racket/unsafe/undefined)]
           [else #f]))
       (define (candidate->inferred-dependency binding)
         (match-define (list local external) binding)
         (define hinted-dependency (compiled-provider-hint local external))
         (cond
           [hinted-dependency hinted-dependency]
           [else
         (define candidates
           (remove-duplicates
            (for/list ([candidate (in-list required-module-candidates)]
                       #:when (and (= 0 (car candidate))
                                   (dependency-cache-external?
                                    dependency-cache
                                    (cadr candidate)
                                    external)))
              candidate)
            equal?))
         (define preferred-candidates
           (filter (lambda (candidate)
                     (dependency-cache-external?
                      preferred-dependency-cache
                      (cadr candidate)
                      external))
                   candidates))
         (define (prefer-stream-cons candidates)
           (cond
             [(symbolic-name=? external 'stream?)
              (define stream-cons-candidates
                (filter (lambda (candidate)
                          (eq? (cadr candidate) 'racket/private/stream-cons))
                        candidates))
              (if (null? stream-cons-candidates) candidates stream-cons-candidates)]
             [else candidates]))
         (define (prefer-for-check-list-provider candidates)
           ;; `for`-expanded list iterations import the `check-list` helper
           ;; from racket/private/for. Other list providers can expose a helper
           ;; with the same name, so prefer the loop expander's provider.
           (cond
             [(and (symbolic-name=? external 'check-list)
                   (for/or ([candidate (in-list candidates)])
                     (eq? (cadr candidate) 'racket/private/for)))
              (filter (lambda (candidate)
                        (eq? (cadr candidate) 'racket/private/for))
                      candidates)]
             [else candidates]))
         (define (prefer-list-member-provider candidates)
           ;; `#lang webracket/full` can expose both pico's lower helper and
           ;; the list-layer `member`. Prefer the list layer only after export
           ;; scanning has proved that it is a valid provider for this bundle.
           (cond
             [(and (symbolic-name=? external 'member)
                   (for/or ([candidate (in-list candidates)])
                     (eq? (cadr candidate) 'racket/private/list)))
              (filter (lambda (candidate)
                        (eq? (cadr candidate) 'racket/private/list))
                      candidates)]
             [else candidates]))
         (define (public-racket-counterpart name)
           (and (symbol? name)
                (match (regexp-match #rx"^racket/private/(.+)$"
                                     (symbol->string name))
                  [(list _ suffix)
                   (string->symbol (string-append "racket/" suffix))]
                  [_ #f])))
         (define (prefer-public-racket-provider candidates)
           ;; Public imports such as `racket/list` can coexist with their
           ;; implementation modules like `racket/private/list` in the same
           ;; candidate set. Prefer the public surface unless another earlier
           ;; rule has already narrowed the choice to the private helper.
           (define public-candidates
             (filter (lambda (candidate)
                       (define dependency (cadr candidate))
                       (for/or ([other (in-list candidates)])
                         (eq? dependency
                              (public-racket-counterpart (cadr other)))))
                     candidates))
           (if (null? public-candidates) candidates public-candidates))
         (define public-contract-substitute-modules
           '(racket/contract
             racket/contract/base
             racket/contract/combinator
             racket/contract/region))
         (define (prefer-public-contract-substitute candidates)
           (define public-candidates
             (filter (lambda (candidate)
                       (memq (cadr candidate)
                             public-contract-substitute-modules))
                     candidates))
           (match public-candidates
             ['() candidates]
             [(list _candidate) public-candidates]
             [_ candidates]))
         (define (prefer-exact-provider-export candidates)
           ;; Generated provide/contract exports can look like contract helper
           ;; names after suffix normalization. Keep an exact provider export,
           ;; such as racket/dict's id-partially-applied42.1, ahead of the
           ;; unsuffixed racket/contract/base helper.
           (define exact-candidates
             (filter (lambda (candidate)
                       (dependency-exports-exact-external? (cadr candidate)
                                                           external))
                     candidates))
           (define base-name
             (and (generated-import-name? external)
                  (string->symbol (generated-base-name external))))
           (define base-exact-candidates
             (if base-name
                 (filter (lambda (candidate)
                           (dependency-exports-exact-external? (cadr candidate)
                                                               base-name))
                         candidates)
                 '()))
           (define (racket-private-provider? name)
             (and (symbol? name)
                  (regexp-match? #rx"^racket/private/" (symbol->string name))))
           (cond
             [(and (generated-import-name? external)
                   (pair? exact-candidates)
                   (pair? base-exact-candidates)
                   (for/or ([candidate (in-list base-exact-candidates)])
                     (webracket-module-name? (cadr candidate)))
                   (andmap (lambda (candidate)
                             (racket-private-provider? (cadr candidate)))
                           exact-candidates))
              base-exact-candidates]
             [(null? exact-candidates) candidates]
             [else exact-candidates]))
         (define (webracket-module-name? name)
           (and (symbol? name)
                (regexp-match? #rx"^webracket/" (symbol->string name))))
         (define (collection-module-name? name)
           (and (symbol? name)
                (regexp-match? #rx"/" (symbol->string name))))
         (define (prefer-collection-module-name candidates)
           ;; Compiled linklets can expose both a short internal module name
           ;; like `runtime` and the resolved collection path
           ;; `racket/private/unit/runtime`. Prefer the collection path when
           ;; both are valid providers, because it remains loadable outside the
           ;; bundle's local naming convention.
           (define collection-candidates
             (filter (lambda (candidate)
                       (collection-module-name? (cadr candidate)))
                     candidates))
           (if (null? collection-candidates) candidates collection-candidates))
         (define (prefer-installed-provider-internals candidates)
           (cond
             [(webracket-module-name? module-name) candidates]
             [else
              (define installed-candidates
                (filter (lambda (candidate)
                          (not (webracket-module-name? (cadr candidate))))
                        candidates))
              (if (null? installed-candidates) candidates installed-candidates)]))
         (define (prefer-non-self-provider candidates)
           (define non-self-candidates
             (filter (lambda (candidate)
                       (not (eq? (cadr candidate) module-name)))
                     candidates))
           (if (null? non-self-candidates) candidates non-self-candidates))
         (define ranked-candidates
           (prefer-non-self-provider
            (prefer-collection-module-name
             (prefer-installed-provider-internals
              (prefer-public-contract-substitute
               (prefer-exact-provider-export
                (prefer-public-racket-provider
                (prefer-list-member-provider
                 (prefer-stream-cons
                  (prefer-for-check-list-provider
                   (if (null? preferred-candidates) candidates preferred-candidates)))))))))))
         (define (candidate-reason candidate)
           (list local
                 (cadr candidate)
                 (if (memq candidate preferred-candidates)
                     'provider-local-export
                     'metadata-export-candidate)
                 (if (dependency-export-cache-exports preferred-dependency-cache
                                                      (cadr candidate))
                     'reachable-provider
                     'discovered-candidate)))
         (cond
           [(null? ranked-candidates) #f]
           [(null? (cdr ranked-candidates))
            (list local (cadar ranked-candidates))]
           [else
            (raise-arguments-error who
                                   "ambiguous inferred import dependency"
                                   "importer" module-name
                                   "import" local
                                   "candidates"
                                   (for/list ([candidate (in-list ranked-candidates)])
                                     (list local (cadr candidate)))
                                   "candidate reasons"
                                   (map candidate-reason candidates))])]))
       (define inferred-dependencies
         (remove-duplicates
          (filter
           values
           (for/list ([binding (in-list module-bindings)]
                      #:do [(match-define (list local _external) binding)]
                      #:unless (memq local explicit-or-alias-locals))
             (candidate->inferred-dependency binding)))
          equal?))
       (define duplicate-inferred (check-duplicates (map car inferred-dependencies)))
       (when duplicate-inferred
         (raise-arguments-error who
                                "ambiguous inferred import dependency"
                                "import" duplicate-inferred
                                "candidates" inferred-dependencies))
       (webify-resolve-module-linklet-imports
        `(linklet (,module-bindings) () (void))
        dependency-exports
        #:module-name module-name
        #:dependencies (append dependencies inferred-dependencies)
        #:reflection-hints reflection-hints
        #:import-aliases
        (append import-aliases
                resolved-require-rename-aliases
                require-order-coverage-aliases
                alias-complement-aliases
                grouped-provider-aliases))]))
  (define triples-by-import
    (for/hasheq ([triple (in-list (append module-protocol-triples module-triples))])
      (values (car triple) triple)))
  (define all-triples (append module-protocol-triples module-triples))
  (for/list ([binding (in-list bindings)])
    (define local (car binding))
    (hash-ref triples-by-import
              local
              (lambda ()
                (match (filter (lambda (triple)
                                 (symbolic-name=? (car triple) local))
                               all-triples)
                  [(list triple) triple]
                  [matches
                   (raise-arguments-error who
                                          "resolved import triple is missing or ambiguous"
                                          "import" local
                                          "matches" matches)])))))

;; webify-module-extractor-spike-dependency-exports : report -> dependency-export-row
;;   Derive a resolver export row from the extracted provider's compiled phase-0 exports.
(define (webify-module-extractor-spike-dependency-exports report)
  (define who 'webify-module-extractor-spike-dependency-exports)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (list (webify-module-extractor-spike-name report)
        (webify-module-extractor-spike-phase0-exports report)))

;; webify-module-extractor-spikes-dependency-exports : (listof report) -> dependency-exports
;;   Derive a resolver export table from extracted provider reports.
(define (webify-module-extractor-spikes-dependency-exports reports)
  (define who 'webify-module-extractor-spikes-dependency-exports)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (define dependency-exports
    (for/list ([report (in-list reports)])
      (unless (webify-module-extractor-spike? report)
        (raise-argument-error who "webify-module-extractor-spike?" report))
      (webify-module-extractor-spike-dependency-exports report)))
  ;; Reuse the manifest-input validator to reject duplicate provider names.
  (webify-module-linklet-inputs-dependency-exports
   (for/list ([row (in-list dependency-exports)])
     (match-define (list name exports) row)
     (webify-module-linklet-input name `(linklet () ,exports (void)) '()))))

;; dependency-exports/include-self : report dependency-exports -> dependency-exports
;;   Add the report's own export row for compiled linklets that import a
;;   same-module binding under an internalized local name.
(define (dependency-exports/include-self report dependency-exports)
  (define self-row (webify-module-extractor-spike-dependency-exports report))
  (match-define (list self-name _self-exports) self-row)
  (if (assoc self-name dependency-exports)
      dependency-exports
      (cons self-row dependency-exports)))

;; dependency-exports/merge-missing : dependency-exports dependency-exports -> dependency-exports
;;   Add rows from extra only when base has no entry for that dependency.
(define (dependency-exports/merge-missing base extra)
  (define who 'dependency-exports/merge-missing)
  (unless (and (list? base)
               (andmap (lambda (row)
                         (match row
                           [(list (? symbol?) exports)
                            (and (list? exports)
                                 (andmap symbol? exports))]
                           [_ #f]))
                       base))
    (raise-argument-error who "(listof (list/c symbol? (listof symbol?)))" base))
  (unless (and (list? extra)
               (andmap (lambda (row)
                         (match row
                           [(list (? symbol?) exports)
                            (and (list? exports)
                                 (andmap symbol? exports))]
                           [_ #f]))
                       extra))
    (raise-argument-error who "(listof (list/c symbol? (listof symbol?)))" extra))
  (append base
          (for/list ([row (in-list extra)]
                     #:unless (assoc (car row) base))
            row)))

;; parsed-directory-select-bundle : symbol? hash? (listof symbol?) -> hash?
;;   Select the main parsed zo bundle for a top-level module or nested submodule path.
(define (parsed-directory-select-bundle who directory-hash submodule-path)
  (match submodule-path
    ['()
     (define bundle
       (or (hash-ref directory-hash #f #f)
           (hash-ref directory-hash '() #f)))
     (unless (webify-zo-linklet-bundle? bundle)
       (raise-arguments-error who
                              "parsed directory has no main linklet bundle"
                              "directory keys" (hash-keys directory-hash)))
     bundle]
    [(cons submodule more)
     (define subdirectory
       (hash-ref directory-hash
                 submodule
                 (lambda ()
                   (raise-arguments-error who
                                          "parsed directory has no requested submodule"
                                          "submodule" submodule
                                          "submodule path" submodule-path
                                          "directory keys" (hash-keys directory-hash)))))
     (unless (webify-zo-linklet-directory? subdirectory)
       (raise-arguments-error who
                              "parsed submodule entry is not a parsed linklet directory"
                              "submodule" submodule
                              "entry" subdirectory))
     (parsed-directory-select-bundle
      who
      (webify-zo-linklet-directory->hash subdirectory)
      more)]))

;; compiled-module->extractor-spike : symbol? any/c -> webify-module-extractor-spike?
;;   Convert one machine-independent compiled module to an extractor report.
(define (compiled-module->extractor-spike who name compiled
                                          #:submodule-path [submodule-path '()])
  (cond
    [(webify-faslable-correlated-linklet? compiled)
     (unless (null? submodule-path)
       (raise-arguments-error who
                              "compiled faslable linklet cannot satisfy a submodule request"
                              "name" name
                              "submodule path" submodule-path))
     (compiled-linklet-datum->extractor-spike
      name
      (webify-faslable-correlated-linklet->datum compiled)
      '("machine-independent compilation exposes a faslable-correlated phase-0 linklet datum"))]
    [(linklet? compiled)
     (unless (null? submodule-path)
       (raise-arguments-error who
                              "direct compiled linklet cannot satisfy a submodule request"
                              "name" name
                              "submodule path" submodule-path))
     (define phase0-entry (bundle-value->entry 0 compiled))
     (define phase0-linklet-datum
       (webify-module-bundle-entry-datum phase0-entry))
     (define manifest-ready? (linklet-datum? phase0-linklet-datum))
     (cond
       [manifest-ready?
        (define repaired-phase0-entry
          (repaired-phase0-bundle-entry name phase0-entry))
        (webify-module-extractor-spike
         name
         '(#f)
         '(0)
         (list repaired-phase0-entry)
         (webify-module-bundle-entry-imports repaired-phase0-entry)
         (webify-module-bundle-entry-exports repaired-phase0-entry)
         (webify-module-bundle-entry-datum repaired-phase0-entry)
         #t
         '("machine-independent compilation exposes a direct decompilable phase-0 linklet datum"))]
       [else
        (define parsed (webify-compiled-expression->zo compiled))
        (cond
          [parsed
           (compiled-zo->extractor-spike who name parsed #:submodule-path submodule-path)]
          [else
           (webify-module-extractor-spike
            name
            '(#f)
            '(0)
            (list phase0-entry)
            (linklet-import-variables compiled)
            (linklet-export-variables compiled)
            phase0-linklet-datum
            #f
            (cond
              [maybe-decompile-linklet
               '("compiled module exposes a direct linklet object"
                 "decompile-linklet did not produce a linklet datum for the phase-0 linklet")]
              [else
               `("compiled module exposes a direct linklet object"
                 ,decompile-linklet-missing-note)]))])])]
    [else
     (define parsed (webify-compiled-expression->zo compiled))
     (cond
       [parsed
        (compiled-zo->extractor-spike who name parsed #:submodule-path submodule-path)]
       [(linklet-directory? compiled)
        (compiled-linklet-directory->extractor-spike who
                                                     name
                                                     compiled
                                                     #:submodule-path submodule-path)]
       [else
        (raise-arguments-error who
                               "compiled module did not produce a linklet directory, parsed zo, or direct linklet"
                               "compiled" compiled)])]))

;; parsed-bundle->extractor-spike : symbol? symbol? hash? any/c any/c -> report
;;   Convert a parsed zo linklet bundle into an extractor report.
(define (parsed-bundle->extractor-spike who name bundle-hash directory-keys)
  (define bundle-entries
    (sort
     (for/list ([(key value) (in-hash bundle-hash)])
       (bundle-value->entry key value))
     bundle-entry<?))
  (define phase0-entry
    (for/first ([entry (in-list bundle-entries)]
                #:when (equal? 0 (webify-module-bundle-entry-key entry)))
      entry))
  (unless phase0-entry
    (raise-arguments-error who
                           "parsed bundle has no phase-0 linklet"
                           "bundle keys" (hash-keys bundle-hash)))
  (define phase0-linklet-datum
    (webify-module-bundle-entry-datum phase0-entry))
  (unless (linklet-datum? phase0-linklet-datum)
    (raise-arguments-error who
                           "parsed phase-0 entry did not contain a linklet datum"
                           "entry" phase0-entry))
  (define repaired-phase0-entry
    (repaired-phase0-bundle-entry name phase0-entry))
  (webify-module-extractor-spike
   name
   directory-keys
   (sort (hash-keys bundle-hash) key<?)
   (replace-bundle-entry bundle-entries repaired-phase0-entry)
   (webify-module-bundle-entry-imports repaired-phase0-entry)
   (webify-module-bundle-entry-exports repaired-phase0-entry)
   (webify-module-bundle-entry-datum repaired-phase0-entry)
   #t
   '("machine-independent compiled expression parses to faslable-correlated linklets")))

;; compiled-zo->extractor-spike : symbol? symbol? any/c -> report
;;   Convert compiler/zo-parse's bundle or directory structures into a report.
(define (compiled-zo->extractor-spike who name parsed
                                      #:submodule-path [submodule-path '()])
  (cond
    [(webify-zo-linklet-bundle? parsed)
     (unless (null? submodule-path)
       (raise-arguments-error who
                              "parsed linklet bundle cannot satisfy a submodule request"
                              "name" name
                              "submodule path" submodule-path))
     (parsed-bundle->extractor-spike
      who
      name
      (webify-zo-linklet-bundle->hash parsed)
      '(#f))]
    [(webify-zo-linklet-directory? parsed)
     (define directory-hash (webify-zo-linklet-directory->hash parsed))
     (define main-bundle
       (parsed-directory-select-bundle who directory-hash submodule-path))
     (parsed-bundle->extractor-spike
      who
      name
      (webify-zo-linklet-bundle->hash main-bundle)
      (sort (hash-keys directory-hash) key<?))]
    [else
     (raise-arguments-error who
                            "parsed compiled module did not produce a linklet bundle or directory"
                            "parsed" parsed)]))

;; compiled-linklet-datum->extractor-spike : symbol? linklet-datum any/c -> report
;;   Convert a decompiled direct phase-0 linklet datum into an extractor report.
(define (compiled-linklet-datum->extractor-spike name phase0-linklet-datum notes)
  (unless (linklet-datum? phase0-linklet-datum)
    (raise-arguments-error 'compiled-linklet-datum->extractor-spike
                           "faslable-correlated value did not contain a linklet datum"
                           "datum" phase0-linklet-datum))
  (match-define `(linklet ,imports ,exports . ,_body) phase0-linklet-datum)
  (define phase0-entry
    (webify-module-bundle-entry
     0
     'linklet
     imports
     exports
     phase0-linklet-datum
     #f))
  (define repaired-phase0-entry
    (repaired-phase0-bundle-entry name phase0-entry))
  (webify-module-extractor-spike
   name
   '(#f)
   '(0)
   (list repaired-phase0-entry)
   (webify-module-bundle-entry-imports repaired-phase0-entry)
   (webify-module-bundle-entry-exports repaired-phase0-entry)
   (webify-module-bundle-entry-datum repaired-phase0-entry)
   #t
   notes))

;; linklet-directory-select-bundle : symbol? linklet-directory? (listof symbol?) -> linklet-bundle?
;;   Select the main bundle for a top-level module or nested submodule path.
(define (linklet-directory-select-bundle who compiled submodule-path)
  (define directory-hash (linklet-directory->hash compiled))
  (match submodule-path
    ['()
     (define bundle
       (hash-ref directory-hash
                 #f
                 (lambda ()
                   (raise-arguments-error who
                                          "compiled module has no main linklet bundle"
                                          "directory keys" (hash-keys directory-hash)))))
     (unless (linklet-bundle? bundle)
       (raise-arguments-error who
                              "main directory entry is not a linklet bundle"
                              "entry" bundle))
     bundle]
    [(cons submodule more)
     (define subdirectory
       (hash-ref directory-hash
                 submodule
                 (lambda ()
                   (raise-arguments-error who
                                          "compiled module has no requested submodule"
                                          "submodule" submodule
                                          "submodule path" submodule-path
                                          "directory keys" (hash-keys directory-hash)))))
     (unless (linklet-directory? subdirectory)
       (raise-arguments-error who
                              "submodule directory entry is not a linklet directory"
                              "submodule" submodule
                              "entry" subdirectory))
     (linklet-directory-select-bundle who subdirectory more)]))

;; compiled-linklet-directory->extractor-spike : symbol? symbol? linklet-directory? [#:submodule-path (listof symbol?)] -> report
;;   Convert one compiled module-directory entry into an extractor report.
(define (compiled-linklet-directory->extractor-spike who name compiled
                                                     #:submodule-path [submodule-path '()])
  (define directory-hash (linklet-directory->hash compiled))
  (define selected-bundle
    (linklet-directory-select-bundle who compiled submodule-path))
  (define bundle-hash (linklet-bundle->hash selected-bundle))
  (define bundle-entries
    (sort
     (for/list ([(key value) (in-hash bundle-hash)])
       (bundle-value->entry key value))
     bundle-entry<?))
  (define phase0-linklet
    (hash-ref bundle-hash
              0
              (lambda ()
                (raise-arguments-error who
                                       "main bundle has no phase-0 linklet"
                                       "bundle keys" (hash-keys bundle-hash)))))
  (unless (linklet? phase0-linklet)
    (raise-arguments-error who
                           "phase-0 bundle entry is not a linklet"
                           "entry" phase0-linklet))
  (define phase0-entry
    (for/first ([entry (in-list bundle-entries)]
                #:when (equal? 0 (webify-module-bundle-entry-key entry)))
      entry))
  (define phase0-linklet-datum
    (webify-module-bundle-entry-datum phase0-entry))
  (define manifest-ready? (linklet-datum? phase0-linklet-datum))
  (define repaired-phase0-entry
    (and manifest-ready?
         (repaired-phase0-bundle-entry name phase0-entry)))
  (webify-module-extractor-spike
   name
   (sort (hash-keys directory-hash) key<?)
   (sort (hash-keys bundle-hash) key<?)
   (if repaired-phase0-entry
       (replace-bundle-entry bundle-entries repaired-phase0-entry)
       bundle-entries)
   (if repaired-phase0-entry
       (webify-module-bundle-entry-imports repaired-phase0-entry)
       (linklet-import-variables phase0-linklet))
   (if repaired-phase0-entry
       (webify-module-bundle-entry-exports repaired-phase0-entry)
       (linklet-export-variables phase0-linklet))
   (if repaired-phase0-entry
       (webify-module-bundle-entry-datum repaired-phase0-entry)
       phase0-linklet-datum)
   manifest-ready?
   (cond
     [manifest-ready?
      '("machine-independent compilation exposes a decompilable phase-0 linklet datum"
        "compiled module import metadata still includes module protocol plumbing")]
     [maybe-decompile-linklet
      '("compiled source modules expose linklet objects and metadata"
        "decompile-linklet did not produce a linklet datum for the phase-0 linklet")]
     [else
      `("compiled source modules expose linklet objects and metadata"
        ,decompile-linklet-missing-note)])))

;; webify-compile-module-extractor-spike : any/c [#:namespace namespace?] [#:module-name-resolver procedure?] -> webify-module-extractor-spike?
;;   Probe Racket's compiled-module linklet shape without claiming extraction support.
(define (webify-compile-module-extractor-spike module-datum
                                               #:namespace [namespace (make-base-namespace)]
                                               #:module-name-resolver [module-name-resolver (current-module-name-resolver)])
  (define who 'webify-compile-module-extractor-spike)
  (define module-stx (source-module->syntax module-datum))
  (define name (validate-source-module! who module-stx))
  (define compiled
    (parameterize ([current-namespace namespace]
                   [current-module-name-resolver module-name-resolver])
      (parameterize ([current-compile-target-machine #f])
        (compile module-stx))))
  (compiled-module->extractor-spike who name compiled))

;; webify-compile-module-extractor-spikes/shared-namespace : (listof module-datum) ... -> reports
;;   Compile source modules in order while installing earlier declarations for quoted requires.
(define (webify-compile-module-extractor-spikes/shared-namespace
         module-data
         #:namespace [namespace (make-base-namespace)]
         #:module-name-resolver [module-name-resolver (current-module-name-resolver)])
  (define who 'webify-compile-module-extractor-spikes/shared-namespace)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (parameterize ([current-namespace namespace])
    (for/list ([module-datum (in-list module-data)])
      (define module-stx (source-module->syntax module-datum))
      (define name (validate-source-module! who module-stx))
      (parameterize ([current-module-name-resolver module-name-resolver])
        (eval module-stx))
      (define compiled
        (parameterize ([current-module-name-resolver module-name-resolver]
                       [current-compile-target-machine #f])
          (compile module-stx)))
      (compiled-module->extractor-spike who name compiled))))

;; make-webify-contract-erasing-namespace : -> namespace?
;;   Create an extraction namespace where Racket contract providers are erased.
(define (make-webify-contract-erasing-namespace)
  (define namespace (make-base-namespace))
  (define contract-file (path->string webify-contract-path/resolved))
  (define private-format-file (path->string webify-private-format-path/resolved))
  (define syntax-contract-file (path->string webify-syntax-contract-path/resolved))
  (define syntax-srcloc-file (path->string webify-syntax-srcloc-path/resolved))
  (define unsafe-undefined-file (path->string webify-unsafe-undefined-path/resolved))
  (define erased-contract-coercion-exports
    '(coerce-contract
      coerce-contracts
      coerce-contract/f
      coerce-flat-contract
      coerce-flat-contracts
      coerce-chaperone-contract
      coerce-chaperone-contracts))
  (define erased-contract-region-exports
    '(define-struct/contract
      struct/contract
      define/contract
      with-contract
      current-contract-region
      invariant-assertion))
  (define (declare-erased-contract-module! name provide-specs)
    (eval
     `(module ,name racket/base
        (require (file ,contract-file))
        (provide ,@provide-specs))))
  (define (declare-staged-format-module! name)
    (eval
     `(module ,name racket/base
        (require (file ,private-format-file))
        (provide (all-from-out (file ,private-format-file))))))
  (parameterize ([current-namespace namespace])
    (namespace-call-with-registry-lock
     namespace
     (lambda ()
       (declare-staged-format-module! 'webracket/private/format)
       (eval
        `(module racket/format racket/base
           (require webracket/private/format)
           (provide (all-from-out webracket/private/format))))
       (declare-erased-contract-module!
        'racket/contract/base
        `((except-out (all-from-out (file ,contract-file))
                      ,@erased-contract-coercion-exports)))
       (declare-erased-contract-module!
        'racket/contract/combinator
        `(prop:contract
          contract-struct-late-neg-projection
          contract-struct-generate
          contract-struct-exercise
          contract-struct-list-contract?
          prop:flat-contract
          prop:chaperone-contract
          contract-property?
          build-contract-property
          chaperone-contract-property?
          flat-contract-property?
          make-contract
          prop:orc-contract
          prop:orc-contract?
          prop:orc-contract-get-subcontracts
          prop:recursive-contract
          prop:recursive-contract?
          prop:recursive-contract-unroll
          prop:arrow-contract
          prop:arrow-contract?
          prop:arrow-contract-get-info
          struct:arrow-contract-info
          arrow-contract-info
          arrow-contract-info?
          arrow-contract-info-accepts-arglist
          arrow-contract-info-chaperone-procedure
          arrow-contract-info-check-first-order
          ,@erased-contract-coercion-exports
          build-compound-type-name
          contract-stronger?
          contract-equivalent?
          list-contract?
          contract-first-order
          contract-first-order-passes?
          prop:contracted
          prop:blame
          impersonator-prop:contracted
          impersonator-prop:blame
          has-blame?
          value-blame
          define/final-prop
          define/subexpression-pos-prop
          define/subexpression-pos-prop/name
          eq-contract?
          eq-contract-val
          equal-contract?
          equal-contract-val
          contract-custom-write-property-proc
          custom-write-property-proc))
       (declare-erased-contract-module!
        'racket/contract/region
        erased-contract-region-exports)
       (declare-erased-contract-module!
        'racket/contract/private/base
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/arr-i
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/arrow-collapsible
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/arrow-common
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/arrow-higher-order
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/arrow-val-first
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/blame
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/case-arrow
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/guts
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/list
        `(*list/c
          blame-add-car-context
          blame-add-cdr-context
          cons/c
          cons/dc
          list*of
          list/c
          listof
          non-empty-listof
          raise-not-cons-blame-error))
       (declare-erased-contract-module!
        'racket/contract/private/misc
        `(set-some-basic-misc-contracts!))
       (declare-erased-contract-module!
        'racket/contract/private/module-boundary-ctc
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/object-c-wrapper
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/opt
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/orc
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract/private/prop
        `((all-from-out (file ,contract-file))))
       (declare-erased-contract-module!
        'racket/contract
        `((all-from-out (file ,contract-file))))
       (eval
        `(module syntax/contract racket/base
           (require (file ,syntax-contract-file))
           (provide (all-from-out (file ,syntax-contract-file)))))
       (eval
        `(module syntax/srcloc racket/base
           (require (file ,syntax-srcloc-file))
           (provide (all-from-out (file ,syntax-srcloc-file)))))
       (eval
        `(module racket/unsafe/undefined racket/base
           (require (file ,unsafe-undefined-file))
           (provide (all-from-out (file ,unsafe-undefined-file)))))
       (dynamic-require ''racket/contract/base #f)
       (dynamic-require ''racket/contract/combinator #f)
       (dynamic-require ''racket/contract/region #f)
       (dynamic-require ''racket/contract/private/base #f)
       (dynamic-require ''racket/contract/private/arr-i #f)
       (dynamic-require ''racket/contract/private/arrow-collapsible #f)
       (dynamic-require ''racket/contract/private/arrow-common #f)
       (dynamic-require ''racket/contract/private/arrow-higher-order #f)
       (dynamic-require ''racket/contract/private/arrow-val-first #f)
       (dynamic-require ''racket/contract/private/blame #f)
       (dynamic-require ''racket/contract/private/case-arrow #f)
       (dynamic-require ''racket/contract/private/guts #f)
       (dynamic-require ''racket/contract/private/list #f)
       (dynamic-require ''racket/contract/private/misc #f)
       (dynamic-require ''racket/contract/private/module-boundary-ctc #f)
       (dynamic-require ''racket/contract/private/object-c-wrapper #f)
       (dynamic-require ''racket/contract/private/opt #f)
       (dynamic-require ''racket/contract/private/orc #f)
       (dynamic-require ''racket/contract/private/prop #f)
       (dynamic-require ''racket/contract #f)
       (dynamic-require `(file ,(path->string webify-private-in-path/resolved)) #f)
       (dynamic-require `(file ,(path->string webify-private-in-out-path/resolved)) #f)
       (dynamic-require `(file ,(path->string webify-private-module-boundary-ctc-path/resolved)) #f)
       (dynamic-require ''webracket/private/format #f)
       (dynamic-require ''racket/format #f)
       (dynamic-require ''syntax/contract #f)
       (dynamic-require ''syntax/srcloc #f)
       (dynamic-require ''racket/unsafe/undefined #f))))
  namespace)

;; webify-module-path->extractor-spike : module-path? -> webify-module-extractor-spike?
;;   Compile an installed module path as machine-independent code and report its linklets.
(define (webify-module-path->extractor-spike module-path
                                             #:namespace [namespace (current-namespace)])
  (define who 'webify-module-path->extractor-spike)
  (define effective-module-path
    (case module-path
      [(syntax/parse/private/residual/3d-stx)
       '(submod syntax/parse/private/residual 3d-stx)]
      [else module-path]))
  (define name (module-path->dependency-name effective-module-path))
  (define (try-slash-submodule-fallback original-exn)
    (cond
      [(symbol? effective-module-path)
       (let loop ([candidates (slash-symbol->submodule-candidates effective-module-path)])
         (cond
           [(null? candidates) (raise original-exn)]
           [else
            (with-handlers ([exn:fail? (lambda (_exn) (loop (cdr candidates)))])
              (webify-module-path->extractor-spike (car candidates)
                                                   #:namespace namespace))]))]
      [else (raise original-exn)]))
  (cond
    [(unsafe-undefined-module-path? effective-module-path)
     (define unsafe-undefined-file (path->string webify-unsafe-undefined-path))
     (define module-datum
       `(module racket/unsafe/undefined racket/base
          (require (file ,unsafe-undefined-file))
          (provide (all-from-out (file ,unsafe-undefined-file)))))
     (define compiled
       (parameterize ([current-namespace namespace]
                      [current-compile-target-machine #f])
         (compile (datum->syntax #f module-datum))))
     (compiled-module->extractor-spike who name compiled)]
    [(and (list? effective-module-path)
          (eq? (car effective-module-path) 'submod)
          (pair? (cdr effective-module-path))
          (pair? (cddr effective-module-path))
          (andmap symbol? (cddr effective-module-path)))
     (parameterize ([current-namespace namespace])
       (define source-path
         (resolved-module-path-name
           (module-path-index-resolve
           (module-path-index-join (cadr effective-module-path) #f)
           #t)))
       (unless (path-string? source-path)
         (raise-arguments-error who
                                "expected submodule root to resolve to a path"
                                "module path" effective-module-path
                                "resolved root" source-path))
       (define compiled
         (get-module-code
          source-path
          #:choose (lambda (_src _zo _so) 'src)
          #:compile (lambda (stx)
                      (parameterize ([current-compile-target-machine #f])
                        (compile stx)))))
       (compiled-module->extractor-spike who
                                         name
                                         compiled
                                         #:submodule-path (cddr effective-module-path)))]
    [else
     (with-handlers ([exn:fail? try-slash-submodule-fallback])
       (parameterize ([current-namespace namespace])
         (define resolved-name
           (resolved-module-path-name
            (module-path-index-resolve
             (module-path-index-join effective-module-path #f)
             #t)))
         (define source-path
           (resolved-module-source-path resolved-name))
         (unless source-path
           (raise-arguments-error who
                                  "expected module path to resolve to a source file"
                                  "module path" effective-module-path
                                  "resolved root" resolved-name))
         (define compiled
           (get-module-code
            source-path
            #:choose (lambda (_src _zo _so) 'src)
            #:compile (lambda (stx)
                        (parameterize ([current-compile-target-machine #f])
                          (compile stx)))))
         (compiled-module->extractor-spike who name compiled)))]))

;; module-path-variable-export-metadata : module-path? -> list?
;;   Declare/load a module and read its variable exports with defined-name metadata.
(define (module-path-variable-export-metadata module-path)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (dynamic-require module-path #f)
    (call-with-values
     (lambda () (module->exports module-path 'defined-names))
     (lambda (variables _syntaxes) variables))))

;; webify-module-path->module-export-metadata : module-path? -> (list/c symbol? list?)
;;   Collect raw module->exports metadata for an installed module path.
(define (webify-module-path->module-export-metadata module-path)
  (list (module-path->dependency-name module-path)
        (module-path-variable-export-metadata module-path)))

;; webify-module-paths->module-export-metadata : (listof module-path?) -> (listof row?)
;;   Collect raw module->exports metadata for installed module paths.
(define (webify-module-paths->module-export-metadata module-paths)
  (define who 'webify-module-paths->module-export-metadata)
  (unless (list? module-paths)
    (raise-argument-error who "(listof module-path?)" module-paths))
  (for/list ([module-path (in-list module-paths)])
    (webify-module-path->module-export-metadata module-path)))

;; source-module-variable-export-metadata : module-datum symbol? -> list?
;;   Declare a source module and read its variable exports with defined-name metadata.
(define (source-module-variable-export-metadata module-datum name)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (eval module-datum)
    (call-with-values
     (lambda () (module->exports (list 'quote name) 'defined-names))
     (lambda (variables _syntaxes) variables))))

;; webify-source-module->module-export-metadata : module-datum -> (list/c symbol? list?)
;;   Collect raw module->exports metadata for a source module declaration.
(define (webify-source-module->module-export-metadata module-datum)
  (define who 'webify-source-module->module-export-metadata)
  (define name (validate-source-module! who module-datum))
  (list name (source-module-variable-export-metadata module-datum name)))

;; webify-source-modules->module-export-metadata : (listof module-datum) -> (listof row?)
;;   Collect raw module->exports metadata for source module declarations.
(define (webify-source-modules->module-export-metadata module-data)
  (define who 'webify-source-modules->module-export-metadata)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (for/list ([module-datum (in-list module-data)])
    (webify-source-module->module-export-metadata module-datum)))

;; webify-source-module->dependency-exports : module-datum -> dependency-export-row
;;   Compile a provider source module and expose its compiled phase-0 exports.
(define (webify-source-module->dependency-exports module-datum)
  (webify-module-extractor-spike-dependency-exports
   (webify-compile-module-extractor-spike module-datum)))

;; webify-source-modules->dependency-exports : (listof module-datum) -> dependency-exports
;;   Compile provider source modules and expose their compiled phase-0 exports.
(define (webify-source-modules->dependency-exports module-data)
  (define who 'webify-source-modules->dependency-exports)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (webify-module-extractor-spikes-dependency-exports
   (webify-compile-module-extractor-spikes/shared-namespace module-data)))

;; validate-extractor-reports! : symbol? any/c -> void?
;;   Reject values that cannot be used as an extracted module graph.
(define (validate-extractor-reports! who reports)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (define names
    (for/list ([report (in-list reports)])
      (unless (webify-module-extractor-spike? report)
        (raise-argument-error who "webify-module-extractor-spike?" report))
      (webify-module-extractor-spike-name report)))
  (define duplicate-name (check-duplicates names eq?))
  (when duplicate-name
    (raise-arguments-error who
                           "duplicate module extractor reports are not supported"
                           "name" duplicate-name))
  (void))

;; validate-extractor-reports-with-exports! : symbol? any/c -> dependency-exports
;;   Reject malformed report lists and return their dependency export table.
(define (validate-extractor-reports-with-exports! who reports)
  (unless (list? reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" reports))
  (for ([report (in-list reports)])
    (unless (webify-module-extractor-spike? report)
      (raise-argument-error who "webify-module-extractor-spike?" report)))
  (webify-module-extractor-spikes-dependency-exports reports))

;; webify-source-module->linklet-input : module-datum [#:imports imports] -> webify-module-linklet-input?
;;   Extract the phase-0 linklet datum from a source module into the manifest input shape.
(define (webify-source-module->linklet-input module-datum #:imports [imports #f])
  (define who 'webify-source-module->linklet-input)
  (define report (webify-compile-module-extractor-spike module-datum))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (webify-module-linklet-input
   (webify-module-extractor-spike-name report)
   (webify-normalize-linklet-imports
   (webify-module-extractor-spike-phase0-linklet-datum report))
   imports))

;; webify-module-extractor-spike->resolved-linklet-input : report ... -> webify-module-linklet-input?
;;   Resolve classified imports from an existing extractor report into bridge triples.
(define (webify-module-extractor-spike->resolved-linklet-input report
                                                               #:dependency-exports [dependency-exports '()]
                                                               #:dependencies [dependencies '()]
                                                               #:reflection-hints [reflection-hints '()]
                                                               #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-module-extractor-spike->resolved-linklet-input)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define raw-linklet (webify-module-extractor-spike-phase0-linklet-datum report))
  (define linklet
    (repair-extracted-linklet-imports
     (webify-module-extractor-spike-name report)
     (webify-normalize-linklet-imports raw-linklet)))
  (route-syntax-literal-import
   (webify-module-linklet-input
    (webify-module-extractor-spike-name report)
    linklet
    (resolve-extracted-linklet-imports
     who
     linklet
     dependency-exports
     dependency-exports
     dependencies
     (webify-module-import-map-import-aliases import-map)
     (webify-module-import-map-require-rename-aliases import-map)
     (webify-module-import-map-required-module-candidates import-map)
     (webify-module-import-map-source-provider-order
      import-map
      (webify-module-extractor-spike-name report))
     module-protocol-dependency
     reflection-hints
     (webify-module-extractor-spike-name report)))
   report))

;; webify-module-extractor-spike->resolved-linklet-input/providers : report reports ... -> input
;;   Resolve an importer report using compiled export rows from provider reports.
(define (webify-module-extractor-spike->resolved-linklet-input/providers report
                                                                         provider-reports
                                                                         #:provider-dependency-exports [precomputed-provider-dependency-exports #f]
                                                                         #:dependency-exports [dependency-exports #f]
                                                                         #:dependencies [dependencies '()]
                                                                         #:reflection-hints [reflection-hints '()]
                                                                         #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-module-extractor-spike->resolved-linklet-input/providers)
  (unless (webify-module-extractor-spike? report)
    (raise-argument-error who "webify-module-extractor-spike?" report))
  (unless (list? provider-reports)
    (raise-argument-error who "(listof webify-module-extractor-spike?)" provider-reports))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (define import-map (webify-module-extractor-spike-import-map report))
  (define raw-linklet (webify-module-extractor-spike-phase0-linklet-datum report))
  (define linklet
    (repair-extracted-linklet-imports
     (webify-module-extractor-spike-name report)
     (webify-normalize-linklet-imports raw-linklet)))
  (define provider-dependency-exports
    (or precomputed-provider-dependency-exports
        (webify-module-extractor-spikes-dependency-exports provider-reports)))
  (define provider+self-dependency-exports
    (dependency-exports/include-self report provider-dependency-exports))
  (define resolved-dependency-exports
    (if dependency-exports
        (dependency-exports/merge-missing dependency-exports
                                          provider+self-dependency-exports)
        provider+self-dependency-exports))
  (route-syntax-literal-import
   (webify-module-linklet-input
    (webify-module-extractor-spike-name report)
    linklet
    (resolve-extracted-linklet-imports
     who
     linklet
     resolved-dependency-exports
     provider+self-dependency-exports
     dependencies
     (webify-module-import-map-import-aliases import-map)
     (webify-module-import-map-require-rename-aliases import-map)
     (webify-module-import-map-required-module-candidates import-map)
     (webify-module-import-map-source-provider-order
      import-map
      (webify-module-extractor-spike-name report))
     module-protocol-dependency
     reflection-hints
     (webify-module-extractor-spike-name report)))
   report))

;; webify-module-extractor-spikes->resolved-linklet-inputs : reports ... -> (listof input?)
;;   Resolve a supplied extracted module graph into registry-ready linklet inputs.
(define (webify-module-extractor-spikes->resolved-linklet-inputs reports
                                                                  #:dependency-exports [dependency-exports #f]
                                                                  #:dependencies [dependencies '()]
                                                                  #:reflection-hints [reflection-hints '()]
                                                                  #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-module-extractor-spikes->resolved-linklet-inputs)
  (define graph-dependency-exports
    (validate-extractor-reports-with-exports! who reports))
  (append*
   (for/list ([report (in-list reports)])
     (define stx-input (webify-module-syntax-literal-input report))
     (define main-input
       (webify-module-extractor-spike->resolved-linklet-input/providers
        report
        '()
        #:provider-dependency-exports graph-dependency-exports
        #:dependency-exports dependency-exports
        #:dependencies dependencies
        #:reflection-hints reflection-hints
        #:module-protocol-dependency module-protocol-dependency))
     (if stx-input
         (list stx-input main-input)
         (list main-input)))))

;; webify-source-module->resolved-linklet-input : module-datum ... -> webify-module-linklet-input?
;;   Extract a source module and resolve classified imports into bridge triples.
(define (webify-source-module->resolved-linklet-input module-datum
                                                       #:dependency-exports [dependency-exports '()]
                                                       #:dependencies [dependencies '()]
                                                       #:reflection-hints [reflection-hints '()]
                                                       #:module-protocol-dependency [module-protocol-dependency #f])
  (webify-module-extractor-spike->resolved-linklet-input
   (webify-compile-module-extractor-spike module-datum)
   #:dependency-exports dependency-exports
   #:dependencies dependencies
   #:reflection-hints reflection-hints
   #:module-protocol-dependency module-protocol-dependency))

;; webify-source-module->resolved-linklet-input/providers : module-datum module-data ... -> input
;;   Compile an importer and providers, then resolve imports from provider compiled exports.
(define (webify-source-module->resolved-linklet-input/providers module-datum
                                                                 provider-module-data
                                                                 #:dependencies [dependencies '()]
                                                                 #:reflection-hints [reflection-hints '()]
                                                                 #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-source-module->resolved-linklet-input/providers)
  (unless (list? provider-module-data)
    (raise-argument-error who "(listof source-module-datum?)" provider-module-data))
  (webify-module-extractor-spike->resolved-linklet-input/providers
   (webify-compile-module-extractor-spike module-datum)
   (for/list ([provider-module-datum (in-list provider-module-data)])
     (webify-compile-module-extractor-spike provider-module-datum))
   #:dependencies dependencies
   #:reflection-hints reflection-hints
   #:module-protocol-dependency module-protocol-dependency))

;; webify-source-modules->resolved-linklet-inputs : module-data ... -> (listof input?)
;;   Compile supplied source modules and resolve them as a closed bridge graph.
(define (webify-source-modules->resolved-linklet-inputs module-data
                                                         #:dependencies [dependencies '()]
                                                         #:reflection-hints [reflection-hints '()]
                                                         #:module-protocol-dependency [module-protocol-dependency #f])
  (define who 'webify-source-modules->resolved-linklet-inputs)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (webify-module-extractor-spikes->resolved-linklet-inputs
   (webify-compile-module-extractor-spikes/shared-namespace module-data)
   #:dependencies dependencies
   #:reflection-hints reflection-hints
   #:module-protocol-dependency module-protocol-dependency))

;; webify-source-modules->discovered-resolved-linklet-inputs : module-data ... -> (listof input?)
;;   Compile roots, discover installed providers, and resolve the graph.
(define (webify-source-modules->discovered-resolved-linklet-inputs
         module-data
         #:extra-reports [extra-reports '()]
         #:fetch-provider [fetch-provider webify-module-path->extractor-spike]
         #:skip-provider? [skip-provider? (lambda (name) #f)]
         #:dependencies [dependencies '()]
         #:module-protocol-dependency [module-protocol-dependency #f]
         #:namespace [namespace (make-base-namespace)]
         #:module-name-resolver [module-name-resolver (current-module-name-resolver)]
         #:demand-slice? [demand-slice? #f])
  (define who 'webify-source-modules->discovered-resolved-linklet-inputs)
  (unless (list? module-data)
    (raise-argument-error who "(listof source-module-datum?)" module-data))
  (webify-module-extractor-spikes->discovered-resolved-linklet-inputs
   (webify-compile-module-extractor-spikes/shared-namespace
    module-data
    #:namespace namespace
    #:module-name-resolver module-name-resolver)
   #:extra-reports extra-reports
   #:fetch-provider fetch-provider
   #:skip-provider? skip-provider?
  #:dependencies dependencies
  #:module-protocol-dependency module-protocol-dependency
  #:demand-slice? demand-slice?))

(module+ test
  (require rackunit)

  (define (phase0-importss linklet)
    (match linklet
      [`(linklet ,importss ,_exports . ,_body) importss]))

  (define free-format-linklet
    '(linklet
      ()
      (message)
      (define-values (message)
        (lambda (n)
          (format "count: ~a" n)))))

  (check-equal?
   (phase0-importss
    (repair-extracted-linklet-imports 'racket/private/string free-format-linklet))
   '(((format format))))

  (define locally-defined-format-linklet
    '(linklet
      ()
      (message)
      (define-values (format)
        (lambda (template value)
          template))
      (define-values (message)
        (format "count: ~a" 42))))

  (check-equal?
   (phase0-importss
    (repair-extracted-linklet-imports 'local-module locally-defined-format-linklet))
   '())

  (define slice-format-linklet
    '(linklet
      ()
      (message)
      (define-values (format-message)
        (lambda (n)
          (format "count: ~a" n)))
      (define-values (message)
        format-message)))

  (define slice-format-entry
    (webify-module-bundle-entry
     0
     'linklet
     '()
     '(message)
     slice-format-linklet
     #f))

  (define slice-format-report
    (webify-module-extractor-spike
     'racket/private/string
     '(#f)
     '(0)
     (list slice-format-entry)
     '()
     '(message)
     slice-format-linklet
     #t
     '()))

  (check-equal?
   (webify-module-extractor-spike-phase0-imports
    (webify-module-extractor-spike/slice-exports slice-format-report '(message)))
   '(((format format))))

  (check-equal?
   (compiled-primitive-alias-hint
    'racket-src/io/format/main-web
    'do-printf
    'do-printf)
   '(racket-src/io/format/printf-web do-printf))

  (check-equal?
   (compiled-primitive-alias-hint
    'racket-src/io/format/main-web
    '1/print-boolean-long-form
    'print-boolean-long-form)
   '(racket-src/io/format/printf-adapter print-boolean-long-form)))
