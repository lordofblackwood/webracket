#lang racket/base

(provide webify-correlated-linklet?
         webify-correlated-linklet->datum
         webify-correlated-linklet->datum/catch
         webify-strip-correlated-linklet-datum)

(require "wrap.rkt")

;; webify-correlated-linklet-vector : any/c -> (or/c vector? #f)
;;   Return an inspectable correlated-linklet struct vector, if available.
(define (webify-correlated-linklet-vector v)
  (and (eq? (object-name v) 'correlated-linklet)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (define vec (struct->vector v '...))
         (and (= (vector-length vec) 4)
              (eq? (vector-ref vec 0) 'struct:correlated-linklet)
              vec))))

;; webify-correlated-linklet? : any/c -> boolean?
;;   Recognize an inspectable expander correlated-linklet value.
(define (webify-correlated-linklet? v)
  (and (webify-correlated-linklet-vector v) #t))

;; webify-strip-correlated-linklet-datum : any/c -> any/c
;;   Remove correlated wrappers from a generated linklet expression tree.
(define (webify-strip-correlated-linklet-datum v)
  (let ([v (unwrap v)])
    (cond
      [(pair? v)
       (cons (webify-strip-correlated-linklet-datum (car v))
             (webify-strip-correlated-linklet-datum (cdr v)))]
      [(vector? v)
       (list->vector
        (for/list ([item (in-vector v)])
          (webify-strip-correlated-linklet-datum item)))]
      [else v])))

;; webify-correlated-linklet->datum : any/c -> any/c
;;   Extract the generated linklet expression from an inspectable correlated-linklet.
(define (webify-correlated-linklet->datum v)
  (define vec (webify-correlated-linklet-vector v))
  (unless vec
    (raise-argument-error 'webify-correlated-linklet->datum
                          "inspectable correlated-linklet?"
                          v))
  (webify-strip-correlated-linklet-datum (vector-ref vec 1)))

;; webify-correlated-linklet->datum/catch : any/c -> (or/c any/c #f)
;;   Extract a linklet datum, returning #f when the value is opaque or not a match.
(define (webify-correlated-linklet->datum/catch v)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (and (webify-correlated-linklet? v)
         (webify-correlated-linklet->datum v))))
