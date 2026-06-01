#lang racket/kernel

;;; WebRacket-staged adapter for `racket/format`.
;;;
;;; The public `racket/format` library is a convenience layer. Keep it separate
;;; from the lower staged original-Racket `io/format` slice, which owns
;;; `format`, `fprintf`, `printf`, and `eprintf`.

(#%require (only racket/base
                apply
                append
                and
                case
                ceiling
                char?
                char=?
                cond
                define
                display
                else
                eqv?
                exact-nonnegative-integer?
                floor
                get-output-string
                hash-iterate-first
                hash-iterate-key
                hash-iterate-next
                hash-ref
                hash?
                lambda
                let
                list
                make-string
                memq
                number->string
                number?
                open-output-string
                or
                pair?
                positive?
                print
                quotient/remainder
                raise-argument-error
                rational?
                reverse
                symbol->string
                symbol?
                string-append
                string=?
                string-length
                string-ref
                string?
                substring
                unless
                values
                vector-length
                vector-ref
                vector?
                zero?)
           (only webracket/private/kw
                 make-keyword-procedure))

(#%provide format
           ~a
           ~s
           ~v
           ~e
           ~r
           ~.a
           ~.s
           ~.v)

;; non-empty-string? : any/c -> boolean?
;;   Check whether v is a non-empty string.
(define (non-empty-string? v)
  (and (string? v) (positive? (string-length v))))

;; build-padding : symbol? string? exact-nonnegative-integer? -> string?
;;   Build left or right padding from a possibly multi-character pattern.
(define (build-padding side padding pad-length)
  (cond
    [(zero? pad-length) ""]
    [(= (string-length padding) 1)
     (make-string pad-length (string-ref padding 0))]
    [else
     (define pattern-length (string-length padding))
     (define-values (whole-copies part-length)
       (quotient/remainder pad-length pattern-length))
     (define pattern-copies
       (let loop ([i 0] [acc null])
         (if (= i whole-copies)
             (reverse acc)
             (loop (+ i 1) (cons padding acc)))))
     (apply string-append
            (case side
              [(left)
               (append pattern-copies
                       (list (substring padding 0 part-length)))]
              [else
               (cons (substring padding (- pattern-length part-length) pattern-length)
                     pattern-copies)]))]))

;; limit-string : exact-nonnegative-integer? string? boolean? string? -> string?
;;   Apply racket/format-style max-width limiting.
(define (limit-string limit limit-marker limit-prefix? s)
  (define len (string-length s))
  (cond
    [(> len limit)
     (if limit-prefix?
         (string-append limit-marker
                        (substring s (+ (- len limit) (string-length limit-marker))))
         (string-append (substring s 0 (- limit (string-length limit-marker)))
                        limit-marker))]
    [else s]))

