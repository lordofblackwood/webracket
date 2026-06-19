#lang racket/base
;;;        
;;; DRIVER 
;;;        

;; This file is the host-side orchestration layer for compilation.
;; The compiler pipeline itself lives deeper in the compiler and webify
;; modules, while this file owns file-system checks, output naming, provider
;; cache setup, external tool invocation, and the shared execution path used by
;; both the ordinary CLI and the long-lived compile server.

;; The functions in this module "drive" the compiler so to speak.
;; The settings given by the user via the command line are
;; passed as arguments to `drive-compilation`.
;; 
;; Here we handle the necessary file operations and call the
;; appropriate compilation function from "compiler.rkt".
;;
;; Any external bookkeeping with respect to files are done here.


;;;
;;; PROVIDES
;;;

(provide drive-compilation
         (struct-out compilation-output-paths)
         (struct-out compilation-timings)
         resolve-compilation-output-paths
         (all-defined-out))


;;;
;;; DEPENDENCIES
;;;

(require (only-in syntax/modread    with-module-reading-parameterization)
         (only-in racket/path       file-name-from-path
                                    find-relative-path
                                    path-only
                                    path-get-extension)
         (only-in racket/file       delete-directory/files
                                    find-files
                                    call-with-file-lock/timeout
                                    make-directory*
                                    make-lock-file-name
                                    make-temporary-file)
         (only-in racket/port       open-output-nowhere with-output-to-string)
         (only-in racket/pretty     pretty-write)
         (only-in racket/format     ~a)
         (only-in racket/fasl       fasl->s-exp s-exp->fasl)
         (only-in racket/system     system*)
         (only-in racket/string     string-join
                                    string-prefix?)
         (only-in racket/set        set-member?
                                    seteq)
         racket/unsafe/undefined
         #;(only-in "lang/reader.rkt" read-syntax)
         (only-in "assembler.rkt"
                  run
                  wat->wasm
                  runtime)
         (only-in racket/list       append* append-map remove-duplicates second take)
         (only-in racket/match      match)
         setup/dirs
         (only-in "private/parameters.rkt"  current-ffi-foreigns
                                    current-ffi-imports-wat
                                    current-ffi-funcs-wat
                                    current-browser?
                                    current-enable-cc-analysis?
                                    current-console-bridge?
                                    current-console-bridge-root-export-bindings
                                    current-console-bridge-root-source-path
                                    current-enable-simplify?
                                    current-module-bridge-elide-public-cells?
                                    current-module-bridge-elidable-module-names
                                    current-module-bridge-module-kinds
                                    current-provider-owned-primitive-aliases
                                    current-webify-knowns-mode
                                    current-letrec-strategy
                                    current-tree-shake?
                                    current-runtime-cache-dir
                                    current-runtime-primitive-report-path)
         (only-in "private/timings.rkt"
                  now-ms
                  format-metric-table
                  format-timing-table)
         "private/wat-identifiers.rkt"
         racket/runtime-path
         racket/syntax
         "private/browser-options.rkt"
         (only-in "legacy-stdlib/module-exports.rkt"
                  stdlib-module-alias-symbols
                  stdlib-module-private-forms+bindings
                  stdlib-definition-form-symbols)
         (only-in "webify/io-format-bridge.rkt"
                  webify-io-format-root-name
                  webify-io-format-printf-name
                  webify-io-format-adapter-name
                  webify-io-format-map-shim-name
                  webify-io-format-module-protocol-name
                  webify-io-format-export-symbols
                  webify-io-format-reports
                  webify-io-format-registry
                  webify-io-format-private-alias-forms
                  webify-io-format-public-alias-forms)
         (only-in "webify/io-print-bridge.rkt"
                  webify-io-print-root-name
                  webify-io-print-registry
                  webify-io-print-private-alias-forms)
         (only-in "webify/regexp-provider.rkt"
                  webify-regexp-default-cache-root
                  webify-regexp-bootstrap-helper-symbols
                  webify-regexp-export-symbols
                  webify-regexp-lowered-provider-cache-path
                  webify-regexp-linklet
                  webify-regexp-public-alias-forms
                  webify-regexp-source-fingerprint)
         (only-in "webify/read-provider.rkt"
                  webify-read-export-symbols
                  webify-read-linklet
                  webify-read-lowered-provider-cache-path
                  webify-read-public-alias-pairs
                  webify-read-public-alias-forms
                  webify-read-public-alias-symbols
                  webify-read-source-fingerprint)
         (only-in "webify/read-syntax-provider.rkt"
                  webify-read-syntax-alias-forms
                  webify-read-syntax-export-symbols
                  webify-read-syntax-linklet
                  webify-read-syntax-lowered-provider-cache-path
                  webify-read-syntax-source-fingerprint)
         (only-in "webify/module-adapter.rkt"
                  bridge-export-entry-binding
                  bridge-export-entry-kind
                  bridge-export-entry-metadata
                  first-slice-top-level-export-cell-ids
                  webify-linklet-first-slice-top-level)
         (only-in "webify/module-composer.rkt"
                  current-composer-primitive-import-cell-overrides)
         (only-in "webify/bridge-stats.rkt"
                  current-webify-bridge-stats)
         (only-in "webify/module-registry.rkt"
                  webify-compose-module-registry/roots/composition
                  webify-module-composition-datum
                  webify-module-composition-fragments
                  webify-module-composition-instances
                  webify-module-registry-names
                  webify-module-composition-with-tail)
         (only-in "webify/module-input.rkt"
                  datum->webify-module-linklet-manifest
                  webify-module-linklet-input
                  webify-module-linklet-input-imports
                  webify-module-linklet-input-linklet
                  webify-module-linklet-input-name
                  webify-module-linklet-inputs->registry
                  webify-module-linklet-manifest->registry)
         (only-in "webify/module-instance.rkt"
                  webify-module-instance-exports
                  webify-module-instance-export-entry)
         (only-in "webify/module-extractor.rkt"
                  make-webify-contract-erasing-namespace
                  make-webify-contract-erasing-module-name-resolver
                  make-webify-module-provider-cache
                  webify-compile-module-report
                  webify-module-import-map-required-module-candidates
                  webify-module-path->report
                  webify-module-provider-cache-hit-count
                  webify-module-provider-cache-miss-count
                  webify-module-provider-cache-ref
                  webify-module-reports->discovered-registry
                  webify-module-reports->discovered-resolved-linklet-inputs
                  webify-module-bundle-entry
                  webify-module-bundle-entry?
                  webify-module-bundle-entry-datum
                  webify-module-bundle-entry-exports
                  webify-module-bundle-entry-imports
                  webify-module-bundle-entry-key
                  webify-module-bundle-entry-kind
                  webify-module-bundle-entry-value
                  webify-module-report
                  webify-module-report-bundle-entries
                  webify-module-report-bundle-keys
                  webify-module-report-directory-keys
                  webify-module-report-import-map
                  webify-module-report-manifest-ready?
                  webify-module-report-name
                  webify-module-report?
                  webify-module-report-notes
                  webify-module-report-phase0-exports
                  webify-module-report-phase0-imports
                  webify-module-report-phase0-linklet-datum
                  webify-module-report-required-provider-names
                  webify-module-reports->resolved-linklet-inputs)
         (only-in "webify/module-protocol.rkt"
                  webify-module-protocol-name
                  webify-module-protocol-input
                  webify-module-protocol-report
                  webify-module-protocol-dependency)
         (only-in "webify/provider-trials.rkt"
                  webify-provider-trial-default-bridge-module-allowed?
                  webify-provider-trial-module-allowed?
                  webify-provider-trial-module-allowlist)
         (only-in "webify/ffi-module-registry.rkt"
                  module-provider->ffi-filenames)
         "compiler.rkt"
         "private/define-foreign.rkt")

(define-runtime-path webracket-root "../../..")
(define-runtime-path webify-root "webify")

