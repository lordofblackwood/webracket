#lang racket

(provide core-runtime-string-constants
         core-runtime-bytes-constants
         core-runtime-symbol-constants)

(require (only-in "booleans.rkt"
                  boolean-runtime-string-constants)
         (only-in "boxes.rkt"
                  box-runtime-string-constants)
         (only-in "bytes.rkt"
                  bytes-runtime-string-constants
                  bytes-runtime-bytes-constants
                  byte-predicate-runtime-symbol-constants
                  bytes-runtime-symbol-constants)
         (only-in "characters.rkt"
                  character-general-category-runtime-symbol-constants
                  character-runtime-symbol-constants)
         (only-in "checkers.rkt"
                  checker-runtime-string-constants
                  checker-runtime-symbol-constants)
         (only-in "control-flow.rkt"
                  continuation-runtime-symbol-constants
                  control-flow-runtime-string-constants
                  multiple-value-runtime-symbol-constants)
         (only-in "events.rkt"
                  event-runtime-string-constants
                  event-runtime-symbol-constants)
         (only-in "exceptions.rkt"
                  exception-struct-type-bindings
                  exception-runtime-string-constants
                  exception-runtime-symbol-constants
                  exception-fail-runtime-symbol-constants
                  exception-break-runtime-symbol-constants)
         (only-in "ffi.rkt"
                  ffi-runtime-string-constants
                  ffi-runtime-symbol-constants)
         (only-in "filesystem.rkt"
                  filesystem-runtime-string-constants
                  filesystem-runtime-symbol-constants
                  filesystem-runtime-bytes-constants)
         (only-in "fixnums.rkt"
                  fixnum-runtime-string-constants
                  fixnum-runtime-symbol-constants)
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
                  immutable-hash-runtime-string-constants
                  immutable-hash-runtime-symbol-constants)
         (only-in "impersonators.rkt"
                  impersonator-runtime-string-constants
                  impersonator-runtime-symbol-constants)
         (only-in "io-handlers.rkt"
                  io-handler-runtime-string-constants
                  io-handler-runtime-symbol-constants)
         (only-in "keywords.rkt"
                  keyword-runtime-string-constants)
         (only-in "linklet-instances.rkt"
                  linklet-instance-runtime-string-constants
                  linklet-instance-runtime-symbol-constants)
         (only-in "linklets.rkt"
                  linklet-runtime-string-constants
                  linklet-runtime-symbol-constants
                  linklet-runtime-bytes-constants)
         (only-in "lists.rkt"
                  list-runtime-string-constants
                  list-runtime-symbol-constants)
         (only-in "locations.rkt"
                  location-runtime-string-constants
                  location-runtime-symbol-constants)
         (only-in "loggers.rkt"
                  logger-runtime-string-constants
                  logger-runtime-symbol-constants)
         (only-in "mlists.rkt"
                  mlist-runtime-string-constants)
         (only-in "namespaces.rkt"
                  namespace-runtime-string-constants)
         (only-in "numbers.rkt"
                  number-runtime-string-constants)
         (only-in "parameters.rkt"
                  parameter-runtime-string-constants
                  parameter-runtime-symbol-constants)
         (only-in "paths.rkt"
                  path-runtime-string-constants
                  path-runtime-symbol-constants
                  path-runtime-bytes-constants)
         (only-in "ports.rkt"
                  port-predicate-runtime-string-constants
                  port-runtime-symbol-constants
                  port-event-runtime-string-constants
                  port-event-runtime-symbol-constants
                  port-closed-error-runtime-string-constants)
         (only-in "procedures.rkt"
                  procedure-runtime-string-constants
                  procedure-runtime-symbol-constants)
         (only-in "random.rkt"
                  random-runtime-string-constants)
         (only-in "realms.rkt"
                  realm-runtime-symbol-constants)
         (only-in "reflection.rkt"
                  reflection-runtime-string-constants
                  reflection-runtime-symbol-constants)
         (only-in "regexps.rkt"
                  regexp-runtime-string-constants
                  regexp-runtime-bytes-constants)
         (only-in "security.rkt"
                  security-runtime-string-constants
                  security-runtime-symbol-constants)
         (only-in "semaphores.rkt"
                  semaphore-runtime-string-constants)
         (only-in "strings.rkt"
                  string-runtime-string-constants)
         (only-in "structs.rkt"
                  struct-runtime-string-constants
                  struct-runtime-symbol-constants)
         (only-in "symbols.rkt"
                  symbol-runtime-string-constants)
         (only-in "syntax.rkt"
                  syntax-runtime-string-constants
                  syntax-runtime-symbol-constants)
         (only-in "system.rkt"
                  system-runtime-string-constants
                  system-runtime-symbol-constants)
         (only-in "threads.rkt"
                  thread-runtime-string-constants
                  thread-runtime-symbol-constants)
         (only-in "time.rkt"
                  time-runtime-string-constants
                  time-date-runtime-symbol-constants
                  time-clock-runtime-symbol-constants)
         (only-in "treelists.rkt"
                  treelist-runtime-string-constants)
         (only-in "vectors.rkt"
                  vector-runtime-string-constants
                  vector-runtime-symbol-constants)
         (only-in "wills.rkt"
                  will-runtime-string-constants
                  will-runtime-symbol-constants))

;; core-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare all domain-owned runtime string constants in assembly order.
(define core-runtime-string-constants
  (append printer-prefix-formatting-runtime-string-constants
          immediate-value-formatting-runtime-string-constants
          opaque-value-formatting-runtime-string-constants
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
          fixnum-runtime-string-constants
          bytes-runtime-string-constants
          vector-runtime-string-constants
          box-runtime-string-constants
          immutable-hash-runtime-string-constants
          port-predicate-runtime-string-constants
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
          linklet-instance-runtime-string-constants
          linklet-runtime-string-constants
          logger-runtime-string-constants
          reflection-runtime-string-constants))

;; core-runtime-bytes-constants : (listof (list/c symbol? bytes?))
;;   Declare all domain-owned runtime byte-string constants in assembly order.
(define core-runtime-bytes-constants
  (append bytes-runtime-bytes-constants
          path-runtime-bytes-constants
          regexp-runtime-bytes-constants
          linklet-runtime-bytes-constants
          filesystem-runtime-bytes-constants))

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
          parameter-runtime-symbol-constants
          system-runtime-symbol-constants
          linklet-runtime-symbol-constants
          multiple-value-runtime-symbol-constants
          list-runtime-symbol-constants
          fixnum-runtime-symbol-constants
          byte-predicate-runtime-symbol-constants
          vector-runtime-symbol-constants
          ffi-runtime-symbol-constants
          location-runtime-symbol-constants
          checker-runtime-symbol-constants
          syntax-runtime-symbol-constants
          path-runtime-symbol-constants
          filesystem-runtime-symbol-constants
          reflection-runtime-symbol-constants
          linklet-instance-runtime-symbol-constants))
