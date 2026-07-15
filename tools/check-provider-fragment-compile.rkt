#lang racket/base

;;; Check Provider Fragment Compile
;;;
;;; This experiment compiles module-bridge provider/program fragments outside
;;; the normal driver path. It can check provider-only, program-only, or
;;; combined provider+program compilation while we validate which cached
;;; artifacts can safely feed split-runtime builds.

(require racket/cmdline
         racket/format
         racket/list
         racket/match
         racket/path
         racket/set
         racket/runtime-path
         (only-in "../pkgs/webracket-lib/compiler/compiler.rkt"
                  comp
                  current-pass-timing-table
                  current-pass-timings?)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm.rkt"
                  split-runtime-modules?
                  split-runtime-modules-program)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/split-runtime.rkt"
                  strip-split-runtime-program-entry-init)
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  cache-datum->module-bridge-provider-fragment-payload
                  current-provider-cache-dir
                  ensure-module-bridge-provider-compiled-fragment-wat-cache!
                  module-bridge-fragment-split-program-datum
                  module-bridge-fragment-split-provider-datum
                  module-bridge-provider-compiled-fragment-cache-key
                  module-bridge-provider-fragment-fingerprint
                  module-bridge-result-cache-path
                  module-bridge-result-cache-payload->fragment-split
                  provider-owned-primitive-alias-symbols
                  read-module-bridge-provider-fragment-cache
                  read-module-bridge-result-cache
                  write-wat-to-file)
         (only-in "../pkgs/webracket-lib/compiler/private/parameters.rkt"
                  current-browser?
                  current-enable-cc-analysis?
                  current-enable-simplify?
                  current-frontend-cache-enabled?
                  current-letrec-strategy
                  current-imported-top-level-globals
                  current-exported-top-level-globals
                  current-provider-owned-primitive-aliases
                  current-split-runtime?
                  current-split-runtime-reference-only?))

(define-runtime-path repo-dir "..")
(define repo-root (simplify-path repo-dir))

