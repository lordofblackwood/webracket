#lang racket

(provide struct-runtime-string-constants
         struct-runtime-symbol-constants
         struct-procedure-invoker-runtime-helper-forms
         struct-core-predicate-runtime-helper-forms
         struct-prefab-registry-runtime-helper-forms
         struct-basic-runtime-helper-forms
         struct-prefab-runtime-helper-forms
         struct-construction-runtime-helper-forms
         struct-constructor-access-runtime-helper-forms
         struct-type-property-runtime-helper-forms
         struct-procedure-runtime-helper-forms
         struct-equal+hash-recur-global-forms
         struct-equal+hash-recur-global-names
         struct-property-global-forms
         struct-property-identity-global-forms
         struct-property-identity-global-names
         struct-property-initializer-forms
         struct-property-identity-initializer-forms
         struct-prefab-registry-global-forms
         struct-core-runtime-helpers
         struct-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/immediates.rkt")

;; struct-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by struct helpers and struct errors.
(define struct-runtime-string-constants
  '((struct-type-descriptor     "#<struct-type-descriptor>")
    (struct-open                "#(struct ")
    (struct?                    "struct?")
    (struct-type?               "struct-type?")
    (struct-type-or-false       "(or/c #f struct-type?)")
    (inspector-or-false         "(or/c inspector? #f)")
    (struct-type-property-or-false
     "(or/c struct-type-property? #f)")
    (make-struct-type-guard     "(or/c #f procedure?)")
    (make-struct-type-inspector "(or/c inspector? #f 'current 'prefab)")
    (make-struct-type-props
     "(listof (cons/c struct-type-property? any/c))")
    (make-struct-type-immutables
     "(listof exact-nonnegative-integer?)")
    (make-struct-type-constructor-name "(or/c #f symbol?)")
    (make-struct-type-proc-spec
     "(or/c procedure? exact-nonnegative-integer? #f)")
    (make-struct-type-immutable-index
     ": index for immutable field >= initialized-field count\n  index: ")
    (make-struct-type-proc-spec-index
     ": index for procedure >= initialized-field count\n  index: ")
    (make-struct-type-initialized-field-count
     "\n  initialized-field count: ")
    (make-struct-type-field-count "\n  field count: ")
    (make-struct-type-in-list "\n  in list: ")
    (make-struct-type:non-generative-supertype
     ": generative supertype disallowed for non-generative structure type\n  structure type name: ")
    (make-struct-type:non-generative-properties
     ": properties disallowed for non-generative structure type\n  structure type name: ")
    (make-struct-type:non-generative-proc-spec
     ": procedure specification disallowed for non-generative structure type\n  structure type name: ")
    (make-struct-type:non-generative-guard
     ": guard disallowed for non-generative structure type\n  structure type name: ")
    (make-struct-type:unsupported-prefab-auto-value
     ": unsupported simple prefab auto value for non-generative structure type\n  structure type name: ")
    (make-struct-type-property-guard
     "(or/c (procedure-arity-includes/c 2) #f 'can-impersonate)")
    (make-struct-type-property-supers
     "(listof (cons/c struct-type-property? (procedure-arity-includes/c 1)))")
    (make-struct-type-property-accessor-name
     "(or/c symbol? #f)")
    (make-struct-type-property-contract-str
     "(or/c symbol? string? #f)")
    (make-struct-field-accessor-procedure
     "(and/c struct-accessor-procedure? (procedure-arity-includes/c 2))")
    (make-struct-field-mutator-procedure
     "(and/c struct-mutator-procedure? (procedure-arity-includes/c 3))")
    (guard-for-prop:custom-write-contract
     "(procedure-arity-includes?/c 3)")
    (guard-for-prop:object-name-contract
     "(or/c exact-nonnegative-integer? (procedure-arity-includes/c 1))")
    (guard-for-prop:object-name-field-index
     ": field index >= initialized-field count for structure type\n  field index: ")
    (guard-for-prop:equal+hash-contract
     "(or/c (list/c (procedure-arity-includes/c 4) (procedure-arity-includes/c 3)) (list/c (procedure-arity-includes/c 3) (procedure-arity-includes/c 2) (procedure-arity-includes/c 2)))")
    (prop:checked-procedure-too-few-fields
     "prop:checked-procedure: need at least two fields in the structure type")
    (prop:checked-procedure-supertype
     "prop:checked-procedure: not allowed on a structure type with a supertype")
    (prop:procedure-contract
     "(or/c procedure? exact-nonnegative-integer?)")
    (make-struct-field-name
     "(or/c symbol? #f)")
    (make-struct-field-contract-str
     "(or/c symbol? string? #f)")
    (make-prefab-struct-supported-key "supported simple prefab key")
    (field                     "field")
    (predicate-suffix          "?")
    (struct-accessor-suffix    "-ref")
    (struct-mutator-suffix     "-set!")
    (struct-accessor:index-too-large
     ": index too large\n  index: ")
    (struct-accessor:index-too-large-no-fields
     ": index too large; no fields accessible\n  index: ")
    (struct-accessor:maximum-allowed-index
     "\n  maximum allowed index: ")
    (struct-accessor:structure-type
     "\n  structure type: ")
    (struct-type-prefix        "#<struct-type:")
    (struct-type-close         ">")
    (struct-mutator:immutable-field
     ": cannot modify value of immutable field in structure\n  structure: ")
    (struct-mutator:field-index
     "\n  field index: ")
    (procedure-struct-type?     "procedure-struct-type?")
    (sealed-struct-supertype    "sealed structure type cannot be used as a supertype")
    (struct->list:on-opaque     "one of 'error, 'return-false, or 'skip")
    (struct:prefix              "struct:")
    (accessor-suffix            "-accessor")))

;; struct-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by struct helpers and struct errors.
(define struct-runtime-symbol-constants
  '(can-impersonate
    prop:sealed
    sealed
    prop:evt
    evt
    prefab
    current
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
    struct->list
    struct->vector
    make-struct-type
    make-struct-type-property
    make-struct-field-accessor
    make-struct-field-mutator
    guard-for-prop:custom-write
    guard-for-prop:object-name
    guard-for-prop:equal+hash
    make-prefab-struct
    prefab-struct-type-key+field-count
    accessor
    mutator
    error
    return-false
    skip
    ...
    procedure-struct-type?))

;; struct-equal+hash-recur-global-names : (listof symbol?)
;;   Name equal+hash closure globals that remain runtime-only for now.
(define struct-equal+hash-recur-global-names
  '($equal+hash-recur/equal
    $equal+hash-recur/equal-always
    $equal+hash-recur/hash
    $equal+hash-recur/hash-always))

;; struct-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a struct global form.
(define (struct-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'struct-global-form-name
              "expected global form, got: ~s"
              form)]))

