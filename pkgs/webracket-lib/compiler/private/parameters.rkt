#lang racket/base
(require racket/set)

(provide current-ffi-foreigns
         current-ffi-imports-wat
         current-ffi-funcs-wat
         current-browser?
         current-enable-cc-analysis?
         current-console-bridge?
         current-console-bridge-root-export-bindings
         current-console-bridge-root-source-path
         current-enable-simplify?
         current-module-bridge-elide-public-cells?
         current-module-bridge-elidable-module-names
         current-module-bridge-local-report-names
         current-module-bridge-support-provider-names
         current-module-bridge-module-kinds
         current-webify-knowns-mode
         current-letrec-strategy
         current-tree-shake?
         current-provider-owned-primitive-aliases
         current-frontend-cache-enabled?
         current-runtime-cache-dir
         current-runtime-primitive-report-path
         current-runtime-extra-used-primitives
         current-split-runtime?
         current-split-runtime-reference-only?
         current-split-runtime-ffi-in-core?
         current-split-runtime-ffi-module?
         current-split-runtime-ffi-program-owned?
         current-split-runtime-program-only-fast-path?
         current-imported-top-level-global-module-name
         current-imported-top-level-globals
         current-exported-top-level-globals
         current-runtime-timing-rows
         current-runtime-metric-rows)

; The parameters are used by the driver to send
; the generated imports and funcs to the compiler and runtime generator.

(define current-ffi-foreigns    (make-parameter '())) ; list of `foreign` structures
(define current-ffi-imports-wat (make-parameter '())) ; list of s-exprs
(define current-ffi-funcs-wat   (make-parameter '())) ; list of s-exprs
(define current-browser?        (make-parameter #f))  ; boolean? browser mode flag
(define current-enable-cc-analysis?
  (make-parameter #f))                                 ; boolean? enable new closure-conversion analysis
(define current-console-bridge? (make-parameter #f))  ; boolean? install browser console bridge
(define current-console-bridge-root-export-bindings
  (make-parameter #f))                                 ; (or/c #f (listof hash?)) authoritative root export bridge metadata
(define current-console-bridge-root-source-path
  (make-parameter #f))                                 ; (or/c #f string?) original root module source path for bridge metadata
(define current-enable-simplify? (make-parameter #f)) ; boolean? run early simplify-LFE pass
(define current-module-bridge-elide-public-cells?
  (make-parameter #f))                                 ; boolean? expose safe module-bridge exports as plain values
(define current-module-bridge-elidable-module-names
  (make-parameter #f))                                 ; (or/c #f (listof symbol?)) modules allowed to elide public cells
(define current-module-bridge-local-report-names
  (make-parameter #f))                                 ; (or/c #f set?) local user-report names allowed to consume user-boundary alias facades
(define current-module-bridge-support-provider-names
  (make-parameter #f))                                 ; (or/c #f set?) support-provider names that should not consume user-boundary alias facades
(define current-module-bridge-module-kinds
  (make-parameter #f))                                 ; (or/c #f hasheq?) module-name -> local/support/installed kind
(define current-webify-knowns-mode
  (make-parameter 'normal))                            ; 'normal or 'abi-only knowns usage during webify
(define current-letrec-strategy (make-parameter 'scc)) ; 'basic, 'waddell, or 'scc
(define current-tree-shake?     (make-parameter #t))  ; boolean? tree shake runtime primitives
(define current-provider-owned-primitive-aliases
  (make-parameter (seteq)
    (lambda (aliases)
      (cond
        [(set? aliases) aliases]
        [(list? aliases) (list->seteq aliases)]
        [else
         (raise-argument-error 'current-provider-owned-primitive-aliases
                               "(or/c set? (listof symbol?))"
                               aliases)]))))          ; provider-owned public names that must resolve through staged providers
(define current-frontend-cache-enabled?
  (make-parameter #f))                                 ; boolean? cache post-unexpand frontend syntax
(define current-runtime-cache-dir
  (make-parameter #f))                                 ; path-string? or #f
(define current-runtime-primitive-report-path
  (make-parameter #f))                                 ; path-string? or #f
(define current-runtime-extra-used-primitives
  (make-parameter '()))                                ; (listof symbol?) extra runtime roots
(define current-split-runtime?
  (make-parameter #f))                                 ; boolean? generate split runtime module data
(define current-split-runtime-reference-only?
  (make-parameter #f))                                 ; boolean? split runtime core will not be materialized
(define current-split-runtime-ffi-in-core?
  (make-parameter #f))                                 ; boolean? keep direct split FFI wrappers in runtime
(define current-split-runtime-ffi-module?
  (make-parameter #f))                                 ; boolean? place direct split FFI wrappers in an FFI sidecar module
(define current-split-runtime-ffi-program-owned?
  (make-parameter #t))                                 ; boolean? split program imports/initializes active FFI wrappers
(define current-split-runtime-program-only-fast-path?
  (make-parameter #t))                                 ; boolean? allow warm split compiles to reuse boundary metadata only
(define current-imported-top-level-global-module-name
  (make-parameter "provider"))                         ; string? Wasm module for imported top-level boxes
(define current-imported-top-level-globals
  (make-parameter (seteq)
    (lambda (names)
      (cond
        [(set? names) names]
        [(list? names) (list->seteq names)]
        [else
         (raise-argument-error 'current-imported-top-level-globals
                               "(or/c set? (listof symbol?))"
                               names)]))))             ; top-level boxed globals imported from provider modules
(define current-exported-top-level-globals
  (make-parameter (seteq)
    (lambda (names)
      (cond
        [(set? names) names]
        [(list? names) (list->seteq names)]
        [else
         (raise-argument-error 'current-exported-top-level-globals
                               "(or/c set? (listof symbol?))"
                               names)]))))             ; top-level boxed globals exported for program modules
(define current-runtime-timing-rows
  (make-parameter #f))                                 ; (or/c #f (listof (list/c string? real?)))
(define current-runtime-metric-rows
  (make-parameter #f))                                 ; (or/c #f (listof (list/c string? string?)))
