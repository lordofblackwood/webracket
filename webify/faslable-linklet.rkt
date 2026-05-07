#lang racket/base

(provide webify-faslable-correlated-available?
         webify-faslable-correlated-linklet?
         webify-faslable-correlated-linklet->datum
         webify-compiled-expression->zo
         webify-zo-linklet-bundle?
         webify-zo-linklet-bundle->hash
         webify-zo-linklet-directory?
         webify-zo-linklet-directory->hash
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
(define zo-parse
  (maybe-dynamic-require 'compiler/zo-parse 'zo-parse))
(define linkl-bundle?
  (maybe-dynamic-require 'compiler/zo-parse 'linkl-bundle?))
(define linkl-bundle-table
  (maybe-dynamic-require 'compiler/zo-parse 'linkl-bundle-table))
(define linkl-directory?
  (maybe-dynamic-require 'compiler/zo-parse 'linkl-directory?))
(define linkl-directory-table
  (maybe-dynamic-require 'compiler/zo-parse 'linkl-directory-table))

;; webify-faslable-correlated-available? : -> boolean?
;;   Report whether this Racket exposes the internal faslable-correlated API.
(define (webify-faslable-correlated-available?)
  (and faslable-correlated-linklet?
       faslable-correlated-linklet-expr
       faslable-correlated?
       faslable-correlated-e
       zo-parse
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

;; webify-compiled-expression->zo : compiled-expression? -> (or/c any/c #f)
;;   Parse a written compiled expression with Racket's internal zo parser.
(define (webify-compiled-expression->zo compiled)
  (and zo-parse
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (define out (open-output-bytes))
         (write compiled out)
         (zo-parse (open-input-bytes (get-output-bytes out))))))

;; webify-zo-linklet-bundle? : any/c -> boolean?
;;   Recognize compiler/zo-parse's parsed linklet-bundle struct.
(define (webify-zo-linklet-bundle? v)
  (and linkl-bundle? (linkl-bundle? v)))

;; webify-zo-linklet-bundle->hash : linkl-bundle? -> hash?
;;   Extract the parsed bundle table.
(define (webify-zo-linklet-bundle->hash v)
  (and (webify-zo-linklet-bundle? v)
       (linkl-bundle-table v)))

;; webify-zo-linklet-directory? : any/c -> boolean?
;;   Recognize compiler/zo-parse's parsed linklet-directory struct.
(define (webify-zo-linklet-directory? v)
  (and linkl-directory? (linkl-directory? v)))

;; webify-zo-linklet-directory->hash : linkl-directory? -> hash?
;;   Extract the parsed directory table.
(define (webify-zo-linklet-directory->hash v)
  (and (webify-zo-linklet-directory? v)
       (linkl-directory-table v)))