;; struct-global-set-target : datum? -> symbol?
;;   Return the Wasm global name assigned by a struct initializer form.
(define (struct-global-set-target form)
  (match form
    [`(global.set ,name . ,_) name]
    [_ (error 'struct-global-set-target
              "expected global.set form, got: ~s"
              form)]))

;; equal+hash-recur-global-name? : symbol? -> boolean?
;;   Check whether name belongs to an equal+hash recursion closure global.
(define (equal+hash-recur-global-name? name)
  (memq name struct-equal+hash-recur-global-names))

;; struct-property-global-forms : (listof datum?)
;;   Declare runtime struct-type property and equal+hash recursion closure globals.
(define struct-property-global-forms
  '(
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
               (global $equal+hash-recur/hash-always  (mut (ref eq)) (global.get $void))))

;; struct-equal+hash-recur-global-forms : (listof datum?)
;;   Declare equal+hash recursion closure globals shared by split runtime modules.
(define struct-equal+hash-recur-global-forms
  (for/list ([form (in-list struct-property-global-forms)]
             #:when (equal+hash-recur-global-name? (struct-global-form-name form)))
    form))

;; struct-property-identity-global-forms : (listof datum?)
;;   Declare runtime struct-type property identity globals, excluding recur closures.
(define struct-property-identity-global-forms
  (for/list ([form (in-list struct-property-global-forms)]
             #:unless (equal+hash-recur-global-name? (struct-global-form-name form)))
    form))

;; struct-property-identity-global-names : (listof symbol?)
;;   Enumerate struct-type property identity globals shared by split runtime modules.
(define struct-property-identity-global-names
  (map struct-global-form-name struct-property-identity-global-forms))

;; struct-property-initializer-forms : (listof datum?)
;;   Initialize runtime struct-type properties and equal+hash recursion closures.
(define struct-property-initializer-forms
  '(
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
                                             (array.new_fixed $Free 0)))))

;; struct-property-identity-initializer-forms : (listof datum?)
;;   Initialize runtime struct-type property identities, excluding recur closures.
(define struct-property-identity-initializer-forms
  (for/list ([form (in-list struct-property-initializer-forms)]
             #:unless (equal+hash-recur-global-name? (struct-global-set-target form)))
    form))

;; struct-prefab-registry-global-forms : (listof datum?)
;;   Declare the prefab struct type registry.
(define struct-prefab-registry-global-forms
  '(
         ;; Simple prefab struct types are interned by prefab key.
         (global $prefab-struct-type-registry (mut (ref null $HashEqMutable)) (ref.null $HashEqMutable))))

;; struct-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate manually defined struct helpers that originated in core runtime.
(define struct-base-core-runtime-helpers
  (list
   ;; struct?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a struct, 0 otherwise.
   (core-runtime-helper
    '$struct?/i32
    "$struct?/i32"
    (lambda ()
      `(func $struct?/i32 (param $v (ref eq)) (result i32)
             (ref.test (ref $Struct) (local.get $v)))))
   ;; struct-type?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a struct type descriptor, 0 otherwise.
   (core-runtime-helper
    '$struct-type?/i32
    "$struct-type?/i32"
    (lambda ()
      `(func $struct-type?/i32 (param $v (ref eq)) (result i32)
             (ref.test (ref $StructType) (local.get $v)))))))

;; struct-core-predicate-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct core predicate helpers.
(define struct-core-predicate-runtime-helper-names
  '($struct?/i32
    $struct-type?/i32))

;; struct-promoted-runtime-helper-names : (listof symbol?)
;;   Name runtime struct helpers that are available in the standalone core runtime.
(define struct-promoted-runtime-helper-names
  '($struct?
    $struct-type?
    $struct-type-is-a?/i32
    $simple-prefab-auto-value-supported?/i32
    $simple-prefab-auto-value-registry-fragment
    $simple-prefab-registry-key
    $simple-prefab-public-key
    $simple-prefab-type-metadata
    $prefab-key?
    $simple-prefab-mutable-mask-valid?/i32
    $simple-prefab-key?/i32
    $simple-prefab-key-name/checked
    $simple-prefab-key-init-count-or-minus-one/checked
    $simple-prefab-key-auto-count/checked
    $simple-prefab-key-auto-value/checked
    $simple-prefab-key-mutables/checked
    $simple-prefab-key-has-super?/i32
    $simple-prefab-key-parent-name/checked
    $simple-prefab-key-parent-init-count/checked
    $simple-prefab-key-parent-auto-count/checked
    $simple-prefab-key-parent-auto-value/checked
    $simple-prefab-key-parent-mutables/checked
    $simple-prefab-super-key-registry-key/checked
    $simple-prefab-empty-mutable-mask
    $simple-prefab-zero-auto-spec
    $simple-prefab-chain-alias-parent-total/checked
    $simple-prefab-chain-alias->explicit-key/checked
    $simple-prefab-chain-alias-top->explicit-key/checked
    $simple-prefab-mutable-mask-member?/i32
    $simple-prefab-struct-type/checked
    $simple-prefab-super-struct-type/checked
    $simple-prefab-substruct-type/checked
    $simple-prefab-struct-type-for-key/checked
    $prefab-metadata?/i32
    $raise-make-prefab-struct:key
    $make-prefab-struct
    $make-struct-accessor/checked
    $struct-type-accessor-name
    $struct-type-predicate-name-string
    $struct-type->display-string
    $raise-struct-accessor:target
    $raise-struct-accessor:index
    $raise-struct-accessor:index-too-large
    $struct-accessor
    $raise-struct-mutator:index-too-large
    $struct-constructor-procedure?
    $struct-predicate-procedure?
    $struct-accessor-procedure?
    $struct-mutator-procedure?
    $fill-fields-from-args
    $fill-fields-from-values
    $struct-type-property-predicate->descriptor
    $struct-type-property?
    $make-struct-type-property-descriptor/checked
    $struct-type-property-table-empty
    $raise-make-struct-type-property:supers
    $initialize-prefab-struct-type-registry))

;; struct-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given struct helper names from a helper index.
(define (struct-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; struct-core-predicate-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render struct core predicate helpers in runtime assembly order.
(define (struct-core-predicate-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-core-predicate-runtime-helper-names))

;; struct-prefab-registry-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab registry initialization.
(define struct-prefab-registry-runtime-helper-names
  '($initialize-prefab-struct-type-registry))

;; struct-guarded-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for guarded constructor helpers.
(define struct-guarded-constructor-runtime-only-helper-names
  '($struct-constructor/with-guard
    $fill-fields-from-args
    $fill-fields-from-values))

;; struct-type-property-lookup-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type property lookup helpers.
(define struct-type-property-lookup-runtime-only-helper-names
  '($struct-type-property-lookup
    $struct-type-property-lookup-by-name))

;; struct-type-property-closure-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type property closure helpers.
(define struct-type-property-closure-runtime-only-helper-names
  '($struct-type-property-predicate
    $struct-type-property-accessor
    $struct-type-property-predicate->descriptor
    $struct-type-property-accessor->descriptor))

;; struct-type-property-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type property predicate helpers.
(define struct-type-property-predicate-runtime-only-helper-names
  '($struct-type-property?
    $struct-type-property-accessor-procedure?
    $struct-type-property-predicate-procedure?))

;; struct-type-property-descriptor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type property descriptor helpers.
(define struct-type-property-descriptor-runtime-only-helper-names
  '($make-struct-type-property-descriptor
    $make-struct-type-property-descriptor/checked))

;; struct-type-property-table-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type property table helpers.
(define struct-type-property-table-runtime-only-helper-names
  '($struct-type-property-table-empty
    $struct-type-property-table-copy
    $struct-type-property-merge-list!
    $struct-type-property-guard-apply
    $raise-prop:checked-procedure-contract
    $struct-type-property-attach!
    $struct-type-property-table-has-name?/i32))

;; struct-type-property-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type property construction helpers.
(define struct-type-property-constructor-runtime-only-helper-names
  '($struct-type-info-for-guard
    $struct-type-properties-normalize
    $raise-make-struct-type-property:name
    $raise-make-struct-type-property:guard
    $raise-make-struct-type-property:supers
    $raise-make-struct-type-property:accessor-name
    $raise-make-struct-type-property:contract-str
    $raise-make-struct-type-property:realm
    $raise-guard-for-prop:object-name-field-index
    $raise-guard-for-prop:equal+hash-contract
    $make-struct-type-property
    $unsafe-make-struct-type-property/guard-calls-no-arguments))

;; struct-procedure-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedural struct helpers.
(define struct-procedure-runtime-only-helper-names
  '($applicable-struct?/i32
    $checked-procedure-struct?/i32
    $struct-procedure-delegate
    $procedure-struct-type?
    $checked-procedure-check-and-extract))

;; struct-procedure-invoker-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for the struct procedure invoker.
(define struct-procedure-invoker-runtime-only-helper-names
  '($invoke-struct))

;; struct-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic struct helpers.
(define struct-basic-runtime-only-helper-names
  '($struct?
    $struct-type?
    $check-struct-type
    $check-inspector
    $struct-type-is-a?/i32
    $struct-type-authentic?))

;; struct-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct conversion helpers.
(define struct-conversion-runtime-only-helper-names
  '($struct->list
    $struct->vector))

;; struct-descriptor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type descriptor helpers.
(define struct-descriptor-runtime-only-helper-names
  '($make-struct-type-descriptor
    $make-struct-type-descriptor/checked))

;; struct-format-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct formatting helpers.
(define struct-format-runtime-only-helper-names
  '($raise-format/display:struct:expected-struct
    $format/display:struct))

;; struct-prefab-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for initial prefab helpers.
(define struct-prefab-basic-runtime-only-helper-names
  '($raise-sealed-struct-supertype
    $simple-prefab-auto-value-supported?/i32))

;; struct-prefab-key-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab key encoding helpers.
(define struct-prefab-key-runtime-only-helper-names
  '($simple-prefab-auto-value-registry-fragment
    $simple-prefab-registry-key
    $simple-prefab-public-key
    $simple-prefab-type-metadata
    $prefab-key?))

;; struct-prefab-key-validation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab key validation helpers.
(define struct-prefab-key-validation-runtime-only-helper-names
  '($simple-prefab-mutable-mask-valid?/i32
    $simple-prefab-key?/i32))

;; struct-prefab-key-accessor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab key accessor helpers.
(define struct-prefab-key-accessor-runtime-only-helper-names
  '($simple-prefab-key-name/checked
    $simple-prefab-key-init-count-or-minus-one/checked
    $simple-prefab-key-auto-count/checked
    $simple-prefab-key-auto-value/checked
    $simple-prefab-key-mutables/checked
    $simple-prefab-key-has-super?/i32
    $simple-prefab-key-parent-name/checked
    $simple-prefab-key-parent-init-count/checked
    $simple-prefab-key-parent-auto-count/checked
    $simple-prefab-key-parent-auto-value/checked
    $simple-prefab-key-parent-mutables/checked))

;; struct-prefab-chain-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab chain and alias helpers.
(define struct-prefab-chain-runtime-only-helper-names
  '($simple-prefab-super-key-registry-key/checked
    $simple-prefab-empty-mutable-mask
    $simple-prefab-zero-auto-spec
    $simple-prefab-chain-alias-parent-total/checked
    $simple-prefab-chain-alias->explicit-key/checked
    $simple-prefab-chain-alias-top->explicit-key/checked
    $simple-prefab-mutable-mask-member?/i32))

;; struct-prefab-struct-type-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab struct-type interning helpers.
(define struct-prefab-struct-type-runtime-only-helper-names
  '($simple-prefab-struct-type/checked
    $simple-prefab-super-struct-type/checked
    $simple-prefab-substruct-type/checked
    $simple-prefab-struct-type-for-key/checked))

;; struct-prefab-metadata-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab metadata helpers.
(define struct-prefab-metadata-runtime-only-helper-names
  '($prefab-metadata?/i32
    $prefab-struct-type-key+field-count
    $prefab-struct-key
    $prefab-struct-field-mutable?/i32))

;; struct-prefab-immutables-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab immutability mask helpers.
(define struct-prefab-immutables-runtime-only-helper-names
  '($simple-prefab-immutables->mutables))

;; struct-prefab-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab constructor helpers.
(define struct-prefab-constructor-runtime-only-helper-names
  '($raise-make-prefab-struct:key
    $make-prefab-struct))

;; struct-type-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct type construction helpers.
(define struct-type-constructor-runtime-only-helper-names
  '($raise-make-struct-type:name
    $raise-make-struct-type:super
    $raise-make-struct-type:field-count
    $raise-make-struct-type:guard
    $raise-make-struct-type:inspector
    $raise-make-struct-type:props
    $raise-make-struct-type:immutables
    $raise-make-struct-type:immutable-index
    $raise-make-struct-type:constructor-name
    $raise-make-struct-type:proc-spec
    $raise-make-struct-type:proc-spec-index
    $raise-make-struct-type:non-generative
    $make-struct-type))

;; struct-accessor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic struct accessor helpers.
(define struct-accessor-runtime-only-helper-names
  '($make-struct-accessor
    $make-struct-accessor/checked
    $struct-type-accessor-name
    $struct-type-mutator-name
    $struct-type-predicate-name-string
    $struct-type->display-string
    $raise-struct-accessor:target
    $raise-struct-accessor:index
    $raise-struct-accessor:index-too-large
    $struct-accessor))

;; struct-constructor-wrapper-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct constructor wrapper helpers.
(define struct-constructor-wrapper-runtime-only-helper-names
  '($make-struct-constructor))

;; struct-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct constructor implementation helpers.
(define struct-constructor-runtime-only-helper-names
  '($struct-constructor/no-guard
    $make-struct-constructor/checked))

;; struct-mutator-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic struct mutator helpers.
(define struct-mutator-runtime-only-helper-names
  '($make-struct-mutator/checked
    $raise-struct-mutator:target
    $raise-struct-mutator:index
    $raise-struct-mutator:index-too-large
    $raise-struct-mutator:immutable-field
    $struct-mutator))

;; struct-field-mutator-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct field mutator helpers.
(define struct-field-mutator-runtime-only-helper-names
  '($make-struct-mutator/specialized/checked
    $struct-mutator/specialized
    $build-structure-field-mutator-name
    $raise-make-struct-field-mutator:mutator-proc
    $raise-make-struct-field-mutator:field-pos
    $raise-make-struct-field-mutator:name
    $raise-make-struct-field-mutator:contract-str
    $raise-make-struct-field-mutator:realm
    $make-struct-field-mutator))

;; struct-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic struct predicate helpers.
(define struct-predicate-runtime-only-helper-names
  '($make-struct-predicate
    $make-struct-predicate/checked
    $struct-predicate))

;; struct-field-accessor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct field accessor helpers.
(define struct-field-accessor-runtime-only-helper-names
  '($raise-make-struct-field-accessor:accessor-proc
    $raise-make-struct-field-accessor:field-pos
    $raise-make-struct-field-accessor:name
    $raise-make-struct-field-accessor:contract-str
    $raise-make-struct-field-accessor:realm
    $make-struct-field-accessor
    $struct-field-accessor/specialized))

;; struct-procedure-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct procedure predicates.
(define struct-procedure-predicate-runtime-only-helper-names
  '($struct-constructor-procedure?
    $struct-predicate-procedure?
    $struct-accessor-procedure?
    $struct-mutator-procedure?))

;; struct-basic-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic struct helpers before prefab support.
(define struct-basic-runtime-helper-names
  (append struct-basic-runtime-only-helper-names
          struct-conversion-runtime-only-helper-names
          struct-format-runtime-only-helper-names
          struct-descriptor-runtime-only-helper-names))

;; struct-prefab-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for prefab struct helpers.
(define struct-prefab-runtime-helper-names
  (append struct-prefab-basic-runtime-only-helper-names
          struct-prefab-key-runtime-only-helper-names
          struct-prefab-key-validation-runtime-only-helper-names
          struct-prefab-key-accessor-runtime-only-helper-names
          struct-prefab-chain-runtime-only-helper-names
          struct-prefab-struct-type-runtime-only-helper-names
          struct-prefab-metadata-runtime-only-helper-names
          struct-prefab-immutables-runtime-only-helper-names
          struct-prefab-constructor-runtime-only-helper-names))

;; struct-construction-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order before primitive function declarations.
(define struct-construction-runtime-helper-names
  (append struct-type-constructor-runtime-only-helper-names
          struct-accessor-runtime-only-helper-names
          struct-constructor-wrapper-runtime-only-helper-names))

;; struct-constructor-access-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order after primitive function declarations.
(define struct-constructor-access-runtime-helper-names
  (append struct-constructor-runtime-only-helper-names
          struct-mutator-runtime-only-helper-names
          struct-field-mutator-runtime-only-helper-names
          struct-predicate-runtime-only-helper-names
          struct-field-accessor-runtime-only-helper-names
          struct-procedure-predicate-runtime-only-helper-names
          struct-guarded-constructor-runtime-only-helper-names))

;; struct-type-property-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for structure type property helpers.
(define struct-type-property-runtime-helper-names
  (append struct-type-property-lookup-runtime-only-helper-names
          struct-type-property-closure-runtime-only-helper-names
          struct-type-property-predicate-runtime-only-helper-names
          struct-type-property-descriptor-runtime-only-helper-names
          struct-type-property-table-runtime-only-helper-names
          struct-type-property-constructor-runtime-only-helper-names))

;; struct-procedure-invoker-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render the struct procedure invoker in runtime assembly order.
(define (struct-procedure-invoker-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-procedure-invoker-runtime-only-helper-names))

;; struct-prefab-registry-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render prefab registry initialization helpers in runtime assembly order.
(define (struct-prefab-registry-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-prefab-registry-runtime-helper-names))

;; struct-basic-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render basic struct helpers in runtime assembly order.
(define (struct-basic-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-basic-runtime-helper-names))

;; struct-prefab-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render prefab struct helpers in runtime assembly order.
(define (struct-prefab-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-prefab-runtime-helper-names))

;; struct-construction-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render struct construction helpers placed before primitive function declarations.
(define (struct-construction-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-construction-runtime-helper-names))

;; struct-constructor-access-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render struct constructor, predicate, accessor, and mutator helpers.
(define (struct-constructor-access-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-constructor-access-runtime-helper-names))

;; struct-type-property-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render structure type property helpers in runtime assembly order.
(define (struct-type-property-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-type-property-runtime-helper-names))

;; struct-procedure-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render procedural struct helpers in runtime assembly order.
(define (struct-procedure-runtime-helper-forms helper-index)
  (struct-helper-forms helper-index struct-procedure-runtime-only-helper-names))

;; struct-basic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate basic struct predicates and checkers used by the monolithic runtime.
(define struct-basic-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-basic-runtime-only-helpers
   '(
     (func $struct? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $Struct) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $struct-type? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $StructType) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $check-struct-type
           (param $name (ref eq))
           (param $v    (ref eq))
           (result      (ref eq))

           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $false))
               (then (local.get $v)) ;; allow #f
               (else (if (result (ref eq))
                         (ref.test (ref $StructType) (local.get $v))
                         (then (local.get $v))
                         (else (call $raise-argument-error1
                                     (local.get $name)
                                     (global.get $string:struct-type-or-false)
                                     (local.get $v))
                               (unreachable))))))

     (func $check-inspector
           (param $name (ref eq))
           (param $v    (ref eq))
           (result      (ref eq))

           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $false))
               (then (local.get $v)) ;; allow #f
               (else (if (result (ref eq))
                         (ref.eq (call $inspector? (local.get $v)) (global.get $true))
                         (then (local.get $v))
                         (else (call $raise-argument-error1
                                     (local.get $name)
                                     (global.get $string:inspector-or-false)
                                     (local.get $v))
                               (unreachable))))))

     (func $struct-type-is-a?/i32
           ; is $a a subtype of $b ?
           (param $a (ref eq)) (param $b (ref eq))
           (result i32)

           (local $cur (ref eq))
           (local.set $cur (local.get $a))

           (loop $walk
                 ;; Success: found a matching struct type in the hierarchy.
                 (if (ref.eq (local.get $cur) (local.get $b))
                     (then (return (i32.const 1))))

                 ;; Failure: reached the end of the chain or encountered a
                 ;; non-struct descriptor before finding $b.
                 (if (ref.eq (local.get $cur) (global.get $false))
                     (then (return (i32.const 0))))
                 (if (i32.eqz (ref.test (ref $StructType) (local.get $cur)))
                     (then (return (i32.const 0))))

                 ;; Walk up the supertype chain and continue searching.
                 (local.set $cur
                            (struct.get $StructType $super
                                        (ref.cast (ref $StructType) (local.get $cur))))
                 (br $walk))
           (unreachable))

     (func $struct-type-authentic? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $std   (ref $StructType))
           (local $props (ref $HashEqMutable))
           (local $has   i32)

           (if (i32.eqz (ref.test (ref $StructType) (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:struct-type-authentic?)
                           (global.get $string:struct-type?)
                           (local.get $v))
                     (unreachable)))

           (local.set $std (ref.cast (ref $StructType) (local.get $v)))
           (local.set $props
                      (ref.cast (ref $HashEqMutable)
                                (struct.get $StructType $properties (local.get $std))))
           (local.set $has
                      (call $struct-type-property-table-has-name?/i32
                            (local.get $props)
                            (ref.cast (ref $Symbol)
                                      (global.get $symbol:prop:authentic))))
           (if (result (ref eq))
               (i32.eq (local.get $has) (i32.const 1))
               (then (global.get $true))
               (else (global.get $false))))
     )))

;; struct-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct conversion helpers used by the monolithic runtime.
(define struct-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-conversion-runtime-only-helpers
   '(
     ;; Note: The #:on-opaque keyword is accepted as a positional optional argument.
     ;;       Keyword arguments are not yet supported, so callers must pass the
     ;;       mode as the second argument directly.
     (func $struct->list (type $Prim02)
           (param $v (ref eq))
           (param $mode-raw (ref eq)) ;; optional, defaults to 'error
           (result (ref eq))

           (local $mode    (ref eq))
           (local $s       (ref $Struct))
           (local $fields  (ref $Array))
           (local $i       i32)
           (local $count   i32)
           (local $acc     (ref eq))
           (local $field   (ref eq))

           ;; Decode optional #:on-opaque mode.
           (local.set $mode (global.get $symbol:error))
           (if (ref.eq (local.get $mode-raw) (global.get $missing))
               (then)
               (else (if (ref.eq (local.get $mode-raw) (global.get $symbol:error))
                         (then)
                         (else (if (ref.eq (local.get $mode-raw) (global.get $symbol:return-false))
                                   (then (local.set $mode (global.get $symbol:return-false)))
                                   (else (if (ref.eq (local.get $mode-raw) (global.get $symbol:skip))
                                             (then (local.set $mode (global.get $symbol:skip)))
                                             (else (call $raise-argument-error1
                                                         (global.get $symbol:struct->list)
                                                         (global.get $string:struct->list:on-opaque)
                                                         (local.get $mode-raw))
                                                   (unreachable)))))))))

           ;; Handle non-struct inputs according to on-opaque mode.
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (if (ref.eq (local.get $mode) (global.get $symbol:error))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:struct->list)
                                     (global.get $string:struct?)
                                     (local.get $v))
                               (unreachable))
                         (else (if (ref.eq (local.get $mode) (global.get $symbol:return-false))
                                   (then (return (global.get $false)))
                                   (else (return (global.get $null))))))))

           ;; Convert accessible struct fields to a list.
           (local.set $s      (ref.cast (ref $Struct) (local.get $v)))
           (local.set $fields (struct.get $Struct $fields (local.get $s)))
           (local.set $count  (array.len (local.get $fields)))
           (local.set $acc    (global.get $null))
           (local.set $i      (i32.sub (local.get $count) (i32.const 1)))

           (block $done
                  (loop $loop
                        (br_if $done (i32.lt_s (local.get $i) (i32.const 0)))
                        (local.set $field (array.get $Array (local.get $fields) (local.get $i)))
                        (local.set $acc
                                   (struct.new $Pair
                                               (i32.const 0)
                                               (local.get $field)
                                               (local.get $acc)))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (br $loop)))

           (local.get $acc))


     (func $struct->vector (type $Prim02)
           (param $v          (ref eq))
           (param $opaque-raw (ref eq)) ;; optional, defaults to '...
           (result            (ref eq))

           (local $opaque   (ref eq))
           (local $s        (ref $Struct))
           (local $type     (ref $StructType))
           (local $name     (ref $Symbol))
           (local $name-str (ref $String))
           (local $tag-str  (ref $String))
           (local $tag      (ref $Symbol))
           (local $fields   (ref $Array))
           (local $arr      (ref $Array))
           (local $count    i32)
           (local $i        i32)
           (local $field    (ref eq))

           ;; Decode optional opaque value argument.
           (local.set $opaque (global.get $symbol:...))
           (if (ref.eq (local.get $opaque-raw) (global.get $missing))
               (then)
               (else (local.set $opaque (local.get $opaque-raw))))

           ;; Validate struct argument.
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:struct->vector)
                           (global.get $string:struct?)
                           (local.get $v))
                     (unreachable)))

           ;; Extract struct information.
           (local.set $s        (ref.cast (ref $Struct) (local.get $v)))
           (local.set $fields   (struct.get $Struct $fields (local.get $s)))
           (local.set $count    (array.len (local.get $fields)))
           (local.set $type     (struct.get $Struct $type (local.get $s)))
           (local.set $name     (struct.get $StructType $name (local.get $type)))
           (local.set $name-str (ref.cast (ref $String)
                                           (call $symbol->immutable-string (local.get $name))))
           (local.set $tag-str  (call $string-append/2
                                      (global.get $string:struct:prefix)
                                      (local.get $name-str)))
           (local.set $tag      (call $string->symbol/checked (local.get $tag-str)))

           ;; Allocate result vector backing array.
           (local.set $arr   (array.new $Array
                                        (global.get $false)
                                        (i32.add (local.get $count) (i32.const 1))))
           (array.set $Array (local.get $arr) (i32.const 0) (local.get $tag))

           ;; Copy fields after the tag entry.
           (local.set $i (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                        (local.set $field (array.get $Array (local.get $fields) (local.get $i)))
                        (array.set $Array (local.get $arr)
                                   (i32.add (local.get $i) (i32.const 1))
                                   (local.get $field))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Build and return the vector.
           (struct.new $Vector
                       (i32.const 0)
                       (i32.const 0)
                       (local.get $arr)))
     )))

;; struct-descriptor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct type descriptor helpers used by the monolithic runtime.
(define struct-descriptor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-descriptor-runtime-only-helpers
   '(
     (func $make-struct-type-descriptor
           (param $name               (ref eq))  ;; (ref $Symbol)
           (param $super-type         (ref eq))  ;; (ref $StructType) or #f
           (param $init-field-count   (ref eq))  ;; fixnum
           (param $auto-field-count   (ref eq))  ;; fixnum
           ; optional:
           (param $auto-field-value   (ref eq))  ;; value to repeat
           (param $opt-props          (ref eq))  ;; or #f
           (param $inspector          (ref eq))  ;; or #f
           (param $proc-spec          (ref eq))  ;; or #f
           (param $immutables         (ref eq))  ;; or #f
           (param $opt-guard          (ref eq))  ;; or #f
           (param $constructor-name   (ref eq))  ;; or #f
           (result                    (ref $StructType))

           (local $ifc   i32)
           (local $afc   i32)
           (local $props (ref eq))
           (local $super (ref $StructType))

           ;; --- Argument checks ---
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
               (then (call $raise-argument-error/internal (local.get $name))))
           (if (i32.or
                (i32.eqz (ref.test (ref i31) (local.get $init-field-count)))
                (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $init-field-count))) (i32.const 1)) (i32.const 0)))
               (then (call $raise-argument-error/internal (local.get $init-field-count))))
           (if (i32.or
                (i32.eqz (ref.test (ref i31) (local.get $auto-field-count)))
                (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $auto-field-count))) (i32.const 1)) (i32.const 0)))
               (then (call $raise-argument-error/internal (local.get $auto-field-count))))

           ;; --- Decode fixnums ---
           (local.set $ifc (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $init-field-count))) (i32.const 1)))
           (local.set $afc (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $auto-field-count))) (i32.const 1)))

           ;; --- Handle optional props ---
           (local.set $props (local.get $opt-props))
           (if (ref.eq (local.get $props) (global.get $missing))
               (then (local.set $props (global.get $null)))
               (else (if (ref.eq (local.get $props) (global.get $false))
                         (then (local.set $props (global.get $null))))))

           ;; --- Cast super if not #f ---
           #;(local.set $super (if (result (ref $StructType))
                                   (ref.eq (local.get $super-type) (global.get $false))
                                   (then (ref.null $StructType))
                                   (else (ref.cast (ref $StructType) (local.get $super-type)))))

           ;; --- Delegate to /checked ---
           (call $make-struct-type-descriptor/checked
                 (ref.cast (ref $Symbol) (local.get $name))
                 (local.get $super-type)
                 (local.get $ifc)
                 (local.get $afc)
                 (local.get $auto-field-value)
                 (local.get $props)
                 (local.get $inspector)
                 (local.get $proc-spec)
                 (local.get $immutables)
                 (local.get $opt-guard)
                 (local.get $constructor-name)))


     (func $make-struct-type-descriptor/checked
           (param $name             (ref $Symbol))    ;; Struct name
           (param $super            (ref eq))         ;; (ref $StructType) or #f
           (param $ifc              i32)              ;; Init field count (decoded)
           (param $afc              i32)              ;; Auto field count (decoded)
           (param $auto-value       (ref eq))         ;; Value to fill auto fields
           (param $props            (ref eq))         ;; Property hash or #f
           (param $inspector        (ref eq))         ;; Inspector or #f
           (param $proc-spec        (ref eq))         ;; Unused
           (param $immutables       (ref eq))         ;; Immutables or #f
           (param $guard            (ref eq))         ;; Guard or #f
           (param $constructor-name (ref eq))         ;; Symbol or #f
           (result (ref $StructType))

           (local $has-super    i32)
           (local $super-typed  (ref null $StructType))
           (local $stfc         i32)
           (local $init-indices (ref eq))
           (local $auto-indices (ref eq))
           (local $auto-values  (ref eq))
           (local $total-fields i32)
           (local $props-table  (ref $HashEqMutable))

           ;; Default all list fields
           (local.set $init-indices (global.get $false))
           (local.set $auto-indices (global.get $false))
           (local.set $auto-values  (global.get $false))

           ;; Determine presence of supertype
           (local.set $has-super (i32.eqz (ref.eq (local.get $super) (global.get $false))))

           (if (local.get $has-super)
               (then
                (local.set $super-typed (ref.cast (ref $StructType) (local.get $super)))
                (local.set $stfc (struct.get $StructType $field-count (local.get $super-typed)))

                (local.set $init-indices
                           (call $append/2
                                 (struct.get $StructType $init-indices (local.get $super-typed))
                                 (call $list-from-range/checked
                                       (local.get $stfc)
                                       (i32.add (local.get $stfc) (local.get $ifc)))))
                (local.set $auto-indices
                           (call $append/2
                                 (struct.get $StructType $auto-indices (local.get $super-typed))
                                 (call $list-from-range/checked
                                       (i32.add (local.get $stfc) (local.get $ifc))
                                       (i32.add (local.get $stfc) (i32.add (local.get $ifc) (local.get $afc))))))

                (local.set $auto-values
                           (call $append/2
                                 (struct.get $StructType $auto-values (local.get $super-typed))
                                 (call $make-list/checked (local.get $afc) (local.get $auto-value)))))
               (else
                (local.set $stfc (i32.const 0))
                (local.set $init-indices
                           (call $list-from-range/checked (i32.const 0) (local.get $ifc)))
                (local.set $auto-indices
                           (call $list-from-range/checked
                                 (local.get $ifc)
                                 (i32.add (local.get $ifc) (local.get $afc))))
                (local.set $auto-values
                           (call $make-list/checked (local.get $afc) (local.get $auto-value)))))

           ;; Structure type properties
           (local.set $props-table
                      (if (result (ref $HashEqMutable))
                          (ref.test (ref $HashEqMutable) (local.get $props))
                          (then (ref.cast (ref $HashEqMutable) (local.get $props)))
                          (else (ref.cast (ref $HashEqMutable)
                                          (call $struct-type-properties-normalize
                                                (local.get $has-super)
                                                (local.get $super-typed)
                                                (local.get $props))))))

           ;; Compute total field count
           (local.set $total-fields
                      (i32.add (local.get $stfc)
                               (i32.add (local.get $ifc) (local.get $afc))))

           ;; Create struct type descriptor
           (struct.new $StructType
                       (i32.const 0)               ;; hash (lazily computed)
                       (local.get $name)
                       (local.get $super)
                       (local.get $total-fields)
                       (local.get $init-indices)
                       (local.get $auto-indices)
                       (local.get $auto-values)
                       (ref.cast (ref eq) (local.get $props-table))
                       (local.get $inspector)
                       (local.get $immutables)
                       (local.get $guard)
                       (local.get $constructor-name)))

     #;(func $make-struct-type-descriptor/checked
           ;; Required
           (param $name             (ref $Symbol))  ;; Symbol naming the struct type
           (param $super            (ref eq))       ;; (ref $StructType) or #f
           (param $ifc              i32)            ;; Number of init fields (unwrapped fixnum)
           (param $afc              i32)            ;; Number of auto fields (unwrapped fixnum)
           (param $auto-value       (ref eq))       ;; Value to fill for each auto field

           ;; Optional (already defaulted appropriately)
           (param $props            (ref eq))       ;; Property table (hash table) or #f
           (param $inspector        (ref eq))       ;; Inspector object or #f
           (param $proc-spec        (ref eq))       ;; Currently unused
           (param $immutables       (ref eq))       ;; Immutables descriptor or #f
           (param $guard            (ref eq))       ;; Guard procedure or #f
           (param $constructor-name (ref eq))       ;; Name symbol or #f

           (result (ref $StructType))

           (local $has-super    i32)
           (local $super-typed  (ref null $StructType))
           (local $stfc         i32)
           (local $init-indices (ref eq))
           (local $auto-indices (ref eq))
           (local $auto-values  (ref eq))
           (local $total-fields i32)

           ;; Initialize locals
           (local.set $init-indices (global.get $false))
           (local.set $auto-indices (global.get $false))
           (local.set $auto-values  (global.get $false))

           ;; Determine if super is present
           (local.set $has-super (i32.eqz (ref.eq (local.get $super) (global.get $false))))

           (if (local.get $has-super)
               (then
                (local.set $super-typed (ref.cast (ref $StructType) (local.get $super)))
                (local.set $stfc (struct.get $StructType $field-count (local.get $super-typed)))
                (local.set $init-indices
                           (call $append/2
                                 (struct.get $StructType $init-indices (local.get $super-typed))
                                 (call $list-from-range/checked (local.get $stfc) (local.get $ifc))))
                (local.set $auto-indices
                           (call $append/2
                                 (struct.get $StructType $auto-indices (local.get $super-typed))
                                 (call $list-from-range/checked
                                       (i32.add (local.get $stfc) (local.get $ifc))
                                       (local.get $afc))))
                (local.set $auto-values
                           (call $append/2
                                 (struct.get $StructType $auto-values (local.get $super-typed))
                                 (call $make-list/checked (local.get $afc) (local.get $auto-value)))))
               (else
                (local.set $stfc (i32.const 0))
                (local.set $init-indices (call $list-from-range/checked (i32.const 0) (local.get $ifc)))
                (local.set $auto-indices (call $list-from-range/checked (local.get $ifc) (local.get $afc)))
                (local.set $auto-values  (call $make-list/checked (local.get $afc) (local.get $auto-value)))))

           (local.set $total-fields (i32.add          (local.get $stfc)
                                             (i32.add (local.get $ifc)
                                                      (local.get $afc))))

           (struct.new $StructType
                       (i32.const 0)                  ;; $hash
                       (local.get $name)
                       (local.get $super)
                       (local.get $total-fields)
                       (local.get $init-indices)
                       (local.get $auto-indices)
                       (local.get $auto-values)
                       (local.get $props)
                       (local.get $inspector)
                       (local.get $immutables)
                       (local.get $guard)
                       (local.get $constructor-name)))
     )))

;; struct-format-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct formatting helpers used by the monolithic runtime.
(define struct-format-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-format-runtime-only-helpers
   '(
     (func $raise-format/display:struct:expected-struct
           (param $v (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:format)
                 (global.get $string:struct?)
                 (local.get $v))
           (unreachable))

     (func $format/display:struct
           (param $v (ref eq))
           (result (ref $String))

           (local $s      (ref $Struct))
           (local $type   (ref $StructType))
           (local $name   (ref eq))
           (local $fields (ref $Array))
           (local $n      i32)
           (local $i      i32)
           (local $out    (ref $GrowableArray))

           ;; Check struct type
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (call $raise-format/display:struct:expected-struct
                           (local.get $v))
                     (unreachable)))

           ;; Cast and extract
           (local.set $s      (ref.cast (ref $Struct) (local.get $v)))
           (local.set $type   (struct.get $Struct     $type   (local.get $s)))
           (local.set $name   (struct.get $StructType $name   (local.get $type)))
           (local.set $fields (struct.get $Struct     $fields (local.get $s)))
           (local.set $n      (array.len (local.get $fields)))

           ;; Start output
           (local.set $out (call $make-growable-array (i32.const 8)))
           (call $growable-array-add! (local.get $out)
                                    (ref.cast (ref $String) (global.get $string:struct-open))) ;; "#(struct "

           ;; Add name
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $name)))

           ;; Add each field
           (local.set $i (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (call $growable-array-add! (local.get $out)
                                                   (ref.cast (ref $String)
                                                            (global.get $string:space)))
                        (call $growable-array-add! (local.get $out)
                              (call $format/display
                                    (array.get $Array (local.get $fields) (local.get $i))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Close output
           (call $growable-array-add! (local.get $out)
                                    (ref.cast (ref $String)
                                             (global.get $string:close-paren)))
           (call $growable-array-of-strings->string (local.get $out)))
     )))

;; struct-prefab-basic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate initial prefab helpers used by the monolithic runtime.
(define struct-prefab-basic-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-basic-runtime-only-helpers
   `(
     ;; raise-sealed-struct-supertype : -> none
     ;;   Reject attempts to derive a structure type from a sealed parent.
     (func $raise-sealed-struct-supertype
           (call $raise
                 (call $exn:fail:contract/make
                       (global.get $string:sealed-struct-supertype)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     ;; simple-prefab-auto-value-supported?/i32 : any/c -> i32
     ;;   Accept stable scalar auto values for the supported prefab subset.
     (func $simple-prefab-auto-value-supported?/i32
           (param $v (ref eq))
           (result   i32)

           (local $raw    i32)
           (local $cursor (ref eq))
           (local $cell   (ref $Pair))
           (local $vec    (ref $Vector))
           (local $i      i32)
           (local $len    i32)

           (if (ref.eq (local.get $v) (global.get $false))
               (then (return (i32.const 1))))
           (if (ref.eq (local.get $v) (global.get $true))
               (then (return (i32.const 1))))
           (if (ref.eq (local.get $v) (global.get $null))
               (then (return (i32.const 1))))
           (if (ref.eq (local.get $v) (global.get $void))
               (then (return (i32.const 1))))
           (if (ref.test (ref $Symbol) (local.get $v))
               (then (return (i32.const 1))))
           (if (ref.test (ref $String) (local.get $v))
               (then (return (i32.const 1))))
           (if (ref.test (ref i31) (local.get $v))
               (then
                (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $v))))
                (if (i32.or
                     (i32.eqz (i32.and (local.get $raw) (i32.const 1)))
                    (i32.eq (i32.and (local.get $raw) (i32.const ,char-mask))
                             (i32.const ,char-tag)))
                    (then (return (i32.const 1))))))
           (if (i32.and
                (ref.test (ref $Pair) (local.get $v))
                (ref.eq (call $list? (local.get $v)) (global.get $true)))
               (then
                (local.set $cursor (local.get $v))
                (block $done-list
                       (loop $check-list
                             (br_if $done-list (ref.eq (local.get $cursor) (global.get $null)))
                             (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                             (if (i32.eqz
                                  (call $simple-prefab-auto-value-supported?/i32
                                        (struct.get $Pair $a (local.get $cell))))
                                 (then (return (i32.const 0))))
                             (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                             (br $check-list)))
                (return (i32.const 1))))
           (if (ref.test (ref $Vector) (local.get $v))
               (then
                (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                (local.set $len (call $vector-length/checked/i32 (local.get $vec)))
                (local.set $i (i32.const 0))
                (block $done-vector
                       (loop $check-vector
                             (br_if $done-vector (i32.ge_u (local.get $i) (local.get $len)))
                             (if (i32.eqz
                                  (call $simple-prefab-auto-value-supported?/i32
                                        (array.get $Array
                                                   (struct.get $Vector $arr (local.get $vec))
                                                   (local.get $i))))
                                 (then (return (i32.const 0))))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $check-vector)))
                (return (i32.const 1))))
           (i32.const 0))
     )))

;; struct-prefab-key-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab key encoding helpers used by the monolithic runtime.
(define struct-prefab-key-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-key-runtime-only-helpers
   `(
     ;; simple-prefab-auto-value-registry-fragment : any/c -> string?
     ;;   Build a type-tagged fragment for supported scalar auto values.
     (func $simple-prefab-auto-value-registry-fragment
           (param $v (ref eq))
           (result   (ref $String))

           (local $type-code i32)
           (local $content   (ref $String))
           (local $raw       i32)
           (local $cursor    (ref eq))
           (local $cell      (ref $Pair))
           (local $vec       (ref $Vector))
           (local $i         i32)
           (local $len       i32)
           (local $elem      (ref eq))

           (local.set $type-code (i32.const 0))
           (local.set $content (ref.cast (ref $String) (global.get $string:empty)))
           (if (ref.eq (local.get $v) (global.get $false))
               (then
                (local.set $type-code (i32.const 1))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $number->string
                                  (ref.i31 (i32.const 0))
                                  (global.get $missing))))))
           (if (ref.eq (local.get $v) (global.get $true))
               (then
                (local.set $type-code (i32.const 1))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $number->string
                                  (ref.i31 (i32.const 2))
                                  (global.get $missing))))))
           (if (ref.eq (local.get $v) (global.get $null))
               (then (local.set $type-code (i32.const 2))))
           (if (ref.eq (local.get $v) (global.get $void))
               (then (local.set $type-code (i32.const 3))))
           (if (ref.test (ref i31) (local.get $v))
               (then (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $v))))))
           (if (i32.and
                (ref.test (ref i31) (local.get $v))
                (i32.eqz (i32.and (local.get $raw) (i32.const 1))))
               (then
                (local.set $type-code (i32.const 4))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $number->string
                                  (local.get $v)
                                  (global.get $missing))))))
           (if (i32.and
                (ref.test (ref i31) (local.get $v))
                (i32.eq (i32.and (local.get $raw) (i32.const ,char-mask))
                        (i32.const ,char-tag)))
               (then
                (local.set $type-code (i32.const 5))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $number->string
                                  (ref.i31
                                   (i32.shl
                                    (i32.shr_u (local.get $raw) (i32.const ,char-shift))
                                    (i32.const 1)))
                                  (global.get $missing))))))
           (if (ref.test (ref $Symbol) (local.get $v))
               (then
                (local.set $type-code (i32.const 6))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $symbol->immutable-string
                                  (ref.cast (ref $Symbol) (local.get $v)))))))
           (if (ref.test (ref $String) (local.get $v))
               (then
                (local.set $type-code (i32.const 7))
                (local.set $content (ref.cast (ref $String) (local.get $v)))))
           (if (i32.and
                (ref.test (ref $Pair) (local.get $v))
                (ref.eq (call $list? (local.get $v)) (global.get $true)))
               (then
                (local.set $type-code (i32.const 8))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $number->string
                                  (ref.i31
                                   (i32.shl
                                    (call $length/i32 (local.get $v))
                                    (i32.const 1)))
                                  (global.get $missing))))
                (local.set $cursor (local.get $v))
                (block $done-list
                       (loop $walk-list
                             (br_if $done-list (ref.eq (local.get $cursor) (global.get $null)))
                             (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                             (local.set $content
                                        (call $string-append/2
                                              (call $string-append/2
                                                    (local.get $content)
                                                    (global.get $string:colon))
                                              (call $simple-prefab-auto-value-registry-fragment
                                                    (struct.get $Pair $a (local.get $cell)))))
                             (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                             (br $walk-list)))))
           (if (ref.test (ref $Vector) (local.get $v))
               (then
                (local.set $type-code (i32.const 9))
                (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                (local.set $len (call $vector-length/checked/i32 (local.get $vec)))
                (local.set $content
                           (ref.cast
                            (ref $String)
                            (call $number->string
                                  (ref.i31 (i32.shl (local.get $len) (i32.const 1)))
                                  (global.get $missing))))
                (local.set $i (i32.const 0))
                (block $done-vector
                       (loop $walk-vector
                             (br_if $done-vector (i32.ge_u (local.get $i) (local.get $len)))
                             (local.set $elem
                                        (array.get $Array
                                                   (struct.get $Vector $arr (local.get $vec))
                                                   (local.get $i)))
                             (local.set $content
                                        (call $string-append/2
                                              (call $string-append/2
                                                    (local.get $content)
                                                    (global.get $string:colon))
                                              (call $simple-prefab-auto-value-registry-fragment
                                                    (local.get $elem))))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $walk-vector)))))
           (call $string-append/2
                 (call $string-append/2
                       (call $string-append/2
                             (call $string-append/2
                                   (ref.cast
                                    (ref $String)
                                    (call $number->string
                                          (ref.i31 (i32.shl (local.get $type-code) (i32.const 1)))
                                          (global.get $missing)))
                                   (global.get $string:colon))
                             (ref.cast
                              (ref $String)
                              (call $number->string
                                    (ref.i31
                                     (i32.shl
                                      (call $string-length/checked/i32 (local.get $content))
                                      (i32.const 1)))
                                    (global.get $missing))))
                       (global.get $string:colon))
                 (local.get $content)))

     ;; simple-prefab-registry-key : symbol? i32 i32 any/c vector? -> symbol?
     ;;   Build the internal registry key for the supported prefab subset.
     (func $simple-prefab-registry-key
           (param $name       (ref $Symbol))
           (param $init-count i32)
           (param $auto-count i32)
           (param $auto-value (ref eq))
           (param $mutables   (ref $Vector))
           (result            (ref $Symbol))

           (local $acc  (ref $String))
           (local $i    i32)
           (local $mlen i32)
           (local $midx i32)

           (local.set $acc
                      (call $string-append/2
                            (call $string-append/2
                                  (call $string-append/2
                                        (call $string-append/2
                                              (call $symbol->immutable-string (local.get $name))
                                              (global.get $string:colon))
                                        (call $number->string
                                              (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))
                                              (global.get $missing)))
                                  (global.get $string:colon))
                            (call $number->string
                                  (ref.i31 (i32.shl (local.get $auto-count) (i32.const 1)))
                                  (global.get $missing))))
           (local.set $acc
                      (call $string-append/2
                            (call $string-append/2
                                  (local.get $acc)
                                  (global.get $string:colon))
                            (call $simple-prefab-auto-value-registry-fragment
                                  (local.get $auto-value))))
           (local.set $mlen (call $vector-length/checked/i32 (local.get $mutables)))
           (local.set $i (i32.const 0))
           (block $done
                  (loop $walk
                        (br_if $done (i32.ge_u (local.get $i) (local.get $mlen)))
                        (local.set $midx
                                   (i32.shr_s
                                    (i31.get_s
                                     (ref.cast
                                      (ref i31)
                                      (array.get $Array
                                                 (struct.get $Vector $arr (local.get $mutables))
                                                 (local.get $i))))
                                    (i32.const 1)))
                        (local.set $acc
                                   (call $string-append/2
                                         (call $string-append/2
                                               (local.get $acc)
                                               (global.get $string:colon))
                                         (call $number->string
                                               (ref.i31 (i32.shl (local.get $midx) (i32.const 1)))
                                               (global.get $missing))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $walk)))
           (call $string->symbol/checked (local.get $acc)))

     ;; simple-prefab-public-key : symbol? i32 i32 any/c vector? -> prefab-key?
     ;;   Build the shortest public key for the supported prefab subset.
     (func $simple-prefab-public-key
           (param $name       (ref $Symbol))
           (param $init-count i32)
           (param $auto-count i32)
           (param $auto-value (ref eq))
           (param $mutables   (ref $Vector))
           (result            (ref eq))

           (local $auto-spec (ref eq))

           (if (i32.and (i32.eqz (local.get $auto-count))
                        (i32.eqz (call $vector-length/checked/i32 (local.get $mutables))))
               (then (return (local.get $name))))

           (local.set $auto-spec
                      (call $cons
                            (ref.i31 (i32.shl (local.get $auto-count) (i32.const 1)))
                            (call $cons (local.get $auto-value) (global.get $null))))
           (call $cons
                 (local.get $name)
                 (call $cons
                       (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))
                       (call $cons
                             (local.get $auto-spec)
                             (call $cons (local.get $mutables) (global.get $null))))))

     ;; simple-prefab-type-metadata : symbol? i32 i32 any/c vector? -> pair?
     ;;   Store the normalized public prefab key plus total field count.
     (func $simple-prefab-type-metadata
           (param $name       (ref $Symbol))
           (param $init-count i32)
           (param $auto-count i32)
           (param $auto-value (ref eq))
           (param $mutables   (ref $Vector))
           (result            (ref eq))

           (call $cons
                 (call $simple-prefab-public-key
                       (local.get $name)
                       (local.get $init-count)
                       (local.get $auto-count)
                       (local.get $auto-value)
                       (local.get $mutables))
                 (ref.i31 (i32.shl (i32.add (local.get $init-count)
                                            (local.get $auto-count))
                                   (i32.const 1)))))

     ;; prefab-key? : any/c -> boolean?
     ;;   Recognize the supported simple prefab key subset.
     (func $prefab-key? (type $Prim1)
           (param $key (ref eq))
           (result     (ref eq))

           (if (result (ref eq))
               (call $simple-prefab-key?/i32 (local.get $key))
               (then (global.get $true))
               (else (global.get $false))))
     )))


;; struct-prefab-key-validation-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab key validation helpers used by the monolithic runtime.
(define struct-prefab-key-validation-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-key-validation-runtime-only-helpers
   '(
     ;; simple-prefab-mutable-mask-valid?/i32 : any/c i32 -> i32
     ;;   Validate a mutable-field vector; negative total disables range checks.
     (func $simple-prefab-mutable-mask-valid?/i32
           (param $mutables (ref eq))
           (param $total    i32)
           (result          i32)

           (local $mlen     i32)
           (local $midx     (ref eq))
           (local $midx-i32 i32)
           (local $seen     (ref eq))
           (local $i        i32)
           (local $j        i32)

           (if (i32.eqz (ref.test (ref $Vector) (local.get $mutables)))
               (then (return (i32.const 0))))
           (local.set $mlen (call $vector-length/checked/i32
                                  (ref.cast (ref $Vector) (local.get $mutables))))
           (local.set $i (i32.const 0))
           (block $done
                  (loop $check
                        (br_if $done (i32.ge_u (local.get $i) (local.get $mlen)))
                        (local.set $midx
                                   (array.get $Array
                                              (struct.get $Vector $arr
                                                          (ref.cast (ref $Vector) (local.get $mutables)))
                                              (local.get $i)))
                        (if (ref.eq (call $exact-nonnegative-integer? (local.get $midx)) (global.get $false))
                            (then (return (i32.const 0))))
                        (local.set $midx-i32
                                   (i32.shr_s
                                    (i31.get_s (ref.cast (ref i31) (local.get $midx)))
                                    (i32.const 1)))
                        (if (i32.and
                             (i32.ge_s (local.get $total) (i32.const 0))
                             (i32.ge_u (local.get $midx-i32) (local.get $total)))
                            (then (return (i32.const 0))))
                        (local.set $j (i32.const 0))
                        (block $done-duplicates
                               (loop $check-duplicate
                                     (br_if $done-duplicates (i32.ge_u (local.get $j) (local.get $i)))
                                     (local.set $seen
                                                (array.get $Array
                                                           (struct.get $Vector $arr
                                                                       (ref.cast (ref $Vector) (local.get $mutables)))
                                                           (local.get $j)))
                                     (if (i32.eq
                                          (i32.shr_s
                                           (i31.get_s (ref.cast (ref i31) (local.get $seen)))
                                           (i32.const 1))
                                          (local.get $midx-i32))
                                         (then (return (i32.const 0))))
                                     (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                     (br $check-duplicate)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $check)))
           (i32.const 1))

     ;; simple-prefab-key?/i32 : any/c -> i32
     ;;   Accept symbols and mutable masks with supported scalar auto values.
     (func $simple-prefab-key?/i32
           (param $key (ref eq))
           (result     i32)

           (local $len        i32)
           (local $name       (ref eq))
           (local $count      (ref eq))
           (local $auto-spec  (ref eq))
           (local $mutables   (ref eq))
           (local $auto-count (ref eq))
           (local $auto-val   (ref eq))
           (local $total      i32)
           (local $mlen       i32)
           (local $midx       (ref eq))
           (local $midx-i32   i32)
           (local $i          i32)
           (local $j          i32)
           (local $seen       (ref eq))
           (local $parent-count (ref eq))
           (local $parent-mutables (ref eq))
           (local $child-mutables  (ref eq))

           ;; A symbol key is shorthand for the simple no-super/no-auto shape.
           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return (i32.const 1))))

           (if (ref.eq (call $list? (local.get $key)) (global.get $false))
               (then (return (i32.const 0))))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.or
                (i32.lt_u (local.get $len) (i32.const 1))
                (i32.and (i32.gt_u (local.get $len) (i32.const 6))
                         (i32.or
                          (i32.and
                           (i32.lt_u (local.get $len) (i32.const 8))
                           (i32.ne
                            (i32.rem_u
                             (i32.sub (local.get $len) (i32.const 1))
                             (i32.const 2))
                            (i32.const 0)))
                          (i32.and
                           (i32.ge_u (local.get $len) (i32.const 8))
                           (i32.and
                            (i32.ne
                             (i32.rem_u
                              (i32.sub (local.get $len) (i32.const 4))
                              (i32.const 4))
                             (i32.const 0))
                            (i32.ne
                             (i32.rem_u (local.get $len) (i32.const 2))
                             (i32.const 1)))))))
               (then (return (i32.const 0))))

           (local.set $name (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 0)))
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
               (then (return (i32.const 0))))
           (if (i32.eq (local.get $len) (i32.const 1))
               (then (return (i32.const 1))))

           ;; Supertype aliases:
           ;;   (child parent parent-init)
           ;;   (child child-init parent parent-init)
           ;;   (child child-mutables parent parent-init parent-mutables)
           ;;   (child child-init child-mutables parent parent-init parent-mutables)
           (if (i32.eq (local.get $len) (i32.const 3))
               (then
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 2)))
                (if (i32.and
                     (ref.test (ref $Symbol)
                               (call $list-ref/checked
                                     (ref.cast (ref $Pair) (local.get $key))
                                     (i32.const 1)))
                     (ref.eq (call $exact-nonnegative-integer? (local.get $parent-count))
                             (global.get $true)))
                    (then (return (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then
                (local.set $count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 1)))
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 3)))
                (if (i32.and
                     (ref.eq (call $exact-nonnegative-integer? (local.get $count))
                             (global.get $true))
                     (i32.and
                      (ref.test (ref $Symbol)
                                (call $list-ref/checked
                                      (ref.cast (ref $Pair) (local.get $key))
                                      (i32.const 2)))
                      (ref.eq (call $exact-nonnegative-integer? (local.get $parent-count))
                              (global.get $true))))
                    (then (return (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then
                ;; Nested supertype alias: (child parent parent-init grandparent grandparent-init).
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 2)))
                (local.set $count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 4)))
                (if (i32.and
                     (ref.test (ref $Symbol)
                               (call $list-ref/checked
                                     (ref.cast (ref $Pair) (local.get $key))
                                     (i32.const 1)))
                     (i32.and
                      (ref.eq (call $exact-nonnegative-integer? (local.get $parent-count))
                              (global.get $true))
                      (i32.and
                       (ref.test (ref $Symbol)
                                 (call $list-ref/checked
                                       (ref.cast (ref $Pair) (local.get $key))
                                       (i32.const 3)))
                       (ref.eq (call $exact-nonnegative-integer? (local.get $count))
                               (global.get $true)))))
                    (then (return (i32.const 1))))
                (local.set $child-mutables
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 1)))
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 3)))
                (local.set $parent-mutables
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 4)))
                (if (i32.and
                     (call $simple-prefab-mutable-mask-valid?/i32
                           (local.get $child-mutables)
                           (i32.const -1))
                     (i32.and
                      (ref.test (ref $Symbol)
                                (call $list-ref/checked
                                      (ref.cast (ref $Pair) (local.get $key))
                                      (i32.const 2)))
                      (i32.and
                       (ref.eq (call $exact-nonnegative-integer? (local.get $parent-count))
                               (global.get $true))
                       (call $simple-prefab-mutable-mask-valid?/i32
                             (local.get $parent-mutables)
                             (i32.shr_s
                              (i31.get_s (ref.cast (ref i31) (local.get $parent-count)))
                              (i32.const 1))))))
                    (then (return (i32.const 1))))))
           (if (i32.gt_u (local.get $len) (i32.const 6))
               (then
                (if (i32.and
                     (i32.eq
                      (i32.rem_u (local.get $len) (i32.const 2))
                      (i32.const 1))
                     (ref.test
                      (ref $Symbol)
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 1))))
                    (then
                     (local.set $i (i32.const 1))
                     (block $done-chain-alias
                            (loop $check-chain-alias
                                  (br_if $done-chain-alias
                                         (i32.ge_u (local.get $i) (local.get $len)))
                                  (if (i32.eqz
                                       (ref.test
                                        (ref $Symbol)
                                        (call $list-ref/checked
                                              (ref.cast (ref $Pair) (local.get $key))
                                              (local.get $i))))
                                      (then (return (i32.const 0))))
                                  (local.set $count
                                             (call $list-ref/checked
                                                   (ref.cast (ref $Pair) (local.get $key))
                                                   (i32.add (local.get $i) (i32.const 1))))
                                  (if (ref.eq
                                       (call $exact-nonnegative-integer? (local.get $count))
                                       (global.get $false))
                                      (then (return (i32.const 0))))
                                  (local.set $i (i32.add (local.get $i) (i32.const 2)))
                                  (br $check-chain-alias)))
                     (return (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 6))
               (then
                (local.set $count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 1)))
                (local.set $child-mutables
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 2)))
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 4)))
                (local.set $parent-mutables
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 5)))
                ;; Nested supertype alias: (child child-init parent parent-init grandparent grandparent-init).
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 3)))
                (if (i32.and
                     (ref.eq (call $exact-nonnegative-integer? (local.get $count))
                             (global.get $true))
                     (i32.and
                      (ref.test (ref $Symbol)
                                (local.get $child-mutables))
                      (i32.and
                       (ref.eq (call $exact-nonnegative-integer? (local.get $parent-count))
                               (global.get $true))
                       (i32.and
                        (ref.test (ref $Symbol)
                                  (call $list-ref/checked
                                        (ref.cast (ref $Pair) (local.get $key))
                                        (i32.const 4)))
                        (ref.eq (call $exact-nonnegative-integer? (local.get $parent-mutables))
                                (global.get $true))))))
                    (then (return (i32.const 1))))
                (local.set $parent-count
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 4)))
                (if (i32.and
                     (ref.eq (call $exact-nonnegative-integer? (local.get $count))
                             (global.get $true))
                     (i32.and
                      (call $simple-prefab-mutable-mask-valid?/i32
                            (local.get $child-mutables)
                            (i32.shr_s
                             (i31.get_s (ref.cast (ref i31) (local.get $count)))
                             (i32.const 1)))
                      (i32.and
                       (ref.test (ref $Symbol)
                                 (call $list-ref/checked
                                       (ref.cast (ref $Pair) (local.get $key))
                                       (i32.const 3)))
                       (i32.and
                        (ref.eq (call $exact-nonnegative-integer? (local.get $parent-count))
                                (global.get $true))
                        (call $simple-prefab-mutable-mask-valid?/i32
                              (local.get $parent-mutables)
                              (i32.shr_s
                               (i31.get_s (ref.cast (ref i31) (local.get $parent-count)))
                               (i32.const 1)))))))
                    (then (return (i32.const 1))))))
           (if (i32.gt_u (local.get $len) (i32.const 6))
               (then
                (if (i32.and
                     (i32.eqz
                      (i32.rem_u (local.get $len) (i32.const 2)))
                     (ref.test
                      (ref $Symbol)
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 2))))
                    (then
                     (local.set $count
                                (call $list-ref/checked
                                      (ref.cast (ref $Pair) (local.get $key))
                                      (i32.const 1)))
                     (if (ref.eq (call $exact-nonnegative-integer? (local.get $count))
                                 (global.get $false))
                         (then (return (i32.const 0))))
                     (local.set $i (i32.const 2))
                     (block $done-chain-alias
                            (loop $check-chain-alias
                                  (br_if $done-chain-alias
                                         (i32.ge_u (local.get $i) (local.get $len)))
                                  (if (i32.eqz
                                       (ref.test
                                        (ref $Symbol)
                                        (call $list-ref/checked
                                              (ref.cast (ref $Pair) (local.get $key))
                                              (local.get $i))))
                                      (then (return (i32.const 0))))
                                  (local.set $count
                                             (call $list-ref/checked
                                                   (ref.cast (ref $Pair) (local.get $key))
                                                   (i32.add (local.get $i) (i32.const 1))))
                                  (if (ref.eq
                                       (call $exact-nonnegative-integer? (local.get $count))
                                       (global.get $false))
                                      (then (return (i32.const 0))))
                                  (local.set $i (i32.add (local.get $i) (i32.const 2)))
                                  (br $check-chain-alias)))
                     (return (i32.const 1))))))

           (local.set $count (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 1)))
           (if (ref.eq (call $exact-nonnegative-integer? (local.get $count)) (global.get $false))
               (then (return (i32.const 0))))
           (if (i32.eq (local.get $len) (i32.const 2))
               (then (return (i32.const 1))))

           (local.set $auto-spec (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 2)))
           (if (ref.eq (call $list? (local.get $auto-spec)) (global.get $false))
               (then (return (i32.const 0))))
           (if (i32.ne (call $length/i32 (local.get $auto-spec)) (i32.const 2))
               (then (return (i32.const 0))))
           (local.set $auto-count
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $auto-spec))
                            (i32.const 0)))
           (local.set $auto-val
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $auto-spec))
                            (i32.const 1)))
           (if (ref.eq (call $exact-nonnegative-integer? (local.get $auto-count)) (global.get $false))
               (then (return (i32.const 0))))
           (if (i32.eqz (call $simple-prefab-auto-value-supported?/i32
                              (local.get $auto-val)))
               (then (return (i32.const 0))))
           (if (i32.eq (local.get $len) (i32.const 3))
               (then (return (i32.const 1))))

           (local.set $mutables (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 3)))
           (if (i32.eqz (ref.test (ref $Vector) (local.get $mutables)))
               (then (return (i32.const 0))))
           (local.set $mlen (call $vector-length/checked/i32
                                  (ref.cast (ref $Vector) (local.get $mutables))))
           (local.set $total
                      (i32.add
                       (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $count))) (i32.const 1))
                       (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $auto-count))) (i32.const 1))))
           (local.set $i (i32.const 0))
           (block $done-mutables
                  (loop $check-mutable
                        (br_if $done-mutables (i32.ge_u (local.get $i) (local.get $mlen)))
                        (local.set $midx
                                   (array.get $Array
                                              (struct.get $Vector $arr
                                                          (ref.cast (ref $Vector) (local.get $mutables)))
                                              (local.get $i)))
                        (if (ref.eq (call $exact-nonnegative-integer? (local.get $midx)) (global.get $false))
                            (then (return (i32.const 0))))
                        (local.set $midx-i32
                                   (i32.shr_s
                                    (i31.get_s (ref.cast (ref i31) (local.get $midx)))
                                    (i32.const 1)))
                        (if (i32.ge_u (local.get $midx-i32) (local.get $total))
                            (then (return (i32.const 0))))
                        (local.set $j (i32.const 0))
                        (block $done-duplicates
                               (loop $check-duplicate
                                     (br_if $done-duplicates (i32.ge_u (local.get $j) (local.get $i)))
                                     (local.set $seen
                                                (array.get $Array
                                                           (struct.get $Vector $arr
                                                                       (ref.cast (ref $Vector) (local.get $mutables)))
                                                           (local.get $j)))
                                     (if (i32.eq
                                          (i32.shr_s
                                           (i31.get_s (ref.cast (ref i31) (local.get $seen)))
                                           (i32.const 1))
                                          (local.get $midx-i32))
                                         (then (return (i32.const 0))))
                                     (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                     (br $check-duplicate)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $check-mutable)))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then (return (i32.const 1))))

           (local.set $name (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 4)))
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
               (then (return (i32.const 0))))
           (local.set $count (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 5)))
           (if (ref.eq (call $exact-nonnegative-integer? (local.get $count)) (global.get $false))
               (then (return (i32.const 0))))
           (local.set $auto-spec (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 6)))
           (if (ref.eq (call $list? (local.get $auto-spec)) (global.get $false))
               (then (return (i32.const 0))))
           (if (i32.ne (call $length/i32 (local.get $auto-spec)) (i32.const 2))
               (then (return (i32.const 0))))
           (local.set $auto-count
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $auto-spec))
                            (i32.const 0)))
           (local.set $auto-val
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $auto-spec))
                            (i32.const 1)))
           (if (ref.eq (call $exact-nonnegative-integer? (local.get $auto-count)) (global.get $false))
               (then (return (i32.const 0))))
           (if (i32.eqz (call $simple-prefab-auto-value-supported?/i32
                              (local.get $auto-val)))
               (then (return (i32.const 0))))
           (local.set $mutables (call $list-ref/checked (ref.cast (ref $Pair) (local.get $key)) (i32.const 7)))
           (if (i32.eqz (ref.test (ref $Vector) (local.get $mutables)))
               (then (return (i32.const 0))))
           (local.set $mlen (call $vector-length/checked/i32
                                  (ref.cast (ref $Vector) (local.get $mutables))))
           (local.set $total
                      (i32.add
                       (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $count))) (i32.const 1))
                       (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $auto-count))) (i32.const 1))))
           (local.set $i (i32.const 0))
           (block $done-parent-mutables
                  (loop $check-parent-mutable
                        (br_if $done-parent-mutables (i32.ge_u (local.get $i) (local.get $mlen)))
                        (local.set $midx
                                   (array.get $Array
                                              (struct.get $Vector $arr
                                                          (ref.cast (ref $Vector) (local.get $mutables)))
                                              (local.get $i)))
                        (if (ref.eq (call $exact-nonnegative-integer? (local.get $midx)) (global.get $false))
                            (then (return (i32.const 0))))
                        (local.set $midx-i32
                                   (i32.shr_s
                                    (i31.get_s (ref.cast (ref i31) (local.get $midx)))
                                    (i32.const 1)))
                        (if (i32.ge_u (local.get $midx-i32) (local.get $total))
                            (then (return (i32.const 0))))
                        (local.set $j (i32.const 0))
                        (block $done-parent-duplicates
                               (loop $check-parent-duplicate
                                     (br_if $done-parent-duplicates (i32.ge_u (local.get $j) (local.get $i)))
                                     (local.set $seen
                                                (array.get $Array
                                                           (struct.get $Vector $arr
                                                                       (ref.cast (ref $Vector) (local.get $mutables)))
                                                           (local.get $j)))
                                     (if (i32.eq
                                          (i32.shr_s
                                           (i31.get_s (ref.cast (ref i31) (local.get $seen)))
                                           (i32.const 1))
                                          (local.get $midx-i32))
                                         (then (return (i32.const 0))))
                                     (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                     (br $check-parent-duplicate)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $check-parent-mutable)))
           (i32.const 1))
     )))


;; struct-prefab-key-accessor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab key accessor helpers used by the monolithic runtime.
(define struct-prefab-key-accessor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-key-accessor-runtime-only-helpers
   '(
     ;; simple-prefab-key-name/checked : prefab-key? -> symbol?
     ;;   Extract the struct name from a supported simple prefab key.
     (func $simple-prefab-key-name/checked
           (param $key (ref eq))
           (result     (ref $Symbol))

           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return (ref.cast (ref $Symbol) (local.get $key)))))
           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (ref.cast (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 0))))

     ;; simple-prefab-key-init-count-or-minus-one/checked : prefab-key? -> i32
     ;;   Return the explicit non-auto count, or -1 when it must be inferred.
     (func $simple-prefab-key-init-count-or-minus-one/checked
           (param $key (ref eq))
           (result     i32)

           (local $len   i32)
           (local $count (ref eq))

           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return (i32.const -1))))
           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.eq (local.get $len) (i32.const 1))
               (then (return (i32.const -1))))
           (if (i32.eq (local.get $len) (i32.const 3))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 1)))
                    (then (return (i32.const -1))))))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then (return (i32.const -1))))
           (local.set $count (call $list-ref/checked
                                   (ref.cast (ref $Pair) (local.get $key))
                                   (i32.const 1)))
           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $count))) (i32.const 1)))

     ;; simple-prefab-key-auto-count/checked : prefab-key? -> i32
     ;;   Return the supported key's auto-field count.
     (func $simple-prefab-key-auto-count/checked
           (param $key (ref eq))
           (result     i32)

           (local $len        i32)
           (local $auto-spec  (ref eq))
           (local $auto-count (ref eq))

           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return (i32.const 0))))
           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.eq (local.get $len) (i32.const 3))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 1)))
                    (then (return (i32.const 0))))))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 2)))
                    (then (return (i32.const 0))))))
           (if (i32.and (i32.ge_u (local.get $len) (i32.const 5))
                        (i32.le_u (local.get $len) (i32.const 6)))
               (then (return (i32.const 0))))
           (if (i32.lt_u (local.get $len) (i32.const 3))
               (then (return (i32.const 0))))
           (local.set $auto-spec
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 2)))
           (local.set $auto-count
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $auto-spec))
                            (i32.const 0)))
           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $auto-count))) (i32.const 1)))

     ;; simple-prefab-key-auto-value/checked : prefab-key? -> any/c
     ;;   Return the supported key's scalar auto-field value.
     (func $simple-prefab-key-auto-value/checked
           (param $key (ref eq))
           (result     (ref eq))

           (local $len       i32)
           (local $auto-spec (ref eq))

           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return (global.get $false))))
           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.eq (local.get $len) (i32.const 3))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 1)))
                    (then (return (global.get $false))))))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 2)))
                    (then (return (global.get $false))))))
           (if (i32.and (i32.ge_u (local.get $len) (i32.const 5))
                        (i32.le_u (local.get $len) (i32.const 6)))
               (then (return (global.get $false))))
           (if (i32.lt_u (local.get $len) (i32.const 3))
               (then (return (global.get $false))))
           (local.set $auto-spec
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 2)))
           (call $list-ref/checked
                 (ref.cast (ref $Pair) (local.get $auto-spec))
                 (i32.const 1)))

     ;; simple-prefab-key-mutables/checked : prefab-key? -> vector?
     ;;   Return the supported mutable-field mask vector.
     (func $simple-prefab-key-mutables/checked
           (param $key (ref eq))
           (result     (ref $Vector))

           (local $len      i32)
           (local $mutables (ref eq))

           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))
           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 1)))
                    (then
                     (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))))
           (if (i32.eq (local.get $len) (i32.const 6))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 2)))
                    (then
                     (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then (return
                      (ref.cast
                       (ref $Vector)
                       (call $list-ref/checked
                             (ref.cast (ref $Pair) (local.get $key))
                             (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 6))
               (then (return
                      (ref.cast
                       (ref $Vector)
                       (call $list-ref/checked
                             (ref.cast (ref $Pair) (local.get $key))
                             (i32.const 2))))))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 2)))
                    (then
                     (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))))
           (if (i32.lt_u (local.get $len) (i32.const 4))
               (then (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))
           (local.set $mutables
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 3)))
           (ref.cast (ref $Vector) (local.get $mutables)))

     ;; simple-prefab-key-has-super?/i32 : prefab-key? -> i32
     ;;   Recognize the supported explicit flattened super-key shape.
     (func $simple-prefab-key-has-super?/i32
           (param $key (ref eq))
           (result     i32)

           (local $len i32)

           (if (ref.test (ref $Symbol) (local.get $key))
               (then (return (i32.const 0))))
           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.eq (local.get $len) (i32.const 3))
               (then
                (return
                 (ref.test
                  (ref $Symbol)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then
                (return
                 (ref.test
                  (ref $Symbol)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 2))))))
           (if (result i32)
               (i32.or
                (i32.or (i32.eq (local.get $len) (i32.const 5))
                        (i32.eq (local.get $len) (i32.const 6)))
                (i32.and
                 (i32.ge_u (local.get $len) (i32.const 8))
                 (i32.eqz
                  (i32.rem_u
                   (i32.sub (local.get $len) (i32.const 4))
                   (i32.const 4)))))
               (then (i32.const 1))
               (else (i32.const 0))))

     ;; simple-prefab-key-parent-name/checked : prefab-key? -> symbol?
     ;;   Extract the parent name from an explicit flattened super key.
     (func $simple-prefab-key-parent-name/checked
           (param $key (ref eq))
           (result     (ref $Symbol))

           (local $len i32)

           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.eq (local.get $len) (i32.const 3))
               (then
                (return
                 (ref.cast
                  (ref $Symbol)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 4))
               (then
                (return
                 (ref.cast
                  (ref $Symbol)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 2))))))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then
                (return
                 (ref.cast
                  (ref $Symbol)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 2))))))
           (if (i32.eq (local.get $len) (i32.const 6))
               (then
                (return
                 (ref.cast
                  (ref $Symbol)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 3))))))
           (ref.cast (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 4))))

     ;; simple-prefab-key-parent-init-count/checked : prefab-key? -> i32
     ;;   Extract the parent init-field count from an explicit flattened super key.
     (func $simple-prefab-key-parent-init-count/checked
           (param $key (ref eq))
           (result     i32)

           (local $len   i32)
           (local $count (ref eq))

           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (local.set $count
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (if (result i32)
                                (i32.eq (local.get $len) (i32.const 3))
                                (then (i32.const 2))
                                (else
                                 (if (result i32)
                                     (i32.eq (local.get $len) (i32.const 4))
                                     (then (i32.const 3))
                                     (else
                                      (if (result i32)
                                          (i32.eq (local.get $len) (i32.const 5))
                                          (then (i32.const 3))
                                          (else
                                           (if (result i32)
                                               (i32.eq (local.get $len) (i32.const 6))
                                               (then (i32.const 4))
                                               (else (i32.const 5)))))))))))
           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $count))) (i32.const 1)))

     ;; simple-prefab-key-parent-auto-count/checked : prefab-key? -> i32
     ;;   Extract the parent auto-field count from an explicit flattened super key.
     (func $simple-prefab-key-parent-auto-count/checked
           (param $key (ref eq))
           (result     i32)

           (local $len         i32)
           (local $auto-spec  (ref eq))
           (local $auto-count (ref eq))

           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.ne (local.get $len) (i32.const 8))
               (then (return (i32.const 0))))
           (local.set $auto-spec
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 6)))
           (local.set $auto-count
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $auto-spec))
                            (i32.const 0)))
           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $auto-count))) (i32.const 1)))

     ;; simple-prefab-key-parent-auto-value/checked : prefab-key? -> any/c
     ;;   Extract the parent auto value from an explicit flattened super key.
     (func $simple-prefab-key-parent-auto-value/checked
           (param $key (ref eq))
           (result     (ref eq))

           (local $len       i32)
           (local $auto-spec (ref eq))

           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.ne (local.get $len) (i32.const 8))
               (then (return (global.get $false))))
           (local.set $auto-spec
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 6)))
           (call $list-ref/checked
                 (ref.cast (ref $Pair) (local.get $auto-spec))
                 (i32.const 1)))

     ;; simple-prefab-key-parent-mutables/checked : prefab-key? -> vector?
     ;;   Extract the parent mutable-field mask from an explicit flattened super key.
     (func $simple-prefab-key-parent-mutables/checked
           (param $key (ref eq))
           (result     (ref $Vector))

           (local $len i32)

           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.lt_u (local.get $len) (i32.const 5))
               (then (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then
                (return
                 (ref.cast
                  (ref $Vector)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 4))))))
           (if (i32.eq (local.get $len) (i32.const 6))
               (then
                (return
                 (ref.cast
                  (ref $Vector)
                  (call $list-ref/checked
                        (ref.cast (ref $Pair) (local.get $key))
                        (i32.const 5))))))
           (ref.cast (ref $Vector)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 7))))
     )))


;; struct-prefab-chain-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab chain and alias helpers used by the monolithic runtime.
(define struct-prefab-chain-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-chain-runtime-only-helpers
   '(
     ;; simple-prefab-super-key-registry-key/checked : prefab-key? -> symbol?
     ;;   Build the internal registry key for an explicit prefab super chain.
     (func $simple-prefab-super-key-registry-key/checked
           (param $key (ref eq))
           (result     (ref $Symbol))

           (local $parent-key (ref eq))

           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $parent-key
                      (call $list-tail/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 4)))
           (call $string->symbol/checked
                 (call $string-append/2
                       (call $string-append/2
                             (call $symbol->immutable-string
                                   (call $simple-prefab-registry-key
                                         (call $simple-prefab-key-name/checked
                                               (local.get $key))
                                         (call $simple-prefab-key-init-count-or-minus-one/checked
                                               (local.get $key))
                                         (call $simple-prefab-key-auto-count/checked
                                               (local.get $key))
                                         (call $simple-prefab-key-auto-value/checked
                                               (local.get $key))
                                         (call $simple-prefab-key-mutables/checked
                                               (local.get $key))))
                             (global.get $string:colon))
                       (call $symbol->immutable-string
                             (if (result (ref $Symbol))
                                 (call $simple-prefab-key-has-super?/i32
                                       (local.get $parent-key))
                                 (then
                                  (call $simple-prefab-super-key-registry-key/checked
                                        (local.get $parent-key)))
                                 (else
                                  (call $simple-prefab-registry-key
                                        (call $simple-prefab-key-name/checked
                                              (local.get $parent-key))
                                        (call $simple-prefab-key-init-count-or-minus-one/checked
                                              (local.get $parent-key))
                                        (call $simple-prefab-key-auto-count/checked
                                              (local.get $parent-key))
                                        (call $simple-prefab-key-auto-value/checked
                                              (local.get $parent-key))
                                        (call $simple-prefab-key-mutables/checked
                                              (local.get $parent-key)))))))))

     ;; simple-prefab-empty-mutable-mask : -> vector?
     ;;   Build the empty mutable mask used by simple no-mutable aliases.
     (func $simple-prefab-empty-mutable-mask
           (result (ref $Vector))

           (struct.new $Vector
                       (i32.const 0)
                       (i32.const 0)
                       (array.new $Array (global.get $false) (i32.const 0))))

     ;; simple-prefab-zero-auto-spec : -> list?
     ;;   Build the `(0 #f)` auto spec used by simple no-auto aliases.
     (func $simple-prefab-zero-auto-spec
           (result (ref eq))

           (call $cons
                 (ref.i31 (i32.const 0))
                 (call $cons (global.get $false) (global.get $null))))

     ;; simple-prefab-chain-alias-parent-total/checked : prefab-key? i32 -> i32
     ;;   Sum init counts in a simple no-auto/no-mutable alias parent chain.
     (func $simple-prefab-chain-alias-parent-total/checked
           (param $key   (ref eq))
           (param $index i32)
           (result       i32)

           (local $len   i32)
           (local $i     i32)
           (local $count (ref eq))
           (local $total i32)

           (local.set $len (call $length/i32 (local.get $key)))
           (local.set $i (local.get $index))
           (local.set $total (i32.const 0))
           (block $done
                  (loop $walk
                        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                        (if (i32.eqz
                             (ref.test
                              (ref $Symbol)
                              (call $list-ref/checked
                                    (ref.cast (ref $Pair) (local.get $key))
                                    (local.get $i))))
                            (then (call $raise-argument-error/internal (local.get $key))
                                  (unreachable)))
                        (local.set $count
                                   (call $list-ref/checked
                                         (ref.cast (ref $Pair) (local.get $key))
                                         (i32.add (local.get $i) (i32.const 1))))
                        (if (ref.eq
                             (call $exact-nonnegative-integer? (local.get $count))
                             (global.get $false))
                            (then (call $raise-argument-error/internal (local.get $key))
                                  (unreachable)))
                        (local.set $total
                                   (i32.add
                                    (local.get $total)
                                    (i32.shr_s
                                     (i31.get_s (ref.cast (ref i31) (local.get $count)))
                                     (i32.const 1))))
                        (local.set $i (i32.add (local.get $i) (i32.const 2)))
                        (br $walk)))
           (local.get $total))

     ;; simple-prefab-chain-alias->explicit-key/checked : prefab-key? i32 -> prefab-key?
     ;;   Convert a simple alias segment chain into an explicit public key.
     (func $simple-prefab-chain-alias->explicit-key/checked
           (param $key   (ref eq))
           (param $index i32)
           (result       (ref eq))

           (local $len        i32)
           (local $name       (ref $Symbol))
           (local $init-count i32)
           (local $tail       (ref eq))

           (local.set $len (call $length/i32 (local.get $key)))
           (if (i32.ge_u (local.get $index) (local.get $len))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (local.set $name
                      (ref.cast
                       (ref $Symbol)
                       (call $list-ref/checked
                             (ref.cast (ref $Pair) (local.get $key))
                             (local.get $index))))
           (local.set $init-count
                      (i32.shr_s
                       (i31.get_s
                        (ref.cast
                         (ref i31)
                         (call $list-ref/checked
                               (ref.cast (ref $Pair) (local.get $key))
                               (i32.add (local.get $index) (i32.const 1)))))
                       (i32.const 1)))
           (local.set $tail
                      (if (result (ref eq))
                          (i32.lt_u
                           (i32.add (local.get $index) (i32.const 2))
                           (local.get $len))
                          (then
                           (call $simple-prefab-chain-alias->explicit-key/checked
                                 (local.get $key)
                                 (i32.add (local.get $index) (i32.const 2))))
                          (else (global.get $null))))
           (call $cons
                 (local.get $name)
                 (call $cons
                       (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))
                       (call $cons
                             (call $simple-prefab-zero-auto-spec)
                             (call $cons
                                   (call $simple-prefab-empty-mutable-mask)
                                   (local.get $tail))))))

     ;; simple-prefab-chain-alias-top->explicit-key/checked : prefab-key? i32 i32 -> prefab-key?
     ;;   Convert a full simple alias key with an inferred or explicit top count.
     (func $simple-prefab-chain-alias-top->explicit-key/checked
           (param $key            (ref eq))
           (param $top-init-count i32)
           (param $parent-index   i32)
           (result                (ref eq))

           (call $cons
                 (call $simple-prefab-key-name/checked (local.get $key))
                 (call $cons
                       (ref.i31 (i32.shl (local.get $top-init-count) (i32.const 1)))
                       (call $cons
                             (call $simple-prefab-zero-auto-spec)
                             (call $cons
                                   (call $simple-prefab-empty-mutable-mask)
                                   (call $simple-prefab-chain-alias->explicit-key/checked
                                         (local.get $key)
                                         (local.get $parent-index)))))))

     ;; simple-prefab-mutable-mask-member?/i32 : vector? i32 -> i32
     ;;   Check whether index appears in the supported mutable-field mask.
     (func $simple-prefab-mutable-mask-member?/i32
           (param $mutables (ref $Vector))
           (param $index    i32)
           (result          i32)

           (local $i    i32)
           (local $mlen i32)
           (local $midx i32)

           (local.set $mlen (call $vector-length/checked/i32 (local.get $mutables)))
           (local.set $i (i32.const 0))
           (block $done
                  (loop $walk
                        (br_if $done (i32.ge_u (local.get $i) (local.get $mlen)))
                        (local.set $midx
                                   (i32.shr_s
                                    (i31.get_s
                                     (ref.cast
                                      (ref i31)
                                      (array.get $Array
                                                 (struct.get $Vector $arr (local.get $mutables))
                                                 (local.get $i))))
                                    (i32.const 1)))
                        (if (i32.eq (local.get $midx) (local.get $index))
                            (then (return (i32.const 1))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $walk)))
           (i32.const 0))
     )))


;; struct-prefab-struct-type-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab struct-type interning helpers used by the monolithic runtime.
(define struct-prefab-struct-type-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-struct-type-runtime-only-helpers
   '(
     ;; simple-prefab-struct-type/checked : symbol? i32 i32 any/c vector? -> struct-type?
     ;;   Intern or retrieve the supported prefab struct type.
     (func $simple-prefab-struct-type/checked
           (param $name       (ref $Symbol))
           (param $init-count i32)
           (param $auto-count i32)
           (param $auto-value (ref eq))
           (param $mutables   (ref $Vector))
           (result            (ref $StructType))

           (local $registry-key (ref null $Symbol))
           (local $existing     (ref eq))
           (local $metadata     (ref eq))
           (local $std          (ref $StructType))

           (local.set $existing (global.get $false))
           (local.set $metadata (global.get $false))
           (local.set $registry-key
                      (call $simple-prefab-registry-key
                            (local.get $name)
                            (local.get $init-count)
                            (local.get $auto-count)
                            (local.get $auto-value)
                            (local.get $mutables)))
           (local.set $existing
                      (call $hasheq-ref/plain
                            (ref.as_non_null (global.get $prefab-struct-type-registry))
                            (ref.as_non_null (local.get $registry-key))
                            (global.get $false)))
           (if (ref.test (ref $StructType) (local.get $existing))
               (then (return (ref.cast (ref $StructType) (local.get $existing)))))
           (local.set $metadata
                      (call $simple-prefab-type-metadata
                            (local.get $name)
                            (local.get $init-count)
                            (local.get $auto-count)
                            (local.get $auto-value)
                            (local.get $mutables)))
           (local.set $std
                      (call $make-struct-type-descriptor/checked
                            (local.get $name)
                            (global.get $false)
                            (local.get $init-count)
                            (local.get $auto-count)
                            (local.get $auto-value)
                            (ref.cast (ref eq) (call $struct-type-property-table-empty))
                            (ref.cast (ref $Symbol) (global.get $symbol:prefab))
                            (global.get $false)
                            (local.get $metadata)
                            (global.get $false)
                            (global.get $false)))
           (call $hasheq-set!/mutable/checked
                 (ref.as_non_null (global.get $prefab-struct-type-registry))
                 (ref.as_non_null (local.get $registry-key))
                 (local.get $std))
           (local.get $std))

     ;; simple-prefab-super-struct-type/checked :
     ;;   symbol? i32 i32 any/c vector? symbol? i32 i32 any/c vector? -> struct-type?
     ;;   Intern or retrieve the supported one-level prefab subtype shape.
     (func $simple-prefab-super-struct-type/checked
           (param $name              (ref $Symbol))
           (param $init-count        i32)
           (param $auto-count        i32)
           (param $auto-value        (ref eq))
           (param $mutables          (ref $Vector))
           (param $parent-name       (ref $Symbol))
           (param $parent-init-count i32)
           (param $parent-auto-count i32)
           (param $parent-auto-value (ref eq))
           (param $parent-mutables   (ref $Vector))
           (result                   (ref $StructType))

           (local $parent-std          (ref $StructType))
           (local $parent-registry-key (ref $Symbol))
           (local $registry-key        (ref null $Symbol))
           (local $existing            (ref eq))
           (local $public-key          (ref eq))
           (local $metadata            (ref eq))
           (local $std                 (ref $StructType))

           (local.set $existing (global.get $false))
           (local.set $metadata (global.get $false))
           (local.set $parent-std
                      (call $simple-prefab-struct-type/checked
                            (local.get $parent-name)
                            (local.get $parent-init-count)
                            (local.get $parent-auto-count)
                            (local.get $parent-auto-value)
                            (local.get $parent-mutables)))
           (local.set $parent-registry-key
                      (call $simple-prefab-registry-key
                            (local.get $parent-name)
                            (local.get $parent-init-count)
                            (local.get $parent-auto-count)
                            (local.get $parent-auto-value)
                            (local.get $parent-mutables)))
           (local.set $registry-key
                      (call $string->symbol/checked
                            (call $string-append/2
                                  (call $string-append/2
                                        (call $symbol->immutable-string
                                              (call $simple-prefab-registry-key
                                                    (local.get $name)
                                                    (local.get $init-count)
                                                    (local.get $auto-count)
                                                    (local.get $auto-value)
                                                    (local.get $mutables)))
                                        (global.get $string:colon))
                                  (call $symbol->immutable-string
                                        (local.get $parent-registry-key)))))
           (local.set $existing
                      (call $hasheq-ref/plain
                            (ref.as_non_null (global.get $prefab-struct-type-registry))
                            (ref.as_non_null (local.get $registry-key))
                            (global.get $false)))
           (if (ref.test (ref $StructType) (local.get $existing))
               (then (return (ref.cast (ref $StructType) (local.get $existing)))))
           (local.set $public-key
                      (call $cons
                            (local.get $name)
                            (call $cons
                                  (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))
                                  (call $cons
                                        (call $cons
                                              (ref.i31 (i32.shl (local.get $auto-count) (i32.const 1)))
                                              (call $cons (local.get $auto-value) (global.get $null)))
                                        (call $cons
                                              (local.get $mutables)
                                              (call $cons
                                                    (local.get $parent-name)
                                                    (call $cons
                                                          (ref.i31
                                                           (i32.shl
                                                            (local.get $parent-init-count)
                                                            (i32.const 1)))
                                                          (call $cons
                                                                (call $cons
                                                                      (ref.i31
                                                                       (i32.shl
                                                                        (local.get $parent-auto-count)
                                                                        (i32.const 1)))
                                                                      (call $cons
                                                                            (local.get $parent-auto-value)
                                                                            (global.get $null)))
                                                                (call $cons
                                                                      (local.get $parent-mutables)
                                                                      (global.get $null))))))))))
           (local.set $metadata
                      (call $cons
                            (local.get $public-key)
                            (ref.i31
                             (i32.shl
                              (i32.add
                               (i32.add (local.get $parent-init-count)
                                        (local.get $parent-auto-count))
                               (i32.add (local.get $init-count)
                                        (local.get $auto-count)))
                              (i32.const 1)))))
           (local.set $std
                      (call $make-struct-type-descriptor/checked
                            (local.get $name)
                            (local.get $parent-std)
                            (local.get $init-count)
                            (local.get $auto-count)
                            (local.get $auto-value)
                            (ref.cast (ref eq) (call $struct-type-property-table-empty))
                            (ref.cast (ref $Symbol) (global.get $symbol:prefab))
                            (global.get $false)
                            (local.get $metadata)
                            (global.get $false)
                            (global.get $false)))
           (call $hasheq-set!/mutable/checked
                 (ref.as_non_null (global.get $prefab-struct-type-registry))
                 (ref.as_non_null (local.get $registry-key))
                 (local.get $std))
           (local.get $std))

     ;; simple-prefab-substruct-type/checked :
     ;;   symbol? i32 i32 any/c vector? struct-type? symbol? -> struct-type?
     ;;   Intern or retrieve a prefab subtype over an already-interned parent.
     (func $simple-prefab-substruct-type/checked
           (param $name                (ref $Symbol))
           (param $init-count          i32)
           (param $auto-count          i32)
           (param $auto-value          (ref eq))
           (param $mutables            (ref $Vector))
           (param $parent-std          (ref $StructType))
           (param $parent-registry-key (ref $Symbol))
           (result                     (ref $StructType))

           (local $registry-key      (ref null $Symbol))
           (local $existing          (ref eq))
           (local $parent-metadata   (ref $Pair))
           (local $parent-public-key (ref eq))
           (local $parent-total      i32)
           (local $public-key        (ref eq))
           (local $metadata          (ref eq))
           (local $std               (ref $StructType))

           (local.set $existing (global.get $false))
           (local.set $metadata (global.get $false))
           (local.set $parent-metadata
                      (ref.cast
                       (ref $Pair)
                       (struct.get $StructType $immutables (local.get $parent-std))))
           (local.set $parent-public-key
                      (struct.get $Pair $a (local.get $parent-metadata)))
           (local.set $parent-total
                      (i32.shr_s
                       (i31.get_s
                        (ref.cast (ref i31)
                                  (struct.get $Pair $d (local.get $parent-metadata))))
                       (i32.const 1)))
           (local.set $registry-key
                      (call $string->symbol/checked
                            (call $string-append/2
                                  (call $string-append/2
                                        (call $symbol->immutable-string
                                              (call $simple-prefab-registry-key
                                                    (local.get $name)
                                                    (local.get $init-count)
                                                    (local.get $auto-count)
                                                    (local.get $auto-value)
                                                    (local.get $mutables)))
                                        (global.get $string:colon))
                                  (call $symbol->immutable-string
                                        (local.get $parent-registry-key)))))
           (local.set $existing
                      (call $hasheq-ref/plain
                            (ref.as_non_null (global.get $prefab-struct-type-registry))
                            (ref.as_non_null (local.get $registry-key))
                            (global.get $false)))
           (if (ref.test (ref $StructType) (local.get $existing))
               (then (return (ref.cast (ref $StructType) (local.get $existing)))))
           (local.set $public-key
                      (call $cons
                            (local.get $name)
                            (call $cons
                                  (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))
                                  (call $cons
                                        (call $cons
                                              (ref.i31 (i32.shl (local.get $auto-count) (i32.const 1)))
                                              (call $cons (local.get $auto-value) (global.get $null)))
                                        (call $cons
                                              (local.get $mutables)
                                              (local.get $parent-public-key))))))
           (local.set $metadata
                      (call $cons
                            (local.get $public-key)
                            (ref.i31
                             (i32.shl
                              (i32.add
                               (local.get $parent-total)
                               (i32.add (local.get $init-count)
                                        (local.get $auto-count)))
                              (i32.const 1)))))
           (local.set $std
                      (call $make-struct-type-descriptor/checked
                            (local.get $name)
                            (local.get $parent-std)
                            (local.get $init-count)
                            (local.get $auto-count)
                            (local.get $auto-value)
                            (ref.cast (ref eq) (call $struct-type-property-table-empty))
                            (ref.cast (ref $Symbol) (global.get $symbol:prefab))
                            (global.get $false)
                            (local.get $metadata)
                            (global.get $false)
                            (global.get $false)))
           (call $hasheq-set!/mutable/checked
                 (ref.as_non_null (global.get $prefab-struct-type-registry))
                 (ref.as_non_null (local.get $registry-key))
                 (local.get $std))
           (local.get $std))

     ;; simple-prefab-struct-type-for-key/checked : prefab-key? -> struct-type?
     ;;   Intern or retrieve a prefab type from an explicit prefab key chain.
     (func $simple-prefab-struct-type-for-key/checked
           (param $key (ref eq))
           (result     (ref $StructType))

           (local $parent-key          (ref eq))
           (local $parent-std          (ref $StructType))
           (local $parent-registry-key (ref $Symbol))

           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (if (i32.eqz (call $simple-prefab-key-has-super?/i32 (local.get $key)))
               (then
                (return
                 (call $simple-prefab-struct-type/checked
                       (call $simple-prefab-key-name/checked (local.get $key))
                       (call $simple-prefab-key-init-count-or-minus-one/checked
                             (local.get $key))
                       (call $simple-prefab-key-auto-count/checked
                             (local.get $key))
                       (call $simple-prefab-key-auto-value/checked
                             (local.get $key))
                       (call $simple-prefab-key-mutables/checked
                             (local.get $key))))))
           (local.set $parent-key
                      (call $list-tail/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 4)))
           (if (i32.eqz (call $simple-prefab-key-has-super?/i32
                              (local.get $parent-key)))
               (then
                (return
                 (call $simple-prefab-super-struct-type/checked
                       (call $simple-prefab-key-name/checked (local.get $key))
                       (call $simple-prefab-key-init-count-or-minus-one/checked
                             (local.get $key))
                       (call $simple-prefab-key-auto-count/checked
                             (local.get $key))
                       (call $simple-prefab-key-auto-value/checked
                             (local.get $key))
                       (call $simple-prefab-key-mutables/checked
                             (local.get $key))
                       (call $simple-prefab-key-name/checked
                             (local.get $parent-key))
                       (call $simple-prefab-key-init-count-or-minus-one/checked
                             (local.get $parent-key))
                       (call $simple-prefab-key-auto-count/checked
                             (local.get $parent-key))
                       (call $simple-prefab-key-auto-value/checked
                             (local.get $parent-key))
                       (call $simple-prefab-key-mutables/checked
                             (local.get $parent-key))))))
           (local.set $parent-std
                      (call $simple-prefab-struct-type-for-key/checked
                            (local.get $parent-key)))
           (local.set $parent-registry-key
                      (if (result (ref $Symbol))
                          (call $simple-prefab-key-has-super?/i32
                                (local.get $parent-key))
                          (then
                           (call $simple-prefab-super-key-registry-key/checked
                                 (local.get $parent-key)))
                          (else
                           (call $simple-prefab-registry-key
                                 (call $simple-prefab-key-name/checked
                                       (local.get $parent-key))
                                 (call $simple-prefab-key-init-count-or-minus-one/checked
                                       (local.get $parent-key))
                                 (call $simple-prefab-key-auto-count/checked
                                       (local.get $parent-key))
                                 (call $simple-prefab-key-auto-value/checked
                                       (local.get $parent-key))
                                 (call $simple-prefab-key-mutables/checked
                                       (local.get $parent-key))))))
           (call $simple-prefab-substruct-type/checked
                 (call $simple-prefab-key-name/checked (local.get $key))
                 (call $simple-prefab-key-init-count-or-minus-one/checked
                       (local.get $key))
                 (call $simple-prefab-key-auto-count/checked
                       (local.get $key))
                 (call $simple-prefab-key-auto-value/checked
                       (local.get $key))
                 (call $simple-prefab-key-mutables/checked
                       (local.get $key))
                 (local.get $parent-std)
                 (local.get $parent-registry-key)))
     )))


