#lang racket/base

;;; Bridge helpers for the staged original-Racket `io/format` provider.
;;;
;;; This module keeps provider extraction and private-cell binding logic out of
;;; tests and out of `driver.rkt`. The current safe integration shape is
;;; cell-only: public `format` and `fprintf` aliases still collide with
;;; compiler/runtime primitives, but private cells can already point at the
;;; staged provider exports.

(provide webify-io-format-root-name
         webify-io-format-printf-name
         webify-io-format-adapter-name
         webify-io-format-map-shim-name
         webify-io-format-module-protocol-name
         webify-io-format-export-symbols
         webify-io-format-module-protocol-input
         webify-io-format-reports
         webify-io-format-inputs
         webify-io-format-registry
         webify-io-format-private-cell-symbol
         webify-io-format-private-alias-forms
         webify-io-format-public-alias-forms)

(require racket/runtime-path
         "module-extractor.rkt"
         "module-input.rkt"
         "module-registry.rkt")

(define-runtime-path webracket-root "../../../..")

(define webify-io-format-root-name
  'racket-src/io/format/main-web)

(define webify-io-format-printf-name
  'racket-src/io/format/printf-web)

(define webify-io-format-adapter-name
  'racket-src/io/format/printf-adapter)

(define webify-io-format-map-shim-name
  'map-shim)

(define webify-io-format-module-protocol-name
  'module-protocol)

(define webify-io-format-export-symbols
  '(format fprintf printf eprintf))

(define map-shim-module
  '(module map-shim racket/base
     (provide map2)
     (define (map2 f xs)
       (if (null? xs)
           null
           (cons (f (car xs)) (map2 f (cdr xs)))))))

;; webify-io-format-module-protocol-input : -> webify-module-linklet-input?
;;   Minimal module protocol provider for compiled source-module linklets.
(define (webify-io-format-module-protocol-input)
  (webify-module-linklet-input
   webify-io-format-module-protocol-name
   '(linklet () (.get-syntax-literal! .set-transformer!)
      (define-values (.get-syntax-literal!) (lambda xs #f))
      (define-values (.set-transformer!) (lambda xs (void))))
   '()))

;; webify-io-format-reports : -> values
;;   Extract reports for the adapted original-Racket io/format graph.
(define (webify-io-format-reports)
  (parameterize ([current-directory webracket-root])
    (values
     (webify-module-path->report (string->path "racket-src/io/format/printf-adapter.rkt"))
     (webify-module-path->report (string->path "racket-src/io/format/printf-web.rkt"))
     (webify-module-path->report (string->path "racket-src/io/format/main-web.rkt"))
     (webify-compile-module-report map-shim-module))))

;; webify-io-format-inputs : -> (listof webify-module-linklet-input?)
;;   Resolve staged io/format reports into registry-ready inputs.
(define (webify-io-format-inputs)
  (define-values (adapter-report printf-report main-report map-report)
    (webify-io-format-reports))
  (list
   (webify-io-format-module-protocol-input)
   (webify-module-report->resolved-linklet-input/providers
    map-report
    '()
    #:module-protocol-dependency webify-io-format-module-protocol-name)
   (webify-module-report->resolved-linklet-input/providers
    adapter-report
    '()
    #:module-protocol-dependency webify-io-format-module-protocol-name)
   (webify-module-report->resolved-linklet-input/providers
    printf-report
    (list adapter-report map-report)
    #:dependencies `((map2 ,webify-io-format-map-shim-name))
    #:module-protocol-dependency webify-io-format-module-protocol-name)
   (webify-module-report->resolved-linklet-input/providers
    main-report
    (list adapter-report printf-report)
    #:module-protocol-dependency webify-io-format-module-protocol-name)))

;; webify-io-format-registry : -> webify-module-registry?
;;   Build a registry that can compose the staged provider graph.
(define (webify-io-format-registry)
  (webify-module-linklet-inputs->registry (webify-io-format-inputs)))

;; webify-io-format-private-cell-symbol : symbol? -> symbol?
;;   Private top-level cell used by the guarded stdlib bridge.
(define (webify-io-format-private-cell-symbol export)
  (unless (memq export webify-io-format-export-symbols)
    (raise-argument-error 'webify-io-format-private-cell-symbol
                          "io/format export symbol"
                          export))
  (string->symbol (format "webify-io-format-export-cell$~a" export)))

;; webify-io-format-private-alias-forms : webify-module-composition? -> (listof datum?)
;;   Bind private cells to staged provider export cells without public aliases.
(define (webify-io-format-private-alias-forms composition)
  (for/list ([export (in-list webify-io-format-export-symbols)])
    (define provider-cell
      (webify-module-composition-export-cell-id
       composition
       webify-io-format-root-name
       export))
    (define private-cell
      (webify-io-format-private-cell-symbol export))
    `(define ,private-cell ,provider-cell)))

;; webify-io-format-public-alias-forms : webify-module-composition? -> (listof datum?)
;;   Bind private cells, then publish public aliases through module-variable-ref.
(define (webify-io-format-public-alias-forms composition)
  (append
   (webify-io-format-private-alias-forms composition)
   (for/list ([export (in-list webify-io-format-export-symbols)])
     `(define ,export
        (module-variable-ref ,(webify-io-format-private-cell-symbol export))))))
