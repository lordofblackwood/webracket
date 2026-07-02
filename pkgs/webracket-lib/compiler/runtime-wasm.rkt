#lang racket
(provide generate-runtime
         generate-core-runtime
         generate-shared-types)

(require "private/wasm-data.rkt"
         "private/wasm-utils.rkt"
         "private/immediates.rkt"
         "private/priminfo.rkt"
         "private/parameters.rkt"
         "private/timings.rkt"
         "private/structs.rkt"
         "runtime-wasm/core-helper.rkt"
         (only-in "runtime-wasm/core/booleans.rkt"
                  boolean-runtime-only-helpers
                  boolean-runtime-only-helper-names)
         (only-in "runtime-wasm/core/boxes.rkt"
                  box-mutability-runtime-only-helper-names
                  box-runtime-only-helpers)
         (only-in "runtime-wasm/core/bytes.rkt"
                  bytes-basic-runtime-only-helper-names
                  byte-comparison-runtime-only-helper-names
                  byte-indexing-runtime-only-helper-names
                  byte-sequence-runtime-only-helper-names
                  bytes-mutability-runtime-only-helper-names
                  bytes-runtime-only-helpers)
         (only-in "runtime-wasm/core/characters.rkt"
                  character-runtime-only-helper-names
                  character-runtime-only-helpers)
         (only-in "runtime-wasm/core/checkers.rkt"
                  checker-runtime-only-helpers
                  checker-runtime-only-helper-names)
         (only-in "runtime-wasm/core/control-flow.rkt"
                  continuation-mark-runtime-only-helper-names
                  continuation-runtime-only-helper-names
                  multiple-value-runtime-only-helper-names
                  control-flow-runtime-only-helpers)
         (only-in "runtime-wasm/core/equality.rkt"
                  equality-runtime-only-helpers
                  equality-runtime-only-helper-names)
         (only-in "runtime-wasm/core/exceptions.rkt"
                  exception-contract-runtime-only-helper-names
                  exception-contract-runtime-only-helpers
                  exception-runtime-only-helper-names
                  exception-runtime-only-helpers)
         (only-in "runtime-wasm/core/events.rkt"
                  event-runtime-only-helpers)
         (only-in "runtime-wasm/core/fasl.rkt"
                  fasl-tag-runtime-only-helper-names
                  fasl-encoding-runtime-only-helper-names
                  fasl-runtime-only-helpers
                  fasl-runtime-only-helper-names)
         (only-in "runtime-wasm/core/ffi.rkt"
                  external-value-runtime-only-helper-names
                  ffi-runtime-only-helpers
                  ffi-runtime-only-helper-forms)
         (only-in "runtime-wasm/core/filesystem.rkt"
                  filesystem-runtime-only-helpers
                  filesystem-runtime-only-helper-names)
         (only-in "runtime-wasm/core/fixnums.rkt"
                  fixnum-arithmetic-runtime-only-helper-names
                  fixnum-comparison-runtime-only-helper-names
                  fixnum-conversion-runtime-only-helper-names
                  fixnum-minmax-runtime-only-helper-names
                  fixnum-predicate-runtime-only-helper-names
                  fixnum-runtime-only-helpers)
         (only-in "runtime-wasm/core/flonums.rkt"
                  flonum-arithmetic-runtime-only-helper-names
                  flonum-constructor-runtime-only-helper-names
                  flonum-conversion-runtime-only-helper-names
                  flonum-math-runtime-only-helper-names
                  flonum-minmax-runtime-only-helper-names
                  flonum-predicate-runtime-only-helper-names
                  flonum-utility-runtime-only-helper-names
                  flonum-runtime-only-helpers)
         (only-in "runtime-wasm/core/formatting.rkt"
                  printer-extension-runtime-only-helper-names
                  formatting-runtime-only-helper-names
                  numeric-display-formatting-runtime-only-helper-names
                  formatting-runtime-only-helpers)
         (only-in "runtime-wasm/core/hashes.rkt"
                  hash-count-list-runtime-only-helper-names
                  hash-equal-composite-runtime-only-helper-names
                  hash-equal-runtime-only-helper-names
                  hash-filter-runtime-only-helper-names
                  hash-for-each-runtime-only-helper-names
                  hash-key-value-runtime-only-helper-names
                  hash-map-copy-runtime-only-helper-names
                  hash-map-runtime-only-helper-names
                  hash-runtime-only-helpers
                  hash-seed-runtime-only-helper-names
                  hash-table-predicate-runtime-only-helper-names
                  hash-predicate-runtime-only-helper-names)
         (only-in "runtime-wasm/core/immutable-hashes.rkt"
                  immutable-hash-constructor-runtime-only-helper-names
                  immutable-hash-iteration-runtime-only-helper-names
                  immutable-hash-public-runtime-only-helper-names
                  immutable-hash-runtime-only-helpers)
         (only-in "runtime-wasm/core/immediates.rkt"
                  void-runtime-only-helper-names
                  immediate-runtime-only-helpers)
         (only-in "runtime-wasm/core/impersonators.rkt"
                  chaperone-procedure-runtime-only-helper-names
                  impersonator-basic-runtime-only-helper-names
                  impersonator-runtime-only-helpers)
         (only-in "runtime-wasm/core/io-handlers.rkt"
                  io-handler-error-runtime-only-helper-names
                  io-handler-port-runtime-only-helper-names
                  io-handler-reader-printer-runtime-only-helper-names
                  io-handler-runtime-only-helpers)
         (only-in "runtime-wasm/core/keywords.rkt"
                  keyword-runtime-only-helper-names
                  keyword-runtime-only-helpers)
         (only-in "runtime-wasm/core/lists.rkt"
                  list-association-runtime-only-helper-names
                  list-error-runtime-only-helper-names
                  list-group-by-runtime-only-helper-names
                  list-member-runtime-only-helper-names
                  list-ordinal-accessor-runtime-only-helper-names
                  list-remove-runtime-only-helper-names
                  list-remove-star-runtime-only-helper-names
                  pair-accessor-runtime-only-helper-names
                  list-runtime-only-helpers)
         (only-in "runtime-wasm/core/linklet-instances.rkt"
                  linklet-instance-runtime-only-helper-names
                  linklet-instance-runtime-only-helpers)
         (only-in "runtime-wasm/core/linklets.rkt"
                  linklet-bootstrap-runtime-only-helper-names
                  linklet-bootstrap-runtime-only-helpers
                  linklet-primitive-table-runtime-only-helper-forms
                  linklet-runtime-only-helper-forms)
         (only-in "runtime-wasm/core/locations.rkt"
                  location-runtime-only-helpers
                  source-location-runtime-only-helper-names)
         (only-in "runtime-wasm/core/locks.rkt"
                  lock-runtime-only-helpers)
         (only-in "runtime-wasm/core/loggers.rkt"
                  logger-runtime-only-helpers)
         (only-in "runtime-wasm/core/mutable-hashes.rkt"
                  mutable-hash-association-constructor-runtime-only-helper-names
                  mutable-hash-constructor-runtime-only-helper-names
                  mutable-hash-pair-error-runtime-only-helper-names
                  mutable-hash-runtime-only-helpers)
         (only-in "runtime-wasm/core/namespaces.rkt"
                  namespace-runtime-only-helpers
                  namespace-runtime-only-helper-names)
         (only-in "runtime-wasm/core/numbers.rkt"
                  generic-arithmetic-runtime-only-helper-names
                  generic-bitwise-runtime-only-helper-names
                  generic-numeric-runtime-only-helper-names
                  number-runtime-only-helpers
                  number-string-conversion-runtime-only-helper-names
                  floating-point-byte-conversion-runtime-only-helper-names
                  numeric-formatting-runtime-only-helper-names
                  string-number-conversion-runtime-only-helper-names
                  number-type-runtime-only-helper-names)
         (only-in "runtime-wasm/core/parameters.rkt"
                  compile-parameter-runtime-only-helper-names
                  namespace-parameter-runtime-only-helper-names
                  parameterization-binding-runtime-only-helper-names
                  parameterization-call-runtime-only-helper-names
                  parameter-directory-runtime-only-helper-names
                  parameter-error-rendering-runtime-only-helper-names
                  parameterization-runtime-only-helper-names
                  parameter-runtime-only-helpers
                  parameter-width-runtime-only-helper-names
                  reader-printer-policy-parameter-helper-names)
         (only-in "runtime-wasm/core/paths.rkt"
                  path-runtime-only-helpers
                  path-runtime-only-helper-names
                  path-manipulation-runtime-only-helper-names)
         (only-in "runtime-wasm/core/ports.rkt"
                  port-byte-char-runtime-only-helper-names
                  port-byte-char-special-runtime-only-helper-names
                  port-custom-byte-runtime-only-helper-names
                  port-custom-constructor-runtime-only-helper-names
                  port-event-runtime-only-helper-names
                  port-location-runtime-only-helper-names
                  port-peek-byte-runtime-only-helper-names
                  port-peek-bytes-bang-runtime-only-helper-names
                  port-peek-bytes-runtime-only-helper-names
                  port-predicate-runtime-only-helper-names
                  port-read-bytes-runtime-only-helper-names
                  port-read-line-runtime-only-helper-names
                  port-read-string-runtime-only-helper-names
                  port-ready-runtime-only-helper-names
                  port-state-runtime-only-helper-names
                  port-string-constructor-runtime-only-helper-names
                  port-write-basic-runtime-only-helper-names
                  port-write-bytes-runtime-only-helper-names
                  port-runtime-only-helpers)
         (only-in "runtime-wasm/core/procedures.rkt"
                  primitive-reflection-runtime-only-helper-names
                  procedure-arity-at-least-runtime-only-helper-names
                  procedure-arity-field-runtime-only-helper-names
                  procedure-arity-mask-runtime-only-helper-names
                  procedure-arity-runtime-only-helper-names
                  procedure-basic-runtime-only-helper-names
                  procedure-composition-runtime-only-helper-names
                  procedure-reduction-runtime-only-helper-names
                  procedure-result-arity-runtime-only-helper-names
                  procedure-runtime-only-helpers)
         (only-in "runtime-wasm/core/random.rkt"
                  random-generator-runtime-only-helper-names
                  random-public-runtime-only-helper-names
                  random-runtime-only-helpers)
         (only-in "runtime-wasm/core/regexps.rkt"
                  regexp-runtime-only-helper-names
                  regexp-runtime-only-helpers)
         (only-in "runtime-wasm/core/reflection.rkt"
                  reflection-runtime-only-helper-names
                  reflection-runtime-only-helpers)
         (only-in "runtime-wasm/core/security.rkt"
                  custodian-runtime-only-helper-names
                  inspector-runtime-only-helper-names
                  security-post-parameter-runtime-only-helper-names
                  security-pre-parameter-runtime-only-helper-names
                  security-runtime-only-helpers)
         (only-in "runtime-wasm/core/semaphores.rkt"
                  semaphore-runtime-only-helpers)
         (only-in "runtime-wasm/core/stencil-vectors.rkt"
                  stencil-vector-runtime-only-helpers)
         (only-in "runtime-wasm/core/strings.rkt"
                  string-mutability-runtime-only-helper-names
                  string-runtime-only-helpers)
         (only-in "runtime-wasm/core/structs.rkt"
                  struct-basic-runtime-only-helper-names
                  struct-conversion-runtime-only-helper-names
                  struct-descriptor-runtime-only-helper-names
                  struct-format-runtime-only-helper-names
                  struct-prefab-basic-runtime-only-helper-names
                  struct-prefab-key-runtime-only-helper-names
                  struct-prefab-key-validation-runtime-only-helper-names
                  struct-prefab-key-accessor-runtime-only-helper-names
                  struct-prefab-chain-runtime-only-helper-names
                  struct-prefab-struct-type-runtime-only-helper-names
                  struct-prefab-metadata-runtime-only-helper-names
                  struct-prefab-immutables-runtime-only-helper-names
                  struct-prefab-constructor-runtime-only-helper-names
                  struct-type-constructor-runtime-only-helper-names
                  struct-accessor-runtime-only-helper-names
                  struct-constructor-wrapper-runtime-only-helper-names
                  struct-constructor-runtime-only-helper-names
                  struct-mutator-runtime-only-helper-names
                  struct-field-mutator-runtime-only-helper-names
                  struct-predicate-runtime-only-helper-names
                  struct-field-accessor-runtime-only-helper-names
                  struct-procedure-predicate-runtime-only-helper-names
                  struct-guarded-constructor-runtime-only-helper-names
                  struct-type-property-lookup-runtime-only-helper-names
                  struct-type-property-closure-runtime-only-helper-names
                  struct-type-property-predicate-runtime-only-helper-names
                  struct-type-property-descriptor-runtime-only-helper-names
                  struct-type-property-table-runtime-only-helper-names
                  struct-type-property-constructor-runtime-only-helper-names
                  struct-procedure-runtime-only-helper-names
                  struct-runtime-only-helpers)
         (only-in "runtime-wasm/core/symbols.rkt"
                  symbol-gensym-runtime-only-helper-names
                  symbol-public-runtime-only-helper-names
                  symbol-table-runtime-only-helper-names
                  symbol-runtime-only-helpers)
         (only-in "runtime-wasm/core/system.rkt"
                  system-runtime-only-helper-names
                  system-runtime-only-helpers)
         (only-in "runtime-wasm/core/syntax.rkt"
                  correlated-syntax-runtime-only-helper-names
                  syntax-runtime-only-helpers
                  syntax-runtime-only-helper-names)
         (only-in "runtime-wasm/core/threads.rkt"
                  thread-runtime-only-helpers)
         (only-in "runtime-wasm/core/time.rkt"
                  time-runtime-only-helpers
                  time-runtime-only-helper-names)
         (only-in "runtime-wasm/core/treelists.rkt"
                  treelist-error-runtime-only-helper-names
                  treelist-runtime-only-helpers)
         (only-in "runtime-wasm/core/unsafe.rkt"
                  unsafe-runtime-only-helpers
                  unsafe-runtime-helper-names)
         (only-in "runtime-wasm/core/vectors.rkt"
                  vector-append-runtime-only-helper-names
                  vector-argminmax-runtime-only-helper-names
                  vector-build-runtime-only-helper-names
                  vector-constructor-runtime-only-helper-names
                  vector-copy-runtime-only-helper-names
                  vector-error-runtime-only-helper-names
                  vector-extend-runtime-only-helper-names
                  vector-filter-search-runtime-only-helper-names
                  vector-list-conversion-runtime-only-helper-names
                  vector-map-count-runtime-only-helper-names
                  vector-make-runtime-only-helper-names
                  vector-mutability-runtime-only-helper-names
                  vector-operation-runtime-only-helper-names
                  vector-slice-runtime-only-helper-names
                  vector-sort-runtime-only-helper-names
                  vector-runtime-only-helpers)
         (only-in "runtime-wasm/core/wills.rkt"
                  will-runtime-only-helpers)
         "runtime-wasm/core-runtime.rkt"
         "runtime-wasm/constants.rkt"
         "runtime-wasm/shared-types.rkt"
         file/sha1
         racket/fasl
         racket/file
         racket/runtime-path)

(define-runtime-path runtime-wasm-path "runtime-wasm.rkt")
(define-runtime-path priminfo-path "private/priminfo.rkt")
(define-runtime-path parameters-path "private/parameters.rkt")
(define-runtime-path structs-path "private/structs.rkt")
(define-runtime-path wasm-data-path "private/wasm-data.rkt")
(define-runtime-path wasm-utils-path "private/wasm-utils.rkt")
(define-runtime-path immediates-path "private/immediates.rkt")
(define-runtime-path constants-path "runtime-wasm/constants.rkt")
(define-runtime-path core-booleans-path "runtime-wasm/core/booleans.rkt")
(define-runtime-path core-boxes-path "runtime-wasm/core/boxes.rkt")
(define-runtime-path core-bytes-path "runtime-wasm/core/bytes.rkt")
(define-runtime-path core-characters-path "runtime-wasm/core/characters.rkt")
(define-runtime-path core-checkers-path "runtime-wasm/core/checkers.rkt")
(define-runtime-path core-control-flow-path "runtime-wasm/core/control-flow.rkt")
(define-runtime-path core-equality-path "runtime-wasm/core/equality.rkt")
(define-runtime-path core-exceptions-path "runtime-wasm/core/exceptions.rkt")
(define-runtime-path core-events-path "runtime-wasm/core/events.rkt")
(define-runtime-path core-fasl-path "runtime-wasm/core/fasl.rkt")
(define-runtime-path core-ffi-path "runtime-wasm/core/ffi.rkt")
(define-runtime-path core-filesystem-path "runtime-wasm/core/filesystem.rkt")
(define-runtime-path core-formatting-path "runtime-wasm/core/formatting.rkt")
(define-runtime-path core-hashes-path "runtime-wasm/core/hashes.rkt")
(define-runtime-path core-immutable-hashes-path "runtime-wasm/core/immutable-hashes.rkt")
(define-runtime-path core-immediates-path "runtime-wasm/core/immediates.rkt")
(define-runtime-path core-impersonators-path "runtime-wasm/core/impersonators.rkt")
(define-runtime-path core-io-handlers-path "runtime-wasm/core/io-handlers.rkt")
(define-runtime-path core-keywords-path "runtime-wasm/core/keywords.rkt")
(define-runtime-path core-lists-path "runtime-wasm/core/lists.rkt")
(define-runtime-path core-linklet-instances-path "runtime-wasm/core/linklet-instances.rkt")
(define-runtime-path core-linklets-path "runtime-wasm/core/linklets.rkt")
(define-runtime-path core-locations-path "runtime-wasm/core/locations.rkt")
(define-runtime-path core-locks-path "runtime-wasm/core/locks.rkt")
(define-runtime-path core-loggers-path "runtime-wasm/core/loggers.rkt")
(define-runtime-path core-mlists-path "runtime-wasm/core/mlists.rkt")
(define-runtime-path core-mutable-hashes-path "runtime-wasm/core/mutable-hashes.rkt")
(define-runtime-path core-namespaces-path "runtime-wasm/core/namespaces.rkt")
(define-runtime-path core-numbers-path "runtime-wasm/core/numbers.rkt")
(define-runtime-path core-parameters-path "runtime-wasm/core/parameters.rkt")
(define-runtime-path core-paths-path "runtime-wasm/core/paths.rkt")
(define-runtime-path core-ports-path "runtime-wasm/core/ports.rkt")
(define-runtime-path core-procedures-path "runtime-wasm/core/procedures.rkt")
(define-runtime-path core-random-path "runtime-wasm/core/random.rkt")
(define-runtime-path core-regexps-path "runtime-wasm/core/regexps.rkt")
(define-runtime-path core-reflection-path "runtime-wasm/core/reflection.rkt")
(define-runtime-path core-security-path "runtime-wasm/core/security.rkt")
(define-runtime-path core-semaphores-path "runtime-wasm/core/semaphores.rkt")
(define-runtime-path core-stencil-vectors-path "runtime-wasm/core/stencil-vectors.rkt")
(define-runtime-path core-strings-path "runtime-wasm/core/strings.rkt")
(define-runtime-path core-symbols-path "runtime-wasm/core/symbols.rkt")
(define-runtime-path core-system-path "runtime-wasm/core/system.rkt")
(define-runtime-path core-syntax-path "runtime-wasm/core/syntax.rkt")
(define-runtime-path core-threads-path "runtime-wasm/core/threads.rkt")
(define-runtime-path core-time-path "runtime-wasm/core/time.rkt")
(define-runtime-path core-treelists-path "runtime-wasm/core/treelists.rkt")
(define-runtime-path core-unsafe-path "runtime-wasm/core/unsafe.rkt")
(define-runtime-path core-vectors-path "runtime-wasm/core/vectors.rkt")
(define-runtime-path core-wills-path "runtime-wasm/core/wills.rkt")

;; runtime-helper-index : hasheq?
;;   Index helpers available to the monolithic runtime generator.
(define runtime-helper-index
  (make-core-runtime-helper-index
   (append core-runtime-helpers
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
           immediate-runtime-only-helpers
           impersonator-runtime-only-helpers
           io-handler-runtime-only-helpers
           keyword-runtime-only-helpers
           list-runtime-only-helpers
           linklet-bootstrap-runtime-only-helpers
           linklet-instance-runtime-only-helpers
           location-runtime-only-helpers
           lock-runtime-only-helpers
           logger-runtime-only-helpers
           mutable-hash-runtime-only-helpers
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
           will-runtime-only-helpers)))

(module+ test
  (require (submod "runtime-wasm/core-runtime.rkt" test)))

; See the end of `generate-code` in `compiler.rkt` for an
; explanation of the arguments.
(define (generate-runtime
           dls tms entry-body result
           ; program specific
           top-vars
           console-bridge-bindings
           top-level-variable-declarations
           entry-locals
           ; general information
           primitives       ; list of symbols
           used-primitives  ; list of symbols referenced by generated program code
           string-constants ; (list (list name string) ...)
           bytes-constants  ; (list (list name bytes)  ...)
           symbol-constants ; (list (list name symbol) ....)
           )

  #;(pretty-print entry-body (current-error-port))

  (let* ()
    (let* ()

    ;; Variable definitions on the top-level ought to go in a namespace,
    ;; but for now we use a global WebAssembly variable.


    ; R = Make reference
    (define (R x [type #f])
      (case type
        [(#f)  (match x
                 [(? integer?) `(ref.i31 (i32.const ,x))]
                 [_            `(ref.cast (ref eq) ,x)])]
        [else  `(ref.cast ,type ,x)]))

    ; D = Dereference
    (define (D x type)
      ; type is one of:
      ;   'i32           cast to signed i32
      ;   '(ref <type>)  cast to (ref <type>)

      ; x evaluates to an (ref eq), cast x to type
      (match type
        ['i32 `(i31.get_s (ref.cast i31ref ,x))]
        ['u32 `(i31.get_u (ref.cast i31ref ,x))]
        [type `(ref.cast (ref ,type) ,x)]))

    (define (I32 x) (D x 'i32))
    (define (U32 x) (D x 'u32))
    (define (Half x)   `(i32.shr_s ,x (i32.const 1)))
    (define (Double x) `(i32.shl   ,x (i32.const 1)))

    ;;;
    ;;; Exception structures
    ;;;

    (define exception-struct-type-bindings
      '((struct:exn                                 ensure-exn-type)
        (struct:exn:break                           ensure-exn:break-type)
        (struct:exn:break:hang-up                   ensure-exn:break:hang-up-type)
        (struct:exn:break:terminate                 ensure-exn:break:terminate-type)
        (struct:exn:fail                            ensure-exn:fail-type)
        (struct:exn:fail:contract                   ensure-exn:fail:contract-type)
        (struct:exn:fail:contract:arity             ensure-exn:fail:contract:arity-type)
        (struct:exn:fail:contract:continuation      ensure-exn:fail:contract:continuation-type)
        (struct:exn:fail:contract:divide-by-zero    ensure-exn:fail:contract:divide-by-zero-type)
        (struct:exn:fail:contract:non-fixnum-result ensure-exn:fail:contract:non-fixnum-result-type)
        (struct:exn:fail:contract:variable          ensure-exn:fail:contract:variable-type)
        (struct:exn:fail:read                       ensure-exn:fail:read-type)
        (struct:exn:fail:read:eof                   ensure-exn:fail:read:eof-type)
        (struct:exn:fail:read:non-char              ensure-exn:fail:read:non-char-type)
        (struct:exn:fail:filesystem                 ensure-exn:fail:filesystem-type)
        (struct:exn:fail:filesystem:exists          ensure-exn:fail:filesystem:exists-type)
        (struct:exn:fail:filesystem:version         ensure-exn:fail:filesystem:version-type)
        (struct:exn:fail:filesystem:errno           ensure-exn:fail:filesystem:errno-type)
        (struct:exn:fail:network                    ensure-exn:fail:network-type)
        (struct:exn:fail:network:errno              ensure-exn:fail:network:errno-type)
        (struct:exn:fail:out-of-memory              ensure-exn:fail:out-of-memory-type)
        (struct:exn:fail:unsupported                ensure-exn:fail:unsupported-type)
        (struct:exn:fail:user                       ensure-exn:fail:user-type)
        (struct:exn:fail:syntax                     ensure-exn:fail:syntax-type)
        (struct:exn:fail:syntax:missing-module      ensure-exn:fail:syntax:missing-module-type)
        (struct:exn:fail:syntax:unbound             ensure-exn:fail:syntax:unbound-type)))

    ;;;
    ;;; Primitives
    ;;;

    (define all-primitives primitives)
    (define active-primitives primitives)
    (define all-ffi-foreigns (current-ffi-foreigns))
    (define active-ffi-foreigns all-ffi-foreigns)
    (define active-ffi-imports-wat (current-ffi-imports-wat))
    (define active-ffi-funcs-wat   (current-ffi-funcs-wat))
    (define active-primitives-sorted
      (λ ()
        (sort active-primitives symbol<?)))

    (define active-described-primitives-sorted
      (λ ()
        (for/list ([pr (in-list (active-primitives-sorted))]
                   #:unless (memq pr todo-handle-later)
                   #:when (primitive->description pr))
          pr)))

    (define active-ffi-primitive-names
      (λ ()
        (for/list ([f (in-list active-ffi-foreigns)])
          (foreign-racket-name f))))

    (define described-primitives
      (filter primitive->description all-primitives))

    (define ffi-primitive-name-set
      (for/hasheq ([f (in-list all-ffi-foreigns)])
        (values (foreign-racket-name f) #t)))

    (define console-bridge-enabled? (pair? console-bridge-bindings))
    (define console-bridge-primitive-names
      (for/list ([binding (in-list console-bridge-bindings)]
                 #:do [(define kind (first binding))]
                 #:when (eq? kind 'primitive))
        (second binding)))

    (define initial-program-string-constant-names
      (map first string-constants))
    (define initial-program-bytes-constant-names
      (map first bytes-constants))
    (define initial-program-symbol-constant-names
      (map first symbol-constants))

    (define primitive-table-module-symbols
      '(#%bootstrap-linklet
        #%kernel
        #%read
        #%paramz
        #%unsafe
        #%foreign
        #%futures
        #%place
        #%flfxnum
        #%extfl
        #%network
        #%terminal
        #%linklet
        internal
        schemify))

    (define (console-bridge-symbol-global const-name)
      ($ (string->symbol (~a "symbol:" const-name))))

    (define (ffi-import-name f)
      (string->symbol (~a "$" (foreign-racket-name f) "/imported")))

    (define primitive-func->symbol
      (for/hasheq ([pr (in-list described-primitives)])
        (values ($ pr) pr)))

    (define primitive-global->symbol
      (for/hasheq ([pr (in-list described-primitives)])
        (values ($ (prim: pr)) pr)))

    (define ffi-func->symbol
      (for/hasheq ([f (in-list all-ffi-foreigns)])
        (values ($ (foreign-racket-name f))
                (foreign-racket-name f))))

    (define ffi-global->symbol
      (for/hasheq ([f (in-list all-ffi-foreigns)])
        (define pr (foreign-racket-name f))
        (values ($ (prim: pr)) pr)))

    (define (sexpr-primitive-refs x)
      (define refs '())
      (define (walk x)
        (cond
          [(symbol? x)
           (define pr
             (or (hash-ref primitive-func->symbol x #f)
                 (hash-ref primitive-global->symbol x #f)))
           (when pr
             (set! refs (cons pr refs)))]
          [(pair? x)
           (walk (car x))
           (walk (cdr x))]
          [else (void)]))
      (walk x)
      (remove-duplicates refs))

    (define (module-func-name form)
      (and (pair? form)
           (eq? (car form) 'func)
           (pair? (cdr form))
           (symbol? (cadr form))
           (cadr form)))

    (set! active-ffi-imports-wat
          (remove-duplicates active-ffi-imports-wat eq? #:key module-func-name))
    (set! active-ffi-funcs-wat
          (remove-duplicates active-ffi-funcs-wat eq? #:key module-func-name))

    (define (module-global-name form)
      (and (pair? form)
           (eq? (car form) 'global)
           (pair? (cdr form))
           (symbol? (cadr form))
           (cadr form)))

    (define (module-data-name form)
      (and (pair? form)
           (eq? (car form) 'data)
           (pair? (cdr form))
           (symbol? (cadr form))
           (cadr form)))

    (define (primitive-global-init-form? x)
      (and (pair? x)
           (eq? (car x) 'global.set)
           (pair? (cdr x))
           (symbol? (cadr x))
           (or (hash-ref primitive-global->symbol (cadr x) #f)
               (hash-ref ffi-global->symbol (cadr x) #f))))

    (define program-function-names
      (for/list ([form (in-list dls)]
                 #:do [(define name (module-func-name form))]
                 #:when name)
        name))

    (define program-driver-function-names
      '($entry
        $entry-uncaught-exception
        $entry-uncaught-exception1
        $entry-uncaught-exception2))

    (define (list->eq-set xs)
      (define ht (make-hasheq))
      (eq-set-add-all! ht xs)
      ht)

    (define (eq-set-add-all! ht xs)
      (for ([x (in-list xs)])
        (hash-set! ht x #t)))

    (define (eq-set-keys ht)
      (hash-keys ht))

    (define (eq-set-keys/sorted ht)
      (sort (hash-keys ht) symbol<?))

    ;; Tree-shake currently analyzes one combined module s-expression.
    ;; The boundary is already implicit in pruning, though:
    ;;   - `dls` contributes generated program helper functions
    ;;   - `$entry` runs the user program and top-level initialization
    ;;   - `top-level-variable-declarations` contributes program globals
    ;; Everything else in `build-runtime-module` is intended to be stable
    ;; runtime/target/FFI support. This classifier exists to document that
    ;; seam and to support a future split cache without changing behavior yet.
    (define program-function-name-set
      (list->eq-set
       (append program-function-names
               program-driver-function-names)))

    (define program-global-name-set
      (list->eq-set
       (append
        (list result)
        (for/list ([form (in-list top-level-variable-declarations)]
                   #:do [(define name (module-global-name form))]
                   #:when name)
          name)
        (append*
         (for/list ([name (in-list initial-program-string-constant-names)])
           (list (string->symbol (~a "$string:" name))))
         (for/list ([name (in-list initial-program-bytes-constant-names)])
           (list (string->symbol (~a "$bytes:" name))))
         (for/list ([name (in-list initial-program-symbol-constant-names)])
           (list (string->symbol (~a "$symbol:" name))))))))

    (define program-data-name-set
      (list->eq-set
       (append
        (for/list ([name (in-list initial-program-string-constant-names)])
          (string->symbol (~a "$string-data:" name)))
        (for/list ([name (in-list initial-program-bytes-constant-names)])
          (string->symbol (~a "$bytes-data:" name)))
        (for/list ([name (in-list initial-program-symbol-constant-names)])
          (string->symbol (~a "$symbol-data:" name))))))

    (define (program-module-form? form)
      (define func-name (module-func-name form))
      (define global-name (module-global-name form))
      (define data-name (module-data-name form))
      (or (and func-name
               (hash-ref program-function-name-set func-name #f))
          (and global-name
               (hash-ref program-global-name-set global-name #f))
          (and data-name
               (hash-ref program-data-name-set data-name #f))))

    (define (split-module-forms module)
      (for/fold ([runtime-forms '()]
                 [program-forms '()])
                ([form (in-list (cdr module))])
        (if (program-module-form? form)
            (values runtime-forms (cons form program-forms))
            (values (cons form runtime-forms) program-forms))))

    (define (time-runtime-step label thunk)
      (if (current-runtime-timing-rows)
          (let-values ([(vals ms)
                        (with-timing
                          (λ ()
                            (call-with-values thunk list)))])
            (current-runtime-timing-rows
             (cons (list label ms) (current-runtime-timing-rows)))
            (apply values vals))
          (thunk)))

    (define (runtime-metric-add! label value)
      (when (current-runtime-metric-rows)
        (current-runtime-metric-rows
         (cons (list label (~a value)) (current-runtime-metric-rows)))))

    (define (runtime-source-fingerprint)
      `(runtime-source
        1
        ,@(for/list ([path (in-list (list runtime-wasm-path
                                          priminfo-path
                                          parameters-path
                                          structs-path
                                          wasm-data-path
                                          wasm-utils-path
                                          immediates-path
                                          constants-path
                                          core-booleans-path
                                          core-boxes-path
                                          core-bytes-path
                                          core-characters-path
                                          core-checkers-path
                                          core-control-flow-path
                                          core-equality-path
                                          core-exceptions-path
                                          core-events-path
                                          core-fasl-path
                                          core-ffi-path
                                          core-filesystem-path
                                          core-formatting-path
                                          core-hashes-path
                                          core-immutable-hashes-path
                                          core-immediates-path
                                          core-impersonators-path
                                          core-io-handlers-path
                                          core-keywords-path
                                          core-lists-path
                                          core-linklet-instances-path
                                          core-linklets-path
                                          core-locations-path
                                          core-locks-path
                                          core-loggers-path
                                          core-mlists-path
                                          core-mutable-hashes-path
                                          core-namespaces-path
                                          core-numbers-path
                                          core-parameters-path
                                          core-paths-path
                                          core-ports-path
                                          core-procedures-path
                                          core-random-path
                                          core-regexps-path
                                          core-reflection-path
                                          core-security-path
                                          core-semaphores-path
                                          core-stencil-vectors-path
                                          core-strings-path
                                          core-symbols-path
                                          core-syntax-path
                                          core-threads-path
                                          core-time-path
                                          core-treelists-path
                                          core-unsafe-path
                                          core-vectors-path
                                          core-wills-path))])
            (list (path->string path)
                  (file-size path)
                  (file-or-directory-modify-seconds path)))))

    (define (module-fingerprint module)
      (bytes->hex-string
       (sha1-bytes
        (string->bytes/utf-8
         (with-output-to-string
           (lambda ()
             (write module)))))))

    (define (stable-runtime-analysis-cache-fingerprint runtime-module)
      `(stable-runtime-analysis-cache
        1
        ,(if (current-browser?) 'browser 'node)
        ,(runtime-source-fingerprint)
        ,(module-fingerprint runtime-module)
        ,(sort (map foreign-racket-name active-ffi-foreigns) symbol<?)
        ,(equal-hash-code active-ffi-imports-wat)
        ,(equal-hash-code active-ffi-funcs-wat)))

    (define (stable-runtime-analysis-cache-path fingerprint)
      (define cache-root (current-runtime-cache-dir))
      (and cache-root
           (build-path cache-root
                       "runtime-analysis-v2"
                       (format "~x.fasl"
                               (abs (equal-hash-code fingerprint))))))

    (define (read-stable-runtime-analysis-cache cache-path fingerprint)
      (and cache-path
           (file-exists? cache-path)
           (with-handlers ([exn:fail? (lambda (_exn) #f)])
             (match (call-with-input-file cache-path
                      (lambda (in)
                        (fasl->s-exp (port->bytes in))))
               [`(,cached-fingerprint ,analysis)
                (and (equal? cached-fingerprint fingerprint) analysis)]
               [_ #f]))))

    (define (write-stable-runtime-analysis-cache! cache-path fingerprint analysis)
      (when cache-path
        (make-directory* (path-only cache-path))
        (call-with-output-file cache-path
          (lambda (out)
            (write-bytes
             (s-exp->fasl (list fingerprint analysis))
             out))
          #:exists 'truncate/replace)))

    (define (module-form-count module predicate)
      (for/sum ([form (in-list (cdr module))]
                #:when (predicate form))
        1))

    (define (module-func-count module)
      (module-form-count module module-func-name))

    (define (module-global-count module)
      (module-form-count module module-global-name))

    (define (module-export-count module)
      (module-form-count
       module
       (lambda (form)
         (and (pair? form)
              (eq? (car form) 'export)))))

    (define (module-byte-size module)
      (bytes-length
       (string->bytes/utf-8
        (with-output-to-string
          (lambda ()
            (write module))))))

    (define (symbol-prefix-count syms prefix)
      (for/sum ([sym (in-list syms)]
                #:when (string-prefix? (symbol->string sym) prefix))
        1))

    (define (constant-global-name? name)
      (and (symbol? name)
           (let ([s (symbol->string name)])
             (or (string-prefix? s "$string:")
                 (string-prefix? s "$bytes:")
                 (string-prefix? s "$symbol:")))))

    (define (constant-data-name? name)
      (and (symbol? name)
           (let ([s (symbol->string name)])
             (or (string-prefix? s "$string-data:")
                 (string-prefix? s "$bytes-data:")
                 (string-prefix? s "$symbol-data:")))))

    (define (stable-runtime-analysis-form? form)
      (define global-name (module-global-name form))
      (define data-name (module-data-name form))
      (and (not (and global-name
                     (constant-global-name? global-name)))
           (not (and data-name
                     (constant-data-name? data-name)))))

    (define (stable-runtime-analysis-module module)
      (forms->module
       (for/list ([form (in-list (cdr module))]
                  #:when (stable-runtime-analysis-form? form))
         form)))

    (define (forms->module forms)
      `(module ,@forms))

    (define (walk-symbol-refs x symbol->value)
      (define refs (make-hasheq))
      (define (walk x)
        (cond
          [(primitive-global-init-form? x) (void)]
          [(symbol? x)
           (define v (hash-ref symbol->value x #f))
           (when v
             (hash-set! refs (if (eq? v #t) x v) #t))]
          [(pair? x)
           (walk (car x))
           (walk (cdr x))]
          [else (void)]))
      (walk x)
      (eq-set-keys refs))

    (define (analyze-stable-runtime module)
      (define primitive-ref->symbol
        (time-runtime-step
         "tree-shake:build-primitive-ref-map"
         (lambda ()
           (let ([ht (make-hasheq)])
             (for ([(k v) (in-hash primitive-func->symbol)])
               (hash-set! ht k v))
             (for ([(k v) (in-hash primitive-global->symbol)])
               (hash-set! ht k v))
             ht))))
      (define named-funcs
        (time-runtime-step
         "tree-shake:collect-named-functions"
         (lambda ()
           (for/list ([form (in-list (cdr module))]
                      #:do [(define name (module-func-name form))]
                      #:when name)
             name))))
      (define (func-export-names form)
        (and (pair? form)
             (eq? (car form) 'func)
             (pair? (cdr form))
             (symbol? (cadr form))
             (for/list ([part (in-list (cddr form))]
                        #:when (and (pair? part)
                                    (eq? (car part) 'export)
                                    (pair? (cdr part))
                                    (string? (cadr part))))
               (cadr part))))
      (define named-funcs-ht
        (for/hasheq ([name (in-list named-funcs)])
          (values name #t)))
      (define func->func-refs (make-hasheq))
      (define func->primitive-refs (make-hasheq))
      (time-runtime-step
       "tree-shake:build-call-graph"
       (lambda ()
         (for ([form (in-list (cdr module))])
           (define name (module-func-name form))
           (when name
             (define refs
               (for/list ([sym (in-list (walk-symbol-refs (cddr form) primitive-ref->symbol))]
                          #:when (not (eq? sym name)))
                 sym))
             (hash-set! func->primitive-refs name refs)
             (hash-set! func->func-refs
                        name
                        (walk-symbol-refs (cddr form) named-funcs-ht))))))
      (define primitive-func-name?
        (λ (name) (and (symbol? name) (hash-ref primitive-func->symbol name #f))))
      (define exported-runtime-functions
        (for/list ([form (in-list (cdr module))]
                   #:do [(define name (module-func-name form))]
                   #:when (and name
                               (pair? (func-export-names form))
                               (not (primitive-func-name? name))))
          name))
      (define (collect-nonprimitive-function-refs x)
        (define refs (make-hasheq))
        (define (walk x)
          (cond
            [(symbol? x)
             (when (and (hash-ref named-funcs-ht x #f)
                        (not (primitive-func-name? x)))
               (hash-set! refs x #t))]
            [(pair? x)
             (walk (car x))
             (walk (cdr x))]
            [else (void)]))
        (walk x)
        (eq-set-keys refs))
      (define module-root-funcs
        (time-runtime-step
         "tree-shake:seed-module-roots"
         (lambda ()
           (let ([roots (list->eq-set exported-runtime-functions)])
             (for ([form (in-list (cdr module))]
                   #:unless (or (module-func-name form)
                                (and (pair? form)
                                     (eq? (car form) 'elem)
                                     (pair? (cdr form))
                                     (eq? (cadr form) 'declare)
                                     (pair? (cddr form))
                                     (eq? (caddr form) 'funcref))))
               (eq-set-add-all! roots (collect-nonprimitive-function-refs form)))
             (eq-set-keys roots)))))
      (define elem-root-functions
        (time-runtime-step
         "tree-shake:seed-elem-roots"
         (lambda ()
           (let ([roots (make-hasheq)])
             (for ([form (in-list (cdr module))]
                   #:when (and (pair? form)
                               (eq? (car form) 'elem)
                               (pair? (cdr form))
                               (eq? (cadr form) 'declare)
                               (pair? (cddr form))
                               (eq? (caddr form) 'funcref)))
               (eq-set-add-all! roots
                                (filter (lambda (name) (not (primitive-func-name? name)))
                                        (walk-symbol-refs form named-funcs-ht))))
             (eq-set-keys roots)))))
      (define (reachable-runtime-funcs roots)
        (let loop ([pending roots] [seen (make-hasheq)])
          (match pending
            ['() (eq-set-keys seen)]
            [(cons name rest)
             (cond
               [(hash-ref seen name #f)
                (loop rest seen)]
               [(primitive-func-name? name)
                (loop rest seen)]
               [else
                (hash-set! seen name #t)
                (loop (append (hash-ref func->func-refs name '()) rest)
                      seen)])])))
      (define runtime-funcs
        (time-runtime-step
         "tree-shake:reach-runtime-roots"
         (lambda ()
           (reachable-runtime-funcs module-root-funcs))))
      (define runtime-root-primitives
        (time-runtime-step
         "tree-shake:collect-runtime-root-primitives"
         (lambda ()
           (let ([roots (make-hasheq)])
             (for ([name (in-list runtime-funcs)])
               (eq-set-add-all! roots (hash-ref func->primitive-refs name '())))
             (eq-set-keys/sorted roots)))))
      (define primitive-graph
        (time-runtime-step
         "tree-shake:build-primitive-graph"
         (lambda ()
           (for/list ([pr (in-list (sort described-primitives symbol<?))])
             (define start ($ pr))
             (define reachable
               (let loop ([pending (hash-ref func->func-refs start '())]
                          [seen (let ([ht (make-hasheq)])
                                  (hash-set! ht start #t)
                                  ht)])
                 (match pending
                   ['() (eq-set-keys seen)]
                   [(cons name rest)
                    (cond
                      [(hash-ref seen name #f)
                       (loop rest seen)]
                      [(primitive-func-name? name)
                       (loop rest seen)]
                      [else
                       (hash-set! seen name #t)
                       (loop (append (hash-ref func->func-refs name '()) rest)
                             seen)])])))
             (cons pr
                   (let ([deps (make-hasheq)])
                     (for ([name (in-list reachable)])
                       (for ([dep (in-list (hash-ref func->primitive-refs name '()))]
                             #:unless (eq? dep pr))
                         (hash-set! deps dep #t)))
                     (eq-set-keys/sorted deps)))))))
      (define incoming-primitives
        (time-runtime-step
         "tree-shake:collect-incoming-primitives"
         (lambda ()
           (let ([incoming (make-hasheq)])
             (for ([entry (in-list primitive-graph)])
               (eq-set-add-all! incoming (cdr entry)))
            (eq-set-keys incoming)))))
      (define incoming-primitives-ht
        (list->eq-set incoming-primitives))
      (define runtime-root-primitives-ht
        (list->eq-set runtime-root-primitives))
      (define isolated-primitives
        (time-runtime-step
         "tree-shake:classify-isolated-primitives"
         (lambda ()
           (sort
            (for/list ([pr (in-list described-primitives)]
                       #:unless (or (hash-ref incoming-primitives-ht pr #f)
                                    (hash-ref runtime-root-primitives-ht pr #f)))
              pr)
            symbol<?))))
      (list (cons 'primitive-graph primitive-graph)
            (cons 'function-graph
                  (for/list ([name (in-list (sort named-funcs symbol<?))])
                    (cons name (sort (hash-ref func->func-refs name '()) symbol<?))))
            (cons 'function-primitive-refs
                  (for/list ([name (in-list (sort named-funcs symbol<?))])
                    (cons name (sort (hash-ref func->primitive-refs name '()) symbol<?))))
            (cons 'exported-runtime-functions (sort exported-runtime-functions symbol<?))
            (cons 'module-root-functions (sort module-root-funcs symbol<?))
            (cons 'elem-root-functions (sort elem-root-functions symbol<?))
            (cons 'reachable-runtime-functions (sort runtime-funcs symbol<?))
            (cons 'reachable-runtime-function-primitive-refs
                  (for/list ([name (in-list (sort runtime-funcs symbol<?))]
                             #:when (pair? (hash-ref func->primitive-refs name '())))
                    (cons name (sort (hash-ref func->primitive-refs name '()) symbol<?))))
            (cons 'runtime-root-primitives runtime-root-primitives)
            (cons 'isolated-primitives isolated-primitives)))

    (define (analyze-program-fragment program-forms runtime-analysis)
      (define runtime-function-names
        (for/list ([entry (in-list (primitive-graph-ref runtime-analysis 'function-graph))])
          (car entry)))
      (define runtime-function-name-set
        (list->eq-set runtime-function-names))
      (define primitive-ref->symbol
        (let ([ht (make-hasheq)])
          (for ([(k v) (in-hash primitive-func->symbol)])
            (hash-set! ht k v))
          (for ([(k v) (in-hash primitive-global->symbol)])
            (hash-set! ht k v))
          ht))
      (define runtime-root-functions
        (sort
         (remove-duplicates
          (for/fold ([roots '()]) ([form (in-list program-forms)])
            (append (walk-symbol-refs form runtime-function-name-set)
                    roots)))
         symbol<?))
      (define program-root-primitives
        (sort
         (remove-duplicates
          (append
           (filter primitive->description
                   (remove-duplicates
                    (append used-primitives
                            console-bridge-primitive-names)))
           (for/fold ([roots '()]) ([form (in-list program-forms)])
             (append (walk-symbol-refs form primitive-ref->symbol)
                     roots))))
         symbol<?))
      (list (cons 'program-root-functions runtime-root-functions)
            (cons 'program-root-primitives program-root-primitives)))

    (define (primitive-graph-ref analysis key)
      (cdr (assq key analysis)))

    (define (primitive-transitive-closure roots graph)
      (define graph-ht
        (for/hasheq ([entry (in-list graph)])
          (values (car entry) (cdr entry))))
      (let loop ([pending roots]
                 [seen (make-hasheq)])
        (match pending
          ['() (eq-set-keys/sorted seen)]
          [(cons pr rest)
           (if (hash-ref seen pr #f)
               (loop rest seen)
               (begin
                 (hash-set! seen pr #t)
                 (loop (append (hash-ref graph-ht pr '())
                             rest)
                      seen)))])))

    (define (primitive-retained-set analysis)
      (define graph          (primitive-graph-ref analysis 'primitive-graph))
      (define runtime-roots  (primitive-graph-ref analysis 'runtime-root-primitives))
      (define program-roots
        (primitive-graph-ref analysis 'program-root-primitives))
      (primitive-transitive-closure (append runtime-roots program-roots) graph))

    (define (primitive-refs-for-functions analysis function-names)
      (define function-primitive-refs
        (primitive-graph-ref analysis 'function-primitive-refs))
      (define function-primitive-refs-ht
        (for/hasheq ([entry (in-list function-primitive-refs)])
          (values (car entry) (cdr entry))))
      (define refs (make-hasheq))
      (for ([name (in-list function-names)])
        (eq-set-add-all! refs (hash-ref function-primitive-refs-ht name '())))
      (eq-set-keys/sorted refs))

    (define (retained-function-set analysis retained-primitives)
      (define function-graph (primitive-graph-ref analysis 'function-graph))
      (define module-roots   (primitive-graph-ref analysis 'module-root-functions))
      (define elem-roots     (primitive-graph-ref analysis 'elem-root-functions))
      (define program-roots  (primitive-graph-ref analysis 'program-root-functions))
      (define retained-primitive-ht (make-hasheq))
      (for ([pr (in-list retained-primitives)])
        (hash-set! retained-primitive-ht pr #t))
      (define retained-primitive-funcs
        (for/list ([pr (in-list retained-primitives)])
          ($ pr)))
      (define function-graph-ht
        (for/hasheq ([entry (in-list function-graph)])
          (values (car entry) (cdr entry))))
      (let loop ([pending (append module-roots elem-roots program-roots retained-primitive-funcs)]
                 [seen (make-hasheq)])
        (match pending
          ['() (eq-set-keys/sorted seen)]
          [(cons name rest)
           (cond
             [(hash-ref seen name #f)
              (loop rest seen)]
             [(and (hash-ref primitive-func->symbol name #f)
                   (not (hash-ref retained-primitive-ht
                                  (hash-ref primitive-func->symbol name)
                                  #f)))
              (loop rest seen)]
             [else
              (hash-set! seen name #t)
              (loop (append (hash-ref function-graph-ht name '())
                            rest)
                    seen)])])))

    (define (prune-runtime-module module retained-primitives retained-functions)
      (define retained-ht
        (for/hasheq ([name (in-list (append program-function-names
                                            program-driver-function-names
                                            retained-functions))])
          (values name #t)))
      (define retained-primitive-ht (make-hasheq))
      (for ([pr (in-list retained-primitives)])
        (hash-set! retained-primitive-ht pr #t))
      (for ([f (in-list active-ffi-foreigns)])
        (hash-set! retained-primitive-ht (foreign-racket-name f) #t))
      (define (retained-primitive-global-name? name)
        (define pr
          (or (hash-ref primitive-global->symbol name #f)
              (hash-ref ffi-global->symbol name #f)))
        (or (not pr)
            (hash-ref retained-primitive-ht pr #f)))
      (define (prune-elem-form form)
        (match form
          [`(elem declare funcref ,refs ...)
           `(elem declare funcref
                  ,@(for/list ([ref (in-list refs)]
                               #:when (match ref
                                        [`(ref.func ,name)
                                         (hash-ref retained-ht name #f)]
                                        [_ #t]))
                      ref))]
          [_ form]))
      (define (prune-entry-form form)
        (match form
          [`(func $entry ,parts ...)
           `(func $entry
                  ,@(for/list ([part (in-list parts)]
                               #:unless (and (primitive-global-init-form? part)
                                             (not (retained-primitive-global-name?
                                                   (cadr part)))))
                      part))]
          [_ form]))
      `(module
         ,@(for/list ([form (in-list (cdr module))]
                      #:unless (let ([name (module-func-name form)])
                                 (and name
                                      (not (hash-ref retained-ht name #f))))
                      #:unless (let ([name (module-global-name form)])
                                 (and name
                                      (not (retained-primitive-global-name? name)))))
             (cond
               [(eq? (module-func-name form) '$entry)
                (prune-entry-form form)]
               [(and (pair? form)
                     (eq? (car form) 'elem))
                (prune-elem-form form)]
               [else form]))))

    (define (write-runtime-primitive-report! analysis retained-primitives)
      (define report-path (current-runtime-primitive-report-path))
      (when report-path
        (define program-root-primitives
          (primitive-graph-ref analysis 'program-root-primitives))
        (define program-root-functions
          (primitive-graph-ref analysis 'program-root-functions))
        (define isolated-primitives
          (primitive-graph-ref analysis 'isolated-primitives))
        (define runtime-root-primitives
          (primitive-graph-ref analysis 'runtime-root-primitives))
        (define total-primitives
          (length described-primitives))
        (define retained-count
          (length retained-primitives))
        (with-output-to-file report-path
          (λ ()
            (pretty-write
             (list (list 'summary
                         (list 'total-primitives total-primitives)
                         (list 'program-root-count (length program-root-primitives))
                         (list 'program-root-function-count (length program-root-functions))
                         (list 'retained-count retained-count)
                         (list 'isolated-count (length isolated-primitives))
                         (list 'runtime-root-count (length runtime-root-primitives))
                         (list 'omitted-count (- total-primitives retained-count)))
                   (cons 'program-root-primitives
                         program-root-primitives)
                   (cons 'program-root-functions
                         program-root-functions)
                   (cons 'retained-primitives retained-primitives)
                   (cons 'isolated-primitives isolated-primitives)
                   (cons 'module-root-functions
                         (primitive-graph-ref analysis 'module-root-functions))
                   (cons 'reachable-runtime-functions
                         (primitive-graph-ref analysis 'reachable-runtime-functions))
                   (cons 'reachable-runtime-function-primitive-refs
                         (primitive-graph-ref analysis
                                             'reachable-runtime-function-primitive-refs))
                   (cons 'runtime-root-primitives runtime-root-primitives)
                   (cons 'primitive-graph
                         (primitive-graph-ref analysis 'primitive-graph)))))
          #:exists 'replace)))

    (define (declare-primitives-as-globals)
      (for/list ([pr (in-list (active-described-primitives-sorted))])
        `(global ,($ (prim: pr)) (mut (ref eq)) ,(Imm (undefined)))))

    (define (declare-ffi-primitives-as-globals)
      (for/list ([f (in-list active-ffi-foreigns)])
        (define pr (foreign-racket-name f))
        `(global ,($ (prim: pr)) (mut (ref eq)) ,(Imm (undefined)))))


    (define (arity-range? a min-arity max-arity)
      (and (list? a)
           (for/and ([n (in-list a)])
             (and (integer? n)
                  (<= min-arity n)
                  (<= n max-arity)))
           (let ([uniq (remove-duplicates a)])
             (and (= (length uniq) (+ 1 (- max-arity min-arity)))
                  (for/and ([n (in-range min-arity (add1 max-arity))])
                    (memq n uniq))))))

    (define (arity-2-3? a)
      (and (list? a)
           (let ([uniq (remove-duplicates a)])
             (and (= (length uniq) 2)
                  (memq 2 uniq)
                  (memq 3 uniq)))))

    (define (arity-3-4? a)
      (and (list? a)
           (let ([uniq (remove-duplicates a)])
             (and (= (length uniq) 2)
                  (memq 3 uniq)
                  (memq 4 uniq)))))

    (define (arity->internal-representation a)
      (match a
        [(arity-at-least n) (- (- n) 1)]
        [(? number? a)      a]
        [(? arity-2-3?)     2]
        [(? arity-3-4?)     3]
        [#f                 #f]
        [_                  #f]
        [_                  (error
                             'arity->internal-representation "got: ~a" a)]))

    (define (arity-entry->marker a)
      (match a
        [(? exact-nonnegative-integer? n) n]
        [(arity-at-least n)               (- (- n) 1)]
        [_                                #f]))

    (define (canonicalize-arity-markers markers)
      (define (dedup xs)
        (reverse
         (for/fold ([acc '()]) ([x (in-list xs)])
           (if (member x acc) acc (cons x acc)))))
      (define exacts
        (for/list ([m (in-list markers)]
                   #:when (>= m 0))
          m))
      (define at-least-starts
        (for/list ([m (in-list markers)]
                   #:when (< m 0))
          (- (- m) 1)))
      (define min-at-least
        (and (pair? at-least-starts)
             (apply min at-least-starts)))
      (define exacts-dedup (dedup exacts))
      (define exacts-usable
        (if min-at-least
            (filter (λ (n) (< n min-at-least)) exacts-dedup)
            exacts-dedup))
      (define exacts-sorted (sort exacts-usable <))
      (cond
        [min-at-least
         (define m (- (- min-at-least) 1))
         (if (null? exacts-sorted)
             (list m)
             (append exacts-sorted (list m)))]
        [else exacts-sorted]))

    (define (arity->markers a)
      (match a
        [(? exact-nonnegative-integer? n)
         (list n)]
        [(arity-at-least n)
         (list (- (- n) 1))]
        [(? list? as)
         (define ms (for/list ([x (in-list as)]) (arity-entry->marker x)))
         (and (andmap integer? ms)
              (canonicalize-arity-markers ms))]
        [#f #f]
        [_ #f]))

    (define (arity->procedure-field-expr a)
      (define ms (arity->markers a))
      (cond
        [(not ms)         (Imm #f)]
        [(null? ms)       `(ref.cast (ref eq) (array.new_fixed $I32Array 0))]
        [(null? (cdr ms)) (Imm (car ms))]
        [else
         `(ref.cast (ref eq)
                    (array.new_fixed $I32Array
                                     ,(length ms)
                                     ,@(for/list ([m (in-list ms)])
                                         `(i32.const ,m))))]))

    ;; See $primitive-invoke for an explanation of shapes.

    (define (arity->shape a)
      (match a
        [(arity-at-least n) (if (>= n 4) 30 (+ 6 n))]
        [(? number? n)      (if (= n 6) 26 (min n 5))]
        [(? (λ (a) (arity-range? a 0 1)))  16]
        [(? (λ (a) (arity-range? a 0 2)))  17]
        [(? (λ (a) (arity-range? a 0 3)))  27]
        [(? (λ (a) (arity-range? a 0 4)))  28]
        [(? (λ (a) (arity-range? a 0 5)))  29]
        [(? (λ (a) (arity-range? a 1 2)))  18]
        [(? (λ (a) (arity-range? a 1 3)))  19]
        [(? (λ (a) (arity-range? a 1 4)))  20]
        [(? (λ (a) (arity-range? a 1 5)))  21]
        [(? (λ (a) (arity-range? a 2 3)))  14]
        [(? (λ (a) (arity-range? a 2 4)))  22]
        [(? (λ (a) (arity-range? a 2 5)))  23]
        [(? (λ (a) (arity-range? a 3 4)))  15]
        [(? (λ (a) (arity-range? a 3 5)))  24]
        [(? (λ (a) (arity-range? a 6 7)))  25]
        [_ #f]))

    ; These functions are variadic functions that can handle the
    ; rest arguments both as an $Args array and as a list.
    ; The $Args convention is used by inlining.
    ; The list  convention by `apply`, `map` and others.
    (define primitive-variadic-args
      '(bytes
        date
        date*
        make-date
        make-date*
        string
        vector
        treelist
        treelist-append
        module-call-with-prompt
        chaperone-procedure
        chaperone-struct
        chaperone-vector
        chaperone-box
        chaperone-hash
        unsafe-chaperone-procedure
        unsafe-impersonate-procedure
        raise-argument-error
        raise-argument-error*
        raise-arguments-error
        vector-immutable
        values
        void))

    (define primitive-shapes
      '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31))

    (define (primitive->shape pr [desc (primitive->description pr)])
      (and desc
           (let ([base (arity->shape (primitive-description-arity desc))])
             (and base
                  (cond
                    [(= base 30)
                     (if (memq pr primitive-variadic-args) 31 base)]
                    [(>= base 6)
                     (if (memq pr primitive-variadic-args) (+ base 4) base)]
                    [else base])))))

    (define (shape->invoker shape)
      (match shape
        [0  'primitive-invoke:shape-0]
        [1  'primitive-invoke:shape-1]
        [2  'primitive-invoke:shape-2]
        [3  'primitive-invoke:shape-3]
        [4  'primitive-invoke:shape-4]
        [5  'primitive-invoke:shape-5]
        [6  'primitive-invoke:shape-6]
        [7  'primitive-invoke:shape-7]
        [8  'primitive-invoke:shape-8]
        [9  'primitive-invoke:shape-9]
        [10 'primitive-invoke:shape-10]
        [11 'primitive-invoke:shape-11]
        [12 'primitive-invoke:shape-12]
        [13 'primitive-invoke:shape-13]
        [14 'primitive-invoke:shape-14]
        [15 'primitive-invoke:shape-15]
        [16 'primitive-invoke:shape-16]
        [17 'primitive-invoke:shape-17]
        [18 'primitive-invoke:shape-18]
        [19 'primitive-invoke:shape-19]
        [20 'primitive-invoke:shape-20]
        [21 'primitive-invoke:shape-21]
        [22 'primitive-invoke:shape-22]
        [23 'primitive-invoke:shape-23]
        [24 'primitive-invoke:shape-24]
        [25 'primitive-invoke:shape-25]
        [26 'primitive-invoke:shape-26]
        [27 'primitive-invoke:shape-27]
        [28 'primitive-invoke:shape-28]
        [29 'primitive-invoke:shape-29]
        [30 'primitive-invoke:shape-30]
        [31 'primitive-invoke:shape-31]
        [_  'primitive-invoke]))

    (define (primitive-invoker-tail shape)
      (match shape
        [0 ; exact 0
         `((if (i32.eqz (local.get $argc))
               (then (if (ref.test (ref $Prim0) (local.get $code))
                         (then (return_call_ref $Prim0
                                                (ref.cast (ref $Prim0) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [1 ; exact 1
         `((if (i32.eq (local.get $argc) (i32.const 1))
               (then (if (ref.test (ref $Prim1) (local.get $code))
                         (then (return_call_ref $Prim1
                                                (local.get $a0)
                                                (ref.cast (ref $Prim1) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [2 ; exact 2
         `((if (i32.eq (local.get $argc) (i32.const 2))
               (then (if (ref.test (ref $Prim2) (local.get $code))
                         (then (return_call_ref $Prim2
                                                (local.get $a0)
                                                (local.get $a1)
                                                (ref.cast (ref $Prim2) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [3 ; exact 3
         `((if (i32.eq (local.get $argc) (i32.const 3))
               (then (if (ref.test (ref $Prim3) (local.get $code))
                         (then (return_call_ref $Prim3
                                                (local.get $a0)
                                                (local.get $a1)
                                                (local.get $a2)
                                                (ref.cast (ref $Prim3) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [4 ; exact 4
         `((if (i32.eq (local.get $argc) (i32.const 4))
               (then (if (ref.test (ref $Prim4) (local.get $code))
                         (then (return_call_ref $Prim4
                                                (local.get $a0)
                                                (local.get $a1)
                                                (local.get $a2)
                                                (array.get $Args (local.get $args) (i32.const 3))
                                                (ref.cast (ref $Prim4) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [5 ; exact 5
         `((if (i32.eq (local.get $argc) (i32.const 5))
               (then (if (ref.test (ref $Prim5) (local.get $code))
                         (then (return_call_ref $Prim5
                                                (local.get $a0)
                                                (local.get $a1)
                                                (local.get $a2)
                                                (array.get $Args (local.get $args) (i32.const 3))
                                                (array.get $Args (local.get $args) (i32.const 4))
                                                (ref.cast (ref $Prim5) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [6 ; at least 0, rest arguments as list
         `((if (ref.test (ref $Prim>=0) (local.get $code))
               (then (local.set $rest
                                (call $rest-arguments->list
                                      (local.get $args)
                                      (i32.const 0)))
                     (return_call_ref $Prim>=0
                                      (local.get $rest)
                                      (ref.cast (ref $Prim>=0) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [7 ; at least 1, rest arguments as list
         `((if (i32.ge_u (local.get $argc) (i32.const 1))
               (then (if (ref.test (ref $Prim>=1) (local.get $code))
                         (then (local.set $rest
                                          (call $rest-arguments->list
                                                (local.get $args)
                                                (i32.const 1)))
                               (return_call_ref $Prim>=1
                                                (local.get $a0)
                                                (local.get $rest)
                                                (ref.cast (ref $Prim>=1) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [8 ; at least 2, rest arguments as list
         `((if (i32.ge_u (local.get $argc) (i32.const 2))
               (then (if (ref.test (ref $Prim>=2) (local.get $code))
                         (then (local.set $rest
                                          (call $rest-arguments->list
                                                (local.get $args)
                                                (i32.const 2)))
                               (return_call_ref $Prim>=2
                                                (local.get $a0)
                                                (local.get $a1)
                                                (local.get $rest)
                                                (ref.cast (ref $Prim>=2) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [9 ; at least 3, rest arguments as list
         `((if (i32.ge_u (local.get $argc) (i32.const 3))
               (then
                (if (ref.test (ref $Prim>=3) (local.get $code))
                    (then (local.set $rest
                                     (call $rest-arguments->list
                                           (local.get $args)
                                           (i32.const 3)))
                          (return_call_ref $Prim>=3
                                           (local.get $a0)
                                           (local.get $a1)
                                           (local.get $a2)
                                           (local.get $rest)
                                           (ref.cast (ref $Prim>=3) (local.get $code))))
                    (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [10 ; at least 0, rest arguments as $Args array
         `((if (ref.test (ref $Prim>=0) (local.get $code))
               (then (return_call_ref $Prim>=0
                                      (local.get $args)
                                      (ref.cast (ref $Prim>=0) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [11 ; at least 1, rest arguments as $Args array
         `((if (i32.ge_u (local.get $argc) (i32.const 1))
               (then (if (ref.test (ref $Prim>=1) (local.get $code))
                         (then (return_call_ref $Prim>=1
                                                (local.get $a0)
                                                (call $rest-arguments->args
                                                      (local.get $args)
                                                      (i32.const 1))
                                                (ref.cast (ref $Prim>=1) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [12 ; at least 2, rest arguments as $Args array
         `((if (i32.ge_u (local.get $argc) (i32.const 2))
               (then (if (ref.test (ref $Prim>=2) (local.get $code))
                         (then (return_call_ref $Prim>=2
                                                (local.get $a0)
                                                (local.get $a1)
                                                (call $rest-arguments->args
                                                      (local.get $args)
                                                      (i32.const 2))
                                                (ref.cast (ref $Prim>=2) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [13 ; at least 3, rest arguments as $Args array
         `((if (i32.ge_u (local.get $argc) (i32.const 3))
               (then
                (if (ref.test (ref $Prim>=3) (local.get $code))
                    (then (return_call_ref $Prim>=3
                                           (local.get $a0)
                                           (local.get $a1)
                                           (local.get $a2)
                                           (call $rest-arguments->args
                                                 (local.get $args)
                                                 (i32.const 3))
                                           (ref.cast (ref $Prim>=3) (local.get $code))))
                    (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [14 ; between 2 and 3 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 2))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 3))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim23) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 2))
                         (then (local.set $a2 (global.get $missing))))
                     (return_call_ref $Prim23
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (ref.cast (ref $Prim23) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [15 ; between 3 and 4 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 3))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 4))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim34) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 3))
                         (then (local.set $a3 (global.get $missing)))
                         (else (local.set $a3
                                          (array.get $Args (local.get $args) (i32.const 3)))))
                     (return_call_ref $Prim34
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (ref.cast (ref $Prim34) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [16 ; between 0 and 1 arguments
         `((if (i32.gt_u (local.get $argc) (i32.const 1))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim01) (local.get $code))
               (then (if (i32.eqz (local.get $argc))
                         (then (local.set $a0 (global.get $missing))))
                     (return_call_ref $Prim01
                                      (local.get $a0)
                                      (ref.cast (ref $Prim01) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [17 ; between 0 and 2 arguments
         `((if (i32.gt_u (local.get $argc) (i32.const 2))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim02) (local.get $code))
               (then (if (i32.eqz (local.get $argc))
                         (then (local.set $a0 (global.get $missing))
                               (local.set $a1 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 1))
                                   (then (local.set $a1 (global.get $missing))))))
                     (return_call_ref $Prim02
                                      (local.get $a0)
                                      (local.get $a1)
                                      (ref.cast (ref $Prim02) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [27 ; between 0 and 3 arguments
         `((if (i32.gt_u (local.get $argc) (i32.const 3))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim03) (local.get $code))
               (then (if (i32.eqz (local.get $argc))
                         (then (local.set $a0 (global.get $missing))
                               (local.set $a1 (global.get $missing))
                               (local.set $a2 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 1))
                                   (then (local.set $a1 (global.get $missing))
                                         (local.set $a2 (global.get $missing)))
                                   (else (if (i32.eq (local.get $argc) (i32.const 2))
                                             (then (local.set $a2 (global.get $missing))))))))
                     (return_call_ref $Prim03
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (ref.cast (ref $Prim03) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [28 ; between 0 and 4 arguments
         `((if (i32.gt_u (local.get $argc) (i32.const 4))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim4) (local.get $code))
               (then (if (i32.eqz (local.get $argc))
                         (then (local.set $a0 (global.get $missing))
                               (local.set $a1 (global.get $missing))
                               (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 1))
                                   (then (local.set $a1 (global.get $missing))
                                         (local.set $a2 (global.get $missing))
                                         (local.set $a3 (global.get $missing)))
                                   (else (if (i32.eq (local.get $argc) (i32.const 2))
                                             (then (local.set $a2 (global.get $missing))
                                                   (local.set $a3 (global.get $missing)))
                                             (else (if (i32.eq (local.get $argc) (i32.const 3))
                                                       (then (local.set $a3 (global.get $missing)))
                                                       (else (local.set $a3
                                                                        (array.get $Args (local.get $args) (i32.const 3)))))))))))
                     (return_call_ref $Prim4
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (ref.cast (ref $Prim4) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [29 ; between 0 and 5 arguments
         `((if (i32.gt_u (local.get $argc) (i32.const 5))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim5) (local.get $code))
               (then (if (i32.eqz (local.get $argc))
                         (then (local.set $a0 (global.get $missing))
                               (local.set $a1 (global.get $missing))
                               (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 1))
                                   (then (local.set $a1 (global.get $missing))
                                         (local.set $a2 (global.get $missing))
                                         (local.set $a3 (global.get $missing))
                                         (local.set $a4 (global.get $missing)))
                                   (else (if (i32.eq (local.get $argc) (i32.const 2))
                                             (then (local.set $a2 (global.get $missing))
                                                   (local.set $a3 (global.get $missing))
                                                   (local.set $a4 (global.get $missing)))
                                             (else (if (i32.eq (local.get $argc) (i32.const 3))
                                                       (then (local.set $a3 (global.get $missing))
                                                             (local.set $a4 (global.get $missing)))
                                                       (else (if (i32.eq (local.get $argc) (i32.const 4))
                                                                 (then (local.set $a3
                                                                                  (array.get $Args (local.get $args) (i32.const 3)))
                                                                       (local.set $a4 (global.get $missing)))
                                                                 (else (local.set $a3
                                                                                  (array.get $Args (local.get $args) (i32.const 3)))
                                                                       (local.set $a4
                                                                                  (array.get $Args (local.get $args) (i32.const 4)))))))))))))
                     (return_call_ref $Prim5
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (local.get $a4)
                                      (ref.cast (ref $Prim5) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [18 ; between 1 and 2 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 1))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 2))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim12) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 1))
                         (then (local.set $a1 (global.get $missing))))
                     (return_call_ref $Prim12
                                      (local.get $a0)
                                      (local.get $a1)
                                      (ref.cast (ref $Prim12) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [19 ; between 1 and 3 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 1))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 3))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim13) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 1))
                         (then (local.set $a1 (global.get $missing))
                               (local.set $a2 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 2))
                                   (then (local.set $a2 (global.get $missing))))))
                     (return_call_ref $Prim13
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (ref.cast (ref $Prim13) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [20 ; between 1 and 4 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 1))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 4))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim14) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 1))
                         (then (local.set $a1 (global.get $missing))
                               (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))))
                     (if (i32.eq (local.get $argc) (i32.const 2))
                         (then (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))))
                     (if (i32.eq (local.get $argc) (i32.const 3))
                         (then (local.set $a3 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 4))
                                   (then (local.set $a3
                                                    (array.get $Args (local.get $args) (i32.const 3)))))))
                     (return_call_ref $Prim14
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (ref.cast (ref $Prim14) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [21 ; between 1 and 5 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 1))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 5))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim15) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 1))
                         (then (local.set $a1 (global.get $missing))
                               (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing))))
                     (if (i32.eq (local.get $argc) (i32.const 2))
                         (then (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing))))
                     (if (i32.eq (local.get $argc) (i32.const 3))
                         (then (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 4))
                                   (then (local.set $a3
                                                    (array.get $Args (local.get $args) (i32.const 3)))
                                         (local.set $a4 (global.get $missing)))
                                   (else (if (i32.eq (local.get $argc) (i32.const 5))
                                             (then (local.set $a3
                                                              (array.get $Args (local.get $args) (i32.const 3)))
                                                   (local.set $a4
                                                              (array.get $Args (local.get $args) (i32.const 4)))))))))
                     (return_call_ref $Prim15
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (local.get $a4)
                                      (ref.cast (ref $Prim15) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [22 ; between 2 and 4 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 2))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 4))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim24) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 2))
                         (then (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))))
                     (if (i32.eq (local.get $argc) (i32.const 3))
                         (then (local.set $a3 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 4))
                                   (then (local.set $a3
                                                    (array.get $Args (local.get $args) (i32.const 3)))))))
                     (return_call_ref $Prim24
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (ref.cast (ref $Prim24) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [23 ; between 2 and 5 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 2))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 5))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim25) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 2))
                         (then (local.set $a2 (global.get $missing))
                               (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing))))
                     (if (i32.eq (local.get $argc) (i32.const 3))
                         (then (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 4))
                                   (then (local.set $a3
                                                    (array.get $Args (local.get $args) (i32.const 3)))
                                         (local.set $a4 (global.get $missing)))
                                   (else (if (i32.eq (local.get $argc) (i32.const 5))
                                             (then (local.set $a3
                                                              (array.get $Args (local.get $args) (i32.const 3)))
                                                   (local.set $a4
                                                              (array.get $Args (local.get $args) (i32.const 4)))))))))
                     (return_call_ref $Prim25
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (local.get $a4)
                                      (ref.cast (ref $Prim25) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [24 ; between 3 and 5 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 3))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 5))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim35) (local.get $code))
               (then (if (i32.eq (local.get $argc) (i32.const 3))
                         (then (local.set $a3 (global.get $missing))
                               (local.set $a4 (global.get $missing)))
                         (else (if (i32.eq (local.get $argc) (i32.const 4))
                                   (then (local.set $a3
                                                    (array.get $Args (local.get $args) (i32.const 3)))
                                         (local.set $a4 (global.get $missing)))
                                   (else (if (i32.eq (local.get $argc) (i32.const 5))
                                             (then (local.set $a3
                                                              (array.get $Args (local.get $args) (i32.const 3)))
                                                   (local.set $a4
                                                              (array.get $Args (local.get $args) (i32.const 4)))))))))
                     (return_call_ref $Prim35
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (local.get $a4)
                                      (ref.cast (ref $Prim35) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [25 ; between 6 and 7 arguments
         `((if (i32.lt_u (local.get $argc) (i32.const 6))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (i32.gt_u (local.get $argc) (i32.const 7))
               (then (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (if (ref.test (ref $Prim67) (local.get $code))
               (then (local.set $a0 (array.get $Args (local.get $args) (i32.const 0)))
                     (local.set $a1 (array.get $Args (local.get $args) (i32.const 1)))
                     (local.set $a2 (array.get $Args (local.get $args) (i32.const 2)))
                     (local.set $a3 (array.get $Args (local.get $args) (i32.const 3)))
                     (local.set $a4 (array.get $Args (local.get $args) (i32.const 4)))
                     (local.set $a5 (array.get $Args (local.get $args) (i32.const 5)))
                     (if (i32.eq (local.get $argc) (i32.const 6))
                         (then (local.set $a6 (global.get $missing)))
                         (else (local.set $a6
                                          (array.get $Args (local.get $args) (i32.const 6)))))
                     (return_call_ref $Prim67
                                      (local.get $a0)
                                      (local.get $a1)
                                      (local.get $a2)
                                      (local.get $a3)
                                      (local.get $a4)
                                      (local.get $a5)
                                      (local.get $a6)
                                      (ref.cast (ref $Prim67) (local.get $code))))
               (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
           (unreachable))]
        [26 ; exact 6
         `((if (i32.eq (local.get $argc) (i32.const 6))
               (then (if (ref.test (ref $Prim6) (local.get $code))
                         (then (return_call_ref $Prim6
                                                (local.get $a0)
                                                (local.get $a1)
                                                (local.get $a2)
                                                (array.get $Args (local.get $args) (i32.const 3))
                                                (array.get $Args (local.get $args) (i32.const 4))
                                                (array.get $Args (local.get $args) (i32.const 5))
                                                (ref.cast (ref $Prim6) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [30 ; at least 4, rest arguments as list
         `((if (i32.ge_u (local.get $argc) (i32.const 4))
               (then
                (if (ref.test (ref $Prim>=4) (local.get $code))
                    (then (local.set $a3
                                     (array.get $Args (local.get $args) (i32.const 3)))
                          (local.set $rest
                                     (call $rest-arguments->list
                                           (local.get $args)
                                           (i32.const 4)))
                          (return_call_ref $Prim>=4
                                           (local.get $a0)
                                           (local.get $a1)
                                           (local.get $a2)
                                           (local.get $a3)
                                           (local.get $rest)
                                           (ref.cast (ref $Prim>=4) (local.get $code))))
                    (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [31 ; at least 4, rest arguments as $Args array
         `((if (i32.ge_u (local.get $argc) (i32.const 4))
               (then
                (if (ref.test (ref $Prim>=4) (local.get $code))
                    (then (return_call_ref $Prim>=4
                                           (local.get $a0)
                                           (local.get $a1)
                                           (local.get $a2)
                                           (array.get $Args (local.get $args) (i32.const 3))
                                           (call $rest-arguments->args
                                                 (local.get $args)
                                                 (i32.const 4))
                                           (ref.cast (ref $Prim>=4) (local.get $code))))
                    (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
               (else (return (call $primitive-invoke:raise-arity-error
                                   (local.get $pproc) (local.get $argc)))))
           (unreachable))]
        [_ (error 'primitive-invoker-tail "unknown shape: ~a" shape)]))

    (define (primitive-invoker shape)
      `(func ,($ (shape->invoker shape)) (type $ProcedureInvoker)
             (param $proc (ref $Procedure))
             (param $args (ref $Args))
             (result      (ref eq))

             (local $pproc (ref $PrimitiveProcedure))
             (local $code  (ref null func))

             (local $argc      i32)

             (local $a0 (ref eq))
             (local $a1 (ref eq))
             (local $a2 (ref eq))
             (local $a3 (ref eq)) ; ? needed - see primitive-invoker-tail above
             (local $a4 (ref eq)) ; ? needed
             (local $a5 (ref eq)) ; ? needed
             (local $a6 (ref eq)) ; ? needed
             (local $rest (ref eq)) ; todo: we should limit this to fewer locals

             (local.set $a0   (global.get $null))
             (local.set $a1   (global.get $null))
             (local.set $a2   (global.get $null))
             (local.set $a3   (global.get $null))
             (local.set $a4   (global.get $null)) ; todo remove these
             (local.set $a5   (global.get $null)) ; todo remove these
             (local.set $a6   (global.get $null)) ; todo remove these
             (local.set $rest (global.get $null))

             (local.set $pproc
                        (ref.cast (ref $PrimitiveProcedure) (local.get $proc)))

             (local.set $code
                        (struct.get $PrimitiveProcedure $code (local.get $pproc)))

             (if (ref.is_null (local.get $code))
                 (then (return (call $raise-no-code (local.get $pproc)))))

             (local.set $argc (array.len (local.get $args)))

             (if (i32.gt_u (local.get $argc) (i32.const 0))
                 (then
                  (local.set $a0
                             (array.get $Args (local.get $args) (i32.const 0)))))

             (if (i32.gt_u (local.get $argc) (i32.const 1))
                 (then
                  (local.set $a1
                             (array.get $Args (local.get $args) (i32.const 1)))))

             (if (i32.gt_u (local.get $argc) (i32.const 2))
                 (then
                  (local.set $a2
                             (array.get $Args (local.get $args) (i32.const 2)))))

             ,@(primitive-invoker-tail shape)))


    (define (min-arity a)
      (match a
        [(arity-at-least n) n]
        [(? number? n)      n]
        [(? list? l)        (apply min (map min-arity l))]
        [_                  (error 'min-arity "got: ~a" a)]))

    ; If a primitive is handled in the inliner, but hasn't been
    ; implemented here in `runtime-wasm.rkt` then put the symbol here.
    (define todo-handle-later '())

    (define (initialize-primitives-as-globals)
      (for/list ([pr (in-list (active-described-primitives-sorted))]
                 #:do [(define desc (primitive->description pr))])
        (define ar    (primitive-description-arity desc))
        (define shape (primitive->shape pr desc))
        (define $name ($ (string->symbol (~a "symbol:" pr))))
        `(global.set ,($ (prim: pr))
                     (struct.new $PrimitiveProcedure
                      ; for $Procedure
                      (i32.const 0)                               ; hash
                      (global.get ,$name)                         ; name  (used by object-name)
                      ,(arity->procedure-field-expr ar)           ; arity
                      (global.get $the-racket/primitive-realm)    ; realm
                      #;(ref.func $primitive-invoke)
                      (ref.func ,($ (shape->invoker shape)))
                      (ref.func ,($ pr))
                      ,(Imm #f
                            #;(arity->internal-representation
                               (primitive-description-result-arity desc)))))))

    (define (initialize-ffi-primitives-as-globals)
      (for/list ([f (in-list active-ffi-foreigns)])
        (define pr    (foreign-racket-name f))
        (define ar    (length (foreign-argument-types f)))
        ;; FFI wrappers with more than six arguments use the normal variadic
        ;; rest-list function type. The procedure object still records the
        ;; exact source arity, and the generated wrapper checks it after
        ;; receiving the rest list.
        (define shape (if (> ar 6) 6 (arity->shape ar)))
        (define $name ($ (string->symbol (~a "symbol:" pr))))
        `(global.set ,($ (prim: pr))
                     (struct.new $PrimitiveProcedure
                      ; for $Procedure
                      (i32.const 0)                               ; hash
                      (global.get ,$name)                         ; name  (used by object-name)
                      ,(arity->procedure-field-expr ar)           ; arity
                      (global.get $the-racket/primitive-realm)    ; realm
                      (ref.func ,($ (shape->invoker shape)))
                      (ref.func ,($ pr))
                      ,(Imm #f)))))

    ;; String constants used in the runtime
    ;;  `string-constants holds the constants passed by `generate-code` in `compiler.rkt`
    (define runtime-constant-registry
      (make-runtime-constant-registry string-constants
                                      bytes-constants
                                      symbol-constants))

    (define (add-runtime-string-constant name string)
      (runtime-constant-registry-add-string! runtime-constant-registry name string))

    (define (declare-runtime-string-constants)
      (runtime-constant-registry-declare-strings runtime-constant-registry))

    (define (initialize-runtime-string-constants)
      (runtime-constant-registry-initialize-strings runtime-constant-registry))

    ;; Bytes constants used in the runtime
    ;;  `bytes-constants holds the constants passed by `generate-code` in `compiler.rkt`
    (define (add-runtime-bytes-constant name bytes)
      (runtime-constant-registry-add-bytes! runtime-constant-registry name bytes))

    (define (declare-runtime-bytes-constants)
      (runtime-constant-registry-declare-bytes runtime-constant-registry))

    (define (initialize-runtime-bytes-constants)
      (runtime-constant-registry-initialize-bytes runtime-constant-registry))

    ;; Symbol constants used in the runtime
    ;;  `runtime-symbol-constants` holds the constants passed by `generate-code`
    ;; in `compiler.rkt`
    (define (add-runtime-symbol-constant symbol)
      (runtime-constant-registry-add-symbol! runtime-constant-registry symbol))

    (define (declare-runtime-symbol-constants)
      (runtime-constant-registry-declare-symbols! runtime-constant-registry))

    (define (initialize-runtime-symbol-constants)
      (runtime-constant-registry-initialize-symbols! runtime-constant-registry))

    ;; String and symbol constants used in the runtime

    ; Names of each primitive
    (for ([pr (in-list (active-described-primitives-sorted))])
      (add-runtime-symbol-constant pr))

    (define (add-ffi-symbol-constants)
      (for ([pr (in-list (active-ffi-primitive-names))])
        (add-runtime-symbol-constant pr)))

    (add-ffi-symbol-constants)

    (for-each add-runtime-symbol-constant primitive-table-module-symbols)

    (define linklet-body-core-reserved-symbols
      '(lambda
        case-lambda
        let-values
        letrec-values
        if
        begin
        begin0
        begin-unsafe
        set!
        quote
        with-continuation-mark
        #%variable-reference))

    (for-each add-runtime-symbol-constant
              (remove-duplicates (append linklet-body-core-reserved-symbols all-primitives)
                                 eq?))

    (define linklet-body-reserved-symbols
      (sort (remove-duplicates
             (append linklet-body-core-reserved-symbols all-primitives)
             eq?)
            symbol<?))

    (let ()
      ; TODO: remove primitives from this list
      (define symbols
        '(racket
          racket/primitive

          Other
          CR
          LF
          Control
          Extend
          ZWJ
          Regional_Indicator
          Prepend
          SpacingMark
          L
          V
          T
          LV
          LVT

          in-list
          in-vector
          in-mlist
          in-range
          in-naturals
          in-string

          can-impersonate

          prop:sealed
          sealed
          prop:evt
          evt
          prefab
          prop:object-name
          object-name
          prop:procedure
          procedure
          prop:exn:srclocs
          exn:srclocs
          exn:srclocs?
          exn:srclocs-accessor
          prop:input-port
          input-port
          prop:output-port
          output-port
          pair
          impersonator-prop:application-mark
          prop:checked-procedure
          checked-procedure
          prop:impersonator-of
          impersonator-of
          prop:method-arity-error
          method-arity-error
          prop:arity-string
          arity-string
          prop:incomplete-arity
          incomplete-arity
          prop:authentic
          authentic
          prop:custom-write
          custom-write
          custom-write?
          custom-write-accessor
          prop:custom-print-quotable
          custom-print-quotable
          custom-print-quotable?
          custom-print-quotable-accessor
          prop:equal+hash
          equal+hash

          string
          unix
          windows
          posix
          gai
          macosx
          os
          os*
          arch
          wasm32
          word
          vm
          chez-scheme
          gc
          link
          static
          machine
          target-machine
          webracket
          fs-change
          supported
          file-level
          cross

          linefeed
          return
          return-linefeed
          any
          any-one
          read
          write
          execute
          bits
          binary
          text
          append
          home-dir
          pref-dir
          pref-file
          temp-dir
          init-dir
          init-file
          config-dir
          host-config-dir
          addon-dir
          host-addon-dir
          cache-dir
          doc-dir
          desk-dir
          sys-dir
          exec-file
          run-file
          collects-dir
          host-collects-dir
          orig-dir
          update
          can-update
          replace
          truncate
          must-truncate
          truncate/replace
          file
          directory

          srcloc
          make-srcloc
          srcloc?
          srcloc-source
          srcloc-line
          srcloc-column
          srcloc-position
          srcloc-span
          srcloc->string

          arity-at-least
          make-arity-at-least
          arity-at-least?
          arity-at-least-value

          correlated
          make-correlated
          correlated?
          correlated-source
          correlated-line
          correlated-column
          correlated-position
          correlated-span
          correlated-e
          correlated-props         ; remove?
          datum->correlated
          correlated-property
          correlated-property-symbol-keys

          instance
          instance-name
          instance-data
          instance-variable-box
          instance-variable-names
          instance-variable-value
          instance-set-variable-value!
          instance-unset-variable!
          make-instance
          link
          linklet-body-reserved-symbol?
          linklet-bundle?
          hash->linklet-bundle
          linklet-bundle->hash
          linklet-directory?
          hash->linklet-directory
          linklet-directory->hash

          syntax
          make-syntax
          syntax?
          syntax-e
          syntax-scopes
          syntax-shifted-multi-scopes
          syntax-srcloc
          syntax-props
          empty-props

          syntax-source
          syntax-line
          syntax-column
          syntax-position
          syntax-span
          syntax-property
          syntax-property-symbol-keys
          datum->syntax
          syntax->datum
          syntax->list
          identifier?

          struct->list
          struct->vector

          exn
          exn?
          exn-message
          exn-continuation-marks
          exn:fail
          exn:fail?
          make-exn
          make-exn:fail
          exn:fail:contract
          exn:fail:contract?
          make-exn:fail:contract
          exn:fail:contract:arity
          exn:fail:contract:arity?
          make-exn:fail:contract:arity
          exn:fail:contract:continuation
          exn:fail:contract:continuation?
          make-exn:fail:contract:continuation
          exn:fail:contract:divide-by-zero
          exn:fail:contract:divide-by-zero?
          make-exn:fail:contract:divide-by-zero
          exn:fail:contract:non-fixnum-result
          exn:fail:contract:non-fixnum-result?
          make-exn:fail:contract:non-fixnum-result
          exn:fail:contract:variable
          exn:fail:contract:variable?
          make-exn:fail:contract:variable
          exn:fail:contract:variable-id
          exn:fail:read
          exn:fail:read?
          make-exn:fail:read
          exn:fail:read-srclocs
          exn:fail:read:eof
          exn:fail:read:eof?
          make-exn:fail:read:eof
          exn:fail:read:non-char
          exn:fail:read:non-char?
          make-exn:fail:read:non-char
          exn:fail:filesystem
          exn:fail:filesystem?
          make-exn:fail:filesystem
          exn:fail:filesystem:exists
          exn:fail:filesystem:exists?
          make-exn:fail:filesystem:exists
          exn:fail:filesystem:version
          exn:fail:filesystem:version?
          make-exn:fail:filesystem:version
          exn:fail:filesystem:errno
          exn:fail:filesystem:errno?
          make-exn:fail:filesystem:errno
          exn:fail:filesystem:errno-errno
          exn:fail:filesystem:missing-module
          exn:fail:filesystem:missing-module?
          make-exn:fail:filesystem:missing-module
          exn:fail:filesystem:missing-module-path
          exn:fail:network
          exn:fail:network?
          make-exn:fail:network
          exn:fail:network:errno
          exn:fail:network:errno?
          make-exn:fail:network:errno
          exn:fail:network:errno-errno
          exn:fail:out-of-memory
          exn:fail:out-of-memory?
          make-exn:fail:out-of-memory
          exn:fail:unsupported
          exn:fail:unsupported?
          make-exn:fail:unsupported
          exn:fail:user
          exn:fail:user?
          make-exn:fail:user
          exn:break
          exn:break?
          make-exn:break
          exn:break-continuation
          exn:break:hang-up
          exn:break:hang-up?
          make-exn:break:hang-up
          exn:break:terminate
          exn:break:terminate?
          make-exn:break:terminate
          exn:fail:syntax
          exn:fail:syntax?
          make-exn:fail:syntax
          exn:fail:syntax-exprs
          exn:fail:syntax:missing-module
          exn:fail:syntax:missing-module?
          make-exn:fail:syntax:missing-module
          exn:fail:syntax:missing-module-path
          exn:fail:syntax:unbound
          exn:fail:syntax:unbound?
          make-exn:fail:syntax:unbound

          mutator

          fixnum
          fx/

          match
          error
          return-false
          skip
          ...))
      (for-each add-runtime-symbol-constant symbols))

    (for ([sym '(lu ll lt lm lo mn mc me nd nl no ps pe pi pf pd pc po sc sm sk so zs zp zl cc cf cs co cn)])
      (add-runtime-symbol-constant sym))

    ; struct:exn, struct:exn:fail, etc.
    (for-each (λ (binding) (add-runtime-symbol-constant (car binding)))
              exception-struct-type-bindings)

    (add-runtime-string-constant 'dash                       "-")
    (add-runtime-string-constant 'bang                       "!")
    (add-runtime-string-constant 'hash-variable-reference    "#<variable-reference>")
    (add-runtime-string-constant 'box-prefix                 "#&")
    (add-runtime-string-constant 'bytes-prefix               "#\"")
    (add-runtime-string-constant 'backslash                  "\\")
    (add-runtime-string-constant 'backslash-x                "\\x")
    (add-runtime-string-constant 'double-quote               "\"")
    (add-runtime-string-constant 'single-quote               "'")
    (add-runtime-string-constant 'hash-t                     "#t")
    (add-runtime-string-constant 'hash-f                     "#f")
    (add-runtime-string-constant 'hash-hash                  "#hash")
    (add-runtime-string-constant 'hash-hasheq                "#hasheq")
    (add-runtime-string-constant 'hash-hasheqv               "#hasheqv")
    (add-runtime-string-constant 'hash-hashalw               "#hashalw")
    (add-runtime-string-constant 'hash-set-non-hash          "hash-set expected hash table, got:")
    (add-runtime-string-constant 'hash-set-exn-message       "hash-set received exception message:")
    (add-runtime-string-constant 'hash-set-unsupported       "hash-set unsupported hash table:")
    (add-runtime-string-constant 'null                       "()")
    (add-runtime-string-constant 'eof                        "#<eof>")
    (add-runtime-string-constant 'void                       "#<void>")
    (add-runtime-string-constant 'undefined                  "#<undefined>")
    (add-runtime-string-constant 'unsafe-undefined           "#<unsafe-undefined>")
    (add-runtime-string-constant 'use-before-initialization  "undefined; cannot use before initialization")
    (add-runtime-string-constant 'unspecified                "#<unspecified>")
    (add-runtime-string-constant 'missing                    "#<missing>")
    (add-runtime-string-constant 'closure                    "#<closure>")
    (add-runtime-string-constant 'external                   "#<external>")
    (add-runtime-string-constant 'external-null              "#<external-null>")
    (add-runtime-string-constant 'linklet                    "#<linklet>")
    (add-runtime-string-constant 'instance                   "#<instance>")
    (add-runtime-string-constant 'namespace                  "#<namespace>")
    (add-runtime-string-constant 'continuation-mark-set      "#<continuation-mark-set>")
    (add-runtime-string-constant 'hash-less-namespace-colon  "#<namespace:")
    (add-runtime-string-constant 'namespace?                 "namespace?")
    (add-runtime-string-constant 'empty                      "")
    (add-runtime-string-constant 'open-paren                 "(")
    (add-runtime-string-constant 'close-paren                ")")
    (add-runtime-string-constant 'space                      " ")
    (add-runtime-string-constant 'dot-space                  ". ")
    (add-runtime-string-constant 'space-dot-space            " . ")
    (add-runtime-string-constant 'vector-prefix              "#(")
    (add-runtime-string-constant 'values-prefix              "(values")
    (add-runtime-string-constant 'rx-dot-class               "[.]")
    (add-runtime-string-constant 'rx-dot-zo-end              "[.]zo$")
    (add-runtime-string-constant 'rx-id-colon-or-end         "^id(:|$)")
    (add-runtime-string-constant 'dot                        ".")
    (add-runtime-string-constant 'dot-zo                     ".zo")
    (add-runtime-string-constant 'id                         "id")
    (add-runtime-string-constant 'regexp?                    "regexp?")
    (add-runtime-string-constant 'regexp-replace             "regexp-replace")
    (add-runtime-string-constant 'regexp-replace*            "regexp-replace*")
    (add-runtime-string-constant 'g                          "g")

    (add-runtime-string-constant 'struct-type-descriptor     "#<struct-type-descriptor>")
    (add-runtime-string-constant 'struct-open                "#(struct ")
    (add-runtime-string-constant 'struct?                    "struct?")
    (add-runtime-string-constant 'struct-type?               "struct-type?")
    (add-runtime-string-constant 'sealed-struct-supertype     "sealed structure type cannot be used as a supertype")
    (add-runtime-string-constant 'custom-write?              "custom-write?")
    (add-runtime-string-constant 'custom-print-quotable?     "custom-print-quotable?")
    (add-runtime-string-constant 'struct->list:on-opaque     "one of 'error, 'return-false, or 'skip")
    (add-runtime-string-constant 'struct:prefix              "struct:")

    (add-runtime-string-constant 'hash-colon                 "#:")
    (add-runtime-string-constant 'hash-backslash             "#\\")
    (add-runtime-string-constant 'hash-backslash-u           "#\\u")
    (add-runtime-string-constant 'hash-backslash-U           "#\\U")
    (add-runtime-string-constant 'word-newline               "newline")
    (add-runtime-string-constant 'word-tab                   "tab")
    (add-runtime-string-constant 'word-return                "return")
    (add-runtime-string-constant 'word-backspace             "backspace")
    (add-runtime-string-constant 'word-space                 "space")
    (add-runtime-string-constant 'word-rubout                "rubout")
    (add-runtime-string-constant 'word-nul                   "nul")
    (add-runtime-string-constant 'unknown                    "unknown")
    (add-runtime-string-constant 'colon                      ":")
    (add-runtime-string-constant '->                         ">")
    (add-runtime-string-constant 'set                        "set")

    (add-runtime-string-constant 'syntax-open                          "#<syntax ")
    (add-runtime-string-constant 'syntax-close                         ">")
    (add-runtime-string-constant 'hash-less-boxed-colon                "#<boxed:")
    (add-runtime-string-constant 'hash-less-procedure-colon            "#<procedure:")
    (add-runtime-string-constant 'hash-less-primitive-colon            "#<primitive:")
    (add-runtime-string-constant 'hash-less-path-colon                 "#<path:")
    (add-runtime-string-constant 'hash-less-input-port                 "#<input-port>")
    (add-runtime-string-constant 'hash-less-output-port                "#<output-port>")
    (add-runtime-string-constant 'hash-less-treelist                   "#<treelist>")
    (add-runtime-string-constant 'hash-less-treelist-colon-space       "#<treelist: ")
    (add-runtime-string-constant 'hash-less-unix-path-colon            "#<unix-path:")
    (add-runtime-string-constant 'hash-less-windows-path-colon         "#<windows-path:")
    (add-runtime-string-constant 'hash-less-struct-type-property-colon "#<struct-type-property:")

    (add-runtime-string-constant 'procedure-realm           "procedure-realm")
    (add-runtime-string-constant 'procedure-struct-type?    "procedure-struct-type?")
    (add-runtime-string-constant 'string?                    "string?")
    (add-runtime-string-constant 'string-or-symbol?          "(or/c string? symbol?)")
    (add-runtime-string-constant 'symbol?                    "symbol?")
    (add-runtime-string-constant 'ephemeron?                 "ephemeron?")
    (add-runtime-string-constant 'keyword?                   "keyword?")
    (add-runtime-string-constant 'keyword:key                "key")
    (add-runtime-string-constant 'keyword:cache-keys?        "cache-keys?")
    (add-runtime-string-constant 'pair?                      "pair?")
    (add-runtime-string-constant 'placeholder?               "placeholder?")
    (add-runtime-string-constant 'list?                      "list?")
    (add-runtime-string-constant 'non-empty-list?            "(and/c list? (not/c empty?))")
    (add-runtime-string-constant 'fixnum?                    "fixnum?")
    (add-runtime-string-constant 'byte?                      "byte?")
    (add-runtime-string-constant 'bytes?                     "bytes?")
    (add-runtime-string-constant 'vector?                    "vector?")
    (add-runtime-string-constant 'mutable-vector?            "(and/c vector? (not/c immutable?))")
    (add-runtime-string-constant 'valid-vector-index          "valid vector index")
    (add-runtime-string-constant 'valid-vector-length         "valid vector length")
    (add-runtime-string-constant 'box?                       "box?")
    (add-runtime-string-constant 'port?                      "port?")
    (add-runtime-string-constant 'input-port?                "input-port?")
    (add-runtime-string-constant 'file-stream-port?          "file-stream-port?")
    (add-runtime-string-constant 'terminal-port?             "terminal-port?")
    (add-runtime-string-constant 'output-port?               "output-port?")
    (add-runtime-string-constant 'port-writes-atomic?        "port-writes-atomic?")
    (add-runtime-string-constant 'port-writes-special?       "port-writes-special?")
    (add-runtime-string-constant 'port-provides-progress-evts? "port-provides-progress-evts?")
    (add-runtime-string-constant 'parameter?                 "parameter?")
    (add-runtime-string-constant 'parameterization?          "parameterization?")
    (add-runtime-string-constant 'pseudo-random-generator?   "pseudo-random-generator?")
    (add-runtime-string-constant 'impersonator-property?     "impersonator-property?")
    (add-runtime-string-constant 'procedure-or-false?       "(or/c procedure? #f)")
    (add-runtime-string-constant 'security-guard?            "security-guard?")
    (add-runtime-string-constant 'custodian?                 "custodian?")
    (add-runtime-string-constant 'custodian-box?             "custodian-box?")
    (add-runtime-string-constant 'mpair-or-null              "(or/c mpair? null?)")
    (add-runtime-string-constant 'catch*-matching-lengths    "same number of handlers as predicates")
    (add-runtime-string-constant 'real?                      "real?")
    (add-runtime-string-constant 'exact-nonnegative-integer? "exact-nonnegative-integer?")
    (add-runtime-string-constant 'exact-integer?             "exact-integer?")
    (add-runtime-string-constant 'filesystem-errno           "(cons/c exact-integer? (or/c 'posix 'windows 'gai))")
    (add-runtime-string-constant 'listof-pair?               "(listof pair?)")
    (add-runtime-string-constant 'semaphore?                 "semaphore?")
    (add-runtime-string-constant 'evt?                       "evt?")
    (add-runtime-string-constant 'handle-evt?                "handle-evt?")
    (add-runtime-string-constant 'will-executor?             "will-executor?")
    (add-runtime-string-constant 'thread?                    "thread?")
    (add-runtime-string-constant 'thread-group?              "thread-group?")
    (add-runtime-string-constant 'procedure-arity?           "procedure-arity?")
    (add-runtime-string-constant 'exn:srclocs?              "exn:srclocs?")
    (add-runtime-string-constant 'valid-argument             "valid argument")
    (add-runtime-string-constant 'read-byte:input-port-closed "read-byte: input port is closed")
    (add-runtime-string-constant 'peek-byte:input-port-closed "peek-byte: input port is closed")
    (add-runtime-string-constant 'write-byte:output-port-closed "write-byte: output port is closed")
    (add-runtime-string-constant 'flush-output:output-port-closed "flush-output: output port is closed")
    (add-runtime-string-constant 'vfs:file-size-failed       "file-size: VFS path does not refer to a file")
    (add-runtime-string-constant 'vfs:read-file-failed       "VFS file read failed")
    (add-runtime-string-constant 'vfs:write-file-failed      "VFS file write failed")
    (add-runtime-string-constant 'vfs:delete-file-failed     "delete-file: VFS path does not refer to a file")
    (add-runtime-string-constant 'vfs:delete-directory-failed "delete-directory: VFS path does not refer to an empty directory")
    (add-runtime-string-constant 'vfs:delete-directory/files-failed "delete-directory/files: VFS recursive delete failed")
    (add-runtime-string-constant 'vfs:make-directory-failed  "make-directory: VFS directory creation failed")
    (add-runtime-string-constant 'vfs:make-directory*-failed "make-directory*: VFS directory creation failed")
    (add-runtime-string-constant 'vfs:make-parent-directory*-failed "make-parent-directory*: VFS directory creation failed")
    (add-runtime-string-constant 'vfs:directory-list-failed  "directory-list: VFS path does not refer to a directory")
    (add-runtime-string-constant 'vfs:root-list-failed       "filesystem-root-list: VFS root list failed")
    (add-runtime-string-constant 'vfs:rename-failed          "rename-file-or-directory: VFS rename failed")
    (add-runtime-string-constant 'vfs:copy-file-failed       "copy-file: VFS copy failed")
    (add-runtime-string-constant 'vfs:copy-directory/files-failed "copy-directory/files: VFS recursive copy failed")
    (add-runtime-string-constant 'vfs:temporary-template     "format string containing ~a")
    (add-runtime-string-constant 'vfs:modify-seconds-failed  "file-or-directory-modify-seconds: VFS path does not exist")
    (add-runtime-string-constant 'vfs:permissions-failed     "file-or-directory-permissions: VFS path does not exist")
    (add-runtime-string-constant 'vfs:stat-failed            "file-or-directory-stat: VFS path does not exist")
    (add-runtime-string-constant 'vfs:type-failed            "file-or-directory-type: VFS path does not exist")
    (add-runtime-string-constant 'vfs:identity-failed        "file-or-directory-identity: VFS path does not exist")
    (add-runtime-string-constant 'permissions-mode           "(or/c #f 'bits (integer-in 0 65535))")
    (add-runtime-string-constant 'input-file-mode-flag       "(or/c 'binary 'text)")
    (add-runtime-string-constant 'output-file-mode-flag      "(or/c 'binary 'text)")
    (add-runtime-string-constant 'output-file-exists-flag    "(or/c 'error 'append 'replace 'truncate 'must-truncate 'truncate/replace)")
    (add-runtime-string-constant 'system-path-kind           "(or/c 'home-dir 'pref-dir 'pref-file 'temp-dir 'init-dir 'init-file 'config-dir 'host-config-dir 'addon-dir 'host-addon-dir 'cache-dir 'doc-dir 'desk-dir 'sys-dir 'exec-file 'run-file 'collects-dir 'host-collects-dir 'orig-dir)")
    (add-runtime-string-constant 'string-or-bytes            "(or/c string? bytes?)")
    (add-runtime-string-constant 'boolean?                   "boolean?")
    (add-runtime-string-constant 'date?                      "date?")
    (add-runtime-string-constant 'date*?                     "date*?")
    (add-runtime-string-constant 'UTC                        "UTC")
    (add-runtime-string-constant 'local                      "local")
    (add-runtime-string-constant 'racket-version             (version))
    (add-runtime-string-constant 'webracket-machine          "WebRacket")
    (add-runtime-string-constant 'uncaught-exception         "uncaught exception: ")
    (add-runtime-string-constant 'callback:no-js-equivalent
                                 "The callback attempted to return a WebRacket value with no JavaScript equivalent (i.e. without a FASL encoding): ")
    (add-runtime-symbol-constant 'wr-ref)
    (add-runtime-symbol-constant 'call-with-escape-continuation)
    (add-runtime-symbol-constant 'current-logger)
    (add-runtime-symbol-constant 'logger?)
    (add-runtime-symbol-constant 'procedure-realm)
    (add-runtime-symbol-constant 'procedure-struct-type?)
    (add-runtime-symbol-constant 'log-receiver?)
    (add-runtime-symbol-constant 'make-log-receiver)
    (add-runtime-symbol-constant 'make-logger)
    (add-runtime-symbol-constant 'logger-name)
    (add-runtime-symbol-constant 'log-level?)
    (add-runtime-symbol-constant 'log-max-level)
    (add-runtime-symbol-constant 'log-message)
    (add-runtime-symbol-constant 'bytes-converter?)
    (add-runtime-symbol-constant 'bytes-open-converter)
    (add-runtime-symbol-constant 'bytes-close-converter)
    (add-runtime-symbol-constant 'bytes-convert)
    (add-runtime-symbol-constant 'bytes-convert-end)
    (add-runtime-symbol-constant 'complete)
    (add-runtime-symbol-constant 'continues)
    (add-runtime-symbol-constant 'make-channel)
    (add-runtime-symbol-constant 'channel?)
    (add-runtime-symbol-constant 'channel-get)
    (add-runtime-symbol-constant 'channel-try-get)
    (add-runtime-symbol-constant 'channel-put)
    (add-runtime-symbol-constant 'channel-put-evt)
    (add-runtime-symbol-constant 'channel-put-evt?)
    (add-runtime-symbol-constant 'evt?)
    (add-runtime-symbol-constant 'handle-evt)
    (add-runtime-symbol-constant 'handle-evt?)
    (add-runtime-symbol-constant 'make-will-executor)
    (add-runtime-symbol-constant 'will-executor?)
    (add-runtime-symbol-constant 'will-register)
    (add-runtime-symbol-constant 'will-execute)
    (add-runtime-symbol-constant 'will-try-execute)
    (add-runtime-symbol-constant 'hash-placeholder?)
    (add-runtime-symbol-constant 'hash-weak?)
    (add-runtime-symbol-constant 'make-reader-graph)
    (add-runtime-symbol-constant 'make-placeholder)
    (add-runtime-symbol-constant 'placeholder-set!)
    (add-runtime-symbol-constant 'placeholder-get)
    (add-runtime-symbol-constant 'make-hash-placeholder)
    (add-runtime-symbol-constant 'make-hasheq-placeholder)
    (add-runtime-symbol-constant 'make-hasheqv-placeholder)
    (add-runtime-symbol-constant 'make-hashalw-placeholder)
    (add-runtime-symbol-constant 'chaperone?)
    (add-runtime-symbol-constant 'continuation-mark-set?)
    (add-runtime-symbol-constant 'continuation-prompt-available?)
    (add-runtime-symbol-constant 'continuation-prompt-tag?)
    (add-runtime-symbol-constant 'continuation?)
    (add-runtime-symbol-constant 'thread?)
    (add-runtime-symbol-constant 'thread-dead?)
    (add-runtime-symbol-constant 'thread-running?)
    (add-runtime-symbol-constant 'thread-group?)
    (add-runtime-symbol-constant 'make-thread-group)
    (add-runtime-symbol-constant 'current-thread-group)
    (add-runtime-symbol-constant 'current-security-guard)
    (add-runtime-symbol-constant 'security-guard?)
    (add-runtime-symbol-constant 'make-security-guard)
    (add-runtime-symbol-constant 'current-custodian)
    (add-runtime-symbol-constant 'custodian?)
    (add-runtime-symbol-constant 'make-custodian)
    (add-runtime-symbol-constant 'custodian-shutdown-all)
    (add-runtime-symbol-constant 'custodian-shut-down?)
    (add-runtime-symbol-constant 'make-custodian-box)
    (add-runtime-symbol-constant 'custodian-box?)
    (add-runtime-symbol-constant 'custodian-box-value)
    (add-runtime-symbol-constant 'date?)
    (add-runtime-symbol-constant 'date)
    (add-runtime-symbol-constant 'make-date)
    (add-runtime-symbol-constant 'date*?)
    (add-runtime-symbol-constant 'date*)
    (add-runtime-symbol-constant 'make-date*)
    (add-runtime-symbol-constant 'date-second)
    (add-runtime-symbol-constant 'date-minute)
    (add-runtime-symbol-constant 'date-hour)
    (add-runtime-symbol-constant 'date-day)
    (add-runtime-symbol-constant 'date-month)
    (add-runtime-symbol-constant 'date-year)
    (add-runtime-symbol-constant 'date-week-day)
    (add-runtime-symbol-constant 'date-year-day)
    (add-runtime-symbol-constant 'date-dst?)
    (add-runtime-symbol-constant 'date-time-zone-offset)
    (add-runtime-symbol-constant 'date*-nanosecond)
    (add-runtime-symbol-constant 'date*-time-zone-name)
    (add-runtime-symbol-constant 'exn:fail:contract:continuation)
    (add-runtime-symbol-constant 'exn:fail:contract:continuation?)
    (add-runtime-symbol-constant 'make-exn:fail:contract:continuation)
    (add-runtime-symbol-constant 'exn:fail:filesystem:exists)
    (add-runtime-symbol-constant 'exn:fail:filesystem:exists?)
    (add-runtime-symbol-constant 'make-exn:fail:filesystem:exists)
    (add-runtime-symbol-constant 'exn:fail:filesystem:version)
    (add-runtime-symbol-constant 'exn:fail:filesystem:version?)
    (add-runtime-symbol-constant 'make-exn:fail:filesystem:version)
    (add-runtime-symbol-constant 'exn:fail:filesystem:errno)
    (add-runtime-symbol-constant 'exn:fail:filesystem:errno?)
    (add-runtime-symbol-constant 'make-exn:fail:filesystem:errno)
    (add-runtime-symbol-constant 'exn:fail:filesystem:errno-errno)
    (add-runtime-symbol-constant 'exn:fail:filesystem:missing-module)
    (add-runtime-symbol-constant 'exn:fail:filesystem:missing-module?)
    (add-runtime-symbol-constant 'make-exn:fail:filesystem:missing-module)
    (add-runtime-symbol-constant 'exn:fail:filesystem:missing-module-path)
    (add-runtime-symbol-constant 'exn:fail:network)
    (add-runtime-symbol-constant 'exn:fail:network?)
    (add-runtime-symbol-constant 'make-exn:fail:network)
    (add-runtime-symbol-constant 'exn:fail:network:errno)
    (add-runtime-symbol-constant 'exn:fail:network:errno?)
    (add-runtime-symbol-constant 'make-exn:fail:network:errno)
    (add-runtime-symbol-constant 'exn:fail:network:errno-errno)
    (add-runtime-symbol-constant 'exn:fail:out-of-memory)
    (add-runtime-symbol-constant 'exn:fail:out-of-memory?)
    (add-runtime-symbol-constant 'make-exn:fail:out-of-memory)
    (add-runtime-symbol-constant 'exn:fail:unsupported)
    (add-runtime-symbol-constant 'exn:fail:unsupported?)
    (add-runtime-symbol-constant 'make-exn:fail:unsupported)
    (add-runtime-symbol-constant 'exn:fail:user)
    (add-runtime-symbol-constant 'exn:fail:user?)
    (add-runtime-symbol-constant 'make-exn:fail:user)
    (add-runtime-symbol-constant 'current-seconds)
    (add-runtime-symbol-constant 'current-inexact-milliseconds)
    (add-runtime-symbol-constant 'current-milliseconds)
    (add-runtime-symbol-constant 'current-process-milliseconds)
    (add-runtime-symbol-constant 'current-gc-milliseconds)
    (add-runtime-symbol-constant 'seconds->date)
    (add-runtime-symbol-constant 'current-date)
    (add-runtime-symbol-constant 'exn:break)
    (add-runtime-symbol-constant 'exn:break?)
    (add-runtime-symbol-constant 'make-exn:break)
    (add-runtime-symbol-constant 'exn:break-continuation)
    (add-runtime-symbol-constant 'exn:break:hang-up)
    (add-runtime-symbol-constant 'exn:break:hang-up?)
    (add-runtime-symbol-constant 'make-exn:break:hang-up)
    (add-runtime-symbol-constant 'exn:break:terminate)
    (add-runtime-symbol-constant 'exn:break:terminate?)
    (add-runtime-symbol-constant 'make-exn:break:terminate)
    (add-runtime-symbol-constant 'exn:srclocs?)
    (add-runtime-symbol-constant 'exn:srclocs-accessor)
    (add-runtime-symbol-constant 'port-read-handler)
    (add-runtime-symbol-constant 'port-write-handler)
    (add-runtime-symbol-constant 'port-display-handler)
    (add-runtime-symbol-constant 'port-print-handler)
    (add-runtime-symbol-constant 'port-writes-atomic?)
    (add-runtime-symbol-constant 'port-writes-special?)
    (add-runtime-symbol-constant 'port-provides-progress-evts?)
    (add-runtime-symbol-constant 'load-on-demand-enabled)
    (add-runtime-symbol-constant 'read-square-bracket-as-paren)
    (add-runtime-symbol-constant 'read-curly-brace-as-paren)
    (add-runtime-symbol-constant 'read-square-bracket-with-tag)
    (add-runtime-symbol-constant 'read-curly-brace-with-tag)
    (add-runtime-symbol-constant 'read-accept-reader)
    (add-runtime-symbol-constant 'read-accept-lang)
    (add-runtime-symbol-constant 'read-accept-compiled)
    (add-runtime-symbol-constant 'read-accept-box)
    (add-runtime-symbol-constant 'read-accept-bar-quote)
    (add-runtime-symbol-constant 'read-accept-graph)
    (add-runtime-symbol-constant 'read-syntax-accept-graph)
    (add-runtime-symbol-constant 'read-accept-dot)
    (add-runtime-symbol-constant 'read-accept-infix-dot)
    (add-runtime-symbol-constant 'read-accept-quasiquote)
    (add-runtime-symbol-constant 'read-cdot)
    (add-runtime-symbol-constant 'read-single-flonum)
    (add-runtime-symbol-constant 'read-decimal-as-inexact)
    (add-runtime-symbol-constant 'read-case-sensitive)
    (add-runtime-symbol-constant 'print-syntax-width)
    (add-runtime-symbol-constant 'error-print-width)
    (add-runtime-symbol-constant 'error-print-source-location)
    (add-runtime-symbol-constant 'current-compile-target-machine)
    (add-runtime-symbol-constant 'current-compile-realm)
    (add-runtime-symbol-constant 'installation-name)
    (add-runtime-symbol-constant 'submod)
    (add-runtime-symbol-constant 'top-level)
    (add-runtime-symbol-constant 'linklet)
    (add-runtime-symbol-constant '#%app)
    (add-runtime-symbol-constant '+)
    (add-runtime-symbol-constant 'add)
    (add-runtime-symbol-constant 'remove)
    (add-runtime-symbol-constant 'flip)
    (add-runtime-symbol-constant 'syntax-introducer)
    (add-runtime-symbol-constant '-)
    (add-runtime-symbol-constant '*)
    (add-runtime-symbol-constant 'values)
    (add-runtime-symbol-constant 'list)
    (add-runtime-symbol-constant 'cons)
    (add-runtime-symbol-constant 'car)
    (add-runtime-symbol-constant 'cdr)
    (add-runtime-symbol-constant 'pair?)
    (add-runtime-symbol-constant 'length)
    (add-runtime-symbol-constant 'list-ref)
    (add-runtime-symbol-constant 'list-tail)
    (add-runtime-symbol-constant 'list-set)
    (add-runtime-symbol-constant 'list-update)
    (add-runtime-symbol-constant 'rest)
    (add-runtime-symbol-constant 'take)
    (add-runtime-symbol-constant 'take-right)
    (add-runtime-symbol-constant 'drop)
    (add-runtime-symbol-constant 'drop-right)
    (add-runtime-symbol-constant 'split-at)
    (add-runtime-symbol-constant 'split-at-right)
    (add-runtime-symbol-constant 'fixnum?)
    (add-runtime-symbol-constant 'byte?)
    (add-runtime-symbol-constant 'vector?)
    (add-runtime-symbol-constant 'make-vector)
    (add-runtime-symbol-constant 'vector-length)
    (add-runtime-symbol-constant 'vector-ref)
    (add-runtime-symbol-constant 'vector-set!)
    (add-runtime-symbol-constant 'vector*-length)
    (add-runtime-symbol-constant 'vector*-ref)
    (add-runtime-symbol-constant 'vector*-set!)
    (add-runtime-symbol-constant 'vector-fill!)
    (add-runtime-symbol-constant 'vector-copy)
    (add-runtime-symbol-constant 'vector-copy!)
    (add-runtime-symbol-constant 'vector-take)
    (add-runtime-symbol-constant 'vector-drop)
    (add-runtime-symbol-constant 'vector-take-right)
    (add-runtime-symbol-constant 'vector-drop-right)
    (add-runtime-symbol-constant 'vector-split-at)
    (add-runtime-symbol-constant 'vector-split-at-right)
    (add-runtime-symbol-constant 'vector->values)
    (add-runtime-symbol-constant 'vector->immutable-vector)
    (add-runtime-symbol-constant 'vector-set/copy)
    (add-runtime-symbol-constant 'vector-extend)
    (add-runtime-symbol-constant 'vector-empty?)
    (add-runtime-symbol-constant 'vector-append)
    (add-runtime-symbol-constant 'vector-sort)
    (add-runtime-symbol-constant 'vector-sort!)
    (add-runtime-symbol-constant 'define-values)
    (add-runtime-symbol-constant 'quote)
    (add-runtime-symbol-constant 'begin)
    (add-runtime-symbol-constant 'if)
    (add-runtime-symbol-constant 'set!)
    (add-runtime-symbol-constant 'void)
    (add-runtime-symbol-constant 'webracket-debug-allocation-budget!)
    (add-runtime-symbol-constant 'webracket-debug-allocation-counters)
    (add-runtime-symbol-constant 'webracket-debug-invoke-budget!)
    (add-runtime-symbol-constant 'allocation-budget-exhausted)
    (add-runtime-symbol-constant 'invoke-budget-exhausted)
    (add-runtime-symbol-constant 'pairs)
    (add-runtime-symbol-constant 'vectors)
    (add-runtime-symbol-constant 'structs)
    (add-runtime-symbol-constant 'hash-sets)
    (add-runtime-symbol-constant 'closures)
    (add-runtime-symbol-constant 'arg-arrays)
    (add-runtime-symbol-constant 'strings)
    (add-runtime-symbol-constant 'bytes)
    (add-runtime-symbol-constant 'value-arrays)
    (add-runtime-symbol-constant 'free-arrays)
    (add-runtime-symbol-constant 'invocations)
    (add-runtime-symbol-constant 'current-procedure)
    (add-runtime-symbol-constant 'name)
    (add-runtime-symbol-constant 'debug-id)
    (add-runtime-symbol-constant 'call-with-parameterization-wrapper-entry)
    (add-runtime-symbol-constant 'call-with-parameterization-primitive-entry)
    (add-runtime-symbol-constant 'count)
    (add-runtime-symbol-constant 'argc)
    (add-runtime-symbol-constant 'arg0-parameterization?)
    (add-runtime-symbol-constant 'arg1-procedure?)
    (add-runtime-symbol-constant 'arg1-name)
    (add-runtime-symbol-constant 'arg1-debug-id)
    (add-runtime-symbol-constant 'application-not-procedure-frontier)
    (add-runtime-symbol-constant 'binding-result-arity-frontier)
    (add-runtime-symbol-constant 'procedure-arity-frontier)
    (add-runtime-symbol-constant 'expected-count)
    (add-runtime-symbol-constant 'received-count)
    (add-runtime-symbol-constant 'got-struct-type)
    (add-runtime-symbol-constant 'got-procedure?)
    (add-runtime-symbol-constant 'caller-name)
    (add-runtime-symbol-constant 'caller-debug-id)
    (add-runtime-string-constant 'wr-kind:value              "value")
    (add-runtime-string-constant 'wr-kind:missing-binding    "missing-binding")
    (add-runtime-string-constant 'wr-kind:not-procedure      "not-procedure")
    (add-runtime-string-constant 'wr-kind:procedure          "procedure")
    (add-runtime-string-constant 'wr-kind:exception          "exception")
    (add-runtime-string-constant 'wr-kind:non-fasl-result    "non-fasl-result")
    (add-runtime-string-constant 'wr-kind:bad-request        "bad-request")
    (add-runtime-string-constant 'wr:bad-request             "invalid WebRacket console bridge request")
    (add-runtime-string-constant 'wr:not-procedure           "top-level binding is not a procedure: ")
    (add-runtime-string-constant 'wr:undefined-exception     "bridge call raised #<undefined>")
    (add-runtime-string-constant 'wr:unsafe-undefined-exception "bridge call raised #<unsafe-undefined>")
    (add-runtime-string-constant 'arity-at-least?            "arity-at-least?")
    (add-runtime-symbol-constant 'break-enabled-key)
    (add-runtime-symbol-constant 'exception-handler-key)
    (add-runtime-symbol-constant 'parameterization-key)
    (add-runtime-symbol-constant 'namespace)

    (add-runtime-string-constant 'srcloc?                    "srcloc?")
    (add-runtime-string-constant 'srcloc-positive-or-false   "(or/c exact-positive-integer? #f)")
    (add-runtime-string-constant 'srcloc-nonnegative-or-false "(or/c exact-nonnegative-integer? #f)")
    (add-runtime-string-constant 'treelist?                  "treelist?")
    (add-runtime-string-constant 'treelist-empty             ": treelist is empty")
    (add-runtime-string-constant 'listof-srcloc?             "(listof srcloc?)")
    (add-runtime-string-constant 'listof-syntax?             "(listof syntax?)")
    (add-runtime-string-constant 'match-error:prefix         ": no matching clause for ")

    (add-runtime-string-constant 'syntax-or-false            "(or/c syntax? #f)")
    (add-runtime-string-constant 'datum->syntax-srcloc       "(or/c #f syntax? srcloc?)")

    (add-runtime-string-constant 'hash?                      "hash?")

    (add-runtime-string-constant 'syntax?                    "syntax?")
    (add-runtime-string-constant 'identifier?                "identifier?")
    (add-runtime-string-constant 'listof-identifier?         "(listof identifier?)")
    (add-runtime-string-constant 'stx-list?                  "stx-list?")
    (add-runtime-string-constant 'syntax-introducer-mode?    "(or/c 'add 'remove 'flip)")
    (add-runtime-string-constant 'syntax-local-value-failure  "(or/c (-> any/c) #f)")
    (add-runtime-string-constant 'syntax-local-value-binding  "identifier with transformer binding")
    (add-runtime-string-constant 'set!-transformer?          "set!-transformer?")
    (add-runtime-string-constant 'dynamic-require-unsupported "dynamic module loading is not supported")
    (add-runtime-string-constant 'path-string?               "path-string?")
    (add-runtime-string-constant 'relative-path-string-or-false
                                 "(or/c #f (and/c path-string? relative-path?))")
    (add-runtime-string-constant 'correlated?                "correlated?")
    (add-runtime-string-constant 'correlated-or-false        "(or/c correlated? #f)")
    (add-runtime-symbol-constant 'correlated->datum)
    (add-runtime-symbol-constant 'datum->correlated)
    (add-runtime-symbol-constant 'correlated-property)
    (add-runtime-symbol-constant 'correlated-property-symbol-keys)
    (add-runtime-symbol-constant 'relative)
    (add-runtime-symbol-constant 'up)
    (add-runtime-symbol-constant 'same)

    (add-runtime-string-constant 'instance?                     "instance?")
    (add-runtime-string-constant 'missing-variable-value        "missing variable value")
    (add-runtime-string-constant 'missing-binding               "missing binding:")
    (add-runtime-string-constant 'instance-variable-not-found   "instance variable not found:")
    (add-runtime-string-constant 'cannot-modify-constant        "cannot modify a constant")
    (add-runtime-string-constant 'at-most-one-optional-argument "expected at most one optional argument")

    (add-runtime-string-constant 'linklet?                      "linklet?")
    (add-runtime-string-constant 'compiled-linklet?             "compiled-linklet?")
    (add-runtime-string-constant 'linklet-bundle?               "linklet-bundle?")
    (add-runtime-string-constant 'linklet-directory?            "linklet-directory?")
    (add-runtime-string-constant 'mutable-hasheq?               "mutable hasheq?")
    (add-runtime-string-constant 'linklet-bundle-key?           "(or/c symbol? fixnum?)")
    (add-runtime-string-constant 'linklet-directory-key?        "(or/c symbol? #f)")
    (add-runtime-string-constant 'listof-symbol?                "(listof symbol?)")
    (add-runtime-string-constant 'listof-listof-symbol?         "(listof (listof symbol?))")
    (add-runtime-string-constant 'listof-instance?              "(listof instance?)")
    (add-runtime-string-constant 'distinct-listof-symbol?       "(and/c (listof symbol?) distinct?)")
    (add-runtime-string-constant 'symbol-or-false               "(or/c symbol? #f)")
    (add-runtime-string-constant 'logger?                       "logger?")
    (add-runtime-string-constant 'log-receiver?                 "log-receiver?")
    (add-runtime-string-constant 'bytes-converter?              "bytes-converter?")
    (add-runtime-string-constant 'channel?                      "channel?")
    (add-runtime-string-constant 'instance-mode?                "(or/c #f 'constant 'consistent)")
    (add-runtime-string-constant 'instance-or-false             "(or/c instance? #f)")
    (add-runtime-string-constant 'variable-reference?           "variable-reference?")
    (add-runtime-string-constant 'module-path?                  "module-path?")
    (add-runtime-string-constant 'module-path-index?            "module-path-index?")
    (add-runtime-string-constant 'resolved-module-path?         "resolved-module-path?")
    (add-runtime-string-constant 'module-path-index-base        "(or/c #f resolved-module-path? module-path-index?)")
    (add-runtime-string-constant 'readtable-or-false            "(or/c readtable? #f)")
    (add-runtime-string-constant 'variable-reference->module-source "variable-reference->module-source")
    (add-runtime-string-constant 'variable-reference->resolved-module-path "variable-reference->resolved-module-path")
    (add-runtime-string-constant 'module-variable?              "module-variable?")
    (add-runtime-string-constant 'module-variable-reference?    "module-variable-reference?")
    (add-runtime-string-constant 'module-variable-same-length-vectors
                                 "value vector with the same length as the cell vector")
    (add-runtime-string-constant 'module-prompts-unsupported    "module prompts are not supported by WebRacket yet")
    (add-runtime-string-constant 'reader-unsupported            "the Racket reader is not supported by WebRacket yet")
    (add-runtime-string-constant 'reader-graph-unsupported
                                 "cyclic reader graphs and hash placeholders are not supported by WebRacket yet")
    (add-runtime-string-constant 'metadata-only-compiled-linklet
                                 "metadata-only compiled linklet has no executable body")
    (add-runtime-symbol-constant 'constant)
    (add-runtime-symbol-constant 'consistent)
    (add-runtime-symbol-constant 'root-continuation-prompt-tag)
    (add-runtime-string-constant 'instantiate-linklet:import-count
                                 "the number of import instances does not match the expected number of imports")

    (add-runtime-string-constant 'datum->correlated-srcloc
                                 (string-append "(or/c correlated? #f (list/c any/c (or/c exact-positive-integer? #f) "
                                                "(or/c exact-nonnegative-integer? #f) (or/c exact-positive-integer? #f) "
                                                "(or/c exact-nonnegative-integer? #f)) "
                                                "(vector/c any/c (or/c exact-positive-integer? #f) "
                                                "(or/c exact-nonnegative-integer? #f) "
                                                "(or/c exact-positive-integer? #f) "
                                                "(or/c exact-nonnegative-integer? #f)))"))
    (add-runtime-string-constant  'procedure? "procedure?")

    (add-runtime-string-constant  'arity-error:start
                                  ": arity mismatch;\n the expected number of arguments does not match the given number\n  expected: ")
    (add-runtime-string-constant  'arity-error:start/no-expected
                                  ": arity mismatch;\n the expected number of arguments does not match the given number\n  given: ")
    (add-runtime-string-constant  'arity-error:given         "\n  given: ")
    (add-runtime-string-constant  'arity-error:at-least      "at least ")
    (add-runtime-string-constant  'arity-error:or            " or ")
    (add-runtime-string-constant  'result-arity-error:start
                                  ": result arity mismatch;\n expected number of values not received\n  expected: ")
    (add-runtime-string-constant  'result-arity-error:received "\n  received: ")
    (add-runtime-string-constant  'contract-violation:prefix
                                  ": contract violation\n  expected: ")
    (add-runtime-string-constant  'application:not-procedure
                                  "application: not a procedure;\n expected a procedure that can be applied to arguments\n  given: ")
    (add-runtime-string-constant  'question           "?")
    (add-runtime-string-constant  'accessor-suffix    "-accessor")
    (add-runtime-string-constant  'fx-overflow:middle        ": fixnum overflow with arguments ")
    (add-runtime-string-constant  'fx-overflow:and           " and ")

    (add-runtime-string-constant  'expected-fixnum:got       "expected fixnum, got: ")
    (add-runtime-string-constant  'path?                     "path?")
    (add-runtime-string-constant  'path-for-some-system?     "path-for-some-system?")
    (add-runtime-string-constant  'path-element?             "path-element?")
    (add-runtime-string-constant  'listof-path?              "(listof path?)")

    ;; Byte Strings
    (add-runtime-bytes-constant  'empty                     #"")
    (add-runtime-bytes-constant  'non-empty                 #"_")
    (add-runtime-bytes-constant  'slash                     #"/")
    (add-runtime-bytes-constant  'backslash                 #"\\")
    (add-runtime-bytes-constant  'dot                       #".")
    (add-runtime-bytes-constant  'dot-dot                   #"..")
    (add-runtime-bytes-constant  'dot-zo                    #".zo")
    (add-runtime-bytes-constant  'exp                       #"exp")
    (add-runtime-bytes-constant  'id                        #"id")
    (add-runtime-bytes-constant  'rx-dot-class              #"[.]")
    (add-runtime-bytes-constant  'rx-dot-zo-end             #"[.]zo$")
    (add-runtime-bytes-constant  'rx-id-colon-or-end        #"^id(:|$)")
    (add-runtime-bytes-constant  'rx-envvar-name            #"^[^\0=]*$")
    (add-runtime-bytes-constant  'rx-unix-path-list         #"([^:]*):(.*)")
    (add-runtime-bytes-constant  'rx-windows-path-list      #"([^;]*);(.*)")
    (add-runtime-bytes-constant  'rkttmp-template           #"rkttmp~a")
    (add-runtime-bytes-constant  'app-dir                   #"/app/")
    (add-runtime-bytes-constant  'vfs-root                  #"/")
    (add-runtime-bytes-constant  'vfs-home-dir              #"/home/")
    (add-runtime-bytes-constant  'vfs-pref-dir              #"/home/.config/racket/")
    (add-runtime-bytes-constant  'vfs-pref-file             #"/home/.config/racket/racket-prefs.rktd")
    (add-runtime-bytes-constant  'vfs-temp-dir              #"/tmp/")
    (add-runtime-bytes-constant  'vfs-init-file             #"/home/.racketrc")
    (add-runtime-bytes-constant  'vfs-config-dir            #"/app/etc/")
    (add-runtime-bytes-constant  'vfs-addon-dir             #"/home/.local/share/racket/")
    (add-runtime-bytes-constant  'vfs-cache-dir             #"/home/.cache/racket/")
    (add-runtime-bytes-constant  'vfs-exec-file             #"/app/webracket")
    (add-runtime-bytes-constant  'vfs-run-file              #"/app/main.rkt")
    (add-runtime-bytes-constant  'vfs-collects-dir          #"/app/collects/")


    ;;;
    ;;; Predicate Generator
    ;;;

    ; Note: We could generate
    ;          (func $predicate-name? (type $Prim1) ...)
    ;;      too, but it is convenient to grep for function definitions
    ;       using "func $name".

    (define (make-predicate-body ref-type)
      `((param $v (ref eq))
        (result   (ref eq))
        (if (result (ref eq))
            (ref.test (ref ,ref-type) (local.get $v))
            (then (global.get $true))
            (else (global.get $false)))))

    ;;;
    ;;; WEB-ASSEMBLY
    ;;;
    (define (build-runtime-module)
      `(module
         ,@(generate-shared-types)

         ;;;
         ;;; MEMORY
         ;;;

         (import "env" "memory" (memory $memory 1024))

         ;;;
         ;;; IMPORTS
         ;;;

         ;  Imported functions from the host (JavaScript).
         ;  Note all imports must appear before other function definitions.

         (func $js_output
               (import "primitives" "js_output")
               (param i32))
         (func $js_print_fasl
               (import "primitives" "js_print_fasl")
               (param i32) (param i32))
         (func $js-vfs-stat-kind
               (import "primitives" "vfs_stat_kind")
               (param i32) (param i32) (result i32))
         (func $js-vfs-file-size
               (import "primitives" "vfs_file_size")
               (param i32) (param i32) (result i32))
         (func $js-vfs-stat
               (import "primitives" "vfs_stat")
               (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-read-file
               (import "primitives" "vfs_read_file")
               (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-write-file
               (import "primitives" "vfs_write_file")
               (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-delete-file
               (import "primitives" "vfs_delete_file")
               (param i32) (param i32) (result i32))
         (func $js-vfs-delete-directory
               (import "primitives" "vfs_delete_directory")
               (param i32) (param i32) (result i32))
         (func $js-vfs-delete-directory/files
               (import "primitives" "vfs_delete_directory_files")
               (param i32) (param i32) (result i32))
         (func $js-vfs-make-directory
               (import "primitives" "vfs_make_directory")
               (param i32) (param i32) (result i32))
         (func $js-vfs-make-directory*
               (import "primitives" "vfs_make_directory_star")
               (param i32) (param i32) (result i32))
         (func $js-vfs-make-parent-directory*
               (import "primitives" "vfs_make_parent_directory_star")
               (param i32) (param i32) (result i32))
         (func $js-vfs-list-directory
               (import "primitives" "vfs_list_directory")
               (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-root-list
               (import "primitives" "vfs_root_list")
               (param i32) (param i32) (result i32))
         (func $js-vfs-rename
               (import "primitives" "vfs_rename")
               (param i32) (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-copy-file
               (import "primitives" "vfs_copy_file")
               (param i32) (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-copy-directory/files
               (import "primitives" "vfs_copy_directory_files")
               (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-modify-seconds
               (import "primitives" "vfs_modify_seconds")
               (param i32) (param i32) (param i32) (param i32) (result i32))
         (func $js-vfs-permissions
               (import "primitives" "vfs_permissions")
               (param i32) (param i32) (param i32) (param i32) (result i32))
        (func $js-vfs-identity
              (import "primitives" "vfs_identity")
              (param i32) (param i32) (result i32))

         ;; Browser/JS wall-clock bridge. The exact millisecond import returns
         ;; already-tagged fixnum bits so JavaScript can apply WebRacket's
         ;; current 30-bit fixnum wrapping policy without trapping in Wasm.
         (func $js-current-inexact-milliseconds
               (import "primitives" "current_inexact_milliseconds")
               (result f64))
         (func $js-current-milliseconds-bits
               (import "primitives" "current_milliseconds_bits")
               (result i32))
         (func $js-date-field
               (import "primitives" "date_field")
               (param f64) (param i32) (param i32) (result i32))

         (func $char-upcase/ucs
               (import "primitives" "char_upcase")
               (param i32) (result i32))

         (func $char-downcase/ucs
               (import "primitives" "char_downcase")
               (param i32) (result i32))

         (func $char-titlecase/ucs
               (import "primitives" "char_titlecase")
               (param i32) (result i32))

         (func $char-foldcase/ucs
               (import "primitives" "char_foldcase")
               (param i32) (result i32))

        ;; Host provides an approximate grapheme break property mapping.
        ;; It currently covers only a subset of Unicode ranges.
        (func $char-grapheme-break-property/ucs
              (import "primitives" "char_grapheme_break_property")
              (param i32) (result i32))

        (func $char-general-category/ucs
              (import "primitives" "char_general_category")
              (param i32) (result i32))

        (func $char-alphabetic?/ucs
              (import "primitives" "char_alphabetic")
              (param i32) (result i32))

        (func $char-lower-case?/ucs
              (import "primitives" "char_lower_case")
              (param i32) (result i32))

        (func $char-upper-case?/ucs
              (import "primitives" "char_upper_case")
              (param i32) (result i32))

        (func $char-title-case?/ucs
              (import "primitives" "char_title_case")
              (param i32) (result i32))

        (func $char-numeric?/ucs
              (import "primitives" "char_numeric")
              (param i32) (result i32))

        (func $char-symbolic?/ucs
              (import "primitives" "char_symbolic")
              (param i32) (result i32))

        (func $char-punctuation?/ucs
              (import "primitives" "char_punctuation")
              (param i32) (result i32))

        (func $char-graphic?/ucs
              (import "primitives" "char_graphic")
              (param i32) (result i32))

        (func $char-extended-pictographic?/ucs
              (import "primitives" "char_extended_pictographic")
              (param i32) (result i32))

        ;; Math functions
        (func $js-raw-math-abs
              (import "math" "abs")
              (param f64) (result f64))
        (func $js-raw-math-acos
              (import "math" "acos")
              (param f64) (result f64))
        (func $js-raw-math-acosh
              (import "math" "acosh")
              (param f64) (result f64))
        (func $js-raw-math-asin
              (import "math" "asin")
              (param f64) (result f64))
        (func $js-raw-math-asinh
              (import "math" "asinh")
              (param f64) (result f64))
        (func $js-raw-math-atan
              (import "math" "atan")
              (param f64) (result f64))
        (func $js-raw-math-atan2
              (import "math" "atan2")
              (param f64) (param f64) (result f64))
        (func $js-raw-math-atanh
              (import "math" "atanh")
              (param f64) (result f64))
        (func $js-raw-math-cbrt
              (import "math" "cbrt")
              (param f64) (result f64))
        (func $js-raw-math-ceil
              (import "math" "ceil")
              (param f64) (result f64))
        (func $js-raw-math-clz32
              (import "math" "clz32")
              (param i32) (result i32))
        (func $js-raw-math-cos
              (import "math" "cos")
              (param f64) (result f64))
        (func $js-raw-math-cosh
              (import "math" "cosh")
              (param f64) (result f64))
        (func $js-raw-math-exp
              (import "math" "exp")
              (param f64) (result f64))
        (func $js-raw-math-expm1
              (import "math" "expm1")
              (param f64) (result f64))
        (func $js-raw-math-floor
              (import "math" "floor")
              (param f64) (result f64))
        (func $js-raw-math-fround
              (import "math" "fround")
              (param f64) (result f64))
        (func $js-raw-math-hypot
              (import "math" "hypot")
              (param f64) (param f64) (result f64))
        (func $js-raw-math-imul
              (import "math" "imul")
              (param i32) (param i32) (result i32))
        (func $js-raw-math-log
              (import "math" "log")
              (param f64) (result f64))
        (func $js-raw-math-log10
              (import "math" "log10")
              (param f64) (result f64))
        (func $js-raw-math-log1p
              (import "math" "log1p")
              (param f64) (result f64))
        (func $js-raw-math-log2
              (import "math" "log2")
              (param f64) (result f64))
        (func $js-raw-math-max
              (import "math" "max")
              (param f64) (param f64) (result f64))
        (func $js-raw-math-min
              (import "math" "min")
              (param f64) (param f64) (result f64))
        (func $js-raw-math-pow
              (import "math" "pow")
              (param f64) (param f64) (result f64))
        (func $js-raw-math-random
              (import "math" "random")
              (result f64))
        (func $js-raw-math-round
              (import "math" "round")
              (param f64) (result f64))
        (func $js-raw-math-sign
              (import "math" "sign")
              (param f64) (result f64))
        (func $js-raw-math-sin
              (import "math" "sin")
              (param f64) (result f64))
        (func $js-raw-math-sinh
              (import "math" "sinh")
              (param f64) (result f64))
        (func $js-raw-math-sqrt
              (import "math" "sqrt")
              (param f64) (result f64))
        (func $js-raw-math-tan
              (import "math" "tan")
              (param f64) (result f64))
        (func $js-raw-math-tanh
              (import "math" "tanh")
              (param f64) (result f64))
        (func $js-raw-math-trunc
              (import "math" "trunc")
              (param f64) (result f64))

         (func $js-make-callback
               (import "primitives" "make_callback")
               (param i32)
               (result (ref extern)))

         (func $js-register-external
               (import "primitives" "register_external")
               (param (ref extern))
               (result i32))

        (func $js-lookup-external
              (import "primitives" "lookup_external")
              (param i32)
              (result (ref extern)))

        (func $js-external-number->f64
              (import "primitives" "external_number_to_f64")
              (param (ref extern)) (result f64))

        (func $js-flonum->string
              (import "primitives" "flonum_to_string")
              (param f64) (result i32))

        (func $js-external-string->string
              (import "primitives" "external_string_to_string")
              (param externref) (result i32))

        ;; Predicates used by define-foreign return-type adapters.
        (func $js-external-nullish?
              (import "primitives" "external_nullish")
              (param externref) (result i32))

        (func $js-external-undefined?
              (import "primitives" "external_undefined")
              (param externref) (result i32))

        ;; FFI host exception tag imported from the host runtime.
        ;; Foreign imports can throw this tag to communicate host-language
        ;; errors that must become ordinary WebRacket exceptions.
        (tag $ffi-host-exn
             (import "primitives" "foreign_error_tag")
             (param externref))

        ;; FFI related imports
        ,@active-ffi-imports-wat ; generated from "driver.rkt" in "define-foreign.rkt"


         ,@active-ffi-funcs-wat   ; generated from "driver.rkt" in "define-foreign.rkt"

         ;; unsafe-ffi-primitive : symbol? -> procedure?
         ;;   Resolve generated unsafe FFI module aliases to active `.ffi` primitive closures.
         (func $unsafe-ffi-primitive (type $Prim1)
               (param $name (ref eq)) ;; quoted FFI primitive symbol
               (result (ref eq))
               (local $proc (ref eq))
               (if (ref.is_null (global.get $unsafe-ffi-primitive-table))
                   (then (call $initialize-unsafe-ffi-primitive-table)))
               (local.set $proc
                          (call $hasheq-ref/plain
                                (ref.cast (ref $HashEqMutable)
                                          (global.get $unsafe-ffi-primitive-table))
                                (local.get $name)
                                (global.get $missing)))
               (if (ref.eq (local.get $proc) (global.get $missing))
                   (then
                    (call $raise-unexpected-argument (local.get $name))
                    (unreachable)))
               (local.get $proc))

         ;;;
         ;;; Exceptions
         ;;;

         (func $raise-expected-string                 (unreachable))
         (func $raise-unexpected-argument             (unreachable))
         (func $raise-wrong-number-of-values-received (unreachable))

         (func $expect-zero-values
               (param $v (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Values) (local.get $v))
                   (then
                    (if (i32.eqz
                         (i32.eq
                          (array.len (ref.cast (ref $Values) (local.get $v)))
                          (i32.const 0)))
                        (then (call $raise-wrong-number-of-values-received)
                              (unreachable)))
                    (global.get $void))
                   (else
                    (call $raise-wrong-number-of-values-received)
                    (unreachable))))

         (func $expect-one-value
               (param $v (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Values) (local.get $v))
                   (then
                    (if (i32.eqz
                         (i32.eq
                          (array.len (ref.cast (ref $Values) (local.get $v)))
                          (i32.const 1)))
                        (then (call $raise-wrong-number-of-values-received)
                              (unreachable)))
                    (array.get $Values
                               (ref.cast (ref $Values) (local.get $v))
                               (i32.const 0)))
                   (else
                    (local.get $v))))

         (func $expect-n-values
               (param $v (ref eq))
               (param $n i32)
               (result (ref $Values))
               (if (result (ref $Values))
                   (ref.test (ref $Values) (local.get $v))
                   (then
                    (if (i32.eqz
                         (i32.eq
                          (array.len (ref.cast (ref $Values) (local.get $v)))
                          (local.get $n)))
                        (then (call $raise-wrong-number-of-values-received)
                              (unreachable)))
                    (ref.cast (ref $Values) (local.get $v)))
                   (else
                    (call $raise-wrong-number-of-values-received)
                    (unreachable))))

         ;; Convert a host exception caught at an FFI boundary into a
         ;; regular WebRacket exn:fail so `with-handlers` can catch it.
         (func $raise-ffi-host-exception
               (param $host externref)
               (local $message (ref eq))

               (local.set $message
                          (call $linear-memory->string
                                (call $js-external-string->string
                                      (local.get $host))))
               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-input-port-closed : string? -> none
         ;;   Raise an exn:fail for an operation on a closed input port.
         (func $raise-input-port-closed
               (param $message (ref eq))

               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-output-port-closed : string? -> none
         ;;   Raise an exn:fail for an operation on a closed output port.
         (func $raise-output-port-closed
               (param $message (ref eq))

               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-vfs-file-error : string? -> none
         ;;   Raise a catchable exn:fail:filesystem for VFS filesystem errors.
         (func $raise-vfs-file-error
               (param $message (ref eq))

               (drop (call $raise
                           (call $make-exn:fail:filesystem
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         (func $raise-argument-error1
               (param $who      (ref eq))      ;; symbol
               (param $expected (ref eq))      ;; expected description
               (param $got      (ref eq))      ;; received value

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-violation:prefix))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String) (local.get $expected)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:arity-error:given))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $got)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))

               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         ;; `identity` is useful as a first-class function in module-language
         ;; programs, so it needs a runtime procedure in addition to inlining.
         (func $identity (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))
               (local.get $v))

         ;; Unquoted printing strings wrap a string but should display without
         ;; additional quoting, matching the behavior of the underlying string.
         (func $unquoted-printing-string? (type $Prim1)
               ,@(make-predicate-body '$UnquotedPrintingString))

        (func $unquoted-printing-string (type $Prim1)
              (param $s (ref eq))    ;; string?
              (result   (ref eq))    ;; unquoted-printing-string?

              (local $str (ref $String))

              (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                  (then (call $raise-argument-error:string-expected (local.get $s))
                        (unreachable)))

              (local.set $str (ref.cast (ref $String) (local.get $s)))

              (struct.new $UnquotedPrintingString
                          (i32.const 0)
                          (local.get $str)))

        (func $raise-argument-error:unquoted-printing-string-expected (unreachable))

        (func $unquoted-printing-string-value (type $Prim1)
              (param $ups (ref eq))  ;; unquoted-printing-string?
              (result     (ref eq))  ;; string?

              (local $wrapped (ref $UnquotedPrintingString))

              (if (i32.eqz (ref.test (ref $UnquotedPrintingString) (local.get $ups)))
                  (then (call $raise-argument-error:unquoted-printing-string-expected (local.get $ups))
                        (unreachable)))

              (local.set $wrapped (ref.cast (ref $UnquotedPrintingString) (local.get $ups)))
              (struct.get $UnquotedPrintingString $value (local.get $wrapped)))

        ;;;
        ;;; Singletons
        ;;;

         (global $null              (ref eq) ,(Imm '()))
         (global $undefined         (ref eq) ,(Imm (undefined)))         ;  79
         (global $unsafe-undefined  (ref eq) ,(Imm (unsafe-undefined)))  ; 335
         (global $void              (ref eq) ,(Imm (void)))
         (global $false             (ref eq) ,(Imm #f))  ; (ref.i31 (i32.const ?))
         (global $true              (ref eq) ,(Imm #t))
         (global $eof               (ref eq) ,(Imm eof))
         (global $error             (ref eq) ,(R 77))
         (global $missing           (ref eq) ,(R missing-value))   ; #x7fffffff
         (global $tombstone         (ref eq) ,(R tombstone-value)) ; #x3fffffff"

         ;; Commonly used fixnums
         (global $zero  (ref eq) ,(Imm 0))
         (global $one   (ref eq) ,(Imm 1))
         (global $two   (ref eq) ,(Imm 2))
         (global $three (ref eq) ,(Imm 3))

         ;; Commonly used flonums
         ;; - initialized in $entry
         (global $flzero  (mut (ref eq)) ,(Undefined))
         (global $flone   (mut (ref eq)) ,(Undefined))
         (global $fltwo   (mut (ref eq)) ,(Undefined))
         (global $flthree (mut (ref eq)) ,(Undefined))

         ;; String constants used in the runtime
         ,@(declare-runtime-string-constants)
         ;; Bytes constants used in the runtime
         ,@(declare-runtime-bytes-constants)
         ;; Symbol constants used in the runtime
         ,@(declare-runtime-symbol-constants)

         ;; The function $char-general-category returns symbols from this array,
         ;; based on an index computed on the host.
         (global $char-general-category-symbols (mut (ref null $Array)) (ref.null $Array))

         ;; Commonly used realms
         (global $the-racket-realm           (mut (ref eq)) ,(Undefined)) ; the symbol 'racket
         (global $the-racket/primitive-realm (mut (ref eq)) ,(Undefined)) ; the symbol 'racket/primitive

         ;; Cached kernel exception struct type descriptors
         (global $exn-type                              (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:break-type                        (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:break:hang-up-type                (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:break:terminate-type              (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail-type                         (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:contract-type                (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:arity-type          (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:continuation-type   (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:divide-by-zero-type (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:non-fixnum-result-type (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:variable-type       (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:read-type                    (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:read:eof-type                (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:read:non-char-type           (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:filesystem-type              (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:exists-type       (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:version-type      (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:errno-type        (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:missing-module-type (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:network-type                 (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:network:errno-type           (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:out-of-memory-type           (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:unsupported-type             (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:user-type                    (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:syntax-type                  (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:syntax:missing-module-type   (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:syntax:unbound-type          (mut (ref null $StructType)) (ref.null $StructType))

         ;; Cached srcloc struct type descriptor
         (global $srcloc-type (mut (ref null $StructType)) (ref.null $StructType))

         ;; Cached arity-at-least struct type descriptor
         (global $arity-at-least-type (mut (ref null $StructType)) (ref.null $StructType))

         ;; Cached correlated struct type descriptor
         (global $correlated-type (mut (ref null $StructType)) (ref.null $StructType))
         ;; Shared empty correlated properties table
         (global $correlated-empty-props (mut (ref eq)) ,(Undefined))

         ;; Cached syntax struct type descriptor
         (global $syntax-type (mut (ref null $StructType)) (ref.null $StructType))
         ;; Shared empty syntax properties table
         (global $syntax-empty-props (mut (ref eq)) ,(Undefined))

         ;; Module Registry
         (global $empty-module-registry (ref $ModuleRegistry)
                 (struct.new $ModuleRegistry
                             (i32.const 0)
                             (array.new $Array (global.get $null) (i32.const 0))))

         ;; Namespaces
         (global $top-level-namespace (mut (ref null $Namespace)) (ref.null $Namespace))

         ;; Callback registry
         (global $callback-registry (ref $GrowableArray)
                 (struct.new $GrowableArray
                             (array.new $Array (global.get $false) (i32.const 4))
                             (i32.const 4)
                             (i32.const 0)))


         ;; Primitives (as values)
         ,@(declare-primitives-as-globals)
         ,@(declare-ffi-primitives-as-globals)

         ;; Closures

         ; Closures with no free variables can share an empty array
         (global $empty-free (ref $Free)
                 (array.new $Free (global.get $null) (i32.const 0)))

         ;; Closure invocation - invoke
         #;(type $ProcedureInvoker
                 (func (param $proc (ref $Procedure))
                       (param $args (ref $Args))      ; an array of (ref eq)
                       (result (ref eq))))

        (func $raise-arity-mismatch (unreachable))

        (func $procedure-arity->expected-string
              (param $proc (ref $Procedure))
              (result (ref $String))
              (local $a         (ref eq))
              (local $arity/tag i32)
              (local $arity     i32)

              (local.set $a (struct.get $Procedure $arity (local.get $proc)))

              (if (ref.test (ref i31) (local.get $a))
                  (then
                   (local.set $arity/tag (i31.get_s (ref.cast (ref i31) (local.get $a))))
                   (local.set $arity (i32.shr_s (local.get $arity/tag) (i32.const 1)))
                   (return (call $arity-i32->string (local.get $arity)))))

              (ref.cast (ref $String)
                        (call $format/display (call $procedure-arity (local.get $proc)))))

        (func $raise-arity-mismatch/proc
              (param $proc (ref $Procedure))
              (param $argc i32)
              (local $name         (ref eq))
              (local $debug-id     (ref eq))
              (local $expected-str (ref $String))
              (local $received-str (ref $String))
              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              (local.set $name
                         (struct.get $Procedure $name (local.get $proc)))
              (local.set $debug-id (global.get $false))
              (if (ref.test (ref $Closure) (local.get $proc))
                  (then
                   (local.set $debug-id
                              (struct.get $Closure $debug-id
                                          (ref.cast (ref $Closure) (local.get $proc))))))

              (local.set $expected-str
                         (call $procedure-arity->expected-string (local.get $proc)))
              (local.set $received-str
                         (call $i32->string (local.get $argc)))

              (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
                  (then
                   (drop (call $js-log (global.get $symbol:procedure-arity-frontier)))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:name)
                                           (call $cons (local.get $name)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:debug-id)
                                           (call $cons (local.get $debug-id)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:expected-count)
                                           (call $cons (local.get $expected-str)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:received-count)
                                           (call $cons (local.get $received-str)
                                                 (global.get $null)))
                                     (global.get $null))))))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $name)))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:start))
              (call $growable-array-add! (local.get $out) (local.get $expected-str))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out) (local.get $received-str))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-arity-mismatch/name+given
              (param $name (ref eq))
              (param $argc i32)
              (local $received-str (ref $String))
              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              ;; TODO: include "arguments..." block like Racket.
              (local.set $received-str
                         (call $i32->string (local.get $argc)))
              (local.set $out
                         (call $make-growable-array (i32.const 3)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $name)))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:start/no-expected))
              (call $growable-array-add! (local.get $out) (local.get $received-str))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        ;; result-arity-count : (or/c exact-integer? list? values?) -> i32
        ;;   Compute counts for Schemify's result-arity helper primitives.
        (func $result-arity-count
              (param $v (ref eq))
              (result i32)

              (if (ref.test (ref i31) (local.get $v))
                  (then (return (i32.shr_s
                                 (i31.get_s (ref.cast (ref i31) (local.get $v)))
                                 (i32.const 1)))))
              (if (ref.test (ref $Values) (local.get $v))
                  (then (return (array.len (ref.cast (ref $Values) (local.get $v))))))
              (call $length/i32 (local.get $v)))

        ;; raise-result-arity-error/internal : symbol? any/c any/c -> none
        ;;   Raise a catchable result-arity error for internal Schemify checks.
        (func $raise-result-arity-error/internal
              (param $who      (ref eq))      ;; symbol
              (param $expected (ref eq))      ;; expected count or identifier list
              (param $args     (ref eq))      ;; received values as list or $Values
              (result          (ref eq))

              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $who)))
              (call $growable-array-add! (local.get $out) (global.get $string:result-arity-error:start))
              (call $growable-array-add! (local.get $out)
                    (call $i32->string (call $result-arity-count (local.get $expected))))
              (call $growable-array-add! (local.get $out) (global.get $string:result-arity-error:received))
              (call $growable-array-add! (local.get $out)
                    (call $i32->string (call $result-arity-count (local.get $args))))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        ;; raise-binding-result-arity-error : any/c any/c -> none
        ;;   Report a local-binding result-arity mismatch from Schemify output.
        (func $raise-binding-result-arity-error
              (type $Prim2)
              (param $expected (ref eq))
              (param $args     (ref eq))
              (result          (ref eq))

              (local $caller-proc     (ref eq))
              (local $caller-name     (ref eq))
              (local $caller-debug-id (ref eq))

              (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
                  (then
                   (local.set $caller-proc (global.get $debug-current-procedure))
                   (local.set $caller-name (global.get $debug-current-procedure-name))
                   (local.set $caller-debug-id (global.get $false))
                   (if (ref.test (ref $Procedure) (local.get $caller-proc))
                       (then
                        (local.set $caller-name
                                   (struct.get $Procedure $name
                                               (ref.cast (ref $Procedure)
                                                         (local.get $caller-proc))))))
                   (if (ref.test (ref $Closure) (local.get $caller-proc))
                       (then
                        (local.set $caller-debug-id
                                   (struct.get $Closure $debug-id
                                               (ref.cast (ref $Closure)
                                                         (local.get $caller-proc))))))
                   (drop (call $js-log
                               (global.get $symbol:binding-result-arity-frontier)))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:expected-count)
                                           (call $cons
                                                 (call $i32->string
                                                       (call $result-arity-count
                                                             (local.get $expected)))
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:received-count)
                                           (call $cons
                                                 (call $i32->string
                                                       (call $result-arity-count
                                                             (local.get $args)))
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-name)
                                           (call $cons (local.get $caller-name)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-debug-id)
                                           (call $cons (local.get $caller-debug-id)
                                                 (global.get $null)))
                                     (global.get $null))))))
              (call $raise-result-arity-error/internal
                    (global.get $symbol:raise-binding-result-arity-error)
                    (local.get $expected)
                    (local.get $args)))

        ;; raise-definition-result-arity-error : any/c any/c -> none
        ;;   Report a define-values result-arity mismatch from Schemify output.
        (func $raise-definition-result-arity-error
              (type $Prim2)
              (param $expected (ref eq))
              (param $args     (ref eq))
              (result          (ref eq))
              (call $raise-result-arity-error/internal
                    (global.get $symbol:raise-definition-result-arity-error)
                    (local.get $expected)
                    (local.get $args)))

        (func $raise-application-not-procedure
              (param $v (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))
              (local $caller-proc (ref eq))
              (local $caller-name (ref eq))
              (local $caller-debug-id (ref eq))
              (local $got-struct-type (ref eq))

              (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
                  (then
                   (local.set $caller-proc (global.get $debug-current-procedure))
                   (local.set $caller-name (global.get $debug-current-procedure-name))
                   (local.set $caller-debug-id (global.get $false))
                   (local.set $got-struct-type (global.get $false))
                   (if (ref.test (ref $Procedure) (local.get $caller-proc))
                       (then
                        (local.set $caller-name
                                   (struct.get $Procedure $name
                                               (ref.cast (ref $Procedure)
                                                         (local.get $caller-proc))))))
                   (if (ref.test (ref $Closure) (local.get $caller-proc))
                       (then
                        (local.set $caller-debug-id
                                   (struct.get $Closure $debug-id
                                               (ref.cast (ref $Closure)
                                                         (local.get $caller-proc))))))
                   (if (ref.test (ref $Struct) (local.get $v))
                       (then
                        (local.set $got-struct-type
                                   (struct.get $StructType $name
                                               (struct.get $Struct $type
                                                           (ref.cast (ref $Struct)
                                                                     (local.get $v)))))))
                   (drop (call $js-log
                               (global.get $symbol:application-not-procedure-frontier)))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:got-struct-type)
                                           (call $cons (local.get $got-struct-type)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:got-procedure?)
                                           (call $cons (call $procedure? (local.get $v))
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-name)
                                           (call $cons (local.get $caller-name)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-debug-id)
                                           (call $cons (local.get $caller-debug-id)
                                                 (global.get $null)))
                                     (global.get $null))))))

              (local.set $out
                         (call $make-growable-array (i32.const 2)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:application:not-procedure))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-apply-final-arg-not-list
              (param $v (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              ;; TODO: include "argument position: last" and "other arguments..." block like Racket.
              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (global.get $symbol:apply)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:list?))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-struct-type-property-accessor-contract
              (param $prop (ref $StructTypeProperty))
              (param $v    (ref eq))
              (local $accessor-name     (ref $String))
              (local $prop-name-str     (ref $String))
              (local $expected-str      (ref $String))
              (local $out               (ref $GrowableArray))
              (local $message           (ref $String))

              (local.set $prop-name-str
                         (ref.cast (ref $String)
                                   (call $symbol->string
                                         (struct.get $StructTypeProperty $name (local.get $prop)))))
              (local.set $accessor-name
                         (call $string-append/2
                               (local.get $prop-name-str)
                               (global.get $string:accessor-suffix)))
              (local.set $expected-str
                         (call $string-append/2
                               (local.get $prop-name-str)
                               (global.get $string:question)))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (local.get $accessor-name))
              (call $growable-array-add! (local.get $out) (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out) (local.get $expected-str))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

         (func $invoke-closure
               (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))      ;; array of (ref eq)
               (result      (ref eq))

               (local $clos          (ref $Closure))
               (local $code          (ref $ClosureCode))
               (local $arity-i31     (ref i31))
               (local $arity-i32     i32)
               (local $arg-count     i32)
               (local $args-repacked (ref $Args))

               (global.set $debug-current-procedure (local.get $proc))
               (call $debug-invoke-tick)
               ;; Step 1: cast proc to closure and extract code
               (local.set $clos (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $code (struct.get $Closure $code (local.get $clos)))
               ;; Step 2: get arity as signed i32
               (local.set $arity-i31
                          (ref.cast (ref i31) (struct.get $Procedure $arity (local.get $clos))))
               (local.set $arity-i32
                          (i32.shr_s (i31.get_s (local.get $arity-i31)) (i32.const 1)))
               ;; Step 3: get argument count
               (local.set $arg-count (array.len (local.get $args)))
               ;; Debug: log argument count and expected arity
               ; (drop (call $js-log (local.get $proc)))
               ;; Step 4: check arity match
               (if (i32.eqz
                    (call $procedure-arity-includes?/checked/i32
                          (local.get $clos)
                          (local.get $arg-count)))
                   (then
                    (call $raise-arity-mismatch/proc (local.get $clos) (local.get $arg-count))))
               ;; Step 5: repack arguments (if variadic)
               (local.set $args-repacked
                          (call $repack-arguments
                                (local.get $args)
                                (local.get $arity-i32)))
               ;; Step 6: invoke
               (return_call_ref $ClosureCode
                                (local.get $clos)
                                (local.get $args-repacked)
                                (local.get $code)))

         (func $invoke-reduced-procedure
               (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $wrapper  (ref $Closure))
               (local $original (ref $Procedure))
               (local $arg-count i32)

               (local.set $wrapper (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $original
                          (ref.cast (ref $Procedure)
                                    (array.get $Free
                                               (struct.get $Closure $free (local.get $wrapper))
                                               (i32.const 0))))
               (local.set $arg-count (array.len (local.get $args)))
               (if (i32.eqz
                    (call $procedure-arity-includes?/checked/i32
                          (local.get $wrapper)
                          (local.get $arg-count)))
                   (then
                    (call $raise-arity-mismatch/proc (local.get $wrapper) (local.get $arg-count))))
               (return_call_ref $ProcedureInvoker
                                (local.get $original)
                                (local.get $args)
                                (struct.get $Procedure $invoke (local.get $original))))

         ;; invoke-composed-procedure : procedure? args-array? -> any
         ;;   Invoke a compose/compose1 wrapper from right to left.
         (func $invoke-composed-procedure
               (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $wrapper (ref $Closure))
               (local $free    (ref $Free))
               (local $procs   (ref $Array))
               (local $single? (ref eq))
               (local $p       (ref $Procedure))
               (local $inv     (ref $ProcedureInvoker))
               (local $result  (ref eq))
               (local $vals    (ref $Values))
               (local $next    (ref $Args))
               (local $i       i32)
               (local $n       i32)
               (local $m       i32)

               (local.set $p      (global.get $dummy-closure))
               (local.set $inv    (ref.func $invoke-closure))
               (local.set $result (global.get $false))
               (local.set $vals   (array.new $Values (global.get $null) (i32.const 0)))
               (local.set $next   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $wrapper (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $free    (struct.get $Closure $free (local.get $wrapper)))
               (local.set $procs   (ref.cast (ref $Array)
                                              (array.get $Free (local.get $free) (i32.const 0))))
               (local.set $single? (array.get $Free (local.get $free) (i32.const 1)))
               (local.set $n       (array.len (local.get $procs)))
               (if (i32.eqz (local.get $n))
                   (then (return_call $values (local.get $args))))

               (local.set $i (i32.sub (local.get $n) (i32.const 1)))
               (local.set $p (ref.cast (ref $Procedure)
                                        (array.get $Array (local.get $procs) (local.get $i))))
               (local.set $inv (struct.get $Procedure $invoke (local.get $p)))
               (local.set $result
                          (call_ref $ProcedureInvoker
                                    (local.get $p)
                                    (local.get $args)
                                    (local.get $inv)))

               (block $done
                      (loop $loop
                            (br_if $done (i32.eqz (local.get $i)))
                            (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                            (if (ref.eq (local.get $single?) (global.get $true))
                                (then
                                 (local.set $result (call $expect-one-value (local.get $result)))
                                 (local.set $next (array.new_fixed $Args 1 (local.get $result))))
                                (else
                                 (if (ref.test (ref $Values) (local.get $result))
                                     (then
                                      (local.set $vals (ref.cast (ref $Values) (local.get $result)))
                                      (local.set $m    (array.len (local.get $vals)))
                                      (local.set $next (array.new $Args (global.get $null) (local.get $m)))
                                      (array.copy $Args $Values
                                                  (local.get $next) (i32.const 0)
                                                  (local.get $vals) (i32.const 0)
                                                  (local.get $m)))
                                     (else
                                      (local.set $next
                                                 (array.new_fixed $Args 1 (local.get $result)))))))
                            (local.set $p (ref.cast (ref $Procedure)
                                                    (array.get $Array
                                                               (local.get $procs)
                                                               (local.get $i))))
                            (local.set $inv (struct.get $Procedure $invoke (local.get $p)))
                            (local.set $result
                                       (call_ref $ProcedureInvoker
                                                 (local.get $p)
                                                 (local.get $next)
                                                 (local.get $inv)))
                            (br $loop)))
               (local.get $result))

         ;; Invoker for case-lambda closures.
         ;; - $args is the vector of *user* arguments (no [closure, tail?] header).
         ;; - Arity checking + repacking are handled by the closure's code
         ;;   ($code:case-lambda-dispatch), so we just tail-call it.
         ; Note: In principle we could use $invoke-closure,
         ;       but that leads to checking the arity multiple times.
         (func $invoke-case-closure (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $clos (ref $Closure))
               (local $code (ref $ClosureCode))
               (global.set $debug-current-procedure (local.get $proc))
               (call $debug-invoke-tick)
               ;; Cast and fetch code pointer
               (local.set $clos (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $code (struct.get $Closure $code (local.get $clos)))
               ;; Tail-call the dispatcher
               (return_call_ref $ClosureCode
                                (local.get $clos)
                                (local.get $args)
                                (local.get $code)))

        ;; Primitive procedure invocation helpers
        (func $raise-no-code
              (param $pproc (ref $PrimitiveProcedure))
              (result (ref eq))
              (unreachable))

        (func $raise-code-type-mismatch
              (param $pproc (ref $PrimitiveProcedure))
              (result (ref eq))
              (call $js-log (call $format/display (local.get $pproc)))
              (unreachable))

        (func $primitive-invoke:raise-arity-error
              (param $pproc (ref $PrimitiveProcedure))
              (param $argc  i32)
              (result       (ref eq))
              (local $name         (ref eq))
              (local $expected-str (ref $String))
              (local $received-str (ref $String))
              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              (local.set $name
                         (struct.get $Procedure $name (local.get $pproc)))

              (local.set $expected-str
                         (call $procedure-arity->expected-string (local.get $pproc)))
              (local.set $received-str
                         (call $i32->string (local.get $argc)))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $name)))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:start))
              (call $growable-array-add! (local.get $out) (local.get $expected-str))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out) (local.get $received-str))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        ;; Shape codes:
        ;;   0: exact 0
        ;;   1: exact 1
        ;;   2: exact 2
        ;;   3: exact 3
        ;;   4: exact 4
        ;;   5: exact 5
        ;;   6: at least 0
        ;;   7: at least 1
        ;;   8: at least 2
        ;;   9: at least >=3
        ;;  10-13: like 6-9 but pass rest arguments as $Args arrays
        ;;  14: between 2 and 3 arguments (3rd optional)
        ;;  15: between 3 and 4 arguments (4th optional)
        ;;  16: between 0 and 1 arguments
        ;;  17: between 0 and 2 arguments
        ;;  18: between 1 and 2 arguments
        ;;  19: between 1 and 3 arguments
        ;;  20: between 1 and 4 arguments
        ;;  21: between 1 and 5 arguments
        ;;  22: between 2 and 4 arguments
        ;;  23: between 2 and 5 arguments
        ;;  24: between 3 and 5 arguments
        ;;  25: between 6 and 7 arguments

        (func $raise-primitive-invoke:unhandled-shape (unreachable))

        (func $primitive-invoke (type $ProcedureInvoker)
              (param $proc (ref $Procedure))
              (param $args (ref $Args))
              (result      (ref eq))

              (local $pproc (ref $PrimitiveProcedure))
              (local $code  (ref null func))

              (local $arity/tag i32)
              (local $arity     i32)
              (local $shape     i32)
              (local $k         i32)
              (local $argc      i32)

              (local $a0   (ref eq))
              (local $a1   (ref eq))
              (local $a2   (ref eq))
              (local $a3   (ref eq))
              (local $a4   (ref eq))
              (local $rest (ref eq))

              (global.set $debug-current-procedure (local.get $proc))
              (call $debug-invoke-tick)
              (local.set $a0 (global.get $null))
              (local.set $a1 (global.get $null))
              (local.set $a2 (global.get $null))
              ; (local.set $a3 (global.get $null))
              ; (local.set $a4 (global.get $null))
              (local.set $rest (global.get $null))

              ;; Proc -> PrimitiveProcedure
              (local.set $pproc
                         (ref.cast (ref $PrimitiveProcedure) (local.get $proc)))

              ;; Fetch code
              (local.set $code
                         (struct.get $PrimitiveProcedure $code (local.get $pproc)))

              ;; Ensure non-null
              (if (ref.is_null (local.get $code))
                  (then (return (call $raise-no-code (local.get $pproc)))))

              ;; argc
              (local.set $argc (array.len (local.get $args)))

              ;; Decode arity fixnum: i31 -> i32, then >> 1
              (local.set $arity/tag
                         (i31.get_s  ; signed due to negative arities
                          (ref.cast (ref i31)
                                    (struct.get $Procedure $arity (local.get $pproc)))))
              (local.set $arity
                         (i32.shr_s (local.get $arity/tag) (i32.const 1)))

              ;; Compute shape (and k for "at least k")
              (if (i32.ge_s (local.get $arity) (i32.const 0))
                  (then
                   ;; exact: shape = min(arity, 5), except for 6 -> 26
                   (local.set $shape (local.get $arity))
                   (if (i32.gt_u (local.get $shape) (i32.const 5))
                       (then (if (i32.eq (local.get $shape) (i32.const 6))
                                 (then (local.set $shape (i32.const 26)))
                                 (else (local.set $shape (i32.const 5)))))))
                  (else
                   ;; at least: k = -arity - 1; shape = 6 + min(k, 3)
                   (local.set $k
                              (i32.sub (i32.const -1) (local.get $arity)))
                   (local.set $shape (local.get $k))
                   (if (i32.gt_u (local.get $shape) (i32.const 3))
                       (then (local.set $shape (i32.const 3))))
                   (local.set $shape (i32.add (i32.const 6) (local.get $shape)))))

              ;; Debug: log argc, arity, shape
              ;; (drop (call $js-log (call $i32->string (local.get $argc))))
              ;; (drop (call $js-log (call $i32->string (local.get $arity))))
              ;; (drop (call $js-log (call $i32->string (local.get $shape))))

              ;; Preload first five args when available
              (if (i32.gt_u (local.get $argc) (i32.const 0))
                  (then
                   (local.set $a0
                              (array.get $Args (local.get $args) (i32.const 0)))))
              (if (i32.gt_u (local.get $argc) (i32.const 1))
                  (then
                   (local.set $a1
                              (array.get $Args (local.get $args) (i32.const 1)))))
              (if (i32.gt_u (local.get $argc) (i32.const 2))
                  (then
                   (local.set $a2
                              (array.get $Args (local.get $args) (i32.const 2)))))

              #;(if (i32.gt_u (local.get $argc) (i32.const 3))
                  (then
                   (local.set $a3
                              (array.get $Args (local.get $args) (i32.const 3)))))
              #;(if (i32.gt_u (local.get $argc) (i32.const 4))
                  (then
                   (local.set $a4
                              (array.get $Args (local.get $args) (i32.const 4)))))

              ;; br_table dispatch by shape
              (block $default
                (block $L13
                  (block $L12
                    (block $L11
                      (block $L10
                        (block $L9
                          (block $L8
                            (block $L7
                              (block $L6
                                (block $L5
                                  (block $L4
                                    (block $L3
                                      (block $L2
                                        (block $L1
                                          (block $L0
                                            (br_table $L0 $L1 $L2 $L3 $L4 $L5 $L6 $L7 $L8 $L9 $L10 $L11 $L12 $L13 $default (local.get $shape))
                                          ) ;; end $L0
                                          ;; shape 0: exact 0
                                          #;(drop (call $js-log (call $i32->string (i32.const 0))))
                                          (if (i32.eqz (local.get $argc))
                                              (then
                                               (if (ref.test (ref $Prim0) (local.get $code))
                                                   (then
                                                    (return_call_ref $Prim0
                                                                     (ref.cast (ref $Prim0) (local.get $code))))
                                                   (else
                                                    (return (call $raise-code-type-mismatch (local.get $pproc)))))
                                              (else
                                               (return (call $primitive-invoke:raise-arity-error
                                                                 (local.get $pproc) (local.get $argc)))))
                                        )) ;; end $L1
                                        ;; shape 1: exact 1
                                        #;(drop (call $js-log (call $i32->string (i32.const 1))))
                                        (if (i32.eq (local.get $argc) (i32.const 1))
                                            (then
                                             (if (ref.test (ref $Prim1) (local.get $code))
                                                 (then
                                                  (return_call_ref $Prim1
                                                                   (local.get $a0)
                                                                   (ref.cast (ref $Prim1) (local.get $code))))
                                                 (else
                                                  (return (call $raise-code-type-mismatch (local.get $pproc)))))
                                            (else
                                             (return (call $primitive-invoke:raise-arity-error
                                                           (local.get $pproc) (local.get $argc)))))
                                      )) ;; end $L2
                                      ;; shape 2: exact 2
                                      #;(drop (call $js-log (call $i32->string (i32.const 2))))
                                      (if (i32.eq (local.get $argc) (i32.const 2))
                                          (then
                                           (if (ref.test (ref $Prim2) (local.get $code))
                                               (then
                                                (return_call_ref $Prim2
                                                                 (local.get $a0)
                                                                 (local.get $a1)
                                                                 (ref.cast (ref $Prim2) (local.get $code))))
                                               (else
                                                (return (call $raise-code-type-mismatch (local.get $pproc)))))
                                          (else
                                           (return (call $primitive-invoke:raise-arity-error
                                                         (local.get $pproc) (local.get $argc)))))
                                    )) ;; end $L3
                                    ;; shape 3: exact 3
                                    #;(drop (call $js-log (call $i32->string (i32.const 3))))
                                    (if (i32.eq (local.get $argc) (i32.const 3))
                                        (then
                                         (if (ref.test (ref $Prim3) (local.get $code))
                                             (then
                                              (return_call_ref $Prim3
                                                               (local.get $a0)
                                                               (local.get $a1)
                                                               (local.get $a2)
                                                               (ref.cast (ref $Prim3) (local.get $code))))
                                             (else
                                              (return (call $raise-code-type-mismatch (local.get $pproc)))))
                                        (else
                                         (return (call $primitive-invoke:raise-arity-error
                                                       (local.get $pproc) (local.get $argc)))))
                                  )) ;; end $L4
                                  ;; shape 4: exact 4
                                  #;(drop (call $js-log (call $i32->string (i32.const 4))))
                                  (if (i32.eq (local.get $argc) (i32.const 4))
                                      (then (if (ref.test (ref $Prim4) (local.get $code))
                                                (then (return_call_ref $Prim4
                                                                       (local.get $a0)
                                                                       (local.get $a1)
                                                                       (local.get $a2)
                                                                       (array.get $Args (local.get $args) (i32.const 3))
                                                                       (ref.cast (ref $Prim4) (local.get $code))))
                                                (else
                                                 (return (call $raise-code-type-mismatch (local.get $pproc))))))
                                      (else (return (call $primitive-invoke:raise-arity-error
                                                          (local.get $pproc) (local.get $argc))))
                                )) ;; end $L5
                                ;; shape 5: exact 5
                                #;(drop (call $js-log (call $i32->string (i32.const 5))))
                                (if (i32.eq (local.get $argc) (i32.const 5))
                                    (then (if (ref.test (ref $Prim5) (local.get $code))
                                              (then (return_call_ref $Prim5
                                                                     (local.get $a0)
                                                                     (local.get $a1)
                                                                     (local.get $a2)
                                                                     (array.get $Args (local.get $args) (i32.const 3))
                                                                     (array.get $Args (local.get $args) (i32.const 4))
                                                                     (ref.cast (ref $Prim5) (local.get $code))))
                                              (else
                                               (return (call $raise-code-type-mismatch (local.get $pproc))))))
                                    (else (return (call $primitive-invoke:raise-arity-error
                                                        (local.get $pproc) (local.get $argc))))
                              )) ;; end $L6
                              ;; shape 6: at least 0 (rest list)
                              (if (ref.test (ref $Prim>=0) (local.get $code))
                                  (then (local.set $rest
                                                   (call $rest-arguments->list
                                                         (local.get $args)
                                                         (i32.const 0)))
                                        (return_call_ref $Prim>=0
                                                         (local.get $rest)
                                                         (ref.cast (ref $Prim>=0) (local.get $code))))
                                  (else
                                   (return (call $raise-code-type-mismatch (local.get $pproc))))
                            )) ;; end $L7
                            ;; shape 7: at least 1 (rest list)
                            (if (i32.ge_u (local.get $argc) (i32.const 1))
                                (then (if (ref.test (ref $Prim>=1) (local.get $code))
                                          (then (local.set $rest
                                                           (call $rest-arguments->list
                                                                 (local.get $args)
                                                                 (i32.const 1))))
                                          (else (return_call_ref $Prim>=1
                                                                 (local.get $a0)
                                                                 (local.get $rest)
                                                                 (ref.cast (ref $Prim>=1) (local.get $code))))))
                                (else (return (call $primitive-invoke:raise-arity-error
                                                    (local.get $pproc) (local.get $argc))))
                          )) ;; end $L8
                          ;; shape 8: at least 2 (rest list)
                          (if (i32.ge_u (local.get $argc) (i32.const 2))
                              (then (if (ref.test (ref $Prim>=2) (local.get $code))
                                        (then (local.set $rest
                                                         (call $rest-arguments->list
                                                               (local.get $args)
                                                               (i32.const 2))))
                                        (else (return_call_ref $Prim>=2
                                                               (local.get $a0)
                                                               (local.get $a1)
                                                               (local.get $rest)
                                                               (ref.cast (ref $Prim>=2) (local.get $code))))))
                              (else (return (call $primitive-invoke:raise-arity-error
                                                  (local.get $pproc) (local.get $argc))))
                        )) ;; end $L9
                        ;; shape 9: at least 3 (rest list)
                        (if (i32.ge_u (local.get $argc) (i32.const 3))
                            (then (if (ref.test (ref $Prim>=3) (local.get $code))
                                      (then (local.set $rest
                                                       (call $rest-arguments->list
                                                             (local.get $args)
                                                             (i32.const 3))))
                                      (else (return_call_ref $Prim>=3
                                                             (local.get $a0)
                                                             (local.get $a1)
                                                             (local.get $a2)
                                                             (local.get $rest)
                                                             (ref.cast (ref $Prim>=3) (local.get $code))))))
                            (else (return (call $primitive-invoke:raise-arity-error
                                                    (local.get $pproc) (local.get $argc))))
                      )) ;; end $L10
                      ;; shape 10: at least 0 (rest $Args)
                       (if (ref.test (ref $Prim>=0) (local.get $code))
                           (then (return_call_ref $Prim>=0
                                                  (local.get $args)
                                                  (ref.cast (ref $Prim>=0) (local.get $code))))
                           (else (return (call $raise-code-type-mismatch (local.get $pproc))))
                    )) ;; end $L11
                    ;; shape 11: at least 1 (rest $Args)
                    (if (i32.ge_u (local.get $argc) (i32.const 1))
                        (then
                         (if (ref.test (ref $Prim>=1) (local.get $code))
                             (then (return_call_ref $Prim>=1
                                                    (local.get $a0)
                                                    (call $rest-arguments->args
                                                          (local.get $args)
                                                          (i32.const 1))
                                                    (ref.cast (ref $Prim>=1) (local.get $code))))
                             (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
                        (else
                         (return (call $primitive-invoke:raise-arity-error
                                       (local.get $pproc) (local.get $argc))))
                  )) ;; end $L12
                  ;; shape 12: at least 2 (rest $Args)
                  (if (i32.ge_u (local.get $argc) (i32.const 2))
                      (then
                       (if (ref.test (ref $Prim>=2) (local.get $code))
                           (then (return_call_ref $Prim>=2
                                                  (local.get $a0)
                                                  (local.get $a1)
                                                  (call $rest-arguments->args
                                                        (local.get $args)
                                                        (i32.const 2))
                                                  (ref.cast (ref $Prim>=2) (local.get $code))))
                           (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
                       (else
                       (return (call $primitive-invoke:raise-arity-error
                                     (local.get $pproc) (local.get $argc)))))
                )) ;; end $L13
                ;; shape 13: at least 3 (rest $Args)
                (if (i32.ge_u (local.get $argc) (i32.const 3))
                    (then
                     (if (ref.test (ref $Prim>=3) (local.get $code))
                         (then (return_call_ref $Prim>=3
                                                (local.get $a0)
                                                (local.get $a1)
                                                (local.get $a2)
                                                (call $rest-arguments->args
                                                      (local.get $args)
                                                      (i32.const 3))
                                                (ref.cast (ref $Prim>=3) (local.get $code))))
                         (else (return (call $raise-code-type-mismatch (local.get $pproc)))))
                     (else
                      (return (call $primitive-invoke:raise-arity-error
                                    (local.get $pproc) (local.get $argc)))))
              )) ;; end $default
              (if (i32.eq (local.get $shape) (i32.const 26))
                  (then (if (i32.eq (local.get $argc) (i32.const 6))
                            (then (if (ref.test (ref $Prim6) (local.get $code))
                                      (then (return_call_ref $Prim6
                                                             (local.get $a0)
                                                             (local.get $a1)
                                                             (local.get $a2)
                                                             (array.get $Args (local.get $args) (i32.const 3))
                                                             (array.get $Args (local.get $args) (i32.const 4))
                                                             (array.get $Args (local.get $args) (i32.const 5))
                                                             (ref.cast (ref $Prim6) (local.get $code))))
                                      (else (return (call $raise-code-type-mismatch (local.get $pproc))))))
                            (else (return (call $primitive-invoke:raise-arity-error
                                                (local.get $pproc) (local.get $argc)))))
                        (unreachable))
                  (else (nop)))
              #;(drop (call $js-log (call $i32->string (i32.const 10))))
              (call $raise-primitive-invoke:unhandled-shape)
              (unreachable))

        ,@(for/list ([shape (in-list primitive-shapes)])
            (primitive-invoker shape))

        (func $repack-arguments
              ; Returns new $Args suitable for calling both fixed and variadic procedures.
              ; I.e. function converts the rest arguments to a list and stores them in the last slot.

               (param $args  (ref $Args))   ;; full argument list
               (param $arity i32)           ;; decoded arity (from fixnum)
               (result       (ref $Args))

               (local $arg-count  i32)
               (local $rest-start i32)
               (local $rest       (ref eq))
               (local $args+rest  (ref $Args))

               ;; Step 1: Compute number of arguments
               (local.set $arg-count (array.len (local.get $args)))
               ;; Step 2: Check if arity is negative (variadic)
               (if (i32.lt_s (local.get $arity) (i32.const 0))
                   (then
                    ;; Step 3: Compute number of fixed args = -1 - arity
                    (local.set $rest-start (i32.sub (i32.const -1) (local.get $arity)))
                    ;; Step 4: Extract rest arguments and turn into list
                    (local.set $rest (call $rest-arguments->list
                                           (local.get $args)
                                           (local.get $rest-start)))
                    ;; Step 5: Create new $Args array with fixed args + 1
                    (local.set $args+rest
                               (array.new $Args
                                          (global.get $false)
                                          (i32.add (local.get $rest-start) (i32.const 1))))
                    ;; Step 6: Copy fixed arguments
                    (array.copy $Args $Args
                                (local.get $args+rest)
                                (i32.const 0)
                                (local.get $args)
                                (i32.const 0)
                                (local.get $rest-start))
                    ;; Step 7: Place rest list at final position
                    (array.set $Args
                               (local.get $args+rest)
                               (local.get $rest-start)
                               (local.get $rest))
                    ;; Step 8: Return modified array
                    (return (local.get $args+rest)))
                   (else
                    ;; Step 9: Arity is non-negative — return original
                    (return (local.get $args))))
               (unreachable))




         ;; Dispatcher for (case-lambda ...) using arities:
         ;;   m >= 0  ⇒ exactly m args
         ;;   m <  0  ⇒ at least (-m - 1) args
         ;;
         ;; $Free payload captured by the dispatcher closure:
         ;;   index 0 : (ref $I32Array)  ; arities per arm
         ;;   index 1 : (ref $Array)     ; arm closures (source order)
         (func $raise-arity-error/case-lambda/arities
               (param $proc    (ref $Procedure))
               (param $argc    i32)
               (param $arities (ref $I32Array))
               (result (ref eq))

               (local $name         (ref eq))
               (local $expected-str (ref $String))
               (local $received-str (ref $String))
               (local $i            i32)
               (local $n            i32)
               (local $m            i32)
               (local $ga           (ref $GrowableArray))
               (local $out          (ref $GrowableArray))
               (local $message      (ref $String))

               (local.set $name
                          (struct.get $Procedure $name (local.get $proc)))
               (local.set $received-str
                          (call $i32->string (local.get $argc)))

               (local.set $n (array.len (local.get $arities)))
               (local.set $ga (call $make-growable-array (local.get $n)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                            (local.set $m (array.get $I32Array (local.get $arities) (local.get $i)))
                            (call $growable-array-add! (local.get $ga)
                                  (call $arity-i32->string (local.get $m)))
                            (if (i32.lt_u (i32.add (local.get $i) (i32.const 1)) (local.get $n))
                                (then (call $growable-array-add! (local.get $ga)
                                              (global.get $string:arity-error:or))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               (local.set $expected-str
                          (call $growable-array-of-strings->string (local.get $ga)))

               (local.set $out
                          (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $out) (call $format/display (local.get $name)))
               (call $growable-array-add! (local.get $out) (global.get $string:arity-error:start))
               (call $growable-array-add! (local.get $out) (local.get $expected-str))
               (call $growable-array-add! (local.get $out) (global.get $string:arity-error:given))
               (call $growable-array-add! (local.get $out) (local.get $received-str))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))

               (call $raise
                     (call $exn:fail:contract:arity/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         ;; Dispatcher uses typed $CaseClosure fields: $arities and $arms.
         (func $code:case-lambda-dispatch (type $ClosureCode)
               (param $clos (ref $Closure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $cclos    (ref $CaseClosure))
               (local $arities  (ref $I32Array))
               (local $arms     (ref $Array))
               (local $argc     i32)
               (local $i        i32)
               (local $m        i32)
               (local $arm      (ref $Closure))
               (local $out      (ref $Args))
               (local $code     (ref $ClosureCode))

               ; Get arities and arms (closures)
               (local.set $cclos   (ref.cast (ref $CaseClosure) (local.get $clos)))
               (local.set $arities (struct.get $CaseClosure $arities (local.get $cclos)))
               (local.set $arms    (struct.get $CaseClosure $arms    (local.get $cclos)))
               ; Argument count
               (local.set $argc (array.len (local.get $args)))
               (local.set $i (i32.const 0))

               (loop $scan
                     (if (i32.ge_u (local.get $i) (array.len (local.get $arms)))
                         (then (drop (call $js-log (call $format/display (local.get $clos))))
                               (call $raise-arity-error/case-lambda/arities
                                     (local.get $clos) (local.get $argc) (local.get $arities))
                               (unreachable)))
                     (local.set $m
                                (array.get $I32Array (local.get $arities) (local.get $i)))
                     (if
                      (i32.or
                       ;; fixed: argc == m
                       (i32.and (i32.ge_s (local.get $m) (i32.const 0))
                                (i32.eq   (local.get $argc) (local.get $m)))
                       ;; rest:  argc >= -m - 1
                       (i32.and (i32.lt_s (local.get $m) (i32.const 0))
                                (i32.ge_u (local.get $argc)
                                          (i32.sub (i32.sub (i32.const 0) (local.get $m))
                                                   (i32.const 1)))))
                      (then
                       ;; Match → repack once and tail-call arm's *code*
                       (local.set $arm  (ref.cast (ref $Closure)
                                                  (array.get $Array (local.get $arms) (local.get $i))))
                       (local.set $out  (call $repack-arguments (local.get $args) (local.get $m)))
                       (local.set $code (struct.get $Closure $code (local.get $arm)))
                       (return_call_ref $ClosureCode (local.get $arm) (local.get $out) (local.get $code)))
                      (else
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $scan))))
               (unreachable))



         (func $invoke-struct (type $ProcedureInvoker)
               (param $proc (ref $Procedure)) ; type check: an $Struct is expected
               (param $args (ref $Args))      ; an array of (ref eq)
               (result      (ref eq))

               (local $struct       (ref $Struct))
               (local $type         (ref $StructType))
               (local $prop-desc    (ref $StructTypeProperty))
               (local $sentinel     (ref eq))
               (local $prop-val     (ref eq))
               (local $fields       (ref $Array))
               (local $idx          i32)
               (local $super        (ref eq))
               (local $super-type   (ref null $StructType))
               (local $super-count  i32)
               (local $abs-index    i32)
               (local $target       (ref eq))
               (local $delegate     (ref $Procedure))
               (local $delegate-inv (ref $ProcedureInvoker))
               (local $argc         i32)
               (local $packed-args  (ref $Args))
               (local $i            i32)
               (local $struct-name  (ref eq))

               ;; Validate and cast the incoming procedure reference.
               (if (i32.eqz (ref.test (ref $Struct) (local.get $proc)))
                   (then (call $raise-application-not-procedure (local.get $proc))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $proc)))
               (local.set $argc (array.len (local.get $args)))

               ;; Look up the prop:procedure association for the structure type.
               (local.set $type (struct.get $Struct $type (local.get $struct)))
               (local.set $struct-name (struct.get $StructType $name (local.get $type)))
               (local.set $prop-desc
                          (ref.cast (ref $StructTypeProperty)
                                    (global.get $prop:procedure)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
               (local.set $prop-val
                          (call $struct-type-property-lookup
                                (local.get $type)
                                (local.get $prop-desc)
                                (local.get $sentinel)))

               ;; Abort when the structure type is not applicable.
               (if (ref.eq (local.get $prop-val) (local.get $sentinel))
                   (then (call $raise-application-not-procedure (ref.cast (ref eq) (local.get $struct)))
                         (unreachable)))

               ;; Case 1: property designates a structure field containing a procedure.
               (if (ref.test (ref i31) (local.get $prop-val))
                   (then
                    (local.set $idx (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $prop-val)))
                                               (i32.const 1)))
                    (local.set $super (struct.get $StructType $super (local.get $type)))
                    (local.set $super-type (ref.null $StructType))
                    (local.set $super-count (i32.const 0))
                    (if (i32.eqz (ref.eq (local.get $super) (global.get $false)))
                        (then (local.set $super-type (ref.cast (ref $StructType) (local.get $super)))
                              (local.set $super-count
                                         (struct.get $StructType $field-count (local.get $super-type)))))
                    (local.set $fields (struct.get $Struct $fields (local.get $struct)))
                    (local.set $abs-index (i32.add (local.get $super-count) (local.get $idx)))
                    (local.set $target (array.get $Array (local.get $fields) (local.get $abs-index)))
                    (if (i32.eqz (ref.test (ref $Procedure) (local.get $target)))
                        (then (call $raise-arity-mismatch/name+given
                                    (local.get $struct-name)
                                    (local.get $argc))
                              (unreachable)))
                    (local.set $delegate (ref.cast (ref $Procedure) (local.get $target)))
                    (local.set $delegate-inv (struct.get $Procedure $invoke (local.get $delegate)))
                    (return_call_ref $ProcedureInvoker
                                     (local.get $delegate)
                                     (local.get $args)
                                     (local.get $delegate-inv))))

               ;; Case 2: property supplies a procedure to receive the structure + arguments.
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $prop-val)))
                   (then (call $raise-arity-mismatch/name+given
                               (local.get $struct-name)
                               (local.get $argc))
                         (unreachable)))
               (local.set $delegate (ref.cast (ref $Procedure) (local.get $prop-val)))
               (local.set $delegate-inv (struct.get $Procedure $invoke (local.get $delegate)))
               (local.set $packed-args
                          (array.new $Args (global.get $null)
                                     (i32.add (local.get $argc) (i32.const 1))))
               (array.set $Args (local.get $packed-args) (i32.const 0) (local.get $struct))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $copy
                            (br_if $done (i32.ge_u (local.get $i) (local.get $argc)))
                            (array.set $Args (local.get $packed-args)
                                       (i32.add (local.get $i) (i32.const 1))
                                       (array.get $Args (local.get $args) (local.get $i)))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $copy)))
               (return_call_ref $ProcedureInvoker
                                (local.get $delegate)
                                (local.get $packed-args)
                                (local.get $delegate-inv)))

         ;; Unused stubs kept for now; safe to remove later.
         (func $raise-arity-error:exactly  (unreachable))
         (func $raise-arity-error:at-least (unreachable))

         ,(core-runtime-helper-form core-runtime-helper-index '$rest-arguments->list)

         ,(core-runtime-helper-form core-runtime-helper-index '$rest-arguments->args)

         ;; Variable used by `closedapp` to hold the closure during construction.
         (func $dummy-code (type $ClosureCode) (param $clos (ref $Closure))
               (param $args (ref $Args)) (result (ref eq)) ,(Imm 0))
         (func $placeholder-linklet-code (type $ClosureCode)
               (param $clos (ref $Closure))
               (param $args (ref $Args))
               (result     (ref eq))
               ;; Metadata-only linklets are inspectable but not executable.
               ;; Keep this distinct from $dummy-code so expander/eval probes
               ;; fail at the missing execution boundary instead of returning 0.
               (call $raise-arguments-error
                     (global.get $symbol:instantiate-linklet)
                     (global.get $string:metadata-only-compiled-linklet)
                     (array.new_fixed $Args 0))
               (unreachable))
         ;; linklet-datum-body-list : linklet-datum? -> list?
         ;;   Return the body forms after imports and exports in `(linklet ...)`.
         (func $linklet-datum-body-list
               (param $src (ref eq)) ;; linklet datum
               (result     (ref eq))

               (local $rest (ref eq))

               (if (i32.eqz (ref.test (ref $Pair) (local.get $src)))
                   (then (return (global.get $null))))
               (local.set $rest
                          (struct.get $Pair $d
                                      (ref.cast (ref $Pair) (local.get $src))))
               ;; imports
               (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                   (then (return (global.get $null))))
               (local.set $rest
                          (struct.get $Pair $d
                                      (ref.cast (ref $Pair) (local.get $rest))))
               ;; exports
               (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                   (then (return (global.get $null))))
               (struct.get $Pair $d
                           (ref.cast (ref $Pair) (local.get $rest))))

         ;; linklet-normalize-id : any/c -> any/c
         ;;   Convert a syntax-wrapped source-linklet identifier to its symbol.
         (func $linklet-normalize-id
               (param $id (ref eq)) ;; linklet variable identifier
               (result    (ref eq))

               (if (ref.eq (call $syntax? (local.get $id)) (global.get $true))
                   (then (return (call $syntax-e (local.get $id)))))
               (local.get $id))

         ;; linklet-import-group-contains?/i32 : list? symbol? -> i32
         ;;   Check whether a linklet import group contains a variable.
         (func $linklet-import-group-contains?/i32
               (param $group (ref eq)) ;; import group
               (param $id    (ref eq)) ;; normalized variable id
               (result       i32)

               (local $node (ref eq))
               (local $pair (ref $Pair))
               (local $sym  (ref eq))

               (local.set $node (local.get $group))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                (then (return (i32.const 0))))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $sym
                                       (call $linklet-normalize-id
                                             (struct.get $Pair $a (local.get $pair))))
                            (if (ref.eq (local.get $sym) (local.get $id))
                                (then (return (i32.const 1))))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $loop)))
               (i32.const 0))

         ;; linklet-import-instance-for-id : list? args? symbol? -> (or/c instance? #f)
         ;;   Find the import instance that supplies id, if any.
         (func $linklet-import-instance-for-id
               (param $importss (ref eq)) ;; linklet import groups
               (param $insts    (ref $Args)) ;; target instance, then imports
               (param $id       (ref eq)) ;; normalized variable id
               (result          (ref eq))

               (local $node  (ref eq))
               (local $pair  (ref $Pair))
               (local $group (ref eq))
               (local $index i32)

               (local.set $node (local.get $importss))
               (local.set $index (i32.const 1))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                (then (return (global.get $false))))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $group (struct.get $Pair $a (local.get $pair)))
                            (if (call $linklet-import-group-contains?/i32
                                      (local.get $group)
                                      (local.get $id))
                                (then
                                 (if (i32.lt_u (local.get $index)
                                               (array.len (local.get $insts)))
                                     (then (return (array.get $Args
                                                          (local.get $insts)
                                                          (local.get $index)))))))
                            (local.set $index (i32.add (local.get $index) (i32.const 1)))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $loop)))
               (global.get $false))

         ;; linklet-eval-sequence : instance? list? args? list? -> any/c
         ;;   Evaluate body forms left-to-right for the bootstrap linklet interpreter.
         (func $linklet-eval-sequence
               (param $self     (ref eq)) ;; target instance
               (param $importss (ref eq)) ;; linklet import groups
               (param $insts    (ref $Args)) ;; target instance, then imports
               (param $forms    (ref eq)) ;; body form list
               (result          (ref eq))

               (local $node   (ref eq))
               (local $pair   (ref $Pair))
               (local $result (ref eq))

               (local.set $node (local.get $forms))
               (local.set $result (global.get $void))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                (then (return (global.get $void))))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $result
                                       (call $linklet-eval-expr
                                             (local.get $self)
                                             (local.get $importss)
                                             (local.get $insts)
                                             (struct.get $Pair $a (local.get $pair))))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $loop)))
               (local.get $result))

         ;; linklet-eval-expr-list : instance? list? args? list? -> list?
         ;;   Evaluate each expression in a source-linklet argument list.
         (func $linklet-eval-expr-list
               (param $self     (ref eq)) ;; target instance
               (param $importss (ref eq)) ;; linklet import groups
               (param $insts    (ref $Args)) ;; target instance, then imports
               (param $forms    (ref eq)) ;; expression list
               (result          (ref eq))

               (local $node   (ref eq))
               (local $pair   (ref $Pair))
               (local $acc    (ref eq))

               (local.set $node (local.get $forms))
               (local.set $acc (global.get $null))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                (then (return (call $reverse (local.get $acc)))))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $acc
                                       (call $cons
                                             (call $linklet-eval-expr
                                                   (local.get $self)
                                                   (local.get $importss)
                                                   (local.get $insts)
                                                   (struct.get $Pair $a (local.get $pair)))
                                             (local.get $acc)))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $loop)))
               (call $reverse (local.get $acc)))

         ;; linklet-apply-primitive : instance? list? args? symbol? list? -> any/c
         ;;   Apply the primitive subset used by source-linklet bootstrap forms.
         (func $linklet-apply-primitive
               (param $self     (ref eq)) ;; target instance
               (param $importss (ref eq)) ;; linklet import groups
               (param $insts    (ref $Args)) ;; target instance, then imports
               (param $op       (ref eq)) ;; primitive operator symbol
               (param $raw-args (ref eq)) ;; unevaluated argument expressions
               (result          (ref eq))

               (local $args (ref eq))
               (local $pair (ref $Pair))
               (local $rest (ref eq))

               (local.set $args
                          (call $linklet-eval-expr-list
                                (local.get $self)
                                (local.get $importss)
                                (local.get $insts)
                                (local.get $raw-args)))

               (if (ref.eq (local.get $op) (global.get $symbol:+))
                   (then (return (call $+ (local.get $args)))))
               (if (ref.eq (local.get $op) (global.get $symbol:*))
                   (then (return (call $* (local.get $args)))))
               (if (ref.eq (local.get $op) (global.get $symbol:values))
                   (then (return (call $values (local.get $args)))))
               (if (ref.eq (local.get $op) (global.get $symbol:list))
                   (then (return (local.get $args))))

               (if (ref.test (ref $Pair) (local.get $args))
                   (then
                    (local.set $pair (ref.cast (ref $Pair) (local.get $args)))
                    (local.set $rest (struct.get $Pair $d (local.get $pair)))
                    (if (ref.eq (local.get $op) (global.get $symbol:-))
                        (then
                         (return (call $-
                                       (struct.get $Pair $a (local.get $pair))
                                       (local.get $rest)))))
                    (if (ref.eq (local.get $op) (global.get $symbol:car))
                        (then
                         (return (call $car
                                       (struct.get $Pair $a (local.get $pair))))))
                    (if (ref.eq (local.get $op) (global.get $symbol:cdr))
                        (then
                         (return (call $cdr
                                       (struct.get $Pair $a (local.get $pair))))))
                    (if (ref.eq (local.get $op) (global.get $symbol:cons))
                        (then
                         (if (ref.test (ref $Pair) (local.get $rest))
                             (then
                              (return (call $cons
                                            (struct.get $Pair $a (local.get $pair))
                                            (struct.get $Pair $a
                                                        (ref.cast (ref $Pair)
                                                                  (local.get $rest)))))))))))

               (global.get $void))

         ;; linklet-define-values! : instance? list? any/c -> void
         ;;   Install one or more definition results in the target instance.
         (func $linklet-define-values!
               (param $self (ref eq)) ;; target instance
               (param $ids  (ref eq)) ;; identifier list
               (param $val  (ref eq)) ;; value or packed multiple values
               (result      (ref eq))

               (local $node    (ref eq))
               (local $pair    (ref $Pair))
               (local $id      (ref eq))
               (local $vals    (ref $Values))
               (local $i       i32)
               (local $len     i32)

               (if (ref.test (ref $Values) (local.get $val))
                   (then
                    (local.set $vals (ref.cast (ref $Values) (local.get $val)))
                    (local.set $len (array.len (local.get $vals)))
                    (local.set $node (local.get $ids))
                    (local.set $i (i32.const 0))
                    (block $done
                           (loop $loop
                                 (br_if $done
                                        (ref.eq (local.get $node) (global.get $null)))
                                 (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                     (then (return (global.get $void))))
                                 (if (i32.ge_u (local.get $i) (local.get $len))
                                     (then (return (global.get $void))))
                                 (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                 (local.set $id
                                            (call $linklet-normalize-id
                                                  (struct.get $Pair $a (local.get $pair))))
                                 (drop (call $instance-set-variable-value!
                                             (local.get $self)
                                             (local.get $id)
                                             (array.get $Values
                                                        (local.get $vals)
                                                        (local.get $i))
                                             (global.get $null)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (local.set $node (struct.get $Pair $d (local.get $pair)))
                                 (br $loop)))
                    (return (global.get $void))))

               (if (ref.test (ref $Pair) (local.get $ids))
                   (then
                    (local.set $pair (ref.cast (ref $Pair) (local.get $ids)))
                    (if (ref.eq (struct.get $Pair $d (local.get $pair))
                                (global.get $null))
                        (then
                         (local.set $id
                                    (call $linklet-normalize-id
                                          (struct.get $Pair $a (local.get $pair))))
                         (return (call $instance-set-variable-value!
                                       (local.get $self)
                                       (local.get $id)
                                       (local.get $val)
                                       (global.get $null)))))))
               (global.get $void))

         ;; linklet-eval-expr : instance? list? args? any/c -> any/c
         ;;   Interpret the small source-linklet subset needed for bootstrap modules.
         (func $linklet-eval-expr
               (param $self     (ref eq)) ;; target instance
               (param $importss (ref eq)) ;; linklet import groups
               (param $insts    (ref $Args)) ;; target instance, then imports
               (param $expr     (ref eq)) ;; expression datum
               (result          (ref eq))

               (local $pair    (ref $Pair))
               (local $head    (ref eq))
               (local $rest    (ref eq))
               (local $ids     (ref eq))
               (local $id-pair (ref $Pair))
               (local $id      (ref eq))
               (local $rhs     (ref eq))
               (local $val     (ref eq))
               (local $op      (ref eq))
               (local $args    (ref eq))
               (local $var-inst (ref eq))
               (local $test    (ref eq))

               (if (i32.eqz (ref.test (ref $Pair) (local.get $expr)))
                   (then
                    (local.set $expr (call $linklet-normalize-id (local.get $expr)))
                    (if
                        (ref.test (ref $Symbol) (local.get $expr))
                        (then
                         (local.set $var-inst
                                    (call $linklet-import-instance-for-id
                                          (local.get $importss)
                                          (local.get $insts)
                                          (local.get $expr)))
                         (if (ref.eq (local.get $var-inst) (global.get $false))
                             (then (local.set $var-inst (local.get $self))))
                         (return (call $instance-variable-value
                                       (local.get $var-inst)
                                       (local.get $expr)
                                       (call $cons
                                             (global.get $false)
                                             (global.get $null)))))
                        (else (return (local.get $expr))))))

               (local.set $pair (ref.cast (ref $Pair) (local.get $expr)))
               (local.set $head (struct.get $Pair $a (local.get $pair)))
               (local.set $rest (struct.get $Pair $d (local.get $pair)))

               ;; (quote datum)
               (if (ref.eq (local.get $head) (global.get $symbol:quote))
                   (then
                    (if (ref.test (ref $Pair) (local.get $rest))
                        (then
                         (return (struct.get $Pair $a
                                             (ref.cast (ref $Pair) (local.get $rest))))))))

               ;; (begin body ...)
               (if (ref.eq (local.get $head) (global.get $symbol:begin))
                   (then
                    (return (call $linklet-eval-sequence
                                  (local.get $self)
                                  (local.get $importss)
                                  (local.get $insts)
                                  (local.get $rest)))))

               ;; (if test then else)
               (if (ref.eq (local.get $head) (global.get $symbol:if))
                   (then
                    (if (ref.test (ref $Pair) (local.get $rest))
                        (then
                         (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                         (local.set $test
                                    (call $linklet-eval-expr
                                          (local.get $self)
                                          (local.get $importss)
                                          (local.get $insts)
                                          (struct.get $Pair $a (local.get $pair))))
                         (local.set $rest (struct.get $Pair $d (local.get $pair)))
                         (if (ref.test (ref $Pair) (local.get $rest))
                             (then
                              (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                              (if (ref.eq (local.get $test) (global.get $false))
                                  (then
                                   (local.set $rest (struct.get $Pair $d (local.get $pair)))
                                   (if (ref.test (ref $Pair) (local.get $rest))
                                       (then
                                        (return
                                         (call $linklet-eval-expr
                                               (local.get $self)
                                               (local.get $importss)
                                               (local.get $insts)
                                               (struct.get $Pair $a
                                                           (ref.cast (ref $Pair)
                                                                     (local.get $rest))))))))
                                  (else
                                   (return
                                    (call $linklet-eval-expr
                                          (local.get $self)
                                          (local.get $importss)
                                          (local.get $insts)
                                          (struct.get $Pair $a (local.get $pair))))))))))))

               ;; (void)
               (if (ref.eq (local.get $head) (global.get $symbol:void))
                   (then (return (global.get $void))))

               ;; (#%app + arg ...)
               (local.set $op (global.get $false))
               (local.set $args (global.get $null))
               (if (ref.eq (local.get $head) (global.get $symbol:#%app))
                   (then
                    (if (ref.test (ref $Pair) (local.get $rest))
                        (then
                         (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                         (local.set $op
                                    (call $linklet-normalize-id
                                          (struct.get $Pair $a (local.get $pair))))
                         (local.set $args (struct.get $Pair $d (local.get $pair)))
                         (return
                          (call $linklet-apply-primitive
                                (local.get $self)
                                (local.get $importss)
                                (local.get $insts)
                                (local.get $op)
                                (local.get $args)))))))

               ;; Some runtime-produced source linklets can already have the
               ;; operator in head position after simplification.
               (if (i32.or (i32.or (ref.eq (local.get $head) (global.get $symbol:+))
                                   (ref.eq (local.get $head) (global.get $symbol:-)))
                           (i32.or (ref.eq (local.get $head) (global.get $symbol:*))
                                   (i32.or (ref.eq (local.get $head) (global.get $symbol:car))
                                           (i32.or (ref.eq (local.get $head) (global.get $symbol:cdr))
                                                   (ref.eq (local.get $head) (global.get $symbol:cons))))))
                   (then (return
                          (call $linklet-apply-primitive
                                (local.get $self)
                                (local.get $importss)
                                (local.get $insts)
                                (local.get $head)
                                (local.get $rest)))))

               ;; (set! id rhs)
               (if (ref.eq (local.get $head) (global.get $symbol:set!))
                   (then
                    (if (ref.test (ref $Pair) (local.get $rest))
                        (then
                         (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                         (local.set $id
                                    (call $linklet-normalize-id
                                          (struct.get $Pair $a (local.get $pair))))
                         (local.set $rest (struct.get $Pair $d (local.get $pair)))
                         (if (ref.test (ref $Pair) (local.get $rest))
                             (then
                              (local.set $rhs
                                         (struct.get $Pair $a
                                                     (ref.cast (ref $Pair) (local.get $rest))))
                              (local.set $val
                                         (call $linklet-eval-expr
                                               (local.get $self)
                                               (local.get $importss)
                                               (local.get $insts)
                                               (local.get $rhs)))
                              (local.set $var-inst
                                         (call $linklet-import-instance-for-id
                                               (local.get $importss)
                                               (local.get $insts)
                                               (local.get $id)))
                              (if (ref.eq (local.get $var-inst) (global.get $false))
                                  (then (local.set $var-inst (local.get $self))))
                              (return (call $instance-set-variable-value!
                                            (local.get $var-inst)
                                            (local.get $id)
                                            (local.get $val)
                                            (global.get $null)))))))))

               ;; (define-values (id) rhs)
               (if (ref.eq (local.get $head) (global.get $symbol:define-values))
                   (then
                    (if (ref.test (ref $Pair) (local.get $rest))
                        (then
                         (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                         (local.set $ids (struct.get $Pair $a (local.get $pair)))
                         (local.set $rest (struct.get $Pair $d (local.get $pair)))
                         (if (ref.test (ref $Pair) (local.get $rest))
                             (then
                              (local.set $rhs
                                         (struct.get $Pair $a
                                                     (ref.cast (ref $Pair) (local.get $rest))))
                              (local.set $val
                                         (call $linklet-eval-expr
                                               (local.get $self)
                                               (local.get $importss)
                                               (local.get $insts)
                                               (local.get $rhs)))
                              (return (call $linklet-define-values!
                                            (local.get $self)
                                            (local.get $ids)
                                            (local.get $val)))))))))

               ;; Unsupported applications are left inert for now; the next
               ;; executor milestones should add primitive and import dispatch.
               (global.get $void))

         ;; interpreted-linklet-code : closure args -> any/c
         ;;   Execute the stored source linklet datum against the target instance.
         (func $interpreted-linklet-code (type $ClosureCode)
               (param $clos (ref $Closure)) ;; closure with source datum free var
               (param $args (ref $Args))    ;; self instance, then imports
               (result     (ref eq))

               (local $src   (ref eq))
               (local $self  (ref eq))
               (local $importss (ref eq))
               (local $forms (ref eq))

               (if (i32.eqz (array.len (local.get $args)))
                   (then (return (global.get $void))))
               (local.set $src
                          (array.get $Free
                                     (struct.get $Closure $free (local.get $clos))
                                     (i32.const 0)))
               (local.set $importss
                          (array.get $Free
                                     (struct.get $Closure $free (local.get $clos))
                                     (i32.const 1)))
               (local.set $self (array.get $Args (local.get $args) (i32.const 0)))
               (local.set $forms (call $linklet-datum-body-list (local.get $src)))
               (call $linklet-eval-sequence
                     (local.get $self)
                     (local.get $importss)
                     (local.get $args)
                     (local.get $forms)))

         (global $dummy-closure (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)               ; hash
                             (global.get $false)         ; name:  #f or $String
                             (global.get $zero)          ; arity: todo
                             (global.get $false)         ; realm: #f or $Symbol
                             (ref.func $invoke-closure) ; invoke (used by apply, map, etc.)
                             (global.get $false)         ; debug-id
                             (ref.func $placeholder-linklet-code)
                             (array.new_fixed $Free 0)))
         (global $placeholder-linklet-closure (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)               ; hash
                             (global.get $false)         ; name:  #f or $String
                             (ref.i31 (i32.const -1))    ; arity-at-least 0
                             (global.get $false)         ; realm: #f or $Symbol
                             (ref.func $invoke-closure) ; invoke (used by apply, map, etc.)
                             (global.get $false)         ; debug-id
                             (ref.func $dummy-code)
                             (array.new_fixed $Free 0)))
         (global $interpreted-linklet-retainer (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)
                             (global.get $false)
                             (ref.i31 (i32.const -1))
                             (global.get $false)
                             (ref.func $invoke-closure)
                             (global.get $false)
                             (ref.func $interpreted-linklet-code)
                             (array.new_fixed $Free 2
                                              (global.get $false)
                                              (global.get $null))))
         (global $escape-continuation-closure (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)
                             (global.get $false)
                             (ref.i31 (i32.const -1)) ; arity-at-least 0
                             (global.get $false)
                             (ref.func $invoke-escape-continuation)
                             (global.get $false)
                             (ref.func $dummy-code)
                             (array.new_fixed $Free 0)))
         (global $closedapp-clos (mut (ref $Closure)) (global.get $dummy-closure))


         ;; Predefined exception struct type descriptors (as boxed top-level bindings)
         ;;   struct:exn, struct:exn:fail, etc.
         ,@(for/list ([binding exception-struct-type-bindings])
             (define name  (car binding))
             (define $name (string->symbol (~a "$" (symbol->string name))))
             `(global ,$name (mut (ref eq)) (global.get $undefined)))

         ;; Return value (for a module)
         (global ,result (mut (ref eq)) (global.get $void))

         ;; Variables defined at the top-level
         ,@top-level-variable-declarations

         ;; The symbol table from strings to symbols.
         ;; Used to intern symbols.
         (global $the-symbol-table (mut (ref null $SymbolTable)) (ref.null $SymbolTable))
         ;; The keyword table from strings to keywords.
         ;; Used to intern keywords.
         (global $the-keyword-table (mut (ref null $SymbolTable)) (ref.null $SymbolTable))
         ;; Simple prefab struct types are interned by prefab key.
         (global $prefab-struct-type-registry (mut (ref null $HashEqMutable)) (ref.null $HashEqMutable))
         ;; Placeholder for future Racket CS-style primitive-table installs.
         ;; The current WebRacket bridge implements the one-argument lookup
         ;; path needed by the expander startup path.
         (global $primitive-table-user-installed (mut (ref null $HashEqMutable)) (ref.null $HashEqMutable))
         ;; Symbol -> primitive procedure table for generated unsafe FFI modules.
         (global $unsafe-ffi-primitive-table (mut (ref null $HashEqMutable)) (ref.null $HashEqMutable))

         (func $initialize-the-symbol-table
               (if (ref.is_null (global.get $the-symbol-table))
                   (then (global.set $the-symbol-table (call $make-symbol-table)))))

         (func $initialize-the-keyword-table
               (if (ref.is_null (global.get $the-keyword-table))
                   (then (global.set $the-keyword-table (call $make-symbol-table)))))

         (func $initialize-primitive-table-user-installed
               (if (ref.is_null (global.get $primitive-table-user-installed))
                   (then
                    (global.set $primitive-table-user-installed
                                (ref.cast (ref $HashEqMutable)
                                          (call $make-empty-hasheq))))))

         (func $initialize-unsafe-ffi-primitive-table
               (if (ref.is_null (global.get $unsafe-ffi-primitive-table))
                   (then
                    (global.set $unsafe-ffi-primitive-table
                                (ref.cast (ref $HashEqMutable)
                                          (call $make-empty-hasheq)))
                    ,@(for/list ([f (in-list active-ffi-foreigns)])
                        (define pr (foreign-racket-name f))
                        `(call $hasheq-set!/mutable/checked
                               (ref.cast (ref $HashEqMutable)
                                         (global.get $unsafe-ffi-primitive-table))
                               (global.get ,($ (string->symbol (~a "symbol:" pr))))
                               (global.get ,($ (prim: pr))))))))


         ;;;
         ;;; Arrays
         ;;;

         ;; Arrays are "vectors" of (ref eq) values.
         ;; They are used internally to implement various Racket data structures.

         ;; Define a mutable array type of (ref eq)
         ; (type $Array (array (mut (ref eq))))

         ,(core-runtime-helper-form core-runtime-helper-index '$make-array)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-length #:export? #t #:export-name "array-length")

         ,(core-runtime-helper-form core-runtime-helper-index '$array-ref #:export? #t #:export-name "array-ref")

         ,(core-runtime-helper-form core-runtime-helper-index '$array-set! #:export? #t #:export-name "array-set!")

         ,(core-runtime-helper-form core-runtime-helper-index '$array-fill! #:export? #t #:export-name "array-fill!")

         ,(core-runtime-helper-form core-runtime-helper-index '$array-copy! #:export? #t #:export-name "array-copy!")

         ,(core-runtime-helper-form core-runtime-helper-index '$array-copy!/error #:export? #t #:export-name "array-copy!/error")

         ,(core-runtime-helper-form core-runtime-helper-index '$array-append)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-append-all)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-take)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-take-right)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-drop)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-drop-right)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-split-at)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-copy)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-set/copy)

         ,(core-runtime-helper-form core-runtime-helper-index '$array-extend)

         (func $list->array
               (param $xs   (ref eq))
               (result      (ref $Array))

               (local $len  i32)
               (local $arr  (ref $Array))
               (local $idx  i32)
               (local $x    (ref eq))
               (local $node (ref eq))

               ;; Step 1: compute length of list
               (local.set $len (call $length/i32 (local.get $xs)))
               ;; Step 2: allocate array of given length
               (local.set $arr (call $make-array (local.get $len) (global.get $null)))
               ;; Step 3: initialize traversal variables
               (local.set $node (local.get $xs))
               (local.set $idx  (i32.const 0))
               ;; Step 4: fill array
               (block $done
                      (loop $fill
                            ;; Stop at null
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            ;; Check that it's a pair
                            (if (ref.test (ref $Pair) (local.get $node))
                                (then
                                 (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                                 (call $array-set! (local.get $arr) (local.get $idx) (local.get $x))
                                 (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
                                 (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))
                                 (br $fill))
                                (else
                                 (call $raise-pair-expected (local.get $node))
                                 (unreachable)))))
               ;; Return the filled array
               (local.get $arr))

         ;;;
         ;;; Growable Arrays
         ;;;

         ,(core-runtime-helper-form core-runtime-helper-index '$make-growable-array)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array??)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array?)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-ref)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-ref/default)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-add!)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-insert!)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-set!)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-remove!)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-remove-last!)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array-count)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-array->array)

         ,(core-runtime-helper-form core-runtime-helper-index '$array->growable-array)




         ;;;
         ;;; Growable Arrays of Bytes
         ;;;

         ,(core-runtime-helper-form core-runtime-helper-index '$make-growable-bytes)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-bytes-add!)

         ,(core-runtime-helper-form core-runtime-helper-index '$growable-bytes->bytes)

         ;;;
         ;;; Growable Arrays of I32
         ;;;

         #;(type $I32Array (array (mut i32)))

         #;(type $I32GrowableArray
               (struct
                 (field $arr (mut (ref $I32Array))) ;; underlying array
                 (field $cap (mut i32))             ;; capacity
                 (field $i   (mut i32))))           ;; current size

         ,(core-runtime-helper-form core-runtime-helper-index '$make-i32growable-array)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array-add!)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array-add-string!)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array-ref)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array-count)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array->array)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array->growable-array)


         ;;;
         ;;; I32Array - Arrays of i32
         ;;;

         ; (type $I32Array (array (mut i32)))

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-make)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-length)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-ref)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-set!)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-equal?)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-fill!)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-copy!)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-copy!/error)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-copy)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-append)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-take)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-take-right)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-drop)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-drop-right)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-set/copy)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array-extend)

         (func $list->i32array (param $xs (ref eq)) (result (ref $I32Array))
               (local $len i32)
               (local $arr  (ref $I32Array))
               (local $idx  i32)
               (local $x    (ref eq))
               (local $v    i32)
               (local $node (ref eq))
               ;; Step 1: compute length of list
               (local.set $len (call $length/i32 (local.get $xs)))
               ;; Step 2: allocate array of given length
               (local.set $arr (call $i32array-make (local.get $len) (i32.const 0)))
               ;; Step 3: initialize traversal variables
               (local.set $node (local.get $xs))
               (local.set $idx  (i32.const 0))
               ;; Step 4: fill array
               (block $done
                      (loop $fill
                            ;; Stop at null
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            ;; Check that it's a pair
                            (if (ref.test (ref $Pair) (local.get $node))
                                (then
                                 ;; Get the car
                                 (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                                 ;; Check that car is a fixnum (i31 with LSB 0)
                                 (if (ref.test (ref i31) (local.get $x))
                                     (then
                                      (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                      (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                          (then
                                           ;; Decode fixnum: shift right 1 and store
                                           (call $i32array-set! (local.get $arr)
                                                 (local.get $idx)
                                                 (i32.shr_u (local.get $v) (i32.const 1)))
                                           ;; Advance
                                           (local.set $idx  (i32.add (local.get $idx) (i32.const 1)))
                                           (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))
                                           (br $fill))
                                          (else (call $raise-check-fixnum (local.get $x))
                                                (unreachable))))
                                     (else (call $raise-check-fixnum (local.get $x))
                                           (unreachable))))
                                (else (call $raise-pair-expected (local.get $node))
                                      (unreachable)))))
               ;; Return the filled array
               (local.get $arr))


         ;;;
         ;;; I8Array
         ;;;

         ; (type $I8Array (array (mut i8)))

         (func $raise-bad-byte (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:byte?)
                     (global.get $string:byte?)
                     (local.get $x)))

         ,(core-runtime-helper-form core-runtime-helper-index '$i8make-array)

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-length #:export? #t #:export-name "i8array-length")

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-ref #:export? #t #:export-name "i8array-ref")

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-set! #:export? #t #:export-name "i8array-set!")

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-fill! #:export? #t #:export-name "i8array-fill!")

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-copy! #:export? #t #:export-name "i8array-copy!")

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-copy!/error #:export? #t #:export-name "i8array-copy!/error")

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-copy)

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-set/copy)

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-extend)

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array-append)

         (func $list->i8array (param $xs (ref eq)) (result (ref $I8Array))
               (local $len  i32)
               (local $arr  (ref $I8Array))
               (local $idx  i32)
               (local $x    (ref eq))
               (local $v    i32)
               (local $node (ref eq))
               ;; Step 1: compute list length
               (local.set $len (call $length/i32 (local.get $xs)))
               ;; Step 2: allocate array of that length
               (local.set $arr (array.new $I8Array (i32.const 0) (local.get $len)))
               ;; Step 3: initialize index and node
               (local.set $idx  (i32.const 0))
               (local.set $node (local.get $xs))
               ;; Step 4: fill loop
               (block $done
                      (loop $fill
                            ;; If we hit null, stop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            ;; Must be a pair
                            (if (ref.test (ref $Pair) (local.get $node))
                                (then
                                 ;; Extract the car
                                 (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                                 ;; Check that car is a fixnum
                                 (if (ref.test (ref i31) (local.get $x))
                                     (then
                                      (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                      ;; Check fixnum has LSB = 0
                                      (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                          (then
                                           ;; Shift right to get raw i32
                                           (local.set $v (i32.shr_u (local.get $v) (i32.const 1)))
                                           ;; Check range 0–255
                                           (if (i32.le_u (local.get $v) (i32.const 255))
                                               (then
                                                ;; Store into array
                                                (array.set $I8Array (local.get $arr)
                                                           (local.get $idx)
                                                           (local.get $v))
                                                ;; Advance
                                                (local.set $idx  (i32.add (local.get $idx) (i32.const 1)))
                                                (local.set $node (struct.get $Pair $d
                                                                     (ref.cast (ref $Pair) (local.get $node))))
                                                (br $fill))
                                               (else (call $raise-bad-byte (local.get $x))
                                                     (unreachable))))
                                          (else (call $raise-check-fixnum (local.get $x))
                                                (unreachable))))
                                     (else (call $raise-check-fixnum (local.get $x))
                                           (unreachable))))
                                (else (call $raise-pair-expected (local.get $node))
                                      (unreachable)))))
               ;; Return array
               (local.get $arr))

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array->bytes)

         ,(core-runtime-helper-form core-runtime-helper-index '$i8array->immutable-bytes)

         ;;;
         ;;; Exceptions
         ;;;

         (tag $exn (param (ref eq)))  ; an exception that that carries an value

         ;;   Exception helpers are implemented in runtime-wasm/core/exceptions.rkt.
         ,@(for/list ([name (in-list exception-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; RUNTIME SUPPORT FOR MATCH AND CHECKERS
         ;;;

         ;;   Implemented in runtime-wasm/core/checkers.rkt.
         ,@(for/list ([name (in-list checker-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; DATATYPES
         ;;;

         ;; https://docs.racket-lang.org/reference/data.html

         ;;;
         ;;;  4.1 Equality
         ;;;

         ;;   Implemented in runtime-wasm/core/equality.rkt.
         ,@(for/list ([name (in-list equality-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 4.2 Booleans
         ;;;

         ;; https://docs.racket-lang.org/reference/booleans.html

         ;;   String mutability predicates are implemented in runtime-wasm/core/strings.rkt.
         ,@(for/list ([name (in-list string-mutability-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Bytes mutability predicates are implemented in runtime-wasm/core/bytes.rkt.
         ,@(for/list ([name (in-list bytes-mutability-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Vector mutability predicates are implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-mutability-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Box mutability predicates are implemented in runtime-wasm/core/boxes.rkt.
         ,@(for/list ([name (in-list box-mutability-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Hash predicates are implemented in runtime-wasm/core/hashes.rkt.
         ,@(for/list ([name (in-list hash-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Boolean helpers are implemented in runtime-wasm/core/booleans.rkt.
         ,@(for/list ([name (in-list boolean-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         (func $immutable? (type $Prim1)
               (param $v (ref eq))
               (result (ref eq))

               (local $s    (ref $String))
               (local $bs   (ref $Bytes))
               (local $vec  (ref $Vector))
               (local $hash (ref $Hash))
               (local $box  (ref $Box))

               (if (ref.test (ref $String) (local.get $v))
                   (then
                    (local.set $s (ref.cast (ref $String) (local.get $v)))
                    (if (i32.eq (struct.get $String $immutable (local.get $s)) (i32.const 1))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               (if (ref.test (ref $Bytes) (local.get $v))
                   (then
                    (local.set $bs (ref.cast (ref $Bytes) (local.get $v)))
                    (if (i32.eq (struct.get $Bytes $immutable (local.get $bs)) (i32.const 1))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then
                    (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                    (if (i32.eq (struct.get $Vector $immutable (local.get $vec)) (i32.const 1))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               (if (call $immutable-hash-leaf?/i32 (local.get $v))
                   (then (return (global.get $true))))
               (if (ref.test (ref $Box) (local.get $v))
                   (then
                    (local.set $box (ref.cast (ref $Box) (local.get $v)))
                    (if (i32.eq (struct.get $Box $immutable (local.get $box)) (i32.const 1))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               (global.get $false))

         ;;;
         ;;; 4.3 Numbers
         ;;;

         ;; https://docs.racket-lang.org/reference/numbers.html

         ;;; 4.3.1 Number Types

         ;; https://docs.racket-lang.org/reference/number-types.html

         ;; [x] number?
         ;; [ ] complex?
         ;; [x] real?
         ;; [ ] rational?
         ;; [x] integer?
         ;; [x] exact-integer?
         ;; [x] exact-nonnegative-integer?
         ;; [x] exact-positive-integer?
         ;; [x] positive-integer?
         ;; [x] negative-integer?
         ;; [x] nonpositive-integer?
         ;; [x] nonnegative-integer?
         ;; [x] natural?
         ;; [x] nan?
         ;; [x] infinite?
         ;; [x] inexact-real?
         ;; [x] fixnum?
         ;; [x] flonum?
         ;; [x] double-flonum?
         ;; [x] single-flonum?
         ;; [x] single-flonum-available?
         ;; [x] zero?
         ;; [x] positive?
         ;; [x] negative?
         ;; [x] even?
         ;; [x] odd?
         ;; [x] exact?
         ;; [x] inexact?
         ;; [x] inexact->exact
         ;; [x] exact->inexact
         ;; [ ] real->single-flonum
         ;; [x] real->double-flonum

         ;;   Number-type helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list number-type-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; 4.3.2 Generic Numerics
         ;;     https://docs.racket-lang.org/reference/generic-numbers.html

         ;; 4.3.2.1 Arithmetic
         ;;   https://docs.racket-lang.org/reference/generic-numbers.html#%28part._.Arithmetic%29

         ;;   Generic numeric helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list generic-numeric-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        (func $raise-expected-number
              (param $x (ref eq))
              (call $js-log (local.get $x))
              (unreachable))
        (func $raise-expected-number1
              (param $x (ref eq))
              (call $js-log (local.get $x))
              (unreachable))
        (func $raise-expected-number2
              (param $x (ref eq))
              (call $js-log (local.get $x))
              (unreachable))
        (func $raise-expected-number3
              (param $x (ref eq))
              (call $js-log (local.get $x))
              (call $js-log (call $fixnum? (local.get $x)))
              (call $js-log (call $flonum? (local.get $x)))
              (call $js-log (call $string? (local.get $x)))
              (call $js-log (call $external? (local.get $x)))
              (call $js-log (local.get $x))
              (unreachable))
        (func $raise-expected-number4
              (param $x (ref eq))
              (call $js-log (local.get $x))
              (unreachable))

        (func $raise-expected-real
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              ;; TODO: include argument position and other arguments like Racket.
              (local.set $out (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $who)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:real?))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $x)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-expected-keyword
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              ;; TODO: include argument position and other arguments like Racket.
              (local.set $out (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $who)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:keyword?))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $x)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

         ;;   Arithmetic and comparison helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list generic-arithmetic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Bitwise numeric helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list generic-bitwise-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        ;; Shared fallback state for early pseudo-random generation.
        ;; Normal random calls use $current-pseudo-random-generator-value after
        ;; entry initialization.
        (global $random-state (mut i32) (i32.const 0x9E3779B9))

        ;;   Random generator helpers are implemented in runtime-wasm/core/random.rkt.
        ,@(for/list ([name (in-list random-generator-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;;   Implemented in runtime-wasm/core/parameters.rkt.
        ,(core-runtime-helper-form runtime-helper-index '$current-pseudo-random-generator)

        ;;   Public random helpers are implemented in runtime-wasm/core/random.rkt.
        ,@(for/list ([name (in-list random-public-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ;; System/runtime information helpers are implemented in runtime-wasm/core/system.rkt.
         ,@(for/list ([name (in-list system-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(for/list ([name (in-list compile-parameter-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;;  4.3.4 Fixnums
         ;;;

         ;; https://docs.racket-lang.org/reference/fixnums.html

         ;; Fixnum predicate helpers are implemented in runtime-wasm/core/fixnums.rkt.
         ,@(for/list ([name (in-list fixnum-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form core-runtime-helper-index '$fx?/i32)

         ;; Fixnum arithmetic helpers are implemented in runtime-wasm/core/fixnums.rkt.
         ,@(for/list ([name (in-list fixnum-arithmetic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form core-runtime-helper-index '$fixnum?/i32)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxand/2)

         ,(core-runtime-helper-form runtime-helper-index '$fxand)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxior/2)

         ,(core-runtime-helper-form runtime-helper-index '$fxior)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxxor/2)

         ,(core-runtime-helper-form runtime-helper-index '$fxxor)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxnot)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxlshift)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxrshift)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxpopcount)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxpopcount32)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxpopcount16)

         ,(core-runtime-helper-form core-runtime-helper-index '$fx+/wraparound)

         ,(core-runtime-helper-form runtime-helper-index '$fx-/wraparound)

         ,(core-runtime-helper-form core-runtime-helper-index '$fx*/wraparound)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxlshift/wraparound)

         ,(core-runtime-helper-form core-runtime-helper-index '$fxrshift/logical)

         ;; Fixnum comparison helpers are implemented in runtime-wasm/core/fixnums.rkt.
         ,@(for/list ([name (in-list fixnum-comparison-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        ,@(for/list ([name (in-list fixnum-minmax-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ;; Fixnum conversion helpers are implemented in runtime-wasm/core/fixnums.rkt.
         ,@(for/list ([name (in-list fixnum-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 4.3.3 Floating Point Numbers
         ;;;

         ;; https://docs.racket-lang.org/reference/flonums.html

         ;; Flonum construction helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(for/list ([name (in-list flonum-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form core-runtime-helper-index '$fl?/i32)

         ;; Flonum predicate helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(for/list ([name (in-list flonum-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Flonum conversion helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(for/list ([name (in-list flonum-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Flonum arithmetic helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(for/list ([name (in-list flonum-arithmetic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Flonum math helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(for/list ([name (in-list flonum-math-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        ;; variadic flonum min/max built on binary helpers
        ,@(for/list ([name (in-list flonum-minmax-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ;; Flonum utility helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(for/list ([name (in-list flonum-utility-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))



         ;;;
         ;;; Number / String conversions
         ;;;

         ;; Number/string conversion helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list number-string-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; String/number conversion helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list string-number-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Floating-point byte conversion helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list floating-point-byte-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;; Numeric formatting helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(for/list ([name (in-list numeric-formatting-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Numeric display helpers are implemented in runtime-wasm/core/formatting.rkt.
         ,@(for/list ([name (in-list numeric-display-formatting-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))



        ;;;
        ;;; - External host values
        ;;;

         ;;   Implemented in runtime-wasm/core/ffi.rkt.
         ,@(for/list ([name (in-list external-value-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))





        ;;;
        ;;; 4.3 Byte Strings
        ;;;

        ;; https://docs.racket-lang.org/reference/bytestrings.html

         ;;   Basic byte-string helpers are implemented in runtime-wasm/core/bytes.rkt.
         ,@(for/list ([name (in-list bytes-basic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Byte-string comparison helpers are implemented in runtime-wasm/core/bytes.rkt.
         ,@(for/list ([name (in-list byte-comparison-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))



         ;;   Byte indexing, mutation, and copy helpers are implemented in runtime-wasm/core/bytes.rkt.
         ,@(for/list ([name (in-list byte-indexing-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; bytes-converter? : any/c -> boolean?
         ;;   Recognize WebRacket's minimal byte converters.
         (func $bytes-converter? (type $Prim1)
               ,@(make-predicate-body '$BytesConverter))

         ;; bytes-open-converter : string? string? -> (or/c bytes-converter? #f)
         ;;   Support the guaranteed UTF-8 identity cases used by module
         ;;   startup. WebRacket currently treats locale encoding as UTF-8.
         (func $bytes-open-converter (type $Prim2)
               (param $from (ref eq)) ;; string?
               (param $to   (ref eq)) ;; string?
               (result      (ref eq))
               (if (i32.eqz (ref.test (ref $String) (local.get $from)))
                   (then (call $raise-check-string (local.get $from)) (unreachable)))
               (if (i32.eqz (ref.test (ref $String) (local.get $to)))
                   (then (call $raise-check-string (local.get $to)) (unreachable)))
               (struct.new $BytesConverter (i32.const 0) (i32.const 0)))

         ;; bytes-close-converter : bytes-converter? -> void?
         ;;   Mark the minimal converter closed; it remains a converter? value,
         ;;   matching Racket's predicate behavior after close.
         (func $bytes-close-converter (type $Prim1)
               (param $converter-raw (ref eq)) ;; bytes-converter?
               (result               (ref eq))
               (if (i32.eqz (ref.test (ref $BytesConverter) (local.get $converter-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:bytes-close-converter)
                               (global.get $string:bytes-converter?)
                               (local.get $converter-raw))
                         (unreachable)))
               (struct.set $BytesConverter $closed
                           (ref.cast (ref $BytesConverter) (local.get $converter-raw))
                           (i32.const 1))
               (global.get $void))

         ;; bytes-convert : bytes-converter? bytes? [start end dest dest-start dest-end] -> values
         ;;   Minimal identity conversion for UTF-8/locale-as-UTF-8. The
         ;;   optional destination limit is accepted but this first slice only
         ;;   supports complete copies that fit the destination.
         (func $bytes-convert (type $Prim>=2)
               (param $converter-raw (ref eq)) ;; bytes-converter?
               (param $src-raw       (ref eq)) ;; bytes?
               (param $rest          (ref eq)) ;; optional arguments
               (result               (ref eq))

               (local $src          (ref $Bytes))
               (local $node         (ref eq))
               (local $src-start    (ref eq))
               (local $src-end      (ref eq))
               (local $dest-raw     (ref eq))
               (local $dest-start   (ref eq))
               (local $slice        (ref eq))
               (local $read-count   i32)

               (if (i32.eqz (ref.test (ref $BytesConverter) (local.get $converter-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:bytes-convert)
                               (global.get $string:bytes-converter?)
                               (local.get $converter-raw))
                         (unreachable)))
               (if (i32.eq
                    (struct.get $BytesConverter $closed
                                (ref.cast (ref $BytesConverter) (local.get $converter-raw)))
                    (i32.const 1))
                   (then (call $raise-argument-error1
                               (global.get $symbol:bytes-convert)
                               (global.get $string:bytes-converter?)
                               (local.get $converter-raw))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $Bytes) (local.get $src-raw)))
                   (then (call $raise-check-bytes (local.get $src-raw)) (unreachable)))
               (local.set $src (ref.cast (ref $Bytes) (local.get $src-raw)))
               (local.set $src-start (ref.i31 (i32.const 0)))
               (local.set $src-end
                          (ref.i31
                           (i32.shl
                            (call $i8array-length (struct.get $Bytes $bs (local.get $src)))
                            (i32.const 1))))
               (local.set $dest-raw (global.get $false))
               (local.set $dest-start (ref.i31 (i32.const 0)))
               (local.set $node (local.get $rest))
               (if (ref.test (ref $Pair) (local.get $node))
                   (then
                    (local.set $src-start (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                    (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))))
               (if (ref.test (ref $Pair) (local.get $node))
                   (then
                    (local.set $src-end (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                    (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))))
               (if (ref.test (ref $Pair) (local.get $node))
                   (then
                    (local.set $dest-raw (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                    (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))))
               (if (ref.test (ref $Pair) (local.get $node))
                   (then
                    (local.set $dest-start (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))))
               (local.set $slice
                          (call $subbytes
                                (local.get $src-raw)
                                (local.get $src-start)
                                (local.get $src-end)))
               (local.set $read-count
                          (i32.sub
                           (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $src-end))) (i32.const 1))
                           (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $src-start))) (i32.const 1))))
               (if (ref.eq (local.get $dest-raw) (global.get $false))
                   (then
                    (return
                     (array.new_fixed $Values
                                      3
                                      (local.get $slice)
                                      (ref.i31 (i32.shl (local.get $read-count) (i32.const 1)))
                                      (global.get $symbol:complete)))))
               (if (i32.eqz (ref.test (ref $Bytes) (local.get $dest-raw)))
                   (then (call $raise-check-bytes (local.get $dest-raw)) (unreachable)))
               (drop (call $bytes-copy!
                           (local.get $dest-raw)
                           (local.get $dest-start)
                           (local.get $slice)
                           (global.get $missing)
                           (global.get $missing)))
               (array.new_fixed $Values
                                3
                                (ref.i31 (i32.shl (local.get $read-count) (i32.const 1)))
                                (ref.i31 (i32.shl (local.get $read-count) (i32.const 1)))
                                (global.get $symbol:complete)))

         ;; bytes-convert-end : bytes-converter? [dest dest-start dest-end] -> values
         ;;   Identity converters have no shift sequence, so conversion ends
         ;;   with empty output and 'complete.
         (func $bytes-convert-end (type $Prim14)
               (param $converter-raw (ref eq)) ;; bytes-converter?
               (param $dest-raw      (ref eq)) ;; optional (or/c bytes? #f)
               (param $dest-start    (ref eq)) ;; optional exact-nonnegative-integer?
               (param $dest-end      (ref eq)) ;; optional bound, ignored
               (result               (ref eq))
               (if (i32.eqz (ref.test (ref $BytesConverter) (local.get $converter-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:bytes-convert-end)
                               (global.get $string:bytes-converter?)
                               (local.get $converter-raw))
                         (unreachable)))
               (if (ref.eq (local.get $dest-raw) (global.get $missing))
                   (then (local.set $dest-raw (global.get $false))))
               (if (ref.eq (local.get $dest-raw) (global.get $false))
                   (then
                    (return
                     (array.new_fixed $Values
                                      2
                                      (struct.new $Bytes
                                                  (i32.const 0)
                                                  (i32.const 0)
                                                  (array.new_fixed $I8Array 0))
                                      (global.get $symbol:complete)))))
               (if (i32.eqz (ref.test (ref $Bytes) (local.get $dest-raw)))
                   (then (call $raise-check-bytes (local.get $dest-raw)) (unreachable)))
               (array.new_fixed $Values
                                2
                                (ref.i31 (i32.const 0))
                                (global.get $symbol:complete)))

         ;;   Byte fill, append, join, and list conversion helpers are implemented in runtime-wasm/core/bytes.rkt.
         ,@(for/list ([name (in-list byte-sequence-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         (func $raise-bytes-utf-8-length:bad-argument      (unreachable))
         (func $raise-bytes-utf-8-length:invalid-err-char  (unreachable))
         (func $raise-bytes-utf-8-length:range-error       (unreachable))

         (func $bytes-utf-8-length (type $Prim14)
               (param $bstr         (ref eq)) ; bytes?
               (param $err-char     (ref eq)) ; optional char?, defaults to #f
               (param $start-raw    (ref eq)) ; optional exact-nonnegative-integer?, defaults to 0
               (param $end-raw      (ref eq)) ; optional exact-nonnegative-integer?, defaults to (bytes-length bstr)
               (result              (ref eq))

               (local $bs           (ref null $Bytes))
               (local $arr          (ref $I8Array))
               (local $len          i32)
               (local $start        i32)
               (local $end          i32)
               (local $use-err-char i32)
               (local $i            i32)
               (local $byte         i32)
               (local $need         i32)
               (local $acc          i32)
               (local $b2           i32)
               (local $count        i32)

               ;; --- Type check for bytes argument ---
               (if (ref.test (ref $Bytes) (local.get $bstr))
                   (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
                   (else (call $raise-bytes-utf-8-length:bad-argument)))
               (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
               (local.set $len (array.len (local.get $arr)))

               ;; --- Decode optional start ---
               (if (ref.eq (local.get $start-raw) (global.get $missing))
                   (then (local.set $start (i32.const 0)))
                   (else (if (ref.test (ref i31) (local.get $start-raw))
                             (then (local.set $start
                                              (i32.shr_u
                                               (i31.get_u (ref.cast (ref i31) (local.get $start-raw)))
                                               (i32.const 1))))
                             (else (call $raise-bytes-utf-8-length:bad-argument)))))

               ;; --- Decode optional end ---
               (if (ref.eq (local.get $end-raw) (global.get $missing))
                   (then (local.set $end (local.get $len)))
                   (else (if (ref.test (ref i31) (local.get $end-raw))
                             (then (local.set $end
                                              (i32.shr_u
                                               (i31.get_u (ref.cast (ref i31) (local.get $end-raw)))
                                               (i32.const 1))))
                             (else (call $raise-bytes-utf-8-length:bad-argument)))))

               ;; --- Decode optional err-char ---
               (if (ref.eq (local.get $err-char) (global.get $missing))
                   (then (local.set $use-err-char (i32.const 0)))
                   (else (if (ref.eq (local.get $err-char) (global.get $false))
                             (then (local.set $use-err-char (i32.const 0)))
                             (else (if (ref.test (ref i31) (local.get $err-char))
                                       (then (local.set $use-err-char (i32.const 1)))
                                       (else (call $raise-bytes-utf-8-length:invalid-err-char)))))))

               ;; --- Range checks ---
               (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                           (i32.gt_u (local.get $end) (local.get $len)))
                   (then (call $raise-bytes-utf-8-length:range-error)))

               ;; --- Main decoding loop ---
               (local.set $i     (local.get $start))
               (local.set $count (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $end)))
                            (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $i)))
                            ;; ASCII fast path
                            (if (i32.lt_u (local.get $byte) (i32.const 128))
                                (then
                                 (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))

                            (call $bytes->string/utf-8:determine-utf-8-sequence (local.get $byte))
                            (local.set $acc) (local.set $need)

                            ;; Invalid lead byte
                            (if (i32.lt_s (local.get $need) (i32.const 0))
                                (then
                                 (if (i32.eqz (local.get $use-err-char))
                                     (then (return (global.get $false)))
                                     (else
                                      (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                      (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))))

                            ;; Not enough bytes left in substring
                            (if (i32.gt_u (i32.add (local.get $i) (local.get $need)) (local.get $end))
                                (then
                                 (if (i32.eqz (local.get $use-err-char))
                                     (then (return (global.get $false)))
                                     (else
                                      (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                      (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))))

                            ;; Consume continuation bytes
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (block $cont-fail
                                   (loop $cont-loop
                                         (br_if $cont-fail (i32.eqz (local.get $need)))
                                         (local.set $b2 (array.get_u $I8Array (local.get $arr) (local.get $i)))
                                         (if (i32.and (i32.ge_u (local.get $b2) (i32.const 128))
                                                      (i32.lt_u (local.get $b2) (i32.const 192)))
                                             (then
                                              (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                              (local.set $need (i32.sub (local.get $need) (i32.const 1)))
                                              (br $cont-loop)))))

                            ;; Invalid continuation sequence
                            (if (i32.ne (local.get $need) (i32.const 0))
                                (then
                                 (if (i32.eqz (local.get $use-err-char))
                                     (then (return (global.get $false)))
                                     (else
                                      (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                      (br $loop)))))

                            ;; Successful multi-byte sequence
                            (local.set $count (i32.add (local.get $count) (i32.const 1)))
                            (br $loop)))

               (ref.i31 (i32.shl (local.get $count) (i32.const 1))))

         (func $raise-bytes->string/latin-1                  (unreachable))
         (func $raise-bytes->string/latin-1:invalid-err-char (unreachable))

         (func $bytes->string/latin-1 (type $Prim14)
               (param $bstr      (ref eq)) ; bytes?
               (param $err-char  (ref eq)) ; optional char?, defaults to #f
               (param $start-raw (ref eq)) ; optional exact-nonnegative-integer?, defaults to 0
               (param $end-raw   (ref eq)) ; optional exact-nonnegative-integer?, defaults to (bytes-length bstr)
               (result           (ref eq))

               (local $bs          (ref null $Bytes))
               (local $arr         (ref $I8Array))
               (local $len         i32)
               (local $start       i32)
               (local $end         i32)
               (local $count       i32)
               (local $codepoints  (ref $I32Array))
               (local $i           i32)
               (local $idx         i32)
               (local $byte        i32)

               ;; --- Validate byte string argument ---
               (if (ref.test (ref $Bytes) (local.get $bstr))
                   (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
                   (else (call $raise-bytes->string/latin-1)))
               (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
               (local.set $len (array.len (local.get $arr)))

               ;; --- Decode optional start ---
               (if (ref.eq (local.get $start-raw) (global.get $missing))
                   (then (local.set $start (i32.const 0)))
                   (else (if (ref.test (ref i31) (local.get $start-raw))
                             (then (local.set $start
                                              (i32.shr_u
                                               (i31.get_u (ref.cast (ref i31) (local.get $start-raw)))
                                               (i32.const 1))))
                             (else (call $raise-bytes->string/latin-1)))))

               ;; --- Decode optional end ---
               (if (ref.eq (local.get $end-raw) (global.get $missing))
                   (then (local.set $end (local.get $len)))
                   (else (if (ref.test (ref i31) (local.get $end-raw))
                             (then (local.set $end
                                              (i32.shr_u
                                               (i31.get_u (ref.cast (ref i31) (local.get $end-raw)))
                                               (i32.const 1))))
                             (else (call $raise-bytes->string/latin-1)))))

               ;; --- Validate optional err-char (ignored value) ---
               (if (ref.eq (local.get $err-char) (global.get $missing))
                   (then (nop))
                   (else (if (ref.eq (local.get $err-char) (global.get $false))
                             (then (nop))
                             (else (if (ref.test (ref i31) (local.get $err-char))
                                       (then (nop))
                                       (else (call $raise-bytes->string/latin-1:invalid-err-char)))))))

               ;; --- Range checks ---
               (if (i32.gt_u (local.get $start) (local.get $end))
                   (then (call $raise-bad-bytes-range (local.get $bstr) (local.get $start) (local.get $end))
                         (unreachable)))
               (if (i32.gt_u (local.get $end) (local.get $len))
                   (then (call $raise-bad-bytes-range (local.get $bstr) (local.get $start) (local.get $end))
                         (unreachable)))

               ;; --- Allocate codepoint array and copy bytes ---
               (local.set $count (i32.sub (local.get $end) (local.get $start)))
               (local.set $codepoints (call $i32array-make (local.get $count) (i32.const 0)))
               (local.set $i    (i32.const 0))
               (local.set $idx  (local.get $start))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                            (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $idx)))
                            (array.set $I32Array (local.get $codepoints) (local.get $i) (local.get $byte))
                            (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                            (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
                            (br $loop)))

               (call $i32array->immutable-string (local.get $codepoints)))


         (func $raise-bytes->string/utf-8                  (unreachable))
         (func $raise-bytes->string/utf-8:invalid-err-char (unreachable))

         (func $bytes->string/utf-8 (type $Prim14)
               (param $bstr         (ref eq))
               (param $err-char     (ref eq)) ; optional character?, defaults to #f
               (param $start-raw    (ref eq)) ; optional exact-nonnegative-integer?, defaults to 0
               (param $end-raw      (ref eq)) ; optional exact-nonnegative-integer?, defaults to (bytes-length bstr)
               (result              (ref eq))

               (local $bs               (ref null $Bytes))
               (local $start            i32)
               (local $end              i32)
               (local $use-err-char     i32)
               (local $decoded-err-char i32)

               ;; Cast input to $Bytes
               (if (ref.test (ref $Bytes) (local.get $bstr))
                   (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
                   (else (call $raise-bytes->string/utf-8)))
               ;; Decode start
               (if (ref.eq (local.get $start-raw) (global.get $missing))
                   (then (local.set $start (i32.const 0)))
                   (else
                    (if (ref.test (ref i31) (local.get $start-raw))
                        (then (local.set $start (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $start-raw))) (i32.const 1))))
                        (else (call $raise-bytes->string/utf-8)))))
               ;; Decode end
               (if (ref.eq (local.get $end-raw) (global.get $missing))
                   (then (local.set $end (array.len (struct.get $Bytes $bs (local.get $bs)))))
                   (else
                    (if (ref.test (ref i31) (local.get $end-raw))
                        (then (local.set $end
                                         (i32.shr_u
                                          (i31.get_u (ref.cast (ref i31) (local.get $end-raw)))
                                          (i32.const 1))))
                        (else (call $raise-bytes->string/utf-8)))))
               ;; Decode err-char
               (if (ref.eq (local.get $err-char) (global.get $missing))
                   ; missing
                   (then (local.set $use-err-char     (i32.const 0))
                         (local.set $decoded-err-char (i32.const 0)))
                   (else
                    ; false
                    (if (ref.eq (local.get $err-char) (global.get $false))
                        (then (local.set $use-err-char     (i32.const 0))
                              (local.set $decoded-err-char (i32.const 0)))
                        (else
                         ; character
                         (if (ref.test (ref i31) (local.get $err-char))
                             (then (local.set $use-err-char (i32.const 1))
                                   (local.set $decoded-err-char
                                              (i32.shr_u
                                               (i31.get_u (ref.cast (ref i31) (local.get $err-char)))
                                               (i32.const 1))))
                             (else (call $raise-bytes->string/utf-8:invalid-err-char)))))))
               ;; Delegate to implementation
               (call $bytes->string/utf-8:work
                     (ref.as_non_null (local.get $bs))
                     (local.get $use-err-char)
                     (local.get $decoded-err-char)
                     (local.get $start)
                     (local.get $end)))

         (func $bytes->string/utf-8/defaults
               (param $bs (ref $Bytes))
               (result (ref $String))
               (ref.cast (ref $String)
                         (call $bytes->string/utf-8
                               (local.get $bs)
                               (global.get $missing)    ;; err-char = #f
                               (global.get $missing)    ;; start    = 0
                               (global.get $missing)))) ;; end      = full length

         (func $bytes->string/utf-8/checked
               (param $bs (ref $Bytes))
               (result (ref $String))
               (local $end i32)
               (local.set $end (array.len (struct.get $Bytes $bs (local.get $bs))))
               (call $bytes->string/utf-8:work
                     (local.get $bs)
                     (i32.const 0)   ;; use-err-char? = false
                     (i32.const 0)   ;; err-char = dummy
                     (i32.const 0)   ;; start
                     (local.get $end)))

         (func $bytes->string/utf-8:work
               (param $bs           (ref $Bytes))
               (param $use-err-char i32)
               (param $err-char     i32)
               (param $start        i32)
               (param $end          i32)
               (result              (ref $String))

               (local $buf  (ref $I32GrowableArray))
               (local $arr  (ref $I8Array))
               (local $i    i32)
               (local $byte i32)
               (local $need i32)
               (local $acc  i32)
               (local $b2   i32)
               (local $cp   i32)

               ;; Get underlying I8Array from Bytes
               (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
               ;; Allocate buffer for codepoints
               (local.set $buf (call $make-i32growable-array (i32.const 16)))
               ;; Start decoding loop
               (local.set $i (local.get $start))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $end)))
                            (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $i)))
                            ;; ASCII fast path
                            (if (i32.lt_u (local.get $byte) (i32.const 128))
                                (then
                                 (call $i32growable-array-add! (local.get $buf) (local.get $byte))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            ;; Determine UTF-8 sequence size and initial accumulator
                            (call $bytes->string/utf-8:determine-utf-8-sequence (local.get $byte))
                            (local.set $acc) (local.set $need)
                            ;; Invalid lead byte
                            (if (i32.lt_s (local.get $need) (i32.const 0))
                                (then
                                 (if (i32.eqz (local.get $use-err-char))
                                     (then (call $raise-bytes->string/utf-8))
                                     (else
                                      (call $i32growable-array-add! (local.get $buf) (local.get $err-char))
                                      (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))))
                            ;; Not enough bytes left
                            (if (i32.gt_u (i32.add (local.get $i) (local.get $need)) (local.get $end))
                                (then
                                 (if (i32.eqz (local.get $use-err-char))
                                     (then (call $raise-bytes->string/utf-8))
                                     (else
                                      (call $i32growable-array-add! (local.get $buf) (local.get $err-char))
                                      (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))))
                            ;; Decode continuation bytes
                            (local.set $cp (local.get $acc))
                            (local.set $i (i32.add (local.get $i) (i32.const 1))) ;; skip lead byte
                            (block $cont-fail
                                   (loop $cont-loop
                                         (br_if $cont-fail (i32.eqz (local.get $need)))
                                         (local.set $b2 (array.get_u $I8Array (local.get $arr) (local.get $i)))
                                         (if (i32.and
                                              (i32.ge_u (local.get $b2) (i32.const 128))
                                              (i32.lt_u (local.get $b2) (i32.const 192)))
                                             (then
                                              (local.set $cp
                                                         (i32.or
                                                          (i32.shl (local.get $cp) (i32.const 6))
                                                          (i32.and (local.get $b2) (i32.const 0x3F))))
                                              (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                              (local.set $need (i32.sub (local.get $need) (i32.const 1)))
                                              (br $cont-loop)))))
                            ;; If we didn't finish the sequence, it's invalid
                            (if (i32.ne (local.get $need) (i32.const 0))
                                (then
                                 (if (i32.eqz (local.get $use-err-char))
                                     (then (call $raise-bytes->string/utf-8))
                                     (else
                                      (call $i32growable-array-add! (local.get $buf) (local.get $err-char))
                                      (br $loop)))))
                            ;; Valid sequence
                            (call $i32growable-array-add! (local.get $buf) (local.get $cp))
                            (br $loop)))
               ;; Convert buffer to immutable string
               (call $i32growable-array->immutable-string (local.get $buf)))


         (func $bytes->string/utf-8:determine-utf-8-sequence ; returns two i32s
               ; This function determines how many continuation bytes are needed for
               ; a given UTF-8 lead byte, and extracts the initial bits for the code point accumulator.
               (param $lead i32)
               (result i32  i32) ;; (need acc) or (-1 -1) if invalid

               (if (i32.and (i32.ge_u (local.get $lead) (i32.const 0xC0))
                            (i32.lt_u (local.get $lead) (i32.const 0xE0)))
                   (then (return (i32.const 1) (i32.and (local.get $lead) (i32.const 0x1F)))))

               (if (i32.and (i32.ge_u (local.get $lead) (i32.const 0xE0))
                            (i32.lt_u (local.get $lead) (i32.const 0xF0)))
                   (then (return (i32.const 2) (i32.and (local.get $lead) (i32.const 0x0F)))))

               (if (i32.and (i32.ge_u (local.get $lead) (i32.const 0xF0))
                            (i32.lt_u (local.get $lead) (i32.const 0xF8)))
                   (then (return (i32.const 3) (i32.and (local.get $lead) (i32.const 0x07)))))

               ;; Not a valid lead byte
               (return (i32.const -1) (i32.const -1)))


        ;;;
        ;;; 4.4 Strings
        ;;;

        ;; https://docs.racket-lang.org/reference/strings.html

         (func $raise-check-string         (param $x (ref eq))                      (unreachable))
         (func $raise-bad-string-index     (param $x (ref eq)) (param $i (ref eq))  (unreachable))
         (func $raise-bad-string-index/i32 (param $x (ref eq)) (param $i i32)       (unreachable))
         (func $raise-string-length:bad-argument (unreachable))

         (func $raise-string-index-out-of-bounds/i32 (param $x (ref eq)) (param $i i32) (param $n i32)
               (unreachable))

         ; for single character strings
         (func $codepoint->string
               (param  $ch i32)                    ;; Unicode scalar value
               (result     (ref $String))

               (local $cp  (ref $I32Array))
               ;; Validate that ch is a Unicode scalar (i.e. not in surrogate range)
               (if (i32.or (i32.lt_u (local.get $ch) (i32.const 0))
                           (i32.gt_u (local.get $ch) (i32.const 0x10FFFF)))
                   (then (call $raise-argument-error:char-expected (ref.i31 (local.get $ch)))
                         (unreachable)))
               (if (i32.and (i32.ge_u (local.get $ch) (i32.const 0xD800))
                            (i32.le_u (local.get $ch) (i32.const 0xDFFF)))
                   (then (call $raise-argument-error:char-expected (ref.i31 (local.get $ch)))
                         (unreachable)))
               ;; Allocate I32Array of length 1
               (local.set $cp (array.new_fixed $I32Array 1 (local.get $ch)))
               ;; Create string with immutable = 1, hash = 0
               (struct.new $String
                           (i32.const 0)       ;; hash (lazy)
                           (i32.const 1)       ;; immutable
                           (local.get $cp)))

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array->string)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32array->immutable-string)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array->string)

         ,(core-runtime-helper-form core-runtime-helper-index '$i32growable-array->immutable-string)

         (func $make-dummy-string (result (ref $String))
               (struct.new $String
                           (i32.const 0)  ;; hash = 0
                           (i32.const 0)  ;; mutable
                           (call $i32array-make (i32.const 0) (i32.const 0))))


         ;; 4.4.1 String Constructors, Selectors, and Mutators

         (func $string? (type $Prim1) (param $s (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $String) (local.get $s))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $non-empty-string? (type $Prim1)
               (param $s (ref eq))
               (result   (ref eq))

               (local $str (ref $String))
               (local $len i32)
               (if (result (ref eq))
                   (ref.test (ref $String) (local.get $s))
                   (then (local.set $str (ref.cast (ref $String) (local.get $s)))
                         (local.set $len (call $i32array-length
                                                  (struct.get $String $codepoints (local.get $str))))
                         (if (result (ref eq))
                             (i32.eqz (local.get $len))
                             (then (global.get $false))
                             (else (global.get $true))))
                   (else (global.get $false))))

         ;; Constructors

         (func $string (type $Prim>=0)
               (param $args (ref eq))
               (result      (ref eq))

               (local $argv      (ref $Args))
               (local $len       i32)
               (local $arr       (ref $I32Array))
               (local $i         i32)
               (local $ch        (ref eq))
               (local $use-args? i32)
               (local $list      (ref eq))
               (local $node      (ref eq))
               (local $pair      (ref $Pair))

               ;; Initialize non-defaultable locals
               (local.set $argv (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $ch   (global.get $false))

               ;; Support both $Args arrays and ordinary rest argument lists.
               (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
               (local.set $list      (global.get $null))
               (local.set $node      (global.get $null))
               (local.set $len       (if (result i32) (local.get $use-args?)
                                         (then
                                          (local.set $argv (ref.cast (ref $Args) (local.get $args)))
                                          (array.len (local.get $argv)))
                                         (else
                                          (local.set $list (local.get $args))
                                          (local.set $node (local.get $list))
                                          (call $length/i32 (local.get $list)))))

               ;; Allocate array for codepoints
               (local.set $arr (array.new $I32Array (i32.const 0) (local.get $len)))

               ;; Fill array with characters from either representation
               (local.set $i (i32.const 0))
               (if (i32.eqz (local.get $use-args?))
                   (then
                    (local.set $node (local.get $list))
                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (ref.test (ref $Pair) (local.get $node))
                                     (then
                                      (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                      (local.set $ch   (struct.get $Pair $a (local.get $pair)))
                                      (local.set $node (struct.get $Pair $d (local.get $pair))))
                                     (else
                                      (call $raise-pair-expected (local.get $node))
                                      (unreachable)))
                                 (array.set $I32Array
                                            (local.get $arr)
                                            (local.get $i)
                                            (call $char->integer/i32 (local.get $ch)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop))))
                   (else
                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $ch (array.get $Args (local.get $argv) (local.get $i)))
                                 (array.set $I32Array
                                            (local.get $arr)
                                            (local.get $i)
                                            (call $char->integer/i32 (local.get $ch)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))))
               ;; Construct mutable string
               (struct.new $String
                           (i32.const 0)  ;; hash
                           (i32.const 0)  ;; mutable
                           (local.get $arr)))


         (func $raise-make-string:bad-length       (unreachable))
         (func $raise-make-string:bad-char         (unreachable))
         (func $raise-argument-error:char-expected (unreachable))

         (func $make-string (type $Prim12)
               (param $n-raw  (ref eq))    ;; fixnum
               (param $ch-raw (ref eq))    ;; optional immediate character
               (result        (ref eq))

               (local $n          i32)
               (local $ch-tagged  i32)
               (local $ch         i32)
               ;; --- Type check for length ---
               (if (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                   (then (call $raise-make-string:bad-length)))
               ;; --- Decode length ---
               (local.set $n (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $n-raw))) (i32.const 1)))
               ;; --- Handle optional character ---
               (if (ref.eq (local.get $ch-raw) (global.get $missing))
                   (then (local.set $ch (i32.const 0)))
                   (else
                    ;; --- Validate character ---
                    (if (i32.eqz (ref.test (ref i31) (local.get $ch-raw)))
                        (then (call $raise-make-string:bad-char)))
                    (local.set $ch-tagged (i31.get_u (ref.cast (ref i31) (local.get $ch-raw))))
                    (if (i32.ne (i32.and (local.get $ch-tagged) (i32.const ,char-mask)) (i32.const ,char-tag))
                        (then (call $raise-make-string:bad-char)))
                    ;; --- Extract code point from character ---
                    (local.set $ch (i32.shr_u (local.get $ch-tagged) (i32.const ,char-shift)))))
               ;; --- Delegate ---
               (call $make-string/checked (local.get $n) (local.get $ch)))

         (func $make-string/checked
               (param $n  i32)      ;; number of characters
               (param $ch i32)      ;; codepoint to fill
               (result    (ref $String))

               (local $arr (ref $I32Array))
               ;; Create backing array and fill with `ch`
               (local.set $arr (array.new $I32Array (local.get $ch) (local.get $n)))
               ;; Construct mutable string
               (call $debug-allocation-tick (i32.const 6))
               (struct.new $String
                           (i32.const 0)     ;; hash = 0
                           (i32.const 0)     ;; mutable
                           (local.get $arr)))

         (func $make-immutable-string/checked
               (param $n  i32)      ;; number of characters
               (param $ch i32)      ;; codepoint to fill
               (result    (ref $String))

               (local $arr (ref $I32Array))
               ;; Create backing array and fill with `ch`
               (local.set $arr (array.new $I32Array (local.get $ch) (local.get $n)))
               ;; Construct mutable string
               (struct.new $String
                           (i32.const 0)     ;; hash = 0
                           (i32.const 1)     ;; immutable
                           (local.get $arr)))

         (func $string->immutable-string (type $Prim1)
               (param $s (ref eq))
               (result   (ref eq))

               (local $str (ref $String))

               (local.set $str (call $make-dummy-string))
               ;; 1. Check that s is a String
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; 2. If already immutable, return it directly
               (if (result (ref eq))
                   (i32.eq (struct.get $String $immutable (local.get $str)) (i32.const 1))
                   (then (local.get $str))
                   (else
                    ;; Otherwise, create a new immutable copy
                    (struct.new $String
                                ; Note: now the mutable and immutable string gets the same hash code.
                                ;       Okay?
                                (struct.get $String $hash (local.get $str))  ;; inherit hash
                                (i32.const 1)                                ;; immutable
                                (call $i32array-copy
                                      (struct.get $String $codepoints (local.get $str))
                                      (i32.const 0)
                                      (call $i32array-length (struct.get $String $codepoints (local.get $str))))))))

         (func $raise-build-string:bad-length    (unreachable))
         (func $raise-build-string:char-expected
               (param $v (ref eq)) (call $js-log (local.get $v)) (unreachable))

         (func $build-string (type $Prim2)
               (param $n-raw (ref eq))
               (param $proc  (ref eq))
               (result       (ref eq))

               (local $n    i32)
               (local $f    (ref $Procedure))
               (local $finv (ref $ProcedureInvoker))
               (local $args (ref $Args))
               (local $arr  (ref $I32Array))
               (local $i    i32)
               (local $res  (ref eq))
               (local $cp   i32)
               (local $str  (ref $String))

               ;; --- Check arguments ---
               (if (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                   (then (call $raise-build-string:bad-length)))
	               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
	                   (then (call $raise-argument-error:procedure-expected/who
	                               (global.get $symbol:build-string)
	                               (local.get $proc))
	                         (unreachable)))

               ;; --- Decode and prepare ---
               (local.set $n    (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $n-raw)))
                                           (i32.const 1)))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

               (local.set $arr  (call $i32array-make (local.get $n) (i32.const 0)))
               (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

               ;; --- Loop ---
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                            ;; Set argument to current index as fixnum
                            (array.set $Args (local.get $args) (i32.const 0)
                                       (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                            ;; Call procedure
                            (local.set $res
                                       (call_ref $ProcedureInvoker
                                                 (local.get $f)
                                                 (local.get $args)
                                                 (local.get $finv)))
                            ;; Validate character result
                            (if (i32.eqz (ref.test (ref i31) (local.get $res)))
                                (then (call $raise-build-string:char-expected (local.get $res))
                                      (unreachable)))
                            (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $res))))
                            (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask))
                                        (i32.const ,char-tag))
                                (then (call $raise-build-string:char-expected (local.get $res))
                                      (unreachable)))
                            (local.set $cp (i32.shr_u (local.get $cp) (i32.const ,char-shift)))
                            (call $i32array-set! (local.get $arr) (local.get $i) (local.get $cp))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               ;; --- Construct string ---
               (local.set $str
                          (struct.new $String
                                      (i32.const 0)
                                      (i32.const 0)
                                      (local.get $arr)))
               (local.get $str))


         (func $string-length (type $Prim1)
               (param $s-raw (ref eq))
               (result (ref eq))

               (local $s   (ref $String))
               (local $len i32)
               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (call $raise-string-length:bad-argument)))
               ;; --- Decode ---
               (local.set $s (ref.cast (ref $String) (local.get $s-raw)))
               ;; --- Compute ---
               (local.set $len (call $i32array-length
                                     (struct.get $String $codepoints (local.get $s))))
               ;; --- Return fixnum ---
               (ref.i31 (i32.shl (local.get $len) (i32.const 1))))


         (func $string-length/checked/i32
               (param $s (ref $String))
               (result i32)
               ;; Fetch the length of the codepoints array
               (call $i32array-length (struct.get $String $codepoints (local.get $s))))


         (func $string-ref (type $Prim2)
               (param $s (ref eq))
               (param $i (ref eq))
               (result (ref eq))

               (local $str     (ref $String))
               (local $idx-i31 (ref i31))
               (local $idx     i32)

               ;; --- All tests ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))

               (if (i32.eqz (ref.test (ref i31) (local.get $i)))
                   (then (call $raise-check-fixnum (local.get $i))))

               (local.set $idx-i31 (ref.cast (ref i31) (local.get $i)))
               (local.set $idx (i31.get_u (local.get $idx-i31)))
               (if (i32.ne (i32.and (local.get $idx) (i32.const 1)) (i32.const 0))
                   (then (call $raise-check-fixnum (local.get $i))))

               ;; --- All decoding ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1)))

               ;; --- Bounds check and delegate ---
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx)
                             (call $string-length/checked/i32 (local.get $str)))
                   (then (call $string-ref/checked (local.get $str) (local.get $idx)))
                   (else (call $raise-bad-string-index/i32 (local.get $s) (local.get $idx))
                         (unreachable))))

         (func $string-ref/checked   ; unsafe: no bounds check
               (param $str (ref $String))
               (param $idx i32)
               (result     (ref eq))

               (local $arr (ref $I32Array))
               (local $cp  i32)

               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $cp  (call $i32array-ref (local.get $arr) (local.get $idx)))
               ;; Return (char): (cp << char-shift) | char-tag
               (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const ,char-shift))
                                (i32.const ,char-tag))))

         (func $string-ref/checked/i32   ; unsafe: no bounds check
               (param $str (ref $String))
               (param $idx i32)
               (result     i32)

               (local $arr (ref $I32Array))
               (local $cp  i32)

               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $cp  (call $i32array-ref (local.get $arr) (local.get $idx)))
               (local.get $cp))


         (func $raise-string-set!:string-expected  (param $x (ref eq)) (unreachable))
         (func $raise-string-set!:fixnum-expected  (param $x (ref eq)) (unreachable))
         (func $raise-string-set!:char-expected    (param $x (ref eq)) (unreachable))
         (func $raise-string-set!:string-immutable (param $x (ref eq)) (unreachable))

         (func $string-set!
               (param $s   (ref eq))
               (param $i   (ref eq))
               (param $ch  (ref eq))
               (result     (ref eq))

               (local $str     (ref $String))
               (local $arr     (ref $I32Array))
               (local $idx     i32)
               (local $cp      i32)
               (local $tagged  i32)
               ;; --- Type checks ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-set!:string-expected (local.get $s))))
               (if (i32.eqz (ref.test (ref i31) (local.get $i)))
                   (then (call $raise-string-set!:fixnum-expected (local.get $i))))
               (if (i32.eqz (ref.test (ref i31) (local.get $ch)))
                   (then (call $raise-string-set!:char-expected (local.get $ch))))
               ;; --- Decode ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; Check for immutability
               (if (i32.eq (struct.get $String $immutable (local.get $str)) (i32.const 1))
                   (then (call $raise-string-set!:string-immutable (local.get $s))))
               ;; Decode and validate fixnum index
               (local.set $idx (i31.get_u (ref.cast (ref i31) (local.get $i))))
               (if (i32.eqz (i32.and (local.get $idx) (i32.const 1)))
                   (then (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                   (else (call $raise-string-set!:fixnum-expected (local.get $i))))
               ;; Decode and validate character
               (local.set $tagged (i31.get_u (ref.cast (ref i31) (local.get $ch))))
               (if (i32.ne (i32.and (local.get $tagged) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then (call $raise-string-set!:char-expected (local.get $ch))))
               (local.set $cp (i32.shr_u (local.get $tagged) (i32.const ,char-shift)))
               ;; --- Bounds-check and write ---
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (if (i32.lt_u (local.get $idx) (call $i32array-length (local.get $arr)))
                   (then (call $i32array-set! (local.get $arr) (local.get $idx) (local.get $cp))
                         ;; Keep the hash. The eq-identity doesn't change.
                         (return (global.get $void)))
                   (else (call $raise-bad-string-index/i32 (local.get $s) (local.get $idx))))
               (unreachable))

         (func $substring (type $Prim23)
              (param $s     (ref eq))
              (param $start (ref eq))
              (param $end   (ref eq)) ; optional, default to (string-length s)
              (result       (ref eq))

              (local $str      (ref null $String))
              (local $arr      (ref $I32Array))
              (local $i32start i32)
              (local $i32end   i32)
              (local $len      i32)
              ;; check string
              (if (ref.test (ref $String) (local.get $s))
                  (then (local.set $str (ref.cast (ref $String) (local.get $s))))
                  (else (call $raise-check-string (local.get $s))))
              ;; decode and check start index
              (if (ref.test (ref i31) (local.get $start))
                  (then (local.set $i32start (i31.get_u (ref.cast (ref i31) (local.get $start))))
                        (if (i32.ne (i32.and (local.get $i32start) (i32.const 1)) (i32.const 0))
                            (then (call $raise-check-fixnum (local.get $start))))
                        (local.set $i32start (i32.shr_u (local.get $i32start) (i32.const 1))))
                  (else (call $raise-check-fixnum (local.get $start))))
              ;; get array and length
              (local.set $arr (struct.get $String $codepoints (local.get $str)))
              (local.set $len (call $i32array-length (local.get $arr)))
              ;; supply default value for the optional end index
              (if (ref.eq (local.get $end) (global.get $missing))
                  (then (local.set $end
                                   (ref.i31 (i32.shl (local.get $len) (i32.const 1))))))
              ;; decode and check end index
              (if (ref.test (ref i31) (local.get $end))
                  (then (local.set $i32end (i31.get_u (ref.cast (ref i31) (local.get $end))))
                        (if (i32.ne (i32.and (local.get $i32end) (i32.const 1)) (i32.const 0))
                            (then (call $raise-check-fixnum (local.get $end))))
                        (local.set $i32end (i32.shr_u (local.get $i32end) (i32.const 1))))
                  (else (call $raise-check-fixnum (local.get $end))))
              ;; bounds check: start <= end <= len
              (if (i32.or (i32.gt_u (local.get $i32start) (local.get $i32end))
                          (i32.gt_u (local.get $i32end) (local.get $len)))
                  (then (call $raise-string-index-out-of-bounds/i32 (local.get $s) (local.get $i32end) (local.get $len))))
              ;; create new string
              (struct.new $String
                          (i32.const 0) ; hash
                          (i32.const 0) ; mutable (also for immutable input)
                          (call $i32array-copy (local.get $arr) (local.get $i32start) (local.get $i32end))))

         (func $string-copy (type $Prim1)
               (param $s (ref eq))
               (result (ref eq))

               (local $str (ref $String))
               (local $arr (ref $I32Array))
               (local $len i32)
               (local $copy (ref $I32Array))
               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               ;; --- Cast and extract ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $len (array.len (local.get $arr)))
               ;; --- Copy the codepoint array ---
               (local.set $copy (call $i32array-copy (local.get $arr) (i32.const 0) (local.get $len)))
               ;; --- Construct new mutable string with hash = 0 ---
               (struct.new $String
                           (i32.const 0)       ;; $hash
                           (i32.const 0)       ;; mutable
                           (local.get $copy))) ;; $codepoints

         (func $raise-immutable-string (param $x (ref eq)) (unreachable))

         (func $string-fill! (type $Prim2)
               (param $s   (ref eq))
               (param $ch  (ref eq))
               (result     (ref eq))

               (local $str (ref $String))
               (local $arr (ref $I32Array))
               (local $cp  i32)

               ;; --- 1. Check and cast string ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; --- 2. Raise if immutable ---
               (if (i32.ne (struct.get $String $immutable (local.get $str)) (i32.const 0))
                   (then (call $raise-immutable-string (local.get $s))))
               ;; --- 3. Decode and check char immediate ---
               (if (i32.eqz (ref.test (ref i31) (local.get $ch)))
                   (then (call $raise-check-char (local.get $ch))))
               (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $ch))))
               (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then (call $raise-check-char (local.get $ch))))
               (local.set $cp (i32.shr_u (local.get $cp) (i32.const ,char-shift)))
               ;; --- 4. Fill (keep eq-hash-code) ---
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (call $i32array-fill! (local.get $arr) (local.get $cp))
               ;; --- 5. Return void ---
               (global.get $void))


         (func $string-append/2 (param $s1 (ref eq)) (param $s2 (ref eq)) (result (ref $String))
               (local $str1 (ref null $String))
               (local $str2 (ref null $String))
               (if (ref.test (ref $String) (local.get $s1))
                   (then (local.set $str1 (ref.cast (ref $String) (local.get $s1))))
                   (else (call $raise-check-string (local.get $s1))))
               (if (ref.test (ref $String) (local.get $s2))
                   (then (local.set $str2 (ref.cast (ref $String) (local.get $s2))))
                   (else (call $raise-check-string (local.get $s2))))
               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (call $i32array-append
                                 (struct.get $String $codepoints (local.get $str1))
                                 (struct.get $String $codepoints (local.get $str2)))))


         (func $string-append (type $Prim>=0)
               (param  $xs   (ref eq))        ;; expects a list of strings
               (result       (ref eq))

               (local $n     i32)
               (local $node  (ref $Pair))
               (local $s     (ref $String))
               (local $v     (ref eq))
               (local $orig  (ref eq))
               (local $total i32)
               (local $len   i32)
               (local $arr   (ref $I32Array))
               (local $pos   i32)

               ;; === initialize non-defaultable refs ===
               (local.set $s (ref.cast (ref $String) (global.get $string:empty)))

               ;; Preserve original list
               (local.set $orig (local.get $xs))
               ;; Determine number of arguments
               (local.set $n (call $length/i32 (local.get $xs)))
               ;; Zero arguments -> existing empty string
               (if (i32.eqz (local.get $n))
                   (then (return (global.get $string:empty))))
               ;; Extract and check first argument
               (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
               (local.set $v    (struct.get $Pair $a (local.get $node)))
               (if (ref.test (ref $String) (local.get $v))
                   (then (local.set $s (ref.cast (ref $String) (local.get $v))))
                   (else (call $raise-check-string (local.get $v))))
               ;; Single argument -> copy to ensure fresh mutable string
               (if (i32.eq (local.get $n) (i32.const 1))
                   (then (if (ref.eq (local.get $s) (global.get $string:empty))
                             (then (return (global.get $string:empty)))
                             (else (return (call $string-copy (local.get $s)))))))
               ;; Compute total length
               (local.set $total
                          (call $i32array-length
                                (struct.get $String $codepoints (local.get $s))))
               (local.set $xs (struct.get $Pair $d (local.get $node)))
               (block $done1
                      (loop $loop1
                            (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (if (ref.test (ref $String) (local.get $v))
                                (then
                                 (local.set $s (ref.cast (ref $String) (local.get $v)))
                                 (local.set $len
                                            (call $i32array-length
                                                  (struct.get $String $codepoints (local.get $s))))
                                 (local.set $total (i32.add (local.get $total) (local.get $len))))
                                (else (call $raise-check-string (local.get $v))))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop1)))
               ;; All strings empty -> return empty string
               (if (i32.eqz (local.get $total))
                   (then (return (global.get $string:empty))))
               ;; Allocate result array
               (local.set $arr (call $i32array-make (local.get $total) (i32.const 0)))
               ;; Copy strings into result array
               (local.set $xs (local.get $orig))
               (local.set $pos (i32.const 0))
               (block $done2
                      (loop $loop2
                            (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $s
                                       (ref.cast (ref $String) (struct.get $Pair $a (local.get $node))))
                            (local.set $len
                                       (call $i32array-length
                                             (struct.get $String $codepoints (local.get $s))))
                            (call $i32array-copy!
                                  (local.get $arr) (local.get $pos)
                                  (struct.get $String $codepoints (local.get $s))
                                  (i32.const 0) (local.get $len))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop2)))

               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (local.get $arr)))


         (func $string-append-immutable (type $Prim>=0)
               (param  $xs (ref eq))         ;; list of strings
               (result     (ref eq))

               (local $s   (ref $String))
               (local $arr (ref $I32Array))
               ;; Do the append (returns a fresh $String)
               (local.set $s (ref.cast (ref $String)
                                       (call $string-append (local.get $xs))))
               ;; Reuse its codepoint array
               (local.set $arr (struct.get $String $codepoints (local.get $s)))
               ;; Build a new $String that is immutable (=1). Hash = 0 (lazy).
               (struct.new $String
                           (i32.const 0)      ;; $hash
                           (i32.const 1)      ;; $immutable
                           (local.get $arr))) ;; $codepoints

         (func $string-append* (type $Prim>=1)
               (param $str  (ref eq))  ;; string? or list of strings
               (param $rest (ref eq))  ;; additional strings, last element list
               (result      (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $acc  (ref eq))
               (local $last (ref eq))
               (local $args (ref eq))

               ; initialize locals with no defaults
               (local.set $last (global.get $false))
               ;; no extra args: first arg supplies list of strings
               (if (ref.eq (local.get $rest) (global.get $null))
                   (then (return (call $string-append (local.get $str)))))

               ;; separate last list from preceding string arguments
               (local.set $xs  (local.get $rest))
               (local.set $acc (global.get $null))
               (block $done
                      (loop $loop
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (if (ref.eq (local.get $xs) (global.get $null))
                                (then
                                 (local.set $last (struct.get $Pair $a (local.get $node)))
                                 (br $done))
                                (else
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (struct.get $Pair $a (local.get $node))
                                                        (local.get $acc)))
                                 (br $loop)))))

               ;; rebuild argument list in proper order
               (local.set $args (local.get $last))
               (block $done2
                      (loop $loop2
                            (br_if $done2 (ref.eq (local.get $acc) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $acc)))
                            (local.set $args
                                       (struct.new $Pair
                                                   (i32.const 0)
                                                   (struct.get $Pair $a (local.get $node))
                                                   (local.get $args)))
                            (local.set $acc (struct.get $Pair $d (local.get $node)))
                            (br $loop2)))
               (local.set $args
                          (struct.new $Pair (i32.const 0)
                                      (local.get $str)
                                      (local.get $args)))
               (call $string-append (local.get $args)))

         ;; Note: Simplified version: accepts list of strings and optional separator only.
         (func $string-join (type $Prim12)
               (param $strs (ref eq)) ;; listof string?
               (param $sep  (ref eq)) ;; optional string?, default = " "
               (result      (ref eq))

               (local $xs      (ref eq))
               (local $node    (ref $Pair))
               (local $v       (ref eq))
               (local $str     (ref $String))
               (local $sep-str (ref $String))
               (local $sep-len i32)
               (local $n       i32)
               (local $total   i32)
               (local $len     i32)
               (local $arr     (ref $I32Array))
               (local $pos     i32)

               ;; --- Handle optional separator ---
               (local.set $sep-str
                          (if (result (ref $String))
                              (ref.eq (local.get $sep) (global.get $missing))
                              (then (ref.cast (ref $String) (global.get $string:space)))
                              (else (if (result (ref $String))
                                        (ref.test (ref $String) (local.get $sep))
                                        (then (ref.cast (ref $String) (local.get $sep)))
                                        (else (call $raise-check-string (local.get $sep))
                                              (unreachable))))))
               ;; --- Determine separator length ---
               (local.set $sep-len
                          (call $i32array-length
                                (struct.get $String $codepoints (local.get $sep-str))))
               ;; --- Determine number of strings ---
               (local.set $n (call $length/i32 (local.get $strs)))
               (if (i32.eqz (local.get $n))
                   (then (return (global.get $string:empty))))
               ;; --- Compute total length ---
               (local.set $xs (local.get $strs))
               (local.set $total
                          (i32.mul (i32.sub (local.get $n) (i32.const 1))
                                   (local.get $sep-len)))
               (block $done1
                      (loop $loop1
                            (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v (struct.get $Pair $a (local.get $node)))
                            (if (ref.test (ref $String) (local.get $v))
                                (then
                                 (local.set $str (ref.cast (ref $String) (local.get $v)))
                                 (local.set $len
                                            (call $i32array-length
                                                  (struct.get $String $codepoints (local.get $str))))
                                 (local.set $total (i32.add (local.get $total) (local.get $len))))
                                (else (call $raise-check-string (local.get $v)) (unreachable)))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop1)))
               ;; --- All empty -> empty string ---
               (if (i32.eqz (local.get $total))
                   (then (return (global.get $string:empty))))
               ;; --- Allocate result array ---
               (local.set $arr (call $i32array-make (local.get $total) (i32.const 0)))
               ;; --- Copy strings and separators ---
               (local.set $xs (local.get $strs))
               (local.set $pos (i32.const 0))
               (block $done2
                      (loop $loop2
                            (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $str
                                       (ref.cast (ref $String)
                                                 (struct.get $Pair $a (local.get $node))))
                            (local.set $len
                                       (call $i32array-length
                                             (struct.get $String $codepoints (local.get $str))))
                            (call $i32array-copy!
                                  (local.get $arr) (local.get $pos)
                                  (struct.get $String $codepoints (local.get $str))
                                  (i32.const 0) (local.get $len))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (if (ref.eq (local.get $xs) (global.get $null))
                                (then (nop))
                                (else
                                 (call $i32array-copy!
                                       (local.get $arr) (local.get $pos)
                                       (struct.get $String $codepoints (local.get $sep-str))
                                       (i32.const 0) (local.get $sep-len))
                                 (local.set $pos
                                            (i32.add (local.get $pos) (local.get $sep-len)))))
                            (br $loop2)))
               ;; --- Build result string ---
               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (local.get $arr)))


         ;; Note: Unlike Racket's string-split, this variant does not support
         ;; keyword arguments or regular-expression separators.
         (func $string-split (type $Prim14)
               (param $str-raw    (ref eq)) ;; string?
               (param $sep-raw    (ref eq)) ;; optional string?, default = " "
               (param $trim-raw   (ref eq)) ;; optional any/c, default = #t
               (param $repeat-raw (ref eq)) ;; optional any/c, default = #f
               (result            (ref eq))

               (local $str          (ref $String))
               (local $sep          (ref $String))
               (local $trim-val     (ref eq))
               (local $repeat-val   (ref eq))
               (local $arr-str      (ref $I32Array))
               (local $arr-sep      (ref $I32Array))
               (local $len-str      i32)
               (local $len-sep      i32)
               (local $trim-flag    i32)
               (local $repeat-flag  i32)
               (local $start        i32)
               (local $end          i32)
               (local $match-pos    i32)
               (local $segment-len  i32)
               (local $acc          (ref eq))
               (local $piece        (ref $String))
               (local $idx          i32)
               (local $empty        (ref $String))
               (local $found        i32)
               (local $pos          i32)

               ;; --- Decode defaults ---
               (if (i32.eqz (ref.test (ref $String) (local.get $str-raw)))
                   (then (call $raise-check-string (local.get $str-raw))))
               (local.set $str (ref.cast (ref $String) (local.get $str-raw)))

               (local.set $sep
                          (if (result (ref $String))
                              (ref.eq (local.get $sep-raw) (global.get $missing))
                              (then (ref.cast (ref $String) (global.get $string:space)))
                              (else (if (result (ref $String))
                                        (ref.test (ref $String) (local.get $sep-raw))
                                        (then (ref.cast (ref $String) (local.get $sep-raw)))
                                        (else (call $raise-check-string (local.get $sep-raw))
                                              (unreachable))))))

               (local.set $trim-val
                          (if (result (ref eq))
                              (ref.eq (local.get $trim-raw) (global.get $missing))
                              (then (global.get $true))
                              (else (local.get $trim-raw))))
               (local.set $repeat-val
                          (if (result (ref eq))
                              (ref.eq (local.get $repeat-raw) (global.get $missing))
                              (then (global.get $false))
                              (else (local.get $repeat-raw))))

               (local.set $trim-flag
                          (if (result i32)
                              (ref.eq (local.get $trim-val) (global.get $false))
                              (then (i32.const 0))
                              (else (i32.const 1))))
               (local.set $repeat-flag
                          (if (result i32)
                              (ref.eq (local.get $repeat-val) (global.get $false))
                              (then (i32.const 0))
                              (else (i32.const 1))))

               (local.set $arr-str (struct.get $String $codepoints (local.get $str)))
               (local.set $arr-sep (struct.get $String $codepoints (local.get $sep)))
               (local.set $len-str (call $i32array-length (local.get $arr-str)))
               (local.set $len-sep (call $i32array-length (local.get $arr-sep)))

               (local.set $start (i32.const 0))
               (local.set $end   (local.get $len-str))

               ;; --- Trim using literal separator when requested ---
               (if (i32.and (local.get $trim-flag)
                            (i32.ne (local.get $len-sep) (i32.const 0)))
                   (then
                    (local.set $start
                               (call $string-split:trim-left
                                     (local.get $arr-str)
                                     (local.get $arr-sep)
                                     (local.get $len-sep)
                                     (local.get $start)
                                     (local.get $end)
                                     (local.get $repeat-flag)))
                    (local.set $end
                               (call $string-split:trim-right
                                     (local.get $arr-str)
                                     (local.get $arr-sep)
                                     (local.get $len-sep)
                                     (local.get $start)
                                     (local.get $end)
                                     (local.get $repeat-flag)))))

               ;; --- Special-case empty after trimming ---
               (if (i32.eq (local.get $start) (local.get $end))
                   (then
                    (if (local.get $trim-flag)
                        (then (return (global.get $null)))
                        (else
                         (local.set $empty (ref.cast (ref $String) (global.get $string:empty)))
                         (return (struct.new $Pair
                                             (i32.const 0)
                                             (local.get $empty)
                                             (global.get $null)))))))

               ;; --- Handle empty separator by splitting into codepoints ---
               (if (i32.eqz (local.get $len-sep))
                   (then
                    (local.set $acc (global.get $null))
                    (local.set $idx (i32.sub (local.get $end) (i32.const 1)))
                    (block $chars-done
                           (loop $chars
                                 (br_if $chars-done (i32.lt_s (local.get $idx) (local.get $start)))
                                 (local.set $piece
                                            (call $codepoint->string
                                                  (call $i32array-ref
                                                        (local.get $arr-str)
                                                        (local.get $idx))))
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (local.get $piece)
                                                        (local.get $acc)))
                                 (if (i32.eq (local.get $idx) (local.get $start))
                                     (then (br $chars-done)))
                                 (local.set $idx (i32.sub (local.get $idx) (i32.const 1)))
                                 (br $chars)))
                    (return (local.get $acc))))

               (local.set $acc (global.get $null))
               (local.set $pos (local.get $start))
               (local.set $empty (ref.cast (ref $String) (global.get $string:empty)))

               (block $done
                      (loop $split
                            (local.set $match-pos
                                       (call $string-split:find-match
                                             (local.get $arr-str)
                                             (local.get $arr-sep)
                                             (local.get $len-sep)
                                             (local.get $pos)
                                             (local.get $end)))
                            (local.set $segment-len
                                       (i32.sub (local.get $match-pos) (local.get $pos)))
                            (local.set $found
                                       (i32.ne (local.get $match-pos) (local.get $end)))
                            (if (i32.or (i32.ne (local.get $segment-len) (i32.const 0))
                                        (i32.eqz (local.get $repeat-flag)))
                                (then
                                 (local.set $piece
                                            (if (result (ref $String))
                                                (i32.eqz (local.get $segment-len))
                                                (then (local.get $empty))
                                                (else (call $i32array->string
                                                            (call $i32array-copy
                                                                  (local.get $arr-str)
                                                                  (local.get $pos)
                                                                  (local.get $match-pos))))))
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (local.get $piece)
                                                        (local.get $acc)))))
                            (if (i32.eqz (local.get $found))
                                (then (br $done)))
                            (local.set $pos
                                       (i32.add (local.get $match-pos) (local.get $len-sep)))
                            (if (local.get $repeat-flag)
                                (then
                                 (local.set $pos
                                            (call $string-split:skip-repeats
                                                  (local.get $arr-str)
                                                  (local.get $arr-sep)
                                                  (local.get $len-sep)
                                                  (local.get $pos)
                                                  (local.get $end)))))
                            (br $split)))

               (call $reverse (local.get $acc)))

         (func $string-split:matches?
               (param $arr-str (ref $I32Array))
               (param $arr-sep (ref $I32Array))
               (param $pos     i32)
               (param $len-sep i32)
               (result i32)

               (local $j i32)

               (local.set $j (i32.const 0))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $j) (local.get $len-sep)))
                            (if (i32.ne (call $i32array-ref
                                              (local.get $arr-str)
                                              (i32.add (local.get $pos) (local.get $j)))
                                        (call $i32array-ref (local.get $arr-sep) (local.get $j)))
                                (then (return (i32.const 0))))
                            (local.set $j (i32.add (local.get $j) (i32.const 1)))
                            (br $loop)))

               (i32.const 1))

         (func $string-split:trim-left
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $start    i32)
               (param $end      i32)
               (param $repeat   i32)
               (result i32)

               (local $pos i32)

               (local.set $pos (local.get $start))

               (block $done
                      (loop $loop
                            (br_if $done
                                   (i32.lt_u (i32.sub (local.get $end) (local.get $pos))
                                             (local.get $len-sep)))
                            (if (i32.eqz (call $string-split:matches?
                                               (local.get $arr-str)
                                               (local.get $arr-sep)
                                               (local.get $pos)
                                               (local.get $len-sep)))
                                (then (br $done)))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len-sep)))
                            (if (i32.eqz (local.get $repeat)) (then (br $done)))
                            (br $loop)))

               (local.get $pos))

         (func $string-split:trim-right
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $start    i32)
               (param $end      i32)
               (param $repeat   i32)
               (result i32)

               (local $limit       i32)
               (local $match-start i32)

               (local.set $limit (local.get $end))

               (block $done
                      (loop $loop
                            (br_if $done
                                   (i32.lt_u (i32.sub (local.get $limit) (local.get $start))
                                             (local.get $len-sep)))
                            (local.set $match-start
                                       (i32.sub (local.get $limit) (local.get $len-sep)))
                            (if (i32.eqz (call $string-split:matches?
                                               (local.get $arr-str)
                                               (local.get $arr-sep)
                                               (local.get $match-start)
                                               (local.get $len-sep)))
                                (then (br $done)))
                            (local.set $limit (local.get $match-start))
                            (if (i32.eqz (local.get $repeat)) (then (br $done)))
                            (br $loop)))

               (local.get $limit))

         (func $string-split:find-match
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $pos      i32)
               (param $end      i32)
               (result i32)

               (local $limit i32)
               (local $scan  i32)

               (if (i32.eqz (local.get $len-sep))
                   (then (return (local.get $pos))))
               (if (i32.gt_u (local.get $len-sep) (local.get $end))
                   (then (return (local.get $end))))

               (local.set $limit (i32.sub (local.get $end) (local.get $len-sep)))
               (if (i32.gt_u (local.get $pos) (local.get $limit))
                   (then (return (local.get $end))))

               (local.set $scan (local.get $pos))

               (block $done
                      (loop $loop
                            (br_if $done (i32.gt_u (local.get $scan) (local.get $limit)))
                            (if (call $string-split:matches?
                                      (local.get $arr-str)
                                      (local.get $arr-sep)
                                      (local.get $scan)
                                      (local.get $len-sep))
                                (then (return (local.get $scan))))
                            (local.set $scan (i32.add (local.get $scan) (i32.const 1)))
                            (br $loop)))

               (local.get $end))

         (func $string-split:skip-repeats
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $pos      i32)
               (param $end      i32)
               (result i32)

               (local $scan  i32)
               (local $limit i32)

               (if (i32.eqz (local.get $len-sep))
                   (then (return (local.get $pos))))
               (if (i32.gt_u (local.get $len-sep) (local.get $end))
                   (then (return (local.get $pos))))

               (local.set $limit (i32.sub (local.get $end) (local.get $len-sep)))
               (local.set $scan (local.get $pos))

               (block $done
                      (loop $loop
                            (br_if $done (i32.gt_u (local.get $scan) (local.get $limit)))
                            (if (i32.eqz (call $string-split:matches?
                                               (local.get $arr-str)
                                               (local.get $arr-sep)
                                               (local.get $scan)
                                               (local.get $len-sep)))
                                (then (br $done)))
                            (local.set $scan (i32.add (local.get $scan) (local.get $len-sep)))
                            (br $loop)))

               (local.get $scan))




         ;; 4.4.3 String Conversions
         ,@(for/list ([name+imp
                       (in-list '(($string-upcase    $char-upcase/ucs)
                                  ($string-downcase  $char-downcase/ucs)
                                  ($string-foldcase  $char-foldcase/ucs)))])
             (define name (car  name+imp))
             (define imp  (cadr name+imp))
             `(func ,name (type $Prim1) (param $s (ref eq)) (result (ref eq))
                    (local $str (ref $String))
                    (local $arr (ref $I32Array))
                    (local $len i32)
                    (local $res (ref $I32Array))
                    (local $i   i32)
                    (local $cp  i32)
                    (local $cp2 i32)
                    ;; Type check
                    (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                        (then (call $raise-check-string (local.get $s))))
                    ;; Extract codepoint array and length
                    (local.set $str (ref.cast (ref $String) (local.get $s)))
                    (local.set $arr (struct.get $String $codepoints (local.get $str)))
                    (local.set $len (array.len (local.get $arr)))
                    ;; Allocate result array
                    (local.set $res (call $i32array-make (local.get $len) (i32.const 0)))
                    ;; Loop over characters
                    (local.set $i (i32.const 0))
                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $cp (call $i32array-ref (local.get $arr) (local.get $i)))
                                 (local.set $cp2 (call ,imp (local.get $cp)))
                                 (call $i32array-set! (local.get $res) (local.get $i) (local.get $cp2))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                    ;; Build new mutable string
                    (struct.new $String
                                (i32.const 0)
                                (i32.const 0)
                                (local.get $res))))


         ;; string-titlecase : string? -> string?
         ;;   Note: Approximates Unicode Case_Ignorable via general categories
         ;;         Mn, Me, Cf, Lm, Sk. No optional parameters.
         (func $string-titlecase (type $Prim1)
               (param $s (ref eq))
               (result   (ref eq))

               (local $t      (ref $String))
               (local $len    i32)
               (local $i      i32)
               (local $in-run i32)
               (local $c      (ref eq))
               (local $cat    (ref eq))

               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))
                         (unreachable)))
               ;; --- Make mutable copy and get length ---
               (local.set $t      (ref.cast (ref $String) (call $string-copy (local.get $s))))
               (local.set $len    (call $string-length/checked/i32 (local.get $t)))
               (local.set $i      (i32.const 0))
               (local.set $in-run (i32.const 0))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))

                            (local.set $c (call $string-ref/checked (local.get $t) (local.get $i)))

                            (if (i32.or (ref.eq (call $char-upper-case? (local.get $c)) (global.get $true))
                                        (ref.eq (call $char-lower-case? (local.get $c)) (global.get $true)))
                                (then
                                 (drop ; rememember, string-set! returns `void`
                                  (call $string-set!
                                        (local.get $t)
                                        (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                        (if (result (ref eq)) (local.get $in-run)
                                            (then (call $char-downcase (local.get $c)))
                                            (else (call $char-upcase (local.get $c))))))
                                 (local.set $in-run (i32.const 1)))
                                (else
                                 (local.set $cat (call $char-general-category (local.get $c)))
                                 (if (i32.eqz (i32.or (ref.eq       (local.get $cat) (global.get $symbol:mn))
                                                (i32.or (ref.eq     (local.get $cat) (global.get $symbol:me))
                                                  (i32.or (ref.eq   (local.get $cat) (global.get $symbol:cf))
                                                    (i32.or (ref.eq (local.get $cat) (global.get $symbol:lm))
                                                            (ref.eq (local.get $cat) (global.get $symbol:sk)))))))
                                     (then (local.set $in-run (i32.const 0))))))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.get $t))

         (func $string->list (type $Prim1) (param $s (ref eq)) (result (ref eq))
               (local $str   (ref null $String))
               (local $arr   (ref $I32Array))
               (local $len   i32)
               (local $i     i32)
               (local $res   (ref $Pair))
               (local $cp    i32)
               ;; check string
               (if (ref.test (ref $String) (local.get $s))
                   (then (local.set $str (ref.cast (ref $String) (local.get $s))))
                   (else (call $raise-check-string (local.get $s))))
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $len (call $i32array-length (local.get $arr)))
               ;; special case len=0
               (if (result (ref eq))
                   (i32.eqz (local.get $len))
                   (then (return (global.get $null)))
                   ; ;; special case len>=1
                   (else (local.set $i   (i32.sub (local.get $len) (i32.const 1))) ; from end
                         (local.set $cp  (call $i32array-ref (local.get $arr) (local.get $i)))
                         (local.set $res (struct.new $Pair (i32.const 0)
                                                     (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const 8)) (i32.const ,char-tag)))
                                                     (global.get $null)))
                         (local.set $i   (i32.sub (local.get $i) (i32.const 1)))
                         (block $done
                                (loop $build
                                      (br_if $done (i32.lt_s (local.get $i) (i32.const 0)))
                                      (local.set $cp (call $i32array-ref (local.get $arr) (local.get $i)))
                                      ;; tag cp as char
                                      (local.set $res
                                                 (struct.new $Pair (i32.const 0)
                                                             (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const 8)) (i32.const ,char-tag)))
                                                             (local.get $res)))
                                      (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                                      (br $build)))
                         (local.get $res))))

         (func $list->string (type $Prim1) (param $xs (ref eq)) (result (ref eq))
               (local $len   i32)
               (local $str   (ref $String))
               (local $arr   (ref $I32Array))
               (local $i     i32)
               (local $node  (ref eq))
               (local $chimm (ref eq))
               (local $cp    i32)
               ;; 1. Compute list length (will raise if not proper list)
               (local.set $len (call $length/i32 (local.get $xs)))
               ;; 2. Create new mutable string
               (local.set $str
                          (struct.new $String
                                      (i32.const 0)  ;; hash
                                      (i32.const 0)  ;; immutable = false
                                      (call $i32array-make (local.get $len) (i32.const 0))))
               ;; 3. Grab codepoint array once
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               ;; 4. Fill from list directly
               (local.set $i (i32.const 0))
               (local.set $node (local.get $xs))
               (block $done
                      (loop $fill
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            ;; Check node is a pair
                            (if (ref.test (ref $Pair) (local.get $node))
                                (then
                                 ;; extract car
                                 (local.set $chimm (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                                 ;; decode and validate character
                                 (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $chimm))))
                                 (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask)) (i32.const ,char-tag))
                                     (then (call $raise-check-char (local.get $chimm))
                                           (unreachable)))
                                 ;; extract codepoint
                                 (local.set $cp (i32.shr_u (local.get $cp) (i32.const 8)))
                                 ;; write codepoint
                                 (call $i32array-set! (local.get $arr) (local.get $i) (local.get $cp))
                                 ;; advance
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node)))))
                                (else
                                 (call $raise-pair-expected (local.get $node))
                                 (unreachable)))
                            (br $fill)))
               ;; 5. Return string
               (local.get $str))



         ;; 4.4.2 String Comparisons

         (func $string=?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string=?/i32 (local.get $a) (local.get $b))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string=? : string? string? ... -> boolean? (at least 1)
         (func $string=? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     (if (i32.eqz (call $string=?/i32/checked (local.get $prev) (local.get $curr)))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string=?/i32
               (param $a-raw (ref eq)) (param $b-raw (ref eq))
               (result i32)

               (local $a (ref $String))
               (local $b (ref $String))
               ;; Check types
               (if (i32.eqz (ref.test (ref $String) (local.get $a-raw)))
                   (then (return (i32.const 0))))
               (if (i32.eqz (ref.test (ref $String) (local.get $b-raw)))
                   (then (return (i32.const 0))))
               ;; Cast and delegate
               (local.set $a (ref.cast (ref $String) (local.get $a-raw)))
               (local.set $b (ref.cast (ref $String) (local.get $b-raw)))
               (return_call $string=?/i32/checked (local.get $a) (local.get $b)))

         (func $string=?/i32/checked
               (param $a (ref $String)) (param $b (ref $String))
               (result i32)

               (return_call $i32array-equal?
                            (struct.get $String $codepoints (local.get $a))
                            (struct.get $String $codepoints (local.get $b))))

         (func $string<?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string</i32 (local.get $a) (local.get $b))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string<? : string? string? ... -> boolean? (at least 1)
         (func $string<? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     (if (i32.eqz (call $string</i32/checked (local.get $prev) (local.get $curr)))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string<=?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (i32.or (call $string</i32 (local.get $a) (local.get $b))
                           (call $string=?/i32 (local.get $a) (local.get $b)))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string<=? : string? string? ... -> boolean? (at least 1)
         (func $string<=? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     ;; Fail if current < previous
                     (if (i32.ne (call $string</i32/checked (local.get $curr) (local.get $prev)) (i32.const 0))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string>?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string</i32 (local.get $b) (local.get $a))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string>? : string? string? ... -> boolean? (at least 1)
         (func $string>? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     (if (i32.eqz (call $string</i32/checked (local.get $curr) (local.get $prev)))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string>=?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (i32.or (call $string</i32 (local.get $b) (local.get $a))
                           (call $string=?/i32 (local.get $a) (local.get $b)))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string>=? : string? string? ... -> boolean? (at least 1)
         (func $string>=? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     ;; Fail if previous < current
                     (if (i32.ne (call $string</i32/checked (local.get $prev) (local.get $curr)) (i32.const 0))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string</i32
               (param $a-raw (ref eq)) (param $b-raw (ref eq))
               (result i32)

               (local $a (ref $String))
               (local $b (ref $String))

               ;; Check types
               (if (i32.eqz (ref.test (ref $String) (local.get $a-raw)))
                   (then (return (i32.const 0))))
               (if (i32.eqz (ref.test (ref $String) (local.get $b-raw)))
                   (then (return (i32.const 0))))
               ;; Cast and delegate
               (local.set $a (ref.cast (ref $String) (local.get $a-raw)))
               (local.set $b (ref.cast (ref $String) (local.get $b-raw)))
               (return_call $string</i32/checked (local.get $a) (local.get $b)))

         (func $string</i32/checked
               (param $a (ref $String)) (param $b (ref $String))
               (result i32)

               (local $arr-a (ref $I32Array))
               (local $arr-b (ref $I32Array))
               (local $len-a i32)
               (local $len-b i32)
               (local $i i32)
               (local $cp-a i32)
               (local $cp-b i32)

               (local.set $arr-a (struct.get $String $codepoints (local.get $a)))
               (local.set $arr-b (struct.get $String $codepoints (local.get $b)))
               (local.set $len-a (array.len (local.get $arr-a)))
               (local.set $len-b (array.len (local.get $arr-b)))
               (local.set $i (i32.const 0))

               (block $exit
                      (loop $loop
                            (br_if $exit (i32.ge_u (local.get $i) (local.get $len-a)))
                            (br_if $exit (i32.ge_u (local.get $i) (local.get $len-b)))
                            (local.set $cp-a (array.get $I32Array (local.get $arr-a) (local.get $i)))
                            (local.set $cp-b (array.get $I32Array (local.get $arr-b) (local.get $i)))
                            (if (i32.lt_u (local.get $cp-a) (local.get $cp-b))
                                (then (return (i32.const 1))))
                            (if (i32.gt_u (local.get $cp-a) (local.get $cp-b))
                                (then (return (i32.const 0))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               ;; If one is a prefix of the other
               (return (i32.lt_u (local.get $len-a) (local.get $len-b))))


         (func $string-ci-compare/checked
               (param $a (ref $String)) (param $b (ref $String))
               (result i32)

               (local $arr-a (ref $I32Array))
               (local $arr-b (ref $I32Array))
               (local $len-a i32)
               (local $len-b i32)
               (local $i     i32)
               (local $cp-a  i32)
               (local $cp-b  i32)
               (local $fc-a  i32)
               (local $fc-b  i32)

               (local.set $arr-a (struct.get $String $codepoints (local.get $a)))
               (local.set $arr-b (struct.get $String $codepoints (local.get $b)))
               (local.set $len-a (array.len (local.get $arr-a)))
               (local.set $len-b (array.len (local.get $arr-b)))
               (local.set $i (i32.const 0))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len-a)))
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len-b)))
                            (local.set $cp-a (array.get $I32Array (local.get $arr-a) (local.get $i)))
                            (local.set $cp-b (array.get $I32Array (local.get $arr-b) (local.get $i)))
                            (local.set $fc-a (call $char-foldcase/ucs (local.get $cp-a)))
                            (local.set $fc-b (call $char-foldcase/ucs (local.get $cp-b)))
                            (if (i32.ne (local.get $fc-a) (local.get $fc-b))
                                (then (return (i32.sub (local.get $fc-a) (local.get $fc-b)))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (return (i32.sub (local.get $len-a) (local.get $len-b))))

        ,@(for*/list ([entry (in-list '(($string-ci=?   eq)
                                        ($string-ci<?   lt)
                                        ($string-ci<=?  le)
                                        ($string-ci>?   gt)
                                        ($string-ci>=?  ge)))]
                      [form
                       (in-list
                        (let* ([cmp             (car entry)]
                               [kind            (cadr entry)]
                               [cmp/2           (string->symbol (~a cmp "/2"))]
                               [cmp/i32         (string->symbol (~a cmp "/i32"))]
                               [cmp/i32/checked (string->symbol (~a cmp "/i32/checked"))]
                               [cond-expr
                                (case kind
                                  [(eq) `(i32.eqz (call $string-ci-compare/checked
                                                       (local.get $a)
                                                       (local.get $b)))]
                                  [(lt) `(i32.lt_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))]
                                  [(le) `(i32.le_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))]
                                  [(gt) `(i32.gt_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))]
                                  [(ge) `(i32.ge_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))])]
                               [fail-cond
                                (case kind
                                  [(eq) `(i32.ne (local.get $cmp) (i32.const 0))]
                                  [(lt) `(i32.ge_s (local.get $cmp) (i32.const 0))]
                                  [(le) `(i32.gt_s (local.get $cmp) (i32.const 0))]
                                  [(gt) `(i32.le_s (local.get $cmp) (i32.const 0))]
                                  [(ge) `(i32.lt_s (local.get $cmp) (i32.const 0))])])
                          (list
                           `(func ,cmp/2
                                  (param $a (ref eq)) (param $b (ref eq))
                                  (result (ref eq))
                                  (if (result (ref eq))
                                      (call ,cmp/i32 (local.get $a) (local.get $b))
                                      (then (global.get $true))
                                      (else (global.get $false))))
                           `(func ,cmp (type $Prim>=1)
                                  (param $a (ref eq))   ;; string?
                                  (param $rest (ref eq)) ;; list of string?
                                  (result (ref eq))

                                  (local $prev (ref $String))
                                  (local $curr (ref $String))
                                  (local $restlist (ref eq))
                                  (local $pair (ref $Pair))
                                  (local $next (ref eq))
                                  (local $cmp i32)

                                  ;; Type check first argument
                                  (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                                      (then (call $raise-argument-error:string-expected (local.get $a))
                                            (unreachable)))
                                  (local.set $prev (ref.cast (ref $String) (local.get $a)))
                                  (local.set $restlist (local.get $rest))

                                  ;; Single argument => #t
                                  (if (ref.eq (local.get $restlist) (global.get $null))
                                      (then (return (global.get $true))))

                                  (loop $loop
                                        (if (ref.eq (local.get $restlist) (global.get $null))
                                            (then (return (global.get $true))))
                                        (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                                            (then (call $raise-pair-expected (local.get $restlist))
                                                  (unreachable)))
                                        (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                                        (local.set $next (struct.get $Pair $a (local.get $pair)))
                                        (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                                            (then (call $raise-argument-error:string-expected (local.get $next))
                                                  (unreachable)))
                                        (local.set $curr (ref.cast (ref $String) (local.get $next)))
                                        (local.set $cmp (call $string-ci-compare/checked (local.get $prev) (local.get $curr)))
                                        (if ,fail-cond
                                            (then (return (global.get $false))))
                                        (local.set $prev (local.get $curr))
                                        (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                                        (br $loop))
                                  (unreachable))
                           `(func ,cmp/i32
                                  (param $a-raw (ref eq)) (param $b-raw (ref eq))
                                  (result i32)

                                  (local $a (ref $String))
                                  (local $b (ref $String))

                                  (if (i32.eqz (ref.test (ref $String) (local.get $a-raw)))
                                      (then (return (i32.const 0))))
                                  (if (i32.eqz (ref.test (ref $String) (local.get $b-raw)))
                                      (then (return (i32.const 0))))
                                  (local.set $a (ref.cast (ref $String) (local.get $a-raw)))
                                  (local.set $b (ref.cast (ref $String) (local.get $b-raw)))
                                  (return_call ,cmp/i32/checked (local.get $a) (local.get $b)))
                           `(func ,cmp/i32/checked
                                  (param $a (ref $String)) (param $b (ref $String))
                                  (result i32)
                                  (return ,cond-expr)))))])
            form)



         ;;;

         (func $raise-invalid-utf8-input (param $bad (ref eq)) (result (ref eq)) (unreachable))

         (func $raise-invalid-utf8-start (param $bad (ref eq)) (result (ref eq)) (unreachable))

         (func $raise-invalid-utf8-end (param $bad (ref eq)) (result (ref eq)) (unreachable))

         (func $raise-invalid-utf8-range (param $start (ref eq)) (param $end (ref eq)) (result (ref eq))
               (unreachable))

         (func $raise-string->bytes/utf8                 (unreachable))
         (func $raise-string->bytes/utf8:expected-string (unreachable))
         (func $raise-string->bytes/utf8:range-error     (unreachable))

         (func $string->bytes/utf-8 (export "string->bytes/utf-8")
               (param $str       (ref eq))
               (param $err-byte  (ref eq)) ;; Ignored
               (param $start-raw (ref eq))
               (param $end-raw   (ref eq))
               (result (ref eq))

               (local $s         (ref null $String))
               (local $cp        (ref $I32Array))
               (local $start     i32)
               (local $end       i32)
               (local $len       i32)
               (local $out-bytes (ref $I8Array))
               (local $idx       i32)
               (local $i         i32)
               (local $char      i32)
               (local $bs        (ref $Bytes))

               (local $raw-start i32)
               (local $raw-end   i32)

               ;; Check and cast $str
               (if (ref.test (ref $String) (local.get $str))
                   (then (local.set $s (ref.cast (ref $String) (local.get $str))))
                   (else (call $raise-string->bytes/utf8:expected-string))) ;; code 1 = not a string
               ;; Get codepoints array and length
               (local.set $cp  (struct.get $String $codepoints (local.get $s)))
               (local.set $len (array.len (local.get $cp)))
               ;; Decode start
               (if (ref.test (ref i31) (local.get $start-raw))
                   (then (local.set $raw-start (i31.get_u (ref.cast (ref i31) (local.get $start-raw))))
                         (if (i32.eq (local.get $raw-start) (i32.const ,(immediate-rep #f)))
                             (then (local.set $start (i32.const 0)))  ;; #f => use 0
                             (else (local.set $start (i32.shr_u (local.get $raw-start) (i32.const 1))))))
                   (else (call $raise-string->bytes/utf8)))  ;; not a fixnum
               ;; Decode end
               (if (ref.test (ref i31) (local.get $end-raw))
                   (then  (local.set $raw-end (i31.get_u (ref.cast (ref i31) (local.get $end-raw))))
                          (if (i32.eq (local.get $raw-end) (i32.const ,(immediate-rep #f))) ; #f
                              (then (local.set $end (local.get $len)))  ;; #f => use length
                              (else (local.set $end (i32.shr_u (local.get $raw-end) (i32.const 1))))))
                   (else (call $raise-string->bytes/utf8)))
               ;; Bounds check
               (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                           (i32.gt_u (local.get $end) (local.get $len)))
                   (then (call $raise-string->bytes/utf8:range-error)))
               ;; First pass: compute output size
               (local.set $i   (local.get $start))
               (local.set $idx (i32.const 0))
               (loop $size-loop
                     (if (i32.lt_u (local.get $i) (local.get $end))
                         (then
                          (local.set $char (array.get $I32Array (local.get $cp) (local.get $i)))
                          (local.set $idx (i32.add (local.get $idx) (call $utf8-size (local.get $char))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $size-loop))))
               ;; Allocate byte array
               (local.set $out-bytes (array.new_default $I8Array (local.get $idx)))
               (local.set $bs
                          (struct.new $Bytes
                                      (i32.const 0) ;; hash
                                      (i32.const 1) ;; immutable
                                      (local.get $out-bytes)))
               ;; Second pass: encode into buffer
               (local.set $i   (local.get $start))
               (local.set $idx (i32.const 0))
               (loop $encode-loop
                     (if (i32.lt_u (local.get $i) (local.get $end))
                         (then
                          (local.set $char (array.get $I32Array (local.get $cp) (local.get $i)))
                          (local.set $idx  (call $write-utf8 (local.get $bs) (local.get $idx) (local.get $char)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $encode-loop))))
               (local.get $bs))

         (func $string->bytes/locale (type $Prim14)
               ;; string->bytes/locale : string? [err-byte] [start] [end] -> bytes?
               ;; WebRacket has no host locale layer yet, so locale encoding is
               ;; currently UTF-8. The optional err-byte is accepted like
               ;; string->bytes/utf-8 but not needed for Unicode-to-UTF-8.
               (param $str       (ref eq)) ;; string?
               (param $err-byte  (ref eq)) ;; optional #f-or-byte?, default = #f
               (param $start-raw (ref eq)) ;; optional exact-nonnegative-integer?, default = 0
               (param $end-raw   (ref eq)) ;; optional exact-nonnegative-integer?, default = string length
               (result           (ref eq))
               (call $string->bytes/utf-8
                     (local.get $str)
                     (local.get $err-byte)
                     (local.get $start-raw)
                     (local.get $end-raw)))

         (func $raise-string-utf-8-length:bad-argument (unreachable))
         (func $raise-string-utf-8-length:range-error (unreachable))

         (func $string-utf-8-length (type $Prim13)
               (param $str       (ref eq))
               (param $start-raw (ref eq))   ;; fixnum or $missing
               (param $end-raw   (ref eq))   ;; fixnum or $missing
               (result (ref eq))

               (local $s     (ref null $String))
               (local $cp    (ref $I32Array))
               (local $len   i32)
               (local $start i32)
               (local $end   i32)
               (local $i     i32)
               (local $char  i32)
               (local $total i32)

               ;; --- Type check for string ---
               (if (ref.test (ref $String) (local.get $str))
                   (then (local.set $s (ref.cast (ref $String) (local.get $str))))
                   (else (call $raise-string-utf-8-length:bad-argument)))
               ;; --- Extract codepoints and length ---
               (local.set $cp  (struct.get $String $codepoints (local.get $s)))
               (local.set $len (array.len (local.get $cp)))
               ;; --- Decode start ---
               (if (ref.eq (local.get $start-raw) (global.get $missing))
                   (then (local.set $start (i32.const 0)))
                   (else (if (ref.test (ref i31) (local.get $start-raw))
                             (then (local.set $start (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $start-raw))) (i32.const 1))))
                             (else (call $raise-string-utf-8-length:bad-argument)))))
               ;; --- Decode end ---
               (if (ref.eq (local.get $end-raw) (global.get $missing))
                   (then (local.set $end (local.get $len)))
                   (else (if (ref.test (ref i31) (local.get $end-raw))
                             (then (local.set $end (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $end-raw))) (i32.const 1))))
                             (else (call $raise-string-utf-8-length:bad-argument)))))
               ;; --- Range check ---
               (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                           (i32.gt_u (local.get $end) (local.get $len)))
                   (then (call $raise-string-utf-8-length:range-error)))
               ;; --- Compute UTF-8 length ---
               (local.set $i     (local.get $start))
               (local.set $total (i32.const 0))
               (loop $len-loop
                     (if (i32.lt_u (local.get $i) (local.get $end))
                         (then
                          (local.set $char (array.get $I32Array (local.get $cp) (local.get $i)))
                          (local.set $total (i32.add (local.get $total) (call $utf8-size (local.get $char))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $len-loop))))
               (ref.i31 (i32.shl (local.get $total) (i32.const 1))))

         (func $raise-string-copy!:bad-destination       (unreachable))
         (func $raise-string-copy!:bad-destination-start (unreachable))
         (func $raise-string-copy!:bad-source            (unreachable))
         (func $raise-string-copy!:bad-source-start      (unreachable))
         (func $raise-string-copy!:bad-source-end        (unreachable))
         (func $raise-string-copy!:bad-source-range      (unreachable))
         (func $raise-string-copy!:bad-destination-range (unreachable))

         (func $string-copy! (type $Prim35)
               (param $dst-raw       (ref eq))
               (param $dst-start-raw (ref eq))
               (param $src-raw       (ref eq))
               (param $src-start-raw (ref eq))   ;; fixnum or $missing
               (param $src-end-raw   (ref eq))   ;; fixnum or $missing
               (result (ref eq))

               (local $dst        (ref $String))
               (local $src        (ref $String))
               (local $dst-start  i32)
               (local $src-start  i32)
               (local $src-end    i32)
               (local $src-len    i32)
               (local $dst-len    i32)
               ;; --- Type + fixnum checks ---
               (if (i32.eqz (ref.test (ref $String) (local.get $dst-raw)))
                   (then (call $raise-string-copy!:bad-destination)))
               (if (i32.eqz (ref.test (ref i31) (local.get $dst-start-raw)))
                   (then (call $raise-string-copy!:bad-destination-start)))
               (if (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $dst-start-raw))) (i32.const 1)) (i32.const 0))
                   (then (call $raise-string-copy!:bad-destination-start)))

               (if (i32.eqz (ref.test (ref $String) (local.get $src-raw)))
                   (then (call $raise-string-copy!:bad-source)))
               ;; src-start optional
               (if (i32.eqz (ref.eq (local.get $src-start-raw) (global.get $missing)))
                   (then
                    (if (i32.eqz (ref.test (ref i31) (local.get $src-start-raw)))
                        (then (call $raise-string-copy!:bad-source-start)))
                    (if (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $src-start-raw))) (i32.const 1)) (i32.const 0))
                        (then (call $raise-string-copy!:bad-source-start)))))
               ;; src-end optional
               (if (i32.eqz (ref.eq (local.get $src-end-raw) (global.get $missing)))
                   (then
                    (if (i32.eqz (ref.test (ref i31) (local.get $src-end-raw)))
                        (then (call $raise-string-copy!:bad-source-end)))
                    (if (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $src-end-raw))) (i32.const 1)) (i32.const 0))
                        (then (call $raise-string-copy!:bad-source-end)))))
               ;; --- Decode ---
               (local.set $dst       (ref.cast (ref $String) (local.get $dst-raw)))
               (local.set $src       (ref.cast (ref $String) (local.get $src-raw)))
               (local.set $dst-start (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $dst-start-raw))) (i32.const 1)))
               (local.set $src-len   (call $string-length/checked/i32 (local.get $src)))
               (if (ref.eq (local.get $src-start-raw) (global.get $missing))
                   (then (local.set $src-start (i32.const 0)))
                   (else (local.set $src-start (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $src-start-raw))) (i32.const 1)))))
               (if (ref.eq (local.get $src-end-raw) (global.get $missing))
                   (then (local.set $src-end (local.get $src-len)))
                   (else (local.set $src-end (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $src-end-raw))) (i32.const 1)))))
               ;; --- Mutability Check ---
               (if (i32.ne (struct.get $String $immutable (local.get $dst)) (i32.const 0))
                   (then (call $raise-immutable-string (local.get $dst))))
               ;; --- Range Validation ---
               (local.set $dst-len (call $string-length/checked/i32 (local.get $dst)))
               (if (i32.gt_u (local.get $src-start) (local.get $src-end))
                   (then (call $raise-string-copy!:bad-source-range)))
               (if (i32.gt_u (local.get $src-end) (local.get $src-len))
                   (then (call $raise-string-copy!:bad-source-range)))
               (if (i32.gt_u
                    (i32.add (local.get $dst-start)
                             (i32.sub (local.get $src-end) (local.get $src-start)))
                    (local.get $dst-len))
                   (then (call $raise-string-copy!:bad-destination-range)))
               ;; --- Delegate ---
               (call $string-copy!/checked
                     (local.get $dst)
                     (local.get $dst-start)
                     (local.get $src)
                     (local.get $src-start)
                     (local.get $src-end))
               ;; --- Invalidate hash ---
               (struct.set $String $hash (local.get $dst) (i32.const 0))
               ;; --- Return ---
               (global.get $void))


         (func $raise-string-copy!/checked:out-of-bounds (unreachable))

         (func $string-copy!/checked
               (param $dst        (ref $String)) ;; Destination string
               (param $dst-start  i32)           ;; Start index in destination
               (param $src        (ref $String)) ;; Source string
               (param $src-start  i32)           ;; Start index in source
               (param $src-end    i32)           ;; End index in source (exclusive)

               (local $dst-len i32)
               (local $src-len i32)
               (local $len     i32)

               ;; --- Compute source slice length ---
               (local.set $len (i32.sub (local.get $src-end) (local.get $src-start)))
               ;; --- Range Checks ---
               (if (i32.lt_u (local.get $src-end) (local.get $src-start))
                   (then (call $raise-string-copy!/checked:out-of-bounds)))
               (local.set $dst-len (call $string-length/checked/i32 (local.get $dst)))
               (local.set $src-len (call $string-length/checked/i32 (local.get $src)))
               (if (i32.gt_u (i32.add (local.get $dst-start) (local.get $len)) (local.get $dst-len))
                   (then (call $raise-string-copy!/checked:out-of-bounds)))
               (if (i32.gt_u (local.get $src-end) (local.get $src-len))
                   (then (call $raise-string-copy!/checked:out-of-bounds)))
               ;; --- Copy elements ---
               (call $i32array-copy!
                     (struct.get $String $codepoints (local.get $dst))
                     (local.get $dst-start)
                     (struct.get $String $codepoints (local.get $src))
                     (local.get $src-start)
                     (local.get $src-end))
               ;; --- Invalidate destination hash ---
               (struct.set $String $hash (local.get $dst) (i32.const 0)))



         (func $array-of-strings->string
               (param $arr (ref $Array))
               (result (ref $String))

               (local $n     i32)
               (local $i     i32)
               (local $total i32)
               (local $s     (ref $String))
               (local $len   i32)
               (local $dst   (ref $String))
               (local $pos   i32)

               ;; Pass 1: compute total length
               (local.set $n     (array.len (local.get $arr)))
               (local.set $i     (i32.const 0))
               (local.set $total (i32.const 0))

               (block $count-done
                      (loop $count-loop
                            (br_if $count-done (i32.ge_u (local.get $i) (local.get $n)))
                            (local.set $s     (ref.cast (ref $String) (array.get $Array (local.get $arr) (local.get $i))))
                            (local.set $len   (call $string-length/checked/i32 (local.get $s)))
                            (local.set $total (i32.add (local.get $total) (local.get $len)))
                            (local.set $i     (i32.add (local.get $i) (i32.const 1)))
                            (br $count-loop)))
               ;; Allocate destination string
               (local.set $dst (call $make-string/checked (local.get $total) (i32.const 0)))
               ;; Pass 2: copy individual strings into destination
               (local.set $i   (i32.const 0))
               (local.set $pos (i32.const 0))
               (block $copy-done
                      (loop $copy-loop
                            (br_if $copy-done (i32.ge_u (local.get $i) (local.get $n)))
                            (local.set $s   (ref.cast (ref $String) (array.get $Array (local.get $arr) (local.get $i))))
                            (local.set $len (call $string-length/checked/i32 (local.get $s)))
                            (call $string-copy!/checked (local.get $dst) (local.get $pos) (local.get $s) (i32.const 0) (local.get $len))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                            (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                            (br $copy-loop)))
               (local.get $dst))

         (func $growable-array-of-strings->string
               (param $g (ref $GrowableArray))
               (result (ref $String))
               ;; Convert growable array to normal array and concatenate its strings
               (call $array-of-strings->string
                     (call $growable-array->array (local.get $g))))


         (func $string-take (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq))  ; an (ref $String)

               (local $str   (ref $String))
               (local $n/tag i32)
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (if (i32.eqz (ref.test (ref i31) (local.get $n)))
                   (then (call $raise-check-fixnum (local.get $n))))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/tag (i31.get_u (ref.cast (ref i31) (local.get $n))))

               (if (i32.and (local.get $n/tag) (i32.const 1))
                   (then (call $raise-check-fixnum (local.get $n))))
               (local.set $n/i32 (i32.shr_u (local.get $n/tag) (i32.const 1)))

               (local.set $len
                          (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-bad-string-index/i32
                               (local.get $s) (local.get $n/i32))))

               (call $string-take/checked (local.get $str) (local.get $n/i32)))

         (func $string-take/checked
               (param $s (ref $String)) (param $n i32)
               (result (ref $String))
               (call $i32array->string
                     (call $i32array-take
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))



         (func $string-take-right (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq))  ; an (ref $String)

               (local $str   (ref $String))
               (local $n/tag i32)
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (if (i32.eqz (ref.test (ref i31) (local.get $n)))
                   (then (call $raise-check-fixnum (local.get $n))))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/tag (i31.get_u (ref.cast (ref i31) (local.get $n))))
               (if (i32.and (local.get $n/tag) (i32.const 1))
                   (then (call $raise-check-fixnum (local.get $n))))
               (local.set $n/i32 (i32.shr_u (local.get $n/tag) (i32.const 1)))

               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-bad-string-index/i32 (local.get $s) (local.get $n/i32))
                         (unreachable)))

               (call $string-take-right/checked (local.get $str) (local.get $n/i32)))

         (func $string-take-right/checked
               (param $s (ref $String))
               (param $n i32)
               (result   (ref $String))

               (call $i32array->string
                     (call $i32array-take-right
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))

         (func $string-drop (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq))  ; an (ref $String)

               (local $str   (ref $String))
               (local $n/tag i32)
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (if (i32.eqz (ref.test (ref i31) (local.get $n)))
                   (then (call $raise-check-fixnum (local.get $n))))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/tag (i31.get_u (ref.cast (ref i31) (local.get $n))))
               (if (i32.and (local.get $n/tag) (i32.const 1))
                   (then (call $raise-check-fixnum (local.get $n))))
               (local.set $n/i32 (i32.shr_u (local.get $n/tag) (i32.const 1)))

               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-bad-string-index/i32 (local.get $s) (local.get $n/i32))))

               (call $string-drop/checked (local.get $str) (local.get $n/i32)))

         (func $string-drop/checked
               (param $s (ref $String)) (param $n i32)
               (result (ref $String))
               (call $i32array->string
                     (call $i32array-drop
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))

         (func $string-drop-right (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq)) ; an (ref $String)

               (local $str   (ref $String))
               (local $n/tag i32)
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (if (i32.eqz (ref.test (ref i31) (local.get $n)))
                   (then (call $raise-check-fixnum (local.get $n))))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/tag (i31.get_u (ref.cast (ref i31) (local.get $n))))
               (if (i32.and (local.get $n/tag) (i32.const 1))
                   (then (call $raise-check-fixnum (local.get $n))))
               (local.set $n/i32 (i32.shr_u (local.get $n/tag) (i32.const 1)))

               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-bad-string-index/i32 (local.get $s) (local.get $n/i32))))

               (call $string-drop-right/checked (local.get $str) (local.get $n/i32)))

         (func $string-drop-right/checked
               (param $s (ref $String)) (param $n i32)
               (result (ref $String))
               (call $i32array->string
                     (call $i32array-drop-right
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))





         (func $raise-argument-error:string-expected (unreachable))

         (func $bomb (unreachable))





         (func $string-trim-right (type $Prim2)
               (param $s       (ref eq))   ;; any value, must be a string
               (param $sep     (ref eq))   ;; a character (tagged i31) or #f
               (result         (ref eq))   ;; an (ref $String)

               (local $str     (ref $String))
               (local $len     i32)
               (local $new-len i32)
               (local $sep/tag i32) ;; still-tagged char
               (local $sep-ch  i32) ;; decoded code point
               (local $use-whitespace? i32)
               (local $ch      i32)

               ;; --- Type check inputs ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected (local.get $s))
                         (unreachable)))

               (if (ref.eq (local.get $sep) (global.get $false))
                   (then (local.set $use-whitespace? (i32.const 1)))
                   (else
                    (if (i32.eqz (ref.test (ref i31) (local.get $sep)))
                        (then (call $raise-argument-error:char-expected (local.get $sep))
                              (unreachable)))
                    (local.set $sep/tag (i31.get_u (ref.cast (ref i31) (local.get $sep))))
                    (if (i32.ne (i32.and (local.get $sep/tag) (i32.const ,char-mask))
                                (i32.const ,char-tag))
                        (then (call $raise-argument-error:char-expected (local.get $sep))
                              (unreachable)))
                    (local.set $use-whitespace? (i32.const 0))))

               ;; --- Decode after checks ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (if (i32.eq (local.get $use-whitespace?) (i32.const 0))
                   (then (local.set $sep-ch (i32.shr_u (local.get $sep/tag) (i32.const ,char-shift)))))

               ;; --- Get length ---
               (local.set $len     (call $string-length/checked/i32 (local.get $str)))
               (local.set $new-len (local.get $len))

               ;; --- Scan backward ---
               (block $done
                      (loop $scan
                            (br_if $done (i32.eqz (local.get $new-len)))
                            (local.set $ch
                                       (call $string-ref/checked/i32
                                             (local.get $str)
                                             (i32.sub (local.get $new-len) (i32.const 1))))

                            (if (i32.eq (local.get $use-whitespace?) (i32.const 1))
                                ;; --- Trim if whitespace ---
                                (then
                                 (if (ref.eq (call $char-whitespace?/ucs (local.get $ch))
                                             (global.get $true))
                                     (then
                                      (local.set $new-len (i32.sub (local.get $new-len) (i32.const 1)))
                                      (br $scan))))
                                ;; --- Else trim if equals sep-ch ---
                                (else
                                 (if (i32.eq (local.get $ch) (local.get $sep-ch))
                                     (then
                                      (local.set $new-len (i32.sub (local.get $new-len) (i32.const 1)))
                                      (br $scan))))))
                      )

               ;; --- Return result ---
               (if (i32.eq (local.get $new-len) (local.get $len))
                   (then (return (local.get $str)))
                   (else (return (call $string-take/checked (local.get $str) (local.get $new-len)))))

               (unreachable))

         (func $string-trim-left (type $Prim2)
               (param $s   (ref eq))   ;; any value, must be a string
               (param $sep (ref eq))   ;; a character (i31) or #f
               (result     (ref eq))   ;; an (ref $String)

               (local $str     (ref $String))
               (local $len     i32)
               (local $i       i32)
               (local $sep-ch  i32)
               (local $use-whitespace? i32) ;; boolean flag
               (local $sep/tag i32)
               (local $ch      i32)

               ;; --- Check inputs ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected (local.get $s))
                         (unreachable)))

               (if (ref.eq (local.get $sep) (global.get $false))
                   (then (local.set $use-whitespace? (i32.const 1)))
                   (else
                    ;; Check: is it a (ref i31)?
                    (if (i32.eqz (ref.test (ref i31) (local.get $sep)))
                        (then (call $raise-argument-error:char-expected
                                    (local.get $sep))
                              (unreachable)))
                    ;; Extract raw tagged value
                    (local.set $sep/tag
                               (i31.get_u (ref.cast (ref i31) (local.get $sep))))
                    ;; Check tag matches ,char-tag
                    (if (i32.ne (i32.and (local.get $sep/tag) (i32.const ,char-mask))
                                (i32.const ,char-tag))
                        (then (call $raise-argument-error:char-expected
                                    (local.get $sep))
                              (unreachable)))
                    ;; Passed: decode
                    (local.set $use-whitespace? (i32.const 0))
                    (local.set $sep-ch (i32.shr_u (local.get $sep/tag)
                                                  (i32.const ,char-shift)))))
               ;; --- Decode after checks ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; --- Get string length (as i32) ---
               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (local.set $i   (i32.const 0))
               ;; --- Scan forward ---
               (block $done
                      (loop $scan
                            (br_if $done (i32.eq (local.get $i) (local.get $len)))

                            (local.set $ch (call $string-ref/checked/i32
                                                 (local.get $str)
                                                 (local.get $i)))

                            (if (i32.eq (local.get $use-whitespace?) (i32.const 1))
                                ;; --- Trim if character is whitespace ---
                                (then (if (ref.eq (call $char-whitespace?/ucs (local.get $ch))
                                                  (global.get $true))
                                          (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                                (br $scan))))
                                ;; --- Else trim if char equals $sep-ch ---
                                (else (if (i32.eq (local.get $ch) (local.get $sep-ch))
                                          (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                                (br $scan)))))))

               ;; --- Return result ---
               (if (i32.eqz (local.get $i))
                   (then (return (local.get $str)))
                   (else (return (call $string-drop
                                       (local.get $str)
                                       (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))))
               (unreachable))


         (func $string-trim (type $Prim15)
               (param $s       (ref eq))   ;; string?
               (param $sep     (ref eq))   ;; optional string?, default = " "
               (param $left?   (ref eq))   ;; optional any/c, default = #t
               (param $right?  (ref eq))   ;; optional any/c, default = #t
               (param $repeat? (ref eq))   ;; optional any/c, default = #f
               (result         (ref eq))

               (local $str             (ref $String))
               (local $sep-str         (ref $String))
               (local $result          (ref $String))
               (local $use-whitespace? i32)
               (local $trim-left?      i32)
               (local $trim-right?     i32)
               (local $repeat-flag     i32)
               (local $sep-len         i32)

               ;; NOTE: WebRacket does not yet support keyword arguments or regular-expression separators here.

               ;; --- Initilize non-defaultable ---
               (local.set $str     (ref.cast (ref $String) (global.get $string:empty)))
               (local.set $sep-str (ref.cast (ref $String) (global.get $string:empty)))
               ; (local.set $str (ref.cast (ref $String) (global.get $string:empty)))

               ;; --- Check and decode required string argument ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (local.set $str    (ref.cast (ref $String) (local.get $s)))
               (local.set $result (local.get $str))
               ;; --- Handle optional separator (defaults to whitespace trimming) ---
               (if (ref.eq (local.get $sep) (global.get $missing))
                   (then (local.set $use-whitespace? (i32.const 1)))
                   (else (if (i32.eqz (ref.test (ref $String) (local.get $sep)))
                             (then (call $raise-check-string (local.get $sep))))
                         (local.set $sep-str (ref.cast (ref $String) (local.get $sep)))
                         (local.set $use-whitespace? (i32.const 0))))
               ;; --- Decode left? flag (default #t) ---
               (if (ref.eq (local.get $left?) (global.get $missing))
                   (then (local.set $trim-left? (i32.const 1)))
                   (else (local.set $trim-left?
                                    (if (result i32)
                                        (ref.eq (local.get $left?) (global.get $false))
                                        (then (i32.const 0))
                                        (else (i32.const 1))))))
               ;; --- Decode right? flag (default #t) ---
               (if (ref.eq (local.get $right?) (global.get $missing))
                   (then (local.set $trim-right? (i32.const 1)))
                   (else (local.set $trim-right?
                                    (if (result i32)
                                        (ref.eq (local.get $right?) (global.get $false))
                                        (then (i32.const 0))
                                        (else (i32.const 1))))))
               ;; --- Decode repeat? flag (default #f) ---
               (if (ref.eq (local.get $repeat?) (global.get $missing))
                   (then (local.set $repeat-flag (i32.const 0)))
                   (else (local.set $repeat-flag
                                    (if (result i32)
                                        (ref.eq (local.get $repeat?) (global.get $false))
                                        (then (i32.const 0))
                                        (else (i32.const 1))))))
               ;; --- Whitespace trimming delegates to existing helpers ---
               (if (i32.eq (local.get $use-whitespace?) (i32.const 1))
                   (then
                    (if (local.get $trim-left?)
                        (then (local.set $result
                                         (ref.cast (ref $String)
                                                   (call $string-trim-left
                                                         (local.get $result)
                                                         (global.get $false))))))
                    (if (local.get $trim-right?)
                        (then (local.set $result
                                         (ref.cast (ref $String)
                                                   (call $string-trim-right
                                                         (local.get $result)
                                                         (global.get $false))))))
                    (return (local.get $result))))
               ;; --- Literal separator trimming ---
               (local.set $sep-len (call $string-length/checked/i32 (local.get $sep-str)))
               (if (i32.eqz (local.get $sep-len))
                   (then (return (local.get $result))))
               ;; Trim left side if requested
               (if (local.get $trim-left?)
                   (then
                    (block $left-done
                           (loop $left-loop
                                 (br_if $left-done
                                        (i32.eqz (call $string-prefix?/i32/checked
                                                       (local.get $result)
                                                       (local.get $sep-str))))
                                 (local.set $result
                                            (call $string-drop/checked
                                                  (local.get $result)
                                                  (local.get $sep-len)))
                                 (if (i32.eqz (local.get $repeat-flag))
                                     (then (br $left-done)))
                                 (br $left-loop)))))
               ;; Trim right side if requested
               (if (local.get $trim-right?)
                   (then
                    (block $right-done
                           (loop $right-loop
                                 (br_if $right-done
                                        (i32.eqz (call $string-suffix?/i32/checked
                                                       (local.get $result)
                                                       (local.get $sep-str))))
                                 (local.set $result
                                            (call $string-drop-right/checked
                                                  (local.get $result)
                                                  (local.get $sep-len)))
                                 (if (i32.eqz (local.get $repeat-flag))
                                     (then (br $right-done)))
                                 (br $right-loop)))))

               (local.get $result))



         ;; 4.4.6 Additional String Functions  (racket/string)

         (func $string-suffix? (type $Prim2)
               (param $s (ref eq)) (param $suffix (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (call $string-suffix?/i32 (local.get $s) (local.get $suffix))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $string-suffix?/i32
               (param $s-raw (ref eq)) (param $suffix-raw (ref eq))
               (result i32)

               (local $s (ref $String))
               (local $suf (ref $String))

               ;; Type checks
               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (return (i32.const 0))))
               (if (i32.eqz (ref.test (ref $String) (local.get $suffix-raw)))
                   (then (return (i32.const 0))))

               ;; Cast and delegate
               (local.set $s   (ref.cast (ref $String) (local.get $s-raw)))
               (local.set $suf (ref.cast (ref $String) (local.get $suffix-raw)))
               (return_call $string-suffix?/i32/checked (local.get $s) (local.get $suf)))

         (func $string-suffix?/i32/checked
               (param $s (ref $String)) (param $suf (ref $String))
               (result i32)

               (local $arr-s   (ref $I32Array))
               (local $arr-suf (ref $I32Array))
               (local $len-s   i32)
               (local $len-suf i32)
               (local $offset  i32)
               (local $i       i32)

               (local.set $arr-s   (struct.get $String $codepoints (local.get $s)))
               (local.set $arr-suf (struct.get $String $codepoints (local.get $suf)))
               (local.set $len-s   (array.len (local.get $arr-s)))
               (local.set $len-suf (array.len (local.get $arr-suf)))

               ;; If suffix longer than string, fail
               (if (i32.gt_u (local.get $len-suf) (local.get $len-s))
                   (then (return (i32.const 0))))

               (local.set $offset (i32.sub (local.get $len-s) (local.get $len-suf)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len-suf)))
                            (if (i32.ne
                                 (array.get $I32Array (local.get $arr-s)
                                            (i32.add (local.get $offset) (local.get $i)))
                                 (array.get $I32Array (local.get $arr-suf) (local.get $i)))
                                (then (return (i32.const 0))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (i32.const 1))

         (func $string-prefix? (type $Prim2)
               (param $s (ref eq)) (param $prefix (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string-prefix?/i32 (local.get $s) (local.get $prefix))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $string-prefix?/i32
               (param $s-raw (ref eq)) (param $prefix-raw (ref eq))
               (result i32)

               (local $s (ref $String))
               (local $p (ref $String))

               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (call $raise-check-string (local.get $s-raw))))
               (if (i32.eqz (ref.test (ref $String) (local.get $prefix-raw)))
                   (then (call $raise-check-string (local.get $prefix-raw))))

               (local.set $s (ref.cast (ref $String) (local.get $s-raw)))
               (local.set $p (ref.cast (ref $String) (local.get $prefix-raw)))

               (return_call $string-prefix?/i32/checked (local.get $s) (local.get $p)))

         (func $string-prefix?/i32/checked
               (param $s (ref $String)) (param $p (ref $String))
               (result i32)

               (local $arr-s (ref $I32Array))
               (local $arr-p (ref $I32Array))
               (local $len-s i32)
               (local $len-p i32)
               (local $i i32)
               (local $cp-s i32)
               (local $cp-p i32)

               (local.set $arr-s (struct.get $String $codepoints (local.get $s)))
               (local.set $arr-p (struct.get $String $codepoints (local.get $p)))
               (local.set $len-s (array.len (local.get $arr-s)))
               (local.set $len-p (array.len (local.get $arr-p)))
               (if (i32.lt_u (local.get $len-s) (local.get $len-p))
                   (then (return (i32.const 0))))
               (local.set $i (i32.const 0))
               (block $exit
                      (loop $loop
                            (br_if $exit (i32.ge_u (local.get $i) (local.get $len-p)))
                            (local.set $cp-s (array.get $I32Array (local.get $arr-s) (local.get $i)))
                            (local.set $cp-p (array.get $I32Array (local.get $arr-p) (local.get $i)))
                            (if (i32.ne (local.get $cp-s) (local.get $cp-p))
                                (then (return (i32.const 0))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (i32.const 1))

         (func $string-contains? (type $Prim2)
               (param $s         (ref eq)) ;; string?
               (param $contained (ref eq)) ;; string?
               (result           (ref eq))

               ;; Delegate to string-find and report only presence.
               (if (result (ref eq))
                   (ref.eq (call $string-find (local.get $s) (local.get $contained))
                           (global.get $false))
                   (then (global.get $false))
                   (else (global.get $true))))

         (func $string-find (type $Prim2)
               (param $s (ref eq))
               (param $contained (ref eq))
               (result (ref eq))

               (local $str    (ref $String))
               (local $sub    (ref $String))
               (local $arr-s  (ref $I32Array))
               (local $arr-c  (ref $I32Array))
               (local $len-s  i32)
               (local $len-c  i32)
               (local $limit  i32)
               (local $i      i32)
               (local $j      i32)
               (local $ch-s   i32)
               (local $ch-c   i32)

               ;; --- Check inputs ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected (local.get $s))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $String) (local.get $contained)))
                   (then (call $raise-argument-error:string-expected (local.get $contained))
                         (unreachable)))

               ;; --- Decode after checks ---
               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $sub   (ref.cast (ref $String) (local.get $contained)))
               (local.set $arr-s (struct.get $String $codepoints (local.get $str)))
               (local.set $arr-c (struct.get $String $codepoints (local.get $sub)))
               (local.set $len-s (array.len (local.get $arr-s)))
               (local.set $len-c (array.len (local.get $arr-c)))

               ;; --- Edge cases ---
               (if (i32.eqz (local.get $len-c))
                   (then (return (global.get $zero))))
               (if (i32.lt_u (local.get $len-s) (local.get $len-c))
                   (then (return (global.get $false))))

               (local.set $limit (i32.sub (local.get $len-s) (local.get $len-c)))
               (local.set $i     (i32.const 0))
               (block $not-found
                      (loop $outer
                            (br_if $not-found
                                   (i32.gt_u (local.get $i) (local.get $limit)))
                            (local.set $j (i32.const 0))
                            (block $mismatch
                                   (loop $inner
                                         (br_if $mismatch
                                                (i32.ge_u (local.get $j) (local.get $len-c)))
                                         (local.set $ch-s
                                                    (call $i32array-ref
                                                          (local.get $arr-s)
                                                          (i32.add (local.get $i) (local.get $j))))
                                         (local.set $ch-c
                                                    (call $i32array-ref
                                                          (local.get $arr-c)
                                                          (local.get $j)))
                                         (if (i32.ne (local.get $ch-s) (local.get $ch-c))
                                             (then (br $mismatch)))
                                         (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                         (br $inner)))
                            (if (i32.eq (local.get $j) (local.get $len-c))
                                (then (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $outer)))
               (global.get $false))


        (func $string-replace (type $Prim34)
              (param $s     (ref eq)) ;; string?
              (param $from  (ref eq)) ;; string?
              (param $to    (ref eq)) ;; string?
              (param $all?  (ref eq)) ;; boolean?, optional with default #t
              (result        (ref eq))

              (local $str      (ref $String))
              (local $f        (ref $String))
              (local $t        (ref $String))
              (local $arr-s    (ref $I32Array))
              (local $arr-f    (ref $I32Array))
              (local $arr-t    (ref $I32Array))
              (local $n        i32)
              (local $m        i32)
              (local $r        i32)
              (local $idxs     (ref $I32GrowableArray))
              (local $limit    i32)
              (local $i        i32)
              (local $j        i32)
              (local $k        i32)
              (local $res-len  i32)
              (local $res      (ref $I32Array))
              (local $dst      i32)
              (local $src      i32)
              (local $idx      i32)

              ;; Handle optional all? with default #t
              (if (ref.eq (local.get $all?) (global.get $missing))
                  (then (local.set $all? (global.get $true))))

              ;; Type checks
              (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                  (then (call $raise-check-string (local.get $s))))
              (if (i32.eqz (ref.test (ref $String) (local.get $from)))
                  (then (call $raise-check-string (local.get $from))))
              (if (i32.eqz (ref.test (ref $String) (local.get $to)))
                  (then (call $raise-check-string (local.get $to))))
              (if (ref.eq (call $boolean? (local.get $all?)) (global.get $false))
                  (then (call $raise-argument-error/internal (local.get $all?))
                        (unreachable)))

              ;; Decode after checks
              (local.set $str   (ref.cast (ref $String) (local.get $s)))
              (local.set $f     (ref.cast (ref $String) (local.get $from)))
              (local.set $t     (ref.cast (ref $String) (local.get $to)))
              (local.set $arr-s (struct.get $String $codepoints (local.get $str)))
              (local.set $arr-f (struct.get $String $codepoints (local.get $f)))
              (local.set $arr-t (struct.get $String $codepoints (local.get $t)))
              (local.set $n     (array.len (local.get $arr-s)))
              (local.set $m     (array.len (local.get $arr-f)))
              (local.set $r     (array.len (local.get $arr-t)))

              ;; Collect match indices
              (local.set $idxs (call $make-i32growable-array (i32.const 4)))
              (if (i32.eqz (local.get $m))
                  (then
                   (if (ref.eq (local.get $all?) (global.get $false))
                       (then (call $i32growable-array-add! (local.get $idxs) (i32.const 0)))
                       (else
                        (local.set $i (i32.const 0))
                        (block $done
                               (loop $loop
                                     (br_if $done (i32.gt_u (local.get $i) (local.get $n)))
                                     (call $i32growable-array-add! (local.get $idxs) (local.get $i))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $loop))))))
                  (else
                   (local.set $limit (i32.sub (local.get $n) (local.get $m)))
                   (local.set $i (i32.const 0))
                   (if (ref.eq (local.get $all?) (global.get $false))
                       (then
                        (block $done
                               (loop $loop
                                     (br_if $done (i32.gt_u (local.get $i) (local.get $limit)))
                                     (local.set $j (i32.const 0))
                                     (block $mismatch
                                            (loop $inner
                                                  (br_if $mismatch (i32.ge_u (local.get $j) (local.get $m)))
                                                  (br_if $mismatch
                                                         (i32.ne
                                                          (call $i32array-ref
                                                                (local.get $arr-s)
                                                                (i32.add (local.get $i) (local.get $j)))
                                                          (call $i32array-ref (local.get $arr-f) (local.get $j))))
                                                  (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                                  (br $inner)))
                                     (if (i32.eq (local.get $j) (local.get $m))
                                         (then (call $i32growable-array-add! (local.get $idxs) (local.get $i))
                                               (br $done)))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $loop))))
                       (else
                        (block $end
                               (loop $loop
                                     (br_if $end (i32.gt_u (local.get $i) (local.get $limit)))
                                     (local.set $j (i32.const 0))
                                     (block $mismatch
                                            (loop $inner
                                                  (br_if $mismatch (i32.ge_u (local.get $j) (local.get $m)))
                                                  (br_if $mismatch
                                                         (i32.ne
                                                          (call $i32array-ref
                                                                (local.get $arr-s)
                                                                (i32.add (local.get $i) (local.get $j)))
                                                          (call $i32array-ref (local.get $arr-f) (local.get $j))))
                                                  (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                                  (br $inner)))
                                     (if (i32.eq (local.get $j) (local.get $m))
                                         (then (call $i32growable-array-add! (local.get $idxs) (local.get $i))
                                               (local.set $i (i32.add (local.get $i) (local.get $m)))
                                               (br $loop)))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $loop)))))))

              (local.set $k (call $i32growable-array-count (local.get $idxs)))
              (if (i32.eqz (local.get $k))
                  (then (return (local.get $str))))

              (local.set $res-len
                        (i32.add (local.get $n)
                                 (i32.mul (local.get $k)
                                          (i32.sub (local.get $r) (local.get $m)))))
              (local.set $res (array.new_default $I32Array (local.get $res-len)))
              (local.set $dst (i32.const 0))
              (local.set $src (i32.const 0))
              (local.set $i   (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $k)))
                           (local.set $idx (call $i32growable-array-ref (local.get $idxs) (local.get $i)))
                           (call $i32array-copy!
                                 (local.get $res) (local.get $dst)
                                 (local.get $arr-s) (local.get $src) (local.get $idx))
                           (local.set $dst (i32.add (local.get $dst)
                                                    (i32.sub (local.get $idx) (local.get $src))))
                           (call $i32array-copy!
                                 (local.get $res) (local.get $dst)
                                 (local.get $arr-t) (i32.const 0) (local.get $r))
                           (local.set $dst (i32.add (local.get $dst) (local.get $r)))
                           (local.set $src (i32.add (local.get $idx) (local.get $m)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (call $i32array-copy!
                    (local.get $res) (local.get $dst)
                    (local.get $arr-s) (local.get $src) (local.get $n))
              (struct.new $String
                          (i32.const 0)
                          (i32.const 0)
                          (local.get $res)))


         ;;;
         ;;; 4.6 Characters
         ;;;

         ;;   Character helpers are implemented in runtime-wasm/core/characters.rkt.
         ,@(for/list ([name (in-list character-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 4.7 SYMBOLS
         ;;;

         ;;   Symbol helpers are implemented in runtime-wasm/core/symbols.rkt.
         ,@(for/list ([name (in-list symbol-public-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         (global $gensym-counter (mut i32) (i32.const 0))

         ;;   Gensym helpers are implemented in runtime-wasm/core/symbols.rkt.
         ,@(for/list ([name (in-list symbol-gensym-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 4.8 REGULAR EXPRESSIONS
         ;;;

         ;;   Regular expression helpers are implemented in runtime-wasm/core/regexps.rkt.
         ,@(for/list ([name (in-list regexp-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 4.9 KEYWORDS
         ;;;

         ;;   Keyword helpers are implemented in runtime-wasm/core/keywords.rkt.
         ,(core-runtime-helper-form core-runtime-helper-index '$keyword?/i32)
         ,@(for/list ([name (in-list keyword-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 4.10 Pairs and lists
         ;;;

         ;; https://docs.racket-lang.org/reference/pairs.html

         (global $dummy-pair (ref $Pair)
                 (struct.new $Pair
                             (i32.const 0)            ;; hash = 0
                             (global.get $false)      ;; a = null
                             (global.get $false)))    ;; d = null

         ;; Pair/list related exceptions
         ;;   Implemented in runtime-wasm/core/lists.rkt.
         ,@(for/list ([name (in-list list-error-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form core-runtime-helper-index '$pair?)

         ,(core-runtime-helper-form core-runtime-helper-index '$cons?)

         ,(core-runtime-helper-form core-runtime-helper-index '$null?)

         ,(core-runtime-helper-form core-runtime-helper-index '$empty?)

         ,(core-runtime-helper-form core-runtime-helper-index '$cons)

         ,(core-runtime-helper-form core-runtime-helper-index '$list*)

         ,(core-runtime-helper-form runtime-helper-index '$car)

         ,(core-runtime-helper-form runtime-helper-index '$cdr)

         ,@(for/list ([name (in-list pair-accessor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form core-runtime-helper-index '$list?)

         ,(core-runtime-helper-form core-runtime-helper-index '$list)

         ,(core-runtime-helper-form runtime-helper-index '$length/i32)

         ,(core-runtime-helper-form runtime-helper-index '$length)

         ,(core-runtime-helper-form runtime-helper-index '$list-ref/checked)

         ,(core-runtime-helper-form runtime-helper-index '$list-ref)

         ;; first through fifteenth
         ;;   Implemented in runtime-wasm/core/lists.rkt.
         ,@(for/list ([name (in-list list-ordinal-accessor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        ,(core-runtime-helper-form runtime-helper-index '$rest)

        ,(core-runtime-helper-form core-runtime-helper-index '$last-pair/checked)

        ,(core-runtime-helper-form runtime-helper-index '$last)

        ,(core-runtime-helper-form runtime-helper-index '$last-pair)

        ,(core-runtime-helper-form runtime-helper-index '$list-tail/checked/who)

        ,(core-runtime-helper-form runtime-helper-index '$list-tail/checked)

        ,(core-runtime-helper-form runtime-helper-index '$list-tail)

        ,(core-runtime-helper-form runtime-helper-index '$list-set/checked)

        ,(core-runtime-helper-form runtime-helper-index '$list-set)


        ,(core-runtime-helper-form runtime-helper-index '$drop/who)

        ,(core-runtime-helper-form runtime-helper-index '$drop)

        ,(core-runtime-helper-form runtime-helper-index '$drop-right/who)

        ,(core-runtime-helper-form runtime-helper-index '$drop-right)

        ,(core-runtime-helper-form runtime-helper-index '$dropf)

        ,(core-runtime-helper-form runtime-helper-index '$dropf-right)


        ,(core-runtime-helper-form runtime-helper-index '$split-at)

        ,(core-runtime-helper-form runtime-helper-index '$split-at-right)

        ,(core-runtime-helper-form runtime-helper-index '$splitf-at)

        ,(core-runtime-helper-form runtime-helper-index '$splitf-at-right)


         ,(core-runtime-helper-form runtime-helper-index '$append)

         ,(core-runtime-helper-form runtime-helper-index '$append/2)

         ,(core-runtime-helper-form runtime-helper-index '$qq-append)

         ,(core-runtime-helper-form runtime-helper-index '$append*)

         ,(core-runtime-helper-form runtime-helper-index '$flatten)

         ,(core-runtime-helper-form runtime-helper-index '$reverse)

         ,(core-runtime-helper-form runtime-helper-index '$alt-reverse)

         ,@(for/list ([name (in-list list-member-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$memf)


         ,@(for/list ([name (in-list list-association-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$assf)

         ,(core-runtime-helper-form runtime-helper-index '$findf)

         ,(core-runtime-helper-form runtime-helper-index '$index-of)

         ,(core-runtime-helper-form runtime-helper-index '$index-where)

         ,(core-runtime-helper-form runtime-helper-index '$indexes-of)

         ,(core-runtime-helper-form runtime-helper-index '$indexes-where)


        ,@(for/list ([name (in-list list-group-by-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))



         ,(core-runtime-helper-form runtime-helper-index '$cartesian-product)

         ,(core-runtime-helper-form runtime-helper-index '$permutations)


         ,(core-runtime-helper-form runtime-helper-index '$make-list)

         ,(core-runtime-helper-form core-runtime-helper-index '$make-list/checked)


         ,(core-runtime-helper-form runtime-helper-index '$build-list)

         ,(core-runtime-helper-form runtime-helper-index '$build-list/checked)

         ,(core-runtime-helper-form runtime-helper-index '$range-proc)

         ,(core-runtime-helper-form runtime-helper-index '$range)

         ,(core-runtime-helper-form runtime-helper-index '$range/fixnum)

         ,(core-runtime-helper-form runtime-helper-index '$range/flonum)

         ,(core-runtime-helper-form runtime-helper-index '$inclusive-range-proc)

         ,(core-runtime-helper-form runtime-helper-index '$inclusive-range)

         ,(core-runtime-helper-form runtime-helper-index '$inclusive-range/fixnum)

         ,(core-runtime-helper-form runtime-helper-index '$inclusive-range/flonum)

         ,(core-runtime-helper-form runtime-helper-index '$list-update/checked/who)

         ,(core-runtime-helper-form runtime-helper-index '$list-update/checked)

         ,(core-runtime-helper-form runtime-helper-index '$list-update)

         ,(core-runtime-helper-form runtime-helper-index '$argmax)

         ,(core-runtime-helper-form runtime-helper-index '$argmin)

         ;; Generic contract-error helpers
         ;;   Implemented in runtime-wasm/core/exceptions.rkt.
         ,@(for/list ([name (in-list exception-contract-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$list-from-range)

         ,(core-runtime-helper-form runtime-helper-index '$list-from-range/checked)

         ,(core-runtime-helper-form runtime-helper-index '$map)



         ,(core-runtime-helper-form runtime-helper-index '$andmap)


         ,(core-runtime-helper-form runtime-helper-index '$ormap)


         ,(core-runtime-helper-form runtime-helper-index '$validate-list-args)

         ,(core-runtime-helper-form runtime-helper-index '$seed-list-args)

         ,(core-runtime-helper-form runtime-helper-index '$append-map)


         ,(core-runtime-helper-form runtime-helper-index '$count)


         ,(core-runtime-helper-form runtime-helper-index '$for-each)

         ,(core-runtime-helper-form runtime-helper-index '$foldl)

         ,(core-runtime-helper-form runtime-helper-index '$foldl/1)

         ,(core-runtime-helper-form runtime-helper-index '$foldl/2)

         ,(core-runtime-helper-form runtime-helper-index '$foldl/n)


         ,(core-runtime-helper-form runtime-helper-index '$foldr)


         ,(core-runtime-helper-form runtime-helper-index '$foldr/1-loop)



         ,(core-runtime-helper-form runtime-helper-index '$foldr/1)

         ,(core-runtime-helper-form runtime-helper-index '$foldr/2-loop)

         ,(core-runtime-helper-form runtime-helper-index '$foldr/2)

         ,(core-runtime-helper-form runtime-helper-index '$foldr/n-loop)

         ,(core-runtime-helper-form runtime-helper-index '$foldr/n)





         ,(core-runtime-helper-form runtime-helper-index '$filter)

         ,(core-runtime-helper-form runtime-helper-index '$filter-map)

         ;; Like filter, but keeps elements for which the predicate returns false
         ,(core-runtime-helper-form runtime-helper-index '$filter-not)

         ,(core-runtime-helper-form runtime-helper-index '$shuffle)

         ,(core-runtime-helper-form runtime-helper-index '$partition)

         ,(core-runtime-helper-form runtime-helper-index '$remove)

         ,(core-runtime-helper-form runtime-helper-index '$remf)

         ,(core-runtime-helper-form runtime-helper-index '$remf*)

        ;; Remove list elements using predicate
         ,(core-runtime-helper-form runtime-helper-index '$remf/impl)





        ,@(for/list ([name (in-list list-remove-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$remove*)

        ;; Iterate through the value list, removing each one in turn
         ,(core-runtime-helper-form runtime-helper-index '$remove*/checked)

        ;; Remove all occurrences of a single value from a list using the comparator
         ,(core-runtime-helper-form runtime-helper-index '$remove*/checked/1)



        ,@(for/list ([name (in-list list-remove-star-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$raise-take:bad-length)

         ,(core-runtime-helper-form runtime-helper-index '$raise-take:bad-length/who)

         ,(core-runtime-helper-form runtime-helper-index '$raise-take-right:bad-length)

         ,(core-runtime-helper-form runtime-helper-index '$raise-take-right:bad-length/who)

         ,(core-runtime-helper-form runtime-helper-index '$take/who)

         ,(core-runtime-helper-form runtime-helper-index '$take)

         ,(core-runtime-helper-form runtime-helper-index '$take-right/who)

         ,(core-runtime-helper-form runtime-helper-index '$take-right)

         ,(core-runtime-helper-form runtime-helper-index '$takef)

         ,(core-runtime-helper-form runtime-helper-index '$takef-right)


         ,(core-runtime-helper-form runtime-helper-index '$list-prefix?)


         ,(core-runtime-helper-form runtime-helper-index '$take-common-prefix)


         ,(core-runtime-helper-form runtime-helper-index '$drop-common-prefix)

         ,(core-runtime-helper-form runtime-helper-index '$split-common-prefix)


         ,(core-runtime-helper-form runtime-helper-index '$add-between)

         ,(core-runtime-helper-form runtime-helper-index '$sort)

         ,(core-runtime-helper-form runtime-helper-index '$sort/expanded-keywords)

         ,(core-runtime-helper-form runtime-helper-index '$sort/keyword-apply)

         ,(core-runtime-helper-form runtime-helper-index '$sort:merge)

         ,(core-runtime-helper-form runtime-helper-index '$sort:merge/key)

         ,(core-runtime-helper-form runtime-helper-index '$sort:split)

         ,(core-runtime-helper-form runtime-helper-index '$sort:merge-sort)

         ,(core-runtime-helper-form runtime-helper-index '$sort:merge-sort/key)

         ,(core-runtime-helper-form runtime-helper-index '$sort:cache-key-pairs)

         ,(core-runtime-helper-form runtime-helper-index '$sort:extract-cached-values)

         ,(core-runtime-helper-form runtime-helper-index '$sort:merge/cached-key)

         ,(core-runtime-helper-form runtime-helper-index '$sort:merge-sort/cached-key)


         ;;;
         ;;; 4.11 Mutable Pairs and lists
         ;;;

         ;; https://docs.racket-lang.org/reference/mpairs.html

        ;; Mutable pairs are similar to pairs but allow their fields
        ;; to be updated. These operations parallel their immutable
        ;; counterparts above but use the `$MPair` type.

        ;; Mutable pair error helper
        ,(core-runtime-helper-form core-runtime-helper-index '$raise-mpair-expected)

        ;; mpair? : any/c -> boolean?
        ,(core-runtime-helper-form core-runtime-helper-index '$mpair?)

        ;; mcons : any/c any/c -> mpair?
        ,(core-runtime-helper-form core-runtime-helper-index '$mcons)

        ;; mcar : mpair? -> any/c
        ,(core-runtime-helper-form core-runtime-helper-index '$mcar)

        ;; mcdr : mpair? -> any/c
        ,(core-runtime-helper-form core-runtime-helper-index '$mcdr)

        ;; set-mcar! : mpair? any/c -> void?
        ,(core-runtime-helper-form core-runtime-helper-index '$set-mcar!)

        ;; set-mcdr! : mpair? any/c -> void?
        ,(core-runtime-helper-form core-runtime-helper-index '$set-mcdr!)

         ;;;
         ;;; 4.12 Vectors
         ;;;

         ;; https://docs.racket-lang.org/reference/vectors.html

         ;; (type $Vector (sub $Heap
         ;;                      (struct
         ;;                        (field $hash (mut i32))
         ;;                        (field (ref $Array))))))

         ;; Treelists use a 32-way radix tree.
         (global $treelist:BITS      i32 (i32.const 5))
         (global $treelist:MAX_WIDTH i32 (i32.const 32))
         (global $treelist:MASK      i32 (i32.const 31))

         ; The global $dummy-vector is needed when a non-nullable local variable needs
         ; initialization to a default.
         (global $dummy-array (ref $Array) (array.new $Array (global.get $false) (i32.const 0)))
         (global $dummy-treelist-node (ref $TreelistNode)
                 (struct.new $TreelistNode
                             (i32.const 0)           ;; hash
                             (global.get $dummy-array)
                             (ref.null $I32Array)))
         (global $empty-treelist (ref $Treelist)
                 (struct.new $Treelist
                             (i32.const 0)                    ;; hash
                             (global.get $dummy-treelist-node)
                             (i32.const 0)                    ;; size
                             (i32.const 0)))                  ;; height
        (global $dummy-vector (ref $Vector)
                (struct.new $Vector
                            (i32.const 0)          ;; hash
                            (i32.const 0)          ;; mutable
                            (global.get $dummy-array)))

        ;; Vector related exceptions
        ;;   Implemented in runtime-wasm/core/vectors.rkt.
        ,@(for/list ([name (in-list vector-error-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-children)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-sizes)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-leftwise-dense?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-child-count)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-find-child-index/relaxed)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-child-start)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-child-size)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-make-parent-root/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-rebalance-node-count)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-rebalance-pack-sizes)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-pack-children-range/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-rebalance-same-height/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-pack-same-height/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-short-node)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-concat-plan/distribute)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-concat-plan)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-merge-boundary-slots/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-exec-concat-plan/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-rebalance-boundary/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-concat-subtree/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-append2/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-leaf)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-radix)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-capacity)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-height-for-size)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-build-dense-node)

         ,(core-runtime-helper-form runtime-helper-index '$array->treelist/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-build/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-from-node/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-singleton-branch)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-child-sizes/exact)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-copy-into!)

         ,(core-runtime-helper-form runtime-helper-index '$treelist->array/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-split/checked)

         ;; Treelist related exceptions
         ;;   Implemented in runtime-wasm/core/treelists.rkt.
         ,@(for/list ([name (in-list treelist-error-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$treelist?)

         ,(core-runtime-helper-form runtime-helper-index '$treelist)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-empty?)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-length)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-length/checked/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-ref-node/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-ref/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-set/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-can-add-right-fast?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-can-add-left-fast?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-add-right/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-add-left/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-set/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-add/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-ref)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-first)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-last)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-add)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-set)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-slice/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-sublist/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-split-at/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-take)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-drop)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-split-at)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-take-right)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-drop-right)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-sublist)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-reverse/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-reverse/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-reverse)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-size/check)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-valid?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-valid?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-count/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-relaxed-count/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-max-child-count/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-unary-start-depth/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-max-unary-depth/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-debug-shape)


         ,(core-runtime-helper-form runtime-helper-index '$treelist-rest)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-append*-collect-into!)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-append*)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-flatten-into!)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-flatten-into!)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-flatten)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-sort/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-sort)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-map-into!)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-for-each)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-filter-into!)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-find/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-same?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-member?/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-node-index-of/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-map)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-for-each)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-filter)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-find)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-member?)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-index-of)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-append/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-append)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-cons/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-cons)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-insert/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-insert)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-delete/checked)

         ,(core-runtime-helper-form runtime-helper-index '$treelist-delete)

         ,(core-runtime-helper-form runtime-helper-index '$make-treelist)

         ,(core-runtime-helper-form runtime-helper-index '$make-treelist/checked)

         ,(core-runtime-helper-form runtime-helper-index '$vector->treelist)

         ,(core-runtime-helper-form runtime-helper-index '$treelist->vector)

         ,(core-runtime-helper-form runtime-helper-index '$treelist->vector/checked)

         ,(core-runtime-helper-form runtime-helper-index '$list->treelist)

         ,(core-runtime-helper-form runtime-helper-index '$treelist->list)


         ;; make-vector helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-make-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector constructors
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; build-vector helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-build-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector operation helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,(core-runtime-helper-form core-runtime-helper-index '$vector?/i32)
         ,@(for/list ([name (in-list vector-operation-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; Stencil Vectors
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector-mask-width)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-mask-valid?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-popcount/i32)

         ,(core-runtime-helper-form runtime-helper-index '$$make-stencil-vector/checked)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector)

         ,(core-runtime-helper-form runtime-helper-index '$$system-stencil-vector)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector?)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector?)

         ,(core-runtime-helper-form runtime-helper-index '$$system-stencil-vector?)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector-length)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-length)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector-mask)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-mask)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector-ref)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-ref)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector-set!)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-set!)

         ,(core-runtime-helper-form runtime-helper-index '$$stencil-vector-update/core)

         ,(core-runtime-helper-form runtime-helper-index '$stencil-vector-update)

         ,(core-runtime-helper-form runtime-helper-index '$$system-stencil-vector-update)

         ,(core-runtime-helper-form runtime-helper-index '$$system-stencil-vector-truncate!)

         ;; vector copy and conversion helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-copy-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector extend helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-extend-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector append helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-append-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector slice helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-slice-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector/list conversion helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-list-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector map/count helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-map-count-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector argmin/argmax helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-argminmax-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector filter/search helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-filter-search-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; vector sorting helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(for/list ([name (in-list vector-sort-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


        ;;;
        ;;; Boxed (for assignable variables)
        ;;;

	        ;; We use `boxed`, `set-boxed!` and `unboxed` for assignable variables.
	        ;; These "boxes" are not the same as the Racket datatype `box`.
	        ;; See next section.

         ,(core-runtime-helper-form runtime-helper-index '$raise-letrec-placeholder-access)

         ;;;
         ;;; Internal Compiler Boxes
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$boxed)

         ,(core-runtime-helper-form runtime-helper-index '$unboxed)

         ,(core-runtime-helper-form runtime-helper-index '$set-boxed!)

         ,(core-runtime-helper-form runtime-helper-index '$initialize-boxed!)

         ,(core-runtime-helper-form runtime-helper-index '$boxed?)

         ;;;
         ;;; 4.14 Boxes
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$box?)

         ,(core-runtime-helper-form runtime-helper-index '$box)

         ,(core-runtime-helper-form runtime-helper-index '$box-immutable)

         ,(core-runtime-helper-form runtime-helper-index '$unbox)

         ,(core-runtime-helper-form runtime-helper-index '$unbox*)

         ,(core-runtime-helper-form runtime-helper-index '$raise-immutable-box)

         ,(core-runtime-helper-form runtime-helper-index '$set-box!)

         ,(core-runtime-helper-form runtime-helper-index '$set-box*!)

         ,(core-runtime-helper-form runtime-helper-index '$box-cas!)

         ,(core-runtime-helper-form runtime-helper-index '$unsafe-box*-cas!)

         ,(core-runtime-helper-form runtime-helper-index '$make-weak-box)

         ,(core-runtime-helper-form runtime-helper-index '$weak-box?)

         ,(core-runtime-helper-form runtime-helper-index '$weak-box-value)

         ;;;
         ;;; 4.15 Thread Cells
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$make-thread-cell)

         ,(core-runtime-helper-form runtime-helper-index '$thread-cell?)

         ,(core-runtime-helper-form runtime-helper-index '$thread-cell-ref)

         ,(core-runtime-helper-form runtime-helper-index '$thread-cell-set!)

         ,(core-runtime-helper-form runtime-helper-index '$current-thread)

         ,(core-runtime-helper-form runtime-helper-index '$thread?)

         ,(core-runtime-helper-form runtime-helper-index '$thread-dead?)

         ,(core-runtime-helper-form runtime-helper-index '$thread-running?)

         ,(core-runtime-helper-form runtime-helper-index '$thread-group?)

         ,(core-runtime-helper-form runtime-helper-index '$current-thread-group)

         ,(core-runtime-helper-form runtime-helper-index '$make-thread-group)

         ;;;
         ;;; Loggers
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$logger?)

         ,(core-runtime-helper-form runtime-helper-index '$log-receiver?)

         ,(core-runtime-helper-form runtime-helper-index '$make-logger)

         ,(core-runtime-helper-form runtime-helper-index '$make-log-receiver)

         ,(core-runtime-helper-form runtime-helper-index '$logger-name)

         ,(core-runtime-helper-form runtime-helper-index '$current-logger)

         ,(core-runtime-helper-form runtime-helper-index '$log-level?)

         ,(core-runtime-helper-form runtime-helper-index '$log-max-level)

         ,(core-runtime-helper-form runtime-helper-index '$log-message)

         ;;;
         ;;; Events and Channels
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$make-channel)

         ,(core-runtime-helper-form runtime-helper-index '$channel?)

         ,(core-runtime-helper-form runtime-helper-index '$channel-put-evt?)

         ,(core-runtime-helper-form runtime-helper-index '$handle-evt?)

         ,(core-runtime-helper-form runtime-helper-index '$evt?)

         ,(core-runtime-helper-form runtime-helper-index '$channel-put)

         ,(core-runtime-helper-form runtime-helper-index '$channel-try-get)

         ,(core-runtime-helper-form runtime-helper-index '$channel-get)

         ,(core-runtime-helper-form runtime-helper-index '$channel-put-evt)

         ,(core-runtime-helper-form runtime-helper-index '$handle-evt)

         ;;;
         ;;; Semaphores
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$make-semaphore)

         ,(core-runtime-helper-form runtime-helper-index '$semaphore?)

         ,(core-runtime-helper-form runtime-helper-index '$semaphore-peek-evt?)

         ,(core-runtime-helper-form runtime-helper-index '$semaphore-post)

         ,(core-runtime-helper-form runtime-helper-index '$semaphore-try-wait?)

         ,(core-runtime-helper-form runtime-helper-index '$call-with-semaphore)

         ,(core-runtime-helper-form runtime-helper-index '$semaphore-peek-evt)

         ;;;
         ;;; Will Executors
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$make-will-executor)

         ,(core-runtime-helper-form runtime-helper-index '$will-executor?)

         ,(core-runtime-helper-form runtime-helper-index '$will-register)

         ,(core-runtime-helper-form runtime-helper-index '$will-try-execute)

         ,(core-runtime-helper-form runtime-helper-index '$will-execute)

         ;;;
         ;;; Event Synchronization
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$sync-one)

         ,(core-runtime-helper-form runtime-helper-index '$sync)

         ,(core-runtime-helper-form runtime-helper-index '$sync/timeout)

         ;;;
         ;;; Uninterruptible Locks
         ;;;

         ,(core-runtime-helper-form runtime-helper-index '$unsafe-make-uninterruptible-lock)

         ,(core-runtime-helper-form runtime-helper-index '$unsafe-uninterruptible-lock-acquire)

         ,(core-runtime-helper-form runtime-helper-index '$unsafe-uninterruptible-lock-release)

         ;;;
         ;;; Memory Map
         ;;;

         ;; Currently (June 2005) the proposal for multiple memories aren't supported
         ;; by Safari (WebKit). Therefore, we are forced to using a single memory only.

         ;; The following memory map is used to segment the linear memory.

         ;; Static host bridge scratch map:
         ;;   0..1MiB        VFS file transfer buffer
         ;;   +4KiB          VFS path buffer
         ;;   +64KiB         callback/FASL/string scratch buffer
         (global $memory-map:vfs-file-buffer-base   (mut i32) (i32.const 0))
         (global $memory-map:vfs-file-buffer-length (mut i32) (i32.const 1048576))
         (global $memory-map:vfs-path-buffer-base   (mut i32) (i32.const 1048576))
         (global $memory-map:vfs-path-buffer-length (mut i32) (i32.const 4096))
         (global $memory-map:callback-buffer-base   (mut i32) (i32.const 1052672))
         (global $memory-map:callback-buffer-length (mut i32) (i32.const 65536))
         (global $memory-map:string-buffer-base     (mut i32) (i32.const 1052672))
         (global $memory-map:string-buffer-length   (mut i32) (i32.const 4096))


         ;;;
         ;;; Data segment strings
         ;;;

         ;; The current (June 2005) support for strings in WebAssembly is *very* limited.
         ;; The data segment can be used to embed byte sequences in the source.
         ;; However in order to access the data, one must copy them to the linear memory first.

         (func $raise-string-buffer-overflow (unreachable))

         ; Turns out that the `memory.init` instruction requires a fixed
         ; segment number. So since we can't pass the segment number as an argument,
         ; we can't use these functions. Sigh.

         #;(func $data:codepoints->string
               (param $segment   i32)  ;; index of the passive data segment
               (param $count     i32)  ;; number of UTF-32 codepoints
               (result           (ref $String))

               (local $base      i32)
               (local $i         i32)
               (local $arr       (ref $I32Array))
               (local $str       (ref $String))
               (local $byte-size i32)

               ;; 1. Get base address for string buffer
               (local.set $base (global.get $memory-map:string-buffer-base))
               ;; 2. Compute byte size = count * 4
               (local.set $byte-size (i32.mul (local.get $count) (i32.const 4)))
               ;; 3. Bounds check (optional but recommended)
               (if (i32.gt_u (local.get $byte-size)
                             (global.get $memory-map:string-buffer-length))
                   (then (call $raise-string-buffer-overflow)))
               ;; 4. Copy data segment to string buffer
               (memory.init (local.get $segment)
                            (local.get $base)
                            (i32.const 0)
                            (local.get $byte-size))
               ;; 5. Allocate I32Array
               (local.set $arr (array.new_default $I32Array (local.get $count)))
               ;; 6. Copy from memory buffer into array
               (local.set $i (i32.const 0))
               (loop $copy (array.set $I32Array
                                      (local.get $arr)
                                      (local.get $i)
                                      (i32.load
                                       (i32.add
                                        (local.get $base)
                                        (i32.mul (local.get $i) (i32.const 4)))))
                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                     (br_if $copy (i32.lt_u (local.get $i) (local.get $count))))

               ;; 7. Convert to string
               (local.set $str (call $i32array->string (local.get $arr)))
               (local.get $str))

         #;(func $data:bytes->string
               (param $segment    i32) ;; passive data segment index
               (param $byte-count i32) ;; number of UTF-8 bytes
               (result            (ref $String))

               (local $base  i32)
               (local $i     i32)
               (local $arr   (ref $I8Array))
               (local $bs    (ref $Bytes))
               (local $str   (ref $String))
               ;; 1. Get base address for string buffer
               (local.set $base (global.get $memory-map:string-buffer-base))
               ;; 2. Bounds check
               (if (i32.gt_u (local.get $byte-count)
                             (global.get $memory-map:string-buffer-length))
                   (then (call $raise-string-buffer-overflow)))
               ;; 3. Copy from data segment into memory buffer
               (memory.init (local.get $segment)
                            (local.get $base)
                            (i32.const 0)
                            (local.get $byte-count))
               ;; 4. Allocate and fill I8Array
               (local.set $arr (array.new_default $I8Array (local.get $byte-count)))
               (local.set $i (i32.const 0))
               (loop $copy
                     (array.set $I8Array (local.get $arr) (local.get $i)
                                (i32.load8_u
                                 (i32.add (local.get $base)
                                          (local.get $i))))
                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                     (br_if $copy (i32.lt_u (local.get $i) (local.get $byte-count))))
               ;; 5. Wrap I8Array in Bytes struct
               (local.set $bs (struct.new $Bytes
                                          (i32.const 0)         ;; hash = 0 (unset)
                                          (local.get $byte-count)
                                          (local.get $arr)))
               ;; 6. Decode UTF-8
               (local.set $str (call $bytes->string/utf-8/checked
                                     (local.get $bs)))
               (local.get $str))


         ;;;
         ;;; HASH TABLES
         ;;;

         ;; Racket contains quite a few types of hash tables.
         ;;
         ;;   eq?/eqv?/equal?/equal-always?    mutable/immutable    strong/weak/ephemerons
         ;;
         ;; Currently `webracket` supports mutable, strong hash tables only.


         ;; Hash table predicates
         ;;   Implemented in runtime-wasm/core/hashes.rkt.
         ,@(for/list ([name (in-list hash-table-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;;
         ;;; MUTABLE HASHEQ
         ;;;

         ,@(for/list ([name (in-list mutable-hash-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,@(for/list ([name (in-list mutable-hash-pair-error-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,@(for/list ([name (in-list mutable-hash-association-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; IMMUTABLE HASHEQV
         ;;;

         ,@(for/list ([name (in-list immutable-hash-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$hash-placeholder?)

         ,(core-runtime-helper-form runtime-helper-index '$placeholder?)

         ,(core-runtime-helper-form runtime-helper-index '$make-placeholder)

         ,(core-runtime-helper-form runtime-helper-index '$placeholder-set!)

         ,(core-runtime-helper-form runtime-helper-index '$placeholder-get)

         ,(core-runtime-helper-form runtime-helper-index '$reader-graph-resolve)

         ,(core-runtime-helper-form runtime-helper-index '$make-reader-graph)

         ,(core-runtime-helper-form runtime-helper-index '$hash-weak?)

         ,(core-runtime-helper-form runtime-helper-index '$make-hash-placeholder/kind)

         ,(core-runtime-helper-form runtime-helper-index '$make-hash-placeholder)

         ,(core-runtime-helper-form runtime-helper-index '$make-hasheq-placeholder)

         ,(core-runtime-helper-form runtime-helper-index '$make-hasheqv-placeholder)

         ,(core-runtime-helper-form runtime-helper-index '$make-hashalw-placeholder)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-bucket-index)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-group-index)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-child-bit)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-key-bit)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-value-bit)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-bits)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-slot-kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bnode-packed-metadata)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-store-bnode-metadata)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bnode-metadata)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-bnode?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-index)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-slot)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-child-slot)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-key-slot)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-value-slot)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-empty-packed-node)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-store-packed-bnode-metadata)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-key-hash/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-wrap-inline-key/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-inline-key-unwrap)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-inline-key-cached-hash)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-entry-for-key/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-metadata-present?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-bucket-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-bucket-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-bucket-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-bucket-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-bucket-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-bucket-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bit)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket-ref/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket-ref-key/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket-has-key?/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-key-matches?/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-node-ref/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-node-ref-key/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-node-has-key?/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-node-set/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-bnode-collapse-if-single/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-packed-node-remove/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-node-ref/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-node-ref-key/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-node-has-key?/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-empty-node)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bnode-collapse-if-single)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket-length)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket-first-entry)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-collapse-small-bucket)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-entry-matches?/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket-remove/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-cnode-ref/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-cnode-ref-key/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-cnode-has-key?/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-cnode-set/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-cnode-remove/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket->cnode)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-bucket->node/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-node-set/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hamt-node-remove/kind)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-bucket-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-bucket-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-bucket-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-bucket-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-bucket-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-bucket-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-ref)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-set)

         ,(core-runtime-helper-form runtime-helper-index '$raise-hasheqv-odd-arguments)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-set)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-set)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-set)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheqv-remove)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hasheq-remove)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hash-remove)

         ,(core-runtime-helper-form runtime-helper-index '$immutable-hashalw-remove)

         ,(core-runtime-helper-form runtime-helper-index '$hash)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv)

         ,(core-runtime-helper-form runtime-helper-index '$make-immutable-hash)

         ,(core-runtime-helper-form runtime-helper-index '$make-immutable-hashalw)

         ,(core-runtime-helper-form runtime-helper-index '$make-immutable-hasheq)

         ,(core-runtime-helper-form runtime-helper-index '$make-immutable-hasheqv)

         ,(core-runtime-helper-form runtime-helper-index '$make-weak-hash)

         ,(core-runtime-helper-form runtime-helper-index '$make-weak-hasheq)

         ,(core-runtime-helper-form runtime-helper-index '$make-ephemeron-hasheq)

         ,(core-runtime-helper-form runtime-helper-index '$make-ephemeron)

         ,(core-runtime-helper-form runtime-helper-index '$ephemeron?)

         ,(core-runtime-helper-form runtime-helper-index '$ephemeron-value)

         ,(core-runtime-helper-form runtime-helper-index '$make-weak-hasheqv)

         ,(core-runtime-helper-form runtime-helper-index '$make-weak-hashalw)

         ;; Source-linklet bootstrap helpers
         ;;   Implemented in runtime-wasm/core/linklets.rkt.
         ,@(for/list ([name (in-list linklet-bootstrap-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Primitive-table bridge helpers
         ;;   Implemented in runtime-wasm/core/linklets.rkt.
         ,@(linklet-primitive-table-runtime-only-helper-forms
            (active-described-primitives-sorted)
            primitive-table-module-symbols)

         ;; Prefab struct registry helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$initialize-prefab-struct-type-registry)


         ,(core-runtime-helper-form runtime-helper-index '$raise-hash-ref-key-not-found)

         ,(core-runtime-helper-form runtime-helper-index '$hash-ref)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:hasheq-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:hasheqv-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:hash-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:hashalw-expected)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hash-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref-key)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref-key/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref-key/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref-key/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref-key/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref-key/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref-key/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref-key/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref-key/plain/checked)

         ;; Public immutable hash functional update wrappers
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,@(for/list ([name (in-list immutable-hash-public-runtime-only-helper-names)]
                      #:when (memq name '($hash-set $hash-remove)))
             (core-runtime-helper-form runtime-helper-index name))

         ,(core-runtime-helper-form runtime-helper-index '$hash-set!)

         ,(core-runtime-helper-form runtime-helper-index '$hash-copy)


         ,(core-runtime-helper-form runtime-helper-index '$hasheq-set!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-set!)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-set!)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-set!)


         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:mutable-hasheq-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:mutable-hasheqv-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:mutable-hash-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:mutable-hashalw-expected)

         ,(core-runtime-helper-form runtime-helper-index '$raise-hash-insert:table-full)

         ,(core-runtime-helper-form runtime-helper-index '$hash-kind/i32)

         ,(core-runtime-helper-form runtime-helper-index '$hash-mutable?/i32)

         ,(core-runtime-helper-form runtime-helper-index '$hash-key-hash/kind)

         ,(core-runtime-helper-form runtime-helper-index '$hash-key-matches?/kind)


         ,(core-runtime-helper-form runtime-helper-index '$hasheq-set!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-set!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hash-set!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-set!/mutable/checked)


         ,(core-runtime-helper-form runtime-helper-index '$hash-ref!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref!)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref!)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-ref!/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-ref!/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-ref!/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-ref!/plain/checked)

         ;; hash-update : immutable-hash? any/c (any/c -> any/c) [any/c or (-> any/c)] -> immutable-hash?
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$hash-update)


         ,(core-runtime-helper-form runtime-helper-index '$hash-update!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-update!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-update!)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-update!)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-update!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-update!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-update!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-update!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-update!/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-update!/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-update!/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-update!/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-update!/plain/checked)



         ,(core-runtime-helper-form runtime-helper-index '$raise-argument-error:hasheq-mutable-expected)

         ;; (func $hash-remove! (type $Prim2)
         ;;       (param $ht  (ref eq))
         ;;       (param $key (ref eq))
         ;;       (result     (ref eq))
         ;;       (call $hash-remove!/mutable
         ;;             (local.get $ht) (local.get $key)))

         ;; (func $hash-remove!/mutable
         ;;       (param $ht  (ref eq))
         ;;       (param $key (ref eq))
         ;;       (result     (ref eq))

         ;;       (local $table (ref $HashEqMutable))

         ;;       ;; --- Type checks ---
         ;;       (if (i32.eqz (ref.test (ref $HashEqMutable) (local.get $ht)))
         ;;           (then
         ;;            (call $raise-argument-error:hasheq-mutable-expected (local.get $ht))
         ;;            (unreachable)))
         ;;       ;; --- Decode ---
         ;;       (local.set $table (ref.cast (ref $HashEqMutable) (local.get $ht)))
         ;;       ;; --- Delegate ---
         ;;       (call $hash-remove!/mutable/checked
         ;;             (local.get $table)
         ;;             (local.get $key))
         ;;       (global.get $void))

         ;; (func $hash-remove!/mutable/checked
         ;;       ; Note: (global $tombstone) must be different from valid keys and $missing.
         ;;       (param $ht  (ref $HashEqMutable))
         ;;       (param $key (ref eq))

         ;;       (local $entries  (ref $Array))
         ;;       (local $capacity i32)
         ;;       (local $hash     i32)
         ;;       (local $index    i32)
         ;;       (local $step     i32)
         ;;       (local $k        (ref eq))
         ;;       (local $slot     i32)

         ;;       ;; Get entries and capacity
         ;;       (local.set $entries  (struct.get $HashEqMutable $entries (local.get $ht)))
         ;;       (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
         ;;       ;; Compute hash and initial index
         ;;       (local.set $hash  (call $eq-hash/i32 (local.get $key)))
         ;;       (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
         ;;       (local.set $step  (i32.const 0))
         ;;       ;; Probe loop
         ;;       (block $done
         ;;              (loop $probe
         ;;                    ;; Stop if probing exceeds capacity
         ;;                    (br_if $done (i32.ge_u (local.get $step) (local.get $capacity)))
         ;;                    ;; Compute probe slot (2 * index)
         ;;                    (local.set $slot (i32.shl
         ;;                                      (i32.rem_u (i32.add (local.get $index) (local.get $step))
         ;;                                                 (local.get $capacity))
         ;;                                      (i32.const 1)))
         ;;                    ;; Load key from slot
         ;;                    (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
         ;;                    ;; Stop if slot is missing
         ;;                    (br_if $done (ref.eq (local.get $k) (global.get $missing)))
         ;;                    ;; If key matches, remove
         ;;                    (if (ref.eq (local.get $k) (local.get $key))
         ;;                        (then
         ;;                         ;; Replace key and value with tombstone
         ;;                         (array.set $Array (local.get $entries) (local.get $slot) (global.get $tombstone))
         ;;                         (array.set $Array (local.get $entries)
         ;;                                    (i32.add (local.get $slot) (i32.const 1))
         ;;                                    (global.get $tombstone))
         ;;                         ;; Decrement count
         ;;                         (struct.set $HashEqMutable $count
         ;;                                     (local.get $ht)
         ;;                                     (i32.sub (struct.get $HashEqMutable $count (local.get $ht)) (i32.const 1)))
         ;;                         (br $done)))
         ;;                    ;; Step to next slot
         ;;                    (local.set $step (i32.add (local.get $step) (i32.const 1)))
         ;;                    (br $probe))))


         ,(core-runtime-helper-form runtime-helper-index '$hash-remove!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-remove!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-remove!)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-remove!)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-remove!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-remove!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-remove!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hash-remove!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-remove!/mutable/checked)



         ,(core-runtime-helper-form runtime-helper-index '$hasheq-resize)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-resize)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-resize)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-resize)

         ,(core-runtime-helper-form runtime-helper-index '$maybe-resize-hasheq)

         ,(core-runtime-helper-form runtime-helper-index '$maybe-resize-hasheqv)

         ,(core-runtime-helper-form runtime-helper-index '$maybe-resize-hashequal)

         ,(core-runtime-helper-form runtime-helper-index '$maybe-resize-hashalw)


         ,(core-runtime-helper-form runtime-helper-index '$hash-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$hash-keys-subset?)


         ,(core-runtime-helper-form runtime-helper-index '$hasheq-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-has-key?)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-has-key?)


         ,(core-runtime-helper-form runtime-helper-index '$hasheq-has-key?/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-has-key?/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-has-key?/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-has-key?/plain)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-has-key?/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-has-key?/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-has-key?/plain/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-has-key?/plain/checked)




         ,(core-runtime-helper-form runtime-helper-index '$hash-clear!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-clear!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-clear!)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-clear!)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-clear!)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-clear!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-clear!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hash-clear!/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-clear!/mutable/checked)

         ;; hash-clear : immutable-hash? -> immutable-hash?
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$hash-clear)



         ,(core-runtime-helper-form runtime-helper-index '$hash-empty?)


         ,(core-runtime-helper-form runtime-helper-index '$hasheq-empty?)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-empty?)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-empty?)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-empty?)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-empty?/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-empty?/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hash-empty?/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-empty?/mutable/checked)

         ,(core-runtime-helper-form runtime-helper-index '$raise-mutable-hash-iterate-bad-index)

         ,(core-runtime-helper-form runtime-helper-index '$hash-iterate-first)

         ,(core-runtime-helper-form runtime-helper-index '$hash-iterate-next)

         ,(core-runtime-helper-form runtime-helper-index '$hash-iterate-key)

         ,(core-runtime-helper-form runtime-helper-index '$hash-iterate-value)

         ,(core-runtime-helper-form runtime-helper-index '$hash-iterate-pair)

         ,(core-runtime-helper-form runtime-helper-index '$hash-iterate-key+value)


         ,(core-runtime-helper-form runtime-helper-index '$mutable-hash-iterate-first)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-iterate-first)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-iterate-first)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-iterate-first)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-iterate-first)

         ,(core-runtime-helper-form runtime-helper-index '$mutable-hash-iterate-next)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-iterate-next)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-iterate-next)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-iterate-next)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-iterate-next)


         ,(core-runtime-helper-form runtime-helper-index '$mutable-hash-iterate-key)

         ,(core-runtime-helper-form runtime-helper-index '$mutable-hash-iterate-value)

         ,(core-runtime-helper-form runtime-helper-index '$mutable-hash-iterate-pair)

         ,(core-runtime-helper-form runtime-helper-index '$mutable-hash-iterate-key+value)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-iterate-key)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-iterate-key)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-iterate-key)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-iterate-key)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-iterate-value)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-iterate-value)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-iterate-value)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-iterate-value)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-iterate-pair)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-iterate-pair)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-iterate-pair)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-iterate-pair)

         ,(core-runtime-helper-form runtime-helper-index '$hasheq-iterate-key+value)

         ,(core-runtime-helper-form runtime-helper-index '$hasheqv-iterate-key+value)

         ,(core-runtime-helper-form runtime-helper-index '$hashequal-iterate-key+value)

         ,(core-runtime-helper-form runtime-helper-index '$hashalw-iterate-key+value)

        ;; unsafe-immutable-hash-iterate-* : immutable hash iteration
        ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
        ,@(for/list ([name (in-list immutable-hash-iteration-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;; General hash-count and hash->list
        ;;   Implemented in runtime-wasm/core/hashes.rkt.
        ,@(for/list ([name (in-list hash-count-list-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ;; hash-for-each : apply proc to each key/value in a hash table.
         ;;   Implemented in runtime-wasm/core/hashes.rkt.
        ,@(for/list ([name (in-list hash-for-each-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;; General hash-map
        ;;   Implemented in runtime-wasm/core/hashes.rkt.
        ,@(for/list ([name (in-list hash-map-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))


        ;; -------------------------------------------------------------------
        ;; hash-map/copy
        ;;   Implemented in runtime-wasm/core/hashes.rkt.
        ,@(for/list ([name (in-list hash-map-copy-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))


        ;; -------------------------------------------------------------------
        ;; hash-filter, hash-filter-keys, hash-filter-values
        ;; -------------------------------------------------------------------
        ;;   Implemented in runtime-wasm/core/hashes.rkt.
        ,@(for/list ([name (in-list hash-filter-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))


        ;; General hash-keys and hash-values
        ;;   Implemented in runtime-wasm/core/hashes.rkt.
        ,@(for/list ([name (in-list hash-key-value-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))



         ;;;
         ;;; HASH CODES
         ;;;

         (global $next-hash-state (mut i32) (i32.const 0x9e3779b9)) ;; initial seed, can be randomized or fixed

         ;;   Implemented in runtime-wasm/core/hashes.rkt.
         ,@(for/list ([name (in-list hash-seed-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;; Equal Hash Code

         ;;   Implemented in runtime-wasm/core/hashes.rkt.
         ,@(for/list ([name (in-list hash-equal-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/hashes.rkt.
         ,@(for/list ([name (in-list hash-equal-composite-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; SYMBOL TABLE
         ;;;

         ; We'll use an open-addressing hash table with linear probing for simplicity.
         ; A load of 50% leads to fast lookup - but uses some more memory.

         ; Theory: https://thenumb.at/Hashtables/

         ; We do not support deleting symbols from the symbol table, so we do not
         ; need to handle tombstones.

         (type $SymbolTable
               (struct
                 (field $entries (mut (ref $Array))) ;; flat array: key0, val0, key1, val1, ...
                 (field $count   (mut i32))))        ;; number of symbols currently stored

         ; The $Array is a flat array: [key0 val0 key1 val1 ...].
         ; Capacity is half the array length (since entries are key-value pairs).
         ; Keys are (ref $String), values are (ref $Symbol).
         ; Count is number of active entries (not tombstones).

         ;;   Implemented in runtime-wasm/core/symbols.rkt.
         ,@(for/list ([name (in-list symbol-table-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;  Fowler–Noll–Vo hash function
         ;    Note: Since 0 means "hash not computed yet", $string-hash/i32 must
         ;          return a non-zero value.
         ,(core-runtime-helper-form core-runtime-helper-index '$string-hash/i32)


         ;;;
         ;;; LOCATION
         ;;;

         ;; When counting lines, Racket treats linefeed, return, and
         ;; return-linefeed combinations as a line terminator and as a single
         ;; position (on all platforms).
         ;; Each tab advances the column count to one before the next multiple
         ;; of 8.
         ;; When a sequence of bytes in the range 128 to 253 forms a
         ;; UTF-8 encoding of a character, the position/column is incremented
         ;; once for each byte, and then decremented appropriately
         ;; when a complete encoding sequence is discovered.

         ;; (array line column pos)
         ;;   pos and line counts from 1
         ;;   column       counts from 0

         ;;   Implemented in runtime-wasm/core/locations.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$make-initial-location)

         ;;;
         ;;; 13.1.6  STRING PORT
         ;;;

         ;; https://docs.racket-lang.org/reference/ports.html

         ;; A string port reads or writes from a byte string. An input
         ;; string port can be created from either a byte string or a string;
         ;; in the latter case, the string is effectively converted to a byte
         ;; string using string->bytes/utf-8. An output string port collects
         ;; output into a byte string, but get-output-string conveniently converts
         ;; the accumulated bytes to a string.

         ;; Note: the index `idx` and the location position may be different,
         ;;       since the #\return#\newline combination counts as a
         ;;       single position.

         ;; [x] string-port?
         ;; [x] open-input-bytes
         ;; [x] open-input-string
         ;; [x] open-output-bytes
         ;; [x] open-output-string
         ;; [x] get-output-bytes
         ;; [x] get-output-string

         ;; [ ] write-byte

        ;; Note:
        ;;   Currently WebRacket only supports string ports. Distinguish
        ;;   between input and output ports based on the mutability of the
        ;;   underlying byte string: input ports store immutable bytes, while
        ;;   output ports keep a mutable byte buffer that grows as data is
        ;;   written.

        ;;   Implemented in runtime-wasm/core/ports.rkt.
        ,@(for/list ([name (in-list port-predicate-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;;   Implemented in runtime-wasm/core/impersonators.rkt.
        ,@(for/list ([name (in-list impersonator-basic-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;;   Implemented in runtime-wasm/core/ports.rkt.
        ,(core-runtime-helper-form runtime-helper-index '$output-port?)

        ;;   Implemented in runtime-wasm/core/ports.rkt.
        ,@(for/list ([name (in-list port-state-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;;   Implemented in runtime-wasm/core/ports.rkt.
        ,@(for/list ([name (in-list port-location-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-string-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$get-output-string)

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-custom-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         (func $eof-object? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (if (result (ref eq))
                   (ref.eq (local.get $v) (global.get $eof))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$call-with-output-string)

         ;;;
         ;;;  13.2  Byte and String Input
         ;;;

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-event-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-custom-byte-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-byte-char-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-byte-char-special-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-read-bytes-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-read-string-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-ready-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-read-line-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-peek-bytes-bang-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$peek-string!)


         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-peek-byte-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-peek-bytes-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;;  13.3  Byte and String Output
         ;;;

         ;; (type $InputStringPort
         ;;     (sub $InputPort
         ;;       (struct
         ;;         (field $name  (ref eq))     ; the port name   (string)
         ;;         (field $bytes (ref eq))     ; the byte string (bytes)
         ;;         (field $len   i32)          ; the length of the string
         ;;         (field $idx   i32)          ; the current index into the string
         ;;         (field $loc   (ref $Location)))) ; the current location

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-write-basic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/ports.rkt.
         ,@(for/list ([name (in-list port-write-bytes-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;;
         ;;; FFI Helpers, callbacks, and browser bridge
         ;;;

         ;;   Implemented in runtime-wasm/core/ffi.rkt.
         ,@(ffi-runtime-only-helper-forms console-bridge-bindings)

         ;;;
         ;;; 5. STRUCTURES
         ;;;

         ;; TODO
         ;; [x] structure types and super structs
         ;; [x] auto fields
         ;; [/] prefab structures
         ;; [x] structure guards
         ;; [ ] applicable structures

         ;; 5.1 Defining Structure Types: struct
         ;; [/] struct                     [syntax]
         ;; [x] struct-field-index         [syntax]
         ;; [x] define-struct              [syntax]
         ;; [x] struct/derived             [syntax]
         ;; [x] define-struct/derived      [syntax]

         ;; 5.2 Creating Structure Types
         ;; [x] make-struct-type
         ;; [x] make-struct-field-accessor
         ;; [x] make-struct-field-mutator
         ;; [ ] prop:sealed                [value]
         ;;       - a structure type property
         ;;       - a sealed struct can not be a supertype of another structure type

         ;; 5.3 Structure Type Properties
         ;; [x] make-struct-type-property
         ;; [x] struct-type-property?
         ;; [x] struct-type-property-accessor-procedure?
         ;; [x] struct-type-property-predicate-procedure?

         ;; 5.4 Generic Interfaces (racket/generic)
         ;; ...

         ;; 5.5 Copying and Updating Structures
         ;; [ ] struct-copy      [syntax]

         ;; 5.6 Structure Utilities
         ;; [x] struct->vector
         ;; [x] struct?
         ;; [x] struct-type?
         ;; [x] struct-constructor-procedure?
         ;; [x] struct-predicate-procedure?
         ;; [x] struct-accessor-procedure?
         ;; [x] struct-mutator-procedure?
         ;; [x] prefab-struct-key
         ;; [x] make-prefab-struct
         ;; [x] prefab-struct-type-key+ field-count
         ;; [ ] prefab-key->struct-type
         ;; [x] prefab-key?

         ;; 5.6.1 Additional Structure Utilities
         ;; [ ] make-constructor-style-printer
         ;; [x] struct->list

         ,(core-runtime-helper-form core-runtime-helper-index '$struct?/i32)
         ,(core-runtime-helper-form core-runtime-helper-index '$struct-type?/i32)

         ;; Basic struct predicates and checkers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-basic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct conversion helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-conversion-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct formatting helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-format-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type descriptor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-descriptor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; > (topexpand  #`(let () (struct foo (bar)) (foo 11)))
         ;; #<syntax:racket-mode-repl::15
         ;; (let-values ()
         ;;   (let-values (((struct:foo foo1 foo? foo-bar)
         ;;                 (let-values (((struct: make- ? -ref -set!)
         ;;                               (let-values ()
         ;;                                 (let-values ()
         ;;                                   (#%app make-struct-type 'foo '#f '1 '0 '#f null (#%app current-inspector) '#f '(0) '#f 'foo)))))
         ;;                   (#%app values struct: make- ? (#%app make-struct-field-accessor -ref '0 'bar)))))
         ;;     (#%app foo1 '11)))

         ;; compiler.rkt>
         ;; (make-struct-type 'foo    ; name
         ;;                   '#f     ; no super
         ;;                   '1      ; init-field-count
         ;;                   '0      ; auto-field-cnt
         ;; optional:
         ;;                   '#f     ; auto-v
         ;;                   null    ; props
         ;;                   (current-inspector) ; inspector
         ;;                   '#f     ; proc-spec
         ;;                   '(0)    ; immutables
         ;;                   '#f     ; guard
         ;;                   'foo))) ; constructor-name


         ;; $make-struct-type
         ;;   returns 5 values:
         ;;     struct-type?
         ;;     struct-constructor-procedure?
         ;;     struct-predicate-procedure?
         ;;     struct-accessor-procedure?
         ;;     struct-mutator-procedure?

         ;; Initial prefab helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-basic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab key encoding helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-key-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab key validation helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-key-validation-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab key accessor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-key-accessor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab chain and alias helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-chain-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab struct-type interning helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-struct-type-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab metadata helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-metadata-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab immutability mask helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-immutables-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Prefab constructor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-prefab-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type construction helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct accessor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-accessor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct constructor wrapper helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-constructor-wrapper-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        (elem declare funcref
              (ref.func $struct-constructor/no-guard)       ; closure body
              (ref.func $struct-constructor/with-guard)     ; closure body
              (ref.func $struct-accessor)                   ; closure body
              (ref.func $struct-mutator)                    ; closure body
              (ref.func $struct-predicate)                  ; closure body
              (ref.func $struct-field-accessor/specialized) ; closure body
              (ref.func $struct-mutator/specialized)
              (ref.func $struct-type-property-predicate)    ; closure body
              (ref.func $struct-type-property-accessor)     ; closure body
              (ref.func $equal+hash-recur/equal)            ; closure body
              (ref.func $equal+hash-recur/equal-always)     ; closure body
              (ref.func $equal+hash-recur/hash)             ; closure body
              (ref.func $equal+hash-recur/hash-always)      ; closure body
              (ref.func $invoke-struct)
              (ref.func $primitive-invoke)
              (ref.func $invoke-reduced-procedure)
              (ref.func $invoke-composed-procedure)
              (ref.func $sort/keyword-apply)
              (ref.func $vector-sort/keyword-apply)
              (ref.func $vector-sort!/keyword-apply)
              (ref.func $code:case-lambda-dispatch)
              (ref.func $invoke-case-closure)
              (ref.func $default-error-syntax->name-handler)
              (ref.func $default-error-value->string-handler)
              (ref.func $default-error-syntax->string-handler)
              (ref.func $default-error-module-path->string-handler)
              (ref.func $default-current-read-interaction)
              (ref.func $default-port-read-handler)
              (ref.func $default-port-read-handler/1)
              (ref.func $default-port-write-handler)
              (ref.func $default-port-display-handler)
              (ref.func $default-port-print-handler)
              (ref.func $syntax-introducer)
              (ref.func $syntax-delta-introducer)

              ;; Primitive invokers for the different shapes
              ,@(for/list ([shape (in-list primitive-shapes)])
                  `(ref.func ,($ (shape->invoker shape))))
              ;; Declare all primitives
              ,@(for/list ([pr (in-list (active-described-primitives-sorted))])
                  `(ref.func ,($ pr)))
              ;; Declare FFI-backed primitive wrappers.
              ,@(for/list ([pr (in-list (active-ffi-primitive-names))])
                  `(ref.func ,($ pr))))


        ;; Struct constructor implementation helpers
        ;;   Implemented in runtime-wasm/core/structs.rkt.
        ,@(for/list ([name (in-list struct-constructor-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

         ;; Struct mutator helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-mutator-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))



         ;; Struct field mutator helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-field-mutator-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct predicate helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct field accessor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-field-accessor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;; Struct procedure predicates
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-procedure-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;; Struct guarded constructor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-guarded-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; -------------------------------------------------------------------
         ;; Structure Type Properties
         ;; -------------------------------------------------------------------

         ;; Struct type property lookup helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-property-lookup-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type property closure helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-property-closure-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type property predicate helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-property-predicate-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type property descriptor helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-property-descriptor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type property table and attachment helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-property-table-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Struct type property construction helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-type-property-constructor-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;;
         ;;; PROCEDURES
         ;;;

         ;; Struct procedure helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(for/list ([name (in-list struct-procedure-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Basic procedure helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-basic-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Procedure arity-at-least helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-arity-at-least-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Procedure arity field helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-arity-field-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Procedure composition helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-composition-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Procedure arity reduction helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-reduction-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Procedure arity accessors
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-arity-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;; Procedure result arity helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-result-arity-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/impersonators.rkt.
         ,@(for/list ([name (in-list chaperone-procedure-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))





         ;; Procedure arity mask helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list procedure-arity-mask-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;;
         ;;; PRIMITIVES
         ;;;

         ; https://docs.racket-lang.org/reference/procedures.html

         ; 4.20.2 Reflecting on Primitives

         ;; Primitive reflection helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(for/list ([name (in-list primitive-reflection-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;;  4.21 Void
         ;;;

         ;; https://docs.racket-lang.org/reference/void.html

         ;;   Implemented in runtime-wasm/core/immediates.rkt.
         ,@(for/list ([name (in-list void-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;;;
         ;;; 10. CONTROL FLOW
         ;;;

         ;; 10.1 Multiple Values

         ;;   Implemented in runtime-wasm/core/control-flow.rkt.
         ,@(for/list ([name (in-list multiple-value-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))



         ;; 10.2 Exceptions

         ;; 10.3 Delayed Evaluation
         ;; 10.4 Continuations

         ;;   Implemented in runtime-wasm/core/control-flow.rkt.
         ,@(for/list ([name (in-list continuation-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; 10.5 Continuation Marks

         ;;   Implemented in runtime-wasm/core/control-flow.rkt.
         ,@(for/list ([name (in-list continuation-mark-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(for/list ([name (in-list parameterization-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(for/list ([name (in-list namespace-parameter-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(for/list ([name (in-list parameterization-binding-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(for/list ([name (in-list parameterization-call-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; 10.6 Breaks
         ;; 10.7 Exiting
         ;; 10.8 Unreachable Expressions


         ;;;
         ;;; 13. INPUT AND OUTPUT
         ;;;

         ;; 13.8 Printer Extension

         ;;   Implemented in runtime-wasm/core/formatting.rkt.
         ,@(for/list ([name (in-list printer-extension-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))


         ;; 13.10 Fast-Load Serialization

         ;;   FASL tag globals are implemented in runtime-wasm/core/fasl.rkt.
         ,@(for/list ([name (in-list fasl-tag-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   FASL encoding helpers are implemented in runtime-wasm/core/fasl.rkt.
         ,@(for/list ([name (in-list fasl-encoding-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;; Fasl decoding (from byte string)

         ;;   FASL decoding helpers are implemented in runtime-wasm/core/fasl.rkt.
         ,@(for/list ([name (in-list fasl-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

        ;;;
        ;;; 14. REFLECTION AND SECURITY
        ;;;

        ;; 14.1 Namespaces

        ;;   Reflection helpers are implemented in runtime-wasm/core/reflection.rkt.
        ,@(for/list ([name (in-list reflection-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))
         ;; 14.2 Evaluation and compilation
         ;; 14.3 The racket/load language
         ;; 14.4 Module names and loading
         ;; 14.5 Impersonators and chaperones
         ;; 14.6 Security Guards
         ;; 14.7 Custodians

         ;;   Security guard helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(for/list ([name (in-list security-pre-parameter-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$current-security-guard)

         ;;   Security guard and custodian predicate helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(for/list ([name (in-list security-post-parameter-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$current-custodian)

         ;;   Custodian helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(for/list ([name (in-list custodian-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; 14.8 Thread Groups
         ;; 14.9 Structure Inspectors

         ;;   Implemented in runtime-wasm/core/time.rkt.
         ,@(for/list ([name (in-list time-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Inspector and object-name helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(for/list ([name (in-list inspector-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; 14.10 Code Inspectors
         ;; 14.11 Plumbers
         ;; 14.12 Sandboxed Evaluation
         ;; 14.13 The racket/repl library

         ;;;
         ;;; 14.14 Linklets and the compiler
         ;;;


         ;;   Linklet instance helpers are implemented in runtime-wasm/core/linklet-instances.rkt.
         ,@(for/list ([name (in-list linklet-instance-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;   Linklet helpers are implemented in runtime-wasm/core/linklets.rkt.
         ,@(linklet-runtime-only-helper-forms linklet-body-reserved-symbols)

         ;;   Correlated syntax helpers are implemented in runtime-wasm/core/syntax.rkt.
         ,@(for/list ([name (in-list correlated-syntax-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; 17. UNSAFE OPERATIONS
         ;;;

         ;;   Implemented in runtime-wasm/core/unsafe.rkt.
         ,@(for/list ([name (in-list unsafe-runtime-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; FORMATTING - DISPLAY MODE
         ;;;

         ;;   Implemented in runtime-wasm/core/formatting.rkt.
         ,@(for/list ([name (in-list formatting-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

               ;;;
               ;;; Support for the for-family: for, for/list, for/vector
               ;;;

               #;(func $grow-vector
                     (param $vec (ref $Vector))
                     (result     (ref $Vector))

                     (local $arr     (ref $Array))
                     (local $len     i32)
                     (local $new-len i32)
                     (local $new-vec (ref $Vector))
                     (local $new-arr (ref $Array))
                     ;; Extract underlying array and its length
                     (local.set $arr     (struct.get $Vector $arr (local.get $vec)))
                     (local.set $len     (array.len (local.get $arr)))
                     (local.set $new-len (i32.mul (local.get $len) (i32.const 2)))
                     ;; Allocate new array and vector wrapper
                     (local.set $new-arr (array.new_default $Array (local.get $new-len) (global.get $null)))
                     (local.set $new-vec (struct.new $Vector (i32.const 0) (i32.const 0) (local.get $new-arr)))
                     ;; Copy elements
                     (call $vector-copy!
                           (local.get $new-vec)
                           (ref.i31 (i32.const 0))
                           (local.get $vec)
                           (ref.i31 (i32.const 0))
                           (ref.i31 (local.get $len)))
                     (return (local.get $new-vec)))


               #;(func $shrink-vector
                     (param $vec (ref $Vector))
                     (param $i   (ref eq))   ;; fixnum
                     (result (ref $Vector))

                     (local $i/u i32)
                     (local $new-vec (ref $Vector))
                     ;; Validate fixnum index
                     (if (i32.eqz (ref.test (ref i31) (local.get $i)))
                         (then (call $raise-check-fixnum (local.get $i)) (unreachable)))
                     (local.set $i/u
                                (i32.shr_u
                                 (i31.get_u (ref.cast (ref i31) (local.get $i)))
                                 (i32.const 1)))
                     ;; Allocate new vector and copy
                     (local.set $new-vec (struct.new $Vector
                                                     (i32.const 0)
                                                     (i32.const 0)
                                                     (array.new_default $Array (local.get $i/u) (global.get $null))))
                     (call $vector-copy!
                           (local.get $new-vec)
                           (ref.i31 (i32.const 0))
                           (local.get $vec)
                           (ref.i31 (i32.const 0))
                           (ref.i31 (i32.shl (local.get $i/u) (i32.const 1)))) ;; convert i32 to fixnum
                     (return (local.get $new-vec)))

               ;;;
               ;;; 14. REFLECTION AND SECURITY
               ;;;

               ;; 14.1 Namespaces

               ;;   Implemented in runtime-wasm/core/namespaces.rkt.
               ,@(for/list ([name (in-list namespace-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;;
               ;;; 14.2 Source Locations
               ;;;

               ;;   Implemented in runtime-wasm/core/locations.rkt.
               ,@(for/list ([name (in-list source-location-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;;
               ;;; 12. Macros
               ;;;

               ;;; 12.2 Syntax Object COntent

               ;;   Implemented in runtime-wasm/core/syntax.rkt.
               ,@(for/list ([name (in-list syntax-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;;
               ;;; 15. OPERATING SYSTEM
               ;;;

               ;;; 15.1 Paths

               ;;   Basic path helpers are implemented in runtime-wasm/core/paths.rkt.
               ,@(for/list ([name (in-list path-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Environment variable helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$environment-variables?)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-environment-variables)

               ;;   Environment variable helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$environment-variables-ref)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-print)

               ;;   Bootstrap reader and printer helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,@(for/list ([name (in-list io-handler-reader-printer-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-readtable)

               ;;   Port handler helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,@(for/list ([name (in-list io-handler-port-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-read-interaction)

               ;; load-on-demand-enabled/use-user-specific-search-paths/read-accept-* : [boolean?] -> boolean? or void?
               ;;   Bootstrap reader policy parameters. The Reference gives
               ;;   load-on-demand-enabled a default of #t; WebRacket exposes
               ;;   the parameter now, while delayed source loading is deferred
               ;;   until the reader/load layer is richer.
               ,@(for/list ([name (in-list reader-printer-policy-parameter-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,@(for/list ([name (in-list parameter-width-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Error rendering defaults are implemented in runtime-wasm/core/io-handlers.rkt.
               ,@(for/list ([name (in-list io-handler-error-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,@(for/list ([name (in-list parameter-error-rendering-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,@(for/list ([name (in-list parameter-directory-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-load-relative-directory)

               ;;   Path manipulation helpers are implemented in runtime-wasm/core/paths.rkt.
               ,@(for/list ([name (in-list path-manipulation-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;   VFS and file-operation helpers are implemented in runtime-wasm/core/filesystem.rkt.
               ,@(for/list ([name (in-list filesystem-runtime-only-helper-names)])
                   (core-runtime-helper-form runtime-helper-index name))

               ;;;
               ;;; FFI
               ;;;

               #;(type $External
                       (sub $Heap
                            (struct
                              (field $hash (mut i32))
                              (field $v    (ref null extern)))))

               ;; Moved up to import section
               #;(func $js_document_body
                       (import "ffi" "js_document_body")
                       (result externref))

               #;(func $js-document-body
                     (result (ref eq))
                     (struct.new $External
                                 (i32.const 0)
                                 (call $js-document-body/imported)))

               #;(func $js-make-text-node
                     (result (ref eq))
                     (struct.new $External
                                 (i32.const 0)
                                 (call $js_make_text_node)))




               ;; Top level `(define-label ...)
               ,@dls

               ;; $entry
               ;;  - called by the host (Node or Browser) to start computation
               ;;  - the host expects `entry` to return an integer as result
               ;;  - we convert the result value into a byte string
               ;;  - store the byte string in $result-bytes
               ;;  - we return the length of $result-bytes
               ;;  - the host calls $get-bytes which copies the result-bytes
               ;;    into the linear memory, where the host can read it.

               (global $system-path-convention   (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-directory-path   (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-directory-for-user-path (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-load-relative-directory-path (mut (ref eq)) (global.get $false))
               (global $current-environment-variables-value (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $temporary-file-counter   (mut i32)      (i32.const 0))
               (global $current-input-port-value  (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-output-port-value (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-error-port-value  (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-print-value       (mut (ref eq)) (global.get $false))
               (global $current-read-interaction-value (mut (ref eq)) (global.get $false))
               (global $current-logger-value      (mut (ref eq)) (global.get $false))
               (global $current-security-guard-value (mut (ref eq)) (global.get $false))
               (global $current-custodian-value   (mut (ref eq)) (global.get $false))
               (global $default-port-read-handler-value (mut (ref eq)) (global.get $false))
               (global $default-port-write-handler-value (mut (ref eq)) (global.get $false))
               (global $default-port-display-handler-value (mut (ref eq)) (global.get $false))
               (global $default-port-print-handler-value (mut (ref eq)) (global.get $false))
               (global $load-on-demand-enabled-value (mut (ref eq)) (global.get $true))
               (global $use-user-specific-search-paths-value (mut (ref eq)) (global.get $true))
               (global $read-square-bracket-as-paren-value (mut (ref eq)) (global.get $true))
               (global $read-curly-brace-as-paren-value   (mut (ref eq)) (global.get $true))
               (global $read-square-bracket-with-tag-value (mut (ref eq)) (global.get $false))
               (global $read-curly-brace-with-tag-value   (mut (ref eq)) (global.get $false))
               (global $read-accept-reader-value       (mut (ref eq)) (global.get $true))
               (global $read-accept-lang-value         (mut (ref eq)) (global.get $true))
               (global $read-accept-compiled-value     (mut (ref eq)) (global.get $false))
               (global $read-accept-box-value          (mut (ref eq)) (global.get $true))
               (global $read-accept-bar-quote-value    (mut (ref eq)) (global.get $true))
               (global $read-accept-graph-value        (mut (ref eq)) (global.get $true))
               (global $read-syntax-accept-graph-value (mut (ref eq)) (global.get $false))
               (global $read-accept-dot-value          (mut (ref eq)) (global.get $true))
               (global $read-accept-infix-dot-value    (mut (ref eq)) (global.get $true))
               (global $read-accept-quasiquote-value   (mut (ref eq)) (global.get $true))
               (global $read-cdot-value                (mut (ref eq)) (global.get $false))
               (global $read-single-flonum-value       (mut (ref eq)) (global.get $false))
               (global $read-decimal-as-inexact-value  (mut (ref eq)) (global.get $true))
               (global $read-case-sensitive-value      (mut (ref eq)) (global.get $true))
               (global $current-readtable-value        (mut (ref eq)) (global.get $false))
               (global $print-pair-curly-braces-value       (mut (ref eq)) (global.get $false))
               (global $print-mpair-curly-braces-value      (mut (ref eq)) (global.get $true))
               (global $print-unreadable-value              (mut (ref eq)) (global.get $true))
               (global $print-graph-value                   (mut (ref eq)) (global.get $false))
               (global $print-struct-value                  (mut (ref eq)) (global.get $true))
               (global $print-box-value                     (mut (ref eq)) (global.get $true))
               (global $print-vector-length-value           (mut (ref eq)) (global.get $false))
               (global $print-hash-table-value              (mut (ref eq)) (global.get $true))
               (global $print-boolean-long-form-value       (mut (ref eq)) (global.get $false))
               (global $print-reader-abbreviations-value    (mut (ref eq)) (global.get $false))
               (global $print-as-expression-value           (mut (ref eq)) (global.get $true))
               (global $print-syntax-width-value       (mut (ref eq)) (ref.i31 (i32.const 512)))
               (global $error-print-width-value        (mut (ref eq)) (ref.i31 (i32.const 512)))
               (global $error-print-source-location-value (mut (ref eq)) (global.get $true))
               (global $current-compile-target-machine-value (mut (ref eq)) (global.get $false))
               (global $current-compile-realm-value (mut (ref eq)) (global.get $false))
               (global $current-parameterization-value (mut (ref eq)) (global.get $false))
               (global $current-namespace-value (mut (ref eq)) (global.get $false))
               (global $current-pseudo-random-generator-value (mut (ref eq)) (global.get $false))
               (global $current-thread-group-value (mut (ref eq)) (global.get $false))
               (global $error-value->string-handler-value (mut (ref eq)) (global.get $false))
               (global $error-syntax->string-handler-value (mut (ref eq)) (global.get $false))
               (global $error-syntax->name-handler-value (mut (ref eq)) (global.get $false))
               (global $error-module-path->string-handler-value (mut (ref eq)) (global.get $false))
               (global $result-bytes             (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-thread-value     (mut (ref eq)) (global.get $false))
               (global $always-evt               (mut (ref eq)) (global.get $false))
               (global $never-evt                (mut (ref eq)) (global.get $false))

               ;; Struct-type properties provided by the runtime
               (global $prop:sealed                   (mut (ref eq)) (global.get $void))
               (global $prop:evt                      (mut (ref eq)) (global.get $void))
               (global $prop:object-name              (mut (ref eq)) (global.get $void))
               (global $prop:procedure                (mut (ref eq)) (global.get $void))
               (global $prop:exn:srclocs              (mut (ref eq)) (global.get $void))
               (global $prop:input-port               (mut (ref eq)) (global.get $void))
               (global $prop:output-port              (mut (ref eq)) (global.get $void))
               (global $impersonator-prop:application-mark (mut (ref eq)) (global.get $void))
               (global $prop:checked-procedure        (mut (ref eq)) (global.get $void))
               (global $prop:impersonator-of          (mut (ref eq)) (global.get $void))
               (global $prop:method-arity-error       (mut (ref eq)) (global.get $void))
               (global $prop:arity-string             (mut (ref eq)) (global.get $void))
               (global $prop:incomplete-arity         (mut (ref eq)) (global.get $void))
               (global $prop:authentic                (mut (ref eq)) (global.get $void))
               (global $prop:custom-write             (mut (ref eq)) (global.get $void))
               (global $prop:custom-print-quotable    (mut (ref eq)) (global.get $void))
               (global $prop:equal+hash               (mut (ref eq)) (global.get $void))
               (global $equal+hash-recur/equal        (mut (ref eq)) (global.get $void))
               (global $equal+hash-recur/equal-always (mut (ref eq)) (global.get $void))
               (global $equal+hash-recur/hash         (mut (ref eq)) (global.get $void))
               (global $equal+hash-recur/hash-always  (mut (ref eq)) (global.get $void))
               (global $break-enabled-key             (mut (ref eq)) (global.get $void))
               (global $exception-handler-key         (mut (ref eq)) (global.get $void))
               (global $parameterization-key          (mut (ref eq)) (global.get $void))
               (global $cache-configuration-values    (mut (ref eq)) (global.get $void))
               (global $debug-allocation-budget        (mut i32)      (i32.const 0))
               (global $debug-allocation-pairs         (mut i32)      (i32.const 0))
               (global $debug-allocation-vectors       (mut i32)      (i32.const 0))
               (global $debug-allocation-structs       (mut i32)      (i32.const 0))
               (global $debug-allocation-hash-sets     (mut i32)      (i32.const 0))
               (global $debug-allocation-closures      (mut i32)      (i32.const 0))
               (global $debug-allocation-arg-arrays    (mut i32)      (i32.const 0))
               (global $debug-allocation-strings       (mut i32)      (i32.const 0))
               (global $debug-allocation-bytes         (mut i32)      (i32.const 0))
               (global $debug-allocation-value-arrays  (mut i32)      (i32.const 0))
               (global $debug-allocation-free-arrays   (mut i32)      (i32.const 0))
               (global $debug-invoke-budget            (mut i32)      (i32.const 0))
               (global $debug-invocations              (mut i32)      (i32.const 0))
               (global $debug-label102683-count        (mut i32)      (i32.const 0))
               (global $debug-current-procedure        (mut (ref eq)) (global.get $false))
               (global $debug-current-procedure-name   (mut (ref eq)) (global.get $false))

               (func $get-bytes (export "get_bytes")
                     (result (ref $Bytes))
                     (ref.cast (ref $Bytes) (global.get $result-bytes)))

               (func $entry-uncaught-exception2
                     (param $e (ref eq))
                     (local $message (ref eq))

                     ;; Keep this intentionally verbose for bootstrap probes:
                     ;; a malformed exception may have an undefined message,
                     ;; so log both the full exception shape and its message.
                     (drop (call $js-log (call $format/display (local.get $e))))
                     (local.set $message (call $exn-message (local.get $e)))
                     (drop (call $js-log (local.get $message)))
                     (drop (call $js-log (call $format/display (local.get $message)))))

               (func $entry-uncaught-exception1
                     (param $e (ref eq))
                     (drop (call $js-log (local.get $e))))

               (func $entry-uncaught-exception
                     (param $e (ref eq))
                     (if (ref.eq (call $exn? (local.get $e)) (global.get $false))
                         (then
                         (call $entry-uncaught-exception1 (local.get $e)))
                         (else
                          (call $entry-uncaught-exception2 (local.get $e))))
                     (throw $exn (local.get $e)))

               (func $entry (export "entry") (result i32)
                     ; Declare local variables (bound by let-values and letrec-values)
                     (local $entry-exn (ref eq))
                     ,@(let ()
                         (define (Local  x)
                           (match x
                             [(list v t)      `(local ,(if (symbol? v) v (Var v)) ,t)]
                             [(list v t init) `(local ,(if (symbol? v) v (Var v)) ,t)]))
                         (define (Local* xs) (map Local xs))
                         (Local* (reverse entry-locals)))

                     ;; Initialize global constants
                     (global.set $flzero  (call $i32->flonum (i32.const 0)))
                     (global.set $flone   (call $i32->flonum (i32.const 1)))
                     (global.set $fltwo   (call $i32->flonum (i32.const 2)))
                     (global.set $flthree (call $i32->flonum (i32.const 3)))

                     ;; Initialize global state
                     (call $initialize-the-symbol-table)  ; for interning
                     (call $initialize-the-keyword-table) ; for interning
                     (call $initialize-primitive-table-user-installed)
                     (call $initialize-prefab-struct-type-registry)

                     ;; Initialize string constants used in the runtime
                     ,@(initialize-runtime-string-constants)
                     ;; Initialize bytes constants used in the runtime
                     ,@(initialize-runtime-bytes-constants)
                     ;; Initialize symbol constants used in the runtime
                     ,@(initialize-runtime-symbol-constants)
                     (global.set $break-enabled-key
                                 (global.get $symbol:break-enabled-key))
                     (global.set $exception-handler-key
                                 (global.get $symbol:exception-handler-key))
                     (global.set $parameterization-key
                                 (global.get $symbol:parameterization-key))
                     (global.set $current-parameterization-value
                                 (struct.new $Parameterization
                                             (i32.const 0)
                                             (global.get $false)
                                             (global.get $null)))
                     (global.set $current-pseudo-random-generator-value
                                 (struct.new $PseudoRandomGenerator
                                             (i32.const 0)
                                             (i32.const 0x9E3779B9)))
                     (global.set $current-thread-value
                                 (struct.new $Thread (i32.const 0)))
                     (global.set $current-thread-group-value
                                 (struct.new $ThreadGroup
                                             (i32.const 0)
                                             (global.get $false)))
                     (global.set $current-logger-value
                                 (struct.new $Logger
                                             (i32.const 0)
                                             (global.get $false)))
                     (global.set $current-custodian-value
                                 (struct.new $Custodian
                                             (i32.const 0)
                                             (i32.const 0)))
                     (global.set $always-evt
                                 (struct.new $AlwaysEvt (i32.const 0)))
                     (global.set $never-evt
                                 (struct.new $NeverEvt (i32.const 0)))

                     ;; Initialize struct-type properties provided by the runtime
                     (global.set $prop:sealed
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:sealed))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:evt
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:evt))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:object-name
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:object-name))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:procedure
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:procedure))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:exn:srclocs
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:exn:srclocs))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     ;; Reference: prop:input-port and prop:output-port identify
                     ;; structure types whose instances can stand in for ports.
                     ;; This initializes the property identities needed by
                     ;; racket/pretty; port coercion through the properties is
                     ;; implemented when a primitive actually consumes the struct
                     ;; as a port.
                     (global.set $prop:input-port
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:input-port))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:output-port
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:output-port))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     ;; Reference: impersonator-prop:application-mark is an
                     ;; impersonator property recognized by procedure
                     ;; impersonators. WebRacket has no impersonators yet, but
                     ;; contracts expect the property identity to exist.
                     (global.set $impersonator-prop:application-mark
                                 (ref.cast (ref eq)
                                           (struct.new $ImpersonatorProperty
                                                       (i32.const 0)
                                                       (global.get $symbol:impersonator-prop:application-mark))))
                     (global.set $prop:checked-procedure
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:checked-procedure))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:impersonator-of
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:impersonator-of))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:method-arity-error
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:method-arity-error))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:arity-string
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:arity-string))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:incomplete-arity
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:incomplete-arity))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:authentic
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:authentic))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:custom-write
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:custom-write))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:custom-print-quotable
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:custom-print-quotable))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:equal+hash
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:equal+hash))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $equal+hash-recur/equal
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 4))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/equal)
                                             (array.new_fixed $Free 0)))
                     (global.set $equal+hash-recur/equal-always
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 4))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/equal-always)
                                             (array.new_fixed $Free 0)))
                     (global.set $equal+hash-recur/hash
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 2))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/hash)
                                             (array.new_fixed $Free 0)))
                     (global.set $equal+hash-recur/hash-always
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 2))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/hash-always)
                                             (array.new_fixed $Free 0)))


                     ;; Default to the host platform's path convention (currently Unix)
                     (global.set $system-path-convention (global.get $symbol:unix))
                     (global.set $current-environment-variables-value
                                 (struct.new $EnvironmentVariables
                                             (i32.const 0)))
                     (global.set $current-directory-path
                                 (call $bytes->path
                                       (global.get $bytes:app-dir)
                                       (global.get $missing)))
                     (global.set $current-directory-for-user-path
                                 (global.get $current-directory-path))
                     (drop (call $reset-current-input-port!))
                     (drop (call $reset-current-output-port!))
                     (drop (call $reset-current-error-port!))

                     (global.set $char-general-category-symbols
                                 (array.new_fixed $Array 30
                                                  (global.get $symbol:lu)
                                                  (global.get $symbol:ll)
                                                  (global.get $symbol:lt)
                                                  (global.get $symbol:lm)
                                                  (global.get $symbol:lo)
                                                  (global.get $symbol:mn)
                                                  (global.get $symbol:mc)
                                                  (global.get $symbol:me)
                                                  (global.get $symbol:nd)
                                                  (global.get $symbol:nl)
                                                  (global.get $symbol:no)
                                                  (global.get $symbol:ps)
                                                  (global.get $symbol:pe)
                                                  (global.get $symbol:pi)
                                                  (global.get $symbol:pf)
                                                  (global.get $symbol:pd)
                                                  (global.get $symbol:pc)
                                                  (global.get $symbol:po)
                                                  (global.get $symbol:sc)
                                                  (global.get $symbol:sm)
                                                  (global.get $symbol:sk)
                                                  (global.get $symbol:so)
                                                  (global.get $symbol:zs)
                                                  (global.get $symbol:zp)
                                                  (global.get $symbol:zl)
                                                  (global.get $symbol:cc)
                                                  (global.get $symbol:cf)
                                                  (global.get $symbol:cs)
                                                  (global.get $symbol:co)
                                                  (global.get $symbol:cn)))

                     ;; ;; Initialize realm symbols
                     ;; (global.set $the-racket-realm
                     ;;             (call $string->symbol
                     ;;                   (ref.cast (ref $String)
                     ;;                             (global.get $string:racket))))
                     ;; (global.set $the-racket/primitive-realm
                     ;;             (call $string->symbol
                     ;;                   (ref.cast
                     ;;                    (ref $String)
                     ;;                    (global.get $string:racket/primitive))))
                     (global.set $the-racket-realm           (global.get $symbol:racket))
                     (global.set $the-racket/primitive-realm (global.get $symbol:racket/primitive))

                    ;; Initialize variables holding primitives
                    ,@(initialize-primitives-as-globals)
                    ,@(initialize-ffi-primitives-as-globals)
                    (call $initialize-unsafe-ffi-primitive-table)
                    (global.set $current-security-guard-value
                                (struct.new $SecurityGuard
                                            (i32.const 0)
                                            (global.get $false)
                                            (ref.cast (ref $Procedure) (global.get $prim:void))
                                            (ref.cast (ref $Procedure) (global.get $prim:void))
                                            (ref.cast (ref $Procedure) (global.get $prim:void))))
                    (global.set $error-value->string-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-value->string-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-error-value->string-handler)
                                            (global.get $false)))
                    (global.set $current-read-interaction-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:current-read-interaction)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-current-read-interaction)
                                            (global.get $false)))
                    (global.set $default-port-read-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:port-read-handler)
                                            (ref.i31 (i32.const 2))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-1)
                                            (ref.func $default-port-read-handler/1)
                                            (global.get $false)))
                    (global.set $default-port-write-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:port-write-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-port-write-handler)
                                            (global.get $false)))
                    (global.set $default-port-display-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:port-display-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-port-display-handler)
                                            (global.get $false)))
                    (global.set $default-port-print-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:port-print-handler)
                                            (ref.i31 (i32.const 12))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-14)
                                            (ref.func $default-port-print-handler)
                                            (global.get $false)))
                    (global.set $error-syntax->string-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-syntax->string-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-error-syntax->string-handler)
                                            (global.get $false)))
                    (global.set $error-syntax->name-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-syntax->name-handler)
                                            (ref.i31 (i32.const 2))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-1)
                                            (ref.func $default-error-syntax->name-handler)
                                            (global.get $false)))
                    (global.set $error-module-path->string-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-module-path->string-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-error-module-path->string-handler)
                                            (global.get $false)))

                     ;; Initialize top-level variables.
                     ;; These are all "boxed".
                     ,@(let ()
                         (for/list ([v top-vars])
                           `(global.set ,(TopVar v)
                                        (struct.new $Boxed
                                                    (global.get $undefined)))
                           #;`(global.set ,(TopVar v)
                                        (struct.new $Boxed
                                                    (global.get ,(TopVar v))))))

                     ;; Populate exception struct type descriptor bindings.
                     ;;   struct:exn, struct:exn:fail, etc
                     ,@(for/list ([binding exception-struct-type-bindings])
                         (define name    (car binding))
                         (define ensure  (cadr binding))
                         (define $name   (string->symbol (~a "$" (symbol->string name))))
                         (define $ensure ($ ensure))
                         `(global.set ,$name (call ,$ensure)))

                     ;; Initialize the top-level namespace
                     (global.set $top-level-namespace
                                 (ref.cast (ref $Namespace) (call $make-empty-namespace)))
                     (global.set $current-namespace-value
                                 (ref.cast (ref eq) (global.get $top-level-namespace)))


                     ; Initialize local variables
                     ,@(let ()
                         (define (Init  x)
                           (match x
                             [(list v t)
                              (if (equal? t '(ref eq))
                                  `(local.set ,(if (symbol? v) v (Var v))
                                              ,(Undefined))
                                  `(nop))]
                             [(list v t init)
                              `(local.set ,(if (symbol? v) v (Var v)) ,init)]))
                         (define (Init* xs) (map Init xs))
                         (Init* entry-locals))

                     ; This runs `entry-body`. An exception handler is
                     ; installed to catch exceptions not handled by the
                     ; user program.
                     (block $entry-done
                            (local.set $entry-exn
                                       (block $entry-handler (result (ref eq))
                                              (try_table (result (ref eq))
                                                         (catch $exn $entry-handler)
                                                         ,entry-body
                                                         (br $entry-done))))
                            (call $entry-uncaught-exception (local.get $entry-exn))
                            (unreachable))

                     ; Return the result
                     (global.set $result-bytes
                                 (call $string->bytes/utf-8
                                       (call $format/display (global.get ,result))
                                       (global.get $false)   ; ignored
                                       (global.get $zero)    ; start = 0
                                       (global.get $false))) ; end

                     (call $copy-bytes-to-memory ; copy and return length as i32
                           (global.get $result-bytes) (i32.const 0)))

               ))

    (time-runtime-step
     "runtime:ffi-wrapper-filter"
     (λ ()
       (define active-ffi-primitive-names
         (if (and (current-tree-shake?)
                  (not (memq 'unsafe-ffi-primitive used-primitives)))
             (sort
              (filter (λ (pr) (hash-ref ffi-primitive-name-set pr #f))
                      (remove-duplicates used-primitives))
             symbol<?)
             (sort (hash-keys ffi-primitive-name-set) symbol<?)))
       (set! active-ffi-foreigns
             (for/list ([f (in-list all-ffi-foreigns)]
                        #:when (memq (foreign-racket-name f) active-ffi-primitive-names))
               f))
       (define active-ffi-import-name-set
         (list->eq-set (map ffi-import-name active-ffi-foreigns)))
       (define active-ffi-func-name-set
         (list->eq-set (map (λ (f) ($ (foreign-racket-name f))) active-ffi-foreigns)))
       (set! active-ffi-imports-wat
             (remove-duplicates
              (for/list ([form (in-list (current-ffi-imports-wat))]
                         #:do [(define name (module-func-name form))]
                         #:when (and name
                                     (hash-ref active-ffi-import-name-set name #f)))
                form)
              eq?
              #:key module-func-name))
       (set! active-ffi-funcs-wat
             (remove-duplicates
              (for/list ([form (in-list (current-ffi-funcs-wat))]
                         #:do [(define name (module-func-name form))]
                         #:when (and name
                                     (hash-ref active-ffi-func-name-set name #f)))
                form)
              eq?
              #:key module-func-name))))
    (runtime-metric-add! "runtime:target"
                         (if (current-browser?) "browser" "node"))
    (runtime-metric-add! "runtime:ffi-foreign-count"
                         (length active-ffi-foreigns))
    (runtime-metric-add! "runtime:ffi-foreign-fingerprint"
                         (format "~x"
                                 (abs (equal-hash-code
                                       (sort (map foreign-racket-name active-ffi-foreigns)
                                             symbol<?)))))
    (runtime-metric-add! "runtime:program-primitive-count"
                         (length used-primitives))
    (define full-module
      (time-runtime-step "runtime:build-runtime-module" build-runtime-module))
    (runtime-metric-add! "runtime:module-bytes-before-prune"
                         (module-byte-size full-module))
    (runtime-metric-add! "runtime:function-count-before-prune"
                         (module-func-count full-module))
    (runtime-metric-add! "runtime:global-count-before-prune"
                         (module-global-count full-module))
    (runtime-metric-add! "runtime:export-count-before-prune"
                         (module-export-count full-module))
    (define-values (runtime-forms-before-prune program-forms-before-prune)
      (split-module-forms full-module))
    (runtime-metric-add! "runtime:runtime-form-count-before-prune"
                         (length runtime-forms-before-prune))
    (runtime-metric-add! "runtime:program-form-count-before-prune"
                         (length program-forms-before-prune))
    (define runtime-only-global-names
      (for/list ([form (in-list runtime-forms-before-prune)]
                 #:do [(define name (module-global-name form))]
                 #:when name)
        name))
    (define runtime-only-data-names
      (for/list ([form (in-list runtime-forms-before-prune)]
                 #:do [(define name (module-data-name form))]
                 #:when name)
        name))
    (runtime-metric-add! "runtime:runtime-string-global-count"
                         (symbol-prefix-count runtime-only-global-names "$string:"))
    (runtime-metric-add! "runtime:runtime-bytes-global-count"
                         (symbol-prefix-count runtime-only-global-names "$bytes:"))
    (runtime-metric-add! "runtime:runtime-symbol-global-count"
                         (symbol-prefix-count runtime-only-global-names "$symbol:"))
    (runtime-metric-add! "runtime:runtime-string-data-count"
                         (symbol-prefix-count runtime-only-data-names "$string-data:"))
    (runtime-metric-add! "runtime:runtime-bytes-data-count"
                         (symbol-prefix-count runtime-only-data-names "$bytes-data:"))
    (runtime-metric-add! "runtime:runtime-symbol-data-count"
                         (symbol-prefix-count runtime-only-data-names "$symbol-data:"))
    (runtime-metric-add! "runtime:program-function-count-before-prune"
                         (length program-function-names))
    (runtime-metric-add! "runtime:program-global-count-before-prune"
                         (length top-level-variable-declarations))
    (define runtime-only-module
      (forms->module runtime-forms-before-prune))
    (define stable-runtime-module
      (stable-runtime-analysis-module runtime-only-module))
    (define program-only-forms
      program-forms-before-prune)
    (define stable-runtime-cache-fingerprint
      (stable-runtime-analysis-cache-fingerprint stable-runtime-module))
    (runtime-metric-add! "runtime:stable-runtime-fingerprint"
                         (format "~x"
                                 (abs (equal-hash-code
                                       stable-runtime-cache-fingerprint))))
    (define stable-runtime-cache-path
      (stable-runtime-analysis-cache-path stable-runtime-cache-fingerprint))
    (runtime-metric-add! "tree-shake:runtime-analysis-v2-cache-enabled?"
                         (if stable-runtime-cache-path "yes" "no"))
    (define cached-stable-runtime-analysis
      (time-runtime-step
       "tree-shake:runtime-analysis-v2-cache-lookup"
       (lambda ()
         (read-stable-runtime-analysis-cache stable-runtime-cache-path
                                             stable-runtime-cache-fingerprint))))
    (define stable-runtime-analysis
      (cond
        [cached-stable-runtime-analysis
         (runtime-metric-add! "tree-shake:runtime-analysis-v2-cache-hit?" "yes")
         (time-runtime-step
          "tree-shake:runtime-analysis-v2-cache-hit"
          (lambda ()
            cached-stable-runtime-analysis))]
        [else
         (runtime-metric-add! "tree-shake:runtime-analysis-v2-cache-hit?" "no")
         (define computed-stable-runtime-analysis
           (time-runtime-step
            "tree-shake:analyze-stable-runtime"
            (lambda ()
              (analyze-stable-runtime stable-runtime-module))))
         (time-runtime-step
          "tree-shake:runtime-analysis-v2-cache-write"
          (lambda ()
            (write-stable-runtime-analysis-cache! stable-runtime-cache-path
                                                  stable-runtime-cache-fingerprint
                                                  computed-stable-runtime-analysis)))
         computed-stable-runtime-analysis]))
    (define program-analysis
      (time-runtime-step
       "tree-shake:analyze-program-fragment"
       (lambda ()
         (analyze-program-fragment program-only-forms
                                   stable-runtime-analysis))))
    (define analysis
      (time-runtime-step
       "tree-shake:combine-analysis"
       (lambda ()
         (append stable-runtime-analysis
                 program-analysis))))
    (define-values (retained-primitives retained-functions)
      (time-runtime-step
       "tree-shake:retain-closure"
       (λ ()
         (if (current-tree-shake?)
             (let loop ([retained-primitives (primitive-retained-set analysis)])
               (define retained-functions
                 (retained-function-set analysis retained-primitives))
               (define next-primitives
                 (sort (remove-duplicates
                        (append retained-primitives
                                (primitive-refs-for-functions analysis retained-functions)))
                       symbol<?))
               (if (equal? next-primitives retained-primitives)
                   (values retained-primitives retained-functions)
                   (loop next-primitives)))
             (values (sort described-primitives symbol<?)
                     '())))))
    (runtime-metric-add! "tree-shake:root-primitive-count"
                         (length retained-primitives))
    (runtime-metric-add! "tree-shake:retained-function-count"
                         (length retained-functions))
    (time-runtime-step
     "tree-shake:write-report"
     (λ ()
       (write-runtime-primitive-report! analysis retained-primitives)))
    (set! active-primitives retained-primitives)
    (define final-module
      (if (current-tree-shake?)
          (time-runtime-step
           "tree-shake:prune-runtime-module"
           (λ ()
             (prune-runtime-module full-module retained-primitives retained-functions)))
          full-module))
    (runtime-metric-add! "tree-shake:enabled?"
                         (if (current-tree-shake?) "yes" "no"))
    (runtime-metric-add! "tree-shake:retained-primitive-count"
                         (length retained-primitives))
    (runtime-metric-add! "tree-shake:removed-primitive-count"
                         (- (length described-primitives)
                            (length retained-primitives)))
    (runtime-metric-add! "tree-shake:function-count-after-prune"
                         (module-func-count final-module))
    (runtime-metric-add! "tree-shake:global-count-after-prune"
                         (module-global-count final-module))
    (runtime-metric-add! "tree-shake:module-bytes-after-prune"
                         (module-byte-size final-module))
    final-module
    )))
