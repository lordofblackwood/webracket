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
         (only-in "runtime-wasm/entry-initializers.rkt"
                  entry-struct-property-global-forms
                  entry-struct-property-initializer-forms)
         (only-in "runtime-wasm/entry-support.rkt"
                  entry-support-forms)
         (only-in "runtime-wasm/function-declarations.rkt"
                  runtime-function-declaration-forms)
         (only-in "runtime-wasm/js-imports.rkt"
                  js-host-import-forms)
         (only-in "runtime-wasm/module-forms.rkt"
                  module-func-name
                  module-global-name
                  module-data-name
                  module-write-bytes
                  module-func-count
                  module-global-count
                  module-export-count
                  module-byte-size
                  symbol-prefix-count
                  forms->module)
         (only-in "runtime-wasm/core/arrays.rkt"
                  array-core-runtime-helper-forms
                  array-runtime-helper-forms
                  array-runtime-only-helper-names
                  array-runtime-only-helpers)
         (only-in "runtime-wasm/core/booleans.rkt"
                  boolean-runtime-helper-forms
                  boolean-runtime-only-helpers)
         (only-in "runtime-wasm/core/boxes.rkt"
                  box-runtime-helper-forms
                  box-mutability-runtime-helper-forms
                  box-runtime-only-helpers)
         (only-in "runtime-wasm/core/bytes.rkt"
                  bytes-core-runtime-helper-forms
                  bytes-main-runtime-helper-forms
                  bytes-mutability-runtime-helper-forms
                  bytes-runtime-only-helpers)
         (only-in "runtime-wasm/core/characters.rkt"
                  character-general-category-global-forms
                  character-general-category-initializer-forms
                  character-runtime-helper-forms
                  character-runtime-only-helpers)
         (only-in "runtime-wasm/core/checkers.rkt"
                  checker-runtime-helper-forms
                  checker-runtime-only-helpers)
         (only-in "runtime-wasm/core/closures.rkt"
                  closure-empty-free-global-forms
                  closure-runtime-global-forms)
         (only-in "runtime-wasm/core/control-flow.rkt"
                  continuation-mark-runtime-helper-forms
                  continuation-runtime-helper-forms
                  multiple-value-runtime-helper-forms
                  value-expectation-runtime-helper-forms
                  control-flow-runtime-only-helpers)
         (only-in "runtime-wasm/core/equality.rkt"
                  equality-runtime-only-helpers
                  immutable-predicate-runtime-helper-forms
                  equality-runtime-helper-forms)
         (only-in "runtime-wasm/core/exceptions.rkt"
                  bootstrap-error-runtime-helper-forms
                  exception-struct-type-bindings
                  exception-struct-type-cache-global-forms
                  exception-struct-type-global-forms
                  exception-struct-type-initializer-forms
                  exception-contract-runtime-helper-forms
                  exception-contract-runtime-only-helpers
                  exception-runtime-helper-forms
                  exception-runtime-only-helpers)
         (only-in "runtime-wasm/core/events.rkt"
                  event-global-forms
                  event-initializer-forms
                  event-channel-runtime-helper-forms
                  event-sync-runtime-helper-forms
                  event-runtime-only-helpers)
         (only-in "runtime-wasm/core/fasl.rkt"
                  fasl-tag-runtime-helper-forms
                  fasl-encoding-runtime-helper-forms
                  fasl-decoding-runtime-helper-forms
                  fasl-runtime-only-helpers)
         (only-in "runtime-wasm/core/ffi.rkt"
                  external-value-runtime-helper-forms
                  ffi-callback-global-forms
                  ffi-entry-global-forms
                  ffi-runtime-only-helpers
                  ffi-runtime-only-helper-forms
                  unsafe-ffi-primitive-table-global-forms
                  unsafe-ffi-runtime-only-helper-forms)
         (only-in "runtime-wasm/core/filesystem.rkt"
                  filesystem-temporary-global-forms
                  filesystem-runtime-only-helpers
                  filesystem-runtime-helper-forms)
         (only-in "runtime-wasm/core/fixnums.rkt"
                  fixnum-global-forms
                  fixnum-runtime-helper-forms
                  fixnum-runtime-only-helpers)
         (only-in "runtime-wasm/core/flonums.rkt"
                  flonum-global-forms
                  flonum-initializer-forms
                  flonum-runtime-helper-forms
                  flonum-runtime-only-helpers)
         (only-in "runtime-wasm/core/formatting.rkt"
                  printer-extension-runtime-helper-forms
                  unquoted-printing-string-runtime-helper-forms
                  formatting-runtime-helper-forms
                  numeric-display-formatting-runtime-helper-forms
                  formatting-runtime-only-helpers)
         (only-in "runtime-wasm/core/growable-arrays.rkt"
                  growable-array-core-runtime-helper-forms)
         (only-in "runtime-wasm/core/growable-bytes.rkt"
                  growable-bytes-core-runtime-helper-forms)
         (only-in "runtime-wasm/core/growable-i32-arrays.rkt"
                  growable-i32-array-core-runtime-helper-forms)
         (only-in "runtime-wasm/core/hashes.rkt"
                  hash-code-runtime-helper-forms
                  hash-runtime-only-helpers
                  hash-seed-global-forms
                  hash-predicate-runtime-helper-forms
                  hash-table-predicate-runtime-helper-forms
                  hash-table-operation-runtime-helper-forms)
         (only-in "runtime-wasm/core/immutable-hashes.rkt"
                  immutable-hash-prelude-runtime-helper-forms
                  immutable-hash-public-set/remove-runtime-helper-forms
                  immutable-hash-public-update-runtime-helper-forms
                  immutable-hash-public-clear-runtime-helper-forms
                  immutable-hash-iteration-runtime-helper-forms
                  immutable-hash-runtime-only-helpers)
         (only-in "runtime-wasm/core/i32-arrays.rkt"
                  i32-array-core-runtime-helper-forms
                  i32-array-runtime-helper-forms
                  i32-array-runtime-only-helpers)
         (only-in "runtime-wasm/core/i8-arrays.rkt"
                  i8-array-core-runtime-helper-forms
                  i8-array-error-runtime-helper-forms
                  i8-array-conversion-runtime-helper-forms
                  i8-array-runtime-only-helpers)
         (only-in "runtime-wasm/core/immediates.rkt"
                  singleton-global-forms
                  void-runtime-helper-forms
                  eof-object-runtime-helper-forms
                  immediate-runtime-only-helpers)
         (only-in "runtime-wasm/core/impersonators.rkt"
                  chaperone-procedure-runtime-only-helper-names
                  impersonator-basic-runtime-only-helper-names
                  impersonator-runtime-only-helpers)
         (only-in "runtime-wasm/core/io-handlers.rkt"
                  io-handler-default-port-global-forms
                  io-handler-default-port-late-initializer-forms
                  io-handler-error-runtime-helper-forms
                  io-handler-port-runtime-helper-forms
                  io-handler-reader-printer-runtime-helper-forms
                  io-handler-runtime-only-helpers)
         (only-in "runtime-wasm/core/keywords.rkt"
                  keyword-core-runtime-helper-forms
                  keyword-table-global-forms
                  keyword-table-initializer-runtime-helper-forms
                  keyword-runtime-helper-forms
                  keyword-runtime-only-helpers)
         (only-in "runtime-wasm/core/lists.rkt"
                  list-pre-contract-runtime-helper-forms
                  list-post-contract-runtime-helper-forms
                  pair-global-forms
                  list-runtime-only-helpers)
         (only-in "runtime-wasm/core/linklet-instances.rkt"
                  linklet-instance-runtime-helper-forms
                  linklet-instance-runtime-only-helpers)
         (only-in "runtime-wasm/core/linklets.rkt"
                  linklet-bootstrap-runtime-only-helper-names
                  linklet-body-core-reserved-symbols
                  linklet-bootstrap-runtime-only-helpers
                  linklet-interpreter-runtime-only-helper-names
                  linklet-interpreter-runtime-only-helpers
                  primitive-table-module-symbols
                  linklet-primitive-table-global-forms
                  linklet-primitive-table-initializer-runtime-only-helper-names
                  linklet-primitive-table-initializer-runtime-only-helpers
                  linklet-primitive-table-runtime-only-helper-forms
                  linklet-runtime-only-helper-forms)
         (only-in "runtime-wasm/core/locations.rkt"
                  location-global-forms
                  location-initial-runtime-helper-forms
                  location-runtime-only-helpers
                  source-location-runtime-helper-forms)
         (only-in "runtime-wasm/core/locks.rkt"
                  lock-runtime-helper-forms
                  lock-runtime-only-helpers)
         (only-in "runtime-wasm/core/loggers.rkt"
                  logger-current-global-forms
                  logger-current-initializer-forms
                  logger-runtime-helper-forms
                  logger-runtime-only-helpers)
         (only-in "runtime-wasm/core/memory-map.rkt"
                  memory-map-global-forms)
         (only-in "runtime-wasm/core/mlists.rkt"
                  mlist-core-runtime-helper-forms)
         (only-in "runtime-wasm/core/mutable-hashes.rkt"
                  mutable-hash-constructor-runtime-helper-forms
                  mutable-hash-empty-iteration-runtime-helper-forms
                  mutable-hash-read-runtime-helper-forms
                  mutable-hash-remove-membership-clear-runtime-helper-forms
                  mutable-hash-runtime-only-helpers
                  mutable-hash-update-runtime-helper-forms
                  mutable-hash-write-runtime-helper-forms)
         (only-in "runtime-wasm/core/namespaces.rkt"
                  namespace-current-global-forms
                  namespace-initializer-forms
                  namespace-module-registry-global-forms
                  namespace-runtime-only-helpers
                  namespace-runtime-helper-forms
                  namespace-top-level-global-forms)
         (only-in "runtime-wasm/core/numbers.rkt"
                  generic-arithmetic-runtime-helper-forms
                  generic-bitwise-runtime-helper-forms
                  generic-numeric-runtime-helper-forms
                  number-error-runtime-helper-forms
                  number-runtime-only-helpers
                  number-string-conversion-runtime-helper-forms
                  floating-point-byte-conversion-runtime-helper-forms
                  numeric-formatting-runtime-helper-forms
                  string-number-conversion-runtime-helper-forms
                  number-type-runtime-helper-forms)
         (only-in "runtime-wasm/core/parameters.rkt"
                  compile-parameter-global-forms
                  compile-parameter-runtime-helper-forms
                  namespace-parameter-runtime-helper-forms
                  parameterization-binding-runtime-helper-forms
                  parameterization-call-runtime-helper-forms
                  parameter-directory-runtime-helper-forms
                  parameter-error-rendering-runtime-helper-forms
                  parameterization-global-forms
                  parameterization-initializer-forms
                  parameterization-runtime-helper-forms
                  parameter-runtime-only-helpers
                  parameter-width-runtime-helper-forms
                  error-rendering-handler-global-forms
                  error-value-handler-late-initializer-forms
                  error-syntax-handler-late-initializer-forms
                  print-read-parameter-global-forms
                  print-read-parameter-late-initializer-forms
                  environment-parameter-global-forms
                  environment-parameter-initializer-forms
                  reader-printer-policy-parameter-global-forms
                  reader-printer-policy-parameter-helper-forms)
         (only-in "runtime-wasm/core/paths.rkt"
                  path-current-global-forms
                  path-current-initializer-forms
                  path-runtime-only-helpers
                  path-runtime-helper-forms
                  path-manipulation-runtime-helper-forms)
         (only-in "runtime-wasm/core/ports.rkt"
                  port-call-with-output-string-runtime-helper-forms
                  port-current-global-forms
                  port-custom-constructor-runtime-helper-forms
                  port-input-runtime-helper-forms
                  port-location-runtime-helper-forms
                  port-output-predicate-runtime-helper-forms
                  port-output-runtime-helper-forms
                  port-output-string-runtime-helper-forms
                  port-predicate-runtime-helper-forms
                  port-state-runtime-helper-forms
                  port-string-constructor-runtime-helper-forms
                  port-runtime-only-helpers)
         (only-in "runtime-wasm/core/procedures.rkt"
                  procedure-global-forms
                  primitive-reflection-runtime-helper-forms
                  procedure-arity-mask-runtime-helper-forms
                  procedure-bootstrap-runtime-helper-forms
                  procedure-main-runtime-helper-forms
                  procedure-post-primitive-invoker-runtime-helper-forms
                  procedure-rest-argument-core-runtime-helper-forms
                  primitive-shapes
                  procedure-primitive-global-forms
                  procedure-ffi-primitive-global-forms
                  procedure-primitive-initializer-forms
                  procedure-ffi-primitive-initializer-forms
                  procedure-primitive-invoker-forms
                  procedure-runtime-only-helpers)
         (only-in "runtime-wasm/core/random.rkt"
                  random-current-global-forms
                  random-current-initializer-forms
                  random-generator-runtime-helper-forms
                  random-public-runtime-helper-forms
                  random-state-global-forms
                  random-runtime-only-helpers)
         (only-in "runtime-wasm/core/realms.rkt"
                  realm-global-forms
                  realm-initializer-forms)
         (only-in "runtime-wasm/core/regexps.rkt"
                  regexp-runtime-helper-forms
                  regexp-runtime-only-helpers)
         (only-in "runtime-wasm/core/runtime-constants.rkt"
                  make-core-populated-runtime-constant-registry)
         (only-in "runtime-wasm/core/reflection.rkt"
                  reflection-runtime-helper-forms
                  reflection-runtime-only-helpers)
         (only-in "runtime-wasm/core/security.rkt"
                  custodian-current-initializer-forms
                  custodian-runtime-helper-forms
                  inspector-runtime-helper-forms
                  security-current-global-forms
                  security-guard-current-initializer-forms
                  security-post-parameter-runtime-helper-forms
                  security-pre-parameter-runtime-helper-forms
                  security-runtime-only-helpers)
         (only-in "runtime-wasm/core/semaphores.rkt"
                  semaphore-runtime-helper-forms
                  semaphore-runtime-only-helpers)
         (only-in "runtime-wasm/core/stencil-vectors.rkt"
                  stencil-vector-runtime-helper-forms
                  stencil-vector-runtime-only-helpers)
         (only-in "runtime-wasm/core/strings.rkt"
                  string-buffer-runtime-helper-forms
                  string-hash-core-runtime-helper-forms
                  string-main-runtime-helper-forms
                  string-mutability-runtime-helper-forms
                  string-runtime-only-helpers)
         (only-in "runtime-wasm/core/structs.rkt"
                  struct-basic-runtime-helper-forms
                  struct-construction-runtime-helper-forms
                  struct-constructor-access-runtime-helper-forms
                  struct-core-predicate-runtime-helper-forms
                  struct-prefab-registry-runtime-helper-forms
                  struct-prefab-runtime-helper-forms
                  struct-procedure-invoker-runtime-helper-forms
                  struct-procedure-runtime-helper-forms
                  struct-type-property-runtime-helper-forms
                  struct-prefab-registry-global-forms
                  struct-runtime-only-helpers)
         (only-in "runtime-wasm/core/symbols.rkt"
                  symbol-gensym-global-forms
                  symbol-gensym-runtime-helper-forms
                  symbol-public-runtime-helper-forms
                  symbol-table-global-forms
                  symbol-table-runtime-helper-forms
                  symbol-table-initializer-runtime-helper-forms
                  symbol-runtime-only-helpers)
         (only-in "runtime-wasm/core/system.rkt"
                  system-runtime-helper-forms
                  system-runtime-only-helpers)
         (only-in "runtime-wasm/core/syntax.rkt"
                  correlated-syntax-runtime-helper-forms
                  syntax-global-forms
                  syntax-runtime-only-helpers
                  syntax-runtime-helper-forms)
         (only-in "runtime-wasm/core/threads.rkt"
                  thread-current-global-forms
                  thread-current-initializer-forms
                  thread-group-current-global-forms
                  thread-runtime-helper-forms
                  thread-runtime-only-helpers)
         (only-in "runtime-wasm/core/time.rkt"
                  time-runtime-only-helpers
                  time-runtime-helper-forms)
         (only-in "runtime-wasm/core/treelists.rkt"
                  treelist-constant-global-forms
                  treelist-empty-global-forms
                  treelist-runtime-helper-forms
                  treelist-runtime-only-helpers)
         (only-in "runtime-wasm/core/unsafe.rkt"
                  unsafe-runtime-only-helpers
                  unsafe-runtime-helper-names)
         (only-in "runtime-wasm/core/vectors.rkt"
                  vector-dummy-array-global-forms
                  vector-dummy-global-forms
                  vector-error-runtime-helper-forms
                  vector-main-runtime-helper-forms
                  vector-mutability-runtime-helper-forms
                  vector-post-stencil-runtime-helper-forms
                  vector-runtime-only-helpers)
         (only-in "runtime-wasm/core/wills.rkt"
                  will-runtime-helper-forms
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
(define-runtime-path function-declarations-path "runtime-wasm/function-declarations.rkt")
(define-runtime-path module-forms-path "runtime-wasm/module-forms.rkt")
(define-runtime-path core-booleans-path "runtime-wasm/core/booleans.rkt")
(define-runtime-path core-boxes-path "runtime-wasm/core/boxes.rkt")
(define-runtime-path core-bytes-path "runtime-wasm/core/bytes.rkt")
(define-runtime-path core-characters-path "runtime-wasm/core/characters.rkt")
(define-runtime-path core-checkers-path "runtime-wasm/core/checkers.rkt")
(define-runtime-path core-closures-path "runtime-wasm/core/closures.rkt")
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
(define-runtime-path core-memory-map-path "runtime-wasm/core/memory-map.rkt")
(define-runtime-path core-mlists-path "runtime-wasm/core/mlists.rkt")
(define-runtime-path core-mutable-hashes-path "runtime-wasm/core/mutable-hashes.rkt")
(define-runtime-path core-namespaces-path "runtime-wasm/core/namespaces.rkt")
(define-runtime-path core-numbers-path "runtime-wasm/core/numbers.rkt")
(define-runtime-path core-parameters-path "runtime-wasm/core/parameters.rkt")
(define-runtime-path core-paths-path "runtime-wasm/core/paths.rkt")
(define-runtime-path core-ports-path "runtime-wasm/core/ports.rkt")
(define-runtime-path core-procedures-path "runtime-wasm/core/procedures.rkt")
(define-runtime-path core-random-path "runtime-wasm/core/random.rkt")
(define-runtime-path core-realms-path "runtime-wasm/core/realms.rkt")
(define-runtime-path core-regexps-path "runtime-wasm/core/regexps.rkt")
(define-runtime-path core-runtime-constants-path "runtime-wasm/core/runtime-constants.rkt")
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
           immediate-runtime-only-helpers
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

    (set! active-ffi-imports-wat
          (remove-duplicates active-ffi-imports-wat eq? #:key module-func-name))
    (set! active-ffi-funcs-wat
          (remove-duplicates active-ffi-funcs-wat eq? #:key module-func-name))

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
        (program-constant-global-names string-constants
                                       bytes-constants
                                       symbol-constants))))

    (define program-data-name-set
      (list->eq-set (program-constant-data-names string-constants
                                                 bytes-constants
                                                 symbol-constants)))

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

    ;; runtime-metric-add/computed! : string? (-> any/c) -> void?
    ;;   Compute and record a runtime metric only when metric rows are active.
    (define (runtime-metric-add/computed! label thunk)
      (when (current-runtime-metric-rows)
        (runtime-metric-add! label (thunk))))

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
                                          function-declarations-path
                                          module-forms-path
                                          core-booleans-path
                                          core-boxes-path
                                          core-bytes-path
                                          core-characters-path
                                          core-checkers-path
                                          core-closures-path
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
                                          core-memory-map-path
                                          core-mlists-path
                                          core-mutable-hashes-path
                                          core-namespaces-path
                                          core-numbers-path
                                          core-parameters-path
                                          core-paths-path
                                          core-ports-path
                                          core-procedures-path
                                          core-random-path
                                          core-realms-path
                                          core-regexps-path
                                          core-runtime-constants-path
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
        (module-write-bytes module))))

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
      (procedure-primitive-global-forms (active-described-primitives-sorted)))

    (define (declare-ffi-primitives-as-globals)
      (procedure-ffi-primitive-global-forms (active-ffi-primitive-names)))



    ; If a primitive is handled in the inliner, but hasn't been
    ; implemented here in `runtime-wasm.rkt` then put the symbol here.
    (define todo-handle-later '())

    (define (initialize-primitives-as-globals)
      (procedure-primitive-initializer-forms
       (for/list ([pr (in-list (active-described-primitives-sorted))]
                  #:do [(define desc (primitive->description pr))])
         (list pr
               (primitive-description-arity desc)
               (primitive-description-result-arity desc)))))

    (define (initialize-ffi-primitives-as-globals)
      (procedure-ffi-primitive-initializer-forms
       (for/list ([f (in-list active-ffi-foreigns)])
         (list (foreign-racket-name f)
               (length (foreign-argument-types f))))))

    (define linklet-body-reserved-symbols/registration
      (remove-duplicates (append linklet-body-core-reserved-symbols all-primitives)
                         eq?))

    (define linklet-body-reserved-symbols
      (sort linklet-body-reserved-symbols/registration symbol<?))

    ;; Runtime constants include program constants passed by `generate-code`
    ;; plus constants required by runtime support.
    (define runtime-constant-registry
      (make-core-populated-runtime-constant-registry
       string-constants
       bytes-constants
       symbol-constants
       (active-described-primitives-sorted)
       (active-ffi-primitive-names)
       linklet-body-reserved-symbols/registration))

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

         ,@js-host-import-forms

        ;; FFI related imports
        ,@active-ffi-imports-wat ; generated from "driver.rkt" in "define-foreign.rkt"


         ,@active-ffi-funcs-wat   ; generated from "driver.rkt" in "define-foreign.rkt"

         ;;   Unsafe FFI primitive helpers are implemented in runtime-wasm/core/ffi.rkt.
         ,@(unsafe-ffi-runtime-only-helper-forms active-ffi-foreigns)

         ;;;
         ;;; Exceptions
         ;;;

         ;;   Bootstrap error helpers are implemented in runtime-wasm/core/exceptions.rkt.
         ,@(bootstrap-error-runtime-helper-forms runtime-helper-index)

         ;;   Multiple-value expectation helpers are implemented in runtime-wasm/core/control-flow.rkt.
         ,@(value-expectation-runtime-helper-forms runtime-helper-index)

         ;;   Unquoted printing string helpers are implemented in runtime-wasm/core/formatting.rkt.
         ,@(unquoted-printing-string-runtime-helper-forms runtime-helper-index)

         ,@singleton-global-forms

         ,@fixnum-global-forms

         ,@flonum-global-forms

         ;; Constants used by the program and runtime.
         ,@(runtime-constant-declaration-forms runtime-constant-registry)

         ,@character-general-category-global-forms

         ,@realm-global-forms

         ,@exception-struct-type-cache-global-forms

         ,@location-global-forms

         ,@procedure-global-forms

         ,@syntax-global-forms

         ,@namespace-module-registry-global-forms

         ;; Namespaces
         ,@namespace-top-level-global-forms

         ,@ffi-callback-global-forms

         ;; Primitives (as values)
         ,@(declare-primitives-as-globals)
         ,@(declare-ffi-primitives-as-globals)

         ,@closure-empty-free-global-forms

         ;; Procedure and primitive invocation helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(procedure-bootstrap-runtime-helper-forms runtime-helper-index)

         ,@(procedure-primitive-invoker-forms primitive-shapes)

         ;;   Procedure case-lambda helpers are implemented in runtime-wasm/core/procedures.rkt.
         ,@(procedure-post-primitive-invoker-runtime-helper-forms runtime-helper-index)

         ;;   Struct procedure invoker is implemented in runtime-wasm/core/structs.rkt.
         ,@(struct-procedure-invoker-runtime-helper-forms runtime-helper-index)

         ;;   Procedure rest-argument helpers are implemented in runtime-wasm/core/procedures.rkt.
         ,@(procedure-rest-argument-core-runtime-helper-forms core-runtime-helper-index)

         ;;   Source-linklet interpreter helpers are implemented in runtime-wasm/core/linklets.rkt.
         ,@(for/list ([name (in-list linklet-interpreter-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ,@closure-runtime-global-forms

         ;; Predefined exception struct type descriptors (as boxed top-level bindings)
         ;;   struct:exn, struct:exn:fail, etc.
         ,@exception-struct-type-global-forms

         ;; Return value (for a module)
         (global ,result (mut (ref eq)) (global.get $void))

         ;; Variables defined at the top-level
         ,@top-level-variable-declarations

         ,@symbol-table-global-forms

         ,@keyword-table-global-forms

         ,@struct-prefab-registry-global-forms

         ,@linklet-primitive-table-global-forms

         ,@unsafe-ffi-primitive-table-global-forms

         ;;   Symbol table initializer is implemented in runtime-wasm/core/symbols.rkt.
         ,@(symbol-table-initializer-runtime-helper-forms runtime-helper-index)

         ;;   Keyword table initializer is implemented in runtime-wasm/core/keywords.rkt.
         ,@(keyword-table-initializer-runtime-helper-forms runtime-helper-index)

         ;;   Primitive table initializer is implemented in runtime-wasm/core/linklets.rkt.
         ,@(for/list ([name (in-list linklet-primitive-table-initializer-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;;;
         ;;; Arrays
         ;;;

         ;; Arrays are "vectors" of (ref eq) values.
         ;; They are used internally to implement various Racket data structures.

         ;; Define a mutable array type of (ref eq)
         ; (type $Array (array (mut (ref eq))))

         ,@(array-core-runtime-helper-forms core-runtime-helper-index)

         ;;   Generic array conversion helpers are implemented in runtime-wasm/core/arrays.rkt.
         ,@(array-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; Growable Arrays
         ;;;

         ,@(growable-array-core-runtime-helper-forms core-runtime-helper-index)

         ;;;
         ;;; Growable Arrays of Bytes
         ;;;

         ,@(growable-bytes-core-runtime-helper-forms core-runtime-helper-index)

         ;;;
         ;;; Growable Arrays of I32
         ;;;

         #;(type $I32Array (array (mut i32)))

         #;(type $I32GrowableArray
               (struct
                 (field $arr (mut (ref $I32Array))) ;; underlying array
                 (field $cap (mut i32))             ;; capacity
                 (field $i   (mut i32))))           ;; current size

         ,@(growable-i32-array-core-runtime-helper-forms core-runtime-helper-index)


         ;;;
         ;;; I32Array - Arrays of i32
         ;;;

         ; (type $I32Array (array (mut i32)))

         ,@(i32-array-core-runtime-helper-forms core-runtime-helper-index)

         ;;   I32 array conversion helpers are implemented in runtime-wasm/core/i32-arrays.rkt.
         ,@(i32-array-runtime-helper-forms runtime-helper-index)


         ;;;
         ;;; I8Array
         ;;;

         ; (type $I8Array (array (mut i8)))

         ;;   I8 array error helpers are implemented in runtime-wasm/core/i8-arrays.rkt.
         ,@(i8-array-error-runtime-helper-forms runtime-helper-index)

         ,@(i8-array-core-runtime-helper-forms core-runtime-helper-index)

         ;;   I8 array conversion helpers are implemented in runtime-wasm/core/i8-arrays.rkt.
         ,@(i8-array-conversion-runtime-helper-forms runtime-helper-index)

         ;;   Byte wrapper core helpers are implemented in runtime-wasm/core/bytes.rkt.
         ,@(bytes-core-runtime-helper-forms core-runtime-helper-index)

         ;;;
         ;;; Exceptions
         ;;;

         (tag $exn (param (ref eq)))  ; an exception that that carries an value

         ;;   Exception helpers are implemented in runtime-wasm/core/exceptions.rkt.
         ,@(exception-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; RUNTIME SUPPORT FOR MATCH AND CHECKERS
         ;;;

         ;;   Implemented in runtime-wasm/core/checkers.rkt.
         ,@(checker-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; DATATYPES
         ;;;

         ;; https://docs.racket-lang.org/reference/data.html

         ;;;
         ;;;  4.1 Equality
         ;;;

         ;;   Implemented in runtime-wasm/core/equality.rkt.
         ,@(equality-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; 4.2 Booleans
         ;;;

         ;; https://docs.racket-lang.org/reference/booleans.html

         ;;   String mutability predicates are implemented in runtime-wasm/core/strings.rkt.
         ,@(string-mutability-runtime-helper-forms runtime-helper-index)

         ;;   Bytes mutability predicates are implemented in runtime-wasm/core/bytes.rkt.
         ,@(bytes-mutability-runtime-helper-forms runtime-helper-index)

         ;;   Vector mutability predicates are implemented in runtime-wasm/core/vectors.rkt.
         ,@(vector-mutability-runtime-helper-forms runtime-helper-index)

         ;;   Box mutability predicates are implemented in runtime-wasm/core/boxes.rkt.
         ,@(box-mutability-runtime-helper-forms runtime-helper-index)

         ;;   Hash predicates are implemented in runtime-wasm/core/hashes.rkt.
         ,@(hash-predicate-runtime-helper-forms runtime-helper-index)

         ;;   Boolean helpers are implemented in runtime-wasm/core/booleans.rkt.
         ,@(boolean-runtime-helper-forms runtime-helper-index)

         ;;   Generic immutability predicates are implemented in runtime-wasm/core/equality.rkt.
         ,@(immutable-predicate-runtime-helper-forms runtime-helper-index)

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
         ,@(number-type-runtime-helper-forms runtime-helper-index)

         ;; 4.3.2 Generic Numerics
         ;;     https://docs.racket-lang.org/reference/generic-numbers.html

         ;; 4.3.2.1 Arithmetic
         ;;   https://docs.racket-lang.org/reference/generic-numbers.html#%28part._.Arithmetic%29

         ;;   Generic numeric helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(generic-numeric-runtime-helper-forms runtime-helper-index)

         ;;   Numeric error helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(number-error-runtime-helper-forms runtime-helper-index)

         ;;   Arithmetic and comparison helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(generic-arithmetic-runtime-helper-forms runtime-helper-index)

         ;;   Bitwise numeric helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(generic-bitwise-runtime-helper-forms runtime-helper-index)

        ,@random-state-global-forms

        ;;   Random generator helpers are implemented in runtime-wasm/core/random.rkt.
        ,@(random-generator-runtime-helper-forms runtime-helper-index)

        ;;   Implemented in runtime-wasm/core/parameters.rkt.
        ,(core-runtime-helper-form runtime-helper-index '$current-pseudo-random-generator)

        ;;   Public random helpers are implemented in runtime-wasm/core/random.rkt.
        ,@(random-public-runtime-helper-forms runtime-helper-index)

         ;; System/runtime information helpers are implemented in runtime-wasm/core/system.rkt.
         ,@(system-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(compile-parameter-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;;  4.3.4 Fixnums
         ;;;

         ;; https://docs.racket-lang.org/reference/fixnums.html

         ;; Fixnum helpers are implemented in runtime-wasm/core/fixnums.rkt.
         ,@(fixnum-runtime-helper-forms runtime-helper-index core-runtime-helper-index)

         ;;;
         ;;; 4.3.3 Floating Point Numbers
         ;;;

         ;; https://docs.racket-lang.org/reference/flonums.html

         ;; Flonum helpers are implemented in runtime-wasm/core/flonums.rkt.
         ,@(flonum-runtime-helper-forms runtime-helper-index core-runtime-helper-index)



         ;;;
         ;;; Number / String conversions
         ;;;

         ;; Number/string conversion helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(number-string-conversion-runtime-helper-forms runtime-helper-index)

         ;; String/number conversion helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(string-number-conversion-runtime-helper-forms runtime-helper-index)

         ;; Floating-point byte conversion helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(floating-point-byte-conversion-runtime-helper-forms runtime-helper-index)


         ;; Numeric formatting helpers are implemented in runtime-wasm/core/numbers.rkt.
         ,@(numeric-formatting-runtime-helper-forms runtime-helper-index)

         ;; Numeric display helpers are implemented in runtime-wasm/core/formatting.rkt.
         ,@(numeric-display-formatting-runtime-helper-forms runtime-helper-index)



        ;;;
        ;;; - External host values
        ;;;

         ;;   Implemented in runtime-wasm/core/ffi.rkt.
         ,@(external-value-runtime-helper-forms runtime-helper-index)





        ;;;
        ;;; 4.3 Byte Strings
        ;;;

        ;; https://docs.racket-lang.org/reference/bytestrings.html

         ;;   Byte-string helpers are implemented in runtime-wasm/core/bytes.rkt.
         ,@(bytes-main-runtime-helper-forms runtime-helper-index)


        ;;;
        ;;; 4.4 Strings
        ;;;

        ;; https://docs.racket-lang.org/reference/strings.html

         ;;   String helpers are implemented in runtime-wasm/core/strings.rkt.
         ,@(string-main-runtime-helper-forms runtime-helper-index core-runtime-helper-index)


         ;;;
         ;;; 4.6 Characters
         ;;;

         ;;   Character helpers are implemented in runtime-wasm/core/characters.rkt.
         ,@(character-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; 4.7 SYMBOLS
         ;;;

         ;;   Symbol helpers are implemented in runtime-wasm/core/symbols.rkt.
         ,@(symbol-public-runtime-helper-forms runtime-helper-index)

         ,@symbol-gensym-global-forms

         ;;   Gensym helpers are implemented in runtime-wasm/core/symbols.rkt.
         ,@(symbol-gensym-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; 4.8 REGULAR EXPRESSIONS
         ;;;

         ;;   Regular expression helpers are implemented in runtime-wasm/core/regexps.rkt.
         ,@(regexp-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; 4.9 KEYWORDS
         ;;;

         ;;   Keyword helpers are implemented in runtime-wasm/core/keywords.rkt.
         ,@(keyword-core-runtime-helper-forms core-runtime-helper-index)
         ,@(keyword-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; 4.10 Pairs and lists
         ;;;

         ;; https://docs.racket-lang.org/reference/pairs.html

         ,@pair-global-forms

         ;; Pair/list helpers
         ;;   Implemented in runtime-wasm/core/lists.rkt.
         ,@(list-pre-contract-runtime-helper-forms runtime-helper-index
                                                   core-runtime-helper-index)

         ;; Generic contract-error helpers
         ;;   Implemented in runtime-wasm/core/exceptions.rkt.
         ,@(exception-contract-runtime-helper-forms runtime-helper-index)

         ,@(list-post-contract-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; 4.11 Mutable Pairs and lists
         ;;;

         ;; https://docs.racket-lang.org/reference/mpairs.html

         ;; Mutable pairs are similar to pairs but allow their fields
         ;; to be updated. These operations parallel their immutable
         ;; counterparts above but use the `$MPair` type.

         ;; Mutable-pair helpers are implemented in runtime-wasm/core/mlists.rkt.
         ,@(mlist-core-runtime-helper-forms core-runtime-helper-index)

         ;;;
         ;;; 4.12 Vectors
         ;;;

         ;; https://docs.racket-lang.org/reference/vectors.html

         ;; (type $Vector (sub $Heap
         ;;                      (struct
         ;;                        (field $hash (mut i32))
         ;;                        (field (ref $Array))))))

         ,@treelist-constant-global-forms
         ,@vector-dummy-array-global-forms
         ,@treelist-empty-global-forms
         ,@vector-dummy-global-forms

         ;; Vector related exceptions
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(vector-error-runtime-helper-forms runtime-helper-index)

         ;; Treelist helpers are implemented in runtime-wasm/core/treelists.rkt.
         ,@(treelist-runtime-helper-forms runtime-helper-index)

         ;; Vector helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(vector-main-runtime-helper-forms runtime-helper-index core-runtime-helper-index)

         ;;;
         ;;; Stencil Vectors
         ;;;

         ;; Stencil-vector helpers are implemented in runtime-wasm/core/stencil-vectors.rkt.
         ,@(stencil-vector-runtime-helper-forms runtime-helper-index)

         ;; Vector copy, conversion, slicing, search, and sorting helpers
         ;;   Implemented in runtime-wasm/core/vectors.rkt.
         ,@(vector-post-stencil-runtime-helper-forms runtime-helper-index)

         ;; Box helpers are implemented in runtime-wasm/core/boxes.rkt.
         ,@(box-runtime-helper-forms runtime-helper-index)

         ;; Thread helpers are implemented in runtime-wasm/core/threads.rkt.
         ,@(thread-runtime-helper-forms runtime-helper-index)

         ;; Logger helpers are implemented in runtime-wasm/core/loggers.rkt.
         ,@(logger-runtime-helper-forms runtime-helper-index)

         ;; Event and channel helpers are implemented in runtime-wasm/core/events.rkt.
         ,@(event-channel-runtime-helper-forms runtime-helper-index)

         ;; Semaphore helpers are implemented in runtime-wasm/core/semaphores.rkt.
         ,@(semaphore-runtime-helper-forms runtime-helper-index)

         ;; Will-executor helpers are implemented in runtime-wasm/core/wills.rkt.
         ,@(will-runtime-helper-forms runtime-helper-index)

         ;; Event synchronization helpers are implemented in runtime-wasm/core/events.rkt.
         ,@(event-sync-runtime-helper-forms runtime-helper-index)

         ;; Uninterruptible-lock helpers are implemented in runtime-wasm/core/locks.rkt.
         ,@(lock-runtime-helper-forms runtime-helper-index)

         ,@memory-map-global-forms


         ;;;
         ;;; Data segment strings
         ;;;

         ;; The current (June 2005) support for strings in WebAssembly is *very* limited.
         ;; The data segment can be used to embed byte sequences in the source.
         ;; However in order to access the data, one must copy them to the linear memory first.

         ;;   String-buffer error helpers are implemented in runtime-wasm/core/strings.rkt.
         ,@(string-buffer-runtime-helper-forms runtime-helper-index)

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
         ,@(hash-table-predicate-runtime-helper-forms runtime-helper-index)


         ;;;
         ;;; MUTABLE HASHEQ
         ;;;

         ,@(mutable-hash-constructor-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; IMMUTABLE HASHEQV
         ;;;

         ,@(immutable-hash-prelude-runtime-helper-forms runtime-helper-index)

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
         ,@(struct-prefab-registry-runtime-helper-forms runtime-helper-index)

         ;; Mutable hash lookup helpers
         ;;   Implemented in runtime-wasm/core/mutable-hashes.rkt.
         ,@(mutable-hash-read-runtime-helper-forms runtime-helper-index)

         ;; Public immutable hash functional update wrappers
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,@(immutable-hash-public-set/remove-runtime-helper-forms runtime-helper-index)

         ;; Mutable hash write and ref! helpers
         ;;   Implemented in runtime-wasm/core/mutable-hashes.rkt.
         ,@(mutable-hash-write-runtime-helper-forms runtime-helper-index)

         ;; hash-update : immutable-hash? any/c (any/c -> any/c) [any/c or (-> any/c)] -> immutable-hash?
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,@(immutable-hash-public-update-runtime-helper-forms runtime-helper-index)

         ;; Mutable hash update! helpers
         ;;   Implemented in runtime-wasm/core/mutable-hashes.rkt.
         ,@(mutable-hash-update-runtime-helper-forms runtime-helper-index)

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


         ;; Mutable hash remove, resize, membership, and clear! helpers
         ;;   Implemented in runtime-wasm/core/mutable-hashes.rkt.
         ,@(mutable-hash-remove-membership-clear-runtime-helper-forms runtime-helper-index)

         ;; hash-clear : immutable-hash? -> immutable-hash?
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,@(immutable-hash-public-clear-runtime-helper-forms runtime-helper-index)

         ;; Mutable hash emptiness and iteration helpers
         ;;   Implemented in runtime-wasm/core/mutable-hashes.rkt.
         ,@(mutable-hash-empty-iteration-runtime-helper-forms runtime-helper-index)

         ;; unsafe-immutable-hash-iterate-* : immutable hash iteration
         ;;   Implemented in runtime-wasm/core/immutable-hashes.rkt.
         ,@(immutable-hash-iteration-runtime-helper-forms runtime-helper-index)

         ;; Generic hash table operations
         ;;   Implemented in runtime-wasm/core/hashes.rkt.
         ,@(hash-table-operation-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;; HASH CODES
         ;;;

         ,@hash-seed-global-forms

         ;; Hash code helpers
         ;;   Implemented in runtime-wasm/core/hashes.rkt.
         ,@(hash-code-runtime-helper-forms runtime-helper-index)

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
         ,@(symbol-table-runtime-helper-forms runtime-helper-index)

         ;; String hash helper is implemented in runtime-wasm/core/strings.rkt.
         ,@(string-hash-core-runtime-helper-forms core-runtime-helper-index)

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
         ,@(location-initial-runtime-helper-forms runtime-helper-index)

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

        ;; Port predicate helpers are implemented in runtime-wasm/core/ports.rkt.
        ,@(port-predicate-runtime-helper-forms runtime-helper-index)

        ;;   Implemented in runtime-wasm/core/impersonators.rkt.
        ,@(for/list ([name (in-list impersonator-basic-runtime-only-helper-names)])
            (core-runtime-helper-form runtime-helper-index name))

        ;; Output-port predicate helper is implemented in runtime-wasm/core/ports.rkt.
        ,@(port-output-predicate-runtime-helper-forms runtime-helper-index)

        ;; Port state helpers are implemented in runtime-wasm/core/ports.rkt.
        ,@(port-state-runtime-helper-forms runtime-helper-index)

        ;; Port location helpers are implemented in runtime-wasm/core/ports.rkt.
        ,@(port-location-runtime-helper-forms runtime-helper-index)

         ;; String/byte string port constructors are implemented in runtime-wasm/core/ports.rkt.
         ,@(port-string-constructor-runtime-helper-forms runtime-helper-index)

         ;; Output string extraction helpers are implemented in runtime-wasm/core/ports.rkt.
         ,@(port-output-string-runtime-helper-forms runtime-helper-index)

         ;; Custom port constructors are implemented in runtime-wasm/core/ports.rkt.
         ,@(port-custom-constructor-runtime-helper-forms runtime-helper-index)

         ;;   EOF object helpers are implemented in runtime-wasm/core/immediates.rkt.
         ,@(eof-object-runtime-helper-forms runtime-helper-index)

         ;; call-with-output-string is implemented in runtime-wasm/core/ports.rkt.
         ,@(port-call-with-output-string-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;;  13.2  Byte and String Input
         ;;;

         ;; Byte/string input helpers are implemented in runtime-wasm/core/ports.rkt.
         ,@(port-input-runtime-helper-forms runtime-helper-index)

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

         ;; Byte/string output helpers are implemented in runtime-wasm/core/ports.rkt.
         ,@(port-output-runtime-helper-forms runtime-helper-index)


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

         ,@(struct-core-predicate-runtime-helper-forms core-runtime-helper-index)

         ;; Basic struct predicates and checkers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(struct-basic-runtime-helper-forms runtime-helper-index)

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
         ,@(struct-prefab-runtime-helper-forms runtime-helper-index)

         ;; Struct type construction helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(struct-construction-runtime-helper-forms runtime-helper-index)

        ,@(runtime-function-declaration-forms primitive-shapes
                                             (active-described-primitives-sorted)
                                             (active-ffi-primitive-names))


        ;; Struct constructor implementation helpers
        ;;   Implemented in runtime-wasm/core/structs.rkt.
        ,@(struct-constructor-access-runtime-helper-forms runtime-helper-index)

         ;; -------------------------------------------------------------------
         ;; Structure Type Properties
         ;; -------------------------------------------------------------------

         ;; Struct type property lookup helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(struct-type-property-runtime-helper-forms runtime-helper-index)


         ;;;
         ;;; PROCEDURES
         ;;;

         ;; Struct procedure helpers
         ;;   Implemented in runtime-wasm/core/structs.rkt.
         ,@(struct-procedure-runtime-helper-forms runtime-helper-index)

         ;; Procedure helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(procedure-main-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/impersonators.rkt.
         ,@(for/list ([name (in-list chaperone-procedure-runtime-only-helper-names)])
             (core-runtime-helper-form runtime-helper-index name))

         ;; Procedure arity mask helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(procedure-arity-mask-runtime-helper-forms runtime-helper-index)


         ;;;
         ;;; PRIMITIVES
         ;;;

         ; https://docs.racket-lang.org/reference/procedures.html

         ; 4.20.2 Reflecting on Primitives

         ;; Primitive reflection helpers
         ;;   Implemented in runtime-wasm/core/procedures.rkt.
         ,@(primitive-reflection-runtime-helper-forms runtime-helper-index)

         ;;;
         ;;;  4.21 Void
         ;;;

         ;; https://docs.racket-lang.org/reference/void.html

         ;;   Implemented in runtime-wasm/core/immediates.rkt.
         ,@(void-runtime-helper-forms runtime-helper-index)


         ;;;
         ;;; 10. CONTROL FLOW
         ;;;

         ;; 10.1 Multiple Values

         ;;   Implemented in runtime-wasm/core/control-flow.rkt.
         ,@(multiple-value-runtime-helper-forms runtime-helper-index)



         ;; 10.2 Exceptions

         ;; 10.3 Delayed Evaluation
         ;; 10.4 Continuations

         ;;   Implemented in runtime-wasm/core/control-flow.rkt.
         ,@(continuation-runtime-helper-forms runtime-helper-index)

         ;; 10.5 Continuation Marks

         ;;   Implemented in runtime-wasm/core/control-flow.rkt.
         ,@(continuation-mark-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(parameterization-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(namespace-parameter-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(parameterization-binding-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,@(parameterization-call-runtime-helper-forms runtime-helper-index)

         ;; 10.6 Breaks
         ;; 10.7 Exiting
         ;; 10.8 Unreachable Expressions


         ;;;
         ;;; 13. INPUT AND OUTPUT
         ;;;

         ;; 13.8 Printer Extension

         ;;   Implemented in runtime-wasm/core/formatting.rkt.
         ,@(printer-extension-runtime-helper-forms runtime-helper-index)


         ;; 13.10 Fast-Load Serialization

         ;;   FASL tag globals are implemented in runtime-wasm/core/fasl.rkt.
         ,@(fasl-tag-runtime-helper-forms runtime-helper-index)

         ;;   FASL encoding helpers are implemented in runtime-wasm/core/fasl.rkt.
         ,@(fasl-encoding-runtime-helper-forms runtime-helper-index)

         ;;; Fasl decoding (from byte string)

         ;;   FASL decoding helpers are implemented in runtime-wasm/core/fasl.rkt.
         ,@(fasl-decoding-runtime-helper-forms runtime-helper-index)

        ;;;
        ;;; 14. REFLECTION AND SECURITY
        ;;;

        ;; 14.1 Namespaces

        ;;   Reflection helpers are implemented in runtime-wasm/core/reflection.rkt.
        ,@(reflection-runtime-helper-forms runtime-helper-index)
         ;; 14.2 Evaluation and compilation
         ;; 14.3 The racket/load language
         ;; 14.4 Module names and loading
         ;; 14.5 Impersonators and chaperones
         ;; 14.6 Security Guards
         ;; 14.7 Custodians

         ;;   Security guard helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(security-pre-parameter-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$current-security-guard)

         ;;   Security guard and custodian predicate helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(security-post-parameter-runtime-helper-forms runtime-helper-index)

         ;;   Implemented in runtime-wasm/core/parameters.rkt.
         ,(core-runtime-helper-form runtime-helper-index '$current-custodian)

         ;;   Custodian helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(custodian-runtime-helper-forms runtime-helper-index)

         ;; 14.8 Thread Groups
         ;; 14.9 Structure Inspectors

         ;;   Implemented in runtime-wasm/core/time.rkt.
         ,@(time-runtime-helper-forms runtime-helper-index)

         ;;   Inspector and object-name helpers are implemented in runtime-wasm/core/security.rkt.
         ,@(inspector-runtime-helper-forms runtime-helper-index)

         ;; 14.10 Code Inspectors
         ;; 14.11 Plumbers
         ;; 14.12 Sandboxed Evaluation
         ;; 14.13 The racket/repl library

         ;;;
         ;;; 14.14 Linklets and the compiler
         ;;;


         ;;   Linklet instance helpers are implemented in runtime-wasm/core/linklet-instances.rkt.
         ,@(linklet-instance-runtime-helper-forms runtime-helper-index)

         ;;   Linklet helpers are implemented in runtime-wasm/core/linklets.rkt.
         ,@(linklet-runtime-only-helper-forms linklet-body-reserved-symbols)

         ;;   Correlated syntax helpers are implemented in runtime-wasm/core/syntax.rkt.
         ,@(correlated-syntax-runtime-helper-forms runtime-helper-index)

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
         ,@(formatting-runtime-helper-forms runtime-helper-index)

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
               ,@(namespace-runtime-helper-forms runtime-helper-index)

               ;;;
               ;;; 14.2 Source Locations
               ;;;

               ;;   Implemented in runtime-wasm/core/locations.rkt.
               ,@(source-location-runtime-helper-forms runtime-helper-index)

               ;;;
               ;;; 12. Macros
               ;;;

               ;;; 12.2 Syntax Object COntent

               ;;   Implemented in runtime-wasm/core/syntax.rkt.
               ,@(syntax-runtime-helper-forms runtime-helper-index)

               ;;;
               ;;; 15. OPERATING SYSTEM
               ;;;

               ;;; 15.1 Paths

               ;;   Basic path helpers are implemented in runtime-wasm/core/paths.rkt.
               ,@(path-runtime-helper-forms runtime-helper-index)

               ;;   Environment variable helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$environment-variables?)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-environment-variables)

               ;;   Environment variable helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$environment-variables-ref)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-print)

               ;;   Bootstrap reader and printer helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,@(io-handler-reader-printer-runtime-helper-forms runtime-helper-index)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-readtable)

               ;;   Port handler helpers are implemented in runtime-wasm/core/io-handlers.rkt.
               ,@(io-handler-port-runtime-helper-forms runtime-helper-index)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-read-interaction)

               ;; load-on-demand-enabled/use-user-specific-search-paths/read-accept-* : [boolean?] -> boolean? or void?
               ;;   Bootstrap reader policy parameters. The Reference gives
               ;;   load-on-demand-enabled a default of #t; WebRacket exposes
               ;;   the parameter now, while delayed source loading is deferred
               ;;   until the reader/load layer is richer.
               ,@(reader-printer-policy-parameter-helper-forms runtime-helper-index)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,@(parameter-width-runtime-helper-forms runtime-helper-index)

               ;;   Error rendering defaults are implemented in runtime-wasm/core/io-handlers.rkt.
               ,@(io-handler-error-runtime-helper-forms runtime-helper-index)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,@(parameter-error-rendering-runtime-helper-forms runtime-helper-index)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,@(parameter-directory-runtime-helper-forms runtime-helper-index)

               ;;   Implemented in runtime-wasm/core/parameters.rkt.
               ,(core-runtime-helper-form runtime-helper-index '$current-load-relative-directory)

               ;;   Path manipulation helpers are implemented in runtime-wasm/core/paths.rkt.
               ,@(path-manipulation-runtime-helper-forms runtime-helper-index)

               ;;   VFS and file-operation helpers are implemented in runtime-wasm/core/filesystem.rkt.
               ,@(filesystem-runtime-helper-forms runtime-helper-index)

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

               ,@path-current-global-forms
               ,@environment-parameter-global-forms
               ,@filesystem-temporary-global-forms
               ,@port-current-global-forms
               ,@print-read-parameter-global-forms
               ,@logger-current-global-forms
               ,@security-current-global-forms
               ,@io-handler-default-port-global-forms
               ,@reader-printer-policy-parameter-global-forms
               ,@compile-parameter-global-forms
               ,@parameterization-global-forms
               ,@namespace-current-global-forms
               ,@random-current-global-forms
               ,@thread-group-current-global-forms
               ,@error-rendering-handler-global-forms
               ,@thread-current-global-forms
               ,@event-global-forms

               ,@entry-struct-property-global-forms
               ,@ffi-entry-global-forms

               ,@entry-support-forms

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
                     ,@flonum-initializer-forms

                     ;; Initialize global state
                     (call $initialize-the-symbol-table)  ; for interning
                     (call $initialize-the-keyword-table) ; for interning
                     (call $initialize-primitive-table-user-installed)
                     (call $initialize-prefab-struct-type-registry)

                     ;; Initialize constants used by the program and runtime.
                     ,@(runtime-constant-initializer-forms runtime-constant-registry)
                     ,@parameterization-initializer-forms
                     ,@random-current-initializer-forms
                     ,@thread-current-initializer-forms
                     ,@logger-current-initializer-forms
                     ,@custodian-current-initializer-forms
                     ,@event-initializer-forms

                     ,@entry-struct-property-initializer-forms


                     ,@path-current-initializer-forms
                     ,@environment-parameter-initializer-forms
                     (drop (call $reset-current-input-port!))
                     (drop (call $reset-current-output-port!))
                     (drop (call $reset-current-error-port!))

                     ,@character-general-category-initializer-forms

                     ,@realm-initializer-forms

                    ;; Initialize variables holding primitives
                    ,@(initialize-primitives-as-globals)
                    ,@(initialize-ffi-primitives-as-globals)
                    (call $initialize-unsafe-ffi-primitive-table)
                    ,@security-guard-current-initializer-forms
                    ,@error-value-handler-late-initializer-forms
                    ,@print-read-parameter-late-initializer-forms
                    ,@io-handler-default-port-late-initializer-forms
                    ,@error-syntax-handler-late-initializer-forms

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
                     ,@exception-struct-type-initializer-forms

                     ;; Initialize the top-level namespace
                     ,@namespace-initializer-forms


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
    (runtime-metric-add/computed! "runtime:module-bytes-before-prune"
                                  (lambda ()
                                    (module-byte-size full-module)))
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
    (runtime-metric-add/computed! "tree-shake:module-bytes-after-prune"
                                  (lambda ()
                                    (module-byte-size final-module)))
    final-module
    )))
