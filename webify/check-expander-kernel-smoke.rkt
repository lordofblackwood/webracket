#lang racket/base

(require racket/cmdline
         racket/match
         racket/port
         racket/string)

;; run-probe : path-string? string? string? -> (values exact-integer? string?)
;;   Run one bounded expander probe against a compiled expander wasm.
(define (run-probe wasm-path export-name json-args)
  (define node (or (find-executable-path "node")
                   (error 'check-expander-kernel-smoke "node not found")))
  (define-values (proc out in err)
    (subprocess #f #f #f
                node
                "--experimental-wasm-exnref"
                "webify/probe-expander-instantiate.js"
                wasm-path
                "--bounded-call-json"
                "20000"
                export-name
                json-args))
  (close-output-port in)
  (define stdout (port->string out))
  (define stderr (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (values status (string-append stdout stderr)))

;; require-output : string? string? -> void?
;;   Fail unless needle appears in output.
(define (require-output output needle)
  (unless (string-contains? output needle)
    (error 'check-expander-kernel-smoke
           "expected output to contain ~s\noutput:\n~a"
           needle
           output)))

;; reject-output : string? string? -> void?
;;   Fail if needle appears in output.
(define (reject-output output needle)
  (when (string-contains? output needle)
    (error 'check-expander-kernel-smoke
           "expected output not to contain ~s\noutput:\n~a"
           needle
           output)))

(define wasm-path
  (command-line
   #:program "check-expander-kernel-smoke"
   #:args ([wasm-path "/private/tmp/webracket-expander-startup.wasm"])
   wasm-path))

(unless (file-exists? wasm-path)
  (error 'check-expander-kernel-smoke
         "compiled expander wasm not found: ~a"
         wasm-path))

(define (check-ok-probe export-name json-args after-marker expected-datum-fragment)
  (define-values (status output)
    (run-probe wasm-path export-name json-args))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "probe ~a failed with status ~a\noutput:\n~a"
           export-name
           status
           output))
  (require-output output after-marker)
  (require-output output expected-datum-fragment)
  (void))

;; check-failing-probe : string? string? (listof string?) (listof string?) -> void?
;;   Require a known frontier failure and reject old internal failure modes.
(define (check-failing-probe export-name json-args required-fragments rejected-fragments)
  (define-values (status output)
    (run-probe wasm-path export-name json-args))
  (when (zero? status)
    (error 'check-expander-kernel-smoke
           "probe ~a unexpectedly succeeded\noutput:\n~a"
           export-name
           output))
  (for ([fragment (in-list required-fragments)])
    (require-output output fragment))
  (for ([fragment (in-list rejected-fragments)])
    (reject-output output fragment))
  (void))

(define-values (quote-status quote-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/direct-expand-kernel-quote"
             "[]"))
(unless (zero? quote-status)
  (error 'check-expander-kernel-smoke
         "quote probe failed with status ~a\noutput:\n~a"
         quote-status
         quote-output))
(require-output quote-output "probe:direct-expand-kernel-quote:after-expand")
(require-output quote-output "(quote 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-datum"
 "[]"
 "probe:direct-expand-kernel-datum:after-expand"
 "(quote 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-let"
 "[]"
 "probe:direct-expand-kernel-let:after-expand"
 "(#%top . let)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-let-values"
 "[]"
 "probe:direct-expand-kernel-let-values:after-expand"
 "(let-values")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-if"
 "[]"
 "probe:direct-expand-kernel-if:after-expand"
 "(if (quote #t)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-lambda"
 "[]"
 "probe:direct-expand-kernel-lambda:after-expand"
 "(lambda (x) x)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-primitive-app"
 "[]"
 "probe:direct-expand-kernel-primitive-app:after-expand"
 "(#%top . +)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/ordinary-kernel-datum"
 "[]"
 "probe:ordinary-kernel-datum:after-expand"
 "(quote 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/ordinary-kernel-primitive-app"
 "[]"
 "probe:ordinary-kernel-primitive-app:after-expand"
 "(#%app + (quote 1) (quote 2))")

(check-ok-probe
 "webify-probe-expand-self-evaluating/ordinary-kernel-if"
 "[]"
 "probe:ordinary-kernel-if:after-expand"
 "(if (quote #t) (quote 1) (quote 2))")

(define-values (ordinary-binding-status ordinary-binding-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/ordinary-kernel-binding-audit"
             "[]"))
(unless (zero? ordinary-binding-status)
  (error 'check-expander-kernel-smoke
         "ordinary binding audit failed with status ~a\noutput:\n~a"
         ordinary-binding-status
         ordinary-binding-output))
(require-output ordinary-binding-output "probe:ordinary-kernel-binding-audit:after-require")
(require-output ordinary-binding-output "(#%datum #t)")
(for ([fragment (in-list '("(#%app #t)"
                           "(quote #t)"
                           "(if #t)"
                           "(lambda #t)"
                           "(let-values #t)"
                           "(+ #t)"))])
  (require-output ordinary-binding-output fragment))

(define-values (compile-status compile-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/compile-kernel-datum"
             "[]"))
(unless (zero? compile-status)
  (error 'check-expander-kernel-smoke
         "compile kernel datum probe failed with status ~a\noutput:\n~a"
         compile-status
         compile-output))
(require-output compile-output "probe:compile-kernel-datum:before-compile")
(require-output compile-output "probe:compile-kernel-datum:after-compile")
(require-output compile-output "compile-kernel-datum:returned")

(for ([probe (in-list
              '("webify-probe-expand-self-evaluating/compile-kernel-quote"
                "webify-probe-expand-self-evaluating/compile-kernel-let-values"
                "webify-probe-expand-self-evaluating/compile-kernel-if"
                "webify-probe-expand-self-evaluating/compile-kernel-lambda"
                "webify-probe-expand-self-evaluating/compile-kernel-primitive-app"))])
  (define marker
    (string-replace
     (substring probe
                (string-length "webify-probe-expand-self-evaluating/"))
     "/" ":"))
  (define-values (status output) (run-probe wasm-path probe "[]"))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "compile matrix probe ~a failed with status ~a\noutput:\n~a"
           probe
           status
           output))
  (require-output output (format "probe:~a:after-compile" marker))
  (require-output output (format "~a:returned" marker)))

(check-failing-probe
 "webify-probe-expand-self-evaluating/full-expander-syntax/invoke-budget"
 "[20000]"
 '("probe:full-expander-syntax/invoke-budget:before-expand"
   "failure-detail: ?: literal data is not allowed;")
 '("procedure-arity-frontier"
   "failure-detail: exception-handler-key"
   "heap out of memory"))

(check-failing-probe
 "webify-probe-expand-self-evaluating/compile-expander-syntax/invoke-budget"
 "[20000]"
 '("probe:compile-expander-syntax/invoke-budget:before-compile"
   "failure-detail: ?: literal data is not allowed;")
 '("procedure-arity-frontier"
   "failure-detail: exception-handler-key"
   "heap out of memory"))

(printf "expander-kernel-smoke: kernel matrix and ordinary #%kernel namespace probes ok\n")
