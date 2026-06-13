#lang racket/base
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
         current-module-bridge-module-kinds
         current-webify-knowns-mode
         current-letrec-strategy
         current-tree-shake?
         current-runtime-cache-dir
         current-runtime-primitive-report-path
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
(define current-module-bridge-module-kinds
  (make-parameter #f))                                 ; (or/c #f hasheq?) module-name -> local/support/installed kind
(define current-webify-knowns-mode
  (make-parameter 'normal))                            ; 'normal or 'abi-only knowns usage during webify
(define current-letrec-strategy (make-parameter 'scc)) ; 'basic, 'waddell, or 'scc
(define current-tree-shake?     (make-parameter #t))  ; boolean? tree shake runtime primitives
(define current-runtime-cache-dir
  (make-parameter #f))                                 ; path-string? or #f
(define current-runtime-primitive-report-path
  (make-parameter #f))                                 ; path-string? or #f
(define current-runtime-timing-rows
  (make-parameter #f))                                 ; (or/c #f (listof (list/c string? real?)))
(define current-runtime-metric-rows
  (make-parameter #f))                                 ; (or/c #f (listof (list/c string? string?)))
