#lang racket/base

(require rackunit
         racket/file
         racket/list
         (only-in "../pkgs/webracket-lib/compiler/compiler.rkt"
                  compiler-primitive?)
         "../pkgs/webracket-lib/compiler/driver.rkt"
         "../pkgs/webracket-lib/compiler/private/priminfo.rkt"
         (only-in "../pkgs/webracket-lib/compiler/private/parameters.rkt"
                  current-runtime-cache-dir)
         "../pkgs/webracket-lib/compiler/runtime-wasm/core/procedures.rkt"
         "../pkgs/webracket-lib/compiler/webify/read-provider.rkt")

;; expander/read provider generation smoke
;;   Prove that the staged reader can be demodularized and lowered to
;;   provider forms without going through a full browser compile.

(define cache-root
  (make-temporary-file "wr-expander-read-provider-test~a" 'directory))

(current-provider-cache-dir cache-root)
(current-runtime-cache-dir cache-root)
(current-provider-cache-force? #f)
(current-provider-cache-verbose? #f)

(define linklet
  (webify-read-linklet #:cache-root cache-root))

(define forms
  (read-provider-forms #:public-aliases? #t))

(define wrapped-datum
  (syntax->datum
   (add-expander-read-provider #'42)))

(check-not-false linklet)
(check-true (pair? forms))
(check-true
 (for/or ([form (in-list forms)])
   (equal? form
           '(define read
              (module-variable-ref
               webify-expander-read-export-cell$webify-expander-read)))))
(check-true
 (for/or ([form (in-list forms)])
   (equal? form
           '(define string->number
              (module-variable-ref
               webify-expander-read-export-cell$webify-expander-string->number)))))
(check-equal? (car wrapped-datum) 'begin)
(check-not-false
 (member
  '(define read
     (module-variable-ref
      webify-expander-read-export-cell$webify-expander-read))
  (cdr wrapped-datum)))
(check-not-false
 (member
  '(define string->number
     (module-variable-ref
      webify-expander-read-export-cell$webify-expander-string->number))
  (cdr wrapped-datum)))
(check-equal? (last wrapped-datum) 42)

;; The staged original-Racket reader builds regexp values while parsing
;; literals. These names must remain direct compiler primitives when they appear
;; in private reader linklets instead of as provider imports.
(for ([row (in-list
            (list
             (list 'regexp 1 1)
             (list 'pregexp 1 1)
             (list 'byte-regexp 1 1)
             (list 'byte-pregexp 1 1)
             (list 'regexp? 1 1)
             (list 'pregexp? 1 1)
             (list 'byte-regexp? 1 1)
             (list 'byte-pregexp? 1 1)
             (list 'regexp-match 2 2)
             (list 'regexp-match? 2 2)
             (list 'regexp-replace '(3 4) 15)
             (list 'regexp-replace* (arity-at-least 3) 9)))])
  (define name (car row))
  (define expected-arity (cadr row))
  (define expected-shape (caddr row))
  (define description (primitive->description name))
  (define check-name (symbol->string name))
  (check-true (compiler-primitive? name) check-name)
  (check-equal? (primitive-description-arity description) expected-arity check-name)
  (check-equal? (primitive-arity->shape name expected-arity)
                expected-shape
                check-name))

(displayln "ok")
