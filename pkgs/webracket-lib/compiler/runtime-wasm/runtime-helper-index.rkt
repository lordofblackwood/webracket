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
(define runtime-helpers
  (append core-runtime-helpers
          array-runtime-only-helpers
          boolean-runtime-only-helpers
          box-runtime-only-helpers
          bytes-runtime-only-helpers
          character-runtime-only-helpers
          checker-runtime-only-helpers
          control-flow-runtime-only-helpers
          equality-runtime-only-helpers
          exception-contract-runtime-only-helpers
          exception-runtime-only-helpers
          event-runtime-only-helpers
          fasl-runtime-only-helpers
          ffi-runtime-only-helpers
          filesystem-runtime-only-helpers
          fixnum-runtime-only-helpers
          flonum-runtime-only-helpers
          formatting-runtime-only-helpers
          hash-runtime-only-helpers
          immutable-hash-runtime-only-helpers
          i32-array-runtime-only-helpers
          i8-array-runtime-only-helpers
          impersonator-runtime-only-helpers
          io-handler-runtime-only-helpers
          keyword-runtime-only-helpers
          list-runtime-only-helpers
          linklet-bootstrap-runtime-only-helpers
          linklet-interpreter-runtime-only-helpers
          linklet-primitive-table-initializer-runtime-only-helpers
          linklet-instance-runtime-only-helpers
          location-runtime-only-helpers
          lock-runtime-only-helpers
          logger-runtime-only-helpers
          mutable-hash-runtime-only-helpers
          mlist-runtime-only-helpers
          namespace-runtime-only-helpers
          number-runtime-only-helpers
          parameter-runtime-only-helpers
          path-runtime-only-helpers
          port-runtime-only-helpers
          procedure-runtime-only-helpers
          random-runtime-only-helpers
          regexp-runtime-only-helpers
          reflection-runtime-only-helpers
          security-runtime-only-helpers
          semaphore-runtime-only-helpers
          stencil-vector-runtime-only-helpers
          string-runtime-only-helpers
          struct-runtime-only-helpers
          symbol-runtime-only-helpers
          system-runtime-only-helpers
          syntax-runtime-only-helpers
          thread-runtime-only-helpers
          time-runtime-only-helpers
          treelist-runtime-only-helpers
          unsafe-runtime-only-helpers
          vector-runtime-only-helpers
          will-runtime-only-helpers))

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

  (for ([name (in-list '($cons $fx+ $string? $symbol? $treelist? $stencil-vector? $current-print))])
    (check-helper-name name)))
