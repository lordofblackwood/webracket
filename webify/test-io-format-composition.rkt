#lang racket/base

(require racket/file
         racket/string
         rackunit
         "io-format-provider.rkt"
         "test-module-support.rkt")

;; make-io-format-fixture-registry : -> webify-module-registry?
;;   Build a tiny provider graph with the same export names as `io/format`.
(define (make-io-format-fixture-registry)
  (define registry (make-webify-module-registry))
  (webify-module-registry-add!
   registry
   'io-format-provider
   '(linklet () (format fprintf printf eprintf)
      (define-values (format)
        (lambda (fmt v)
          (string-append "fmt:" fmt ":" v)))
      (define-values (fprintf)
        (lambda (out fmt v)
          (write-string (format fmt v) out)
          (void)))
      (define-values (printf)
        (lambda (fmt v)
          (fprintf (current-output-port) fmt v)))
      (define-values (eprintf)
        (lambda (fmt v)
          (fprintf (current-error-port) fmt v)))))
  registry)

;; compose-io-format-fixture : webify-module-registry? -> webify-module-composition?
;;   Compose without top-level aliases, because `format` is still a primitive.
(define (compose-io-format-fixture registry)
  (webify-compose-module-registry/roots/composition
   registry
   '(io-format-provider)
   #:define-export-aliases? #f
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

(test-case "synthetic io/format provider composes through module-variable cells"
  (define registry (make-io-format-fixture-registry))
  (define composition (compose-io-format-fixture registry))
  (for ([name (in-list io-format-provider-symbols)])
    (check-true (symbol? (webify-module-composition-export-cell-id
                          composition
                          'io-format-provider
                          name))))
  (define fmt-cell
    (webify-module-composition-export-cell-id composition 'io-format-provider 'format))
  (define combined
    (webify-module-composition-with-tail
     composition
     `((define provided-format (module-variable-ref ,fmt-cell))
       (js-log (provided-format "hello" "world")))))
  (define normalized (normalize-symbols combined))
  (check-not-false
   (member `("define" "provided-format"
             ("module-variable-ref" ,(symbol->string fmt-cell)))
           normalized))
  (check-true (string-contains? (wat-string (comp (datum->syntax #f combined)))
                                "$module-variable-ref")))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "synthetic io/format provider fixture runs under --no-stdlib"
    (define source-dir (make-temporary-file "webracket-io-format-provider-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-io-format-provider-dest-~a" 'directory))
    (define source-path (build-path source-dir "io-format-provider-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define registry (make-io-format-fixture-registry))
        (define composition (compose-io-format-fixture registry))
        (define fmt-cell
          (webify-module-composition-export-cell-id composition 'io-format-provider 'format))
        (define fprintf-cell
          (webify-module-composition-export-cell-id composition 'io-format-provider 'fprintf))
        (define combined
          (webify-module-composition-with-tail
           composition
           `((define provided-format (module-variable-ref ,fmt-cell))
             (define provided-fprintf (module-variable-ref ,fprintf-cell))
             (define out (open-output-string))
             (provided-fprintf out "hello" "cell")
             (js-log (provided-format "hello" "world"))
             (js-log (get-output-string out)))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir
                         #:timeout-seconds 120
                         #:memory-mb 1024))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^fmt:hello:world$)" output)
        (check-regexp-match #rx"(?m:^fmt:hello:cell$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(module+ main
  (void))
