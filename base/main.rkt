#lang racket/base

(require racket/base
         (only-in "../core.rkt" js-log)
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax "../browser-options.rkt"))

;; `webracket/base` is the small foundation, mirroring Racket's distinction
;; between `racket/base` and the broader `racket` language.
(provide (all-from-out racket/base)
         js-log
         (for-syntax (all-from-out racket/base))
         (for-syntax (all-from-out racket/splicing))
         (for-syntax (all-from-out "../browser-options.rkt")))
