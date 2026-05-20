#lang racket/base

(require "../pkgs/webracket-lib/compiler/webify/io-format-provider.rkt")

(cond
  [(io-format-bootstrap-retirement-ready?)
   (displayln "io/format bootstrap primitive retirement gate passed")]
  [else
   (printf "io/format bootstrap primitive retirement blocked: ~s\n"
           io-format-bootstrap-retirement-blockers)])
