#lang racket/base

;; in-out shim : -> exports
;;   Expose the erased contract surface under the helper name used by staged providers.

(require "../contract.rkt")

(provide (all-from-out "../contract.rkt"))
