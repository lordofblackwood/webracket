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
                                    make-directory*
                                    make-temporary-file)
         (only-in racket/port       open-output-nowhere with-output-to-string)
         (only-in racket/pretty     pretty-write)
         (only-in racket/format     ~a)
         (only-in racket/system     system*)
         #;(only-in "lang/reader.rkt" read-syntax)
         (only-in "assembler.rkt"   run wat->wasm runtime)
         (only-in racket/list       append* append-map remove-duplicates)
         (only-in racket/match      match)
         setup/dirs
         (only-in "parameters.rkt"  current-ffi-foreigns
                                    current-ffi-imports-wat
                                    current-ffi-funcs-wat
                                    current-browser?
                                    current-enable-cc-analysis?
                                    current-console-bridge?
                                    current-enable-simplify?
                                    current-letrec-strategy
                                    current-tree-shake?
                                    current-runtime-primitive-report-path)
         (only-in "timings.rkt"     now-ms format-timing-table)
         "wat-identifiers.rkt"
         racket/runtime-path
         racket/syntax
         "browser-options.rkt"
         (only-in "stdlib/module-exports.rkt"
                  stdlib-module-alias-symbols
                  stdlib-module-private-forms+bindings
                  stdlib-definition-form-symbols)
         (only-in "webify/io-format-bridge.rkt"
                  webify-io-format-root-name
                  webify-io-format-export-symbols
                  webify-io-format-registry
                  webify-io-format-private-alias-forms
                  webify-io-format-public-alias-forms)
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
         "compiler.rkt"
         "define-foreign.rkt")

(define-runtime-path webracket-root ".")

(define webracket-collection-parent
  (simplify-path (build-path webracket-root "..")))

;; call-with-webracket-collection-path : (-> any/c) -> any/c
;;   Make this checkout visible as collection `webracket` while reading #lang modules.
(define (call-with-webracket-collection-path thunk)
  (parameterize ([current-library-collection-paths
                  (cons webracket-collection-parent
                        (current-library-collection-paths))])
    (thunk)))

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

;; default-ffi-files : boolean? -> (listof path-string?)
;;   Return the bundled FFI files enabled by default for the target.
(define (default-ffi-files browser?)
  (if browser?
      (list "standard.ffi" "dom.ffi")
      (list "standard.ffi")))

;; merged-ffi-files : symbol? boolean? (listof path-string?) [syntax?] -> (listof path?)
;;   Resolve and deduplicate default, explicit, and inferred ffi files.
;;     explicit: from the command line
;;     inferred: from include-lib
(define (merged-ffi-files who browser? ffi-files [stx #f])
  (define resolved-base-ffi-files
    (remove-duplicates
     (resolve-ffi-files! who
                         (append (default-ffi-files browser?)
                                 ffi-files))))
  (define inferred-ffi-files
    (if stx
        (source->inferred-ffi-files stx resolved-base-ffi-files)
        '()))
  (remove-duplicates
   (resolve-ffi-files! who
                       (append resolved-base-ffi-files
                               inferred-ffi-files))))

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

;; provider-cache-path : path-string? ... -> path?
;;   Build a cache path under the active provider cache directory.
(define (provider-cache-path . elems)
  (apply build-path (current-provider-cache-dir) elems))

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

;; provider-cache-log : string? any/c ... -> void?
;;   Print provider cache diagnostics in verbose mode.
(define (provider-cache-log fmt . args)
  (when (current-provider-cache-verbose?)
    (apply fprintf (current-error-port)
           (string-append "provider-cache: " fmt "\n")
           args)))

;; io-format-source-fingerprint : -> any/c
;;   Fingerprint the staged io/format provider inputs.
(define (io-format-source-fingerprint)
  (path-fingerprint
   'io-format-provider-cache
   1
   (cons (build-path webracket-root "webify/io-format-bridge.rkt")
         (find-files file-exists? (build-path webracket-root "racket-src/io")))))

;; provider-slice-forms : symbol? #:public-aliases? boolean? -> (listof datum?)
;;   Compose a provider slice and expose export cells, optionally publishing
;;   public top-level aliases.
(define (provider-slice-forms name #:public-aliases? [public-aliases? #f])
  (case name
    [(io/format)
     (io-format-provider-forms #:public-aliases? public-aliases?)]
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
     forms]))

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
    (filter (λ (binding) (hash-ref alias-set (car binding) #f))
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
         ;; Provider Cache
         #:provider-cache-dir [provider-cache-dir webify-regexp-default-cache-root]
         #:clear-provider-cache? [clear-provider-cache? #f]
         #:force-provider-cache-refresh? [force-provider-cache-refresh? #f])

  (define exit-code       0)
  (define compile-timings #f)
  (define t-driver-start (now-ms))

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
      (read-top-level-from-file filename)))
  (define t-read-source-end (now-ms))
  (define stx-for-compile
    (if print-top-level-results?
        (add-print-top-level-results-sentinel stx)
        stx))

  ; 2. Handle ffi-files.
  (define t-ffi-setup-start  (now-ms))
  (define resolved-ffi-files
    (merged-ffi-files 'drive-compilation browser? ffi-files stx))

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
  ;     "stdlib-for-browser.rkt" includes "stdlib.rkt" and adds `sxml->dom`
  (define t-add-stdlib-start (now-ms))
  (define stx-with-stdlib
    (cond
      [(and stdlib? browser?)
       (when verbose?
         (displayln "Composing module stdlib root `stdlib/stdlib-for-browser.rkt`"
                    (current-error-port)))
       (add-module-stdlib stx-for-compile
                           #t
                           #:io-format-provider? stdlib-io-format-provider?
                           #:expander-read-provider? expander-read-provider?
                           #:expander-read-syntax-provider? expander-read-syntax-provider?)]
      [stdlib?
       (when verbose?
         (displayln "Composing module stdlib root `stdlib/stdlib.rkt`"
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

;; module-form->top-level : syntax? -> syntax?
;;   Transitional #lang webracket/base support for the top-level compiler path.
(define (module-form->top-level stx)
  (define datum (syntax->datum stx))
  (define body
    (match datum
      [`(module ,_name webracket/base (#%module-begin ,forms ...))
       forms]
      [`(module ,_name webracket/base ,forms ...)
       forms]
      [_
       (raise-arguments-error
        'read-top-level-from-file
        "expected a #lang webracket/base module"
        "datum" datum)]))
  (define top-level-forms
    (filter (lambda (form)
              (not (and (pair? form)
                        (memq (car form) '(provide module+)))))
            body))
  (datum->syntax stx `(begin ,@top-level-forms) stx))

(define (read-top-level-from-file filename)
  (define first-line
    (call-with-input-file filename
      (λ (port)
        (read-line port 'any))))
  (define starts-with-webracket-lang?
    (webracket-script-lang-line? first-line))
  (define starts-with-webracket/base-lang?
    (webracket-base-lang-line? first-line))
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
             (void (read-line port 'any))
             (define forms (read-forms port))
             (datum->syntax #f `(begin ,@forms))]
            [starts-with-webracket/base-lang?
             (call-with-webracket-collection-path
              (lambda ()
                (module-form->top-level (read-syntax filename port))))]
            [else
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


(define-runtime-path here ".")
(define system-ffi-directory
  (let ([candidate (build-path here "ffi")])
    (and (directory-exists? candidate) candidate)))

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
