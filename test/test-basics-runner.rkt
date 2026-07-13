#lang racket/base

(require rackunit
         "no-stdlib-result-tree-support.rkt")

;; Slow-runner selection knobs:
;;   WEBRACKET_TEST_BASICS_PART=result-tree|fixtures|all
;;   WEBRACKET_RESULT_TREE_CHUNKS=1,3-5
;;   WEBRACKET_RESULT_TREE_SHARD=1/4
;;   WEBRACKET_RESULT_TREE_CHUNK_JOBS=2
;;   WEBRACKET_FIXTURE_CHUNKS=1-4
;;   WEBRACKET_FIXTURE_SHARD=2/4
;;   WEBRACKET_FIXTURE_JOBS=4

;; test-basics-part : -> symbol?
;;   Return which part of the slow cadence runner to execute.
(define (test-basics-part)
  (define raw (getenv "WEBRACKET_TEST_BASICS_PART"))
  (define part (if raw (string-downcase raw) "all"))
  (cond
    [(member part '("all" "both")) 'all]
    [(member part '("result-tree" "tree" "chunks")) 'result-tree]
    [(member part '("fixtures" "fixture")) 'fixtures]
    [else
     (error 'test-basics-part
            "expected all, result-tree, or fixtures; got: ~a"
            raw)]))

(define selected-part (test-basics-part))

(when (memq selected-part '(all result-tree))
  (test-case "test-basics has no false leaves"
    (check-no-stdlib-result-tree/chunked
     "test/test-basics.rkt"
     #:timeout-seconds 240
     #:jobs (env-positive-integer/default
             "WEBRACKET_RESULT_TREE_CHUNK_JOBS"
             1)
     #:chunk-spec (getenv "WEBRACKET_RESULT_TREE_CHUNKS")
     #:shard-spec (getenv "WEBRACKET_RESULT_TREE_SHARD"))))

(define focused-fixtures
  (list
   (make-no-stdlib-result-tree-fixture "test/test-byte-text-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-comparison-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-index-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-value-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-byte-sequence-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-fixnum-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-flonum-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-number-conversion-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-numeric-range-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-random-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-box-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-string-copy-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-build-string-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-vector-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-stencil-vector-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-struct-errors.rkt"
                                       #:timeout-seconds 240)
   (make-no-stdlib-result-tree-fixture "test/test-treelist-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-list-errors.rkt")
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
   (make-no-stdlib-result-tree-fixture "test/test-regexp-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-misc-primitive-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-logger-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-time-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-control-flow-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-sequence-checker-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-security-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-exception-handler-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-procedure-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-linklet-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-parameterization-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-impersonator-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-ffi-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-values-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-port-input-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-port-output-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-lock-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-will-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-system-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-hash-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-character-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-event-sync-errors.rkt")
   (make-no-stdlib-result-tree-fixture "test/test-hash.rkt"
                                       #:timeout-seconds 240)))

;; selected-focused-fixtures : -> (listof no-stdlib-result-tree-fixture?)
;;   Return focused fixtures selected by optional index/range or K/N shard env vars.
(define (selected-focused-fixtures)
  (map cdr
       (select-indexed-items focused-fixtures
                             #:index-spec (getenv "WEBRACKET_FIXTURE_CHUNKS")
                             #:shard-spec (getenv "WEBRACKET_FIXTURE_SHARD"))))

(when (memq selected-part '(all fixtures))
  (test-case "focused no-stdlib result-tree fixtures have no false leaves"
    (define fixtures (selected-focused-fixtures))
    (when (null? fixtures)
      (fail "selected no focused fixtures"))
    (check-no-stdlib-result-tree-fixtures/parallel
     fixtures
     #:jobs (env-positive-integer/default "WEBRACKET_FIXTURE_JOBS" 4))))

(module+ main
  (void))
