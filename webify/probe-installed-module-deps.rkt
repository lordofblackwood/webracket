#lang racket/base

(provide known-module-cases
         goal1-module-cases
         module-case-data
         extract-case-extra-reports
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

;; rename-report : webify-module-report? symbol? -> webify-module-report?
;;   Register report under an alternate dependency name for probe-time support injection.
(define (rename-report report name)
  (if (eq? name (webify-module-report-name report))
      report
      (webify-module-report
       name
       (webify-module-report-directory-keys report)
       (webify-module-report-bundle-keys report)
       (webify-module-report-bundle-entries report)
       (webify-module-report-phase0-imports report)
       (webify-module-report-phase0-exports report)
       (webify-module-report-phase0-linklet-datum report)
       (webify-module-report-manifest-ready? report)
       (cons (format "probe support provider registered as ~a" name)
             (webify-module-report-notes report)))))

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
    hash-provider-basic
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
    vector-provider-basic
    function-compose
    function-identity
    function-compose1
    function-negate
    function-const
    function-provider-basic
    keyword-procedure-predicate
    sequence-list
    sequence-range
    sequence-in-bytes
    sequence-in-hash
    sequence-in-hash-keys
    sequence-in-hash-values
    sequence-in-hash-pairs
    sequence-common-producers
    sequence-real-library-pressure
    sequence-in-indexed
    sequence-stop-before-after
    sequence-in-sequences
    sequence-in-parallel
    sequence-in-cycle
    sequence-in-values-sequence
    sequence-generate-basic
    sequence-generate-star
    sequence-generate-exhausted
    sequence-boundary-safe
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
    sequence-make-do-values
    sequence-make-do-early-next
    sequence-make-do-stop
    sequence-make-do-guards
    sequence-make-do-empty
    sequence-in-syntax
    sequence-port-edges
    sequence-append-tail
    sequence-in-value
    sequence-ref-length
    sequence-prop-sequence
    sequence-prop-gen-sequence
    sequence-prop-gen-sequence-guard
    sequence-in-parallel-values
    sequence-boundary-safe
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
    for/and-or
    for/sum-product
    for/hash-basic
    for/lists-basic
    for*/vector-basic
    for/hash-kinds
    for/final-clause
    for/control-parallel
    for*/control-nested
    for/vector-length-fill
    for/result-builders-rich
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
    class-mixin-basic
    class-object-equality
    class-reflection-basic
    class-relationships
    class-info-basic
    class-construction-basic
    class-send-forms
    class-dynamic-field-send
    class-with-method
    class-send-apply
    class-inherit-field
    class-rename-public
    class-rename-super
    class-inherit-super
    class-optional-init
    class-overment-inner
    class-augride-basic
    class-inherit-inner
    class-augment-inner
    class-private-final
    class-abstract-basic
    class-init-rest-basic
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
    list-provider-basic
    string-provider-basic
    bool-provider-basic
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
    sequence-prop-sequence
    sequence-prop-gen-sequence
    sequence-in-parallel-values
    sequence-generate-exhausted
    sequence-boundary-safe
    sequence-common-producers
    sequence-real-library-pressure
    sequence-make-do-values
    sequence-make-do-early-next
    sequence-make-do-stop
    sequence-make-do-guards
    sequence-make-do-empty
    sequence-port-edges
    for/in-list
    for/in-vector
    for/in-string
    for/in-range
    for/in-naturals
    for/parallel-sequences
    for*/nested-sequences
    for/control-clauses
    for/and-or
    for/sum-product
    for/hash-basic
    for/lists-basic
    for*/vector-basic
    for/hash-kinds
    for/final-clause
    for/control-parallel
    for*/control-nested
    for/vector-length-fill
    for/result-builders-rich
    for/list-basic
    for/fold-basic
    for*/list-basic
    for/first-basic
    match-basic
    match-literal-default
    match-let-basic
    match-predicate
    list-provider-basic
    string-provider-basic
    bool-provider-basic
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
    keyword-procedure-predicate
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
    class-mixin-basic
    class-object-equality
    class-reflection-basic
    class-relationships
    class-info-basic
    class-construction-basic
    class-send-forms
    class-dynamic-field-send
    class-with-method
    class-send-apply
    class-inherit-field
    class-rename-public
    class-rename-super
    class-inherit-super
    class-optional-init
    class-overment-inner
    class-augride-basic
    class-inherit-inner
    class-augment-inner
    class-private-final
    class-abstract-basic
    class-init-rest-basic
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
    vector-provider-basic
    function-compose
    function-identity
    function-compose1
    function-negate
    function-const
    function-provider-basic
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
    hash-provider-basic
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
    [(hash-provider-basic)
     '((module use-hash-provider-basic racket/base
         (require racket/hash)
         (provide y)
         (define h1 (hash 'a 1 'b 2))
         (define h2 (hash 'b 20 'c 3))
         (define u (hash-union h1 h2 #:combine +))
         (define i (hash-intersect h1 h2 #:combine +))
         (define f (hash-filter u (lambda (k v) (positive? v))))
         (define y
           (+ (hash-ref u 'b)
              (hash-ref i 'b)
              (hash-count f)
              -5))))]
    [(combined-list-string-set)
     '((module use-combined-list-string-set racket/base
         (require racket/list racket/string racket/set)
         (provide y)
         (define y
           (+ (first '(37 38))
              (string-length (string-join '("ab" "c") ""))
              (set-count (set 'x 'y 'y))))))]
    [(list-provider-basic)
     '((module use-list-provider-basic racket/base
         (require racket/list)
         (provide y)
         (define xs '(39 40 41))
         (define y
           (+ (first xs)
              (first (rest xs))
              (length (filter-map (lambda (x) (and (odd? x) x)) xs))
              (length (append-map (lambda (x) (list x)) '(a b)))
              -41))))]
    [(string-provider-basic)
     '((module use-string-provider-basic racket/base
         (require racket/string)
         (provide y)
         (define parts (string-split "web racket"))
         (define y
           (if (and (string-prefix? "webracket" "web")
                    (string-suffix? "webracket" "racket"))
               (+ (string-length (string-join parts "-")) 32)
               0))))]
    [(bool-provider-basic)
     '((module use-bool-provider-basic racket/base
         (require racket/bool)
         (provide y)
         (define y
           (if (and (xor #t #f)
                    (not (xor #t #t))
                    (boolean=? #t #t)
                    (not (boolean=? #t #f)))
               42
               0))))]
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
    [(keyword-procedure-predicate)
     '((module use-keyword-procedure-predicate racket/base
         (require racket/private/kw)
         (provide y)
         (define f
           (make-keyword-procedure
            (lambda (kws kw-args . args) 0)
            (lambda args 42)))
         (define y (and (procedure? f) (f)))))]
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
    [(vector-provider-basic)
     '((module use-vector-provider-basic racket/base
         (require racket/vector)
         (provide y)
         (define v (vector-map add1 '#(10 20 30)))
         (define kept (vector-filter odd? v))
         (define y
           (+ (vector-ref v 0)
              (vector-count odd? v)
              (vector-member 21 v)
              (vector-length kept)
              24))))]
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
    [(function-provider-basic)
     '((module use-function-provider-basic racket/base
         (require racket/function)
         (provide y)
         (define add10 (curry + 10))
         (define minus8 (curryr - 8))
         (define good? (conjoin number? positive?))
         (define ok? (disjoin symbol? string?))
         (define y
           (if (and (= (add10 20) 30)
                    (= (minus8 20) 12)
                    (good? 1)
                    (ok? "x"))
               42
               0))))]
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
    [(sequence-common-producers)
     '((module use-sequence-common-producers racket/base
         (require racket/sequence racket/set racket/stream)
         (provide y)
         (define bsum (for/sum ([b (in-bytes #"abc")]) b))
         (define hsum (for/sum ([(k v) (in-hash (hash 'a 10 'b 20 'c 12))]) v))
         (define set-sum (for/sum ([x (in-set (set 10 20 12))]) x))
         (define stream-sum (for/sum ([x (in-stream (stream 1 2 3))]) x))
         (define y (+ bsum hsum set-sum stream-sum))))]
    [(sequence-real-library-pressure)
     '((module use-sequence-real-library-pressure racket/base
         (require racket/sequence racket/list racket/string racket/hash racket/set)
         (provide y)
         (define evens
           (for/list ([x (filter even? (range 1 8))]) x))
         (define joined
           (string-join (for/list ([s (string-split "a bb c")]) s) ""))
         (define merged
           (hash-union (hash 'a 1) (hash 'b 2)))
         (define odds
           (for/set ([x (in-set (set 1 2 3))]
                     #:when (odd? x))
             x))
         (define y (+ (length evens)
                      (string-length joined)
                      (hash-count merged)
                      (set-count odds)
                      31))))]
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
         (define pair-seq
           (make-do-sequence
            (lambda ()
              (values (lambda (xs) (values (car xs) (* 10 (car xs))))
                      #f
                      cdr
                      '(1 2)
                      pair?
                      #f
                      #f))))
         (define-values (first next) (sequence-generate* pair-seq))
         (define-values (second done) (next))
         (define-values (third _done-again) (done))
         (define y (+ (car first)
                      (cadr first)
                      (car second)
                      (cadr second)
                      (if third 100 0)))))]
    [(sequence-generate-exhausted)
     '((module use-sequence-generate-exhausted racket/base
         (require racket/sequence)
         (provide y)
         (define-values (more? get) (sequence-generate '(1)))
         (get)
         (define y (if (more?) 0 42))))]
    [(sequence-boundary-safe)
     '((module use-sequence-boundary-safe racket/base
         (provide y)
         (define y
           (+ (length (for/list ([x (in-vector (vector) 0 0)]) x))
              (vector-ref (for/vector #:length 3 ([x (in-range 0 10 0)]) x) 2)))))]
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
    [(sequence-make-do-values)
     '((module use-sequence-make-do-values racket/base
         (require racket/sequence)
         (provide y)
         (define seq
           (make-do-sequence
            (lambda ()
              (values (lambda (xs) (values (car xs) (* 10 (car xs))))
                      cdr
                      '(1 2 3)
                      pair?
                      #f
                      #f))))
         (define y (for/sum ([(x y) seq]) (+ x y)))))]
    [(sequence-make-do-early-next)
     '((module use-sequence-make-do-early-next racket/base
         (require racket/sequence)
         (provide y)
         (define seq
           (make-do-sequence
            (lambda ()
              (values car
                      cdr
                      values
                      '(10 20 12)
                      pair?
                      #f
                      #f))))
         (define-values (more? next) (sequence-generate seq))
         (define y (+ (if (more?) (next) 0)
                      (if (more?) (next) 0)
                      (if (more?) (next) 0)))))]
    [(sequence-make-do-stop)
     '((module use-sequence-make-do-stop racket/base
         (require racket/sequence)
         (provide y)
         (define seq
           (make-do-sequence
            (lambda ()
              (values car
                      cdr
                      '(1 2 3 4)
                      pair?
                      #f
                      (lambda (xs v) (< v 3))))))
         (define y (length (sequence->list seq)))))]
    [(sequence-make-do-guards)
     '((module use-sequence-make-do-guards racket/base
         (require racket/sequence)
         (provide y)
         (define guarded
           (make-do-sequence
            (lambda ()
              (values car cdr '(1 2 3 4 5) pair? (lambda (v) (< v 4)) #f))))
         (define multi-init
           (make-do-sequence
            (lambda ()
              (values (lambda (p) (+ (car p) (cdr p)))
                      (lambda (p) (cons (+ (car p) 1) (cdr p)))
                      (cons 0 10)
                      (lambda (p) (< (car p) 3))
                      #f
                      #f))))
         (define y (+ (length (for/list ([x guarded]) x))
                      (for/fold ([sum 0]) ([x multi-init]) (+ sum x))
                      6))))]
    [(sequence-make-do-empty)
     '((module use-sequence-make-do-empty racket/base
         (require racket/sequence)
         (provide y)
         (define empty-seq
           (make-do-sequence
            (lambda ()
              (values car cdr null pair? #f #f))))
         (define y (length (sequence->list empty-seq)))))]
    [(sequence-in-syntax)
     '((module use-sequence-in-syntax racket/base
         (require racket/sequence)
         (provide y)
         (define y (length (for/list ([x (in-syntax #'(1 2 3))]) x)))))]
    [(sequence-port-edges)
     '((module use-sequence-port-edges racket/base
         (require racket/sequence)
         (provide y)
         (define empty-lines
           (length (for/list ([line (in-lines (open-input-string ""))]) line)))
         (define trailing-lines
           (length (for/list ([line (in-lines (open-input-string "a\n"))]) line)))
         (define two-lines
           (length (for/list ([line (in-lines (open-input-string "a\nb"))]) line)))
         (define bytes-lines
           (length (for/list ([bs (in-bytes-lines (open-input-string "a\n"))]) bs)))
         (define byte-sum
           (for/sum ([b (in-input-port-bytes (open-input-bytes #"AZ"))]) b))
         (define y (+ empty-lines trailing-lines two-lines bytes-lines byte-sum -117))))]
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
    [(sequence-prop-sequence)
     '((module use-sequence-prop-sequence racket/base
         (require racket/sequence)
         (provide y)
         (struct seqbox (xs)
           #:property prop:sequence
           (lambda (self) (seqbox-xs self)))
         (define y (for/fold ([sum 0]) ([x (seqbox '(10 20 12))]) (+ sum x)))))]
    [(sequence-prop-gen-sequence)
     '((module use-sequence-prop-gen-sequence racket/base
         (require racket/sequence)
         (provide y)
         (struct seqbox (xs)
           #:property prop:gen-sequence
           (lambda (self)
             (define xs (seqbox-xs self))
             (values (lambda (pos) (values (car pos) (* 10 (car pos))))
                     #f
                     cdr
                     xs
                     pair?
                     #f
                     #f)))
         (define y (for/sum ([(x y) (seqbox '(1 2 3))]) (+ x y)))))]
    [(sequence-prop-gen-sequence-guard)
     '((module use-sequence-prop-gen-sequence-guard racket/base
         (require racket/sequence)
         (provide y)
         (struct bad-seq (xs)
           #:property prop:gen-sequence
           42)
         (define y 0)))]
    [(sequence-in-parallel-values)
     '((module use-sequence-in-parallel-values racket/base
         (require racket/sequence)
         (provide y)
         (define y
           (for/sum ([(x y z) (in-parallel-values
                               2
                               (in-parallel (list 1 2) (list 10 20))
                               1
                               (list 100 200))])
             (+ x y z)))))]
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
    [(for/and-or)
     '((module use-for-and-or racket/base
         (provide y)
         (define y
           (+ (if (for/and ([x (in-list '(2 4 6))]) (even? x)) 10 0)
              (if (for/or ([x (in-list '(1 3 4))]) (even? x)) 20 0)))))]
    [(for/sum-product)
     '((module use-for-sum-product racket/base
         (provide y)
         (define y
           (+ (for/sum ([x (in-list '(1 2 3))]) x)
              (for/product ([x (in-list '(2 3 4))]) x)))))]
    [(for/hash-basic)
     '((module use-for-hash-basic racket/base
         (provide y)
         (define ht
           (for/hash ([x (in-list '(1 2 3))])
             (values x (* x 10))))
         (define y (+ (hash-count ht) (hash-ref ht 2)))))]
    [(for/lists-basic)
     '((module use-for-lists-basic racket/base
         (provide y)
         (define-values (xs ys)
           (for/lists (xs ys) ([x (in-list '(1 2 3))])
             (values x (* x 10))))
         (define y (+ (length xs) (length ys) (car xs) (car ys)))))]
    [(for*/vector-basic)
     '((module use-for-star-vector-basic racket/base
         (provide y)
         (define y
           (vector-length
            (for*/vector ([x (in-list '(a b))]
                          [y (in-list '(1 2))])
              (list x y))))))]
    [(for/hash-kinds)
     '((module use-for-hash-kinds racket/base
         (provide y)
         (define ht-eq
           (for/hasheq ([x (in-list '(a b))])
             (values x 10)))
         (define ht-eqv
           (for/hasheqv ([x (in-list '(1 2))])
             (values x (* x 10))))
         (define ht-alw
           (for/hashalw ([x (in-list '(a b))])
             (values (string->symbol (symbol->string x)) 3)))
         (define y (+ (hash-ref ht-eq 'a)
                      (hash-ref ht-eqv 2)
                      (hash-ref ht-alw 'a)))))]
    [(for/final-clause)
     '((module use-for-final-clause racket/base
         (provide y)
         (define y
           (for/sum ([x (in-list '(1 2 3 4 5))]
                     #:when (odd? x)
                     #:final (= x 3))
             x))))]
    [(for/control-parallel)
     '((module use-for-control-parallel racket/base
         (provide y)
         (define y
           (for/sum ([x (in-list '(1 2 3))]
                     [y (in-list '(10 20 30))]
                     #:when (odd? x)
                     #:unless (= y 10)
                     #:break (> y 20))
             (+ x y)))))]
    [(for*/control-nested)
     '((module use-for-star-control-nested racket/base
         (provide y)
         (define y
           (for/sum ([x (in-list '(1 2))]
                     #:when #t
                     [y (in-list '(10 20 30))]
                     #:final (= y 20))
             (+ x y)))))]
    [(for/vector-length-fill)
     '((module use-for-vector-length-fill racket/base
         (provide y)
         (define v-short
           (for/vector #:length 2 ([x (in-list '(10 20 30))]) x))
         (define v-fill
           (for/vector #:length 4 #:fill 9 ([x (in-list '(1 2))]) x))
         (define y (+ (vector-length v-short)
                      (vector-ref v-short 1)
                      (vector-ref v-fill 3)))))]
    [(for/result-builders-rich)
     '((module use-for-result-builders-rich racket/base
         (provide y)
         (define h1
           (for/hasheq ([x (in-list '(a b))])
             (values x 1)))
         (define h2
           (for/hasheqv ([x (in-list '(1 2))])
             (values x (* x 10))))
         (define h3
           (for/hashalw ([x (in-list '(a b))])
             (values (string->symbol (symbol->string x)) 4)))
         (define first-v
           (for/first ([x (in-list '(#f 41 42))]
                       #:when x)
             x))
         (define last-v
           (for/last ([x (in-list '(10 20 12))])
             x))
         (define y
           (+ (hash-count h1)
              (hash-ref h1 'a)
              (hash-ref h2 2)
              (hash-ref h3 'a)
              first-v
              last-v
              (if (for/and ([x (in-list '(2 4 6))]) (even? x)) 10 0)
              (if (for/or ([x (in-list '(1 3 4))]) (even? x)) 20 0)))))]
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
    [(class-mixin-basic)
     '((module use-class-mixin-basic racket/base
         (require racket/class)
         (provide y)
         (define value<%> (interface () value))
         (define base%
           (class* object% (value<%>)
             (super-new)
             (define/public (value) 40)))
         (define add-two-mixin
           (mixin (value<%>) ()
             (super-new)
             (define/override (value) (+ (super value) 2))))
         (define child% (add-two-mixin base%))
         (define y (send (new child%) value))))]
    [(class-object-equality)
     '((module use-class-object-equality racket/base
         (require racket/class)
         (provide y)
         (define a (new object%))
         (define b (new object%))
         (define y
           (if (and (object=? a a)
                    (not (object=? a b))
                    (object-or-false=? #f #f)
                    (not (object-or-false=? a #f)))
               42
               0))))]
    [(class-reflection-basic)
     '((module use-class-reflection-basic racket/base
         (require racket/class)
         (provide y)
         (define value<%> (interface () value adjust))
         (define value%
           (class* object% (value<%>)
             (super-new)
             (field [x 40] [y 2])
             (define/public (value) (+ x y))
             (define/public (adjust n [delta 0]) (+ n delta))))
         (define obj (new value%))
         (define methods (interface->method-names value<%>))
         (define fields (field-names obj))
         (define y
           (if (and (interface? (class->interface value%))
                    (interface? (object-interface obj))
                    (method-in-interface? 'value value<%>)
                    (method-in-interface? 'adjust value<%>)
                    (memq 'value methods)
                    (memq 'adjust methods)
                    (memq 'x fields)
                    (memq 'y fields)
                    (vector? (object->vector obj))
                    (object-method-arity-includes? obj 'adjust 1)
                    (object-method-arity-includes? obj 'adjust 2)
                    (not (object-method-arity-includes? obj 'adjust 3)))
               42
               0))))]
    [(class-relationships)
     '((module use-class-relationships racket/base
         (require racket/class)
         (provide y)
         (define a<%> (interface () a))
         (define b<%> (interface (a<%>) b))
         (define base%
           (class* object% (a<%>)
             (super-new)
             (define/public (a) 40)))
         (define child%
           (class* base% (b<%>)
             (super-new)
             (define/public (b) 2)))
         (define y
           (if (and (subclass? child% base%)
                    (subclass? base% object%)
                    (not (subclass? base% child%))
                    (implementation? child% a<%>)
                    (implementation? child% b<%>)
                    (not (implementation? object% a<%>))
                    (interface-extension? b<%> a<%>)
                    (not (interface-extension? a<%> b<%>)))
               42
               0))))]
    [(class-info-basic)
     '((module use-class-info-basic racket/base
         (require racket/class)
         (provide y)
         (define point%
           (class object%
             (inspect #f)
             (super-new)
             (field [x 40] [y 2])))
         (define obj (new point%))
         (define-values (cls skipped?) (object-info obj))
         (define-values (name field-cnt field-name-list field-ref field-set!
                              super-class skipped-super?)
           (class-info point%))
         (field-set! obj 0 41)
         (define y
           (if (and (class? cls)
                    (not skipped?)
                    (eq? name 'point%)
                    (= field-cnt 2)
                    (memq 'x field-name-list)
                    (memq 'y field-name-list)
                    (= (field-ref obj 0) 41)
                    (= (field-ref obj 1) 2)
                    (not super-class)
                    skipped-super?)
               (- (+ (field-ref obj 0) (field-ref obj 1)) 1)
               0))))]
    [(class-construction-basic)
     '((module use-class-construction-basic racket/base
         (require racket/class)
         (provide y)
         (define point%
           (class object%
             (super-new)
             (init-field x y)
             (define/public (sum) (+ x y))))
         (define a (make-object point% 40 2))
         (define b (instantiate point% (41) [y 1]))
         (define c (dynamic-instantiate point% '(39) '([y . 3])))
         (define y (+ (send a sum) (send b sum) (send c sum)))))]
    [(class-send-forms)
     '((module use-class-send-forms racket/base
         (require racket/class)
         (provide y)
         (define box%
           (class object%
             (super-new)
             (field [n 0])
             (define/public (add! x) (set! n (+ n x)))
             (define/public (value) n)))
         (define b (new box%))
         (send* b (add! 20) (add! 22))
         (define point%
           (class object%
             (super-new)
             (init-field [x 0] [y 0])
             (define/public (move-x dx) (new point% [x (+ x dx)] [y y]))
             (define/public (move-y dy) (new point% [x x] [y (+ y dy)]))
             (define/public (sum) (+ x y))))
         (define y
           (+ (send b value)
              (send+ (new point%)
                     (move-x 19)
                     (move-y 23)
                     (sum))))))]
    [(class-dynamic-field-send)
     '((module use-class-dynamic-field-send racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)
             (field [n 10])
             (define/public (add x) (+ n x))))
         (define obj (new counter%))
         (define get-n (class-field-accessor counter% n))
         (define set-n! (class-field-mutator counter% n))
         (dynamic-set-field! 'n obj 40)
         (define a (dynamic-get-field 'n obj))
         (set-n! obj 41)
         (define b (get-n obj))
         (define c (dynamic-send obj 'add 1))
         (define d (if (field-bound? n obj) 0 1000))
         (define y (+ a b c d))))]
    [(class-with-method)
     '((module use-class-with-method racket/base
         (require racket/class)
         (provide y)
         (define stack%
           (class object%
             (super-new)
             (field [xs null])
             (define/public (push! x) (set! xs (cons x xs)))
             (define/public (pop!)
               (define x (car xs))
               (set! xs (cdr xs))
               x)))
         (define s (new stack%))
         (define y
           (with-method ([push (s push!)]
                         [pop (s pop!)])
             (push 40)
             (push 42)
             (pop)))))]
    [(class-send-apply)
     '((module use-class-send-apply racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)
             (define/public (sum a b c) (+ a b c))
             (define/public (kw #:x x #:y y z) (+ x y z))))
         (define obj (new counter%))
         (define a (send/apply obj sum 10 '(11 21)))
         (define b (send/keyword-apply obj kw '(#:x #:y) '(10 20) 12 null))
         (define y (+ a b))))]
    [(class-inherit-field)
     '((module use-class-inherit-field racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (field [n 40])
             (define/public (value) n)))
         (define child%
           (class base%
             (super-new)
             (inherit-field n)
             (set! n (+ n 2))))
         (define y (send (new child%) value))))]
    [(class-rename-public)
     '((module use-class-rename-public racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)
             (define (raw-value) 42)
             (public [raw-value value])))
         (define y (send (new counter%) value))))]
    [(class-rename-super)
     '((module use-class-rename-super racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/public (value) 40)))
         (define child%
           (class base%
             (super-new)
             (rename-super [base-value value])
             (define/override (value) (+ (base-value) 2))))
         (define y (send (new child%) value))))]
    [(class-inherit-super)
     '((module use-class-inherit-super racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/public (value) 40)))
         (define child%
           (class base%
             (super-new)
             (inherit/super value)
             (define/public (next) (+ (super value) 2))))
         (define y (send (new child%) next))))]
    [(class-optional-init)
     '((module use-class-optional-init racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (init [n 40])
             (super-new)
             (define saved n)
             (define/public (value) saved)))
         (define y (+ (send (new counter%) value)
                      (send (new counter% [n 2]) value)))))]
    [(class-overment-inner)
     '((module use-class-overment-inner racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/public (value n) n)))
         (define child%
           (class base%
             (super-new)
             (define/overment (value n) (+ 1 n (inner 0 value n)))))
         (define grand%
           (class child%
             (super-new)
             (define/augment (value n) 1)))
         (define y (send (new grand%) value 40))))]
    [(class-augride-basic)
     '((module use-class-augride-basic racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/pubment (value n) (+ n (inner 0 value n)))))
         (define child%
           (class base%
             (super-new)
             (define/augride (value n) 2)))
         (define y (send (new child%) value 40))))]
    [(class-inherit-inner)
     '((module use-class-inherit-inner racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/pubment (value n) (+ n (inner 0 value n)))))
         (define child%
           (class base%
             (super-new)
             (inherit/inner value)
             (define/public (next) (+ (value 38) (inner 0 value 0)))))
         (define grand%
           (class child%
             (super-new)
             (define/augment (value n) 2)))
         (define y (send (new grand%) next))))]
    [(class-augment-inner)
     '((module use-class-augment-inner racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (define/pubment (value n)
               (+ n (inner 0 value n)))))
         (define child%
           (class base%
             (super-new)
             (define/augment (value n) 2)))
         (define y (send (new child%) value 40))))]
    [(class-private-final)
     '((module use-class-private-final racket/base
         (require racket/class)
         (provide y)
         (define counter%
           (class object%
             (super-new)
             (define n 40)
             (define (inc!) (set! n (+ n 2)))
             (private inc!)
             (define/public-final (value)
               (inc!)
               n)))
         (define y (send (new counter%) value))))]
    [(class-abstract-basic)
     '((module use-class-abstract-basic racket/base
         (require racket/class)
         (provide y)
         (define base%
           (class object%
             (super-new)
             (abstract amount)
             (define/public (value) (+ 2 (amount)))))
         (define child%
           (class base%
             (super-new)
             (define/override (amount) 40)))
         (define y (send (new child%) value))))]
    [(class-init-rest-basic)
     '((module use-class-init-rest-basic racket/base
         (require racket/class)
         (provide y)
         (define basket%
           (class object%
             (super-new)
             (init-rest fruits)
             (define saved fruits)
             (define/public (count) (length saved))))
         (define y (send (make-object basket% 'kiwi 'lychee 'melon) count))))]
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
(define (extract-case-extra-reports name)
  (if (regexp-match? #rx"^class-" (symbol->string name))
      (list webify-module-protocol-report
            (webify-module-path->report 'webracket/contract)
            (webify-module-path->report 'webracket/unsafe/undefined)
            (rename-report
             (webify-module-path->report 'webracket/unsafe/undefined)
             'racket/unsafe/undefined))
      (list webify-module-protocol-report)))

;; extract-case-inputs : symbol? -> (listof webify-module-linklet-input?)
;;   Extract the demand-sliced installed provider graph for one case.
(define (extract-case-inputs name)
  (webify-source-modules->discovered-resolved-linklet-inputs
   (module-case-data name)
   #:extra-reports (extract-case-extra-reports name)
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
