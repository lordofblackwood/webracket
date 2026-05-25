#lang racket/base

(provide known-module-cases
         goal1-module-cases
         module-case-data
         extract-case-inputs
         input-names
         set-diff
         print-case-summary
         print-case-delta
         print-goal1-summary
         print-goal1-dashboard
         print-primitive-ownership-collisions)

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-protocol.rkt"
         "../pkgs/webracket-lib/compiler/webify/primitive-demands.rkt")

(define-runtime-path self-path "probe-installed-module-deps.rkt")

(define goal1-output-semaphore (make-semaphore 1))

;; call-with-goal1-output-lock : (-> any/c) -> any/c
;;   Serialize parent-side dashboard output from parallel bounded workers.
(define (call-with-goal1-output-lock thunk)
  (call-with-semaphore goal1-output-semaphore thunk))

(define known-module-cases
  '(set-require
    set-predicate
    set-count
    set-member
    set-add
    set-remove
    set-union
    set->list
    set-intersect
    set-subtract
    set-symmetric-difference
    set-map
    stream-first
    stream-rest
    bytes-append-basic
    hash-basic
    hash-kind-predicates
    hash-map-basic
    hash-clear-basic
    hash-iterate
    combined-list-string-set
    multi-module-list-string-set
    multi-module-reexport-installed
    pretty-require
    promise-require
    promise-predicate-plain
    force-identity
    promise-basic
    promise-state
    vector-require
    vector-member-basic
    function-compose
    function-identity
    function-compose1
    function-negate
    function-const
    sequence-list
    sequence-range
    sequence-in-bytes
    sequence-in-hash
    sequence-in-hash-keys
    sequence-in-hash-values
    sequence-in-hash-pairs
    sequence-in-indexed
    sequence-stop-before-after
    sequence-in-sequences
    sequence-in-parallel
    sequence-in-cycle
    sequence-in-values-sequence
    sequence-generate-basic
    sequence-generate-star
    sequence-empty
    sequence-map-filter-count
    sequence-andmap-ormap
    sequence-for-each-fold
    sequence-add-between
    sequence-in-slice
    sequence-in-values-star
    sequence-predicate
    sequence-inclusive-range
    sequence-in-producer
    sequence-make-do
    sequence-in-syntax
    sequence-append-tail
    sequence-in-value
    sequence-ref-length
    sequence-for/list
    sequence-for/fold
    sequence-for/vector
    for/in-list
    for/in-vector
    for/in-string
    for/in-range
    for/in-naturals
    for/parallel-sequences
    for*/nested-sequences
    for/control-clauses
    for/list-basic
    for/fold-basic
    for*/list-basic
    for/first-basic
    keyword-optional-direct
    keyword-plain-direct
    values-call-with-values
    values-let-values
    contract-wrapper-basic
    class-require
    class-basic
    class-init-field
    class-field-access
    class-inheritance
    class-predicate
    class-super-override
    class-interface-basic
    class-generic-basic
    read-list
    read-vector
    read-symbol-string
    read-comment
    read-public-list
    read-current-readtable
    read-accept-reader-param
    read-string->number
    read-regexp-literal
    read-pregexp-literal
    read-hash-literal
    read-port-location
    read-accept-dot-param
    regexp-literal
    regexp-capture
    regexp-replace
    format-require
    format-single
    format-basic
    format-number
    format-write
    format-print
    format-print-string
    format-align
    format-fprintf-port
    match-basic
    match-literal-default
    match-let-basic
    match-predicate
    hash-comparator-semantics
    set-comparator-semantics
    custom-write-require
    set-types-require
    set-types-predicate))

;; goal1-module-cases : (listof symbol?)
;;   Small module-library matrix for Goal 1: module programs in the browser
;;   without relying on browser-side eval.
(define goal1-module-cases
  '(promise-basic
    promise-state
    sequence-list
    sequence-range
    sequence-for/list
    sequence-for/fold
    sequence-for/vector
    for/in-list
    for/in-vector
    for/in-string
    for/in-range
    for/in-naturals
    for/parallel-sequences
    for*/nested-sequences
    for/control-clauses
    for/list-basic
    for/fold-basic
    for*/list-basic
    for/first-basic
    match-basic
    match-literal-default
    match-let-basic
    match-predicate
    format-require
    format-single
    format-basic
    format-number
    format-write
    format-print
    format-print-string
    format-align
    format-fprintf-port
    keyword-optional-direct
    keyword-plain-direct
    values-call-with-values
    values-let-values
    class-basic
    class-init-field
    class-field-access
    class-inheritance
    class-predicate
    class-super-override
    class-interface-basic
    class-generic-basic
    regexp-literal
    regexp-capture
    regexp-replace
    read-public-list
    read-current-readtable
    read-accept-reader-param
    read-string->number
    read-regexp-literal
    read-pregexp-literal
    read-hash-literal
    read-port-location
    read-accept-dot-param
    bytes-append-basic
    stream-first
    stream-rest
    promise-require
    promise-predicate-plain
    force-identity
    promise-basic
    vector-require
    vector-member-basic
    function-compose
    function-identity
    function-compose1
    function-negate
    function-const
    set-member
    set-add
    set-remove
    set->list
    set-intersect
    set-subtract
    set-symmetric-difference
    set-map
    set-comparator-semantics
    hash-kind-predicates
    hash-map-basic
    hash-clear-basic
    hash-comparator-semantics
    multi-module-list-string-set
    multi-module-reexport-installed
    custom-write-require
    set-types-require
    set-types-predicate
    set-count
    set-union
    hash-basic
    hash-iterate
    combined-list-string-set))

