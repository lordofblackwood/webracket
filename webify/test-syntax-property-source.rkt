#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../racket-src/expander/syntax/property.rkt"
         "../racket-src/expander/syntax/syntax.rkt"
         "../racket-src/expander/syntax/taint.rkt")

(define-runtime-path property-rkt
  "../racket-src/expander/syntax/property.rkt")

(define property-source (file->string property-rkt))

(test-case "syntax/property staged source has expected public surface"
  (for ([name (in-list '("syntax-property"
                         "syntax-property-preserved?"
                         "syntax-property-symbol-keys"
                         "syntax-property-remove"
                         "syntax-has-property?"))])
    (check-true (string-contains? property-source name) name)))

(test-case "syntax/property staged source exposes taint dependency"
  (check-true (string-contains? property-source "\"taint.rkt\""))
  (check-true (string-contains? property-source "taint-content")))

(test-case "syntax/property supports basic property operations"
  (define s (datum->syntax #f 'x))
  (define colored (syntax-property s 'color 'blue))
  (check-equal? (syntax-property colored 'color) 'blue)
  (check-equal? (syntax-property-symbol-keys colored) '(color))
  (check-not-false (syntax-has-property? colored 'color))
  (define removed (syntax-property-remove colored 'color))
  (check-false (syntax-property removed 'color))
  (check-false (syntax-has-property? removed 'color)))

(test-case "syntax/property supports preserved properties and taint predicates"
  (define s (datum->syntax #f 'x))
  (define preserved (syntax-property s 'kept 1 #t))
  (check-equal? (syntax-property preserved 'kept) 1)
  (check-true (syntax-property-preserved? preserved 'kept))
  (check-true (syntax-clean? s))
  (define tainted (syntax-taint s))
  (check-true (syntax-tainted? tainted))
  (check-false (syntax-clean? tainted)))

(module+ main
  (void))
