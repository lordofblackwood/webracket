#lang racket/base

(provide webify-runtime-primitive-implemented?
         webify-kernel-runtime-explicitly-unsupported?
         webify-module-graph-audit-kernel-runtime-gaps
         webify-module-graph-audit-kernel-runtime-actionable-gaps)

(require racket/list
         racket/match
         racket/port
         racket/runtime-path
         racket/string
         "module-audit.rkt"
         "module-input.rkt")

(define-runtime-path default-runtime-wasm "../runtime-wasm.rkt")

;; webify-runtime-primitive-implemented? : symbol? [path-string?] -> boolean?
;;   Check whether runtime-wasm.rkt defines a Wasm function for a primitive.
(define (webify-runtime-primitive-implemented? name [runtime-path default-runtime-wasm])
  (define text (call-with-input-file runtime-path port->string))
  (string-contains? text (format "(func $~a" name)))

;; explicitly-unsupported-kernel-runtime-primitives : (listof symbol?)
;;   Kernel services that can appear in provider metadata but are outside Goal 1's
;;   ahead-of-time module-runtime contract unless code actually reaches them.
(define explicitly-unsupported-kernel-runtime-primitives
  '(collection-file-path
    collection-path
    do-raise-syntax-error
    raise-syntax-error
    syntax-binding-set-extend
    syntax-deserialize
    syntax-serialize))

;; webify-kernel-runtime-explicitly-unsupported? : symbol? -> boolean?
;;   Recognize kernel names that are intentionally not implemented in WebRacket.
(define (webify-kernel-runtime-explicitly-unsupported? name)
  (and (memq name explicitly-unsupported-kernel-runtime-primitives) #t))

;; webify-module-graph-audit-kernel-runtime-gaps : webify-module-graph-audit? [path-string?] -> (listof symbol?)
;;   Report resolved #%kernel imports whose primitive names are not runtime-backed.
(define (webify-module-graph-audit-kernel-runtime-gaps audit [runtime-path default-runtime-wasm])
  (unless (webify-module-graph-audit? audit)
    (raise-argument-error 'webify-module-graph-audit-kernel-runtime-gaps
                          "webify-module-graph-audit?"
                          audit))
  (define kernel-imports
    (for*/list ([input (in-list (webify-module-graph-audit-resolved-inputs audit))]
                [import (in-list (webify-module-linklet-input-imports input))]
                #:when (match import
                         [(list _ '#%kernel (? symbol? provider-export)) provider-export]
                         [_ #f]))
      (match import
        [(list _ '#%kernel provider-export) provider-export])))
  (sort
   (remove-duplicates
    (filter (lambda (name)
              (not (webify-runtime-primitive-implemented? name runtime-path)))
            kernel-imports))
   symbol<?))

;; webify-module-graph-audit-kernel-runtime-actionable-gaps : webify-module-graph-audit? [path-string?] -> (listof symbol?)
;;   Report runtime gaps after filtering kernel services with an explicit unsupported policy.
(define (webify-module-graph-audit-kernel-runtime-actionable-gaps audit [runtime-path default-runtime-wasm])
  (filter-not webify-kernel-runtime-explicitly-unsupported?
              (webify-module-graph-audit-kernel-runtime-gaps audit runtime-path)))
