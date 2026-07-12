#lang racket/base

;;; Check Split Runtime Prewarm
;;;

;; This regression-style check verifies the compile-once split-runtime workflow:
;; prewarm the stable runtime cache, then compile and run a user program whose
;; generated Node host references the cached runtime wasm directly.


;;; Imports

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         racket/system)


;;; Repository Paths

;; repo-dir : path?
;;   Absolute path to the repository root.
(define-runtime-path repo-dir "..")
(define repo-root
  (simplify-path repo-dir))

;; default-source-file : path?
;;   Default source used by the split-runtime prewarm check.
(define default-source-file
  (build-path repo-root "test" "test-trivial.rkt"))


;;; Command-Line Configuration

(define source-file default-source-file)
(define extra-source-files '())
(define expected-output-regexp #rx"(^|\n)42(\n|$)")
(define rejected-output-regexp #f)
(define suite? #f)
(define keep-temp? #f)
(define force-prewarm? #f)

;; resolve-source-path : string? -> path?
;;   Resolve a user-provided source path relative to the repository root.
(define (resolve-source-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

(command-line
 #:program "check-split-runtime-prewarm"
 #:once-each
 [("--source") path
  "Source file to compile/run; defaults to test/test-trivial.rkt."
  (set! source-file (resolve-source-path path))]
 [("--expect") pattern
  "Regular expression expected in compiler/run stdout; defaults to a line containing 42."
  (set! expected-output-regexp (regexp pattern))]
 [("--no-expect")
  "Do not validate generated program output."
  (set! expected-output-regexp #f)]
 [("--reject") pattern
  "Regular expression that must not appear in compiler/run stdout."
  (set! rejected-output-regexp (regexp pattern))]
 [("--suite")
  "Also run generated no-stdlib fixtures against the same prewarmed runtime cache."
  (set! suite? #t)]
 [("--force-prewarm")
  "Force refresh of the staged provider/runtime cache during prewarm."
  (set! force-prewarm? #t)]
 [("--keep-temp")
  "Keep the temporary check directory after a successful run."
  (set! keep-temp? #t)]
 #:multi
 [("--extra-source") path
  "Additional source file to compile/run against the same prewarmed runtime cache."
  (set! extra-source-files
        (append extra-source-files
                (list (resolve-source-path path))))])


;;; Subprocess Helpers

;; command-result : boolean? string? string? real? -> command-result?
;;   Captured subprocess result.
(struct command-result (ok? stdout stderr wall-ms) #:transparent)

;; ensure-executable : string? -> path?
;;   Resolve an executable from PATH or fail with a helpful error.
(define (ensure-executable name)
  (or (find-executable-path name)
      (error 'check-split-runtime-prewarm
             "required executable not found in PATH: ~a"
             name)))

;; run-command/capture : path-string? path-string? (listof string?) -> command-result?
;;   Run a command under `cwd`, capturing stdout/stderr and wall time in ms.
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
  (command-result ok?
                  (get-output-string out)
                  (get-output-string err)
                  (- end-ms start-ms)))

;; write-log! : path-string? path-string? (listof string?) command-result? -> void?
;;   Save a command transcript for later inspection.
(define (write-log! path exe args result)
  (call-with-output-file path
    (lambda (out)
      (fprintf out "$ ~a\n\n"
               (string-join (cons (path->string exe) args) " "))
      (displayln ";;; stdout" out)
      (display (command-result-stdout result) out)
      (unless (or (string=? (command-result-stdout result) "")
                  (string-suffix? (command-result-stdout result) "\n"))
        (newline out))
      (displayln ";;; stderr" out)
      (display (command-result-stderr result) out))
    #:exists 'truncate/replace))


;;; Artifact Helpers

;; generated-path : path-string? path? string? -> path?
;;   Return a generated artifact path in `dest-dir`.
(define (generated-path dest-dir source ext)
  (build-path dest-dir
              (path-replace-extension (file-name-from-path source) ext)))

;; cached-runtime-wasm-files : path-string? -> (listof path?)
;;   Return non-lock runtime wasm files in the stable split-runtime cache.
(define (cached-runtime-wasm-files runtime-cache)
  (define cache-root
    (build-path runtime-cache "split-runtime-core-v3"))
  (if (directory-exists? cache-root)
      (find-files
       (lambda (p)
         (and (file-exists? p)
              (equal? (path-get-extension p) #".wasm")
              (not (regexp-match? #rx"^\\.LOCK"
                                  (path->string (file-name-from-path p))))))
       cache-root)
      '()))

;; transcript-contains? : command-result? regexp? -> boolean?
;;   Check stdout and stderr for a regexp.
(define (transcript-contains? result rx)
  (regexp-match? rx
                 (string-append (command-result-stdout result)
                                "\n"
                                (command-result-stderr result))))

;; format-seconds : real? -> string?
;;   Format milliseconds as seconds.
(define (format-seconds ms)
  (~r (/ ms 1000.0) #:precision '(= 1)))

;; check-case : string? path? (or/c regexp? #f) (or/c regexp? #f) -> check-case?
;;   One source program compiled against the prewarmed split runtime cache.
(struct check-case (name source expect reject) #:transparent)

;; safe-case-name : string? -> string?
;;   Keep generated directories and logs readable.
(define (safe-case-name s)
  (regexp-replace* #rx"[^A-Za-z0-9_.-]" s "_"))

;; source-case-name : path? -> string?
;;   Derive a stable case name from a source path.
(define (source-case-name source)
  (safe-case-name
   (path->string (path-replace-extension (file-name-from-path source) #""))))

;; write-generated-case! :
;;   path-string? string? string? (or/c regexp? #f) (or/c regexp? #f) -> check-case?
;;   Write a generated suite source under `source-dir`.
(define (write-generated-case! source-dir name body expect reject)
  (define source
    (build-path source-dir (format "~a.rkt" name)))
  (call-with-output-file source
    (lambda (out)
      (display body out)
      (unless (string-suffix? body "\n")
        (newline out)))
    #:exists 'truncate/replace)
  (check-case name source expect reject))

;; generated-suite-cases :
;;   path-string? (or/c regexp? #f) (or/c regexp? #f) -> (listof check-case?)
;;   Build small no-stdlib programs that exercise several program/runtime edges.
(define (generated-suite-cases temp-root expect reject)
  (define source-dir
    (build-path temp-root "sources"))
  (make-directory* source-dir)
  (list
   (write-generated-case!
    source-dir
    "mixed-values"
    #<<RKT
(let* ([f (lambda (p v . rest)
            (if (string? (car rest))
                (+ (car p) (vector-ref v 1))
                0))]
       [p (cons 40 0)]
       [v (vector 0 2)])
  (f p v "cached-runtime"))
RKT
    expect
    reject)
   (write-generated-case!
    source-dir
    "vector-mutation"
    #<<RKT
(let ([v (vector 40 0)])
  (vector-set! v 1 2)
  (+ (vector-ref v 0) (vector-ref v 1)))
RKT
    expect
    reject)))

;; record-failure! : string? any/c ... -> void?
;;   Accumulate a formatted check failure.
(define failures '())
(define (record-failure! fmt . args)
  (set! failures (cons (apply format fmt args) failures)))

;; compile-case! :
;;   check-case? exact-positive-integer? path-string? path-string? path-string?
;;   path-string? path-string? -> command-result?
;;   Compile/run one source by directly referencing the prewarmed runtime wasm.
(define (compile-case! case index racket-exe provider-cache runtime-cache dest-root temp-root)
  (define case-name
    (safe-case-name (check-case-name case)))
  (define dest-dir
    (build-path dest-root (format "~a-~a" index case-name)))
  (make-directory* dest-dir)
  (define compile-args
    (list "-S" "pkgs" "webracket.rkt"
          "--node" "--run" "--timings"
          "--split-runtime"
          "--split-runtime-cache-reference"
          "--no-stdlib"
          "--provider-cache-dir" (path->string provider-cache)
          "--runtime-provider-cache-dir" (path->string runtime-cache)
          "--dest" (path->string dest-dir)
          (path->string (check-case-source case))))
  (define compile-result
    (run-command/capture repo-root racket-exe compile-args))
  (define compile-log
    (build-path temp-root (format "compile-~a-~a.log" index case-name)))
  (write-log! compile-log racket-exe compile-args compile-result)

  (unless (command-result-ok? compile-result)
    (record-failure! "~a: compile/run command failed; see ~a"
                     (check-case-name case)
                     compile-log))
  (when (and (check-case-expect case)
             (not (regexp-match? (check-case-expect case)
                                 (command-result-stdout compile-result))))
    (record-failure! "~a: stdout did not match expected output regexp ~s"
                     (check-case-name case)
                     (check-case-expect case)))
  (when (and (check-case-reject case)
             (regexp-match? (check-case-reject case)
                            (command-result-stdout compile-result)))
    (record-failure! "~a: stdout matched rejected output regexp ~s"
                     (check-case-name case)
                     (check-case-reject case)))
  (unless (transcript-contains? compile-result
                                #rx"split-runtime-core:reference-wasm-hit")
    (record-failure! "~a: did not report split-runtime-core:reference-wasm-hit"
                     (check-case-name case)))
  (when (transcript-contains? compile-result
                              #rx"split-runtime-core:assemble-wasm")
    (record-failure! "~a: assembled the split runtime instead of using the cache"
                     (check-case-name case)))
  (when (transcript-contains? compile-result
                              #rx"split-runtime-core:materialize-wasm-hit")
    (record-failure! "~a: materialized a runtime wasm sidecar instead of referencing cache"
                     (check-case-name case)))

  (define program-wasm
    (generated-path dest-dir (check-case-source case) ".wasm"))
  (define runtime-sidecar-wasm
    (generated-path dest-dir (check-case-source case) ".runtime.wasm"))
  (unless (file-exists? program-wasm)
    (record-failure! "~a: did not produce program wasm: ~a"
                     (check-case-name case)
                     program-wasm))
  (when (file-exists? runtime-sidecar-wasm)
    (record-failure! "~a: cache-reference compile unexpectedly produced runtime sidecar: ~a"
                     (check-case-name case)
                     runtime-sidecar-wasm))
  compile-result)


;;; Main Check

;; run-check! : -> void?
;;   Prewarm the split-runtime cache, compile/run a program by cache reference,
;;   and validate the observed cache behavior.
(define (run-check!)
  (define racket-exe (ensure-executable "racket"))
  (ensure-executable "node")
  (define temp-root
    (make-temporary-file "webracket-split-runtime-prewarm-check-~a" 'directory))
  (define provider-cache (build-path temp-root "provider-cache"))
  (define runtime-cache  (build-path temp-root "runtime-provider-cache"))
  (define compiled-root  (build-path temp-root "compiled-root"))
  (define dest-dir       (build-path temp-root "dest"))
  (make-directory* provider-cache)
  (make-directory* runtime-cache)
  (make-directory* compiled-root)
  (make-directory* dest-dir)
  (putenv "PLTCOMPILEDROOTS" (path->string compiled-root))

  (printf "Split runtime prewarm check\n")
  (define source-files
    (cons source-file extra-source-files))
  (define cases
    (append
     (for/list ([source (in-list source-files)])
       (check-case (source-case-name source)
                   source
                   expected-output-regexp
                   rejected-output-regexp))
     (if suite?
         (generated-suite-cases temp-root
                                expected-output-regexp
                                rejected-output-regexp)
         '())))
  (for ([case (in-list cases)])
    (unless (file-exists? (check-case-source case))
      (error 'check-split-runtime-prewarm
             "source file does not exist: ~a"
             (check-case-source case))))

  (printf "  sources:       ~a\n" (length cases))
  (for ([case (in-list cases)])
    (printf "    ~a: ~a\n"
            (check-case-name case)
            (path->string (check-case-source case))))
  (printf "  temp:          ~a\n" (path->string temp-root))
  (printf "  compiled root: ~a\n\n" (path->string compiled-root))

  (define prewarm-args
    (append
     (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--mode" "split-runtime")
     (if force-prewarm? '("--force") '())))
  (define prewarm-result
    (run-command/capture repo-root racket-exe prewarm-args))
  (define prewarm-log (build-path temp-root "prewarm.log"))
  (write-log! prewarm-log racket-exe prewarm-args prewarm-result)

  (unless (command-result-ok? prewarm-result)
    (record-failure! "prewarm command failed; see ~a" prewarm-log))

  (define cached-wasms-after-prewarm
    (cached-runtime-wasm-files runtime-cache))
  (when (null? cached-wasms-after-prewarm)
    (record-failure! "prewarm did not create a cached split-runtime wasm in ~a"
                     runtime-cache))

  (define compile-results
    (for/list ([case (in-list cases)]
               [index (in-naturals 1)])
      (compile-case! case
                     index
                     racket-exe
                     provider-cache
                     runtime-cache
                     dest-dir
                     temp-root)))

  (cond
    [(null? failures)
     (printf "ok: prewarm=~as compile/runs=[~a] cached-runtime-wasms=~a\n"
             (format-seconds (command-result-wall-ms prewarm-result))
             (string-join
              (for/list ([result (in-list compile-results)])
                (format "~as" (format-seconds (command-result-wall-ms result))))
              ", ")
             (length cached-wasms-after-prewarm))
     (when keep-temp?
       (printf "kept temp: ~a\n" (path->string temp-root)))
     (unless keep-temp?
       (delete-directory/files temp-root))]
    [else
     (printf "failed: split runtime prewarm check\n")
     (for ([failure (in-list (reverse failures))])
       (printf "  - ~a\n" failure))
     (printf "kept temp: ~a\n" (path->string temp-root))
     (exit 1)]))

(module+ main
  (run-check!))