;; module-case-data : symbol? -> (listof source-module-datum?)
;;   Return a small installed-module source slice for dependency probing.
(define (module-case-data name)
  (case name
    [(set-require)
     '((module use-set-require-only racket/base
         (require racket/set)
         (provide y)
         (define y 42)))]
    [(set-predicate)
     '((module use-set-predicate racket/base
         (require racket/set)
         (provide y)
         (define y (set? 42))))]
    [(set-count)
     '((module use-set-count racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set 1 2 2)))))]
    [(set-member)
     '((module use-set-member racket/base
         (require racket/set)
         (provide y)
         (define y (set-member? (set 'a 'b) 'b))))]
    [(set-add)
     '((module use-set-add racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set-add (set 1 2) 3)))))]
    [(set-remove)
     '((module use-set-remove racket/base
         (require racket/set)
         (provide y)
         (define y (set-member? (set-remove (set 'a 'b) 'a) 'a))))]
    [(set-union)
     '((module use-set-union racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set-union (set 1 2) (set 2 3))))))]
    [(set->list)
     '((module use-set-to-list racket/base
         (require racket/set)
         (provide y)
         (define y (length (set->list (set 1 2))))))]
    [(set-intersect)
     '((module use-set-intersect racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set-intersect (set 1 2) (set 2 3))))))]
    [(set-subtract)
     '((module use-set-subtract racket/base
         (require racket/set)
         (provide y)
         (define y (set-member? (set-subtract (set 'a 'b) (set 'a)) 'a))))]
    [(set-symmetric-difference)
     '((module use-set-symmetric-difference racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set-symmetric-difference (set 1 2) (set 2 3))))))]
    [(set-map)
     '((module use-set-map racket/base
         (require racket/set)
         (provide y)
         (define y (length (set-map (set 1 2) add1)))))]
    [(stream-first)
     '((module use-stream-first racket/base
         (require racket/stream)
         (provide y)
         (define y (stream-first (stream 42)))))]
    [(stream-rest)
     '((module use-stream-rest racket/base
         (require racket/stream)
         (provide y)
         (define y (stream-first (stream-rest (stream 40 42))))))]
    [(bytes-append-basic)
     '((module use-bytes-append-basic racket/base
         (require racket/bytes)
         (provide y)
         (define y (bytes-length (bytes-append #"web" #"-" #"racket")))))]
    [(hash-basic)
     '((module use-hash-basic racket/base
         (provide y)
         (define y
           (hash-ref (hash-set (make-immutable-hash '((a . 1))) 'b 41)
                     'b))))]
    [(hash-kind-predicates)
     '((module use-hash-kind-predicates racket/base
         (provide y)
         (define y
           (and (hash-equal? (hash 'a 1))
                (hash-eq? (hasheq 'a 1))
                (hash-eqv? (hasheqv 'a 1))))))]
    [(hash-map-basic)
     '((module use-hash-map-basic racket/base
         (provide y)
         (define y
           (apply + (hash-map (make-immutable-hash '((a . 1) (b . 2)))
                              (lambda (k v) v))))))]
    [(hash-clear-basic)
     '((module use-hash-clear-basic racket/base
         (provide y)
         (define y
           (+ (hash-count (hash-clear (hash 'a 1 'b 2)))
              (if (hash-equal? (hash-clear (hash 'a 1))) 42 0)))))]
    [(hash-iterate)
     '((module use-hash-iterate racket/base
         (provide y)
         (define y
           (let ([h (make-immutable-hash '((a . 1) (b . 2)))])
             (+ (length (hash-keys h))
                (length (hash-values h))
                (length (hash->list h))
                (let ([sum 0])
                  (hash-for-each h (lambda (k v) (set! sum (+ sum v))))
                  sum))))))]
    [(combined-list-string-set)
     '((module use-combined-list-string-set racket/base
         (require racket/list racket/string racket/set)
         (provide y)
         (define y
           (+ (first '(37 38))
              (string-length (string-join '("ab" "c") ""))
              (set-count (set 'x 'y 'y))))))]
    [(multi-module-list-string-set)
     '((module set-provider racket/base
         (require racket/set)
         (provide selected)
         (define selected (set-add (set 'alpha) 'beta)))
       (module string-provider racket/base
         (require racket/list racket/string)
         (provide joined)
         (define joined (string-join (map symbol->string '(alpha beta)) ",")))
       (module use-multi-module-list-string-set racket/base
         (require racket/set 'set-provider 'string-provider)
         (provide y)
         (define y (+ (set-count selected) (string-length joined)))))]
    [(multi-module-reexport-installed)
     '((module values-provider racket/base
         (require racket/list)
         (provide picked)
         (define picked (first '(40 41 42))))
       (module values-reexport racket/base
         (require 'values-provider racket/string)
         (provide renamed)
         (define renamed (string-append (number->string picked) "!")))
       (module use-reexport-installed racket/base
         (require 'values-reexport racket/string)
         (provide y)
         (define y (string-length renamed))))]
    [(format-require)
     '((module use-format-require racket/base
         (require racket/format)
         (provide y)
         (define y 42)))]
    [(format-single)
     '((module use-format-single racket/base
         (require racket/format)
         (provide y)
         (define y (~a "web"))))]
    [(format-basic)
     '((module use-format-basic racket/base
         (require racket/format)
         (provide y)
         (define y (~a "web" 'racket #:separator "-"))))]
    [(format-number)
     '((module use-format-number racket/base
         (require racket/format)
         (provide y)
         (define y (~a 42))))]
    [(format-write)
     '((module use-format-write racket/base
         (require racket/format)
         (provide y)
         (define y (~s 'web))))]
    [(format-print)
     '((module use-format-print racket/base
         (require racket/format)
         (provide y)
         (define y (~v 'web))))]
    [(format-print-string)
     '((module use-format-print-string racket/base
         (require racket/format)
         (provide y)
         (define y (~v "web"))))]
    [(format-align)
     '((module use-format-align racket/base
         (require racket/format)
         (provide y)
         (define y (~a "web" #:min-width 5 #:align 'right))))]
    [(format-fprintf-port)
     '((module use-format-fprintf-port racket/base
         (require racket/format)
         (provide y)
         (struct sink (port) #:property prop:output-port 0)
         (define out (open-output-string))
         (fprintf (sink out) "~a" "ok")
         (define y (get-output-string out))))]
    [(keyword-optional-direct)
     '((module use-keyword-optional-direct racket/base
         (require racket/private/kw)
         (provide y)
         (define f
           (make-keyword-procedure
            (lambda (kws kw-args . args)
              (+ (length kws) (length kw-args) (length args)))))
         (define y (f #:sep "-" 'a 'b))))]
    [(keyword-plain-direct)
     '((module use-keyword-plain-direct racket/base
         (require racket/private/kw)
         (provide y)
         (define f
           (make-keyword-procedure
            (lambda (kws kw-args . args) 0)
            (lambda args (+ 40 (length args)))))
         (define y (f 'a 'b))))]
    [(values-call-with-values)
     '((module use-values-call-with-values racket/base
         (provide y)
         (define y
           (call-with-values
            (lambda () (values 20 22))
            +))))]
    [(values-let-values)
     '((module use-values-let-values racket/base
         (provide y)
         (define y
           (let-values ([(a b) (values 20 22)])
             (+ a b)))))]
    [(contract-wrapper-basic)
     '((module use-contract-wrapper-basic racket/base
         (require racket/contract)
         (provide y)
         (define/contract (answer x)
           (-> number? number?)
           (+ x 1))
         (define y (answer 41))))]
    [(pretty-require)
     '((module use-pretty-require racket/base
         (require racket/pretty)
         (provide y)
         (define y 42)))]
    [(promise-require)
     '((module use-promise-require racket/base
         (require racket/promise)
         (provide y)
         (define y 42)))]
    [(promise-predicate-plain)
     '((module use-promise-predicate-plain racket/base
         (require racket/promise)
         (provide y)
         (define y (promise? 42))))]
    [(force-identity)
     '((module use-force-identity racket/base
         (require racket/promise)
         (provide y)
         (define y (force 42))))]
    [(promise-basic)
     '((module use-promise-basic racket/base
         (require racket/promise)
         (provide y)
         (define p (delay (+ 20 22)))
         (define y (if (promise? p) (force p) 0))))]
    [(promise-state)
     '((module use-promise-state racket/base
         (require racket/promise)
         (provide y)
         (define p (delay (+ 20 22)))
         (define y
           (and (not (promise-forced? p))
                (not (promise-running? p))
                (= (force p) 42)
                (promise-forced? p)
                (not (promise-running? p))))))]
    [(vector-require)
     '((module use-vector-require racket/base
         (require racket/vector)
         (provide y)
         (define y 42)))]
    [(vector-member-basic)
     '((module use-vector-member-basic racket/base
         (require racket/vector)
         (provide y)
         (define y (vector-member 2 (vector 1 2 3)))))]
    [(function-compose)
     '((module use-function-compose racket/base
         (require racket/function)
         (provide y)
         (define y ((compose add1 add1) 40))))]
    [(function-identity)
     '((module use-function-identity racket/base
         (require racket/function)
         (provide y)
         (define y (identity 42))))]
    [(function-compose1)
     '((module use-function-compose1 racket/base
         (require racket/function)
         (provide y)
         (define y ((compose1 add1 add1) 40))))]
    [(function-negate)
     '((module use-function-negate racket/base
         (require racket/function)
         (provide y)
         (define y ((negate symbol?) 42))))]
    [(function-const)
     '((module use-function-const racket/base
         (require racket/function)
         (provide y)
         (define y ((const 42) 'ignored))))]
    [(sequence-list)
     '((module use-sequence-list racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (sequence->list '(a b c))))))]
    [(sequence-range)
     '((module use-sequence-range racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (sequence->list (in-range 3))))))]
    [(sequence-in-bytes)
     '((module use-sequence-in-bytes racket/base
         (require racket/sequence)
         (provide y)
         (define bstr #"abc")
         (define y
           (for/fold ([sum 0]) ([b (in-bytes bstr)])
             (+ sum (if (integer? b) 1 0))))))]
    [(sequence-in-hash)
     '((module use-sequence-in-hash racket/base
         (require racket/sequence)
         (provide y)
         (define ht (hash 'a 1 'b 2))
         (define y
           (for/fold ([sum 0]) ([(k v) (in-hash ht)])
             (+ sum v)))))]
    [(sequence-in-hash-keys)
     '((module use-sequence-in-hash-keys racket/base
         (require racket/sequence)
         (provide y)
         (define ht (hash 'a 10 'b 20))
         (define y (length (for/list ([k (in-hash-keys ht)]) k)))))]
    [(sequence-in-hash-values)
     '((module use-sequence-in-hash-values racket/base
         (require racket/sequence)
         (provide y)
         (define ht (hash 'a 10 'b 20))
         (define y (for/fold ([sum 0]) ([v (in-hash-values ht)]) (+ sum v)))))]
    [(sequence-in-hash-pairs)
     '((module use-sequence-in-hash-pairs racket/base
         (require racket/sequence)
         (provide y)
         (define ht (hash 'a 10 'b 20))
         (define y (length (for/list ([p (in-hash-pairs ht)]) p)))))]
    [(sequence-in-indexed)
     '((module use-sequence-in-indexed racket/base
         (require racket/sequence)
         (provide y)
         (define y
           (for/fold ([sum 0]) ([(ch i) (in-indexed "abc")])
             (+ sum i)))))]
    [(sequence-stop-before-after)
     '((module use-sequence-stop-before-after racket/base
         (require racket/sequence)
         (provide y)
         (define before (for/list ([x (stop-before '(1 2 3 4) (lambda (x) (= x 3)))]) x))
         (define after (for/list ([x (stop-after '(1 2 3 4) (lambda (x) (= x 3)))]) x))
         (define y (+ (length before) (length after)))))]
    [(sequence-in-sequences)
     '((module use-sequence-in-sequences racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (for/list ([x (in-sequences '(a b) "cd")]) x)))))]
    [(sequence-in-parallel)
     '((module use-sequence-in-parallel racket/base
         (require racket/sequence)
         (provide y)
         (define y
           (for/fold ([sum 0]) ([(x y) (in-parallel '(1 2 3) '(10 20 30))])
             (+ sum x y)))))]
    [(sequence-in-cycle)
     '((module use-sequence-in-cycle racket/base
         (require racket/sequence)
         (provide y)
         (define y
           (for/fold ([sum 0]) ([x (in-cycle '(1 2))]
                                [i (in-range 5)])
             (+ sum x)))))]
    [(sequence-in-values-sequence)
     '((module use-sequence-in-values-sequence racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (for/list ([xs (in-values-sequence (in-hash (hash 'a 1 'b 2)))]) xs)))))]
    [(sequence-generate-basic)
     '((module use-sequence-generate-basic racket/base
         (require racket/sequence)
         (provide y)
         (define-values (more? get) (sequence-generate '(10 20 30)))
         (define y (+ (if (more?) 1 0) (get) (get)))))]
    [(sequence-generate-star)
     '((module use-sequence-generate-star racket/base
         (require racket/sequence)
         (provide y)
         (define-values (first next) (sequence-generate* '(10 20)))
         (define-values (second done) (next))
         (define-values (third _done-again) (done))
         (define y (+ (car first) (car second) (if third 100 0)))))]
    [(sequence-empty)
     '((module use-sequence-empty racket/base
         (require racket/sequence)
         (provide y)
         (define y (sequence-length empty-sequence))))]
    [(sequence-map-filter-count)
     '((module use-sequence-map-filter-count racket/base
         (require racket/sequence)
         (provide y)
         (define y (+ (sequence-count even? '(1 2 3 4))
                      (length (sequence->list (sequence-filter odd? '(1 2 3 4))))
                      (sequence-ref (sequence-map add1 '(40)) 0)))))]
    [(sequence-andmap-ormap)
     '((module use-sequence-andmap-ormap racket/base
         (require racket/sequence)
         (provide y)
         (define y
           (+ (if (sequence-andmap number? '(1 2 3)) 10 0)
              (if (sequence-ormap even? '(1 3 4)) 20 0)))))]
    [(sequence-for-each-fold)
     '((module use-sequence-for-each-fold racket/base
         (require racket/sequence)
         (provide y)
         (define seen '())
         (sequence-for-each (lambda (x) (set! seen (cons x seen))) '(1 2 3))
         (define y (+ (length seen)
                      (sequence-fold (lambda (acc x) (+ acc x)) 0 '(4 5 6))))))]
    [(sequence-add-between)
     '((module use-sequence-add-between racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (sequence->list (sequence-add-between '(a b c) 'sep))))))]
    [(sequence-in-slice)
     '((module use-sequence-in-slice racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (for/list ([xs (in-slice 3 (in-range 8))]) xs)))))]
    [(sequence-in-values-star)
     '((module use-sequence-in-values-star racket/base
         (require racket/sequence)
         (provide y)
         (define y (+ (length (for/list ([xs (in-values*-sequence (in-hash (hash 'a 1 'b 2)))]) xs))
                      (length (for/list ([xs (in-values*-sequence '(a b))]) xs))))))]
    [(sequence-predicate)
     '((module use-sequence-predicate racket/base
         (require racket/sequence)
         (provide y)
         (define y (+ (if (sequence? 42) 10 0)
                      (if (sequence? '(a b)) 20 0)
                      (if (sequence? #\x) 100 0)))))]
    [(sequence-inclusive-range)
     '((module use-sequence-inclusive-range racket/base
         (require racket/sequence)
         (provide y)
         (define y (for/fold ([sum 0]) ([x (in-inclusive-range 7 11 2)]) (+ sum x)))))]
    [(sequence-in-producer)
     '((module use-sequence-in-producer racket/base
         (require racket/sequence)
         (provide y)
         (define n 0)
         (define (next)
           (set! n (+ n 1))
           n)
         (define y (for/fold ([sum 0]) ([x (in-producer next 4)]) (+ sum x)))))]
    [(sequence-make-do)
     '((module use-sequence-make-do racket/base
         (require racket/sequence)
         (provide y)
         (define (in-alt-list xs)
           (make-do-sequence
            (lambda ()
              (initiate-sequence
               #:pos->element car
               #:next-pos (lambda (xs) (cdr (cdr xs)))
               #:init-pos xs
               #:continue-with-pos? pair?
               #:continue-after-pos+val? (lambda (xs _) (pair? (cdr xs)))))))
         (define y (length (sequence->list (in-alt-list '(1 2 3 4 5 6 7)))))))]
    [(sequence-in-syntax)
     '((module use-sequence-in-syntax racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (for/list ([x (in-syntax #'(1 2 3))]) x)))))]
    [(sequence-append-tail)
     '((module use-sequence-append-tail racket/base
         (require racket/sequence)
         (provide y)
         (define y (+ (length (sequence->list (sequence-append '(a b) '(c d))))
                      (sequence-ref (sequence-tail '(10 20 30) 1) 0)))))]
    [(sequence-in-value)
     '((module use-sequence-in-value racket/base
         (require racket/sequence)
         (provide y)
         (define y (for/first ([x (in-value 42)]) x))))]
    [(sequence-ref-length)
     '((module use-sequence-ref-length racket/base
         (require racket/sequence)
         (provide y)
         (define y (+ (sequence-ref '(10 20 30) 1)
                      (sequence-length "abc")))))]
    [(sequence-for/list)
     '((module use-sequence-for-list racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (for/list ([x (in-list '(a b c))]) x)))))]
    [(sequence-for/fold)
     '((module use-sequence-for-fold racket/base
         (require racket/sequence)
         (provide y)
         (define y (for/fold ([sum 0]) ([x (in-range 4)]) (+ sum x)))))]
    [(sequence-for/vector)
     '((module use-sequence-for-vector racket/base
         (require racket/sequence)
         (provide y)
         (define y (vector-length (for/vector ([x (in-vector '#(a b c))]) x)))))]
    [(for/in-list)
     '((module use-for-in-list racket/base
         (provide y)
         (define y (apply + (for/list ([x (in-list '(10 20 12))]) x)))))]
    [(for/in-vector)
     '((module use-for-in-vector racket/base
         (provide y)
         (define y (apply + (for/list ([x (in-vector '#(10 20 12))]) x)))))]
    [(for/in-string)
     '((module use-for-in-string racket/base
         (provide y)
         (define y
           (for/fold ([sum 0]) ([ch (in-string "abc")])
             (+ sum (if (char? ch) 1 0))))))]
    [(for/in-range)
     '((module use-for-in-range racket/base
         (provide y)
         (define y (for/fold ([sum 0]) ([x (in-range 7 10)]) (+ sum x)))))]
    [(for/in-naturals)
     '((module use-for-in-naturals racket/base
         (provide y)
         (define y
           (for/fold ([sum 0]) ([x (in-naturals)] [v '(10 11 21)])
             (+ sum x v)))))]
    [(for/parallel-sequences)
     '((module use-for-parallel-sequences racket/base
         (provide y)
         (define y
           (apply + (for/list ([x (in-list '(1 2 3))]
                               [v (in-vector '#(10 20 6))])
                      (+ x v))))))]
    [(for*/nested-sequences)
     '((module use-for-star-nested-sequences racket/base
         (provide y)
         (define y
           (apply + (for*/list ([x (in-list '(1 2))]
                                [v (in-vector '#(10 9))])
                      (+ x v))))))]
    [(for/control-clauses)
     '((module use-for-control-clauses racket/base
         (provide y)
         (define y
           (for/fold ([sum 0]) ([x (in-list '(1 2 3 4 5))]
                                #:when (odd? x)
                                #:unless (= x 1)
                                #:break (> x 4))
             (+ sum x)))))]
    [(for/list-basic)
     '((module use-for-list-basic racket/base
         (provide y)
         (define y (length (for/list ([x '(a b c)]) x)))))]
    [(for/fold-basic)
     '((module use-for-fold-basic racket/base
         (provide y)
         (define y (for/fold ([sum 0]) ([x '(1 2 3)]) (+ sum x)))))]
    [(for*/list-basic)
     '((module use-for-star-list-basic racket/base
         (provide y)
         (define y (length (for*/list ([x '(a b)] [y '(1 2)]) (list x y))))))]
    [(for/first-basic)
     '((module use-for-first-basic racket/base
         (provide y)
         (define y (for/first ([x '(40 41 42)] #:when (> x 40)) x))))]
    [(class-require)
     '((module use-class-require racket/base
         (require racket/class)
         (provide y)
         (define y 42)))]
    [(class-basic)
     '((module use-class-basic racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)
             (define/public (value) 42)))
         (define y (send (new counter%) value))))]
    [(class-init-field)
     '((module use-class-init-field racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (init-field n)
             (super-new)
             (define/public (value) n)))
         (define y (send (new counter% [n 42]) value))))]
    [(class-field-access)
     '((module use-class-field-access racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (field [n 40])
             (super-new)))
         (define obj (new counter%))
         (set-field! n obj 42)
         (define y (get-field n obj))))]
    [(class-inheritance)
     '((module use-class-inheritance racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/public (value) 40)))
         (define child%
           (class base%
             (super-new)
             (inherit value)
             (define/public (next) (+ (value) 2))))
         (define y (send (new child%) next))))]
    [(class-predicate)
     '((module use-class-predicate racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)))
         (define obj (new counter%))
         (define y (if (and (object? obj) (is-a? obj counter%)) 42 0))))]
    [(class-super-override)
     '((module use-class-super-override racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/public (value) 40)))
         (define child%
           (class base%
             (super-new)
             (define/override (value) (+ (super value) 2))))
         (define y (send (new child%) value))))]
    [(class-interface-basic)
     '((module use-class-interface-basic racket/base
         (require racket/class)
         (provide y)
         (define point<%> (interface () get-x get-y))
         (define point%
           (class* object% (point<%>)
             (super-new)
             (define/public (get-x) 40)
             (define/public (get-y) 2)))
         (define obj (new point%))
         (define y
           (if (and (interface? point<%>)
                    (is-a? obj point<%>)
                    (implementation? point% point<%>))
               (+ (send obj get-x) (send obj get-y))
               0))))]
    [(class-generic-basic)
     '((module use-class-generic-basic racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)
             (define/public (value x) (+ x 2))))
         (define value-g (generic counter% value))
         (define obj (new counter%))
         (define y (send-generic obj value-g 40))))]
    [(regexp-literal)
     '((module use-regexp-literal racket/base
         (provide y)
         (define y (regexp-match? #rx"a+" "cat"))))]
    [(read-list)
     '((module use-read-list racket/base
         (provide y)
         (define y (length (read (open-input-string "(1 2 3)"))))))]
    [(read-vector)
     '((module use-read-vector racket/base
         (provide y)
         (define y (vector-length (read (open-input-string "#(1 2 3)"))))))]
    [(read-symbol-string)
     '((module use-read-symbol-string racket/base
         (provide y)
         (define in (open-input-string "sym \"web\""))
         (define y (+ (string-length (symbol->string (read in)))
                      (string-length (read in))))))]
    [(read-comment)
     '((module use-read-comment racket/base
         (provide y)
         (define y (read (open-input-string "#; ignored 42")))))]
    [(read-public-list)
     '((module use-read-public-list racket/base
         (provide y)
         (define y (length (read (open-input-string "(1 2 3)"))))))]
    [(read-current-readtable)
     '((module use-read-current-readtable racket/base
         (provide y)
         (define y (not (current-readtable)))))]
    [(read-accept-reader-param)
     '((module use-read-accept-reader-param racket/base
         (provide y)
         (read-accept-reader #t)
         (define y (read-accept-reader))))]
    [(read-string->number)
     '((module use-read-string-to-number racket/base
         (provide y)
         (define y (string->number "42"))))]
    [(read-regexp-literal)
     '((module use-read-regexp-literal racket/base
         (provide y)
         (define y (regexp? (read (open-input-string "#rx\"a+\""))))))]
    [(read-pregexp-literal)
     '((module use-read-pregexp-literal racket/base
         (provide y)
         (define y (pregexp? (read (open-input-string "#px\"a+\""))))))]
    [(read-hash-literal)
     '((module use-read-hash-literal racket/base
         (provide y)
         (define y (hash-ref (read (open-input-string "#hash((a . 41))")) 'a))))]
    [(read-port-location)
     '((module use-read-port-location racket/base
         (provide y)
         (define in (open-input-string "abc\n42"))
         (port-count-lines! in)
         (read in)
         (define-values (line col pos) (port-next-location in))
         (define y (+ line col pos))))]
    [(read-accept-dot-param)
     '((module use-read-accept-dot-param racket/base
         (provide y)
         (define old (read-accept-dot))
         (read-accept-dot #t)
         (define y (and (read-accept-dot) old))))]
    [(regexp-capture)
     '((module use-regexp-capture racket/base
         (provide y)
         (define y (length (regexp-match #rx"(a)" "cat")))))]
    [(regexp-replace)
     '((module use-regexp-replace racket/base
         (provide y)
         (define y (regexp-replace* #rx"a" "banana" "o"))))]
    [(match-basic)
     '((module use-match-basic racket/base
         (require racket/match)
         (provide y)
         (define (score v)
           (match v
             [(list 'answer n) n]
             [_ 0]))
         (define y (score '(answer 42)))))]
    [(match-literal-default)
     '((module use-match-literal-default racket/base
         (require racket/match)
         (provide y)
         (define y
           (match '(other 17)
             [(list 'answer n) n]
             [_ 42]))))]
    [(match-let-basic)
     '((module use-match-let-basic racket/base
         (require racket/match)
         (provide y)
         (define y
           (match-let ([(list a b c) '(10 20 12)])
             (+ a b c)))))]
    [(match-predicate)
     '((module use-match-predicate racket/base
         (require racket/match)
         (provide y)
         (define y
           (match 42
             [(? number? n) n]
             [_ 0]))))]
    [(hash-comparator-semantics)
     '((module use-hash-comparator-semantics racket/base
         (provide y)
         (define a (list 1))
         (define b (list 1))
         (define y
           (+ (hash-count (hash a 1 b 2))
              (* 10 (hash-count (hasheq a 1 b 2)))))))]
    [(set-comparator-semantics)
     '((module use-set-comparator-semantics racket/base
         (require racket/set)
         (provide y)
         (define a (list 1))
         (define b (list 1))
         (define y
           (+ (set-count (set a b))
              (* 10 (set-count (seteq a b)))))))]
    [(custom-write-require)
     '((module use-custom-write-require racket/base
         (require racket/private/custom-write)
         (provide y)
         (define y 42)))]
    [(set-types-require)
     '((module use-set-types-require racket/base
         (require racket/private/set-types)
         (provide y)
         (define y 42)))]
    [(set-types-predicate)
     '((module use-set-types-predicate racket/base
         (require racket/private/set-types)
         (provide y)
         (define y (set? 42))))]
    [else
     (raise-user-error 'probe-installed-module-deps
                       "unknown case ~a; expected one of ~a"
                       name
                       known-module-cases)]))

;; extract-case-inputs : symbol? -> (listof webify-module-linklet-input?)
;;   Extract the demand-sliced installed provider graph for one case.
(define (extract-case-inputs name)
  (webify-source-modules->discovered-resolved-linklet-inputs
   (module-case-data name)
   #:extra-reports (list webify-module-protocol-report)
   #:module-protocol-dependency webify-module-protocol-dependency
   #:demand-slice? #t))

;; input-names : (listof webify-module-linklet-input?) -> (listof symbol?)
;;   Return extracted module names in manifest order.
(define (input-names inputs)
  (map webify-module-linklet-input-name inputs))

;; symbol<?* : symbol? symbol? -> boolean?
;;   Sort symbols by printed name.
(define (symbol<?* a b)
  (string<? (symbol->string a) (symbol->string b)))

;; set-diff : (listof symbol?) (listof symbol?) -> (listof symbol?)
;;   Return sorted names in xs but not ys.
(define (set-diff xs ys)
  (define ys-table (for/hasheq ([y (in-list ys)]) (values y #t)))
  (sort (filter (lambda (x) (not (hash-has-key? ys-table x))) xs) symbol<?*))

;; print-case-summary : symbol? (listof input?) -> void?
;;   Print a compact dependency and primitive-demand summary.
(define (print-case-summary name inputs)
  (define report (webify-module-linklet-inputs->primitive-demands inputs))
  (define missing (webify-primitive-demand-report-missing report))
  (printf "case: ~a\n" name)
  (printf "input-count: ~a\n" (length inputs))
  (printf "inputs: ~s\n" (input-names inputs))
  (printf "primitive-demand-count: ~a\n"
          (length (webify-primitive-demand-report-demands report)))
  (printf "missing-primitive-demand-count: ~a\n"
          (length missing))
  (unless (null? missing)
    (printf "missing-primitive-demands: ~s\n"
            (map (lambda (d)
                   (list (webify-primitive-demand-module d)
                         (webify-primitive-demand-name d)
                         (webify-primitive-demand-sources d)))
                 missing))))

;; print-case-delta : symbol? inputs symbol? inputs -> void?
;;   Print module-name deltas between two extracted cases.
(define (print-case-delta baseline baseline-inputs current current-inputs)
  (define baseline-names (input-names baseline-inputs))
  (define current-names  (input-names current-inputs))
  (printf "baseline-case: ~a\n" baseline)
  (printf "current-case: ~a\n" current)
  (printf "added-inputs: ~s\n" (set-diff current-names baseline-names))
  (printf "removed-inputs: ~s\n" (set-diff baseline-names current-names)))

;; summarize-goal1-case : symbol? -> hash?
;;   Compute provider-graph and primitive-demand status for one Goal 1 case.
(define (summarize-goal1-case name)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (hasheq 'case name
                             'extract-status 'failed
                             'compile-to-wat-status 'unknown
                             'runtime-status 'unknown
                             'extract-error (exn-message exn)
                             'input-count #f
                             'input-names '()
                             'primitive-demand-count #f
                             'missing-primitive-count #f
                             'missing-primitive-demands '()
                             'ownership-counts '()))])
    (define inputs (extract-case-inputs name))
    (define report (webify-module-linklet-inputs->primitive-demands inputs))
    (define missing (webify-primitive-demand-report-missing report))
    (hasheq 'case name
            'extract-status 'ok
            'compile-to-wat-status 'not-run
            'runtime-status 'not-run
            'input-count (length inputs)
            'input-names (input-names inputs)
            'primitive-demand-count
            (length (webify-primitive-demand-report-demands report))
            'missing-primitive-count (length missing)
            'ownership-counts
            (webify-primitive-demand-report-ownership-counts report)
            'missing-primitive-demands
            (map (lambda (d)
                   (list (webify-primitive-demand-module d)
                         (webify-primitive-demand-name d)
                         (webify-primitive-demand-sources d)))
                 missing))))

;; print-goal1-case-verbose : hash? -> void?
;;   Print the detailed per-case Goal 1 dependency summary.
(define (print-goal1-case-verbose summary)
  (printf "case: ~a\n" (hash-ref summary 'case))
  (printf "extract-status: ~a\n" (hash-ref summary 'extract-status))
  (printf "compile-to-wat-status: ~a\n"
          (hash-ref summary 'compile-to-wat-status 'unknown))
  (printf "runtime-status: ~a\n"
          (hash-ref summary 'runtime-status 'unknown))
  (cond
    [(eq? (hash-ref summary 'extract-status) 'ok)
     (printf "input-count: ~a\n" (hash-ref summary 'input-count))
     (printf "inputs: ~s\n" (hash-ref summary 'input-names))
     (printf "primitive-demand-count: ~a\n"
             (hash-ref summary 'primitive-demand-count))
     (printf "missing-primitive-demand-count: ~a\n"
             (hash-ref summary 'missing-primitive-count))
     (printf "primitive-ownership-counts: ~s\n"
             (hash-ref summary 'ownership-counts))
     (unless (zero? (hash-ref summary 'missing-primitive-count))
       (printf "missing-primitive-demands: ~s\n"
               (hash-ref summary 'missing-primitive-demands)))]
    [else
     (printf "extract-error: ~a\n" (hash-ref summary 'extract-error))]))

;; print-goal1-case-compact : hash? -> void?
;;   Print one compact dashboard row for a Goal 1 dependency case.
(define (print-goal1-case-compact summary)
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
          (hash-ref summary 'case)
          (hash-ref summary 'extract-status)
          (hash-ref summary 'compile-to-wat-status 'unknown)
          (hash-ref summary 'runtime-status 'unknown)
          (or (hash-ref summary 'input-count #f) "-")
          (or (hash-ref summary 'primitive-demand-count #f) "-")
          (or (hash-ref summary 'missing-primitive-count #f) "-")
          (or (hash-ref summary 'ownership-counts #f) "-"))
  (flush-output))

;; print-goal1-summary : [#:compact? boolean?] -> void?
;;   Print provider-graph and primitive-demand status for Goal 1 cases.
(define (print-goal1-summary #:compact? [compact? #f]
                             #:cases [cases goal1-module-cases])
  (when compact?
    (printf "case\textract\tcompile-to-wat\truntime\tinputs\tprimitive-demands\tmissing-primitives\townership\n")
    (flush-output))
  (for ([name (in-list cases)]
        [index (in-naturals)])
    (when (and (not compact?) (positive? index))
      (newline))
    (define summary (summarize-goal1-case name))
    (if compact?
        (print-goal1-case-compact summary)
        (print-goal1-case-verbose summary))))

;; print-goal1-dashboard : -> void?
;;   Print the compact must-have library dependency dashboard.
(define (print-goal1-dashboard #:cases [cases goal1-module-cases])
  (printf "Goal 1 must-have library dependency dashboard\n")
  (printf "case\textract\tcompile-to-wat\truntime\tinputs\tprimitive-demands\tmissing-primitives\townership\n")
  (flush-output)
  (for ([name (in-list cases)])
    (print-goal1-case-compact (summarize-goal1-case name))))

;; select-goal1-cases : (or/c #f exact-nonnegative-integer?) -> (listof symbol?)
;;   Select an optional prefix of Goal 1 cases for quick bounded checks.
(define (select-goal1-cases limit)
  (cond
    [(not limit) goal1-module-cases]
    [else        (take goal1-module-cases
                       (min limit (length goal1-module-cases)))]))

;; call-with-memory-limit : (or/c #f exact-positive-integer?) (-> any/c) -> any/c
;;   Optionally run thunk in a custodian-limited worker thread.
(define (call-with-memory-limit limit-bytes thunk)
  (cond
    [(not limit-bytes)
     (thunk)]
    [else
     (define ch (make-channel))
     (define cust (make-custodian))
     (custodian-limit-memory cust limit-bytes cust)
     (parameterize ([current-custodian cust])
       (thread
        (lambda ()
          (channel-put
           ch
           (with-handlers ([exn:fail? (lambda (exn) (list 'exn exn))])
             (list 'values (call-with-values thunk list)))))))
     (match (channel-get ch)
       [(list 'values results) (apply values results)]
       [(list 'exn exn)        (raise exn)])]))

;; run-goal1-worker! : symbol? (or/c #f exact-positive-integer?) -> void?
;;   Print one compact Goal 1 dependency row in a memory-limited worker.
(define (run-goal1-worker! name memory-mb)
  (call-with-memory-limit
   (and memory-mb (* memory-mb 1024 1024))
   (lambda ()
     (print-goal1-case-compact (summarize-goal1-case name))
     (flush-output))))

;; run-goal1-child/bounded! : symbol? exact-positive-integer? (or/c #f exact-positive-integer?) -> exact-integer?
;;   Run one Goal 1 extraction case in a child process with timeout protection.
(define (run-goal1-child/bounded! name timeout-seconds memory-mb)
  (call-with-goal1-output-lock
   (lambda ()
     (printf "# goal1-deps starting ~a (timeout ~as, memory ~a MiB)\n"
             name
             timeout-seconds
             (or memory-mb "unlimited"))
     (flush-output)))
  (define exec-file (find-system-path 'exec-file))
  (define racket-bin
    (cond
      [(and (path? exec-file)
            (complete-path? exec-file))
       exec-file]
      [(and (path? exec-file)
            (file-exists? exec-file))
       (path->complete-path exec-file)]
      [else
       (find-executable-path (path->string exec-file))]))
  (unless racket-bin
    (raise-user-error 'probe-installed-module-deps
                      "could not find current racket executable on PATH"))
  (define tmp-dir (make-temporary-file "webracket-goal1-deps-~a" 'directory))
  (define out-path (build-path tmp-dir "stdout.txt"))
  (define err-path (build-path tmp-dir "stderr.txt"))
  (define out (open-output-file out-path #:exists 'truncate/replace))
  (define err (open-output-file err-path #:exists 'truncate/replace))
  (define args
    (append
     (list "-y"
           (path->string self-path)
           "--goal1-worker"
           "--case"
           (symbol->string name))
     (if memory-mb
         (list "--memory-mb" (number->string memory-mb))
         '())))
  (define-values (proc child-out child-in child-err)
    (apply subprocess out #f err 'new (path->string racket-bin) args))
  (when child-out (close-input-port child-out))
  (when child-in  (close-output-port child-in))
  (when child-err (close-input-port child-err))
  (define completed (sync/timeout timeout-seconds proc))
  (unless completed
    (subprocess-kill proc #t))
  (subprocess-wait proc)
  (close-output-port out)
  (close-output-port err)
  (define stdout (file->string out-path))
  (define stderr (file->string err-path))
  (define status (subprocess-status proc))
  (delete-directory/files tmp-dir)
  (cond
    [(not completed)
     (call-with-goal1-output-lock
      (lambda ()
        (printf "~a\ttimeout\tunknown\tunknown\t-\t-\t-\t-\n" name)
        (flush-output)
        (printf "# goal1-deps timed out ~a\n" name)
        (flush-output)))
     124]
    [(and (integer? status) (zero? status))
     (call-with-goal1-output-lock
      (lambda ()
        (display stdout)
        (flush-output)
        (printf "# goal1-deps finished ~a\n" name)
        (flush-output)))
     0]
    [else
     (call-with-goal1-output-lock
      (lambda ()
        (printf "~a\tworker-failed\tunknown\tunknown\t-\t-\t-\t-\n" name)
        (unless (string=? stdout "") (display stdout))
        (unless (string=? stderr "")
          (display stderr (current-error-port)))
        (flush-output)
        (fprintf (current-error-port) "goal1-deps: failed ~a\n" name)
        (flush-output (current-error-port))))
     (if (integer? status) status 1)]))

;; run-goal1-children/bounded! : (listof symbol?) exact-positive-integer?
;;                             (or/c #f exact-positive-integer?)
;;                             exact-positive-integer?
;;                          -> exact-integer?
;;   Run bounded Goal 1 child extractions across a limited number of lanes.
(define (run-goal1-children/bounded! cases timeout-seconds memory-mb jobs)
  (cond
    [(or (<= jobs 1) (<= (length cases) 1))
     (for/fold ([status 0]) ([name (in-list cases)])
       (define next-status (run-goal1-child/bounded! name timeout-seconds memory-mb))
       (if (zero? status) next-status status))]
    [else
     (define work-ch (make-channel))
     (define result-ch (make-channel))
     (define worker-count (min jobs (length cases)))
     (for ([worker-index (in-range worker-count)])
       (thread
        (lambda ()
          (let loop ()
            (define name (channel-get work-ch))
            (cond
              [(eq? name 'stop)
               (channel-put result-ch (cons worker-index #f))]
              [else
               (define status
                 (with-handlers ([exn:fail?
                                  (lambda (exn)
                                    (fprintf (current-error-port)
                                             "goal1-deps: worker ~a crashed on ~a: ~a\n"
                                             worker-index
                                             name
                                             (exn-message exn))
                                    1)])
                   (run-goal1-child/bounded! name timeout-seconds memory-mb)))
               (channel-put result-ch (cons worker-index status))
               (loop)])))))
     (thread
      (lambda ()
        (for ([name (in-list cases)])
          (channel-put work-ch name))
        (for ([_ (in-range worker-count)])
          (channel-put work-ch 'stop))))
     (let loop ([remaining (+ (length cases) worker-count)] [status 0])
       (cond
         [(zero? remaining) status]
         [else
          (match-define (cons _worker-index next-status) (channel-get result-ch))
          (loop (sub1 remaining)
                (if (and next-status (zero? status)) next-status status))]))]))

;; print-goal1-dashboard/bounded : exact-positive-integer? (or/c #f exact-positive-integer?) [#:cases (listof symbol?)] [#:jobs exact-positive-integer?] -> exact-integer?
;;   Print the Goal 1 dashboard while isolating each extraction case.
(define (print-goal1-dashboard/bounded timeout-seconds memory-mb
                                       #:cases [cases goal1-module-cases]
                                       #:jobs [jobs 1])
  (printf "Goal 1 must-have library dependency dashboard\n")
  (printf "case\textract\tcompile-to-wat\truntime\tinputs\tprimitive-demands\tmissing-primitives\townership\n")
  (flush-output)
  (run-goal1-children/bounded! cases timeout-seconds memory-mb jobs))

;; print-primitive-ownership-collisions : boolean? -> void?
;;   Print provider-owned names that still exist in the runtime primitive DB.
(define (print-primitive-ownership-collisions tsv?)
  (cond
    [tsv?
     (printf "name\townership\tprovider\tstatus\n")
     (for ([name (in-list (webify-primitive-provider-shadowed-names))])
       (printf "~a\t~a\t~a\t~a\n"
               name
               (webify-primitive-name-ownership name)
               (webify-provider-owned-primitive-provider name)
               (webify-primitive-provider-shadowed-status name)))]
    [else
     (printf "runtime-owned-but-provider-shadowed\n")
     (for ([name (in-list (webify-primitive-provider-shadowed-names))])
       (printf "~a\n" name))]))

(module+ main
  (define selected-case 'set-require)
  (define baseline-case #f)
  (define goal1? #f)
  (define goal1-compact? #f)
  (define goal1-dashboard? #f)
  (define goal1-bounded? #f)
  (define goal1-worker? #f)
  (define primitive-ownership-collisions? #f)
  (define primitive-ownership-collisions-tsv? #f)
  (define timeout-seconds 120)
  (define memory-mb 1024)
  (define goal1-limit #f)
  (define jobs 1)

  (command-line
   #:program "probe-installed-module-deps"
   #:once-each
   [("--case") name "case to extract"
               (set! selected-case (string->symbol name))]
   [("--baseline") name "optional case to diff against"
                   (set! baseline-case (string->symbol name))]
   [("--goal1") "summarize the Goal 1 module-library matrix"
                (set! goal1? #t)]
   [("--goal1-compact") "summarize the Goal 1 matrix without provider lists"
                        (set! goal1? #t)
                        (set! goal1-compact? #t)]
   [("--goal1-dashboard") "print the compact Goal 1 must-have dashboard"
                          (set! goal1-dashboard? #t)]
   [("--goal1-compact-bounded") "print the compact Goal 1 dashboard with per-case child limits"
                                (set! goal1-bounded? #t)]
   [("--goal1-worker") "internal mode: print one compact Goal 1 dependency row"
                       (set! goal1-worker? #t)]
   [("--primitive-ownership-collisions")
    "list provider-owned public names that still exist as compiler primitives"
    (set! primitive-ownership-collisions? #t)]
   [("--primitive-ownership-collisions-tsv")
    "list provider-owned public primitive collisions as TSV"
    (set! primitive-ownership-collisions? #t)
    (set! primitive-ownership-collisions-tsv? #t)]
   [("--timeout") seconds "seconds before killing a child extraction process"
                (set! timeout-seconds (string->number seconds))]
   [("--memory-mb") mb "best-effort Racket worker memory limit in MiB"
                  (set! memory-mb (string->number mb))]
   [("--jobs") n "child extraction processes to run concurrently in bounded Goal 1 modes"
             (set! jobs (max 1 (string->number n)))]
   [("--goal1-limit") n "limit Goal 1 dashboard modes to the first n cases"
                      (set! goal1-limit (string->number n))])

  (define selected-goal1-cases (select-goal1-cases goal1-limit))
  (define exit-status
    (cond
      [primitive-ownership-collisions?
       (print-primitive-ownership-collisions primitive-ownership-collisions-tsv?)
       0]
      [goal1-worker?
       (run-goal1-worker! selected-case memory-mb)
       0]
      [goal1-bounded?
       (print-goal1-dashboard/bounded timeout-seconds memory-mb
                                      #:cases selected-goal1-cases
                                      #:jobs jobs)]
      [goal1-dashboard?
       (print-goal1-dashboard #:cases selected-goal1-cases)
       0]
      [goal1?
       (print-goal1-summary #:compact? goal1-compact?
                            #:cases selected-goal1-cases)
       0]
      [else
       (define selected-inputs (extract-case-inputs selected-case))
       (print-case-summary selected-case selected-inputs)
       (when baseline-case
         (newline)
         (define baseline-inputs (extract-case-inputs baseline-case))
         (print-case-summary baseline-case baseline-inputs)
         (newline)
         (print-case-delta baseline-case baseline-inputs selected-case selected-inputs))
       0]))
  (exit exit-status))
