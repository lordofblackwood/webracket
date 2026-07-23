#lang racket/base

;;; Check Split Runtime Default
;;;

;; This focused smoke verifies the public default policy:
;; compiling without `--split-runtime` emits and runs split-runtime sidecar
;; output, while explicit `--no-split-runtime` still emits and runs one
;; monolithic Wasm module.


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

;; resolve-source-path : string? -> path?
;;   Resolve a user-provided source path relative to the repository root.
(define (resolve-source-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

(command-line
 #:program "check-split-runtime-default"
 #:once-each
 [("--source") path
  "Source file to compile/run; defaults to test/test-trivial.rkt."
  (set! source-file (resolve-source-path path))]
 [("--extra-source") path
  "Additional source file to compile/run under default and monolithic modes."
  (set! extra-source-files
        (append extra-source-files
                (list (resolve-source-path path))))]
 [("--expect") pattern
  "Regular expression expected in compiler/run stdout; defaults to a line containing 42."
  (set! expected-output-regexp (regexp pattern))]
 [("--no-expect")
  "Do not validate generated program output."
  (set! expected-output-regexp #f)]
 [("--keep-temp")
  "Keep the temporary check directory after a successful run."
  (set! keep-temp? #t)])


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
      (unless (string-suffix? (command-result-stdout result) "\n")
        (newline out))
      (fprintf out ";;; stderr\n~a" (command-result-stderr result))
      (unless (string-suffix? (command-result-stderr result) "\n")
        (newline out)))
    #:exists 'truncate/replace))

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
         (define bs (file->bytes path))
         (and (>= (bytes-length bs) 4)
              (bytes=? (subbytes bs 0 4) #"\0asm")))))


;;; Checks

;; record-failure! : string? any/c ... -> void?
;;   Accumulate a formatted check failure.
(define failures '())
(define (record-failure! fmt . args)
  (set! failures (cons (apply format fmt args) failures)))

;; check-output! : symbol? path-string? command-result? [#:expect-output? boolean?] -> void?
;;   Check command success and generated program output.
(define (check-output! mode log-path result #:expect-output? [expect-output? #t])
  (unless (command-result-ok? result)
    (record-failure! "~a compile/run command failed; see ~a" mode log-path))
  (when (and expect-output?
             expected-output-regexp
             (not (regexp-match? expected-output-regexp
                                  (command-result-stdout result))))
    (record-failure! "~a program stdout did not match expected output regexp ~s; see ~a"
                     mode
                     expected-output-regexp
                     log-path)))

;; source-case-name : path? -> string?
;;   Derive a stable case name from a source path.
(define (source-case-name source)
  (path->string
   (path-replace-extension (file-name-from-path source) #"")))

;; check-artifacts! : symbol? path? path-string? boolean? [#:split-ffi? boolean?] -> void?
;;   Check split/default or monolithic generated artifacts.
(define (check-artifacts! mode source dest-dir split-runtime?
                          #:split-ffi? [split-ffi? #f])
  (define base (generated-basename source))
  (define host-js (build-path dest-dir (string-append base ".js")))
  (define program-wasm (build-path dest-dir (string-append base ".wasm")))
  (define runtime-wasm (build-path dest-dir (string-append base ".runtime.wasm")))
  (define ffi-wasm (build-path dest-dir (string-append base ".ffi.wasm")))
  (unless (file-exists? host-js)
    (record-failure! "~a did not produce Node host: ~a" mode host-js))
  (unless (wasm-magic? program-wasm)
    (record-failure! "~a did not produce valid program wasm: ~a" mode program-wasm))
  (cond
    [split-runtime?
     (unless (wasm-magic? runtime-wasm)
       (record-failure! "~a did not produce valid runtime sidecar: ~a"
                        mode
                        runtime-wasm))]
    [(file-exists? runtime-wasm)
     (record-failure! "~a unexpectedly produced runtime sidecar: ~a"
                      mode
                      runtime-wasm)])
  (cond
    [split-ffi?
     (unless (wasm-magic? ffi-wasm)
       (record-failure! "~a did not produce valid FFI sidecar: ~a"
                        mode
                        ffi-wasm))]
    [(file-exists? ffi-wasm)
     (record-failure! "~a unexpectedly produced FFI sidecar: ~a"
                      mode
                      ffi-wasm)]))

;; run-case! : symbol? path-string? path? (listof string?) boolean?
;;             [#:split-ffi? boolean?] [#:run? boolean?] -> void?
;;   Compile/run one default-policy case and check its artifacts.
(define (run-case! mode temp-root source extra-args split-runtime?
                   #:split-ffi? [split-ffi? #f]
                   #:run? [run? #t])
  (define racket-exe (ensure-executable "racket"))
  (define dest-dir
    (build-path temp-root
                (format "~a-~a" mode (source-case-name source))))
  (make-directory* dest-dir)
  (define args
    (append
     (list "-S" "pkgs" "webracket.rkt"
           "--node")
     (if run? '("--run") '())
     (list
           "--dest" (path->string dest-dir))
     extra-args
     (list (path->string source))))
  (define result
    (run-command/capture repo-root racket-exe args))
  (define log-path
    (build-path temp-root
                (format "~a-~a.log" mode (source-case-name source))))
  (write-log! log-path racket-exe args result)
  (check-output! mode log-path result #:expect-output? run?)
  (check-artifacts! mode source dest-dir split-runtime?
                    #:split-ffi? split-ffi?))

;; run-invalid-case! : symbol? path-string? (listof string?) regexp? -> void?
;;   Check that invalid default-policy flag combinations are rejected.
(define (run-invalid-case! mode temp-root extra-args expected-message)
  (run-invalid-source-case! mode temp-root source-file extra-args expected-message))

;; run-invalid-source-case! : symbol? path-string? path? (listof string?) regexp? -> void?
;;   Check that an invalid compile for `source` is rejected.
(define (run-invalid-source-case! mode temp-root source extra-args expected-message)
  (define racket-exe (ensure-executable "racket"))
  (define dest-dir (build-path temp-root (symbol->string mode)))
  (make-directory* dest-dir)
  (define args
    (append
     (list "-S" "pkgs" "webracket.rkt"
           "--dest" (path->string dest-dir))
     extra-args
     (list (path->string source))))
  (define result
    (run-command/capture repo-root racket-exe args))
  (define log-path
    (build-path temp-root (format "~a.log" mode)))
  (write-log! log-path racket-exe args result)
  (when (command-result-ok? result)
    (record-failure! "~a unexpectedly succeeded; see ~a" mode log-path))
  (define transcript
    (string-append (command-result-stdout result)
                   "\n"
                   (command-result-stderr result)))
  (unless (regexp-match? expected-message transcript)
    (record-failure! "~a failure did not match expected regexp ~s; see ~a"
                     mode
                     expected-message
                     log-path)))


;;; Main

(define temp-root
  (build-path (check-temp-dir)
              (format "webracket-split-runtime-default-check-~a"
                      (string-replace (~a (current-inexact-milliseconds))
                                      "."
                                      ""))))
(make-directory* temp-root)

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

(printf "Split runtime default check\n")
(printf "  sources: ~a\n" (length default-source-files))
(for ([source (in-list default-source-files)])
  (printf "    ~a\n" source))
(printf "  ffi source: ~a\n" standard-ffi-source)
(printf "  provider-runtime provider ffi source: ~a\n"
        provider-runtime-provider-ffi-source)
(printf "  provider-runtime local provider ffi source: ~a\n"
        provider-runtime-local-provider-ffi-source)
(printf "  temp:   ~a\n" temp-root)

(for ([source (in-list default-source-files)])
  (run-case! 'default-sidecar temp-root source '() #t)
  (run-case! 'explicit-monolithic temp-root source '("--no-split-runtime") #f))
(run-case! 'default-split-ffi temp-root standard-ffi-source '() #t
           #:split-ffi? #t
           #:run? #f)
(run-case! 'explicit-inline-ffi temp-root standard-ffi-source
           '("--no-split-runtime-ffi-module")
           #t
           #:run? #f)
(run-case! 'explicit-monolithic-ffi temp-root standard-ffi-source
           '("--no-split-runtime")
           #f
           #:run? #f)
(run-case! 'provider-runtime-explicit-split-ffi-clean-provider
           temp-root
           module-read-demand-source
           '("--split-runtime-provider-runtime" "--split-runtime-ffi-module")
           #t
           #:split-ffi? #f
           #:run? #t)
(run-case! 'provider-runtime-provider-ffi-with-split-ffi
           temp-root
           provider-runtime-provider-ffi-source
           '("--split-runtime-provider-runtime" "--split-runtime-ffi-module")
           #t
           #:split-ffi? #t
           #:run? #t)
(run-case! 'provider-runtime-local-provider-ffi-with-split-ffi
           temp-root
           provider-runtime-local-provider-ffi-source
           '("--split-runtime-provider-runtime" "--split-runtime-ffi-module")
           #t
           #:split-ffi? #t
           #:run? #t)
(run-invalid-case!
 'invalid-cache-reference-without-split
 temp-root
 '("--no-split-runtime" "--split-runtime-cache-reference")
 #rx"`--split-runtime-cache-reference` requires `--split-runtime`")
(run-invalid-case!
 'invalid-browser-url-without-split
 temp-root
 '("--browser" "--no-split-runtime" "--split-runtime-core-url" "/runtime.wasm")
 #rx"`--split-runtime-core-url` requires `--split-runtime`")
(run-invalid-case!
 'invalid-explicit-split-ffi-without-split
 temp-root
 '("--no-split-runtime" "--split-runtime-ffi-module")
 #rx"`--split-runtime-ffi-module` requires `--split-runtime`")

(cond
  [(null? failures)
   (printf "ok: default sidecar, default split FFI, provider-runtime boundary, provider-runtime FFI sidecar, explicit fallbacks, and invalid flag checks succeeded\n")
   (unless keep-temp?
     (delete-directory/files temp-root))
   (exit 0)]
  [else
   (printf "failed: split runtime default check\n")
   (for ([failure (in-list (reverse failures))])
     (printf "  - ~a\n" failure))
   (printf "kept temp: ~a\n" temp-root)
   (exit 1)])
