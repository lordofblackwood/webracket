#lang webracket/base

(require racket/include
         racket/list
         racket/vector
         webracket/unsafe/dom
         (only-in webracket/primitives
                  external?
                  procedure->external)
         (for-syntax racket/base))

;; Module wrapper for the legacy RQuery library. The included files still use
;; old `include-lib`/`require-lib` directives, so this module supplies the
;; dependencies explicitly and makes those legacy directives no-ops here.

(provide (except-out (all-defined-out) include-lib require-lib))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(define-syntax (include-lib stx)
  (syntax-case stx ()
    [(_) #'(void)]
    [(_ _lib-id) #'(void)]))

(define-syntax (require-lib stx)
  (syntax-case stx ()
    [(_) #'(void)]
    [(_ _lib-id) #'(void)]))

(begin-for-syntax
  (define (chain-dotted-identifier? stx)
    (and (identifier? stx)
         (let ([name (syntax-e stx)])
           (and (symbol? name)
                (let ([s (symbol->string name)])
                  (and (positive? (string-length s))
                       (char=? (string-ref s 0) #\.)))))))

  (define (chain-split-clauses rest who whole-stx)
    (let loop ([xs rest] [current #f] [clauses '()])
      (cond
        [(null? xs)
         (reverse (if current
                      (cons (reverse current) clauses)
                      clauses))]
        [else
         (define hd (car xs))
         (cond
           [(chain-dotted-identifier? hd)
            (loop (cdr xs)
                  (list hd)
                  (if current
                      (cons (reverse current) clauses)
                      clauses))]
           [current
            (loop (cdr xs) (cons hd current) clauses)]
           [else
            (raise-syntax-error who
                                "expected a dotted method name after the seed expression"
                                whole-stx
                                hd)])])))

  (define (chain-build seed clauses whole-stx)
    (let loop ([current seed] [xs clauses])
      (cond
        [(null? xs) current]
        [else
         (define clause (car xs))
         (define method (car clause))
         (define args (cdr clause))
         (define call-stx
           (quasisyntax/loc whole-stx
             (#,method #,current #,@args)))
         (loop call-stx (cdr xs))]))))

(define-syntax ($chain stx)
  (syntax-case stx ()
    [(_ seed rest ...)
     (let* ([rest-list (syntax->list #'(rest ...))]
            [clauses   (chain-split-clauses rest-list '$chain stx)])
       (chain-build #'seed clauses stx))]
    [_ (raise-syntax-error '$chain
                           "expected `($chain seed .method arg ... ...)`"
                           stx)]))

(include/reader "../../pkgs/webracket-lib/compiler/legacy-stdlib/shared-library-structs.rkt"
                read-syntax/skip-first-line)
(include/reader "../../lib/libs/document.rkt" read-syntax/skip-first-line)
(include/reader "../../lib/libs/element.rkt"  read-syntax/skip-first-line)
(include/reader "../../lib/libs/event.rkt"    read-syntax/skip-first-line)
(include/reader "../../lib/libs/rquery.rkt"   read-syntax/skip-first-line)