;; webracket/module-reader-path : (or/c 'base 'full) -> (or/c path? #f)
;;   Resolve an installed WebRacket module reader through Racket's collection search.
(define (webracket/module-reader-path language)
  (collection-file-path "reader.rkt"
                        "webracket"
                        (symbol->string language)
                        "lang"
                        #:fail (lambda (_msg) #f)))

;; webracket/base-reader-path : -> (or/c path? #f)
;;   Resolve the installed `webracket/base` reader through Racket's collection search.
(define (webracket/base-reader-path)
  (webracket/module-reader-path 'base))

;; ensure-webracket/module-reader! : (or/c 'base 'full) -> void?
;;   Fail early unless normal Racket collection resolution can find the reader.
(define (ensure-webracket/module-reader! language)
  (unless (webracket/module-reader-path language)
    (raise-arguments-error
     'read-top-level-from-file
     (format "cannot resolve #lang webracket/~a through Racket's collection search"
             language)
     "reader" `(lib ,(format "webracket/~a/lang/reader.rkt" language))
     "hint" "install/link the webracket collection or set PLTCOLLECTS")))

;; ensure-webracket/base-reader! : -> void?
;;   Compatibility wrapper for tests and older driver helpers.
(define (ensure-webracket/base-reader!)
  (ensure-webracket/module-reader! 'base))

;;;
;;; FFI Files
;;; 

;; resolve-ffi-files! : symbol? (listof path-string?) -> (listof path-string?)
;;   Resolve ffi-files to existing paths and fail if any are missing.
(define (resolve-ffi-files! who ffi-files)
  (for/list ([ffi-filename ffi-files])
    (define resolved (resolve-ffi-filename ffi-filename))
    (unless resolved
      (error who
             (~a "ffi file not found: " ffi-filename)))
    resolved))

;; ffi-filename-basename : path-string? -> string?
;;   Return the last path component for an ffi file specification.
(define (ffi-filename-basename ffi-filename)
  (define pathish (if (path? ffi-filename)
                      ffi-filename
                      (string->path ffi-filename)))
  (define basename (file-name-from-path pathish))
  (and basename (path->string basename)))

;; ffi-filename-stem : path-string? -> (or/c string? #f)
;;   Return the ffi filename without its .ffi extension.
(define (ffi-filename-stem ffi-filename)
  (define basename (ffi-filename-basename ffi-filename))
  (and basename
       (path->string
        (path-replace-extension (string->path basename) #""))))

;; source->inferred-ffi-files : syntax? (listof path-string?) -> (listof path-string?)
;;   Infer direct ffi bundles from top-level `(include-lib ...)` forms in source.
(define (source->inferred-ffi-files stx ffi-files)
  (define suppressed-include-libs
    (remove-duplicates
     (append-map bundle->suppressed-include-lib-names ffi-files)))
  (define (top-level-include-lib-names datum)
    (cond
      [(and (pair? datum)
            (eq? (car datum) 'module)
            (pair? (cdr datum))
            (pair? (cddr datum)))
       (append-map top-level-include-lib-names (cdddr datum))]
      [(and (pair? datum)
            (memq (car datum) '(begin begin0)))
       (append-map top-level-include-lib-names (cdr datum))]
      [(and (pair? datum)
            (eq? (car datum) 'include-lib)
            (pair? (cdr datum))
            (symbol? (cadr datum))
            (null? (cddr datum)))
       (if (memq (cadr datum) suppressed-include-libs)
           '()
           (list (cadr datum)))]
      [else
       '()]))
  (define inferred
    (for/list ([lib-name (in-list (top-level-include-lib-names (syntax->datum stx)))]
               #:when (include-lib->ffi-filename lib-name))
      (include-lib->ffi-filename lib-name)))
  (remove-duplicates inferred))

;; module-source->inferred-ffi-files : path-string? (listof path-string?) -> (listof path-string?)
;;   Infer ffi bundles from the actual module-provider graph.
(define (module-source->inferred-ffi-files filename ffi-files)
  (define suppressed-ffi-stems
    (remove-duplicates
     (filter values (map ffi-filename-stem ffi-files))))
  (define provider-names
    (or (current-source-module-provider-names)
        (let-values ([(_root reports _local-source-paths)
                      (webracket/base-file->local-module-reports filename)])
          (module-reports->provider-names reports))))
  (for*/list ([provider-name (in-list provider-names)]
              [ffi-filename (in-list (module-provider->ffi-filenames provider-name))]
              #:unless (member (ffi-filename-stem ffi-filename)
                               suppressed-ffi-stems
                               equal?))
    ffi-filename))

;; default-ffi-files : boolean? -> (listof path-string?)
;;   Return the bundled FFI files enabled by default for the target.
(define (default-ffi-files browser?)
  (if browser?
      (list "standard.ffi" "dom.ffi")
      (list "standard.ffi")))

;; merged-ffi-files : symbol? boolean? (listof path-string?) [syntax?] -> (listof path?)
;;   Resolve and deduplicate default, explicit, and inferred ffi files.
;;     explicit: from the command line
;;     inferred: from include-lib and module-provider requires
(define (merged-ffi-files who browser? ffi-files [stx #f] #:source-filename [source-filename #f])
  (define resolved-base-ffi-files
    (remove-duplicates
     (resolve-ffi-files! who
                         (append (default-ffi-files browser?)
                                 ffi-files))))
  (define inferred-ffi-files
    (if stx
        (source->inferred-ffi-files stx resolved-base-ffi-files)
        '()))
  (define module-inferred-ffi-files
    (if (and source-filename (current-source-module-language))
        (module-source->inferred-ffi-files source-filename
                                           (append resolved-base-ffi-files
                                                   inferred-ffi-files))
        '()))
  (remove-duplicates
   (resolve-ffi-files! who
                       (append resolved-base-ffi-files
                               inferred-ffi-files
                               module-inferred-ffi-files))))

;;;
;;; Include Files
;;;

;; include-lib->ffi-filename : symbol? -> (or/c path-string? #f)
;;   Return the ffi bundle corresponding to a public include-lib library name.
(define include-lib->ffi-filename-table
  '((array      . "array.ffi")
    (audio      . "audio.ffi")
    (canvas     . "canvas.ffi")
    (console    . "console.ffi")
    (document   . "document.ffi")
    (dom        . "dom.ffi")
    (domrect    . "domrect.ffi")
    (element    . "element.ffi")
    (event      . "event.ffi")
    (audio      . "audio.ffi")
    (fetch      . "dom.ffi")          ; is window enough?
    (image      . "image.ffi")
    (iterator   . "iterator.ffi")
    (jsx-graph  . "jsxgraph.ffi")
    (media      . "media.ffi")
    (rquery     . "dom.ffi")
    (performance . "performance.ffi")
    (storage    . "dom.ffi")          ; smaller dep?
    (indexed-db . "dom.ffi")          ; smaller dep?
    (websocket  . "websocket.ffi")
    (window     . "window.ffi")
    (web-easy   . "dom.ffi")
    (web-pict   . "dom.ffi")))

(define (include-lib->ffi-filename lib-name)
  (define maybe (assq lib-name include-lib->ffi-filename-table))
  (and maybe (cdr maybe)))


;; bundle->suppressed-include-lib-names : string? -> (listof symbol?)
;;   Return include-lib names that are already covered by an explicit ffi bundle.
;;   This keeps umbrella bundles like `dom.ffi` from re-adding the sublibs
;;   they already include transitively.
(define bundle->suppressed-include-lib-names-table
  '(("dom"    . (array canvas document domrect element event image media performance window))
    ("canvas" . (array media))))

(define (bundle->suppressed-include-lib-names ffi-filename)
  (define basename (ffi-filename-stem ffi-filename))
  (define maybe (and basename (assoc basename bundle->suppressed-include-lib-names-table)))
  (if maybe
      (cdr maybe)
      '()))

;;;
;;; Printing of top-level results
;;;

;; --print-top-level-results
;;   Print each top-level expression result with print.

;; When this option is present, the compiler wraps top-level expressions.
;; The compiler needs to know where the standard library ends and where
;; the user program starts, so we insert a sentinel.

;; add-print-top-level-results-sentinel : syntax? -> syntax?
;;   Insert a compiler-private definition immediately before user forms.
(define (add-print-top-level-results-sentinel stx)
  (define sentinel-id (datum->syntax stx print-top-level-results-sentinel-symbol stx))
  #`(begin
      (define #,sentinel-id (void))
      #,stx))

;; stdlib-cell-symbol : exact-nonnegative-integer? -> symbol?
;;   Produce a private top-level cell name for a stdlib export alias.
(define (stdlib-cell-symbol i)
  (string->symbol (format "webify-stdlib-export-cell$~a" i)))

(define current-provider-cache-dir
  (make-parameter webify-regexp-default-cache-root))

(define current-provider-cache-force?
  (make-parameter #f))

(define current-provider-cache-verbose?
  (make-parameter #f))

(define current-webracket/base-provider-substitutions?
  (make-parameter #t))

(define current-read-source-timing-rows
  (make-parameter '()))

(define current-module-bridge-detail-rows
  (make-parameter '()))

(define current-module-bridge-needs-regexp-provider?
  (make-parameter #t))

;; module-bridge-datum-needs-regexp-provider? : any/c -> boolean?
;;   Detect whether the composed bridge datum refers to staged regexp bindings.
(define (module-bridge-datum-needs-regexp-provider? datum)
  (define target-symbols
    (for/hasheq ([sym (in-list (append webify-regexp-export-symbols
                                       webify-regexp-bootstrap-helper-symbols))])
      (values sym #t)))
  (define found? #f)
  (define visited-pairs (make-weak-hasheq))
  (define (walk v)
    (unless found?
      (cond
        [(symbol? v)
         (when (hash-ref target-symbols v #f)
           (set! found? #t))]
        [(or (regexp? v) (byte-regexp? v) (pregexp? v) (byte-pregexp? v))
         (set! found? #t)]
        [(pair? v)
         (unless (hash-ref visited-pairs v #f)
           (hash-set! visited-pairs v #t)
           (walk (car v))
           (walk (cdr v)))]
        [(vector? v)
         (for ([elt (in-vector v)])
           (walk elt))]
        [else (void)])))
  (walk datum)
  found?)

;; module-bridge-datum-operator-count : any/c symbol? -> exact-nonnegative-integer?
;;   Count bridge operator calls while skipping quoted/template data.
(define (module-bridge-datum-operator-count datum target)
  (cond
    [(pair? datum)
     (match datum
       [`(,(or 'quote 'quote-syntax 'syntax 'quasiquote) . ,_)
        0]
       [`(,head . ,rest)
        (+ (if (eq? head target) 1 0)
           (module-bridge-datum-operator-count head target)
           (module-bridge-datum-operator-count rest target))]
       [_ 0])]
    [(vector? datum)
     (for/sum ([entry (in-vector datum)])
       (module-bridge-datum-operator-count entry target))]
    [else
     0]))

;; module-bridge-report-reexport-count : webify-module-report? -> exact-nonnegative-integer?
;;   Approximate phase-0 reexports as names that are both imported and exported.
(define (module-bridge-report-reexport-count report)
  (define imported
    (remove-duplicates
     (webify-module-report-phase0-imports report)
     eq?))
  (for/sum ([export (in-list (remove-duplicates
                              (webify-module-report-phase0-exports report)
                              eq?))])
    (if (memq export imported) 1 0)))

;; bridge-export-cell-meta-entries : hash? -> (listof (cons/c list? hash?))
;;   Extract per-cell metadata rows recorded during bridge generation.
(define (bridge-export-cell-meta-entries stats)
  (for/list ([(key value) (in-hash stats)]
             #:when (match key
                      [(list 'bridge-export-cell-meta _module-name _export) #t]
                      [_ #f]))
    (cons key value)))

;; bridge-export-cell-module-counts : hash? -> hasheq?
;;   Collect per-module export-cell counts from the active bridge stats.
(define (bridge-export-cell-module-counts stats)
  (for/hasheq ([(key value) (in-hash stats)]
               #:when (match key
                        [(list 'bridge-export-cell-module (? symbol? _name)) #t]
                        [_ #f]))
    (match key
      [(list 'bridge-export-cell-module name)
       (values name value)])))

;; bridge-export-cell-name-counts : hash? -> hasheq?
;;   Collect per-export-name bridge counts from the active bridge stats.
(define (bridge-export-cell-name-counts stats)
  (for/hasheq ([(key value) (in-hash stats)]
               #:when (match key
                        [(list 'bridge-export-cell-name (? symbol? _name)) #t]
                        [_ #f]))
    (match key
      [(list 'bridge-export-cell-name name)
       (values name value)])))

;; bridge-import-abi-meta-entries : hash? -> (listof hash?)
;;   Extract per-import ABI metadata recorded during linklet slice analysis.
(define (bridge-import-abi-meta-entries stats)
  (for/list ([(key value) (in-hash stats)]
             #:when (match key
                      [(list 'bridge-import-abi-meta _importer _provider _import _export) #t]
                      [_ #f]))
    value))

;; bridge-import-abi-false-module-counts : hash? -> hasheq?
;;   Count ABI-`#f` imports by provider module.
(define (bridge-import-abi-false-module-counts stats)
  (for/hasheq ([(key value) (in-hash stats)]
               #:when (match key
                        [(list 'bridge-import-abi-false-module (? symbol? _name)) #t]
                        [_ #f]))
    (match key
      [(list 'bridge-import-abi-false-module name)
       (values name value)])))

;; bridge-import-abi-false-name-counts : hash? -> hasheq?
;;   Count ABI-`#f` imports by provider export name.
(define (bridge-import-abi-false-name-counts stats)
  (for/hasheq ([(key value) (in-hash stats)]
               #:when (match key
                        [(list 'bridge-import-abi-false-name (? symbol? _name)) #t]
                        [_ #f]))
    (match key
      [(list 'bridge-import-abi-false-name name)
       (values name value)])))

;; bridge-import-abi-false-provider-kind-counts : hash? -> hasheq?
;;   Count ABI-`#f` imports by provider ownership kind.
(define (bridge-import-abi-false-provider-kind-counts stats)
  (for/hasheq ([(key value) (in-hash stats)]
               #:when (match key
                        [(list 'bridge-import-abi-false-provider-kind _kind) #t]
                        [_ #f]))
    (match key
      [(list 'bridge-import-abi-false-provider-kind kind)
       (values kind value)])))

;; bridge-import-abi-false-reason-counts : hash? -> hasheq?
;;   Count ABI-`#f` imports by the recorded analysis fallback reason.
(define (bridge-import-abi-false-reason-counts stats)
  (for/hasheq ([(key value) (in-hash stats)]
               #:when (match key
                        [(list 'bridge-import-abi-false-reason _reason) #t]
                        [_ #f]))
    (match key
      [(list 'bridge-import-abi-false-reason reason)
       (values reason value)])))

;; bridge-import-abi-false-filtered-counts : hash? symbol? (-> hash? any/c) -> hasheq?
;;   Count ABI-`#f` import metadata rows by extractor after filtering on reason.
(define (bridge-import-abi-false-filtered-counts stats false-reason extractor)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-import-abi-meta-entries stats))])
    (if (and (not (hash-ref entry 'abi #f))
             (eq? (hash-ref entry 'false-reason #f) false-reason))
        (let ([key (extractor entry)])
          (if key
              (hash-update counts key add1 0)
              counts))
        counts)))

;; bridge-import-abi-false-kernel-entries : hash? -> (listof hash?)
;;   Collect ABI-`#f` import metadata rows for `#%kernel`-classified providers.
(define (bridge-import-abi-false-kernel-entries stats)
  (for/list ([entry (in-list (bridge-import-abi-meta-entries stats))]
             #:when (and (not (hash-ref entry 'abi #f))
                         (eq? (hash-ref entry 'provider-kind #f) 'kernel-provider)))
    entry))

;; bridge-import-abi-false-kernel-counts : hash? (-> hash? any/c) -> hasheq?
;;   Count kernel ABI holdouts using one metadata field extractor.
(define (bridge-import-abi-false-kernel-counts stats extractor)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-import-abi-false-kernel-entries stats))])
    (define key (extractor entry))
    (if key
        (hash-update counts key add1 0)
        counts)))

;; bridge-import-abi-false-kernel-details : hash? -> string?
;;   Render a bounded detail list for residual kernel ABI-`#f` imports.
(define (bridge-import-abi-false-kernel-details stats)
  (define entries
    (sort (bridge-import-abi-false-kernel-entries stats)
          (lambda (a b)
            (define a-importer (~a (hash-ref a 'importer-module #f)))
            (define b-importer (~a (hash-ref b 'importer-module #f)))
            (or (string<? a-importer b-importer)
                (and (string=? a-importer b-importer)
                     (string<?
                      (~a (hash-ref a 'import-name #f))
                      (~a (hash-ref b 'import-name #f))))))))
  (define details
    (for/list ([entry (in-list (take entries (min 10 (length entries))))])
      (define importer-module (hash-ref entry 'importer-module #f))
      (define import-name (hash-ref entry 'import-name #f))
      (define export-name (hash-ref entry 'export-name #f))
      (define group-key (hash-ref entry 'group-key #f))
      (define false-reason (hash-ref entry 'false-reason #f))
      (define kernel-known? (hash-ref entry 'kernel-known? #f))
      (define provider-export-meta
        (and (symbol? (hash-ref entry 'provider-module #f))
             (symbol? export-name)
             (hash-ref stats
                       (list 'bridge-export-cell-meta
                             (hash-ref entry 'provider-module #f)
                             export-name)
                       #f)))
      (format "~a import=~a export=~a group=~a abi-false=~a candidate=~a forced-cell=~a kernel-known=~a"
              importer-module
              import-name
              export-name
              (or group-key '-)
              false-reason
              (cond
                [(not provider-export-meta) "-"]
                [(bridge-public-cell-base-candidate? provider-export-meta) "yes"]
                [else "no"])
              (if (and provider-export-meta
                       (bridge-public-cell-forced-cell? provider-export-meta))
                  "yes"
                  (if provider-export-meta "no" "-"))
              (if kernel-known? "yes" "no"))))
  (if (null? details)
      ""
      (string-join details " | ")))

;; bridge-top-count-summary : hasheq? -> string?
;;   Render the largest bucket counts in descending order for timing output.
(define (bridge-top-count-summary counts)
  (define entries
    (sort (hash->list counts)
          (lambda (a b)
            (define av (cdr a))
            (define bv (cdr b))
            (or (> av bv)
                (and (= av bv)
                     (symbol<? (car a) (car b)))))))
  (if (null? entries)
      "-"
      (string-join
       (for/list ([entry (in-list (take entries (min 5 (length entries))))])
         (format "~a(~a)" (car entry) (cdr entry)))
       ", ")))

;; bridge-public-cell-classification : hash? hash? -> symbol?
;;   Classify one public export cell by the first conservative reason it must stay cell-backed.
(define (bridge-public-cell-classification graph meta)
  (define module-name (hash-ref meta 'module-name #f))
  (define module-kinds
    (webracket/base-local-module-graph-module-kinds graph))
  (define (missing? key)
    (not (hash-has-key? meta key)))
  (define unknown?
    (or (not module-name)
        (not (hash-has-key? module-kinds module-name))
        (missing? 'public-boundary?)
        (missing? 'immutable?)
        (missing? 'reexport?)
        (missing? 'mutated?)
        (missing? 'undefined-sensitive?)
        (missing? 'reflection-visible?)
        (missing? 'dynamic-require-sensitive?)
        (missing? 'phase0-value-space-only?)))
  (cond
    [unknown? 'required-unknown]
    [(not (hash-ref meta 'public-boundary? #f)) 'required-unknown]
    [(hash-ref meta 'reflection-visible? #f) 'required-reflection]
    [(hash-ref meta 'dynamic-require-sensitive? #f) 'required-dynamic-require]
    [(or (not (hash-ref meta 'immutable? #f))
         (hash-ref meta 'mutated? #f))
     'required-mutation]
    [(hash-ref meta 'undefined-sensitive? #f) 'required-undefined]
    [(hash-ref meta 'reexport? #f) 'required-reexport]
    [(not (hash-ref meta 'phase0-value-space-only? #f)) 'required-phase-space]
    [else 'plain-value-candidate]))

;; bridge-public-cell-provider-kind : hash? hash? -> symbol?
;;   Classify one public export by the graph ownership of its defining module.
(define (bridge-public-cell-provider-kind graph meta)
  (define module-name (hash-ref meta 'module-name #f))
  (cond
    [(not (symbol? module-name)) 'unknown-provider]
    [else
     (hash-ref (webracket/base-local-module-graph-module-kinds graph)
               module-name
               'unknown-provider)]))

;; bridge-public-cell-base-candidate? : hash? -> boolean?
;;   Check whether one export is safety-eligible before policy and importer constraints.
(define (bridge-public-cell-base-candidate? meta)
  (hash-ref meta
            'plain-value-base-candidate?
            (eq? (hash-ref meta 'selected-export-kind 'cell)
                 'value)))

;; bridge-public-cell-policy-eligible? : hash? -> boolean?
;;   Check whether the current elision policy allows this export's defining module.
(define (bridge-public-cell-policy-eligible? meta)
  (hash-ref meta
            'plain-value-policy-eligible?
            (bridge-public-cell-base-candidate? meta)))

;; bridge-public-cell-forced-cell? : hash? -> boolean?
;;   Check whether some importer path still requires a cell-backed export entry.
(define (bridge-public-cell-forced-cell? meta)
  (hash-ref meta 'forced-cell? #f))

;; bridge-public-cell-selected-kind : hash? -> symbol?
;;   Read the final export-entry ABI choice recorded for one public export.
(define (bridge-public-cell-selected-kind meta)
  (hash-ref meta 'selected-export-kind 'cell))

;; bridge-public-cell-candidate-not-elided? : hash? -> boolean?
;;   Check whether a safety-eligible export stayed cell-backed.
(define (bridge-public-cell-candidate-not-elided? meta)
  (and (bridge-public-cell-base-candidate? meta)
       (not (eq? (bridge-public-cell-selected-kind meta) 'value))))

;; bridge-export-cell-role-counts : graph hash? -> hasheq?
;;   Partition export-cell counts by local/support/installed module ownership.
(define (bridge-export-cell-role-counts graph stats)
  (define module-counts (bridge-export-cell-module-counts stats))
  (for/fold ([counts (hasheq 'local-user 0
                             'support-provider 0
                             'installed-provider 0
                             'kernel-provider 0)])
            ([(name cell-count) (in-hash module-counts)])
    (define kind
      (hash-ref (webracket/base-local-module-graph-module-kinds graph)
                name
                'installed-provider))
    (hash-update counts kind (lambda (n) (+ n cell-count)) 0)))

;; bridge-public-cell-required-counts : graph hash? -> hasheq?
;;   Count public export cells by the conservative reason they must keep a cell.
(define (bridge-public-cell-required-counts graph stats)
  (for/fold ([counts (hasheq 'required-reflection 0
                             'required-dynamic-require 0
                             'required-mutation 0
                             'required-undefined 0
                             'required-reexport 0
                             'required-phase-space 0
                             'required-unknown 0
                             'plain-value-candidate 0)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (define reason
      (bridge-public-cell-classification graph meta))
    (hash-update counts reason add1 0)))

;; bridge-public-cell-candidate-module-counts : graph hash? -> hasheq?
;;   Count candidate plain-value public exports per provider module.
(define (bridge-public-cell-candidate-module-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (define module-name (hash-ref meta 'module-name #f))
    (if (and module-name
             (eq? (bridge-public-cell-classification graph meta)
                  'plain-value-candidate))
        (hash-update counts module-name add1 0)
        counts)))

;; bridge-public-cell-candidate-name-counts : graph hash? -> hasheq?
;;   Count candidate plain-value public exports per exported name.
(define (bridge-public-cell-candidate-name-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (define export-name (hash-ref meta 'export #f))
    (if (and export-name
             (eq? (bridge-public-cell-classification graph meta)
                  'plain-value-candidate))
        (hash-update counts export-name add1 0)
        counts)))

;; bridge-public-cell-candidate-not-elided-counts : hash? hash? -> hasheq?
;;   Count why safety-eligible exports stayed cell-backed under the current ABI.
(define (bridge-public-cell-candidate-not-elided-counts graph stats)
  (for/fold ([counts (hasheq 'candidate-not-elided 0
                             'candidate-not-elided-local-only-policy 0
                             'candidate-not-elided-provider-export 0
                             'candidate-not-elided-support-provider 0
                             'candidate-not-elided-installed-provider 0
                             'candidate-not-elided-kernel-provider 0
                             'candidate-not-elided-importer-needs-cell 0
                             'candidate-not-elided-registry-shape 0
                             'candidate-not-elided-unknown 0)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (if (not (bridge-public-cell-candidate-not-elided? meta))
        counts
        (let* ([provider-kind (bridge-public-cell-provider-kind graph meta)]
               [counts* (hash-update counts 'candidate-not-elided add1 0)]
               [counts** (case provider-kind
                           [(support-provider)
                            (hash-update
                             (hash-update counts* 'candidate-not-elided-provider-export add1 0)
                             'candidate-not-elided-support-provider
                             add1
                             0)]
                           [(installed-provider)
                           (hash-update
                             (hash-update counts* 'candidate-not-elided-provider-export add1 0)
                             'candidate-not-elided-installed-provider
                             add1
                             0)]
                           [(kernel-provider)
                            (hash-update
                             (hash-update counts* 'candidate-not-elided-provider-export add1 0)
                             'candidate-not-elided-kernel-provider
                             add1
                             0)]
                           [(unknown-provider)
                            (hash-update counts* 'candidate-not-elided-unknown add1 0)]
                           [else counts*])])
          (cond
            [(not (bridge-public-cell-policy-eligible? meta))
             (hash-update counts** 'candidate-not-elided-local-only-policy add1 0)]
            [(bridge-public-cell-forced-cell? meta)
             (hash-update counts** 'candidate-not-elided-importer-needs-cell add1 0)]
            [(eq? (bridge-public-cell-selected-kind meta) 'value)
             counts**]
            [else
             (hash-update counts** 'candidate-not-elided-registry-shape add1 0)])))))

;; bridge-public-cell-candidate-not-elided-module-counts : hash? hash? -> hasheq?
;;   Count non-elided safety candidates per defining module.
(define (bridge-public-cell-candidate-not-elided-module-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (define module-name (hash-ref meta 'module-name #f))
    (if (and module-name
             (bridge-public-cell-candidate-not-elided? meta))
        (hash-update counts module-name add1 0)
        counts)))

;; bridge-public-cell-candidate-not-elided-name-counts : hash? hash? -> hasheq?
;;   Count non-elided safety candidates per export name.
(define (bridge-public-cell-candidate-not-elided-name-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (define export-name (hash-ref meta 'export #f))
    (if (and export-name
             (bridge-public-cell-candidate-not-elided? meta))
        (hash-update counts export-name add1 0)
        counts)))

;; bridge-import-abi-false-elision-candidate-count : hash? hash? -> exact-nonnegative-integer?
;;   Count ABI-`#f` imports whose provider exports are otherwise plain-value candidates.
(define (bridge-import-abi-false-elision-candidate-count graph stats)
  (for/sum ([entry (in-list (bridge-import-abi-meta-entries stats))])
    (define provider (hash-ref entry 'provider-module #f))
    (define export-name (hash-ref entry 'export-name #f))
    (define export-meta
      (and provider
           export-name
           (hash-ref stats (list 'bridge-export-cell-meta provider export-name) #f)))
    (if (and export-meta
             (eq? (bridge-public-cell-classification graph export-meta)
                  'plain-value-candidate)
             (not (hash-ref entry 'abi #f)))
        1
        0)))

;; bridge-public-cell-candidate-not-elided-reason : hash? hash? -> symbol?
;;   Explain why one safety-eligible export stayed cell-backed.
(define (bridge-public-cell-candidate-not-elided-reason graph meta)
  (cond
    [(not (bridge-public-cell-policy-eligible? meta))
     'local-only-policy]
    [(bridge-public-cell-forced-cell? meta)
     'importer-needs-cell]
    [(eq? (bridge-public-cell-selected-kind meta) 'value)
     'elided]
    [else
     'registry-shape]))

;; bridge-import-abi-provider-export-entries : hash? symbol? symbol? -> (listof hash?)
;;   Collect per-import ABI metadata rows for one provider export.
(define (bridge-import-abi-provider-export-entries stats provider-name export-name)
  (for/list ([entry (in-list (bridge-import-abi-meta-entries stats))]
             #:when (and (eq? (hash-ref entry 'provider-module #f) provider-name)
                         (eq? (hash-ref entry 'export-name #f) export-name)))
    entry))

;; bridge-public-cell-candidate-not-elided-support-provider-entries : hash? hash? -> (listof (cons any/c hash?))
;;   Collect non-elided support-provider candidate export metadata entries.
(define (bridge-public-cell-candidate-not-elided-support-provider-entries graph stats)
  (for/list ([entry (in-list (bridge-export-cell-meta-entries stats))]
             #:do [(define meta (cdr entry))]
             #:when (and (bridge-public-cell-candidate-not-elided? meta)
                         (eq? (bridge-public-cell-provider-kind graph meta)
                              'support-provider)))
    entry))

;; bridge-public-cell-candidate-not-elided-support-provider-module-counts : hash? hash? -> hasheq?
;;   Count residual support-provider holdouts by provider module.
(define (bridge-public-cell-candidate-not-elided-support-provider-module-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-public-cell-candidate-not-elided-support-provider-entries graph stats))])
    (define module-name (hash-ref (cdr entry) 'module-name #f))
    (if module-name
        (hash-update counts module-name add1 0)
        counts)))

;; bridge-public-cell-candidate-not-elided-support-provider-name-counts : hash? hash? -> hasheq?
;;   Count residual support-provider holdouts by export name.
(define (bridge-public-cell-candidate-not-elided-support-provider-name-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-public-cell-candidate-not-elided-support-provider-entries graph stats))])
    (define export-name (hash-ref (cdr entry) 'export #f))
    (if export-name
        (hash-update counts export-name add1 0)
        counts)))

;; bridge-public-cell-candidate-not-elided-support-provider-details : hash? hash? -> string?
;;   Render a bounded detail list for residual support-provider holdouts.
(define (bridge-public-cell-candidate-not-elided-support-provider-details graph stats)
  (define support-provider-entries
    (bridge-public-cell-candidate-not-elided-support-provider-entries graph stats))
  (define details
    (for/list ([entry (in-list (take support-provider-entries
                                     (min 10 (length support-provider-entries))))])
      (define meta (cdr entry))
      (define provider-module (hash-ref meta 'module-name #f))
      (define export-name (hash-ref meta 'export #f))
      (define import-entries
        (bridge-import-abi-provider-export-entries stats provider-module export-name))
      (define importer-modules
        (remove-duplicates
         (for/list ([import-entry (in-list import-entries)])
           (hash-ref import-entry 'importer-module #f))
         eq?))
      (define import-abis
        (remove-duplicates
         (for/list ([import-entry (in-list import-entries)])
           (hash-ref import-entry 'abi #f))
         equal?))
      (define abi-false-reasons
        (remove-duplicates
         (for/list ([import-entry (in-list import-entries)]
                    #:when (not (hash-ref import-entry 'abi #f)))
           (hash-ref import-entry 'false-reason #f))
         eq?))
      (format "~a/~a importers=~a abi=~a provider-kind=~a not-elided=~a abi-false=~a cell-forced=~a"
              provider-module
              export-name
              (if (null? importer-modules) "-" (string-join (map ~a importer-modules) ","))
              (if (null? import-abis) "-" (string-join (map ~a import-abis) ","))
              (hash-ref meta 'provider-kind 'unknown-provider)
              (bridge-public-cell-candidate-not-elided-reason graph meta)
              (if (null? abi-false-reasons) "-" (string-join (map ~a abi-false-reasons) ","))
              (if (bridge-public-cell-forced-cell? meta) "yes" "no"))))
  (if (null? details)
      ""
      (string-join details " | ")))

;; installed-provider-policy-class : symbol? -> symbol?
;;   Split installed providers into the current public-cell elision policy buckets.
(define (installed-provider-policy-class module-name)
  (cond
    [(not (symbol? module-name))
     'unknown-installed-provider]
    [(webracket-owned-ffi-provider-name? module-name)
     'webracket-owned-installed-provider]
    [(string-prefix? (symbol->string module-name) "racket/")
     'racket-installed-provider]
    [else
     'third-party-installed-provider]))

;; racket-installed-provider-elision-allowed-module? : any/c -> boolean?
;;   Narrow allowlist for upstream Racket installed providers eligible for elision.
(define (racket-installed-provider-elision-allowed-module? module-name)
  (and (symbol? module-name)
       (memq module-name
             '(racket/private/list
               racket/list
               racket/private/more-scheme
               racket/private/string
               racket/string))))

;; bridge-installed-provider-candidate-not-elided-entries : hash? hash? -> (listof (cons any/c hash?))
;;   Collect non-elided installed-provider candidate export metadata entries.
(define (bridge-installed-provider-candidate-not-elided-entries graph stats)
  (for/list ([entry (in-list (bridge-export-cell-meta-entries stats))]
             #:do [(define meta (cdr entry))]
             #:when (and (bridge-public-cell-candidate-not-elided? meta)
                         (eq? (bridge-public-cell-provider-kind graph meta)
                              'installed-provider)))
    entry))

;; bridge-installed-provider-candidate-class-counts : hash? hash? -> hasheq?
;;   Count residual installed-provider candidates by policy class.
(define (bridge-installed-provider-candidate-class-counts graph stats)
  (for/fold ([counts (hasheq 'webracket-owned-installed-provider 0
                             'racket-installed-provider 0
                             'third-party-installed-provider 0
                             'unknown-installed-provider 0)])
            ([entry (in-list (bridge-installed-provider-candidate-not-elided-entries graph stats))])
    (define meta (cdr entry))
    (hash-update counts
                 (installed-provider-policy-class (hash-ref meta 'module-name #f))
                 add1
                 0)))

;; bridge-installed-provider-candidate-module-counts : hash? hash? -> hasheq?
;;   Count residual installed-provider candidates by provider module.
(define (bridge-installed-provider-candidate-module-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-installed-provider-candidate-not-elided-entries graph stats))])
    (define module-name (hash-ref (cdr entry) 'module-name #f))
    (if module-name
        (hash-update counts module-name add1 0)
        counts)))

;; bridge-installed-provider-candidate-name-counts : hash? hash? -> hasheq?
;;   Count residual installed-provider candidates by export name.
(define (bridge-installed-provider-candidate-name-counts graph stats)
  (for/fold ([counts (hasheq)])
            ([entry (in-list (bridge-installed-provider-candidate-not-elided-entries graph stats))])
    (define export-name (hash-ref (cdr entry) 'export #f))
    (if export-name
        (hash-update counts export-name add1 0)
        counts)))

;; bridge-installed-provider-candidate-class-details : hash? hash? symbol? -> string?
;;   Render a bounded detail list for one installed-provider policy class.
(define (bridge-installed-provider-candidate-class-details graph stats class)
  (define entries
    (filter (lambda (entry)
              (eq? (installed-provider-policy-class
                    (hash-ref (cdr entry) 'module-name #f))
                   class))
            (bridge-installed-provider-candidate-not-elided-entries graph stats)))
  (define details
    (for/list ([entry (in-list (take entries (min 50 (length entries))))])
      (define meta (cdr entry))
      (define provider-module (hash-ref meta 'module-name #f))
      (define export-name (hash-ref meta 'export #f))
      (define import-entries
        (bridge-import-abi-provider-export-entries stats provider-module export-name))
      (define importer-modules
        (remove-duplicates
         (for/list ([import-entry (in-list import-entries)])
           (hash-ref import-entry 'importer-module #f))
         eq?))
      (define import-abis
        (remove-duplicates
         (for/list ([import-entry (in-list import-entries)])
           (hash-ref import-entry 'abi #f))
         equal?))
      (format "~a/~a constance=~a immutable=~a phase0=~a dynamic=~a reflection=~a importers=~a importer-modules=~a import-abi=~a reason=~a"
              provider-module
              export-name
              (hash-ref meta 'constance #f)
              (hash-ref meta 'immutable? #f)
              (hash-ref meta 'phase0-value-space-only? #f)
              (hash-ref meta 'dynamic-require-sensitive? #f)
              (hash-ref meta 'reflection-visible? #f)
              (length importer-modules)
              (if (null? importer-modules) "-" (string-join (map ~a importer-modules) ","))
              (if (null? import-abis) "-" (string-join (map ~a import-abis) ","))
              (bridge-public-cell-candidate-not-elided-reason graph meta))))
  (if (null? details)
      ""
      (string-join details " | ")))

;; bridge-public-cell-elided-installed-provider-class-counts : hash? hash? -> hasheq?
;;   Count installed-provider exports that now elide by policy class.
(define (bridge-public-cell-elided-installed-provider-class-counts graph stats)
  (for/fold ([counts (hasheq 'webracket-owned-installed-provider 0
                             'racket-installed-provider 0
                             'third-party-installed-provider 0
                             'unknown-installed-provider 0)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (if (and (eq? (bridge-public-cell-provider-kind graph meta) 'installed-provider)
             (eq? (bridge-public-cell-selected-kind meta) 'value))
        (hash-update counts
                     (installed-provider-policy-class (hash-ref meta 'module-name #f))
                     add1
                     0)
        counts)))

;; bridge-racket-installed-provider-kept-reason-counts : hash? hash? -> hasheq?
;;   Count why Racket installed-provider exports remain cell-backed.
(define (bridge-racket-installed-provider-kept-reason-counts graph stats)
  (for/fold ([counts (hasheq 'metadata 0
                             'abi 0
                             'policy 0)])
            ([entry (in-list (bridge-export-cell-meta-entries stats))])
    (define meta (cdr entry))
    (define module-name (hash-ref meta 'module-name #f))
    (if (and (eq? (bridge-public-cell-provider-kind graph meta) 'installed-provider)
             (eq? (installed-provider-policy-class module-name)
                  'racket-installed-provider)
             (not (eq? (bridge-public-cell-selected-kind meta) 'value)))
        (cond
          [(not (bridge-public-cell-base-candidate? meta))
           (hash-update counts 'metadata add1 0)]
          [(bridge-public-cell-forced-cell? meta)
           (hash-update counts 'abi add1 0)]
          [else
           (hash-update counts 'policy add1 0)])
        counts)))

;; bridge-module-elidable-public-modules : graph -> (listof symbol?)
;;   List modules currently allowed to expose safe public exports as plain values.
(define (bridge-module-elidable-public-modules graph)
  (for/list ([(name kind)
              (in-hash (webracket/base-local-module-graph-module-kinds graph))]
             #:when (or (memq kind '(local-user support-provider))
                        (and (eq? kind 'installed-provider)
                             (or (webracket-owned-ffi-provider-name? name)
                                 (racket-installed-provider-elision-allowed-module? name)))))
    name))

;; module-bridge-graph-metric-rows : graph composition -> (listof (list/c string? any/c))
;;   Summarize bridge scaffolding and graph shape before the main compiler pipeline.
(define (module-bridge-graph-metric-rows graph composition)
  (define reports (webracket/base-local-module-graph-reports graph))
  (define datum   (webify-module-composition-datum composition))
  (define stats   (or (current-webify-bridge-stats) (make-hash)))
  (define elision-enabled?
    (current-module-bridge-elide-public-cells?))
  (define local-module-count (length reports))
  (define direct-provider-names (webracket/base-external-provider-names reports))
  (define graph-module-count
    (hash-count (webify-module-composition-instances composition)))
  (define total-export-count
    (for/sum ([report (in-list reports)])
      (length (webify-module-report-phase0-exports report))))
  (define total-import-count
    (for/sum ([report (in-list reports)])
      (length (webify-module-report-phase0-imports report))))
  (define reexport-count
    (for/sum ([report (in-list reports)])
      (module-bridge-report-reexport-count report)))
  (define role-counts
    (bridge-export-cell-role-counts graph stats))
  (define public-cell-counts
    (bridge-public-cell-required-counts graph stats))
  (define public-cell-candidate-not-elided-counts
    (bridge-public-cell-candidate-not-elided-counts graph stats))
  (define installed-provider-candidate-class-counts
    (bridge-installed-provider-candidate-class-counts graph stats))
  (define installed-provider-elided-class-counts
    (bridge-public-cell-elided-installed-provider-class-counts graph stats))
  (define racket-installed-provider-kept-reason-counts
    (bridge-racket-installed-provider-kept-reason-counts graph stats))
  (define (stat key [default 0])
    (hash-ref stats key default))
  (list
   (list "bridge-module-variable-make-count"
         (module-bridge-datum-operator-count datum 'module-variable-make))
   (list "bridge-module-variable-define-count"
         (module-bridge-datum-operator-count datum 'module-variable-define!))
   (list "bridge-module-variable-ref-count"
         (module-bridge-datum-operator-count datum 'module-variable-ref))
   (list "bridge-module-variable-ref-no-check-count"
         (module-bridge-datum-operator-count datum 'module-variable-ref/no-check))
   (list "bridge-module-variable-set-count"
         (+ (module-bridge-datum-operator-count datum 'module-variable-set!)
            (module-bridge-datum-operator-count datum 'module-variable-set!/check-undefined!)))
   (list "bridge-export-cell-count" (stat 'bridge-export-cell-count))
   (list "bridge-export-cell-local-user-count" (hash-ref role-counts 'local-user 0))
   (list "bridge-export-cell-support-provider-count" (hash-ref role-counts 'support-provider 0))
   (list "bridge-export-cell-installed-provider-count" (hash-ref role-counts 'installed-provider 0))
   (list "bridge-export-cell-kernel-provider-count" (hash-ref role-counts 'kernel-provider 0))
   (list "bridge-export-cell-reexport-count" (stat 'bridge-export-cell-reexport-count))
   (list "bridge-export-cell-internal-count"
         (- (stat 'bridge-export-cell-count)
            (stat 'bridge-export-cell-public-boundary-count)))
   (list "bridge-export-cell-mutated-count" (stat 'bridge-export-cell-mutated-count))
   (list "bridge-export-cell-undefined-sensitive-count"
         (stat 'bridge-export-cell-undefined-sensitive-count))
   (list "bridge-export-cell-reflection-visible-count"
         (stat 'bridge-export-cell-reflection-visible-count))
   (list "bridge-export-cell-public-boundary-count"
         (stat 'bridge-export-cell-public-boundary-count))
   (list "bridge-export-cell-late-materialization-candidate-count"
         (stat 'bridge-export-cell-late-materialization-candidate-count))
   (list "bridge-public-cell-count"
         (stat 'bridge-export-cell-public-boundary-count))
   (list "module-bridge-public-cell-elision-mode"
         (if elision-enabled? "enabled" "disabled"))
   (list "bridge-public-cell-required-reflection-count"
         (hash-ref public-cell-counts 'required-reflection 0))
   (list "bridge-public-cell-required-dynamic-require-count"
         (hash-ref public-cell-counts 'required-dynamic-require 0))
   (list "bridge-public-cell-required-mutation-count"
         (hash-ref public-cell-counts 'required-mutation 0))
   (list "bridge-public-cell-required-undefined-count"
         (hash-ref public-cell-counts 'required-undefined 0))
   (list "bridge-public-cell-required-reexport-count"
         (hash-ref public-cell-counts 'required-reexport 0))
   (list "bridge-public-cell-required-phase-space-count"
         (hash-ref public-cell-counts 'required-phase-space 0))
   (list "bridge-public-cell-required-unknown-count"
         (hash-ref public-cell-counts 'required-unknown 0))
   (list "bridge-public-cell-plain-value-candidate-count"
         (hash-ref public-cell-counts 'plain-value-candidate 0))
   (list "bridge-public-cell-elided-count"
         (stat 'bridge-public-cell-elided-count))
   (list "bridge-public-cell-kept-count"
         (stat 'bridge-public-cell-kept-count))
   (list "bridge-public-cell-kept-required-count"
         (stat 'bridge-public-cell-kept-required-count))
   (list "bridge-public-cell-kept-mutation-count"
         (stat 'bridge-public-cell-kept-mutation-count))
   (list "bridge-public-cell-kept-undefined-count"
         (stat 'bridge-public-cell-kept-undefined-count))
   (list "bridge-public-cell-kept-reflection-count"
         (stat 'bridge-public-cell-kept-reflection-count))
   (list "bridge-public-cell-kept-dynamic-require-count"
         (stat 'bridge-public-cell-kept-dynamic-require-count))
   (list "bridge-public-cell-kept-reexport-count"
         (stat 'bridge-public-cell-kept-reexport-count))
   (list "bridge-public-cell-kept-unknown-count"
         (stat 'bridge-public-cell-kept-unknown-count))
   (list "bridge-public-cell-top-required-reasons"
         (bridge-top-count-summary
          (for/hasheq ([(key value) (in-hash public-cell-counts)]
                       #:unless (eq? key 'plain-value-candidate))
            (values key value))))
   (list "bridge-public-cell-top-plain-value-candidate-modules"
         (bridge-top-count-summary
          (bridge-public-cell-candidate-module-counts graph stats)))
   (list "bridge-public-cell-top-plain-value-candidate-names"
         (bridge-top-count-summary
          (bridge-public-cell-candidate-name-counts graph stats)))
   (list "bridge-public-cell-candidate-not-elided-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided
                   0))
   (list "bridge-public-cell-candidate-not-elided-local-only-policy-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-local-only-policy
                   0))
   (list "bridge-public-cell-candidate-not-elided-provider-export-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-provider-export
                   0))
   (list "bridge-public-cell-candidate-not-elided-support-provider-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-support-provider
                   0))
   (list "bridge-public-cell-candidate-not-elided-support-provider-top-modules"
         (bridge-top-count-summary
          (bridge-public-cell-candidate-not-elided-support-provider-module-counts
           graph
           stats)))
   (list "bridge-public-cell-candidate-not-elided-support-provider-top-names"
         (bridge-top-count-summary
          (bridge-public-cell-candidate-not-elided-support-provider-name-counts
           graph
           stats)))
   (list "bridge-public-cell-candidate-not-elided-support-provider-details"
         (bridge-public-cell-candidate-not-elided-support-provider-details
          graph
          stats))
   (list "bridge-public-cell-candidate-not-elided-installed-provider-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-installed-provider
                   0))
   (list "bridge-public-cell-candidate-not-elided-installed-provider-top-modules"
         (bridge-top-count-summary
          (bridge-installed-provider-candidate-module-counts graph stats)))
   (list "bridge-public-cell-candidate-not-elided-installed-provider-top-names"
         (bridge-top-count-summary
          (bridge-installed-provider-candidate-name-counts graph stats)))
   (list "bridge-public-cell-candidate-not-elided-installed-provider-details"
         (bridge-installed-provider-candidate-class-details
          graph
          stats
          'webracket-owned-installed-provider))
   (list "bridge-installed-provider-candidate-webracket-owned-count"
         (hash-ref installed-provider-candidate-class-counts
                   'webracket-owned-installed-provider
                   0))
   (list "bridge-installed-provider-candidate-racket-count"
         (hash-ref installed-provider-candidate-class-counts
                   'racket-installed-provider
                   0))
   (list "bridge-installed-provider-candidate-third-party-count"
         (hash-ref installed-provider-candidate-class-counts
                   'third-party-installed-provider
                   0))
   (list "bridge-installed-provider-candidate-unknown-count"
         (hash-ref installed-provider-candidate-class-counts
                   'unknown-installed-provider
                   0))
   (list "bridge-installed-provider-racket-candidate-details"
         (bridge-installed-provider-candidate-class-details
          graph
          stats
          'racket-installed-provider))
   (list "bridge-public-cell-elided-webracket-owned-installed-provider-count"
         (hash-ref installed-provider-elided-class-counts
                   'webracket-owned-installed-provider
                   0))
   (list "bridge-public-cell-kept-webracket-owned-installed-provider-count"
         (hash-ref installed-provider-candidate-class-counts
                   'webracket-owned-installed-provider
                   0))
   (list "bridge-public-cell-elided-racket-installed-provider-count"
         (hash-ref installed-provider-elided-class-counts
                   'racket-installed-provider
                   0))
   (list "bridge-public-cell-kept-racket-installed-provider-count"
         (hash-ref installed-provider-candidate-class-counts
                   'racket-installed-provider
                   0))
   (list "bridge-racket-installed-provider-elision-blocked-metadata-count"
         (hash-ref racket-installed-provider-kept-reason-counts
                   'metadata
                   0))
   (list "bridge-racket-installed-provider-elision-blocked-abi-count"
         (hash-ref racket-installed-provider-kept-reason-counts
                   'abi
                   0))
   (list "bridge-racket-installed-provider-elision-blocked-policy-count"
         (hash-ref racket-installed-provider-kept-reason-counts
                   'policy
                   0))
   (list "bridge-public-cell-candidate-not-elided-kernel-provider-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-kernel-provider
                   0))
   (list "bridge-public-cell-candidate-not-elided-importer-needs-cell-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-importer-needs-cell
                   0))
   (list "bridge-public-cell-candidate-not-elided-registry-shape-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-registry-shape
                   0))
   (list "bridge-public-cell-candidate-not-elided-unknown-count"
         (hash-ref public-cell-candidate-not-elided-counts
                   'candidate-not-elided-unknown
                   0))
   (list "bridge-public-cell-candidate-not-elided-top-modules"
         (bridge-top-count-summary
          (bridge-public-cell-candidate-not-elided-module-counts graph stats)))
   (list "bridge-public-cell-candidate-not-elided-top-names"
         (bridge-top-count-summary
          (bridge-public-cell-candidate-not-elided-name-counts graph stats)))
   (list "bridge-export-cell-elision-candidate-count"
         (hash-ref public-cell-counts 'plain-value-candidate 0))
   (list "bridge-export-cell-elision-blocked-reexport-count"
         (hash-ref public-cell-counts 'required-reexport 0))
   (list "bridge-export-cell-elision-blocked-mutated-count"
         (hash-ref public-cell-counts 'required-mutation 0))
   (list "bridge-export-cell-elision-blocked-undefined-count"
         (hash-ref public-cell-counts 'required-undefined 0))
   (list "bridge-export-cell-elision-blocked-reflection-count"
         (hash-ref public-cell-counts 'required-reflection 0))
   (list "bridge-export-cell-elision-blocked-unknown-count"
         (hash-ref public-cell-counts 'required-unknown 0))
   (list "bridge-export-cell-top-modules"
         (bridge-top-count-summary (bridge-export-cell-module-counts stats)))
   (list "bridge-export-cell-top-names"
         (bridge-top-count-summary (bridge-export-cell-name-counts stats)))
   (list "bridge-import-cell-count" (stat 'bridge-import-cell-count))
   (list "bridge-direct-import-count" (stat 'bridge-direct-import-count))
   (list "bridge-direct-local-ref-count" (stat 'bridge-direct-local-ref-count))
   (list "bridge-cell-elision-count" (stat 'bridge-cell-elision-count))
   (list "bridge-import-from-plain-public-value-count"
         (stat 'bridge-import-from-plain-public-value-count))
   (list "bridge-import-from-cell-public-value-count"
         (stat 'bridge-import-from-cell-public-value-count))
   (list "bridge-import-abi-false-count"
         (stat 'bridge-import-abi-false-count))
   (list "bridge-import-abi-false-top-modules"
         (bridge-top-count-summary
          (bridge-import-abi-false-module-counts stats)))
   (list "bridge-import-abi-false-top-names"
         (bridge-top-count-summary
          (bridge-import-abi-false-name-counts stats)))
   (list "bridge-import-abi-false-top-provider-kinds"
         (bridge-top-count-summary
          (bridge-import-abi-false-provider-kind-counts stats)))
   (list "bridge-import-abi-false-top-reasons"
         (bridge-top-count-summary
          (bridge-import-abi-false-reason-counts stats)))
   (list "bridge-import-abi-false-kernel-provider-count"
         (stat 'bridge-import-abi-false-kernel-provider-count))
   (list "bridge-import-abi-false-kernel-top-names"
         (bridge-top-count-summary
          (bridge-import-abi-false-kernel-counts
           stats
           (lambda (entry) (hash-ref entry 'import-name #f)))))
   (list "bridge-import-abi-false-kernel-top-importers"
         (bridge-top-count-summary
          (bridge-import-abi-false-kernel-counts
           stats
           (lambda (entry) (hash-ref entry 'importer-module #f)))))
   (list "bridge-import-abi-false-kernel-details"
         (bridge-import-abi-false-kernel-details stats))
   (list "bridge-import-abi-false-unknown-top-modules"
         (bridge-top-count-summary
          (bridge-import-abi-false-filtered-counts
           stats
           'unknown
           (lambda (entry) (hash-ref entry 'provider-module #f)))))
   (list "bridge-import-abi-false-unknown-top-names"
         (bridge-top-count-summary
          (bridge-import-abi-false-filtered-counts
           stats
           'unknown
           (lambda (entry) (hash-ref entry 'export-name #f)))))
   (list "bridge-import-abi-false-unknown-provider-kind-top-modules"
         (bridge-top-count-summary
          (bridge-import-abi-false-filtered-counts
           stats
           'unknown-provider-kind
           (lambda (entry) (hash-ref entry 'provider-module #f)))))
   (list "bridge-import-abi-false-unknown-provider-kind-top-names"
         (bridge-top-count-summary
          (bridge-import-abi-false-filtered-counts
           stats
           'unknown-provider-kind
           (lambda (entry) (hash-ref entry 'export-name #f)))))
   (list "bridge-import-abi-false-elision-candidate-count"
         (bridge-import-abi-false-elision-candidate-count graph stats))
   (list "bridge-import-abi-false-cell-forcing-count"
         (stat 'bridge-import-abi-false-cell-forcing-count))
   (list "bridge-import-abi-resolved-from-prior-export-knowns-count"
         (stat 'bridge-import-abi-resolved-from-prior-export-knowns-count))
   (list "bridge-import-abi-resolved-from-kernel-knowns-count"
         (stat 'bridge-import-abi-resolved-from-kernel-knowns-count))
   (list "bridge-import-abi-still-false-after-prior-knowns-count"
         (stat 'bridge-import-abi-still-false-after-prior-knowns-count))
   (list "bridge-import-abi-false-kernel-after-knowns-count"
         (stat 'bridge-import-abi-false-kernel-after-knowns-count))
   (list "bridge-abi-only-import-group-knowns-forced-count"
         (stat 'bridge-abi-only-import-group-knowns-forced-count))
   (list "bridge-import-from-plain-local-value-count"
         (stat 'bridge-import-from-plain-local-value-count))
   (list "bridge-import-from-cell-local-value-count"
         (stat 'bridge-import-from-cell-local-value-count))
   (list "bridge-import-from-plain-provider-value-count"
         (stat 'bridge-import-from-plain-provider-value-count))
   (list "bridge-import-from-cell-provider-value-count"
         (stat 'bridge-import-from-cell-provider-value-count))
   (list "bridge-unsafe-struct-ref-count"
         (+ (module-bridge-datum-operator-count datum 'unsafe-struct-ref)
            (module-bridge-datum-operator-count datum 'unsafe-struct*-ref)))
   (list "bridge-unsafe-struct-predicate-count"
         (+ (module-bridge-datum-operator-count datum 'unsafe-struct?)
            (module-bridge-datum-operator-count datum 'unsafe-struct*?)))
   (list "provider-count" (length direct-provider-names))
   (list "local-module-count" local-module-count)
   (list "graph-module-count" graph-module-count)
   (list "export-count" total-export-count)
   (list "import-count" total-import-count)
   (list "reexport-count" reexport-count)
   (list "transitive-provider-count" (max 0 (- graph-module-count local-module-count)))))

(define current-source-module-language
  (make-parameter #f))

(define current-source-module-provider-names
  (make-parameter #f))

;; provider-cache-path : path-string? ... -> path?
;;   Build a cache path under the active provider cache directory.
(define (provider-cache-path . elems)
  (apply build-path (current-provider-cache-dir) elems))

;; provider-report-cache-directory : -> path?
;;   Return the directory used for installed provider report cache entries.
(define (provider-report-cache-directory)
  (provider-cache-path "installed-provider-reports"))

;; provider-report-cache-entries : -> (listof (list/c path? integer? integer?))
;;   Report installed-provider cache files for diagnostics and tests.
(define (provider-report-cache-entries)
  (define dir (provider-report-cache-directory))
  (if (directory-exists? dir)
      (sort
       (for/list ([path (in-list (find-files file-exists? dir))]
                  #:when (file-exists? path))
         (list path
               (file-size path)
               (file-or-directory-modify-seconds path)))
       string<?
       #:key (lambda (entry) (path->string (car entry))))
      '()))

;; driver-timing-add! : symbol? exact-integer? -> void?
;;   Record fine-grained source-reading timing rows for `--timings`.
(define (driver-timing-add! name elapsed-ms)
  (current-read-source-timing-rows
   (append (current-read-source-timing-rows)
           (list (list (symbol->string name) elapsed-ms)))))

;; with-driver-timing : symbol? (-> any/c) -> any/c
;;   Time a small driver phase and append it to the source-reading rows.
(define (with-driver-timing name thunk)
  (define start-ms (now-ms))
  (begin0
    (thunk)
    (driver-timing-add! name (- (now-ms) start-ms))))

;; module-bridge-timing-add! : symbol? exact-integer? -> void?
;;   Record fine-grained module-bridge extraction rows for `--timings`.
(define (module-bridge-timing-add! name elapsed-ms)
  (current-module-bridge-detail-rows
   (append (current-module-bridge-detail-rows)
           (list (list (symbol->string name) elapsed-ms)))))

;; with-module-bridge-timing : symbol? (-> any/c) -> any/c
;;   Time one module-bridge extraction phase and append it to the detail rows.
(define (with-module-bridge-timing name thunk)
  (define start-ms (now-ms))
  (begin0
    (thunk)
    (module-bridge-timing-add! name (- (now-ms) start-ms))))

;; path-fingerprint : symbol? exact-integer? (listof path?) -> any/c
;;   Fingerprint files using path, size, and mtime.
(define (path-fingerprint tag version paths)
  `(,tag
    ,version
    ,@(for/list ([path (in-list (sort (map simplify-path paths)
                                      string<?
                                      #:key path->string))])
        (list (path->string path)
              (file-size path)
              (file-or-directory-modify-seconds path)))))

;; read-provider-cache : path? any/c -> (or/c any/c #f)
;;   Read a provider cache payload when its fingerprint matches.
(define (read-provider-cache cache-path fingerprint)
  (and (not (current-provider-cache-force?))
       (file-exists? cache-path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (match (call-with-input-file cache-path read)
           [`(,cached-fingerprint ,payload)
            (and (equal? cached-fingerprint fingerprint) payload)]
           [_ #f]))))

;; write-provider-cache! : path? any/c any/c -> void?
;;   Write one fingerprinted provider cache payload.
(define (write-provider-cache! cache-path fingerprint payload)
  (make-directory* (path-only cache-path))
  (call-with-output-file cache-path
    (lambda (out)
      (write (list fingerprint payload) out)
      (newline out))
    #:exists 'truncate/replace))

;; call-with-provider-cache-lock : path? (-> any/c) -> any/c
;;   Serialize expensive provider cache materialization across dashboard workers.
(define (call-with-provider-cache-lock cache-path thunk)
  (make-directory* (path-only cache-path))
  (define lock-path (make-lock-file-name cache-path))
  (call-with-file-lock/timeout
   cache-path
   'exclusive
   thunk
   (lambda ()
     (error 'provider-cache
            "timed out waiting for provider cache lock: ~a"
            lock-path))
   #:lock-file lock-path
   #:max-delay 300))

;; provider-cache-log : string? any/c ... -> void?
;;   Print provider cache diagnostics in verbose mode.
(define (provider-cache-log fmt . args)
  (when (current-provider-cache-verbose?)
    (apply fprintf (current-error-port)
           (string-append "provider-cache: " fmt "\n")
           args)))

;; provider-cache-symbol-segment : symbol? -> string?
;;   Make a conservative filename segment for provider report cache rows.
(define (provider-cache-symbol-segment name)
  (regexp-replace* #px"[^A-Za-z0-9_.-]"
                   (symbol->string name)
                   "_"))

;; provider-cache-string-segment : string? -> string?
;;   Make a conservative filename segment for path-keyed cache rows.
(define (provider-cache-string-segment str)
  (regexp-replace* #px"[^A-Za-z0-9_.-]"
                   str
                   "_"))

;; provider-module-source-fingerprint : symbol? -> any/c
;;   Include provider source metadata in the disk cache key when available.
(define (provider-module-source-fingerprint name)
  (with-handlers ([exn:fail? (lambda (_exn) `(module-source unresolved ,name))])
    (define resolved
      (module-path-index-resolve
       (module-path-index-join name #f)))
    (define resolved-name (resolved-module-path-name resolved))
    (cond
      [(and (path? resolved-name) (file-exists? resolved-name))
       `(module-source
         path
         ,(path->string (simplify-path resolved-name))
         ,(file-size resolved-name)
         ,(file-or-directory-modify-seconds resolved-name))]
      [else
       `(module-source
         resolved
         ,(if (path-string? resolved-name)
              (path->string resolved-name)
              resolved-name))])))

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

;; provider-report-extractor-fingerprint : -> any/c
;;   Include bridge/extractor implementation metadata in installed-provider
;;   cache keys, since cached reports contain compiler-derived import maps.
(define (provider-report-extractor-fingerprint)
  (path-fingerprint
   'provider-report-extractor
   2
   (list (build-path webify-root "module-extractor.rkt")
         (build-path webify-root "module-extractor-spike.rkt")
         (build-path webify-root "module-input.rkt"))))

;; local-module-graph-extractor-fingerprint : -> any/c
;;   Include bridge-reader and extractor implementation metadata in cached
;;   local #lang webracket/base report graphs.
(define (local-module-graph-extractor-fingerprint)
  (path-fingerprint
   'local-module-graph-extractor
   1
   (filter values
           (list (build-path webracket-root "pkgs" "webracket-lib" "compiler" "driver.rkt")
                 (build-path webify-root "module-extractor.rkt")
                 (build-path webify-root "module-extractor-spike.rkt")
                 (build-path webify-root "module-input.rkt")
                 (webracket/base-reader-path)
                 (webracket/module-reader-path 'full)))))

;; provider-report->cache-datum : webify-module-report? -> datum?
;;   Serialize provider reports without relying on reader-visible struct types.
(define (provider-bundle-entry->cache-datum entry)
  `(bundle-entry
    ,(webify-module-bundle-entry-key entry)
    ,(webify-module-bundle-entry-kind entry)
    ,(cache-readable-datum (webify-module-bundle-entry-imports entry))
    ,(cache-readable-datum (webify-module-bundle-entry-exports entry))
    ,(cache-readable-datum (webify-module-bundle-entry-datum entry))
    ,(cache-readable-datum (webify-module-bundle-entry-value entry))))

(define (cache-datum->provider-bundle-entry datum)
  (match datum
    [`(bundle-entry ,key ,kind ,imports ,exports ,entry-datum ,value)
     (webify-module-bundle-entry key
                                 kind
                                 (cache-readable->datum imports)
                                 (cache-readable->datum exports)
                                 (cache-readable->datum entry-datum)
                                 (cache-readable->datum value))]
    [_ #f]))

(define (provider-report->cache-datum report)
  `(provider-report
    ,(webify-module-report-name report)
    ,(webify-module-report-directory-keys report)
    ,(webify-module-report-bundle-keys report)
    ,(map provider-bundle-entry->cache-datum
          (webify-module-report-bundle-entries report))
    ,(cache-readable-datum (webify-module-report-phase0-imports report))
    ,(cache-readable-datum (webify-module-report-phase0-exports report))
    ,(cache-readable-datum (webify-module-report-phase0-linklet-datum report))
    ,(webify-module-report-manifest-ready? report)
    ,(cache-readable-datum (webify-module-report-notes report))))

;; cache-datum->provider-report : datum? -> webify-module-report?
;;   Rehydrate the conservative provider-report cache representation.
(define (cache-datum->provider-report datum)
  (match datum
    [`(provider-report
       ,name
       ,directory-keys
       ,bundle-keys
       ,bundle-entries
       ,phase0-imports
       ,phase0-exports
       ,phase0-linklet-datum
       ,manifest-ready?
       ,notes)
     (define parsed-bundle-entries
       (and (list? bundle-entries)
            (for/list ([entry (in-list bundle-entries)])
              (cache-datum->provider-bundle-entry entry))))
     (and parsed-bundle-entries
          (andmap webify-module-bundle-entry? parsed-bundle-entries)
     (webify-module-report name
                           directory-keys
                           bundle-keys
                           parsed-bundle-entries
                           (cache-readable->datum phase0-imports)
                           (cache-readable->datum phase0-exports)
                           (cache-readable->datum phase0-linklet-datum)
                           manifest-ready?
                           (cache-readable->datum notes)))]
    [else #f]))

;; local-module-graph-cache-path : path-string? -> path?
;;   Cache one extracted local bridge graph per root source file.
(define (local-module-graph-cache-path filename)
  (define resolved (simplify-path (path->complete-path filename)))
  (provider-cache-path
   "local-module-graphs"
   (string-append
    (provider-cache-string-segment (path->string resolved))
    ".rktd")))

;; local-module-graph-fingerprint : (listof path?) -> any/c
;;   Fingerprint extracted local-module graphs using source files and bridge code.
(define (local-module-graph-fingerprint local-source-paths)
  `(local-module-graph-cache
    1
    ,(version)
    ,(path-fingerprint 'local-module-graph-source 1 local-source-paths)
    ,(local-module-graph-extractor-fingerprint)))

;; local-module-graph->cache-datum : symbol? (listof report?) (listof path?) -> datum?
;;   Serialize extracted local-module reports plus their visited source files.
(define (local-module-graph->cache-datum root reports local-source-paths)
  `(local-module-graph
    ,root
    (reports
     ,@(for/list ([report (in-list reports)])
         (provider-report->cache-datum report)))
    (local-source-paths
     ,@(for/list ([path (in-list local-source-paths)])
         (cache-readable-datum path)))))

;; cache-datum->local-module-graph-payload : datum? -> (or/c vector? #f)
;;   Rehydrate cached local-module graph payload fields.
(define (cache-datum->local-module-graph-payload datum)
  (match datum
    [`(local-module-graph
       ,root
       (reports ,report-data ...)
       (local-source-paths ,path-data ...))
     (define reports
       (for/list ([report-datum (in-list report-data)])
         (cache-datum->provider-report report-datum)))
     (define local-source-paths
       (for/list ([path-datum (in-list path-data)])
         (cache-readable->datum path-datum)))
     (and (symbol? root)
          (andmap webify-module-report? reports)
          (andmap path? local-source-paths)
          (vector root
                  reports
                  (sort (map simplify-path local-source-paths)
                        string<?
                        #:key path->string)))]
    [_ #f]))

;; read-local-module-graph-cache : path? -> (or/c vector? #f)
;;   Read a cached local-module graph when its extracted source fingerprint still matches.
(define (read-local-module-graph-cache cache-path)
  (and (not (current-provider-cache-force?))
       (file-exists? cache-path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (match (call-with-input-file cache-path read)
           [`(,cached-fingerprint ,payload)
            (define decoded (cache-datum->local-module-graph-payload payload))
            (and decoded
                 (equal? cached-fingerprint
                         (local-module-graph-fingerprint
                          (vector-ref decoded 2)))
                 decoded)]
           [_ #f]))))

;; write-local-module-graph-cache! : path? symbol? (listof report?) (listof path?) -> void?
;;   Persist one extracted local-module graph payload under its dynamic fingerprint.
(define (write-local-module-graph-cache! cache-path root reports local-source-paths)
  (write-provider-cache!
   cache-path
   (local-module-graph-fingerprint local-source-paths)
   (local-module-graph->cache-datum root reports local-source-paths)))

;; cached-installed-provider-report : symbol? (symbol? -> report?) -> report?
;;   Reuse extracted installed-provider reports across driver runs.
(define (cached-installed-provider-report name fetch-provider)
  (define cache-path
    (provider-cache-path
     "installed-provider-reports"
     (string-append (provider-cache-symbol-segment name) ".rktd")))
  (define fingerprint
    `(installed-provider-report-cache
      9
      ,name
      ,(version)
      ,(provider-module-source-fingerprint name)
      ,(provider-report-extractor-fingerprint)))
  (define cached
    (with-module-bridge-timing
     'provider-cache-lookup
     (lambda ()
       (read-provider-cache cache-path fingerprint))))
  (cond
    [cached
     (provider-cache-log "installed provider report hit: ~a" name)
     (or (cache-datum->provider-report cached)
         (let ()
           (provider-cache-log "installed provider report cache unreadable; extracting: ~a" name)
           (define report
             (with-module-bridge-timing
              'provider-report-extraction-miss
              (lambda ()
                (fetch-provider name))))
           (write-provider-cache! cache-path
                                  fingerprint
                                  (provider-report->cache-datum report))
           report))]
    [else
     (provider-cache-log "installed provider report miss; extracting: ~a" name)
     (define report
       (with-module-bridge-timing
        'provider-cache-miss
        (lambda ()
          (with-module-bridge-timing
           'provider-report-extraction-miss
           (lambda ()
             (fetch-provider name))))))
     (write-provider-cache! cache-path fingerprint (provider-report->cache-datum report))
     report]))

;; log-discovered-provider-graph-cache-miss! : path? any/c -> void?
;;   Explain why the discovered provider-graph cache did not hit.
(define (log-discovered-provider-graph-cache-miss! cache-path fingerprint)
  (when (and (current-provider-cache-verbose?)
             (file-exists? cache-path))
    (with-handlers ([exn:fail?
                     (lambda (e)
                       (provider-cache-log
                        "#lang webracket/base discovered provider graph cache unreadable: ~a"
                        (exn-message e)))])
      (match (call-with-input-file cache-path read)
        [`(,cached-fingerprint ,_payload)
         (unless (equal? cached-fingerprint fingerprint)
           (define labels
             '(tag
               cache-version
               root
               demand-slice?
               module-protocol-dependency
               racket-version
               extractor-fingerprint
               local-source-fingerprint
               support-provider-fingerprints))
           (define cached-parts
             (if (list? cached-fingerprint) cached-fingerprint '()))
           (define current-parts
             (if (list? fingerprint) fingerprint '()))
           (define mismatch-index
             (for/or ([label (in-list labels)]
                      [cached-part (in-list cached-parts)]
                      [current-part (in-list current-parts)]
                      [i (in-naturals)])
               (and (not (equal? cached-part current-part))
                    (list i label cached-part current-part))))
           (match mismatch-index
             [(list _i label cached-part current-part)
              (provider-cache-log
               "#lang webracket/base discovered provider graph fingerprint mismatch at ~a"
               label)
              (provider-cache-log "  cached: ~s" cached-part)
              (provider-cache-log "  current: ~s" current-part)]
             [_ (provider-cache-log
                 "#lang webracket/base discovered provider graph fingerprint mismatch in unlabelled tail")]))]
        [_ (provider-cache-log
            "#lang webracket/base discovered provider graph cache has unexpected shape")]))))

;; module-linklet-input->cache-datum : webify-module-linklet-input? -> datum?
;;   Serialize one resolved linklet input using the manifest handoff shape.
(define (cache-readable-datum v)
  (cond
    [(void? v)
     'webracket-cache:void]
    [(eq? v unsafe-undefined)
     'webracket-cache:unsafe-undefined]
    [(path? v)
     `(webracket-cache:path ,(path->string v))]
    [(pair? v)
     (cons (cache-readable-datum (car v))
           (cache-readable-datum (cdr v)))]
    [(vector? v)
     `(webracket-cache:vector
       ,@(for/list ([elem (in-vector v)])
           (cache-readable-datum elem)))]
    [(box? v)
     `(webracket-cache:box ,(cache-readable-datum (unbox v)))]
    [(prefab-struct-key v)
     (define data (struct->vector v))
     `(webracket-cache:prefab
       ,(prefab-struct-key v)
       ,@(for/list ([i (in-range 1 (vector-length data))])
           (cache-readable-datum (vector-ref data i))))]
    [(hash? v)
     `(webracket-cache:hash
       ,(cond
          [(hash-eq? v)  'eq]
          [(hash-eqv? v) 'eqv]
          [else          'equal])
       ,(for/list ([(key value) (in-hash v)])
          (list (cache-readable-datum key)
                (cache-readable-datum value))))]
    [else v]))

(define (cache-readable->datum v)
  (cond
    [(eq? v 'webracket-cache:void)
     (void)]
    [(eq? v 'webracket-cache:unsafe-undefined)
     unsafe-undefined]
    [(pair? v)
     (match v
       [`(webracket-cache:path ,s)
        (string->path s)]
       [`(webracket-cache:vector ,elems ...)
        (list->vector (map cache-readable->datum elems))]
       [`(webracket-cache:box ,elem)
        (box (cache-readable->datum elem))]
       [`(webracket-cache:prefab ,key ,fields ...)
        (apply make-prefab-struct key (map cache-readable->datum fields))]
       [`(webracket-cache:hash ,kind ,entries)
        (define decoded-entries
          (for/list ([entry (in-list entries)])
            (match entry
              [(list key value)
               (cons (cache-readable->datum key)
                     (cache-readable->datum value))]
              [_ (error 'cache-readable->datum
                        "invalid cached hash entry: ~e"
                        entry)])))
        (for/fold ([h (case kind
                        [(eq)  (hasheq)]
                        [(eqv) (hasheqv)]
                        [else  (hash)])])
                  ([entry (in-list decoded-entries)])
          (hash-set h (car entry) (cdr entry)))]
       [else
        (cons (cache-readable->datum (car v))
              (cache-readable->datum (cdr v)))])]
    [else v]))

(define (module-linklet-input->cache-datum input)
  `(input
    ,(webify-module-linklet-input-name input)
    ,(cache-readable-datum (webify-module-linklet-input-linklet input))
    (imports ,(webify-module-linklet-input-imports input))))

;; module-linklet-manifest->cache-datum : (listof input?) (listof symbol?) -> datum?
;;   Serialize cached discovered inputs using the manifest handoff format.
(define (module-linklet-manifest->cache-datum inputs roots)
  `(webify-module-linklet-manifest
    (roots ,roots)
    ,@(map module-linklet-input->cache-datum inputs)))

;; discovered-provider-graph-fingerprint : symbol? (listof path?) (listof symbol?) boolean? any/c -> any/c
;;   Fingerprint discovered provider graphs using stable source file metadata.
(define (discovered-provider-graph-fingerprint root
                                               local-source-paths
                                               support-provider-names
                                               demand-slice?
                                               module-protocol-dependency)
  `(discovered-provider-graph-cache
    2
    ,root
    ,demand-slice?
    ,module-protocol-dependency
    ,(version)
    ,(provider-report-extractor-fingerprint)
    ,(path-fingerprint
      'discovered-provider-graph-local-sources
      1
      local-source-paths)
    ,(for/list ([name (in-list support-provider-names)])
       (provider-module-source-fingerprint name))))

;; cached-discovered-provider-registry : symbol? (listof path?) (listof symbol?) (-> inputs) -> registry
;;   Cache the expensive discovered provider graph as resolved linklet inputs.
(define (cached-discovered-provider-registry root
                                             local-source-paths
                                             support-provider-names
                                             demand-slice?
                                             module-protocol-dependency
                                             discover-inputs)
  (define cache-path
    (provider-cache-path
     "discovered-provider-graphs"
     (string-append (provider-cache-symbol-segment root) ".rktd")))
  (define fingerprint
    (discovered-provider-graph-fingerprint root
                                           local-source-paths
                                           support-provider-names
                                           demand-slice?
                                           module-protocol-dependency))
  (define cached
    (with-module-bridge-timing
     'discover-provider-graph-cache-lookup
     (lambda ()
       (read-provider-cache cache-path fingerprint))))
  (cond
    [cached
     (provider-cache-log "#lang webracket/base discovered provider graph hit: ~a" root)
     (define manifest
       (datum->webify-module-linklet-manifest
        (fasl->s-exp cached)))
     (with-module-bridge-timing
      'discover-provider-graph-cache-hit
      (lambda ()
        (webify-module-linklet-manifest->registry manifest)))]
    [else
     (log-discovered-provider-graph-cache-miss! cache-path fingerprint)
     (provider-cache-log "#lang webracket/base discovered provider graph miss: ~a" root)
     (define inputs
       (with-module-bridge-timing
        'discover-provider-graph-cache-miss
        discover-inputs))
     (write-provider-cache! cache-path
                            fingerprint
                            (s-exp->fasl
                             (module-linklet-manifest->cache-datum inputs (list root))))
     (webify-module-linklet-inputs->registry inputs)]))

;; staged-io-source-fingerprint : symbol? -> any/c
;;   Fingerprint staged io provider inputs.
(define (staged-io-source-fingerprint cache-tag)
  (path-fingerprint
   cache-tag
   1
   (cons (build-path webify-root "io-format-bridge.rkt")
         (cons (build-path webify-root "io-print-bridge.rkt")
               (find-files file-exists? (build-path webracket-root "racket-src/io"))))))

;; io-format-source-fingerprint : -> any/c
;;   Fingerprint the staged io/format provider inputs.
(define (io-format-source-fingerprint)
  (staged-io-source-fingerprint 'io-format-provider-cache))

;; io-print-source-fingerprint : -> any/c
;;   Fingerprint the staged io/print provider inputs.
(define (io-print-source-fingerprint)
  (staged-io-source-fingerprint 'io-print-provider-cache))

;; provider-slice-forms : symbol? #:public-aliases? boolean? -> (listof datum?)
;;   Compose a provider slice and expose export cells, optionally publishing
;;   public top-level aliases.
(define (provider-slice-forms name #:public-aliases? [public-aliases? #f])
  (case name
    [(io/format)
     (io-format-provider-forms #:public-aliases? public-aliases?)]
    [(io/print)
     (io-print-provider-forms #:public-aliases? public-aliases?)]
    [(regexp)
     (regexp-provider-forms #:public-aliases? public-aliases?)]
    [(expander/read)
     (read-provider-forms #:public-aliases? public-aliases?)]
    [(expander/read-syntax)
     (read-syntax-provider-forms)]
    [else
     (error 'provider-slice-forms "provider slice is not runtime-integrated yet: ~a" name)]))

;; io-format-provider-forms : #:public-aliases? boolean? -> (listof datum?)
;;   Compose the staged original-Racket io/format provider and expose export
;;   cells, optionally publishing public top-level aliases.
(define (io-format-provider-forms #:public-aliases? [public-aliases? #f])
  (define cache-path
    (provider-cache-path
     (if public-aliases?
         "io-format-provider-public.rktd"
         "io-format-provider-private.rktd")))
  (define fingerprint
    `(io-format-lowered-provider-cache 1 ,public-aliases? ,(io-format-source-fingerprint)))
  (define cached (read-provider-cache cache-path fingerprint))
  (cond
    [cached
     (provider-cache-log "io/format lowered forms hit: ~a" cache-path)
     cached]
    [else
     (provider-cache-log "io/format lowered forms miss; rebuilding: ~a" cache-path)
     (define composition
       (webify-compose-module-registry/roots/composition
        (webify-io-format-registry)
        (list webify-io-format-root-name)
        #:define-export-aliases? #f
        #:serializable?-box     #f
        #:datum-intern?         #f
        #:target                #f
        #:allow-set!-undefined? #f
        #:unsafe-mode?          #f
        #:enforce-constant?     #t
        #:allow-inline?         #t
        #:no-prompt?            #f
        #:prim-knowns           (hasheq)
        #:primitives            (hasheq)
        #:compiler-query        (lambda (v) #f)
        #:get-import-knowns     (lambda (key) (values #f #f #f))
        #:import-keys           #f))
     (define forms
       (cdr (webify-module-composition-with-tail
             composition
             ((if public-aliases?
                  webify-io-format-public-alias-forms
                  webify-io-format-private-alias-forms)
              composition))))
     (write-provider-cache! cache-path fingerprint forms)
     forms]))

;; io-print-provider-forms : #:public-aliases? boolean? -> (listof datum?)
;;   Compose the staged original-Racket io/print provider seed and expose
;;   private export cells. Public aliases stay disabled until ownership flips.
(define (io-print-provider-forms #:public-aliases? [public-aliases? #f])
  (when public-aliases?
    (error 'io-print-provider-forms
           "io/print public aliases are not ready; use private export cells"))
  (define cache-path
    (provider-cache-path "io-print-provider-private.rktd"))
  (define fingerprint
    `(io-print-lowered-provider-cache 1 ,(io-print-source-fingerprint)))
  (define cached (read-provider-cache cache-path fingerprint))
  (cond
    [cached
     (provider-cache-log "io/print lowered forms hit: ~a" cache-path)
     cached]
    [else
     (provider-cache-log "io/print lowered forms miss; rebuilding: ~a" cache-path)
     (define composition
       (webify-compose-module-registry/roots/composition
        (webify-io-print-registry)
        (list webify-io-print-root-name)
        #:define-export-aliases? #f
        #:serializable?-box     #f
        #:datum-intern?         #f
        #:target                #f
        #:allow-set!-undefined? #f
        #:unsafe-mode?          #f
        #:enforce-constant?     #t
        #:allow-inline?         #t
        #:no-prompt?            #f
        #:prim-knowns           (hasheq)
        #:primitives            (hasheq)
        #:compiler-query        (lambda (v) #f)
        #:get-import-knowns     (lambda (key) (values #f #f #f))
        #:import-keys           #f))
     (define forms
       (cdr (webify-module-composition-with-tail
             composition
             (webify-io-print-private-alias-forms composition))))
     (write-provider-cache! cache-path fingerprint forms)
     forms]))

;; io-format-provider-reports : -> (listof webify-module-report?)
;;   Expose staged io/format as the implementation report for `racket/format`.
(define (io-format-provider-reports)
  (define-values (adapter-report printf-report main-report map-report)
    (webify-io-format-reports))
  (define format-report
    (parameterize ([current-directory webracket-root])
      (webify-module-path->report (string->path "racket-src/racket/format-web.rkt"))))
  (list adapter-report
        printf-report
        main-report
        (webify-module-report/rename main-report 'racket-src/io/format/main-web)
        map-report
        (webify-module-report/rename format-report 'racket-src/racket/format-web)
        (webify-module-report/rename format-report 'racket/format)))

;; io-format-provider-report/ref : symbol? -> (or/c webify-module-report? #f)
;;   Resolve staged io/format support aliases without falling back to generic
;;   module-path extraction. Some aliases, such as `racket-src/racket/format-web`,
;;   are report names but not real collection-path module names.
(define (io-format-provider-report/ref name)
  (for/or ([report (in-list (io-format-provider-reports))])
    (and (eq? name (webify-module-report-name report))
         report)))

;; read-provider-wrapper-module : datum?
;;   Public staged `expander/read` facade that re-exports reader aliases.
(define read-provider-wrapper-module
  `(module expander-read-public racket/base
     (require (file "racket-src/expander/read-provider-root.rkt"))
     (provide ,@(map car webify-read-public-alias-pairs))
     ,@(for/list ([alias (in-list webify-read-public-alias-pairs)])
         `(define ,(car alias) ,(cdr alias)))))

(define (expander-read-private-provider-name? name)
  (define s (and (symbol? name) (symbol->string name)))
  (and s
       (or (equal? s "racket-src/expander/read-provider-root.rkt")
           (string-prefix? s "racket-src/expander/read/")
           (string-prefix? s "racket-src/expander/common/")
           (string-prefix? s "racket-src/expander/host/"))))

(define (expander-read-private-provider-path name)
  (define s (symbol->string name))
  (string->path
   (if (regexp-match? #rx"[.]rkt$" s)
       s
       (string-append s ".rkt"))))

(define (expander-read-private-provider-file-backed? name)
  (file-exists? (build-path webracket-root
                            (expander-read-private-provider-path name))))

;; read-provider-reports : -> (listof webify-module-report?)
;;   Expose the staged expander/read private implementation closure plus the
;;   public facade used for user-module alias ownership.
(define (read-provider-reports)
  (parameterize ([current-directory webracket-root])
    (parameterize ([current-provider-owned-primitive-aliases (seteq)])
      (define visited (make-hasheq))
      (define ordered-reports '())
      (define (visit! name)
        (unless (hash-ref visited name #f)
          (hash-set! visited name #t)
          (define report
            (let ([report
                   (webify-module-path->report
                    (expander-read-private-provider-path name))])
              (if (eq? name (webify-module-report-name report))
                  report
                  (webify-module-report/rename report name))))
          (set! ordered-reports (append ordered-reports (list report)))
          (for ([required (in-list (webify-module-report-required-provider-names report))]
                #:when (and (expander-read-private-provider-name? required)
                            (expander-read-private-provider-file-backed? required)))
            (visit! required))))
      (visit! 'racket-src/expander/read-provider-root.rkt)
      (append
       ordered-reports
       (list
        (webify-module-report/rename
         (webify-compile-module-report read-provider-wrapper-module)
         'expander/read))))))

;; read-provider-report/ref : symbol? -> (or/c webify-module-report? #f)
;;   Resolve staged expander/read support aliases without generic extraction.
(define (read-provider-report/ref name)
  (for/or ([report (in-list (read-provider-reports))])
    (and (eq? name (webify-module-report-name report))
         report)))

;; read-syntax-provider-forms : -> (listof datum?)
;;   Compose the private staged original-Racket read-syntax provider and publish
;;   only Webify-owned aliases. Public `read-syntax` ownership is still pending.
(define (read-syntax-provider-forms)
  (define cache-path
    (webify-read-syntax-lowered-provider-cache-path (current-provider-cache-dir)))
  (define fingerprint
    `(expander-read-syntax-lowered-provider-cache 1
                                                  ,(webify-read-syntax-source-fingerprint)))
  (define cached (read-provider-cache cache-path fingerprint))
  (cond
    [cached
     (provider-cache-log "expander/read-syntax lowered forms hit: ~a" cache-path)
     cached]
    [else
     (provider-cache-log "expander/read-syntax lowered forms miss; rebuilding: ~a"
                         cache-path)
     (define lk
       (webify-read-syntax-linklet #:cache-root (current-provider-cache-dir)
                                   #:force? (current-provider-cache-force?)
                                   #:verbose? (current-provider-cache-verbose?)))
     (define-values (provider-stx exports _exports-info)
       (webify-linklet-first-slice-top-level
        lk
        #:define-export-aliases? #f
        #:serializable?-box     #f
        #:datum-intern?         #f
        #:target                #f
        #:allow-set!-undefined? #f
        #:unsafe-mode?          #f
        #:enforce-constant?     #t
        #:allow-inline?         #t
        #:no-prompt?            #f
        #:prim-knowns           (hasheq)
        #:primitives            (hasheq)
        #:compiler-query        (lambda (v) #f)
        #:get-import-knowns     (lambda (key) (values #f #f #f))
        #:import-keys           #f))
     (unless (equal? (sort exports symbol<?)
                     (sort webify-read-syntax-export-symbols symbol<?))
       (error 'read-syntax-provider-forms
              "unexpected expander/read-syntax exports: ~s"
              exports))
     (define export-cells
       (first-slice-top-level-export-cell-ids exports))
     (define forms
       (append
        (cdr (syntax->datum provider-stx))
        (webify-read-syntax-alias-forms export-cells)))
     (write-provider-cache! cache-path fingerprint forms)
     forms]))

;; read-provider-forms : #:public-aliases? boolean? -> (listof datum?)
;;   Compose the cached original-Racket expander/read provider and optionally
;;   publish its Webify-owned `webify-expander-*` names plus public reader
;;   aliases owned by the provider.
(define (read-provider-forms #:public-aliases? [public-aliases? #f])
  (define cache-path
    (webify-read-lowered-provider-cache-path (current-provider-cache-dir)))
  (define fingerprint
    `(expander-read-lowered-provider-cache 2
                                           ,public-aliases?
                                           ,webify-read-public-alias-symbols
                                           ,(webify-read-source-fingerprint)))
  (define cached (read-provider-cache cache-path fingerprint))
  (cond
    [cached
     (provider-cache-log "expander/read lowered forms hit: ~a" cache-path)
     cached]
    [else
     (provider-cache-log "expander/read lowered forms miss; rebuilding: ~a" cache-path)
     (define lk
       (webify-read-linklet #:cache-root (current-provider-cache-dir)
                            #:force? (current-provider-cache-force?)
                            #:verbose? (current-provider-cache-verbose?)))
     (define-values (provider-stx exports _exports-info)
       (webify-linklet-first-slice-top-level
        lk
        #:define-export-aliases? #f
        #:serializable?-box     #f
        #:datum-intern?         #f
        #:target                #f
        #:allow-set!-undefined? #f
        #:unsafe-mode?          #f
        #:enforce-constant?     #t
        #:allow-inline?         #t
        #:no-prompt?            #f
        #:prim-knowns           (hasheq)
        #:primitives            (hasheq)
        #:compiler-query        (lambda (v) #f)
        #:get-import-knowns     (lambda (key) (values #f #f #f))
        #:import-keys           #f))
     (unless (equal? (sort exports symbol<?)
                     (sort webify-read-export-symbols symbol<?))
       (error 'read-provider-forms
              "unexpected expander/read exports: ~s"
              exports))
     (define export-cells
       (first-slice-top-level-export-cell-ids exports))
     (define forms
       (append
        (cdr (syntax->datum provider-stx))
        (if public-aliases?
            (webify-read-public-alias-forms export-cells)
            '())))
     (write-provider-cache! cache-path fingerprint forms)
     forms]))

;; regexp-provider-forms : #:public-aliases? boolean? #:cache-context symbol? -> (listof datum?)
;;   Compose the cached original-Racket regexp provider and expose export cells,
;;   optionally publishing public top-level aliases.
(define (regexp-provider-forms #:public-aliases? [public-aliases? #f]
                               #:cache-context [cache-context 'default])
  (define cache-path
    (if (eq? cache-context 'default)
        (webify-regexp-lowered-provider-cache-path public-aliases?
                                                  (current-provider-cache-dir))
        (provider-cache-path
         (format "regexp-provider-~a-~a.rktd"
                 (if public-aliases? "public" "private")
                 cache-context))))
  (define fingerprint
    `(regexp-lowered-provider-cache 2
                                    ,public-aliases?
                                    ,cache-context
                                    ,(webify-regexp-source-fingerprint)))
  (define cached (read-provider-cache cache-path fingerprint))
  (cond
    [cached
     (provider-cache-log "regexp lowered forms hit: ~a" cache-path)
     cached]
    [else
     (call-with-provider-cache-lock
      cache-path
      (lambda ()
        (define cached* (read-provider-cache cache-path fingerprint))
        (cond
          [cached*
           (provider-cache-log "regexp lowered forms hit: ~a" cache-path)
           cached*]
          [else
           (provider-cache-log "regexp lowered forms miss; rebuilding: ~a" cache-path)
           (define lk
             (webify-regexp-linklet #:cache-root (current-provider-cache-dir)
                                    #:force? (current-provider-cache-force?)
                                    #:verbose? (current-provider-cache-verbose?)))
           (define-values (provider-stx exports _exports-info)
             (webify-linklet-first-slice-top-level
              lk
              #:define-export-aliases? #f
              #:serializable?-box     #f
              #:datum-intern?         #f
              #:target                #f
              #:allow-set!-undefined? #f
              #:unsafe-mode?          #f
              #:enforce-constant?     #t
              #:allow-inline?         #t
              #:no-prompt?            #f
              #:prim-knowns           (hasheq)
              #:primitives            (hasheq)
              #:compiler-query        (lambda (v) #f)
              #:get-import-knowns     (lambda (key) (values #f #f #f))
              #:import-keys           #f))
           (unless (equal? (sort exports symbol<?)
                           (sort webify-regexp-export-symbols symbol<?))
             (error 'regexp-provider-forms
                    "unexpected regexp exports: ~s"
                    exports))
           (define export-cells
             (first-slice-top-level-export-cell-ids exports))
           (define forms
             (append
              (cdr (syntax->datum provider-stx))
              (if public-aliases?
                  (webify-regexp-public-alias-forms export-cells)
                  '())))
           (write-provider-cache! cache-path fingerprint forms)
           forms])))]))

;; add-io-format-provider : syntax? #:expander-read-provider? boolean? #:expander-read-syntax-provider? boolean? -> syntax?
;;   Prepend only the staged io/format provider, without the old stdlib root.
(define (add-io-format-provider stx
                                #:expander-read-provider? [expander-read-provider? #f]
                                #:expander-read-syntax-provider? [expander-read-syntax-provider? #f])
  (define provider-forms
    (append
     (regexp-provider-forms #:public-aliases? #t
                            #:cache-context (if expander-read-syntax-provider?
                                                'read-syntax
                                                'default))
     (if expander-read-provider?
         (provider-slice-forms 'expander/read #:public-aliases? #t)
         '())
     (if expander-read-syntax-provider?
         (provider-slice-forms 'expander/read-syntax)
         '())
     (provider-slice-forms 'io/format #:public-aliases? #t)))
  (with-syntax ([(provider-form ...) (map (lambda (form) (datum->syntax stx form stx))
                                          provider-forms)])
    #`(begin
        provider-form ...
        #,stx)))

;; add-regexp-provider : syntax? -> syntax?
;;   Prepend only the always-available regexp provider slice.
(define (add-regexp-provider stx)
  (define regexp-forms
    (provider-slice-forms 'regexp #:public-aliases? #t))
  (with-syntax ([(regexp-form ...) (map (lambda (form) (datum->syntax stx form stx))
                                        regexp-forms)])
    #`(begin
        regexp-form ...
        #,stx)))

;; add-expander-read-provider : syntax? #:expander-read-syntax-provider? boolean? -> syntax?
;;   Prepend regexp plus staged expander providers for focused replacement trials.
(define (add-expander-read-provider stx
                                    #:expander-read-syntax-provider?
                                    [expander-read-syntax-provider? #f])
  (define provider-forms
    (append
     (regexp-provider-forms #:public-aliases? #t
                            #:cache-context (if expander-read-syntax-provider?
                                                'read-syntax
                                                'default))
     (provider-slice-forms 'expander/read #:public-aliases? #t)
     (if expander-read-syntax-provider?
         (provider-slice-forms 'expander/read-syntax)
         '())))
  (with-syntax ([(provider-form ...) (map (lambda (form) (datum->syntax stx form stx))
                                          provider-forms)])
    #`(begin
        provider-form ...
        #,stx)))

;; add-module-stdlib : syntax? boolean? #:io-format-provider? boolean? #:expander-read-provider? boolean? #:expander-read-syntax-provider? boolean? -> syntax?
;;   Evaluate the selected stdlib root with private top-level names, publish
;;   chosen exports through module-variable cells, then append the user program.
(define (add-module-stdlib stx browser?
                           #:io-format-provider? [io-format-provider? #f]
                           #:expander-read-provider? [expander-read-provider? #f]
                           #:expander-read-syntax-provider? [expander-read-syntax-provider? #f])
  (define-values (stdlib-forms bindings)
    (stdlib-module-private-forms+bindings browser?))
  (define alias-set
    (for/hasheq ([export (in-list (stdlib-module-alias-symbols browser?))])
      (values export #t)))
  (define alias-bindings
    (filter (λ (binding)
              (define public (car binding))
              (and (hash-ref alias-set public #f)
                   ;; Primitive-owned exports are already available at the
                   ;; script top level. Re-aliasing them would recreate the
                   ;; old textual-stdlib primitive collision under the module
                   ;; stdlib bridge.
                   (not (compiler-primitive? public))))
            bindings))
  (define private->binding
    (for/hasheq ([binding (in-list alias-bindings)])
      (values (cdr binding) binding)))
  (define public->cell
    (for/hasheq ([binding (in-list alias-bindings)]
                 [i (in-naturals)])
      (values (car binding) (stdlib-cell-symbol i))))
  (define (alias-forms-after form)
    (for*/list ([private (in-list (stdlib-definition-form-symbols form))]
                [binding (in-value (hash-ref private->binding private #f))]
                #:when binding
                [alias-form (in-list
                             (let* ([public (car binding)]
                                    [cell (hash-ref public->cell public)])
                               `((define ,cell (module-variable-make ',public))
                                 (module-variable-define! ,cell ,private 'constant)
                                 (define ,public (module-variable-ref ,cell)))))])
      alias-form))
  (define stdlib-program-forms
    (append (regexp-provider-forms #:public-aliases? #t
                                   #:cache-context (if expander-read-syntax-provider?
                                                       'read-syntax
                                                       'default))
            (if io-format-provider?
                (provider-slice-forms 'io/format #:public-aliases? #t)
                '())
            (if expander-read-provider?
                (provider-slice-forms 'expander/read #:public-aliases? #t)
                '())
            (if expander-read-syntax-provider?
                (provider-slice-forms 'expander/read-syntax)
                '())
            (append-map (λ (form) (cons form (alias-forms-after form)))
                        stdlib-forms)))
  (with-syntax ([(stdlib-form ...) (map (λ (form) (datum->syntax stx form stx))
                                        stdlib-program-forms)])
    #`(begin
        stdlib-form ...
        #,stx)))

;; provider-owned-primitive-alias-symbols : ... -> (listof symbol?)
;;   Compute public primitive names that must resolve through provider cells.
(define (provider-owned-primitive-alias-symbols
         #:expander-read-provider? [expander-read-provider? #f]
         #:io-format-provider? [io-format-provider? #f])
  (append webify-regexp-export-symbols
          (if expander-read-provider?
              webify-read-public-alias-symbols
              '())
          (if io-format-provider?
              webify-io-format-export-symbols
              '())))

;;;
;;; Available Primitives
;;;

;; list-available-primitives : [#:ffi-files (listof path-string?)] -> (listof symbol?)
;;   Return a sorted list of known primitives, optionally extended with FFI primitives.
(define (list-available-primitives #:ffi-files [ffi-files '()])
  (define resolved-ffi-files
    (merged-ffi-files 'list-available-primitives #f ffi-files))
  (define requested-ffi-primitives
    (append-map (λ (ffi-filename)
                  (foreigns->primitive-names (ffi-file->foreigns ffi-filename)))
                resolved-ffi-files))
  ; `primitives` may already include previously registered ffi primitives.
  ; Keep core primitives stable, then add only explicitly requested ffi primitives.
  (define core-primitives
    (filter (λ (sym) (not (memq sym ffi-primitives)))
            primitives))
  
  (sort (remove-duplicates (append core-primitives requested-ffi-primitives))
        symbol<?))


;;;
;;; THE MAIN DRIVER
;;;

;;   --timings
;;      Print timing breakdown for compilation steps.

(struct compilation-timings
  (ffi-setup     ; time spent resolving and loading FFI declarations
   read-source   ; time spent reading source and module-language input
   add-stdlib    ; time spent composing stdlib and provider slices
   preflight     ; time spent validating outputs, tools, and runtime mode
   compile       ; core compiler pipeline time
   write-wat     ; time spent writing the .wat file
   assemble      ; time spent producing the .wasm file
   write-map     ; time spent writing the label-map sidecar
   write-host    ; time spent writing the JS or HTML host wrapper
   compile-total ; compile-pipeline subtotal excluding optional run-after
   run           ; optional Node run-after time
   driver-total  ; total driver time including orchestration and optional run
   )
  #:transparent)

(struct compilation-output-paths
  (wat   ; emitted WebAssembly text path
   wasm  ; emitted WebAssembly binary path
   map   ; emitted label-map sidecar path
   host  ; emitted JS or HTML host wrapper path
   )
  #:transparent)

;; stdlib-decision-note : string? string? -> (list/c string? string?)
;;   Build one stdlib/provider diagnostic row for timing output.
(define (stdlib-decision-note label value)
  (list label value))

;; resolve-compilation-output-paths : path-string? (or/c path-string? #f) (or/c path-string? #f) (or/c path-string? #f) (or/c path-string? #f) boolean? -> compilation-output-paths?
;;   Compute the effective output paths for one compilation request.
(define (resolve-compilation-output-paths filename
                                          wat-filename
                                          wasm-filename
                                          host-filename
                                          dest-dir
                                          node?)
  (define (default-output-path ext)
    (define source-base (or (file-name-from-path filename) filename))
    (define default-name (path-replace-extension source-base ext))
    (if dest-dir
        (build-path dest-dir default-name)
        (path-replace-extension filename ext)))
  (define out-wat  (or wat-filename  (default-output-path ".wat")))
  (define out-wasm (or wasm-filename (default-output-path ".wasm")))
  (define out-map  (path-replace-extension out-wasm ".wasm.map.sexp"))
  (define out-host (or host-filename
                       (if node?
                           (default-output-path ".js")
                           (default-output-path ".html"))))
  (compilation-output-paths out-wat out-wasm out-map out-host))


(define (drive-compilation
         ;; Paths
         #:filename          filename
         #:wat-filename      wat-filename
         #:wasm-filename     wasm-filename
         #:host-filename     host-filename      ; default: "runtime.js"
         #:dest-dir          dest-dir
         ;; Debug Information
         #:label-map-forms?  label-map-forms?    
         #:dump-passes-dir   dump-passes-dir     
         #:dump-passes-limit dump-passes-limit  ; max number of passes to dump
         #:timings?          timings?
         #:alpha-rename-profile? alpha-rename-profile?
         #:simplify-profile? simplify-profile?
         #:pretty-wat?       pretty-wat?        ; pretty print (slow) the wat-file
         #:verbose?          verbose?
         ;; Targets
         #:browser?          browser?           
         #:node?             node?
         ;; Compiler strategy
         #:letrec-strategy   letrec-strategy
         ;; Optimization
         #:enable-cc-analysis? enable-cc-analysis?
         #:enable-simplify?  enable-simplify?
         #:module-bridge-elide-public-cells? [module-bridge-elide-public-cells? #f]
         #:tree-shake?       tree-shake?        ; remove dead code from the wat-file
         #:tree-shake-report tree-shake-report
         ;; Program Debug
         #:print-top-level-results? print-top-level-results?
         #:internal-bind-treelist-debug-shape? internal-bind-treelist-debug-shape?
         #:internal-bind-immutable-hash-debug-shape? internal-bind-immutable-hash-debug-shape?
         ;; Reflection
         #:console-bridge?   console-bridge?    ; adds WR on the JS side
         ;; Populate the Virtual File System
         #:vfs-preloads      vfs-preloads       
         #:vfs-mounts        vfs-mounts
         ;; Convenience
         #:run-after?        run-after?
         ;; Foreign Function Interface
         #:ffi-files         ffi-files    ; list of file paths for .ffi files
         ;; Standard Library
         #:stdlib?           stdlib?      ; can be turned off for testing the compiler
         #:stdlib-io-format-provider? [stdlib-io-format-provider? #t]
         #:expander-read-provider? [expander-read-provider? #f]
         #:expander-read-syntax-provider? [expander-read-syntax-provider? #f]
         #:webracket-module-bridge? [webracket-module-bridge? #f]
         #:provider-substitutions? [provider-substitutions? #t]
         ;; Provider Cache
         #:provider-cache-dir [provider-cache-dir webify-regexp-default-cache-root]
         #:clear-provider-cache? [clear-provider-cache? #f]
         #:force-provider-cache-refresh? [force-provider-cache-refresh? #f])

  (define exit-code       0)
  (define compile-timings #f)
  (define t-driver-start (now-ms))
  (current-source-module-language #f)
  (current-source-module-provider-names #f)
  (current-module-bridge-elidable-module-names #f)
  (current-module-bridge-module-kinds #f)
  (current-module-bridge-needs-regexp-provider? #t)
  (current-console-bridge-root-export-bindings #f)
  (current-console-bridge-root-source-path #f)
  (current-webify-knowns-mode 'normal)
  (current-module-bridge-detail-rows '())
  (current-webify-bridge-stats (make-hash))

  (current-browser? browser?)
  (current-enable-cc-analysis? enable-cc-analysis?)
  (current-console-bridge? console-bridge?)
  (current-tree-shake? tree-shake?)
  (current-module-bridge-elide-public-cells? module-bridge-elide-public-cells?)
  (define provider-cache-path
    (let ([p (if (path? provider-cache-dir)
                 provider-cache-dir
                 (string->path provider-cache-dir))])
      (path->complete-path p)))
  (current-runtime-cache-dir provider-cache-path)
  (current-runtime-primitive-report-path tree-shake-report)
  (set-browser-mode! browser?)
  (current-provider-cache-dir provider-cache-path)
  (current-provider-cache-force? force-provider-cache-refresh?)
  (current-provider-cache-verbose? verbose?)
  (current-webracket/base-provider-substitutions? provider-substitutions?)
  (when clear-provider-cache?
    (provider-cache-log "clearing cache directory: ~a" provider-cache-path)
    (with-handlers ([exn:fail:filesystem? void])
      (delete-directory/files provider-cache-path)))
  (when verbose?
    (provider-cache-log "cache directory: ~a" provider-cache-path)
    (when force-provider-cache-refresh?
      (provider-cache-log "force refresh enabled")))
  (define provider-owned-primitive-aliases/pre-read
    (provider-owned-primitive-alias-symbols
     #:expander-read-provider? expander-read-provider?
     #:io-format-provider? #f))

  ; 0. Check that `filename` exists and is a source file.
  (ensure-source-file! 'drive-compilation filename)

  ; 1. Read the top-level forms from `filename`.
  (define t-read-source-start (now-ms))
  (define stx
    (with-handlers ([exn:fail? (lambda (e)
                                 (error 'drive-compilation
                                        "~a"
                                        (~a "read failed: " (exn-message e))))])
      (parameterize ([current-provider-owned-primitive-aliases
                      provider-owned-primitive-aliases/pre-read])
        (read-top-level-from-file
         filename
         #:webracket-module-bridge? webracket-module-bridge?))))
  (define t-read-source-end (now-ms))
  (define stx-for-compile
    (if print-top-level-results?
        (add-print-top-level-results-sentinel stx)
        stx))
  (define module-input? (and (current-source-module-language) #t))
  (define effective-legacy-stdlib?
    (and (not module-input?) stdlib?))
  (define effective-io-format-provider?
    (and (not module-input?) stdlib-io-format-provider?))
  (define effective-expander-read-provider?
    expander-read-provider?)
  (define effective-expander-read-syntax-provider?
    expander-read-syntax-provider?)
  (define stdlib-decision-rows
    (list
     (stdlib-decision-note "input-mode"
                           (if module-input? "module" "script"))
     (stdlib-decision-note "legacy-stdlib-mode"
                           (cond
                             [module-input?
                              (if stdlib?
                                  "ignored-module-input"
                                  "skipped-module-input")]
                             [stdlib?
                              "enabled-script-input"]
                             [else
                              "disabled-script-input"]))
     (stdlib-decision-note "io-format-provider-mode"
                           (cond
                             [module-input?
                              (if stdlib-io-format-provider?
                                  "skipped-module-input"
                                  "disabled-module-input")]
                             [stdlib-io-format-provider?
                              "enabled-script-input"]
                             [else
                              "disabled-script-input"]))
     (stdlib-decision-note "expander-read-provider-mode"
                           (if effective-expander-read-provider?
                               "enabled"
                               "disabled"))
     (stdlib-decision-note "expander-read-syntax-provider-mode"
                           (if effective-expander-read-syntax-provider?
                               "enabled"
                               "disabled"))
     (stdlib-decision-note "regexp-provider-mode"
                           (cond
                             [module-input?
                              (if (current-module-bridge-needs-regexp-provider?)
                                  "enabled-module-demand"
                                  "skipped-module-no-demand")]
                             [else
                              "enabled"]))))

  ; 2. Handle ffi-files.
  (define t-ffi-setup-start  (now-ms))
  (define resolved-ffi-files
    (merged-ffi-files 'drive-compilation
                      browser?
                      ffi-files
                      stx
                      #:source-filename filename))

  (define ffi-foreigns  '()) ; list of `foreign` structures
  (define ffi-imports   '()) ; list of wat
  (define ffi-funcs     '()) ; list of wat

  (for ([ffi-filename resolved-ffi-files])
    (define fs (ffi-file->foreigns ffi-filename))
    (set! ffi-foreigns (cons fs ffi-foreigns)))
  (set! ffi-foreigns
        (foreigns-deduplicate
         'drive-compilation
         (append* (reverse ffi-foreigns))))
  (set! ffi-imports (map foreign->import ffi-foreigns))
  (set! ffi-funcs   (map foreign->primitive ffi-foreigns))

  (current-ffi-foreigns    ffi-foreigns)
  (current-ffi-imports-wat ffi-imports)
  (current-ffi-funcs-wat   ffi-funcs)
  (define t-ffi-setup-end (now-ms))

  ; 3. Prepend the standard library (if enabled)
  ;     "legacy-stdlib/stdlib-for-browser.rkt" includes "stdlib.rkt" and adds `sxml->dom`
  (define t-add-stdlib-start (now-ms))
  (define stx-with-stdlib
    (cond
      [(current-source-module-language)
       (when (and verbose? stdlib?)
         (displayln
          "Ignoring legacy stdlib root for module-language input"
          (current-error-port)))
       (when (and verbose? stdlib-io-format-provider?)
         (displayln
          "Skipping staged io/format provider for module-language input; module providers resolve racket/format directly"
          (current-error-port)))
       (cond
         [effective-expander-read-provider?
          (add-expander-read-provider stx-for-compile
                                      #:expander-read-syntax-provider?
                                      effective-expander-read-syntax-provider?)]
         [effective-expander-read-syntax-provider?
          (with-syntax ([(provider-form ...)
                         (map (lambda (form)
                                (datum->syntax stx-for-compile form stx-for-compile))
                              (append
                               (regexp-provider-forms #:public-aliases? #t
                                                      #:cache-context 'read-syntax)
                               (provider-slice-forms 'expander/read-syntax)))])
            #`(begin
                provider-form ...
                #,stx-for-compile))]
         [else
          (if (current-module-bridge-needs-regexp-provider?)
              (add-regexp-provider stx-for-compile)
              stx-for-compile)])]
      [(and effective-legacy-stdlib? browser?)
       (when verbose?
         (displayln "Composing module stdlib root `legacy-stdlib/stdlib-for-browser.rkt`"
                    (current-error-port)))
       (add-module-stdlib stx-for-compile
                           #t
                           #:io-format-provider? effective-io-format-provider?
                           #:expander-read-provider? effective-expander-read-provider?
                           #:expander-read-syntax-provider? effective-expander-read-syntax-provider?)]
      [effective-legacy-stdlib?
       (when verbose?
         (displayln "Composing module stdlib root `legacy-stdlib/stdlib.rkt`"
                    (current-error-port)))
       (add-module-stdlib stx-for-compile
                           #f
                           #:io-format-provider? effective-io-format-provider?
                           #:expander-read-provider? effective-expander-read-provider?
                           #:expander-read-syntax-provider? effective-expander-read-syntax-provider?)]
      [effective-io-format-provider?
       (when verbose?
         (displayln "Composing module stdlib-free `io/format` provider"
                    (current-error-port)))
       (add-io-format-provider stx-for-compile
                               #:expander-read-provider? effective-expander-read-provider?
                               #:expander-read-syntax-provider? effective-expander-read-syntax-provider?)]
      [effective-expander-read-provider?
       (when verbose?
         (displayln "Composing module stdlib-free `expander/read` provider"
                    (current-error-port)))
       (add-expander-read-provider stx-for-compile
                                   #:expander-read-syntax-provider?
                                   effective-expander-read-syntax-provider?)]
      [effective-expander-read-syntax-provider?
       (when verbose?
         (displayln "Composing module stdlib-free `expander/read-syntax` provider"
                    (current-error-port)))
       (with-syntax ([(provider-form ...)
                      (map (lambda (form) (datum->syntax stx-for-compile form stx-for-compile))
                           (append
                            (regexp-provider-forms #:public-aliases? #t
                                                   #:cache-context 'read-syntax)
                            (provider-slice-forms 'expander/read-syntax)))])
         #`(begin
             provider-form ...
             #,stx-for-compile))]
      [else
       (when verbose?
         (displayln "Composing module stdlib-free `regexp` provider"
                    (current-error-port)))
       (add-regexp-provider stx-for-compile)]))
  (define t-add-stdlib-end (now-ms))

  (define t-preflight-start (now-ms))

  ; 4. Preflight checks

  ; Preflight: `-r` requires Node host mode.
  (when (and run-after? browser?)
    (error 'drive-compilation
           "cannot use `-r` in browser mode; use Node mode or omit `-r`."))

  ; Preflight: `-r` in Node mode requires a Node.js executable.
  (when (and node? run-after?)
    (check-node! 'drive-compilation))

  ; Precompute output paths for preflight checks.
  (define output-paths
    (resolve-compilation-output-paths filename
                                      wat-filename
                                      wasm-filename
                                      host-filename
                                      dest-dir
                                      node?))
  (define out-wat  (compilation-output-paths-wat output-paths))
  (define out-wasm (compilation-output-paths-wasm output-paths))
  (define out-map  (compilation-output-paths-map output-paths))
  (define out-host (compilation-output-paths-host output-paths))

  ; Preflight: ensure output files do not collide.
  (ensure-distinct-output-files!
   'drive-compilation
   (list (cons "WAT output file"       out-wat)
         (cons "Wasm output file"      out-wasm)
         (cons "label-map output file" out-map)
         (cons "host output file"      out-host)))

  ; Preflight: ensure output locations are writable.
  (ensure-output-path-writable! 'drive-compilation out-wat  "WAT output file")
  (ensure-output-path-writable! 'drive-compilation out-wasm "Wasm output file")
  (ensure-output-path-writable! 'drive-compilation out-map  "label-map output file")
  (ensure-output-path-writable! 'drive-compilation out-host "host output file")
  
  ; Preflight: ensure wasm-tools exists and can run.
  (check-wasm-tools! 'drive-compilation)
  (define t-preflight-end (now-ms))

  ; 5. Compile the syntax object.
  (label-map-include-form? label-map-forms?)
  (current-pass-dump-dir   dump-passes-dir)
  (current-pass-dump-limit dump-passes-limit)
  (current-pass-timings?   timings?)
  (current-alpha-rename-profile? alpha-rename-profile?)
  (current-simplify-profile? simplify-profile?)
  (define t-compile-start (now-ms))
  (define provider-owned-primitive-aliases
    (provider-owned-primitive-alias-symbols
     #:expander-read-provider? effective-expander-read-provider?
     #:io-format-provider? effective-io-format-provider?))
  (define wat
    (with-handlers (#;[exn:fail? (λ (e)
                                 (error 'drive-compilation
                                        (~a "compile failed: " (exn-message e))))])
      (parameterize ([current-browser? browser?]
                     [current-enable-cc-analysis? enable-cc-analysis?]
                     [current-letrec-strategy letrec-strategy]
                     [current-enable-simplify? enable-simplify?]
                     [current-module-bridge-elide-public-cells?
                      module-bridge-elide-public-cells?]
                     [current-print-top-level-results? print-top-level-results?]
                     [current-internal-treelist-debug-shape?
                      internal-bind-treelist-debug-shape?]
                     [current-internal-immutable-hash-debug-shape?
                      internal-bind-immutable-hash-debug-shape?]
                     [current-provider-owned-primitive-aliases
                      provider-owned-primitive-aliases])
        (comp stx-with-stdlib))))
  (define t-compile-end (now-ms))

  ; 6. Save the resulting WAT module.
  (define t-write-wat-start (now-ms))
  (write-wat-to-file out-wat wat #:pretty? pretty-wat?)
  (ensure-generated-file-exists! 'drive-compilation out-wat "WAT output file")
  (define t-write-wat-end (now-ms))

  ; 7. Compile the wat-file to wasm using `wat->wasm` from `assembler.rkt`
  (define t-assemble-start (now-ms))
  (define wat->wasm-success?
    (with-handlers ([exn:fail? (λ (e)
                                 (error 'drive-compilation
                                        (~a "wat->wasm failed: " (exn-message e))))])
      (wat->wasm wat #:wat out-wat #:wasm out-wasm #:write-wat? #f)))
  (unless wat->wasm-success?
    (error 'drive-compilation
           (~a "wat->wasm failed to produce bytecode for " filename)))
  (ensure-generated-file-exists! 'drive-compilation out-wasm "Wasm bytecode file")
  (define t-assemble-end (now-ms))

  ; 7b. Write label map sidecar
  (define t-write-map-start (now-ms))
  (with-output-to-file out-map
    (λ () (pretty-write (label-map->sexp)))
    #:exists 'replace)
  (ensure-generated-file-exists! 'drive-compilation out-map "label-map output file")
  (define t-write-map-end (now-ms))

  ; 8. Write the host file (default: "runtime.js")
  (define t-write-host-start (now-ms))
  (define runtime-wasm-reference
    (if browser?
        (path->string
         (find-relative-path
          (path->complete-path (or (path-only out-host) (current-directory))
                               (current-directory))
          (path->complete-path out-wasm (current-directory))))
        out-wasm))
  (with-output-to-file out-host
    (λ () (displayln
           (runtime #:out runtime-wasm-reference
                    #:host (if node? 'node 'browser)
                    #:console-bridge? console-bridge?
                    #:vfs-preloads vfs-preloads
                    #:vfs-mounts vfs-mounts)))
    #:exists 'replace)
  (ensure-generated-file-exists! 'drive-compilation out-host "host output file")
  (define t-write-host-end (now-ms))

  ; 9. Optionally run the program via Node.js.
  (define t-run-ms 0.0)
  (when (and node? run-after?)
    (define t-run-start (now-ms))
    (ensure-generated-file-exists! 'drive-compilation out-wasm "Wasm bytecode file")
    (define runtime-js out-host)
    (set! exit-code
          (run #f
               #:wat out-wat
               #:wasm out-wasm
               #:runtime.js runtime-js
               #:write-runtime? #f))
    (set! t-run-ms (- (now-ms) t-run-start)))

  ; 10. Output timings
  (define alpha-rename-profile-report
    (current-alpha-rename-profile-report))
  (define simplify-profile-report
    (current-simplify-profile-report))
  (when timings?
    (define ffi-setup-ms     (- t-ffi-setup-end   t-ffi-setup-start))
    (define read-source-ms   (- t-read-source-end t-read-source-start))
    (define add-stdlib-ms    (- t-add-stdlib-end  t-add-stdlib-start))
    (define preflight-ms     (- t-preflight-end   t-preflight-start))
    (define compile-ms       (- t-compile-end     t-compile-start))
    (define write-wat-ms     (- t-write-wat-end   t-write-wat-start))
    (define assemble-ms      (- t-assemble-end    t-assemble-start))
    (define write-map-ms     (- t-write-map-end   t-write-map-start))
    (define write-host-ms    (- t-write-host-end  t-write-host-start))
    (define compile-total-ms (- t-write-host-end  t-compile-start))
    (define driver-total-ms  (+ (- t-write-host-end t-driver-start)
                                t-run-ms))
    (set! compile-timings
          (compilation-timings ffi-setup-ms
                               read-source-ms
                               add-stdlib-ms
                               preflight-ms
                               compile-ms
                               write-wat-ms
                               assemble-ms
                               write-map-ms
                               write-host-ms
                               compile-total-ms
                               t-run-ms
                               driver-total-ms))
    (define read-detail-rows (current-read-source-timing-rows))
    (define module-bridge-detail-rows (current-module-bridge-detail-rows))
    (define driver-rows
      (append
       (list (list "ffi-setup"        ffi-setup-ms)
             (list "read-source"      read-source-ms)
             (list "add-stdlib"       add-stdlib-ms)
             (list "preflight"        preflight-ms)
             (list "compile-pipeline" compile-total-ms))
       (if (zero? t-run-ms)
           '()
           (list (list "run" t-run-ms)))
       (list (list "total" driver-total-ms))))
    (define overall-table
      (format-timing-table
       (list (list "compile"    compile-ms)
             (list "write-wat"  write-wat-ms)
             (list "assemble"   assemble-ms)
             (list "write-map"  write-map-ms)
             (list "write-host" write-host-ms)
             (list "total"      compile-total-ms))))
    (displayln "=== Driver Timings ===")
    (displayln (format-timing-table driver-rows))
    (displayln "=== Stdlib Decision ===")
    (displayln (format-metric-table stdlib-decision-rows))
    (when (pair? read-detail-rows)
      (displayln "=== Read Source Details ===")
      (displayln (format-timing-table read-detail-rows)))
    (when (pair? module-bridge-detail-rows)
      (displayln "=== Module Bridge Extract Details ===")
      (displayln
       (format-timing-table
        (append module-bridge-detail-rows
                (list (list "total"
                            (for/sum ([row (in-list module-bridge-detail-rows)])
                              (second row))))))))
      (define module-bridge-metric-rows
        (filter (lambda (row)
                  (let ([value (second row)])
                    (not (and (number? value)
                              (zero? value)))))
                (hash-ref (current-webify-bridge-stats)
                          'module-bridge-metric-rows
                          '())))
      (when (pair? module-bridge-metric-rows)
        (displayln
         (format-metric-table
          (for/list ([row (in-list module-bridge-metric-rows)])
            (list (car row) (~a (second row)))))))
    (displayln "=== Compile Pipeline ===")
    (displayln overall-table)
    (define pass-table (current-pass-timing-table))
    (when pass-table
      (displayln "=== Pass Timings ===")
      (displayln pass-table))
    (define gen-table (current-gen-timing-table))
    (when gen-table
      (displayln "=== Generate-Code Phases ===")
      (displayln gen-table)))
  (when alpha-rename-profile-report
    (displayln "=== Alpha-Rename Profile ===")
    (displayln alpha-rename-profile-report))
  (when simplify-profile-report
    (displayln "=== Simplify-LFE Profile ===")
    (displayln simplify-profile-report))
  (values exit-code compile-timings))

;;;
;;; READ TOP-LEVEL FORMS FROM FILE 
;;;

(define (webracket-script-lang-line? line)
  (and (string? line)
       (regexp-match? #px"^#lang[ \t]+webracket([ \t].*)?$" line)))

(define (webracket-base-lang-line? line)
  (and (string? line)
       (regexp-match? #px"^#lang[ \t]+webracket/base([ \t].*)?$" line)))

(define (webracket-module-lang-line? line)
  (and (string? line)
       (regexp-match? #px"^#lang[ \t]+webracket/(base|full)([ \t].*)?$" line)))

(define (webracket-module-lang-line->language line)
  (define match
    (and (string? line)
         (regexp-match #px"^#lang[ \t]+webracket/(base|full)([ \t].*)?$" line)))
  (and match (string->symbol (cadr match))))

(define (webracket-module-source-language filename)
  (call-with-input-file filename
    (lambda (port)
      (or (webracket-module-lang-line->language (read-line port 'any))
          'base))))

(define (module-export-cell-symbol module-name export)
  (string->symbol (format "webify-module-export-cell$~a$~a" module-name export)))

(define (module-private-symbol module-name name)
  (string->symbol (format "webify-module-private$~a$~a" module-name name)))

(define (simple-provide-exports form)
  (match form
    [`(provide ,exports ...)
     (filter symbol? exports)]
    [_ '()]))

(define (simple-local-require-paths form)
  (define (spec->paths spec)
    (match spec
      [(? string?) (list spec)]
      [(? symbol?) '()]
      [`(combine-in ,inner ...)
       (append* (map spec->paths inner))]
      [`(,(or 'only-in 'except-in 'rename-in 'prefix-in
              'only-meta-in 'for-meta 'for-syntax 'for-template
              'for-label 'for-space)
         ,inner . ,_rest)
       (cond
         [(string? inner)
          (raise-arguments-error
           'read-top-level-from-file
           "unsupported #lang webracket/base local require spec"
           "spec" spec
           "supported" "plain local string requires, such as (require \"lib.rkt\")")]
         [else '()])]
      [_ '()]))
  (match form
    [`(require ,specs ...)
     (append* (map spec->paths specs))]
    [_ '()]))

(define (candidate-module-symbol->relative-rkt-path candidate)
  (and (symbol? candidate)
       (string->path (string-append (symbol->string candidate) ".rkt"))))

;; local-require-spec-paths : any/c path? -> (listof path?)
;;   Discover source-visible local files before expanded metadata is available.
(define (local-require-spec-paths spec source-dir)
  (define (relative-path->complete path-string base-dir)
    (simplify-path (build-path base-dir path-string)))
  (match spec
    [(? string?)
     (list (relative-path->complete spec source-dir))]
    [`(relative-in ,(? string? base) ,inner ...)
     (define base-path (relative-path->complete base source-dir))
     (define base-dir  (or (path-only base-path) source-dir))
     (append* (map (lambda (inner-spec)
                     (local-require-spec-paths inner-spec base-dir))
                   inner))]
    [`(combine-in ,inner ...)
     (append* (map (lambda (inner-spec)
                     (local-require-spec-paths inner-spec source-dir))
                   inner))]
    [`(,(or 'only-in 'except-in 'rename-in 'prefix-in 'only-meta-in)
       ,inner . ,_rest)
     (local-require-spec-paths inner source-dir)]
    [`(for-meta 0 ,inner ...)
     (append* (map (lambda (inner-spec)
                     (local-require-spec-paths inner-spec source-dir))
                   inner))]
    [_ '()]))

;; local-require-form-paths : any/c path? -> (listof path?)
;;   Discover local file dependencies from one source require form.
(define (local-require-form-paths form source-dir)
  (match form
    [`(require ,specs ...)
     (append* (map (lambda (spec)
                     (local-require-spec-paths spec source-dir))
                   specs))]
    [_ '()]))

(define (webracket/base-report-local-dependency-paths report source-dir)
  (define import-map (webify-module-report-import-map report))
  (define self-name (webify-module-report-name report))
  (remove-duplicates
   (for/list ([candidate (in-list (webify-module-import-map-required-module-candidates
                                    import-map))]
              #:when (= 0 (car candidate))
              #:do [(define module-name (cadr candidate))
                    (define relative-path
                      (candidate-module-symbol->relative-rkt-path module-name))
                    (define path
                      (and relative-path
                           (simplify-path (build-path source-dir relative-path))))]
              #:when (and path
                          (not (eq? module-name self-name))
                          (file-exists? path)))
     path)
   equal?))

(define (simple-defined-symbols forms)
  (append-map stdlib-definition-form-symbols forms))

(define (module-rename-reference renames v)
  (cond
    [(symbol? v)
     (hash-ref renames v v)]
    [(pair? v)
     (match v
       [`(quote . ,_) v]
       [`(quote-syntax . ,_) v]
       [`(syntax . ,_) v]
       [`(quasiquote . ,_) v]
       [else
        (cons (module-rename-reference renames (car v))
              (module-rename-reference renames (cdr v)))])]
    [(vector? v)
     (list->vector
      (for/list ([elem (in-vector v)])
        (module-rename-reference renames elem)))]
    [else v]))

(define (module-rename-definition-name renames name)
  (hash-ref renames name name))

(define (module-rename-top-level-form renames form)
  (match form
    [`(define (,name . ,formals) . ,body)
     `(define (,(module-rename-definition-name renames name) . ,formals)
        ,@(map (lambda (expr) (module-rename-reference renames expr)) body))]
    [`(define ,name . ,rhs)
     `(define ,(module-rename-definition-name renames name)
        ,@(map (lambda (expr) (module-rename-reference renames expr)) rhs))]
    [`(define-values ,names . ,rhs)
     `(define-values ,(map (lambda (name) (module-rename-definition-name renames name))
                           names)
        ,@(map (lambda (expr) (module-rename-reference renames expr)) rhs))]
    [else
     (module-rename-reference renames form)]))

;; read-webracket/module : path-string? (or/c 'base 'full) -> syntax?
;;   Read a WebRacket module source through normal Racket module reading.
(define (read-webracket/module filename language)
  (with-driver-timing
   'module-read
   (lambda ()
     (define resolved (simplify-path (path->complete-path filename)))
     (call-with-input-file resolved
       (lambda (port)
         (port-count-lines! port)
         (define dir (or (path-only resolved) (current-directory)))
         (parameterize ([current-directory dir]
                        [current-load-relative-directory dir]
                        [current-write-relative-directory dir])
           (with-module-reading-parameterization
             (lambda ()
               ;; Module readers and expander-time relative requires must be
               ;; anchored to the source file, not the caller's cwd.
               (ensure-webracket/module-reader! language)
               (read-syntax resolved port)))))))))

;; read-webracket/base-module : path-string? -> syntax?
;;   Compatibility wrapper for WebRacket module readers.
(define (read-webracket/base-module filename)
  (webracket/base-substitute-module-requires
   (webracket/full-module->base-require-module
    (read-webracket/module filename (webracket-module-source-language filename)))))

;; webracket/full-module->base-require-module : syntax? -> syntax?
;;   Normalize #lang webracket/full to an explicit provider import. This keeps
;;   the full surface available while avoiding host-expander phase-1 lazy
;;   require resolution through the language-root module.
(define (webracket/full-module->base-require-module stx)
  (define datum (syntax->datum stx))
  (define rewritten
    (match datum
      [`(module ,name webracket/full (#%module-begin ,forms ...))
       `(module ,name webracket/base
          (#%module-begin
           (require webracket/full)
           ,@forms))]
      [`(module ,name webracket/full ,forms ...)
       `(module ,name webracket/base
          (require webracket/full)
          ,@forms)]
      [_ datum]))
  (if (equal? rewritten datum)
      stx
      (datum->syntax stx rewritten stx)))

;; webracket/base-provider-substitution : struct
;;   Describe one provider substitution so temporary shims stay visible.
(struct webracket/base-provider-substitution
  (requested routed classification pressure disposition reason)
  #:transparent)

;; substitution : symbol? symbol? symbol? symbol? symbol? string? -> webracket/base-provider-substitution?
;;   Keep the substitution table compact while retaining ownership metadata.
(define (substitution requested routed classification pressure disposition reason)
  (webracket/base-provider-substitution requested
                                        routed
                                        classification
                                        pressure
                                        disposition
                                        reason))

;; webracket/base-provider-substitution-records : (listof webracket/base-provider-substitution?)
;;   Single Goal 1 substitution registry for source-level requires and provider-graph fetching.
(define webracket/base-provider-substitution-records
  (list
   (substitution 'racket/contract 'webracket/contract 'temporary-shim 'high 'postpone
                 "erased contracts unblock provider composition until contract enforcement is available")
   (substitution 'racket/contract/base 'webracket/contract 'temporary-shim 'high 'postpone
                 "same erased-contract adapter as racket/contract")
   (substitution 'racket/contract/combinator 'webracket/contract 'temporary-shim 'high 'postpone
                 "same erased-contract adapter as racket/contract")
   (substitution 'racket/contract/region 'webracket/contract 'temporary-shim 'high 'postpone
                 "same erased-contract adapter as racket/contract")
   (substitution 'racket/contract/private/list 'webracket/contract 'temporary-shim 'high 'postpone
                 "same erased-contract adapter as racket/contract")
   (substitution 'racket/contract/private/misc 'webracket/contract 'temporary-shim 'high 'postpone
                 "same erased-contract adapter as racket/contract")
   (substitution 'racket/file 'webracket/file 'runtime-owned 'low 'keep-webracket-owned
                 "browser and VFS file behavior differs from host filesystem behavior")
   (substitution 'racket/format 'webracket/private/format 'staged-original 'medium 'keep-webracket-owned
                 "route source expansion to the staged io/format-backed adapter")
   (substitution 'racket/generator 'webracket/generator 'diagnostic-shim 'low 'postpone
                 "generators depend on continuation prompts, which are outside Goal 1")
   (substitution 'racket/hash 'webracket/hash 'temporary-shim 'medium 'keep-webracket-owned
                 "hash helpers should track WebRacket HAMT/runtime hash behavior")
   (substitution 'racket/mpair 'webracket/mpair 'runtime-owned 'low 'keep-webracket-owned
                 "mutable-pair representation is WebRacket runtime work")
   (substitution 'racket/port 'webracket/port 'runtime-owned 'low 'keep-webracket-owned
                 "ports are tied to WebRacket string ports, VFS, and browser IO")
   (substitution 'racket/private/kw 'webracket/private/kw 'runtime-owned 'high 'keep-webracket-owned
                 "keyword-procedure structs must share one WebRacket runtime type across composed providers")
   (substitution 'racket/private/sort 'webracket/private/sort 'runtime-owned 'high 'keep-webracket-owned
                 "keyword-capable sort bindings should use WebRacket's primitive sort bridge")
   (substitution 'racket/private/share-search 'webracket/private/share-search 'runtime-owned 'low 'keep-webracket-owned
                 "runtime-path shared-data search has no browser host directory equivalent")
   (substitution 'racket/private/so-search 'webracket/private/so-search 'runtime-owned 'low 'keep-webracket-owned
                 "runtime-path shared-object search has no browser native-library equivalent")
   (substitution 'racket/promise 'webracket/promise 'runtime-owned 'low 'keep-webracket-owned
                 "ordinary promises are small browser-local runtime behavior")
   (substitution 'racket/set 'webracket/set 'temporary-shim 'medium 'keep-webracket-owned
                 "set support follows WebRacket hash/HAMT behavior while contracts/generics are postponed")
   (substitution 'racket/stream 'webracket/stream 'temporary-shim 'medium 'postpone
                 "staged streams preserve lazy syntax without importing full stream internals")
   (substitution 'racket/unsafe/undefined 'webracket/unsafe/undefined 'runtime-owned 'low 'keep-webracket-owned
                 "undefined values need WebRacket representation support")
   (substitution 'syntax/contract 'webracket/syntax/contract 'temporary-shim 'high 'postpone
                 "supports contract erasure at expansion and provider time")))

;; webracket/base-erased-contract-provider-name? : symbol? -> boolean?
;;   Recognize contract implementation providers that real-provider diagnostics
;;   should satisfy with WebRacket's erased contract module during extraction.
(define (webracket/base-erased-contract-provider-name? name)
  (memq name
        '(racket/contract
          racket/contract/base
          racket/contract/combinator
          racket/contract/region
          racket/in-out
          racket/module-boundary-ctc
          racket/contract/private/arrow-collapsible
          racket/contract/private/arrow-common
          racket/contract/private/arrow-higher-order
          racket/contract/private/arrow-val-first
          racket/contract/private/base
          racket/contract/private/blame
          racket/contract/private/case-arrow
          racket/contract/private/guts
          racket/contract/private/list
          racket/contract/private/module-boundary-ctc
          racket/contract/private/misc
          racket/contract/private/object
          racket/contract/private/object-c-wrapper
          racket/contract/private/opt
          racket/contract/private/orc
          racket/contract/private/prop
          ;; Racket/contract's compiled metadata can expose relative contract
          ;; implementation paths. They are still contract-owned and should use
          ;; the erased WebRacket contract provider during Goal 1 diagnostics.
          private/arrow-common
          private/arrow-val-first
          private/base
          private/guts
          private/helpers
          private/misc)))

;; webracket/base-provider-substitution-pairs : (listof (cons/c symbol? symbol?))
;;   Pair view of the structured substitution registry.
(define webracket/base-provider-substitution-pairs
  (for/list ([record (in-list webracket/base-provider-substitution-records)])
    (cons (webracket/base-provider-substitution-requested record)
          (webracket/base-provider-substitution-routed record))))

;; webracket/base-provider-substitute : symbol? -> symbol?
;;   Route selected installed providers to smaller WebRacket-owned Goal 1 shims.
(define (webracket/base-provider-substitute name)
  (if (current-webracket/base-provider-substitutions?)
      (let ([maybe (assq name webracket/base-provider-substitution-pairs)])
        (if maybe
            (cdr maybe)
            name))
      name))

;; substitute-require-module-path : any/c -> any/c
;;   Rewrite selected source-level require paths to WebRacket-owned providers.
(define (substitute-require-module-path module-path)
  (if (symbol? module-path)
      (webracket/base-provider-substitute module-path)
      module-path))

;; substitute-require-spec : any/c -> any/c
;;   Rewrite provider paths inside common require combinators.
(define (substitute-require-spec spec)
  (match spec
    [(? symbol?) (substitute-require-module-path spec)]
    [`(,(and form
             (or 'only-in 'except-in 'rename-in 'prefix-in
                 'combine-in 'only-meta-in 'for-meta 'for-syntax
                 'for-template 'for-label 'for-space))
       ,body ...)
     (cons form (map substitute-require-spec body))]
    [_ spec]))

;; substitute-require-form : any/c -> any/c
;;   Rewrite module paths in one require form.
(define (substitute-require-form form)
  (match form
    [`(require ,specs ...)
     `(require ,@(map substitute-require-spec specs))]
    [_ form]))

;; webracket/base-substitute-module-requires : syntax? -> syntax?
;;   Apply Goal 1 provider substitutions before module extraction/expansion.
(define (webracket/base-substitute-module-requires stx)
  (define datum (syntax->datum stx))
  (define rewritten
    (match datum
      [`(module ,name ,language (#%module-begin ,forms ...))
       `(module ,name ,language (#%module-begin ,@(map substitute-require-form forms)))]
      [`(module ,name ,language ,forms ...)
       `(module ,name ,language ,@(map substitute-require-form forms))]
      [_ datum]))
  (if (equal? rewritten datum)
      stx
      (datum->syntax stx rewritten stx)))

;; module-stx->name+body : syntax? -> values
;;   Extract the module name and body from a #lang webracket/base or full datum.
(define (module-stx->name+body stx)
  (define datum (syntax->datum stx))
  (match datum
    [`(module ,(? symbol? name) ,(and language
                                      (or 'webracket/base 'webracket/full))
              (#%module-begin ,forms ...))
     (values name forms)]
    [`(module ,(? symbol? name) ,(and language
                                      (or 'webracket/base 'webracket/full))
              ,forms ...)
     (values name forms)]
    [_
     (raise-arguments-error
      'read-top-level-from-file
      "expected a #lang webracket/base or #lang webracket/full module"
      "datum" datum)]))

;; webracket/base-module->top-level-forms : path-string? [hash?] [boolean?] -> values
;;   Inline simple local string requires for the transitional top-level path.
(define (webracket/base-module->top-level-forms filename [seen (make-hash)] [root? #t])
  (define resolved (simplify-path (path->complete-path filename)))
  (cond
    [(hash-ref seen resolved #f)
     (values '() '())]
    [else
     (hash-set! seen resolved #t)
     (define stx (read-webracket/base-module resolved))
     (define-values (module-name body) (module-stx->name+body stx))
     (define source-dir (or (path-only resolved) (current-directory)))
     (define require-paths (append-map simple-local-require-paths body))
     (define-values (required-forms _required-exports)
       (for/fold ([forms '()]
                  [exports '()])
                 ([req (in-list require-paths)])
         (define req-path (simplify-path (build-path source-dir req)))
         (define-values (req-forms req-exports)
           (webracket/base-module->top-level-forms req-path seen #f))
         (values (append forms req-forms)
                 (append exports req-exports))))
     (define exports (append-map simple-provide-exports body))
     (define body-top-level-forms
       (filter (lambda (form)
                 (not (and (pair? form)
                           (memq (car form) '(provide module+ require)))))
               body))
     (define private-renames
       (if root?
           (hasheq)
           (for/hasheq ([name (in-list (simple-defined-symbols body-top-level-forms))]
                        #:unless (memq name exports))
             (values name (module-private-symbol module-name name)))))
     (define top-level-forms
       (if root?
           body-top-level-forms
           (map (lambda (form) (module-rename-top-level-form private-renames form))
                body-top-level-forms)))
     (define export-forms
       (for/list ([export (in-list exports)])
         (define cell (module-export-cell-symbol module-name export))
         `(begin
            (define ,cell (module-variable-make ',export))
            (module-variable-define! ,cell ,export 'constant))))
     (values (append required-forms top-level-forms export-forms)
             exports)]))

;; module-form->top-level : path-string? -> syntax?
;;   Transitional #lang webracket/base support for the top-level compiler path.
(define (module-file->top-level filename)
  (define-values (forms _exports)
    (webracket/base-module->top-level-forms filename))
  (datum->syntax #f `(begin ,@forms)))

;; webracket-sequence-prelude-forms : -> datum
;;   Provide the private generic sequence adapter used by expanded `for` forms.
(define (webracket-sequence-prelude-forms)
  '((define (make-sequence who v)
      (cond
        [(exact-nonnegative-integer? v)
         (values (lambda (pos) pos)
                 #f
                 add1
                 0
                 (lambda (pos) (< pos v))
                 #f
                 #f)]
        [(list? v)
         (values car
                 #f
                 cdr
                 v
                 pair?
                 #f
                 #f)]
        [(vector? v)
         (values (lambda (pos) (vector-ref v pos))
                 #f
                 add1
                 0
                 (lambda (pos) (< pos (vector-length v)))
                 #f
                 #f)]
        [(string? v)
         (values (lambda (pos) (string-ref v pos))
                 #f
                 add1
                 0
                 (lambda (pos) (< pos (string-length v)))
                 #f
                 #f)]
        [(bytes? v)
         (values (lambda (pos) (bytes-ref v pos))
                 #f
                 add1
                 0
                 (lambda (pos) (< pos (bytes-length v)))
                 #f
                 #f)]
        [(hash? v)
         (values (lambda (pos) (hash-iterate-key+value v pos #f))
                 #f
                 (lambda (pos) (hash-iterate-next v pos))
                 (hash-iterate-first v)
                 values
                 #f
                 #f)]
        [else
         (raise-argument-error 'for "sequence?" v)]))))

;; with-webracket-sequence-prelude : syntax? -> syntax?
;;   Add generic sequence support without exposing it as a language export.
(define (with-webracket-sequence-prelude stx)
  (datum->syntax
   stx
   `(begin ,@(webracket-sequence-prelude-forms)
           ,@(match (syntax->datum stx)
               [`(begin ,forms ...) forms]
               [datum (list datum)]))
   stx))

(struct webracket/base-local-module-graph (root reports registry module-kinds)
  #:transparent)

;; module-reports->provider-names : (listof webify-module-report?) -> (listof symbol?)
;;   Collect local and required provider names from extracted module reports.
(define (module-reports->provider-names reports)
  (remove-duplicates
   (append (map webify-module-report-name reports)
           (append-map webify-module-report-required-provider-names reports))
   eq?))

;; module-composer-primitive-overrides : -> hash?
;;   Override primitive cells whose compiled-module role differs from scripts.
(define (module-composer-primitive-overrides)
  (hasheq
   'print-values
   `(let ([cell (module-variable-make 'print-values)])
      ;; Module body expression values are discarded, unlike script top-level
      ;; results that may be printed by --print-top-level-results.
      (module-variable-define! cell (lambda values (void)) 'constant)
      cell)))

;; module-datum-direct-require-symbols : any/c -> (listof symbol?)
;;   Find plain direct external require symbols in a source module datum.
(define (module-datum-direct-require-symbols module-datum)
  (define (spec->symbols spec)
    (match spec
      [(? symbol?) (list spec)]
      [`(,(or 'only-in 'except-in 'rename-in 'prefix-in) ,inner . ,_rest)
       (spec->symbols inner)]
      [`(,(or 'combine-in) ,inner ...)
       (append* (map spec->symbols inner))]
      [`(,(or 'for-syntax 'for-template 'for-label 'for-meta 'only-meta-in
              'for-space)
         ,inner . ,_rest)
       (spec->symbols inner)]
      [_ '()]))
  (define (form->symbols form)
    (match form
      [`(require ,specs ...)
       (append* (map spec->symbols specs))]
      [`(#%module-begin ,inner ...)
       (append* (map form->symbols inner))]
      [_ '()]))
  (match module-datum
    [`(module ,_name ,_language ,body ...)
     (remove-duplicates (append* (map form->symbols body)) eq?)]
    [_ '()]))

;; declare-provider-compile-stub! : namespace? symbol? (listof symbol?) -> void?
;;   Declare a compile-time-only provider stub for local module extraction.
(define (declare-provider-compile-stub! namespace name exports)
  (define unique-exports (remove-duplicates exports eq?))
  (parameterize ([current-namespace namespace])
    (namespace-call-with-registry-lock
     namespace
     (lambda ()
       (eval
        `(module ,name racket/base
           ,@(for/list ([export (in-list unique-exports)])
               `(define-values (,export) #f))
           (provide ,@unique-exports)))))))

;; provider-public-export-symbols : symbol? namespace? procedure? -> (listof symbol?)
;;   Approximate source-level value exports added by requiring a provider.
(define (provider-public-export-symbols name namespace module-name-resolver)
  (define before (namespace-mapped-symbols namespace))
  (with-handlers ([exn:fail? (lambda (_exn) '())])
    (parameterize ([current-namespace namespace]
                   [current-module-name-resolver module-name-resolver])
      (namespace-require name)
      (define after (namespace-mapped-symbols namespace))
      (for/list ([sym (in-list after)]
                 #:unless (memq sym before))
        sym))))

;; lib-module-path->symbol : any/c -> (or/c symbol? #f)
;;   Convert simple `(lib "x.rkt" "collection" ...)` paths to shorthand names.
(define (lib-module-path->symbol module-path)
  (define (join-path-parts parts)
    (cond
      [(null? parts) ""]
      [(null? (cdr parts)) (car parts)]
      [else (string-append (car parts) "/" (join-path-parts (cdr parts)))]))
  (match module-path
    [`(lib ,file ,collections ...)
     (and (string? file)
          (andmap string? collections)
          (regexp-match? #rx"[.]rkt$" file)
          (string->symbol
           (join-path-parts
            (append collections
                    (list (regexp-replace #rx"[.]rkt$" file ""))))))]
    [_ #f]))

;; module-path-compile-stub-name : any/c -> (or/c symbol? #f)
;;   Recognize module-path spellings that should resolve to a local stub.
(define (module-path-compile-stub-name module-path)
  (cond
    [(symbol? module-path) module-path]
    [else (lib-module-path->symbol module-path)]))

;; webracket-owned-module-name? : symbol? -> boolean?
;;   Recognize modules that should be compiled directly from this collection.
(define (webracket-owned-module-name? name)
  (regexp-match? #rx"^webracket/" (symbol->string name)))

;; webracket-owned-provider-compile-stub-name? : symbol? -> boolean?
;;   Some WebRacket-owned staged adapters compile cleanly by module path but
;;   are still too awkward to inline into the local source-module extraction
;;   namespace. Let them use the same value-only compile-stub path as external
;;   providers, then fetch their real bridge reports later.
(define (webracket-owned-provider-compile-stub-name? name)
  (memq name
        '(webracket/private/format)))

(define provider-phase0-syntax-export-cache (make-hasheq))

;; provider-has-phase0-syntax-exports? : symbol? -> boolean?
;;   Check whether a provider exports phase-0 syntax that value stubs cannot fake.
(define (provider-has-phase0-syntax-exports? name)
  (hash-ref!
   provider-phase0-syntax-export-cache
   name
   (lambda ()
     (with-handlers ([exn:fail? (lambda (_exn) #t)])
       (define-values (_values syntaxes) (module->exports name))
       (define phase0 (assoc 0 syntaxes))
       (and phase0 (pair? (cdr phase0)))))))

;; provider-compile-stub-safe? : symbol? -> boolean?
;;   Value-only compile stubs are unsafe for providers with macro exports.
(define (provider-compile-stub-safe? name)
  (and (not (memq name '(racket/match racket/match/runtime racket/match/gen-match)))
       (not (provider-has-phase0-syntax-exports? name))))

;; compile-webracket/base-module-file-report : path-string? [#:namespace namespace?] [#:module-name-resolver procedure?] -> webify-module-report?
;;   Compile one module file from its absolute source path.
(define (compile-webracket/base-module-file-report filename
                                                  #:namespace [namespace (make-base-namespace)]
                                                  #:module-name-resolver [module-name-resolver (current-module-name-resolver)])
  (define resolved (simplify-path (path->complete-path filename)))
  (define module-stx (read-webracket/base-module resolved))
  (define source-dir (or (path-only resolved) (current-directory)))
  ;; Read with the normal resolver so #lang webracket/base itself is found,
  ;; then compile with the erased-contract resolver for provider imports. The
  ;; root source module itself must still compile relative to its own path so
  ;; sibling string requires resolve the same way they do during ordinary host
  ;; expansion.
  (provider-cache-log "#lang webracket/base local compile start: ~a" resolved)
  (with-module-bridge-timing
   'source-compile-decompile
   (lambda ()
     (parameterize ([current-directory source-dir]
                    [current-load-relative-directory source-dir]
                    [current-write-relative-directory source-dir])
       (webify-compile-module-report
        module-stx
        #:namespace namespace
        #:module-name-resolver module-name-resolver)))))

;; webracket/base-file->local-module-reports : path-string? -> values
;;   Extract local module reports plus the visited source files for the bridge path.
(define (webracket/base-file->local-module-reports filename)
  (define extraction-namespace (make-base-namespace))
  (define provider-namespace (make-webify-contract-erasing-namespace))
  (define provider-module-name-resolver
    (make-webify-contract-erasing-module-name-resolver))
  (define base-module-name-resolver (current-module-name-resolver))
  (define compile-stub-names '())
  (define (module-name-resolver module-path source syntax load?)
    (define stub-name (module-path-compile-stub-name module-path))
    (cond
      [(and stub-name (memq stub-name compile-stub-names))
       (make-resolved-module-path stub-name)]
      [else
       (base-module-name-resolver module-path source syntax load?)]))
  (define module-name-resolver*
    (case-lambda
      [(module-path source syntax load?)
       (module-name-resolver module-path source syntax load?)]
      [(resolved namespace)
       (base-module-name-resolver resolved namespace)]))
  (define (install-compile-stubs! module-datum)
    (with-module-bridge-timing
     'provider-substitution
     (lambda ()
       (for ([name (in-list (module-datum-direct-require-symbols module-datum))]
             #:unless (webracket/base-language-provider-name? name)
             #:unless (and (webracket-owned-module-name? name)
                           (not (webracket-owned-provider-compile-stub-name? name)))
             #:when (provider-compile-stub-safe? name)
             #:when (webify-provider-trial-module-allowed? name))
         (define substitute-name (webracket/base-provider-substitute name))
         (unless (memq name compile-stub-names)
           (provider-cache-log "#lang webracket/base compile stub install: ~a via ~a"
                               name
                               substitute-name)
           (define use-erased-provider-namespace?
             (not (webracket-owned-ffi-provider-name? substitute-name)))
           (define report
             (if use-erased-provider-namespace?
                 (parameterize ([current-namespace provider-namespace]
                                [current-module-name-resolver provider-module-name-resolver])
                   (webify-module-path->report substitute-name
                                               #:namespace provider-namespace))
                 (webify-module-path->report substitute-name)))
           (define public-exports
             (provider-public-export-symbols
              substitute-name
              (if use-erased-provider-namespace?
                  (make-webify-contract-erasing-namespace)
                  (make-base-namespace))
              (if use-erased-provider-namespace?
                  provider-module-name-resolver
                  base-module-name-resolver)))
           (declare-provider-compile-stub!
            extraction-namespace
            name
            (append public-exports
                    (webify-module-report-phase0-exports report)))
           (set! compile-stub-names (cons name compile-stub-names)))))))
  (define visiting (make-hash))
  (define permanent (make-hash))
  (define reports '())
  (define (visit path)
    (define resolved (simplify-path (path->complete-path path)))
    (cond
      [(hash-ref permanent resolved #f)
       => (lambda (name) name)]
      [(hash-ref visiting resolved #f)
       (raise-arguments-error
        'read-top-level-from-file
        "#lang webracket/base local module cycle is not supported"
        "path" resolved)]
      [else
       (hash-set! visiting resolved #t)
       (define source-dir (or (path-only resolved) (current-directory)))
       (define module-stx (read-webracket/base-module resolved))
       (define module-datum (syntax->datum module-stx))
       (install-compile-stubs! module-datum)
       (define report
         (compile-webracket/base-module-file-report
          resolved
          #:namespace extraction-namespace
          #:module-name-resolver module-name-resolver*))
       (define module-name (webify-module-report-name report))
       (define source-dependency-paths
         (remove-duplicates
          (append-map (lambda (form)
                        (local-require-form-paths form source-dir))
                      (match module-datum
                        [`(module ,_name ,_language (#%module-begin ,forms ...)) forms]
                        [`(module ,_name ,_language ,forms ...) forms]
                        [_ '()]))
          equal?))
       (define report-dependency-paths
         (webracket/base-report-local-dependency-paths report source-dir))
       (for ([dep-path (in-list (remove-duplicates
                                 (append report-dependency-paths
                                         source-dependency-paths)
                                 equal?))])
         (visit dep-path))
       (set! reports (append reports (list report)))
       (hash-remove! visiting resolved)
       (hash-set! permanent resolved module-name)
       module-name]))
  (define root (visit filename))
  (define local-source-paths
    (sort (hash-keys permanent)
          string<?
          #:key path->string))
  (values root reports local-source-paths))

;; webracket/base-language-provider-name? : symbol? -> boolean?
;;   Recognize providers that are part of the #lang webracket/base language root.
(define (webracket/base-language-provider-name? name)
  (memq name
        '(webracket/base/main
          webracket/base
          webracket/js/main
          webracket/js
          webracket/core
          webracket/primitives
          ;; Some host-expanded source can still report legacy relative names.
          ;; Treat them as language-root providers while the bridge normalizes
          ;; installed and package-local module paths.
          base/main
          base
          js/main
          js
          core
          primitives
          #%kernel
          fully
          browser-options
          racket/base
          racket/private/base
          racket/private/misc
          racket/private/pre-base
          ;; Require/provide transformer helpers run in the host expander while
          ;; extracting module metadata; they are not runtime provider demands.
          racket/private/modbeg
          racket/require
          racket/require-syntax
          racket/provide
          racket/provide-syntax)))

;; webracket/base-reports-demand-external-providers? : (listof webify-module-report?) -> boolean?
;;   Check whether a bridge graph needs installed-provider discovery.
(define (webracket/base-reports-demand-external-providers? reports)
  (pair? (webracket/base-external-provider-names reports)))

;; webracket/base-external-provider-names : (listof webify-module-report?) -> (listof symbol?)
;;   List required providers outside local reports and the language root.
(define (webracket/base-external-provider-names reports)
  (define local-provider-names (map webify-module-report-name reports))
  (define (local-bridge-provider-name? name)
    (and (symbol? name)
         (string-prefix? (symbol->string name) "webracket/local/")))
  (define (local-provider-name? name)
    (and (symbol? name)
         (or (memq name local-provider-names)
             (local-bridge-provider-name? name))))
  (remove-duplicates
   (append
    (for/list ([report (in-list reports)]
               #:do [(define name (webify-module-report-name report))]
               #:when (and (not (local-provider-name? name))
                           (webify-provider-trial-module-allowed? name)
                           (not (webracket/base-language-provider-name? name))))
      name)
    (for*/list ([report (in-list reports)]
                [name (in-list (webify-module-report-required-provider-names report))]
                #:unless (or (local-bridge-provider-name? name)
                             (and (local-provider-name? name)
                                   ;; A file module can have the same name as
                                   ;; an external collection provider, such as
                                   ;; `fetch.rkt` requiring collection `fetch`.
                                   ;; The local module's own name must not hide
                                   ;; that external provider from the bridge.
                                   (not (eq? name (webify-module-report-name report))))
                             (webracket/base-language-provider-name? name)))
      name))
   eq?))

;; webify-module-report/rename : report symbol? -> report
;;   Register a substituted provider under the originally requested name.
(define (webify-module-report/rename report name)
  (if (eq? name (webify-module-report-name report))
      report
      (webify-module-report
       name
       (webify-module-report-directory-keys report)
       (webify-module-report-bundle-keys report)
       (webify-module-report-bundle-entries report)
       (webify-module-report-phase0-imports report)
       (webify-module-report-phase0-exports report)
       (webify-module-report-phase0-linklet-datum report)
       (webify-module-report-manifest-ready? report)
       (cons (format "substituted provider registered as ~a" name)
             (webify-module-report-notes report)))))

;; webracket/base-fetch-provider/timed : (symbol? -> webify-module-report?) -> symbol? -> webify-module-report?
;;   Wrap provider extraction with verbose timing diagnostics.
(define ((webracket/base-fetch-provider/timed fetch-provider) name)
  (define substitute-name (webracket/base-provider-substitute name))
  (define start-ms (now-ms))
  (provider-cache-log "#lang webracket/base provider fetch start: ~a via ~a"
                      name
                      substitute-name)
  (define report
    (webify-module-report/rename
     (cached-installed-provider-report substitute-name fetch-provider)
     name))
  (provider-cache-log "#lang webracket/base provider fetch done: ~a via ~a (~ams)"
                      name
                      substitute-name
                      (- (now-ms) start-ms))
  report)

;; webracket/base-local-collision-name : symbol? -> symbol?
;;   Build a private bridge name for a local module/provider-name collision.
(define (webracket/base-local-collision-name name)
  (string->symbol (format "webracket/local/~a" name)))

;; webracket/base-rename-self-colliding-local-reports : symbol? reports -> values
;;   Rename local modules that import an external provider with the same name.
(define (webracket/base-rename-self-colliding-local-reports root reports)
  (define self-colliding-names
    (for/list ([report (in-list reports)]
               #:do [(define name (webify-module-report-name report))]
               #:when (memq name (webify-module-report-required-provider-names report)))
      name))
  (define (renamed-name name)
    (if (memq name self-colliding-names)
        (webracket/base-local-collision-name name)
        name))
  (values (renamed-name root)
          (for/list ([report (in-list reports)])
            (define name (webify-module-report-name report))
            (if (memq name self-colliding-names)
                (webify-module-report/rename report (renamed-name name))
                report))))

;; webracket/base-check-external-provider-allowlist! : reports -> void?
;;   Keep the temporary bridge from silently growing unsupported providers.
(define (webracket/base-check-external-provider-allowlist! reports)
  (define external-names (webracket/base-external-provider-names reports))
  (define unsupported
    (filter (lambda (name)
              (not (webify-provider-trial-module-allowed? name)))
            external-names))
  (unless (null? unsupported)
    (raise-arguments-error
     'webracket/base-reports->module-graph
     "#lang webracket/base external provider is not in the Goal 1 trial allowlist"
     "unsupported providers" unsupported
     "allowed providers" webify-provider-trial-module-allowlist)))

;; webracket-owned-ffi-provider-name? : symbol? -> boolean?
;;   Recognize WebRacket provider modules that do not need contract erasure.
(define webracket-owned-ffi-provider-exacts
  '(web-easy
    audio
    fetch
    indexed-db
    jsxgraph
    storage
    websocket
    web-pict
    rquery
    webracket/full
    webracket/full/main
    webracket/private/ffi
    webracket/private/kw
    webracket/private/sort-public
    webracket/private/sort))

(define webracket-owned-ffi-provider-prefixes
  '("js/"
    "browser/"
    "web-easy/"
    "web-pict/"
    "rquery/"
    "webracket/unsafe/"))

(define (webracket-owned-ffi-provider-name? name)
  (cond
    [(not (symbol? name)) #f]
    [(memq name webracket-owned-ffi-provider-exacts) #t]
    [else
     (define name-string (symbol->string name))
     (for/or ([prefix (in-list webracket-owned-ffi-provider-prefixes)])
       (string-prefix? name-string prefix))]))

;; webracket/base-reports->module-graph : symbol? reports keyword-args -> graph
;;   Build a bridge graph from already-extracted reports.
(define (webracket/base-reports->module-graph root
                                             reports
                                             #:local-source-paths [local-source-paths '()]
                                             #:fetch-provider
                                             [fetch-provider webify-module-path->report])
  (define-values (bridge-root bridge-reports)
    (webracket/base-rename-self-colliding-local-reports root reports))
  (define local-report-names
    (map webify-module-report-name bridge-reports))
  (define support-report-names '())
  (define needs-expander-read-support?
    (for/or ([name (in-list webify-read-public-alias-symbols)])
      (set-member? (current-provider-owned-primitive-aliases) name)))
  (define registry
    (cond
     [(or (webracket/base-reports-demand-external-providers? bridge-reports)
          needs-expander-read-support?)
       (webracket/base-check-external-provider-allowlist! bridge-reports)
       (define external-names (webracket/base-external-provider-names bridge-reports))
       (define provider-namespace (make-webify-contract-erasing-namespace))
       (define provider-module-name-resolver
         (make-webify-contract-erasing-module-name-resolver))
       (define (fetch-provider/erased-contracts name)
         (define staged-io-format-report
           (io-format-provider-report/ref name))
         (define staged-read-report
           (read-provider-report/ref name))
       (define substitute-name (webracket/base-provider-substitute name))
        (define extraction-name
           (cond
             [(eq? name 'racket/in-out)
              'webracket/private/in-out]
             [(memq name '(racket/module-boundary-ctc
                           racket/contract/private/module-boundary-ctc))
              'webracket/private/module-boundary-ctc]
             [(webracket/base-erased-contract-provider-name? name)
              'webracket/contract]
             [else
              substitute-name]))
         (define webracket-owned-provider?
           (and (symbol? extraction-name)
                (string-prefix? (symbol->string extraction-name) "webracket/")))
         (define normal-export-shape?
           ;; The root module is expanded by normal Racket, so contracted
           ;; public providers must keep their generated provide/contract
           ;; export names while their contract implementation dependencies
           ;; remain eligible for erased-provider routing.
          (or (memq name '(racket/dict
                           racket/math
                           racket/private/for
                           racket/private/map
                           racket/private/define-struct
                           racket/private/kernstruct
                           racket/private/class-internal
                           racket/private/class-struct
                           racket/private/stx
                           syntax/context
                           syntax/intdef
                           syntax/kerncase
                           syntax/name
                           syntax/parse/private/lib
                           syntax/parse/private/residual
                           syntax/parse/private/residual/parse-util
                           syntax/parse/private/residual/state
                           syntax/private/id-table
                           syntax/stx
                           racket/unit
                           racket/private/unit/contract
                           racket/private/unit/contract-syntax
                           racket/private/unit/keywords
                           racket/private/unit/runtime
                           racket/private/unit/signature
                           racket/private/unit/unit-core
                           racket/private/unit/unit-infer
                           racket/private/unit/util
                           racket/private/unit/exptime/import-export
                           racket/private/unit/exptime/signature
                           racket/private/unit/exptime/syntax
                           racket/private/unit/exptime/unit-infer
                           racket/private/unit/exptime/util
                           contract
                           contract-syntax
                           exptime/import-export
                           exptime/signature
                           exptime/syntax
                           exptime/unit-infer
                           exptime/util
                           keywords
                           runtime
                           signature
                           unit-core
                           unit-infer
                           util
                           racket/private/serialize-structs))
              (webracket-owned-ffi-provider-name? name)))
         (cond
           [staged-io-format-report
            staged-io-format-report]
           [staged-read-report
            staged-read-report]
           [else
            (define (extract)
              ;; Provider-owned primitive aliases are a user-module boundary
              ;; routing rule. Keep installed/support provider extraction in its
              ;; ordinary world so private support modules do not grow spurious
              ;; facade dependencies like `expander/read`.
              (parameterize ([current-provider-owned-primitive-aliases (seteq)])
                (webify-module-report/rename
                 (if (eq? fetch-provider webify-module-path->report)
                     (if (or normal-export-shape?
                             webracket-owned-provider?)
                         (webify-module-path->report extraction-name)
                         (webify-module-path->report extraction-name #:namespace provider-namespace))
                     (fetch-provider extraction-name))
                 name)))
            (if (or normal-export-shape?
                    webracket-owned-provider?)
                (extract)
                (parameterize ([current-namespace provider-namespace]
                               [current-module-name-resolver provider-module-name-resolver])
                  (extract)))]) )
       (define provider-cache
         (make-webify-module-provider-cache
          (webracket/base-fetch-provider/timed fetch-provider/erased-contracts)))
       (define erased-contract-support-names
         '(racket/contract/base
           racket/contract/combinator
           racket/contract/region
           racket/in-out
           racket/module-boundary-ctc
           racket/contract/private/base
           racket/contract/private/blame
           racket/contract/private/guts
           racket/contract/private/object
           racket/contract/private/object-c-wrapper))
       (define (erased-contract-support-reports)
         (let ([report (webify-module-provider-cache-ref provider-cache
                                                         'webracket/contract)])
           (for/list ([name (in-list erased-contract-support-names)])
             (webify-module-report/rename report name))))
       (define needs-class-support?
         ;; `webracket/full` re-exports the installed `racket/class` surface, so
         ;; its graph needs the same seeded private-provider support as an
         ;; explicit `(require racket/class)` program. The same support bundle
         ;; also carries the private struct helpers that expanded local modules
         ;; can surface as phase-0 provider candidates.
         (ormap (lambda (name)
                  (memq name '(racket/class
                               racket/private/kernstruct
                               webracket/full
                               webracket/full/main)))
                external-names))
       (define have-racket/private/pico?
         (module-path-available? 'racket/private/pico))
       (define have-racket/private/reverse?
         (module-path-available? 'racket/private/reverse))
       (define needs-unit-support?
         (ormap (lambda (name)
                  (memq name '(racket/unit
                               racket/private/unit/contract
                               racket/private/unit/runtime
                               racket/private/unit/signature
                               racket/private/unit/unit-core
                               racket/private/unit/unit-infer)))
                external-names))
       (define unit-relative-provider-aliases
         '((contract . racket/private/unit/contract)
           (contract-syntax . racket/private/unit/contract-syntax)
           (exptime/import-export . racket/private/unit/exptime/import-export)
           (exptime/signature . racket/private/unit/exptime/signature)
           (exptime/syntax . racket/private/unit/exptime/syntax)
           (exptime/unit-infer . racket/private/unit/exptime/unit-infer)
           (exptime/util . racket/private/unit/exptime/util)
           (keywords . racket/private/unit/keywords)
           (runtime . racket/private/unit/runtime)
           (signature . racket/private/unit/signature)
           (unit-core . racket/private/unit/unit-core)
           (unit-infer . racket/private/unit/unit-infer)
           (util . racket/private/unit/util)))
       (define erased-contract-support-report-names
         (cons 'webracket/contract erased-contract-support-names))
       (define class-support-report-names
         (append
          '(racket/private/for
            racket/private/map
            webracket/list
            syntax/location
            racket/private/define-struct
            racket/private/kernstruct
            racket/private/serialize-structs
            racket/private/class-internal
            racket/private/class-struct
            racket/private/list)
          (if have-racket/private/pico?
              '(racket/private/pico)
              (if have-racket/private/reverse?
                  '(racket/private/reverse)
                  '()))))
       (define unit-support-report-names
         (append
          '(racket/private/unit/contract
            racket/private/unit/contract-syntax
            racket/private/unit/keywords
            racket/private/unit/runtime
            racket/private/unit/signature
            racket/private/unit/unit-core
            racket/private/unit/unit-infer
            racket/private/unit/util
            racket/promise
            racket/private/unit/exptime/import-export
            racket/private/unit/exptime/signature
            racket/private/unit/exptime/syntax
            racket/private/unit/exptime/unit-infer
            racket/private/unit/exptime/util)
          (map car unit-relative-provider-aliases)
          (map cdr unit-relative-provider-aliases)
          '(syntax/parse/private/residual/parse-util
            syntax/parse/private/residual/state
            syntax/parse/private/rep-patterns/simple)))
       (define ffi-support-report-names
         (for/list ([name (in-list external-names)]
                    #:when (webracket-owned-ffi-provider-name? name))
           name))
       (define expander-read-support-report-names
         (if needs-expander-read-support?
             (append
              (map webify-module-report-name (read-provider-reports))
              ;; The private staged reader closure reaches racket/prefab through
              ;; racket-src/expander/common/prefab.
              '(racket/prefab))
             '()))
       (define io-format-support-report-names
         (list webify-io-format-adapter-name
               webify-io-format-printf-name
               webify-io-format-root-name
               webify-io-format-map-shim-name
               'racket-src/racket/format-web
               'racket/format))
       (set! support-report-names
             (append
              (list webify-module-protocol-name
                    'webracket/contract
                    'webracket/private/sort-public
                    'webracket/private/kw
                    'racket/private/pre-base
                    'webracket/private/sort
                    'racket/private/sort
                    'webracket/unsafe/undefined
                    'racket/unsafe/undefined)
              erased-contract-support-report-names
              (if needs-class-support?
                  class-support-report-names
                  '())
              (if needs-unit-support?
                  unit-support-report-names
                  '())
              ffi-support-report-names
              expander-read-support-report-names
              io-format-support-report-names))
       (define (unit-support-reports)
         (append
          (for/list ([name (in-list '(racket/private/unit/contract
                                      racket/private/unit/contract-syntax
                                      racket/private/unit/keywords
                                      racket/private/unit/runtime
                                      racket/private/unit/signature
                                      racket/private/unit/unit-core
                                      racket/private/unit/unit-infer
                                      racket/private/unit/util
                                      racket/promise
                                      racket/private/unit/exptime/import-export
                                      racket/private/unit/exptime/signature
                                      racket/private/unit/exptime/syntax
                                      racket/private/unit/exptime/unit-infer
                                      racket/private/unit/exptime/util))])
            (webify-module-provider-cache-ref provider-cache name))
          (for/list ([alias (in-list unit-relative-provider-aliases)])
            (webify-module-report/rename
             (webify-module-provider-cache-ref provider-cache (cdr alias))
             (car alias)))
          (list
           (webify-module-report/rename
            (webify-module-path->report '(submod syntax/parse/private/residual parse-util))
            'syntax/parse/private/residual/parse-util)
           (webify-module-report/rename
           (webify-module-path->report '(submod syntax/parse/private/residual state))
           'syntax/parse/private/residual/state)
           (webify-module-report/rename
            (webify-module-path->report '(submod syntax/parse/private/rep-patterns simple))
            'syntax/parse/private/rep-patterns/simple))))
       (define registry
         (cached-discovered-provider-registry
            root
            local-source-paths
            support-report-names
            #t
            webify-module-protocol-dependency
            (lambda ()
              ;; Some resolver hints target WebRacket-owned support modules
              ;; directly; only materialize those reports when the discovered
              ;; provider graph cache itself misses.
              (define support-reports
                (append
                 (list webify-module-protocol-report
                       (webify-module-provider-cache-ref provider-cache
                                                         'webracket/contract)
                       (webify-module-provider-cache-ref provider-cache
                                                         'webracket/private/sort-public)
                       (webify-module-provider-cache-ref provider-cache
                                                         'webracket/private/kw)
                       (webify-module-provider-cache-ref provider-cache
                                                         'racket/private/pre-base)
                       (webify-module-provider-cache-ref provider-cache
                                                         'webracket/private/sort)
                       (webify-module-report/rename
                        (webify-module-provider-cache-ref provider-cache
                                                          'webracket/private/sort)
                        'racket/private/sort)
                       (webify-module-provider-cache-ref provider-cache
                                                         'webracket/unsafe/undefined)
                       (webify-module-report/rename
                        (webify-module-provider-cache-ref provider-cache
                                                          'webracket/unsafe/undefined)
                        'racket/unsafe/undefined))
                 (erased-contract-support-reports)
                 (if needs-class-support?
                     (append
                      (list (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/for)
                            (webify-module-report/rename
                             (webify-module-provider-cache-ref provider-cache
                                                               'webracket/list)
                             'racket/private/list)
                            (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/map))
                      (if have-racket/private/pico?
                          (list (webify-module-provider-cache-ref provider-cache
                                                                  'racket/private/pico))
                          (if have-racket/private/reverse?
                              (list (webify-module-provider-cache-ref provider-cache
                                                                      'racket/private/reverse))
                              '()))
                      (list (webify-module-provider-cache-ref provider-cache
                                                              'syntax/location)
                            (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/define-struct)
                            (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/kernstruct)
                            (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/serialize-structs)
                            (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/class-internal)
                            (webify-module-provider-cache-ref provider-cache
                                                              'racket/private/class-struct)))
                     '())
                 (if needs-unit-support?
                     (unit-support-reports)
                     '())
                 ;; WebRacket-owned browser/library providers are hand-authored
                 ;; modules with exported procedures that often close over private
                 ;; helpers. Until provider slicing can prove and retain those private
                 ;; closure dependencies, keep these providers unsliced.
                 (for/list ([name (in-list external-names)]
                            #:when (webracket-owned-ffi-provider-name? name))
                   (webify-module-provider-cache-ref provider-cache name))
                 (if needs-expander-read-support?
                     (append
                      (read-provider-reports)
                      ;; The private staged reader closure reaches racket/prefab
                      ;; through racket-src/expander/common/prefab.
                      (list (webify-module-provider-cache-ref provider-cache
                                                              'racket/prefab)))
                     '())
                 (io-format-provider-reports)))
              (with-module-bridge-timing
               'discover-provider-graph
               (lambda ()
                 (webify-module-reports->discovered-resolved-linklet-inputs
                  bridge-reports
                  #:extra-reports support-reports
                  #:fetch-provider (lambda (name)
                                     (unless (webify-provider-trial-module-allowed? name)
                                       (raise-arguments-error
                                        'webracket/base-reports->module-graph
                                        "#lang webracket/base transitive provider is not in the Goal 1 trial allowlist"
                                        "unsupported provider" name
                                        "allowed providers" webify-provider-trial-module-allowlist))
                                     (webify-module-provider-cache-ref provider-cache name))
                  #:skip-provider? webracket/base-language-provider-name?
                  #:module-protocol-dependency webify-module-protocol-dependency
                  #:demand-slice? #t))))))
       (provider-cache-log "#lang webracket/base provider cache: ~a hit(s), ~a miss(es)"
                           (webify-module-provider-cache-hit-count provider-cache)
                           (webify-module-provider-cache-miss-count provider-cache))
       registry]
      [else
       (set! support-report-names (list webify-module-protocol-name))
       (with-module-bridge-timing
        'final-extracted-form-assembly
        (lambda ()
          (webify-module-linklet-inputs->registry
           (cons webify-module-protocol-input
                 (webify-module-reports->resolved-linklet-inputs
                  bridge-reports
                 #:module-protocol-dependency webify-module-protocol-dependency)))))]))
  (define module-kinds
    (for/hasheq ([name (in-list (webify-module-registry-names registry))])
      (values name
              (cond
                [(memq name local-report-names) 'local-user]
                [(memq name support-report-names) 'support-provider]
                [else 'installed-provider]))))
  (webracket/base-local-module-graph bridge-root bridge-reports registry module-kinds))

;; webracket/base-file->local-module-graph : path-string? -> webracket/base-local-module-graph?
;;   Build a local root graph plus demanded provider reports for the module bridge.
(define (webracket/base-file->local-module-graph filename)
  (define resolved (simplify-path (path->complete-path filename)))
  (define cache-path (local-module-graph-cache-path resolved))
  (define cached
    (with-module-bridge-timing
     'local-module-graph-cache-lookup
     (lambda ()
       (read-local-module-graph-cache cache-path))))
  (define-values (root reports local-source-paths)
    (cond
      [cached
       (provider-cache-log "#lang webracket/base local module graph hit: ~a" resolved)
       (with-module-bridge-timing
        'local-module-graph-cache-hit
        (lambda ()
          (values (vector-ref cached 0)
                  (vector-ref cached 1)
                  (vector-ref cached 2))))]
      [else
       (provider-cache-log "#lang webracket/base local module graph miss: ~a" resolved)
       (call-with-provider-cache-lock
        cache-path
        (lambda ()
          (define cached*
            (with-module-bridge-timing
             'local-module-graph-cache-lookup
             (lambda ()
               (read-local-module-graph-cache cache-path))))
          (cond
            [cached*
             (provider-cache-log "#lang webracket/base local module graph hit: ~a" resolved)
             (with-module-bridge-timing
              'local-module-graph-cache-hit
              (lambda ()
                (values (vector-ref cached* 0)
                        (vector-ref cached* 1)
                        (vector-ref cached* 2))))]
            [else
             (define-values (root reports local-source-paths)
               (with-module-bridge-timing
                'local-module-graph-cache-miss
                (lambda ()
                  (webracket/base-file->local-module-reports resolved))))
             (write-local-module-graph-cache! cache-path
                                              root
                                              reports
                                              local-source-paths)
             (values root reports local-source-paths)])))]))
  (webracket/base-reports->module-graph
   root
   reports
   #:local-source-paths local-source-paths))

;; module-bridge-root-export-bindings : webracket/base-local-module-graph? webify-module-composition? -> (listof hash?)
;;   Collect authoritative public export bindings for the root user module.
(define (module-bridge-root-export-bindings graph composition)
  (define who 'module-bridge-root-export-bindings)
  (define root-name
    (webracket/base-local-module-graph-root graph))
  (define root-instance
    (hash-ref (webify-module-composition-instances composition)
              root-name
              (lambda ()
                (raise-arguments-error who
                                       "composition is missing the root module instance"
                                       "root" root-name
                                       "available instances"
                                       (hash-keys
                                        (webify-module-composition-instances composition))))))
  (for/list ([export-name (in-list (webify-module-instance-exports root-instance))])
    (define entry
      (webify-module-instance-export-entry root-instance export-name))
    (define meta
      (bridge-export-entry-metadata entry))
    (hasheq 'name export-name
            'binding-kind (bridge-export-entry-kind entry)
            'binding-id (bridge-export-entry-binding entry)
            'mutable? (and (hash-ref meta 'mutated? #f) #t))))

;; module-file->module-bridge-top-level : path-string? -> syntax?
;;   Compose a local #lang webracket/base graph through module instances.
;;   `module-bridge-extract` covers this exact path:
;;   `module-file->module-bridge-top-level`
;;    -> `webracket/base-file->local-module-graph`
;;    -> `webracket/base-file->local-module-reports`
;;    -> `compile-webracket/base-module-file-report`
;;    -> `webracket/base-reports->module-graph`.
(define (module-file->module-bridge-top-level filename)
  (define resolved-filename
    (path->string (simplify-path (path->complete-path filename))))
  (define graph
    (with-driver-timing
     'module-bridge-extract
     (lambda ()
       (with-handlers ([exn:fail?
                        (lambda (e)
                         (raise-arguments-error
                           'read-top-level-from-file
                           "#lang webracket/base module bridge graph extraction failed"
                           "file" filename
                           "message" (exn-message e)))])
         (webracket/base-file->local-module-graph filename)))))
  (current-source-module-provider-names
   (module-reports->provider-names (webracket/base-local-module-graph-reports graph)))
  (current-module-bridge-module-kinds
   (webracket/base-local-module-graph-module-kinds graph))
  (current-module-bridge-elidable-module-names
   (bridge-module-elidable-public-modules graph))
  (define composition
    (with-driver-timing
     'module-bridge-compose
     (lambda ()
       (with-handlers ([exn:fail?
                        (lambda (e)
                          (raise-arguments-error
                           'read-top-level-from-file
                           "#lang webracket/base module bridge composition failed"
                           "root" (webracket/base-local-module-graph-root graph)
                           "message" (exn-message e)))])
         (parameterize ([current-composer-primitive-import-cell-overrides
                         (module-composer-primitive-overrides)])
           (webify-compose-module-registry/roots/composition
            (webracket/base-local-module-graph-registry graph)
            (list (webracket/base-local-module-graph-root graph))
            #:define-export-aliases? #f
            #:serializable?-box     #f
            #:datum-intern?         #f
            #:target                #f
            #:allow-set!-undefined? #f
            #:unsafe-mode?          #f
            #:enforce-constant?     #t
            #:allow-inline?         #t
            #:no-prompt?            #f
            #:prim-knowns           (hasheq)
            #:primitives            (hasheq)
            #:compiler-query        (lambda (v) #f)
            #:get-import-knowns     (lambda (key) (values #f #f #f))
            #:import-keys           #f))))))
  (current-console-bridge-root-export-bindings
   (module-bridge-root-export-bindings graph composition))
  (current-console-bridge-root-source-path resolved-filename)
  (hash-set! (current-webify-bridge-stats)
             'module-bridge-metric-rows
             (module-bridge-graph-metric-rows graph composition))
  (define bridge-datum
    (webify-module-composition-datum composition))
  (current-module-bridge-needs-regexp-provider?
   (module-bridge-datum-needs-regexp-provider? bridge-datum))
  (datum->syntax
   #f
   (webify-module-composition-with-tail composition '((void)))))

;; module-file->module-bridge-top-level/local-only : path-string? -> (or/c syntax? #f)
;;   Use the default bridge only for local or explicitly staged provider graphs.
(define (module-file->module-bridge-top-level/local-only filename)
  (define resolved-filename
    (path->string (simplify-path (path->complete-path filename))))
  (define-values (root reports _local-source-paths)
    (with-driver-timing
     'module-bridge-extract
     (lambda ()
       (webracket/base-file->local-module-reports filename))))
  (define external-names (webracket/base-external-provider-names reports))
  (current-console-bridge-root-export-bindings #f)
  (current-console-bridge-root-source-path #f)
  (current-module-bridge-elidable-module-names #f)
  (define (compose)
    (let ([graph
           (with-driver-timing
            'module-bridge-register
            (lambda ()
              (webracket/base-reports->module-graph root reports)))])
      (current-module-bridge-module-kinds
       (webracket/base-local-module-graph-module-kinds graph))
      (current-module-bridge-elidable-module-names
       (bridge-module-elidable-public-modules graph))
      (define composition
        (with-driver-timing
         'module-bridge-compose
         (lambda ()
           (parameterize ([current-composer-primitive-import-cell-overrides
                           (module-composer-primitive-overrides)])
             (webify-compose-module-registry/roots/composition
              (webracket/base-local-module-graph-registry graph)
              (list (webracket/base-local-module-graph-root graph))
              #:define-export-aliases? #f
              #:serializable?-box     #f
              #:datum-intern?         #f
              #:target                #f
              #:allow-set!-undefined? #f
              #:unsafe-mode?          #f
              #:enforce-constant?     #t
              #:allow-inline?         #t
              #:no-prompt?            #f
              #:prim-knowns           (hasheq)
              #:primitives            (hasheq)
              #:compiler-query        (lambda (v) #f)
              #:get-import-knowns     (lambda (key) (values #f #f #f))
              #:import-keys           #f)))))
      (current-console-bridge-root-export-bindings
       (module-bridge-root-export-bindings graph composition))
      (current-console-bridge-root-source-path resolved-filename)
      (hash-set! (current-webify-bridge-stats)
                 'module-bridge-metric-rows
                 (module-bridge-graph-metric-rows graph composition))
      (datum->syntax
       #f
       (webify-module-composition-with-tail composition '((void))))))
  (and (andmap webify-provider-trial-default-bridge-module-allowed?
               external-names)
       (cond
         [(null? external-names)
          (with-handlers ([exn:fail? (lambda (_exn) #f)])
            (compose))]
         [else
          (compose)])))

;; module-form->top-level : syntax? -> syntax?
;;   Transitional helper for tests that already have a module syntax object.
(define (module-form->top-level stx)
  (define-values (module-name body) (module-stx->name+body stx))
  (define exports (append-map simple-provide-exports body))
  (define top-level-forms
    (filter (lambda (form)
              (not (and (pair? form)
                        (memq (car form) '(provide module+ require)))))
            body))
  (define export-forms
    (for/list ([export (in-list exports)])
      (define cell (module-export-cell-symbol module-name export))
      `(begin
         (define ,cell (module-variable-make ',export))
         (module-variable-define! ,cell ,export 'constant))))
  (datum->syntax stx `(begin ,@top-level-forms ,@export-forms) stx))

(define (read-top-level-from-file filename
                                  #:webracket-module-bridge?
                                  [webracket-module-bridge? #f])
  (current-read-source-timing-rows '())
  (current-module-bridge-detail-rows '())
  (current-webify-bridge-stats (make-hash))
  (current-source-module-language #f)
  (define first-line
    (call-with-input-file filename
      (λ (port)
        (read-line port 'any))))
  (define starts-with-webracket-lang?
    (webracket-script-lang-line? first-line))
  (define starts-with-webracket/base-lang?
    (webracket-module-lang-line? first-line))
  (define (read-forms port)
    (let loop ([forms '()])
      (define stx (read-syntax filename port))
      (if (eof-object? stx)
          (reverse forms)
          (loop (cons stx forms)))))
  (call-with-input-file filename
    (λ (port)
      (port-count-lines! port)
      (with-module-reading-parameterization
        (λ ()
          ;; `webracket.rkt` compiles script-style top-level programs. A source
          ;; that starts with `#lang webracket` uses the same body language, so
          ;; skip the language line here instead of asking Racket to resolve the
          ;; checkout as an installed `webracket/lang/reader` collection.
          (cond
            [starts-with-webracket-lang?
             (current-source-module-language #f)
             (void (read-line port 'any))
             (define forms (read-forms port))
             (datum->syntax #f `(begin ,@forms))]
            [starts-with-webracket/base-lang?
             (current-source-module-language
              (webracket-module-lang-line->language first-line))
             (with-webracket-sequence-prelude
              (module-file->module-bridge-top-level filename))]
            [else
             (current-source-module-language #f)
             (define forms (read-forms port))
             (datum->syntax #f `(begin ,@forms))]))))))

;;;
;;; WRITE WAT TO FILE
;;;

(define (write-wat-to-file out-filename wat #:pretty? [pretty? #t])
  (define wat-string
    (with-output-to-string
      (λ ()
        (if pretty?
            (pretty-write wat)
            (write wat)))))
  (with-output-to-file out-filename
    (λ ()
      (displayln ";; This file was generated by `webracket`.")
      (display (rewrite-wat-identifiers wat-string)))
    #:exists 'replace))

;;;
;;; PREFLIGHT CHECK TOOLS
;;;

(define (ensure-source-file! who filename)
  (cond
    [(directory-exists? filename)
     (error who (~a "expected a source file, got directory: " filename))]
    [(not (file-exists? filename))
     (error who (~a "file not found: " filename))]))

(define (ensure-generated-file-exists! who path kind)
  (unless (file-exists? path)
    (error who (~a kind " was not created: " path))))

(define (ensure-output-path-writable! who output-path kind)
  (when (directory-exists? output-path)
    (error who
           (~a "cannot write " kind ": " output-path
               "\n" "target path is an existing directory")))
  (define dir (or (path-only output-path) (current-directory)))
  (with-handlers ([exn:fail:filesystem?
                   (λ (e)
                     (error who
                            (~a "cannot prepare directory for " kind ": " dir
                                "\n" (exn-message e))))])
    (make-directory* dir))
  (define probe #f)
  (with-handlers ([exn:fail:filesystem?
                   (λ (e)
                     (when (and probe (file-exists? probe))
                       (with-handlers ([exn:fail:filesystem? void])
                         (delete-file probe)))
                     (error who
                            (~a "cannot write " kind ": " output-path
                                "\n" (exn-message e))))])
    (set! probe (make-temporary-file "webracket-write-check~a.tmp" #f dir))
    (delete-file probe)))

(define (check-node! who)
  (define node-path (find-executable-path "node"))
  (unless node-path
    (error who
           (string-append
            "required executable `node` was not found in PATH.\n"
            "Install Node.js or run without `-r`.")))
  (define node-ok?
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      (system* node-path "--version")))
  (unless node-ok?
    (error who
           (string-append
            "found `node` in PATH but could not run `node --version`.\n"
            "Check the installation and executable permissions.")))
  (define wasm-exnref-flag-ok?
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      (system* node-path "--experimental-wasm-exnref" "-e" "")))
  (unless wasm-exnref-flag-ok?
    (error who
           (string-append
            "found `node`, but it does not accept `--experimental-wasm-exnref`.\n"
            "Install a compatible Node.js version or run without `-r`."))))

(define (ensure-distinct-output-files! who entries)
  (define seen (make-hash))
  (for ([entry entries])
    (define kind          (car entry))
    (define path          (cdr entry))
    (define normalized    (path->complete-path path (current-directory)))
    (define previous-kind (hash-ref seen normalized #f))
    (when previous-kind
      (error who
             (~a "output file collision: " previous-kind " and "
                 kind " resolve to the same path: " path)))
    (hash-set! seen normalized kind)))

(define (check-wasm-tools! who)
  (define wasm-tools-path (find-executable-path "wasm-tools"))
  (unless wasm-tools-path
    (error who
           (string-append
            "required executable `wasm-tools` was not found in PATH.\n"
            "Install `wasm-tools` to compile `.wat` files to `.wasm`.")))
  (define parse-help-ok?
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      (system* wasm-tools-path "parse" "--help")))
  (unless parse-help-ok?
    (error who
           (string-append
            "found `wasm-tools` in PATH but could not run `wasm-tools parse --help`.\n"
            "Check the installation and executable permissions."))))

;;;
;;; READ MODULE
;;;

(define (read-lang-module port)
  (port-count-lines! port)
  ; Reset all reader parameters to default values.
  (with-module-reading-parameterization 
    (lambda ()
      (read-syntax (object-name port) port))))

; read-lang-file : path-string -> syntax
;   Read the program in `path-string`.
;   Return a syntax object representing a module.
(define (read-lang-file path-string)
  (call-with-input-file path-string
    (λ (port)
      (parameterize ([current-directory (or (path-only path-string)
                                            (current-directory))])
        (read-lang-module port)))))

;;;
;;; EXPAND MODULE
;;;

(require "expander.rkt") ; provides `topexpand`

;;;
;;; EXPAND FILE
;;;

; Note: The following procedure is modelled after:
;    racket/collects/compiler/compile-file.rkt
; It uses `dynamic-wind` to handle errors (removing temporary files etc.).
; With an eye towards bootstrapping, we postpone using `dynamic-wind`.

(define (expand-file src-path
                     [dest-path
                      (let-values ([(base name dir?) (split-path src-path)])
                        (build-path base "expanded"
                                    (path-add-suffix name #".erkt")))])
  ; create .../expanded/ if needed
  (make-directory* (path-only dest-path))

  ; We write to a temporary file and only move it to `dest-path`
  ; only if we encounter no errors.
  (define temp-filename (make-temporary-file "tmp~a" #f (path-only dest-path)))

  (define dir
    (let-values ([(base name dir?) (split-path src-path)])
      (if (eq? base 'relative)
          (current-directory)
          (path->complete-path base (current-directory)))))

  (define out (open-output-file temp-filename #:exists 'truncate/replace))

  (parameterize ([current-load-relative-directory dir]
                 [current-write-relative-directory dir])
    (define program (read-lang-file src-path))
    (pretty-write (syntax->datum
                   (topexpand program))
                   out))
  
  (close-output-port out)

  (rename-file-or-directory temp-filename dest-path #t) ; exists-ok? = #t

  (with-handlers ([exn:fail:filesystem? void])
    (delete-file temp-filename)))

;;;
;;; RESOLUTION OF FFI-PATHS
;;;


(define-runtime-path system-ffi-directory "ffi")

(define (resolve-ffi-filename ffi-filename)
  (define filename
    (if (path-get-extension ffi-filename)
        ffi-filename
        (path-add-extension ffi-filename ".ffi")))
  
  (define candidates
    (if (absolute-path? filename)
        (list filename)
        (append (list filename
                      (build-path "ffi" filename))
                (if system-ffi-directory
                    (list (build-path system-ffi-directory filename))
                    '()))))
  (for/or ([candidate (in-list candidates)])
    (and candidate
         (file-exists? candidate)
         (path->complete-path candidate (current-directory)))))