;; struct-prefab-metadata-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab metadata helpers used by the monolithic runtime.
(define struct-prefab-metadata-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-metadata-runtime-only-helpers
   '(
     ;; prefab-metadata? : any/c -> i32
     ;;   Detect the simple prefab metadata stored in StructType's immutables slot.
     (func $prefab-metadata?/i32
           (param $metadata (ref eq))
           (result          i32)

           (local $cell (ref $Pair))
           (local $key  (ref eq))
           (local $cnt  (ref eq))

           (if (i32.eqz (ref.test (ref $Pair) (local.get $metadata)))
               (then (return (i32.const 0))))
           (local.set $cell (ref.cast (ref $Pair) (local.get $metadata)))
           (local.set $key  (struct.get $Pair $a (local.get $cell)))
           (local.set $cnt  (struct.get $Pair $d (local.get $cell)))
           (if (i32.and
                (call $simple-prefab-key?/i32 (local.get $key))
                (ref.eq (call $exact-nonnegative-integer? (local.get $cnt)) (global.get $true)))
               (then (return (i32.const 1))))
           (i32.const 0))

     ;; prefab-struct-type-key+field-count : struct-type? -> (or/c pair? #f)
     ;;   Return stored simple prefab metadata for prefab struct types.
     (func $prefab-struct-type-key+field-count (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $std      (ref $StructType))
           (local $metadata (ref eq))

           (if (i32.eqz (ref.test (ref $StructType) (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:prefab-struct-type-key+field-count)
                           (global.get $string:struct-type?)
                           (local.get $v))
                     (unreachable)))
           (local.set $std (ref.cast (ref $StructType) (local.get $v)))
           (local.set $metadata (struct.get $StructType $immutables (local.get $std)))
           (if (result (ref eq))
               (call $prefab-metadata?/i32 (local.get $metadata))
               (then (local.get $metadata))
               (else (global.get $false))))

     ;; prefab-struct-key : any/c -> (or/c prefab-key? #f)
     ;;   Return the shortest supported simple prefab key for prefab instances.
     (func $prefab-struct-key (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $struct   (ref $Struct))
           (local $metadata (ref eq))

           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (return (global.get $false))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
           (local.set $metadata
                      (struct.get $StructType $immutables
                                  (struct.get $Struct $type (local.get $struct))))
           (if (result (ref eq))
               (call $prefab-metadata?/i32 (local.get $metadata))
               (then (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $metadata))))
               (else (global.get $false))))

     ;; prefab-struct-field-mutable?/i32 : struct-type? i32 -> i32
     ;;   For prefab metadata, allow mutation only for fields in the mask.
     ;;   For ordinary struct immutability lists, reject listed fields.
     (func $prefab-struct-field-mutable?/i32
           (param $std   (ref $StructType))
           (param $index i32)
           (result       i32)

           (local $metadata      (ref eq))
           (local $key           (ref eq))
           (local $mutables      (ref $Vector))
           (local $super         (ref eq))
           (local $relative-index i32)
           (local $cursor        (ref eq))
           (local $cell          (ref $Pair))
           (local $raw           (ref eq))

           (local.set $metadata (struct.get $StructType $immutables (local.get $std)))
           (if (call $prefab-metadata?/i32 (local.get $metadata))
               (then
                (local.set $key (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $metadata))))
                (local.set $mutables (call $simple-prefab-key-mutables/checked (local.get $key)))
                (return
                 (call $simple-prefab-mutable-mask-member?/i32
                       (local.get $mutables)
                       (local.get $index)))))

           (if (i32.or (ref.eq (local.get $metadata) (global.get $false))
                       (ref.eq (local.get $metadata) (global.get $null)))
               (then (return (i32.const 1))))

           (local.set $relative-index (local.get $index))
           (local.set $super (struct.get $StructType $super (local.get $std)))
           (if (i32.eqz (ref.eq (local.get $super) (global.get $false)))
               (then
                (local.set $relative-index
                           (i32.sub
                            (local.get $index)
                            (struct.get $StructType $field-count
                                        (ref.cast (ref $StructType)
                                                  (local.get $super)))))))

           (local.set $cursor (local.get $metadata))
           (block $done
                  (loop $walk
                        (br_if $done (ref.eq (local.get $cursor) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                            (then (return (i32.const 1))))
                        (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                        (local.set $raw (struct.get $Pair $a (local.get $cell)))
                        (if (ref.eq (call $exact-nonnegative-integer? (local.get $raw))
                                    (global.get $true))
                            (then
                             (if (i32.eq
                                  (i32.shr_u
                                   (i31.get_u (ref.cast (ref i31) (local.get $raw)))
                                   (i32.const 1))
                                  (local.get $relative-index))
                                 (then (return (i32.const 0))))))
                        (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                        (br $walk)))
           (i32.const 1))
     )))


