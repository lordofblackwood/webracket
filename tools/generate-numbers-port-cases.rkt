#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/pretty
         racket/set
         racket/string
         syntax/modread
         "../test/numbers/model.rkt"
         "../test/numbers/sources.rkt")

(define repo-root
  (simplify-path
   (build-path (find-system-path 'run-file) 'up 'up)))

(define generated-path
  (build-path repo-root "test" "numbers" "generated" "simple-cases.rkt"))

;; source-path : number-port-source? -> path?
;;   Resolve an upstream source path relative to the WebRacket checkout.
(define (source-path source)
  (simplify-path (build-path repo-root (number-port-source-path source))))

;; head-symbol : syntax? -> (or/c symbol? #f)
;;   Return the datum head symbol for a list syntax object.
(define (head-symbol stx)
  (define xs (syntax->list stx))
  (and xs
       (pair? xs)
       (let ([v (syntax-e (car xs))])
         (and (symbol? v) v))))

;; syntax-line/default : syntax? -> exact-nonnegative-integer?
;;   Return a source line for generated provenance.
(define (syntax-line/default stx)
  (or (syntax-line stx) 0))

;; quote-form? : any/c -> boolean?
;;   Recognize literal quote forms in source datums.
(define (quote-form? v)
  (and (pair? v)
       (eq? (car v) 'quote)
       (pair? (cdr v))
       (null? (cddr v))))

;; application-test-expr : syntax? exact-nonnegative-integer? -> any/c
;;   Port a Racket `(test expected fun arg ...)` actual expression.
(define (application-test-expr form offset)
  (define xs (syntax->list form))
  (define fun (list-ref xs (+ offset 1)))
  (define args (drop xs (+ offset 2)))
  (define fun-datum (syntax->datum fun))
  (cond
    [(null? args)
     fun-datum]
    [(quote-form? fun-datum)
     (syntax->datum (car args))]
    [else
     (cons fun-datum (map syntax->datum args))]))

;; port-form : symbol? syntax? -> (values (or/c any/c #f) symbol? string?)
;;   Convert an upstream test-like form to a standalone expression when possible.
(define (port-form kind form)
  (define xs (syntax->list form))
  (case kind
    [(test)
     (cond
       [(>= (length xs) 3)
        (values (application-test-expr form 1) 'test "ported test actual expression")]
       [else
        (values #f 'malformed "test form has too few elements")])]
    [(test/compare)
     (cond
       [(>= (length xs) 4)
        (values (application-test-expr form 2)
                'test/compare
                "ported test/compare actual expression; compare predicate is not part of the oracle case")]
       [else
        (values #f 'malformed "test/compare form has too few elements")])]
    [(err/rt-test err/rt-test/once)
     (cond
       [(>= (length xs) 2)
        (values (syntax->datum (cadr xs))
                kind
                "ported error expression; oracle compares normalized exception records")]
       [else
        (values #f 'malformed "error test form has too few elements")])]
    [(test-values)
     (cond
       [(= (length xs) 3)
        (values `(call-with-values ,(syntax->datum (caddr xs)) list)
                'test-values
                "ported values expression")]
       [else
        (values #f 'macro-dependent "test-values form has an unsupported shape")])]
    [(arity-test test-sequence)
     (values #f 'macro-dependent "macro test needs a hand port")]
    [else
     (values #f 'unsupported "unsupported upstream test form")]))

;; syntax-subforms : syntax? -> (listof syntax?)
;;   Return child forms, avoiding quoted data.
(define (syntax-subforms stx)
  (define head (head-symbol stx))
  (cond
    [(memq head '(quote quasiquote quote-syntax))
     '()]
    [else
     (or (syntax->list stx) '())]))

(define test-like-heads
  '(test test/compare err/rt-test err/rt-test/once test-values arity-test test-sequence))

(define syntax-keywords
  '(and begin begin0 case cond define define-values else if lambda lambda*
        let let* letrec letrec-values let-values or parameterize quote
        quasiquote quote-syntax set! unless when with-handlers))

(define portable-global-symbols
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (for ([module '(racket/base
                      racket/fasl
                      racket/fixnum
                      racket/flonum
                      racket/list
                      racket/math
                      racket/random)])
        (namespace-require module))
      (list->seteq (namespace-mapped-symbols)))))

;; formals->symbols : any/c -> (listof symbol?)
;;   Extract simple symbols from a lambda formal datum.
(define (formals->symbols formals)
  (cond
    [(symbol? formals) (list formals)]
    [(pair? formals)
     (append (formals->symbols (car formals))
             (formals->symbols (cdr formals)))]
    [else '()]))

;; binding-id : any/c -> (or/c symbol? #f)
;;   Return a simple let binding id.
(define (binding-id binding)
  (match binding
    [(list (? symbol? id) _value) id]
    [_ #f]))

;; portable-expression? : any/c -> boolean?
;;   Check whether an extracted expression is standalone in a Racket base namespace.
(define (portable-expression? expr)
  (define (global? sym)
    (or (set-member? portable-global-symbols sym)
        (memq sym syntax-keywords)))
  (define (ok? datum bound)
    (cond
      [(symbol? datum)
       (or (memq datum bound) (global? datum))]
      [(pair? datum)
       (match datum
         [`(quote ,_) #t]
         [`(quote-syntax ,_) #t]
         [`(lambda ,formals ,body ...)
          (andmap (lambda (body-expr)
                    (ok? body-expr (append (formals->symbols formals) bound)))
                  body)]
         [`(case-lambda [,formalss ,bodys ...] ...)
          (for/and ([formals (in-list formalss)]
                    [body (in-list bodys)])
            (andmap (lambda (body-expr)
                      (ok? body-expr (append (formals->symbols formals) bound)))
                    body))]
         [`(let ,(? symbol? name) ,bindings ,body ...)
          (define ids (filter values (map binding-id bindings)))
          (and (andmap (lambda (binding)
                         (match binding
                           [(list _ value) (ok? value (cons name bound))]
                           [_ #f]))
                       bindings)
               (andmap (lambda (body-expr)
                         (ok? body-expr (append ids (cons name bound))))
                       body))]
         [`(let ,bindings ,body ...)
          (define ids (filter values (map binding-id bindings)))
          (and (andmap (lambda (binding)
                         (match binding
                           [(list _ value) (ok? value bound)]
                           [_ #f]))
                       bindings)
               (andmap (lambda (body-expr)
                         (ok? body-expr (append ids bound)))
                       body))]
         [`(let* ,bindings ,body ...)
          (let loop ([bindings bindings] [bound bound])
            (cond
              [(null? bindings)
               (andmap (lambda (body-expr) (ok? body-expr bound)) body)]
              [else
               (match (car bindings)
                 [(list (? symbol? id) value)
                  (and (ok? value bound)
                       (loop (cdr bindings) (cons id bound)))]
                 [_ #f])]))]
         [`(letrec ,bindings ,body ...)
          (define ids (filter values (map binding-id bindings)))
          (define new-bound (append ids bound))
          (and (andmap (lambda (binding)
                         (match binding
                           [(list _ value) (ok? value new-bound)]
                           [_ #f]))
                       bindings)
               (andmap (lambda (body-expr) (ok? body-expr new-bound)) body))]
         [`(define ,_ ,_) #f]
         [`(define-values ,_ ,_) #f]
         [`(quasiquote ,_) #f]
         [else
          (andmap (lambda (part) (ok? part bound)) datum)])]
      [(vector? datum)
       (for/and ([elem (in-vector datum)])
         (ok? elem bound))]
      [else #t]))
  (ok? expr '()))

;; numstrs-cases+skips :
;;   number-port-source? path? -> (values (listof number-port-case?) (listof number-port-skip?))
;;   Port the `numstrs.rktl` number table to string->number oracle cases.
(define (numstrs-cases+skips source path)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (values
                      '()
                      (list
                       (number-port-skip
                        (number-port-source-id source)
                        0
                        'source-eval
                        (exn-message exn)
                        (path->string path)))))])
    (define ns (make-base-namespace))
    (parameterize ([current-namespace ns]
                   [current-load-relative-directory (path-only path)]
                   [use-compiled-file-paths '()])
      (load path))
    (define table
      (parameterize ([current-namespace ns])
        (namespace-variable-value 'number-table)))
    (define cases
      (for/list ([row (in-list table)]
                 [index (in-naturals 1)])
        (match row
          [(list _expected (? string? text))
           (number-port-case
            (make-case-id (number-port-source-id source) 'number-table 0 index)
            (number-port-source-id source)
            0
            'number-table
            (string->symbol
             (format "upstream-~a" (number-port-source-id source)))
            `(string->number ,text)
            'ignore-fixnum-width
            #f
            "ported numstrs number-table entry as string->number")]
          [other
           (number-port-case
            (make-case-id (number-port-source-id source) 'number-table 0 index)
            (number-port-source-id source)
            0
            'number-table
            (string->symbol
             (format "upstream-~a" (number-port-source-id source)))
            `(quote ,other)
            'ignore-fixnum-width
            #f
            "unexpected numstrs row shape is recorded as data")])))
    (values cases '())))

;; source-forms : path? -> (listof syntax?)
;;   Read all syntax forms from an upstream source.
(define (source-forms path)
  (parameterize ([current-load-relative-directory (path-only path)]
                 [use-compiled-file-paths '()])
    (call-with-input-file path
      (lambda (in)
        (port-count-lines! in)
        (let loop ([forms '()])
          (define stx (with-module-reading-parameterization
                        (lambda () (read-syntax path in))))
          (if (eof-object? stx)
              (reverse forms)
              (loop (cons stx forms))))))))

;; source-test-forms : path? -> (listof syntax?)
;;   Extract all test-like forms from a source, including nested tests.
(define (source-test-forms path)
  (define out '())
  (define (walk stx)
    (define head (head-symbol stx))
    (when (memq head test-like-heads)
      (set! out (cons stx out)))
    (for ([child (in-list (syntax-subforms stx))])
      (walk child)))
  (for ([form (in-list (source-forms path))])
    (walk form))
  (reverse out))

;; source-id-prefix : symbol? -> string?
;;   Render an id prefix for generated case names.
(define (source-id-prefix source-id)
  (regexp-replace* #rx"[^a-zA-Z0-9]+"
                   (symbol->string source-id)
                   "-"))

;; make-case-id : symbol? symbol? exact-nonnegative-integer? exact-nonnegative-integer? -> symbol?
;;   Build a stable generated case id.
(define (make-case-id source-id kind line index)
  (string->symbol
   (format "~a:~a:~a:~a"
           (source-id-prefix source-id)
           kind
           line
           index)))

;; generated-cases+skips-for-source :
;;   number-port-source? -> (values (listof number-port-case?) (listof number-port-skip?))
;;   Generate executable cases and explicit skips for one upstream source.
(define (generated-cases+skips-for-source source)
  (define path (source-path source))
  (cond
    [(not (file-exists? path))
     (values
      '()
      (list
        (number-port-skip
         (number-port-source-id source)
         0
         'source-missing
         "upstream source file is not present"
         (path->string path))))]
    [(eq? (number-port-source-id source) 'racket-numstrs)
     (numstrs-cases+skips source path)]
    [(eq? (number-port-source-id source) 'racket-extflonum)
     (values
      '()
      (list
       (number-port-skip
        (number-port-source-id source)
        0
        'source-unsupported
        "WebRacket has no extflonum representation; source needs a dedicated unsupported-feature port"
        (path->string path))))]
    [else
     (with-handlers ([exn:fail?
                      (lambda (exn)
                        (values
                         '()
                         (list
                          (number-port-skip
                           (number-port-source-id source)
                           0
                           'source-read
                           (exn-message exn)
                           (path->string path)))))])
       (define cases '())
       (define skips '())
       (for ([form (in-list (source-test-forms path))]
             [index (in-naturals 1)])
         (define kind (head-symbol form))
         (define line (syntax-line/default form))
         (define-values (expr port-kind note) (port-form kind form))
       (cond
         [(and expr (portable-expression? expr))
          (set! cases
                (cons
                 (number-port-case
                    (make-case-id (number-port-source-id source) kind line index)
                    (number-port-source-id source)
                    line
                    port-kind
                    (string->symbol
                     (format "upstream-~a" (number-port-source-id source)))
                    expr
                    'ignore-fixnum-width
                    #f
                    note)
                   cases))]
         [expr
          (set! skips
                (cons
                 (number-port-skip
                  (number-port-source-id source)
                  line
                  'source-context
                  "ported expression depends on source-local bindings or unsupported globals"
                  expr)
                 skips))]
         [else
          (set! skips
                  (cons
                   (number-port-skip
                    (number-port-source-id source)
                    line
                    port-kind
                    note
                    (syntax->datum form))
                   skips))]))
       (if (and (null? cases) (null? skips))
           (values
            '()
            (list
             (number-port-skip
              (number-port-source-id source)
              0
              'source-no-loadtest-forms
              "source has no loadtest-style test forms; it needs a hand stress port"
              (path->string path))))
           (values (reverse cases) (reverse skips))))]))

;; generated-cases+skips : -> (values (listof number-port-case?) (listof number-port-skip?))
;;   Generate ports for all configured sources.
(define (generated-cases+skips)
  (define all-cases '())
  (define all-skips '())
  (for ([source (in-list number-port-sources)])
    (define-values (cases skips) (generated-cases+skips-for-source source))
    (set! all-cases (append all-cases cases))
    (set! all-skips (append all-skips skips)))
  (values all-cases all-skips))

(define (quote-expr v)
  `(quote ,v))

;; case->source-expression : number-port-case? -> any/c
;;   Convert a generated port case to a constructor expression.
(define (case->source-expression c)
  `(number-port-case
    ',(number-port-case-id c)
    ',(number-port-case-source c)
    ,(number-port-case-line c)
    ',(number-port-case-kind c)
    ',(number-port-case-group c)
    ,(quote-expr (number-port-case-expr c))
    ',(number-port-case-comparison c)
    ,(number-port-case-gate? c)
    ,(number-port-case-note c)))

;; skip->source-expression : number-port-skip? -> any/c
;;   Convert a generated skip to a constructor expression.
(define (skip->source-expression s)
  `(number-port-skip
    ',(number-port-skip-source s)
    ,(number-port-skip-line s)
    ',(number-port-skip-kind s)
    ,(number-port-skip-reason s)
    ,(quote-expr (number-port-skip-datum s))))

;; write-definition-list! : output-port? symbol? (listof any/c) -> void?
;;   Write a constructor-expression list definition.
(define (write-definition-list! out name exprs)
  (fprintf out "(define ~a\n  (list" name)
  (for ([expr (in-list exprs)])
    (newline out)
    (display "   " out)
    (pretty-write expr out))
  (display "))\n" out))

;; write-generated-file! : (listof number-port-case?) (listof number-port-skip?) -> void?
;;   Write the checked-in generated case file.
(define (write-generated-file! cases skips)
  (make-directory* (path-only generated-path))
  (call-with-output-file generated-path
    (lambda (out)
      (display "#lang racket/base\n\n" out)
      (display "(require \"../model.rkt\")\n\n" out)
      (display "(provide generated-number-port-cases\n" out)
      (display "         generated-number-port-skips)\n\n" out)
      (display ";; This file is generated by tools/generate-numbers-port-cases.rkt.\n\n" out)
      (write-definition-list! out
                              'generated-number-port-cases
                              (map case->source-expression cases))
      (newline out)
      (write-definition-list! out
                              'generated-number-port-skips
                              (map skip->source-expression skips))
      (newline out))
    #:exists 'truncate/replace))

;; main : -> void?
;;   Regenerate source-backed number port cases.
(define (main)
  (define-values (cases skips) (generated-cases+skips))
  (write-generated-file! cases skips)
  (printf "wrote ~a cases and ~a skips to ~a\n"
          (length cases)
          (length skips)
          (find-relative-path repo-root generated-path)))

(module+ main
  (main))
