#lang racket/base

(provide -> ->* </c <=/c =/c >/c >=/c and/c any/c between/c box/c
         case-> chaperone-contract? coerce-contract cons/c contract
         contract-first-order-passes? contract? contract-out define/contract
         flat-contract? flat-named-contract hash/c immutable-vector/c
         impersonator-contract? integer-in list/c listof none/c not/c one-of/c
         or/c parameter/c parametric->/c predicate/c procedure-arity-includes/c
         promise/c provide/contract real-in recursive-contract struct/c symbols
         vector/c vectorof with-contract ->i)

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

;; =/c : real? -> contract?
;;   Build an inert equality contract descriptor.
(define (=/c z)
  (make-erased-contract '=/c (list z)))

;; </c : real? -> contract?
;;   Build an inert less-than contract descriptor.
(define (</c n)
  (make-erased-contract '</c (list n)))

;; >/c : real? -> contract?
;;   Build an inert greater-than contract descriptor.
(define (>/c n)
  (make-erased-contract '>/c (list n)))

;; <=/c : real? -> contract?
;;   Build an inert less-than-or-equal contract descriptor.
(define (<=/c n)
  (make-erased-contract '<=/c (list n)))

;; >=/c : real? -> contract?
;;   Build an inert greater-than-or-equal contract descriptor.
(define (>=/c n)
  (make-erased-contract '>=/c (list n)))

;; between/c : real? real? -> contract?
;;   Build an inert inclusive range contract descriptor.
(define (between/c n m)
  (make-erased-contract 'between/c (list n m)))

;; real-in : real? real? -> contract?
;;   Build an inert real range contract descriptor.
(define (real-in n m)
  (make-erased-contract 'real-in (list n m)))

;; integer-in : (or/c exact-integer? #f) (or/c exact-integer? #f) -> contract?
;;   Build an inert integer range contract descriptor.
(define (integer-in j k)
  (make-erased-contract 'integer-in (list j k)))

;; one-of/c : any/c ... -> contract?
;;   Build an inert finite-choice contract descriptor.
(define (one-of/c . values)
  (make-erased-contract 'one-of/c values))

;; symbols : symbol? ... -> contract?
;;   Build an inert symbol-choice contract descriptor.
(define (symbols . syms)
  (make-erased-contract 'symbols syms))

;; flat-named-contract : any/c procedure? any/c ... -> contract?
;;   Build an inert named flat contract descriptor.
(define (flat-named-contract name predicate . rest)
  (make-erased-contract 'flat-named-contract (list* name predicate rest)))

;; listof : contract? -> contract?
;;   Build an inert list contract descriptor.
(define (listof contract)
  (make-erased-contract 'listof (list contract)))

;; list/c : contract? ... -> contract?
;;   Build an inert fixed-length list contract descriptor.
(define (list/c . contracts)
  (make-erased-contract 'list/c contracts))

;; vectorof : contract? -> contract?
;;   Build an inert vector contract descriptor.
(define (vectorof contract)
  (make-erased-contract 'vectorof (list contract)))

;; vector/c : contract? ... -> contract?
;;   Build an inert fixed-length vector contract descriptor.
(define (vector/c . contracts)
  (make-erased-contract 'vector/c contracts))

;; immutable-vector/c : contract? ... -> contract?
;;   Build an inert immutable vector contract descriptor.
(define (immutable-vector/c . contracts)
  (make-erased-contract 'immutable-vector/c contracts))

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

;; parameter/c : contract? contract? ... -> contract?
;;   Build an inert parameter contract descriptor.
(define (parameter/c in-contract . contracts)
  (make-erased-contract 'parameter/c (cons in-contract contracts)))

;; promise/c : contract? -> contract?
;;   Build an inert promise contract descriptor.
(define (promise/c contract)
  (make-erased-contract 'promise/c (list contract)))

;; procedure-arity-includes/c : exact-nonnegative-integer? -> contract?
;;   Build an inert procedure-arity contract descriptor.
(define (procedure-arity-includes/c arity)
  (make-erased-contract 'procedure-arity-includes/c (list arity)))

;; struct/c : syntax -> syntax
;;   Erase struct field contracts to an inert descriptor.
(define-syntax-rule (struct/c struct-id contract-expr ...)
  (and/c contract-expr ...))

;; recursive-contract : syntax -> syntax
;;   Erase recursive-contract options and keep the body contract expression.
(define-syntax-rule (recursive-contract contract-expr option ...)
  contract-expr)

;; ->i : syntax -> syntax
;;   Erase dependent function contracts to an inert function contract.
(define-syntax-rule (->i clause ...)
  (->))

;; parametric->/c : syntax -> syntax
;;   Erase parametric contract variables to an inert function contract.
(define-syntax-rule (parametric->/c vars contract-expr)
  (->))

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
