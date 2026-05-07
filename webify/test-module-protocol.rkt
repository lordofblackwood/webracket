#lang racket/base

(require rackunit
         racket/file
         racket/path
         "test-module-support.rkt")

(test-case "module protocol exposes report and input providers"
  (check-equal? webify-module-protocol-name 'module-protocol)
  (check-equal? webify-module-protocol-dependency 'module-protocol)
  (check-true (webify-module-report? webify-module-protocol-report))
  (check-true (webify-module-linklet-input? webify-module-protocol-input))
  (check-equal? (webify-module-report-name webify-module-protocol-report)
                'module-protocol)
  (check-equal? (webify-module-report-phase0-exports webify-module-protocol-report)
                '(.get-syntax-literal! .set-transformer!))
  (check-equal? (webify-module-linklet-input-dependency-exports
                 webify-module-protocol-input)
                '(module-protocol (.get-syntax-literal! .set-transformer!))))

(test-case "module protocol report resolves compiled module protocol imports"
  (define source-module
    '(module a racket/base
       (provide x)
       (define x 10)))
  (define report (webify-compile-module-report source-module))
  (cond
    [(webify-module-report-manifest-ready? report)
     (define input
       (webify-module-report->resolved-linklet-input/providers
        report
        (list webify-module-protocol-report)
        #:module-protocol-dependency webify-module-protocol-dependency))
     (check-equal? (webify-module-linklet-input-imports input)
                   '((.get-syntax-literal! module-protocol .get-syntax-literal!)
                     (.set-transformer! module-protocol .set-transformer!)))]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-module-report->resolved-linklet-input/providers
         report
         (list webify-module-protocol-report)
         #:module-protocol-dependency webify-module-protocol-dependency)))]))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "module protocol graph runs through WebRacket"
    (define source-dir (make-temporary-file "webracket-module-protocol-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-module-protocol-dest-~a" 'directory))
    (define source-path (build-path source-dir "module-protocol-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define report
          (webify-module-report
           'a
           '(#f)
           '(0)
           '()
           '((.get-syntax-literal!) (.set-transformer!))
           '(x)
           '(linklet (((.get-syntax-literal! .get-syntax-literal!))
                      ((.set-transformer! .set-transformer!)))
              (x)
              (define-values (x) 10))
           #t
           '()))
        (define registry
          (webify-module-reports->registry
           (list webify-module-protocol-report report)
           #:module-protocol-dependency webify-module-protocol-dependency))
        (define loader (make-webify-module-loader registry))
        (webify-module-loader-instantiate!
         loader
         '(a)
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
         #:import-keys           #f)
        (write-datum-program!
         source-path
         (webify-module-loader-observe loader '((a x))))
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir))))))

  (test-case "module protocol syntax literal calls fail fast"
    (define source-dir (make-temporary-file "webracket-module-protocol-syntax-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-module-protocol-syntax-dest-~a" 'directory))
    (define source-path (build-path source-dir "module-protocol-syntax-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define report
          (webify-module-report
           'a
           '(#f)
           '(0)
           '()
           '((.get-syntax-literal!))
           '(x)
           '(linklet (((.get-syntax-literal! .get-syntax-literal!)))
              (x)
              (define-values (x) (.get-syntax-literal! 'x)))
           #t
           '()))
        (define registry
          (webify-module-reports->registry
           (list webify-module-protocol-report report)
           #:module-protocol-dependency webify-module-protocol-dependency))
        (define loader (make-webify-module-loader registry))
        (write-datum-program!
         source-path
         (webify-module-loader-instantiate-observe!
          loader
          '(a)
          '((a x))
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
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (define failure (webify-classify-runtime-output status output))
        (check-true (webify-module-failure? failure))
        (check-equal? (webify-module-failure-category failure) 'syntax-literal output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(module+ main
  (void))
