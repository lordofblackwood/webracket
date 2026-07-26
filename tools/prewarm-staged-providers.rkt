#lang racket/base

;;; Prewarm Staged Providers
;;;

;; This tool builds cache artifacts before an example compile needs them. It is
;; mainly used for expensive staged providers such as regexp support and
;; `expander/read`, for #lang webracket/base or full module-bridge results,
;; and for the split-runtime core wasm cache.
;; Prewarming moves cold demodularization/runtime assembly cost out of the
;; normal compile path.
;;
;; Invoke it with the Racket toolchain and cache directories you plan to use for
;; the later compile:
;;
;;   racket tools/prewarm-staged-providers.rkt \
;;     --provider-cache-dir path/to/provider-cache \
;;     --runtime-provider-cache-dir path/to/runtime-provider-cache \
;;     --mode read
;;
;; It prints the prewarmed mode and cache path. The selected artifacts are
;; written into the cache, and repeated runs reuse the existing artifacts unless
;; `--force` is supplied.


;;; Imports

;; The tool reuses the compiler driver's staged-provider and compilation entry
;; points so the prewarmed artifacts exactly match what normal WebRacket
;; compilation expects.

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         (only-in "../pkgs/webracket-lib/compiler/private/parameters.rkt"
                  current-provider-owned-primitive-aliases
                  current-runtime-cache-dir)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/split-runtime-cache.rkt"
                  split-runtime-boundary-cache-current?
                  split-runtime-core-cache-directory
                  split-runtime-core-cache-key-fingerprint
                  split-runtime-core-cache-wasm-path
                  split-runtime-request-cache-fingerprint
                  make-split-runtime-core-cache-key
                  make-split-runtime-core-only-cache-key)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/runtime-source.rkt"
                  runtime-source-fingerprint))

(define-runtime-path repo-dir "..")
(define repo-root
  (simplify-path repo-dir))
(define-runtime-path driver-module-path
  "../pkgs/webracket-lib/compiler/driver.rkt")

;; driver-ref : symbol? -> any/c
;;   Lazily load the heavy compiler driver only on paths that need it.
(define driver-ref
  (let ([cache (make-hasheq)])
    (lambda (name)
      (hash-ref! cache
                 name
                 (lambda ()
                   (dynamic-require driver-module-path name))))))

;; tool-temp-dir : -> path?
;;   Return the repo-local parent for temporary prewarm work directories.
(define (tool-temp-dir)
  (define dir (build-path repo-root "tmp"))
  (make-directory* dir)
  dir)


;;; Provider Prewarming

;; This section drives staged provider builders and split-runtime prebuilds
;; under the requested cache settings. The modes mirror the practical compile
;; needs: regexp alone, read plus its regexp dependency, module-bridge results,
;; split-runtime core wasm, io/format, or all currently known staged providers.

;; cache-dir->complete-path : path-string? -> path?
;;   Normalize a cache root argument to an absolute path.
(define (cache-dir->complete-path dir)
  (define p
    (if (path? dir)
        dir
        (string->path dir)))
  (path->complete-path p))

