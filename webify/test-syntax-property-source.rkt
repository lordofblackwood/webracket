#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         rackunit)

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

(test-case "syntax/property staged source exposes taint as the current boundary"
  (check-true (string-contains? property-source "\"taint.rkt\""))
  (check-true (string-contains? property-source "taint-content")))

(module+ main
  (void))
