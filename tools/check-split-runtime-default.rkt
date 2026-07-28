#lang racket/base

;;; Check Split Runtime Default
;;;

;; This smoke verifies the public default policy:
;; compiling without `--split-runtime` emits and runs split-runtime
;; output, while explicit fallbacks still work. Cases are named so expensive
;; subsets can be run independently or in parallel.


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
;;   Default source used by the split-runtime default check.
(define default-source-file
  (build-path repo-root "test" "test-trivial.rkt"))

;; check-temp-dir : -> path?
;;   Return the repo-local parent for temporary check directories.
(define (check-temp-dir)
  (define dir (build-path repo-root "tmp"))
  (make-directory* dir)
  dir)


;;; Command-Line Configuration

(define source-file default-source-file)
(define extra-source-files '())
(define expected-output-regexp #rx"(^|\n)42(\n|$)")
(define keep-temp? #f)
(define list-cases? #f)
(define only-case-ids '())
(define skip-case-ids '())
(define selected-groups '())
(define jobs 1)

;; resolve-source-path : string? -> path?
;;   Resolve a user-provided source path relative to the repository root.
(define (resolve-source-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

;; positive-integer-string? : string? -> boolean?
;;   Check whether s is a positive exact integer in decimal notation.
(define (positive-integer-string? s)
  (define n (string->number s))
  (and (exact-integer? n) (positive? n)))

;; string->selector-symbol : string? -> symbol?
;;   Parse a case or group selector.
(define (string->selector-symbol s)
  (string->symbol s))

(command-line
 #:program "check-split-runtime-default"
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
 [("--jobs") n
  "Run up to N selected cases in parallel; defaults to 1."
  (unless (positive-integer-string? n)
    (raise-user-error 'check-split-runtime-default
                      "expected positive integer jobs, got ~a"
                      n))
  (set! jobs (string->number n))]
 [("--list-cases")
  "List available case IDs and groups, then exit."
  (set! list-cases? #t)]
 [("--keep-temp")
  "Keep the temporary check directory after a successful run."
  (set! keep-temp? #t)]
 #:multi
 [("--extra-source") path
  "Additional source file to compile/run under default and monolithic modes."
  (set! extra-source-files
        (append extra-source-files
                (list (resolve-source-path path))))]
 [("--only") id
  "Run only the named case; repeatable."
  (set! only-case-ids
        (append only-case-ids
                (list (string->selector-symbol id))))]
 [("--skip") id
  "Skip the named case; repeatable."
  (set! skip-case-ids
        (append skip-case-ids
                (list (string->selector-symbol id))))]
 [("--group") group
  "Run cases in the named group; repeatable. Use `all` for every case."
  (set! selected-groups
        (append selected-groups
                (list (string->selector-symbol group))))])


;;; Subprocess Helpers

;; command-result : boolean? string? string? real? -> command-result?
;;   Captured subprocess result.
(struct command-result (ok? stdout stderr wall-ms) #:transparent)

;; ensure-executable : string? -> path?
;;   Resolve an executable from PATH or fail with a helpful error.
(define (ensure-executable name)
  (or (find-executable-path name)
      (error 'check-split-runtime-default
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
;;   Persist a subprocess transcript for debugging failed checks.
(define (write-log! path exe args result)
  (call-with-output-file path
    (lambda (out)
      (fprintf out "$ ~a ~a\n\n" exe (string-join args " "))
      (fprintf out ";;; stdout\n~a" (command-result-stdout result))
      (unless (or (string=? (command-result-stdout result) "")
                  (string-suffix? (command-result-stdout result) "\n"))
        (newline out))
      (fprintf out ";;; stderr\n~a" (command-result-stderr result))
      (unless (or (string=? (command-result-stderr result) "")
                  (string-suffix? (command-result-stderr result) "\n"))
        (newline out)))
    #:exists 'truncate/replace))

;; compiled-root-env-binding : path-string? -> string?
;;   Build an environment assignment for a private compiled-file root.
(define (compiled-root-env-binding compiled-root)
  (format "PLTCOMPILEDROOTS=~a" (path->string compiled-root)))

;; racket-env-args : path-string? path-string? (listof string?) -> (listof string?)
;;   Wrap a Racket invocation with a private compiled-file root.
(define (racket-env-args compiled-root racket-exe args)
  (append (list (compiled-root-env-binding compiled-root)
                (path->string racket-exe))
          args))

;; run-racket/capture :
;;   path-string? path-string? path-string? path-string? (listof string?)
;;   -> (values command-result? path-string? (listof string?))
;;   Run Racket through env with a private compiled-file root.
(define (run-racket/capture cwd env-exe compiled-root racket-exe args)
  (define command-args (racket-env-args compiled-root racket-exe args))
  (values (run-command/capture cwd env-exe command-args)
          env-exe
          command-args))

;; precompile-compiler! : path-string? path-string? path-string? path-string? -> void?
;;   Compile the CLI into the private root before parallel child checks start.
(define (precompile-compiler! temp-root env-exe compiled-root racket-exe)
  (define args '("-S" "pkgs" "-l" "raco" "--" "make" "webracket.rkt"))
  (printf "START precompile webracket.rkt\n")
  (flush-output)
  (define-values (result command-exe command-args)
    (run-racket/capture repo-root env-exe compiled-root racket-exe args))
  (define log-path (build-path temp-root "precompile.log"))
  (write-log! log-path command-exe command-args result)
  (printf "~a precompile webracket.rkt ~as\n"
          (if (command-result-ok? result) "PASS" "FAIL")
          (real->decimal-string (/ (command-result-wall-ms result) 1000.0) 1))
  (flush-output)
  (unless (command-result-ok? result)
    (raise-user-error 'check-split-runtime-default
                      "compiler precompile failed; see ~a"
                      log-path)))

;; generated-basename : path? -> string?
;;   Return the generated output basename without an extension.
(define (generated-basename source)
  (path->string
   (path-replace-extension (file-name-from-path source) #"")))

;; wasm-magic? : path-string? -> boolean?
;;   Check whether `path` starts with the WebAssembly magic bytes.
(define (wasm-magic? path)
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (call-with-input-file path
           (lambda (in)
             (define bs (read-bytes 4 in))
             (and (bytes? bs)
                  (= (bytes-length bs) 4)
                  (bytes=? bs #"\0asm")))))))

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

;; single-valid-sidecar-failures : symbol? string? (listof path?) -> (listof string?)
;;   Return failures unless paths contains exactly one valid Wasm file.
(define (single-valid-sidecar-failures mode label paths)
  (cond
    [(not (= (length paths) 1))
     (list (format "~a produced ~a ~a wasm files, expected exactly one: ~a"
                   mode
                   (length paths)
                   label
                   paths))]
    [(not (wasm-magic? (car paths)))
     (list (format "~a did not produce a valid ~a wasm file: ~a"
                   mode
                   label
                   (car paths)))]
    [else '()]))


;;; Case Model

;; check-case :
;;   symbol? (listof symbol?) symbol? path? (listof string?) boolean? boolean?
;;   boolean? (or/c regexp? #f) -> check-case?
;;   A named compile/run or expected-failure check.
(struct check-case
  (id groups kind source extra-args split-runtime? split-ffi? run?
      expected-message)
  #:transparent)

;; check-result :
;;   symbol? (listof symbol?) boolean? real? path-string? (listof string?)
;;   -> check-result?
;;   The result of one named case.
(struct check-result (id groups ok? wall-ms log-path failures) #:transparent)

;; source-case-name : path? -> string?
;;   Derive a stable case name from a source path.
(define (source-case-name source)
  (path->string
   (path-replace-extension (file-name-from-path source) #"")))

;; case-id : symbol? path? -> symbol?
;;   Derive a stable case ID from a mode and source.
(define (case-id mode source)
  (string->symbol
   (format "~a-~a" mode (source-case-name source))))

;; valid-case : symbol? path? (listof string?) boolean?
;;              [#:split-ffi? boolean?] [#:run? boolean?] [#:groups (listof symbol?)]
;;              -> check-case?
;;   Construct a successful compile/run case.
(define (valid-case mode source extra-args split-runtime?
                    #:split-ffi? [split-ffi? #f]
                    #:run? [run? #t]
                    #:groups [groups '()])
  (check-case (case-id mode source)
              (sort (remove-duplicates (append '(valid) groups)) symbol<?)
              'valid
              source
              extra-args
              split-runtime?
              split-ffi?
              run?
              #f))

;; invalid-case : symbol? path? (listof string?) regexp? [#:groups (listof symbol?)] -> check-case?
;;   Construct an expected-failure case.
(define (invalid-case id source extra-args expected-message
                      #:groups [groups '()])
  (check-case id
              (sort (remove-duplicates (append '(invalid) groups)) symbol<?)
              'invalid
              source
              extra-args
              #f
              #f
              #f
              expected-message))

;; case-root-dir : path-string? check-case? -> path?
;;   Return a private temp root for one case.
(define (case-root-dir temp-root c)
  (build-path temp-root (symbol->string (check-case-id c))))

;; case-dest-dir : path-string? check-case? -> path?
;;   Return the generated output directory for one case.
(define (case-dest-dir temp-root c)
  (build-path (case-root-dir temp-root c) "out"))

;; case-provider-cache-dir : path-string? check-case? -> path?
;;   Return the private provider cache directory for one case.
(define (case-provider-cache-dir temp-root c)
  (build-path (case-root-dir temp-root c) "provider-cache"))

;; case-runtime-provider-cache-dir : path-string? check-case? -> path?
;;   Return the private runtime/provider cache directory for one case.
(define (case-runtime-provider-cache-dir temp-root c)
  (build-path (case-root-dir temp-root c) "runtime-provider-cache"))

;; case-log-path : path-string? check-case? -> path?
;;   Return the transcript log path for one case.
(define (case-log-path temp-root c)
  (build-path temp-root
              (format "~a.log" (check-case-id c))))

;; prepare-case-dirs! : path-string? check-case? -> void?
;;   Create private output/cache directories for a case.
(define (prepare-case-dirs! temp-root c)
  (make-directory* (case-dest-dir temp-root c))
  (make-directory* (case-provider-cache-dir temp-root c))
  (make-directory* (case-runtime-provider-cache-dir temp-root c)))


;;; Source Generation

;; write-generated-regexp-source! : path-string? -> path?
;;   Write a generated script source that demands regexp support.
(define (write-generated-regexp-source! temp-root)
  (define source-dir (build-path temp-root "sources"))
  (make-directory* source-dir)
  (define source (build-path source-dir "regexp-demand.rkt"))
  (call-with-output-file source
    (lambda (out)
      (display
       #<<RKT
(let ([m (regexp-match #rx"^a+" "aaab")])
  (if (and m (equal? (car m) "aaa"))
      42
      0))
RKT
       out))
    #:exists 'truncate/replace)
  source)

;; write-generated-standard-ffi-source! : path-string? -> path?
;;   Write a generated module source that demands standard JS FFI support.
(define (write-generated-standard-ffi-source! temp-root)
  (define source-dir (build-path temp-root "sources"))
  (make-directory* source-dir)
  (define source (build-path source-dir "standard-ffi-demand.rkt"))
  (call-with-output-file source
    (lambda (out)
      (display
       #<<RKT
#lang webracket/base

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?
                  js-number-finite?))

(unless (and (js-truthy? (js-eval "true"))
             (js-number-finite? 42.0))
  (error 'standard-ffi-demand "expected finite JS number"))

42
RKT
       out))
    #:exists 'truncate/replace)
  source)

;; write-generated-provider-runtime-provider-ffi-source! : path-string? -> path?
;;   Write a module whose provider fragment demands standard JS FFI directly.
(define (write-generated-provider-runtime-provider-ffi-source! temp-root)
  (define source-dir (build-path temp-root "sources"))
  (make-directory* source-dir)
  (define source (build-path source-dir "provider-runtime-provider-ffi-demand.rkt"))
  (call-with-output-file source
    (lambda (out)
      (display
       #<<RKT
#lang webracket/base

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?
                  js-number-finite?))

(define parsed (read (open-input-string "42")))

(unless (and (= parsed 42)
             (js-truthy? (js-eval "true"))
             (js-number-finite? 42.0))
  (error 'provider-runtime-provider-ffi-demand "expected read and FFI demand"))

42
RKT
       out))
    #:exists 'truncate/replace)
  source)

;; write-generated-provider-runtime-local-provider-ffi-source! : path-string? -> path?
;;   Write a local provider module that demands standard JS FFI.
(define (write-generated-provider-runtime-local-provider-ffi-source! temp-root)
  (define source-dir (build-path temp-root "sources" "provider-ffi"))
  (make-directory* source-dir)
  (define provider (build-path source-dir "ffi-provider.rkt"))
  (define source (build-path source-dir "provider-ffi-demand.rkt"))
  (call-with-output-file provider
    (lambda (out)
      (display
       #<<RKT
#lang webracket/base

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?
                  js-number-finite?))

(provide provider-answer)

(define provider-answer
  (if (and (js-truthy? (js-eval "true"))
           (js-number-finite? 42.0))
      42
      0))
RKT
       out))
    #:exists 'truncate/replace)
  (call-with-output-file source
    (lambda (out)
      (display
       #<<RKT
#lang webracket/base

(require "ffi-provider.rkt")

provider-answer
RKT
       out))
    #:exists 'truncate/replace)
  source)


;;; Checks

;; check-output : check-case? path-string? command-result? -> (listof string?)
;;   Return command-success and program-output failures for a valid case.
(define (check-output c log-path result)
  (define failures '())
  (unless (command-result-ok? result)
    (set! failures
          (cons (format "~a compile/run command failed; see ~a"
                        (check-case-id c)
                        log-path)
                failures)))
  (when (and (command-result-ok? result)
             (check-case-run? c)
             expected-output-regexp
             (not (regexp-match? expected-output-regexp
                                  (command-result-stdout result))))
    (set! failures
          (cons (format "~a program stdout did not match expected output regexp ~s; see ~a"
                        (check-case-id c)
                        expected-output-regexp
                        log-path)
                failures)))
  (reverse failures))

;; check-artifacts : check-case? path-string? -> (listof string?)
;;   Return generated-artifact failures for a valid case.
(define (check-artifacts c dest-dir)
  (define mode (check-case-id c))
  (define source (check-case-source c))
  (define split-runtime? (check-case-split-runtime? c))
  (define split-ffi? (check-case-split-ffi? c))
  (define base (generated-basename source))
  (define host-js (build-path dest-dir (string-append base ".js")))
  (define program-wasm (build-path dest-dir (string-append base ".wasm")))
  (define runtime-wasms (content-sidecar-paths dest-dir "webracket-runtime"))
  (define ffi-wasms (content-sidecar-paths dest-dir "webracket-ffi"))
  (define failures '())
  (unless (file-exists? host-js)
    (set! failures
          (cons (format "~a did not produce Node host: ~a" mode host-js)
                failures)))
  (unless (wasm-magic? program-wasm)
    (set! failures
          (cons (format "~a did not produce valid program wasm: ~a"
                        mode
                        program-wasm)
                failures)))
  (cond
    [split-runtime?
     (set! failures
           (append (single-valid-sidecar-failures mode
                                                  "runtime"
                                                  runtime-wasms)
                   failures))]
    [(pair? runtime-wasms)
     (set! failures
           (cons (format "~a unexpectedly produced runtime wasm files: ~a"
                         mode
                         runtime-wasms)
                 failures))])
  (cond
    [split-ffi?
     (set! failures
           (append (single-valid-sidecar-failures mode
                                                  "FFI"
                                                  ffi-wasms)
                   failures))]
    [(pair? ffi-wasms)
     (set! failures
           (cons (format "~a unexpectedly produced FFI wasm files: ~a"
                         mode
                         ffi-wasms)
                 failures))])
  (reverse failures))

;; valid-case-args : path-string? check-case? -> (listof string?)
;;   Build WebRacket CLI arguments for a valid case.
(define (valid-case-args temp-root c)
  (append
   (list "-S" "pkgs" "webracket.rkt"
         "--node")
   (if (check-case-run? c) '("--run") '())
   (list "--dest" (path->string (case-dest-dir temp-root c))
         "--provider-cache-dir"
         (path->string (case-provider-cache-dir temp-root c))
         "--runtime-provider-cache-dir"
         (path->string (case-runtime-provider-cache-dir temp-root c)))
   (check-case-extra-args c)
   (list (path->string (check-case-source c)))))

;; invalid-case-args : path-string? check-case? -> (listof string?)
;;   Build WebRacket CLI arguments for an expected-failure case.
(define (invalid-case-args temp-root c)
  (append
   (list "-S" "pkgs" "webracket.rkt"
         "--dest" (path->string (case-dest-dir temp-root c))
         "--provider-cache-dir"
         (path->string (case-provider-cache-dir temp-root c))
         "--runtime-provider-cache-dir"
         (path->string (case-runtime-provider-cache-dir temp-root c)))
   (check-case-extra-args c)
   (list (path->string (check-case-source c)))))

;; run-valid-case :
;;   path-string? path-string? path-string? path-string? check-case?
;;   -> check-result?
;;   Compile/run one successful case and check outputs.
(define (run-valid-case temp-root env-exe compiled-root racket-exe c)
  (prepare-case-dirs! temp-root c)
  (define args (valid-case-args temp-root c))
  (define-values (result command-exe command-args)
    (run-racket/capture repo-root env-exe compiled-root racket-exe args))
  (define log-path (case-log-path temp-root c))
  (write-log! log-path command-exe command-args result)
  (define failures
    (append (check-output c log-path result)
            (if (command-result-ok? result)
                (check-artifacts c (case-dest-dir temp-root c))
                '())))
  (check-result (check-case-id c)
                (check-case-groups c)
                (null? failures)
                (command-result-wall-ms result)
                log-path
                failures))

;; run-invalid-case :
;;   path-string? path-string? path-string? path-string? check-case?
;;   -> check-result?
;;   Run one expected-failure case and check the diagnostic.
(define (run-invalid-case temp-root env-exe compiled-root racket-exe c)
  (prepare-case-dirs! temp-root c)
  (define args (invalid-case-args temp-root c))
  (define-values (result command-exe command-args)
    (run-racket/capture repo-root env-exe compiled-root racket-exe args))
  (define log-path (case-log-path temp-root c))
  (write-log! log-path command-exe command-args result)
  (define failures '())
  (when (command-result-ok? result)
    (set! failures
          (cons (format "~a unexpectedly succeeded; see ~a"
                        (check-case-id c)
                        log-path)
                failures)))
  (define transcript
    (string-append (command-result-stdout result)
                   "\n"
                   (command-result-stderr result)))
  (unless (regexp-match? (check-case-expected-message c) transcript)
    (set! failures
          (cons (format "~a failure did not match expected regexp ~s; see ~a"
                        (check-case-id c)
                        (check-case-expected-message c)
                        log-path)
                failures)))
  (check-result (check-case-id c)
                (check-case-groups c)
                (null? failures)
                (command-result-wall-ms result)
                log-path
                (reverse failures)))

;; run-check-case :
;;   path-string? path-string? path-string? path-string? check-case?
;;   -> check-result?
;;   Run one case and print one progress line.
(define (run-check-case temp-root env-exe compiled-root racket-exe c)
  (printf "START ~a\n" (check-case-id c))
  (flush-output)
  (define result
    (with-handlers ([exn:fail?
                     (lambda (exn)
                       (check-result
                        (check-case-id c)
                        (check-case-groups c)
                        #f
                        0
                        (case-log-path temp-root c)
                        (list (format "~a raised ~a"
                                      (check-case-id c)
                                      (exn-message exn)))))])
      (case (check-case-kind c)
        [(valid)   (run-valid-case temp-root env-exe compiled-root racket-exe c)]
        [(invalid) (run-invalid-case temp-root env-exe compiled-root racket-exe c)]
        [else
         (error 'run-check-case
                "unknown case kind: ~a"
                (check-case-kind c))])))
  (printf "~a ~a ~as\n"
          (if (check-result-ok? result) "PASS" "FAIL")
          (check-result-id result)
          (real->decimal-string (/ (check-result-wall-ms result) 1000.0) 1))
  (flush-output)
  result)

;; run-selected-cases :
;;   (listof check-case?) path-string? path-string? path-string? path-string?
;;   exact-positive-integer? -> (listof check-result?)
;;   Run cases serially or with a bounded worker pool.
(define (run-selected-cases cases temp-root env-exe compiled-root racket-exe jobs)
  (cond
    [(or (null? cases) (= jobs 1))
     (for/list ([c (in-list cases)])
       (run-check-case temp-root env-exe compiled-root racket-exe c))]
    [else
     (define worker-limit (min jobs (length cases)))
     (define gate (make-semaphore worker-limit))
     (define result-ch (make-channel))
     (for ([c (in-list cases)])
       (thread
        (lambda ()
          (semaphore-wait gate)
          (define result
            (run-check-case temp-root env-exe compiled-root racket-exe c))
          (semaphore-post gate)
          (channel-put result-ch result))))
     (define results-by-id (make-hasheq))
     (for ([_ (in-list cases)])
       (define result (channel-get result-ch))
       (hash-set! results-by-id (check-result-id result) result))
     (for/list ([c (in-list cases)])
       (hash-ref results-by-id (check-case-id c)))]))


;;; Case Selection

;; list->eq-set : (listof symbol?) -> hasheq?
;;   Build an eq?-based set.
(define (list->eq-set xs)
  (define ht (make-hasheq))
  (for ([x (in-list xs)])
    (hash-set! ht x #t))
  ht)

;; all-case-groups : (listof check-case?) -> (listof symbol?)
;;   Return all known groups, including the synthetic `all` group.
(define (all-case-groups cases)
  (sort
   (remove-duplicates
    (cons 'all
          (append*
           (for/list ([c (in-list cases)])
             (check-case-groups c)))))
   symbol<?))

;; validate-case-ids! : symbol? (listof symbol?) hasheq? -> void?
;;   Reject unknown case IDs.
(define (validate-case-ids! who ids known-id-set)
  (for ([id (in-list ids)]
        #:unless (hash-ref known-id-set id #f))
    (raise-user-error who "unknown case id: ~a" id)))

;; validate-groups! : (listof symbol?) (listof symbol?) -> void?
;;   Reject unknown group selectors.
(define (validate-groups! groups known-groups)
  (define known-group-set (list->eq-set known-groups))
  (for ([group (in-list groups)]
        #:unless (hash-ref known-group-set group #f))
    (raise-user-error 'check-split-runtime-default
                      "unknown group: ~a"
                      group)))

;; validate-unique-case-ids! : (listof check-case?) -> void?
;;   Reject duplicate case IDs.
(define (validate-unique-case-ids! cases)
  (define seen (make-hasheq))
  (define duplicates '())
  (for ([c (in-list cases)])
    (define id (check-case-id c))
    (if (hash-ref seen id #f)
        (set! duplicates (cons id duplicates))
        (hash-set! seen id #t)))
  (unless (null? duplicates)
    (raise-user-error 'check-split-runtime-default
                      "duplicate case ids: ~a"
                      (string-join (map symbol->string
                                        (sort (remove-duplicates duplicates)
                                              symbol<?))
                                   ", "))))

;; select-cases : (listof check-case?) -> (listof check-case?)
;;   Select cases requested by --only/--group, then remove --skip cases.
(define (select-cases cases)
  (define only-set (list->eq-set only-case-ids))
  (define skip-set (list->eq-set skip-case-ids))
  (define group-set (list->eq-set selected-groups))
  (define selectors? (or (pair? only-case-ids)
                         (pair? selected-groups)))
  (for/list ([c (in-list cases)]
             #:when
             (and
              (if selectors?
                  (or (hash-ref only-set (check-case-id c) #f)
                      (hash-ref group-set 'all #f)
                      (for/or ([group (in-list (check-case-groups c))])
                        (hash-ref group-set group #f)))
                  #t)
              (not (hash-ref skip-set (check-case-id c) #f))))
    c))

;; print-case-list! : (listof check-case?) -> void?
;;   Print available cases for --only/--skip selection.
(define (print-case-list! cases)
  (printf "Available split-runtime default cases\n")
  (for ([c (in-list cases)])
    (printf "~a\tgroups=~a\tsource=~a\n"
            (check-case-id c)
            (string-join (map symbol->string (check-case-groups c)) ",")
            (check-case-source c))))


;;; Main

(define temp-root
  (build-path (check-temp-dir)
              (format "webracket-split-runtime-default-check-~a"
                      (string-replace (~a (current-inexact-milliseconds))
                                      "."
                                      ""))))
(make-directory* temp-root)

(define module-read-demand-source
  (build-path repo-root "test" "test-module-read-demand.rkt"))
(define default-source-files
  (append (list source-file
                module-read-demand-source
                (write-generated-regexp-source! temp-root))
          extra-source-files))
(define standard-ffi-source
  (write-generated-standard-ffi-source! temp-root))
(define provider-runtime-provider-ffi-source
  (write-generated-provider-runtime-provider-ffi-source! temp-root))
(define provider-runtime-local-provider-ffi-source
  (write-generated-provider-runtime-local-provider-ffi-source! temp-root))

(define default-cases
  (append*
   (for/list ([source (in-list default-source-files)])
     (list
      (valid-case 'default-split-runtime
                  source
                  '()
                  #t
                  #:groups '(default split-runtime))
      (valid-case 'explicit-monolithic
                  source
                  '("--no-split-runtime")
                  #f
                  #:groups '(default fallback monolithic))))))

(define ffi-cases
  (list
   (valid-case 'default-split-ffi
               standard-ffi-source
               '()
               #t
               #:split-ffi? #t
               #:run? #f
               #:groups '(default ffi split-ffi))
   (valid-case 'explicit-inline-ffi
               standard-ffi-source
               '("--no-split-runtime-ffi-module")
               #t
               #:run? #f
               #:groups '(fallback ffi inline))
   (valid-case 'explicit-monolithic-ffi
               standard-ffi-source
               '("--no-split-runtime")
               #f
               #:run? #f
               #:groups '(fallback ffi monolithic))))

(define provider-runtime-cases
  (list
   (valid-case 'provider-runtime-explicit-split-ffi-clean-provider
               module-read-demand-source
               '("--split-runtime-provider-runtime" "--split-runtime-ffi-module")
               #t
               #:groups '(provider-runtime))
   (valid-case 'provider-runtime-provider-ffi-with-split-ffi
               provider-runtime-provider-ffi-source
               '("--split-runtime-provider-runtime" "--split-runtime-ffi-module")
               #t
               #:split-ffi? #t
               #:groups '(ffi provider-runtime))
   (valid-case 'provider-runtime-local-provider-ffi-with-split-ffi
               provider-runtime-local-provider-ffi-source
               '("--split-runtime-provider-runtime" "--split-runtime-ffi-module")
               #t
               #:split-ffi? #t
               #:groups '(ffi provider-runtime))))

(define invalid-cases
  (list
   (invalid-case
    'invalid-cache-reference-without-split
    source-file
    '("--no-split-runtime" "--split-runtime-cache-reference")
    #rx"`--split-runtime-cache-reference` requires `--split-runtime`")
   (invalid-case
    'invalid-browser-url-without-split
    source-file
    '("--browser" "--no-split-runtime" "--split-runtime-core-url" "/runtime.wasm")
    #rx"`--split-runtime-core-url` requires `--split-runtime`")
   (invalid-case
    'invalid-explicit-split-ffi-without-split
    source-file
    '("--no-split-runtime" "--split-runtime-ffi-module")
    #rx"`--split-runtime-ffi-module` requires `--split-runtime`")))

(define all-cases
  (append default-cases
          ffi-cases
          provider-runtime-cases
          invalid-cases))

(validate-unique-case-ids! all-cases)

(define known-id-set
  (list->eq-set
   (for/list ([c (in-list all-cases)])
     (check-case-id c))))
(define known-groups (all-case-groups all-cases))
(validate-case-ids! 'check-split-runtime-default only-case-ids known-id-set)
(validate-case-ids! 'check-split-runtime-default skip-case-ids known-id-set)
(validate-groups! selected-groups known-groups)

(when list-cases?
  (print-case-list! all-cases)
  (unless keep-temp?
    (delete-directory/files temp-root))
  (exit 0))

(define selected-cases
  (select-cases all-cases))
(when (null? selected-cases)
  (raise-user-error 'check-split-runtime-default
                    "no cases selected"))

(printf "Split runtime default check\n")
(printf "  sources: ~a\n" (length default-source-files))
(for ([source (in-list default-source-files)])
  (printf "    ~a\n" source))
(printf "  ffi source: ~a\n" standard-ffi-source)
(printf "  provider-runtime provider ffi source: ~a\n"
        provider-runtime-provider-ffi-source)
(printf "  provider-runtime local provider ffi source: ~a\n"
        provider-runtime-local-provider-ffi-source)
(printf "  groups: ~a\n" (string-join (map symbol->string known-groups) ", "))
(printf "  selected: ~a cases\n" (length selected-cases))
(printf "  jobs:   ~a\n" jobs)
(printf "  temp:   ~a\n" temp-root)

(define compiled-root (build-path temp-root "compiled-root"))
(make-directory* compiled-root)
(printf "  compiled-root: ~a\n" compiled-root)

(define env-exe (ensure-executable "env"))
(define racket-exe (ensure-racket-executable))
(precompile-compiler! temp-root env-exe compiled-root racket-exe)

(define results
  (run-selected-cases selected-cases
                      temp-root
                      env-exe
                      compiled-root
                      racket-exe
                      jobs))
(define failures
  (append*
   (for/list ([result (in-list results)])
     (check-result-failures result))))

(printf "\ncase\tstatus\twall\tlog\n")
(for ([result (in-list results)])
  (printf "~a\t~a\t~as\t~a\n"
          (check-result-id result)
          (if (check-result-ok? result) "ok" "fail")
          (real->decimal-string (/ (check-result-wall-ms result) 1000.0) 1)
          (check-result-log-path result)))

(cond
  [(null? failures)
   (printf "ok: selected split runtime default cases succeeded\n")
   (unless keep-temp?
     (delete-directory/files temp-root))
   (exit 0)]
  [else
   (printf "failed: split runtime default check\n")
   (for ([failure (in-list failures)])
     (printf "  - ~a\n" failure))
   (printf "kept temp: ~a\n" temp-root)
   (exit 1)])
