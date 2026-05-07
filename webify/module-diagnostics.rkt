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
    [(regexp-match? #rx"compiled module did not produce a linklet directory or direct linklet" message)
     'compiled-provider-shape]
    [(regexp-match? #rx"cannot open module file[^\n]*\n  module path: racket/for" message)
     'provider-candidate-overreach]
    [(regexp-match? #rx"could not resolve import dependency|dependency does not export aliased name|unresolved import|ambiguous inferred import dependency" message)
     'unresolved-import]
    [(regexp-match? #rx"[.]get-syntax-literal!" message)
     'syntax-literal]
    [(regexp-match? #rx"redefine a primitive at the top-level" message)
     'primitive-alias-collision]
    [(regexp-match? #rx"unsupported|not supported" message)
     'unsupported-runtime]
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