;; struct-prefab-immutables-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab immutability mask helpers used by the monolithic runtime.
(define struct-prefab-immutables-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-immutables-runtime-only-helpers
   '(
     ;; simple-prefab-immutables->mutables : any/c i32 -> vector?
     ;;   Convert make-struct-type immutables into a prefab mutable-field mask.
     (func $simple-prefab-immutables->mutables
           (param $immutables  (ref eq))
           (param $field-count i32)
           (result             (ref $Vector))

           (local $cursor       (ref eq))
           (local $cell         (ref $Pair))
           (local $raw          (ref eq))
           (local $immutable-i  i32)
           (local $i            i32)
           (local $immutable?   i32)
           (local $mutable-seen i32)
           (local $arr          (ref $Array))

           (if (i32.or (ref.eq (local.get $immutables) (global.get $false))
                       (ref.eq (local.get $immutables) (global.get $missing)))
               (then (return
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))))
           (if (ref.eq (local.get $immutables) (global.get $null))
               (then
                (local.set $arr (array.new $Array (global.get $false) (local.get $field-count)))
                (local.set $i (i32.const 0))
                (block $done-all
                       (loop $fill-all
                             (br_if $done-all (i32.ge_u (local.get $i) (local.get $field-count)))
                             (array.set $Array
                                        (local.get $arr)
                                        (local.get $i)
                                        (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $fill-all)))
                (return
                 (struct.new $Vector
                             (i32.const 0)
                             (i32.const 0)
                             (local.get $arr)))))

           (local.set $mutable-seen (i32.const 0))
           (local.set $i            (i32.const 0))
           (block $done-fields
                  (loop $field
                        (br_if $done-fields (i32.ge_u (local.get $i) (local.get $field-count)))
                        (local.set $immutable? (i32.const 0))
                        (local.set $cursor (local.get $immutables))
                        (block $done-list
                               (loop $walk
                                     (br_if $done-list (ref.eq (local.get $cursor) (global.get $null)))
                                     (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                                         (then (call $raise-argument-error/internal (local.get $immutables))
                                               (unreachable)))
                                     (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                                     (local.set $raw (struct.get $Pair $a (local.get $cell)))
                                     (if (ref.eq (call $exact-nonnegative-integer? (local.get $raw))
                                                 (global.get $false))
                                         (then (call $raise-argument-error/internal (local.get $raw))
                                               (unreachable)))
                                     (local.set $immutable-i
                                                (i32.shr_s
                                                 (i31.get_s (ref.cast (ref i31) (local.get $raw)))
                                                 (i32.const 1)))
                                     (if (i32.ge_u (local.get $immutable-i) (local.get $field-count))
                                         (then (call $raise-argument-error/internal (local.get $raw))
                                               (unreachable)))
                                     (if (i32.eq (local.get $immutable-i) (local.get $i))
                                         (then (local.set $immutable? (i32.const 1))))
                                     (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                                     (br $walk)))
                        (if (i32.eqz (local.get $immutable?))
                            (then
                             (local.set $mutable-seen
                                        (i32.add (local.get $mutable-seen) (i32.const 1)))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $field)))
           (local.set $arr (array.new $Array (global.get $false) (local.get $mutable-seen)))
           (local.set $mutable-seen (i32.const 0))
           (local.set $i            (i32.const 0))
           (block $done-fill
                  (loop $fill
                        (br_if $done-fill (i32.ge_u (local.get $i) (local.get $field-count)))
                        (local.set $immutable? (i32.const 0))
                        (local.set $cursor (local.get $immutables))
                        (block $done-list-fill
                               (loop $walk-fill
                                     (br_if $done-list-fill (ref.eq (local.get $cursor) (global.get $null)))
                                     (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                                     (local.set $raw (struct.get $Pair $a (local.get $cell)))
                                     (local.set $immutable-i
                                                (i32.shr_s
                                                 (i31.get_s (ref.cast (ref i31) (local.get $raw)))
                                                 (i32.const 1)))
                                     (if (i32.eq (local.get $immutable-i) (local.get $i))
                                         (then (local.set $immutable? (i32.const 1))))
                                     (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                                     (br $walk-fill)))
                        (if (i32.eqz (local.get $immutable?))
                            (then
                             (array.set $Array
                                        (local.get $arr)
                                        (local.get $mutable-seen)
                                        (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                             (local.set $mutable-seen
                                        (i32.add (local.get $mutable-seen) (i32.const 1)))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill)))
           (struct.new $Vector
                       (i32.const 0)
                       (i32.const 0)
                       (local.get $arr)))
     )))


;; struct-prefab-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate prefab constructor helpers used by the monolithic runtime.
(define struct-prefab-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-prefab-constructor-runtime-only-helpers
   '(
     ;; make-prefab-struct : prefab-key? any/c ... -> struct?
     ;;   Construct a simple prefab struct through the shared interned type path.
     (func $raise-make-prefab-struct:key
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-prefab-struct)
                 (global.get $string:make-prefab-struct-supported-key)
                 (local.get $bad))
           (unreachable))

     (func $make-prefab-struct (type $Prim>=1)
           (param $key  (ref eq)) ;; supported prefab key
           (param $vals (ref eq)) ;; constructor field values
           (result      (ref eq))

           (local $name           (ref $Symbol))
           (local $parent-name    (ref $Symbol))
           (local $explicit-count i32)
           (local $field-count    i32)
           (local $auto-count     i32)
           (local $auto-value     (ref eq))
           (local $mutables       (ref $Vector))
           (local $len            i32)
           (local $has-super-key  i32)
           (local $has-nested-super-key i32)
           (local $chain-alias?   i32)
           (local $chain-parent-index i32)
           (local $chain-parent-total i32)
           (local $parent-init    i32)
           (local $parent-auto    i32)
           (local $parent-total   i32)
           (local $parent-key     (ref eq))
           (local $parent-metadata (ref null $Pair))
           (local $parent-std     (ref $StructType))
           (local $parent-registry-key (ref $Symbol))
           (local $grandparent-name (ref $Symbol))
           (local $grandparent-init i32)
           (local $grandparent-registry-key (ref $Symbol))
           (local $parent-auto-value (ref eq))
           (local $parent-mutables (ref $Vector))
           (local $total-count    i32)
           (local $std            (ref $StructType))
           (local $init-arr       (ref $Array))
           (local $arr            (ref $Array))
           (local $i              i32)
           (local $src            i32)

           (if (i32.eqz (call $simple-prefab-key?/i32 (local.get $key)))
               (then (call $raise-make-prefab-struct:key (local.get $key))
                     (unreachable)))
           (local.set $field-count    (call $length/i32 (local.get $vals)))
           (local.set $len            (if (result i32)
                                           (ref.test (ref $Symbol) (local.get $key))
                                           (then (i32.const 0))
                                           (else (call $length/i32 (local.get $key)))))
           (local.set $chain-alias? (i32.const 0))
           (local.set $chain-parent-index (i32.const 0))
           (if (i32.gt_u (local.get $len) (i32.const 6))
               (then
                (if (i32.and
                     (i32.eq
                      (i32.rem_u (local.get $len) (i32.const 2))
                      (i32.const 1))
                     (ref.test
                      (ref $Symbol)
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 1))))
                    (then
                     (local.set $chain-alias? (i32.const 1))
                     (local.set $chain-parent-index (i32.const 1))
                     (local.set $chain-parent-total
                                (call $simple-prefab-chain-alias-parent-total/checked
                                      (local.get $key)
                                      (local.get $chain-parent-index)))
                     (if (i32.gt_u (local.get $chain-parent-total)
                                   (local.get $field-count))
                         (then (call $raise-make-prefab-struct:key (local.get $key))
                               (unreachable)))
                     (local.set $key
                                (call $simple-prefab-chain-alias-top->explicit-key/checked
                                      (local.get $key)
                                      (i32.sub (local.get $field-count)
                                               (local.get $chain-parent-total))
                                      (local.get $chain-parent-index)))
                     (local.set $len (call $length/i32 (local.get $key)))))))
           (if (i32.and
                (i32.eqz (local.get $chain-alias?))
                (i32.gt_u (local.get $len) (i32.const 6)))
               (then
                (if (i32.and
                     (i32.eqz (i32.rem_u (local.get $len) (i32.const 2)))
                     (ref.test
                      (ref $Symbol)
                      (call $list-ref/checked
                            (ref.cast (ref $Pair) (local.get $key))
                            (i32.const 2))))
                    (then
                     (local.set $chain-alias? (i32.const 1))
                     (local.set $chain-parent-index (i32.const 2))
                     (local.set $key
                                (call $simple-prefab-chain-alias-top->explicit-key/checked
                                      (local.get $key)
                                      (i32.shr_s
                                       (i31.get_s
                                        (ref.cast
                                         (ref i31)
                                         (call $list-ref/checked
                                               (ref.cast (ref $Pair) (local.get $key))
                                               (i32.const 1))))
                                       (i32.const 1))
                                      (local.get $chain-parent-index)))
                     (local.set $len (call $length/i32 (local.get $key)))))))
           (local.set $name           (call $simple-prefab-key-name/checked (local.get $key)))
           (local.set $parent-std
                      (call $simple-prefab-struct-type/checked
                            (local.get $name)
                            (i32.const 0)
                            (i32.const 0)
                            (global.get $false)
                            (struct.new $Vector
                                        (i32.const 0)
                                        (i32.const 0)
                                        (array.new $Array (global.get $false) (i32.const 0)))))
           (local.set $parent-registry-key (local.get $name))
           (local.set $grandparent-name (local.get $name))
           (local.set $grandparent-registry-key (local.get $name))
           (local.set $explicit-count
                      (call $simple-prefab-key-init-count-or-minus-one/checked
                            (local.get $key)))
           (local.set $auto-count
                      (call $simple-prefab-key-auto-count/checked
                            (local.get $key)))
           (local.set $auto-value
                      (call $simple-prefab-key-auto-value/checked
                            (local.get $key)))
           (local.set $mutables
                      (call $simple-prefab-key-mutables/checked
                            (local.get $key)))
           (local.set $parent-name (local.get $name))
           (local.set $parent-key  (local.get $key))
           (local.set $parent-auto-value (global.get $false))
           (local.set $parent-mutables
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))
           (local.set $has-super-key
                      (call $simple-prefab-key-has-super?/i32
                            (local.get $key)))
           (local.set $has-nested-super-key (i32.const 0))
           (if (i32.eq (local.get $len) (i32.const 5))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 1)))
                    (then (local.set $has-nested-super-key (i32.const 1))))))
           (if (i32.eq (local.get $len) (i32.const 6))
               (then
                (if (ref.test
                     (ref $Symbol)
                     (call $list-ref/checked
                           (ref.cast (ref $Pair) (local.get $key))
                           (i32.const 2)))
                    (then (local.set $has-nested-super-key (i32.const 1))))))
           (if (local.get $has-super-key)
               (then
                (if (local.get $has-nested-super-key)
                    (then
                     (if (i32.eq (local.get $len) (i32.const 5))
                         (then
                          (local.set $parent-name
                                     (ref.cast
                                      (ref $Symbol)
                                      (call $list-ref/checked
                                            (ref.cast (ref $Pair) (local.get $key))
                                            (i32.const 1))))
                          (local.set $parent-init
                                     (i32.shr_s
                                      (i31.get_s
                                       (ref.cast
                                        (ref i31)
                                        (call $list-ref/checked
                                              (ref.cast (ref $Pair) (local.get $key))
                                              (i32.const 2))))
                                      (i32.const 1)))
                          (local.set $grandparent-name
                                     (ref.cast
                                      (ref $Symbol)
                                      (call $list-ref/checked
                                            (ref.cast (ref $Pair) (local.get $key))
                                            (i32.const 3))))
                          (local.set $grandparent-init
                                     (i32.shr_s
                                      (i31.get_s
                                       (ref.cast
                                        (ref i31)
                                        (call $list-ref/checked
                                              (ref.cast (ref $Pair) (local.get $key))
                                              (i32.const 4))))
                                      (i32.const 1))))
                         (else
                          (local.set $parent-name
                                     (ref.cast
                                      (ref $Symbol)
                                      (call $list-ref/checked
                                            (ref.cast (ref $Pair) (local.get $key))
                                            (i32.const 2))))
                          (local.set $parent-init
                                     (i32.shr_s
                                      (i31.get_s
                                       (ref.cast
                                        (ref i31)
                                        (call $list-ref/checked
                                              (ref.cast (ref $Pair) (local.get $key))
                                              (i32.const 3))))
                                      (i32.const 1)))
                          (local.set $grandparent-name
                                     (ref.cast
                                      (ref $Symbol)
                                      (call $list-ref/checked
                                            (ref.cast (ref $Pair) (local.get $key))
                                            (i32.const 4))))
                          (local.set $grandparent-init
                                     (i32.shr_s
                                      (i31.get_s
                                       (ref.cast
                                        (ref i31)
                                        (call $list-ref/checked
                                              (ref.cast (ref $Pair) (local.get $key))
                                              (i32.const 5))))
                                      (i32.const 1)))))
                     (local.set $parent-auto (i32.const 0))
                     (local.set $parent-auto-value (global.get $false))
                     (local.set $parent-mutables
                                (struct.new $Vector
                                            (i32.const 0)
                                            (i32.const 0)
                                            (array.new $Array (global.get $false) (i32.const 0)))))
                    (else
                     (local.set $parent-name
                                (call $simple-prefab-key-parent-name/checked
                                      (local.get $key)))
                     (local.set $parent-init
                                (call $simple-prefab-key-parent-init-count/checked
                                      (local.get $key)))
                     (local.set $parent-auto
                                (call $simple-prefab-key-parent-auto-count/checked
                                      (local.get $key)))
                     (local.set $parent-auto-value
                                (call $simple-prefab-key-parent-auto-value/checked
                                      (local.get $key)))
                     (local.set $parent-mutables
                                (call $simple-prefab-key-parent-mutables/checked
                                      (local.get $key))))))
               (else
                (local.set $parent-name (local.get $name))
                (local.set $parent-init (i32.const 0))
                (local.set $parent-auto (i32.const 0))
                (local.set $parent-auto-value (global.get $false))))
           (local.set $parent-total
                      (i32.add (local.get $parent-init) (local.get $parent-auto)))
           (if (local.get $has-nested-super-key)
               (then
                (local.set $parent-total
                           (i32.add (local.get $grandparent-init)
                                    (local.get $parent-init)))))
           (if (i32.and
                (local.get $has-super-key)
                (i32.and
                 (i32.eqz (local.get $has-nested-super-key))
                 (i32.gt_u (local.get $len) (i32.const 8))))
               (then
                (local.set $parent-key
                           (call $list-tail/checked
                                 (ref.cast (ref $Pair) (local.get $key))
                                 (i32.const 4)))
                (local.set $parent-std
                           (call $simple-prefab-struct-type-for-key/checked
                                 (local.get $parent-key)))
                (local.set $parent-registry-key
                           (call $simple-prefab-super-key-registry-key/checked
                                 (local.get $parent-key)))
                (local.set $parent-metadata
                           (ref.cast
                            (ref $Pair)
                            (struct.get $StructType $immutables
                                        (local.get $parent-std))))
                (local.set $parent-total
                           (i32.shr_s
                            (i31.get_s
                             (ref.cast
                              (ref i31)
                              (struct.get $Pair $d
                                          (ref.as_non_null
                                           (local.get $parent-metadata)))))
                            (i32.const 1)))
                (local.set $parent-init (local.get $parent-total))))
           (if (i32.lt_s (local.get $explicit-count) (i32.const 0))
               (then
                (local.set $explicit-count
                           (if (result i32)
                               (local.get $has-super-key)
                               (then
                                (i32.sub (local.get $field-count)
                                         (local.get $parent-total)))
                               (else (local.get $field-count))))))
           (if (i32.lt_s (local.get $explicit-count) (i32.const 0))
               (then (call $raise-make-prefab-struct:key (local.get $key))
                     (unreachable)))
           (if (i32.and
                (i32.ge_s (local.get $explicit-count) (i32.const 0))
                (i32.ne
                 (i32.add (local.get $explicit-count) (local.get $parent-total))
                 (local.get $field-count)))
               (then (call $raise-make-prefab-struct:key (local.get $key))
                     (unreachable)))
           (local.set $total-count
                      (i32.add
                       (local.get $parent-total)
                       (i32.add (local.get $explicit-count) (local.get $auto-count))))
           (local.set $std
                      (if (result (ref $StructType))
                          (local.get $has-super-key)
                          (then
                           (if (result (ref $StructType))
                               (local.get $has-nested-super-key)
                               (then
                                (local.set $grandparent-registry-key
                                           (call $simple-prefab-registry-key
                                                 (local.get $grandparent-name)
                                                 (local.get $grandparent-init)
                                                 (i32.const 0)
                                                 (global.get $false)
                                                 (local.get $parent-mutables)))
                                (local.set $parent-registry-key
                                           (call $string->symbol/checked
                                                 (call $string-append/2
                                                       (call $string-append/2
                                                             (call $symbol->immutable-string
                                                                   (call $simple-prefab-registry-key
                                                                         (local.get $parent-name)
                                                                         (local.get $parent-init)
                                                                         (i32.const 0)
                                                                         (global.get $false)
                                                                         (local.get $parent-mutables)))
                                                             (global.get $string:colon))
                                                       (call $symbol->immutable-string
                                                             (local.get $grandparent-registry-key)))))
                                (local.set $parent-std
                                           (call $simple-prefab-super-struct-type/checked
                                                 (local.get $parent-name)
                                                 (local.get $parent-init)
                                                 (i32.const 0)
                                                 (global.get $false)
                                                 (local.get $parent-mutables)
                                                 (local.get $grandparent-name)
                                                 (local.get $grandparent-init)
                                                 (i32.const 0)
                                                 (global.get $false)
                                                 (local.get $parent-mutables)))
                                (call $simple-prefab-substruct-type/checked
                                      (local.get $name)
                                      (local.get $explicit-count)
                                      (local.get $auto-count)
                                      (local.get $auto-value)
                                      (local.get $mutables)
                                      (local.get $parent-std)
                                      (local.get $parent-registry-key)))
                               (else
                                (if (result (ref $StructType))
                                    (i32.gt_u (local.get $len) (i32.const 8))
                                    (then
                                     (call $simple-prefab-substruct-type/checked
                                           (local.get $name)
                                           (local.get $explicit-count)
                                           (local.get $auto-count)
                                           (local.get $auto-value)
                                           (local.get $mutables)
                                           (local.get $parent-std)
                                           (local.get $parent-registry-key)))
                                    (else
                                     (call $simple-prefab-super-struct-type/checked
                                           (local.get $name)
                                           (local.get $explicit-count)
                                           (local.get $auto-count)
                                           (local.get $auto-value)
                                           (local.get $mutables)
                                           (local.get $parent-name)
                                           (local.get $parent-init)
                                           (local.get $parent-auto)
                                           (local.get $parent-auto-value)
                                           (local.get $parent-mutables)))))))
                          (else
                           (call $simple-prefab-struct-type/checked
                                 (local.get $name)
                                 (local.get $field-count)
                                 (local.get $auto-count)
                                 (local.get $auto-value)
                                 (local.get $mutables)))))
           (if (local.get $has-nested-super-key)
               (then (local.set $parent-init (local.get $parent-total))))
           (local.set $init-arr (call $list->array (local.get $vals)))
           (local.set $arr (array.new $Array (global.get $false) (local.get $total-count)))
           (local.set $i (i32.const 0))
           (block $done-parent-init-copy
                  (loop $copy-parent-init
                        (br_if $done-parent-init-copy (i32.ge_u (local.get $i) (local.get $parent-init)))
                        (array.set $Array (local.get $arr) (local.get $i)
                                   (array.get $Array (local.get $init-arr) (local.get $i)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $copy-parent-init)))
           (block $done-parent-auto-fill
                  (loop $fill-parent-auto
                        (br_if $done-parent-auto-fill (i32.ge_u (local.get $i) (local.get $parent-total)))
                        (array.set $Array
                                   (local.get $arr)
                                   (local.get $i)
                                   (local.get $parent-auto-value))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill-parent-auto)))
           (local.set $src (local.get $parent-init))
           (block $done-child-init-copy
                  (loop $copy-child-init
                        (br_if $done-child-init-copy
                               (i32.ge_u
                                (local.get $src)
                                (i32.add (local.get $parent-init) (local.get $explicit-count))))
                        (array.set $Array
                                   (local.get $arr)
                                   (local.get $i)
                                   (array.get $Array (local.get $init-arr) (local.get $src)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (local.set $src (i32.add (local.get $src) (i32.const 1)))
                        (br $copy-child-init)))
           (block $done-child-auto-fill
                  (loop $fill-child-auto
                        (br_if $done-child-auto-fill (i32.ge_u (local.get $i) (local.get $total-count)))
                        (array.set $Array
                                   (local.get $arr)
                                   (local.get $i)
                                   (local.get $auto-value))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill-child-auto)))
           (struct.new $Struct
                       (i32.const 0)
                       (struct.get $StructType $name (local.get $std))
                       (ref.i31 (i32.const 0))
                       (ref.i31 (i32.const 31))
                       (ref.func $invoke-struct)
                       (local.get $std)
                       (local.get $arr)))
     )))

