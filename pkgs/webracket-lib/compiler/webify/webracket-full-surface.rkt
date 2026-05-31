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
    webracket/class
    racket/contract
    webracket/contract
    webracket/pretty
    webracket/promise
    webracket/sequence
    webracket/set
    webracket/stream))

(define webracket-full-deferred-libraries
  '(racket/cmdline
    racket/file
    racket/future
    racket/place
    racket/system
    racket/tcp
    racket/udp
    racket/unit))

;; webracket-full-surface-statuses : (listof (list/c symbol? symbol? symbol? symbol? symbol?))
;;   Track exported/extracted/composed/runtime status for the broader language surface.
(define webracket-full-surface-statuses
  '((racket/base     exported extracts partial partial)
    (racket/bool     exported extracts partial runs)
    (racket/bytes    exported extracts partial runs)
    (racket/dict     exported extracts partial runs)
    (racket/format   exported extracts partial runs)
    (racket/function exported extracts composes runs)
    (racket/include  exported expands  partial host-only)
    (racket/list     exported extracts partial runs)
    (racket/local    exported expands  partial host-only)
    (racket/match    exported extracts partial runs)
    (racket/math     exported extracts partial runs)
    (racket/path     exported extracts partial runs)
    (racket/port     exported extracts partial runs)
    (racket/sequence exported substituted staged runs)
    (racket/shared   exported expands  partial host-only)
    (racket/stream   substituted staged staged runs)
    (racket/string   exported extracts partial runs)
    (racket/vector   exported extracts partial runs)
    (racket/class    exported substituted staged partial)
    (webracket/class exported extracts staged partial)
    (racket/contract exported substituted staged runs)
    (webracket/contract exported extracts staged runs)
    (webracket/pretty   exported extracts staged runs)
    (webracket/promise exported extracts staged runs)
    (webracket/sequence exported extracts staged runs)
    (webracket/set     exported extracts staged runs)
    (webracket/stream  exported extracts staged runs)))
