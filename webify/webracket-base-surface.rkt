#lang racket/base

(provide webracket-base-foundation
         webracket-base-addon-libraries
         webracket-base-deferred-libraries
         webracket-base-surface-statuses)

(define webracket-base-foundation
  'racket/base)

(define webracket-base-addon-libraries
  '(racket/bool
    racket/bytes
    racket/dict
    racket/format
    racket/function
    racket/include
    racket/list
    racket/local
    racket/match
    racket/math
    racket/path
    racket/port
    racket/promise
    racket/sequence
    racket/set
    racket/shared
    racket/stream
    racket/string
    racket/vector))

(define webracket-base-deferred-libraries
  '(racket/class
    racket/cmdline
    racket/contract
    racket/file
    racket/future
    racket/place
    racket/pretty
    racket/system
    racket/tcp
    racket/udp
    racket/unit))

;; webracket-base-surface-statuses : (listof (list/c symbol? symbol? symbol? symbol? symbol?))
;;   Track exported/extracted/composed/runtime status for the initial language surface.
(define webracket-base-surface-statuses
  '((racket/base     exported extracts partial partial)
    (racket/bool     exported extracts partial runs)
    (racket/bytes    exported extracts partial partial)
    (racket/dict     exported extracts partial partial)
    (racket/format   exported extracts partial runs)
    (racket/function exported extracts partial runs)
    (racket/include  exported expands  partial host-only)
    (racket/list     exported extracts partial runs)
    (racket/local    exported expands  partial host-only)
    (racket/match    exported extracts partial runs)
    (racket/math     exported extracts partial partial)
    (racket/path     exported extracts partial partial)
    (racket/port     exported extracts partial partial)
    (racket/promise  exported extracts partial runs)
    (racket/sequence exported extracts partial runs)
    (racket/set      exported extracts partial runs)
    (racket/shared   exported expands  partial host-only)
    (racket/stream   exported extracts partial runs)
    (racket/string   exported extracts partial runs)
    (racket/vector   exported extracts partial runs)))
