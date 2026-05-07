#lang racket/base

(require rackunit
         racket/match
         "module-input.rkt"
         "module-extractor-spike.rkt")

;; normalized-linklet-imports : linklet-datum -> (listof any/c)
;;   Pull normalized import bindings out of a linklet datum for tests.
(define (normalized-linklet-imports linklet)
  (match linklet
    [`(linklet ,importss ,_exports . ,_body)
     (apply append importss)]))

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
  (check-not-false
   (andmap webify-module-bundle-entry?
           (webify-module-extractor-spike-bundle-entries report)))
  (define phase0-entry (webify-module-bundle-entry-ref report 0))
  (define decl-entry (webify-module-bundle-entry-ref report 'decl))
  (define data-entry (webify-module-bundle-entry-ref report 'data))
  (check-equal? (webify-module-bundle-entry-kind phase0-entry) 'linklet)
  (check-equal? (webify-module-bundle-entry-kind decl-entry) 'linklet)
  (check-equal? (webify-module-bundle-entry-kind data-entry) 'linklet)
  (check-equal? (webify-module-bundle-entry-imports phase0-entry)
                (webify-module-extractor-spike-phase0-imports report))
  (check-equal? (webify-module-bundle-entry-exports phase0-entry)
                (webify-module-extractor-spike-phase0-exports report))
  (check-equal? (webify-module-extractor-spike-phase0-exports report) '(x))
  (check-not-false
   (member '(.get-syntax-literal!)
           (webify-module-extractor-spike-phase0-imports report)))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-match (webify-module-extractor-spike-phase0-linklet-datum report)
                  `(linklet ,_ ,exports . ,_))
     (check-match (webify-module-bundle-entry-datum decl-entry)
                  `(linklet ,_ ,_ . ,_))
     (check-match (webify-module-bundle-entry-datum data-entry)
                  `(linklet ,_ ,_ . ,_))
     (check-equal? (caddr (webify-module-extractor-spike-phase0-linklet-datum report))
                   '(x))
     (check-not-false
      (member "machine-independent compilation exposes a decompilable phase-0 linklet datum"
              (webify-module-extractor-spike-notes report)))]
    [else
     (check-false (webify-module-extractor-spike-phase0-linklet-datum report))
     (check-false (webify-module-bundle-entry-datum phase0-entry))
     (check-false (webify-module-bundle-entry-datum decl-entry))
     (check-false (webify-module-bundle-entry-datum data-entry))
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
     (check-not-false
      (andmap (lambda (binding)
                (match binding
                  [(list (? symbol?) (? symbol?)) #t]
                  [_                              #f]))
              (normalized-linklet-imports
               (webify-module-linklet-input-linklet input))))
     (check-equal? (caddr (webify-module-linklet-input-linklet input))
                   '(x))

     (define import-triples
       '((.get-syntax-literal! module-protocol .get-syntax-literal!)
         (.set-transformer! module-protocol .set-transformer!)))
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

(test-case "source module import resolver classifies module protocol imports"
  (define module-datum
    '(module a racket/base
       (provide x)
       (define x 10)))
  (define report (webify-compile-module-extractor-spike module-datum))
  (cond
    [(webify-module-extractor-spike-manifest-ready? report)
     (check-exn
      #rx"module protocol dependency"
      (lambda ()
        (webify-source-module->resolved-linklet-input module-datum)))
     (define input
       (webify-source-module->resolved-linklet-input
        module-datum
        #:module-protocol-dependency 'module-protocol))
     (check-true (webify-module-linklet-input? input))
     (check-equal? (webify-module-linklet-input-imports input)
                   '((.get-syntax-literal! module-protocol .get-syntax-literal!)
                     (.set-transformer! module-protocol .set-transformer!)))]
    [else
     (check-exn
      #rx"source module did not produce a decompilable phase-0 linklet datum"
      (lambda ()
        (webify-source-module->resolved-linklet-input module-datum)))]))

(module+ main
  (void))
