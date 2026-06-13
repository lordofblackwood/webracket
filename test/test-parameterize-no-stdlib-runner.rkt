#lang racket/base

(require rackunit
         "no-stdlib-result-tree-support.rkt")

(test-case "test-parameterize-no-stdlib has no false leaves"
  (check-no-stdlib-result-tree "test/test-parameterize-no-stdlib.rkt"))

(module+ main
  (void))
