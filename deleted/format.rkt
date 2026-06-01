;; Retired legacy public `webracket/format` shim.
;;
;; Goal 1 now routes `racket/format` through the staged `io/format` adapter and
;; internal WebRacket modules that need formatting import `webracket/private/format`.
;; Keep this file outside the collection temporarily as a reference while we
;; finish removing old stdlib-era shims.
#lang racket/base

(require (only-in racket/private/kw
                  [make-keyword-procedure wr-make-keyword-procedure]))

(provide format
         fprintf
         printf
         eprintf
         ~a
         ~s
         ~v
         ~e
         ~r
         ~.a
         ~.s
         ~.v)

;; A small contract-free `racket/format` substitute for Goal 1 module
;; programs. The padding/truncation keywords follow the Reference shape for
;; the common textual formatters; full numeric `~r` remains a later staged
;; io/format milestone.

;; value->string : string? any/c -> string?
;;   Format one value with a one-value format directive.
(define (value->string directive value)
  (cond
    [(or (string=? directive "~s")
         (string=? directive "~.s"))
     (write-value->string value)]
    [(or (string=? directive "~v")
         (string=? directive "~.v"))
     (print-value->string value)]
    [else (display-value->string value)]))

;; wr-format : string? any/c ... -> string?
;;   Local export-cell wrapper for the base formatter.
(define (wr-format fmt . args)
  (format-string fmt args))

;; format : string? any/c ... -> string?
;;   Public binding used by module-provider composition.
(define format wr-format)

;; wr-fprintf : output-port? string? any/c ... -> void?
;;   Local export-cell wrapper for formatted output.
(define (wr-fprintf out fmt . args)
  (display (format-string fmt args) out))

;; fprintf : output-port? string? any/c ... -> void?
;;   Public binding used by module-provider composition.
(define fprintf wr-fprintf)

;; wr-printf : string? any/c ... -> void?
;;   Local export-cell wrapper for current-output-port formatted output.
(define (wr-printf fmt . args)
  (display (format-string fmt args)))

;; printf : string? any/c ... -> void?
;;   Public binding used by module-provider composition.
(define printf wr-printf)

;; wr-eprintf : string? any/c ... -> void?
;;   Local export-cell wrapper for current-error-port formatted output.
(define (wr-eprintf fmt . args)
  (display (format-string fmt args) (current-error-port)))

;; eprintf : string? any/c ... -> void?
;;   Public binding used by module-provider composition.
(define eprintf wr-eprintf)

;; one-character-string : char? -> string?
;;   Build a one-character string.
(define (one-character-string ch)
  (make-string 1 ch))

;; display-value->string : any/c -> string?
;;   Small display-mode value renderer for the format shim.
(define (display-value->string value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [(keyword? value) (string-append "#:" (keyword->string value))]
    [(number? value) (number->string value)]
    [(boolean? value) (if value "#t" "#f")]
    [(char? value) (one-character-string value)]
    [(null? value) "()"]
    [(pair? value) (string-append "(" (display-list->string value) ")")]
    [(vector? value) (string-append "#(" (display-vector->string value) ")")]
    [(hash? value) (hash->string* value display-value->string)]
    [else "#<value>"]))

;; write-value->string : any/c -> string?
;;   Small write/print-mode value renderer for the format shim.
(define (write-value->string value)
  (cond
    [(string? value) (write-string-literal value)]
    [(char? value) (write-char-literal value)]
    [(pair? value) (string-append "(" (write-list->string value) ")")]
    [(vector? value) (string-append "#(" (write-vector->string value) ")")]
    [(hash? value) (hash->string* value write-value->string)]
    [else (display-value->string value)]))

;; print-value->string : any/c -> string?
;;   Small print-mode renderer for the format shim.
(define (print-value->string value)
  (cond
    [(or (symbol? value) (null? value) (pair? value) (vector? value) (hash? value))
     (string-append "'" (write-value->string value))]
    [else (write-value->string value)]))

