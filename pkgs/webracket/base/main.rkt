#lang racket/base

(require (except-in racket/base
                    make-keyword-procedure
                    keyword-apply
                    procedure-keywords
                    procedure-reduce-keyword-arity
                    procedure-reduce-keyword-arity-mask
                    print-as-expression
                    read-bytes-line
                    sort)
         "../js/main.rkt"
         "../private/kw.rkt"
         (only-in "../private/for.rkt"
                  prop:gen-sequence)
         (only-in "../primitives.rkt"
                  print-as-expression
                  sort)
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax webracket-lib/compiler/private/browser-options))

;; `webracket/base` is the small foundation, mirroring Racket's distinction
;; between `racket/base` and the broader `racket` language.
(provide (all-from-out racket/base)
         read-bytes-line
         sort
         prop:gen-sequence
         (all-from-out "../js/main.rkt")
         (all-from-out "../private/kw.rkt")
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
