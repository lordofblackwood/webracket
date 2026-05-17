#lang racket/base

(provide module-declared?)

;; The Goal 1 read-syntax slice does not support on-demand module loading for
;; reader extensions. Ordinary datum-to-syntax reading can safely report that
;; no extension module is declared.

(define (module-declared? mod [load? #f])
  #f)
