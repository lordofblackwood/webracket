#lang racket/base

(provide webracket-full-foundation
         webracket-full-addon-libraries
         webracket-full-deferred-libraries
         webracket-full-surface-statuses
         webracket-full-surface-audit)

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
    racket/pretty
    racket/sequence
    racket/shared
    racket/stream
    racket/string
    racket/vector
    racket/contract
    webracket/contract
    webracket/file
    webracket/hash
    webracket/js
    webracket/pretty
    webracket/promise
    webracket/sequence
    webracket/set
    webracket/stream))

(define webracket-full-deferred-libraries
  '(racket/cmdline
    racket/class
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
    (racket/pretty   exported extracts partial runs)
    (racket/sequence exported extracts partial runs)
    (racket/shared   exported expands  partial host-only)
    (racket/stream   substituted staged staged runs)
    (racket/string   exported extracts partial runs)
    (racket/vector   exported extracts partial runs)
    (racket/contract exported substituted staged runs)
    (webracket/contract exported extracts staged runs)
    (webracket/file     exported extracts staged runs)
    (webracket/hash     exported extracts staged runs)
    (webracket/js       exported extracts staged runs)
    (webracket/pretty   exported extracts staged runs)
    (webracket/promise exported extracts staged runs)
    (webracket/sequence exported extracts staged runs)
    (webracket/set     exported extracts staged runs)
    (webracket/stream  exported extracts staged runs)))

;; webracket-full-surface-audit : (listof (list/c symbol? symbol? symbol? symbol?))
;;   Pin the curated full surface to an implementation owner and dashboard row.
(define webracket-full-surface-audit
  '((racket/bool     racket/bool        real-provider-proven installed-racket-bool-coverage)
    (racket/bytes    racket/bytes       real-provider-proven full-bytes-coverage)
    (racket/dict     racket/dict        real-provider-proven installed-racket-dict-coverage)
    (racket/format   io/format          staged-original      installed-racket-format-coverage)
    (racket/function racket/function   real-provider-proven installed-racket-function-coverage)
    (racket/include  racket/include     real-provider-proven full-include)
    (racket/list     racket/list        real-provider-proven installed-racket-list-coverage)
    (racket/local    racket/local       real-provider-proven full-local)
    (racket/match    racket/match       real-provider-proven full-match-coverage)
    (racket/math     racket/math        real-provider-proven full-math-coverage)
    (racket/path     racket/path        real-provider-proven full-path-coverage)
    (racket/port     racket/port        real-provider-proven installed-racket-port-coverage)
    (racket/pretty   racket/pretty      real-provider-proven installed-racket-pretty-coverage)
    (racket/sequence racket/sequence    real-provider-proven real-racket-sequence-coverage)
    (racket/shared   racket/shared      real-provider-proven full-shared-coverage)
    (racket/stream   webracket/stream   webracket-owned      full-stream-coverage)
    (racket/string   racket/string      real-provider-proven installed-racket-string-coverage)
    (racket/vector   racket/vector      real-provider-proven installed-racket-vector-coverage)
    (racket/contract webracket/contract webracket-owned      full-contract-erased)
    (webracket/contract webracket/contract webracket-owned   full-contract-erased)
    (webracket/file     webracket/file     webracket-owned   full-file-coverage)
    (webracket/hash     webracket/hash     webracket-owned   installed-racket-hash-coverage)
    (webracket/js       webracket/js       webracket-owned   ffi-js-console-coverage)
    (webracket/pretty   webracket/pretty   webracket-owned   installed-racket-pretty-coverage)
    (webracket/promise  webracket/promise  webracket-owned   full-promise-coverage)
    (webracket/sequence webracket/sequence webracket-owned   full-sequence-coverage)
    (webracket/set      webracket/set      webracket-owned   full-set-coverage)
    (webracket/stream   webracket/stream   webracket-owned   full-stream-coverage)))
