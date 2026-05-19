#lang racket/base

(provide webracket-full-foundation
         webracket-full-addon-libraries
         webracket-full-deferred-libraries
         webracket-full-surface-statuses)

(define webracket-full-foundation
  'racket/base)

(define webracket-full-addon-libraries
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
    racket/sequence
    racket/shared
    racket/stream
    racket/string
    racket/vector
    webracket/promise
    webracket/set))

(define webracket-full-deferred-libraries
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

;; webracket-full-surface-statuses : (listof (list/c symbol? symbol? symbol? symbol? symbol?))
;;   Track exported/extracted/composed/runtime status for the broader language surface.
(define webracket-full-surface-statuses
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
    (racket/sequence exported extracts partial runs)
    (racket/shared   exported expands  partial host-only)
    (racket/stream   exported extracts partial runs)
    (racket/string   exported extracts partial runs)
    (racket/vector   exported extracts partial runs)
    (webracket/promise exported extracts staged runs)
    (webracket/set     exported extracts staged runs)))
