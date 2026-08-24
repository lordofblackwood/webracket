#lang racket

(provide core-runtime-string-constants)

(require (only-in "booleans.rkt"
                  boolean-runtime-string-constants)
         (only-in "bignums.rkt"
                  bignum-runtime-string-constants)
         (only-in "boxes.rkt"
                  box-runtime-string-constants)
         (only-in "bytes.rkt"
                  bytes-runtime-string-constants)
         (only-in "characters.rkt"
                  character-runtime-string-constants)
         (only-in "checkers.rkt"
                  checker-runtime-string-constants)
         (only-in "control-flow.rkt"
                  control-flow-runtime-string-constants)
         (only-in "events.rkt"
                  event-runtime-string-constants)
         (only-in "exceptions.rkt"
                  exception-runtime-string-constants)
         (only-in "fasl.rkt"
                  fasl-runtime-string-constants)
         (only-in "ffi.rkt"
                  ffi-runtime-string-constants)
         (only-in "filesystem.rkt"
                  filesystem-runtime-string-constants)
         (only-in "fixnums.rkt"
                  fixnum-runtime-string-constants)
         (only-in "flonums.rkt"
                  flonum-runtime-string-constants)
         (only-in "formatting.rkt"
                  printer-prefix-formatting-runtime-string-constants
                  immediate-value-formatting-runtime-string-constants
                  opaque-value-formatting-runtime-string-constants
                  character-notation-formatting-runtime-string-constants
                  arrow-formatting-runtime-string-constants
                  hash-less-formatting-runtime-string-constants
                  formatting-runtime-string-constants
                  struct-type-property-formatting-runtime-string-constants)
         (only-in "hashes.rkt"
                  hash-runtime-string-constants)
         (only-in "immutable-hashes.rkt"
                  immutable-hash-runtime-string-constants)
         (only-in "impersonators.rkt"
                  impersonator-runtime-string-constants)
         (only-in "io-handlers.rkt"
                  io-handler-runtime-string-constants)
         (only-in "keywords.rkt"
                  keyword-runtime-string-constants)
         (only-in "linklet-instances.rkt"
                  linklet-instance-runtime-string-constants)
         (only-in "linklets.rkt"
                  linklet-runtime-string-constants)
         (only-in "locks.rkt"
                  lock-runtime-string-constants)
         (only-in "lists.rkt"
                  list-runtime-string-constants)
         (only-in "locations.rkt"
                  location-runtime-string-constants)
         (only-in "loggers.rkt"
                  logger-runtime-string-constants)
         (only-in "mlists.rkt"
                  mlist-runtime-string-constants)
         (only-in "namespaces.rkt"
                  namespace-runtime-string-constants)
         (only-in "numbers.rkt"
                  number-runtime-string-constants)
         (only-in "parameters.rkt"
                  parameter-runtime-string-constants)
         (only-in "paths.rkt"
                  path-runtime-string-constants)
         (only-in "ports.rkt"
                  port-predicate-runtime-string-constants
                  port-event-runtime-string-constants
                  port-output-runtime-string-constants
                  port-closed-error-runtime-string-constants)
         (only-in "procedures.rkt"
                  procedure-runtime-string-constants)
         (only-in "random.rkt"
                  random-runtime-string-constants)
         (only-in "reflection.rkt"
                  reflection-runtime-string-constants)
         (only-in "regexps.rkt"
                  regexp-runtime-string-constants)
         (only-in "security.rkt"
                  security-runtime-string-constants)
         (only-in "semaphores.rkt"
                  semaphore-runtime-string-constants)
         (only-in "stencil-vectors.rkt"
                  stencil-vector-runtime-string-constants)
         (only-in "strings.rkt"
                  string-runtime-string-constants)
         (only-in "structs.rkt"
                  struct-runtime-string-constants)
         (only-in "symbols.rkt"
                  symbol-runtime-string-constants)
         (only-in "syntax.rkt"
                  syntax-runtime-string-constants)
         (only-in "system.rkt"
                  system-runtime-string-constants)
         (only-in "threads.rkt"
                  thread-runtime-string-constants)
         (only-in "time.rkt"
                  time-runtime-string-constants)
         (only-in "treelists.rkt"
                  treelist-runtime-string-constants)
         (only-in "vectors.rkt"
                  vector-runtime-string-constants)
         (only-in "wills.rkt"
                  will-runtime-string-constants))

;; core-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare all domain-owned runtime string constants in assembly order.
(define core-runtime-string-constants
  (append printer-prefix-formatting-runtime-string-constants
          immediate-value-formatting-runtime-string-constants
          opaque-value-formatting-runtime-string-constants
          character-runtime-string-constants
          string-runtime-string-constants
          symbol-runtime-string-constants
          boolean-runtime-string-constants
          namespace-runtime-string-constants
          regexp-runtime-string-constants
          struct-runtime-string-constants
          formatting-runtime-string-constants
          character-notation-formatting-runtime-string-constants
          arrow-formatting-runtime-string-constants
          hash-less-formatting-runtime-string-constants
          struct-type-property-formatting-runtime-string-constants
          procedure-runtime-string-constants
          keyword-runtime-string-constants
          list-runtime-string-constants
          bignum-runtime-string-constants
          fixnum-runtime-string-constants
          flonum-runtime-string-constants
          bytes-runtime-string-constants
          vector-runtime-string-constants
          stencil-vector-runtime-string-constants
          box-runtime-string-constants
          immutable-hash-runtime-string-constants
          port-predicate-runtime-string-constants
          port-output-runtime-string-constants
          io-handler-runtime-string-constants
          port-event-runtime-string-constants
          parameter-runtime-string-constants
          random-runtime-string-constants
          impersonator-runtime-string-constants
          security-runtime-string-constants
          mlist-runtime-string-constants
          number-runtime-string-constants
          semaphore-runtime-string-constants
          event-runtime-string-constants
          will-runtime-string-constants
          thread-runtime-string-constants
          exception-runtime-string-constants
          fasl-runtime-string-constants
          port-closed-error-runtime-string-constants
          filesystem-runtime-string-constants
          path-runtime-string-constants
          time-runtime-string-constants
          system-runtime-string-constants
          ffi-runtime-string-constants
          location-runtime-string-constants
          treelist-runtime-string-constants
          checker-runtime-string-constants
          syntax-runtime-string-constants
          hash-runtime-string-constants
          control-flow-runtime-string-constants
          lock-runtime-string-constants
          linklet-instance-runtime-string-constants
          linklet-runtime-string-constants
          logger-runtime-string-constants
          reflection-runtime-string-constants))

(module+ test
  (require rackunit)

  (check-not-false (assoc 'empty core-runtime-string-constants))
  (check-not-false (assoc 'symbol? core-runtime-string-constants))
  (check-not-false (assoc 'logger? core-runtime-string-constants)))
