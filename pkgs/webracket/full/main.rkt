#lang racket/base

(require racket/base
         racket/bool
         racket/bytes
         racket/dict
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
         racket/string
         racket/vector
         "../contract.rkt"
         (except-in "../format.rkt" format fprintf printf eprintf)
         (rename-in "../format.rkt"
                    [format wr-format]
                    [fprintf wr-fprintf]
                    [printf wr-printf]
                    [eprintf wr-eprintf])
         "../hash.rkt"
         "../js/main.rkt"
         "../pretty.rkt"
         "../promise.rkt"
         "../set.rkt"
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax webracket-lib/compiler/private/browser-options))

;; `webracket/full` is the deliberately broader, batteries-included Goal 1
;; surface. Keep `webracket/base` small so its name tracks Racket's convention.
(provide (except-out (all-from-out racket/base)
                     format
                     fprintf
                     printf
                     eprintf)
         (rename-out [wr-format format]
                     [wr-fprintf fprintf]
                     [wr-printf printf]
                     [wr-eprintf eprintf])
         (all-from-out racket/bool)
         (all-from-out racket/bytes)
         (all-from-out racket/dict)
         (all-from-out racket/function)
         (all-from-out racket/include)
         (all-from-out racket/list)
         (all-from-out racket/local)
         (all-from-out racket/match)
         (all-from-out racket/math)
         (all-from-out racket/path)
         (all-from-out racket/port)
         (all-from-out racket/sequence)
         (all-from-out racket/shared)
         (all-from-out racket/string)
         (all-from-out racket/vector)
         (all-from-out "../contract.rkt")
         ~a
         ~s
         ~v
         ~e
         ~r
         ~.a
         ~.s
         ~.v
         (all-from-out "../hash.rkt")
         (all-from-out "../js/main.rkt")
         (all-from-out "../pretty.rkt")
         (all-from-out "../promise.rkt")
         (all-from-out "../set.rkt")
         (for-syntax (all-from-out racket/base))
         (for-syntax (all-from-out racket/splicing))
         (for-syntax (all-from-out webracket-lib/compiler/private/browser-options)))
