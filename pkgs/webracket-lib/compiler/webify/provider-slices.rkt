#lang racket/base

;;; Provider-slice inventory for original-Racket library layers.

(provide (struct-out provider-slice)
         known-provider-slices
         provider-slice-by-name
         provider-slice-report-lines)

(require racket/format
         racket/string
         "io-format-bridge.rkt"
         "io-print-bridge.rkt"
         "read-provider.rkt"
         "regexp-provider.rkt")

(struct provider-slice
  (name default-enabled? status exports description)
  #:transparent)

(define known-provider-slices
  (list
   (provider-slice
    'io/format
    #t
    'active
    webify-io-format-export-symbols
    "staged original-Racket format provider; composed by default, including with --no-stdlib")
   (provider-slice
    'regexp
    #t
    'active
    webify-regexp-export-symbols
    "whole staged regexp/ tree demodularized to one cached linklet; composed by default")
   (provider-slice
    'expander/read
    #f
    'staged
    webify-read-export-symbols
    "staged original-Racket expander/read provider; enable with --expander-read-provider for Webify-owned public aliases")
   (provider-slice
    'io/print
    #f
    'staged
    webify-io-print-export-symbols
    "staged original-Racket print provider seed; public aliases are available on demand")))

;; provider-slice-by-name : symbol? -> (or/c provider-slice? #f)
;;   Look up a known provider slice.
(define (provider-slice-by-name name)
  (for/first ([slice (in-list known-provider-slices)]
              #:when (eq? name (provider-slice-name slice)))
    slice))

;; provider-slice-report-lines : -> (listof string?)
;;   Return a human-readable summary for command-line and tests.
(define (provider-slice-report-lines)
  (for/list ([slice (in-list known-provider-slices)])
    (format "~a\tdefault: ~a\tstatus: ~a\texports: ~a\t~a"
            (provider-slice-name slice)
            (if (provider-slice-default-enabled? slice) "enabled" "disabled")
            (provider-slice-status slice)
            (string-join (map ~a (provider-slice-exports slice)) ",")
            (provider-slice-description slice))))
