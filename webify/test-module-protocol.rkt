#lang racket/base

(require rackunit
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

(module+ main
  (void))
