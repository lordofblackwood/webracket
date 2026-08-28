#lang racket/base

(require (except-in racket/base
                    read-bytes-line
                    fprintf
                    printf
                    eprintf
                    write
                    writeln
                    print
                    println
                    make-keyword-procedure
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
         (only-in racket/base
                  [write racket-write]
                  [writeln racket-writeln]
                  [print racket-print]
                  [println racket-println])
         racket/bool
         racket/bytes
         racket/class
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
         racket/unit
         (except-in racket/vector vector-member vector-sort vector-sort!)
         (only-in "../primitives.rkt"
                  [sort/expanded-keywords primitive-sort/expanded-keywords]
                  [vector-sort/expanded-keywords primitive-vector-sort/expanded-keywords]
                  [vector-sort!/expanded-keywords primitive-vector-sort!/expanded-keywords])
         (only-in "../private/kw.rkt"
                  make-keyword-procedure)
         "../contract.rkt"
         (only-in "../private/format.rkt"
                  [format wr-format]
                  [fprintf wr-fprintf]
                  [printf wr-printf]
                  [eprintf wr-eprintf]
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

;; extract-sort-keywords : symbol? (listof keyword?) list? -> values
;;   Decode the keyword options supported by WebRacket's primitive sort bridge.
(define (extract-sort-keywords who kws kw-args)
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
       (raise-arguments-error who
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
     (define-values (key cache-keys?) (extract-sort-keywords 'sort kws kw-args))
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

;; vector-sort/range+keywords : vector? procedure? list? procedure? any/c -> vector?
;;   Sort a range with keyword options when the fixed-shape primitive is too narrow.
(define (vector-sort/range+keywords vec less-than? maybe-range key cache-keys?)
  (case (length maybe-range)
    [(0) (primitive-vector-sort/expanded-keywords vec less-than? #f key #f cache-keys?)]
    [else
     (raise-arguments-error 'vector-sort
                            "range arguments are not supported by the WebRacket keyword sort bridge yet"
                            "range arguments" maybe-range)]))

;; vector-sort!/range+keywords : vector? procedure? list? procedure? any/c -> void?
;;   Sort a range in place with keyword options when the fixed-shape primitive is too narrow.
(define (vector-sort!/range+keywords vec less-than? maybe-range key cache-keys?)
  (case (length maybe-range)
    [(0) (primitive-vector-sort!/expanded-keywords vec less-than? #f key #f cache-keys?)]
    [else
     (raise-arguments-error 'vector-sort!
                            "range arguments are not supported by the WebRacket keyword sort bridge yet"
                            "range arguments" maybe-range)]))

;; vector-sort : vector? procedure? [exact-nonnegative-integer? exact-nonnegative-integer?] -> vector?
;;   Keyword-aware public wrapper over WebRacket's primitive vector sort.
(define vector-sort
  (make-keyword-procedure
   (lambda (kws kw-args vec less-than? . maybe-range)
     (define-values (key cache-keys?) (extract-sort-keywords 'vector-sort kws kw-args))
     (cond
       [(null? maybe-range)
        (primitive-vector-sort/expanded-keywords vec less-than? #f key #f cache-keys?)]
       [else
        (vector-sort/range+keywords vec less-than? maybe-range key cache-keys?)]))))

;; vector-sort! : vector? procedure? [exact-nonnegative-integer? exact-nonnegative-integer?] -> void?
;;   Keyword-aware public wrapper over WebRacket's primitive in-place vector sort.
(define vector-sort!
  (make-keyword-procedure
   (lambda (kws kw-args vec less-than? . maybe-range)
     (define-values (key cache-keys?) (extract-sort-keywords 'vector-sort! kws kw-args))
     (cond
       [(null? maybe-range)
        (primitive-vector-sort!/expanded-keywords vec less-than? #f key #f cache-keys?)]
       [else
        (vector-sort!/range+keywords vec less-than? maybe-range key cache-keys?)]))))

(provide (except-out (all-from-out racket/base)
                     format
                     fprintf
                     printf
                     eprintf)
         read-bytes-line
         (rename-out [wr-format format]
                     [wr-fprintf fprintf]
                     [wr-printf printf]
                     [wr-eprintf eprintf])
         write
         writeln
         print
         println
         sort
         (all-from-out racket/bool)
         (all-from-out racket/bytes)
         (all-from-out racket/class)
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
         (all-from-out racket/unit)
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
