#lang racket/base

(provide read-linklet-bundle-or-directory)

;; Compiled-code reading is outside the first Goal 1 read-syntax slice. Plain
;; source datum reading does not call this hook, but the upstream reader expects
;; one to be supplied for `#~` input.

(define (read-linklet-bundle-or-directory in)
  (error '|loading code| "compiled-code reading is unsupported"))
