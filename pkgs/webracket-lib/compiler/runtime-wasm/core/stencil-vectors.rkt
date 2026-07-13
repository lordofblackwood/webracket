#lang racket

(provide stencil-vector-runtime-string-constants
         stencil-vector-runtime-symbol-constants
         stencil-vector-core-runtime-helpers
         stencil-vector-core-runtime-helper-forms
         stencil-vector-runtime-helper-forms
         stencil-vector-runtime-only-helpers)

(require "../core-helper.rkt")

;; stencil-vector-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by stencil-vector helpers and errors.
(define stencil-vector-runtime-string-constants
  '((stencil-vector?               "stencil-vector?")
    (stencil-vector-mask-contract  "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))")
    (stencil-vector-mask-count     "mask does not match given number of items")
    (stencil-vector-remove-missing "mask of stencil vector does not have all bits in removal mask")
    (stencil-vector-add-present    "mask of stencil vector already has bits in addition mask")
    (stencil-vector-add-count      "addition mask does not match given number of items")
    (stencil-vector-truncate-wide  "new mask has more slots than stencil vector")))

;; stencil-vector-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used as `who` names by stencil-vector helpers.
(define stencil-vector-runtime-symbol-constants
  '(stencil-vector
    $system-stencil-vector
    stencil-vector-length
    stencil-vector-mask
    stencil-vector-ref
    stencil-vector-set!
    stencil-vector-update
    $system-stencil-vector-update
    $system-stencil-vector-truncate!))

;; stencil-vector-all-runtime-helper-names : (listof symbol?)
;;   Preserve the full stencil-vector helper emission order.
(define stencil-vector-all-runtime-helper-names
  '($stencil-vector-mask-width
    $$stencil-vector-mask-valid?/i32
    $$stencil-vector-mask/i32
    $$stencil-vector-popcount/i32
    $raise-stencil-vector-index-out-of-range/who
    $$make-stencil-vector/checked
    $stencil-vector
    $$system-stencil-vector
    $stencil-vector?
    $$stencil-vector?
    $$system-stencil-vector?
    $stencil-vector-length
    $$stencil-vector-length
    $stencil-vector-mask
    $$stencil-vector-mask
    $stencil-vector-ref
    $$stencil-vector-ref
    $stencil-vector-set!
    $$stencil-vector-set!
    $$stencil-vector-update/core
    $stencil-vector-update
    $$system-stencil-vector-update
    $$system-stencil-vector-truncate!))

;; stencil-vector-core-runtime-helper-names : (listof symbol?)
;;   Name stencil-vector helpers available in the standalone core runtime.
(define stencil-vector-core-runtime-helper-names
  '($stencil-vector-mask-width
    $$stencil-vector-mask-valid?/i32
    $$stencil-vector-popcount/i32
    $$make-stencil-vector/checked
    $stencil-vector?
    $$stencil-vector?
    $$system-stencil-vector?
    $$stencil-vector-update/core))

;; stencil-vector-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only stencil-vector helper emission order.
(define stencil-vector-runtime-only-helper-names
  (remove* stencil-vector-core-runtime-helper-names
           stencil-vector-all-runtime-helper-names))

