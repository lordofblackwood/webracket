#lang racket/base

(provide non-empty-string?
         string-append*
         string-contains?
         string-find
         string-join
         string-normalize-spaces
         string-prefix?
         string-replace
         string-split
         string-suffix?
         string-trim)

;; A small contract-free `racket/string` substitute for Goal 1 module
;; programs. Most operations are compiler/runtime primitives. Keep the
;; high-volume string assembly operations routed to their iterative Wasm
;; implementations rather than expanding `(apply string-append ...)` into a
;; recursive application chain.

;; string-append* : (or/c (listof string?) string? ... string?) -> string?
;;   Append a list of strings or a variadic sequence of strings.
;;
;; The compiler recognizes this public alias as runtime-preferred, so compiled
;; calls go directly to the iterative Wasm primitive. This host definition
;; preserves the provider's ordinary Racket behavior and export shape.
(define string-append*
  (case-lambda
    [(strings) (apply string-append strings)]
    [strings (apply string-append strings)]))

;; non-empty-string? : any/c -> boolean?
;;   Recognize strings with positive length.
(define (non-empty-string? v)
  (and (string? v)
       (positive? (string-length v))))

;; string-prefix? : string? string? -> boolean?
;;   Check whether str starts with prefix.
(define (string-prefix? str prefix)
  (and (<= (string-length prefix) (string-length str))
       (string=? (substring str 0 (string-length prefix)) prefix)))

;; string-suffix? : string? string? -> boolean?
;;   Check whether str ends with suffix.
(define (string-suffix? str suffix)
  (define len (string-length str))
  (define suffix-len (string-length suffix))
  (and (<= suffix-len len)
       (string=? (substring str (- len suffix-len) len) suffix)))

;; string-find : string? string? [exact-nonnegative-integer?] -> (or/c exact-nonnegative-integer? #f)
;;   Return the first index where needle occurs in str.
(define string-find
  (case-lambda
    [(str needle) (string-find str needle 0)]
    [(str needle start)
     (define str-len (string-length str))
     (define needle-len (string-length needle))
     (let loop ([i start])
       (cond
         [(> (+ i needle-len) str-len) #f]
         [(string=? (substring str i (+ i needle-len)) needle) i]
         [else (loop (add1 i))]))]))

;; string-contains? : string? string? -> (or/c exact-nonnegative-integer? #f)
;;   Return the first containment index, matching racket/string's truthy result.
(define (string-contains? str needle)
  (string-find str needle))

;; string-replace : string? string? string? -> string?
;;   Replace all non-overlapping occurrences of from with to.
(define string-replace
  (case-lambda
    [(str from to) (string-replace str from to #t)]
    [(str from to _all?)
     (if (string=? from "")
         str
         (let ([from-len (string-length from)])
           (let loop ([start 0] [acc ""])
             (define i (string-find str from start))
             (if i
                 (loop (+ i from-len)
                       (string-append acc (substring str start i) to))
                 (string-append acc
                                (substring str start (string-length str)))))))]))

;; trim-left : string? -> string?
;;   Drop leading whitespace.
(define (trim-left str)
  (let loop ([i 0])
    (cond
      [(= i (string-length str)) ""]
      [(char-whitespace? (string-ref str i)) (loop (add1 i))]
      [else (substring str i (string-length str))])))

;; trim-right : string? -> string?
;;   Drop trailing whitespace.
(define (trim-right str)
  (let loop ([i (sub1 (string-length str))])
    (cond
      [(negative? i) ""]
      [(char-whitespace? (string-ref str i)) (loop (sub1 i))]
      [else (substring str 0 (add1 i))])))

;; string-trim : string? -> string?
;;   Trim leading and trailing whitespace.
(define string-trim
  (case-lambda
    [(str) (trim-right (trim-left str))]
    [(str _sep) (string-trim str)]
    [(str _sep _repeat?) (string-trim str)]
    [(str _sep _repeat? _left? _right?) (string-trim str)]))

;; split-whitespace : string? -> (listof string?)
;;   Split a string on runs of whitespace.
(define (split-whitespace str)
  (let loop ([i 0] [current ""] [parts '()])
    (cond
      [(= i (string-length str))
       (reverse (if (string=? current "") parts (cons current parts)))]
      [(char-whitespace? (string-ref str i))
       (loop (add1 i) "" (if (string=? current "") parts (cons current parts)))]
      [else
       (loop (add1 i)
             (string-append current (string (string-ref str i)))
             parts)])))

;; split-string : string? string? -> (listof string?)
;;   Split str on a literal separator.
(define (split-string str sep)
  (cond
    [(string=? sep "") (for/list ([ch (in-string str)]) (string ch))]
    [else
     (define sep-len (string-length sep))
     (let loop ([start 0] [parts '()])
       (define i (string-find str sep start))
       (if i
           (loop (+ i sep-len) (cons (substring str start i) parts))
           (reverse (cons (substring str start (string-length str)) parts))))]))

;; string-split : string? [string?] -> (listof string?)
;;   Split on whitespace by default, or on a literal string separator.
(define string-split
  (case-lambda
    [(str) (split-whitespace str)]
    [(str sep) (split-string str sep)]
    [(str sep _repeat?) (string-split str sep)]
    [(str sep _repeat? _trim?) (string-split str sep)]))

;; string-normalize-spaces : string? -> string?
;;   Collapse whitespace runs to single spaces after trimming.
(define string-normalize-spaces
  (case-lambda
    [(str) (string-join (string-split str) " ")]
    [(str _sep) (string-normalize-spaces str)]
    [(str _sep _replacement) (string-normalize-spaces str)]))

;; string-join : (listof string?) [string?] [symbol?] -> string?
;;   Join strings with a separator; before/after modes follow racket/string.
(define string-join
  (case-lambda
    [(strings) (string-join strings " " 'infix)]
    [(strings sep) (string-join strings sep 'infix)]
    [(strings sep mode)
     (cond
       [(null? strings)
        (case mode
          [(infix strict-infix) ""]
          [(prefix suffix) sep]
          [else (raise-argument-error 'string-join
                                      "(or/c 'infix 'strict-infix 'prefix 'suffix)"
                                      mode)])]
       [else
        (define joined
          (let loop ([rest (cdr strings)] [acc (car strings)])
            (if (null? rest)
                acc
                (loop (cdr rest)
                      (string-append acc sep (car rest))))))
        (case mode
          [(infix strict-infix) joined]
          [(prefix) (string-append sep joined)]
          [(suffix) (string-append joined sep)]
          [else (raise-argument-error 'string-join
                                      "(or/c 'infix 'strict-infix 'prefix 'suffix)"
                                      mode)])])]))
