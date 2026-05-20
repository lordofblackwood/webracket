#lang racket/base

(require rackunit
         "kernel-runtime-audit.rkt"
         "module-audit.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt")

(test-case "runtime primitive implementation check reads runtime-wasm definitions"
  (check-true (webify-runtime-primitive-implemented? 'exn:fail:syntax?))
  (check-false (webify-runtime-primitive-implemented? 'raise-syntax-error)))

(test-case "kernel runtime audit distinguishes explicit unsupported services"
  (check-true (webify-kernel-runtime-explicitly-unsupported?
               'raise-syntax-error))
  (check-false (webify-kernel-runtime-explicitly-unsupported?
                'exn:fail:syntax?)))

(test-case "kernel runtime audit reports resolved kernel imports missing runtime functions"
  (define input
    (webify-module-linklet-input
     'use-kernel
     '(linklet (([reverse reverse]
                 [raise-syntax-error raise-syntax-error]))
        (y)
        (define-values (y) reverse))
     '((exn:fail:syntax? #%kernel exn:fail:syntax?)
       (raise-syntax-error #%kernel raise-syntax-error))))
  (define audit
    (webify-module-graph-audit
     '()
     '()
     '()
     '()
     '()
     '()
     '()
     '()
     (list input)
     '()))
  (check-equal? (webify-module-graph-audit-kernel-runtime-gaps audit)
                '(raise-syntax-error))
  (check-equal?
   (webify-module-graph-audit-kernel-runtime-actionable-gaps audit)
   '()))
