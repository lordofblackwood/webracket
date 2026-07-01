#lang racket

(provide struct-basic-runtime-only-helper-names
         struct-conversion-runtime-only-helper-names
         struct-core-runtime-helpers
         struct-runtime-only-helpers)

(require "../core-helper.rkt")

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

;; struct-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers that depend on monolithic runtime globals.
(define struct-runtime-only-helpers
  (append
   struct-basic-runtime-only-helpers
   struct-conversion-runtime-only-helpers
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