;; struct-type-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct type construction helpers used by the monolithic runtime.
(define struct-type-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-type-constructor-runtime-only-helpers
   '(
     (func $raise-make-struct-type:name
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:symbol?)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:super
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:struct-type-or-false)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:field-count
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:guard
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:make-struct-type-guard)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:inspector
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:make-struct-type-inspector)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:props
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:make-struct-type-props)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:immutables
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:make-struct-type-immutables)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:constructor-name
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:make-struct-type-constructor-name)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:proc-spec
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type)
                 (global.get $string:make-struct-type-proc-spec)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type:immutable-index
           (param $bad-index  (ref eq))
           (param $init-count i32)
           (param $bad-list   (ref eq))

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 8)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (global.get $symbol:make-struct-type)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:make-struct-type-immutable-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $bad-index)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:make-struct-type-initialized-field-count))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:make-struct-type-in-list))
           (call $growable-array-add! (local.get $out)
                 (call $format/print
                       (local.get $bad-list)
                       (global.get $missing)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $raise-make-struct-type:proc-spec-index
           (param $bad-index  (ref eq))
           (param $init-count i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 6)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (global.get $symbol:make-struct-type)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:make-struct-type-proc-spec-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $bad-index)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:make-struct-type-field-count))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $raise-make-struct-type:non-generative
           (param $detail (ref eq))
           (param $name   (ref eq))

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 4)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (global.get $symbol:make-struct-type)))
           (call $growable-array-add! (local.get $out)
                 (local.get $detail))
           (call $growable-array-add! (local.get $out)
                 (call $format/print
                       (local.get $name)
                       (global.get $missing)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $make-struct-type
           ;; Parameters
           (param $name             (ref eq))  ;; (ref $Symbol)
           (param $super            (ref eq))  ;; (ref $StructType) or #f
           (param $init-count       (ref eq))  ;; fixnum
           (param $auto-count       (ref eq))  ;; fixnum
           ; optional:
           (param $auto-val         (ref eq))  ;; default value for auto fields
           (param $props            (ref eq))  ;; hash table or #f
           (param $inspector        (ref eq))  ;; inspector object or #f
           (param $proc-spec        (ref eq))  ;; procedure, exact nonnegative integer, or #f
           (param $immutables       (ref eq))  ;; immutable mask or #f
           (param $guard            (ref eq))  ;; closure or #f
           (param $constructor-name (ref eq))  ;; symbol or #f

           (result (ref eq))  ;; returns 5-values packed as a pair
           ;                  ;; values: (struct-type, constructor, predicate, accessor, mutator)

           ;; Locals
           (local $init           i32)
           (local $auto           i32)
           (local $super-count    i32)
           (local $field-count    i32)
           (local $std            (ref $StructType))
           (local $ctor           (ref eq))
           (local $pred           (ref eq))
           (local $acc            (ref eq))
           (local $mut            (ref eq))
           (local $super-count-fx (ref eq))
           (local $has-super      i32)
           (local $super-typed    (ref null $StructType))
           (local $props-final    (ref $HashEqMutable))
           (local $props-new      (ref $HashEqMutable))
           (local $props-spec     (ref eq))
           (local $props-list     (ref eq))
           (local $props-cursor   (ref eq))
           (local $props-cell     (ref $Pair))
           (local $entry          (ref $Pair))
           (local $entry-raw      (ref eq))
           (local $prop-desc      (ref $StructTypeProperty))
           (local $prop-raw       (ref eq))
           (local $value          (ref eq))
           (local $sti            (ref eq))
           (local $sentinel       (ref eq))
           (local $new-list       (ref eq))
           (local $struct-name    (ref eq))
           (local $guard-checked  (ref eq))
           (local $prefab?        i32)
           (local $prefab-mutables (ref $Vector))
           (local $prefab-parent-key (ref eq))
           (local $prefab-parent-has-super i32)
           (local $prefab-parent-registry-key (ref null $Symbol))
           (local $prefab-parent-init i32)
           (local $prefab-parent-auto i32)
           (local $prefab-parent-auto-value (ref eq))
           (local $prefab-parent-mutables (ref $Vector))
           (local $prefab-key     (ref null $Symbol))
           (local $prefab-existing (ref eq))
           (local $prefab-metadata (ref eq))
           (local $immutables-list   (ref eq))
           (local $immutables-cursor (ref eq))
           (local $immutables-cell   (ref $Pair))
           (local $immutable-raw     (ref eq))
           (local $immutable-index   i32)
           (local $proc-spec-index   i32)

           ;; --- Type checks ---
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
               (then (call $raise-make-struct-type:name (local.get $name))))

           (if (i32.and
                (i32.eqz (ref.eq (local.get $super) (global.get $false)))
                (i32.eqz (ref.test (ref $StructType) (local.get $super))))
               (then (call $raise-make-struct-type:super (local.get $super))))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $init-count))
                       (global.get $false))
               (then (call $raise-make-struct-type:field-count (local.get $init-count))))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $auto-count))
                       (global.get $false))
               (then (call $raise-make-struct-type:field-count (local.get $auto-count))))

           ;; Initialize non-defaultable prefab locals before branching.
           (local.set $prefab-existing (global.get $false))
           (local.set $prefab-metadata (global.get $false))
           (local.set $prefab-parent-key (global.get $false))
           (local.set $prefab-parent-registry-key (ref.null $Symbol))
           (local.set $prefab-parent-auto-value (global.get $false))
           (local.set $prefab-mutables
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))
           (local.set $prefab-parent-mutables
                      (struct.new $Vector
                                  (i32.const 0)
                                  (i32.const 0)
                                  (array.new $Array (global.get $false) (i32.const 0))))

           ;; --- Decode fixnums ---
           (local.set $init (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $init-count))) (i32.const 1)))
           (local.set $auto (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $auto-count))) (i32.const 1)))

           ;; --- Super field count ---
           (local.set $has-super (i32.eqz (ref.eq (local.get $super) (global.get $false))))
           (if (local.get $has-super)
               (then (local.set $super-typed (ref.cast (ref $StructType) (local.get $super))))
               (else (local.set $super-typed (ref.null $StructType))))

           (local.set $super-count
                      (if (result i32)
                          (local.get $has-super)
                          (then (struct.get $StructType $field-count
                                            (ref.as_non_null (local.get $super-typed))))
                          (else (i32.const 0))))
           (local.set $super-count-fx (ref.i31 (i32.shl (local.get $super-count) (i32.const 1))))

           (local.set $field-count (i32.add (local.get $super-count)
                                            (i32.add (local.get $init) (local.get $auto))))

           ;; Optional auto-v defaults to #f.
           (if (ref.eq (local.get $auto-val) (global.get $missing))
               (then (local.set $auto-val (global.get $false))))

           ;; --- Guard ---
           ;; Optional guard defaults to #f. If present, it must be a procedure.
           (local.set $guard-checked (local.get $guard))
           (if (ref.eq (local.get $guard-checked) (global.get $missing))
               (then (local.set $guard-checked (global.get $false))))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $guard-checked) (global.get $false)))
                (ref.eq (call $procedure? (local.get $guard-checked))
                        (global.get $false)))
               (then (call $raise-make-struct-type:guard (local.get $guard-checked))
                     (unreachable)))

           ;; WebRacket currently represents inspectors as #f. Preserve the
           ;; supported public shorthands while rejecting other values.
           (if (ref.eq (local.get $inspector) (global.get $missing))
               (then (local.set $inspector (global.get $false))))
           (if (i32.eqz (ref.eq (local.get $inspector) (global.get $false)))
               (then
                (if (i32.eqz (ref.test (ref $Symbol) (local.get $inspector)))
                    (then (call $raise-make-struct-type:inspector (local.get $inspector))
                          (unreachable)))
                (if (i32.and
                     (i32.eqz (call $symbol=?/i32
                                    (ref.cast (ref $Symbol) (local.get $inspector))
                                    (ref.cast (ref $Symbol) (global.get $symbol:prefab))))
                     (i32.eqz (call $symbol=?/i32
                                    (ref.cast (ref $Symbol) (local.get $inspector))
                                    (ref.cast (ref $Symbol) (global.get $symbol:current)))))
                    (then (call $raise-make-struct-type:inspector (local.get $inspector))
                          (unreachable)))
                (if (call $symbol=?/i32
                          (ref.cast (ref $Symbol) (local.get $inspector))
                          (ref.cast (ref $Symbol) (global.get $symbol:current)))
                    (then (local.set $inspector (global.get $false))))))

           ;; Optional immutable field indexes default to null. Each index must
           ;; refer to an initialized field.
           (local.set $immutables-list (local.get $immutables))
           (if (ref.eq (local.get $immutables-list) (global.get $missing))
               (then
                (local.set $immutables-list (global.get $null))
                (local.set $immutables (global.get $null))))
           (local.set $immutables-cursor (local.get $immutables-list))
           (block $done-immutables
                  (loop $walk-immutables
                        (br_if $done-immutables
                               (ref.eq (local.get $immutables-cursor) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $immutables-cursor)))
                            (then (call $raise-make-struct-type:immutables
                                        (local.get $immutables-list))
                                  (unreachable)))
                        (local.set $immutables-cell
                                   (ref.cast (ref $Pair) (local.get $immutables-cursor)))
                        (local.set $immutable-raw
                                   (struct.get $Pair $a (local.get $immutables-cell)))
                        (if (ref.eq (call $exact-nonnegative-integer?
                                          (local.get $immutable-raw))
                                    (global.get $false))
                            (then (call $raise-make-struct-type:immutables
                                        (local.get $immutables-list))
                                  (unreachable)))
                        (local.set $immutable-index
                                   (i32.shr_s
                                    (i31.get_s
                                     (ref.cast (ref i31) (local.get $immutable-raw)))
                                    (i32.const 1)))
                        (if (i32.ge_u (local.get $immutable-index) (local.get $init))
                            (then (call $raise-make-struct-type:immutable-index
                                        (local.get $immutable-raw)
                                        (local.get $init)
                                        (local.get $immutables-list))
                                  (unreachable)))
                        (local.set $immutables-cursor
                                   (struct.get $Pair $d (local.get $immutables-cell)))
                        (br $walk-immutables)))

           ;; Optional constructor name defaults to #f.
           (if (ref.eq (local.get $constructor-name) (global.get $missing))
               (then (local.set $constructor-name (global.get $false))))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $constructor-name) (global.get $false)))
                (i32.eqz (ref.test (ref $Symbol) (local.get $constructor-name))))
               (then (call $raise-make-struct-type:constructor-name
                           (local.get $constructor-name))
                     (unreachable)))

           ;; Optional proc-spec defaults to #f. It can be a procedure or an
           ;; initialized-field index.
           (if (ref.eq (local.get $proc-spec) (global.get $missing))
               (then (local.set $proc-spec (global.get $false))))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $proc-spec) (global.get $false)))
                (i32.and
                 (ref.eq (call $procedure? (local.get $proc-spec))
                         (global.get $false))
                 (ref.eq (call $exact-nonnegative-integer? (local.get $proc-spec))
                         (global.get $false))))
               (then (call $raise-make-struct-type:proc-spec
                           (local.get $proc-spec))
                     (unreachable)))
           (if (ref.eq (call $exact-nonnegative-integer? (local.get $proc-spec))
                       (global.get $true))
               (then
                (local.set $proc-spec-index
                           (i32.shr_s
                            (i31.get_s
                             (ref.cast (ref i31) (local.get $proc-spec)))
                            (i32.const 1)))
                (if (i32.ge_u (local.get $proc-spec-index) (local.get $init))
                    (then (call $raise-make-struct-type:proc-spec-index
                                (local.get $proc-spec)
                                (local.get $init))
                          (unreachable)))))

           ;; --- Initialize property tables ---
           (local.set $props-new   (call $struct-type-property-table-empty))
           (local.set $props-final (call $struct-type-property-table-empty))
           (if (local.get $has-super)
               (then
                (local.set $props-final
                           (call $struct-type-property-table-copy
                                 (ref.cast (ref $HashEqMutable)
                                           (struct.get $StructType $properties
                                                       (ref.as_non_null (local.get $super-typed))))))
                (if (i32.eq (call $struct-type-property-table-has-name?/i32
                                    (local.get $props-final)
                                    (ref.cast (ref $Symbol) (global.get $symbol:prop:sealed)))
                             (i32.const 1))
                    (then (call $raise-sealed-struct-supertype)
                          (unreachable)))))

           ;; --- Canonicalize properties specification ---
           (local.set $props-spec (local.get $props))
           (if (ref.eq (local.get $props-spec) (global.get $missing))
               (then (local.set $props-spec (global.get $null))))
           (if (ref.eq (local.get $props-spec) (global.get $false))
               (then (local.set $props-spec (global.get $null))))
           (local.set $props-list (local.get $props-spec))
           (if (ref.test (ref $HashEqMutable) (local.get $props-list))
               (then (local.set $props-list
                                (call $hasheq->list/plain/checked
                                      (ref.cast (ref $HashEqMutable) (local.get $props-list))))))

           ;; Racket specifies that a non-#f `proc-spec` is the same as
           ;; appending `(cons prop:procedure proc-spec)` to the property
           ;; list. Keyword-procedure support relies on this path via
           ;; `make-optional-keyword-procedure`.
           (if (i32.and
                (i32.eqz (ref.eq (local.get $proc-spec) (global.get $false)))
                (i32.eqz (ref.eq (local.get $proc-spec) (global.get $missing))))
               (then
                (local.set $props-list
                           (call $cons
                                 (call $cons
                                       (global.get $prop:procedure)
                                       (local.get $proc-spec))
                                 (local.get $props-list)))))

           ;; --- Simple prefab support ---
           ;; WebRacket interns supported prefab types by name/init/auto shape.
           ;; More complex prefab shapes should fail instead of becoming
           ;; ordinary fresh structure types.
           (local.set $prefab?
                      (if (result i32)
                          (ref.test (ref $Symbol) (local.get $inspector))
                          (then
                           (call $symbol=?/i32
                                 (ref.cast (ref $Symbol) (local.get $inspector))
                                 (ref.cast (ref $Symbol) (global.get $symbol:prefab))))
                          (else (i32.const 0))))
           (if (local.get $prefab?)
               (then
                (local.set $prefab-mutables
                           (call $simple-prefab-immutables->mutables
                                 (local.get $immutables)
                                 (i32.add (local.get $init) (local.get $auto))))
                (if (local.get $has-super)
                    (then
                     (local.set $prefab-metadata
                                (struct.get $StructType $immutables
                                            (ref.as_non_null (local.get $super-typed))))
                     (if (i32.eqz (call $prefab-metadata?/i32 (local.get $prefab-metadata)))
                         (then (call $raise-make-struct-type:non-generative
                                     (global.get $string:make-struct-type:non-generative-supertype)
                                     (local.get $name))
                               (unreachable)))
                     (local.set $prefab-parent-key
                                (struct.get $Pair $a
                                            (ref.cast (ref $Pair) (local.get $prefab-metadata))))
                     (local.set $prefab-parent-has-super
                                (call $simple-prefab-key-has-super?/i32
                                      (local.get $prefab-parent-key)))
                     (if (local.get $prefab-parent-has-super)
                         (then
                          (local.set $prefab-parent-registry-key
                                     (call $simple-prefab-super-key-registry-key/checked
                                           (local.get $prefab-parent-key)))))
                     (local.set $prefab-parent-auto
                                (call $simple-prefab-key-auto-count/checked
                                      (local.get $prefab-parent-key)))
                     (local.set $prefab-parent-auto-value
                                (call $simple-prefab-key-auto-value/checked
                                      (local.get $prefab-parent-key)))
                     (local.set $prefab-parent-mutables
                                (call $simple-prefab-key-mutables/checked
                                      (local.get $prefab-parent-key)))
                     (local.set $prefab-parent-init
                                (call $simple-prefab-key-init-count-or-minus-one/checked
                                      (local.get $prefab-parent-key)))
                     (if (i32.lt_s (local.get $prefab-parent-init) (i32.const 0))
                         (then
                          (local.set $prefab-parent-init
                                     (i32.sub
                                      (i32.shr_s
                                       (i31.get_s
                                        (ref.cast
                                         (ref i31)
                                         (struct.get $Pair $d
                                                     (ref.cast (ref $Pair)
                                                               (local.get $prefab-metadata)))))
                                       (i32.const 1))
                                      (local.get $prefab-parent-auto)))))))
                (if (i32.eqz (call $simple-prefab-auto-value-supported?/i32
                                   (local.get $auto-val)))
                    (then (call $raise-make-struct-type:non-generative
                                (global.get $string:make-struct-type:unsupported-prefab-auto-value)
                                (local.get $name))
                          (unreachable)))
                (if (i32.eqz (ref.eq (local.get $proc-spec) (global.get $false)))
                    (then (call $raise-make-struct-type:non-generative
                                (global.get $string:make-struct-type:non-generative-proc-spec)
                                (local.get $name))
                          (unreachable)))
                (if (i32.eqz (ref.eq (local.get $props-list) (global.get $null)))
                    (then (call $raise-make-struct-type:non-generative
                                (global.get $string:make-struct-type:non-generative-properties)
                                (local.get $name))
                          (unreachable)))
                (if (i32.eqz (ref.eq (local.get $guard-checked) (global.get $false)))
                    (then (call $raise-make-struct-type:non-generative
                                (global.get $string:make-struct-type:non-generative-guard)
                                (local.get $name))
                          (unreachable)))))


           ;; --- Create struct type descriptor ---
           (local.set $std
                      (if (result (ref $StructType))
                          (local.get $prefab?)
                          (then
                           (if (result (ref $StructType))
                               (local.get $has-super)
                               (then
                                (if (result (ref $StructType))
                                    (local.get $prefab-parent-has-super)
                                    (then
                                     (call $simple-prefab-substruct-type/checked
                                           (ref.cast (ref $Symbol) (local.get $name))
                                           (local.get $init)
                                           (local.get $auto)
                                           (local.get $auto-val)
                                           (local.get $prefab-mutables)
                                           (ref.as_non_null (local.get $super-typed))
                                           (ref.as_non_null
                                            (local.get $prefab-parent-registry-key))))
                                    (else
                                     (call $simple-prefab-super-struct-type/checked
                                           (ref.cast (ref $Symbol) (local.get $name))
                                           (local.get $init)
                                           (local.get $auto)
                                           (local.get $auto-val)
                                           (local.get $prefab-mutables)
                                           (call $simple-prefab-key-name/checked
                                                 (local.get $prefab-parent-key))
                                           (local.get $prefab-parent-init)
                                           (local.get $prefab-parent-auto)
                                           (local.get $prefab-parent-auto-value)
                                           (local.get $prefab-parent-mutables)))))
                               (else
                                (call $simple-prefab-struct-type/checked
                                      (ref.cast (ref $Symbol) (local.get $name))
                                      (local.get $init)
                                      (local.get $auto)
                                      (local.get $auto-val)
                                      (local.get $prefab-mutables)))))
                          (else
                           (call $make-struct-type-descriptor/checked
                                 (ref.cast (ref $Symbol) (local.get $name))
                                 (local.get $super)
                                 (local.get $init)
                                 (local.get $auto)
                                 (local.get $auto-val)
                                 (ref.cast (ref eq) (local.get $props-final))
                                 (local.get $inspector)
                                 (local.get $proc-spec)
                                 (local.get $immutables)
                                 (local.get $guard-checked)
                                 (local.get $constructor-name)))))
           (local.set $struct-name (struct.get $StructType $name (local.get $std)))

           ;; --- Prepare struct-type-info for property guards ---
           (local.set $sti
                      (call $struct-type-info-for-guard
                            (local.get $std)
                            (ref.cast (ref $Symbol) (local.get $name))
                            (local.get $init)
                            (local.get $auto)
                            (local.get $super)
                            (local.get $super-count-fx)
                            (local.get $immutables)))

           ;; --- Process property associations ---
           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $props-cursor (local.get $props-list))
           (block $done
                  (loop $walk
                        (br_if $done (ref.eq (local.get $props-cursor) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $props-cursor)))
                            (then (call $raise-make-struct-type:props (local.get $props-spec))
                                  (unreachable)))
                        (local.set $props-cell (ref.cast (ref $Pair) (local.get $props-cursor)))
                        (local.set $entry-raw (struct.get $Pair $a (local.get $props-cell)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $entry-raw)))
                            (then (call $raise-make-struct-type:props (local.get $props-spec))
                                  (unreachable)))
                        (local.set $entry (ref.cast (ref $Pair) (local.get $entry-raw)))
                        (local.set $prop-raw (struct.get $Pair $a (local.get $entry)))
                        (if (i32.eqz (ref.test (ref $StructTypeProperty) (local.get $prop-raw)))
                            (then (call $raise-make-struct-type:props (local.get $props-spec))
                                  (unreachable)))
                        (local.set $prop-desc (ref.cast (ref $StructTypeProperty) (local.get $prop-raw)))
                        (local.set $value (struct.get $Pair $d (local.get $entry)))
                        (drop (call $struct-type-property-attach!
                                    (local.get $prop-desc)
                                    (local.get $value)
                                    (local.get $props-new)
                                    (local.get $sti)
                                    (local.get $sentinel)))
                        (local.set $props-cursor (struct.get $Pair $d (local.get $props-cell)))
                        (br $walk)))

           ;; --- Merge processed properties into final table ---
           (local.set $new-list (call $hasheq->list/plain/checked (local.get $props-new)))
           (drop (call $struct-type-property-merge-list!
                       (local.get $props-final)
                       (local.get $new-list)))

           ;; --- Create constructor ---
           (local.set $ctor (call $make-struct-constructor/checked (local.get $std)))
           (local.set $pred (call $make-struct-predicate/checked   (local.get $std)))
           (local.set $acc  (call $make-struct-accessor/checked
                                  (local.get $std) (local.get $super-count-fx) (local.get $struct-name)))
           (local.set $mut  (call $make-struct-mutator/checked
                                  (local.get $std) (local.get $super-count-fx)))

           ;; --- Return values as a compound value ---
           (array.new_fixed $Values 5
                 (local.get $std)    ; struct type descriptor
                 (local.get $ctor)   ; constructor procedure
                 (local.get $pred)   ; predicate procedure
                 (local.get $acc)    ; accessor  procedure
                 (local.get $mut)))  ; mutator   procedure
     )))

;; struct-accessor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic struct accessor helpers used by the monolithic runtime.
(define struct-accessor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-accessor-runtime-only-helpers
   '(
     (func $make-struct-accessor
           (param $std (ref eq))
           (param $field-index (ref eq))   ;; fixnum
           (param $super-count (ref eq))   ;; fixnum
           (result (ref eq))               ;; $StructAccessorProcedure

           (local $i            i32)
           (local $std-typed    (ref $StructType))
           (local $struct-name  (ref eq))

           ;; Type checks
           (if (i32.eqz (ref.test (ref $StructType) (local.get $std)))
               (then (call $raise-argument-error/internal (local.get $std))))
           (if (i32.eqz (ref.test (ref i31) (local.get $field-index)))
               (then (call $raise-argument-error/internal (local.get $field-index))))
           (if (i32.eqz (ref.test (ref i31) (local.get $super-count)))
               (then (call $raise-argument-error/internal (local.get $super-count))))
           ;; Decode
           (local.set $i (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $field-index))) (i32.const 1)))
           ;; Prepare typed std and accessor name
           (local.set $std-typed   (ref.cast (ref $StructType) (local.get $std)))
           (local.set $struct-name (struct.get $StructType $name (local.get $std-typed)))
           ;; Delegate
           (call $make-struct-accessor/checked
                 (local.get $std-typed)
                 (local.get $super-count)
                 (local.get $struct-name)))

     (func $make-struct-accessor/checked
           (param $std         (ref $StructType))
           (param $super-count (ref eq))
           (param $struct-name (ref eq))
           (result             (ref eq)) ;; StructAccessorProcedure

           (local $free (ref $Free))
           (local $name (ref $Symbol))

           (local.set $name
                      (call $struct-type-accessor-name (local.get $std)))

           ;; Pack just std and super-count; index comes at runtime
           (local.set $free
                      (array.new_fixed $Free 2
                                       (local.get $std)
                                       (local.get $super-count)))

           (struct.new $StructAccessorProcedure
                       (i32.const 0)               ; hash
                       (local.get $name)           ; name:  #f or $Symbol
                       (ref.i31 (i32.const 4))     ; arity: 2
                       (global.get $false)         ; realm: #f or $Symbol
                       (ref.func $invoke-closure) ; invoke (used by apply, map, etc.)
                       (global.get $false)         ; debug-id
                       (ref.func $struct-accessor)
                       (local.get $free)))

     (func $struct-type-accessor-name
           (param $std (ref $StructType))
           (result (ref $Symbol))

           (call $string->symbol/checked
                 (call $string-append/2
                       (call $symbol->immutable-string
                             (struct.get $StructType $name (local.get $std)))
                       (global.get $string:struct-accessor-suffix))))

     (func $struct-type-mutator-name
           (param $std (ref $StructType))
           (result (ref $Symbol))

           (call $string->symbol/checked
                 (call $string-append/2
                       (call $symbol->immutable-string
                             (struct.get $StructType $name (local.get $std)))
                       (global.get $string:struct-mutator-suffix))))

     (func $struct-type-predicate-name-string
           (param $std (ref $StructType))
           (result (ref $String))

           (call $string-append/2
                 (call $symbol->immutable-string
                       (struct.get $StructType $name (local.get $std)))
                 (global.get $string:predicate-suffix)))

     (func $struct-type->display-string
           (param $std (ref $StructType))
           (result (ref $String))

           (call $string-append/2
                 (call $string-append/2
                       (global.get $string:struct-type-prefix)
                       (call $symbol->immutable-string
                             (struct.get $StructType $name (local.get $std))))
                 (global.get $string:struct-type-close)))

     (func $raise-struct-accessor:target
           (param $who    (ref eq))
           (param $std    (ref $StructType))
           (param $target (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (call $struct-type-predicate-name-string (local.get $std))
                 (local.get $target))
           (unreachable))

     (func $raise-struct-accessor:index
           (param $who (ref eq))
           (param $bad (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $bad))
           (unreachable))

     (func $raise-struct-accessor:index-too-large
           (param $who              (ref eq))
           (param $std              (ref $StructType))
           (param $index            i32)
           (param $accessible-count i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 8)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $who)))
           (call $growable-array-add! (local.get $out)
                 (if (result (ref eq))
                     (i32.eqz (local.get $accessible-count))
                     (then (global.get $string:struct-accessor:index-too-large-no-fields))
                     (else (global.get $string:struct-accessor:index-too-large))))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $index) (i32.const 1)))))
           (if (local.get $accessible-count)
               (then
                (call $growable-array-add! (local.get $out)
                      (global.get $string:struct-accessor:maximum-allowed-index))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (ref.i31
                             (i32.shl
                              (i32.sub (local.get $accessible-count) (i32.const 1))
                              (i32.const 1)))))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:struct-accessor:structure-type))
           (call $growable-array-add! (local.get $out)
                 (call $struct-type->display-string (local.get $std)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $struct-accessor
           (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result      (ref eq))

           (local $free           (ref $Free))
           (local $std            (ref $StructType))  ; free[0]
           (local $super-count-fx (ref eq))           ; free[1]
           (local $super-count    i32)
           (local $target         (ref eq))           ; args[0]
           (local $struct         (ref $Struct))
           (local $index-fx       (ref eq))           ; args[1]
           (local $index          i32)
           (local $skip           i32)
           (local $fields         (ref $Array))
           (local $who            (ref eq))
           (local $accessible-count i32)

           ;; Unpack free vars
           (local.set $free            (struct.get $Closure $free (local.get $clos)))
           (local.set $who             (struct.get $Closure $name (local.get $clos)))
           (local.set $std             (ref.cast (ref $StructType)
                                                 (array.get $Free (local.get $free) (i32.const 0))))

           (local.set $super-count-fx  (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $super-count     (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $super-count-fx)))
                                                  (i32.const 1)))
           (local.set $skip            (local.get $super-count))

           ;; Get struct
           (local.set $target (array.get $Args (local.get $args) (i32.const 0)))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $target)))
               (then (call $raise-struct-accessor:target
                           (local.get $who)
                           (local.get $std)
                           (local.get $target))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $target)))

           ;; Get index and decode
           (local.set $index-fx (array.get $Args (local.get $args) (i32.const 1)))
           (if (i32.or (i32.eqz (ref.test (ref i31) (local.get $index-fx)))
                       (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $index-fx))) (i32.const 1)) (i32.const 0)))
               (then (call $raise-struct-accessor:index
                           (local.get $who)
                           (local.get $index-fx))))
           (local.set $index (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $index-fx))) (i32.const 1)))

           ;; Type match - is $struct a subtype of $std
           (if (i32.eqz (call $struct-type-is-a?/i32
                              (struct.get $Struct $type (local.get $struct))
                              (local.get $std)))
               (then (call $raise-struct-accessor:target
                           (local.get $who)
                           (local.get $std)
                           (local.get $target))))

           ;; Get and return field
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (local.set $accessible-count
                      (i32.sub (struct.get $StructType $field-count (local.get $std))
                               (local.get $skip)))
           (if (i32.ge_u (local.get $index) (local.get $accessible-count))
               (then (call $raise-struct-accessor:index-too-large
                           (local.get $who)
                           (local.get $std)
                           (local.get $index)
                           (local.get $accessible-count))))
           (array.get $Array (local.get $fields)
                      (i32.add (local.get $skip) (local.get $index))))
     )))

;; struct-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct constructor implementation helpers used by the monolithic runtime.
(define struct-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-constructor-runtime-only-helpers
   '(
    (func $struct-constructor/no-guard
           (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result      (ref eq))

           (local $free         (ref $Free))
           (local $std          (ref $StructType))
           (local $init-indices (ref eq))
           (local $auto-indices (ref eq))
           (local $auto-values  (ref eq))
           (local $name         (ref eq))
           (local $field-count  i32)
           (local $arr          (ref $Array))

           (local.set $free         (struct.get $Closure $free (local.get $clos)))
           (local.set $std          (ref.cast (ref $StructType) (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $init-indices (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $auto-indices (array.get $Free (local.get $free) (i32.const 2)))
           (local.set $auto-values  (array.get $Free (local.get $free) (i32.const 3)))
           (local.set $name         (array.get $Free (local.get $free) (i32.const 4)))
           (local.set $field-count  (struct.get $StructType $field-count (local.get $std)))

           (local.set $arr (array.new $Array (global.get $false) (local.get $field-count)))
           (call $fill-fields-from-args   (local.get $arr) (local.get $init-indices) (local.get $args))
           (call $fill-fields-from-values (local.get $arr) (local.get $auto-indices) (local.get $auto-values))
           (call $debug-allocation-tick (i32.const 2))

           (struct.new $Struct
                       ; $Heap
                       (i32.const 0)             ;; hash
                       ; $Procedure
                       (local.get $name)         ;; $false or a $Symbol
                       (ref.i31 (i32.const 0))                  ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (ref.i31 (i32.const 31))                 ;; $false or $Symbol
                       (ref.func $invoke-struct)
                       ; $Struct
                       (local.get $std)
                       (local.get $arr)))

     (func $make-struct-constructor/checked
           (param $std (ref $StructType))
           (result (ref eq)) ;; closure

           (local $field-count      i32)
           (local $guard            (ref eq))
           (local $struct-name      (ref eq))
           (local $constructor-name (ref eq))
           (local $closure-name     (ref eq))
           (local $init-indices     (ref eq))
           (local $auto-indices     (ref eq))
           (local $auto-values      (ref eq))
           (local $free             (ref $Free))
           (local $code             (ref $ClosureCode))
           (local $arity            i32)

           ;; Extract descriptor data
           (local.set $field-count      (struct.get $StructType $field-count      (local.get $std)))
           (local.set $guard            (struct.get $StructType $guard            (local.get $std)))
           (local.set $struct-name      (struct.get $StructType $name             (local.get $std)))
           (local.set $constructor-name (struct.get $StructType $constructor-name (local.get $std)))
           (local.set $init-indices     (struct.get $StructType $init-indices     (local.get $std)))
           (local.set $auto-indices     (struct.get $StructType $auto-indices     (local.get $std)))
           (local.set $auto-values      (struct.get $StructType $auto-values      (local.get $std)))
           (local.set $arity            (call $length/i32 (local.get $init-indices)))
           (local.set $closure-name     (if (result (ref eq))
                                            (ref.eq (local.get $constructor-name) (global.get $false))
                                            (then (local.get $struct-name))
                                            (else (local.get $constructor-name))))

           ;; Choose code based on guard
           (local.set $code
                      (if (result (ref $ClosureCode))
                          (ref.eq (local.get $guard) (global.get $false))
                          (then (ref.func $struct-constructor/no-guard))
                          (else (ref.func $struct-constructor/with-guard))))

           ;; Build free array
           (local.set $free
                      (array.new_fixed $Free 5
                                       (local.get $std)
                                       (local.get $init-indices)
                                       (local.get $auto-indices)
                                       (local.get $auto-values)
                                       local.get $struct-name))

           ;; Construct closure
           (call $debug-allocation-tick (i32.const 4))
           (struct.new $Closure
                       (i32.const 0)               ; hash
                       (local.get $closure-name)   ; name:  #f or $Symbol
                       (ref.i31 (i32.shl (local.get $arity) (i32.const 1))) ; arity
                       (global.get $false)         ; realm: #f or $Symbol
                       (ref.func $invoke-closure)  ; invoke (used by apply, map, etc.)
                       (global.get $false)         ; debug-id
                       (local.get $code)
                       (local.get $free)))
     )))

;; struct-mutator-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic struct mutator helpers used by the monolithic runtime.
(define struct-mutator-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-mutator-runtime-only-helpers
   '(
     (func $make-struct-mutator/checked
           ; Makes a generic mutator that can mutate any field.
           (param $std            (ref $StructType))
           (param $super-count-fx (ref eq))              ;; fixnum: number of supertype fields to skip
           (result                (ref eq))              ;; returns a closure

           (local $free (ref $Free))
           (local $name (ref $Symbol))

           (local.set $name
                      (call $struct-type-mutator-name (local.get $std)))

           ;; Store the struct type and super-field count in the closure's free array
           (local.set $free (array.new_fixed $Free 2
                                             (local.get $std)
                                             (local.get $super-count-fx)))
           (struct.new $StructMutatorProcedure
                       (i32.const 0)               ; hash
                       (local.get $name)           ; name:  #f or $Symbol
                       (ref.i31 (i32.const 6))     ; arity: 3
                       (global.get $false)         ; realm: #f or $Symbol
                       (ref.func $invoke-closure)  ; invoke (used by apply, map, etc.)
                       (global.get $false)         ; debug-id
                       (ref.func $struct-mutator)
                       (local.get $free)))

     (func $raise-struct-mutator:target
           (param $who    (ref eq))
           (param $std    (ref $StructType))
           (param $target (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (call $struct-type-predicate-name-string (local.get $std))
                 (local.get $target))
           (unreachable))

     (func $raise-struct-mutator:index
           (param $who (ref eq))
           (param $bad (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $bad))
           (unreachable))

     (func $raise-struct-mutator:index-too-large
           (param $who              (ref eq))
           (param $std              (ref $StructType))
           (param $index            i32)
           (param $accessible-count i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 8)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $who)))
           (call $growable-array-add! (local.get $out)
                 (if (result (ref eq))
                     (i32.eqz (local.get $accessible-count))
                     (then (global.get $string:struct-accessor:index-too-large-no-fields))
                     (else (global.get $string:struct-accessor:index-too-large))))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $index) (i32.const 1)))))
           (if (local.get $accessible-count)
               (then
                (call $growable-array-add! (local.get $out)
                      (global.get $string:struct-accessor:maximum-allowed-index))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (ref.i31
                             (i32.shl
                              (i32.sub (local.get $accessible-count) (i32.const 1))
                              (i32.const 1)))))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:struct-accessor:structure-type))
           (call $growable-array-add! (local.get $out)
                 (call $struct-type->display-string (local.get $std)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $raise-struct-mutator:immutable-field
           (param $who    (ref eq))
           (param $target (ref eq))
           (param $index  i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 6)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $who)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:struct-mutator:immutable-field))
           (call $growable-array-add! (local.get $out)
                 (call $format/print (local.get $target) (global.get $missing)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:struct-mutator:field-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $index) (i32.const 1)))))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $struct-mutator  ; closure body
           (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result      (ref eq)) ;; returns #<void>

           (local $free           (ref $Free))
           (local $std            (ref $StructType)) ; free[0]
           (local $super-count-fx (ref eq))          ; free[1]
           (local $super-count    i32)


           (local $target    (ref eq))      ; args[0]
           (local $struct    (ref $Struct)) ;  = (cast $Struct $target)
           (local $index-fx  (ref eq))      ; args[1]
           (local $index     i32)           ;  = decoded $index-fx
           (local $val       (ref eq))      ; args[2]

           (local $fields    (ref $Array))  ; fields of the received struct
           (local $skip      i32)
           (local $who       (ref eq))
           (local $accessible-count i32)

           ;; --- Unpack closure free vars ---
           (local.set $free           (struct.get $Closure $free (local.get $clos)))
           (local.set $who            (struct.get $Closure $name (local.get $clos)))
           (local.set $std            (ref.cast (ref $StructType)
                                                (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $super-count-fx (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $super-count    (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $super-count-fx)))
                                                 (i32.const 1)))
           (local.set $skip           (local.get $super-count))

           ;; --- Get arguments ---
           ;; struct
           (local.set $target (array.get $Args (local.get $args) (i32.const 0)))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $target)))
               (then (call $raise-struct-mutator:target
                           (local.get $who)
                           (local.get $std)
                           (local.get $target))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $target)))
           ;; index
           (local.set $index-fx (array.get $Args (local.get $args) (i32.const 1)))
           (if (i32.or (i32.eqz (ref.test (ref i31) (local.get $index-fx)))
                       (i32.ne (i32.and (i31.get_u (ref.cast (ref i31)
                                                             (local.get $index-fx)))
                                        (i32.const 1)) (i32.const 0)))
               (then (call $raise-struct-mutator:index
                           (local.get $who)
                           (local.get $index-fx))))
           (local.set $index (i32.shr_u (i31.get_u (ref.cast (ref i31)
                                                             (local.get $index-fx)))
                                        (i32.const 1)))
           ;; value to store
           (local.set $val (array.get $Args (local.get $args) (i32.const 2)))

           ;; --- Type match ---
           ;  Check that the structure received has the same type as the mutator.
           ;; Type match - is $struct a subtype of $std
           (if (i32.eqz (call $struct-type-is-a?/i32
                              (struct.get $Struct $type (local.get $struct))
                              (local.get $std)))
               (then (call $raise-struct-mutator:target
                           (local.get $who)
                           (local.get $std)
                           (local.get $target))))
           ;; --- Set field ---
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (local.set $accessible-count
                      (i32.sub (struct.get $StructType $field-count (local.get $std))
                               (local.get $skip)))
           (if (i32.ge_u (local.get $index) (local.get $accessible-count))
               (then (call $raise-struct-mutator:index-too-large
                           (local.get $who)
                           (local.get $std)
                           (local.get $index)
                           (local.get $accessible-count))))
           (if (i32.eqz (call $prefab-struct-field-mutable?/i32
                              (local.get $std)
                              (i32.add (local.get $skip) (local.get $index))))
               (then (call $raise-struct-mutator:immutable-field
                           (local.get $who)
                           (local.get $target)
                           (local.get $index))))
           (array.set $Array (local.get $fields)
                      (i32.add (local.get $skip) (local.get $index))
                      (local.get $val))
           ;; --- Return #<void> ---
           (global.get $void))
     )))

