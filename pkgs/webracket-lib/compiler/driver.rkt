#lang racket/base
;;;        
;;; DRIVER 
;;;        

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
         (struct-out compilation-timings)
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
         (only-in racket/system     system*)
         #;(only-in "lang/reader.rkt" read-syntax)
         (only-in "assembler.rkt"
                  run
                  wat->wasm
                  runtime)
         (only-in racket/list       append* append-map remove-duplicates)
         (only-in racket/match      match)
         setup/dirs
         (only-in "private/parameters.rkt"  current-ffi-foreigns
                                    current-ffi-imports-wat
                                    current-ffi-funcs-wat
                                    current-browser?
                                    current-enable-cc-analysis?
                                    current-console-bridge?
                                    current-enable-simplify?
                                    current-letrec-strategy
                                    current-tree-shake?
                                    current-runtime-primitive-report-path)
         (only-in "private/timings.rkt"
                  now-ms
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
                  webify-regexp-export-symbols
                  webify-regexp-lowered-provider-cache-path
                  webify-regexp-linklet
                  webify-regexp-public-alias-forms
                  webify-regexp-source-fingerprint)
         (only-in "webify/read-provider.rkt"
                  webify-read-export-symbols
                  webify-read-linklet
                  webify-read-lowered-provider-cache-path
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
                  first-slice-top-level-export-cell-ids
                  webify-linklet-first-slice-top-level)
         (only-in "webify/module-registry.rkt"
                  webify-compose-module-registry/roots/composition
                  webify-module-composition-with-tail)
         (only-in "webify/module-input.rkt"
                  webify-module-linklet-inputs->registry)
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
                  webify-module-report-notes
                  webify-module-report-phase0-exports
                  webify-module-report-phase0-imports
                  webify-module-report-phase0-linklet-datum
                  webify-module-report-required-provider-names
                  webify-module-reports->resolved-linklet-inputs)
         (only-in "webify/module-protocol.rkt"
                  webify-module-protocol-input
                  webify-module-protocol-report
                  webify-module-protocol-dependency)
         (only-in "webify/provider-trials.rkt"
                  webify-provider-trial-default-bridge-module-allowed?
                  webify-provider-trial-module-allowed?
                  webify-provider-trial-module-allowlist)
         (only-in "webify/ffi-module-registry.rkt"
                  module-provider->ffi-filename)
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
  (define-values (_root reports)
    (webracket/base-file->local-module-reports filename))
  (define provider-names
    (remove-duplicates
     (append (map webify-module-report-name reports)
             (append-map webify-module-report-required-provider-names reports))
     eq?))
  (for/list ([provider-name (in-list provider-names)]
             #:do [(define ffi-filename
                     (module-provider->ffi-filename provider-name))]
             #:when ffi-filename
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

