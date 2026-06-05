#lang racket/base

(require (only-in "../primitives.rkt"
                  [sort/expanded-keywords primitive-sort/expanded-keywords]
                  [vector-sort/expanded-keywords primitive-vector-sort/expanded-keywords]
                  [vector-sort!/expanded-keywords primitive-vector-sort!/expanded-keywords])
         (only-in "kw.rkt"
                  make-keyword-procedure))

(provide sort
         vector-sort
         vector-sort!)

;; extract-sort-keywords : symbol? (listof keyword?) list? -> values
;;   Decode the keyword options supported by WebRacket's primitive sort bridge.
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

;; sort : list? procedure? -> list?
;;   Keyword-aware public wrapper over WebRacket's primitive list sort.
(define sort
  (make-keyword-procedure
   (lambda (kws kw-args xs less-than?)
     (define-values (key cache-keys?) (extract-sort-keywords 'sort kws kw-args))
     (primitive-sort/expanded-keywords xs less-than? #f key #f cache-keys?))))

;; vector-sort/range+keywords : vector? procedure? list? procedure? any/c -> vector?
;;   Sort a range with keyword options when the fixed-shape primitive is too narrow.
(define (vector-sort/range+keywords vec less-than? maybe-range key cache-keys?)
  (case (length maybe-range)
    [(0) (primitive-vector-sort/expanded-keywords vec less-than? #f key #f cache-keys?)]
    [else
     (raise-arguments-error 'vector-sort
                            "range arguments are not supported by the WebRacket keyword sort bridge yet"
                            "range arguments" maybe-range)]))

;; vector-sort!/range+keywords : vector? procedure? list? procedure? any/c -> void?
;;   Sort a range in place with keyword options when the fixed-shape primitive is too narrow.
(define (vector-sort!/range+keywords vec less-than? maybe-range key cache-keys?)
  (case (length maybe-range)
    [(0) (primitive-vector-sort!/expanded-keywords vec less-than? #f key #f cache-keys?)]
    [else
     (raise-arguments-error 'vector-sort!
                            "range arguments are not supported by the WebRacket keyword sort bridge yet"
                            "range arguments" maybe-range)]))

;; vector-sort : vector? procedure? [exact-nonnegative-integer? exact-nonnegative-integer?] -> vector?
;;   Keyword-aware public wrapper over WebRacket's primitive vector sort.
(define vector-sort
  (make-keyword-procedure
   (lambda (kws kw-args vec less-than? . maybe-range)
     (define-values (key cache-keys?) (extract-sort-keywords 'vector-sort kws kw-args))
     (cond
       [(null? maybe-range)
        (primitive-vector-sort/expanded-keywords vec less-than? #f key #f cache-keys?)]
       [else
        (vector-sort/range+keywords vec less-than? maybe-range key cache-keys?)]))))

;; vector-sort! : vector? procedure? [exact-nonnegative-integer? exact-nonnegative-integer?] -> void?
;;   Keyword-aware public wrapper over WebRacket's primitive in-place vector sort.
(define vector-sort!
  (make-keyword-procedure
   (lambda (kws kw-args vec less-than? . maybe-range)
     (define-values (key cache-keys?) (extract-sort-keywords 'vector-sort! kws kw-args))
     (cond
       [(null? maybe-range)
        (primitive-vector-sort!/expanded-keywords vec less-than? #f key #f cache-keys?)]
       [else
        (vector-sort!/range+keywords vec less-than? maybe-range key cache-keys?)]))))