;; stencil-vector-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate all stencil-vector helpers.
(define stencil-vector-all-runtime-helpers
  (list
   ;; stencil-vector-mask-width : -> exact-nonnegative-integer?
   ;;   WebRacket uses the 32-bit Racket/BC-compatible width. Racket CS
   ;;   uses 58 on 64-bit platforms, but WebRacket fixnums cannot encode
   ;;   masks that wide.
   (core-runtime-helper
    '$stencil-vector-mask-width
    "$stencil-vector-mask-width"
    (lambda ()
      `(func $stencil-vector-mask-width (type $Prim0)
             (result (ref eq))
             (ref.i31 (i32.const 52))))) ;; 26 << 1


   ;; $stencil-vector-mask-valid?/i32 : i32 -> i32
   ;;   Check whether mask is in [0, 2^26).
   (core-runtime-helper
    '$$stencil-vector-mask-valid?/i32
    "$$stencil-vector-mask-valid?/i32"
    (lambda ()
      `(func $$stencil-vector-mask-valid?/i32
             (param $mask i32)
             (result i32)
             (i32.and (i32.ge_s (local.get $mask) (i32.const 0))
                      (i32.lt_s (local.get $mask) (i32.const 67108864))))))


   ;; $stencil-vector-mask/i32 : symbol? any/c -> i32
   ;;   Validate a public stencil-vector mask and return the unboxed value.
   (core-runtime-helper
    '$$stencil-vector-mask/i32
    "$$stencil-vector-mask/i32"
    (lambda ()
      `(func $$stencil-vector-mask/i32
             (param $who    (ref eq))
             (param $mask-v (ref eq))
             (result        i32)
             (local $bits i32)
             (local $mask i32)
             (if (i32.eqz (ref.test (ref i31) (local.get $mask-v)))
                 (then
                  (call $raise-argument-error1
                        (local.get $who)
                        (global.get $string:stencil-vector-mask-contract)
                        (local.get $mask-v))
                  (unreachable)))
             (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $mask-v))))
             (if (i32.and (local.get $bits) (i32.const 1))
                 (then
                  (call $raise-argument-error1
                        (local.get $who)
                        (global.get $string:stencil-vector-mask-contract)
                        (local.get $mask-v))
                  (unreachable)))
             (local.set $mask (i32.shr_s (local.get $bits) (i32.const 1)))
             (if (i32.eqz (call $$stencil-vector-mask-valid?/i32 (local.get $mask)))
                 (then
                  (call $raise-argument-error1
                        (local.get $who)
                        (global.get $string:stencil-vector-mask-contract)
                        (local.get $mask-v))
                  (unreachable)))
             (local.get $mask))))


   ;; $stencil-vector-popcount/i32 : i32 -> i32
   ;;   Count the active slots in a stencil-vector mask.
   (core-runtime-helper
    '$$stencil-vector-popcount/i32
    "$$stencil-vector-popcount/i32"
    (lambda ()
      `(func $$stencil-vector-popcount/i32
             (param $mask i32)
             (result i32)
             (i32.popcnt (local.get $mask)))))


   ;; raise-stencil-vector-index-out-of-range/who : symbol? i32 -> none
   ;;   Raise a catchable error for an out-of-range dense slot index.
   (core-runtime-helper
    '$raise-stencil-vector-index-out-of-range/who
    "$raise-stencil-vector-index-out-of-range/who"
    (lambda ()
      `(func $raise-stencil-vector-index-out-of-range/who
             (param $who (ref eq))
             (param $i   i32)
             (call $raise-argument-error1
                   (local.get $who)
                   (global.get $string:valid-vector-index)
                   (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
             (unreachable))))


   ;; $make-stencil-vector/checked : i32 i32 (ref $Array) -> stencil-vector?
   ;;   Build a stencil vector from an already-validated mask and slot array.
   (core-runtime-helper
    '$$make-stencil-vector/checked
    "$$make-stencil-vector/checked"
    (lambda ()
      `(func $$make-stencil-vector/checked
             (param $system? i32)
             (param $mask    i32)
             (param $slots   (ref $Array))
             (result         (ref $StencilVector))
             (struct.new $StencilVector
                         (i32.const 0)
                         (local.get $system?)
                         (local.get $mask)
                         (local.get $slots)))))


   ;; stencil-vector : mask value ... -> stencil-vector?
   ;;   Construct a normal stencil vector. The number of values must equal
   ;;   popcount(mask).
   (core-runtime-helper
    '$stencil-vector
    "$stencil-vector"
    (lambda ()
      `(func $stencil-vector (type $Prim>=1)
             (param $mask-v (ref eq)) ;; exact-nonnegative-integer mask
             (param $vals   (ref eq)) ;; list of payload values
             (result        (ref eq))
             (local $mask i32)
             (local $len  i32)
             (local $arr  (ref $Array))
             (local $pair (ref $Pair))
             (local $as   (ref $Args))
             (local $i    i32)
             (if (ref.test (ref $Pair) (local.get $mask-v))
                 (then
                  (local.set $pair (ref.cast (ref $Pair) (local.get $mask-v)))
                  (local.set $vals (struct.get $Pair $d (local.get $pair)))
                  (local.set $mask-v (struct.get $Pair $a (local.get $pair)))))
             (if (ref.test (ref $Args) (local.get $mask-v))
                 (then
                  (local.set $as (ref.cast (ref $Args) (local.get $mask-v)))
                  (local.set $len (array.len (local.get $as)))
                  (if (i32.eqz (local.get $len))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:stencil-vector)
                                  (global.get $string:stencil-vector-mask-contract)
                                  (local.get $mask-v))
                            (unreachable)))
                  (local.set $mask-v (array.get $Args (local.get $as) (i32.const 0)))
                  (local.set $vals (global.get $null))
                  (local.set $i (local.get $len))
                  (block $args-done
                         (loop $args-loop
                               (br_if $args-done (i32.le_u (local.get $i) (i32.const 1)))
                               (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                               (local.set $vals
                                          (call $cons
                                                (array.get $Args (local.get $as) (local.get $i))
                                                (local.get $vals)))
                               (br $args-loop)))))
             (local.set $mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:stencil-vector)
                              (local.get $mask-v)))
             (local.set $len (call $$stencil-vector-popcount/i32 (local.get $mask)))
             (if (i32.ne (call $length/i32 (local.get $vals)) (local.get $len))
                 (then (call $raise-arguments-error
                             (global.get $symbol:stencil-vector)
                             (global.get $string:stencil-vector-mask-count)
                             (array.new_fixed $Args 0))
                       (unreachable)))
             (local.set $arr (call $list->array (local.get $vals)))
             (ref.cast (ref eq)
                       (call $$make-stencil-vector/checked
                             (i32.const 0)
                             (local.get $mask)
                             (local.get $arr))))))


   ;; $system-stencil-vector : mask value ... -> system-stencil-vector?
   ;;   Internal constructor used by Racket CS HAMT nodes.
   (core-runtime-helper
    '$$system-stencil-vector
    "$$system-stencil-vector"
    (lambda ()
      `(func $$system-stencil-vector (type $Prim>=1)
             (param $mask-v (ref eq)) ;; exact-nonnegative-integer mask
             (param $vals   (ref eq)) ;; list of payload values
             (result        (ref eq))
             (local $mask i32)
             (local $len  i32)
             (local $arr  (ref $Array))
             (local $pair (ref $Pair))
             (local $as   (ref $Args))
             (local $i    i32)
             (if (ref.test (ref $Pair) (local.get $mask-v))
                 (then
                  (local.set $pair (ref.cast (ref $Pair) (local.get $mask-v)))
                  (local.set $vals (struct.get $Pair $d (local.get $pair)))
                  (local.set $mask-v (struct.get $Pair $a (local.get $pair)))))
             (if (ref.test (ref $Args) (local.get $mask-v))
                 (then
                  (local.set $as (ref.cast (ref $Args) (local.get $mask-v)))
                  (local.set $len (array.len (local.get $as)))
                  (if (i32.eqz (local.get $len))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:$system-stencil-vector)
                                  (global.get $string:stencil-vector-mask-contract)
                                  (local.get $mask-v))
                            (unreachable)))
                  (local.set $mask-v (array.get $Args (local.get $as) (i32.const 0)))
                  (local.set $vals (global.get $null))
                  (local.set $i (local.get $len))
                  (block $args-done
                         (loop $args-loop
                               (br_if $args-done (i32.le_u (local.get $i) (i32.const 1)))
                               (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                               (local.set $vals
                                          (call $cons
                                                (array.get $Args (local.get $as) (local.get $i))
                                                (local.get $vals)))
                               (br $args-loop)))))
             (local.set $mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:$system-stencil-vector)
                              (local.get $mask-v)))
             (local.set $len (call $$stencil-vector-popcount/i32 (local.get $mask)))
             (if (i32.ne (call $length/i32 (local.get $vals)) (local.get $len))
                 (then (call $raise-arguments-error
                             (global.get $symbol:$system-stencil-vector)
                             (global.get $string:stencil-vector-mask-count)
                             (array.new_fixed $Args 0))
                       (unreachable)))
             (local.set $arr (call $list->array (local.get $vals)))
             (ref.cast (ref eq)
                       (call $$make-stencil-vector/checked
                             (i32.const 1)
                             (local.get $mask)
                             (local.get $arr))))))


   ;; stencil-vector? : any/c -> boolean?
   ;;   True only for non-system stencil vectors.
   (core-runtime-helper
    '$stencil-vector?
    "$stencil-vector?"
    (lambda ()
      `(func $stencil-vector? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq)) (ref.test (ref $StencilVector) (local.get $v))
                 (then
                  (if (result (ref eq))
                      (i32.eqz (struct.get $StencilVector $system?
                                           (ref.cast (ref $StencilVector)
                                                     (local.get $v))))
                      (then (global.get $true))
                      (else (global.get $false))))
                 (else (global.get $false))))))


   ;; $stencil-vector? : any/c -> boolean?
   ;;   True for normal and system stencil vectors.
   (core-runtime-helper
    '$$stencil-vector?
    "$$stencil-vector?"
    (lambda ()
      `(func $$stencil-vector? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $StencilVector) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; $system-stencil-vector? : any/c -> boolean?
   ;;   True only for system stencil vectors.
   (core-runtime-helper
    '$$system-stencil-vector?
    "$$system-stencil-vector?"
    (lambda ()
      `(func $$system-stencil-vector? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq)) (ref.test (ref $StencilVector) (local.get $v))
                 (then
                  (if (result (ref eq))
                      (struct.get $StencilVector $system?
                                  (ref.cast (ref $StencilVector)
                                            (local.get $v)))
                      (then (global.get $true))
                      (else (global.get $false))))
                 (else (global.get $false))))))


   ;; stencil-vector-length : stencil-vector? -> exact-nonnegative-integer?
   ;;   Return the dense slot count, i.e. popcount(mask).
   (core-runtime-helper
    '$stencil-vector-length
    "$stencil-vector-length"
    (lambda ()
      `(func $stencil-vector-length (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:stencil-vector-length)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (ref.i31
              (i32.shl
               (call $$stencil-vector-popcount/i32
                     (struct.get $StencilVector $mask
                                 (ref.cast (ref $StencilVector) (local.get $v))))
               (i32.const 1))))))


   (core-runtime-helper
    '$$stencil-vector-length
    "$$stencil-vector-length"
    (lambda ()
      `(func $$stencil-vector-length (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (call $stencil-vector-length (local.get $v)))))


   ;; stencil-vector-mask : stencil-vector? -> exact-nonnegative-integer?
   ;;   Return the bit mask that determines slot positions.
   (core-runtime-helper
    '$stencil-vector-mask
    "$stencil-vector-mask"
    (lambda ()
      `(func $stencil-vector-mask (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:stencil-vector-mask)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (ref.i31
              (i32.shl
               (struct.get $StencilVector $mask
                           (ref.cast (ref $StencilVector) (local.get $v)))
               (i32.const 1))))))


   (core-runtime-helper
    '$$stencil-vector-mask
    "$$stencil-vector-mask"
    (lambda ()
      `(func $$stencil-vector-mask (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (call $stencil-vector-mask (local.get $v)))))


   ;; stencil-vector-ref : stencil-vector? exact-nonnegative-integer? -> any/c
   ;;   Ref by dense slot index, not by mask bit number.
   (core-runtime-helper
    '$stencil-vector-ref
    "$stencil-vector-ref"
    (lambda ()
      `(func $stencil-vector-ref (type $Prim2)
             (param $v (ref eq)) ;; stencil vector
             (param $i (ref eq)) ;; dense slot index
             (result   (ref eq))
             (local $sv  (ref $StencilVector))
             (local $idx i32)
             (local $len i32)
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:stencil-vector-ref)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (local.set $sv  (ref.cast (ref $StencilVector) (local.get $v)))
             (local.set $idx
                        (call $vector-index/i32
                              (global.get $symbol:stencil-vector-ref)
                              (local.get $i)))
             (local.set $len (array.len (struct.get $StencilVector $slots (local.get $sv))))
             (if (i32.ge_u (local.get $idx) (local.get $len))
                 (then (call $raise-stencil-vector-index-out-of-range/who
                             (global.get $symbol:stencil-vector-ref)
                             (local.get $idx))
                       (unreachable)))
             (array.get $Array (struct.get $StencilVector $slots (local.get $sv)) (local.get $idx)))))


   (core-runtime-helper
    '$$stencil-vector-ref
    "$$stencil-vector-ref"
    (lambda ()
      `(func $$stencil-vector-ref (type $Prim2)
             (param $v (ref eq))
             (param $i (ref eq))
             (result   (ref eq))
             (call $stencil-vector-ref (local.get $v) (local.get $i)))))


   ;; stencil-vector-set! : stencil-vector? exact-nonnegative-integer? any/c -> void?
   ;;   Mutate the dense slot array. Racket CS exposes this for stencil
   ;;   vectors even though HAMT updates use functional update.
   (core-runtime-helper
    '$stencil-vector-set!
    "$stencil-vector-set!"
    (lambda ()
      `(func $stencil-vector-set! (type $Prim3)
             (param $v   (ref eq)) ;; stencil vector
             (param $i   (ref eq)) ;; dense slot index
             (param $val (ref eq)) ;; new value
             (result     (ref eq))
             (local $sv  (ref $StencilVector))
             (local $idx i32)
             (local $len i32)
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:stencil-vector-set!)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (local.set $sv  (ref.cast (ref $StencilVector) (local.get $v)))
             (local.set $idx
                        (call $vector-index/i32
                              (global.get $symbol:stencil-vector-set!)
                              (local.get $i)))
             (local.set $len (array.len (struct.get $StencilVector $slots (local.get $sv))))
             (if (i32.ge_u (local.get $idx) (local.get $len))
                 (then (call $raise-stencil-vector-index-out-of-range/who
                             (global.get $symbol:stencil-vector-set!)
                             (local.get $idx))
                       (unreachable)))
             (array.set $Array (struct.get $StencilVector $slots (local.get $sv)) (local.get $idx) (local.get $val))
             (global.get $void))))


   (core-runtime-helper
    '$$stencil-vector-set!
    "$$stencil-vector-set!"
    (lambda ()
      `(func $$stencil-vector-set! (type $Prim3)
             (param $v   (ref eq))
             (param $i   (ref eq))
             (param $val (ref eq))
             (result     (ref eq))
             (call $stencil-vector-set! (local.get $v) (local.get $i) (local.get $val)))))


   ;; stencil-vector-update/core : stencil-vector? remove-mask add-mask values system? -> stencil-vector?
   ;;   Functional mask update. Values are consumed in increasing add-bit order.
   (core-runtime-helper
    '$$stencil-vector-update/core
    "$$stencil-vector-update/core"
    (lambda ()
      `(func $$stencil-vector-update/core
             (param $sv          (ref $StencilVector))
             (param $remove-mask i32)
             (param $add-mask    i32)
             (param $vals        (ref eq))
             (param $system?     i32)
             (result             (ref eq))
             (local $old-mask i32)
             (local $new-mask i32)
             (local $new-len  i32)
             (local $arr      (ref $Array))
             (local $bit      i32)
             (local $old-i    i32)
             (local $new-i    i32)
             (local $vals-i   (ref eq))
             (local $pair     (ref $Pair))
             (local $who      (ref eq))
             (local.set $who
                        (if (result (ref eq))
                            (local.get $system?)
                            (then (global.get $symbol:$system-stencil-vector-update))
                            (else (global.get $symbol:stencil-vector-update))))
             (local.set $old-mask (struct.get $StencilVector $mask (local.get $sv)))
             (if (i32.ne (i32.and (local.get $old-mask) (local.get $remove-mask))
                          (local.get $remove-mask))
                 (then (call $raise-arguments-error
                             (local.get $who)
                             (global.get $string:stencil-vector-remove-missing)
                             (array.new_fixed $Args 0))
                       (unreachable)))
             (if (i32.ne (i32.and (i32.and (local.get $old-mask)
                                           (i32.xor (local.get $remove-mask) (i32.const -1)))
                                   (local.get $add-mask))
                          (i32.const 0))
                 (then (call $raise-arguments-error
                             (local.get $who)
                             (global.get $string:stencil-vector-add-present)
                             (array.new_fixed $Args 0))
                       (unreachable)))
             (if (i32.ne (call $$stencil-vector-popcount/i32 (local.get $add-mask))
                          (call $length/i32 (local.get $vals)))
                 (then (call $raise-arguments-error
                             (local.get $who)
                             (global.get $string:stencil-vector-add-count)
                             (array.new_fixed $Args 0))
                       (unreachable)))
             (local.set $new-mask
                        (i32.or (i32.and (local.get $old-mask)
                                         (i32.xor (local.get $remove-mask) (i32.const -1)))
                                (local.get $add-mask)))
             (local.set $new-len (call $$stencil-vector-popcount/i32 (local.get $new-mask)))
             (local.set $arr (array.new $Array (global.get $false) (local.get $new-len)))
             (local.set $bit (i32.const 1))
             (local.set $old-i (i32.const 0))
             (local.set $new-i (i32.const 0))
             (local.set $vals-i (local.get $vals))
             (block $done
                    (loop $loop
                          (br_if $done (i32.eqz (local.get $bit)))
                          (br_if $done (i32.ge_u (local.get $new-i) (local.get $new-len)))
                          (if (i32.ne (i32.and (local.get $old-mask) (local.get $bit)) (i32.const 0))
                              (then
                               (if (i32.eqz (i32.and (local.get $remove-mask) (local.get $bit)))
                                   (then
                                    (array.set $Array
                                               (local.get $arr)
                                               (local.get $new-i)
                                               (array.get $Array
                                                          (struct.get $StencilVector $slots (local.get $sv))
                                                          (local.get $old-i)))
                                    (local.set $new-i (i32.add (local.get $new-i) (i32.const 1)))))
                               (local.set $old-i (i32.add (local.get $old-i) (i32.const 1)))))
                          (if (i32.ne (i32.and (local.get $add-mask) (local.get $bit)) (i32.const 0))
                              (then
                               (local.set $pair (ref.cast (ref $Pair) (local.get $vals-i)))
                               (array.set $Array
                                          (local.get $arr)
                                          (local.get $new-i)
                                          (struct.get $Pair $a (local.get $pair)))
                               (local.set $vals-i (struct.get $Pair $d (local.get $pair)))
                               (local.set $new-i (i32.add (local.get $new-i) (i32.const 1)))))
                          (local.set $bit (i32.shl (local.get $bit) (i32.const 1)))
                          (br $loop)))
             (ref.cast (ref eq)
                       (call $$make-stencil-vector/checked
                             (local.get $system?)
                             (local.get $new-mask)
                             (local.get $arr))))))


   ;; stencil-vector-update : stencil-vector? remove-mask add-mask value ... -> stencil-vector?
   ;;   Checked public update for normal stencil vectors.
   (core-runtime-helper
    '$stencil-vector-update
    "$stencil-vector-update"
    (lambda ()
      `(func $stencil-vector-update (type $Prim>=3)
             (param $v        (ref eq)) ;; stencil vector
             (param $remove-v (ref eq)) ;; removal mask
             (param $add-v    (ref eq)) ;; addition mask
             (param $vals     (ref eq)) ;; replacement values
             (result          (ref eq))
             (local $sv          (ref $StencilVector))
             (local $remove-mask i32)
             (local $add-mask    i32)
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:stencil-vector-update)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (local.set $sv (ref.cast (ref $StencilVector) (local.get $v)))
             (local.set $remove-mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:stencil-vector-update)
                              (local.get $remove-v)))
             (local.set $add-mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:stencil-vector-update)
                              (local.get $add-v)))
             (call $$stencil-vector-update/core
                   (local.get $sv)
                   (local.get $remove-mask)
                   (local.get $add-mask)
                   (local.get $vals)
                   (struct.get $StencilVector $system? (local.get $sv))))))


   ;; $system-stencil-vector-update : stencil-vector? remove-mask add-mask value ... -> system-stencil-vector?
   ;;   Internal update used by the CS HAMT implementation.
   (core-runtime-helper
    '$$system-stencil-vector-update
    "$$system-stencil-vector-update"
    (lambda ()
      `(func $$system-stencil-vector-update (type $Prim>=3)
             (param $v        (ref eq)) ;; system stencil vector
             (param $remove-v (ref eq)) ;; removal mask
             (param $add-v    (ref eq)) ;; addition mask
             (param $vals     (ref eq)) ;; replacement values
             (result          (ref eq))
             (local $sv          (ref $StencilVector))
             (local $remove-mask i32)
             (local $add-mask    i32)
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:$system-stencil-vector-update)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (local.set $sv (ref.cast (ref $StencilVector) (local.get $v)))
             (local.set $remove-mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:$system-stencil-vector-update)
                              (local.get $remove-v)))
             (local.set $add-mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:$system-stencil-vector-update)
                              (local.get $add-v)))
             (call $$stencil-vector-update/core
                   (local.get $sv)
                   (local.get $remove-mask)
                   (local.get $add-mask)
                   (local.get $vals)
                   (i32.const 1)))))


   ;; $system-stencil-vector-truncate! : system-stencil-vector? mask -> void?
   ;;   Shrink/update a system stencil vector's mask in place. Used for
   ;;   intmap-shell synchronization during CS hash construction.
   (core-runtime-helper
    '$$system-stencil-vector-truncate!
    "$$system-stencil-vector-truncate!"
    (lambda ()
      `(func $$system-stencil-vector-truncate! (type $Prim2)
             (param $v      (ref eq)) ;; system stencil vector
             (param $mask-v (ref eq)) ;; new mask
             (result        (ref eq))
             (local $sv       (ref $StencilVector))
             (local $new-mask i32)
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $v)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:$system-stencil-vector-truncate!)
                             (global.get $string:stencil-vector?)
                             (local.get $v))
                       (unreachable)))
             (local.set $sv (ref.cast (ref $StencilVector) (local.get $v)))
             (local.set $new-mask
                        (call $$stencil-vector-mask/i32
                              (global.get $symbol:$system-stencil-vector-truncate!)
                              (local.get $mask-v)))
             (if (i32.gt_u (call $$stencil-vector-popcount/i32 (local.get $new-mask))
                           (array.len (struct.get $StencilVector $slots (local.get $sv))))
                 (then (call $raise-arguments-error
                             (global.get $symbol:$system-stencil-vector-truncate!)
                             (global.get $string:stencil-vector-truncate-wide)
                             (array.new_fixed $Args 0))
                       (unreachable)))
             (struct.set $StencilVector $mask (local.get $sv) (local.get $new-mask))
             (global.get $void))))
))

;; stencil-vector-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate stencil-vector helpers available in the standalone core runtime.
(define stencil-vector-core-runtime-helpers
  (select-runtime-helpers stencil-vector-all-runtime-helpers
                          stencil-vector-core-runtime-helper-names))

;; stencil-vector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate stencil-vector helpers that still depend on monolithic runtime definitions.
(define stencil-vector-runtime-only-helpers
  (remove-runtime-helpers stencil-vector-all-runtime-helpers
                          stencil-vector-core-runtime-helper-names))

;; stencil-vector-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render stencil-vector helpers in runtime assembly order.
(define (stencil-vector-runtime-helper-forms helper-index)
  (for/list ([name (in-list stencil-vector-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; stencil-vector-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted stencil-vector helpers in runtime assembly order.
(define (stencil-vector-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list stencil-vector-core-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define stencil-vector-helper-index
    (make-core-runtime-helper-index
     (append stencil-vector-core-runtime-helpers
             stencil-vector-runtime-only-helpers)))

  (define stencil-vector-core-helper-index
    (make-core-runtime-helper-index stencil-vector-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name stencil-vector-core-runtime-helpers)
   stencil-vector-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (stencil-vector-core-runtime-helper-forms stencil-vector-core-helper-index))
   stencil-vector-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (stencil-vector-runtime-helper-forms stencil-vector-helper-index))
   stencil-vector-runtime-only-helper-names))
