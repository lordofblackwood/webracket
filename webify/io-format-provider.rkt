#lang racket/base

;;; Provider metadata for the staged original Racket `io/format` slice.
;;;
;;; This module is intentionally about ownership and readiness, not about
;;; reimplementing formatting. The staged provider lives in `racket-src/io/`.

(provide io-format-provider-symbols
         io-format-current-primitive-symbols
         io-format-provider-module
         io-format-provider-ready?
         io-format-provider-status)

(require racket/list
         racket/runtime-path)

(define io-format-provider-symbols
  '(format fprintf printf eprintf))

(define io-format-current-primitive-symbols
  '(format fprintf))

(define-runtime-path io-format-provider-module
  "../racket-src/io/format/main-web.rkt")

;; io-format-provider-ready? : -> boolean?
;;   Check whether the staged provider can be loaded by the host-side adapter.
(define (io-format-provider-ready?)
  (with-handlers ([exn:fail? (lambda (_e) #f)])
    (andmap procedure?
            (for/list ([name (in-list io-format-provider-symbols)])
              (dynamic-require io-format-provider-module name)))))

;; io-format-provider-status : -> (listof (list/c symbol? symbol?))
;;   Report current ownership for each future `io/format` export.
(define (io-format-provider-status)
  (for/list ([name (in-list io-format-provider-symbols)])
    (list name
          (if (memq name io-format-current-primitive-symbols)
              'primitive-now/staged-original-next
              'staged-original-ready))))