;; pad-string : exact-nonnegative-integer? symbol? string? string? string? -> string?
;;   Pad s to the requested width and alignment.
(define (pad-string pad-to align left-padding right-padding s)
  (cond
    [(< (string-length s) pad-to)
     (define to-pad-length (- pad-to (string-length s)))
     (define-values (left-pad-length right-pad-length)
       (case align
         [(left) (values 0 to-pad-length)]
         [(right) (values to-pad-length 0)]
         [else (values (floor (/ to-pad-length 2))
                       (ceiling (/ to-pad-length 2)))]))
     (string-append
      (build-padding 'left left-padding left-pad-length)
      s
      (build-padding 'right right-padding right-pad-length))]
    [else s]))

;; option-ref : (listof (cons/c keyword? any/c)) keyword? any/c -> any/c
;;   Look up a keyword option supplied to a format helper.
(define (option-ref options key default)
  (cond
    [(null? options) default]
    [(eqv? (car (car options)) key) (cdr (car options))]
    [else (option-ref (cdr options) key default)]))

;; collect-options : symbol? (listof keyword?) (listof any/c) -> (listof (cons/c keyword? any/c))
;;   Convert keyword/value lists to local option pairs.
(define (collect-options who kws vals)
  (cond
    [(null? kws)
     (unless (null? vals)
       (raise-argument-error who "keyword/value lists of matching length" vals))
     null]
    [(null? vals)
     (raise-argument-error who "keyword/value lists of matching length" kws)]
    [(memq (car kws)
           '(#:separator
             #:width
             #:max-width
             #:min-width
             #:limit-marker
             #:limit-prefix?
             #:align
             #:pad-string
             #:left-pad-string
             #:right-pad-string))
     (cons (cons (car kws) (car vals))
           (collect-options who (cdr kws) (cdr vals)))]
    [else
     (raise-argument-error who "supported racket/format keyword" (car kws))]))

;; format-values : symbol? (any/c -> string?) string? string? options? (listof any/c) -> string?
;;   Shared implementation for `~a`, `~s`, `~v`, and `~e`.
(define (format-values who
                       value->string
                       default-separator
                       default-limit-marker
                       options
                       values)
  (define separator (option-ref options '#:separator default-separator))
  (define width (option-ref options '#:width #f))
  (define limit (option-ref options '#:max-width (or width +inf.0)))
  (define pad-to (option-ref options '#:min-width (or width 0)))
  (define limit-marker (option-ref options '#:limit-marker default-limit-marker))
  (define limit-prefix? (option-ref options '#:limit-prefix? #f))
  (define align (option-ref options '#:align 'left))
  (define padding (option-ref options '#:pad-string " "))
  (define left-padding (option-ref options '#:left-pad-string padding))
  (define right-padding (option-ref options '#:right-pad-string padding))
  (unless (or (not width) (exact-nonnegative-integer? width))
    (raise-argument-error who "(or/c exact-nonnegative-integer? #f)" width))
  (unless (exact-nonnegative-integer? pad-to)
    (raise-argument-error who "exact-nonnegative-integer?" pad-to))
  (unless (or (eqv? limit +inf.0) (exact-nonnegative-integer? limit))
    (raise-argument-error who "(or/c exact-nonnegative-integer? +inf.0)" limit))
  (unless (string? limit-marker)
    (raise-argument-error who "string?" limit-marker))
  (unless (memq align '(left right center))
    (raise-argument-error who "(or/c 'left 'right 'center)" align))
  (define raw
    (cond
      [(null? values) ""]
      [(null? (cdr values)) (value->string (car values))]
      [else
       (let loop ([rest values] [first? #t] [acc ""])
         (cond
           [(null? rest) acc]
           [else
            (loop (cdr rest)
                  #f
                  (string-append acc
                                 (if first? "" separator)
                                 (value->string (car rest))))]))]))
  (pad-string pad-to
              align
              left-padding
              right-padding
              (limit-string limit limit-marker limit-prefix? raw)))

;; make-format-procedure : symbol? (any/c -> string?) string? string? -> procedure?
;;   Build a stable exported keyword procedure without keyword-lambda expansion.
(define (make-format-procedure who value->string default-separator default-limit-marker)
  (make-keyword-procedure
   (lambda (kws vals . args)
     (format-values who
                    value->string
                    default-separator
                    default-limit-marker
                    (collect-options who kws vals)
                    args))
   (lambda args
     (format-values who
                    value->string
                    default-separator
                    default-limit-marker
                    null
                    args))))

;; value->display-string : any/c -> string?
;;   Render v with display mode.
(define (value->display-string v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [(number? v) (number->string v)]
    [(boolean? v) (if v "#t" "#f")]
    [(char? v) (make-string 1 v)]
    [(null? v) "()"]
    [(pair? v) (string-append "(" (list->string* v value->display-string) ")")]
    [(vector? v) (string-append "#(" (vector->string* v value->display-string) ")")]
    [(hash? v) (hash->string* v value->display-string)]
    [else "#<value>"]))

;; value->write-string : any/c -> string?
;;   Render v with write mode.
(define (value->write-string v)
  (cond
    [(string? v) (write-string-literal v)]
    [(char? v) (write-char-literal v)]
    [(pair? v) (string-append "(" (list->string* v value->write-string) ")")]
    [(vector? v) (string-append "#(" (vector->string* v value->write-string) ")")]
    [(hash? v) (hash->string* v value->write-string)]
    [else (value->display-string v)]))

;; value->print-string : any/c -> string?
;;   Render v with print mode.
(define (value->print-string v)
  (cond
    [(or (symbol? v) (null? v) (pair? v) (vector? v) (hash? v))
     (string-append "'" (value->write-string v))]
    [else (value->write-string v)]))

;; write-string-literal : string? -> string?
;;   Render a string with basic write escapes.
(define (write-string-literal s)
  (let loop ([i 0] [acc "\""])
    (cond
      [(= i (string-length s)) (string-append acc "\"")]
      [else
       (define ch (string-ref s i))
       (loop (+ i 1)
             (string-append
              acc
              (cond
                [(char=? ch #\\) "\\\\"]
                [(char=? ch #\") "\\\""]
                [(char=? ch #\newline) "\\n"]
                [(char=? ch #\return) "\\r"]
                [(char=? ch #\tab) "\\t"]
                [else (make-string 1 ch)])))])))

;; write-char-literal : char? -> string?
;;   Render common character literals.
(define (write-char-literal ch)
  (cond
    [(char=? ch #\space) "#\\space"]
    [(char=? ch #\newline) "#\\newline"]
    [(char=? ch #\tab) "#\\tab"]
    [(char=? ch #\return) "#\\return"]
    [else (string-append "#\\" (make-string 1 ch))]))

;; list->string* : any/c (any/c -> string?) -> string?
;;   Render a proper or dotted list body.
(define (list->string* v elem->string)
  (let loop ([rest v] [first? #t] [acc ""])
    (cond
      [(null? rest) acc]
      [(pair? rest)
       (loop (cdr rest)
             #f
             (string-append acc
                            (if first? "" " ")
                            (elem->string (car rest))))]
      [else (string-append acc " . " (elem->string rest))])))

;; vector->string* : vector? (any/c -> string?) -> string?
;;   Render a vector body.
(define (vector->string* v elem->string)
  (let loop ([i 0] [acc ""])
    (cond
      [(= i (vector-length v)) acc]
      [else
       (loop (+ i 1)
             (string-append acc
                            (if (zero? i) "" " ")
                            (elem->string (vector-ref v i))))])))

;; hash->string* : hash? (any/c -> string?) -> string?
;;   Render a hash table as a write-style association list.
(define (hash->string* v elem->string)
  (let loop ([pos (hash-iterate-first v)] [first? #t] [acc ""])
    (cond
      [(not pos) (string-append "#hash(" acc ")")]
      [else
       (define key (hash-iterate-key v pos #f))
       (define entry (cons key (hash-ref v key)))
       (loop (hash-iterate-next v pos)
             #f
             (string-append acc
                            (if first? "" " ")
                            (elem->string entry)))])))

;; consume-format-arg : symbol? list? -> values
;;   Get the next format argument or report a small arity error.
(define (consume-format-arg who args)
  (cond
    [(pair? args) (values (car args) (cdr args))]
    [else (raise-argument-error who "enough arguments for format string" args)]))

;; format-string : string? list? -> string?
;;   Small formatter for ~a, ~s, ~v, ~e, ~%, ~n, and ~~.
(define (format-string fmt args)
  (let loop ([i 0] [args args] [acc ""])
    (cond
      [(= i (string-length fmt)) acc]
      [else
       (define ch (string-ref fmt i))
       (cond
         [(and (char=? ch #\~) (< (+ i 1) (string-length fmt)))
          (define next (string-ref fmt (+ i 1)))
          (cond
            [(char=? next #\~)
             (loop (+ i 2) args (string-append acc "~"))]
            [(or (char=? next #\n) (char=? next #\%))
             (loop (+ i 2) args (string-append acc "\n"))]
            [(or (char=? next #\a) (char=? next #\e))
             (define-values (arg rest) (consume-format-arg 'format args))
             (loop (+ i 2) rest (string-append acc (value->display-string arg)))]
            [(char=? next #\s)
             (define-values (arg rest) (consume-format-arg 'format args))
             (loop (+ i 2) rest (string-append acc (value->write-string arg)))]
            [(char=? next #\v)
             (define-values (arg rest) (consume-format-arg 'format args))
             (loop (+ i 2) rest (string-append acc (value->print-string arg)))]
            [else
             (loop (+ i 2)
                   args
                   (string-append acc "~" (make-string 1 next)))])]
         [else
          (loop (+ i 1)
                args
                (string-append acc (make-string 1 ch)))])])))

;; format : string? any/c ... -> string?
;;   Compact `format` implementation for the staged `racket/format` adapter.
(define (format fmt . args)
  (format-string fmt args))

;; ~a : any/c ... -> string?
;;   Format values in display mode with optional padding and limiting keywords.
(define ~a (make-format-procedure '~a value->display-string "" ""))

;; ~s : any/c ... -> string?
;;   Format values in write mode with optional padding and limiting keywords.
(define ~s (make-format-procedure '~s value->write-string " " "..."))

;; ~v : any/c ... -> string?
;;   Format values in print mode with optional padding and limiting keywords.
(define ~v (make-format-procedure '~v value->print-string " " "..."))

;; ~e : any/c ... -> string?
;;   Format values in error-display mode with optional padding and limiting keywords.
(define ~e (make-format-procedure '~e value->display-string " " "..."))

;; ~.a : any/c ... -> string?
;;   Format values like `~a`; WebRacket currently shares the implementation.
(define ~.a ~a)

;; ~.s : any/c ... -> string?
;;   Format values like `~s`; WebRacket currently shares the implementation.
(define ~.s ~s)

;; ~.v : any/c ... -> string?
;;   Format values like `~v`; WebRacket currently shares the implementation.
(define ~.v ~v)

;; ~r/plain : rational? options? -> string?
;;   Minimal real-number formatter; full `racket/format` keyword support is later.
(define (~r/plain v options)
  (unless (rational? v)
    (raise-argument-error '~r "rational?" v))
  (define min-width (option-ref options '#:min-width 0))
  (define pad (option-ref options '#:pad-string " "))
  (pad-string min-width 'right pad pad (number->string v)))

;; ~r : rational? -> string?
;;   Format a rational number with the currently supported keyword subset.
(define ~r
  (make-keyword-procedure
   (lambda (kws vals v)
     (~r/plain v (collect-options '~r kws vals)))
   (lambda (v)
     (~r/plain v null))))
