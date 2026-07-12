#lang racket/base

;;; Prewarm Staged Providers
;;;

;; This tool builds cache artifacts before an example compile needs them. It is
;; mainly used for expensive staged providers such as regexp support and
;; `expander/read`, and for the experimental split-runtime core wasm cache.
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
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         "../pkgs/webracket-lib/compiler/driver.rkt"
         (only-in "../pkgs/webracket-lib/compiler/private/parameters.rkt"
                  current-runtime-cache-dir))

(define-runtime-path repo-dir "..")
(define repo-root
  (simplify-path repo-dir))


;;; Provider Prewarming

;; This section drives staged provider builders and split-runtime prebuilds
;; under the requested cache settings. The modes mirror the practical compile
;; needs: regexp alone, read plus its regexp dependency, split-runtime core
;; wasm, or all currently known staged providers.

;; cache-dir->complete-path : path-string? -> path?
;;   Normalize a cache root argument to an absolute path.
(define (cache-dir->complete-path dir)
  (define p
    (if (path? dir)
        dir
        (string->path dir)))
  (path->complete-path p))

;; prewarm-split-runtime! : path? path? symbol? boolean? boolean? -> void?
;;   Populate the stable split-runtime wasm cache through the normal driver.
(define (prewarm-split-runtime! cache-dir runtime-cache-dir host force? verbose?)
  (define work-dir
    (make-temporary-file "webracket-split-runtime-prewarm-~a" 'directory))
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
      (drive-compilation
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
  (define (runtime-cache-wasm-file? p)
    (and (file-exists? p)
         (equal? (path-get-extension p) #".wasm")
         (not (regexp-match? #rx"^\\.LOCK"
                             (path->string (file-name-from-path p))))))
  (define runtime-cache-files
    (find-files
     runtime-cache-wasm-file?
     (build-path runtime-cache-dir "split-runtime-core-v3")))
  (when (null? runtime-cache-files)
    (error 'prewarm-split-runtime!
           "split-runtime prewarm did not create a cached runtime wasm in ~a"
           runtime-cache-dir))
  (delete-directory/files work-dir))

;; prewarm-staged-providers! : path-string? path-string? symbol? symbol? boolean? boolean? -> void?
;;   Build staged provider artifacts into the selected provider-cache roots.
(define (prewarm-staged-providers! provider-cache-dir runtime-provider-cache-dir mode host force? verbose?)
  (define cache-dir
    (cache-dir->complete-path provider-cache-dir))
  (define runtime-cache-dir
    (cache-dir->complete-path runtime-provider-cache-dir))
  (make-directory* cache-dir)
  (make-directory* runtime-cache-dir)
  (parameterize ([current-provider-cache-dir cache-dir]
                 [current-provider-cache-force? force?]
                 [current-provider-cache-verbose? verbose?]
                 [current-runtime-cache-dir runtime-cache-dir])
    (match mode
      ['regexp
       (regexp-provider-forms #:public-aliases? #t
                              #:owner 'prewarm)]
      ['read
       ;; The staged reader needs the staged regexp provider as part of its
       ;; dependency closure, so prewarm both artifacts together.
       (regexp-provider-forms #:public-aliases? #t
                              #:owner 'prewarm-expander-read)
       (read-provider-forms #:public-aliases? #t
                            #:owner 'prewarm-expander-read)]
      ['all
       (regexp-provider-forms #:public-aliases? #t
                              #:owner 'prewarm-expander-read)
       (read-provider-forms #:public-aliases? #t
                            #:owner 'prewarm-expander-read)]
      ['split-runtime
       (prewarm-split-runtime! cache-dir
                               runtime-cache-dir
                               host
                               force?
                               verbose?)]
      [_
       (error 'prewarm-staged-providers!
              "unsupported mode: ~a"
              mode)]))
  (printf "prewarmed caches: mode=~a host=~a cache=~a runtime-cache=~a\n"
          mode
          host
          cache-dir
          runtime-cache-dir))


;;; Command-Line Validation

;; Command-line validation keeps mode errors friendly before the tool starts
;; building staged providers.

;; parse-mode : string? -> symbol?
;;   Parse a command-line prewarm mode.
(define (parse-mode s)
  (define mode
    (string->symbol s))
  (unless (memq mode '(regexp read all split-runtime))
    (raise-user-error
     'prewarm-staged-providers
     (format "expected mode regexp, read, split-runtime, or all; got ~a" s)))
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
    "Prewarm one of: regexp, read, split-runtime, all."
    (set! mode (parse-mode which))]
   [("--host") which
    "Split-runtime target host: node or browser. Defaults to node."
    (set! host (parse-host which))]
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
                              verbose?))
