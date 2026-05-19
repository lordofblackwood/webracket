#lang racket/base

(require rackunit
         racket/list
         racket/runtime-path
         (prefix-in r: racket/set)
         (prefix-in wr: "../set.rkt")
         (prefix-in wr-stream: "../stream.rkt"))

(define-runtime-path webracket-set-path "../set.rkt")

(define deferred-racket/set-exports
  '(chaperone-hash-set
    impersonate-hash-set
    set-implements/c
    set-implements?))

(define allowed-webracket/set-extra-exports
  '(set-filter))

(define (phase0-exports module-path)
  (define-values (vals _stxs) (module->exports module-path))
  (sort (map car (cdr (assoc 0 vals))) symbol<?))

(test-case "webracket/set exports racket/set minus deferred features"
  (define racket-exports
    (phase0-exports '(lib "racket/set.rkt")))
  (dynamic-require webracket-set-path #f)
  (define webracket-exports
    (phase0-exports webracket-set-path))
  (define expected
    (sort (append (remove* deferred-racket/set-exports racket-exports)
                  allowed-webracket/set-extra-exports)
          symbol<?))
  (check-equal? webracket-exports expected))

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
