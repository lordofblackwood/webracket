#lang racket

(provide core-runtime-symbol-constants
         runtime-linklet-body-reserved-symbols/registration
         runtime-linklet-body-reserved-symbols)

(require (only-in "bytes.rkt"
                  byte-predicate-runtime-symbol-constants
                  bytes-runtime-symbol-constants)
         (only-in "characters.rkt"
                  character-general-category-runtime-symbol-constants
                  character-runtime-symbol-constants)
         (only-in "checkers.rkt"
                  checker-runtime-symbol-constants)
         (only-in "control-flow.rkt"
                  continuation-runtime-symbol-constants
                  multiple-value-runtime-symbol-constants)
         (only-in "events.rkt"
                  event-runtime-symbol-constants)
         (only-in "exceptions.rkt"
                  exception-struct-type-bindings
                  exception-runtime-symbol-constants
                  exception-fail-runtime-symbol-constants
                  exception-break-runtime-symbol-constants)
         (only-in "ffi.rkt"
                  ffi-runtime-symbol-constants)
         (only-in "filesystem.rkt"
                  filesystem-runtime-symbol-constants)
         (only-in "fixnums.rkt"
                  fixnum-runtime-symbol-constants)
         (only-in "flonums.rkt"
                  flonum-runtime-symbol-constants)
         (only-in "immutable-hashes.rkt"
                  immutable-hash-runtime-symbol-constants)
         (only-in "impersonators.rkt"
                  impersonator-runtime-symbol-constants)
         (only-in "io-handlers.rkt"
                  io-handler-runtime-symbol-constants)
         (only-in "linklet-instances.rkt"
                  linklet-instance-runtime-symbol-constants)
         (only-in "linklets.rkt"
                  linklet-body-core-reserved-symbols
                  linklet-runtime-symbol-constants)
         (only-in "locks.rkt"
                  lock-runtime-symbol-constants)
         (only-in "lists.rkt"
                  list-runtime-symbol-constants)
         (only-in "locations.rkt"
                  location-runtime-symbol-constants)
         (only-in "loggers.rkt"
                  logger-runtime-symbol-constants)
         (only-in "namespaces.rkt"
                  namespace-runtime-symbol-constants)
         (only-in "parameters.rkt"
                  parameter-runtime-symbol-constants)
         (only-in "paths.rkt"
                  path-runtime-symbol-constants)
         (only-in "ports.rkt"
                  port-runtime-symbol-constants
                  port-event-runtime-symbol-constants)
         (only-in "procedures.rkt"
                  procedure-runtime-symbol-constants)
         (only-in "realms.rkt"
                  realm-runtime-symbol-constants)
         (only-in "reflection.rkt"
                  reflection-runtime-symbol-constants)
         (only-in "security.rkt"
                  security-runtime-symbol-constants)
         (only-in "structs.rkt"
                  struct-runtime-symbol-constants)
         (only-in "syntax.rkt"
                  syntax-runtime-symbol-constants)
         (only-in "system.rkt"
                  system-runtime-symbol-constants)
         (only-in "threads.rkt"
                  thread-runtime-symbol-constants)
         (only-in "time.rkt"
                  time-date-runtime-symbol-constants
                  time-clock-runtime-symbol-constants)
         (only-in "vectors.rkt"
                  vector-runtime-symbol-constants)
         (only-in "wills.rkt"
                  will-runtime-symbol-constants))

;; core-runtime-symbol-constants : (listof symbol?)
;;   Declare all domain-owned runtime symbol constants in assembly order.
(define core-runtime-symbol-constants
  (append realm-runtime-symbol-constants
          character-runtime-symbol-constants
          character-general-category-runtime-symbol-constants
          (map car exception-struct-type-bindings)
          logger-runtime-symbol-constants
          procedure-runtime-symbol-constants
          struct-runtime-symbol-constants
          bytes-runtime-symbol-constants
          event-runtime-symbol-constants
          will-runtime-symbol-constants
          immutable-hash-runtime-symbol-constants
          impersonator-runtime-symbol-constants
          continuation-runtime-symbol-constants
          thread-runtime-symbol-constants
          security-runtime-symbol-constants
          time-date-runtime-symbol-constants
          exception-runtime-symbol-constants
          exception-fail-runtime-symbol-constants
          time-clock-runtime-symbol-constants
          exception-break-runtime-symbol-constants
          io-handler-runtime-symbol-constants
          port-runtime-symbol-constants
          port-event-runtime-symbol-constants
          namespace-runtime-symbol-constants
          parameter-runtime-symbol-constants
          system-runtime-symbol-constants
          linklet-runtime-symbol-constants
          multiple-value-runtime-symbol-constants
          list-runtime-symbol-constants
          fixnum-runtime-symbol-constants
          flonum-runtime-symbol-constants
          byte-predicate-runtime-symbol-constants
          vector-runtime-symbol-constants
          ffi-runtime-symbol-constants
          location-runtime-symbol-constants
          checker-runtime-symbol-constants
          syntax-runtime-symbol-constants
          path-runtime-symbol-constants
          filesystem-runtime-symbol-constants
          reflection-runtime-symbol-constants
          lock-runtime-symbol-constants
          linklet-instance-runtime-symbol-constants))

;; runtime-linklet-body-reserved-symbols/registration : (listof symbol?) -> (listof symbol?)
;;   Return source-linklet body symbols registered as runtime constants.
(define (runtime-linklet-body-reserved-symbols/registration all-primitives)
  (remove-duplicates (append linklet-body-core-reserved-symbols all-primitives)
                     eq?))

;; runtime-linklet-body-reserved-symbols : (listof symbol?) -> (listof symbol?)
;;   Return source-linklet body symbols in stable predicate-emission order.
(define (runtime-linklet-body-reserved-symbols all-primitives)
  (sort (runtime-linklet-body-reserved-symbols/registration all-primitives)
        symbol<?))

(module+ test
  (require rackunit)

  (check-not-false (memq 'racket core-runtime-symbol-constants))
  (check-not-false (memq 'exn core-runtime-symbol-constants))
  (check-not-false (memq 'current-logger core-runtime-symbol-constants))
  (check-equal?
   (runtime-linklet-body-reserved-symbols/registration '(lambda custom))
   (append linklet-body-core-reserved-symbols '(custom)))
  (check-equal?
   (runtime-linklet-body-reserved-symbols '(custom lambda))
   (sort (append linklet-body-core-reserved-symbols '(custom))
         symbol<?)))
