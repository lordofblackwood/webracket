#lang racket

(provide runtime-helper-index)

(require "core-helper.rkt"
         (only-in "core-runtime.rkt"
                  core-runtime-helpers)
         (only-in "core/arrays.rkt"
                  array-runtime-only-helpers)
         (only-in "core/booleans.rkt"
                  boolean-runtime-only-helpers)
         (only-in "core/boxes.rkt"
                  box-runtime-only-helpers)
         (only-in "core/bytes.rkt"
                  bytes-runtime-only-helpers)
         (only-in "core/characters.rkt"
                  character-runtime-only-helpers)
         (only-in "core/checkers.rkt"
                  checker-runtime-only-helpers)
         (only-in "core/control-flow.rkt"
                  control-flow-runtime-only-helpers)
         (only-in "core/equality.rkt"
                  equality-runtime-only-helpers)
         (only-in "core/events.rkt"
                  event-runtime-only-helpers)
         (only-in "core/exceptions.rkt"
                  exception-contract-runtime-only-helpers
                  exception-runtime-only-helpers)
         (only-in "core/fasl.rkt"
                  fasl-runtime-only-helpers)
         (only-in "core/ffi.rkt"
                  ffi-runtime-only-helpers)
         (only-in "core/filesystem.rkt"
                  filesystem-runtime-only-helpers)
         (only-in "core/fixnums.rkt"
                  fixnum-runtime-only-helpers)
         (only-in "core/flonums.rkt"
                  flonum-runtime-only-helpers)
         (only-in "core/formatting.rkt"
                  formatting-runtime-only-helpers)
         (only-in "core/hashes.rkt"
                  hash-runtime-only-helpers)
         (only-in "core/i32-arrays.rkt"
                  i32-array-runtime-only-helpers)
         (only-in "core/i8-arrays.rkt"
                  i8-array-runtime-only-helpers)
         (only-in "core/immutable-hashes.rkt"
                  immutable-hash-runtime-only-helpers)
         (only-in "core/impersonators.rkt"
                  impersonator-runtime-only-helpers)
         (only-in "core/io-handlers.rkt"
                  io-handler-runtime-only-helpers)
         (only-in "core/keywords.rkt"
                  keyword-runtime-only-helpers)
         (only-in "core/linklet-instances.rkt"
                  linklet-instance-runtime-only-helpers)
         (only-in "core/linklets.rkt"
                  linklet-bootstrap-runtime-only-helpers
                  linklet-interpreter-runtime-only-helpers
                  linklet-primitive-table-initializer-runtime-only-helpers)
         (only-in "core/lists.rkt"
                  list-runtime-only-helpers)
         (only-in "core/locations.rkt"
                  location-runtime-only-helpers)
         (only-in "core/locks.rkt"
                  lock-runtime-only-helpers)
         (only-in "core/loggers.rkt"
                  logger-runtime-only-helpers)
         (only-in "core/mutable-hashes.rkt"
                  mutable-hash-runtime-only-helpers)
         (only-in "core/mlists.rkt"
                  mlist-runtime-only-helpers)
         (only-in "core/namespaces.rkt"
                  namespace-runtime-only-helpers)
         (only-in "core/numbers.rkt"
                  number-runtime-only-helpers)
         (only-in "core/parameters.rkt"
                  parameter-runtime-only-helpers)
         (only-in "core/paths.rkt"
                  path-runtime-only-helpers)
         (only-in "core/ports.rkt"
                  port-runtime-only-helpers)
         (only-in "core/procedures.rkt"
                  procedure-runtime-only-helpers)
         (only-in "core/random.rkt"
                  random-runtime-only-helpers)
         (only-in "core/reflection.rkt"
                  reflection-runtime-only-helpers)
         (only-in "core/regexps.rkt"
                  regexp-runtime-only-helpers)
         (only-in "core/security.rkt"
                  security-runtime-only-helpers)
         (only-in "core/semaphores.rkt"
                  semaphore-runtime-only-helpers)
         (only-in "core/stencil-vectors.rkt"
                  stencil-vector-runtime-only-helpers)
         (only-in "core/strings.rkt"
                  string-runtime-only-helpers)
         (only-in "core/structs.rkt"
                  struct-runtime-only-helpers)
         (only-in "core/symbols.rkt"
                  symbol-runtime-only-helpers)
         (only-in "core/syntax.rkt"
                  syntax-runtime-only-helpers)
         (only-in "core/system.rkt"
                  system-runtime-only-helpers)
         (only-in "core/threads.rkt"
                  thread-runtime-only-helpers)
         (only-in "core/time.rkt"
                  time-runtime-only-helpers)
         (only-in "core/treelists.rkt"
                  treelist-runtime-only-helpers)
         (only-in "core/unsafe.rkt"
                  unsafe-runtime-only-helpers)
         (only-in "core/vectors.rkt"
                  vector-runtime-only-helpers)
         (only-in "core/wills.rkt"
                  will-runtime-only-helpers))

;; runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate the helpers available to the monolithic runtime generator.
;; core-runtime-helper-name-set : hasheq?
;;   Index helper names already promoted to the standalone core runtime.
(define core-runtime-helper-name-set
  (for/hasheq ([helper (in-list core-runtime-helpers)])
    (values (core-runtime-helper-name helper) #t)))

;; runtime-only-minus-core : (listof core-runtime-helper?) -> (listof core-runtime-helper?)
;;   Drop runtime-only helpers that are now supplied by core-runtime-helpers.
(define (runtime-only-minus-core helpers)
  (for/list ([helper (in-list helpers)]
             #:unless (hash-ref core-runtime-helper-name-set
                                (core-runtime-helper-name helper)
                                #f))
    helper))

(define runtime-helpers
  (append core-runtime-helpers
          (runtime-only-minus-core array-runtime-only-helpers)
          (runtime-only-minus-core boolean-runtime-only-helpers)
          (runtime-only-minus-core box-runtime-only-helpers)
          (runtime-only-minus-core bytes-runtime-only-helpers)
          (runtime-only-minus-core character-runtime-only-helpers)
          (runtime-only-minus-core checker-runtime-only-helpers)
          (runtime-only-minus-core control-flow-runtime-only-helpers)
          (runtime-only-minus-core equality-runtime-only-helpers)
          (runtime-only-minus-core exception-contract-runtime-only-helpers)
          (runtime-only-minus-core exception-runtime-only-helpers)
          (runtime-only-minus-core event-runtime-only-helpers)
          (runtime-only-minus-core fasl-runtime-only-helpers)
          (runtime-only-minus-core ffi-runtime-only-helpers)
          (runtime-only-minus-core filesystem-runtime-only-helpers)
          (runtime-only-minus-core fixnum-runtime-only-helpers)
          (runtime-only-minus-core flonum-runtime-only-helpers)
          (runtime-only-minus-core formatting-runtime-only-helpers)
          (runtime-only-minus-core hash-runtime-only-helpers)
          (runtime-only-minus-core immutable-hash-runtime-only-helpers)
          (runtime-only-minus-core i32-array-runtime-only-helpers)
          (runtime-only-minus-core i8-array-runtime-only-helpers)
          (runtime-only-minus-core impersonator-runtime-only-helpers)
          (runtime-only-minus-core io-handler-runtime-only-helpers)
          (runtime-only-minus-core keyword-runtime-only-helpers)
          (runtime-only-minus-core list-runtime-only-helpers)
          (runtime-only-minus-core linklet-bootstrap-runtime-only-helpers)
          (runtime-only-minus-core linklet-interpreter-runtime-only-helpers)
          (runtime-only-minus-core linklet-primitive-table-initializer-runtime-only-helpers)
          (runtime-only-minus-core linklet-instance-runtime-only-helpers)
          (runtime-only-minus-core location-runtime-only-helpers)
          (runtime-only-minus-core lock-runtime-only-helpers)
          (runtime-only-minus-core logger-runtime-only-helpers)
          (runtime-only-minus-core mutable-hash-runtime-only-helpers)
          (runtime-only-minus-core mlist-runtime-only-helpers)
          (runtime-only-minus-core namespace-runtime-only-helpers)
          (runtime-only-minus-core number-runtime-only-helpers)
          (runtime-only-minus-core parameter-runtime-only-helpers)
          (runtime-only-minus-core path-runtime-only-helpers)
          (runtime-only-minus-core port-runtime-only-helpers)
          (runtime-only-minus-core procedure-runtime-only-helpers)
          (runtime-only-minus-core random-runtime-only-helpers)
          (runtime-only-minus-core regexp-runtime-only-helpers)
          (runtime-only-minus-core reflection-runtime-only-helpers)
          (runtime-only-minus-core security-runtime-only-helpers)
          (runtime-only-minus-core semaphore-runtime-only-helpers)
          (runtime-only-minus-core stencil-vector-runtime-only-helpers)
          (runtime-only-minus-core string-runtime-only-helpers)
          (runtime-only-minus-core struct-runtime-only-helpers)
          (runtime-only-minus-core symbol-runtime-only-helpers)
          (runtime-only-minus-core system-runtime-only-helpers)
          (runtime-only-minus-core syntax-runtime-only-helpers)
          (runtime-only-minus-core thread-runtime-only-helpers)
          (runtime-only-minus-core time-runtime-only-helpers)
          (runtime-only-minus-core treelist-runtime-only-helpers)
          (runtime-only-minus-core unsafe-runtime-only-helpers)
          (runtime-only-minus-core vector-runtime-only-helpers)
          (runtime-only-minus-core will-runtime-only-helpers)))

;; runtime-helper-index : hasheq?
;;   Index helpers available to the monolithic runtime generator.
(define runtime-helper-index
  (make-core-runtime-helper-index runtime-helpers))

(module+ test
  (require rackunit)

  ;; check-helper-name : symbol? -> void?
  ;;   Check that a representative helper resolves through the runtime index.
  (define (check-helper-name name)
    (check-eq? (core-runtime-helper-name
                (core-runtime-helper-ref runtime-helper-index name))
               name))

  (check-true (hash? runtime-helper-index))

  (for ([name (in-list '($cons $fx+ $string? $symbol?
                         $eqv?
                         $external? $impersonator? $date?
                         $hash? $mutable-hash?
                         $immutable?
                         $current-thread
                         $treelist? $stencil-vector? $current-print))])
    (check-helper-name name)))
