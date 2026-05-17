#lang racket/base

(require rackunit
         "../racket-src/expander/syntax/weaker-inspector.rkt")

(test-case "weaker-inspector preserves equal, false, and superior relations"
  (define root       (current-code-inspector))
  (define child      (make-inspector root))
  (define grandchild (make-inspector child))
  (check-eq? (weaker-inspector root root) root)
  (check-false (weaker-inspector #f root))
  (check-false (weaker-inspector root #f))
  (check-eq? (weaker-inspector root child) child)
  (check-eq? (weaker-inspector child root) child)
  (check-eq? (weaker-inspector root grandchild) grandchild)
  (check-eq? (weaker-inspector child grandchild) grandchild))

(module+ main
  (void))
