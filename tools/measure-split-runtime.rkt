#lang racket/base

;;; Measure Split Runtime
;;;

;; This benchmark checks the default split-runtime path against explicit
;; monolithic compiler output on a tiny no-stdlib Node program. It first runs a
;; cold split compile to populate the stable runtime cache, then measures a
;; `--no-split-runtime` compile/run and a warm split compile/run against the
;; same private provider/runtime caches. With `--prewarm-runtime-first`, the
;; runtime cache is populated by the prewarm tool before any measured user
;; compile.
;;
;; Invoke it from the repository root:
;;
;;   racket -S pkgs tools/measure-split-runtime.rkt
;;
;; The tool prints a compact timing table and exits non-zero if compilation
;; fails, the generated output does not run, or the warm split run does not use
;; the cached runtime wasm.


;;; Imports

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         "../pkgs/webracket-lib/compiler/cli-lib.rkt")


;;; Result Records

;; mode-result :
;;   symbol? boolean? boolean? boolean? real? string? string? path?
;;   (or/c real? #f) (or/c real? #f) (or/c real? #f) (or/c real? #f)
;;   (or/c real? #f) exact-nonnegative-integer? exact-nonnegative-integer?
;;   symbol? (or/c string? #f) (or/c string? #f) (or/c string? #f)
;;   -> mode-result?
;;   Summary of one compile/run mode.
(struct mode-result
  (name
   compile-ok?
   expect-ok?
   cache-ok?
   wall-ms
   stdout
   stderr
   dest-dir
   driver-total
   compile-pipeline
   compile
   assemble
   generate-runtime
   program-wasm-size
   runtime-wasm-size
   split-cache-status
   split-imported-name-count
   split-program-form-count
   split-program-function-count)
  #:transparent)

;; phase-result :
;;   symbol? boolean? real? (or/c real? #f) (or/c real? #f) path? string? string?
;;   -> phase-result?
;;   Summary of one extended phase-breakdown row.
(struct phase-result
  (name
   ok?
   wall-ms
   driver-total
   outside-driver
   log-path
   status-detail
   stderr)
  #:transparent)


;;; Repository Paths

;; repo-dir : path?
;;   Absolute path to the repository root.
(define-runtime-path repo-dir "..")
(define repo-root
  (simplify-path repo-dir))

;; default-source-file : path?
;;   Default tiny no-stdlib source used by this benchmark.
(define default-source-file
  (build-path repo-root "test" "test-trivial.rkt"))

;; benchmark-temp-dir : -> path?
;;   Return the repo-local parent for temporary benchmark directories.
(define (benchmark-temp-dir)
  (define dir (build-path repo-root "tmp"))
  (make-directory* dir)
  dir)


;;; Command-Line Configuration

(define source-file default-source-file)
(define expected-output-regexp #rx"(^|\n)42(\n|$)")
(define keep-temp? #t)
(define include-cache-reference? #f)
(define prewarm-runtime-first? #f)
(define prewarm-staged-providers-first? #f)
(define prewarm-module-bridge-first? #f)
(define precompile-compiler-first? #f)
(define isolate-compiled-root? #f)
(define core-only? #f)
(define provider-runtime? #f)
(define in-process? #f)
(define compile-server? #f)
(define frontend-cache? #f)
(define phase-breakdown? #f)
(define phase-breakdown-only? #f)

;; resolve-source-path : string? -> path?
;;   Resolve a user-provided source path relative to the repository root.
(define (resolve-source-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

(command-line
 #:program "measure-split-runtime"
 #:once-each
 [("--source") path
  "Source file to benchmark; defaults to test/test-trivial.rkt"
  (set! source-file (resolve-source-path path))]
 [("--expect") pattern
  "Regular expression expected in compiler/run stdout; defaults to a line containing 42"
  (set! expected-output-regexp (regexp pattern))]
 [("--no-expect")
  "Do not validate generated program output"
  (set! expected-output-regexp #f)]
 [("--delete-temp")
  "Delete the temporary benchmark directory after a successful run"
  (set! keep-temp? #f)]
 [("--include-cache-reference")
  "Also measure Node output that references cached split-runtime wasm directly"
  (set! include-cache-reference? #t)]
 [("--prewarm-runtime-first")
  "Prewarm the split runtime cache before measured user compiles; skips split-cold"
  (set! prewarm-runtime-first? #t)]
 [("--prewarm-staged-providers-first")
  "Prewarm staged regexp/read/io-format provider caches before measured user compiles"
  (set! prewarm-staged-providers-first? #t)]
 [("--prewarm-module-bridge-first")
  "Compile the source once before measuring so module-bridge result caches are warm"
  (set! prewarm-module-bridge-first? #t)]
 [("--precompile-compiler-first")
  "Run raco make for the compiler into the isolated compiled root before measuring"
  (set! precompile-compiler-first? #t)]
 [("--isolate-compiled-root")
  "Run subprocesses with a private PLTCOMPILEDROOTS; useful for cold-root measurements"
  (set! isolate-compiled-root? #t)]
 [("--split-runtime-core-only")
  "Measure the core-helper-only split runtime strategy"
  (set! core-only? #t)]
 [("--split-runtime-provider-runtime")
  "For module sources, measure the provider-fragment-in-runtime split strategy"
  (set! provider-runtime? #t)]
 [("--in-process")
  "Run measured compiles in this Racket process instead of fresh subprocesses"
  (set! in-process? #t)]
 [("--compile-server")
  "Run measured compiles through the local WebRacket compile server client"
  (set! compile-server? #t)]
 [("--frontend-cache")
  "Pass --frontend-cache to measured compiles"
  (set! frontend-cache? #t)]
 [("--phase-breakdown")
  "Also print a fresh-process startup/require/compile/run phase breakdown"
  (set! phase-breakdown? #t)]
 [("--phase-breakdown-only")
  "Only print the fresh-process phase breakdown; skip the normal mode table"
  (set! phase-breakdown? #t)
  (set! phase-breakdown-only? #t)])

(when (and in-process? compile-server?)
  (raise-user-error 'measure-split-runtime
                    "use --in-process or --compile-server, not both"))

(when (and provider-runtime? core-only?)
  (raise-user-error 'measure-split-runtime
                    "use --split-runtime-provider-runtime or --split-runtime-core-only, not both"))


;;; Subprocess Helpers

;; ensure-executable : string? -> path?
;;   Resolve an executable from PATH or fail with a helpful error.
(define (ensure-executable name)
  (or (find-executable-path name)
      (error 'measure-split-runtime
             "required executable not found in PATH: ~a"
             name)))

;; env-ref* : (listof string?) (or/c string? #f) -> (or/c string? #f)
;;   Return the first non-empty environment variable value from names.
(define (env-ref* names fallback)
  (or (for/or ([name (in-list names)])
        (define value (and name (getenv name)))
        (and value (not (string=? value "")) value))
      fallback))

;; configured-racket-command : -> string?
;;   Return the Racket executable to use for child compiler processes.
(define (configured-racket-command)
  (or (env-ref* '("WEBRACKET_RACKET" "RACKET") #f)
      (path->string (find-system-path 'exec-file))
      "racket"))

;; ensure-racket-executable : -> path?
;;   Resolve the configured child Racket executable.
(define (ensure-racket-executable)
  (ensure-executable (configured-racket-command)))

;; run-command/capture : path-string? path-string? (listof string?)
;;   -> (values boolean? string? string? real?)
;;   Run a command under `cwd`, capturing stdout/stderr and elapsed wall time in ms.
(define (run-command/capture cwd exe args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define start-ms (current-inexact-milliseconds))
  (define ok?
    (parameterize ([current-directory cwd]
                   [current-output-port out]
                   [current-error-port err])
      (apply system* exe args)))
  (define end-ms (current-inexact-milliseconds))
  (values ok?
          (get-output-string out)
          (get-output-string err)
          (- end-ms start-ms)))

;; compile-config-from-args : (listof string?) -> webracket-compile-config?
;;   Parse a WebRacket compiler config from ordinary user-facing CLI arguments.
(define (compile-config-from-args args)
  (parameterize ([current-command-line-arguments (list->vector args)])
    (match (parse-webracket-cli)
      [(webracket-cli-command 'compile cfg) cfg]
      [command
       (error 'measure-split-runtime
              "expected compile command, got: ~a"
              (webracket-cli-command-kind command))])))

;; run-compile-in-process/capture :
;;   (listof string?) -> (values boolean? string? string? real?)
;;   Run one compile in the current Racket process while capturing output.
(define (run-compile-in-process/capture args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define start-ms (current-inexact-milliseconds))
  (define-values (ok? maybe-exn)
    (with-handlers ([exn:fail?
                     (lambda (exn)
                       (values #f exn))])
      (parameterize ([current-output-port out]
                     [current-error-port err])
        (define cfg (compile-config-from-args args))
        (define-values (exit-code _compile-timings _output-paths)
          (run-webracket-compile cfg))
        (values (zero? exit-code) #f))))
  (when maybe-exn
    (displayln (exn-message maybe-exn) err))
  (define end-ms (current-inexact-milliseconds))
  (values ok?
          (get-output-string out)
          (get-output-string err)
          (- end-ms start-ms)))

;; call-with-compile-server-env : (-> any/c) -> any/c
;;   Run thunk with the CLI routed through the local compile server.
(define (call-with-compile-server-env thunk)
  (define env
    (environment-variables-copy (current-environment-variables)))
  (environment-variables-set! env #"WEBRACKET_COMPILE_SERVER" #"1")
  (parameterize ([current-environment-variables env])
    (thunk)))

;; run-compile-server/capture :
;;   path-string? path-string? (listof string?) -> (values boolean? string? string? real?)
;;   Run one compile through `webracket.rkt` with WEBRACKET_COMPILE_SERVER enabled.
(define (run-compile-server/capture cwd racket-exe args)
  (call-with-compile-server-env
   (lambda ()
     (run-command/capture cwd
                          racket-exe
                          (append (list "-S" "pkgs" "webracket.rkt")
                                  args)))))

;; run-webracket-compile-args/capture :
;;   path-string? path-string? (listof string?) -> (values boolean? string? string? real?)
;;   Run one WebRacket compile using the selected benchmark runner.
(define (run-webracket-compile-args/capture cwd racket-exe args)
  (cond
    [in-process?
     (run-compile-in-process/capture args)]
    [compile-server?
     (run-compile-server/capture cwd racket-exe args)]
    [else
     (run-command/capture cwd
                          racket-exe
                          (append (list "-S" "pkgs" "webracket.rkt")
                                  args))]))

;; compile-runner-label : -> string?
;;   Return the user-facing name of the selected compile runner.
(define (compile-runner-label)
  (cond
    [in-process? "in-process"]
    [compile-server? "compile-server"]
    [else "fresh subprocess per mode"]))

;; compiler-timing-heading-line? : string? -> boolean?
;;   Check whether a stdout line starts a compiler timing/report section.
(define (compiler-timing-heading-line? line)
  (and (string-prefix? line "=== ")
       (string-suffix? line " ===")))

;; compiler-stdout->program-output : string? -> string?
;;   Return only the program-output prefix before compiler timing sections.
(define (compiler-stdout->program-output stdout)
  (string-join
   (let loop ([lines (string-split stdout "\n" #:trim? #f)]
              [acc '()])
     (cond
       [(null? lines) (reverse acc)]
       [(compiler-timing-heading-line? (car lines)) (reverse acc)]
       [else (loop (cdr lines) (cons (car lines) acc))]))
   "\n"))

;; webracket-module-source? : path-string? -> boolean?
;;   Check whether source uses the module bridge path.
(define (webracket-module-source? source)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (call-with-input-file source
      (lambda (in)
        (define first-line
          (read-line in 'any))
        (and (string? first-line)
             (regexp-match? #px"^#lang[ \t]+webracket/(base|full)([ \t].*)?$"
                            first-line))))))

;; write-log! : path-string? string? string? -> void?
;;   Save a captured subprocess transcript.
(define (write-log! path stdout stderr)
  (call-with-output-file path
    (lambda (out)
      (display stdout out)
      (unless (or (string=? stdout "") (string-suffix? stdout "\n"))
        (newline out))
      (display stderr out))
    #:exists 'truncate/replace))

;; compiler-entry-files : -> (listof path?)
;;   Return compiler entry modules whose dependencies should be precompiled.
(define (compiler-entry-files)
  (list
   (build-path repo-root "webracket.rkt")
   (build-path repo-root "tools" "prewarm-staged-providers.rkt")
   (build-path repo-root "pkgs" "webracket-lib" "compiler" "cli.rkt")
   (build-path repo-root "pkgs" "webracket-lib" "compiler" "cli-lib.rkt")
   (build-path repo-root "pkgs" "webracket-lib" "compiler" "driver.rkt")
   (build-path repo-root "pkgs" "webracket-lib" "compiler" "compiler.rkt")
   (build-path repo-root "pkgs" "webracket-lib" "compiler" "runtime-wasm.rkt")))

;; precompile-compiler! : path? path? -> (values boolean? real?)
;;   Precompile compiler modules into the current PLTCOMPILEDROOTS.
(define (precompile-compiler! racket-exe temp-root)
  (define compile-files
    (compiler-entry-files))
  (define args
    (append (list "-S" "pkgs" "-l" "raco" "make")
            (map path->string compile-files)))
  (define-values (ok? stdout stderr wall-ms)
    (run-command/capture repo-root racket-exe args))
  (write-log! (build-path temp-root "precompile-compiler.log")
              stdout
              stderr)
  (values ok? wall-ms))

;; prewarm-split-runtime-cache! : path? path? path? path? -> (values boolean? real?)
;;   Populate the selected split runtime cache before measured user compiles.
(define (prewarm-split-runtime-cache! racket-exe temp-root provider-cache runtime-cache)
  (define-values (ok? stdout stderr wall-ms)
    (cond
      [provider-runtime?
       (define prewarm-args
         (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
               "--provider-cache-dir" (path->string provider-cache)
               "--runtime-provider-cache-dir" (path->string runtime-cache)
               "--mode" "provider-runtime"
               "--host" "node"
               "--source" (path->string source-file)))
       (run-command/capture repo-root racket-exe prewarm-args)]
      [else
       (define prewarm-args
         (append
          (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
                "--provider-cache-dir" (path->string provider-cache)
                "--runtime-provider-cache-dir" (path->string runtime-cache)
                "--mode" "split-runtime")
          (if core-only?
              '("--split-runtime-core-only")
              '())))
       (run-command/capture repo-root racket-exe prewarm-args)]))
  (write-log! (build-path temp-root "prewarm-split-runtime.log")
              stdout
              stderr)
  (values ok? wall-ms))

;; prewarm-staged-provider-cache! : path? path? path? path? -> (values boolean? real?)
;;   Populate staged provider caches through the standalone prewarm tool.
(define (prewarm-staged-provider-cache! racket-exe temp-root provider-cache runtime-cache)
  (define prewarm-args
    (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
          "--provider-cache-dir" (path->string provider-cache)
          "--runtime-provider-cache-dir" (path->string runtime-cache)
          "--mode" "all"))
  (define-values (ok? stdout stderr wall-ms)
    (run-command/capture repo-root racket-exe prewarm-args))
  (write-log! (build-path temp-root "prewarm-staged-providers.log")
              stdout
              stderr)
  (values ok? wall-ms))

;; prewarm-module-bridge-cache! : path? path? path? path? (or/c regexp? #f)
;;   -> (values boolean? real?)
;;   Compile the source once to populate source-specific module-bridge caches.
(define (prewarm-module-bridge-cache! racket-exe
                                      temp-root
                                      provider-cache
                                      runtime-cache
                                      expect-rx)
  (define dest-dir
    (build-path temp-root "dest" "module-bridge-prewarm"))
  (make-directory* dest-dir)
  (define split-shape-flags
      (if prewarm-runtime-first?
        (append
         (list "--split-runtime-cache-reference"
               "--runtime-provider-cache-dir"
               (path->string runtime-cache))
         (if provider-runtime?
             '("--split-runtime-provider-runtime")
             '())
         (if core-only?
             '("--split-runtime-core-only")
             '()))
        '("--no-split-runtime")))
  (define webracket-args
    (append
     (append
      '("--node" "--run" "--timings" "--no-stdlib")
      split-shape-flags
      (if frontend-cache?
          '("--frontend-cache")
          '()))
     (list "--provider-cache-dir" (path->string provider-cache)
           "--dest" (path->string dest-dir)
           (path->string source-file))))
  (define-values (ok? stdout stderr wall-ms)
    (run-webracket-compile-args/capture repo-root racket-exe webracket-args))
  (write-log! (build-path temp-root "prewarm-module-bridge.log")
              stdout
              stderr)
  (values (and ok?
               (or (not expect-rx)
                   (regexp-match? expect-rx
                                  (compiler-stdout->program-output stdout))))
          wall-ms))


;;; Timing Parsing

;; section-lines : string? string? -> (listof string?)
;;   Extract lines from a named `=== Heading ===` timing section.
(define (section-lines transcript heading)
  (define wanted-heading (format "=== ~a ===" heading))
  (let loop ([lines (string-split transcript "\n")]
             [inside? #f]
             [acc '()])
    (cond
      [(null? lines) (reverse acc)]
      [else
       (define line (car lines))
       (cond
         [(string=? line wanted-heading)
          (loop (cdr lines) #t '())]
         [(and inside?
               (regexp-match? #px"^=== .+ ===$" line))
          (reverse acc)]
         [inside?
          (loop (cdr lines) #t (cons line acc))]
         [else
          (loop (cdr lines) #f acc)])])))

;; timing-line->label+seconds : string? -> (values (or/c string? #f) (or/c real? #f))
;;   Parse one timing table row.
(define (timing-line->label+seconds line)
  (match (regexp-match #px"^\\s*(.+?)\\s+:\\s+([0-9]+(?:\\.[0-9]+)?)" line)
    [(list _ label seconds)
     (values (string-trim label) (string->number seconds))]
    [_ (values #f #f)]))

;; section-row-seconds : string? string? string? -> (or/c real? #f)
;;   Return the seconds value for a row in a named timing section.
(define (section-row-seconds transcript heading label)
  (for/first ([line (in-list (section-lines transcript heading))]
              #:do [(define-values (row-label seconds)
                      (timing-line->label+seconds line))]
              #:when (and row-label (string=? row-label label)))
    seconds))

;; section-row-value : string? string? string? -> (or/c string? #f)
;;   Return the raw value for a row in a named report section.
(define (section-row-value transcript heading label)
  (for/first ([line (in-list (section-lines transcript heading))]
              #:do [(define match
                      (regexp-match #px"^\\s*(.+?)\\s+:\\s+(.+?)\\s*$"
                                    line))]
              #:when (and match
                          (string=? (string-trim (second match)) label)))
    (string-trim (third match))))

;; transcript-split-cache-status : string? -> symbol?
;;   Classify the split-runtime core cache behavior visible in a transcript.
(define (transcript-split-cache-status transcript)
  (cond
    [(regexp-match? #rx"split-runtime-core:reference-wasm-hit" transcript)
     'wasm-reference-hit]
    [(regexp-match? #rx"split-runtime-core:materialize-wasm-hit" transcript)
     'wasm-hit]
    [(regexp-match? #rx"split-runtime-core:assemble-wasm" transcript)
     'miss-assembled]
    [(regexp-match? #rx"=== Split Runtime Core Cache Details ===" transcript)
     'other]
    [else
     'none]))

;; transcript-provider-runtime-cold-work? : string? -> boolean?
;;   Check whether a provider-runtime compile rebuilt provider/runtime artifacts.
(define (transcript-provider-runtime-cold-work? transcript)
  (regexp-match? #rx"provider-runtime-merge|provider-fragment-cache"
                 transcript))


;;; Compilation

;; generated-path : path-string? path? string? -> path?
;;   Return a generated artifact path in `dest-dir`.
(define (generated-path dest-dir source ext)
  (build-path dest-dir
              (path-replace-extension (file-name-from-path source) ext)))

;; file-size/zero : path-string? -> exact-nonnegative-integer?
;;   Return the file size or zero when the file is missing.
(define (file-size/zero path)
  (if (file-exists? path) (file-size path) 0))

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

;; sidecar-size/zero : path-string? string? -> exact-nonnegative-integer?
;;   Return the total size of content-addressed sidecars with prefix.
(define (sidecar-size/zero dest-dir prefix)
  (for/sum ([path (in-list (content-sidecar-paths dest-dir prefix))])
    (file-size/zero path)))

;; mode-flags : symbol? path-string? path-string? [#:run? boolean?] -> (listof string?)
;;   Return WebRacket flags for one benchmark mode.
(define (mode-flags mode provider-cache runtime-cache #:run? [run? #t])
  (append
   (append
    (append '("--node" "--timings" "--no-stdlib")
            (if run? '("--run") '()))
    (if frontend-cache?
        '("--frontend-cache")
        '()))
   (list "--provider-cache-dir" (path->string provider-cache))
   (case mode
     [(monolithic) '("--no-split-runtime")]
     [(split-cold split-warm)
      (append
       (list "--runtime-provider-cache-dir"
             (path->string runtime-cache))
       (if provider-runtime?
           '("--split-runtime-provider-runtime")
           '())
       (if core-only?
           '("--split-runtime-core-only")
           '()))]
     [(split-cache-reference-warm)
      (append
       (list "--split-runtime-cache-reference"
             "--runtime-provider-cache-dir"
             (path->string runtime-cache))
       (if provider-runtime?
           '("--split-runtime-provider-runtime")
           '())
       (if core-only?
           '("--split-runtime-core-only")
           '()))]
     [else
      (error 'mode-flags "unknown mode: ~a" mode)])))

;; compile-mode :
;;   symbol? path? path? path? path? regexp? -> mode-result?
;;   Compile and run one benchmark mode.
(define (compile-mode mode racket-exe temp-root provider-cache runtime-cache expect-rx)
  (define dest-dir
    (build-path temp-root "dest" (symbol->string mode)))
  (when (directory-exists? dest-dir)
    (delete-directory/files dest-dir))
  (make-directory* dest-dir)
  (define webracket-args
    (append
     (mode-flags mode provider-cache runtime-cache)
     (list "--dest"
           (path->string dest-dir)
           (path->string source-file))))
  (define-values (ok? stdout stderr wall-ms)
    (run-webracket-compile-args/capture repo-root racket-exe webracket-args))
  (write-log! (build-path temp-root (format "~a.log" mode)) stdout stderr)
  (define transcript (string-append stdout "\n" stderr))
  (define program-wasm
    (generated-path dest-dir source-file ".wasm"))
  (define expect-ok?
    (and ok?
         (or (not expect-rx)
             (regexp-match? expect-rx
                            (compiler-stdout->program-output stdout)))))
  (define split-status
    (transcript-split-cache-status transcript))
  (define cache-ok?
    (and
     (case mode
       [(split-cold) (eq? split-status 'miss-assembled)]
       [(split-warm) (eq? split-status 'wasm-hit)]
       [(split-cache-reference-warm) (eq? split-status 'wasm-reference-hit)]
       [else #t])
     (not (and provider-runtime?
               (memq mode '(split-warm split-cache-reference-warm))
               (transcript-provider-runtime-cold-work? transcript)))))
  (mode-result mode
               ok?
               expect-ok?
               cache-ok?
               wall-ms
               stdout
               stderr
               dest-dir
               (section-row-seconds transcript "Driver Timings" "total")
               (section-row-seconds transcript "Driver Timings" "compile-pipeline")
               (section-row-seconds transcript "Compile Pipeline" "compile")
               (section-row-seconds transcript "Compile Pipeline" "assemble")
               (section-row-seconds transcript "Generate-Code Phases" "generate-runtime")
               (file-size/zero program-wasm)
               (sidecar-size/zero dest-dir "webracket-runtime")
               split-status
               (section-row-value transcript
                                  "Runtime Generation Metrics"
                                  "split-imported-name-count")
               (section-row-value transcript
                                  "Runtime Generation Metrics"
                                  "split-program-form-count")
               (section-row-value transcript
                                  "Runtime Generation Metrics"
                                  "split-program-function-count")))


;;; Extended Phase Breakdown

;; phase-log-path : path-string? symbol? -> path?
;;   Return the log path for an extended phase row.
(define (phase-log-path temp-root name)
  (build-path temp-root (format "phase-~a.log" name)))

;; measure-command-phase :
;;   symbol? path-string? path-string? path-string? (listof string?) -> phase-result?
;;   Measure a plain subprocess phase.
(define (measure-command-phase name temp-root cwd exe args)
  (define-values (ok? stdout stderr wall-ms)
    (run-command/capture cwd exe args))
  (define log-path (phase-log-path temp-root name))
  (write-log! log-path stdout stderr)
  (phase-result name
                ok?
                wall-ms
                #f
                #f
                log-path
                (if ok? "ok" "failed")
                stderr))

;; measure-startup-phase-rows : path-string? path-string? -> (listof phase-result?)
;;   Measure fresh Racket startup and compiler/tool module loading.
(define (measure-startup-phase-rows racket-exe temp-root)
  (list
   (measure-command-phase
    'racket-startup
    temp-root
    repo-root
    racket-exe
    '("-e" "(void)"))
   (measure-command-phase
    'racket-pkgs-startup
    temp-root
    repo-root
    racket-exe
    '("-S" "pkgs" "-e" "(void)"))
   (measure-command-phase
    'require-compiler-tools
    temp-root
    repo-root
    racket-exe
    '("-S" "pkgs"
      "-t" "tools/prewarm-staged-providers.rkt"
      "-t" "pkgs/webracket-lib/compiler/cli-lib.rkt"
      "-t" "pkgs/webracket-lib/compiler/driver.rkt"
      "-t" "pkgs/webracket-lib/compiler/runtime-wasm.rkt"))))

;; split-cache-status-ok? : symbol? symbol? -> boolean?
;;   Check whether a mode observed the expected split-runtime cache behavior.
(define (split-cache-status-ok? mode split-status)
  (case mode
    [(split-cold) (eq? split-status 'miss-assembled)]
    [(split-warm) (eq? split-status 'wasm-hit)]
    [(split-cache-reference-warm) (eq? split-status 'wasm-reference-hit)]
    [else #t]))

;; phase-modes : -> (listof symbol?)
;;   Return modes to use for compile/run phase breakdown.
(define (phase-modes)
  (append (if prewarm-runtime-first? '() '(split-cold))
          '(monolithic split-warm)
          (if include-cache-reference?
              '(split-cache-reference-warm)
              '())))

;; measure-phase-compile+run :
;;   symbol? path-string? path-string? path? path? path? (or/c regexp? #f)
;;   -> (list phase-result? phase-result?)
;;   Compile one mode without --run, then run the generated Node host separately.
(define (measure-phase-compile+run mode
                                   racket-exe
                                   node-exe
                                   temp-root
                                   provider-cache
                                   runtime-cache
                                   expect-rx)
  (define dest-dir
    (build-path temp-root "phase-dest" (symbol->string mode)))
  (when (directory-exists? dest-dir)
    (delete-directory/files dest-dir))
  (make-directory* dest-dir)
  (define webracket-args
    (append
     (mode-flags mode provider-cache runtime-cache #:run? #f)
     (list "--dest"
           (path->string dest-dir)
           (path->string source-file))))
  (define-values (compile-ok? compile-stdout compile-stderr compile-wall-ms)
    (run-command/capture repo-root
                         racket-exe
                         (append (list "-S" "pkgs" "webracket.rkt")
                                 webracket-args)))
  (define compile-log
    (phase-log-path temp-root (string->symbol (format "~a-compile" mode))))
  (write-log! compile-log compile-stdout compile-stderr)
  (define transcript (string-append compile-stdout "\n" compile-stderr))
  (define driver-total
    (section-row-seconds transcript "Driver Timings" "total"))
  (define outside-driver
    (and driver-total
         (- (/ compile-wall-ms 1000.0) driver-total)))
  (define split-status
    (transcript-split-cache-status transcript))
  (define cache-ok?
    (and (split-cache-status-ok? mode split-status)
         (not (and provider-runtime?
                   (memq mode '(split-warm split-cache-reference-warm))
                   (transcript-provider-runtime-cold-work? transcript)))))
  (define compile-phase
    (phase-result (string->symbol (format "~a-compile" mode))
                  (and compile-ok? cache-ok?)
                  compile-wall-ms
                  driver-total
                  outside-driver
                  compile-log
                  (format "core-cache=~a" split-status)
                  compile-stderr))
  (define host-js
    (generated-path dest-dir source-file ".js"))
  (define-values (run-ok? run-stdout run-stderr run-wall-ms)
    (if (and compile-ok? (file-exists? host-js))
        (run-command/capture dest-dir
                             node-exe
                             (list (path->string (file-name-from-path host-js))))
        (values #f "" "generated host JavaScript is missing\n" 0.0)))
  (define run-log
    (phase-log-path temp-root (string->symbol (format "~a-run" mode))))
  (write-log! run-log run-stdout run-stderr)
  (define output-ok?
    (and run-ok?
         (or (not expect-rx)
             (regexp-match? expect-rx run-stdout))))
  (define run-phase
    (phase-result (string->symbol (format "~a-run" mode))
                  output-ok?
                  run-wall-ms
                  #f
                  #f
                  run-log
                  (if output-ok? "output-ok" "unexpected-output")
                  run-stderr))
  (list compile-phase run-phase))


;;; Reporting

;; result-status : mode-result? -> string?
;;   Return a compact status string for a benchmark result.
(define (result-status r)
  (cond
    [(not (mode-result-compile-ok? r)) "compile/run failed"]
    [(not (mode-result-expect-ok? r))  "unexpected output"]
    [(not (mode-result-cache-ok? r))   "unexpected cache behavior"]
    [else                              "ok"]))

;; format-seconds : (or/c real? #f) -> string?
;;   Format a seconds value from compiler timing output.
(define (format-seconds seconds)
  (if seconds
      (~r seconds #:precision '(= 1))
      "-"))

;; format-duration-ms : real? -> string?
;;   Format milliseconds as seconds.
(define (format-duration-ms ms)
  (~r (/ ms 1000.0) #:precision '(= 1)))

;; format-bytes->mb : exact-nonnegative-integer? -> string?
;;   Format a byte count in MB.
(define (format-bytes->mb n)
  (~r (/ n 1000000.0) #:precision '(= 3)))

;; format-maybe : (or/c string? #f) -> string?
;;   Render an optional table value.
(define (format-maybe v)
  (or v "-"))

;; format-phase-status : phase-result? -> string?
;;   Return a compact status string for a phase row.
(define (format-phase-status r)
  (if (phase-result-ok? r) "ok" "failed"))

;; print-phase-row : phase-result? -> void?
;;   Print one extended phase-breakdown table row.
(define (print-phase-row r)
  (printf "~a\t~a\t~a\t~a\t~a\t~a\n"
          (phase-result-name r)
          (format-phase-status r)
          (format-duration-ms (phase-result-wall-ms r))
          (format-seconds (phase-result-driver-total r))
          (format-seconds (phase-result-outside-driver r))
          (phase-result-status-detail r)))

;; print-phase-breakdown : (listof phase-result?) -> void?
;;   Print the extended fresh-process startup/compile/run phase table.
(define (print-phase-breakdown rows)
  (printf "phase\tstatus\twall\tdriver-total\toutside-driver\tdetail\n")
  (for ([row (in-list rows)])
    (print-phase-row row)))

;; print-phase-failure-details : phase-result? -> void?
;;   Print log locations and stderr snippets for failed phase rows.
(define (print-phase-failure-details r)
  (unless (phase-result-ok? r)
    (printf "\n~a failed\n" (phase-result-name r))
    (printf "  log: ~a\n" (path->string (phase-result-log-path r)))
    (unless (string=? (string-trim (phase-result-stderr r)) "")
      (printf "  stderr tail:\n")
      (for ([line (in-list (take-right (string-split (string-trim (phase-result-stderr r)) "\n")
                                       (min 20
                                            (length
                                             (string-split (string-trim (phase-result-stderr r))
                                                           "\n")))))])
        (printf "    ~a\n" line)))))

;; print-row : mode-result? -> void?
;;   Print one benchmark table row.
(define (print-row r)
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
          (mode-result-name r)
          (result-status r)
          (format-duration-ms (mode-result-wall-ms r))
          (format-seconds (mode-result-driver-total r))
          (format-seconds (mode-result-compile-pipeline r))
          (format-seconds (mode-result-compile r))
          (format-seconds (mode-result-assemble r))
          (format-seconds (mode-result-generate-runtime r))
          (mode-result-split-cache-status r)
          (format-bytes->mb (mode-result-program-wasm-size r))
          (format-bytes->mb (mode-result-runtime-wasm-size r))
          (format-maybe (mode-result-split-imported-name-count r))
          (format-maybe (mode-result-split-program-form-count r))
          (format-maybe (mode-result-split-program-function-count r))))

;; delta-seconds : (or/c real? #f) (or/c real? #f) -> (or/c real? #f)
;;   Return `other - base` when both values are available.
(define (delta-seconds other base)
  (and other base (- other base)))

;; print-delta : mode-result? mode-result? -> void?
;;   Print warm split deltas against monolithic output.
(define (print-delta monolithic split-warm)
  (printf "\nDelta ~a vs monolithic (seconds)\n"
          (mode-result-name split-warm))
  (printf "  driver total:      ~a\n"
          (format-seconds
           (delta-seconds (mode-result-driver-total split-warm)
                          (mode-result-driver-total monolithic))))
  (printf "  compile-pipeline:  ~a\n"
          (format-seconds
           (delta-seconds (mode-result-compile-pipeline split-warm)
                          (mode-result-compile-pipeline monolithic))))
  (printf "  assemble:          ~a\n"
          (format-seconds
           (delta-seconds (mode-result-assemble split-warm)
                          (mode-result-assemble monolithic)))))

;; print-failure-details : mode-result? -> void?
;;   Print log locations and stderr snippets for a failed result.
(define (print-failure-details r temp-root)
  (unless (string=? (result-status r) "ok")
    (printf "\n~a failed: ~a\n"
            (mode-result-name r)
            (result-status r))
    (printf "  log: ~a\n"
            (path->string
             (build-path temp-root (format "~a.log" (mode-result-name r)))))
    (unless (string=? (string-trim (mode-result-stderr r)) "")
      (printf "  stderr tail:\n")
      (for ([line (in-list (take-right (string-split (string-trim (mode-result-stderr r)) "\n")
                                       (min 20
                                            (length
                                             (string-split (string-trim (mode-result-stderr r))
                                                           "\n")))))])
        (printf "    ~a\n" line)))))


;;; Main

;; successful-result? : mode-result? -> boolean?
;;   Check whether one benchmark result satisfied all gates.
(define (successful-result? r)
  (and (mode-result-compile-ok? r)
       (mode-result-expect-ok? r)
       (mode-result-cache-ok? r)))

;; main : -> void?
;;   Run the split-runtime benchmark.
(define (main)
  (unless (file-exists? source-file)
    (error 'measure-split-runtime
           "source file does not exist: ~a"
           source-file))
  (when (and provider-runtime?
             (not (webracket-module-source? source-file)))
    (raise-user-error
     'measure-split-runtime
     "--split-runtime-provider-runtime requires a #lang webracket/base or #lang webracket/full source: ~a"
     source-file))
  (define racket-exe (ensure-racket-executable))
  (define node-exe (ensure-executable "node"))
  (define temp-root
    (make-temporary-file "webracket-split-runtime-bench-~a"
                         'directory
                         (benchmark-temp-dir)))
  (define provider-cache (build-path temp-root "provider-cache"))
  (define runtime-cache  (build-path temp-root "runtime-provider-cache"))
  (define compiled-root  (build-path temp-root "compiled-root"))
  (define private-compiled-root?
    (or isolate-compiled-root?
        precompile-compiler-first?))
  (make-directory* provider-cache)
  (make-directory* runtime-cache)
  (when private-compiled-root?
    (make-directory* compiled-root)
    (putenv "PLTCOMPILEDROOTS" (path->string compiled-root)))
  (printf "Split runtime benchmark\n")
  (printf "  source:        ~a\n" (path->string source-file))
  (printf "  temp:          ~a\n" (path->string temp-root))
  (printf "  compiled root: ~a\n"
          (if private-compiled-root?
              (path->string compiled-root)
              "normal environment"))
  (printf "  compiler warm: ~a\n"
          (if precompile-compiler-first?
              "raco make"
              "not precompiled by benchmark"))
  (printf "  compile runner: ~a\n"
          (compile-runner-label))
  (printf "  split mode:    ~a\n"
          (cond
            [provider-runtime? "provider-runtime"]
            [core-only? "core-only"]
            [else "classified"]))
  (printf "  provider warm: ~a\n"
          (if prewarm-staged-providers-first?
              "regexp/read/io-format"
              "not prewarmed by benchmark"))
  (printf "  bridge warm:   ~a\n"
          (if prewarm-module-bridge-first?
              "module-bridge prewarm"
              "not prewarmed by benchmark"))
  (printf "  frontend cache: ~a\n"
          (if frontend-cache?
              "enabled"
              "disabled"))
  (printf "  runtime warm:  ~a\n\n"
          (cond
            [(and prewarm-runtime-first? provider-runtime?)
             "provider-runtime prewarm"]
            [prewarm-runtime-first?
             "split-runtime prewarm"]
            [else "split-cold"]))
  (define-values (precompile-ok? precompile-wall-ms)
    (if precompile-compiler-first?
        (precompile-compiler! racket-exe temp-root)
        (values #t 0.0)))
  (unless precompile-ok?
    (printf "compiler precompile failed; log: ~a\n"
            (path->string (build-path temp-root "precompile-compiler.log")))
    (exit 1))
  (when precompile-compiler-first?
    (printf "precompile\tok\t~a\n" (format-duration-ms precompile-wall-ms)))
  (define phase-startup-rows
    (if phase-breakdown?
        (measure-startup-phase-rows racket-exe temp-root)
        '()))
  (define phase-precompile-row
    (if (and phase-breakdown? precompile-compiler-first?)
        (list
         (phase-result 'compiler-precompile
                       precompile-ok?
                       precompile-wall-ms
                       #f
                       #f
                       (build-path temp-root "precompile-compiler.log")
                       "raco-make"
                       ""))
        '()))
  (define-values (provider-prewarm-ok? provider-prewarm-wall-ms)
    (if prewarm-staged-providers-first?
        (prewarm-staged-provider-cache! racket-exe
                                        temp-root
                                        provider-cache
                                        runtime-cache)
        (values #t 0.0)))
  (unless provider-prewarm-ok?
    (printf "staged provider prewarm failed; log: ~a\n"
            (path->string (build-path temp-root "prewarm-staged-providers.log")))
    (exit 1))
  (when prewarm-staged-providers-first?
    (printf "provider-prewarm\tok\t~a\n"
            (format-duration-ms provider-prewarm-wall-ms)))
  (define phase-provider-prewarm-row
    (if (and phase-breakdown? prewarm-staged-providers-first?)
        (list
         (phase-result 'staged-provider-prewarm
                       provider-prewarm-ok?
                       provider-prewarm-wall-ms
                       #f
                       #f
                       (build-path temp-root "prewarm-staged-providers.log")
                       "regexp/read/io-format"
                       ""))
        '()))
  (define-values (prewarm-ok? prewarm-wall-ms)
    (if prewarm-runtime-first?
        (prewarm-split-runtime-cache! racket-exe
                                      temp-root
                                      provider-cache
                                      runtime-cache)
        (values #t 0.0)))
  (unless prewarm-ok?
    (printf "split runtime prewarm failed; log: ~a\n"
            (path->string (build-path temp-root "prewarm-split-runtime.log")))
    (exit 1))
  (when prewarm-runtime-first?
    (printf "prewarm\tok\t~a\n" (format-duration-ms prewarm-wall-ms)))
  (define phase-runtime-prewarm-row
    (if (and phase-breakdown? prewarm-runtime-first?)
        (list
         (phase-result 'runtime-prewarm
                       prewarm-ok?
                       prewarm-wall-ms
                       #f
                       #f
                       (build-path temp-root "prewarm-split-runtime.log")
                       (if provider-runtime?
                           "provider-runtime"
                           "split-runtime")
                       ""))
        '()))
  (define-values (module-bridge-prewarm-ok? module-bridge-prewarm-wall-ms)
    (if prewarm-module-bridge-first?
        (prewarm-module-bridge-cache! racket-exe
                                      temp-root
                                      provider-cache
                                      runtime-cache
                                      expected-output-regexp)
        (values #t 0.0)))
  (unless module-bridge-prewarm-ok?
    (printf "module bridge prewarm failed; log: ~a\n"
            (path->string (build-path temp-root "prewarm-module-bridge.log")))
    (exit 1))
  (when prewarm-module-bridge-first?
    (printf "module-bridge-prewarm\tok\t~a\n"
            (format-duration-ms module-bridge-prewarm-wall-ms)))
  (define phase-module-bridge-prewarm-row
    (if (and phase-breakdown? prewarm-module-bridge-first?)
        (list
         (phase-result 'module-bridge-prewarm
                       module-bridge-prewarm-ok?
                       module-bridge-prewarm-wall-ms
                       #f
                       #f
                       (build-path temp-root "prewarm-module-bridge.log")
                       "compile-cache-warm"
                       ""))
        '()))
  (when (or precompile-compiler-first?
            prewarm-staged-providers-first?
            prewarm-module-bridge-first?
            prewarm-runtime-first?)
    (newline))
  (define phase-compile-run-rows
    (if phase-breakdown?
        (append*
         (for/list ([mode (in-list (phase-modes))])
           (measure-phase-compile+run mode
                                      racket-exe
                                      node-exe
                                      temp-root
                                      provider-cache
                                      runtime-cache
                                      expected-output-regexp)))
        '()))
  (define phase-rows
    (append phase-precompile-row
            phase-startup-rows
            phase-provider-prewarm-row
            phase-runtime-prewarm-row
            phase-module-bridge-prewarm-row
            phase-compile-run-rows))
  (when phase-breakdown?
    (printf "=== Fresh Process Phase Breakdown ===\n")
    (print-phase-breakdown phase-rows)
    (for ([row (in-list phase-rows)])
      (print-phase-failure-details row))
    (newline))
  (define phase-ok?
    (andmap phase-result-ok? phase-rows))
  (when phase-breakdown-only?
    (when (and phase-ok? (not keep-temp?))
      (delete-directory/files temp-root))
    (unless phase-ok?
      (exit 1))
    (exit 0))
  (define split-cold
    (and (not prewarm-runtime-first?)
         (compile-mode 'split-cold
                       racket-exe
                       temp-root
                       provider-cache
                       runtime-cache
                       expected-output-regexp)))
  (define monolithic
    (compile-mode 'monolithic
                  racket-exe
                  temp-root
                  provider-cache
                  runtime-cache
                  expected-output-regexp))
  (define split-warm
    (compile-mode 'split-warm
                  racket-exe
                  temp-root
                  provider-cache
                  runtime-cache
                  expected-output-regexp))
  (define split-cache-reference-warm
    (and include-cache-reference?
         (compile-mode 'split-cache-reference-warm
                       racket-exe
                       temp-root
                       provider-cache
                       runtime-cache
                       expected-output-regexp)))
  (printf "mode\tstatus\twall\tdriver-total\tcompile-pipeline\tcompile\tassemble\tgenerate-runtime\tcore-cache\tprogram-wasm-mb\truntime-wasm-mb\tsplit-imports\tsplit-program-forms\tsplit-program-funcs\n")
  (define results
    (append (if split-cold (list split-cold) '())
            (list monolithic split-warm)
            (if split-cache-reference-warm
                (list split-cache-reference-warm)
                '())))
  (for ([r (in-list results)])
    (print-row r))
  (print-delta monolithic split-warm)
  (when split-cache-reference-warm
    (print-delta monolithic split-cache-reference-warm))
  (for ([r (in-list results)])
    (print-failure-details r temp-root))
  (define ok?
    (and phase-ok?
         (andmap successful-result? results)))
  (when (and ok? (not keep-temp?))
    (delete-directory/files temp-root))
  (unless ok?
    (exit 1)))

(module+ main
  (main))
