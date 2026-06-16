#lang racket/base

(require rackunit
         racket/file
         racket/list
         "../pkgs/webracket-lib/compiler/driver.rkt"
         "../pkgs/webracket-lib/compiler/webify/read-provider.rkt")

;; expander/read provider generation smoke
;;   Prove that the staged reader can be demodularized and lowered to
;;   provider forms without going through a full browser compile.

(define cache-root
  (make-temporary-file "wr-expander-read-provider-test~a" 'directory))

(current-provider-cache-dir cache-root)
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

(displayln "ok")
