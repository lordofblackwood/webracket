#lang racket/base

(require racket/file
         racket/path
         rackunit
         "module-input.rkt"
         "module-runtime-smoke.rkt"
         "primitive-demands.rkt"
         "test-module-support.rkt")

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

(test-case "hand-authored two-module graph runs through WebRacket runtime"
  (define source-dir (make-temporary-file "webracket-runtime-smoke-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-runtime-smoke-dest-~a" 'directory))
  (define source-path (build-path source-dir "two-module-runtime.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (define registry
        (webify-module-linklet-inputs->registry
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
           '((ext-x provider x))))))
      (define-values (combined _fragments _instances _exports-infos)
        (compose-module-registry/roots+observations
         registry
         '(consumer)
         '((consumer y))))
      (write-datum-program! source-path combined)
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(module+ main
  (void))
