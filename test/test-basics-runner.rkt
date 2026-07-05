#lang racket/base

(require rackunit
         "no-stdlib-result-tree-support.rkt")

(test-case "test-basics has no false leaves"
  (check-no-stdlib-result-tree "test/test-basics.rkt"))

(test-case "test-byte-text-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-byte-text-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-byte-comparison-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-byte-comparison-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-fixnum-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-fixnum-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-number-conversion-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-number-conversion-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-string-copy-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-string-copy-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-build-string-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-build-string-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-vector-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-vector-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-string-trim-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-string-trim-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-string-comparison-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-string-comparison-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-string-constructor-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-string-constructor-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-string-index-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-string-index-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-string-misc-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-string-misc-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-lock-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-lock-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-hash-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-hash-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-character-errors has no false leaves"
  (check-no-stdlib-result-tree "test/test-character-errors.rkt"
                               #:timeout-seconds 180))

(test-case "test-hash has no false leaves"
  (check-no-stdlib-result-tree "test/test-hash.rkt"
                               #:timeout-seconds 120))

(module+ main
  (void))
