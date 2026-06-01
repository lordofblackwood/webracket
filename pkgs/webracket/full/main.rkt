#lang racket/base

(require (except-in racket/base
                    read-bytes-line
                    sort
                    andmap
                    append
                    assf
                    assoc
                    assq
                    assv
                    build-list
                    filter
                    findf
                    foldl
                    foldr
                    for-each
                    length
                    list-ref
                    list-tail
                    map
                    member
                    memf
                    memq
                    memv
                    ormap
                    remove
                    remove*
                    remq
                    remv
                    remw
                    reverse)
         racket/bool
         racket/bytes
         racket/dict
         racket/function
         racket/include
         "../list.rkt"
         racket/local
         racket/match
         racket/math
         racket/path
         racket/port
         racket/shared
         (except-in racket/string string-append* string-join)
         (only-in "../string.rkt" string-append* string-join)
         (except-in racket/vector vector-member vector-sort vector-sort!)
         (only-in "../primitives.rkt" sort vector-sort vector-sort!)
         "../contract.rkt"
         (only-in "../private/format.rkt"
                  [format wr-format]
                  ~a
                  ~s
                  ~v
                  ~e
                  ~r
                  ~.a
                  ~.s
                  ~.v)
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
         (only-in "../sequence.rkt"
                  empty-sequence
                  sequence->list
                  sequence-length
                  sequence-ref
                  sequence-tail
                  sequence-append
                  sequence-map
                  sequence-andmap
                  sequence-ormap
                  sequence-for-each
                  sequence-fold
                  sequence-count
                  sequence-filter
                  sequence-add-between
                  in-slice
                  in-syntax
                  initiate-sequence)
         "../set.rkt"
         "../stream.rkt"
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax webracket-lib/compiler/private/browser-options))

;; `webracket/full` is the deliberately broader, batteries-included Goal 1
;; surface. Keep `webracket/base` small so its name tracks Racket's convention.
;; Use a source-level wrapper for `vector-member` so the module bridge exports
;; a callable value instead of an installed-provider alias cell in #lang full.
(define (vector-member v vec [same? equal?])
  (let loop ([i 0])
    (cond
      [(= i (vector-length vec)) #f]
      [(same? v (vector-ref vec i)) i]
      [else (loop (add1 i))])))

(provide (except-out (all-from-out racket/base)
                     format)
         read-bytes-line
         (rename-out [wr-format format])
         sort
         (all-from-out racket/bool)
         (all-from-out racket/bytes)
         (all-from-out racket/dict)
         (all-from-out racket/function)
         (all-from-out racket/include)
         (all-from-out "../list.rkt")
         (all-from-out racket/local)
         (all-from-out racket/match)
         (all-from-out racket/math)
         (all-from-out racket/path)
         (all-from-out racket/port)
         (all-from-out racket/shared)
         (all-from-out racket/string)
         string-append*
         string-join
         (all-from-out racket/vector)
         vector-member
         vector-sort
         vector-sort!
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
         (all-from-out "../hash.rkt")
         (all-from-out "../js/main.rkt")
         (all-from-out "../pretty.rkt")
         (all-from-out "../promise.rkt")
         empty-sequence
         sequence->list
         sequence-length
         sequence-ref
         sequence-tail
         sequence-append
         sequence-map
         sequence-andmap
         sequence-ormap
         sequence-for-each
         sequence-fold
         sequence-count
         sequence-filter
         sequence-add-between
         in-slice
         in-syntax
         initiate-sequence
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
