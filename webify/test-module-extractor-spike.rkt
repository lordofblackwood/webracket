#lang racket/base

(require rackunit
         "module-input.rkt"
         "module-extractor-spike.rkt")

(test-case "extractor spike reports compiled module linklet metadata"
  (define report
    (webify-compile-module-extractor-spike
     '(module a racket/base
        (provide x)
        (define x 10))))
  (check-true (webify-module-extractor-spike? report))
  (check-equal? (webify-module-extractor-spike-name report) 'a)
  (check-equal? (webify-module-extractor-spike-directory-keys report)
                '(#f configure-runtime))
  (check-not-false
   (andmap (lambda (key)
             (member key (webify-module-extractor-spike-bundle-keys report)))
           '(0 decl data)))
  (check-equal? (webify-module-extractor-spike-phase0-exports report) '(x))
  (check-not-false
   (member '(.get-syntax-literal!)
           (webify-module-extractor-spike-phase0-imports report)))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-match (webify-module-extractor-spike-phase0-linklet-datum report)
                  `(linklet ,_ ,exports . ,_))
     (check-equal? (caddr (webify-module-extractor-spike-phase0-linklet-datum report))
                   '(x))
     (check-not-false
      (member "machine-independent compilation exposes a decompilable phase-0 linklet datum"
              (webify-module-extractor-spike-notes report)))]
    [else
     (check-false (webify-module-extractor-spike-phase0-linklet-datum report))
     (check-not-false
      (member "host Racket does not provide decompile-linklet"
              (webify-module-extractor-spike-notes report)))]))

(test-case "extractor spike rejects non-module data"
  (check-exn
   #rx"expected a source module datum"
   (lambda ()
     (webify-compile-module-extractor-spike
      '(define x 10)))))

(test-case "source module extractor returns linklet input when available"
  (define module-datum
    '(module a racket/base
       (provide x)
       (define x 10)))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (define input (webify-source-module->linklet-input module-datum))
     (check-true (webify-module-linklet-input? input))
     (check-equal? (webify-module-linklet-input-name input) 'a)
     (check-false (webify-module-linklet-input-imports input))
     (check-match (webify-module-linklet-input-linklet input)
                  `(linklet ,_ ,_ . ,_))
     (check-equal? (caddr (webify-module-linklet-input-linklet input))
                   '(x))

     (define import-triples
       '((.get-syntax-literal! kernel .get-syntax-literal!)
         (.set-transformer! kernel .set-transformer!)))
     (define explicit-input
       (webify-source-module->linklet-input module-datum
                                            #:imports import-triples))
     (check-equal? (webify-module-linklet-input-imports explicit-input)
                   import-triples)]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->linklet-input module-datum)))]))

(module+ main
  (void))