;; struct-field-mutator-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate specialized and field mutator helpers used by the monolithic runtime.
(define struct-field-mutator-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-field-mutator-runtime-only-helpers
   '(
     (func $make-struct-mutator/specialized/checked ; helper
           ; The specialized version saves a fixed index to mutate
           ; in the free variables.

           (param $std            (ref $StructType))
           (param $super-count-fx (ref eq)) ;; fixnum
           (param $index-fx       (ref eq)) ;; fixnum
           (param $expected-contract (ref eq)) ;; string expected for target errors
           (param $name           (ref eq)) ;; symbol used for object-name
           (param $realm          (ref eq)) ;; procedure realm symbol
           (result                (ref eq)) ;; returns closure

           (local $free (ref $Free))
           (local.set $free (array.new_fixed $Free 4
                                             (local.get $std)
                                             (local.get $super-count-fx)
                                             (local.get $index-fx)
                                             (local.get $expected-contract)))
           (struct.new $StructMutatorProcedure
                       (i32.const 0)               ; hash
                       (local.get $name)           ; name:  #f or $Symbol
                       (ref.i31 (i32.const 4))     ; arity: 2
                       (local.get $realm)          ; realm: #f or $Symbol
                       (ref.func $invoke-closure)  ; invoke (used by apply, map, etc.)
                       (global.get $false)         ; debug-id
                       (ref.func $struct-mutator/specialized)
                       (local.get $free)))

     (func $struct-mutator/specialized ; closure code
           (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result (ref eq))

           (local $free           (ref $Free))
           (local $std            (ref $StructType)) ; free[0]
           (local $super-count-fx (ref eq))          ; free[1]
           (local $index-fx       (ref eq))          ; free[2]
           (local $expected-contract (ref eq))        ; free[3]
           (local $super-count    i32)
           (local $index          i32)

           (local $target   (ref eq))      ; args[0]
           (local $struct   (ref $Struct))
           (local $val      (ref eq))      ; args[1]
           (local $fields   (ref $Array))
           (local $skip     i32)
           (local $who      (ref eq))
           (local $accessible-count i32)

           ;; --- Unpack free vars ---
           (local.set $free           (struct.get $Closure $free (local.get $clos)))
           (local.set $who            (struct.get $Closure $name (local.get $clos)))
           (local.set $std            (ref.cast (ref $StructType)
                                                (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $super-count-fx (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $index-fx       (array.get $Free (local.get $free) (i32.const 2)))
           (local.set $expected-contract (array.get $Free (local.get $free) (i32.const 3)))
           (local.set $super-count    (i32.shr_u
                                       (i31.get_u (ref.cast (ref i31) (local.get $super-count-fx)))
                                       (i32.const 1)))
           (local.set $index          (i32.shr_u
                                       (i31.get_u (ref.cast (ref i31) (local.get $index-fx)))
                                       (i32.const 1)))
           (local.set $skip           (local.get $super-count))

           ;; --- Get arguments ---
           (local.set $target (array.get $Args (local.get $args) (i32.const 0)))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $target)))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected-contract)
                           (local.get $target))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $target)))

           (local.set $val (array.get $Args (local.get $args) (i32.const 1)))

           ;; --- Type check ---
           ;; Is $struct a subtype of $std
           (if (i32.eqz (call $struct-type-is-a?/i32
                              (struct.get $Struct $type (local.get $struct))
                              (local.get $std)))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected-contract)
                           (local.get $target))))

           ;; --- Set field ---
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (local.set $accessible-count
                      (i32.sub (struct.get $StructType $field-count (local.get $std))
                               (local.get $skip)))
           (if (i32.ge_u (local.get $index) (local.get $accessible-count))
               (then (call $raise-struct-mutator:index-too-large
                           (local.get $who)
                           (local.get $std)
                           (local.get $index)
                           (local.get $accessible-count))))
           (if (i32.eqz (call $prefab-struct-field-mutable?/i32
                              (local.get $std)
                              (i32.add (local.get $skip) (local.get $index))))
               (then (call $raise-struct-mutator:immutable-field
                           (local.get $who)
                           (local.get $target)
                           (local.get $index))))
           (array.set $Array (local.get $fields)
                      (i32.add (local.get $skip) (local.get $index))
                      (local.get $val))

           ;; --- Return #<void> ---
           (global.get $void))


     (func $build-structure-field-mutator-name
           ; Builds set-<struct-name>-<field-name>!
           (param $struct-name (ref $String))
           (param $field-name  (ref $String))
           (result             (ref $Symbol))

           (local $parts    (ref eq))

           (local.set $parts (global.get $null))
           (local.set $parts (call $cons (global.get $string:bang) (local.get $parts)))
           (local.set $parts (call $cons (local.get  $field-name)  (local.get $parts)))
           (local.set $parts (call $cons (global.get $string:dash) (local.get $parts)))
           (local.set $parts (call $cons (local.get  $struct-name) (local.get $parts)))
           (local.set $parts (call $cons (global.get $string:dash) (local.get $parts)))
           (local.set $parts (call $cons (global.get $string:set)  (local.get $parts)))

           (call $string->symbol/checked
                 (ref.cast (ref $String)
                           (call $string-append (local.get $parts)))))

     (func $raise-make-struct-field-mutator:mutator-proc
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-mutator)
                 (global.get $string:make-struct-field-mutator-procedure)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-mutator:field-pos
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-mutator)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-mutator:name
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-mutator)
                 (global.get $string:make-struct-field-name)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-mutator:contract-str
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-mutator)
                 (global.get $string:make-struct-field-contract-str)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-mutator:realm
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-mutator)
                 (global.get $string:symbol?)
                 (local.get $bad))
           (unreachable))

     (func $make-struct-field-mutator  ; Racket primitive
           ; Note: This functions uses the internal representation of
           ;       a mutator procedure closure.
           (param $mutator-proc      (ref eq)) ;; closure
           (param $field-pos-fx      (ref eq)) ;; fixnum
           (param $field/proc-name   (ref eq)) ;; symbol or #f
           (param $arg-contract-str  (ref eq)) ;; string/symbol/#f
           (param $realm             (ref eq)) ;; symbol
           (result                   (ref eq)) ;; returns a specialized mutator

           (local $clos             (ref $Closure))
           (local $code             (ref $ClosureCode))
           (local $free             (ref $Free))
           (local $std              (ref $StructType))
           (local $super-count-fx   (ref eq))
           (local $super-count      i32)
           (local $accessible-count i32)
           (local $struct-name      (ref eq))
           (local $struct-name-sym  (ref $Symbol))
           (local $struct-name-str  (ref $String))
           (local $field-name       (ref eq))
           (local $field-name-sym   (ref $Symbol))
           (local $field-name-str   (ref $String))
           (local $name             (ref eq))
           (local $realm-checked    (ref eq))
           (local $arg-contract     (ref eq))
           (local $expected-contract (ref eq))
           (local $combine?         i32)
           (local $field-pos        i32)

           ;; --- Check mutator-proc is a closure ---
           (if (i32.eqz (ref.test (ref $StructMutatorProcedure) (local.get $mutator-proc)))
               (then (call $raise-make-struct-field-mutator:mutator-proc
                           (local.get $mutator-proc))))
           (if (i32.eqz
                (call $procedure-arity-includes?/checked/i32
                      (ref.cast (ref $Procedure) (local.get $mutator-proc))
                      (i32.const 3)))
               (then (call $raise-make-struct-field-mutator:mutator-proc
                           (local.get $mutator-proc))))
           (local.set $clos (ref.cast (ref $Closure) (local.get $mutator-proc)))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $field-pos-fx))
                       (global.get $false))
               (then (call $raise-make-struct-field-mutator:field-pos
                           (local.get $field-pos-fx))))
           (local.set $field-pos
                      (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $field-pos-fx)))
                                  (i32.const 1)))

           ;; --- Extract fields ---
           (local.set $free           (struct.get $Closure $free (local.get $clos)))
           (local.set $std            (ref.cast (ref $StructType)
                                                (array.get $Free
                                                           (local.get $free) (i32.const 0))))
           (local.set $super-count-fx (array.get $Free
                                                 (local.get $free) (i32.const 1)))
           (local.set $super-count
                      (i32.shr_u (i31.get_u
                                  (ref.cast (ref i31) (local.get $super-count-fx)))
                                 (i32.const 1)))
           (local.set $accessible-count
                      (i32.sub (struct.get $StructType $field-count (local.get $std))
                               (local.get $super-count)))
           (if (i32.ge_u (local.get $field-pos) (local.get $accessible-count))
               (then (call $raise-struct-mutator:index-too-large
                           (global.get $symbol:make-struct-field-mutator)
                           (local.get $std)
                           (local.get $field-pos)
                           (local.get $accessible-count))))
           (local.set $struct-name    (struct.get $StructType $name (local.get $std)))
           (local.set $field-name
                      (if (result (ref eq))
                          (ref.eq (local.get $field/proc-name) (global.get $missing))
                          (then
                           (call $string->symbol/checked
                                 (call $string-append/2
                                       (global.get $string:field)
                                       (call $i32->string (local.get $field-pos)))))
                          (else (local.get $field/proc-name))))
           (local.set $arg-contract
                      (if (result (ref eq))
                          (ref.eq (local.get $arg-contract-str) (global.get $missing))
                          (then (global.get $false))
                          (else (local.get $arg-contract-str))))
           (local.set $realm-checked
                      (if (result (ref eq))
                          (ref.eq (local.get $realm) (global.get $missing))
                          (then (global.get $symbol:racket))
                          (else (local.get $realm))))

           ;; --- Validate optional arguments ---
           (if (i32.and (i32.eqz (ref.eq (local.get $field-name) (global.get $false)))
                        (i32.eqz (ref.test (ref $Symbol) (local.get $field-name))))
               (then (call $raise-make-struct-field-mutator:name
                           (local.get $field-name))))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $arg-contract) (global.get $false)))
                (i32.and (i32.eqz (ref.test (ref $Symbol) (local.get $arg-contract)))
                         (i32.eqz (ref.test (ref $String) (local.get $arg-contract)))))
               (then (call $raise-make-struct-field-mutator:contract-str
                           (local.get $arg-contract))))
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm-checked)))
               (then (call $raise-make-struct-field-mutator:realm
                           (local.get $realm-checked))))
           (local.set $expected-contract
                      (if (result (ref eq))
                          (ref.eq (local.get $arg-contract) (global.get $false))
                          (then (call $struct-type-predicate-name-string (local.get $std)))
                          (else
                           (if (result (ref eq))
                               (ref.test (ref $Symbol) (local.get $arg-contract))
                               (then
                                (call $symbol->immutable-string
                                      (ref.cast (ref $Symbol)
                                                (local.get $arg-contract))))
                               (else (local.get $arg-contract))))))

           ;; --- Determine procedure name ---
           (local.set $name (global.get $symbol:mutator))
           (if (ref.eq (local.get $field-name) (global.get $false))
               (then)
               (else
                (if (ref.test (ref $Symbol) (local.get $field-name))
                    (then
                     (local.set $field-name-sym (ref.cast (ref $Symbol) (local.get $field-name)))
                     (local.set $combine?
                                (if (result i32)
                                    (ref.eq (local.get $arg-contract) (global.get $false))
                                    (then (i32.const 1))
                                    (else
                                     (if (result i32)
                                         (ref.test (ref $Symbol) (local.get $arg-contract))
                                         (then
                                          (if (result i32)
                                              (i32.eqz (ref.eq (ref.cast (ref $Symbol) (local.get $arg-contract))
                                                                (local.get $field-name-sym)))
                                              (then (i32.const 0))
                                              (else (i32.const 1))))
                                         (else
                                          (if (result i32)
                                              (ref.test (ref $String) (local.get $arg-contract))
                                              (then
                                               (local.set $field-name-str
                                                          (ref.cast (ref $String)
                                                                    (call $symbol->immutable-string
                                                                          (local.get $field-name-sym))))
                                               (if (result i32)
                                                   (call $string=?/i32
                                                         (local.get $field-name-str)
                                                         (ref.cast (ref $String) (local.get $arg-contract)))
                                                   (then (i32.const 1))
                                                   (else (i32.const 0))))
                                              (else (i32.const 0))))))))
                     (if (local.get $combine?)
                         (then
                          (if (i32.eqz (ref.test (ref $Symbol) (local.get $struct-name)))
                              (then (local.set $name (local.get $field-name)))
                              (else
                               (local.set $struct-name-sym
                                          (ref.cast (ref $Symbol) (local.get $struct-name)))
                               (local.set $struct-name-str
                                          (ref.cast (ref $String)
                                                    (call $symbol->immutable-string
                                                          (local.get $struct-name-sym))))
                               (local.set $field-name-str
                                          (ref.cast (ref $String)
                                                    (call $symbol->immutable-string
                                                          (local.get $field-name-sym))))
                               (local.set $name
                                          (call $build-structure-field-mutator-name
                                                (local.get $struct-name-str)
                                                (local.get $field-name-str))))))
                         (else
                          (local.set $name (local.get $field-name)))))
                    (else
                     (call $raise-make-struct-field-mutator:name
                           (local.get $field-name))))))

           ;; --- Call specialized mutator constructor ---
           (call $make-struct-mutator/specialized/checked
                 (local.get $std)
                 (local.get $super-count-fx)
                 (local.get $field-pos-fx)
                 (local.get $expected-contract)
                 (local.get $name)
                 (local.get $realm-checked)))
     )))

;; struct-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic struct predicate helpers used by the monolithic runtime.
(define struct-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-predicate-runtime-only-helpers
   '(
     (func $make-struct-predicate
           (param $v (ref eq)) ;; expected: (ref $StructType)
           (result (ref eq))   ;; returns: closure

           (if (i32.eqz (ref.test (ref $StructType) (local.get $v)))
               (then (call $raise-argument-error/internal (local.get $v))))

           (call $make-struct-predicate/checked
                 (ref.cast (ref $StructType) (local.get $v))))

     (func $make-struct-predicate/checked
           (param $std (ref $StructType))
           (result (ref eq)) ;; returns closure

           (local $free (ref $Free))

           (local.set $free
                      (array.new_fixed $Free 1 (local.get $std)))

           (struct.new $Closure
                       (i32.const 0)               ; hash
                       (global.get $false)         ; name:  #f or $String
                       (ref.i31 (i32.const 2))     ; arity: 1
                       (global.get $false)         ; realm: #f or $Symbol
                       (ref.func $invoke-closure)  ; invoke (used by apply, map, etc.)
                       (global.get $false)         ; debug-id
                       (ref.func $struct-predicate)
                       (local.get $free)))


     (func $struct-predicate  ; closure code
           (type $ClosureCode)

           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result      (ref eq))

           (local $free (ref $Free))
           (local $std  (ref $StructType))
           (local $v    (ref eq))
           (local $ok   i32)

           (local.set $free (struct.get $Closure $free (local.get $clos)))
           (local.set $std  (ref.cast (ref $StructType)
                                      (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $v    (array.get $Args (local.get $args) (i32.const 0)))
           (local.set $ok   (if (result i32)
                                (ref.test (ref $Struct) (local.get $v))
                                (then ;; Is $struct a subtype of $std
                                 (call $struct-type-is-a?/i32
                                           (struct.get $Struct $type
                                                       (ref.cast (ref $Struct) (local.get $v)))
                                           (local.get $std)))
                                (else (i32.const 0))))
           (if (result (ref eq))
               (local.get $ok)
               (then (global.get $true))
               (else (global.get $false))))
     )))

;; struct-constructor-wrapper-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public struct constructor wrapper helpers used by the monolithic runtime.
(define struct-constructor-wrapper-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-constructor-wrapper-runtime-only-helpers
   '(
     (func $make-struct-constructor
           ;; Parameters
           (param $v (ref eq)) ;; Expected: (ref $StructType)
           (result   (ref eq)) ;; Returns: closure

           (local $std (ref $StructType))

           ;; Type check
           (if (i32.eqz (ref.test (ref $StructType) (local.get $v)))
               (then (call $raise-argument-error/internal (local.get $v))))
           ;; Decode
           (local.set $std (ref.cast (ref $StructType) (local.get $v)))
           ;; Delegate
           (call $make-struct-constructor/checked (local.get $std)))
     )))

;; struct-field-accessor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct field accessor helpers used by the monolithic runtime.
(define struct-field-accessor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-field-accessor-runtime-only-helpers
   '(
     (func $raise-make-struct-field-accessor:accessor-proc
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-accessor)
                 (global.get $string:make-struct-field-accessor-procedure)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-accessor:field-pos
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-accessor)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-accessor:name
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-accessor)
                 (global.get $string:make-struct-field-name)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-accessor:contract-str
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-accessor)
                 (global.get $string:make-struct-field-contract-str)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-field-accessor:realm
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-field-accessor)
                 (global.get $string:symbol?)
                 (local.get $bad))
           (unreachable))

     (func $make-struct-field-accessor ; primitive, section 5.2, returns specialized accessor
           ;; Parameters
           (param $accessor-proc  (ref eq))   ;; closure produced by make-struct-accessor
           (param $field-index-fx (ref eq))   ;; fixnum
           (param $name           (ref eq))   ;; symbol or #f
           (param $contract-str   (ref eq))   ;; string/symbol/#f (ignored)
           (param $realm          (ref eq))   ;; symbol

           (result (ref eq)) ;; closure: (λ (struct) field-value)

           ;; Locals
           (local $accessor             (ref $Closure))
           (local $free                 (ref $Free))
           (local $std                  (ref $StructType))
           (local $super-count-fx       (ref eq))
           (local $super-count          i32)
           (local $accessible-count     i32)
           (local $struct-name          (ref eq))
           (local $field-accessor-name  (ref eq))
           (local $field-index          i32)
           (local $field-name           (ref eq))
           (local $contract-checked     (ref eq))
           (local $expected-contract    (ref eq))
           (local $realm-checked        (ref eq))

           ;; --- Type checks ---
           ;; Check accessor-proc is a struct accessor procedure
           (if (i32.eqz (ref.test (ref $StructAccessorProcedure) (local.get $accessor-proc)))
               (then (call $raise-make-struct-field-accessor:accessor-proc
                           (local.get $accessor-proc))))
           (if (i32.eqz
                (call $procedure-arity-includes?/checked/i32
                      (ref.cast (ref $Procedure) (local.get $accessor-proc))
                      (i32.const 2)))
               (then (call $raise-make-struct-field-accessor:accessor-proc
                           (local.get $accessor-proc))))
           (local.set $accessor (ref.cast (ref $Closure) (local.get $accessor-proc)))
           ;; Check field-index is an exact nonnegative integer.
           (if (ref.eq (call $exact-nonnegative-integer? (local.get $field-index-fx))
                       (global.get $false))
               (then (call $raise-make-struct-field-accessor:field-pos
                           (local.get $field-index-fx))))
           (local.set $field-index
                      (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $field-index-fx)))
                                  (i32.const 1)))
           (local.set $field-name
                      (if (result (ref eq))
                          (ref.eq (local.get $name) (global.get $missing))
                          (then
                           (call $string->symbol/checked
                                 (call $string-append/2
                                       (global.get $string:field)
                                       (call $i32->string (local.get $field-index)))))
                          (else (local.get $name))))
           (local.set $contract-checked
                      (if (result (ref eq))
                          (ref.eq (local.get $contract-str) (global.get $missing))
                          (then (global.get $false))
                          (else (local.get $contract-str))))
           (local.set $realm-checked
                      (if (result (ref eq))
                          (ref.eq (local.get $realm) (global.get $missing))
                          (then (global.get $symbol:racket))
                          (else (local.get $realm))))
           ;; field name must be a symbol or #f
           (if (i32.and (i32.eqz (ref.eq (local.get $field-name) (global.get $false)))
                        (i32.eqz (ref.test (ref $Symbol) (local.get $field-name))))
               (then (call $raise-make-struct-field-accessor:name
                           (local.get $field-name))))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $contract-checked) (global.get $false)))
                (i32.and (i32.eqz (ref.test (ref $Symbol) (local.get $contract-checked)))
                         (i32.eqz (ref.test (ref $String) (local.get $contract-checked)))))
               (then (call $raise-make-struct-field-accessor:contract-str
                           (local.get $contract-checked))))
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm-checked)))
               (then (call $raise-make-struct-field-accessor:realm
                           (local.get $realm-checked))))
           ;; Build the name of the struct accessor
           (local.set $free (struct.get $Closure $free (local.get $accessor)))
           (local.set $std  (ref.cast (ref $StructType)
                                      (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $super-count-fx (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $super-count
                      (i32.shr_u (i31.get_u
                                  (ref.cast (ref i31) (local.get $super-count-fx)))
                                 (i32.const 1)))
           (local.set $accessible-count
                      (i32.sub (struct.get $StructType $field-count (local.get $std))
                               (local.get $super-count)))
           (if (i32.ge_u (local.get $field-index) (local.get $accessible-count))
               (then (call $raise-struct-accessor:index-too-large
                           (global.get $symbol:make-struct-field-accessor)
                           (local.get $std)
                           (local.get $field-index)
                           (local.get $accessible-count))))
           (local.set $struct-name (struct.get $StructType $name (local.get $std)))
           (local.set $expected-contract
                      (if (result (ref eq))
                          (ref.eq (local.get $contract-checked) (global.get $false))
                          (then (call $struct-type-predicate-name-string (local.get $std)))
                          (else
                           (if (result (ref eq))
                               (ref.test (ref $Symbol) (local.get $contract-checked))
                               (then
                                (call $symbol->immutable-string
                                      (ref.cast (ref $Symbol)
                                                (local.get $contract-checked))))
                               (else (local.get $contract-checked))))))
           (local.set $field-accessor-name
                      (if (result (ref eq))
                          (ref.eq (local.get $field-name) (global.get $false))
                          (then (global.get $symbol:accessor))
                          (else
                           (if (result (ref eq))
                               (ref.eq (local.get $contract-checked) (global.get $false))
                               (then
                                (call $string->symbol
                                      (call $string-append/2
                                            (call $string-append/2
                                                  (call $symbol->string
                                                        (ref.cast (ref $Symbol)
                                                                  (local.get $struct-name)))
                                                  (call $codepoint->string (i32.const 45)))
                                            (call $symbol->string
                                                  (ref.cast (ref $Symbol)
                                                            (local.get $field-name))))))
                               (else (local.get $field-name))))))
           ;; --- Build Free vector ---
           (local.set $free (array.new_fixed $Free 4
                                             (local.get $std)
                                             (local.get $super-count-fx)
                                             (local.get $field-index-fx)
                                             (local.get $expected-contract)))
           ;; --- Return closure ---
           (struct.new $Closure
                       (i32.const 0)                     ; hash
                       (local.get $field-accessor-name)  ; name:  #f or $Symbol
                       (ref.i31 (i32.const 2))           ; arity: 1
                       (local.get $realm-checked)        ; realm: $Symbol
                       (ref.func $invoke-closure)        ; invoke (used by apply, map, etc.)
                       (global.get $false)               ; debug-id
                       (ref.func $struct-field-accessor/specialized)
                       (local.get $free)))

     (func $struct-field-accessor/specialized
           (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result      (ref eq))

           (local $free              (ref $Free))
           (local $std               (ref $StructType))
           (local $super-count-fx    (ref eq))
           (local $field-index-fx    (ref eq))
           (local $expected-contract (ref eq))
           (local $super-count       i32)
           (local $field-index       i32)
           (local $target            (ref eq))
           (local $struct            (ref $Struct))
           (local $fields            (ref $Array))
           (local $who               (ref eq))

           (local.set $free              (struct.get $Closure $free (local.get $clos)))
           (local.set $who               (struct.get $Closure $name (local.get $clos)))
           (local.set $std               (ref.cast (ref $StructType)
                                                   (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $super-count-fx    (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $field-index-fx    (array.get $Free (local.get $free) (i32.const 2)))
           (local.set $expected-contract (array.get $Free (local.get $free) (i32.const 3)))
           (local.set $super-count
                      (i32.shr_u (i31.get_u
                                  (ref.cast (ref i31) (local.get $super-count-fx)))
                                 (i32.const 1)))
           (local.set $field-index
                      (i32.shr_u (i31.get_u
                                  (ref.cast (ref i31) (local.get $field-index-fx)))
                                 (i32.const 1)))

           (local.set $target (array.get $Args (local.get $args) (i32.const 0)))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $target)))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected-contract)
                           (local.get $target))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $target)))
           (if (i32.eqz (call $struct-type-is-a?/i32
                              (struct.get $Struct $type (local.get $struct))
                              (local.get $std)))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected-contract)
                           (local.get $target))))
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (array.get $Array (local.get $fields)
                      (i32.add (local.get $super-count) (local.get $field-index))))
     )))

;; struct-procedure-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate predicates for generated struct procedure wrappers.
(define struct-procedure-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-procedure-predicate-runtime-only-helpers
   '(
     (func $struct-constructor-procedure? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $StructConstructorProcedure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $struct-predicate-procedure? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $StructPredicateProcedure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $struct-accessor-procedure? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $StructAccessorProcedure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $struct-mutator-procedure? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $StructMutatorProcedure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))
     )))

;; struct-guarded-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate guarded constructor and field-fill helpers used by the monolithic runtime.
(define struct-guarded-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-guarded-constructor-runtime-only-helpers
   '(
     (func $struct-constructor/with-guard
           (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result (ref eq))

           (local $free         (ref $Free))
           (local $std          (ref $StructType))
           (local $init-indices (ref eq))
           (local $auto-indices (ref eq))
           (local $auto-values  (ref eq))
           (local $name         (ref eq))
           (local $field-count  i32)
           (local $init-count   i32)
           (local $i            i32)
           (local $arr          (ref $Array))
           (local $g-args       (ref $Args))
           (local $init-args    (ref $Args))
           (local $guard        (ref $Procedure))
           (local $guard-invoke (ref $ProcedureInvoker))
           (local $result       (ref eq))
           (local $vals         (ref $Values))

           (local.set $free         (struct.get $Closure $free (local.get $clos)))
           (local.set $std          (ref.cast (ref $StructType) (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $init-indices (array.get $Free (local.get $free) (i32.const 1)))
           (local.set $auto-indices (array.get $Free (local.get $free) (i32.const 2)))
           (local.set $auto-values  (array.get $Free (local.get $free) (i32.const 3)))
           (local.set $name         (array.get $Free (local.get $free) (i32.const 4)))
           (local.set $field-count  (struct.get $StructType $field-count (local.get $std)))
           (local.set $init-count   (call $length/i32 (local.get $init-indices)))
           (local.set $guard        (ref.cast (ref $Procedure) (struct.get $StructType $guard (local.get $std))))
           (local.set $guard-invoke (struct.get $Procedure $invoke (local.get $guard)))

           ;; Call guard with all constructor init arguments plus the struct name.
           (local.set $g-args (array.new $Args (global.get $false)
                                          (i32.add (local.get $init-count) (i32.const 1))))
           (local.set $i (i32.const 0))
           (block $done-copy-guard-args
                  (loop $copy-guard-args
                        (br_if $done-copy-guard-args (i32.ge_u (local.get $i) (local.get $init-count)))
                        (array.set $Args (local.get $g-args) (local.get $i)
                                   (array.get $Args (local.get $args) (local.get $i)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $copy-guard-args)))
           (array.set $Args (local.get $g-args) (local.get $init-count) (local.get $name))
           (local.set $result
                      (call_ref $ProcedureInvoker
                                (local.get $guard)
                                (local.get $g-args)
                                (local.get $guard-invoke)))

           ;; The guard returns the replacement init arguments.
           (local.set $init-args (array.new $Args (global.get $false) (local.get $init-count)))
           (if (i32.eqz (local.get $init-count))
               (then (drop (call $expect-zero-values (local.get $result))))
               (else
                (if (i32.eq (local.get $init-count) (i32.const 1))
                    (then
                     (array.set $Args (local.get $init-args) (i32.const 0)
                                (call $expect-one-value (local.get $result))))
                    (else
                     (local.set $vals (call $expect-n-values
                                            (local.get $result)
                                            (local.get $init-count)))
                     (local.set $i (i32.const 0))
                     (block $done-copy-results
                            (loop $copy-results
                                  (br_if $done-copy-results (i32.ge_u (local.get $i) (local.get $init-count)))
                                  (array.set $Args (local.get $init-args) (local.get $i)
                                             (array.get $Values (local.get $vals) (local.get $i)))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $copy-results)))))))

           ;; Make $arr and fill it from guarded init results.
           (local.set $arr (array.new $Array (global.get $false) (local.get $field-count)))
           (call $fill-fields-from-args (local.get $arr) (local.get $init-indices) (local.get $init-args))
           (call $fill-fields-from-values (local.get $arr) (local.get $auto-indices) (local.get $auto-values))

           (struct.new $Struct
                       ; $Heap
                       (i32.const 0)             ;; hash
                       ; $Procedure
                       (local.get $name)         ;; $false or a $Symbol
                       (ref.i31 (i32.const 0))                  ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (ref.i31 (i32.const 31))                 ;; $false or $Symbol
                       (ref.func $invoke-struct)
                       ; $Struct
                       (local.get $std)
                       (local.get $arr)))

     ; (call $fill-fields-from-args   (local.get $arr) (local.get $init-indices) (local.get $args))

     (func $fill-fields-from-args
           (param $fields  (ref $Array)) ;; struct field array
           (param $indices (ref eq))     ;; list of i31 fixnums (init field indices)
           (param $args    (ref $Args))  ;; argument array

           (local $i       i32)
           (local $arg     (ref eq))
           (local $index   i32)

           (local.set $i (i32.const 0))
           (block $done
                  (loop $loop
                        ;; If $indices is null, we’re done
                        (br_if $done (ref.eq (local.get $indices) (global.get $null)))
                        ;; Type check: $indices must be $Pair
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $indices)))
                            (then (call $raise-argument-error/internal (local.get $indices))))
                        ;; Extract current index (fixnum) and decode
                        (local.set $index (i32.shr_u
                                           (i31.get_u
                                            (ref.cast (ref i31)
                                                      (struct.get $Pair $a
                                                                  (ref.cast (ref $Pair)
                                                                            (local.get $indices)))))
                                           (i32.const 1)))
                        ;; Get arg[i]
                        (local.set $arg (array.get $Args (local.get $args) (local.get $i)))
                        ;; fields[index] := arg[i]
                        (array.set $Array (local.get $fields) (local.get $index) (local.get $arg))
                        ;; Move to next
                        (local.set $i       (i32.add (local.get $i) (i32.const 1)))
                        (local.set $indices (struct.get $Pair $d
                                                        (ref.cast (ref $Pair)
                                                                  (local.get $indices))))
                        (br $loop))))

     (func $fill-fields-from-values
           (param $fields  (ref $Array)) ;; struct field array
           (param $indices (ref eq))     ;; list of i31 fixnums (auto field indices)
           (param $values  (ref eq))     ;; list of values for auto fields
           (local $val (ref eq))
           (local $index i32)

           (block $done
                  (loop $loop
                        ;; Done if either list is null
                        (br_if $done
                               (i32.or
                                (ref.eq (local.get $indices) (global.get $null))
                                (ref.eq (local.get $values)  (global.get $null))))
                        ;; Type checks
                        (if (i32.or (i32.eqz (ref.test (ref $Pair) (local.get $indices)))
                                    (i32.eqz (ref.test (ref $Pair) (local.get $values))))
                            (then (call $raise-argument-error/internal (local.get $indices))))
                        ;; Decode fixnum index
                        (local.set $index (i32.shr_u
                                           (i31.get_u
                                            (ref.cast (ref i31)
                                                      (struct.get $Pair $a
                                                                  (ref.cast (ref $Pair)
                                                                            (local.get $indices)))))
                                           (i32.const 1)))
                        ;; Get value
                        (local.set $val (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $values))))
                        ;; fields[index] := val
                        (array.set $Array (local.get $fields) (local.get $index) (local.get $val))
                        ;; Move to next
                        (local.set $indices (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $indices))))
                        (local.set $values  (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $values))))
                        (br $loop))))
     )))

;; struct-type-property-lookup-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct type property lookup helpers used by the monolithic runtime.
(define struct-type-property-lookup-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-type-property-lookup-runtime-only-helpers
   '(
     (func $struct-type-property-lookup
           (param $std      (ref $StructType))
           (param $prop     (ref $StructTypeProperty))
           (param $sentinel (ref eq))
           (result (ref eq))

           (local $table (ref eq))

           (local.set $table (struct.get $StructType $properties (local.get $std)))
           (call $hasheq-ref/plain
                 (local.get $table)
                 (ref.cast (ref eq) (local.get $prop))
                 (local.get $sentinel)))

     (func $struct-type-property-lookup-by-name
           (param $std      (ref $StructType))
           (param $name     (ref $Symbol))
           (param $sentinel (ref eq))
           (result (ref eq))

           (local $table     (ref $HashEqMutable))
           (local $alist     (ref eq))
           (local $cursor    (ref eq))
           (local $cell      (ref $Pair))
           (local $entry-raw (ref eq))
           (local $entry     (ref $Pair))
           (local $prop      (ref $StructTypeProperty))

           (local.set $table
                      (ref.cast (ref $HashEqMutable)
                                (struct.get $StructType $properties (local.get $std))))
           (local.set $alist (call $hasheq->list/plain/checked (local.get $table)))
           (local.set $cursor (local.get $alist))
           (block $done
                  (loop $walk
                        (br_if $done (ref.eq (local.get $cursor) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                            (then (call $raise-argument-error/internal (local.get $cursor))
                                  (unreachable)))
                        (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                        (local.set $entry-raw (struct.get $Pair $a (local.get $cell)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $entry-raw)))
                            (then (call $raise-argument-error/internal (local.get $entry-raw))
                                  (unreachable)))
                        (local.set $entry (ref.cast (ref $Pair) (local.get $entry-raw)))
                        (local.set $prop
                                   (ref.cast (ref $StructTypeProperty)
                                             (struct.get $Pair $a (local.get $entry))))
                        (if (i32.eq (call $symbol=?/i32
                                           (struct.get $StructTypeProperty $name (local.get $prop))
                                           (local.get $name))
                                     (i32.const 1))
                            (then (return (struct.get $Pair $d (local.get $entry)))))
                        (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                        (br $walk)))
           (local.get $sentinel))
     )))

