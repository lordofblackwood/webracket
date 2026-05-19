#lang racket/base

(provide -> ->* and/c any/c box/c case-> chaperone-contract? coerce-contract
         cons/c contract contract-first-order-passes? contract? contract-out
         define/contract flat-contract? hash/c impersonator-contract? listof
         none/c not/c or/c predicate/c provide/contract vectorof with-contract)

(require racket/provide-syntax
         (for-syntax racket/base))

;; A deliberately erased contract provider for Goal 1. It preserves common
;; `racket/contract` source shapes, but it does not enforce contracts or create
;; chaperones/impersonators.

(struct erased-contract (name parts) #:transparent)

;; make-erased-contract : symbol? (listof any/c) -> contract?
;;   Build an inert contract descriptor for compatibility.
(define (make-erased-contract name parts)
  (erased-contract name parts))

(define any/c  (make-erased-contract 'any/c '()))
(define none/c (make-erased-contract 'none/c '()))
(define predicate/c (make-erased-contract 'predicate/c '()))

;; contract? : any/c -> boolean?
;;   Treat all values as contracts in this erased compatibility provider.
(define (contract? _v) #t)

;; flat-contract? : any/c -> boolean?
;;   Treat all values as flat contracts; no checking is performed.
(define (flat-contract? _v) #t)

;; chaperone-contract? : any/c -> boolean?
;;   Treat all values as chaperone contracts without creating wrappers.
(define (chaperone-contract? _v) #t)

;; impersonator-contract? : any/c -> boolean?
;;   Treat all values as impersonator contracts without creating wrappers.
(define (impersonator-contract? _v) #t)

;; coerce-contract : symbol? any/c -> contract?
;;   Return v unchanged; the erased provider accepts ordinary values.
(define (coerce-contract _who v) v)

;; contract-first-order-passes? : contract? any/c -> boolean?
;;   Always report success because this provider erases enforcement.
(define (contract-first-order-passes? _contract _v) #t)

;; contract : contract? any/c any/c any/c any/c ... -> any/c
;;   Erase a contract boundary and return val unchanged.
(define (contract _contract val _positive-party _negative-party . _rest) val)

;; -> : contract? ... -> contract?
;;   Build an inert function-contract descriptor.
(define (-> . contracts)
  (make-erased-contract '-> contracts))

;; ->* : any/c ... -> contract?
;;   Build an inert optional/rest/keyword function-contract descriptor.
(define (->* . contracts)
  (make-erased-contract '->* contracts))

;; case-> : contract? ... -> contract?
;;   Build an inert case-function-contract descriptor.
(define (case-> . contracts)
  (make-erased-contract 'case-> contracts))

;; or/c : contract? ... -> contract?
;;   Build an inert disjunction contract descriptor.
(define (or/c . contracts)
  (make-erased-contract 'or/c contracts))

;; and/c : contract? ... -> contract?
;;   Build an inert conjunction contract descriptor.
(define (and/c . contracts)
  (make-erased-contract 'and/c contracts))

;; not/c : contract? -> contract?
;;   Build an inert negated contract descriptor.
(define (not/c contract)
  (make-erased-contract 'not/c (list contract)))

;; listof : contract? -> contract?
;;   Build an inert list contract descriptor.
(define (listof contract)
  (make-erased-contract 'listof (list contract)))

;; vectorof : contract? -> contract?
;;   Build an inert vector contract descriptor.
(define (vectorof contract)
  (make-erased-contract 'vectorof (list contract)))

;; cons/c : contract? contract? -> contract?
;;   Build an inert pair contract descriptor.
(define (cons/c car-contract cdr-contract)
  (make-erased-contract 'cons/c (list car-contract cdr-contract)))

;; box/c : contract? contract? ... -> contract?
;;   Build an inert box contract descriptor.
(define (box/c in-contract . contracts)
  (make-erased-contract 'box/c (cons in-contract contracts)))

;; hash/c : contract? contract? any/c ... -> contract?
;;   Build an inert hash contract descriptor.
(define (hash/c key-contract value-contract . options)
  (make-erased-contract 'hash/c (list* key-contract value-contract options)))

;; define/contract : syntax -> syntax
;;   Erase contract metadata from common definition forms.
(define-syntax define/contract
  (lambda (stx)
    (syntax-case stx ()
      [(_ id contract-expr init-expr)
       (identifier? #'id)
       #'(define id init-expr)]
      [(_ id contract-expr free-vars init-expr)
       (identifier? #'id)
       #'(define id init-expr)]
      [(_ (head . args) contract-expr body ...)
       #'(define (head . args) body ...)])))

;; with-contract : syntax -> syntax
;;   Erase with-contract boundaries while preserving definition contexts.
(define-syntax (with-contract stx)
  (syntax-case stx ()
    [(_ blame-id exports-or-results free-vars body ...)
     (if (eq? (syntax-local-context) 'expression)
         #'(let () body ...)
         #'(begin body ...))]))

;; contract-out : provide-transformer
;;   Erase contract annotations in simple contract-out specs.
(define-provide-syntax (contract-out stx)
  (syntax-case stx ()
    [(_ spec ...)
     (begin
       (define (spec->provide spec)
         (syntax-case spec ()
           [(id contract-expr)
            (identifier? #'id)
            #'id]
           [id
            (identifier? #'id)
            #'id]
           [_
            (raise-syntax-error 'contract-out
                                "unsupported erased contract-out spec"
                                spec)]))
       #`(combine-out #,@(map spec->provide (syntax->list #'(spec ...)))))]))

;; provide/contract : syntax -> syntax
;;   Legacy shorthand for a contract-out provide with erased annotations.
(define-syntax-rule (provide/contract spec ...)
  (provide (contract-out spec ...)))