(define current-source-module-language
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

;; provider-report->cache-datum : webify-module-report? -> datum?
;;   Serialize provider reports without relying on reader-visible struct types.
(define (provider-bundle-entry->cache-datum entry)
  `(bundle-entry
    ,(webify-module-bundle-entry-key entry)
    ,(webify-module-bundle-entry-kind entry)
    ,(webify-module-bundle-entry-imports entry)
    ,(webify-module-bundle-entry-exports entry)
    ,(webify-module-bundle-entry-datum entry)
    ,(webify-module-bundle-entry-value entry)))

(define (cache-datum->provider-bundle-entry datum)
  (match datum
    [`(bundle-entry ,key ,kind ,imports ,exports ,entry-datum ,value)
     (webify-module-bundle-entry key kind imports exports entry-datum value)]
    [_ #f]))

(define (provider-report->cache-datum report)
  `(provider-report
    ,(webify-module-report-name report)
    ,(webify-module-report-directory-keys report)
    ,(webify-module-report-bundle-keys report)
    ,(map provider-bundle-entry->cache-datum
          (webify-module-report-bundle-entries report))
    ,(webify-module-report-phase0-imports report)
    ,(webify-module-report-phase0-exports report)
    ,(webify-module-report-phase0-linklet-datum report)
    ,(webify-module-report-manifest-ready? report)
    ,(webify-module-report-notes report)))

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
                           phase0-imports
                           phase0-exports
                           phase0-linklet-datum
                           manifest-ready?
                           notes))]
    [else #f]))

;; cached-installed-provider-report : symbol? (symbol? -> report?) -> report?
;;   Reuse extracted installed-provider reports across driver runs.
(define (cached-installed-provider-report name fetch-provider)
  (define cache-path
    (provider-cache-path
     "installed-provider-reports"
     (string-append (provider-cache-symbol-segment name) ".rktd")))
  (define fingerprint
    `(installed-provider-report-cache 6 ,name ,(version)))
  (define cached (read-provider-cache cache-path fingerprint))
  (cond
    [cached
     (provider-cache-log "installed provider report hit: ~a" name)
     (or (cache-datum->provider-report cached)
         (let ()
           (provider-cache-log "installed provider report cache unreadable; extracting: ~a" name)
           (define report (fetch-provider name))
           (write-provider-cache! cache-path
                                  fingerprint
                                  (provider-report->cache-datum report))
           report))]
    [else
     (provider-cache-log "installed provider report miss; extracting: ~a" name)
     (define report (fetch-provider name))
     (write-provider-cache! cache-path fingerprint (provider-report->cache-datum report))
     report]))

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
  (ffi-setup
   read-source
   add-stdlib
   preflight
   compile
   write-wat
   assemble
   write-map
   write-host
   compile-total
   run
   driver-total)
  #:transparent)


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

  (current-browser? browser?)
  (current-enable-cc-analysis? enable-cc-analysis?)
  (current-console-bridge? console-bridge?)
  (current-tree-shake? tree-shake?)
  (current-runtime-primitive-report-path tree-shake-report)
  (set-browser-mode! browser?)
  (define provider-cache-path
    (let ([p (if (path? provider-cache-dir)
                 provider-cache-dir
                 (string->path provider-cache-dir))])
      (path->complete-path p)))
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

  ; 0. Check that `filename` exists and is a source file.
  (ensure-source-file! 'drive-compilation filename)

  ; 1. Read the top-level forms from `filename`.
  (define t-read-source-start (now-ms))
  (define stx
    (with-handlers ([exn:fail? (λ (e)
                                 (error 'drive-compilation
                                        (~a "read failed: " (exn-message e))))])
      (read-top-level-from-file
       filename
       #:webracket-module-bridge? webracket-module-bridge?)))
  (define t-read-source-end (now-ms))
  (define stx-for-compile
    (if print-top-level-results?
        (add-print-top-level-results-sentinel stx)
        stx))

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
       (when (and verbose?
                  (or stdlib?
                      stdlib-io-format-provider?
                      expander-read-provider?
                      expander-read-syntax-provider?))
         (displayln
          "Skipping temporary stdlib root for module-language input; composing provider slices only"
          (current-error-port)))
       (cond
         [stdlib-io-format-provider?
          (add-io-format-provider stx-for-compile
                                  #:expander-read-provider? expander-read-provider?
                                  #:expander-read-syntax-provider? expander-read-syntax-provider?)]
         [expander-read-provider?
          (add-expander-read-provider stx-for-compile
                                      #:expander-read-syntax-provider?
                                      expander-read-syntax-provider?)]
         [expander-read-syntax-provider?
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
          (add-regexp-provider stx-for-compile)])]
      [(and stdlib? browser?)
       (when verbose?
         (displayln "Composing module stdlib root `legacy-stdlib/stdlib-for-browser.rkt`"
                    (current-error-port)))
       (add-module-stdlib stx-for-compile
                           #t
                           #:io-format-provider? stdlib-io-format-provider?
                           #:expander-read-provider? expander-read-provider?
                           #:expander-read-syntax-provider? expander-read-syntax-provider?)]
      [stdlib?
       (when verbose?
         (displayln "Composing module stdlib root `legacy-stdlib/stdlib.rkt`"
                    (current-error-port)))
       (add-module-stdlib stx-for-compile
                           #f
                           #:io-format-provider? stdlib-io-format-provider?
                           #:expander-read-provider? expander-read-provider?
                           #:expander-read-syntax-provider? expander-read-syntax-provider?)]
      [stdlib-io-format-provider?
       (when verbose?
         (displayln "Composing module stdlib-free `io/format` provider"
                    (current-error-port)))
       (add-io-format-provider stx-for-compile
                               #:expander-read-provider? expander-read-provider?
                               #:expander-read-syntax-provider? expander-read-syntax-provider?)]
      [expander-read-provider?
       (when verbose?
         (displayln "Composing module stdlib-free `expander/read` provider"
                    (current-error-port)))
       (add-expander-read-provider stx-for-compile
                                   #:expander-read-syntax-provider?
                                   expander-read-syntax-provider?)]
      [expander-read-syntax-provider?
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
  (define t-compile-start (now-ms))
  (define provider-owned-primitive-aliases
    (provider-owned-primitive-alias-symbols
     #:expander-read-provider? expander-read-provider?
     #:io-format-provider? stdlib-io-format-provider?))
  (define wat
    (with-handlers (#;[exn:fail? (λ (e)
                                 (error 'drive-compilation
                                        (~a "compile failed: " (exn-message e))))])
      (parameterize ([current-browser? browser?]
                     [current-enable-cc-analysis? enable-cc-analysis?]
                     [current-letrec-strategy letrec-strategy]
                     [current-enable-simplify? enable-simplify?]
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
  (with-output-to-file out-host
    (λ () (displayln
           (runtime #:out out-wasm
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
    (when (pair? read-detail-rows)
      (displayln "=== Read Source Details ===")
      (displayln (format-timing-table read-detail-rows)))
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
     (call-with-input-file filename
       (lambda (port)
         (port-count-lines! port)
         (with-module-reading-parameterization
           (lambda ()
             (ensure-webracket/module-reader! language)
             (read-syntax filename port))))))))

;; read-webracket/base-module : path-string? -> syntax?
;;   Compatibility wrapper for WebRacket module readers.
(define (read-webracket/base-module filename)
  (webracket/base-substitute-module-requires
   (read-webracket/module filename (webracket-module-source-language filename))))

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
  (datum->syntax stx rewritten stx))

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

(struct webracket/base-local-module-graph (root reports registry)
  #:transparent)

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
;;   Compile one module file while resolving relative requires from its directory.
(define (compile-webracket/base-module-file-report filename
                                                  #:namespace [namespace (make-base-namespace)]
                                                  #:module-name-resolver [module-name-resolver (current-module-name-resolver)])
  (define resolved (simplify-path (path->complete-path filename)))
  (parameterize ([current-directory (or (path-only resolved)
                                        (current-directory))])
    (define module-datum (syntax->datum (read-webracket/base-module resolved)))
    ;; Read with the normal resolver so #lang webracket/base itself is found,
    ;; then compile with the erased-contract resolver for provider imports.
    (provider-cache-log "#lang webracket/base local compile start: ~a" resolved)
    (webify-compile-module-report
     module-datum
     #:namespace namespace
     #:module-name-resolver module-name-resolver)))

;; webracket/base-file->local-module-graph : path-string? -> webracket/base-local-module-graph?
;;   Extract local module reports for the module bridge path.
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
    (for ([name (in-list (module-datum-direct-require-symbols module-datum))]
          #:unless (webracket/base-language-provider-name? name)
          #:unless (webracket-owned-module-name? name)
          #:when (provider-compile-stub-safe? name)
          #:when (webify-provider-trial-module-allowed? name))
      (define substitute-name (webracket/base-provider-substitute name))
      (unless (memq name compile-stub-names)
        (provider-cache-log "#lang webracket/base compile stub install: ~a via ~a"
                            name
                            substitute-name)
        (define report
          (parameterize ([current-namespace provider-namespace]
                         [current-module-name-resolver provider-module-name-resolver])
            (webify-module-path->report substitute-name
                                        #:namespace provider-namespace)))
        (define public-exports
          (provider-public-export-symbols
           name
           (make-webify-contract-erasing-namespace)
           provider-module-name-resolver))
        (declare-provider-compile-stub!
         extraction-namespace
         name
         (append public-exports
                 (webify-module-report-phase0-exports report)))
        (set! compile-stub-names (cons name compile-stub-names)))))
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
       (define module-datum (syntax->datum (read-webracket/base-module resolved)))
       (install-compile-stubs! module-datum)
       (define report
         (compile-webracket/base-module-file-report
          resolved
          #:namespace extraction-namespace
          #:module-name-resolver module-name-resolver*))
       (define module-name (webify-module-report-name report))
       (for ([dep-path (in-list (webracket/base-report-local-dependency-paths
                                 report
                                 source-dir))])
         (visit dep-path))
       (set! reports (append reports (list report)))
       (hash-remove! visiting resolved)
       (hash-set! permanent resolved module-name)
       module-name]))
  (define root (visit filename))
  (values root reports))

;; webracket/base-language-provider-name? : symbol? -> boolean?
;;   Recognize providers that are part of the #lang webracket/base language root.
(define (webracket/base-language-provider-name? name)
  (memq name
        '(webracket/base/main
          webracket/base
          webracket/full/main
          webracket/full
          webracket/js/main
          webracket/js
          webracket/core
          webracket/primitives
          ;; Some host-expanded source can still report legacy relative names.
          ;; Treat them as language-root providers while the bridge normalizes
          ;; installed and package-local module paths.
          base/main
          base
          full/main
          full
          js/main
          js
          core
          primitives
          fully
          browser-options
          racket/base
          racket/private/base
          racket/private/pre-base
          racket/private/modbeg)))

;; webracket/base-reports-demand-external-providers? : (listof webify-module-report?) -> boolean?
;;   Check whether a bridge graph needs installed-provider discovery.
(define (webracket/base-reports-demand-external-providers? reports)
  (pair? (webracket/base-external-provider-names reports)))

;; webracket/base-external-provider-names : (listof webify-module-report?) -> (listof symbol?)
;;   List required providers outside local reports and the language root.
(define (webracket/base-external-provider-names reports)
  (define local-provider-names (map webify-module-report-name reports))
  (remove-duplicates
   (for*/list ([report (in-list reports)]
               [name (in-list (webify-module-report-required-provider-names report))]
               #:unless (or (memq name local-provider-names)
                            (webracket/base-language-provider-name? name)))
     name)
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

;; webracket/base-reports->module-graph : symbol? reports keyword-args -> graph
;;   Build a bridge graph from already-extracted reports.
(define (webracket/base-reports->module-graph root
                                             reports
                                             #:fetch-provider
                                             [fetch-provider webify-module-path->report])
  (define registry
    (cond
     [(webracket/base-reports-demand-external-providers? reports)
       (webracket/base-check-external-provider-allowlist! reports)
       (define external-names (webracket/base-external-provider-names reports))
       (define provider-namespace (make-webify-contract-erasing-namespace))
       (define provider-module-name-resolver
         (make-webify-contract-erasing-module-name-resolver))
       (define (fetch-provider/erased-contracts name)
         (define substitute-name (webracket/base-provider-substitute name))
         (define extraction-name
           (if (webracket/base-erased-contract-provider-name? name)
               'webracket/contract
               substitute-name))
         (define normal-export-shape?
           ;; The root module is expanded by normal Racket, so contracted
           ;; public providers must keep their generated provide/contract
           ;; export names while their contract implementation dependencies
           ;; remain eligible for erased-provider routing.
           (memq name '(racket/dict
                        racket/private/for
                        racket/private/map
                        racket/private/define-struct
                        racket/private/class-internal
                        racket/private/class-struct
                        racket/private/serialize-structs)))
         (define (extract)
           (webify-module-report/rename
            (if (eq? fetch-provider webify-module-path->report)
                (if normal-export-shape?
                    (webify-module-path->report extraction-name)
                    (webify-module-path->report extraction-name #:namespace provider-namespace))
                (fetch-provider extraction-name))
            name))
         (if normal-export-shape?
             (extract)
             (parameterize ([current-namespace provider-namespace]
                            [current-module-name-resolver provider-module-name-resolver])
               (extract))))
       (define provider-cache
         (make-webify-module-provider-cache
          (webracket/base-fetch-provider/timed fetch-provider/erased-contracts)))
       ;; Some resolver hints target WebRacket-owned support modules directly;
       ;; include those reports even when the installed provider graph only
       ;; names the original Racket module.
       (define support-reports
         (append
          (list webify-module-protocol-report
                (webify-module-provider-cache-ref provider-cache
                                                  'webracket/contract)
                (webify-module-provider-cache-ref provider-cache
                                                  'webracket/private/kw)
                (webify-module-provider-cache-ref provider-cache
                                                  'webracket/unsafe/undefined))
          (if (memq 'racket/class external-names)
              (list (webify-module-provider-cache-ref provider-cache
                                                      'racket/private/for)
                    (webify-module-provider-cache-ref provider-cache
                                                      'racket/private/map)
                    (webify-module-provider-cache-ref provider-cache
                                                      'webracket/list)
                    (webify-module-provider-cache-ref provider-cache
                                                      'racket/private/define-struct)
                    (webify-module-provider-cache-ref provider-cache
                                                      'racket/private/serialize-structs)
                    (webify-module-provider-cache-ref provider-cache
                                                      'racket/private/class-internal)
                    (webify-module-provider-cache-ref provider-cache
                                                      'racket/private/class-struct))
              '())
          (io-format-provider-reports)))
       (define registry
         (webify-module-reports->discovered-registry
          reports
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
          #:demand-slice? #t))
       (provider-cache-log "#lang webracket/base provider cache: ~a hit(s), ~a miss(es)"
                           (webify-module-provider-cache-hit-count provider-cache)
                           (webify-module-provider-cache-miss-count provider-cache))
       registry]
      [else
       (webify-module-linklet-inputs->registry
        (cons webify-module-protocol-input
              (webify-module-reports->resolved-linklet-inputs
               reports
               #:module-protocol-dependency webify-module-protocol-dependency)))]))
  (webracket/base-local-module-graph root reports registry))

;; webracket/base-file->local-module-graph : path-string? -> webracket/base-local-module-graph?
;;   Build a local root graph plus demanded provider reports for the module bridge.
(define (webracket/base-file->local-module-graph filename)
  (define-values (root reports)
    (webracket/base-file->local-module-reports filename))
  (webracket/base-reports->module-graph root reports))

;; module-file->module-bridge-top-level : path-string? -> syntax?
;;   Compose a local #lang webracket/base graph through module instances.
(define (module-file->module-bridge-top-level filename)
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
  (datum->syntax
   #f
   (webify-module-composition-with-tail composition '((void)))))

;; module-file->module-bridge-top-level/local-only : path-string? -> (or/c syntax? #f)
;;   Use the default bridge only for local or explicitly staged provider graphs.
(define (module-file->module-bridge-top-level/local-only filename)
  (define-values (root reports)
    (with-driver-timing
     'module-bridge-extract
     (lambda ()
       (webracket/base-file->local-module-reports filename))))
  (define external-names (webracket/base-external-provider-names reports))
  (define (compose)
    (let ([graph
           (with-driver-timing
            'module-bridge-register
            (lambda ()
              (webracket/base-reports->module-graph root reports)))])
      (define composition
        (with-driver-timing
         'module-bridge-compose
         (lambda ()
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
            #:import-keys           #f))))
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
              (if webracket-module-bridge?
                  (module-file->module-bridge-top-level filename)
                  (or (module-file->module-bridge-top-level/local-only filename)
                      (module-file->top-level filename))))]
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