;; struct-type-property-closure-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct type property closure helpers used by the monolithic runtime.
(define struct-type-property-closure-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-type-property-closure-runtime-only-helpers
   '(
     (func $struct-type-property-predicate (type $ClosureCode)
           (param $clos           (ref $Closure))
           (param $args           (ref $Args))
           (result                (ref eq))

           (local $free           (ref $Free))
           (local $prop           (ref $StructTypeProperty))
           (local $target         (ref eq))
           (local $std            (ref null $StructType))
           (local $struct         (ref $Struct))
           (local $sentinel       (ref eq))
           (local $val            (ref eq))

           (local.set $free (struct.get $Closure $free (local.get $clos)))
           (local.set $prop
                      (ref.cast (ref $StructTypeProperty)
                                (array.get $Free (local.get $free) (i32.const 0))))
           (local.set $target (array.get $Args (local.get $args) (i32.const 0)))
           (local.set $std (ref.null $StructType))

           (block $validated
                  (if (ref.test (ref $StructType) (local.get $target))
                      (then
                       (local.set $std (ref.cast (ref $StructType) (local.get $target)))
                       (br $validated)))
                  (if (ref.test (ref $Struct) (local.get $target))
                      (then
                       (local.set $struct (ref.cast (ref $Struct) (local.get $target)))
                       (local.set $std (struct.get $Struct $type (local.get $struct)))
                       (br $validated)))
                  (return (global.get $false)))

           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $val
                      (call $struct-type-property-lookup
                            (ref.as_non_null (local.get $std))
                            (local.get $prop)
                            (local.get $sentinel)))

           (if (result (ref eq))
               (ref.eq (local.get $val) (local.get $sentinel))
               (then (global.get $false))
               (else (global.get $true))))

     (func $struct-type-property-accessor (type $ClosureCode)
           (param $clos (ref $Closure))
           (param $args (ref $Args))
           (result      (ref eq))

           (local $free     (ref $Free))
           (local $prop     (ref $StructTypeProperty))
           (local $argc     i32)
           (local $target   (ref eq))
           (local $fallback (ref eq))
           (local $std      (ref null $StructType))
           (local $struct   (ref $Struct))
           (local $sentinel (ref eq))
           (local $val      (ref eq))
           (local $proc     (ref $Procedure))
           (local $inv      (ref $ProcedureInvoker))
           (local $noargs   (ref $Args))
           (local $fallback-proc? i32)
           (local $rest     (ref eq))
           (local $rest-pair (ref $Pair))
           (local $rest-tail (ref eq))
           (local $given-count i32)

           (local.set $free (struct.get $Closure $free (local.get $clos)))
           (local.set $prop
                      (ref.cast (ref $StructTypeProperty)
                                (array.get $Free (local.get $free) (i32.const 0))))

           (local.set $argc (array.len (local.get $args)))
           (if (i32.eqz (i32.ge_u (local.get $argc) (i32.const 1)))
               (then (call $raise-arity-mismatch/proc (local.get $clos) (local.get $argc))
                     (unreachable)))

           (local.set $target (array.get $Args (local.get $args) (i32.const 0)))
           (local.set $rest
                      (if (result (ref eq))
                          (i32.gt_u (local.get $argc) (i32.const 1))
                          (then (array.get $Args (local.get $args) (i32.const 1)))
                          (else (global.get $null))))

           (local.set $fallback (global.get $missing))
           (if (ref.eq (local.get $rest) (global.get $null))
               (then)
               (else
                (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                    (then (call $raise-argument-error/internal (local.get $rest))
                          (unreachable)))
                (local.set $rest-pair (ref.cast (ref $Pair) (local.get $rest)))
                (local.set $fallback (struct.get $Pair $a (local.get $rest-pair)))
                (local.set $rest-tail (struct.get $Pair $d (local.get $rest-pair)))
                (if (i32.eqz (ref.eq (local.get $rest-tail) (global.get $null)))
                    (then (local.set $given-count
                                     (i32.add (i32.const 1)
                                              (call $length/i32 (local.get $rest))))
                          (call $raise-arity-mismatch/proc (local.get $clos) (local.get $given-count))
                          (unreachable)))))

           (local.set $std (ref.null $StructType))

           (if (ref.test (ref $StructType) (local.get $target))
               (then (local.set $std (ref.cast (ref $StructType) (local.get $target))))
               (else
                (if (ref.test (ref $Struct) (local.get $target))
                    (then (local.set $struct (ref.cast (ref $Struct) (local.get $target)))
                          (local.set $std (struct.get $Struct $type (local.get $struct))))
                    (else
                     (if (ref.eq (local.get $fallback) (global.get $missing))
                         (then (call $raise-struct-type-property-accessor-contract
                                     (local.get $prop)
                                     (local.get $target))
                               (unreachable))
                         (else
                          (local.set $fallback-proc?
                                     (ref.eq (call $procedure? (local.get $fallback))
                                             (global.get $true)))
                          (if (local.get $fallback-proc?)
                              (then (local.set $proc (ref.cast (ref $Procedure) (local.get $fallback)))
                                    (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                                    (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                                    (return_call_ref $ProcedureInvoker
                                                     (local.get $proc)
                                                     (local.get $noargs)
                                                     (local.get $inv)))
                              (else (return (local.get $fallback))))))))))

           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $val
                      (call $struct-type-property-lookup
                            (ref.as_non_null (local.get $std))
                            (local.get $prop)
                            (local.get $sentinel)))

           (if (ref.eq (local.get $val) (local.get $sentinel))
               (then
                (if (ref.eq (local.get $fallback) (global.get $missing))
                    (then (call $raise-struct-type-property-accessor-contract
                                (local.get $prop)
                                (local.get $target))
                          (unreachable))
                    (else
                     (local.set $fallback-proc?
                                (ref.eq (call $procedure? (local.get $fallback))
                                        (global.get $true)))
                     (if (local.get $fallback-proc?)
                         (then (local.set $proc (ref.cast (ref $Procedure) (local.get $fallback)))
                               (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                               (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                               (return_call_ref $ProcedureInvoker
                                                (local.get $proc)
                                                (local.get $noargs)
                                                (local.get $inv)))
                         (else (return (local.get $fallback)))))))
               (else (return (local.get $val))))

           (unreachable))

     (func $struct-type-property-predicate->descriptor
           (param $proc (ref $Closure))   ;; predicate closure
           (result (ref eq))              ;; descriptor or #f

           (local $free (ref $Free))
           (local $len  i32)
           (local $prop (ref eq))
           (local $tag  (ref eq))

           (local.set $free (struct.get $Closure $free (local.get $proc)))
           (local.set $len  (array.len (local.get $free)))
           (if (i32.lt_u (local.get $len) (i32.const 2))
               (then (return (global.get $false))))

           (local.set $prop (array.get $Free (local.get $free) (i32.const 0)))
           (local.set $tag  (array.get $Free (local.get $free) (i32.const 1)))

           (if (i32.eqz (ref.test (ref $StructTypeProperty) (local.get $prop)))
               (then (return (global.get $false))))
           (if (i32.eqz (ref.eq (local.get $prop) (local.get $tag)))
               (then (return (global.get $false))))

           (local.get $prop))

     (func $struct-type-property-accessor->descriptor
           (param $proc (ref $Closure))   ;; accessor closure
           (result (ref eq))              ;; descriptor or #f

           (local $free          (ref $Free))
           (local $len           i32)
           (local $prop          (ref eq))
           (local $tag           (ref eq))
           (local $desc          (ref $StructTypeProperty))
           (local $contract      (ref eq))
           (local $name-string   (ref eq))
           (local $realm-record  (ref eq))
           (local $accessor-name (ref eq))
           (local $clos-name     (ref eq))
           (local $clos-realm    (ref eq))
           (local $expected-name (ref eq))

           (local.set $free (struct.get $Closure $free (local.get $proc)))
           (local.set $len  (array.len (local.get $free)))
           (if (i32.lt_u (local.get $len) (i32.const 6))
               (then (return (global.get $false))))

           (local.set $prop (array.get $Free (local.get $free) (i32.const 0)))
           (local.set $tag  (array.get $Free (local.get $free) (i32.const 1)))

           (if (i32.eqz (ref.test (ref $StructTypeProperty) (local.get $prop)))
               (then (return (global.get $false))))
           (if (i32.eqz (ref.eq (local.get $prop) (local.get $tag)))
               (then (return (global.get $false))))

           (local.set $desc          (ref.cast (ref $StructTypeProperty) (local.get $prop)))
           (local.set $contract      (array.get $Free (local.get $free) (i32.const 2)))
           (local.set $name-string   (array.get $Free (local.get $free) (i32.const 3)))
           (local.set $realm-record  (array.get $Free (local.get $free) (i32.const 4)))
           (local.set $accessor-name (array.get $Free (local.get $free) (i32.const 5)))
           (local.set $clos-name  (struct.get $Closure $name  (local.get $proc)))
           (local.set $clos-realm (struct.get $Closure $realm (local.get $proc)))

           ;; Contract metadata must be #f or a string.
           (if (i32.eqz (ref.eq (local.get $contract) (global.get $false)))
               (then (if (i32.eqz (ref.test (ref $String) (local.get $contract)))
                         (then (return (global.get $false))))))

           ;; Cached property name string must remain a string when present.
           (if (i32.eqz (ref.eq (local.get $name-string) (global.get $false)))
               (then (if (i32.eqz (ref.test (ref $String) (local.get $name-string)))
                         (then (return (global.get $false))))))

           ;; Realm metadata must be #f or a symbol, matching the closure field.
           (if (i32.eqz (ref.eq (local.get $realm-record) (global.get $false)))
               (then (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm-record)))
                         (then (return (global.get $false))))))
           (if (i32.eqz (ref.eq (local.get $clos-realm) (local.get $realm-record)))
               (then (return (global.get $false))))

           ;; Accessor names must agree with closure metadata and descriptor hints.
           (if (i32.eqz (ref.eq (local.get $accessor-name) (global.get $false)))
               (then (if (i32.eqz (ref.test (ref $String) (local.get $accessor-name)))
                         (then (return (global.get $false))))))
           (if (i32.eqz (ref.eq (struct.get $StructTypeProperty $accessor-name-info (local.get $desc))
                                (local.get $accessor-name)))
               (then (return (global.get $false))))
           (local.set $expected-name
                      (if (result (ref eq))
                          (ref.eq (local.get $accessor-name) (global.get $false))
                          (then
                           (ref.cast (ref eq)
                                     (call $string->symbol/checked
                                           (call $string-append/2
                                                 (ref.cast (ref $String) (local.get $name-string))
                                                 (global.get $string:accessor-suffix)))))
                          (else
                           (ref.cast (ref eq)
                                     (call $string->symbol/checked
                                           (ref.cast (ref $String) (local.get $accessor-name)))))))
           (if (i32.eqz (ref.eq (local.get $clos-name) (local.get $expected-name)))
               (then (return (global.get $false))))

           (local.get $prop))
     )))

