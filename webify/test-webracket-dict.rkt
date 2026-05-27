#lang racket/base

(require rackunit
         webracket/dict)

(module+ test
  (test-case "derived dict capability predicates"
    (check-false (dict-mutable? #hash((a . 1))))
    (check-true (dict-mutable? (make-hash '((a . 1)))))
    (check-false (dict-mutable? '#(a b)))
    (check-true (dict-mutable? (vector 'a 'b)))
    (check-true (dict-can-remove-keys? #hash((a . 1))))
    (check-false (dict-can-remove-keys? '#(a b)))
    (check-true (dict-can-remove-keys? '((a . 1))))
    (check-true (dict-can-functional-set? #hash()))
    (check-false (dict-can-functional-set? (make-hash)))
    (check-true (dict-can-functional-set? '())))

  (test-case "derived dict mutation and functional updates"
    (define h (make-hash))
    (dict-set*! h 'a 1 'b 2 'a 3)
    (check-equal? (dict-ref h 'a) 3)
    (check-equal? (dict-ref! h 'c (lambda () 4)) 4)
    (dict-update! h 'c add1)
    (check-equal? (dict-ref h 'c) 5)
    (dict-remove! h 'b)
    (check-false (dict-has-key? h 'b))
    (dict-clear! h)
    (check-true (dict-empty? h))
    (check-equal? (dict-set* #hash() 'a 1 'b 2 'a 3)
                  #hash((a . 3) (b . 2)))
    (check-equal? (dict-update #hash((a . 1)) 'a add1)
                  #hash((a . 2)))
    (check-equal? (dict-remove '((a . 1) (b . 2)) 'a)
                  '((b . 2))))

  (test-case "dict copy, clear, and map/copy"
    (define copied (dict-copy (make-hash '((a . 1)))))
    (check-true (dict-mutable? copied))
    (check-equal? (dict-clear #hash((a . 1))) #hash())
    (check-equal? (dict-clear '((a . 1))) '())
    (check-equal? (dict-map/copy #hash((a . 1) (b . 2))
                                 (lambda (k v) (values k (+ v 10))))
                  #hash((a . 11) (b . 12)))
    (check-equal? (dict-map/copy '((a . 1) (b . 2))
                                 (lambda (k v) (values k (+ v 10))))
                  '((a . 11) (b . 12)))))
