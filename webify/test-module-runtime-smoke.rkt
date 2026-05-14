#lang racket/base

(require rackunit
         "module-input.rkt"
         "module-registry.rkt"
         "module-runtime-smoke.rkt"
         "primitive-demands.rkt")

(define local-runtime-smokes
  (list
   (local-runtime-smoke
    "hand-authored two-module graph runs through WebRacket runtime"
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (x)
         (define-values (x) 20))
      '())
     (webify-module-linklet-input
      'consumer
      '(linklet (([ext-x x])) (y)
         (define-values (y) (+ ext-x 22)))
      '((ext-x provider x))))
    '(consumer)
    '((consumer y))
    #rx"(?m:^42$)"
    '()
    #f)
   (local-runtime-smoke
    "resolved re-export graph can use the backing provider cell"
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (internal-x)
         (define-values (internal-x) 20))
      '())
     (webify-module-linklet-input
      'reexport
      '(linklet (([local-x internal-x])) (public-x)
         (define-values (public-x) local-x))
      '((local-x provider internal-x)))
     (webify-module-linklet-input
      'consumer
      '(linklet (([public-x internal-x])) (answer)
         (define-values (answer) (+ public-x 22)))
      '((public-x provider internal-x))))
    '(reexport consumer)
    '((reexport public-x)
      (consumer answer))
    #rx"(?s:20.*42)"
    '()
    #f)
   (local-runtime-smoke
    "renamed import graph reaches WebRacket runtime"
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (x)
         (define-values (x) 41))
      '())
     (webify-module-linklet-input
      'consumer
      '(linklet (([renamed-x x])) (answer)
         (define-values (answer) (+ renamed-x 1)))
      '((renamed-x provider x))))
    '(consumer)
    '((consumer answer))
    #rx"(?m:^42$)"
    '()
    #f)
   (local-runtime-smoke
    "multi-root graph shares provider instances"
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (x)
         (define-values (x) 20))
      '())
     (webify-module-linklet-input
      'left-root
      '(linklet (([x x])) (left)
         (define-values (left) (+ x 1)))
      '((x provider x)))
     (webify-module-linklet-input
      'right-root
      '(linklet (([x x])) (right)
         (define-values (right) (+ x 2)))
      '((x provider x))))
    '(left-root right-root)
    '((left-root left)
      (right-root right))
    #rx"(?s:21.*22)"
    '()
    #f)
   (local-runtime-smoke
    "missing runtime primitive is classified before WebRacket runs"
    (list
     (webify-module-linklet-input
      'needs-missing-primitive
      '(linklet (((missing missing))) (out)
         (define-values (out) missing))
      '((missing #%kernel not-a-real-kernel-primitive))))
    '(needs-missing-primitive)
    '((needs-missing-primitive out))
    #rx"never-matches-success"
    '(primitive-demand-preflight)
    #rx"not-a-real-kernel-primitive")
   (local-runtime-smoke
    "missing provider export is classified during composition"
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (x)
         (define-values (x) 20))
      '())
     (webify-module-linklet-input
      'consumer
      '(linklet (([x x])) (answer)
         (define-values (answer) (+ x 22)))
      '((x provider missing-export))))
    '(consumer)
    '((consumer answer))
    #rx"never-matches-success"
    '(provider-export-mismatch)
    #rx"missing-export")
   (local-runtime-smoke
    "escape out of letrec RHS preserves unsafe-undefined guard"
    (list
     (webify-module-linklet-input
      'escape-letrec
      '(linklet () (y)
         (define-values (y)
           ((call-with-escape-continuation
             (lambda (escape)
               (letrec-values ([(x)
                                (escape
                                 (lambda ()
                                   (check-not-unsafe-undefined x 'x)))])
                 x))))))
      '()))
    '(escape-letrec)
    '((escape-letrec y))
    #rx"never-matches-success"
    '(runtime-exception)
    #rx"exn:fail:contract:variable")
   (local-runtime-smoke
    "custom-write/pretty shaped import preserves unsafe-undefined guard"
    (list
     (webify-module-linklet-input
      'racket/pretty
      '(linklet () (make-tentative-pretty-print-output-port)
         (define-values (make-tentative-pretty-print-output-port)
           (call-with-escape-continuation
            (lambda (escape)
              (letrec-values ([(x)
                               (escape
                                (lambda ()
                                  (check-not-unsafe-undefined
                                   x
                                   'make-tentative-pretty-print-output-port)))])
                x)))))
      '())
     (webify-module-linklet-input
      'racket/private/custom-write
      '(linklet (([make-tentative-pretty-print-output-port
                   make-tentative-pretty-print-output-port]))
         (y)
         (define-values
           (y)
           (make-tentative-pretty-print-output-port)))
      '((make-tentative-pretty-print-output-port
         racket/pretty
         make-tentative-pretty-print-output-port))))
    '(racket/private/custom-write)
    '((racket/private/custom-write y))
    #rx"never-matches-success"
    '(runtime-exception)
    #rx"exn:fail:contract:variable")))

(test-case "multi-root local manifest plans shared provider once"
  (define inputs
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (x)
         (define-values (x) 20))
      '())
     (webify-module-linklet-input
      'left-root
      '(linklet (([x x])) (left)
         (define-values (left) (+ x 1)))
      '((x provider x)))
     (webify-module-linklet-input
      'right-root
      '(linklet (([x x])) (right)
         (define-values (right) (+ x 2)))
      '((x provider x)))))
  (define registry
    (webify-module-linklet-manifest->registry
     (webify-module-linklet-manifest inputs '(left-root right-root))))
  (check-equal?
   (webify-module-registry-plan registry '(left-root right-root))
   '(provider left-root right-root)))

(test-case "runtime smoke graph audit summarizes plan, imports, and primitive demands"
  (define inputs
    (list
     (webify-module-linklet-input
      'provider
      '(linklet () (x)
         (define-values (x) 20))
      '())
     (webify-module-linklet-input
      'consumer
      '(linklet (((cons cons)) ([x x])) (answer)
         (define-values (answer) (cons x '())))
      '((cons #%kernel cons)
        (x provider x)))))
  (define audit
    (webify-module-linklet-manifest->runtime-smoke-graph-audit
     (webify-module-linklet-manifest inputs '(consumer))))
  (check-equal? (runtime-smoke-graph-audit-roots audit) '(consumer))
  (check-equal? (runtime-smoke-graph-audit-input-names audit) '(provider consumer))
  (check-equal? (runtime-smoke-graph-audit-plan audit) '(provider consumer))
  (check-equal?
   (runtime-smoke-graph-audit-imports audit)
   '((provider ())
     (consumer ((cons #%kernel cons)
                (x provider x)))))
  (check-equal?
   (runtime-smoke-graph-audit-primitive-demands audit)
   '((#%kernel cons (consumer))))
  (check-equal?
   (runtime-smoke-graph-audit-missing-primitive-demands audit)
   '()))

(test-case "runtime smoke preflight reports missing primitive-table entries"
  (define input
    (webify-module-linklet-input
     'needs-missing-primitive
     '(linklet (((missing missing))) (out)
        (define-values (out) missing))
     '((missing #%kernel not-a-real-kernel-primitive))))
  (define missing
    (installed-runtime-inputs-missing-primitive-demands (list input)))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        missing)
   '((#%kernel not-a-real-kernel-primitive (needs-missing-primitive)))))

(test-case "runtime smoke preflight accepts present primitive-table entries"
  (define input
    (webify-module-linklet-input
     'needs-present-primitive
     '(linklet (((cons cons))) (out)
        (define-values (out) cons))
     '((cons #%kernel cons))))
  (check-equal?
   (installed-runtime-inputs-missing-primitive-demands (list input))
   '()))

(for ([smoke (in-list local-runtime-smokes)])
  (test-case (local-runtime-smoke-name smoke)
    (run-local-runtime-smoke smoke)))

(module+ main
  (void))
