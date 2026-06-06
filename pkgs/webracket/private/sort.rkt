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
  (define original-kw-args kw-args)
  (let loop ([kws kws] [kw-args kw-args] [key #f] [cache-keys? #f])
    (cond
      [(null? kws)
       (cond
         [(and (not key)
               (not cache-keys?)
               (pair? original-kw-args)
               (null? (cdr original-kw-args)))
          (define value (car original-kw-args))
          (values value cache-keys?)]
         [else (values key cache-keys?)])]
      [(eq? (car kws) '#:key)
       (loop (cdr kws) (cdr kw-args) (car kw-args) cache-keys?)]
      [(eq? (car kws) '#:cache-keys?)
       (loop (cdr kws) (cdr kw-args) key (car kw-args))]
      [else
       (raise-arguments-error who
                              "unsupported keyword"
                              "keyword" (car kws))])))

;; sort-expanded-call : any/c any/c any/c any/c -> list?
;;   Support both internal expanded sort orders seen after module lowering.
(define (sort-expanded-call a b c d)
  (cond
    [(or (null? a) (pair? a))
     (primitive-sort/expanded-keywords a b #f d #f c)]
    [else
     (primitive-sort/expanded-keywords c d #f b #f a)]))

;; sort : list? procedure? -> list?
;;   Keyword-aware public wrapper over WebRacket's primitive list sort.
(define sort
  (make-keyword-procedure
   (lambda (kws kw-args a b . rest)
     (define-values (key cache-keys?) (extract-sort-keywords 'sort kws kw-args))
     (case (length rest)
       [(0)
        (primitive-sort/expanded-keywords a b #f key #f cache-keys?)]
       [(2)
       ;; Expanded module code can pass sort's internal positional keyword
       ;; shape as (cache-keys? key xs less-than?) before the fixed primitive
       ;; helper reorders the values.
        (sort-expanded-call a b (car rest) (cadr rest))]
       [else
        (raise-arguments-error 'sort
                               "wrong number of arguments"
                               "arguments" (cons a (cons b rest)))]))
   (case-lambda
     [(xs less-than?)
      (primitive-sort/expanded-keywords xs less-than? #f #f #f #f)]
     [(a b c d)
      (sort-expanded-call a b c d)])))

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
