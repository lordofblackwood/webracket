#lang racket/base

(require rackunit
         webracket/list)

(module+ test
  (test-case "append* follows racket/list arity and behavior"
    (check-exn exn:fail? (lambda () (append*)))
    (check-equal? (append* '()) '())
    (check-equal? (append* '((a) (b c))) '(a b c))
    (check-equal? (append* '(a) '((b) (c))) '(a b c)))

  (test-case "prefix and indexed list updates"
    (check-equal? (list-set '(a b c) 1 'x) '(a x c))
    (check-equal? (list-update '(1 2 3) 1 add1) '(1 3 3))
    (check-true (list-prefix? '(1 2) '(1 2 3)))
    (check-false (list-prefix? '(1 3) '(1 2 3)))
    (let-values ([(prefix xs ys)
                  (split-common-prefix '(a b c) '(a b d e))])
      (check-equal? prefix '(a b))
      (check-equal? xs '(c))
      (check-equal? ys '(d e)))
    (check-equal? (take-common-prefix '(a b c) '(a b d)) '(a b))
    (let-values ([(xs ys) (drop-common-prefix '(a b c) '(a b d))])
      (check-equal? xs '(c))
      (check-equal? ys '(d))))

  (test-case "higher list utilities"
    (check-equal? (argmax car '((3 pears) (1 banana) (2 apples)))
                  '(3 pears))
    (check-equal? (argmin car '((3 pears) (1 banana) (2 apples)))
                  '(1 banana))
    (check-equal? (group-by (lambda (x) (modulo x 3))
                            '(1 2 1 2 54 2 5 43 7 2 643 1 2 0))
                  '((1 1 43 7 643 1) (2 2 2 5 2 2) (54 0)))
    (check-equal? (group-by (lambda (x) x)
                            '("A" "a" "b" "B")
                            (lambda (a b)
                              (equal? (string-downcase a)
                                      (string-downcase b))))
                  '(("A" "a") ("b" "B")))
    (check-equal? (cartesian-product) '(()))
    (check-equal? (cartesian-product '(1 2) '(a b))
                  '((1 a) (1 b) (2 a) (2 b)))
    (check-equal? (combinations '(a b c) 2)
                  '((a b) (a c) (b c)))
    (check-equal? (permutations '(x x))
                  '((x x) (x x))))

  (test-case "keyword-sensitive list utilities stay source-defined"
    (check-equal? (add-between '(1 2 3) 0)
                  '(1 0 2 0 3))
    (check-equal? (add-between '(1 2 3)
                               '(x)
                               #:splice? #t
                               #:before-first '(a)
                               #:before-last '(b)
                               #:after-last '(c))
                  '(a 1 x 2 b 3 c))
    (check-equal? (remove-duplicates '("A" "a" "B")
                                     string-ci=?
                                     #:key values)
                  '("A" "B"))
    (check-equal? (remove-duplicates '((1 a) (1 b) (2 c))
                                     =
                                     #:key car)
                  '((1 a) (2 c)))
    (check-equal? (check-duplicates '("A" "a" "B")
                                    string-ci=?
                                    #:key values)
                  "a")
    (check-equal? (check-duplicates '(1 2 3)
                                    #:default 'none)
                  'none)))
