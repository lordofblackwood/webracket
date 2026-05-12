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

(define-values (datum-status datum-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/direct-expand-kernel-datum"
             "[]"))
(unless (not (zero? datum-status))
  (error 'check-expander-kernel-smoke
         "datum probe unexpectedly succeeded; update this smoke test\noutput:\n~a"
         datum-output))
(reject-output datum-output "call-with-continuation-barrier")
(require-output datum-output "application: not a procedure")

(printf "expander-kernel-smoke: quote ok; datum frontier is application-not-procedure\n")