(define source-file #f)
(define fragment-cache-file #f)
(define provider-cache-root #f)
(define write-wat-file #f)
(define timings? #f)
(define browser? #f)
(define enable-simplify? #f)
(define enable-cc-analysis? #f)
(define frontend-cache? #f)
(define expander-read-provider? #t)
(define io-format-provider? #f)
(define cache-wat? #f)
(define fragment-kind 'provider)
(define split-runtime-reference? #f)
(define strip-program-entry-runtime-init? #f)

;; resolve-repo-path : string? -> path?
;;   Resolve a command-line path relative to the repository root.
(define (resolve-repo-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

(command-line
 #:program "check-provider-fragment-compile"
 #:once-each
 [("--source") path
  "Root #lang webracket/base source whose module-bridge result cache should be used."
  (set! source-file (resolve-repo-path path))]
 [("--fragment-cache") path
  "Read a provider-fragment .rktd cache file directly instead of locating it from --source."
  (set! fragment-cache-file (resolve-repo-path path))]
 [("--provider-cache-root") path
  "Provider cache root that contains module-bridge result and provider-fragment caches."
  (set! provider-cache-root (resolve-repo-path path))]
 [("--write-wat") path
  "Write the compiled fragment WAT to this path."
  (set! write-wat-file (resolve-repo-path path))]
 [("--cache-wat")
  "Cache compact WAT by the provider-fragment fingerprint and compiler/runtime options."
  (set! cache-wat? #t)]
 [("--split-runtime-reference")
  "Compile the fragment as a split-runtime program module that imports core helpers."
  (set! split-runtime-reference? #t)]
 [("--strip-program-entry-runtime-init")
  "For a split-runtime program fragment, omit runtime init calls owned by an external loader."
  (set! strip-program-entry-runtime-init? #t)]
 [("--fragment") kind
  "Compile provider, program, or combined fragment from --source; defaults to provider."
  (case (string->symbol kind)
    [(provider program combined)
     (set! fragment-kind (string->symbol kind))]
    [else
     (raise-user-error 'check-provider-fragment-compile
                       "expected provider, program, or combined for --fragment, got ~a"
                       kind)])]
 [("--timings")
  "Print compiler pass timings for the fragment compile."
  (set! timings? #t)]
 [("--browser")
  "Compile with browser-mode runtime settings."
  (set! browser? #t)]
 [("--enable-simplify")
  "Enable the compiler simplify pass."
  (set! enable-simplify? #t)]
 [("--enable-cc-analysis")
  "Enable closure-conversion analysis."
  (set! enable-cc-analysis? #t)]
 [("--frontend-cache")
  "Enable the post-unexpand frontend cache for this experiment."
  (set! frontend-cache? #t)]
 [("--no-expander-read-provider")
  "Do not treat expander/read public aliases as provider-owned primitives."
  (set! expander-read-provider? #f)]
 [("--io-format-provider")
  "Treat io/format public aliases as provider-owned primitives."
  (set! io-format-provider? #t)])

(unless (or source-file fragment-cache-file)
  (raise-user-error 'check-provider-fragment-compile
                    "expected --source or --fragment-cache"))
(when (and source-file fragment-cache-file)
  (raise-user-error 'check-provider-fragment-compile
                    "use either --source or --fragment-cache, not both"))
(when (and fragment-cache-file (not (eq? fragment-kind 'provider)))
  (raise-user-error 'check-provider-fragment-compile
                    "--fragment-cache only contains a provider fragment"))
(when (and cache-wat? (not (eq? fragment-kind 'provider)))
  (raise-user-error 'check-provider-fragment-compile
                    "--cache-wat is currently supported only for provider fragments"))
(when (and strip-program-entry-runtime-init?
           (not (eq? fragment-kind 'program)))
  (raise-user-error 'check-provider-fragment-compile
                    "--strip-program-entry-runtime-init is supported only for --fragment program"))
(when (and strip-program-entry-runtime-init?
           (not split-runtime-reference?))
  (raise-user-error 'check-provider-fragment-compile
                    "--strip-program-entry-runtime-init requires --split-runtime-reference"))
;; direct-fragment-cache->provider-datum+fingerprint : path-string? -> (values any/c any/c)
;;   Read one provider-fragment cache file without checking its fingerprint.
(define (direct-fragment-cache->provider-datum+fingerprint path)
  (match (call-with-input-file path read)
    [`(,fingerprint ,payload)
     (define decoded
       (cache-datum->module-bridge-provider-fragment-payload payload))
     (unless decoded
       (raise-user-error 'check-provider-fragment-compile
                         "invalid provider-fragment cache payload: ~a"
                         path))
     (values (vector-ref decoded 1) fingerprint)]
    [other
     (raise-user-error 'check-provider-fragment-compile
                       "invalid provider-fragment cache file: ~a"
                       other)]))

;; bridge-export-symbol? : any/c -> boolean?
;;   Check whether a symbol is a generated module-bridge export box/value.
(define (bridge-export-symbol? v)
  (and (symbol? v)
       (regexp-match? #rx"^webify-export-(value|cell)"
                      (symbol->string v))))

;; collect-datum-symbols : any/c -> (set/c symbol?)
;;   Collect symbols anywhere in a datum.
(define (collect-datum-symbols datum)
  (define names (mutable-seteq))
  (define (walk v)
    (cond
      [(symbol? v)
       (set-add! names v)]
      [(pair? v)
       (walk (car v))
       (walk (cdr v))]
      [(vector? v)
       (for ([item (in-vector v)])
         (walk item))]
      [else
       (void)]))
  (walk datum)
  (list->seteq (set->list names)))

;; collect-top-define-symbols : any/c -> (set/c symbol?)
;;   Collect top-level definition names in a lowered bridge fragment.
(define (collect-top-define-symbols datum)
  (define forms
    (match datum
      [`(begin ,forms ...) forms]
      [_ '()]))
  (for*/seteq ([form (in-list forms)]
               [name (in-list
                      (match form
                        [`(define ,(? symbol? name) ,_) (list name)]
                        [`(define-values (,names ...) ,_)
                         (filter symbol? names)]
                        [_ '()]))])
    name))

;; provider-program-interface-symbols : any/c any/c -> (set/c symbol?)
;;   Return provider top-level boxes/values demanded by a program fragment.
(define (provider-program-interface-symbols provider-datum program-datum)
  (define provider-defs (collect-top-define-symbols provider-datum))
  (define program-symbols (collect-datum-symbols program-datum))
  (for/seteq ([name (in-set program-symbols)]
              #:when (and (bridge-export-symbol? name)
                          (set-member? provider-defs name)))
    name))

;; source-cache->fragment-datum+fingerprint+interface :
;;   path-string? -> (values any/c any/c (set/c symbol?))
;;   Locate the cached bridge result for `source` and return the selected fragment datum.
(define (source-cache->fragment-datum+fingerprint+interface source)
  (define bridge-cache-path
    (module-bridge-result-cache-path source))
  (define bridge-payload
    (read-module-bridge-result-cache bridge-cache-path))
  (unless bridge-payload
    (raise-user-error 'check-provider-fragment-compile
                      "module-bridge result cache miss for ~a at ~a"
                      source
                      bridge-cache-path))
  (define split
    (module-bridge-result-cache-payload->fragment-split bridge-payload))
  (define fingerprint
    (module-bridge-provider-fragment-fingerprint split))
  (define provider-datum
    (module-bridge-fragment-split-provider-datum split))
  (define program-datum
    (module-bridge-fragment-split-program-datum split))
  (define interface-symbols
    (provider-program-interface-symbols provider-datum program-datum))
  (case fragment-kind
    [(provider)
     (define cached-provider
       (read-module-bridge-provider-fragment-cache fingerprint))
     (cond
       [cached-provider
        (values (vector-ref cached-provider 1) fingerprint interface-symbols)]
       [else
        (values provider-datum fingerprint interface-symbols)])]
    [(program)
     (values program-datum
             fingerprint
             interface-symbols)]
    [(combined)
     (values `(begin ,provider-datum ,program-datum)
             fingerprint
             interface-symbols)]))

(define aliases
  (provider-owned-primitive-alias-symbols
   #:expander-read-provider? expander-read-provider?
   #:io-format-provider? io-format-provider?))

(define-values (provider-datum provider-fragment-fingerprint interface-symbols)
  (parameterize ([current-provider-cache-dir
                  (or provider-cache-root
                      (current-provider-cache-dir))]
                 [current-provider-owned-primitive-aliases aliases])
    (cond
      [fragment-cache-file
       (define-values (datum fingerprint)
         (direct-fragment-cache->provider-datum+fingerprint fragment-cache-file))
       (values datum
               fingerprint
               (for/seteq ([name (in-set (collect-top-define-symbols datum))]
                           #:when (bridge-export-symbol? name))
                 name))]
      [else
       (source-cache->fragment-datum+fingerprint+interface source-file)])))

(define provider-form-count
  (match provider-datum
    [`(begin ,forms ...) (length forms)]
    [_ #f]))

(printf "fragment-kind=~a\n" fragment-kind)
(printf "fragment-forms=~a\n" provider-form-count)
(printf "interface-symbols=~a\n" (set-count interface-symbols))

;; compile-fragment : -> any/c
;;   Run the ordinary compiler pipeline on the selected cached fragment datum.
(define (compile-fragment)
  (parameterize ([current-browser? browser?]
                 [current-enable-cc-analysis? enable-cc-analysis?]
                 [current-enable-simplify? enable-simplify?]
                 [current-frontend-cache-enabled? frontend-cache?]
                 [current-letrec-strategy 'scc]
                 [current-pass-timings? timings?]
                 [current-imported-top-level-globals
                  (if (eq? fragment-kind 'program)
                      interface-symbols
                      (seteq))]
                 [current-exported-top-level-globals
                  (if (eq? fragment-kind 'provider)
                      interface-symbols
                      (seteq))]
                 [current-provider-owned-primitive-aliases aliases]
                 [current-split-runtime? split-runtime-reference?]
                 [current-split-runtime-reference-only? split-runtime-reference?])
    (comp (datum->syntax #f provider-datum))))

;; compiled-fragment->wat : any/c -> any/c
;;   Extract the emitted program WAT from a normal or split-runtime compile result.
(define (compiled-fragment->wat compiled-fragment)
  (define wat
    (if (split-runtime-modules? compiled-fragment)
        (split-runtime-modules-program compiled-fragment)
        compiled-fragment))
  (if strip-program-entry-runtime-init?
      (strip-split-runtime-program-entry-init wat)
      wat))

;; print-pass-timings! : -> void?
;;   Print the compiler pass timing table when requested and available.
(define (print-pass-timings!)
  (when timings?
    (define timing-table (current-pass-timing-table))
    (when timing-table
      (display timing-table))))

(cond
  [cache-wat?
   (define cache-key
     (module-bridge-provider-compiled-fragment-cache-key
      provider-fragment-fingerprint
      #:browser? browser?
      #:enable-cc-analysis? enable-cc-analysis?
      #:enable-simplify? enable-simplify?
      #:split-runtime-reference? split-runtime-reference?
      #:letrec-strategy 'scc
      #:provider-owned-primitive-aliases aliases))
   (define compile-ms #f)
   (define ensure-start-ms (current-inexact-milliseconds))
   (define-values (cache-status wat-path)
     (parameterize ([current-provider-cache-dir
                     (or provider-cache-root
                         (current-provider-cache-dir))])
       (ensure-module-bridge-provider-compiled-fragment-wat-cache!
        cache-key
        (lambda ()
          (define compile-start-ms (current-inexact-milliseconds))
          (define compiled-provider (compile-fragment))
          (define compile-end-ms (current-inexact-milliseconds))
          (set! compile-ms (- compile-end-ms compile-start-ms))
          (compiled-fragment->wat compiled-provider)))))
   (define ensure-end-ms (current-inexact-milliseconds))
   (printf "cache-status=~a\n" cache-status)
   (when compile-ms
     (printf "compile-ms=~a\n" (~r compile-ms #:precision '(= 1)))
     (print-pass-timings!))
   (printf "ensure-ms=~a\n"
           (~r (- ensure-end-ms ensure-start-ms) #:precision '(= 1)))
   (printf "wat=~a\n" wat-path)]
  [else
   (define start-ms (current-inexact-milliseconds))
   (define compiled-provider (compile-fragment))
   (define end-ms (current-inexact-milliseconds))
   (printf "compile-ms=~a\n" (~r (- end-ms start-ms) #:precision '(= 1)))
   (print-pass-timings!)
   (when write-wat-file
     (write-wat-to-file write-wat-file
                        (compiled-fragment->wat compiled-provider)
                        #:pretty? #f)
     (printf "wat=~a\n" write-wat-file))])
