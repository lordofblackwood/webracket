#lang racket/base

;;; Check Provider Runtime Split
;;;
;;; Experimental checker for the compile-once runtime/provider direction. It
;;; merges a compiled module-bridge provider fragment into a split runtime
;;; module, leaves the user program as a separate Wasm module, and runs both
;;; through the generated two-module host.

(require racket/cmdline
         racket/format
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         (only-in "../pkgs/webracket-lib/compiler/assembler.rkt"
                  runtime
                  wat->wasm)
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  write-wat-to-file)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/provider-fragment-runtime.rkt"
                  merge-provider-fragment-into-runtime
                  provider-runtime-merge-info-core-form-count
                  provider-runtime-merge-info-merged-runtime-form-count
                  provider-runtime-merge-info-provider-colliding-definition-names
                  provider-runtime-merge-info-provider-form-count
                  provider-runtime-merge-info-provider-import-count
                  retarget-provider-imports-to-runtime)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/split-runtime.rkt"
                  strip-split-runtime-program-entry-init))

(define-runtime-path repo-dir "..")
(define repo-root (simplify-path repo-dir))

(define core-wat-file #f)
(define provider-wat-file #f)
(define program-wat-file #f)
(define runtime-wat-file #f)
(define runtime-wasm-file #f)
(define output-program-wat-file #f)
(define output-program-wasm-file #f)
(define host-file #f)
(define strip-program-entry-runtime-init? #f)
(define retarget-provider-imports? #f)
(define run? #f)
(define expected-stdout-lines '())

;; resolve-repo-path : string? -> path?
;;   Resolve a command-line path relative to the repository root.
(define (resolve-repo-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

(command-line
 #:program "check-provider-runtime-split"
 #:once-each
 [("--core-wat") path
  "Split runtime core WAT module."
  (set! core-wat-file (resolve-repo-path path))]
 [("--provider-wat") path
  "Compiled provider-fragment WAT module."
  (set! provider-wat-file (resolve-repo-path path))]
 [("--program-wat") path
  "Compiled program-fragment WAT module."
  (set! program-wat-file (resolve-repo-path path))]
 [("--write-runtime-wat") path
  "Write merged runtime/provider WAT to path."
  (set! runtime-wat-file (resolve-repo-path path))]
 [("--write-runtime-wasm") path
  "Assemble merged runtime/provider Wasm to path."
  (set! runtime-wasm-file (resolve-repo-path path))]
 [("--write-program-wat") path
  "Write normalized program WAT to path."
  (set! output-program-wat-file (resolve-repo-path path))]
 [("--write-program-wasm") path
  "Assemble normalized program Wasm to path."
  (set! output-program-wasm-file (resolve-repo-path path))]
 [("--write-host") path
  "Write generated Node host to path."
  (set! host-file (resolve-repo-path path))]
 [("--strip-program-entry-runtime-init")
  "Remove runtime init calls from the program entry; runtime/provider host owns them."
  (set! strip-program-entry-runtime-init? #t)]
 [("--retarget-provider-imports-to-core")
  "Retarget program provider imports to the core import namespace."
  (set! retarget-provider-imports? #t)]
 [("--run")
  "Run the generated host with Node."
  (set! run? #t)]
 #:multi
 [("--expect-stdout-line") line
  "Expected stdout line when --run is used; may be repeated."
  (set! expected-stdout-lines
        (append expected-stdout-lines (list line)))])

(for ([label (in-list '("--core-wat"
                        "--provider-wat"
                        "--program-wat"
                        "--write-runtime-wat"
                        "--write-runtime-wasm"
                        "--write-program-wat"
                        "--write-program-wasm"
                        "--write-host"))]
      [value (in-list (list core-wat-file
                            provider-wat-file
                            program-wat-file
                            runtime-wat-file
                            runtime-wasm-file
                            output-program-wat-file
                            output-program-wasm-file
                            host-file))])
  (unless value
    (raise-user-error 'check-provider-runtime-split
                      "missing ~a"
                      label)))

;; read-wat-module : path-string? -> list?
;;   Read one generated WAT module datum.
(define (read-wat-module path)
  (define datum (call-with-input-file path read))
  (match datum
    [`(module ,_ ...) datum]
    [_ (raise-user-error 'check-provider-runtime-split
                         "expected module datum in ~a"
                         path)]))

;; print-merge-info! : provider-runtime-merge-info? -> void?
;;   Print merge metrics in a stable, grep-friendly form.
(define (print-merge-info! info)
  (define collisions
    (provider-runtime-merge-info-provider-colliding-definition-names info))
  (printf "core-forms=~a\n"
          (provider-runtime-merge-info-core-form-count info))
  (printf "provider-forms=~a\n"
          (provider-runtime-merge-info-provider-form-count info))
  (printf "provider-imports-kept=~a\n"
          (provider-runtime-merge-info-provider-import-count info))
  (printf "provider-colliding-definitions=~a\n"
          (length collisions))
  (when (pair? collisions)
    (printf "provider-colliding-definition-sample=~s\n"
            (take collisions (min 20 (length collisions)))))
  (printf "merged-runtime-forms=~a\n"
          (provider-runtime-merge-info-merged-runtime-form-count info)))

;; host-reference : path-string? path-string? -> string?
;;   Return a runtime host reference for target relative to host path.
(define (host-reference host target)
  (path->string
   (find-relative-path
    (path->complete-path (or (path-only host) (current-directory))
                         (current-directory))
    (path->complete-path target (current-directory)))))

;; run-node-host : path-string? -> (values boolean? string? string?)
;;   Run one generated Node host and capture stdout/stderr.
(define (run-node-host host)
  (define node
    (or (find-executable-path "node")
        (raise-user-error 'check-provider-runtime-split
                          "could not find node on PATH")))
  (define host-dir
    (path->complete-path (or (path-only host) (current-directory))
                         (current-directory)))
  (define host-file-name
    (file-name-from-path host))
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define ok?
    (parameterize ([current-directory host-dir]
                   [current-output-port stdout]
                   [current-error-port stderr])
      (system* node (path->string host-file-name))))
  (values ok?
          (get-output-string stdout)
          (get-output-string stderr)))

(define core-module (read-wat-module core-wat-file))
(define provider-module (read-wat-module provider-wat-file))
(define program-module (read-wat-module program-wat-file))

(define merge-start-ms (current-inexact-milliseconds))
(define-values (runtime-module merge-info)
  (merge-provider-fragment-into-runtime core-module provider-module))
(define merge-end-ms (current-inexact-milliseconds))
(print-merge-info! merge-info)
(printf "merge-ms=~a\n" (~r (- merge-end-ms merge-start-ms)
                            #:precision '(= 1)))

(define normalized-program-module
  (let ([module (if strip-program-entry-runtime-init?
                    (strip-split-runtime-program-entry-init program-module)
                    program-module)])
    (if retarget-provider-imports?
        (retarget-provider-imports-to-runtime module)
        module)))

(define write-runtime-start-ms (current-inexact-milliseconds))
(write-wat-to-file runtime-wat-file runtime-module #:pretty? #f)
(define write-runtime-end-ms (current-inexact-milliseconds))
(printf "write-runtime-wat-ms=~a\n"
        (~r (- write-runtime-end-ms write-runtime-start-ms)
            #:precision '(= 1)))
(printf "runtime-wat=~a\n" runtime-wat-file)

(define write-program-start-ms (current-inexact-milliseconds))
(write-wat-to-file output-program-wat-file normalized-program-module #:pretty? #f)
(define write-program-end-ms (current-inexact-milliseconds))
(printf "write-program-wat-ms=~a\n"
        (~r (- write-program-end-ms write-program-start-ms)
            #:precision '(= 1)))
(printf "program-wat=~a\n" output-program-wat-file)

(define assemble-runtime-start-ms (current-inexact-milliseconds))
(define runtime-ok?
  (wat->wasm runtime-module
             #:wat runtime-wat-file
             #:wasm runtime-wasm-file
             #:write-wat? #f))
(define assemble-runtime-end-ms (current-inexact-milliseconds))
(printf "assemble-runtime-ms=~a\n"
        (~r (- assemble-runtime-end-ms assemble-runtime-start-ms)
            #:precision '(= 1)))
(unless runtime-ok?
  (raise-user-error 'check-provider-runtime-split
                    "wasm-tools failed to assemble ~a"
                    runtime-wat-file))
(printf "runtime-wasm=~a\n" runtime-wasm-file)

(define assemble-program-start-ms (current-inexact-milliseconds))
(define program-ok?
  (wat->wasm normalized-program-module
             #:wat output-program-wat-file
             #:wasm output-program-wasm-file
             #:write-wat? #f))
(define assemble-program-end-ms (current-inexact-milliseconds))
(printf "assemble-program-ms=~a\n"
        (~r (- assemble-program-end-ms assemble-program-start-ms)
            #:precision '(= 1)))
(unless program-ok?
  (raise-user-error 'check-provider-runtime-split
                    "wasm-tools failed to assemble ~a"
                    output-program-wat-file))
(printf "program-wasm=~a\n" output-program-wasm-file)

(with-output-to-file host-file
  (lambda ()
    (displayln
     (runtime #:out (host-reference host-file output-program-wasm-file)
              #:core-out (host-reference host-file runtime-wasm-file)
              #:core-provider-imports-from-core? (not retarget-provider-imports?)
              #:core-initialize? strip-program-entry-runtime-init?
              #:core-provider-entry "provider-entry"
              #:host 'node)))
  #:exists 'replace)
(printf "host=~a\n" host-file)

(when run?
  (define-values (ok? stdout stderr)
    (run-node-host host-file))
  (printf "run-status=~a\n" (if ok? 'ok 'failed))
  (printf "run-stdout:\n")
  (display stdout)
  (unless (string=? stderr "")
    (printf "run-stderr:\n")
    (display stderr))
  (when (pair? expected-stdout-lines)
    (define expected-stdout
      (string-append (string-join expected-stdout-lines "\n") "\n"))
    (unless (string=? stdout expected-stdout)
      (raise-user-error 'check-provider-runtime-split
                        "unexpected stdout\nexpected: ~s\nactual: ~s"
                        expected-stdout
                        stdout)))
  (unless ok?
    (raise-user-error 'check-provider-runtime-split
                      "generated Node host failed")))
