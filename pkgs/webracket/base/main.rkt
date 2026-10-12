#lang racket/base

(require (except-in racket/base
                    format
                    fprintf
                    printf
                    eprintf
                    write
                    writeln
                    print
                    println
                    make-keyword-procedure
                    keyword-apply
                    procedure-keywords
                    procedure-reduce-keyword-arity
                    procedure-reduce-keyword-arity-mask
                    print-as-expression
                    read-bytes-line
                    map
                    filter
                    sort)
         (only-in racket/base
                  [write racket-write]
                  [writeln racket-writeln]
                  [print racket-print]
                  [println racket-println])
         "../js/main.rkt"
         "../private/kw.rkt"
         (only-in "../private/for.rkt"
                  prop:gen-sequence)
         (only-in "../primitives.rkt"
                  print-as-expression
                  [sort/expanded-keywords primitive-sort/expanded-keywords])
         (only-in "../private/format.rkt"
                  [format wr-format]
                  [fprintf wr-fprintf]
                  [printf wr-printf]
                  [eprintf wr-eprintf])
         (for-syntax racket/base)
         (for-syntax racket/splicing)
         (for-syntax webracket-lib/compiler/private/browser-options))

;; `webracket/base` is the small foundation, mirroring Racket's distinction
;; between `racket/base` and the broader `racket` language.
;; write : any/c [output-port?] -> void?
;;   Host-compatible wrapper that gives Webify a fresh language binding.
(define (write v [o (current-output-port)])
  (racket-write v o))

;; writeln : any/c [output-port?] -> void?
;;   Host-compatible wrapper that gives Webify a fresh language binding.
(define (writeln v [o (current-output-port)])
  (racket-writeln v o))

;; print : any/c [output-port?] [any/c] -> void?
;;   Host-compatible wrapper that gives Webify a fresh language binding.
(define (print v [o (current-output-port)] [quote-depth 0])
  (racket-print v o quote-depth))

;; println : any/c [output-port?] [any/c] -> void?
;;   Host-compatible wrapper that gives Webify a fresh language binding.
(define (println v [o (current-output-port)] [quote-depth 0])
  (racket-println v o quote-depth))

;; map : procedure? list? ... -> list?
;;   Transform equally sized lists without growing the Wasm stack.
(define (map proc first . rest)
  (define inputs (cons first rest))
  (unless (procedure? proc)
    (raise-argument-error 'map "procedure?" proc))
  (let validate ([remaining inputs])
    (cond
      [(null? remaining) (void)]
      [(list? (car remaining)) (validate (cdr remaining))]
      [else (raise-argument-error 'map "list?" (car remaining))]))
  (define (state lists)
    (let loop ([remaining lists] [saw-empty? #f] [saw-pair? #f])
      (cond
        [(null? remaining)
         (cond
           [(and saw-empty? saw-pair?) 'mismatched]
           [saw-empty? 'finished]
           [else 'continue])]
        [(null? (car remaining))
         (loop (cdr remaining) #t saw-pair?)]
        [else (loop (cdr remaining) saw-empty? #t)])))
  (define (cars lists)
    (let loop ([remaining lists] [reversed null])
      (if (null? remaining)
          (reverse reversed)
          (loop (cdr remaining) (cons (caar remaining) reversed)))))
  (define (cdrs lists)
    (let loop ([remaining lists] [reversed null])
      (if (null? remaining)
          (reverse reversed)
          (loop (cdr remaining) (cons (cdar remaining) reversed)))))
  (let loop ([lists inputs] [reversed null])
    (cond
      [(eq? (state lists) 'finished) (reverse reversed)]
      [(eq? (state lists) 'mismatched)
       (raise-arguments-error 'map "all lists must have the same size"
                              "lists" inputs)]
      [else
       (loop (cdrs lists)
             (cons (apply proc (cars lists)) reversed))])))

;; filter : procedure? list? -> list?
;;   Preserve Racket's left-to-right results without growing the Wasm stack.
(define (filter pred xs)
  (let loop ([remaining xs] [reversed null])
    (cond
      [(null? remaining) (reverse reversed)]
      [(pred (car remaining))
       (loop (cdr remaining) (cons (car remaining) reversed))]
      [else (loop (cdr remaining) reversed)])))

(provide (except-out (all-from-out racket/base)
                     format
                     fprintf
                     printf
                     eprintf)
         (rename-out [wr-format format]
                     [wr-fprintf fprintf]
                     [wr-printf printf]
                     [wr-eprintf eprintf])
         write
         writeln
         print
         println
         read-bytes-line
         map
         filter
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
  (define original-kw-args kw-args)
  (let loop ([kws kws] [kw-args kw-args] [key #f] [cache-keys? #f])
    (cond
      [(null? kws)
       (cond
         [(and (not key)
               (not cache-keys?)
               (pair? original-kw-args)
               (null? (cdr original-kw-args)))
          (define value (car original-kw-args))
          (values value cache-keys?)]
         [else (values key cache-keys?)])]
      [(eq? (car kws) '#:key)
       (loop (cdr kws) (cdr kw-args) (car kw-args) cache-keys?)]
      [(eq? (car kws) '#:cache-keys?)
       (loop (cdr kws) (cdr kw-args) key (car kw-args))]
      [else
       (raise-arguments-error 'sort
                              "unsupported keyword"
                              "keyword" (car kws))])))

;; sort-expanded-call : any/c any/c any/c any/c -> list?
;;   Support both internal expanded sort orders seen after module lowering.
(define (sort-expanded-call a b c d)
  (cond
    [(or (null? a) (pair? a))
     (primitive-sort/expanded-keywords a b #f d #f c)]
    [else
     (primitive-sort/expanded-keywords c d #f b #f a)]))

;; sort : list? procedure? -> list?
;;   Keyword-aware public wrapper over WebRacket's primitive list sort.
(define sort
  (make-keyword-procedure
   (lambda (kws kw-args a b . rest)
     (define-values (key cache-keys?) (sort-keyword-options kws kw-args))
     (case (length rest)
       [(0)
        (primitive-sort/expanded-keywords a b #f key #f cache-keys?)]
       [(2)
       ;; Expanded module code can pass sort's internal positional keyword
       ;; shape as (cache-keys? key xs less-than?) before the fixed primitive
       ;; helper reorders the values.
        (sort-expanded-call a b (car rest) (cadr rest))]
       [else
        (raise-arguments-error 'sort
                               "wrong number of arguments"
                               "arguments" (cons a (cons b rest)))]))
   (case-lambda
     [(xs less-than?)
      (primitive-sort/expanded-keywords xs less-than? #f #f #f #f)]
     [(a b c d)
      (sort-expanded-call a b c d)])))

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