;; write-string-literal : string? -> string?
;;   Render a string literal with basic Racket write escapes.
(define (write-string-literal value)
  (define len (string-length value))
  (let loop ([i 0] [acc "\""])
    (cond
      [(= i len) (string-append acc "\"")]
      [else
       (define ch (string-ref value i))
       (define escaped
         (cond
           [(char=? ch #\\) "\\\\"]
           [(char=? ch #\") "\\\""]
           [(char=? ch #\newline) "\\n"]
           [(char=? ch #\return) "\\r"]
           [(char=? ch #\tab) "\\t"]
           [else (one-character-string ch)]))
       (loop (+ i 1) (string-append acc escaped))])))

;; write-char-literal : char? -> string?
;;   Render the common named character literals used by write.
(define (write-char-literal value)
  (cond
    [(char=? value #\space) "#\\space"]
    [(char=? value #\newline) "#\\newline"]
    [(char=? value #\tab) "#\\tab"]
    [(char=? value #\return) "#\\return"]
    [else (string-append "#\\" (one-character-string value))]))

;; display-list->string : list? -> string?
;;   Render a proper or dotted list in display mode.
(define (display-list->string value)
  (list->string* value display-value->string))

;; write-list->string : list? -> string?
;;   Render a proper or dotted list in write mode.
(define (write-list->string value)
  (list->string* value write-value->string))

;; list->string* : pair? procedure? -> string?
;;   Shared list renderer.
(define (list->string* value elem->string)
  (let loop ([rest value] [first? #t] [acc ""])
    (cond
      [(null? rest) acc]
      [(pair? rest)
       (loop (cdr rest)
             #f
             (string-append acc
                            (if first? "" " ")
                            (elem->string (car rest))))]
      [else
       (string-append acc " . " (elem->string rest))])))

;; display-vector->string : vector? -> string?
;;   Render a vector in display mode.
(define (display-vector->string value)
  (vector->string* value display-value->string))

;; write-vector->string : vector? -> string?
;;   Render a vector in write mode.
(define (write-vector->string value)
  (vector->string* value write-value->string))

;; hash->string* : hash? procedure? -> string?
;;   Render a hash table as a write-style association list.
(define (hash->string* value elem->string)
  (let loop ([pos (hash-iterate-first value)] [first? #t] [acc ""])
    (cond
      [(not pos) (string-append "#hash(" acc ")")]
      [else
       (define key (hash-iterate-key value pos #f))
       (define entry (cons key (hash-ref value key)))
       (loop (hash-iterate-next value pos)
             #f
             (string-append acc
                            (if first? "" " ")
                            (elem->string entry)))])))

;; vector->string* : vector? procedure? -> string?
;;   Shared vector renderer.
(define (vector->string* value elem->string)
  (let loop ([i 0] [acc ""])
    (cond
      [(= i (vector-length value)) acc]
      [else
       (loop (+ i 1)
             (string-append acc
                            (if (zero? i) "" " ")
                            (elem->string (vector-ref value i))))])))

;; consume-format-arg : symbol? list? -> values
;;   Get the next format argument or raise a small arity error.
(define (consume-format-arg who args)
  (cond
    [(pair? args) (values (car args) (cdr args))]
    [else
     (raise-arguments-error who
                            "not enough arguments for format string")]))

;; format-string : string? list? -> string?
;;   Small formatter for ~a, ~s, ~v, ~e, ~%, ~n, and ~~.
(define (format-string fmt args)
  (define len (string-length fmt))
  (let loop ([i 0] [args args] [acc ""])
    (cond
      [(= i len) acc]
      [else
       (define ch (string-ref fmt i))
       (cond
         [(and (char=? ch #\~) (< (+ i 1) len))
          (define next (string-ref fmt (+ i 1)))
          (cond
            [(char=? next #\~)
             (loop (+ i 2) args (string-append acc "~"))]
            [(or (char=? next #\n) (char=? next #\%))
             (loop (+ i 2) args (string-append acc "\n"))]
            [(or (char=? next #\a) (char=? next #\e))
             (define-values (arg rest) (consume-format-arg 'format args))
             (loop (+ i 2) rest (string-append acc (display-value->string arg)))]
            [(char=? next #\s)
             (define-values (arg rest) (consume-format-arg 'format args))
             (loop (+ i 2) rest (string-append acc (write-value->string arg)))]
            [(char=? next #\v)
             (define-values (arg rest) (consume-format-arg 'format args))
             (loop (+ i 2) rest (string-append acc (print-value->string arg)))]
            [else
             (loop (+ i 2)
                   args
                   (string-append acc "~" (one-character-string next)))])]
         [else
          (loop (+ i 1)
                args
                (string-append acc (one-character-string ch)))])])))

;; join-formatted-values : string? string? list? -> string?
;;   Convert values and join them with separator.
(define (join-formatted-values directive separator values)
  (let loop ([values values] [first? #t] [acc ""])
    (cond
      [(null? values) acc]
      [else
       (define piece (value->string directive (car values)))
       (loop (cdr values)
             #f
             (string-append acc
                            (if first? "" separator)
                            piece))])))

;; repeat-string-at-least : string? exact-nonnegative-integer? -> string?
;;   Repeat s until the result has at least len characters.
(define (repeat-string-at-least s len)
  (let loop ([acc ""])
    (if (>= (string-length acc) len)
        acc
        (loop (string-append acc s)))))

;; left-pad : string? exact-nonnegative-integer? string? -> string?
;;   Pad the left side using prefixes of pad-string when needed.
(define (left-pad s amount pad-string)
  (cond
    [(zero? amount) s]
    [else
     (define padding (repeat-string-at-least pad-string amount))
     (string-append (substring padding 0 amount) s)]))

;; right-pad : string? exact-nonnegative-integer? string? -> string?
;;   Pad the right side using suffixes of pad-string when needed.
(define (right-pad s amount pad-string)
  (cond
    [(zero? amount) s]
    [else
     (define padding (repeat-string-at-least pad-string amount))
     (define padding-length (string-length padding))
     (string-append s (substring padding (- padding-length amount) padding-length))]))

;; truncate-formatted : string? exact-nonnegative-integer? string? boolean? -> string?
;;   Truncate s and splice in the limit marker.
(define (truncate-formatted s max-width limit-marker limit-prefix?)
  (define marker-length (string-length limit-marker))
  (when (> marker-length max-width)
    (raise-arguments-error '~a
                           "limit marker is longer than maximum width"
                           "limit marker" limit-marker
                           "maximum width" max-width))
  (define keep (- max-width marker-length))
  (cond
    [limit-prefix?
     (string-append limit-marker
                    (substring s (- (string-length s) keep) (string-length s)))]
    [else
     (string-append (substring s 0 keep)
                    limit-marker)]))

;; pad-formatted : string? exact-nonnegative-integer? symbol? string? string? -> string?
;;   Pad s according to the documented alignment mode.
(define (pad-formatted s min-width align left-pad-string right-pad-string)
  (define amount (- min-width (string-length s)))
  (cond
    [(<= amount 0) s]
    [(eq? align 'right)
     (left-pad s amount left-pad-string)]
    [(eq? align 'center)
     (define left-amount (quotient amount 2))
     (define right-amount (- amount left-amount))
     (right-pad (left-pad s left-amount left-pad-string)
                right-amount
                right-pad-string)]
    [else
     (right-pad s amount right-pad-string)]))

;; format-values : symbol? string? list? string? any/c exact-nonnegative-integer? string? boolean? symbol? string? string? string? -> string?
;;   Shared implementation for ~a, ~s, ~v, ~e, and dotted variants.
(define (format-values who
                       directive
                       values
                       separator
                       width
                       max-width
                       min-width
                       limit-marker
                       limit-prefix?
                       align
                       pad-string
                       left-pad-string
                       right-pad-string)
  (unless (or (not width) (exact-nonnegative-integer? width))
    (raise-argument-error who "(or/c exact-nonnegative-integer? #f)" width))
  (unless (or (eqv? max-width +inf.0) (exact-nonnegative-integer? max-width))
    (raise-argument-error who "(or/c exact-nonnegative-integer? +inf.0)" max-width))
  (unless (exact-nonnegative-integer? min-width)
    (raise-argument-error who "exact-nonnegative-integer?" min-width))
  (when (and (exact-integer? max-width) (> min-width max-width))
    (raise-arguments-error who
                           "minimum width is greater than maximum width"
                           "minimum width" min-width
                           "maximum width" max-width))
  (unless (or (eq? align 'left) (eq? align 'right) (eq? align 'center))
    (raise-argument-error who "(or/c 'left 'center 'right)" align))
  (define joined (join-formatted-values directive separator values))
  (define truncated
    (if (and (exact-integer? max-width)
             (> (string-length joined) max-width))
        (truncate-formatted joined max-width limit-marker limit-prefix?)
        joined))
  (pad-formatted truncated min-width align left-pad-string right-pad-string))

;; find-keyword-value : (listof keyword?) list? keyword? any/c -> any/c
;;   Find a keyword argument value, or return default when absent.
(define (find-keyword-value kws kw-args key default)
  (let loop ([kws kws] [kw-args kw-args])
    (cond
      [(null? kws) default]
      [(eq? (car kws) key) (car kw-args)]
      [else (loop (cdr kws) (cdr kw-args))])))

;; check-format-keywords : symbol? (listof keyword?) -> void?
;;   Reject unsupported abbreviated-format keywords.
(define (check-format-keywords who kws)
  (let loop ([kws kws])
    (cond
      [(null? kws) (void)]
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
       (loop (cdr kws))]
      [else
       (raise-arguments-error who
                              "unsupported keyword"
                              "keyword" (car kws))])))

;; apply-format-keywords : symbol? string? string? string? (listof keyword?) list? list? -> string?
;;   Parse abbreviated-format keywords and run the shared formatter.
(define (apply-format-keywords who directive default-separator default-limit-marker kws kw-args values)
  (check-format-keywords who kws)
  (define width (find-keyword-value kws kw-args '#:width #f))
  (define max-width
    (find-keyword-value kws kw-args '#:max-width (if width width +inf.0)))
  (define min-width
    (find-keyword-value kws kw-args '#:min-width (if width width 0)))
  (define pad-string (find-keyword-value kws kw-args '#:pad-string " "))
  (format-values who
                 directive
                 values
                 (find-keyword-value kws kw-args '#:separator default-separator)
                 width
                 max-width
                 min-width
                 (find-keyword-value kws kw-args '#:limit-marker default-limit-marker)
                 (find-keyword-value kws kw-args '#:limit-prefix? #f)
                 (find-keyword-value kws kw-args '#:align 'left)
                 pad-string
                 (find-keyword-value kws kw-args '#:left-pad-string pad-string)
                 (find-keyword-value kws kw-args '#:right-pad-string pad-string)))

;; make-abbrev-formatter : symbol? string? string? string? -> procedure?
;;   Build a keyword-aware formatter without using keyword-lambda expansion.
(define (make-abbrev-formatter who directive default-separator default-limit-marker)
  (wr-make-keyword-procedure
   (lambda (kws kw-args . values)
     (apply-format-keywords who directive default-separator default-limit-marker kws kw-args values))
   (lambda values
     (apply-format-keywords who directive default-separator default-limit-marker null null values))))

;; ~a : any/c ... #:separator string? #:width (or/c exact-nonnegative-integer? #f) ... -> string?
;;   Convert values in display mode, then join, truncate, and pad.
(define ~a (make-abbrev-formatter '~a "~a" "" ""))

;; ~s : any/c ... -> string?
;;   Convert values in write mode, then join, truncate, and pad.
(define ~s (make-abbrev-formatter '~s "~s" " " "..."))

;; ~v : any/c ... -> string?
;;   Convert values in print mode, then join, truncate, and pad.
(define ~v (make-abbrev-formatter '~v "~v" " " "..."))

;; ~e : any/c ... -> string?
;;   Convert values in error-value mode, then join, truncate, and pad.
(define ~e (make-abbrev-formatter '~e "~e" " " "..."))

;; ~.a : any/c ... -> string?
;;   Like ~a, using the runtime's compact display directive.
(define ~.a (make-abbrev-formatter '~.a "~.a" "" ""))

;; ~.s : any/c ... -> string?
;;   Like ~s, using the runtime's compact write directive.
(define ~.s (make-abbrev-formatter '~.s "~.s" " " "..."))

;; ~.v : any/c ... -> string?
;;   Like ~v, using the runtime's compact print directive.
(define ~.v (make-abbrev-formatter '~.v "~.v" " " "..."))

;; ~r : rational? ... -> string?
;;   Minimal numeric formatter; advanced grouping/sign/notation remains staged.
(define ~r
  (wr-make-keyword-procedure
   (lambda (kws kw-args x)
     (define min-width (find-keyword-value kws kw-args '#:min-width 1))
     (define pad-string (find-keyword-value kws kw-args '#:pad-string " "))
     (unless (number? x)
       (raise-argument-error '~r "number?" x))
     (pad-formatted (number->string x) min-width 'right pad-string pad-string))
   (lambda (x)
     (unless (number? x)
       (raise-argument-error '~r "number?" x))
     (number->string x))))
