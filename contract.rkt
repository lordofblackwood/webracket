#lang racket/base

(provide *list/c -> ->* ->d </c <=/c =/c >/c >=/c and/c any any/c
         arity-checking-wrapper arrow-contract-info
         arrow-contract-info-accepts-arglist
         arrow-contract-info-chaperone-procedure
         arrow-contract-info-check-first-order arrow-contract-info?
         bad-number-of-results base->-doms/c base->-rngs/c base->?
         between/c blame-add-car-context blame-add-cdr-context
         blame-add-context blame-add-missing-party blame-add-nth-arg-context
         blame-add-range-context blame-add-unknown-context blame-context
         blame-contract blame-fmt->-string blame-missing-party? blame-negative
         blame-original? blame-positive blame-replace-negative
         blame-replaced-negative? blame-source blame-swap blame-swapped?
         blame-update blame-value blame? box-immutable/c box/c
         build-chaperone-contract-property build-compound-type-name
         build-contract-property build-flat-contract-property case->
         channel/c chaperone-contract-property? chaperone-contract? char-in
         char-in/c coerce-chaperone-contract coerce-chaperone-contracts
         coerce-contract coerce-contract/f coerce-contracts coerce-flat-contract
         coerce-flat-contracts complex/c cons/c cons/dc continuation-mark-key/c
         contract contract-continuation-mark-key contract-custom-write-property-proc
         contract-equivalent? contract-exercise contract-first-order
         contract-first-order-passes? contract-in contract-late-neg-projection
         contract-name contract-out contract-pos/neg-doubling contract-proc
         contract-projection contract-property? contract-random-generate
         contract-random-generate-env? contract-random-generate-fail
         contract-random-generate-fail?
         contract-random-generate-get-current-environment
         contract-random-generate-stash contract-random-generate/choose
         contract-stronger? contract-struct contract-struct-exercise
         contract-struct-generate contract-struct-late-neg-projection
         contract-struct-list-contract? contract-val-first-projection contract?
         current-blame-format current-contract-region custom-write-property-proc
         define-contract-struct define-module-boundary-contract define-opt/c
         define-struct/contract define/contract define/final-prop
         define/subexpression-pos-prop define/subexpression-pos-prop/name
         dynamic->* eq-contract-val eq-contract? equal-contract-val
         equal-contract? evt/c exn:fail:contract:blame
         exn:fail:contract:blame-object exn:fail:contract:blame?
         failure-result/c false/c first-or/c flat-contract
         flat-contract-predicate flat-contract-property? flat-contract?
         flat-contract-with-explanation flat-murec-contract flat-named-contract
         flat-rec-contract get/build-late-neg-projection
         get/build-val-first-projection has-blame? has-contract? hash/c hash/dc
         if/c impersonator-contract? impersonator-prop:blame
         impersonator-prop:contracted integer-in invariant-assertion keywords-match
         list*of list-contract? list/c listof make-chaperone-contract make-contract
         make-exn:fail:contract:blame make-flat-contract make-none/c
         make-proj-contract matches-arity-exactly? mutable-treelist/c n->th
         natural-number/c new-∀/c new-∃/c non-empty-listof none/c not/c
         one-of/c opt/c or/c parameter/c parametric->/c predicate/c
         printable/c procedure-arity-includes/c promise/c prompt-tag/c
         prop:arrow-contract prop:arrow-contract-get-info prop:arrow-contract?
         prop:blame prop:chaperone-contract prop:contract prop:contracted
         prop:flat-contract prop:orc-contract prop:orc-contract-get-subcontracts
         prop:orc-contract? prop:recursive-contract
         prop:recursive-contract-unroll prop:recursive-contract? property/c
         provide/contract raise-blame-error raise-contract-error
         raise-not-cons-blame-error real-in recontract-out recursive-contract
         rename-contract skip-projection-wrapper? string-len/c struct-guard/c
         struct-type-property/c struct/c struct/contract struct/dc
         struct:arrow-contract-info struct:exn:fail:contract:blame suggest/c
         symbols syntax/c tail-marks-match? the-unsupplied-arg treelist/c
         unconstrained-domain-> unspecified-dom unsupplied-arg? value-blame
         value-contract values/drop vector-immutable/c vector-immutableof
         vector/c vectorof with-contract with-contract-continuation-mark ->i)

