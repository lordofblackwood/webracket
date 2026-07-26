#lang racket/base

(require rackunit
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         setup/getinfo)

(define-runtime-path repo-root "..")

;; maybe-local-racket-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-racket-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "racket")))
  (and (file-exists? p) p))

;; racket-path : path?
;;   Pick one Racket executable for the subprocess checks.
(define racket-path
  (or (maybe-local-racket-path)
      (find-executable-path "racket")))

;; skip! : string? -> none
;;   Exit cleanly with a visible skip reason.
(define (skip! msg)
  (displayln (string-append "SKIP: " msg))
  (exit 0))

(unless racket-path
  (skip! "could not find a Racket executable"))

(define pkgs-dir
  (build-path repo-root "pkgs"))
(define webracket-package-dir
  (build-path pkgs-dir "webracket"))

;; run-racket : (listof string?) -> (values exact-integer? string?)
;;   Run a checkout-local Racket command and collect combined output.
(define (run-racket args)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (apply system*/exit-code racket-path args)))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; check-entrypoint-help : string? (listof string?) -> void?
;;   Check that one public entrypoint reaches the shared CLI help.
(define (check-entrypoint-help name args)
  (define-values (status output)
    (run-racket args))
  (check-equal? status
                0
                (format "~a --help failed with output:\n~a" name output))
  (check-true (string-contains? output "webracket")
              (format "~a --help did not look like WebRacket help:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--browser")
              (format "~a --help omitted compiler flags:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--help-full")
              (format "~a --help omitted full-help pointer:\n~a"
                      name
                      output))
  (check-true (string-contains? output "Node mode only")
              (format "~a --help did not explain --run target:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--server-start")
              (format "~a --help omitted server start:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--server-status")
              (format "~a --help omitted server status:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--server-stop")
              (format "~a --help omitted server stop:\n~a"
                      name
                      output))
  (check-false (string-contains? output "--ffi")
               (format "~a --help printed legacy manual FFI flags:\n~a"
                       name
                       output))
  (check-false (string-contains? output "--force-provider-cache-refresh")
               (format "~a --help printed detailed provider flags:\n~a"
                       name
                       output)))

;; check-entrypoint-full-help : string? (listof string?) -> void?
;;   Check that the detailed help includes grouped expert options.
(define (check-entrypoint-full-help name args)
  (define-values (status output)
    (run-racket args))
  (define (check-blank-after-help-line help-line next-option)
    (define pattern
      (pregexp
       (format "~a\n[ ]*\n[ ]+~a"
               (regexp-quote help-line)
               (regexp-quote next-option))))
    (check-true (regexp-match? pattern output)
                (format "~a --help-full omitted blank line after ~s before ~a:\n~a"
                        name
                        help-line
                        next-option
                        output)))
  (check-equal? status
                0
                (format "~a --help-full failed with output:\n~a" name output))
  (check-false (string-contains? output "--help-full")
               (format "~a --help-full repeated the already-selected help flag:\n~a"
                       name
                       output))
  (check-true (string-contains? output "Provider and cache options")
              (format "~a --help-full omitted provider section:\n~a"
                      name
                      output))
  (check-true (regexp-match? #rx"\n[ ]*\n[ ]+Provider and cache options\n" output)
              (format "~a --help-full omitted blank line before provider section:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--force-provider-cache-refresh")
              (format "~a --help-full omitted provider cache flags:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--ffi")
              (format "~a --help-full omitted manual FFI flags:\n~a"
                      name
                      output))
  (check-true (string-contains? output "Debug and internal options")
              (format "~a --help-full omitted debug section:\n~a"
                      name
                      output))
  (check-true (string-contains? output "--internal-bind-treelist-debug-shape")
              (format "~a --help-full omitted internal flags:\n~a"
                      name
                      output))
  (check-blank-after-help-line
   "Emit the normal monolithic Wasm module"
   "--split-runtime-cache-reference")
  (check-blank-after-help-line
   "Use the current process environment when finding wasm-tools"
   "--console-bridge")
  (check-blank-after-help-line
   "Disable post-unexpand frontend syntax caching (default)"
   "--module-bridge-elide-public-cells")
  (check-blank-after-help-line
   "Enable Goal 1 provider substitutions (default)"
   "--provider-cache-dir"))

;; check-entrypoint-user-error : string? (listof string?) string? -> void?
;;   Check that a usage error is reported without an implementation stack.
(define (check-entrypoint-user-error name args expected-message)
  (define-values (status output)
    (run-racket args))
  (check-not-equal? status
                    0
                    (format "~a unexpectedly succeeded with output:\n~a"
                            name
                            output))
  (check-true (string-contains? output expected-message)
              (format "~a omitted expected user error:\n~a"
                      name
                      output))
  (check-false (string-contains? output "context...")
               (format "~a printed an implementation stack:\n~a"
                       name
                       output)))

;; test-command-module : -> void?
;;   Check the installed launcher target module directly.
(define (test-command-module)
  (check-entrypoint-help
   "webracket module"
   (list "-S" (path->string pkgs-dir)
         "-l" "webracket/command"
         "--" "--help"))
  (check-entrypoint-full-help
   "webracket module"
   (list "-S" (path->string pkgs-dir)
         "-l" "webracket/command"
         "--" "--help-full"))
  (check-entrypoint-user-error
   "webracket module"
   (list "-S" (path->string pkgs-dir)
         "-l" "webracket/command")
   "webracket: expected exactly one source filename, got 0"))

;; test-package-metadata : -> void?
;;   Check the package metadata that installs `webracket` and `raco webracket`.
(define (test-package-metadata)
  (define info
    (get-info/full webracket-package-dir))
  (check-equal? (info 'racket-launcher-names (lambda () #f))
                '("webracket"))
  (check-equal? (info 'racket-launcher-libraries (lambda () #f))
                '("command.rkt"))
  (check-equal? (info 'raco-commands (lambda () #f))
                '(("webracket"
                   webracket/command
                   "compile Racket programs to WebAssembly"
                   #f))))

(define (test-entrypoints)
  (test-command-module)
  (test-package-metadata))

(module+ test
  (test-entrypoints))

(module+ main
  (test-entrypoints)
  (displayln "ok"))
