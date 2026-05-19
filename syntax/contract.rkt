#lang racket/base

(provide wrap-expr/c)

;; wrap-expr/c : syntax? syntax? keyword-args ... -> syntax?
;;   Erase syntax-time contract checks while preserving expression evaluation.
(define (wrap-expr/c _ctc-expr expr
                     #:arg? [arg? #t]
                     #:positive [pos-source 'from-macro]
                     #:negative [neg-source 'use-site]
                     #:name [expr-name #f]
                     #:macro [macro-name #f]
                     #:context [ctx #f]
                     #:phase [phase 0])
  (void arg? pos-source neg-source expr-name macro-name ctx phase)
  expr)
