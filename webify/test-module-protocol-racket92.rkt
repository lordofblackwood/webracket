#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-protocol.rkt")

(test-case "Racket 9.2 module protocol provider resolves source report imports"
  (define report
    (webify-compile-module-report
     '(module a racket/base
        (provide x)
        (define x 10))))
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