;; struct-type-property-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Implement public struct type property predicate helpers.
(define struct-type-property-predicate-runtime-only-helpers
  (list
   (core-runtime-helper
    '$struct-type-property?
    "$struct-type-property?"
    (lambda ()
      `(func $struct-type-property? (type $Prim1)
             (param $v (ref eq))             ;; any/c
             (result (ref eq))

             (if (result (ref eq))
                 (ref.test (ref $StructTypeProperty) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))

   (core-runtime-helper
    '$struct-type-property-accessor-procedure?
    "$struct-type-property-accessor-procedure?"
    (lambda ()
      `(func $struct-type-property-accessor-procedure? (type $Prim1)
             (param $v (ref eq))             ;; procedure?
             (result (ref eq))

             (local $clos (ref $Closure))
             (local $prop (ref eq))

             (if (i32.eqz (ref.test (ref $Closure) (local.get $v)))
                 (then (return (global.get $false))))

             (local.set $clos (ref.cast (ref $Closure) (local.get $v)))
             (local.set $prop (call $struct-type-property-accessor->descriptor
                                    (local.get $clos)))

             (if (result (ref eq))
                 (ref.eq (local.get $prop) (global.get $false))
                 (then (global.get $false))
                 (else (global.get $true))))))

   (core-runtime-helper
    '$struct-type-property-predicate-procedure?
    "$struct-type-property-predicate-procedure?"
    (lambda ()
      `(func $struct-type-property-predicate-procedure? (type $Prim02)
             (param $v          (ref eq))  ;; procedure?
             (param $prop-info  (ref eq))  ;; optional struct-type-property? (#f default)
             (result            (ref eq))

             (local $clos     (ref $Closure))
             (local $prop     (ref eq))
             (local $expected (ref eq))

             (local.set $expected (global.get $false))
             (if (ref.eq (local.get $prop-info) (global.get $false))
                 (then)
                 (else
                  (if (i32.eqz (ref.test (ref $StructTypeProperty) (local.get $prop-info)))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:struct-type-property-predicate-procedure?)
                                  (global.get $string:struct-type-property-or-false)
                                  (local.get $prop-info))
                            (unreachable)))
                  (local.set $expected (local.get $prop-info))))

             (if (i32.eqz (ref.test (ref $Closure) (local.get $v)))
                 (then (return (global.get $false))))

             (local.set $clos (ref.cast (ref $Closure) (local.get $v)))
             (local.set $prop (call $struct-type-property-predicate->descriptor
                                    (local.get $clos)))

             (if (ref.eq (local.get $prop) (global.get $false))
                 (then (return (global.get $false))))

             (if (result (ref eq))
                 (ref.eq (local.get $expected) (global.get $false))
                 (then (global.get $true))
                 (else
                  (if (result (ref eq))
                      (ref.eq (local.get $prop) (local.get $expected))
                      (then (global.get $true))
                      (else (global.get $false))))))))))

;; struct-type-property-descriptor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Implement struct type property descriptor constructors.
(define struct-type-property-descriptor-runtime-only-helpers
  (list
   (core-runtime-helper
    '$make-struct-type-property-descriptor
    "$make-struct-type-property-descriptor"
    (lambda ()
      `(func $make-struct-type-property-descriptor
             (param $name               (ref eq))
             (param $guard-info         (ref eq))
             (param $supers             (ref eq))
             (param $can-impersonate    (ref eq))
             (param $accessor-name-info (ref eq))

             (result (ref $StructTypeProperty))

             (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
                 (then (call $raise-argument-error/internal (local.get $name))
                       (unreachable)))

             (call $make-struct-type-property-descriptor/checked
                   (ref.cast (ref $Symbol) (local.get $name))
                   (local.get $guard-info)
                   (local.get $supers)
                   (local.get $can-impersonate)
                   (local.get $accessor-name-info)))))

   (core-runtime-helper
    '$make-struct-type-property-descriptor/checked
    "$make-struct-type-property-descriptor/checked"
    (lambda ()
      `(func $make-struct-type-property-descriptor/checked
             (param $name               (ref $Symbol))
             (param $guard-info         (ref eq))
             (param $supers             (ref eq))
             (param $can-impersonate    (ref eq))
             (param $accessor-name-info (ref eq))

             (result (ref $StructTypeProperty))

             (local $guard        (ref eq))
             (local $supers-list  (ref eq))
             (local $impersonate  (ref eq))
             (local $accessor-tag (ref eq))

             (local.set $guard (local.get $guard-info))
             (if (ref.eq (local.get $guard) (global.get $missing))
                 (then (local.set $guard (global.get $false))))

             (local.set $supers-list (local.get $supers))
             (if (ref.eq (local.get $supers-list) (global.get $missing))
                 (then (local.set $supers-list (global.get $null)))
                 (else (if (ref.eq (local.get $supers-list) (global.get $false))
                           (then (local.set $supers-list (global.get $null))))))

             (local.set $impersonate (local.get $can-impersonate))
             (if (ref.eq (local.get $impersonate) (global.get $missing))
                 (then (local.set $impersonate (global.get $false))))

             (local.set $accessor-tag (local.get $accessor-name-info))
             (if (ref.eq (local.get $accessor-tag) (global.get $missing))
                 (then (local.set $accessor-tag (global.get $false))))

             (struct.new $StructTypeProperty
                         (i32.const 0)
                         (local.get $name)
                         (local.get $guard)
                         (local.get $supers-list)
                         (local.get $impersonate)
                         (local.get $accessor-tag)
                         (global.get $false)
                         (global.get $false)))))))

;; struct-type-property-table-runtime-only-helpers : (listof core-runtime-helper?)
;;   Implement struct type property table and attachment helpers.
(define struct-type-property-table-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-type-property-table-runtime-only-helpers
   '(
     (func $struct-type-property-table-empty
           (result (ref $HashEqMutable))

           (ref.cast (ref $HashEqMutable)
                     (call $make-empty-hasheq)))

     (func $struct-type-property-table-copy
           (param $table (ref $HashEqMutable))
           (result (ref $HashEqMutable))

           (local $alist (ref eq))
           (local $copy  (ref eq))

           (local.set $alist (call $hasheq->list/plain/checked (local.get $table)))
           (local.set $copy  (call $make-hasheq (local.get $alist)))
           (ref.cast (ref $HashEqMutable) (local.get $copy)))

     (func $struct-type-property-merge-list!
           (param $table (ref $HashEqMutable))
           (param $list  (ref eq))
           (result (ref $HashEqMutable))

           (local $cursor (ref eq))
           (local $cell   (ref $Pair))
           (local $entry  (ref $Pair))
           (local $prop   (ref $StructTypeProperty))
           (local $val    (ref eq))

           (local.set $cursor (local.get $list))
           (block $done
                  (loop $walk
                        (br_if $done (ref.eq (local.get $cursor) (global.get $null)))

                        (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                        (local.set $entry
                                   (ref.cast (ref $Pair)
                                             (struct.get $Pair $a (local.get $cell))))
                        (local.set $prop
                                   (ref.cast (ref $StructTypeProperty)
                                             (struct.get $Pair $a (local.get $entry))))
                        (local.set $val (struct.get $Pair $d (local.get $entry)))

                        (call $hasheq-set!/mutable/checked
                              (local.get $table)
                              (ref.cast (ref eq) (local.get $prop))
                              (local.get $val))

                        (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                        (br $walk)))
           (local.get $table))

     (func $struct-type-property-guard-apply
           (param $prop  (ref $StructTypeProperty))
           (param $value (ref eq))
           (param $sti   (ref eq))
           (result (ref eq))

           (local $guard (ref eq))
           (local $proc  (ref $Procedure))
           (local $inv   (ref $ProcedureInvoker))
           (local $args  (ref $Args))

           (local.set $guard (struct.get $StructTypeProperty $guard-info (local.get $prop)))
           (if (ref.eq (local.get $guard) (global.get $false))
               (then (return (local.get $value))))

           (local.set $proc (ref.cast (ref $Procedure) (local.get $guard)))
           (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
           (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
           (array.set $Args (local.get $args) (i32.const 0) (local.get $value))
           (array.set $Args (local.get $args) (i32.const 1) (local.get $sti))
           (call_ref $ProcedureInvoker
                     (local.get $proc)
                     (local.get $args)
                     (local.get $inv)))

     (func $raise-prop:checked-procedure-contract
           (param $message (ref eq))

           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks
                                   (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $struct-type-property-attach!
           (param $prop     (ref $StructTypeProperty))
           (param $value    (ref eq))
           (param $table    (ref $HashEqMutable))
           (param $sti      (ref eq))
           (param $sentinel (ref eq))
           (result          i32)

           (local $processed        (ref eq))
           (local $existing         (ref eq))
           (local $sealed           i32)
           (local $supers           (ref eq))
           (local $cursor           (ref eq))
           (local $cell             (ref $Pair))
           (local $entry            (ref $Pair))
           (local $entry-raw        (ref eq))
           (local $super-prop       (ref $StructTypeProperty))
           (local $converter        (ref $Procedure))
           (local $converter-raw    (ref eq))
           (local $conv-inv         (ref $ProcedureInvoker))
           (local $conv-args        (ref $Args))
           (local $converted        (ref eq))
           (local $equal+hash-array (ref $Array))
           (local $equal+hash-info  (ref $Array))
           (local $equal+hash-count i32)
           (local $equal+hash-index i32)
           (local $equal+hash-proc  (ref eq))
           (local $equal+hash-required-arity i32)
           (local $object-name-index i32)
           (local $object-name-init-count-raw (ref eq))
           (local $object-name-init-count i32)
           (local $object-name-sti-tail (ref eq))
           (local $procedure-index i32)
           (local $procedure-init-count-raw (ref eq))
           (local $procedure-init-count i32)
           (local $procedure-sti-tail (ref eq))
           (local $checked-procedure-init-count-raw (ref eq))
           (local $checked-procedure-init-count i32)
           (local $checked-procedure-super (ref eq))

           (local.set $sealed (i32.const 0))
           (local.set $processed
                      (call $struct-type-property-guard-apply
                            (local.get $prop)
                            (local.get $value)
                            (local.get $sti)))

           ;; Built-in property guards live here because the runtime creates
           ;; these property descriptors directly.
           ;;
           ;; --- prop:custom-write
           (if (call $symbol=?/i32
                     (struct.get $StructTypeProperty $name (local.get $prop))
                     (global.get $symbol:prop:custom-write))
               (then
                (if (ref.eq (call $procedure? (local.get $processed))
                            (global.get $false))
                    (then (call $raise-argument-error1
                                (global.get $symbol:guard-for-prop:custom-write)
                                (global.get $string:guard-for-prop:custom-write-contract)
                                (local.get $processed))
                          (unreachable)))
                (if (i32.eqz
                     (call $procedure-arity-includes?/checked/i32
                           (ref.cast (ref $Procedure) (local.get $processed))
                           (i32.const 3)))
                    (then (call $raise-argument-error1
                                (global.get $symbol:guard-for-prop:custom-write)
                                (global.get $string:guard-for-prop:custom-write-contract)
                                (local.get $processed))
                          (unreachable)))))

           ;; --- prop:object-name
           (if (call $symbol=?/i32
                     (struct.get $StructTypeProperty $name (local.get $prop))
                     (global.get $symbol:object-name))
               (then
                (if (ref.eq (call $exact-nonnegative-integer?
                                  (local.get $processed))
                            (global.get $true))
                    (then
                     (local.set $object-name-index
                                (i32.shr_u
                                 (i31.get_u
                                  (ref.cast (ref i31) (local.get $processed)))
                                 (i32.const 1)))
                     ;; `sti` is the internal guard-info list:
                     ;; (name init-count auto-count accessor mutator immutables super #f).
                     (local.set $object-name-sti-tail
                                (struct.get $Pair $d
                                            (ref.cast (ref $Pair)
                                                      (local.get $sti))))
                     (local.set $object-name-init-count-raw
                                (struct.get $Pair $a
                                            (ref.cast (ref $Pair)
                                                      (local.get $object-name-sti-tail))))
                     (local.set $object-name-init-count
                                (i32.shr_u
                                 (i31.get_u
                                  (ref.cast (ref i31)
                                            (local.get $object-name-init-count-raw)))
                                 (i32.const 1)))
                     (if (i32.ge_u (local.get $object-name-index)
                                   (local.get $object-name-init-count))
                         (then (call $raise-guard-for-prop:object-name-field-index
                                     (local.get $object-name-index)
                                     (local.get $object-name-init-count))
                               (unreachable))))
                    (else
                     (if (ref.eq (call $procedure? (local.get $processed))
                                 (global.get $false))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:guard-for-prop:object-name)
                                     (global.get $string:guard-for-prop:object-name-contract)
                                     (local.get $processed))
                               (unreachable)))
                     (if (i32.eqz
                          (call $procedure-arity-includes?/checked/i32
                                (ref.cast (ref $Procedure) (local.get $processed))
                                (i32.const 1)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:guard-for-prop:object-name)
                                     (global.get $string:guard-for-prop:object-name-contract)
                                     (local.get $processed))
                               (unreachable)))))))

           ;; --- prop:procedure
           (if (call $symbol=?/i32
                     (struct.get $StructTypeProperty $name (local.get $prop))
                     (global.get $symbol:procedure))
               (then
                (if (ref.eq (call $exact-nonnegative-integer?
                                  (local.get $processed))
                            (global.get $true))
                    (then
                     (local.set $procedure-index
                                (i32.shr_u
                                 (i31.get_u
                                  (ref.cast (ref i31) (local.get $processed)))
                                 (i32.const 1)))
                     (local.set $procedure-sti-tail
                                (struct.get $Pair $d
                                            (ref.cast (ref $Pair)
                                                      (local.get $sti))))
                     (local.set $procedure-init-count-raw
                                (struct.get $Pair $a
                                            (ref.cast (ref $Pair)
                                                      (local.get $procedure-sti-tail))))
                     (local.set $procedure-init-count
                                (i32.shr_u
                                 (i31.get_u
                                  (ref.cast (ref i31)
                                            (local.get $procedure-init-count-raw)))
                                 (i32.const 1)))
                     (if (i32.ge_u (local.get $procedure-index)
                                   (local.get $procedure-init-count))
                         (then (call $raise-make-struct-type:proc-spec-index
                                     (local.get $processed)
                                     (local.get $procedure-init-count))
                               (unreachable))))
                    (else
                     (if (ref.eq (call $procedure? (local.get $processed))
                                 (global.get $false))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:make-struct-type)
                                     (global.get $string:prop:procedure-contract)
                                     (local.get $processed))
                               (unreachable)))))))

           ;; --- prop:checked-procedure
           (if (call $symbol=?/i32
                     (struct.get $StructTypeProperty $name (local.get $prop))
                     (global.get $symbol:checked-procedure))
               (then
                (local.set $checked-procedure-super
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $sti))
                                 (i32.const 6)))
                (if (i32.eqz
                     (ref.eq (local.get $checked-procedure-super)
                             (global.get $false)))
                    (then (call $raise-prop:checked-procedure-contract
                                (global.get $string:prop:checked-procedure-supertype))
                          (unreachable)))
                (local.set $checked-procedure-init-count-raw
                           (call $list-ref/checked
                                 (ref.cast (ref $Pair) (local.get $sti))
                                 (i32.const 1)))
                (local.set $checked-procedure-init-count
                           (i32.shr_u
                            (i31.get_u
                             (ref.cast (ref i31)
                                       (local.get $checked-procedure-init-count-raw)))
                            (i32.const 1)))
                (if (i32.lt_u (local.get $checked-procedure-init-count)
                              (i32.const 2))
                    (then (call $raise-prop:checked-procedure-contract
                                (global.get $string:prop:checked-procedure-too-few-fields))
                          (unreachable)))))

           ;; --- prop:equal+hash
           (if (call $symbol=?/i32
                     (struct.get $StructTypeProperty $name (local.get $prop))
                     (global.get $symbol:prop:equal+hash))
               (then
                (if (i32.eqz (ref.test (ref $Array) (local.get $processed)))
                    (then
                     (if (ref.eq (call $list? (local.get $processed))
                                 (global.get $false))
                         (then (call $raise-guard-for-prop:equal+hash-contract
                                     (local.get $processed))
                               (unreachable)))
                     (local.set $equal+hash-array
                                (ref.cast (ref $Array)
                                          (call $list->array (local.get $processed))))
                     (local.set $equal+hash-count (array.len (local.get $equal+hash-array)))
                     (if (i32.or (i32.lt_s (local.get $equal+hash-count) (i32.const 2))
                                 (i32.gt_s (local.get $equal+hash-count) (i32.const 3)))
                         (then (call $raise-guard-for-prop:equal+hash-contract
                                     (local.get $processed))
                               (unreachable)))
                     (local.set $equal+hash-index (i32.const 0))
                     (block $done
                            (loop $loop
                                  (br_if $done (i32.ge_u (local.get $equal+hash-index)
                                                         (local.get $equal+hash-count)))
                                  (local.set $equal+hash-proc
                                             (array.get $Array
                                                        (local.get $equal+hash-array)
                                                        (local.get $equal+hash-index)))
                                  (if (ref.eq (call $procedure?
                                                    (local.get $equal+hash-proc))
                                              (global.get $false))
                                      (then (call $raise-guard-for-prop:equal+hash-contract
                                                  (local.get $processed))
                                            (unreachable)))
                                  (local.set $equal+hash-required-arity
                                             (if (result i32)
                                                 (i32.eq (local.get $equal+hash-count)
                                                         (i32.const 2))
                                                 (then
                                                  (if (result i32)
                                                      (i32.eq (local.get $equal+hash-index)
                                                              (i32.const 0))
                                                      (then (i32.const 4))
                                                      (else (i32.const 3))))
                                                 (else
                                                  (if (result i32)
                                                      (i32.eq (local.get $equal+hash-index)
                                                              (i32.const 0))
                                                      (then (i32.const 3))
                                                      (else (i32.const 2))))))
                                  (if (i32.eqz
                                       (call $procedure-arity-includes?/checked/i32
                                             (ref.cast (ref $Procedure)
                                                       (local.get $equal+hash-proc))
                                             (local.get $equal+hash-required-arity)))
                                      (then (call $raise-guard-for-prop:equal+hash-contract
                                                  (local.get $processed))
                                            (unreachable)))
                                  (local.set $equal+hash-index
                                             (i32.add (local.get $equal+hash-index)
                                                      (i32.const 1)))
                                  (br $loop)))
                     (local.set $equal+hash-info
                                (array.new_fixed $Array 4
                                                 (ref.i31 (i32.shl (local.get $equal+hash-count)
                                                                    (i32.const 1)))
                                                 (array.get $Array (local.get $equal+hash-array) (i32.const 0))
                                                 (array.get $Array (local.get $equal+hash-array) (i32.const 1))
                                                 (if (result (ref eq))
                                                     (i32.eq (local.get $equal+hash-count) (i32.const 3))
                                                     (then (array.get $Array (local.get $equal+hash-array) (i32.const 2)))
                                                     (else (global.get $false)))))
                     (local.set $processed
                                (ref.cast (ref eq) (local.get $equal+hash-info))))
                    (else
                     (local.set $equal+hash-info
                                (ref.cast (ref $Array) (local.get $processed)))
                     (local.set $equal+hash-count
                                (i32.shr_u
                                 (i31.get_u (ref.cast (ref i31)
                                                      (array.get $Array (local.get $equal+hash-info)
                                                                  (i32.const 0))))
                                 (i32.const 1)))
                     (if (i32.or (i32.lt_s (local.get $equal+hash-count) (i32.const 2))
                                 (i32.gt_s (local.get $equal+hash-count) (i32.const 3)))
                         (then (call $raise-guard-for-prop:equal+hash-contract
                                     (local.get $value))
                               (unreachable)))))))

           ;; --- prop:authentic
           (if (i32.eq (call $symbol=?/i32
                                   (struct.get $StructTypeProperty $name (local.get $prop))
                                   (global.get $symbol:prop:authentic))
                            (i32.const 1))
               (then (local.set $processed (global.get $true))))
           (local.set $existing
                      (call $hasheq-ref/plain
                            (ref.cast (ref eq) (local.get $table))
                            (ref.cast (ref eq) (local.get $prop))
                            (local.get $sentinel)))

           (if (ref.eq (local.get $existing) (local.get $sentinel))
               (then
                (call $hasheq-set!/mutable/checked
                      (local.get $table)
                      (ref.cast (ref eq) (local.get $prop))
                      (local.get $processed))
                (if (i32.eq (call $symbol=?/i32
                                   (struct.get $StructTypeProperty $name (local.get $prop))
                                   (global.get $symbol:prop:sealed))
                             (i32.const 1))
                    (then (local.set $sealed (i32.const 1))))
                (local.set $supers (struct.get $StructTypeProperty $supers (local.get $prop)))
                (block $done
                       (loop $walk
                             (br_if $done (ref.eq (local.get $supers) (global.get $null)))
                             (if (i32.eqz (ref.test (ref $Pair) (local.get $supers)))
                                 (then (call $raise-argument-error/internal (local.get $supers))
                                       (unreachable)))
                             (local.set $cell (ref.cast (ref $Pair) (local.get $supers)))
                             (local.set $entry-raw (struct.get $Pair $a (local.get $cell)))
                             (if (i32.eqz (ref.test (ref $Pair) (local.get $entry-raw)))
                                 (then (call $raise-argument-error/internal (local.get $entry-raw))
                                       (unreachable)))
                             (local.set $entry (ref.cast (ref $Pair) (local.get $entry-raw)))
                             (local.set $super-prop
                                        (ref.cast (ref $StructTypeProperty)
                                                  (struct.get $Pair $a (local.get $entry))))
                             (local.set $converter-raw (struct.get $Pair $d (local.get $entry)))
                             (if (ref.eq (call $procedure? (local.get $converter-raw))
                                         (global.get $false))
                                 (then (call $raise-argument-error/internal (local.get $converter-raw))
                                       (unreachable)))
                             (local.set $converter (ref.cast (ref $Procedure) (local.get $converter-raw)))
                             (local.set $conv-inv (struct.get $Procedure $invoke (local.get $converter)))
                             (local.set $conv-args (array.new $Args (global.get $null) (i32.const 1)))
                             (array.set $Args (local.get $conv-args) (i32.const 0) (local.get $processed))
                             (local.set $converted
                                        (call_ref $ProcedureInvoker
                                                  (local.get $converter)
                                                  (local.get $conv-args)
                                                  (local.get $conv-inv)))
                             (local.set $sealed
                                        (i32.or (local.get $sealed)
                                                (call $struct-type-property-attach!
                                                      (local.get $super-prop)
                                                      (local.get $converted)
                                                      (local.get $table)
                                                      (local.get $sti)
                                                      (local.get $sentinel))))
                             (local.set $supers (struct.get $Pair $d (local.get $cell)))
                             (br $walk))))
               (else
                (if (i32.eqz (ref.eq (local.get $existing) (local.get $processed)))
                    (then (call $raise-argument-error/internal (local.get $value))
                          (unreachable))
                    (else
                     (if (i32.eq (call $symbol=?/i32
                                       (struct.get $StructTypeProperty $name (local.get $prop))
                                       (global.get $symbol:prop:sealed))
                                 (i32.const 1))
                         (then (local.set $sealed (i32.const 1))))))))
           (local.get $sealed))

     (func $struct-type-property-table-has-name?/i32
           (param $table (ref $HashEqMutable))
           (param $name  (ref $Symbol))
           (result i32)

           (local $alist  (ref eq))
           (local $cursor (ref eq))
           (local $cell   (ref $Pair))
           (local $entry  (ref $Pair))
           (local $entry-raw (ref eq))
           (local $prop   (ref $StructTypeProperty))

           (local.set $alist (call $hasheq->list/plain/checked (local.get $table)))
           (local.set $cursor (local.get $alist))
           (block $done
                  (loop $walk
                        (br_if $done (ref.eq (local.get $cursor) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                            (then (call $raise-argument-error/internal (local.get $cursor))
                                  (unreachable)))
                        (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                        (local.set $entry-raw (struct.get $Pair $a (local.get $cell)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $entry-raw)))
                            (then (call $raise-argument-error/internal (local.get $entry-raw))
                                  (unreachable)))
                        (local.set $entry (ref.cast (ref $Pair) (local.get $entry-raw)))
                        (local.set $prop
                                   (ref.cast (ref $StructTypeProperty)
                                             (struct.get $Pair $a (local.get $entry))))
                        (if (i32.eq (call $symbol=?/i32
                                           (struct.get $StructTypeProperty $name (local.get $prop))
                                           (local.get $name))
                                     (i32.const 1))
                            (then (return (i32.const 1))))
                        (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                        (br $walk)))
           (i32.const 0))
     )))

;; struct-type-property-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Implement struct type property construction and normalization helpers.
(define struct-type-property-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-type-property-constructor-runtime-only-helpers
   '(
     (func $struct-type-info-for-guard
           (param $std            (ref $StructType))
           (param $name           (ref $Symbol))
           (param $init-count     i32)
           (param $auto-count     i32)
           (param $super          (ref eq))
           (param $super-count-fx (ref eq))
           (param $immutables     (ref eq))
           (result (ref eq))

           (local $init-fx          (ref eq))
           (local $auto-fx          (ref eq))
           (local $immutables-list  (ref eq))
           (local $accessor         (ref eq))
           (local $mutator          (ref eq))
           (local $list             (ref eq))

           (local.set $init-fx (ref.i31 (i32.shl (local.get $init-count) (i32.const 1))))
           (local.set $auto-fx (ref.i31 (i32.shl (local.get $auto-count) (i32.const 1))))
           (local.set $immutables-list (local.get $immutables))
           (if (ref.eq (local.get $immutables-list) (global.get $false))
               (then (local.set $immutables-list (global.get $null))))
           (local.set $accessor
                      (call $make-struct-accessor/checked
                            (local.get $std)
                            (local.get $super-count-fx)
                            (local.get $name)))
           (local.set $mutator
                      (call $make-struct-mutator/checked
                            (local.get $std)
                            (local.get $super-count-fx)))
           (local.set $list (global.get $null))
           (local.set $list (call $cons (global.get $false) (local.get $list)))
           (local.set $list (call $cons (local.get $super) (local.get $list)))
           (local.set $list (call $cons (local.get $immutables-list) (local.get $list)))
           (local.set $list (call $cons (local.get $mutator) (local.get $list)))
           (local.set $list (call $cons (local.get $accessor) (local.get $list)))
           (local.set $list (call $cons (local.get $auto-fx) (local.get $list)))
           (local.set $list (call $cons (local.get $init-fx) (local.get $list)))
           (local.set $list (call $cons (ref.cast (ref eq) (local.get $name)) (local.get $list)))
           (local.get $list))

     (func $struct-type-properties-normalize
           (param $has-super i32)
           (param $super     (ref null $StructType))
           (param $raw       (ref eq))
           (result           (ref eq))

           (local $table (ref $HashEqMutable))
           (local $spec  (ref eq))
           (local $alist (ref eq))

           ;; Initialize non-defaultable locals
           (local.set $table (ref.cast (ref $HashEqMutable) (call $make-empty-hasheq)))


           (if (local.get $has-super)
               (then
                (local.set $table
                           (call $struct-type-property-table-copy
                                 (ref.cast (ref $HashEqMutable)
                                           (struct.get $StructType $properties
                                                       (ref.as_non_null (local.get $super)))))))
               (else
                (local.set $table (call $struct-type-property-table-empty))))

           (local.set $spec (local.get $raw))
           (if (ref.eq (local.get $spec) (global.get $missing))
               (then (local.set $spec (global.get $null))))
           (if (ref.eq (local.get $spec) (global.get $false))
               (then (local.set $spec (global.get $null))))

           (if (ref.eq (local.get $spec) (global.get $null))
               (then (return (ref.cast (ref eq) (local.get $table)))))

           (if (ref.test (ref $HashEqMutable) (local.get $spec))
               (then
                (local.set $alist
                           (call $hasheq->list/plain/checked
                                 (ref.cast (ref $HashEqMutable) (local.get $spec))))
                (local.set $spec (local.get $alist))))

           (drop (call $struct-type-property-merge-list!
                       (local.get $table)
                       (local.get $spec)))

           (ref.cast (ref eq) (local.get $table)))

     (func $raise-make-struct-type-property:name
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type-property)
                 (global.get $string:symbol?)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type-property:guard
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type-property)
                 (global.get $string:make-struct-type-property-guard)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type-property:supers
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type-property)
                 (global.get $string:make-struct-type-property-supers)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type-property:accessor-name
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type-property)
                 (global.get $string:make-struct-type-property-accessor-name)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type-property:contract-str
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type-property)
                 (global.get $string:make-struct-type-property-contract-str)
                 (local.get $bad))
           (unreachable))

     (func $raise-make-struct-type-property:realm
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:make-struct-type-property)
                 (global.get $string:symbol?)
                 (local.get $bad))
           (unreachable))

     (func $raise-guard-for-prop:object-name-field-index
           (param $field-index i32)
           (param $init-count  i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 6)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (global.get $symbol:guard-for-prop:object-name)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:guard-for-prop:object-name-field-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $field-index) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:make-struct-type-initialized-field-count))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $init-count) (i32.const 1)))))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (drop (call $raise
                       (call $exn:fail:contract/make
                             (local.get $message)
                             (call $current-continuation-marks (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $raise-guard-for-prop:equal+hash-contract
           (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:guard-for-prop:equal+hash)
                 (global.get $string:guard-for-prop:equal+hash-contract)
                 (local.get $bad))
           (unreachable))

     (func $make-struct-type-property
           (param $name               (ref eq))  ;; symbol
           ;; optional parameters (defaults in parentheses):
           (param $guard-info         (ref eq))  ;; guard/#f ('#f)
           (param $supers-spec        (ref eq))  ;; list of (cons prop proc)/#f ('())
           (param $can-impersonate?   (ref eq))  ;; any/c (#f)
           (param $accessor-name-info (ref eq))  ;; symbol/#f (#f)
           (param $contract-info      (ref eq))  ;; string/symbol/#f (#f)
           (param $realm-info         (ref eq))  ;; symbol/#f ('racket)
           (result                    (ref eq))

           (local $name-sym         (ref $Symbol))
           (local $name-string      (ref $String))
           (local $guard            (ref eq))
           (local $supers           (ref eq))
           (local $impersonate      (ref eq))
           (local $accessor-name    (ref eq))
           (local $contract-str     (ref eq))
           (local $realm            (ref eq))
           (local $prop             (ref $StructTypeProperty))
           (local $pred             (ref eq))
           (local $acc              (ref eq))
           (local $pred-free        (ref $Free))
           (local $acc-free         (ref $Free))
           (local $supers-cursor    (ref eq))
           (local $supers-cell      (ref $Pair))
           (local $supers-entry     (ref $Pair))
           (local $supers-entry-raw (ref eq))
           (local $super-prop       (ref $StructTypeProperty))
           (local $super-prop-raw   (ref eq))
           (local $super-proc       (ref $Procedure))
           (local $super-proc-raw   (ref eq))
           (local $closure-name     (ref eq))

           ;; Validate property name and capture its string form.
           (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
               (then (call $raise-make-struct-type-property:name (local.get $name))
                     (unreachable)))
           (local.set $name-sym    (ref.cast (ref $Symbol) (local.get $name)))
           (local.set $name-string (ref.cast (ref $String)
                                             (call $symbol->immutable-string
                                                   (local.get $name-sym))))

           ;; Default optional arguments.
           (local.set $guard         (global.get $false))
           (local.set $supers        (global.get $null))
           (local.set $impersonate   (global.get $false))
           (local.set $accessor-name (global.get $false))
           (local.set $contract-str  (global.get $false))
           (local.set $realm         (global.get $symbol:racket))
           (local.set $closure-name
                      (call $string->symbol/checked
                            (call $string-append/2
                                  (local.get $name-string)
                                  (global.get $string:accessor-suffix))))

           ;; Guard: allow #f, a procedure, or the symbol 'can-impersonate.
           (if (ref.eq (local.get $guard-info) (global.get $missing))
               (then)
               (else
                (if (ref.eq (local.get $guard-info) (global.get $false))
                    (then)
                    (else
                     (if (ref.test (ref $Symbol) (local.get $guard-info))
                         (then
                          (if (i32.eq (call $symbol=?/i32 (local.get $guard-info)
                                            (global.get $symbol:can-impersonate))
                                      (i32.const 1))
                              (then (local.set $impersonate (global.get $true)))
                              (else (call $raise-make-struct-type-property:guard
                                          (local.get $guard-info))
                                    (unreachable))))
                         (else
                          (if (ref.eq (call $procedure? (local.get $guard-info))
                                      (global.get $false))
                              (then (call $raise-make-struct-type-property:guard
                                          (local.get $guard-info))
                                    (unreachable)))
                          (if (i32.eqz
                               (call $procedure-arity-includes?/checked/i32
                                     (ref.cast (ref $Procedure) (local.get $guard-info))
                                     (i32.const 2)))
                              (then (call $raise-make-struct-type-property:guard
                                          (local.get $guard-info))
                                    (unreachable)))
                          (local.set $guard (local.get $guard-info))))))))

           ;; Supers: expect a list of (cons prop proc) pairs.
           (if (ref.eq (local.get $supers-spec) (global.get $missing))
               (then)
               (else
                (if (ref.eq (local.get $supers-spec) (global.get $false))
                    (then)
                    (else
                     (local.set $supers        (local.get $supers-spec))
                     (local.set $supers-cursor (local.get $supers))
                     (block $done
                            (loop $walk
                                  (br_if $done (ref.eq (local.get $supers-cursor)
                                                       (global.get $null)))
                                  (if (i32.eqz (ref.test (ref $Pair)
                                                         (local.get $supers-cursor)))
                                      (then (call $raise-make-struct-type-property:supers
                                                  (local.get $supers-spec))
                                            (unreachable)))
                                  (local.set $supers-cell
                                             (ref.cast (ref $Pair)
                                                       (local.get $supers-cursor)))
                                  (local.set $supers-entry-raw
                                             (struct.get $Pair $a (local.get $supers-cell)))
                                  (if (i32.eqz (ref.test (ref $Pair) (local.get $supers-entry-raw)))
                                      (then (call $raise-make-struct-type-property:supers
                                                  (local.get $supers-spec))
                                            (unreachable)))
                                  (local.set $supers-entry
                                             (ref.cast (ref $Pair) (local.get $supers-entry-raw)))
                                  (local.set $super-prop-raw
                                             (struct.get $Pair $a (local.get $supers-entry)))
                                  (if (i32.eqz (ref.test (ref $StructTypeProperty)
                                                         (local.get $super-prop-raw)))
                                      (then (call $raise-make-struct-type-property:supers
                                                  (local.get $supers-spec))
                                            (unreachable)))
                                  (local.set $super-prop
                                             (ref.cast (ref $StructTypeProperty)
                                                       (local.get $super-prop-raw)))
                                  (local.set $super-proc-raw
                                             (struct.get $Pair $d (local.get $supers-entry)))
                                  (if (ref.eq (call $procedure? (local.get $super-proc-raw))
                                              (global.get $false))
                                      (then (call $raise-make-struct-type-property:supers
                                                  (local.get $supers-spec))
                                            (unreachable)))
                                  (local.set $super-proc
                                             (ref.cast (ref $Procedure) (local.get $super-proc-raw)))
                                  (if (i32.eqz
                                       (call $procedure-arity-includes?/checked/i32
                                             (local.get $super-proc)
                                             (i32.const 1)))
                                      (then (call $raise-make-struct-type-property:supers
                                                  (local.get $supers-spec))
                                            (unreachable)))
                                  (local.set $supers-cursor
                                             (struct.get $Pair $d (local.get $supers-cell)))
                                  (br $walk)))))))

           ;; can-impersonate? treats any non-#f as true.
           (if (ref.eq (local.get $can-impersonate?) (global.get $missing))
               (then)
               (else
                (if (ref.eq (local.get $can-impersonate?) (global.get $false))
                    (then (local.set $impersonate (global.get $false)))
                    (else (local.set $impersonate (global.get $true))))))

           ;; Accessor name: allow #f or symbol (converted to string).
           (if (ref.eq (local.get $accessor-name-info) (global.get $missing))
               (then)
               (else
                (if (ref.eq (local.get $accessor-name-info) (global.get $false))
                    (then)
                    (else
                     (if (ref.test (ref $Symbol) (local.get $accessor-name-info))
                         (then
                          (local.set $accessor-name
                                     (ref.cast (ref eq)
                                               (ref.cast (ref $String)
                                                         (call $symbol->immutable-string
                                                               (ref.cast (ref $Symbol)
                                                                         (local.get $accessor-name-info))))))
                          (local.set $closure-name (local.get $accessor-name-info)))
                         (else (call $raise-make-struct-type-property:accessor-name
                                     (local.get $accessor-name-info))
                               (unreachable)))))))

           ;; Contract string: allow #f, string, or symbol (converted to string).
           (if (ref.eq (local.get $contract-info) (global.get $missing))
               (then)
               (else
                (if (ref.eq (local.get $contract-info) (global.get $false))
                    (then)
                    (else
                     (if (ref.test (ref $Symbol) (local.get $contract-info))
                         (then (local.set $contract-str
                                          (ref.cast (ref eq)
                                                    (ref.cast (ref $String)
                                                              (call $symbol->immutable-string
                                                                    (ref.cast (ref $Symbol)
                                                                              (local.get $contract-info)))))))
                         (else
                          (if (ref.test (ref $String) (local.get $contract-info))
                              (then (local.set $contract-str
                                               (ref.cast (ref eq)
                                                         (ref.cast (ref $String)
                                                                   (local.get $contract-info)))))
                              (else (call $raise-make-struct-type-property:contract-str
                                          (local.get $contract-info))
                                    (unreachable)))))))))

           ;; Realm defaults to 'racket unless a symbol is supplied.
           (if (ref.eq (local.get $realm-info) (global.get $missing))
               (then)
               (else
                (if (ref.eq (local.get $realm-info) (global.get $false))
                    (then)
                    (else
                     (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm-info)))
                         (then (call $raise-make-struct-type-property:realm
                                     (local.get $realm-info))
                               (unreachable)))
                     (local.set $realm (local.get $realm-info))))))

           ;; Construct descriptor and cached procedures.
           (local.set $prop
                      (call $make-struct-type-property-descriptor/checked
                            (local.get $name-sym)
                            (local.get $guard)
                            (local.get $supers)
                            (local.get $impersonate)
                            (local.get $accessor-name)))

           (local.set $pred-free
                      (array.new_fixed $Free 2
                                       (ref.cast (ref eq) (local.get $prop))
                                       (ref.cast (ref eq) (local.get $prop))))
           (local.set $pred
                      (struct.new $Closure
                                  (i32.const 0)
                                  (global.get $false)
                                  (ref.i31 (i32.const 2))     ; arity = 1
                                  (global.get $false)
                                  (ref.func $invoke-closure)
                                  (global.get $false)
                                  (ref.func $struct-type-property-predicate)
                                  (local.get $pred-free)))

           (local.set $acc-free
                      (array.new_fixed $Free 6
                                       (ref.cast (ref eq) (local.get $prop))
                                       (ref.cast (ref eq) (local.get $prop))
                                       (local.get $contract-str)
                                       (ref.cast (ref eq) (local.get $name-string))
                                       (local.get $realm)
                                       (local.get $accessor-name)))
           (local.set $acc
                      (struct.new $Closure
                                  (i32.const 0)
                                  (local.get $closure-name)
                                  (ref.i31 (i32.const -4))    ; arity-at-least 1 (optional fallback)
                                  (local.get $realm)
                                  (ref.func $invoke-closure)
                                  (global.get $false)
                                  (ref.func $struct-type-property-accessor)
                                  (local.get $acc-free)))

           (struct.set $StructTypeProperty $predicate-cache
                       (local.get $prop) (local.get $pred))
           (struct.set $StructTypeProperty $accessor-cache
                       (local.get $prop) (local.get $acc))

           (array.new_fixed $Values 3
                            (ref.cast (ref eq) (local.get $prop))
                            (ref.cast (ref eq) (local.get $pred))
                            (ref.cast (ref eq) (local.get $acc))))

     ;; unsafe-make-struct-type-property/guard-calls-no-arguments :
     ;;   symbol? [guard] [supers] [can-impersonate?] [accessor-name] [contract-str] [realm] -> values
     ;;   CS exposes this unsafe operation as an alias of
     ;;   make-struct-type-property. The "guard calls no arguments" part is
     ;;   compile-time knowledge for optimizers; WebRacket delegates to the
     ;;   same runtime implementation as the safe constructor.
     (func $unsafe-make-struct-type-property/guard-calls-no-arguments
           (type $Prim67)
           (param $name               (ref eq)) ;; symbol?
           (param $guard-info         (ref eq)) ;; optional guard/#f, default = #f
           (param $supers-spec        (ref eq)) ;; optional list/#f, default = '()
           (param $can-impersonate?   (ref eq)) ;; optional any/c, default = #f
           (param $accessor-name-info (ref eq)) ;; optional symbol/#f, default = #f
           (param $contract-info      (ref eq)) ;; optional string/symbol/#f, default = #f
           (param $realm-info         (ref eq)) ;; optional symbol/#f, default = 'racket
           (result                    (ref eq))
           (call $make-struct-type-property
                 (local.get $name)
                 (local.get $guard-info)
                 (local.get $supers-spec)
                 (local.get $can-impersonate?)
                 (local.get $accessor-name-info)
                 (local.get $contract-info)
                 (local.get $realm-info)))
     )))

;; struct-procedure-invoker-runtime-only-helpers : (listof core-runtime-helper?)
;;   Implement the invoker for structs that behave as procedures.
(define struct-procedure-invoker-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-procedure-invoker-runtime-only-helpers
   '(
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
                (if (ref.eq (call $procedure? (local.get $target))
                            (global.get $false))
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
           (if (ref.eq (call $procedure? (local.get $prop-val))
                       (global.get $false))
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
     )))

;; struct-procedure-runtime-only-helpers : (listof core-runtime-helper?)
;;   Implement helpers for structs that behave as procedures.
(define struct-procedure-runtime-only-helpers
  (function-forms->runtime-helpers
   'struct-procedure-runtime-only-helpers
   '(
     ;; applicable-struct?/i32 : any/c -> i32
     ;;   Check whether a struct instance has a prop:procedure association.
     (func $applicable-struct?/i32
           (param $v (ref eq)) ;; candidate value
           (result   i32)
           (local $type     (ref $StructType))
           (local $sentinel (ref eq))
           (local $prop-val (ref eq))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (return (i32.const 0))))
           (local.set $type
                      (struct.get $Struct $type
                                  (ref.cast (ref $Struct) (local.get $v))))
           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $type)
                           (ref.cast (ref $StructTypeProperty)
                                      (global.get $prop:procedure))
                            (local.get $sentinel)))
           (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel))))

     ;; checked-procedure-struct?/i32 : any/c -> i32
     ;;   Check whether a struct instance has prop:checked-procedure. This is
     ;;   a keyword-procedure protocol marker, not enough by itself to make
     ;;   a structure an ordinary Racket procedure.
     (func $checked-procedure-struct?/i32
           (param $v (ref eq)) ;; candidate value
           (result   i32)
           (local $type     (ref $StructType))
           (local $sentinel (ref eq))
           (local $prop-val (ref eq))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (return (i32.const 0))))
           (local.set $type
                      (struct.get $Struct $type
                                  (ref.cast (ref $Struct) (local.get $v))))
           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $type)
                            (ref.cast (ref $StructTypeProperty)
                                      (global.get $prop:checked-procedure))
                            (local.get $sentinel)))
           (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel))))

     ;; struct-procedure-delegate : any/c -> (or/c procedure? #f)
     ;;   Resolve a field-based prop:procedure struct to its delegate
     ;;   procedure. This mirrors invoke-struct's field-index case so
     ;;   reflection such as procedure-arity sees the real callable arity.
     (func $struct-procedure-delegate
           (param $v (ref eq))
           (result   (ref eq))

           (local $struct      (ref $Struct))
           (local $type        (ref $StructType))
           (local $sentinel    (ref eq))
           (local $prop-val    (ref eq))
           (local $idx         i32)
           (local $super       (ref eq))
           (local $super-type  (ref null $StructType))
           (local $super-count i32)
           (local $abs-index   i32)
           (local $fields      (ref $Array))
           (local $target      (ref eq))

           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (return (global.get $false))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
           (local.set $type   (struct.get $Struct $type (local.get $struct)))
           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $type)
                            (ref.cast (ref $StructTypeProperty)
                                      (global.get $prop:procedure))
                            (local.get $sentinel)))
           (if (ref.eq (local.get $prop-val) (local.get $sentinel))
               (then (return (global.get $false))))
           (if (i32.eqz (ref.test (ref i31) (local.get $prop-val)))
               (then (return (global.get $false))))
           (local.set $idx (i32.shr_u
                            (i31.get_u (ref.cast (ref i31) (local.get $prop-val)))
                            (i32.const 1)))
           (local.set $super (struct.get $StructType $super (local.get $type)))
           (local.set $super-type (ref.null $StructType))
           (local.set $super-count (i32.const 0))
           (if (i32.eqz (ref.eq (local.get $super) (global.get $false)))
               (then (local.set $super-type (ref.cast (ref $StructType) (local.get $super)))
                     (local.set $super-count
                                (struct.get $StructType $field-count
                                            (local.get $super-type)))))
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (local.set $abs-index (i32.add (local.get $super-count) (local.get $idx)))
           (if (i32.ge_u (local.get $abs-index) (array.len (local.get $fields)))
               (then (return (global.get $false))))
           (local.set $target (array.get $Array (local.get $fields) (local.get $abs-index)))
           (if (result (ref eq))
               (ref.eq (call $procedure? (local.get $target))
                       (global.get $true))
               (then (local.get $target))
               (else (global.get $false))))

     ;; procedure-struct-type? : struct-type? -> boolean?
     ;;   Check whether instances of a structure type act as procedures.
     (func $procedure-struct-type? (type $Prim1)
           (param $type-raw (ref eq)) ;; struct-type?
           (result          (ref eq))

           (local $type     (ref $StructType))
           (local $sentinel (ref eq))
           (local $prop-val (ref eq))

           (if (i32.eqz (ref.test (ref $StructType) (local.get $type-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:procedure-struct-type?)
                           (global.get $string:struct-type?)
                           (local.get $type-raw))
                     (unreachable)))
           (local.set $type (ref.cast (ref $StructType) (local.get $type-raw)))
           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $type)
                            (ref.cast (ref $StructTypeProperty)
                                      (global.get $prop:procedure))
                            (local.get $sentinel)))
           (if (result (ref eq))
               (ref.eq (local.get $prop-val) (local.get $sentinel))
               (then (global.get $false))
               (else (global.get $true))))

     ;; checked-procedure-check-and-extract :
     ;;   struct-type? any/c (any/c any/c any/c -> any/c) any/c any/c -> any/c
     ;;   Runtime helper for prop:checked-procedure. Racket CS uses this in
     ;;   keyword-procedure fast paths: if `v` is an instance of `type`, has
     ;;   prop:checked-procedure, and its first field accepts v1/v2, return
     ;;   its second field; otherwise delegate to the fallback procedure.
     ;;   WebRacket does not implement impersonators yet, so raw struct
     ;;   field access matches unsafe-struct*-ref for currently supported
     ;;   values.
     (func $checked-procedure-check-and-extract (type $Prim5)
           (param $type-raw     (ref eq)) ;; struct-type?
           (param $v            (ref eq)) ;; candidate checked procedure
           (param $fallback-raw (ref eq)) ;; fallback procedure
           (param $v1           (ref eq)) ;; checker argument 1
           (param $v2           (ref eq)) ;; checker argument 2
           (result              (ref eq))

           (local $type        (ref $StructType))
           (local $fallback    (ref $Procedure))
           (local $struct      (ref $Struct))
           (local $struct-type (ref $StructType))
           (local $sentinel    (ref eq))
           (local $prop-val    (ref eq))
           (local $fields      (ref $Array))
           (local $checker-raw (ref eq))
           (local $checker     (ref $Procedure))
           (local $extracted   (ref eq))
           (local $args2       (ref $Args))
           (local $args3       (ref $Args))
           (local $accepted    (ref eq))
           (local $primitive   (ref $PrimitiveProcedure))

           (if (i32.eqz (ref.test (ref $StructType) (local.get $type-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:checked-procedure-check-and-extract)
                           (global.get $string:struct-type?)
                           (local.get $type-raw))
                     (unreachable)))
           (local.set $type (ref.cast (ref $StructType) (local.get $type-raw)))

           (if (ref.eq (call $procedure? (local.get $fallback-raw))
                       (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:checked-procedure-check-and-extract)
                           (global.get $string:procedure?)
                           (local.get $fallback-raw))
                     (unreachable)))
           (local.set $fallback (ref.cast (ref $Procedure) (local.get $fallback-raw)))

           ;; Racket expands keyword calls to primitive sort through
           ;; checked-procedure-check-and-extract when the primitive is
           ;; imported as a module variable. Return a small keyword-apply
           ;; primitive instead of delegating to keyword-procedure-extract.
           (if (ref.test (ref $PrimitiveProcedure) (local.get $v))
               (then
                (local.set $primitive (ref.cast (ref $PrimitiveProcedure) (local.get $v)))
                (if (call $string=?/i32
                          (call $symbol->string
                                (struct.get $PrimitiveProcedure $name (local.get $primitive)))
                          (call $symbol->string (global.get $symbol:sort)))
                    (then
                     (return
                      (struct.new $PrimitiveProcedure
                                  (i32.const 0)
                                  (global.get $symbol:sort)
                                  (ref.i31 (i32.const 8))
                                  (global.get $the-racket/primitive-realm)
                                  (ref.func $primitive-invoke:shape-4)
                                  (ref.func $sort/keyword-apply)
                                  (global.get $false)))))
                (if (call $string=?/i32
                          (call $symbol->string
                                (struct.get $PrimitiveProcedure $name (local.get $primitive)))
                          (call $symbol->string (global.get $symbol:vector-sort)))
                    (then
                     (return
                      (struct.new $PrimitiveProcedure
                                  (i32.const 0)
                                  (global.get $symbol:vector-sort)
                                  (ref.i31 (i32.const 8))
                                  (global.get $the-racket/primitive-realm)
                                  (ref.func $primitive-invoke:shape-4)
                                  (ref.func $vector-sort/keyword-apply)
                                  (global.get $false)))))
                (if (call $string=?/i32
                          (call $symbol->string
                                (struct.get $PrimitiveProcedure $name (local.get $primitive)))
                          (call $symbol->string (global.get $symbol:vector-sort!)))
                    (then
                     (return
                      (struct.new $PrimitiveProcedure
                                  (i32.const 0)
                                  (global.get $symbol:vector-sort!)
                                  (ref.i31 (i32.const 8))
                                  (global.get $the-racket/primitive-realm)
                                  (ref.func $primitive-invoke:shape-4)
                                  (ref.func $vector-sort!/keyword-apply)
                                  (global.get $false)))))))

           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then
                (local.set $args3 (array.new_fixed $Args 3
                                                   (local.get $v)
                                                   (local.get $v1)
                                                   (local.get $v2)))
                (return_call_ref $ProcedureInvoker
                                 (local.get $fallback)
                                 (local.get $args3)
                                 (struct.get $Procedure $invoke (local.get $fallback)))))

           (local.set $struct      (ref.cast (ref $Struct) (local.get $v)))
           (local.set $struct-type (struct.get $Struct $type (local.get $struct)))

           (if (i32.eqz (call $struct-type-is-a?/i32
                               (ref.cast (ref eq) (local.get $struct-type))
                               (ref.cast (ref eq) (local.get $type))))
               (then
                (local.set $args3 (array.new_fixed $Args 3
                                                   (local.get $v)
                                                   (local.get $v1)
                                                   (local.get $v2)))
                (return_call_ref $ProcedureInvoker
                                 (local.get $fallback)
                                 (local.get $args3)
                                 (struct.get $Procedure $invoke (local.get $fallback)))))

           (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $struct-type)
                            (ref.cast (ref $StructTypeProperty)
                                      (global.get $prop:checked-procedure))
                            (local.get $sentinel)))
           (if (ref.eq (local.get $prop-val) (local.get $sentinel))
               (then
                (local.set $args3 (array.new_fixed $Args 3
                                                   (local.get $v)
                                                   (local.get $v1)
                                                   (local.get $v2)))
                (return_call_ref $ProcedureInvoker
                                 (local.get $fallback)
                                 (local.get $args3)
                                 (struct.get $Procedure $invoke (local.get $fallback)))))

           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (local.set $checker-raw
                      (array.get $Array (local.get $fields) (i32.const 0)))
           (if (ref.eq (call $procedure? (local.get $checker-raw))
                       (global.get $false))
               (then (call $raise-application-not-procedure (local.get $checker-raw))
                     (unreachable)))
           (local.set $checker (ref.cast (ref $Procedure) (local.get $checker-raw)))
           (local.set $extracted (array.get $Array (local.get $fields) (i32.const 1)))
           (local.set $args2 (array.new_fixed $Args 2
                                              (local.get $v1)
                                              (local.get $v2)))
           (local.set $accepted
                      (call $expect-one-value
                            (call_ref $ProcedureInvoker
                                      (local.get $checker)
                                      (local.get $args2)
                                      (struct.get $Procedure $invoke (local.get $checker)))))
           (if (result (ref eq))
               (ref.eq (local.get $accepted) (global.get $false))
               (then
                (local.set $args3 (array.new_fixed $Args 3
                                                   (local.get $v)
                                                   (local.get $v1)
                                                   (local.get $v2)))
                (return_call_ref $ProcedureInvoker
                                 (local.get $fallback)
                                 (local.get $args3)
                                 (struct.get $Procedure $invoke (local.get $fallback))))
               (else (local.get $extracted))))
     )))

;; struct-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers in monolithic runtime order.
(define struct-all-runtime-helpers
  (append
   struct-basic-runtime-only-helpers
   struct-conversion-runtime-only-helpers
   struct-descriptor-runtime-only-helpers
   struct-format-runtime-only-helpers
   struct-prefab-basic-runtime-only-helpers
   struct-prefab-key-runtime-only-helpers
   struct-prefab-key-validation-runtime-only-helpers
   struct-prefab-key-accessor-runtime-only-helpers
   struct-prefab-chain-runtime-only-helpers
   struct-prefab-struct-type-runtime-only-helpers
   struct-prefab-metadata-runtime-only-helpers
   struct-prefab-immutables-runtime-only-helpers
   struct-prefab-constructor-runtime-only-helpers
   struct-type-constructor-runtime-only-helpers
   struct-accessor-runtime-only-helpers
   struct-constructor-wrapper-runtime-only-helpers
   struct-constructor-runtime-only-helpers
   struct-mutator-runtime-only-helpers
   struct-field-mutator-runtime-only-helpers
   struct-predicate-runtime-only-helpers
   struct-field-accessor-runtime-only-helpers
   struct-procedure-predicate-runtime-only-helpers
   struct-guarded-constructor-runtime-only-helpers
   struct-type-property-lookup-runtime-only-helpers
   struct-type-property-closure-runtime-only-helpers
   struct-type-property-predicate-runtime-only-helpers
   struct-type-property-descriptor-runtime-only-helpers
   struct-type-property-table-runtime-only-helpers
   struct-type-property-constructor-runtime-only-helpers
   struct-procedure-invoker-runtime-only-helpers
   struct-procedure-runtime-only-helpers
   (list
    ;; initialize-prefab-struct-type-registry : -> void
    ;;   Lazily allocate the global prefab struct type registry.
    (core-runtime-helper
     '$initialize-prefab-struct-type-registry
     "$initialize-prefab-struct-type-registry"
     (lambda ()
       `(func $initialize-prefab-struct-type-registry
              (if (ref.is_null (global.get $prefab-struct-type-registry))
                  (then
                   (global.set $prefab-struct-type-registry
                               (ref.cast (ref $HashEqMutable)
                                         (call $make-empty-hasheq)))))))))))

;; struct-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers available in the standalone core runtime.
(define struct-core-runtime-helpers
  (append struct-base-core-runtime-helpers
          (select-runtime-helpers struct-all-runtime-helpers
                                  struct-promoted-runtime-helper-names)))

;; struct-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers that still depend on monolithic runtime globals.
(define struct-runtime-only-helpers
  (remove-runtime-helpers struct-all-runtime-helpers
                          struct-promoted-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define struct-core-helper-index
    (make-core-runtime-helper-index struct-core-runtime-helpers))

  (define struct-helper-index
    (make-core-runtime-helper-index
     (append struct-core-runtime-helpers
             struct-runtime-only-helpers)))

  (check-not-false (member '$prop:procedure
                           struct-property-identity-global-names))
  (check-not-false (member '$prop:checked-procedure
                           struct-property-identity-global-names))
  (for ([name (in-list struct-equal+hash-recur-global-names)])
    (check-false (member name struct-property-identity-global-names)))
  (check-equal? (map struct-global-form-name
                     struct-equal+hash-recur-global-forms)
                struct-equal+hash-recur-global-names)
  (check-equal? (length struct-property-identity-global-forms)
                (length struct-property-identity-initializer-forms))
  (check-true
   (for/and ([form (in-list struct-property-identity-initializer-forms)])
     (not (equal+hash-recur-global-name? (struct-global-set-target form)))))

  (check-equal?
   (map core-runtime-helper-name
        (select-runtime-helpers struct-core-runtime-helpers
                                struct-promoted-runtime-helper-names))
   struct-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (struct-core-predicate-runtime-helper-forms struct-core-helper-index))
   struct-core-predicate-runtime-helper-names)

  (check-equal?
   (map form-name (struct-procedure-invoker-runtime-helper-forms struct-helper-index))
   struct-procedure-invoker-runtime-only-helper-names)

  (check-equal?
   (map form-name (struct-prefab-registry-runtime-helper-forms struct-helper-index))
   struct-prefab-registry-runtime-helper-names)

  (check-equal?
   (map form-name (struct-basic-runtime-helper-forms struct-helper-index))
   struct-basic-runtime-helper-names)

  (check-equal?
   (map form-name (struct-prefab-runtime-helper-forms struct-helper-index))
   struct-prefab-runtime-helper-names)

  (check-equal?
   (map form-name (struct-construction-runtime-helper-forms struct-helper-index))
   struct-construction-runtime-helper-names)

  (check-equal?
   (map form-name (struct-constructor-access-runtime-helper-forms struct-helper-index))
   struct-constructor-access-runtime-helper-names)

  (check-equal?
   (map form-name (struct-type-property-runtime-helper-forms struct-helper-index))
   struct-type-property-runtime-helper-names)

  (check-equal?
   (map form-name (struct-procedure-runtime-helper-forms struct-helper-index))
   struct-procedure-runtime-only-helper-names))
