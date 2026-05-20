#lang racket/base

(require rackunit
         racket/list
         racket/runtime-path
         (prefix-in r: racket/set)
         (prefix-in wr: "../pkgs/webracket/set.rkt")
         (prefix-in wr-stream: "../pkgs/webracket/stream.rkt"))

(define-runtime-path webracket-set-path "../pkgs/webracket/set.rkt")

(define deferred-racket/set-exports
  '(chaperone-hash-set
    impersonate-hash-set
    set-implements/c
    set-implements?))

(define deferred-racket/set-syntax-exports
  '(define-custom-set-types
    gen:set
    make-custom-set
    make-custom-set-types
    make-mutable-custom-set
    make-weak-custom-set
    set/c))

(define allowed-webracket/set-extra-exports
  '(set-filter))

(define (phase0-value-exports module-path)
  (define-values (vals _stxs) (module->exports module-path))
  (sort (map car (cdr (assoc 0 vals))) symbol<?))

(define (phase0-syntax-exports module-path)
  (define-values (_vals stxs) (module->exports module-path))
  (sort (map car (cdr (assoc 0 stxs))) symbol<?))

(test-case "webracket/set exports racket/set minus deferred features"
  (define racket-exports
    (phase0-value-exports '(lib "racket/set.rkt")))
  (define racket-syntax-exports
    (phase0-syntax-exports '(lib "racket/set.rkt")))
  (dynamic-require webracket-set-path #f)
  (define webracket-exports
    (phase0-value-exports webracket-set-path))
  (define webracket-syntax-exports
    (phase0-syntax-exports webracket-set-path))
  (define expected
    (sort (append (remove* deferred-racket/set-exports racket-exports)
                  allowed-webracket/set-extra-exports)
          symbol<?))
  (define expected-syntax
    (remove* deferred-racket/set-syntax-exports racket-syntax-exports))
  (check-equal? webracket-exports expected)
  (check-equal? webracket-syntax-exports expected-syntax))

(test-case "constructors classify comparator and storage variants"
  (check-true (wr:set? (wr:set 1 2)))
  (check-true (wr:set-equal? (wr:set 1 2)))
  (check-true (wr:set-eq? (wr:seteq 1 2)))
  (check-true (wr:set-eqv? (wr:seteqv 1 2)))
  (check-true (wr:set-equal-always? (wr:setalw 1 2)))
  (check-true (wr:set-mutable? (wr:mutable-set 1 2)))
  (check-true (wr:set-weak? (wr:weak-set 1 2)))
  (check-false (wr:set? (wr:mutable-set 1 2)))
  (check-false (wr:set-mutable? (wr:weak-set 1 2))))

(test-case "immutable operations preserve the first set comparator"
  (define eq-a (wr:seteq 'a 'b))
  (define eq-b (wr:mutable-seteq 'b 'c))
  (define unioned (wr:set-union eq-a eq-b))
  (define intersected (wr:set-intersect eq-a eq-b))
  (define subtracted (wr:set-subtract eq-a eq-b))
  (define symmetric (wr:set-symmetric-difference eq-a eq-b))
  (for ([st (in-list (list unioned intersected subtracted symmetric))])
    (check-true (wr:set? st))
    (check-true (wr:set-eq? st)))
  (check-equal? (wr:set-count unioned) 3)
  (check-equal? (wr:set-count intersected) 1)
  (check-false (wr:set-member? subtracted 'b))
  (check-true (wr:set-member? symmetric 'a))
  (check-false (wr:set-member? symmetric 'b))
  (check-true (wr:set-member? symmetric 'c)))

(test-case "copy, clear, stream, map, foreach, and filter follow staged semantics"
  (define st (wr:set 1 2 3))
  (define copied (wr:set-copy st))
  (define cleared (wr:set-copy-clear st))
  (check-true (wr:set-mutable? copied))
  (check-true (wr:set? cleared))
  (check-equal? (wr:set-count copied) 3)
  (check-equal? (wr:set-count cleared) 0)
  (check-equal? (sort (wr-stream:stream->list (wr:set->stream st)) <)
                '(1 2 3))
  (check-equal? (sort (wr:set-map st add1) <)
                '(2 3 4))
  (define seen '())
  (check-equal? (wr:set-for-each st (lambda (x) (set! seen (cons x seen))))
                (void))
  (check-equal? (sort seen <) '(1 2 3))
  (check-equal? (wr:set-count (wr:set-filter st odd?)) 2))

(test-case "sequence adapters expose set iteration"
  (define immutable (wr:set 3 1 2))
  (define mutable (wr:mutable-seteq 'b 'a))
  (define weak (wr:weak-seteqv 9 7))
  (check-equal? (sort (for/list ([x (wr:in-set immutable)]) x) <)
                '(1 2 3))
  (check-equal? (sort (for/list ([x (wr:in-immutable-set immutable)]) x) <)
                '(1 2 3))
  (check-equal? (sort (for/list ([x (wr:in-mutable-set mutable)]) x) symbol<?)
                '(a b))
  (check-equal? (sort (for/list ([x (wr:in-weak-set weak)]) x) <)
                '(7 9))
  (check-exn exn:fail?
             (lambda () (for/list ([x (wr:in-mutable-set immutable)]) x))))

(test-case "for/set comprehensions build immutable comparator variants"
  (define equal-set
    (wr:for/set ([x (in-list '(1 2 2 3))])
      x))
  (define eq-set
    (wr:for/seteq ([x (in-list '(a b a))])
      x))
  (define eqv-set
    (wr:for/seteqv ([x (in-list '(1 2 1))])
      x))
  (define alw-set
    (wr:for/setalw ([x (in-list '(1 2 1))])
      x))
  (check-true (wr:set-equal? equal-set))
  (check-true (wr:set-eq? eq-set))
  (check-true (wr:set-eqv? eqv-set))
  (check-true (wr:set-equal-always? alw-set))
  (check-equal? (wr:set-count equal-set) 3)
  (check-equal? (wr:set-count eq-set) 2)
  (check-equal? (wr:set-count eqv-set) 2)
  (check-equal? (wr:set-count alw-set) 2)
  (check-equal? (wr:set-count
                 (wr:for*/set ([x (in-list '(1 2))]
                               [y (in-list '(10 20))])
                   (+ x y)))
                4))

(test-case "for/mutable-set and for/weak-set comprehensions build mutable variants"
  (define mutable
    (wr:for/mutable-seteq ([x (in-list '(a b a))])
      x))
  (define weak
    (wr:for/weak-seteqv ([x (in-list '(1 2 1))])
      x))
  (define mutable-product
    (wr:for*/mutable-set ([x (in-list '(1 2))]
                          [y (in-list '(10 20))])
      (+ x y)))
  (define weak-product
    (wr:for*/weak-seteq ([x (in-list '(a b))]
                         [y (in-list '(c d))])
      (string->symbol (format "~a~a" x y))))
  (check-true (wr:set-mutable? mutable))
  (check-true (wr:set-eq? mutable))
  (check-true (wr:set-weak? weak))
  (check-true (wr:set-eqv? weak))
  (check-true (wr:set-mutable? mutable-product))
  (check-true (wr:set-weak? weak-product))
  (check-equal? (wr:set-count mutable) 2)
  (check-equal? (wr:set-count weak) 2)
  (check-equal? (wr:set-count mutable-product) 4)
  (check-equal? (wr:set-count weak-product) 4))

(test-case "mutable operations mutate in place"
  (define st (wr:mutable-seteq 1 2))
  (check-equal? (wr:set-add! st 3) (void))
  (check-true (wr:set-member? st 3))
  (check-equal? (wr:set-remove! st 1) (void))
  (check-false (wr:set-member? st 1))
  (check-equal? (wr:set-union! st (wr:seteq 4 5)) (void))
  (check-equal? (wr:set-count st) 4)
  (check-equal? (wr:set-intersect! st (wr:seteq 2 4)) (void))
  (check-true (wr:set-member? st 2))
  (check-true (wr:set-member? st 4))
  (check-false (wr:set-member? st 3))
  (check-equal? (wr:set-symmetric-difference! st (wr:seteq 4 9)) (void))
  (check-false (wr:set-member? st 4))
  (check-true (wr:set-member? st 9))
  (check-equal? (wr:set-clear! st) (void))
  (check-true (wr:set-empty? st)))

(test-case "weak sets are exposed through the staged wrapper"
  (define st (wr:weak-seteq 'a 'b))
  (check-true (wr:generic-set? st))
  (check-true (wr:set-weak? st))
  (check-true (wr:set-eq? st))
  (check-equal? (wr:set-add! st 'c) (void))
  (check-true (wr:set-member? st 'c))
  (check-true (wr:set-weak? (wr:set-copy st)))
  (check-true (wr:set-weak? (wr:set-copy-clear st))))

(test-case "invalid mutation and comparator mixes fail"
  (check-exn exn:fail?
             (lambda () (wr:set-add! (wr:set 1) 2)))
  (check-exn exn:fail?
             (lambda () (wr:set-union (wr:set 1) (wr:seteq 1)))))

(module+ main
  (void))
