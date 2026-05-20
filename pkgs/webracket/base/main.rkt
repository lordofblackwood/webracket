#lang racket/base

(require racket/base
         "../js/main.rkt"
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax webracket-lib/compiler/private/browser-options))

;; `webracket/base` is the small foundation, mirroring Racket's distinction
;; between `racket/base` and the broader `racket` language.
(provide (all-from-out racket/base)
         (all-from-out "../js/main.rkt")
         (for-syntax (all-from-out racket/base))
         (for-syntax (all-from-out racket/splicing))
         (for-syntax (all-from-out webracket-lib/compiler/private/browser-options)))
