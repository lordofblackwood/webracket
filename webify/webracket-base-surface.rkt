#lang racket/base

(provide webracket-base-foundation
         webracket-base-addon-libraries
         webracket-base-deferred-libraries
         webracket-base-surface-statuses)

(define webracket-base-foundation
  'racket/base)

(define webracket-base-addon-libraries
  '())

(define webracket-base-deferred-libraries
  '(racket/bool
    racket/bytes
    racket/class
    racket/cmdline
    racket/contract
    racket/dict
    racket/file
    racket/format
    racket/function
    racket/future
    racket/include
    racket/list
    racket/local
    racket/match
    racket/math
    racket/path
    racket/place
    racket/port
    racket/pretty
    racket/promise
    racket/sequence
    racket/set
    racket/shared
    racket/stream
    racket/string
    racket/system
    racket/tcp
    racket/udp
    racket/unit
    racket/vector))

;; webracket-base-surface-statuses : (listof (list/c symbol? symbol? symbol? symbol? symbol?))
;;   Track exported/extracted/composed/runtime status for the small base surface.
(define webracket-base-surface-statuses
  '((racket/base exported extracts partial partial)))
