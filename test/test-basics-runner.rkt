#lang racket/base

(require rackunit
         "no-stdlib-result-tree-support.rkt")

(test-case "test-basics has no false leaves"
  (check-no-stdlib-result-tree "test/test-basics.rkt"))

(test-case "test-byte-text-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-byte-text-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-fixnum-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-fixnum-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-character-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-character-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-hash has no false leaves"
  (check-no-stdlib-result-tree "test/test-hash.rkt"
                               #:timeout-seconds 120))

(module+ main
  (void))
