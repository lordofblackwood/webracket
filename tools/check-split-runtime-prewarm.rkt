#lang racket/base

;;; Check Split Runtime Prewarm
;;;

;; This regression-style check verifies the compile-once split-runtime workflow:
;; prewarm the stable runtime cache, then compile and run user programs whose
;; generated Node hosts either reference the cached runtime wasm directly or
;; materialize a warm runtime sidecar next to the program wasm.


;;; Imports

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/split-runtime-cache.rkt"
                  split-runtime-boundary-cache-current?
                  split-runtime-core-cache-directory
                  split-runtime-core-cache-key-fingerprint
                  split-runtime-core-cache-wasm-path
                  split-runtime-request-cache-fingerprint
                  make-split-runtime-core-cache-key
                  make-split-runtime-core-only-cache-key)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/runtime-source.rkt"
                  runtime-source-fingerprint)
         "../pkgs/webracket-lib/compiler/cli-lib.rkt")


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
(define rejected-output-regexp #f)
(define suite? #f)
(define keep-temp? #f)
(define force-prewarm? #f)
(define core-only? #f)
(define provider-runtime? #f)
(define in-process? #f)
(define compile-server? #f)
(define staged-provider-prewarm? #f)
(define module-bridge-result-cache-check? #f)
(define precompile-compiler? #f)
(define isolate-compiled-root? #f)
(define frontend-cache? #f)
(define sidecar-check? #t)
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
 [("--prewarm-staged-providers")
  "Prewarm staged regexp/read/io-format provider caches before runtime prewarm."
  (set! staged-provider-prewarm? #t)]
 [("--check-module-bridge-result-cache")
  "Compile module sources once to warm the module-bridge result cache, then require cache hits."
  (set! module-bridge-result-cache-check? #t)]
 [("--precompile-compiler")
  "Run raco make for the compiler/tool entry points in the private compiled root before measuring."
  (set! precompile-compiler? #t)]
 [("--isolate-compiled-root")
  "Run subprocesses with a private PLTCOMPILEDROOTS; useful for cold-root checks."
  (set! isolate-compiled-root? #t)]
 [("--split-runtime-core-only")
  "Use the core-helper-only split runtime strategy for prewarm and compile."
  (set! core-only? #t)]
 [("--split-runtime-provider-runtime")
  "For module sources, prewarm/check the provider-fragment-in-runtime split path."
  (set! provider-runtime? #t)]
 [("--frontend-cache")
  "Pass --frontend-cache to post-prewarm compiles."
  (set! frontend-cache? #t)]
 [("--no-sidecar-check")
  "Skip warm sidecar compile/run checks; only check cache-reference output."
  (set! sidecar-check? #f)]
 [("--keep-temp")
  "Keep the temporary check directory after a successful run."
  (set! keep-temp? #t)]
 [("--in-process")
  "Compile/run cases in this Racket process after prewarm; serial warm-compiler check."
  (set! in-process? #t)]
 [("--compile-server")
  "Compile/run cases through the local WebRacket compile server client."
  (set! compile-server? #t)]
 [("--jobs") n
  "Compile/run up to N cases in parallel after prewarm; defaults to 1."
  (unless (positive-integer-string? n)
    (raise-user-error 'check-split-runtime-prewarm
                      "expected positive integer jobs, got ~a"
                      n))
  (set! jobs (string->number n))]
 #:multi
 [("--extra-source") path
  "Additional source file to compile/run against the same prewarmed runtime cache."
  (set! extra-source-files
        (append extra-source-files
                (list (resolve-source-path path))))])

(when (and in-process? compile-server?)
  (raise-user-error 'check-split-runtime-prewarm
                    "use --in-process or --compile-server, not both"))

(when (and provider-runtime? core-only?)
  (raise-user-error 'check-split-runtime-prewarm
                    "use --split-runtime-provider-runtime or --split-runtime-core-only, not both"))


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

;; compile-config-from-args : (listof string?) -> webracket-compile-config?
;;   Parse a WebRacket compiler config from ordinary user-facing CLI arguments.
(define (compile-config-from-args args)
  (parameterize ([current-command-line-arguments (list->vector args)])
    (match (parse-webracket-cli)
      [(webracket-cli-command 'compile cfg) cfg]
      [command
       (error 'check-split-runtime-prewarm
              "expected compile command, got: ~a"
              (webracket-cli-command-kind command))])))

;; run-compile-in-process/capture : (listof string?) -> command-result?
;;   Run one compile in the current Racket process while capturing output.
(define (run-compile-in-process/capture args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define start-ms (current-inexact-milliseconds))
  (define-values (ok? maybe-exn)
    (with-handlers ([exn:fail?
                     (lambda (exn)
                       (values #f exn))])
      (parameterize ([current-directory repo-root]
                     [current-output-port out]
                     [current-error-port err])
        (define cfg (compile-config-from-args args))
        (define-values (exit-code _compile-timings _output-paths)
          (run-webracket-compile cfg))
        (values (zero? exit-code) #f))))
  (when maybe-exn
    (displayln (exn-message maybe-exn) err))
  (define end-ms (current-inexact-milliseconds))
  (command-result ok?
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
;;   path-string? path-string? (listof string?) -> command-result?
;;   Run one compile through `webracket.rkt` with WEBRACKET_COMPILE_SERVER enabled.
(define (run-compile-server/capture cwd racket-exe args)
  (call-with-compile-server-env
   (lambda ()
     (run-command/capture cwd
                          racket-exe
                          (append (list "-S" "pkgs" "webracket.rkt")
                                  args)))))

;; run-webracket-compile-args/capture :
;;   path-string? path-string? (listof string?) -> command-result?
;;   Run one WebRacket compile using the selected checker runner.
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
    [else "fresh subprocess"]))

;; compile-runner-serial? : -> boolean?
;;   Check whether the selected runner should avoid parallel case dispatch.
(define (compile-runner-serial?)
  (or in-process? compile-server?))

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

;; executable-label : path-string? -> string?
;;   Format a path or synthetic runner name for command transcripts.
(define (executable-label exe)
  (if (path? exe)
      (path->string exe)
      exe))

;; write-log! : path-string? path-string? (listof string?) command-result? -> void?
;;   Save a command transcript for later inspection.
(define (write-log! path exe args result)
  (call-with-output-file path
    (lambda (out)
      (fprintf out "$ ~a\n\n"
               (string-join (cons (executable-label exe) args) " "))
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

;; wasm-magic? : path-string? -> boolean?
;;   Check whether path starts with the WebAssembly magic bytes.
(define (wasm-magic? path)
  (and (file-exists? path)
       (call-with-input-file path
         (lambda (in)
           (equal? (for/list ([_ (in-range 4)])
                     (read-byte in))
                   '(0 97 115 109))))))

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

;; cached-runtime-wasm-files : path-string? -> (listof path?)
;;   Return non-lock runtime wasm files in the stable split-runtime cache.
(define (cached-runtime-wasm-files runtime-cache)
  (define cache-root
    (build-path runtime-cache split-runtime-core-cache-directory))
  (if (directory-exists? cache-root)
      (sort
       (find-files
        (lambda (p)
          (and (file-exists? p)
               (equal? (path-get-extension p) #".wasm")
               (not (regexp-match? #rx"^\\.LOCK"
                                   (path->string (file-name-from-path p))))))
        cache-root)
       string<?
       #:key path->string)
      '()))

;; cached-runtime-wasm-snapshot : path-string? -> list?
;;   Return stable file metadata for cached runtime wasm artifacts.
(define (cached-runtime-wasm-snapshot runtime-cache)
  (for/list ([p (in-list (cached-runtime-wasm-files runtime-cache))])
    (list (path->string p)
          (file-size p)
          (file-or-directory-modify-seconds p))))

;; expected-split-runtime-core-cache-key : -> any/c
;;   Build the cache key that Node split-runtime prewarm should populate.
(define (expected-split-runtime-core-cache-key)
  (define runtime-fingerprint
    (runtime-source-fingerprint))
  (if core-only?
      (make-split-runtime-core-only-cache-key runtime-fingerprint)
      (make-split-runtime-core-cache-key
       #t
       (split-runtime-request-cache-fingerprint
        #:browser? #f
        #:runtime-source-fingerprint runtime-fingerprint
        #:active-ffi-foreigns '()
        #:active-ffi-imports-wat '()
        #:active-ffi-funcs-wat '()))))

;; expected-split-runtime-core-wasm-path : path-string? any/c -> path?
;;   Return the exact cache wasm path implied by a split-runtime cache key.
(define (expected-split-runtime-core-wasm-path runtime-cache core-cache-key)
  (split-runtime-core-cache-wasm-path
   runtime-cache
   (split-runtime-core-cache-key-fingerprint core-cache-key)))

;; transcript-contains? : command-result? regexp? -> boolean?
;;   Check stdout and stderr for a regexp.
(define (transcript-contains? result rx)
  (regexp-match? rx
                 (string-append (command-result-stdout result)
                                "\n"
                                (command-result-stderr result))))

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
    reject)
   (write-generated-case!
    source-dir
    "unsafe-core-helpers"
    #<<RKT
(let* ([p (cons 39 3)]
       [v (vector 40 2)]
       [b (bytes 97 98 99)]
       [s "abcd"])
  (unsafe-bytes-set! b 1 100)
  (if (and (unsafe-fx= (unsafe-fx+ (unsafe-car p) (unsafe-cdr p)) 42)
           (unsafe-fx= (unsafe-vector-length v) 2)
           (unsafe-fx= (unsafe-vector-ref v 1) 2)
           (unsafe-fx= (unsafe-string-length s) 4)
           (unsafe-fx= (unsafe-bytes-length b) 3)
           (unsafe-fx= (unsafe-bytes-ref b 1) 100))
      42
      0))
RKT
    expect
    reject)
   (write-generated-case!
    source-dir
    "box-core-helpers"
    #<<RKT
(let ([x 40])
  (set! x (+ x 2))
  (let ([b  (box x)]
        [ib (box-immutable x)]
        [wb (make-weak-box 'cached)])
    (if (and (= x 42)
             (box? b)
             (box? ib)
             (not (box? 1))
             (mutable-box? b)
             (not (mutable-box? ib))
             (immutable-box? ib)
             (not (immutable-box? b))
             (weak-box? wb)
             (not (weak-box? 'cached)))
        x
        0)))
RKT
    expect
    reject)
   (write-generated-case!
    source-dir
    "bytes-core-helpers"
    #<<RKT
(let ([b (bytes 40 0)])
  (bytes-set! b 1 2)
  (if (and (bytes? b)
           (mutable-bytes? b)
           (immutable-bytes? #"abc")
           (not (bytes? 1))
           (byte? 255)
           (not (byte? 256))
           (bytes=? #"ab" #"ab")
           (bytes<? #"ab" #"ac")
           (bytes>? #"ad" #"ac")
           (not (bytes-converter? b)))
      (+ (bytes-ref b 0) (bytes-ref b 1))
      0))
RKT
    expect
    reject)
   (write-generated-case!
    source-dir
    "regexp-core-helpers"
    #<<RKT
(if (and (regexp? #rx"abc")
         (pregexp? #px"abc")
         (byte-regexp? #rx#"abc")
         (byte-pregexp? #px#"abc")
         (not (regexp? 1))
         (not (pregexp? #rx"abc"))
         (not (byte-regexp? #rx"abc"))
         (not (byte-pregexp? #rx#"abc")))
    42
    0)
RKT
    expect
    reject)
   (write-generated-case!
    source-dir
    "predicate-core-helpers"
    #<<RKT
(let* ([mh (make-hasheq)]
       [un (string->uninterned-symbol "cached")]
       [s  (string #\a #\b #\c)]
       [v  (vector 40 2)]
       [ch (make-channel)]
       [put-evt (channel-put-evt ch 42)]
       [thread-cell (make-thread-cell 42 #f)]
       [sema (make-semaphore)]
       [peek-evt (semaphore-peek-evt sema)]
       [logger (current-logger)]
       [receiver (make-log-receiver logger 'info)]
       [will (make-will-executor)]
       [cust (current-custodian)]
       [cust-box (make-custodian-box cust 42)]
       [ups (unquoted-printing-string "raw")]
       [ih (hasheqv 'a 1 'b 2)]
       [ih-pos (hash-iterate-first ih)]
       [p (string->path "/tmp/name.rkt")]
       [tl (treelist 1 2 3)]
       [tlv (treelist->vector tl)]
       [sv (stencil-vector #b101 'a 'b)]
       [sys-sv ($system-stencil-vector #b11 'x 'y)]
       [date-v (date 6 5 4 3 2 2024 1 33 #f 0)]
       [date*-v (date* 6 5 4 3 2 2024 1 33 #f 0 9 "UTC")]
       [linklet-info (linklet-summarize-target-machine-info 42)])
  (if (and (eq? 'cached 'cached)
           (not (eq? (box 1) (box 1)))
           (char? #\a)
           (char-blank? #\space)
           (char-whitespace? #\newline)
           (string? s)
           (mutable-string? s)
           (not (immutable? s))
           (immutable? "abc")
           (immutable-string? "abc")
           (= (string-length s) 3)
           (char=? (string-ref s 1) #\b)
           (equal? (string-split "  a  b  " " " #t #t) '("a" "b"))
           (equal? (string-split "a--b--c" "--" #t #f) '("a" "b" "c"))
           (string=? "same" "same")
           (string<? "a" "b")
           (string<=? "a" "a")
           (string>? "b" "a")
           (string>=? "b" "b")
           (vector? v)
           (mutable-vector? v)
           (not (immutable? v))
           (immutable? '#(1 2))
           (immutable-vector? '#(1 2))
           (= (vector-length v) 2)
           (= (car (vector->list v)) 40)
           (symbol? un)
           (symbol? 'cached)
           (number? 42)
           (real? 42)
           (rational? 42)
           (exact? 42)
           (not (inexact? 42))
           (exact-integer? 42)
           (exact-nonnegative-integer? 42)
           (exact-positive-integer? 42)
           (integer? (string->number "42"))
           (string? (number->string 42))
           (fixnum? 42)
           (fxzero? 0)
           (not (fxvector? 42))
           (fixnum-for-every-system? 42)
           (fx= (fxabs -42) 42)
           (fx= (fxand 42 42) 42)
           (fixnum? (most-positive-fixnum))
           (fixnum? (most-negative-fixnum))
           (flonum? 3.5)
           (fl= (fl/ 6.0 2.0) 3.0)
           (fl= (flabs -3.0) 3.0)
           (fl= (flfloor 3.8) 3.0)
           (fl= (flceiling 3.2) 4.0)
           (fl= (fltruncate 3.8) 3.0)
           (fl= (flmin 7.0 3.0) 3.0)
           (fl= (flmax 7.0 3.0) 7.0)
           (hash? mh)
           (mutable-hash? mh)
           (not (immutable? mh))
           (hash-empty? mh)
           (hash? ih)
           (not (mutable-hash? ih))
           (immutable? ih)
           (immutable-hash? ih)
           (not (hash? 42))
           (hash-eqv? ih)
           (hash-has-key? ih 'a)
           (= (hash-ref ih 'b) 2)
           ih-pos
           (symbol? (hash-iterate-key ih ih-pos))
           (number? (hash-iterate-value ih ih-pos))
           (path-for-some-system? p)
           (bytes=? (path-get-extension p) #".rkt")
           (bytes=? (filename-extension p) #"rkt")
           (path-has-extension? p #".rkt")
           (string=? (path->string (file-name-from-path p)) "name.rkt")
           (treelist? tl)
           (= (treelist-length tl) 3)
           (vector? tlv)
           (= (vector-length tlv) 3)
           (= (vector-ref tlv 0) 1)
           (= (vector-ref tlv 2) 3)
           (= (stencil-vector-mask-width) 26)
           (stencil-vector? sv)
           ($stencil-vector? sv)
           ($system-stencil-vector? sys-sv)
           (not (stencil-vector? sys-sv))
           (= (stencil-vector-length sv) 2)
           (= (stencil-vector-mask sv) #b101)
           (eq? (stencil-vector-ref sv 0) 'a)
           (eq? (stencil-vector-ref sv 1) 'b)
           (eqv? 42 42)
           (eqv? #\a #\a)
           (not (eqv? 0.0 -0.0))
           (date? date-v)
           (not (date*? date-v))
           (date? date*-v)
           (date*? date*-v)
           (= (date-second date-v) 6)
           (not (impersonator? 42))
           (not (procedure-impersonator*? (lambda (x) x)))
           (not (chaperone? 42))
           (not (external? 42))
           (not (struct? 42))
           (not (struct-type? 42))
           (not (struct-type-property? 42))
           (not (struct-constructor-procedure? (lambda (x) x)))
           (not (struct-predicate-procedure? (lambda (x) x)))
           (not (struct-accessor-procedure? (lambda (x) x)))
           (not (struct-mutator-procedure? (lambda (x) x)))
           (not (compiled-expression? 42))
           (not (compiled-module-expression? 42))
           (not (readtable? 42))
           (not (rename-transformer? 42))
           (not (set!-transformer? 42))
           (not (special-comment? 42))
           (not (syntax-original? 42))
           (not (syntax-tainted? 42))
           (not (internal-definition-context? 42))
           (not (liberal-define-context? 42))
           (not (module-path-index? 42))
           (not (resolved-module-path? 42))
           (not (variable-reference? 42))
           (channel? ch)
           (channel-put-evt? put-evt)
           (evt? ch)
           (evt? put-evt)
           (thread-cell? thread-cell)
           (thread? (current-thread))
           (thread-group? (current-thread-group))
           (semaphore? sema)
           (semaphore-peek-evt? peek-evt)
           (evt? sema)
           (evt? peek-evt)
           (logger? logger)
           (log-receiver? receiver)
           (evt? receiver)
           (will-executor? will)
           (evt? will)
           (not (subprocess? 42))
           (security-guard? (current-security-guard))
           (custodian? cust)
           (custodian-box? cust-box)
           (inspector? (current-inspector))
           (inspector? (current-code-inspector))
           (unquoted-printing-string? ups)
           (string=? (format "~a" ups) "raw")
           (string=? (format "~s" "a\n") "\"a\\n\"")
           (not (primitive->compiled-position 'car))
           (not (compiled-position->primitive #f))
           (not (primitive-in-category? 'car 'unsafe))
           (not (primitive-lookup 'car))
           (eq? (recompile-linklet 42 #f) 42)
           (eq? (eval-linklet 42) 42)
           (eq? (linklet-add-target-machine-info 42 0) 42)
           (hash? linklet-info)
           (hash-empty? linklet-info)
           (not (linklet-cross-machine-type linklet-info))
           (eq? (write-linklet-bundle-hash linklet-info 0) (void))
           (not (read-linklet-bundle-hash 0 #f)))
      42
      0))
RKT
    expect
    reject)))

;; record-failure! : string? any/c ... -> void?
;;   Accumulate a formatted check failure.
(define failures '())
(define failure-lock (make-semaphore 1))
(define (record-failure! fmt . args)
  (semaphore-wait failure-lock)
  (dynamic-wind
    void
    (lambda ()
      (set! failures (cons (apply format fmt args) failures)))
    (lambda ()
      (semaphore-post failure-lock))))

;; compile-cases! :
;;   (listof check-case?) path-string? path-string? path-string? path-string?
;;   path-string?
;;   [#:expect-module-bridge-result-cache-hit? boolean?]
;;   [#:runtime-mode (or/c 'cache-reference 'sidecar)]
;;   [#:log-prefix string?] -> (listof command-result?)
;;   Compile/run cases with bounded parallelism, preserving result order.
(define (compile-cases! cases
                        racket-exe
                        provider-cache
                        runtime-cache
                        dest-root
                        temp-root
                        #:expect-module-bridge-result-cache-hit?
                        [expect-module-bridge-result-cache-hit? #f]
                        #:runtime-mode
                        [runtime-mode 'cache-reference]
                        #:log-prefix
                        [log-prefix "compile"])
  (define (compile-one case index)
    (with-handlers ([exn:fail?
                     (lambda (exn)
                       (record-failure!
                       "~a: compile/run raised exception: ~a"
                       (check-case-name case)
                       (exn-message exn))
                       (command-result #f "" "" 0.0))])
      (compile-case! case
                     index
                     racket-exe
                     provider-cache
                     runtime-cache
                     dest-root
                     temp-root
                     #:expect-module-bridge-result-cache-hit?
                     expect-module-bridge-result-cache-hit?
                     #:runtime-mode runtime-mode
                     #:log-prefix log-prefix)))
  (cond
    [(compile-runner-serial?)
     (for/list ([case (in-list cases)]
                [index (in-naturals 1)])
       (compile-one case index))]
    [else
     (define worker-limit (make-semaphore jobs))
     (define result-channel (make-channel))
     (define case-count (length cases))
     (define threads
       (for/list ([case (in-list cases)]
                  [index (in-naturals 1)])
         (thread
          (lambda ()
            (semaphore-wait worker-limit)
            (define result
              (dynamic-wind
                void
                (lambda ()
                  (compile-one case index))
                (lambda ()
                  (semaphore-post worker-limit))))
            (channel-put result-channel (list index result))))))
     (define indexed-results
       (for/list ([_ (in-range case-count)])
         (channel-get result-channel)))
     (for ([worker (in-list threads)])
       (thread-wait worker))
     (for/list ([indexed-result (in-list
                                 (sort indexed-results < #:key first))])
       (second indexed-result))]))

;; compile-case! :
;;   check-case? exact-positive-integer? path-string? path-string? path-string?
;;   path-string? path-string?
;;   [#:expect-module-bridge-result-cache-hit? boolean?]
;;   [#:runtime-mode (or/c 'cache-reference 'sidecar 'prewarm-sidecar)]
;;   [#:log-prefix string?] -> command-result?
;;   Compile/run one source against the prewarmed runtime cache.
(define (compile-case! case
                       index
                       racket-exe
                       provider-cache
                       runtime-cache
                       dest-root
                       temp-root
                       #:expect-module-bridge-result-cache-hit?
                       [expect-module-bridge-result-cache-hit? #f]
                       #:runtime-mode
                       [runtime-mode 'cache-reference]
                       #:log-prefix
                       [log-prefix "compile"])
  (unless (memq runtime-mode '(cache-reference sidecar prewarm-sidecar))
    (error 'compile-case!
           "unknown split runtime check mode: ~s"
           runtime-mode))
  (define cache-reference-mode? (eq? runtime-mode 'cache-reference))
  (define sidecar-mode? (eq? runtime-mode 'sidecar))
  (define prewarm-sidecar-mode? (eq? runtime-mode 'prewarm-sidecar))
  (define sidecar-output-mode? (or sidecar-mode? prewarm-sidecar-mode?))
  (define case-name
    (safe-case-name (check-case-name case)))
  (define dest-dir
    (build-path dest-root (format "~a-~a" index case-name)))
  (make-directory* dest-dir)
  (define webracket-args
    (append
     (list "--node" "--run" "--timings"
           "--split-runtime"
           "--no-stdlib")
     (if cache-reference-mode?
         '("--split-runtime-cache-reference")
         '())
     (if frontend-cache?
         '("--frontend-cache")
         '())
     (if core-only?
         '("--split-runtime-core-only")
         '())
     (if provider-runtime?
         '("--split-runtime-provider-runtime")
         '())
     (list "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--dest" (path->string dest-dir)
           (path->string (check-case-source case)))))
  (define compile-result
    (run-webracket-compile-args/capture repo-root racket-exe webracket-args))
  (define compile-log
    (build-path temp-root (format "~a-~a-~a.log" log-prefix index case-name)))
  (write-log! compile-log
              (cond
                [in-process? "in-process-webracket"]
                [compile-server? "compile-server-webracket"]
                [else racket-exe])
              (if (or in-process? compile-server?)
                  webracket-args
                  (append (list "-S" "pkgs" "webracket.rkt")
                          webracket-args))
              compile-result)

  (when frontend-cache?
    (define module-source? (webracket-module-source? (check-case-source case)))
    (define expected-frontend-cache-mode
      (if module-source?
          #rx"frontend-cache-mode +: +disabled-module-input"
          #rx"frontend-cache-mode +: +enabled"))
    (unless (transcript-contains? compile-result expected-frontend-cache-mode)
      (record-failure! "~a: frontend cache mode did not match expected regexp ~s; see ~a"
                       (check-case-name case)
                       expected-frontend-cache-mode
                       compile-log)))

  (unless (command-result-ok? compile-result)
    (record-failure! "~a: compile/run command failed; see ~a"
                     (check-case-name case)
                     compile-log))
  (when (and (check-case-expect case)
             (not (regexp-match? (check-case-expect case)
                                  (compiler-stdout->program-output
                                   (command-result-stdout compile-result)))))
    (record-failure! "~a: program stdout did not match expected output regexp ~s"
                     (check-case-name case)
                     (check-case-expect case)))
  (when (and (check-case-reject case)
             (regexp-match? (check-case-reject case)
                            (compiler-stdout->program-output
                             (command-result-stdout compile-result))))
    (record-failure! "~a: program stdout matched rejected output regexp ~s"
                     (check-case-name case)
                     (check-case-reject case)))
  (when (and expect-module-bridge-result-cache-hit?
             (webracket-module-source? (check-case-source case))
             (not (transcript-contains? compile-result
                                        #rx"module-bridge-result-cache-hit")))
    (record-failure! "~a: did not report module-bridge-result-cache-hit"
                     (check-case-name case)))
  (define reference-compatible?
    (not (transcript-contains? compile-result
                               #rx"split-reference-compatible\\? *: *no")))
  (define program-only-fast-path?
    (transcript-contains? compile-result
                          #rx"split-program-only-fast-path\\? *: *yes"))
  (when (and cache-reference-mode? reference-compatible?)
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
                       (check-case-name case))))
  (when (and sidecar-mode? reference-compatible?)
    (unless (transcript-contains? compile-result
                                  #rx"split-runtime-core:materialize-wasm-hit")
      (record-failure! "~a: did not report split-runtime-core:materialize-wasm-hit"
                       (check-case-name case)))
    (when (transcript-contains? compile-result
                                #rx"split-runtime-core:reference-wasm-hit")
      (record-failure! "~a: referenced cached runtime wasm instead of materializing sidecar"
                       (check-case-name case)))
    (when (transcript-contains? compile-result
                                #rx"split-runtime-core:assemble-wasm")
      (record-failure! "~a: assembled the split runtime instead of using the cache"
                       (check-case-name case)))
    (when (and (not core-only?)
               (transcript-contains? compile-result
                                     #rx"split-core-wasm-cache-preflight-hit\\? *: *yes")
               (transcript-contains? compile-result
                                     #rx"split-boundary-cache-preflight-hit\\? *: *yes")
               (not program-only-fast-path?))
      (record-failure! "~a: warm sidecar compile did not take the program-only fast path"
                       (check-case-name case))))
  (when (and provider-runtime?
             (or cache-reference-mode? sidecar-mode?)
             reference-compatible?)
    (when (transcript-contains? compile-result #rx"provider-runtime-merge")
      (record-failure! "~a: warm provider-runtime compile merged provider code instead of using cache"
                       (check-case-name case)))
    (when (transcript-contains? compile-result #rx"provider-fragment-cache")
      (record-failure! "~a: warm provider-runtime compile touched the compiled provider-fragment cache"
                       (check-case-name case))))

  (define program-wasm
    (generated-path dest-dir (check-case-source case) ".wasm"))
  (define runtime-sidecar-wasms
    (content-sidecar-paths dest-dir "webracket-runtime"))
  (unless (file-exists? program-wasm)
    (record-failure! "~a: did not produce program wasm: ~a"
                     (check-case-name case)
                     program-wasm))
  (when (and reference-compatible?
             cache-reference-mode?
             (pair? runtime-sidecar-wasms))
    (record-failure! "~a: cache-reference compile unexpectedly produced runtime sidecars: ~a"
                     (check-case-name case)
                     runtime-sidecar-wasms))
  (when (and reference-compatible?
             sidecar-output-mode?
             (not (= (length runtime-sidecar-wasms) 1)))
    (record-failure! "~a: sidecar compile produced ~a runtime sidecars, expected exactly one: ~a"
                     (check-case-name case)
                     (length runtime-sidecar-wasms)
                     runtime-sidecar-wasms))
  (when (and reference-compatible?
             sidecar-output-mode?
             (= (length runtime-sidecar-wasms) 1)
             (not (wasm-magic? (car runtime-sidecar-wasms))))
    (record-failure! "~a: sidecar compile produced invalid runtime sidecar: ~a"
                     (check-case-name case)
                     (car runtime-sidecar-wasms)))
  compile-result)

;; prewarm-provider-runtime-case! :
;;   check-case? exact-positive-integer? path-string? path-string? path-string?
;;   path-string? [#:expect-cache-hit? boolean?] [#:log-prefix string?]
;;   -> command-result?
;;   Prewarm one module source's provider-augmented runtime cache via the public tool.
(define (prewarm-provider-runtime-case! case
                                        index
                                        racket-exe
                                        provider-cache
                                        runtime-cache
                                        temp-root
                                        #:expect-cache-hit?
                                        [expect-cache-hit? #f]
                                        #:log-prefix
                                        [log-prefix "provider-runtime-prewarm"])
  (define case-name
    (safe-case-name (check-case-name case)))
  (define output-dir
    (build-path temp-root "provider-runtime-prewarm-runtime-wasm"))
  (make-directory* output-dir)
  (define runtime-wasm-out
    (generated-path output-dir (check-case-source case) ".runtime.wasm"))
  (define args
    (append
     (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--mode" "provider-runtime"
           "--host" "node"
           "--source" (path->string (check-case-source case))
           "--runtime-wasm-out" (path->string runtime-wasm-out))
     (if expect-cache-hit?
         '("--verbose")
         '())))
  (define previous-runtime-wasm-bytes
    (and expect-cache-hit?
         (file-exists? runtime-wasm-out)
         (file->bytes runtime-wasm-out)))
  (define result
    (run-command/capture repo-root racket-exe args))
  (define log
    (build-path temp-root
                (format "~a-~a-~a.log"
                        log-prefix
                        index
                        case-name)))
  (write-log! log racket-exe args result)
  (unless (command-result-ok? result)
    (record-failure! "~a: provider-runtime prewarm command failed; see ~a"
                     (check-case-name case)
                     log))
  (unless (wasm-magic? runtime-wasm-out)
    (record-failure! "~a: provider-runtime prewarm did not export a valid runtime wasm: ~a"
                     (check-case-name case)
                     runtime-wasm-out))
  (when expect-cache-hit?
    (unless previous-runtime-wasm-bytes
      (record-failure! "~a: provider-runtime cache-hit prewarm had no previous runtime wasm to compare: ~a"
                       (check-case-name case)
                       runtime-wasm-out))
    (when (and previous-runtime-wasm-bytes
               (file-exists? runtime-wasm-out)
               (not (equal? previous-runtime-wasm-bytes
                            (file->bytes runtime-wasm-out))))
      (record-failure! "~a: provider-runtime cache-hit prewarm exported a different runtime wasm: ~a"
                       (check-case-name case)
                       runtime-wasm-out))
    (unless (transcript-contains? result
                                  #rx"split-runtime-core:materialize-wasm-hit")
      (record-failure! "~a: repeated provider-runtime prewarm did not report cached runtime materialization"
                       (check-case-name case)))
    (when (transcript-contains? result
                                #rx"split-runtime-core:assemble-wasm")
      (record-failure! "~a: repeated provider-runtime prewarm assembled runtime wasm"
                       (check-case-name case)))
    (when (transcript-contains? result
                                #rx"provider-runtime-merge|provider-fragment-cache")
      (record-failure! "~a: repeated provider-runtime prewarm rebuilt provider/runtime artifacts"
                       (check-case-name case))))
  result)


;;; Main Check

;; run-check! : -> void?
;;   Prewarm the split-runtime cache, compile/run a program by cache reference,
;;   and validate the observed cache behavior.
(define (run-check!)
  (define racket-exe (ensure-racket-executable))
  (ensure-executable "node")
  (define temp-root
    (make-temporary-file "webracket-split-runtime-prewarm-check-~a"
                         'directory
                         (check-temp-dir)))
  (define provider-cache (build-path temp-root "provider-cache"))
  (define runtime-cache  (build-path temp-root "runtime-provider-cache"))
  (define compiled-root  (build-path temp-root "compiled-root"))
  (define dest-dir       (build-path temp-root "dest"))
  (define private-compiled-root?
    (or isolate-compiled-root?
        precompile-compiler?))
  (make-directory* provider-cache)
  (make-directory* runtime-cache)
  (make-directory* dest-dir)
  (when private-compiled-root?
    (make-directory* compiled-root)
    (putenv "PLTCOMPILEDROOTS" (path->string compiled-root)))

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
  (when provider-runtime?
    (define non-module-cases
      (filter-not (lambda (case)
                    (webracket-module-source? (check-case-source case)))
                  cases))
    (when (pair? non-module-cases)
      (raise-user-error
       'check-split-runtime-prewarm
       "--split-runtime-provider-runtime requires module-language sources; non-module cases: ~a"
       (string-join (map check-case-name non-module-cases) ", "))))

  (printf "  sources:       ~a\n" (length cases))
  (printf "  runner:        ~a\n"
          (compile-runner-label))
  (printf "  runtime mode:  ~a\n"
          (if provider-runtime? "provider-runtime" "classified/core"))
  (printf "  provider warm: ~a\n"
          (if staged-provider-prewarm? "regexp/read/io-format" "runtime only"))
  (printf "  precompile:    ~a\n"
          (if precompile-compiler? "compiler/tools" "no"))
  (printf "  frontend cache: ~a\n"
          (if frontend-cache? "enabled" "disabled"))
  (printf "  sidecar check: ~a\n"
          (if sidecar-check? "enabled" "disabled"))
  (printf "  jobs:          ~a\n"
          (if (compile-runner-serial?)
              "1 (serial runner)"
              jobs))
  (for ([case (in-list cases)])
    (printf "    ~a: ~a\n"
            (check-case-name case)
            (path->string (check-case-source case))))
  (printf "  temp:          ~a\n" (path->string temp-root))
  (printf "  compiled root: ~a\n\n"
          (if private-compiled-root?
              (path->string compiled-root)
              "normal environment"))

  (define compiler-precompile-args
    (list "-S" "pkgs" "-l" "raco" "make"
          "webracket.rkt"
          "tools/prewarm-staged-providers.rkt"
          "tools/check-split-runtime-prewarm.rkt"))
  (define compiler-precompile-result
    (if precompile-compiler?
        (run-command/capture repo-root racket-exe compiler-precompile-args)
        (command-result #t "" "" 0.0)))
  (when precompile-compiler?
    (define compiler-precompile-log
      (build-path temp-root "precompile-compiler.log"))
    (write-log! compiler-precompile-log
                racket-exe
                compiler-precompile-args
                compiler-precompile-result)
    (unless (command-result-ok? compiler-precompile-result)
      (record-failure! "compiler precompile command failed; see ~a"
                       compiler-precompile-log)))

  (define staged-provider-prewarm-args
    (append
     (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--mode" "all")
     (if force-prewarm? '("--force") '())))
  (define staged-provider-prewarm-result
    (if staged-provider-prewarm?
        (run-command/capture repo-root racket-exe staged-provider-prewarm-args)
        (command-result #t "" "" 0.0)))
  (when staged-provider-prewarm?
    (define staged-provider-prewarm-log
      (build-path temp-root "prewarm-staged-providers.log"))
    (write-log! staged-provider-prewarm-log
                racket-exe
                staged-provider-prewarm-args
                staged-provider-prewarm-result)
    (unless (command-result-ok? staged-provider-prewarm-result)
      (record-failure! "staged-provider prewarm command failed; see ~a"
                       staged-provider-prewarm-log)))

  (define base-prewarm-args
    (append
     (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--mode" "split-runtime")
     (if core-only?
         '("--split-runtime-core-only")
         '())))
  (define prewarm-args
    (append
     base-prewarm-args
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
  (define expected-core-cache-key
    (expected-split-runtime-core-cache-key))
  (define expected-runtime-wasm
    (expected-split-runtime-core-wasm-path runtime-cache
                                           expected-core-cache-key))
  (unless (file-exists? expected-runtime-wasm)
    (record-failure! "prewarm did not create expected cached split-runtime wasm: ~a"
                     expected-runtime-wasm))
  (when (and (not core-only?)
             (not (split-runtime-boundary-cache-current?
                   runtime-cache
                   expected-core-cache-key)))
    (record-failure! "prewarm did not create current split-boundary metadata for expected runtime key"))
  (define cached-wasm-snapshot-after-prewarm
    (cached-runtime-wasm-snapshot runtime-cache))

  (define prewarm-cache-hit-result
    (if (and (command-result-ok? prewarm-result)
             (pair? cached-wasms-after-prewarm))
        (run-command/capture repo-root racket-exe base-prewarm-args)
        (command-result #f "" "" 0.0)))
  (define prewarm-cache-hit-log
    (build-path temp-root "prewarm-cache-hit.log"))
  (write-log! prewarm-cache-hit-log
              racket-exe
              base-prewarm-args
              prewarm-cache-hit-result)
  (unless (command-result-ok? prewarm-cache-hit-result)
    (record-failure! "second prewarm command failed; see ~a"
                     prewarm-cache-hit-log))
  (unless (transcript-contains? prewarm-cache-hit-result
                                #rx"split-runtime prewarm cache hit")
    (record-failure! "second prewarm did not report a direct split-runtime cache hit"))
  (define cached-wasm-snapshot-after-cache-hit
    (cached-runtime-wasm-snapshot runtime-cache))
  (unless (equal? cached-wasm-snapshot-after-cache-hit
                  cached-wasm-snapshot-after-prewarm)
    (record-failure! "second prewarm changed cached runtime wasm artifacts"))

  (define provider-runtime-prewarm-results
    (if provider-runtime?
        (let ()
          (printf "  prewarming provider-runtime cache for ~a module source(s)\n"
                  (length cases))
          (for/list ([case (in-list cases)]
                     [index (in-naturals 1)])
            (prewarm-provider-runtime-case! case
                                            index
                                            racket-exe
                                            provider-cache
                                            runtime-cache
                                            temp-root)))
        '()))
  (define cached-wasm-snapshot-after-provider-runtime-prewarm
    (cached-runtime-wasm-snapshot runtime-cache))

  (define provider-runtime-cache-hit-prewarm-results
    (if (and provider-runtime?
             (andmap command-result-ok? provider-runtime-prewarm-results))
        (let ()
          (printf "  checking provider-runtime prewarm cache hit for ~a module source(s)\n"
                  (length cases))
          (for/list ([case (in-list cases)]
                     [index (in-naturals 1)])
            (prewarm-provider-runtime-case! case
                                            index
                                            racket-exe
                                            provider-cache
                                            runtime-cache
                                            temp-root
                                            #:expect-cache-hit? #t
                                            #:log-prefix
                                            "provider-runtime-prewarm-cache-hit")))
        '()))
  (define cached-wasm-snapshot-after-provider-runtime-cache-hit-prewarm
    (cached-runtime-wasm-snapshot runtime-cache))
  (when (and provider-runtime?
             (not (equal? cached-wasm-snapshot-after-provider-runtime-cache-hit-prewarm
                          cached-wasm-snapshot-after-provider-runtime-prewarm)))
    (record-failure! "repeated provider-runtime prewarm changed cached runtime wasm artifacts"))

  (define module-bridge-cache-warm-results
    (if (and module-bridge-result-cache-check?
             (not provider-runtime?))
        (let ([module-cases
               (filter (lambda (case)
                         (webracket-module-source? (check-case-source case)))
                       cases)])
          (cond
            [(null? module-cases)
             (record-failure!
              "module-bridge result cache check requested, but no module sources were selected")
             '()]
            [else
             (printf "  warming module-bridge result cache for ~a module source(s)\n"
                     (length module-cases))
             (compile-cases! module-cases
                             racket-exe
                             provider-cache
                             runtime-cache
                             (build-path temp-root "module-bridge-cache-warmup-dest")
                             temp-root
                             #:log-prefix "module-bridge-warmup")]))
        '()))

  (define cache-reference-results
    (compile-cases! cases
                    racket-exe
                    provider-cache
                    runtime-cache
                    (build-path dest-dir "cache-reference")
                    temp-root
                    #:expect-module-bridge-result-cache-hit?
                    module-bridge-result-cache-check?
                    #:runtime-mode 'cache-reference
                    #:log-prefix "compile-cache-reference"))

  (define sidecar-results
    (if sidecar-check?
        (compile-cases! cases
                        racket-exe
                        provider-cache
                        runtime-cache
                        (build-path dest-dir "sidecar")
                        temp-root
                        #:expect-module-bridge-result-cache-hit?
                        module-bridge-result-cache-check?
                        #:runtime-mode 'sidecar
                        #:log-prefix "compile-sidecar")
        '()))

  (define cached-wasm-snapshot-after-warm-checks
    (cached-runtime-wasm-snapshot runtime-cache))
  (unless (equal? cached-wasm-snapshot-after-warm-checks
                  cached-wasm-snapshot-after-provider-runtime-cache-hit-prewarm)
    (record-failure! "warm compile/run checks changed cached runtime wasm artifacts"))

  (cond
    [(null? failures)
     (printf "ok: ~a~a~a~a~aprewarm=~as cache-hit-prewarm=~as cache-reference=[~a]~a cached-runtime-wasms=~a\n"
             (if precompile-compiler?
                 (format "compiler-precompile=~as "
                         (format-seconds
                          (command-result-wall-ms compiler-precompile-result)))
                 "")
             (if staged-provider-prewarm?
                 (format "provider-prewarm=~as "
                         (format-seconds
                          (command-result-wall-ms
                           staged-provider-prewarm-result)))
                 "")
             (if provider-runtime?
                 (format "provider-runtime-prewarm=[~a] "
                         (string-join
                          (for/list ([result (in-list provider-runtime-prewarm-results)])
                            (format "~as" (format-seconds (command-result-wall-ms result))))
                          ", "))
                 "")
             (if provider-runtime?
                 (format "provider-runtime-cache-hit-prewarm=[~a] "
                         (string-join
                          (for/list ([result (in-list provider-runtime-cache-hit-prewarm-results)])
                            (format "~as" (format-seconds (command-result-wall-ms result))))
                          ", "))
                 "")
             (if module-bridge-result-cache-check?
                 (format "module-bridge-warmup=[~a] "
                         (string-join
                          (for/list ([result (in-list module-bridge-cache-warm-results)])
                            (format "~as" (format-seconds (command-result-wall-ms result))))
                          ", "))
                 "")
             (format-seconds (command-result-wall-ms prewarm-result))
             (format-seconds (command-result-wall-ms prewarm-cache-hit-result))
             (string-join
              (for/list ([result (in-list cache-reference-results)])
                (format "~as" (format-seconds (command-result-wall-ms result))))
              ", ")
             (if sidecar-check?
                 (format " sidecar=[~a]"
                         (string-join
                          (for/list ([result (in-list sidecar-results)])
                            (format "~as" (format-seconds
                                           (command-result-wall-ms result))))
                          ", "))
                 "")
             (length (cached-runtime-wasm-files runtime-cache)))
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
