#lang racket/base

;;; Measure Simplify Module Builds
;;;

;; This benchmark measures module-example builds with and without the compiler
;; simplify pass. It is aimed at module-mode performance work, where we need to
;; compare driver totals, compiler pass timings, node counts, and simplify
;; profile counters on browser-style module inputs.
;;
;; Invoke it from the repository root:
;;
;;   racket tools/measure-simplify-module-builds.rkt [--tsv] [example ...]
;;
;; The tool precompiles `webracket.rkt` in an isolated compiled root, warms each
;; mode once, reruns the measured compile, then prints a compact table and
;; optional TSV rows.


;;; Imports

;; The benchmark uses subprocess capture, isolated toolchain environments,
;; transcript parsing, and table/TSV formatting.

(require racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system)


;;; Result Records

;; These structs carry parsed timing/profile metrics and the source example
;; configuration used for each measured run.

;; mode-result : string? hash? string? string? -> mode-result?
;;   Collected timing/profile summary for one example and simplify mode.
(struct mode-result (mode metrics result output)
  #:transparent)

;; example-config : string? path? -> example-config?
;;   One module example to compile and compare.
(struct example-config (name source)
  #:transparent)


;;; Repository And Defaults

;; Runtime paths and default examples keep the benchmark usable without
;; command-line arguments.

(define-runtime-path repo-root "..")

(define default-example-paths
  (list (build-path repo-root "pkgs" "web-easy" "examples" "hello-world" "hello-world.rkt")
        (build-path repo-root "pkgs" "web-easy" "examples" "single-counter" "single-counter.rkt")))


;;; Toolchain Selection

;; These helpers prefer the sibling local Racket checkout when present, so the
;; benchmark can match the pinned toolchain used by larger WebRacket probes.

;; maybe-local-racket-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-racket-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "racket")))
  (and (file-exists? p) p))

;; maybe-local-raco-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-raco-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "raco")))
  (and (file-exists? p) p))

;; racket-path : path?
;;   Pick one Racket executable for the whole run.
(define racket-path
  (or (maybe-local-racket-path)
      (find-executable-path "racket")))

;; raco-path : path?
;;   Pick one `raco` executable for the whole run.
(define raco-path
  (or (maybe-local-raco-path)
      (find-executable-path "raco")))

