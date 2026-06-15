#lang racket/base

(require (only-in "../primitives.rkt"
                  [sort/expanded-keywords primitive-sort/expanded-keywords]))

(provide sort)

;; Lightweight public `sort` wrapper for Goal 1 module routing.
;;
;; Keep this provider narrow so imports from `racket/list` and
;; `racket/private/list` can resolve plain `sort` without pulling the broader
;; `webracket/list` implementation graph into bridge extraction.

;; extract-sort-keywords : symbol? (listof keyword?) list? -> values
;;   Decode WebRacket's supported public sort keywords.
(define (extract-sort-keywords who kws kw-args)
  (let loop ([kws kws] [kw-args kw-args] [key #f] [cache-keys? #f])
    (cond
      [(null? kws) (values key cache-keys?)]
      [(eq? (car kws) '#:key)
       (loop (cdr kws) (cdr kw-args) (car kw-args) cache-keys?)]
      [(eq? (car kws) '#:cache-keys?)
       (loop (cdr kws) (cdr kw-args) key (car kw-args))]
      [else
       (raise-arguments-error who
                              "unsupported keyword"
                              "keyword" (car kws))])))

;; sort : list? procedure? #:key procedure? #:cache-keys? any/c -> list?
;;   Expose public `sort` semantics through the fixed-shape primitive helper.
(define sort
  (make-keyword-procedure
   (lambda (kws kw-args xs less-than?)
     (define-values (key cache-keys?) (extract-sort-keywords 'sort kws kw-args))
     (primitive-sort/expanded-keywords xs less-than? #f key #f cache-keys?))
   (lambda (xs less-than?)
     (primitive-sort/expanded-keywords xs less-than? #f #f #f #f))))
