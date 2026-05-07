#lang racket/base

(require rackunit
         "module-extractor.rkt"
         "module-registry.rkt")

(define module-protocol-report
  (webify-module-report
   'module-protocol
   '(#f)
   '(0)
   '()
   '()
   '(.get-syntax-literal! .set-transformer!)
   '(linklet () (.get-syntax-literal! .set-transformer!)
      (define-values (.get-syntax-literal!)
        (lambda (sym) (error '.get-syntax-literal! "not implemented in smoke")))
      (define-values (.set-transformer!)
        (lambda args (void))))
   #t
   '()))

(test-case "Racket 9.2 source module graph resolves into registry"
  (define source-module-data
    '((module a racket/base
        (provide x)
        (define x 10))
      (module b racket/base
        (provide y)
        (define y 20))))
  (define source-reports (map webify-compile-module-report source-module-data))
  (check-true (andmap webify-module-report-manifest-ready? source-reports))
  (define registry
    (webify-module-reports->registry
     (cons module-protocol-report source-reports)
     #:module-protocol-dependency 'module-protocol))
  (check-equal? (webify-module-registry-plan registry '(a b))
                '(module-protocol a b)))