(require racket/provide-syntax
         (for-syntax racket/base
                     racket/list))

;; A deliberately erased contract provider for Goal 1. It preserves common
;; `racket/contract` source shapes, but it does not enforce contracts or create
;; chaperones/impersonators.

(struct erased-contract (name parts) #:transparent)
(struct arrow-contract-info (accepts-arglist chaperone-procedure check-first-order) #:transparent)
(struct exn:fail:contract:blame exn:fail:contract (object) #:transparent)

(define the-unsupplied-arg '(unsupplied-arg))
(define unspecified-dom '(unspecified-dom))
(define contract-continuation-mark-key '(contract-continuation-mark-key))
(define impersonator-prop:blame '(impersonator-prop:blame))
(define impersonator-prop:contracted '(impersonator-prop:contracted))
(define prop:arrow-contract '(prop:arrow-contract))
(define prop:blame '(prop:blame))
(define prop:chaperone-contract '(prop:chaperone-contract))
(define prop:contract '(prop:contract))
(define prop:contracted '(prop:contracted))
(define prop:flat-contract '(prop:flat-contract))
(define prop:orc-contract '(prop:orc-contract))
(define prop:recursive-contract '(prop:recursive-contract))
(define current-blame-format (make-parameter #f))

(define-syntax-rule (define-erased-contract-function id)
  (define (id . args)
    (make-erased-contract 'id args)))

(define-syntax-rule (define-erased-predicate id)
  (define (id _v) #t))

(define-syntax-rule (define-erased-syntax id)
  (define-syntax id
    (lambda (stx)
      #'(make-erased-contract 'id '()))))

(define-syntax (define-erased-syntaxes stx)
  (syntax-case stx ()
    [(_ id ...)
     #'(begin (define-erased-syntax id) ...)]))

(define-syntax-rule (define-identity-wrapper id)
  (define (id v . _args) v))

;; make-erased-contract : symbol? (listof any/c) -> contract?
;;   Build an inert contract descriptor for compatibility.
(define (make-erased-contract name parts)
  (erased-contract name parts))

(define any/c  (make-erased-contract 'any/c '()))
(define none/c (make-erased-contract 'none/c '()))
(define predicate/c (make-erased-contract 'predicate/c '()))

;; map-contract-names : (listof any/c) -> (listof any/c)
;;   Map `contract-name` without pulling in higher-order list helpers.
(define (map-contract-names contracts)
  (if (null? contracts)
      '()
      (cons (contract-name (car contracts))
            (map-contract-names (cdr contracts)))))

;; map-contract-predicates : (listof contract?) -> (listof procedure?)
;;   Map `contract-first-order` without expanding to internal map helpers.
(define (map-contract-predicates contracts)
  (if (null? contracts)
      '()
      (cons (contract-first-order (car contracts))
            (map-contract-predicates (cdr contracts)))))

;; contract-name : any/c -> any/c
;;   Approximate Racket contract names for erased descriptors and predicates.
(define (contract-name contract)
  (cond
    [(erased-contract? contract)
     (define name  (erased-contract-name contract))
     (define parts (erased-contract-parts contract))
     (cond
       [(eq? name 'flat-named-contract)
        (if (pair? parts) (car parts) name)]
       [(null? parts) name]
       [else (cons name (map-contract-names parts))])]
    [(procedure? contract)
     (or (object-name contract) 'procedure)]
    [else contract]))

;; contract-first-order : contract? -> procedure?
;;   Return a best-effort first-order predicate for erased descriptors.
(define (contract-first-order contract)
  (define (predicate-of c) (contract-first-order c))
  (define (all-predicates-pass? predicates v)
    (or (null? predicates)
        (and ((car predicates) v)
             (all-predicates-pass? (cdr predicates) v))))
  (define (any-predicate-passes? predicates v)
    (and (pair? predicates)
         (or ((car predicates) v)
             (any-predicate-passes? (cdr predicates) v))))
  (define (all-items-pass? predicate items)
    (or (null? items)
        (and (predicate (car items))
             (all-items-pass? predicate (cdr items)))))
  (define (all-items-match-predicates? predicates items)
    (or (null? predicates)
        (and (pair? items)
             ((car predicates) (car items))
             (all-items-match-predicates? (cdr predicates) (cdr items)))))
  (cond
    [(procedure? contract) contract]
    [(not (erased-contract? contract)) (lambda (_v) #t)]
    [else
     (define name  (erased-contract-name contract))
     (define parts (erased-contract-parts contract))
     (cond
       [(eq? name 'none/c) (lambda (_v) #f)]
       [(eq? name 'flat-named-contract)
        (cond
          [(and (pair? (cdr parts)) (procedure? (cadr parts))) (cadr parts)]
          [else (lambda (_v) #t)])]
       [(eq? name 'and/c)
        (define predicates (map-contract-predicates parts))
        (lambda (v) (all-predicates-pass? predicates v))]
       [(eq? name 'or/c)
        (define predicates (map-contract-predicates parts))
        (lambda (v) (any-predicate-passes? predicates v))]
       [(eq? name 'not/c)
        (define predicate
          (if (pair? parts) (predicate-of (car parts)) (lambda (_v) #f)))
        (lambda (v) (not (predicate v)))]
       [(eq? name '=/c)
        (define expected (and (pair? parts) (car parts)))
        (lambda (v) (equal? v expected))]
       [(eq? name '</c)
        (define bound (and (pair? parts) (car parts)))
        (lambda (v) (and (real? v) (real? bound) (< v bound)))]
       [(eq? name '>/c)
        (define bound (and (pair? parts) (car parts)))
        (lambda (v) (and (real? v) (real? bound) (> v bound)))]
       [(eq? name '<=/c)
        (define bound (and (pair? parts) (car parts)))
        (lambda (v) (and (real? v) (real? bound) (<= v bound)))]
       [(eq? name '>=/c)
        (define bound (and (pair? parts) (car parts)))
        (lambda (v) (and (real? v) (real? bound) (>= v bound)))]
       [(or (eq? name 'between/c) (eq? name 'real-in))
        (define lower (and (pair? parts) (car parts)))
        (define upper (and (pair? (cdr parts)) (cadr parts)))
        (lambda (v)
          (and (real? v)
               (or (not (real? lower)) (<= lower v))
               (or (not (real? upper)) (<= v upper))))]
       [(eq? name 'integer-in)
        (define lower (and (pair? parts) (car parts)))
        (define upper (and (pair? (cdr parts)) (cadr parts)))
        (lambda (v)
          (and (integer? v)
               (or (not lower) (<= lower v))
               (or (not upper) (<= v upper))))]
       [(eq? name 'one-of/c)
        (lambda (v) (and (member v parts) #t))]
       [(eq? name 'symbols)
        (lambda (v) (and (memq v parts) #t))]
       [(eq? name 'listof)
        (define predicate
          (if (pair? parts) (predicate-of (car parts)) (lambda (_v) #t)))
        (lambda (v) (and (list? v) (all-items-pass? predicate v)))]
       [(eq? name 'list/c)
        (define predicates (map-contract-predicates parts))
        (lambda (v)
          (and (list? v)
               (= (length v) (length predicates))
               (all-items-match-predicates? predicates v)))]
       [(eq? name 'cons/c)
        (define car-predicate
          (if (pair? parts) (predicate-of (car parts)) (lambda (_v) #t)))
        (define cdr-predicate
          (if (pair? (cdr parts)) (predicate-of (cadr parts)) (lambda (_v) #t)))
        (lambda (v) (and (pair? v) (car-predicate (car v)) (cdr-predicate (cdr v))))]
       [(eq? name 'vectorof)
        (define predicate
          (if (pair? parts) (predicate-of (car parts)) (lambda (_v) #t)))
        (lambda (v)
          (and (vector? v)
               (let loop ([i 0])
                 (or (= i (vector-length v))
                     (and (predicate (vector-ref v i))
                          (loop (+ i 1)))))))]
       [(or (eq? name 'vector/c) (eq? name 'immutable-vector/c))
        (define predicates (map-contract-predicates parts))
        (lambda (v)
          (and (vector? v)
               (= (vector-length v) (length predicates))
               (let loop ([i 0] [predicates predicates])
                 (or (null? predicates)
                     (and ((car predicates) (vector-ref v i))
                          (loop (+ i 1) (cdr predicates)))))))]
       [(eq? name 'box/c)
        (define predicate
          (if (pair? parts) (predicate-of (car parts)) (lambda (_v) #t)))
        (lambda (v) (and (box? v) (predicate (unbox v))))]
       [(eq? name 'hash/c)
        (define key-predicate
          (if (pair? parts) (predicate-of (car parts)) (lambda (_v) #t)))
        (define value-predicate
          (if (pair? (cdr parts)) (predicate-of (cadr parts)) (lambda (_v) #t)))
        (lambda (v)
          (and (hash? v)
               (let loop ([keys (hash-keys v)])
                 (or (null? keys)
                     (let ([key (car keys)])
                       (and (key-predicate key)
                            (value-predicate (hash-ref v key))
                            (loop (cdr keys))))))))]
       [(or (eq? name '->) (eq? name '->*) (eq? name 'case->))
        procedure?]
       [else (lambda (_v) #t)])]))

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
;;   Run the best-effort first-order predicate; boundaries still erase values.
(define (contract-first-order-passes? contract v)
  ((contract-first-order contract) v))

;; contract : contract? any/c any/c any/c any/c ... -> any/c
;;   Erase a contract boundary and return val unchanged.
(define (contract _contract val _positive-party _negative-party . _rest) val)

(define-identity-wrapper arity-checking-wrapper)
(define-identity-wrapper blame-add-car-context)
(define-identity-wrapper blame-add-cdr-context)
(define-identity-wrapper blame-add-missing-party)
(define-identity-wrapper blame-add-nth-arg-context)
(define-identity-wrapper blame-add-range-context)
(define-identity-wrapper blame-add-unknown-context)
(define-identity-wrapper blame-replace-negative)
(define-identity-wrapper blame-swap)
(define-identity-wrapper blame-update)
(define-identity-wrapper coerce-chaperone-contract)
(define-identity-wrapper coerce-contract/f)
(define-identity-wrapper coerce-flat-contract)
(define-identity-wrapper contract-late-neg-projection)
(define-identity-wrapper contract-proc)
(define-identity-wrapper contract-projection)
(define-identity-wrapper contract-val-first-projection)
(define-identity-wrapper custom-write-property-proc)
(define-identity-wrapper get/build-late-neg-projection)
(define-identity-wrapper get/build-val-first-projection)
(define-identity-wrapper rename-contract)
(define-identity-wrapper value-blame)

(define-erased-predicate blame-missing-party?)
(define-erased-predicate blame-original?)
(define-erased-predicate blame-replaced-negative?)
(define-erased-predicate blame-swapped?)
(define-erased-predicate blame?)
(define-erased-predicate chaperone-contract-property?)
(define-erased-predicate contract-equivalent?)
(define-erased-predicate contract-property?)
(define-erased-predicate contract-random-generate-env?)
(define-erased-predicate contract-random-generate-fail?)
(define-erased-predicate contract-stronger?)
(define-erased-predicate contract-struct-list-contract?)
(define-erased-predicate eq-contract?)
(define-erased-predicate equal-contract?)
(define-erased-predicate flat-contract-property?)
(define-erased-predicate has-blame?)
(define-erased-predicate has-contract?)
(define-erased-predicate list-contract?)
(define-erased-predicate matches-arity-exactly?)
(define-erased-predicate prop:arrow-contract?)
(define-erased-predicate prop:orc-contract?)
(define-erased-predicate prop:recursive-contract?)
(define-erased-predicate skip-projection-wrapper?)
(define-erased-predicate tail-marks-match?)
(define-erased-predicate unsupplied-arg?)

(define (blame-context _blame) '())
(define (blame-contract _blame) any/c)
(define (blame-fmt->-string _blame fmt . args) (apply format fmt args))
(define (blame-negative _blame) #f)
(define (blame-positive _blame) #f)
(define (blame-source _blame) #f)
(define (blame-value _blame) #f)
(define (build-compound-type-name name . parts) (cons name parts))
(define (contract-custom-write-property-proc _contract) #f)
(define (contract-random-generate _contract . _args) #f)
(define (contract-random-generate-fail) '(contract-random-generate-fail))
(define (contract-random-generate-get-current-environment) #f)
(define (contract-random-generate-stash . _args) (void))
(define (contract-random-generate/choose . args) (and (pair? args) (car args)))
(define (contract-struct-exercise . _args) (void))
(define (contract-struct-generate . _args) #f)
(define (contract-struct-late-neg-projection contract) contract)
(define (eq-contract-val v) v)
(define (equal-contract-val v) v)
(define (flat-contract-predicate contract) (contract-first-order contract))
(define (keywords-match . _args) #t)
(define (make-exn:fail:contract:blame message marks object)
  (exn:fail:contract:blame message marks object))
(define (n->th n) (format "~ath" n))
(define (prop:arrow-contract-get-info _v) #f)
(define (prop:orc-contract-get-subcontracts _v) '())
(define (prop:recursive-contract-unroll contract) contract)
(define (raise-contract-error . _args) (error 'contract "erased contract error"))
(define (value-contract v) any/c)

(define-erased-contract-function *list/c)
(define-erased-contract-function base->-doms/c)
(define-erased-contract-function base->-rngs/c)
(define-erased-contract-function base->?)
(define-erased-contract-function build-chaperone-contract-property)
(define-erased-contract-function build-contract-property)
(define-erased-contract-function build-flat-contract-property)
(define-erased-contract-function char-in)
(define-erased-contract-function coerce-chaperone-contracts)
(define-erased-contract-function coerce-contracts)
(define-erased-contract-function coerce-flat-contracts)
(define-erased-contract-function complex/c)
(define-erased-contract-function evt/c)
(define-erased-contract-function failure-result/c)
(define-erased-contract-function false/c)
(define-erased-contract-function flat-contract)
(define-erased-contract-function if/c)
(define-erased-contract-function make-chaperone-contract)
(define-erased-contract-function make-contract)
(define-erased-contract-function make-flat-contract)
(define-erased-contract-function make-none/c)
(define-erased-contract-function make-proj-contract)
(define-erased-contract-function natural-number/c)
(define-erased-contract-function printable/c)
(define-erased-contract-function struct-type-property/c)
(define-erased-contract-function suggest/c)

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

;; ->d : syntax -> syntax
;;   Erase dependent function contracts without evaluating dependent clauses.
(define-syntax-rule (->d clause ...)
  (->))

;; dynamic->* : syntax -> syntax
;;   Keep dynamic function-contract pieces as inert descriptor parts.
(define-syntax dynamic->*
  (lambda (stx)
    (syntax-case stx ()
      [(_ mandatory optional result)
       #'(make-erased-contract 'dynamic->* (list mandatory optional result))]
      [(_ mandatory optional rest result)
       #'(make-erased-contract 'dynamic->* (list mandatory optional rest result))])))

;; cons/dc : syntax -> syntax
;;   Erase dependent pair contracts; dependent field names are not runtime values.
(define-syntax-rule (cons/dc field ...)
  (cons/c any/c any/c))

;; hash/dc : syntax -> syntax
;;   Erase dependent hash contracts to a plain inert hash contract.
(define-syntax-rule (hash/dc field ...)
  (hash/c any/c any/c))

;; struct/dc : syntax -> syntax
;;   Erase dependent struct contracts to a plain inert struct contract.
(define-syntax-rule (struct/dc struct-id field ...)
  (struct/c struct-id))

;; values/drop : syntax -> syntax
;;   Preserve non-dependent contract subexpressions while erasing projection logic.
(define-syntax-rule (values/drop contract-expr ...)
  (and/c contract-expr ...))

;; vector-immutable/c : syntax -> syntax
;;   Preserve element contract subexpressions as an inert vector descriptor.
(define-syntax-rule (vector-immutable/c contract-expr ...)
  (vector/c contract-expr ...))

;; with-contract-continuation-mark : syntax -> syntax
;;   Preserve key/value side effects, then erase to the wrapped contract.
(define-syntax-rule (with-contract-continuation-mark key-expr val-expr contract-expr)
  (begin key-expr val-expr contract-expr))

(define-erased-syntaxes
  any
  bad-number-of-results
  blame-add-context
  box-immutable/c
  channel/c
  char-in/c
  continuation-mark-key/c
  contract-exercise
  contract-in
  contract-pos/neg-doubling
  contract-struct
  current-contract-region
  define-module-boundary-contract
  define-opt/c
  define/final-prop
  define/subexpression-pos-prop
  define/subexpression-pos-prop/name
  first-or/c
  flat-contract-with-explanation
  flat-murec-contract
  flat-rec-contract
  invariant-assertion
  list*of
  mutable-treelist/c
  new-∀/c
  new-∃/c
  non-empty-listof
  opt/c
  prompt-tag/c
  property/c
  raise-blame-error
  raise-not-cons-blame-error
  recontract-out
  string-len/c
  struct-guard/c
  syntax/c
  treelist/c
  unconstrained-domain->
  vector-immutableof)

;; struct/contract : syntax -> syntax
;;   Erase field contracts and define the struct.
(define-syntax struct/contract
  (lambda (stx)
    (syntax-case stx ()
      [(_ id ([field contract-expr] ...) option ...)
       #'(struct id (field ...) option ...)]
      [(_ id super-id ([field contract-expr] ...) option ...)
       #'(struct id super-id (field ...) option ...)])))

;; define-struct/contract : syntax -> syntax
;;   Erase field contracts and define the struct.
(define-syntax define-struct/contract
  (lambda (stx)
    (syntax-case stx ()
      [(_ id ([field contract-expr] ...) option ...)
       #'(define-struct id (field ...) option ...)]
      [(_ (id super-id) ([field contract-expr] ...) option ...)
       #'(define-struct (id super-id) (field ...) option ...)])))

;; define-contract-struct : syntax -> syntax
;;   Compatibility alias for erased struct contracts.
(define-syntax define-contract-struct
  (lambda (stx)
    (syntax-case stx ()
      [(_ id fields option ...)
       #'(define-struct id fields option ...)]
      [(_ (id super-id) fields option ...)
       #'(define-struct (id super-id) fields option ...)])))

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
       (define (struct-id id-stx)
         (syntax-case id-stx ()
           [id
            (identifier? #'id)
            #'id]
           [(id ignored-id)
            (identifier? #'id)
            #'id]
           [_
            (raise-syntax-error 'contract-out
                                "unsupported erased contract-out struct id"
                                id-stx)]))
       (define (spec->provides spec)
         (syntax-case spec ()
           [(id contract-expr)
            (identifier? #'id)
            (list #'id)]
           [(rename internal-id external-id contract-expr)
            (and (identifier? #'internal-id)
                 (identifier? #'external-id))
            (list #'(rename-out [internal-id external-id]))]
           [(struct id/ignored ([field-id field-contract] ...) option ...)
            (list #`(struct-out #,(struct-id #'id/ignored)))]
           [kw
            (and (keyword? (syntax-e #'kw))
                 (memq (syntax-e #'kw)
                       '(#:exists #:∃ #:forall #:∀ #:unprotected-submodule)))
            '()]
           [id
            (identifier? #'id)
            (list #'id)]
           [_
            (raise-syntax-error 'contract-out
                                "unsupported erased contract-out spec"
                                spec)]))
       (define (abstract-binder-keyword? spec)
         (and (keyword? (syntax-e spec))
              (memq (syntax-e spec)
                    '(#:exists #:∃ #:forall #:∀ #:unprotected-submodule))))
       (define (specs->provides specs)
         (cond
           [(null? specs) '()]
           [(abstract-binder-keyword? (car specs))
            (if (null? (cdr specs))
                '()
                (specs->provides (cddr specs)))]
           [else
            (append (spec->provides (car specs))
                    (specs->provides (cdr specs)))]))
       #`(combine-out #,@(specs->provides (syntax->list #'(spec ...)))))]))

;; provide/contract : syntax -> syntax
;;   Legacy shorthand for a contract-out provide with erased annotations.
(define-syntax-rule (provide/contract spec ...)
  (provide (contract-out spec ...)))
