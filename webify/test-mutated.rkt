#lang racket/base

(require "../pkgs/webracket-lib/compiler/webify/gensym.rkt"
         "../pkgs/webracket-lib/compiler/webify/mutated.rkt")

;; hash->sorted-list : hash? -> list?
;;   Normalize mutation tables for deterministic comparison.
(define (hash->sorted-list h)
  (sort (hash->list h) symbol<? #:key car))

;; check-equal? : any/c any/c symbol? -> void?
;;   Lightweight check to keep this regression independent of RackUnit.
(define (check-equal? actual expected who)
  (unless (equal? actual expected)
    (error who
           "check failed\n  actual: ~s\n  expected: ~s"
           actual
           expected)))

;; analyze-mutated : any/c -> hash?
;;   Run the Webify mutation pass with small test defaults.
(define (analyze-mutated forms [exports (hasheq 'f #t 'g #t)])
  (with-deterministic-gensym
    (mutated-in-body forms
                     exports
                     (make-hasheq)
                     (hasheq)
                     (hasheq)
                     (hasheq)
                     (make-hasheq)
                     #f
                     #f
                     #t)))

(check-equal?
 (hash->sorted-list
  (analyze-mutated
   '((define-values (f g)
       (values (lambda () g)
               (lambda () 1))))))
 '()
 'matching-values-precision)

(check-equal?
 (hash->sorted-list
  (analyze-mutated
   '((define-values (f g)
       (values (lambda () g))))))
 '((g . too-early))
 'mismatched-values-conservative)

(check-equal?
 (hash->sorted-list
  (analyze-mutated
   '((define-values (x)
       (begin0
         (lambda () x)
         (x))))
   (hasheq)))
 '((x . too-early))
 'begin0-rest-before-result-unexported)

(check-equal?
 (hash->sorted-list
  (analyze-mutated
   '((define-values (f)
       (lambda () x))
     (define-values (x)
       (begin0
         f
         (f))))
   (hasheq 'x #t)))
 '((x . too-early))
 'begin0-rest-before-result-exported)
