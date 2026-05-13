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
    #rx"not-a-real-kernel-primitive")))

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
