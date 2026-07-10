#lang racket/base

(require rackunit
         "no-stdlib-result-tree-support.rkt")

(test-case "test-basics has no false leaves"
  (check-no-stdlib-result-tree/chunked "test/test-basics.rkt"
                                       #:timeout-seconds 240))

(define focused-fixtures
  (list
   (make-no-stdlib-result-tree-fixture "test/test-byte-text-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-comparison-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-index-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-value-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-sequence-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-fixnum-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-number-conversion-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-numeric-range-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-copy-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-build-string-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-vector-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-stencil-vector-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-struct-errors.rkt"
                                       #:timeout-seconds 240)
   (make-no-stdlib-result-tree-fixture "test/test-treelist-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-trim-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-comparison-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-constructor-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-index-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-misc-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-range-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-path-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-filesystem-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-reflection-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-format-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-misc-primitive-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-exception-handler-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-procedure-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-ffi-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-values-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-port-input-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-port-output-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-lock-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-hash-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-character-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-event-sync-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-hash.rkt"
                                       #:timeout-seconds 120)))

;; fixture-jobs : -> exact-positive-integer?
;;   Return the requested fixture parallelism, defaulting to four workers.
(define (fixture-jobs)
  (define raw (getenv "WEBRACKET_FIXTURE_JOBS"))
  (define n (and raw (string->number raw)))
  (if (and (exact-integer? n) (positive? n))
      n
      4))

(test-case "focused no-stdlib result-tree fixtures have no false leaves"
  (check-no-stdlib-result-tree-fixtures/parallel focused-fixtures
                                                 #:jobs (fixture-jobs)))

(module+ main
  (void))
