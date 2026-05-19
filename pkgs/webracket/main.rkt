#lang racket/base

(require "core.rkt"
         (for-syntax racket/splicing)
         (for-syntax (file "../webracket-lib/compiler/private/browser-options.rkt")))
(provide (all-from-out "core.rkt")
         (for-syntax (all-from-out racket/splicing))
         (for-syntax (all-from-out (file "../webracket-lib/compiler/private/browser-options.rkt"))))

;; Uncommenting the line below disables the custom reader
;; in `lang/reader.rkt`.
#;(module reader syntax/module-reader webracket)
         
