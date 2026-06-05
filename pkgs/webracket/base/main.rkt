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
                  [sort primitive-sort]
                  [sort/expanded-keywords primitive-sort/expanded-keywords])
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

;; sort-keyword-options : (listof keyword?) list? -> values
;;   Decode the keyword options supported by WebRacket's primitive sort bridge.
(define (sort-keyword-options kws kw-args)
  (let loop ([kws kws] [kw-args kw-args] [key #f] [cache-keys? #f])
    (cond
      [(null? kws) (values key cache-keys?)]
      [(eq? (car kws) '#:key)
       (loop (cdr kws) (cdr kw-args) (car kw-args) cache-keys?)]
      [(eq? (car kws) '#:cache-keys?)
       (loop (cdr kws) (cdr kw-args) key (car kw-args))]
      [else
       (raise-arguments-error 'sort
                              "unsupported keyword"
                              "keyword" (car kws))])))

;; sort : list? procedure? -> list?
;;   Keyword-aware public wrapper over WebRacket's primitive list sort.
(define sort
  (make-keyword-procedure
   (lambda (kws kw-args xs less-than?)
     (define-values (key cache-keys?) (sort-keyword-options kws kw-args))
     (primitive-sort/expanded-keywords xs less-than? #f key #f cache-keys?))
   primitive-sort))

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
