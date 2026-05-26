#lang racket/base

(require (except-in racket/base read-bytes-line)
         racket/bool
         racket/bytes
         racket/dict
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
         (except-in "../file.rkt"
                    call-with-input-file
                    call-with-input-file*
                    call-with-output-file
                    call-with-output-file*
                    with-input-from-file
                    with-output-to-file)
         "../hash.rkt"
         "../js/main.rkt"
         "../pretty.rkt"
         "../promise.rkt"
         "../set.rkt"
         "../stream.rkt"
         (except-in "../function.rkt" compose compose1)
         (rename-in "../function.rkt"
                    [compose wr-compose]
                    [compose1 wr-compose1])
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax webracket-lib/compiler/private/browser-options))

;; `webracket/full` is the deliberately broader, batteries-included Goal 1
;; surface. Keep `webracket/base` small so its name tracks Racket's convention.
(provide (except-out (all-from-out racket/base)
                     format
                     fprintf
                     printf
                     eprintf
                     compose
                     compose1)
         read-bytes-line
         (rename-out [wr-format format]
                     [wr-fprintf fprintf]
                     [wr-printf printf]
                     [wr-eprintf eprintf]
                     [wr-compose compose]
                     [wr-compose1 compose1])
         (all-from-out racket/bool)
         (all-from-out racket/bytes)
         (all-from-out racket/dict)
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
         (all-from-out "../file.rkt")
         (all-from-out "../function.rkt")
         (all-from-out "../hash.rkt")
         (all-from-out "../js/main.rkt")
         (all-from-out "../pretty.rkt")
         (all-from-out "../promise.rkt")
         (all-from-out "../set.rkt")
         (all-from-out "../stream.rkt")
         (for-syntax (all-from-out racket/base))
         (for-syntax (all-from-out racket/splicing))
         (for-syntax (all-from-out webracket-lib/compiler/private/browser-options)))

;; read-bytes-line : [input-port?] [symbol?] -> (or/c bytes? eof-object?)
;;   Small WebRacket-compatible implementation. Optional mode defaults to 'linefeed.
(define read-bytes-line
  (case-lambda
    [() (read-bytes-line (current-input-port) 'linefeed)]
    [(in) (read-bytes-line in 'linefeed)]
    [(in mode)
     (define line (read-line in mode))
     (if (eof-object? line)
         eof
         (string->bytes/utf-8 line))]))