;; collects-root : path?
;;   Derive the matching collects root for the selected toolchain.
(define collects-root
  (cond
    [(maybe-local-racket-path)
     (simplify-path
      (build-path repo-root 'up "racket" "racket" "collects"))]
    [else
     (find-system-path 'collects-dir)]))

;; fail! : string? -> none
;;   Abort with a helpful message.
(define (fail! msg)
  (error 'measure-simplify-module-builds "~a" msg))

(unless racket-path
  (fail! "could not find a Racket executable"))

(unless raco-path
  (fail! "could not find a raco executable"))


;;; Temporary Environment

;; This section creates isolated temporary directories and subprocess
;; environments so benchmark results are not polluted by stale compiled files.

;; make-temp-dir : string? -> path?
;;   Create a fresh temporary directory for one measurement run.
(define (make-temp-dir template)
  (make-temporary-file template 'directory))

;; build-env : path? -> environment-variables?
;;   Construct a pinned subprocess environment for compiler checks.
(define (build-env compiled-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (environment-variables-set!
   env
   #"PLTCOLLECTS"
   (string->bytes/utf-8
    (format "~a:~a"
            (path->string (build-path repo-root "pkgs"))
            (path->string collects-root))))
  (environment-variables-set!
   env
   #"PLTCOMPILEDROOTS"
   (string->bytes/utf-8 (path->string compiled-root)))
  env)


;;; Subprocess Helpers

;; Subprocess helpers capture combined stdout/stderr, enforce timeouts, and
;; precompile the WebRacket driver before benchmarked runs.

;; run/collect : path? (listof string?) path? environment-variables? exact-positive-integer? -> values
;;   Run one subprocess and capture stdout/stderr together.
(define (run/collect exe args cwd env timeout-seconds)
  (parameterize ([current-directory cwd]
                 [current-environment-variables env])
    (define-values (proc out in err)
      (apply subprocess #f #f #f (path->string exe) args))
    (close-output-port in)
    (define out-ch (make-channel))
    (define err-ch (make-channel))
    (thread (lambda ()
              (channel-put
               out-ch
               (with-handlers ([exn:fail? (lambda (_e) "")])
                 (port->string out)))))
    (thread (lambda ()
              (channel-put
               err-ch
               (with-handlers ([exn:fail? (lambda (_e) "")])
                 (port->string err)))))
    (define done? (sync/timeout timeout-seconds proc))
    (unless done?
      (subprocess-kill proc #t)
      (sync proc)
      (fail! (format "subprocess timed out: ~a" args)))
    (subprocess-wait proc)
    (values (subprocess-status proc)
            (string-append (channel-get out-ch)
                           (channel-get err-ch)))))

;; precompile-webracket! : environment-variables? -> void
;;   Build `webracket.rkt` once under the isolated compiled-root environment.
(define (precompile-webracket! env)
  (define-values (status output)
    (run/collect raco-path
                 (list "make" "webracket.rkt")
                 repo-root
                 env
                 300))
  (unless (zero? status)
    (fail! (format "precompile failed\n~a" output))))


;;; Transcript Parsing

;; These helpers extract numeric timing, node-count, and simplify-profile data
;; from the compiler transcript.

;; safe-string->number : string? -> (or/c number? #f)
;;   Convert s to a number after trimming it.
(define (safe-string->number s)
  (string->number (string-trim s)))

;; maybe-first-timing-number : string? string? -> (or/c number? #f)
;;   Extract the first numeric token after `key:` from a timing-table row.
(define (maybe-first-timing-number line key)
  (define trimmed (string-trim line))
  (define prefix (string-append key))
  (and (string-prefix? trimmed prefix)
       (let ([parts (string-split trimmed ":" #:trim? #f)])
         (and (= (length parts) 2)
              (let* ([rhs (string-trim (cadr parts))]
                     [fields (string-split rhs)])
                (and (pair? fields)
                     (safe-string->number (car fields))))))))

;; maybe-last-node-count : string? string? -> (or/c exact-nonnegative-integer? #f)
;;   Extract the final node-count token from a pass-timings row.
(define (maybe-last-node-count line key)
  (define trimmed (string-trim line))
  (and (string-prefix? trimmed key)
       (let ([parts (string-split trimmed ":" #:trim? #f)])
         (and (= (length parts) 2)
              (let* ([rhs (string-trim (cadr parts))]
                     [fields (string-split rhs)]
                     [last-field (and (pair? fields) (last fields))]
                     [n (and last-field (safe-string->number last-field))])
                (and (exact-integer? n)
                     (>= n 0)
                     n))))))

;; timing-number : string? string? -> (or/c number? #f)
;;   Extract one timing value from any timing table row.
(define (timing-number output key)
  (for/or ([line (in-list (string-split output "\n"))])
    (maybe-first-timing-number line key)))

;; node-count : string? string? -> (or/c exact-nonnegative-integer? #f)
;;   Extract one node count from the pass-timings table.
(define (node-count output key)
  (for/or ([line (in-list (string-split output "\n"))])
    (maybe-last-node-count line key)))

;; profile-number : string? string? -> (or/c number? #f)
;;   Extract a numeric simplify-profile counter from the transcript.
(define (profile-number output key)
  (for/or ([line (in-list (string-split output "\n"))])
    (define fields
      (string-split (string-trim line) "\t"))
    (and (= (length fields) 2)
         (string=? (car fields) key)
         (safe-string->number (cadr fields)))))

;; collect-metrics : string? symbol? -> hash?
;;   Parse the timing/profile metrics we care about from one compile transcript.
(define (collect-metrics output mode)
  (define parse-nodes
    (node-count output "parse"))
  (define simplified-nodes
    (or (profile-number output "output-nodes")
        parse-nodes))
  (hash 'driver-total              (timing-number output "total")
        'compile-pipeline         (timing-number output "compile-pipeline")
        'parse-nodes              parse-nodes
        'simplified-nodes         simplified-nodes
        'nodes-removed            (or (profile-number output "nodes-removed")
                                      (and parse-nodes simplified-nodes
                                           (- parse-nodes simplified-nodes))
                                      0)
        'simplify-LFE             (timing-number output "simplify-LFE")
        'lower-letrec-values      (timing-number output "lower-letrec-values")
        'closure-conversion       (timing-number output "closure-conversion")
        'generate-code            (timing-number output "generate-code")
        'free-var-summary-root-ms (profile-number output "free-var-summary-root-ms")
        'result                   (if (eq? mode 'simplify) "ok" "ok")))


;;; Compile Runs

;; Compile-run helpers construct WebRacket command lines, warm a mode, and then
;; collect the measured transcript for that same mode.

;; compile-args : path? path? path? boolean? -> (listof string?)
;;   Construct one webracket compile command.
(define (compile-args source dest provider-cache-dir simplify?)
  (append
   (list (path->string (build-path repo-root "webracket.rkt"))
         "--browser"
         "--dest" (path->string dest)
         "--timings"
         "--provider-cache-dir" (path->string provider-cache-dir))
   (if simplify?
       (list "--enable-simplify" "--simplify-profile")
       '())
   (list (path->string source))))

;; run-mode : example-config? symbol? path? environment-variables? -> mode-result?
;;   Warm one mode once, then rerun and capture the measured transcript.
(define (run-mode example mode temp-root env)
  (define simplify?
    (eq? mode 'simplify))
  (define example-root
    (build-path temp-root (example-config-name example)))
  (define provider-cache-dir
    (build-path example-root "provider-cache"))
  (define warm-dest
    (build-path example-root
                (format "~a-warm" (symbol->string mode))))
  (define measured-dest
    (build-path example-root
                (format "~a-measured" (symbol->string mode))))
  (make-directory* provider-cache-dir)
  (make-directory* warm-dest)
  (make-directory* measured-dest)
  (define warm-args
    (compile-args (example-config-source example) warm-dest provider-cache-dir simplify?))
  (define-values (warm-status warm-output)
    (run/collect racket-path warm-args repo-root env 600))
  (unless (zero? warm-status)
    (fail! (format "warmup failed for ~a ~a\n~a"
                   (example-config-name example)
                   mode
                   warm-output)))
  (define measured-args
    (compile-args (example-config-source example) measured-dest provider-cache-dir simplify?))
  (define-values (status output)
    (run/collect racket-path measured-args repo-root env 600))
  (unless (zero? status)
    (fail! (format "measured run failed for ~a ~a\n~a"
                   (example-config-name example)
                   mode
                   output)))
  (mode-result (symbol->string mode)
               (collect-metrics output mode)
               "ok"
               output))


;;; Example Selection

;; Example selection accepts explicit paths or the built-in short names derived
;; from the default example paths.

;; metric-ref : mode-result? symbol? -> any/c
;;   Look up one parsed metric from a mode result.
(define (metric-ref result key)
  (hash-ref (mode-result-metrics result) key #f))

;; example-name-from-path : path-string? -> string?
;;   Derive a stable human-readable label from the example path.
(define (example-name-from-path p)
  (path->string
   (let-values ([(base name dir?) (split-path (path-only p))])
     name)))

;; resolve-example-arg : string? -> example-config?
;;   Accept either an explicit path or one of the built-in short names.
(define (resolve-example-arg arg)
  (define maybe-path
    (if (absolute-path? (string->path arg))
        (string->path arg)
        (build-path repo-root arg)))
  (cond
    [(file-exists? maybe-path)
     (example-config (example-name-from-path maybe-path)
                     (simplify-path maybe-path))]
    [else
     (match (findf (λ (p)
                     (string=? (example-name-from-path p) arg))
                   default-example-paths)
       [#f
        (fail! (format "unknown example or missing path: ~a" arg))]
       [p
        (example-config (example-name-from-path p)
                        p)])]))


;;; Reporting

;; Reporting can emit human-readable comparison tables and machine-readable TSV
;; rows for longer benchmark tracking.

;; maybe-number->string : any/c -> string?
;;   Render numeric metrics consistently for tables and TSV.
(define (maybe-number->string v)
  (cond
    [(number? v) (~a v)]
    [else "n/a"]))

;; emit-row : output-port? (listof string?) -> void
;;   Emit one TSV row.
(define (emit-row out fields)
  (displayln (string-join fields "\t") out))

;; print-results-tsv : output-port? example-config? mode-result? mode-result? -> void
;;   Emit baseline, simplify, and delta rows in TSV format.
(define (print-results-tsv out example baseline simplify)
  (define example-name (example-config-name example))
  (define keys
    '(driver-total
      compile-pipeline
      parse-nodes
      simplified-nodes
      nodes-removed
      simplify-LFE
      lower-letrec-values
      closure-conversion
      generate-code
      free-var-summary-root-ms))
  (define (mode-row label result)
    (append (list example-name
                  label)
            (for/list ([key (in-list keys)])
              (maybe-number->string (metric-ref result key)))
            (list (mode-result-result result))))
  (define (delta-row)
    (define (delta key)
      (define a (metric-ref baseline key))
      (define b (metric-ref simplify key))
      (if (and (number? a) (number? b))
          (- b a)
          #f))
    (list example-name
          "delta"
          (maybe-number->string (delta 'driver-total))
          (maybe-number->string (delta 'compile-pipeline))
          "n/a"
          "n/a"
          "n/a"
          "n/a"
          (maybe-number->string (delta 'lower-letrec-values))
          (maybe-number->string (delta 'closure-conversion))
          (maybe-number->string (delta 'generate-code))
          "n/a"
          "ok"
          (maybe-number->string (delta 'driver-total))
          (maybe-number->string (delta 'compile-pipeline))
          (maybe-number->string (delta 'lower-letrec-values))
          (maybe-number->string (delta 'closure-conversion))
          (maybe-number->string (delta 'generate-code))))
  (emit-row out
            (append
             (mode-row "baseline" baseline)
             (list "n/a" "n/a" "n/a" "n/a" "n/a")))
  (emit-row out
            (append
             (mode-row "simplify" simplify)
             (list "n/a" "n/a" "n/a" "n/a" "n/a")))
  (emit-row out (delta-row)))

;; print-results-table : example-config? mode-result? mode-result? -> void
;;   Print a compact comparison table for one example.
(define (print-results-table example baseline simplify)
  (define example-name (example-config-name example))
  (define (delta key)
    (define a (metric-ref baseline key))
    (define b (metric-ref simplify key))
    (and (number? a) (number? b) (- b a)))
  (printf "~a\n" example-name)
  (printf "  baseline: driver ~a, pipeline ~a, parse-nodes ~a\n"
          (maybe-number->string (metric-ref baseline 'driver-total))
          (maybe-number->string (metric-ref baseline 'compile-pipeline))
          (maybe-number->string (metric-ref baseline 'parse-nodes)))
  (printf "  simplify: driver ~a, pipeline ~a, simplified-nodes ~a, nodes-removed ~a, simplify-LFE ~a\n"
          (maybe-number->string (metric-ref simplify 'driver-total))
          (maybe-number->string (metric-ref simplify 'compile-pipeline))
          (maybe-number->string (metric-ref simplify 'simplified-nodes))
          (maybe-number->string (metric-ref simplify 'nodes-removed))
          (maybe-number->string (metric-ref simplify 'simplify-LFE)))
  (printf "  deltas: driver ~a, pipeline ~a, lower-letrec ~a, closure ~a, generate-code ~a\n"
          (maybe-number->string (delta 'driver-total))
          (maybe-number->string (delta 'compile-pipeline))
          (maybe-number->string (delta 'lower-letrec-values))
          (maybe-number->string (delta 'closure-conversion))
          (maybe-number->string (delta 'generate-code)))
  (printf "  free-var-summary-root-ms: ~a\n"
          (maybe-number->string (metric-ref simplify 'free-var-summary-root-ms)))
  (newline))


;;; Command-Line Entry Point

;; The main body parses flags, prepares the isolated environment, runs each
;; selected example in baseline and simplify modes, and prints the results.

;; parse-args : (listof string?) -> values
;;   Parse optional tool flags and example-path arguments.
(define (parse-args argv)
  (let loop ([args argv] [emit-tsv? #f] [example-args '()])
    (match args
      ['()
       (values emit-tsv? (reverse example-args))]
      [(list "--tsv" rest ...)
       (loop rest #t example-args)]
      [(list "--help")
       (displayln "usage: racket tools/measure-simplify-module-builds.rkt [--tsv] [example-path-or-name ...]")
       (exit 0)]
      [(list arg rest ...)
       (loop rest emit-tsv? (cons arg example-args))])))

(module+ main
  (define-values (emit-tsv? example-args)
    (parse-args (vector->list (current-command-line-arguments))))
  (define selected-examples
    (if (null? example-args)
        (map (λ (p) (example-config (example-name-from-path p) p))
             default-example-paths)
        (map resolve-example-arg example-args)))
  (define temp-root
    (make-temp-dir "webracket-simplify-module-builds~a"))
  (define compiled-root
    (build-path temp-root "compiled"))
  (make-directory* compiled-root)
  (define env
    (build-env compiled-root))
  (precompile-webracket! env)
  (when emit-tsv?
    (emit-row (current-output-port)
              '("example"
                "mode"
                "driver-total"
                "compile-pipeline"
                "parse-nodes"
                "simplified-nodes"
                "nodes-removed"
                "simplify-LFE"
                "lower-letrec-values"
                "closure-conversion"
                "generate-code"
                "free-var-summary-root-ms"
                "result"
                "driver-delta"
                "compile-pipeline-delta"
                "lower-letrec-delta"
                "closure-delta"
                "generate-code-delta")))
  (for ([example (in-list selected-examples)])
    (define baseline
      (run-mode example 'baseline temp-root env))
    (define simplify
      (run-mode example 'simplify temp-root env))
    (print-results-table example baseline simplify)
    (when emit-tsv?
      (print-results-tsv (current-output-port) example baseline simplify))
    (flush-output)))
