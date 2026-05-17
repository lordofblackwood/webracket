#lang racket/base

(require rackunit
         "../racket-src/expander/syntax/taint-object.rkt")

(test-case "syntax taint markers distinguish clean and tainted states"
  (check-true (taint? #f))
  (check-true (taint? 'tainted))
  (check-true (taint? 'tainted/need-propagate))
  (check-false (taint? 42)))

(test-case "compound datum content needs taint propagation"
  (check-equal? (tainted-for-content '(a b)) 'tainted/need-propagate)
  (check-equal? (tainted-for-content '#(a b)) 'tainted/need-propagate)
  (check-equal? (tainted-for-content 'a) 'tainted)
  (check-equal? (tainted-for-content 42) 'tainted))

(test-case "propagating taint clears the propagation-needed marker"
  (check-true (taint-needs-propagate? 'tainted/need-propagate))
  (check-false (taint-needs-propagate? 'tainted))
  (check-equal? (taint-propagated 'tainted/need-propagate) 'tainted)
  (check-equal? (taint-propagated 'tainted) 'tainted)
  (check-false (taint-propagated #f)))

(module+ main
  (void))
