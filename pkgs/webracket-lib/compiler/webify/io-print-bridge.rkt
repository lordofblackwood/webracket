#lang racket/base

;;; Bridge helpers for the staged original-Racket `io/print` provider seed.

(provide webify-io-print-root-name
         webify-io-print-adapter-name
         webify-io-print-export-symbols
         webify-io-print-module-protocol-name
         webify-io-print-module-protocol-input
         webify-io-print-reports
         webify-io-print-inputs
         webify-io-print-registry
         webify-io-print-private-cell-symbol
         webify-io-print-private-alias-forms)

(require racket/runtime-path
         "module-extractor.rkt"
         "module-input.rkt"
         "module-registry.rkt")

(define-runtime-path webracket-root "../../../..")

(define webify-io-print-root-name
  'racket-src/io/print/main-web)

(define webify-io-print-adapter-name
  'racket-src/io/format/printf-adapter)

(define webify-io-print-module-protocol-name
  'module-protocol)

(define webify-io-print-export-symbols
  '(display displayln newline print println write writeln))

;; webify-io-print-module-protocol-input : -> webify-module-linklet-input?
;;   Minimal module protocol provider for compiled source-module linklets.
(define (webify-io-print-module-protocol-input)
  (webify-module-linklet-input
   webify-io-print-module-protocol-name
   '(linklet () (.get-syntax-literal! .set-transformer!)
      (define-values (.get-syntax-literal!) (lambda xs #f))
      (define-values (.set-transformer!) (lambda xs (void))))
   '()))

;; webify-io-print-reports : -> webify-module-report?
;;   Extract the WebRacket-facing high-level print provider seed.
(define (webify-io-print-reports)
  (parameterize ([current-directory webracket-root])
    (values
     (webify-module-path->report (string->path "racket-src/io/format/printf-adapter.rkt"))
     (webify-module-path->report (string->path "racket-src/io/print/main-web.rkt")))))

;; webify-io-print-inputs : -> (listof webify-module-linklet-input?)
;;   Resolve the staged print provider seed into registry-ready inputs.
(define (webify-io-print-inputs)
  (define-values (adapter-report main-report)
    (webify-io-print-reports))
  (list
   (webify-io-print-module-protocol-input)
   (webify-module-report->resolved-linklet-input/providers
    adapter-report
    '()
    #:module-protocol-dependency webify-io-print-module-protocol-name)
   (webify-module-report->resolved-linklet-input/providers
    main-report
    (list adapter-report)
    #:module-protocol-dependency webify-io-print-module-protocol-name)))

;; webify-io-print-registry : -> webify-module-registry?
;;   Build a registry that can compose the staged print provider seed.
(define (webify-io-print-registry)
  (webify-module-linklet-inputs->registry (webify-io-print-inputs)))

;; webify-io-print-private-cell-symbol : symbol? -> symbol?
;;   Private top-level cell used by the cell-only print provider smoke.
(define (webify-io-print-private-cell-symbol export)
  (unless (memq export webify-io-print-export-symbols)
    (raise-argument-error 'webify-io-print-private-cell-symbol
                          "io/print export symbol"
                          export))
  (string->symbol (format "webify-io-print-export-cell$~a" export)))

;; webify-io-print-private-alias-forms : composition -> (listof datum?)
;;   Bind private cells to staged provider export cells without public aliases.
(define (webify-io-print-private-alias-forms composition)
  (for/list ([export (in-list webify-io-print-export-symbols)])
    (define provider-cell
      (webify-module-composition-export-cell-id
       composition
       webify-io-print-root-name
       export))
    (define private-cell
      (webify-io-print-private-cell-symbol export))
    `(define ,private-cell ,provider-cell)))
