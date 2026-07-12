#lang racket/base

;;; Measure Split Runtime
;;;

;; This benchmark checks the experimental split-runtime path against the
;; monolithic compiler output on a tiny no-stdlib Node program. It first runs a
;; cold split compile to populate the stable runtime cache, then measures a
;; monolithic compile/run and a warm split compile/run against the same private
;; provider/runtime caches. With `--prewarm-runtime-first`, the runtime cache is
;; populated by the prewarm tool before any measured user compile.
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
         racket/system)


;;; Result Records

;; mode-result :
;;   symbol? boolean? boolean? boolean? real? string? string? path?
;;   (or/c real? #f) (or/c real? #f) (or/c real? #f) (or/c real? #f)
;;   (or/c real? #f) exact-nonnegative-integer? exact-nonnegative-integer?
;;   symbol? -> mode-result?
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
   split-cache-status)
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


;;; Command-Line Configuration

(define source-file default-source-file)
(define expected-output-regexp #rx"(^|\n)42(\n|$)")
(define keep-temp? #t)
(define include-cache-reference? #f)
(define prewarm-runtime-first? #f)
(define precompile-compiler-first? #f)
(define core-only? #f)

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
 [("--precompile-compiler-first")
  "Run raco make for the compiler into the isolated compiled root before measuring"
  (set! precompile-compiler-first? #t)]
 [("--split-runtime-core-only")
  "Measure the core-helper-only split runtime strategy"
  (set! core-only? #t)])


;;; Subprocess Helpers

;; ensure-executable : string? -> path?
;;   Resolve an executable from PATH or fail with a helpful error.
(define (ensure-executable name)
  (or (find-executable-path name)
      (error 'measure-split-runtime
             "required executable not found in PATH: ~a"
             name)))

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
;;   Populate the runtime cache through the standalone prewarm tool.
(define (prewarm-split-runtime-cache! racket-exe temp-root provider-cache runtime-cache)
  (define prewarm-args
    (append
     (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--mode" "split-runtime")
     (if core-only?
         '("--split-runtime-core-only")
         '())))
  (define-values (ok? stdout stderr wall-ms)
    (run-command/capture repo-root racket-exe prewarm-args))
  (write-log! (build-path temp-root "prewarm-split-runtime.log")
              stdout
              stderr)
  (values ok? wall-ms))


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

;; mode-flags : symbol? path-string? path-string? -> (listof string?)
;;   Return WebRacket flags for one benchmark mode.
(define (mode-flags mode provider-cache runtime-cache)
  (append
   '("--node" "--run" "--timings" "--no-stdlib")
   (list "--provider-cache-dir" (path->string provider-cache))
   (case mode
     [(monolithic) '("--no-split-runtime")]
     [(split-cold split-warm)
      (append
       (list "--split-runtime"
             "--runtime-provider-cache-dir"
             (path->string runtime-cache))
       (if core-only?
           '("--split-runtime-core-only")
           '()))]
     [(split-cache-reference-warm)
      (append
       (list "--split-runtime"
             "--split-runtime-cache-reference"
             "--runtime-provider-cache-dir"
             (path->string runtime-cache))
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
  (define compile-args
    (append
     (list "-S" "pkgs" "webracket.rkt")
     (mode-flags mode provider-cache runtime-cache)
     (list "--dest"
           (path->string dest-dir)
           (path->string source-file))))
  (define-values (ok? stdout stderr wall-ms)
    (run-command/capture repo-root racket-exe compile-args))
  (write-log! (build-path temp-root (format "~a.log" mode)) stdout stderr)
  (define transcript (string-append stdout "\n" stderr))
  (define program-wasm
    (generated-path dest-dir source-file ".wasm"))
  (define runtime-wasm
    (generated-path dest-dir source-file ".runtime.wasm"))
  (define expect-ok?
    (and ok?
         (or (not expect-rx)
             (regexp-match? expect-rx stdout))))
  (define split-status
    (transcript-split-cache-status transcript))
  (define cache-ok?
    (case mode
      [(split-cold) (eq? split-status 'miss-assembled)]
      [(split-warm) (eq? split-status 'wasm-hit)]
      [(split-cache-reference-warm) (eq? split-status 'wasm-reference-hit)]
      [else #t]))
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
               (file-size/zero runtime-wasm)
               split-status))


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

;; print-row : mode-result? -> void?
;;   Print one benchmark table row.
(define (print-row r)
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
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
          (format-bytes->mb (mode-result-runtime-wasm-size r))))

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
  (define racket-exe (ensure-executable "racket"))
  (ensure-executable "node")
  (define temp-root
    (make-temporary-file "webracket-split-runtime-bench-~a" 'directory))
  (define provider-cache (build-path temp-root "provider-cache"))
  (define runtime-cache  (build-path temp-root "runtime-provider-cache"))
  (define compiled-root  (build-path temp-root "compiled-root"))
  (make-directory* provider-cache)
  (make-directory* runtime-cache)
  (make-directory* compiled-root)
  (putenv "PLTCOMPILEDROOTS" (path->string compiled-root))
  (printf "Split runtime benchmark\n")
  (printf "  source:        ~a\n" (path->string source-file))
  (printf "  temp:          ~a\n" (path->string temp-root))
  (printf "  compiled root: ~a\n" (path->string compiled-root))
  (printf "  compiler warm: ~a\n"
          (if precompile-compiler-first?
              "raco make"
              "not precompiled by benchmark"))
  (printf "  split mode:    ~a\n" (if core-only? "core-only" "classified"))
  (printf "  runtime warm:  ~a\n\n"
          (if prewarm-runtime-first?
              "prewarm-staged-providers"
              "split-cold"))
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
  (when (or precompile-compiler-first? prewarm-runtime-first?)
    (newline))
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
  (printf "mode\tstatus\twall\tdriver-total\tcompile-pipeline\tcompile\tassemble\tgenerate-runtime\tcore-cache\tprogram-wasm-mb\truntime-wasm-mb\n")
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
    (andmap successful-result? results))
  (when (and ok? (not keep-temp?))
    (delete-directory/files temp-root))
  (unless ok?
    (exit 1)))

(module+ main
  (main))
