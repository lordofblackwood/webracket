#lang racket

(provide struct-basic-runtime-only-helper-names
         struct-conversion-runtime-only-helper-names
         struct-descriptor-runtime-only-helper-names
         struct-format-runtime-only-helper-names
         struct-prefab-basic-runtime-only-helper-names
         struct-prefab-key-runtime-only-helper-names
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
