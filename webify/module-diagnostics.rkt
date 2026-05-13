#lang racket/base

(provide webify-module-failure
         webify-module-failure?
         webify-module-failure-stage
         webify-module-failure-category
         webify-module-failure-message
         webify-module-failure-details
         webify-classify-module-exn
         webify-classify-runtime-output)

(require racket/match
         racket/string)

(struct webify-module-failure (stage category message details) #:transparent)

;; classify-message : string? -> symbol?
;;   Map known bridge/compiler failure text to a stable diagnostic category.
(define (classify-message message)
  (cond
    [(regexp-match? #rx"decompilable phase-0 linklet datum" message)
     'missing-decompile]
    [(regexp-match? #rx"missing primitive-table entries before runtime smoke" message)
     'primitive-demand-preflight]
    [(regexp-match? #rx"compiled module did not produce a linklet directory or direct linklet" message)
     'compiled-provider-shape]
    [(regexp-match? #rx"cannot open module file[^\n]*\n  module path: racket/for" message)
     'provider-candidate-overreach]
    [(regexp-match? #rx"import: '(read|current-input-port|read-byte|read-char|read-line|read-bytes-line)" message)
     'io-dependent]
    [(regexp-match? #rx"import dependency has no export table entry" message)
     'provider-key-mismatch]
    [(regexp-match? #rx"unsupported kernel-origin binding" message)
     'unsupported-kernel-binding]
    [(regexp-match? #rx"missing-after-reflection|could not resolve import dependency|dependency does not export aliased name|unresolved import|ambiguous inferred import dependency" message)
     'unresolved-import]
    [(regexp-match? #rx"ambiguous-after-reflection|ambiguous import dependency" message)
     'ambiguous-import]
    [(regexp-match? #rx"[.]get-syntax-literal!" message)
     'syntax-literal]
    [(regexp-match? #rx"known-procedure-arity-mask" message)
     'known-procedure-metadata]
    [(regexp-match? #rx"with-continuation-mark[*]" message)
     'continuation-mark]
    [(regexp-match? #rx"datum->construction-expr: got: #rx" message)
     'regexp-literal]
    [(regexp-match? #rx"redefine a primitive at the top-level" message)
     'primitive-alias-collision]
    [(regexp-match? #rx"unsupported|not supported" message)
     'unsupported-runtime]
    [(regexp-match? #rx"Uncaught WebAssembly exception|RuntimeError:" message)
     'runtime-exception]
    [else
     'unknown]))

;; webify-classify-module-exn : symbol? exn? -> webify-module-failure?
;;   Classify a caught exception from extraction, resolution, composition, or runtime.
(define (webify-classify-module-exn stage exn)
  (unless (symbol? stage)
    (raise-argument-error 'webify-classify-module-exn "symbol?" stage))
  (unless (exn? exn)
    (raise-argument-error 'webify-classify-module-exn "exn?" exn))
  (define message (exn-message exn))
  (webify-module-failure stage
                         (classify-message message)
                         message
                         '()))

;; webify-classify-runtime-output : exact-integer? string? -> (or/c webify-module-failure? #f)
;;   Classify non-zero WebRacket command output; return #f for successful output.
(define (webify-classify-runtime-output status output)
  (unless (exact-integer? status)
    (raise-argument-error 'webify-classify-runtime-output "exact-integer?" status))
  (unless (string? output)
    (raise-argument-error 'webify-classify-runtime-output "string?" output))
  (and (not (zero? status))
       (webify-module-failure 'runtime
                              (classify-message output)
                              (string-trim output)
                              `((status ,status)))))
