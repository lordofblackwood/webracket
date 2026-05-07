#lang racket/base

(provide webify-faslable-correlated-available?
         webify-faslable-correlated-linklet?
         webify-faslable-correlated-linklet->datum
         webify-strip-faslable-correlated)

(require racket/match)

;; maybe-dynamic-require : module-path? symbol? -> any/c
;;   Resolve an optional Racket-internal binding without forcing older hosts to have it.
(define (maybe-dynamic-require module name)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (dynamic-require module name)))

(define faslable-correlated-linklet?
  (maybe-dynamic-require 'compiler/faslable-correlated
                         'faslable-correlated-linklet?))
(define faslable-correlated-linklet-expr
  (maybe-dynamic-require 'compiler/faslable-correlated
                         'faslable-correlated-linklet-expr))
(define faslable-correlated?
  (maybe-dynamic-require 'compiler/faslable-correlated
                         'faslable-correlated?))
(define faslable-correlated-e
  (maybe-dynamic-require 'compiler/faslable-correlated
                         'faslable-correlated-e))

;; webify-faslable-correlated-available? : -> boolean?
;;   Report whether this Racket exposes the internal faslable-correlated API.
(define (webify-faslable-correlated-available?)
  (and faslable-correlated-linklet?
       faslable-correlated-linklet-expr
       faslable-correlated?
       faslable-correlated-e
       #t))

;; webify-faslable-correlated-linklet? : any/c -> boolean?
;;   Recognize Racket's machine-independent faslable linklet wrapper.
(define (webify-faslable-correlated-linklet? v)
  (and faslable-correlated-linklet?
       (faslable-correlated-linklet? v)))

;; webify-strip-faslable-correlated : any/c -> any/c
;;   Strip source-location wrappers from a faslable-correlated datum tree.
(define (webify-strip-faslable-correlated v)
  (cond
    [(and faslable-correlated? (faslable-correlated? v))
     (webify-strip-faslable-correlated (faslable-correlated-e v))]
    [(pair? v)
     (cons (webify-strip-faslable-correlated (car v))
           (webify-strip-faslable-correlated (cdr v)))]
    [(vector? v)
     (list->vector
      (for/list ([item (in-vector v)])
        (webify-strip-faslable-correlated item)))]
    [else v]))

;; webify-faslable-correlated-linklet->datum : any/c -> (or/c any/c #f)
;;   Extract a plain linklet datum from a faslable-correlated linklet wrapper.
(define (webify-faslable-correlated-linklet->datum v)
  (and (webify-faslable-correlated-linklet? v)
       (webify-strip-faslable-correlated
        (faslable-correlated-linklet-expr v))))
