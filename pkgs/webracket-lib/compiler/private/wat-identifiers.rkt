#lang racket/base

(provide rewrite-wat-identifiers
         write-compact-wat
         rewrite-wat-identifiers-from-port
         rewrite-wat-identifiers-to-port)

(require (only-in racket/format ~a))

;; wat-unquoted-idchar? : char? -> boolean?
;;   Check whether c is accepted in an unquoted WAT identifier.
(define (wat-unquoted-idchar? c)
  (define i (char->integer c))
  (and (<= #x21 i #x7e) ; printable ASCII without space
       (not (memq c '(#\" #\, #\; #\( #\) #\[ #\] #\{ #\})))))

;; valid-unquoted-id-token? : string? -> boolean?
;;   Check whether token is a valid unquoted WAT identifier token.
(define (valid-unquoted-id-token? token)
  (and (> (string-length token) 1)
       (char=? (string-ref token 0) #\$)
       (for/and ([c (in-string (substring token 1))])
         (wat-unquoted-idchar? c))))

;; escape-quoted-id-name : string? -> string?
;;   Escape a WAT quoted identifier payload.
(define (escape-quoted-id-name name)
  (define b (open-output-string))
  (for ([c (in-string name)])
    (cond
      [(char=? c #\\) (display "\\\\" b)]
      [(char=? c #\") (display "\\\"" b)]
      [else
       (define i (char->integer c))
       (if (or (< i 32) (= i 127))
           (display (~a "\\u{" (number->string i 16) "}") b)
           (write-char c b))]))
  (get-output-string b))

;; write-wat-symbol : symbol? output-port? -> void?
;;   Write one compact WAT symbol, quoting invalid `$` identifiers.
(define (write-wat-symbol sym out)
  (define token (symbol->string sym))
  (cond
    [(and (positive? (string-length token))
          (char=? (string-ref token 0) #\$)
          (not (valid-unquoted-id-token? token)))
     (display "$\"" out)
     (display (escape-quoted-id-name (substring token 1)) out)
     (display "\"" out)]
    [else
     (display token out)]))

;; write-wat-string : string? output-port? -> void?
;;   Write one WAT string literal using WAT byte/control escapes.
(define (write-wat-string s out)
  (define (write-byte-escape i)
    (display "\\" out)
    (when (< i 16)
      (display "0" out))
    (display (number->string i 16) out))
  (display "\"" out)
  (for ([c (in-string s)])
    (cond
      [(char=? c #\") (display "\\\"" out)]
      [(char=? c #\\) (display "\\\\" out)]
      [else
       (define i (char->integer c))
       (if (or (< i 32) (= i 127))
           (write-byte-escape i)
           (write-char c out))]))
  (display "\"" out))

;; write-compact-wat : any/c output-port? -> void?
;;   Write compact folded WAT directly, avoiding a second identifier rewrite pass.
(define (write-compact-wat wat out)
  (define (write-list xs)
    (display "(" out)
    (let loop ([xs xs] [first? #t])
      (cond
        [(null? xs)
         (display ")" out)]
        [(pair? xs)
         (unless first?
           (display " " out))
         (write-one (car xs))
         (loop (cdr xs) #f)]
        [else
         (display " . " out)
         (write-one xs)
         (display ")" out)])))
  (define (write-one v)
    (cond
      [(syntax? v) (write-one (syntax->datum v))]
      [(symbol? v) (write-wat-symbol v out)]
      [(string? v) (write-wat-string v out)]
      [(pair? v)   (write-list v)]
      [(null? v)   (display "()" out)]
      [else        (write v out)]))
  (write-one wat))

;; rewrite-wat-identifiers-to-port : string? output-port? -> void?
;;   Write WAT text with invalid unquoted identifiers rewritten into quoted form.
(define (rewrite-wat-identifiers-to-port s out)
  (define n (string-length s))

  (define (emit str) (display str out))
  (define (emit-char ch) (write-char ch out))
  (define (ch i) (string-ref s i))
  (define (in-range? i) (< i n))

  (define (delimiter? c)
    (or (char-whitespace? c)
        (char=? c #\()
        (char=? c #\))
        (char=? c #\")
        (char=? c #\;)))

  (define (wat-unquoted-idchar? c)
    (define i (char->integer c))
    (and (<= #x21 i #x7e) ; printable ASCII without space
         (not (memq c '(#\" #\, #\; #\( #\) #\[ #\] #\{ #\})))))

  (define (valid-unquoted-id-token? token)
    (and (> (string-length token) 1)
         (char=? (string-ref token 0) #\$)
         (for/and ([c (in-string (substring token 1))])
           (wat-unquoted-idchar? c))))

  (define (escape-quoted-id-name name)
    (define b (open-output-string))
    (for ([c (in-string name)])
      (cond
        [(char=? c #\\) (display "\\\\" b)]
        [(char=? c #\") (display "\\\"" b)]
        [else
         (define i (char->integer c))
         (if (or (< i 32) (= i 127))
             (display (~a "\\u{" (number->string i 16) "}") b)
             (write-char c b))]))
    (get-output-string b))

  (let loop ([i 0] [state 'code] [comment-depth 0] [escaped? #f])
    (cond
      [(not (in-range? i))
       (void)]

      [(eq? state 'string)
       (define c (ch i))
       (emit-char c)
       (cond
         [escaped? (loop (add1 i) 'string comment-depth #f)]
         [(char=? c #\\) (loop (add1 i) 'string comment-depth #t)]
         [(char=? c #\") (loop (add1 i) 'code comment-depth #f)]
         [else (loop (add1 i) 'string comment-depth #f)])]

      [(eq? state 'line-comment)
       (define c (ch i))
       (emit-char c)
       (if (char=? c #\newline)
           (loop (add1 i) 'code comment-depth #f)
           (loop (add1 i) 'line-comment comment-depth #f))]

      [(eq? state 'block-comment)
       (cond
         [(and (< (add1 i) n)
               (char=? (ch i) #\()
               (char=? (ch (add1 i)) #\;))
          (emit "(;")
          (loop (+ i 2) 'block-comment (add1 comment-depth) #f)]
         [(and (< (add1 i) n)
               (char=? (ch i) #\;)
               (char=? (ch (add1 i)) #\)))
          (emit ";)")
          (define next-depth (sub1 comment-depth))
          (loop (+ i 2)
                (if (zero? next-depth) 'code 'block-comment)
                next-depth
                #f)]
         [else
          (emit-char (ch i))
          (loop (add1 i) 'block-comment comment-depth #f)])]

      [else ; code
       (cond
         [(and (< (add1 i) n)
               (char=? (ch i) #\;)
               (char=? (ch (add1 i)) #\;))
          (emit ";;")
          (loop (+ i 2) 'line-comment comment-depth #f)]

         [(and (< (add1 i) n)
               (char=? (ch i) #\()
               (char=? (ch (add1 i)) #\;))
          (emit "(;")
          (loop (+ i 2) 'block-comment 1 #f)]

         [(char=? (ch i) #\")
          (emit-char #\")
          (loop (add1 i) 'string comment-depth #f)]

         [(char=? (ch i) #\$)
          (cond
            [(and (< (add1 i) n) (char=? (ch (add1 i)) #\"))
             (emit "$\"")
             (loop (+ i 2) 'string comment-depth #f)]
            [else
             (define j
               (let find-end ([k i])
                 (if (or (not (in-range? k))
                         (delimiter? (ch k)))
                     k
                     (find-end (add1 k)))))
             (define token (substring s i j))
             (if (valid-unquoted-id-token? token)
                 (emit token)
                 (let ([name (substring token 1)])
                   (emit (~a "$\"" (escape-quoted-id-name name) "\""))))
             (loop j 'code comment-depth #f)])]

         [else
          (emit-char (ch i))
         (loop (add1 i) 'code comment-depth #f)])])))

;; rewrite-wat-identifiers-from-port : input-port? output-port? -> void?
;;   Stream WAT text while rewriting invalid unquoted identifiers.
(define (rewrite-wat-identifiers-from-port in out)
  (define (emit str) (display str out))
  (define (emit-char ch) (write-char ch out))

  (define (delimiter? c)
    (or (char-whitespace? c)
        (char=? c #\()
        (char=? c #\))
        (char=? c #\")
        (char=? c #\;)))

  (define (wat-unquoted-idchar? c)
    (define i (char->integer c))
    (and (<= #x21 i #x7e) ; printable ASCII without space
         (not (memq c '(#\" #\, #\; #\( #\) #\[ #\] #\{ #\})))))

  (define (valid-unquoted-id-token? token)
    (and (> (string-length token) 1)
         (char=? (string-ref token 0) #\$)
         (for/and ([c (in-string (substring token 1))])
           (wat-unquoted-idchar? c))))

  (define (escape-quoted-id-name name)
    (define b (open-output-string))
    (for ([c (in-string name)])
      (cond
        [(char=? c #\\) (display "\\\\" b)]
        [(char=? c #\") (display "\\\"" b)]
        [else
         (define i (char->integer c))
         (if (or (< i 32) (= i 127))
             (display (~a "\\u{" (number->string i 16) "}") b)
             (write-char c b))]))
    (get-output-string b))

  (define (peek-next)
    (peek-char in))

  (define (read-next)
    (read-char in))

  (define (emit-dollar-token)
    (define token-out (open-output-string))
    (write-char #\$ token-out)
    (let loop ()
      (define next (peek-next))
      (unless (or (eof-object? next)
                  (delimiter? next))
        (write-char (read-next) token-out)
        (loop)))
    (define token (get-output-string token-out))
    (if (valid-unquoted-id-token? token)
        (emit token)
        (let ([name (substring token 1)])
          (emit (~a "$\"" (escape-quoted-id-name name) "\"")))))

  (let loop ([state 'code] [comment-depth 0] [escaped? #f])
    (define c (read-next))
    (unless (eof-object? c)
      (case state
        [(string)
         (emit-char c)
         (cond
           [escaped? (loop 'string comment-depth #f)]
           [(char=? c #\\) (loop 'string comment-depth #t)]
           [(char=? c #\") (loop 'code comment-depth #f)]
           [else (loop 'string comment-depth #f)])]
        [(line-comment)
         (emit-char c)
         (if (char=? c #\newline)
             (loop 'code comment-depth #f)
             (loop 'line-comment comment-depth #f))]
        [(block-comment)
         (cond
           [(and (char=? c #\()
                 (let ([next (peek-next)])
                   (and (char? next) (char=? next #\;))))
            (read-next)
            (emit "(;")
            (loop 'block-comment (add1 comment-depth) #f)]
           [(and (char=? c #\;)
                 (let ([next (peek-next)])
                   (and (char? next) (char=? next #\)))))
            (read-next)
            (emit ";)")
            (define next-depth (sub1 comment-depth))
            (loop (if (zero? next-depth) 'code 'block-comment)
                  next-depth
                  #f)]
           [else
            (emit-char c)
            (loop 'block-comment comment-depth #f)])]
        [else
         (cond
           [(and (char=? c #\;)
                 (let ([next (peek-next)])
                   (and (char? next) (char=? next #\;))))
            (read-next)
            (emit ";;")
            (loop 'line-comment comment-depth #f)]
           [(and (char=? c #\()
                 (let ([next (peek-next)])
                   (and (char? next) (char=? next #\;))))
            (read-next)
            (emit "(;")
            (loop 'block-comment 1 #f)]
           [(char=? c #\")
            (emit-char #\")
            (loop 'string comment-depth #f)]
           [(char=? c #\$)
            (define next (peek-next))
            (cond
              [(and (char? next) (char=? next #\"))
               (read-next)
               (emit "$\"")
               (loop 'string comment-depth #f)]
              [else
               (emit-dollar-token)
               (loop 'code comment-depth #f)])]
           [else
            (emit-char c)
            (loop 'code comment-depth #f)])]))))

;; rewrite-wat-identifiers : string? -> string?
;;   Rewrite invalid unquoted WAT identifiers ($...) into quoted form ($"..."),
;;   while preserving strings and comments.
(define (rewrite-wat-identifiers s)
  (define out (open-output-string))
  (rewrite-wat-identifiers-to-port s out)
  (get-output-string out))

(module+ test
  (require rackunit)

  (check-equal? (rewrite-wat-identifiers "(func $ok)")
                "(func $ok)")
  (check-equal? (rewrite-wat-identifiers "(func $bad/name[0])")
                "(func $\"bad/name[0]\")")
  (check-equal? (rewrite-wat-identifiers "(func $\"already quoted\")")
                "(func $\"already quoted\")")
  (check-equal? (rewrite-wat-identifiers "(data \"keep $bad[name]\")")
                "(data \"keep $bad[name]\")")
  (check-equal? (rewrite-wat-identifiers ";; keep $bad[name]\n(func $x)")
                ";; keep $bad[name]\n(func $x)")
  (define out (open-output-string))
  (rewrite-wat-identifiers-to-port "(global $bad{name} i32)" out)
  (check-equal? (get-output-string out)
                "(global $\"bad{name}\" i32)")
  (define out/stream (open-output-string))
  (rewrite-wat-identifiers-from-port
   (open-input-string "(global $bad{name} i32)")
   out/stream)
  (check-equal? (get-output-string out/stream)
                "(global $\"bad{name}\" i32)")
  (define out/compact (open-output-string))
  (write-compact-wat
   `(module (func ,(string->symbol "$bad{name}") (result i32) (i32.const 1)))
   out/compact)
  (check-equal? (get-output-string out/compact)
                "(module (func $\"bad{name}\" (result i32) (i32.const 1)))")
  (define out/compact-string (open-output-string))
  (write-compact-wat
   '(data $ok "keep $bad[name]")
   out/compact-string)
  (check-equal? (get-output-string out/compact-string)
                "(data $ok \"keep $bad[name]\")")
  (define out/compact-control-string (open-output-string))
  (write-compact-wat
   (list 'data '$ok (string #\nul #\tab #\" #\\))
   out/compact-control-string)
  (check-equal? (get-output-string out/compact-control-string)
                "(data $ok \"\\00\\09\\\"\\\\\")"))