;; runtime-cache-wasm-file? : path? -> boolean?
;;   Check whether p is a cached runtime wasm artifact rather than a lock file.
(define (runtime-cache-wasm-file? p)
  (and (file-exists? p)
       (equal? (path-get-extension p) #".wasm")
       (not (regexp-match? #rx"^\\.LOCK"
                           (path->string (file-name-from-path p))))))

;; cached-runtime-wasm-files : path? -> (listof path?)
;;   Return cached split-runtime wasm artifacts in deterministic order.
(define (cached-runtime-wasm-files runtime-cache-dir)
  (define runtime-cache-root
    (build-path runtime-cache-dir split-runtime-core-cache-directory))
  (if (directory-exists? runtime-cache-root)
      (sort (find-files runtime-cache-wasm-file? runtime-cache-root)
            string<?
            #:key path->string)
      '()))

;; content-sidecar-paths : path-string? string? -> (listof path?)
;;   Return content-addressed Wasm sidecars with the given filename prefix.
(define (content-sidecar-paths dest-dir prefix)
  (define sidecar-rx
    (regexp
     (format "^~a-[0-9a-f]+\\.wasm$"
             (regexp-quote prefix))))
  (sort
   (for/list ([path (in-list (directory-list dest-dir #:build? #t))]
              #:when
              (regexp-match? sidecar-rx
                             (path->string (file-name-from-path path))))
     path)
   string<?
   #:key path->string))

;; copy-runtime-wasm-out! : path? path-string? -> void?
;;   Copy the selected cached runtime wasm to a caller-provided output path.
(define (copy-runtime-wasm-out! runtime-wasm runtime-wasm-out)
  (define out-path
    (cache-dir->complete-path runtime-wasm-out))
  (define parent
    (path-only out-path))
  (when parent
    (make-directory* parent))
  (copy-file runtime-wasm out-path #t))

;; prewarm-regexp-provider! : -> any/c
;;   Populate the public regexp provider cache used by script compiles.
(define (prewarm-regexp-provider!)
  ((driver-ref 'regexp-provider-forms) #:public-aliases? #t
                                      #:owner 'prewarm))

;; prewarm-read-provider! : -> any/c
;;   Populate expander/read plus its regexp dependency.
(define (prewarm-read-provider!)
  ;; The staged reader needs the staged regexp provider as part of its
  ;; dependency closure, so prewarm both artifacts together.
  ((driver-ref 'regexp-provider-forms) #:public-aliases? #t
                                      #:owner 'prewarm-expander-read)
  ((driver-ref 'read-provider-forms) #:public-aliases? #t
                                    #:owner 'prewarm-expander-read))

;; prewarm-io-format-provider! : -> any/c
;;   Populate the public io/format provider cache used by script compiles.
(define (prewarm-io-format-provider!)
  ((driver-ref 'io-format-provider-forms) #:public-aliases? #t))

;; prewarm-all-staged-providers! : -> any/c
;;   Populate all staged provider artifacts used by ordinary warm compiles.
(define (prewarm-all-staged-providers!)
  (prewarm-read-provider!)
  (prewarm-io-format-provider!))

;; module-bridge-lang-line? : any/c -> boolean?
;;   Check whether line starts a WebRacket module-language source.
(define (module-bridge-lang-line? line)
  (and (string? line)
       ;; Keep this in sync with the driver's `webracket-module-lang-line?`.
       (regexp-match? #px"^#lang[ \t]+webracket/(base|full)([ \t].*)?$" line)))

;; module-bridge-source? : path-string? -> boolean?
;;   Check whether source starts with a WebRacket module-language line.
(define (module-bridge-source? source)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (call-with-input-file source
      (lambda (in)
        (module-bridge-lang-line? (read-line in 'any))))))

;; prewarm-module-bridge! : path? path-string? boolean? boolean? -> void?
;;   Populate the module-bridge result cache for one module-language program.
(define (prewarm-module-bridge! cache-dir source force? verbose?)
  (unless source
    (raise-user-error 'prewarm-module-bridge!
                      "--mode module-bridge requires --source <file>"))
  (define source-path
    (path->complete-path
     (if (path? source) source (string->path source))))
  (unless (file-exists? source-path)
    (raise-user-error 'prewarm-module-bridge!
                      "source file does not exist: ~a"
                      source-path))
  (unless (module-bridge-source? source-path)
    (raise-user-error 'prewarm-module-bridge!
                      "expected a #lang webracket/base or full source file: ~a"
                      source-path))
  (parameterize ([(driver-ref 'current-provider-cache-dir) cache-dir]
                 [(driver-ref 'current-provider-cache-force?) force?]
                 [(driver-ref 'current-provider-cache-verbose?) verbose?]
                 [current-provider-owned-primitive-aliases
                  ((driver-ref 'provider-owned-primitive-alias-symbols)
                   #:expander-read-provider? #t
                   #:io-format-provider? #f)]
                 [current-directory repo-root]
                 [current-output-port (open-output-nowhere)])
    ((driver-ref 'read-top-level-from-file)
     source-path
     #:webracket-module-bridge? #t)
    (cond
      [((driver-ref 'current-module-bridge-needs-expander-read-provider?))
       (prewarm-read-provider!)]
      [((driver-ref 'current-module-bridge-needs-regexp-provider?))
       (prewarm-regexp-provider!)]
      [else
       (void)])))

;; split-runtime-prewarm-core-cache-key : symbol? boolean? -> any/c
;;   Build the split-runtime cache key produced by the prewarm compile.
(define (split-runtime-prewarm-core-cache-key host core-only?)
  (if core-only?
      (make-split-runtime-core-only-cache-key
       (runtime-source-fingerprint))
      (make-split-runtime-core-cache-key
       #t
       (split-runtime-request-cache-fingerprint
        #:browser? (eq? host 'browser)
        #:runtime-source-fingerprint (runtime-source-fingerprint)
        #:active-ffi-foreigns '()
        #:active-ffi-imports-wat '()
        #:active-ffi-funcs-wat '()))))

;; split-runtime-prewarm-cache-hit :
;;   path? symbol? boolean? boolean? -> (values (or/c any/c #f) (or/c path? #f))
;;   Return the cached runtime wasm when direct prewarm can skip compilation.
(define (split-runtime-prewarm-cache-hit runtime-cache-dir host core-only? force?)
  (define core-cache-key
    (split-runtime-prewarm-core-cache-key host core-only?))
  (define cache-wasm-path
    (split-runtime-core-cache-wasm-path
     runtime-cache-dir
     (split-runtime-core-cache-key-fingerprint core-cache-key)))
  (define boundary-cache-hit?
    (or core-only?
        (split-runtime-boundary-cache-current? runtime-cache-dir
                                               core-cache-key)))
  (if (and (not force?)
           boundary-cache-hit?
           (file-exists? cache-wasm-path))
      (values core-cache-key cache-wasm-path)
      (values #f #f)))

;; prewarm-split-runtime! :
;;   path? path? symbol? boolean? boolean? boolean? (or/c path-string? #f) -> void?
;;   Populate the stable split-runtime wasm cache through the normal driver.
(define (prewarm-split-runtime! cache-dir
                                runtime-cache-dir
                                host
                                force?
                                verbose?
                                core-only?
                                runtime-wasm-out)
  (define-values (_cache-key cached-runtime-wasm)
    (split-runtime-prewarm-cache-hit runtime-cache-dir host core-only? force?))
  (cond
    [cached-runtime-wasm
     (printf "split-runtime prewarm cache hit: ~a\n" cached-runtime-wasm)
     (when runtime-wasm-out
       (copy-runtime-wasm-out! cached-runtime-wasm runtime-wasm-out))]
    [else
     (define work-dir
       (make-temporary-file "webracket-split-runtime-prewarm-~a"
                            'directory
                            (tool-temp-dir)))
     (define source-path
       (build-path work-dir "split-runtime-prewarm.rkt"))
     (define dest-dir
       (build-path work-dir "out"))
     (call-with-output-file source-path
       (lambda (out)
         (displayln "(void)" out))
       #:exists 'truncate/replace)
     (make-directory* dest-dir)
     (define-values (exit-code _compile-timings)
       (parameterize ([current-directory repo-root]
                      [current-output-port (open-output-nowhere)])
         ((driver-ref 'drive-compilation)
          #:filename source-path
          #:wat-filename #f
          #:wasm-filename #f
          #:host-filename #f
          #:dest-dir dest-dir
          #:label-map-forms? #f
          #:dump-passes-dir #f
          #:dump-passes-limit #f
          #:timings? #f
          #:alpha-rename-profile? #f
          #:simplify-profile? #f
          #:pretty-wat? #f
          #:verbose? verbose?
          #:browser? (eq? host 'browser)
          #:node? (eq? host 'node)
          #:letrec-strategy 'waddell
          #:enable-cc-analysis? #f
          #:enable-simplify? #f
          #:module-bridge-elide-public-cells? #f
          #:tree-shake? #t
          #:tree-shake-report #f
          #:split-runtime? #t
          #:split-runtime-cache-reference? (eq? host 'node)
          #:split-runtime-core-only? core-only?
          #:print-top-level-results? #f
          #:internal-bind-treelist-debug-shape? #f
          #:internal-bind-immutable-hash-debug-shape? #f
          #:console-bridge? #f
          #:vfs-preloads '()
          #:vfs-mounts '()
          #:run-after? (eq? host 'node)
          #:exec-path-from-shell? #t
          #:ffi-files '()
          #:stdlib? #f
          #:stdlib-io-format-provider? #f
          #:expander-read-provider? #f
          #:expander-read-syntax-provider? #f
          #:webracket-module-bridge? #f
          #:provider-substitutions? #t
          #:provider-cache-dir cache-dir
          #:runtime-provider-cache-dir runtime-cache-dir
          #:clear-provider-cache? #f
          #:clear-runtime-provider-cache? #f
          #:force-provider-cache-refresh? force?)))
     (unless (zero? exit-code)
       (error 'prewarm-split-runtime!
              "split-runtime prewarm compile exited with code ~a"
              exit-code))
     (define-values (_post-cache-key post-cache-runtime-wasm)
       (split-runtime-prewarm-cache-hit runtime-cache-dir host core-only? #f))
     (unless post-cache-runtime-wasm
       (error 'prewarm-split-runtime!
              "split-runtime prewarm did not create a reusable cached runtime wasm in ~a"
              runtime-cache-dir))
     (when runtime-wasm-out
       (copy-runtime-wasm-out! post-cache-runtime-wasm runtime-wasm-out))
     (delete-directory/files work-dir)]))

;; prewarm-provider-runtime! :
;;   path? path? path-string? symbol? boolean? boolean? (or/c path-string? #f)
;;   -> void?
;;   Populate the source-specific provider-runtime split wasm cache.
(define (prewarm-provider-runtime! cache-dir
                                   runtime-cache-dir
                                   source
                                   host
                                   force?
                                   verbose?
                                   runtime-wasm-out)
  (unless source
    (raise-user-error 'prewarm-provider-runtime!
                      "--mode provider-runtime requires --source <file>"))
  (define source-path
    (path->complete-path
     (if (path? source) source (string->path source))))
  (unless (file-exists? source-path)
    (raise-user-error 'prewarm-provider-runtime!
                      "source file does not exist: ~a"
                      source-path))
  (unless (module-bridge-source? source-path)
    (raise-user-error 'prewarm-provider-runtime!
                      "expected a #lang webracket/base or full source file: ~a"
                      source-path))
  (define work-dir
    (make-temporary-file "webracket-provider-runtime-prewarm-~a"
                         'directory
                         (tool-temp-dir)))
  (define dest-dir
    (build-path work-dir "out"))
  (make-directory* dest-dir)
  (define-values (exit-code _compile-timings)
    (parameterize ([current-directory repo-root]
                   [current-output-port (if verbose?
                                            (current-output-port)
                                            (open-output-nowhere))])
      ((driver-ref 'drive-compilation)
       #:filename source-path
       #:wat-filename #f
       #:wasm-filename #f
       #:host-filename #f
       #:dest-dir dest-dir
       #:label-map-forms? #f
       #:dump-passes-dir #f
       #:dump-passes-limit #f
       #:timings? verbose?
       #:alpha-rename-profile? #f
       #:simplify-profile? #f
       #:pretty-wat? #f
       #:verbose? verbose?
       #:browser? (eq? host 'browser)
       #:node? (eq? host 'node)
       #:letrec-strategy 'waddell
       #:enable-cc-analysis? #f
       #:enable-simplify? #f
       #:module-bridge-elide-public-cells? #f
       #:tree-shake? #t
       #:tree-shake-report #f
       #:split-runtime? #t
       #:split-runtime-cache-reference? #f
       #:split-runtime-core-url #f
       #:split-runtime-core-only? #f
       #:split-runtime-provider-runtime? #t
       #:print-top-level-results? #f
       #:internal-bind-treelist-debug-shape? #f
       #:internal-bind-immutable-hash-debug-shape? #f
       #:console-bridge? #f
       #:vfs-preloads '()
       #:vfs-mounts '()
       #:run-after? #f
       #:exec-path-from-shell? #t
       #:ffi-files '()
       #:stdlib? #f
       #:stdlib-io-format-provider? #f
       #:expander-read-provider? #f
       #:expander-read-syntax-provider? #f
       #:webracket-module-bridge? #f
       #:provider-substitutions? #t
       #:provider-cache-dir cache-dir
       #:runtime-provider-cache-dir runtime-cache-dir
       #:clear-provider-cache? #f
       #:clear-runtime-provider-cache? #f
       #:force-provider-cache-refresh? force?)))
  (unless (zero? exit-code)
    (error 'prewarm-provider-runtime!
           "provider-runtime prewarm compile exited with code ~a"
           exit-code))
  (define runtime-wasms
    (content-sidecar-paths dest-dir "webracket-runtime"))
  (unless (= (length runtime-wasms) 1)
    (error 'prewarm-provider-runtime!
           "provider-runtime prewarm materialized ~a runtime wasm sidecars, expected exactly one: ~a"
           (length runtime-wasms)
           runtime-wasms))
  (define runtime-wasm (car runtime-wasms))
  (when runtime-wasm-out
    (copy-runtime-wasm-out! runtime-wasm runtime-wasm-out))
  (delete-directory/files work-dir))

;; prewarm-staged-providers! :
;;   path-string? path-string? symbol? symbol? boolean? boolean? boolean?
;;   (or/c path-string? #f) (or/c path-string? #f)
;;   -> void?
;;   Build staged provider artifacts into the selected provider-cache roots.
(define (prewarm-staged-providers! provider-cache-dir
                                   runtime-provider-cache-dir
                                   mode
                                   host
                                   force?
                                   verbose?
                                   core-only?
                                   runtime-wasm-out
                                   source)
  (when (and runtime-wasm-out
             (not (memq mode '(split-runtime provider-runtime))))
    (raise-user-error 'prewarm-staged-providers!
                      "--runtime-wasm-out requires --mode split-runtime or provider-runtime"))
  (when (and source
             (not (memq mode '(module-bridge provider-runtime))))
    (raise-user-error 'prewarm-staged-providers!
                      "--source requires --mode module-bridge or provider-runtime"))
  (when (and core-only?
             (eq? mode 'provider-runtime))
    (raise-user-error 'prewarm-staged-providers!
                      "--split-runtime-core-only cannot be combined with --mode provider-runtime"))
  (define cache-dir
    (cache-dir->complete-path provider-cache-dir))
  (define runtime-cache-dir
    (cache-dir->complete-path runtime-provider-cache-dir))
  (make-directory* cache-dir)
  (make-directory* runtime-cache-dir)
  (parameterize ([current-runtime-cache-dir runtime-cache-dir])
    (match mode
      ['split-runtime
       (prewarm-split-runtime! cache-dir
                               runtime-cache-dir
                               host
                               force?
                               verbose?
                               core-only?
                               runtime-wasm-out)]
      ['module-bridge
       (prewarm-module-bridge! cache-dir source force? verbose?)]
      ['provider-runtime
       (prewarm-provider-runtime! cache-dir
                                  runtime-cache-dir
                                  source
                                  host
                                  force?
                                  verbose?
                                  runtime-wasm-out)]
      ['regexp
       (parameterize ([(driver-ref 'current-provider-cache-dir) cache-dir]
                      [(driver-ref 'current-provider-cache-force?) force?]
                      [(driver-ref 'current-provider-cache-verbose?) verbose?])
         (prewarm-regexp-provider!))]
      ['read
       (parameterize ([(driver-ref 'current-provider-cache-dir) cache-dir]
                      [(driver-ref 'current-provider-cache-force?) force?]
                      [(driver-ref 'current-provider-cache-verbose?) verbose?])
         (prewarm-read-provider!))]
      ['io-format
       (parameterize ([(driver-ref 'current-provider-cache-dir) cache-dir]
                      [(driver-ref 'current-provider-cache-force?) force?]
                      [(driver-ref 'current-provider-cache-verbose?) verbose?])
         (prewarm-io-format-provider!))]
      ['all
       (parameterize ([(driver-ref 'current-provider-cache-dir) cache-dir]
                      [(driver-ref 'current-provider-cache-force?) force?]
                      [(driver-ref 'current-provider-cache-verbose?) verbose?])
         (prewarm-all-staged-providers!))]
      [_
       (error 'prewarm-staged-providers!
              "unsupported mode: ~a"
              mode)]))
  (printf "prewarmed caches: mode=~a host=~a split=~a cache=~a runtime-cache=~a~a~a\n"
          mode
          host
          (if core-only? 'core-only 'classified)
          cache-dir
          runtime-cache-dir
          (if runtime-wasm-out
              (format " runtime-wasm-out=~a"
                      (cache-dir->complete-path runtime-wasm-out))
              "")
          (if source
              (format " source=~a"
                      (path->complete-path
                       (if (path? source) source (string->path source))))
              "")))


;;; Command-Line Validation

;; Command-line validation keeps mode errors friendly before the tool starts
;; building staged providers.

;; parse-mode : string? -> symbol?
;;   Parse a command-line prewarm mode.
(define (parse-mode s)
  (define mode
    (string->symbol s))
  (unless (memq mode '(regexp read io-format module-bridge all split-runtime provider-runtime))
    (raise-user-error
     'prewarm-staged-providers
     (format "expected mode regexp, read, io-format, module-bridge, split-runtime, provider-runtime, or all; got ~a" s)))
  mode)

;; parse-host : string? -> symbol?
;;   Parse a command-line split-runtime target host.
(define (parse-host s)
  (define host
    (string->symbol s))
  (unless (memq host '(node browser))
    (raise-user-error
     'prewarm-staged-providers
     (format "expected host node or browser; got ~a" s)))
  host)


;;; Tests

(module+ test
  (require rackunit)

  (check-true (module-bridge-lang-line? "#lang webracket/base"))
  (check-true (module-bridge-lang-line? "#lang webracket/base racket/base"))
  (check-true (module-bridge-lang-line? "#lang webracket/full"))
  (check-true (module-bridge-lang-line? "#lang webracket/full racket/base"))
  (check-false (module-bridge-lang-line? "#lang webracket"))
  (check-false (module-bridge-lang-line? "#lang racket/base"))
  (check-false (module-bridge-lang-line? 'not-a-line))
  (check-eq? (parse-mode "provider-runtime") 'provider-runtime))


;;; Command-Line Entry Point

;; The main body collects cache and mode options, then runs the selected
;; prewarm operation with optional cache refresh and verbose cache logging.

(module+ main
  (define provider-cache-dir
    (build-path (find-system-path 'temp-dir) "webracket-provider-cache"))
  (define runtime-provider-cache-dir #f)
  (define mode 'all)
  (define host 'node)
  (define force? #f)
  (define verbose? #f)
  (define core-only? #f)
  (define runtime-wasm-out #f)
  (define source #f)
  (command-line
   #:program "prewarm-staged-providers.rkt"
   #:once-each
   [("--provider-cache-dir") dir
    "Write staged provider artifacts to <dir>."
    (set! provider-cache-dir dir)]
   [("--runtime-provider-cache-dir") dir
    "Write stable runtime-provider artifacts to <dir>."
    (set! runtime-provider-cache-dir dir)]
   [("--mode") which
    "Prewarm one of: regexp, read, io-format, module-bridge, split-runtime, provider-runtime, all."
    (set! mode (parse-mode which))]
   [("--host") which
    "Split-runtime target host: node or browser. Defaults to node."
    (set! host (parse-host which))]
   [("--runtime-wasm-out") path
    "After split-runtime/provider-runtime prewarm, copy the cached runtime wasm to <path>."
    (set! runtime-wasm-out path)]
   [("--source") path
    "With --mode module-bridge or provider-runtime, prewarm caches for <path>."
    (set! source path)]
   [("--split-runtime-core-only")
    "Prewarm the split runtime using only registered core-runtime helpers."
    (set! core-only? #t)]
   [("--no-split-runtime-core-only")
    "Prewarm the classified runtime/program split strategy (default)."
    (set! core-only? #f)]
   [("--force")
    "Force staged provider cache refresh."
    (set! force? #t)]
   [("--verbose")
    "Print provider-cache hit/miss messages."
    (set! verbose? #t)])
  (prewarm-staged-providers! provider-cache-dir
                              (or runtime-provider-cache-dir provider-cache-dir)
                              mode
                              host
                              force?
                              verbose?
                              core-only?
                              runtime-wasm-out
                              source))
