#lang racket

(provide struct-basic-runtime-only-helper-names
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
         struct-procedure-predicate-runtime-only-helper-names
         struct-core-runtime-helpers
         struct-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/immediates.rkt")

;; struct-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers that can be emitted in core runtime.
(define struct-core-runtime-helpers
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

;; struct-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic struct helpers.
(define struct-basic-runtime-only-helper-names
  '($struct?
    $struct-type?
    $raise-check-struct-type
    $check-struct-type
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
  '($make-prefab-struct))

;; struct-procedure-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for struct procedure predicates.
(define struct-procedure-predicate-runtime-only-helper-names
  '($struct-constructor-procedure?
    $struct-predicate-procedure?
    $struct-accessor-procedure?
    $struct-mutator-procedure?))

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

     (func $raise-check-struct-type (unreachable))

     (func $check-struct-type
           (param $name (ref $String))
           (param $v    (ref eq))
           (result      (ref eq))

           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $false))
               (then (local.get $v)) ;; allow #f
               (else (if (result (ref eq))
                         (ref.test (ref $StructType) (local.get $v))
                         (then (local.get $v))
                         (else (call $raise-check-struct-type)
                               #;(call $raise-argument-error
                                       (local.get $name)
                                       (call $str-struct-type-or-false)
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
     (func $raise-format/display:struct:expected-struct (unreachable))

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
               (then (call $raise-format/display:struct:expected-struct)))

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
               (then (call $raise-argument-error/internal (local.get $v))
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
     (func $prefab-struct-field-mutable?/i32
           (param $std   (ref $StructType))
           (param $index i32)
           (result       i32)

           (local $metadata      (ref eq))
           (local $key           (ref eq))
           (local $mutables      (ref $Vector))

           (local.set $metadata (struct.get $StructType $immutables (local.get $std)))
           (if (i32.eqz (call $prefab-metadata?/i32 (local.get $metadata)))
               (then (return (i32.const 1))))
           (local.set $key (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $metadata))))
           (local.set $mutables (call $simple-prefab-key-mutables/checked (local.get $key)))
           (call $simple-prefab-mutable-mask-member?/i32
                 (local.get $mutables)
                 (local.get $index)))
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
               (then (call $raise-argument-error/internal (local.get $key))
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
                         (then (call $raise-argument-error/internal (local.get $key))
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
               (then (call $raise-argument-error/internal (local.get $key))
                     (unreachable)))
           (if (i32.and
                (i32.ge_s (local.get $explicit-count) (i32.const 0))
                (i32.ne
                 (i32.add (local.get $explicit-count) (local.get $parent-total))
                 (local.get $field-count)))
               (then (call $raise-argument-error/internal (local.get $key))
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

;; struct-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers that depend on monolithic runtime globals.
(define struct-runtime-only-helpers
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
   struct-procedure-predicate-runtime-only-helpers
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
