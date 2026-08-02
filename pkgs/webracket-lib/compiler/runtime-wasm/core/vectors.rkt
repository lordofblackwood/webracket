#lang racket

(provide vector-append-runtime-only-helper-names
         vector-argminmax-runtime-only-helper-names
         vector-build-runtime-only-helper-names
         vector-constructor-runtime-only-helper-names
         vector-copy-runtime-only-helper-names
         vector-core-runtime-helpers
         vector-runtime-string-constants
         vector-runtime-symbol-constants
         vector-dummy-array-global-forms
         vector-dummy-global-forms
         vector-error-runtime-only-helper-names
         vector-extend-runtime-only-helper-names
         vector-filter-search-runtime-only-helper-names
         vector-list-conversion-runtime-only-helper-names
         vector-map-count-runtime-only-helper-names
         vector-make-runtime-only-helper-names
         vector-mutability-runtime-only-helper-names
         vector-mutability-runtime-helper-forms
         vector-operation-runtime-only-helper-names
         vector-slice-runtime-only-helper-names
         vector-sort-runtime-only-helper-names
         vector-error-runtime-helper-forms
         vector-main-runtime-helper-forms
         vector-post-stencil-runtime-helper-forms
         vector-runtime-only-helpers)

(require "../core-helper.rkt")

;; vector-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by vector helpers and vector errors.
(define vector-runtime-string-constants
  '((vector?                    "vector?")
    (mutable-vector?            "(and/c vector? (not/c immutable?))")
    (valid-vector-index         "valid vector index")
    (valid-vector-length        "valid-vector-length?")
    (vector-extend-shorter      "new length is shorter than existing length")
    (vector-extend-new-length   "new length")
    (vector-extend-existing-length "existing length")
    (vector-index-out-of-range  ": index is out of range")
    (vector-index-out-of-range-empty ": index is out of range for empty vector")
    (vector-starting-index-out-of-range ": starting index is out of range")
    (vector-ending-index-out-of-range ": ending index is out of range")
    (vector-ending-index-before-starting-index ": ending index is smaller than starting index")
    (vector-not-enough-room-in-target ": not enough room in target vector")
    (vector-index               "\n  index: ")
    (vector-starting-index      "\n  starting index: ")
    (vector-ending-index        "\n  ending index: ")
    (vector-valid-range         "\n  valid range: [0, ")
    (vector-valid-range-close   "]")
    (vector-vector              "\n  vector: ")
    (vector-target-length       "\n  target length: ")
    (vector-needed-length       "\n  needed length: ")
    (build-vector-procedure     "(exact-nonnegative-integer? . -> . any/c)")
    (vector-unary-any-procedure "(any/c . -> . any/c)")
    (vector-unary-real-procedure "(any/c . -> . real?)")
    (vector-binary-any-procedure "(any/c any/c . -> . any/c)")
    (non-empty-vector           "(and/c vector? (lambda (v) (positive? (vector-length v))))")
    (all-vectors-same-size      ": all vectors must have same size")))

;; vector-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by vector helpers and vector errors.
(define vector-runtime-symbol-constants
  '(vector?
    make-vector
    build-vector
    vector-length
    vector-ref
    vector-set!
    vector*-length
    vector*-ref
    vector*-set!
    vector-fill!
    vector-copy
    vector-copy!
    vector-take
    vector-drop
    vector-take-right
    vector-drop-right
    vector-split-at
    vector-split-at-right
    vector->values
    vector->immutable-vector
    vector-set/copy
    vector-extend
    vector-empty?
    vector-append
    vector-map
    vector-map!
    vector-count
    vector-argmin
    vector-argmax
    vector-filter
    vector-filter-not
    vector-member
    vector-sort
    vector-sort!))

;; vector-dummy-array-global-forms : (listof datum?)
;;   Declare the shared empty internal array used by vector-like structures.
(define vector-dummy-array-global-forms
  '(
         ; The global $dummy-vector is needed when a non-nullable local variable needs
         ; initialization to a default.
         (global $dummy-array (ref $Array) (array.new $Array (global.get $false) (i32.const 0)))))

;; vector-dummy-global-forms : (listof datum?)
;;   Declare the shared dummy vector used for default local initialization.
(define vector-dummy-global-forms
  '(
        (global $dummy-vector (ref $Vector)
                (struct.new $Vector
                            (i32.const 0)          ;; hash
                            (i32.const 0)          ;; mutable
                            (global.get $dummy-array)))))

;; vector-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate manually defined vector helpers that originated in core runtime.
(define vector-base-core-runtime-helpers
  (list
   ;; vector?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a vector, 0 otherwise.
   (core-runtime-helper
    '$vector?/i32
    "$vector?/i32"
    (lambda ()
      `(func $vector?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Vector) (local.get $a)))))))

;; vector-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector mutability predicates.
(define vector-mutability-runtime-only-helper-names
  '($mutable-vector?
    $immutable-vector?))

;; vector-error-runtime-only-forms : (listof datum?)
;;   Enumerate vector error helpers used by the monolithic runtime.
(define vector-error-runtime-only-forms
  '(
        ;; Vector related exceptions
        (func $raise-check-vector/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:vector?)
                    (local.get $x)))
        (func $raise-check-vector
              (param $x (ref eq))
              (call $raise-check-vector/who
                    (global.get $symbol:vector?)
                    (local.get $x)))
        (func $raise-check-fixnum/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:fixnum?)
                    (local.get $x)))
        (func $raise-check-fixnum (param $x (ref eq))
              (call $raise-check-fixnum/who
                    (global.get $symbol:fixnum?)
                    (local.get $x)))
        (func $vector-index/i32
              (param $who (ref eq))
              (param $x   (ref eq))
              (result i32)

              (local $bits i32)
              (local $idx  i32)

              (if (i32.eqz (ref.test (ref i31) (local.get $x)))
                  (then
                   (call $raise-argument-error1
                         (local.get $who)
                         (global.get $string:exact-nonnegative-integer?)
                         (local.get $x))
                   (unreachable)))
              (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
              (if (i32.and (local.get $bits) (i32.const 1))
                  (then
                   (call $raise-argument-error1
                         (local.get $who)
                         (global.get $string:exact-nonnegative-integer?)
                         (local.get $x))
                   (unreachable)))
              (local.set $idx (i32.shr_s (local.get $bits) (i32.const 1)))
              (if (i32.lt_s (local.get $idx) (i32.const 0))
                  (then
                   (call $raise-argument-error1
                         (local.get $who)
                         (global.get $string:exact-nonnegative-integer?)
                         (local.get $x))
                   (unreachable)))
              (local.get $idx))
        (func $raise-immutable-vector/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:mutable-vector?)
                    (local.get $x)))
        (func $raise-immutable-vector
              (param $x (ref eq))
              (call $raise-immutable-vector/who
                    (global.get $symbol:vector-set!)
                    (local.get $x)))
        (func $raise-bad-vector-ref-index/who
              (param $who (ref eq))
              (param $v   (ref $Vector))
              (param $i   i32)
              (param $len i32)

              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              (local.set $out
                         (call $make-growable-array (i32.const 10)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $who)))
              (if (i32.eqz (local.get $len))
                  (then
                   (call $growable-array-add! (local.get $out)
                         (global.get $string:vector-index-out-of-range-empty)))
                  (else
                   (call $growable-array-add! (local.get $out)
                         (global.get $string:vector-index-out-of-range))))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:vector-index))
              (call $growable-array-add! (local.get $out)
                    (call $format/error-value->string
                          (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))
              (if (i32.ne (local.get $len) (i32.const 0))
                  (then
                   (call $growable-array-add! (local.get $out)
                         (global.get $string:vector-valid-range))
                   (call $growable-array-add! (local.get $out)
                         (call $format/display
                               (ref.i31
                                (i32.shl
                                 (i32.sub (local.get $len) (i32.const 1))
                                 (i32.const 1)))))
                   (call $growable-array-add! (local.get $out)
                         (global.get $string:vector-valid-range-close))))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:vector-vector))
              (call $growable-array-add! (local.get $out)
                    (call $format/error-value->string (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))
              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))
        (func $raise-bad-vector-ref-index
              (param $v (ref $Vector)) (param $i i32) (param $len i32)
              (call $raise-bad-vector-ref-index/who
                    (global.get $symbol:vector-ref)
                    (local.get $v)
                    (local.get $i)
                    (local.get $len)))
         (func $raise-bad-vector-copy-range/who
               (param $who        (ref eq))
               (param $dest       (ref $Vector))
               (param $dest-start i32)
               (param $src        (ref $Vector))
               (param $src-start  i32)
               (param $src-end    i32)

               (local $dest-len i32)
               (local $src-len  i32)
               (local $needed   i32)

               (local.set $dest-len
                          (array.len (struct.get $Vector $arr (local.get $dest))))
               (local.set $src-len
                          (array.len (struct.get $Vector $arr (local.get $src))))
               (if (i32.gt_u (local.get $dest-start) (local.get $dest-len))
                   (then (call $raise-vector-start-index-out-of-range/who
                               (local.get $who)
                               (local.get $dest)
                               (local.get $dest-start)
                               (local.get $dest-len))
                         (unreachable)))
               (if (i32.gt_u (local.get $src-start) (local.get $src-len))
                   (then (call $raise-vector-start-index-out-of-range/who
                               (local.get $who)
                               (local.get $src)
                               (local.get $src-start)
                               (local.get $src-len))
                         (unreachable)))
               (if (i32.gt_u (local.get $src-end) (local.get $src-len))
                   (then (call $raise-vector-end-index-out-of-range/who
                               (local.get $who)
                               (local.get $src)
                               (local.get $src-end)
                               (local.get $src-len))
                         (unreachable)))
               (if (i32.gt_u (local.get $src-start) (local.get $src-end))
                   (then (call $raise-vector-end-before-start/who
                               (local.get $who)
                               (local.get $src)
                               (local.get $src-start)
                               (local.get $src-end)
                               (local.get $src-len))
                         (unreachable)))
               (local.set $needed
                          (i32.add (local.get $dest-start)
                                   (i32.sub (local.get $src-end)
                                            (local.get $src-start))))
               (if (i32.gt_u (local.get $needed) (local.get $dest-len))
                   (then (call $raise-vector-target-too-small/who
                               (local.get $who)
                               (local.get $dest-len)
                               (local.get $needed))
                         (unreachable)))
               (unreachable))
         (func $raise-bad-vector-copy-range
               (param $dest (ref $Vector)) (param $dest-start i32)
               (param $src  (ref $Vector)) (param $src-start  i32) (param $src-end i32)
               (call $raise-bad-vector-copy-range/who
                     (global.get $symbol:vector-copy)
                     (local.get $dest)
                     (local.get $dest-start)
                     (local.get $src)
                     (local.get $src-start)
                     (local.get $src-end)))
         (func $raise-vector-range-index-out-of-range/who
               (param $who      (ref eq))
               (param $v        (ref $Vector))
               (param $headline (ref eq))
               (param $label    (ref eq))
               (param $idx      i32)
               (param $len      i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 10)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (local.get $headline))
               (call $growable-array-add! (local.get $out)
                     (local.get $label))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $idx) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-vector))
               (call $growable-array-add! (local.get $out)
                     (call $format/error-value->string (local.get $v)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $raise-vector-start-index-out-of-range/who
               (param $who (ref eq))
               (param $v   (ref $Vector))
               (param $idx i32)
               (param $len i32)
               (call $raise-vector-range-index-out-of-range/who
                     (local.get $who)
                     (local.get $v)
                     (global.get $string:vector-starting-index-out-of-range)
                     (global.get $string:vector-starting-index)
                     (local.get $idx)
                     (local.get $len)))
         (func $raise-vector-end-index-out-of-range/who
               (param $who (ref eq))
               (param $v   (ref $Vector))
               (param $idx i32)
               (param $len i32)
               (call $raise-vector-range-index-out-of-range/who
                     (local.get $who)
                     (local.get $v)
                     (global.get $string:vector-ending-index-out-of-range)
                     (global.get $string:vector-ending-index)
                     (local.get $idx)
                     (local.get $len)))
         (func $raise-vector-end-before-start/who
               (param $who   (ref eq))
               (param $v     (ref $Vector))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 12)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-ending-index-before-starting-index))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-ending-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $end) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-starting-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $start) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-vector))
               (call $growable-array-add! (local.get $out)
                     (call $format/error-value->string (local.get $v)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $raise-vector-target-too-small/who
               (param $who        (ref eq))
               (param $target-len i32)
               (param $needed-len i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 6)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-not-enough-room-in-target))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-target-length))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $target-len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-needed-length))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $needed-len) (i32.const 1)))))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $raise-bad-vector-take-index/who
               (param $who (ref eq))
               (param $v   (ref $Vector))
               (param $i   i32)
               (param $len i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 10)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-index-out-of-range))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:vector-vector))
               (call $growable-array-add! (local.get $out)
                     (call $format/error-value->string (local.get $v)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $raise-bad-vector-take-index
               (param $v (ref $Vector)) (param $i i32) (param $len i32)
               (call $raise-bad-vector-take-index/who
                     (global.get $symbol:vector-take)
                     (local.get $v)
                     (local.get $i)
                     (local.get $len)))


         (func $raise-make-vector:bad-length
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:make-vector)
                     (global.get $string:valid-vector-length)
                     (local.get $x)))
         (func $raise-build-vector:bad-length
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:build-vector)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))
         (func $raise-build-vector:procedure-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:build-vector)
                     (global.get $string:build-vector-procedure)
                     (local.get $x)))
         (func $raise-vector-argument-error/who
               (param $who      (ref eq))
               (param $expected (ref eq))
               (param $x        (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (local.get $expected)
                     (local.get $x)))
         (func $raise-vector-length-mismatch
               (param $who (ref eq))

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 2)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:all-vectors-same-size))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))

               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

     ))

;; vector-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector error helpers used by the monolithic runtime.
(define vector-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-error-runtime-only-helpers
   vector-error-runtime-only-forms))

;; vector-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector error helpers.
(define vector-error-runtime-only-helper-names
  (map core-runtime-helper-name vector-error-runtime-only-helpers))

;; vector-make-runtime-only-forms : (listof datum?)
;;   Enumerate make-vector helpers used by the monolithic runtime.
(define vector-make-runtime-only-forms
  '(
         (func $make-vector (type $Prim12)
               (param $k-fx   (ref eq))  ;; fixnum
               (param $val    (ref eq))  ;; optional, defaults to 0
               (result        (ref eq))

               (local $k         i32)
               (local $k-encoded i32)
               (local $k/s       i32)
               (local $v         (ref eq))  ;; possibly rewritten value
               ;; --- Type check for fixnum ---
               (if (i32.eqz (ref.test (ref i31) (local.get $k-fx)))
                   (then (call $raise-make-vector:bad-length (local.get $k-fx))
                         (unreachable)))
               (local.set $k-encoded
                          (i31.get_s (ref.cast (ref i31) (local.get $k-fx))))
               (if (i32.ne (i32.and (local.get $k-encoded) (i32.const 1)) (i32.const 0))
                   (then (call $raise-make-vector:bad-length (local.get $k-fx))
                         (unreachable)))
               ;; --- Decode fixnum to i32 ---
               (local.set $k/s
                          (i32.shr_s
                           (local.get $k-encoded)
                           (i32.const 1)))
               (if (i32.lt_s (local.get $k/s) (i32.const 0))
                   (then (call $raise-make-vector:bad-length (local.get $k-fx))
                         (unreachable)))
               (local.set $k (local.get $k/s))
               ;; --- Substitute default value if missing ---
               (local.set $v (if (result (ref eq))
                                 (ref.eq (local.get $val) (global.get $missing))
                                 (then (global.get $zero))
                                 (else (local.get $val))))
               ;; --- Delegate to checked version ---
               (call $make-vector/checked (local.get $k) (local.get $v)))

         (func $make-vector/checked
               (param $k   i32)        ;; number of elements
               (param $val (ref eq))   ;; initial value
               (result     (ref $Vector))

               (local $arr (ref $Array))
               (call $debug-allocation-tick (i32.const 1))
               ;; Create the array
               (local.set $arr (array.new $Array (local.get $val) (local.get $k)))
               ;; Construct and return the vector
               (struct.new $Vector
                           (i32.const 0)    ;; hash = 0
                           (i32.const 0)    ;; mutable
                           (local.get $arr)))

     ))

;; vector-make-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate make-vector helpers used by the monolithic runtime.
(define vector-make-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-make-runtime-only-helpers
   vector-make-runtime-only-forms))

;; vector-make-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for make-vector helpers.
(define vector-make-runtime-only-helper-names
  (map core-runtime-helper-name vector-make-runtime-only-helpers))

;; vector-constructor-runtime-only-forms : (listof datum?)
;;   Enumerate vector constructor helpers used by the monolithic runtime.
(define vector-constructor-runtime-only-forms
  '(
         (func $vector (type $Prim>=0)
               (param $args (ref eq))
               (result      (ref eq))

               (local $as        (ref $Args))
               (local $len       i32)
               (local $arr       (ref $Array))
               (local $use-args? i32)
               (local $list      (ref eq))
               (local $node      (ref eq))
               (local $pair      (ref $Pair))
               (local $i         i32)
               (local $x         (ref eq))

               ;; Initialize non-defaultable locals
               (local.set $as   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $x    (global.get $false))
               (local.set $list (global.get $null))
               (local.set $node (global.get $null))

               ;; Determine whether we received an $Args array or a list of rest arguments.
               (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
               (if (local.get $use-args?)
                   (then
                    (local.set $as (ref.cast (ref $Args) (local.get $args)))
                    (local.set $len (array.len (local.get $as))))
                   (else
                    (local.set $list (local.get $args))
                    (local.set $node (local.get $list))
                    (local.set $len (call $length/i32 (local.get $list)))))

               ;; Allocate backing array
               (local.set $arr (call $make-array (local.get $len) (global.get $false)))
               (local.set $i   (i32.const 0))

               ;; Copy arguments from either $Args or list form
               (if (local.get $use-args?)
                   (then
                    (block $done-args
                           (loop $loop-args
                                 (br_if $done-args
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $x (array.get $Args (local.get $as) (local.get $i)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-args))))
                   (else
                    (local.set $node (local.get $list))
                    (block $done-list
                           (loop $loop-list
                                 (br_if $done-list
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (ref.test (ref $Pair) (local.get $node))
                                     (then
                                      (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                      (local.set $x (struct.get $Pair $a (local.get $pair)))
                                      (local.set $node (struct.get $Pair $d (local.get $pair))))
                                     (else
                                      (call $raise-pair-expected (local.get $node))
                                      (unreachable)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-list)))))

               ;; Wrap in a mutable vector structure
               (struct.new $Vector
                           (i32.const 0)          ;; hash
                           (i32.const 0)          ;; mutable
                           (local.get $arr)))


         (func $vector-immutable (type $Prim>=0)
               (param $args (ref eq))
               (result      (ref eq))

               (local $as        (ref $Args))
               (local $len       i32)
               (local $arr       (ref $Array))
               (local $use-args? i32)
               (local $list      (ref eq))
               (local $node      (ref eq))
               (local $pair      (ref $Pair))
               (local $i         i32)
               (local $x         (ref eq))

               ;; Initialize non-defaultable locals
               (local.set $as   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $x    (global.get $false))
               (local.set $list (global.get $null))
               (local.set $node (global.get $null))

               ;; Determine whether we received an $Args array or a list of rest arguments.
               (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
               (if (local.get $use-args?)
                   (then
                    (local.set $as (ref.cast (ref $Args) (local.get $args)))
                    (local.set $len (array.len (local.get $as))))
                   (else
                    (local.set $list (local.get $args))
                    (local.set $node (local.get $list))
                    (local.set $len (call $length/i32 (local.get $list)))))

               ;; Allocate backing array
               (local.set $arr (call $make-array (local.get $len) (global.get $false)))
               (local.set $i   (i32.const 0))

               ;; Copy arguments from either $Args or list form
               (if (local.get $use-args?)
                   (then
                    (block $done-args
                           (loop $loop-args
                                 (br_if $done-args
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $x (array.get $Args (local.get $as) (local.get $i)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-args))))
                   (else
                    (local.set $node (local.get $list))
                    (block $done-list
                           (loop $loop-list
                                 (br_if $done-list
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (ref.test (ref $Pair) (local.get $node))
                                     (then
                                      (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                      (local.set $x (struct.get $Pair $a (local.get $pair)))
                                      (local.set $node (struct.get $Pair $d (local.get $pair))))
                                     (else
                                      (call $raise-pair-expected (local.get $node))
                                      (unreachable)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-list)))))

               ;; Wrap in a mutable vector structure
               (struct.new $Vector
                           (i32.const 0)          ;; hash
                           (i32.const 1)          ;; immutable
                           (local.get $arr)))


     ))

;; vector-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector constructor helpers used by the monolithic runtime.
(define vector-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-constructor-runtime-only-helpers
   vector-constructor-runtime-only-forms))

;; vector-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector constructor helpers.
(define vector-constructor-runtime-only-helper-names
  (map core-runtime-helper-name vector-constructor-runtime-only-helpers))

;; vector-build-runtime-only-forms : (listof datum?)
;;   Enumerate build-vector helpers used by the monolithic runtime.
(define vector-build-runtime-only-forms
  '(
        (func $build-vector (type $Prim2)
              (param $n-raw (ref eq))  ;; exact-nonnegative integer
              (param $proc  (ref eq))  ;; (exact-nonnegative-integer? . -> . any/c)
              (result       (ref eq))

              (local $n    i32)
              (local $n-encoded i32)
              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))

              ;; --- Check and unwrap n ---
              (if (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                  (then (call $raise-build-vector:bad-length (local.get $n-raw))
                        (unreachable)))
              (local.set $n-encoded
                         (i31.get_s (ref.cast (ref i31) (local.get $n-raw))))
              (if (i32.ne (i32.and (local.get $n-encoded) (i32.const 1)) (i32.const 0))
                  (then (call $raise-build-vector:bad-length (local.get $n-raw))
                        (unreachable)))
              (local.set $n
                         (i32.shr_s
                          (local.get $n-encoded)
                          (i32.const 1)))
              (if (i32.lt_s (local.get $n) (i32.const 0))
                  (then (call $raise-build-vector:bad-length (local.get $n-raw))
                        (unreachable)))

              ;; --- Check procedure ---
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-build-vector:procedure-expected (local.get $proc))
                        (unreachable)))
              (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 1)))
                  (then (call $raise-build-vector:procedure-expected (local.get $proc))
                        (unreachable)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; Delegate
              (call $build-vector/checked (local.get $n)
                    (local.get $f)
                    (local.get $finv)))

        (func $build-vector/checked
              (param $n    i32)
              (param $f    (ref $Procedure))
              (param $finv (ref $ProcedureInvoker))
              (result      (ref $Vector))

              (local $args (ref $Args))
              (local $arr  (ref $Array))
              (local $i    i32)
              (local $res  (ref eq))

              ;; Prepare array and argument holder
              (local.set $arr  (call $make-array (local.get $n) (global.get $false)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              ;; Iterate from 0 to n-1
              (local.set $i (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                           ;; Set argument to current index as fixnum
                           (array.set $Args (local.get $args) (i32.const 0)
                                      (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                           ;; Call procedure and store result
                           (local.set $res
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (array.set $Array (local.get $arr) (local.get $i) (local.get $res))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))

              ;; Construct vector
              (struct.new $Vector
                          (i32.const 0)    ;; hash
                          (i32.const 0)    ;; mutable
                          (local.get $arr)))

     ))

;; vector-build-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate build-vector helpers used by the monolithic runtime.
(define vector-build-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-build-runtime-only-helpers
   vector-build-runtime-only-forms))

;; vector-build-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for build-vector helpers.
(define vector-build-runtime-only-helper-names
  (map core-runtime-helper-name vector-build-runtime-only-helpers))


;; vector-operation-runtime-only-forms : (listof datum?)
;;   Enumerate vector operation helpers used by the monolithic runtime.
(define vector-operation-runtime-only-forms
  '(
        (func $vector-set/copy (type $Prim3)
              ;; Returns a fresh mutable vector with VAL at index POS.
              (param $v   (ref eq)) ;; vector
              (param $pos (ref eq)) ;; fixnum
              (param $val (ref eq)) ;; any
              (result     (ref eq))

              (local $vec (ref $Vector))
              (local $idx i32)
              (local $len i32)

              ;; --- Validate vector ---
              (local.set $vec (global.get $dummy-vector))
              (if (ref.test (ref $Vector) (local.get $v))
                  (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-set/copy)
                              (local.get $v))))

              ;; --- Validate index ---
              (local.set $idx
                         (call $vector-index/i32
                               (global.get $symbol:vector-set/copy)
                               (local.get $pos)))

              ;; --- Bounds check ---
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
              (if (i32.lt_u (local.get $idx) (local.get $len))
                  (then (return
                         (struct.new $Vector
                                    (i32.const 0)
                                    (i32.const 0)
                                    (call $array-set/copy
                                          (struct.get $Vector $arr (local.get $vec))
                                          (local.get $idx)
                                          (local.get $val)))))
                  (else (call $raise-bad-vector-ref-index/who
                              (global.get $symbol:vector-set/copy)
                              (local.get $vec) (local.get $idx) (local.get $len))
                        (unreachable)))
              (unreachable))


        (func $vector-length (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                         (ref.i31
                          (i32.shl
                           (array.len
                            (struct.get $Vector $arr (local.get $vec)))
                           (i32.const 1))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-length)
                               (local.get $v))
                         (unreachable))))


         (func $vector-length/i32 (param $v (ref eq)) (result i32)
               (local $vec (ref $Vector))
               (if (result i32)
                   (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                         (array.len (struct.get $Vector $arr (local.get $vec))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-length)
                               (local.get $v))
                         (unreachable))))

         (func $vector-length/checked/i32 (param $v (ref $Vector)) (result i32)
               (array.len (struct.get $Vector $arr (local.get $v))))


         (func $vector? (type $Prim1) (param $a (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $a))
                   (then (global.get $true))
                   (else (global.get $false))))


         (func $vector-ref/checked
               (param $a (ref $Vector)) (param $i i32)
               (result (ref eq))
               (local $len i32)
               ;; get length
               (local.set $len (array.len (struct.get $Vector $arr (local.get $a))))
               ;; bounds check
               (if (result (ref eq))
                   (i32.lt_u (local.get $i) (local.get $len))
                   (then (array.get $Array
                                    (struct.get $Vector $arr (local.get $a))
                                    (local.get $i)))
                   (else (call $raise-bad-vector-ref-index
                               (local.get $a) (local.get $i) (local.get $len))
                         (unreachable))))

         (func $vector-ref/who
               (param $who (ref eq))
               (param $v (ref eq)) (param $i (ref eq))
               (result (ref eq))
               (local $vec (ref $Vector))
               (local $idx i32)
               (local $len i32)
               ;; Initialize vec to dummy to satisfy non-nullable default requirement
               (local.set $vec (global.get $dummy-vector))
               ;; Check that $v is a vector
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who (local.get $who) (local.get $v))))
               ;; Check and decode exact-nonnegative-integer? index
               (local.set $idx
                          (call $vector-index/i32
                                (local.get $who)
                                (local.get $i)))
               ;; Get array length
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               ;; Bounds check
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx) (local.get $len))
                   (then (return
                          (array.get $Array
                                     (struct.get $Vector $arr (local.get $vec))
                                     (local.get $idx))))
                   (else (call $raise-bad-vector-ref-index/who
                               (local.get $who)
                               (local.get $vec) (local.get $idx) (local.get $len))
                         (unreachable))))

         (func $vector-ref (type $Prim2)
               (param $v (ref eq)) (param $i (ref eq))
               (result (ref eq))
               (call $vector-ref/who
                     (global.get $symbol:vector-ref)
                     (local.get $v)
                     (local.get $i)))


         (func $vector-set!/checked
               (param $vec (ref $Vector)) (param $i i32) (param $val (ref eq))
               (local $len i32)

               (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                   (then (call $raise-immutable-vector (local.get $vec)) (unreachable)))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.lt_u (local.get $i) (local.get $len))
                   (then (array.set $Array
                                    (struct.get $Vector $arr (local.get $vec))
                                    (local.get $i)
                                    (local.get $val)))
                   (else (call $raise-bad-vector-ref-index
                               (local.get $vec) (local.get $i) (local.get $len))
                         (unreachable))))

         (func $vector-set!/who
               (param $who (ref eq))
               (param $v   (ref eq))
               (param $i   (ref eq))
               (param $val (ref eq))
               (result     (ref eq))

               (local $vec (ref $Vector))
               (local $idx i32)
               (local $len i32)
               ;; Initialize $vec with dummy to satisfy non-nullable restriction
               (local.set $vec (global.get $dummy-vector))
               ;; 1. Check $v is a vector
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who (local.get $who) (local.get $v))))
               ;; 2. Check and decode exact-nonnegative-integer? index
               (local.set $idx
                          (call $vector-index/i32
                                (local.get $who)
                                (local.get $i)))
              ;; 3. Check mutability and get length
              (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                  (then (call $raise-immutable-vector/who (local.get $who) (local.get $v))))
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               ;; 4. Bounds check and set
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx) (local.get $len))
                   (then (array.set $Array
                                    (struct.get $Vector $arr (local.get $vec))
                                    (local.get $idx)
                                    (local.get $val))
                         (global.get $void))
                   (else (call $raise-bad-vector-ref-index/who
                               (local.get $who)
                               (local.get $vec) (local.get $idx) (local.get $len))
                         (unreachable))))

         (func $vector-set! (type $Prim3)
               (param $v   (ref eq))
               (param $i   (ref eq))
               (param $val (ref eq))
               (result     (ref eq))
               (call $vector-set!/who
                     (global.get $symbol:vector-set!)
                     (local.get $v)
                     (local.get $i)
                     (local.get $val)))

         ;; vector*-length : vector? -> exact-nonnegative-integer?
         ;;   Checked vector length. WebRacket has no vector impersonators yet,
         ;;   so this currently matches vector-length.
         (func $vector*-length (type $Prim1)
               (param $v (ref eq)) ;; vector?
               (result   (ref eq))

               (local $vec (ref $Vector))
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector*-length)
                               (local.get $v))
                         (unreachable)))
               (ref.i31 (i32.shl
                         (array.len
                          (struct.get $Vector $arr (local.get $vec)))
                         (i32.const 1))))

         ;; vector*-ref : vector? exact-nonnegative-integer? -> any/c
         ;;   Checked vector ref. WebRacket has no vector impersonators yet,
         ;;   so this currently matches vector-ref.
         (func $vector*-ref (type $Prim2)
               (param $v (ref eq)) ;; vector?
               (param $i (ref eq)) ;; exact-nonnegative-integer?
               (result   (ref eq))
               (call $vector-ref/who
                     (global.get $symbol:vector*-ref)
                     (local.get $v)
                     (local.get $i)))

         ;; vector*-set! : (and/c vector? (not/c immutable?)) exact-nonnegative-integer? any/c -> void?
         ;;   Checked vector set. WebRacket has no vector impersonators yet,
         ;;   so this currently matches vector-set!.
         (func $vector*-set! (type $Prim3)
               (param $v   (ref eq)) ;; mutable vector?
               (param $i   (ref eq)) ;; exact-nonnegative-integer?
               (param $val (ref eq)) ;; new value
               (result     (ref eq))
               (call $vector-set!/who
                     (global.get $symbol:vector*-set!)
                     (local.get $v)
                     (local.get $i)
                     (local.get $val)))

         (func $vector-fill! (type $Prim2) (param $v (ref eq)) (param $x (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-fill!)
                               (local.get $v))))
               (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                   (then (call $raise-immutable-vector/who
                               (global.get $symbol:vector-fill!)
                               (local.get $v))))
               (call $array-fill! (struct.get $Vector $arr (local.get $vec)) (local.get $x))
               (global.get $void))


     ))

;; vector-operation-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector operation helpers used by the monolithic runtime.
(define vector-operation-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-operation-runtime-only-helpers
   vector-operation-runtime-only-forms))

;; vector-operation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector operation helpers.
(define vector-operation-runtime-only-helper-names
  (map core-runtime-helper-name vector-operation-runtime-only-helpers))


;; vector-copy-runtime-only-forms : (listof datum?)
;;   Enumerate vector copy and conversion helpers used by the monolithic runtime.
(define vector-copy-runtime-only-forms
  '(
         (func $vector-copy!
               (param $dest       (ref eq))
               (param $dest-start (ref eq))   ;; fixnum
               (param $src        (ref eq))
               (param $src-start  (ref eq))   ;; fixnum or $missing, default: 0)
               (param $src-end    (ref eq))   ;; fixnum or $missing, default: (vector-length src)
               (result            (ref eq))

               (local $d       (ref $Vector))
               (local $s       (ref $Vector))
               (local $ds      i32)
               (local $ss      i32)
               (local $se      i32)
               (local $src-len i32)

               ;; --- Validate $dest ---
               (if (i32.eqz (ref.test (ref $Vector) (local.get $dest)))
                   (then (call $raise-check-vector/who
                               (global.get $symbol:vector-copy!)
                               (local.get $dest))))
               ;; --- Validate $src ---
               (if (i32.eqz (ref.test (ref $Vector) (local.get $src)))
                   (then (call $raise-check-vector/who
                               (global.get $symbol:vector-copy!)
                               (local.get $src))))
               ;; --- Cast and decode after validation ---
               (local.set $d  (ref.cast (ref $Vector) (local.get $dest)))
               (local.set $s  (ref.cast (ref $Vector) (local.get $src)))
               (if (i32.ne (struct.get $Vector $immutable (local.get $d)) (i32.const 0))
                   (then (call $raise-immutable-vector/who
                               (global.get $symbol:vector-copy!)
                               (local.get $dest))))
               (local.set $ds
                          (call $vector-index/i32
                                (global.get $symbol:vector-copy!)
                                (local.get $dest-start)))

               (local.set $src-len (array.len (struct.get $Vector $arr (local.get $s))))

               (if (ref.eq (local.get $src-start) (global.get $missing))
                   (then (local.set $ss (i32.const 0)))
                   (else (local.set $ss
                                    (call $vector-index/i32
                                          (global.get $symbol:vector-copy!)
                                          (local.get $src-start)))))

               (if (ref.eq (local.get $src-end) (global.get $missing))
                   (then (local.set $se (local.get $src-len)))
                   (else (local.set $se
                                    (call $vector-index/i32
                                          (global.get $symbol:vector-copy!)
                                          (local.get $src-end)))))
               ;; --- Delegate to checked copy ---
               (call $vector-copy!/checked/who
                     (global.get $symbol:vector-copy!)
                     (local.get $d) (local.get $ds)
                     (local.get $s) (local.get $ss)
                     (local.get $se)))

         (func $vector-copy!/checked/who
               (param $who  (ref eq))
               (param $dest (ref $Vector)) (param $ds i32)
               (param $src  (ref $Vector)) (param $ss i32) (param $se i32)
               (result (ref eq))

               (local $src-len i32)
               (local $dest-len i32)
               (if (i32.ne (struct.get $Vector $immutable (local.get $dest)) (i32.const 0))
                   (then (call $raise-immutable-vector/who
                               (local.get $who)
                               (local.get $dest))
                         (unreachable)))
               (local.set $src-len  (array.len (struct.get $Vector $arr (local.get $src))))
               (local.set $dest-len (array.len (struct.get $Vector $arr (local.get $dest))))
               (if (i32.or
                    (i32.or (i32.gt_u (local.get $ss) (local.get $src-len))
                            (i32.gt_u (local.get $se) (local.get $src-len)))
                    (i32.gt_u (i32.add (local.get $ds) (i32.sub (local.get $se) (local.get $ss))) (local.get $dest-len)))
                   (then (call $raise-bad-vector-copy-range/who
                               (local.get $who)
                               (local.get $dest) (local.get $ds)
                               (local.get $src) (local.get $ss) (local.get $se))
                         (unreachable)))

               (call $array-copy!
                     (struct.get $Vector $arr (local.get $dest)) (local.get $ds)
                     (struct.get $Vector $arr (local.get $src))  (local.get $ss) (local.get $se))
               (global.get $void))

         (func $vector-copy!/checked
               (param $dest (ref $Vector)) (param $ds i32)
               (param $src  (ref $Vector)) (param $ss i32) (param $se i32)
               (result (ref eq))

               (call $vector-copy!/checked/who
                     (global.get $symbol:vector-copy!)
                     (local.get $dest) (local.get $ds)
                     (local.get $src) (local.get $ss) (local.get $se)))

         (func $vector-copy/who
               (param $who   (ref eq))
               (param $v     (ref eq))
               (param $start (ref eq))   ;; fixnum or $missing, default: 0
               (param $end   (ref eq))   ;; fixnum or $missing, default: (vector-length v)
               (result       (ref eq))

               (local $vec (ref $Vector))
               (local $ss  i32)
               (local $se  i32)
               (local $len i32)

               ;; --- Validate vector ---
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (local.get $who)
                               (local.get $v))))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               ;; --- Decode $start ---
               (if (ref.eq (local.get $start) (global.get $missing))
                   (then (local.set $ss (i32.const 0)))
                   (else (local.set $ss
                                    (call $vector-index/i32
                                          (local.get $who)
                                          (local.get $start)))))
               ;; --- Decode $end ---
               (if (ref.eq (local.get $end) (global.get $missing))
                   (then (local.set $se (local.get $len)))
                   (else (local.set $se
                                    (call $vector-index/i32
                                          (local.get $who)
                                          (local.get $end)))))
               ;; --- Bounds check: start <= end <= len ---
               (if (i32.or (i32.gt_u (local.get $ss) (local.get $se))
                           (i32.gt_u (local.get $se) (local.get $len)))
                   (then (call $raise-bad-vector-copy-range/who
                               (local.get $who)
                               (local.get $vec) (i32.const 0)
                               (local.get $vec) (local.get $ss) (local.get $se))
                         (unreachable)))
               ;; --- Allocate and return new mutable vector ---
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-copy
                                 (struct.get $Vector $arr (local.get $vec))
                                 (local.get $ss) (local.get $se))))

         (func $vector-copy (type $Prim13)
               (param $v     (ref eq))
               (param $start (ref eq))
               (param $end   (ref eq))
               (result       (ref eq))

               (call $vector-copy/who
                     (global.get $symbol:vector-copy)
                     (local.get $v)
                     (local.get $start)
                     (local.get $end)))

         (func $vector->immutable-vector (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $vec (ref $Vector))

               ;; --- Validate vector ---
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector->immutable-vector)
                               (local.get $v))))

               ;; --- If already immutable, return as-is ---
               (if (result (ref eq))
                   (i32.eq (struct.get $Vector $immutable (local.get $vec)) (i32.const 1))
                   (then (local.get $vec))
                   (else
                    ;; Otherwise, allocate immutable copy
                    (struct.new $Vector
                                (struct.get $Vector $hash (local.get $vec))
                                (i32.const 1)
                                (call $array-copy
                                      (struct.get $Vector $arr (local.get $vec))
                                      (i32.const 0)
                                      (array.len (struct.get $Vector $arr (local.get $vec))))))))

         (func $vector->values (type $Prim13)
               (param $v     (ref eq))
               (param $start (ref eq))   ;; fixnum or $missing, default: 0
               (param $end   (ref eq))   ;; fixnum or $missing, default: (vector-length v)
               (result       (ref eq))

               (local $vec  (ref $Vector))
               (local $arr  (ref $Array))
               (local $ss   i32)
               (local $se   i32)
               (local $len  i32)
               (local $n    i32)
               (local $vals (ref $Values))

               ;; --- Validate vector ---
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector->values)
                               (local.get $v))))
               (local.set $arr (struct.get $Vector $arr (local.get $vec)))
               (local.set $len (array.len (local.get $arr)))

               ;; --- Decode $start ---
               (if (ref.eq (local.get $start) (global.get $missing))
                   (then (local.set $ss (i32.const 0)))
                   (else (local.set $ss
                                    (call $vector-index/i32
                                          (global.get $symbol:vector->values)
                                          (local.get $start)))))

               ;; --- Decode $end ---
               (if (ref.eq (local.get $end) (global.get $missing))
                   (then (local.set $se (local.get $len)))
                   (else (local.set $se
                                    (call $vector-index/i32
                                          (global.get $symbol:vector->values)
                                          (local.get $end)))))

               ;; --- Bounds check: start <= end <= len ---
               (if (i32.or (i32.gt_u (local.get $ss) (local.get $se))
                           (i32.gt_u (local.get $se) (local.get $len)))
                   (then (call $raise-bad-vector-copy-range/who
                               (global.get $symbol:vector->values)
                               (local.get $vec) (i32.const 0)
                               (local.get $vec) (local.get $ss) (local.get $se))
                         (unreachable)))

               (local.set $n (i32.sub (local.get $se) (local.get $ss)))
               (if (i32.eq (local.get $n) (i32.const 1))
                   (then (return (array.get $Array (local.get $arr) (local.get $ss)))))

               (local.set $vals (array.new $Values (global.get $null) (local.get $n)))
               (array.copy $Values $Array
                           (local.get $vals) (i32.const 0)
                           (local.get $arr) (local.get $ss)
                           (local.get $n))
               (local.get $vals))


     ))

;; vector-copy-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector copy and conversion helpers used by the monolithic runtime.
(define vector-copy-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-copy-runtime-only-helpers
   vector-copy-runtime-only-forms))

;; vector-copy-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector copy and conversion helpers.
(define vector-copy-runtime-only-helper-names
  (map core-runtime-helper-name vector-copy-runtime-only-helpers))


;; vector-extend-runtime-only-forms : (listof datum?)
;;   Enumerate vector extend helpers used by the monolithic runtime.
(define vector-extend-runtime-only-forms
  '(
         (func $raise-vector-extend:bad-length
               (param $v        (ref $Vector))
               (param $new-size (ref eq))
               (param $len      i32)
               (call $raise-arguments-error
                     (global.get $symbol:vector-extend)
                     (global.get $string:vector-extend-shorter)
                     (array.new_fixed $Args 4
                                      (global.get $string:vector-extend-new-length)
                                      (local.get $new-size)
                                      (global.get $string:vector-extend-existing-length)
                                      (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (unreachable))

         (func $vector-extend (type $Prim23)
               (param $v        (ref eq))  ;; vector
               (param $new-size (ref eq))  ;; fixnum
               (param $val      (ref eq))  ;; optional, defaults to 0
               (result          (ref eq))

               (local $vec  (ref $Vector))
               (local $ns   i32)
               (local $len  i32)
               (local $fill (ref eq))

               (local.set $vec  (global.get $dummy-vector))
               (local.set $fill (global.get $zero))

               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-extend)
                               (local.get $v))))

               (if (ref.test (ref i31) (local.get $new-size))
                   (then (local.set $ns (i31.get_s (ref.cast (ref i31) (local.get $new-size))))
                         (if (i32.and (local.get $ns) (i32.const 1))
                             (then (call $raise-argument-error1
                                         (global.get $symbol:vector-extend)
                                         (global.get $string:exact-nonnegative-integer?)
                                         (local.get $new-size))
                                   (unreachable)))
                         (local.set $ns (i32.shr_s (local.get $ns) (i32.const 1))))
                   (else (call $raise-argument-error1
                               (global.get $symbol:vector-extend)
                               (global.get $string:exact-nonnegative-integer?)
                               (local.get $new-size))
                         (unreachable)))

               (if (i32.lt_s (local.get $ns) (i32.const 0))
                   (then (call $raise-argument-error1
                               (global.get $symbol:vector-extend)
                               (global.get $string:exact-nonnegative-integer?)
                               (local.get $new-size))
                         (unreachable)))

               (local.set $fill (if (result (ref eq))
                                    (ref.eq (local.get $val) (global.get $missing))
                                    (then (global.get $zero))
                                    (else (local.get $val))))

               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.lt_s (local.get $ns) (local.get $len))
                   (then (call $raise-vector-extend:bad-length
                               (local.get $vec) (local.get $new-size) (local.get $len))
                         (unreachable)))

               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-extend
                                 (struct.get $Vector $arr (local.get $vec))
                                 (local.get $ns)
                                 (local.get $fill))))

         (func $vector-empty? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $len i32)
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                         (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
                         (if (result (ref eq))
                             (i32.eqz (local.get $len))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-empty?)
                               (local.get $v))
                         (unreachable))))


     ))

;; vector-extend-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector extend helpers used by the monolithic runtime.
(define vector-extend-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-extend-runtime-only-helpers
   vector-extend-runtime-only-forms))

;; vector-extend-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector extend helpers.
(define vector-extend-runtime-only-helper-names
  (map core-runtime-helper-name vector-extend-runtime-only-helpers))


;; vector-append-runtime-only-forms : (listof datum?)
;;   Enumerate vector append helpers used by the monolithic runtime.
(define vector-append-runtime-only-forms
  '(
         (func $vector-append (type $Prim>=0)
              (param $xs    (ref eq))        ;; list of vectors
              (result       (ref eq))

              (local $n     i32)
              (local $node  (ref $Pair))
              (local $vec   (ref $Vector))
              (local $v     (ref eq))
              (local $orig  (ref eq))
              (local $total i32)
              (local $len   i32)
              (local $arr   (ref $Array))
              (local $pos   i32)

              ;; initialize non-defaultable refs
              (local.set $vec (global.get $dummy-vector))

              ;; Preserve original list
              (local.set $orig (local.get $xs))
              ;; Determine number of arguments
              (local.set $n (call $length/i32 (local.get $xs)))
              ;; Zero arguments -> empty vector
              (if (i32.eqz (local.get $n))
                  (then (return (struct.new $Vector
                                           (i32.const 0)
                                           (i32.const 0)
                                           (call $make-array
                                                 (i32.const 0)
                                                 (global.get $false))))))
              ;; Extract and check first argument
              (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
              (local.set $v    (struct.get $Pair $a (local.get $node)))
              (if (ref.test (ref $Vector) (local.get $v))
                  (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-append)
                              (local.get $v))))
              ;; Single argument -> copy to ensure fresh vector
              (if (i32.eq (local.get $n) (i32.const 1))
                  (then (return (call $vector-copy
                                      (local.get $v)
                                      (global.get $missing)
                                      (global.get $missing)))))
              ;; Compute total length
              (local.set $total (array.len (struct.get $Vector $arr (local.get $vec))))
              (local.set $xs    (struct.get $Pair $d (local.get $node)))
              (block $done1
                     (loop $loop1
                           (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                           (local.set $v    (struct.get $Pair $a (local.get $node)))
                           (if (ref.test (ref $Vector) (local.get $v))
                               (then (local.set $vec   (ref.cast (ref $Vector) (local.get $v)))
                                     (local.set $len   (array.len (struct.get $Vector $arr (local.get $vec))))
                                     (local.set $total (i32.add (local.get $total) (local.get $len))))
                               (else (call $raise-check-vector/who
                                           (global.get $symbol:vector-append)
                                           (local.get $v))))
                           (local.set $xs (struct.get $Pair $d (local.get $node)))
                           (br $loop1)))
              ;; Allocate result array
              (local.set $arr (call $make-array (local.get $total) (global.get $false)))
              ;; Copy vectors into result array
              (local.set $xs (local.get $orig))
              (local.set $pos (i32.const 0))
              (block $done2
                     (loop $loop2
                           (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                           (local.set $vec  (ref.cast (ref $Vector)
                                                      (struct.get $Pair $a (local.get $node))))
                           (local.set $len  (array.len (struct.get $Vector $arr (local.get $vec))))
                           (call $array-copy!
                                 (local.get $arr) (local.get $pos)
                                 (struct.get $Vector $arr (local.get $vec))
                                 (i32.const 0) (local.get $len))
                           (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                           (local.set $xs (struct.get $Pair $d (local.get $node)))
                           (br $loop2)))

              (struct.new $Vector
                          (i32.const 0)
                          (i32.const 0)
                          (local.get $arr)))

         (func $vector-append/2 (param $a (ref eq)) (param $b (ref eq)) (result (ref eq))
               (local $va (ref $Vector))
               (local $vb (ref $Vector))
               (local.set $va (global.get $dummy-vector))
               (local.set $vb (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $a))
                   (then (local.set $va (ref.cast (ref $Vector) (local.get $a))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-append)
                               (local.get $a))))
               (if (ref.test (ref $Vector) (local.get $b))
                   (then (local.set $vb (ref.cast (ref $Vector) (local.get $b))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-append)
                               (local.get $b))))

               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-append
                                 (struct.get $Vector $arr (local.get $va))
                                 (struct.get $Vector $arr (local.get $vb)))))



     ))

;; vector-append-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector append helpers used by the monolithic runtime.
(define vector-append-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-append-runtime-only-helpers
   vector-append-runtime-only-forms))

;; vector-append-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector append helpers.
(define vector-append-runtime-only-helper-names
  (map core-runtime-helper-name vector-append-runtime-only-helpers))


;; vector-slice-runtime-only-forms : (listof datum?)
;;   Enumerate vector take, drop, and split helpers used by the monolithic runtime.
(define vector-slice-runtime-only-forms
  '(
         (func $vector-take (type $Prim2) (param $v (ref eq)) (param $i (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-take)
                               (local.get $v))))
               (local.set $ix
                          (call $vector-index/i32
                                (global.get $symbol:vector-take)
                                (local.get $i)))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-take)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-take (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))

         (func $vector-drop (type $Prim2) (param $v (ref eq)) (param $i (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-drop)
                               (local.get $v))))
               (local.set $ix
                          (call $vector-index/i32
                                (global.get $symbol:vector-drop)
                                (local.get $i)))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-drop)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-drop (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))

         (func $vector-drop-right (type $Prim2) (param $v (ref eq)) (param $i (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-drop-right)
                               (local.get $v))))
               (local.set $ix
                          (call $vector-index/i32
                                (global.get $symbol:vector-drop-right)
                                (local.get $i)))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-drop-right)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-drop-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))

         (func $vector-take-right (type $Prim2)
               (param $v (ref eq))
               (param $i (ref eq))
               (result   (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-take-right)
                               (local.get $v))))
               (local.set $ix
                          (call $vector-index/i32
                                (global.get $symbol:vector-take-right)
                                (local.get $i)))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-take-right)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-take-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))



         (func $vector-split-at (type $Prim2)
               (param $v (ref eq))
               (param $i (ref eq))
               (result   (ref eq))  ; returns two values

               (local $vec (ref $Vector))
               (local $ix  i32)
               (local $len i32)
               (local $res (ref $Array))

               ; 1. Check $v is a vector
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-split-at)
                               (local.get $v))))
               ; 2. Check and decode exact-nonnegative-integer? index
               (local.set $ix
                          (call $vector-index/i32
                                (global.get $symbol:vector-split-at)
                                (local.get $i)))
               ; 3. Range check
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-split-at)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               ; 4. Split the vector
               (local.set $res (call $array-split-at (struct.get $Vector $arr (local.get $vec)) (local.get $ix)))
               (array.new_fixed $Values 2
                                (struct.new $Vector
                                            (i32.const 0)  ; hash
                                            (i32.const 0)  ; mutable
                                            (ref.cast (ref $Array)
                                                      (array.get $Array (local.get $res) (i32.const 0))))
                                (struct.new $Vector
                                            (i32.const 0) ; hash
                                            (i32.const 0) ; mutable
                                            (ref.cast (ref $Array)
                                                      (array.get $Array (local.get $res) (i32.const 1))))))

         (func $vector-split-at-right (type $Prim2)
               (param $v (ref eq))      ; vec
               (param $i (ref eq))      ; count
               (result   (ref eq))      ; returns two values

               (local $vec  (ref $Vector))
               (local $ix   i32)
               (local $len  i32)
               (local $take (ref $Array))
               (local $drop (ref $Array))

               ; 1. Check $v is a vector
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-split-at-right)
                               (local.get $v))))
               ; 2. Check and decode exact-nonnegative-integer? index
               (local.set $ix
                          (call $vector-index/i32
                                (global.get $symbol:vector-split-at-right)
                                (local.get $i)))
               ; 3. Range check
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-split-at-right)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               ; 4. Split the vector from the right
               (local.set $take (call $array-take-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix)))
               (local.set $drop (call $array-drop-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix)))
               (array.new_fixed $Values 2
                                (struct.new $Vector
                                            (i32.const 0) ; hash
                                            (i32.const 0) ; mutable
                                            (local.get $take))
                                (struct.new $Vector
                                            (i32.const 0) ; hash
                                            (i32.const 0) ; mutable
                                            (local.get $drop))))



     ))

;; vector-slice-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector take, drop, and split helpers used by the monolithic runtime.
(define vector-slice-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-slice-runtime-only-helpers
   vector-slice-runtime-only-forms))

;; vector-slice-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector take, drop, and split helpers.
(define vector-slice-runtime-only-helper-names
  (map core-runtime-helper-name vector-slice-runtime-only-helpers))


;; vector-list-conversion-runtime-only-forms : (listof datum?)
;;   Enumerate vector/list conversion helpers used by the monolithic runtime.
(define vector-list-conversion-runtime-only-forms
  '(
         (func $list->vector (type $Prim1)
               (param $xs (ref eq))
               (result    (ref eq))

               (local $arr (ref $Array))
               (local $len i32)
               (local $idx i32)
               (local $node (ref eq))
               (local $pair (ref $Pair))
               (local $x (ref eq))

               ;; Count and validate the proper-list shape.
               (local.set $len (i32.const 0))
               (local.set $node (local.get $xs))
               (block $length-done
                      (loop $length-loop
                            (br_if $length-done
                                   (ref.eq (local.get $node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                (then (call $raise-list-expected/who
                                            (global.get $symbol:list->vector)
                                            (local.get $xs))
                                      (unreachable)))
                            (local.set $len (i32.add (local.get $len) (i32.const 1)))
                            (local.set $node
                                       (struct.get $Pair $d
                                                   (ref.cast (ref $Pair) (local.get $node))))
                            (br $length-loop)))

               (local.set $arr (call $make-array (local.get $len) (global.get $null)))
               (local.set $idx (i32.const 0))
               (local.set $node (local.get $xs))
               (block $fill-done
                      (loop $fill-loop
                            (br_if $fill-done
                                   (ref.eq (local.get $node) (global.get $null)))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $x (struct.get $Pair $a (local.get $pair)))
                            (call $array-set! (local.get $arr) (local.get $idx) (local.get $x))
                            (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $fill-loop)))
               (struct.new $Vector
                           (i32.const 0)     ; hash
                           (i32.const 0)     ; immutable
                           (local.get $arr)))

         (func $vector->list (type $Prim1)
               (param $v (ref eq))
               (result (ref eq))
               (if (i32.eqz (ref.test (ref $Vector) (local.get $v)))
                   (then (call $raise-check-vector/who
                               (global.get $symbol:vector->list)
                               (local.get $v))
                         (unreachable)))
               (call $vector->list/checked (ref.cast (ref $Vector) (local.get $v))))

         (func $vector->list/checked
               (param $v (ref $Vector))
               (result   (ref eq))

               (local $arr (ref $Array))
               (local $i   i32)         ;; current index (starts from len - 1 and decrements)
               (local $x   (ref eq))
               (local $xs  (ref eq))
               ;; Extract backing array and initialize
               (local.set $arr (struct.get $Vector $arr (local.get $v)))
               (local.set $i   (i32.sub (array.len (local.get $arr)) (i32.const 1)))
               (local.set $xs  (global.get $null))
               ;; Loop backwards
               (block $done
                      (loop $loop
                            (br_if $done (i32.lt_s (local.get $i) (i32.const 0)))
                            (local.set $x (array.get $Array (local.get $arr) (local.get $i)))
                            (local.set $xs (struct.new $Pair
                                                       (i32.const 0)
                                                       (local.get $x)
                                                       (local.get $xs)))
                            (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                            (br $loop)))
               (return (local.get $xs)))


     ))

;; vector-list-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector/list conversion helpers used by the monolithic runtime.
(define vector-list-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-list-conversion-runtime-only-helpers
   vector-list-conversion-runtime-only-forms))

;; vector-list-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector/list conversion helpers.
(define vector-list-conversion-runtime-only-helper-names
  (map core-runtime-helper-name vector-list-conversion-runtime-only-helpers))


;; vector-map-count-runtime-only-forms : (listof datum?)
;;   Enumerate vector map and count helpers used by the monolithic runtime.
(define vector-map-count-runtime-only-forms
  '(
        (func $vector-map (type $Prim>=2)
              (param $proc (ref eq))
              (param $v0   (ref eq))
              (param $rest (ref eq))
              (result      (ref eq))

              (local $vec0 (ref $Vector))
              (local $copy (ref $Vector))

              (local.set $vec0 (global.get $dummy-vector))

              ;; Validate procedure first, matching Racket's argument order.
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-vector-argument-error/who
                              (global.get $symbol:vector-map)
                              (global.get $string:procedure?)
                              (local.get $proc))
                        (unreachable)))

              ;; Validate and copy the first vector under vector-map's name.
              (if (ref.test (ref $Vector) (local.get $v0))
                  (then (local.set $vec0 (ref.cast (ref $Vector) (local.get $v0))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-map)
                              (local.get $v0))
                        (unreachable)))
              (local.set $copy
                         (struct.new $Vector
                                     (i32.const 0)
                                     (i32.const 0)
                                     (call $array-copy
                                           (struct.get $Vector $arr (local.get $vec0))
                                           (i32.const 0)
                                           (array.len (struct.get $Vector $arr (local.get $vec0))))))

              (call $vector-map!/who
                    (global.get $symbol:vector-map)
                    (local.get $proc)
                    (local.get $copy)
                    (local.get $rest)))

        (func $vector-map! (type $Prim>=2)
              (param $proc (ref eq))
              (param $v0   (ref eq))
              (param $rest (ref eq))
              (result      (ref eq))

              (call $vector-map!/who
                    (global.get $symbol:vector-map!)
                    (local.get $proc)
                    (local.get $v0)
                    (local.get $rest)))

        (func $vector-map!/who
              (param $who  (ref eq))
              (param $proc (ref eq))
              (param $v0   (ref eq))
              (param $rest (ref eq))
              (result      (ref eq))

              (local $f       (ref $Procedure))
              (local $finv    (ref $ProcedureInvoker))
              (local $vec0    (ref $Vector))
              (local $cur     (ref eq))
              (local $pair    (ref $Pair))
              (local $vec     (ref $Vector))
              (local $vectors (ref $Args))
              (local $call    (ref $Args))
              (local $nvecs   i32)
              (local $len     i32)
              (local $i       i32)
              (local $j       i32)
              (local $elem    (ref eq))
              (local $r       (ref eq))
              (local $tmp     (ref eq))

              ;; 1) Validate procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-vector-argument-error/who
                              (local.get $who)
                              (global.get $string:procedure?)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; 2) Validate first vector
              (local.set $vec0 (global.get $dummy-vector))
              (if (ref.test (ref $Vector) (local.get $v0))
                  (then (local.set $vec0 (ref.cast (ref $Vector) (local.get $v0))))
                  (else (call $raise-immutable-vector/who
                              (local.get $who)
                              (local.get $v0))
                        (unreachable)))
              (if (i32.ne (struct.get $Vector $immutable (local.get $vec0)) (i32.const 0))
                  (then (call $raise-immutable-vector/who
                              (local.get $who)
                              (local.get $v0))
                        (unreachable)))
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec0))))

              ;; 3) Walk rest vectors
              (local.set $nvecs (i32.const 1))
              (local.set $cur   (local.get $rest))
              (block $count-done
                     (loop $count
                           (if (ref.eq (local.get $cur) (global.get $null))
                               (then (br $count-done)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                               (then (call $raise-pair-expected (local.get $cur))
                                     (unreachable)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))

                           ;; Load car as (ref eq), test, then cast before putting into $vec
                           (local.set $tmp (struct.get $Pair $a (local.get $pair)))
                           (if (i32.eqz (ref.test (ref $Vector) (local.get $tmp)))
                               (then (call $raise-check-vector/who
                                           (local.get $who)
                                           (local.get $tmp))
                                     (unreachable)))
                           (local.set $vec (ref.cast (ref $Vector) (local.get $tmp)))

                           (if (i32.ne
                                (array.len (struct.get $Vector $arr (local.get $vec)))
                                (local.get $len))
                               (then (call $raise-vector-length-mismatch
                                           (local.get $who))
                                     (unreachable)))
                           (local.set $nvecs (i32.add (local.get $nvecs) (i32.const 1)))
                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (br $count)))

              ;; 4) Allocate arrays and seed
              (local.set $vectors (array.new $Args (global.get $null) (local.get $nvecs)))
              (local.set $call    (array.new $Args (global.get $null) (local.get $nvecs)))
              (array.set $Args    (local.get $vectors) (i32.const 0) (local.get $vec0))
              (local.set $cur     (local.get $rest))
              (local.set $i       (i32.const 1))
              (block $seed-done
                     (loop $seed
                           (if (i32.ge_u (local.get $i) (local.get $nvecs))
                               (then (br $seed-done)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                           (array.set $Args (local.get $vectors) (local.get $i)
                                      (ref.cast (ref $Vector)
                                                (struct.get $Pair $a (local.get $pair))))
                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $seed)))

              ;; 5) Iterate and mutate first vector
              (local.set $j (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $j) (local.get $len)))

                           (local.set $i (i32.const 0))
                           (block $args-done
                                  (loop $args
                                        (if (i32.ge_u (local.get $i) (local.get $nvecs))
                                            (then (br $args-done)))
                                        (local.set $vec
                                                   (ref.cast (ref $Vector)
                                                             (array.get $Args (local.get $vectors) (local.get $i))))
                                        (local.set $elem
                                                   (array.get $Array
                                                              (struct.get $Vector $arr (local.get $vec))
                                                              (local.get $j)))
                                        (array.set $Args (local.get $call) (local.get $i) (local.get $elem))
                                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                        (br $args)))

                           (local.set $r
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $call)
                                                (local.get $finv)))
                           (array.set $Array
                                      (struct.get $Vector $arr (local.get $vec0))
                                      (local.get $j)
                                      (local.get $r))
                           (local.set $j (i32.add (local.get $j) (i32.const 1)))
                           (br $loop)))

              (local.get $vec0))


        (func $vector-count (type $Prim>=2)
              (param $proc (ref eq))   ;; procedure
              (param $v0   (ref eq))   ;; first vector
              (param $rest (ref eq))   ;; list of vectors
              (result      (ref eq))

              (local $f       (ref $Procedure))
              (local $finv    (ref $ProcedureInvoker))
              (local $vec0    (ref $Vector))
              (local $cur     (ref eq))
              (local $pair    (ref $Pair))
              (local $vec     (ref $Vector))
              (local $vectors (ref $Args))
              (local $call    (ref $Args))
              (local $nvecs   i32)
              (local $len     i32)
              (local $i       i32)
              (local $j       i32)
              (local $elem    (ref eq))
              (local $r       (ref eq))
              (local $tmp     (ref eq))
              (local $cnt     i32)

              ;; 1) Validate procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-vector-argument-error/who
                              (global.get $symbol:vector-count)
                              (global.get $string:procedure?)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; 2) Validate first vector
              (local.set $vec0 (global.get $dummy-vector))
              (if (ref.test (ref $Vector) (local.get $v0))
                  (then (local.set $vec0 (ref.cast (ref $Vector) (local.get $v0))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-count)
                              (local.get $v0))
                        (unreachable)))
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec0))))

              ;; 3) Walk rest vectors
              (local.set $nvecs (i32.const 1))
              (local.set $cur   (local.get $rest))
              (block $count-done
                     (loop $count
                           (if (ref.eq (local.get $cur) (global.get $null))
                               (then (br $count-done)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                               (then (call $raise-pair-expected (local.get $cur))
                                     (unreachable)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))

                           ;; Load car as (ref eq), test, then cast before putting into $vec
                           (local.set $tmp (struct.get $Pair $a (local.get $pair)))
                           (if (i32.eqz (ref.test (ref $Vector) (local.get $tmp)))
                               (then (call $raise-check-vector/who
                                           (global.get $symbol:vector-count)
                                           (local.get $tmp))
                                     (unreachable)))
                           (local.set $vec (ref.cast (ref $Vector) (local.get $tmp)))

                           (if (i32.ne
                                (array.len (struct.get $Vector $arr (local.get $vec)))
                                (local.get $len))
                               (then (call $raise-vector-length-mismatch
                                           (global.get $symbol:vector-count))
                                     (unreachable)))
                           (local.set $nvecs (i32.add (local.get $nvecs) (i32.const 1)))
                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (br $count)))

              ;; 4) Allocate arrays and seed
              (local.set $vectors (array.new $Args (global.get $null) (local.get $nvecs)))
              (local.set $call    (array.new $Args (global.get $null) (local.get $nvecs)))
              (array.set $Args (local.get $vectors) (i32.const 0) (local.get $vec0))
              (local.set $cur (local.get $rest))
              (local.set $i   (i32.const 1))
              (block $seed-done
                     (loop $seed
                           (if (i32.ge_u (local.get $i) (local.get $nvecs))
                               (then (br $seed-done)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                           (array.set $Args (local.get $vectors) (local.get $i)
                                      (ref.cast (ref $Vector)
                                                (struct.get $Pair $a (local.get $pair))))
                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $seed)))

              ;; 5) Iterate and count
              (local.set $cnt (i32.const 0))
              (local.set $j   (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $j) (local.get $len)))

                           (local.set $i (i32.const 0))
                           (block $args-done
                                  (loop $args
                                        (if (i32.ge_u (local.get $i) (local.get $nvecs))
                                            (then (br $args-done)))
                                        (local.set $vec
                                                   (ref.cast (ref $Vector)
                                                             (array.get $Args (local.get $vectors) (local.get $i))))
                                        (local.set $elem
                                                   (array.get $Array
                                                              (struct.get $Vector $arr (local.get $vec))
                                                              (local.get $j)))
                                        (array.set $Args (local.get $call) (local.get $i) (local.get $elem))
                                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                        (br $args)))

                           (local.set $r
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $call)
                                                (local.get $finv)))

                           (if (i32.eqz (ref.eq (local.get $r) (global.get $false)))
                               (then (local.set $cnt (i32.add (local.get $cnt) (i32.const 1))))
                               (else))

                           (local.set $j (i32.add (local.get $j) (i32.const 1)))
                           (br $loop)))

              (ref.i31 (i32.shl (local.get $cnt) (i32.const 1))))


     ))

;; vector-map-count-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector map and count helpers used by the monolithic runtime.
(define vector-map-count-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-map-count-runtime-only-helpers
   vector-map-count-runtime-only-forms))

;; vector-map-count-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector map and count helpers.
(define vector-map-count-runtime-only-helper-names
  (map core-runtime-helper-name vector-map-count-runtime-only-helpers))


;; vector-argminmax-runtime-only-forms : (listof datum?)
;;   Enumerate vector argmin and argmax helpers used by the monolithic runtime.
(define vector-argminmax-runtime-only-forms
  (let ()
            (define (gen-vector-argminmax $name cmp)
              (define who
                (string->symbol
                 (format "$symbol:~a"
                         (substring (symbol->string $name) 1))))
              `((func ,$name (type $Prim2)
                      (param $proc (ref eq)) ;; procedure
                      (param $vec  (ref eq)) ;; vector
                      (result (ref eq))

                      (local $f      (ref $Procedure))
                      (local $finv   (ref $ProcedureInvoker))
                      (local $vector (ref $Vector))
                      (local $args   (ref $Args))
                      (local $len    i32)
                      (local $i      i32)
                      (local $elem   (ref eq))
                      (local $best   (ref eq))
                      (local $bestv  (ref eq))
                      (local $val    (ref eq))

                      (local.set $vector (global.get $dummy-vector))

                      ;; Validate procedure
                      (if (ref.eq (call $procedure? (local.get $proc))
                                  (global.get $false))
                          (then (call $raise-vector-argument-error/who
                                      (global.get ,who)
                                      (global.get $string:vector-unary-real-procedure)
                                      (local.get $proc))
                                (unreachable)))
                      (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
                      (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                         (local.get $f)
                                         (i32.const 1)))
                          (then (call $raise-vector-argument-error/who
                                      (global.get ,who)
                                      (global.get $string:vector-unary-real-procedure)
                                      (local.get $proc))
                                (unreachable)))
                      (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

                      ;; Validate vector
                      (if (ref.test (ref $Vector) (local.get $vec))
                          (then (local.set $vector (ref.cast (ref $Vector) (local.get $vec))))
                          (else (call $raise-check-vector/who
                                      (global.get ,who)
                                      (local.get $vec))
                                (unreachable)))
                      (local.set $len (array.len (struct.get $Vector $arr (local.get $vector))))
                      ;; non-empty vector
                      (if (i32.eqz (local.get $len))
                          (then (call $raise-vector-argument-error/who
                                      (global.get ,who)
                                      (global.get $string:non-empty-vector)
                                      (local.get $vec))
                                (unreachable)))
                      ;; Prepare argument array
                      (local.set $args (array.new $Args (global.get $null) (i32.const 1)))
                      ;; Seed with first element
                      (local.set $best (array.get $Array (struct.get $Vector $arr (local.get $vector)) (i32.const 0)))
                      (array.set $Args (local.get $args) (i32.const 0) (local.get $best))
                      (local.set $bestv (call_ref $ProcedureInvoker
                                                  (local.get $f)
                                                  (local.get $args)
                                                  (local.get $finv)))
                      (if (ref.eq (call $real? (local.get $bestv))
                                  (global.get $false))
                          (then (call $raise-result-error
                                      (global.get ,who)
                                      (global.get $string:real?)
                                      (local.get $bestv))
                                (unreachable)))
                      (local.set $i (i32.const 1))
                      ;; Iterate remaining elements
                      (block $done
                             (loop $loop
                                   (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                   (local.set $elem (array.get $Array
                                                               (struct.get $Vector $arr (local.get $vector))
                                                               (local.get $i)))
                                   (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                                   (local.set $val (call_ref $ProcedureInvoker
                                                             (local.get $f)
                                                             (local.get $args)
                                                             (local.get $finv)))
                                   (if (ref.eq (call $real? (local.get $val))
                                               (global.get $false))
                                       (then (call $raise-result-error
                                                   (global.get ,who)
                                                   (global.get $string:real?)
                                                   (local.get $val))
                                             (unreachable)))
                                   (if (ref.eq (call ,cmp (local.get $bestv) (local.get $val))
                                               (global.get $true))
                                       (then (local.set $best  (local.get $elem))
                                             (local.set $bestv (local.get $val))))
                                   (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                   (br $loop)))
                      (local.get $best))))
            (append (gen-vector-argminmax '$vector-argmax '$</2)
                    (gen-vector-argminmax '$vector-argmin '$>/2))))

;; vector-argminmax-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector argmin and argmax helpers used by the monolithic runtime.
(define vector-argminmax-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-argminmax-runtime-only-helpers
   vector-argminmax-runtime-only-forms))

;; vector-argminmax-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector argmin and argmax helpers.
(define vector-argminmax-runtime-only-helper-names
  (map core-runtime-helper-name vector-argminmax-runtime-only-helpers))


;; vector-filter-search-runtime-only-forms : (listof datum?)
;;   Enumerate vector filter and search helpers used by the monolithic runtime.
(define vector-filter-search-runtime-only-forms
  `(
        (func $vector-filter/template
              (param $who  (ref eq))  ;; caller name
              (param $proc (ref eq))  ;; predicate, must accept one argument
              (param $vec  (ref eq))  ;; vector
              (param $not? i32)       ;; 1 => keep elements where predicate returns #f
              (result      (ref eq))

              (local $f     (ref $Procedure))
              (local $finv  (ref $ProcedureInvoker))
              (local $v     (ref $Vector))
              (local $len   i32)
              (local $call  (ref $Args))
              (local $i     i32)
              (local $elem  (ref eq))
              (local $r     (ref eq))
              (local $ga    (ref $GrowableArray))
              (local $arr   (ref $Array))

              ;; 1) Validate procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-vector-argument-error/who
                              (local.get $who)
                              (global.get $string:vector-unary-any-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 1)))
                  (then (call $raise-vector-argument-error/who
                              (local.get $who)
                              (global.get $string:vector-unary-any-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              ;; 2) Validate vector
              (local.set $v (global.get $dummy-vector))
              (if (ref.test (ref $Vector) (local.get $vec))
                  (then (local.set $v (ref.cast (ref $Vector) (local.get $vec))))
                  (else (call $raise-check-vector/who
                              (local.get $who)
                              (local.get $vec))
                        (unreachable)))
              (local.set $len (array.len (struct.get $Vector $arr (local.get $v))))
              ;; 3) Prepare argument array and growable result array
              (local.set $call (array.new $Args (global.get $null) (i32.const 1)))
              (local.set $ga   (call $make-growable-array (local.get $len)))
              ;; 4) Single pass over elements
              (local.set $i (i32.const 0))
              (block $loop-done
                     (loop $loop
                           (br_if $loop-done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $elem
                                      (array.get $Array
                                                 (struct.get $Vector $arr (local.get $v))
                                                 (local.get $i)))
                           (array.set $Args (local.get $call) (i32.const 0) (local.get $elem))
                           (local.set $r
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $call)
                                                (local.get $finv)))
                           (if (i32.eqz (local.get $not?))
                               (then (if (ref.eq (local.get $r) (global.get $false))
                                         (then (nop))
                                         (else (call $growable-array-add! (local.get $ga) (local.get $elem)))))
                               (else (if (ref.eq (local.get $r) (global.get $false))
                                         (then (call $growable-array-add! (local.get $ga) (local.get $elem))))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              ;; 5) Turn growable array into vector
              (local.set $arr (call $growable-array->array (local.get $ga)))
              (struct.new $Vector (i32.const 0) (i32.const 0) (local.get $arr)))



            (func $vector-filter (type $Prim2)
                  (param $proc (ref eq))  ;; predicate
                  (param $vec  (ref eq))  ;; vector
                  (result (ref eq))
                  (call $vector-filter/template
                        (global.get $symbol:vector-filter)
                        (local.get $proc) (local.get $vec) (i32.const 0)))

            (func $vector-filter-not (type $Prim2)
                  (param $proc (ref eq))  ;; predicate
                  (param $vec  (ref eq))  ;; vector
                  (result (ref eq))
                  (call $vector-filter/template
                        (global.get $symbol:vector-filter-not)
                        (local.get $proc) (local.get $vec) (i32.const 1)))

            ,@(for/list ([name '($vector-memq $vector-memv)]
                         [cmp  '((ref.eq (local.get $needle)             (local.get $elem))
                                 (ref.eq (call $eqv? (local.get $needle) (local.get $elem))
                                         (global.get $true)))])
                `(func ,name (type $Prim2)
                       (param $needle (ref eq)) ;; value to find
                       (param $v      (ref eq)) ;; vector to search
                       (result (ref eq))        ;; fixnum index or #f

                       (local $vec  (ref $Vector))
                       (local $arr  (ref $Array))
                       (local $len  i32)
                       (local $i    i32)
                       (local $elem (ref eq))

                       ;; Ensure $v is a vector
                       (local.set $vec (global.get $dummy-vector))
                       (if (ref.test (ref $Vector) (local.get $v))
                           (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                           (else (call $raise-check-vector (local.get $v))
                                 (unreachable)))

                       (local.set $arr (struct.get $Vector $arr (local.get $vec)))
                       (local.set $len (array.len (local.get $arr)))
                       (local.set $i   (i32.const 0))
                       (loop $loop
                             (if (i32.ge_u (local.get $i) (local.get $len))
                                 (then (return (global.get $false))))
                             (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                             (if ,cmp
                                 (then (return (ref.i31 (i32.shl (local.get $i)
                                                                 (i32.const 1))))))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $loop))
                       (unreachable)))

            (func $vector-member/2
                  (param $v   (ref eq))  ;; value to find
                  (param $vec (ref eq))  ;; vector to search
                  (result     (ref eq))

                  (local $vecv (ref $Vector))
                  (local $len  i32)
                  (local $i    i32)
                  (local $elem (ref eq))

                  (local.set $vecv (global.get $dummy-vector))
                  (if (ref.test (ref $Vector) (local.get $vec))
                      (then (local.set $vecv (ref.cast (ref $Vector) (local.get $vec))))
                      (else (call $raise-check-vector/who
                                  (global.get $symbol:vector-member)
                                  (local.get $vec))))
                  (local.set $len (array.len (struct.get $Vector $arr (local.get $vecv))))
                  (local.set $i   (i32.const 0))
                  (loop $loop
                        (if (i32.ge_u (local.get $i) (local.get $len))
                            (then (return (global.get $false))))
                        (local.set $elem
                                   (array.get $Array
                                              (struct.get $Vector $arr (local.get $vecv))
                                              (local.get $i)))
                        (if (ref.eq (call $equal? (local.get $v) (local.get $elem))
                                    (global.get $true))
                            (then (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop))
                  (unreachable))

            (func $vector-member (type $Prim23)
                  (param $v     (ref eq)) ;; value to find
                  (param $vec   (ref eq)) ;; vector to search
                  (param $same? (ref eq)) ;; optional comparator, default equal?
                  (result       (ref eq))

                  (local $vecv (ref $Vector))
                  (local $len  i32)
                  (local $i    i32)
                  (local $elem (ref eq))
                  (local $args (ref $Args))
                  (local $res  (ref eq))

                  (if (ref.eq (local.get $same?) (global.get $missing))
                      (then (return (call $vector-member/2 (local.get $v) (local.get $vec)))))

                  (local.set $vecv (global.get $dummy-vector))
                  (if (ref.test (ref $Vector) (local.get $vec))
                      (then (local.set $vecv (ref.cast (ref $Vector) (local.get $vec))))
                      (else (call $raise-check-vector/who
                                  (global.get $symbol:vector-member)
                                  (local.get $vec))))

                  (if (ref.eq (call $procedure? (local.get $same?))
                              (global.get $false))
                      (then (call $raise-vector-argument-error/who
                                  (global.get $symbol:vector-member)
                                  (global.get $string:procedure?)
                                  (local.get $same?))
                            (unreachable)))

                  (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
                  (local.set $len  (array.len (struct.get $Vector $arr (local.get $vecv))))
                  (local.set $i    (i32.const 0))

                  (loop $loop
                        (if (i32.ge_u (local.get $i) (local.get $len))
                            (then (return (global.get $false))))
                        (local.set $elem (array.get $Array
                                                    (struct.get $Vector $arr (local.get $vecv))
                                                    (local.get $i)))
                        (array.set $Args (local.get $args) (i32.const 0) (local.get $v))
                        (array.set $Args (local.get $args) (i32.const 1) (local.get $elem))
                        (local.set $res
                                   (call_ref $ProcedureInvoker
                                             (ref.cast (ref $Procedure) (local.get $same?))
                                             (local.get $args)
                                             (struct.get $Procedure $invoke
                                                         (ref.cast (ref $Procedure) (local.get $same?)))))
                        (if (ref.eq (local.get $res) (global.get $true))
                            (then (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop))
                  (unreachable))



     ))

;; vector-filter-search-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector filter and search helpers used by the monolithic runtime.
(define vector-filter-search-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-filter-search-runtime-only-helpers
   vector-filter-search-runtime-only-forms))

;; vector-filter-search-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector filter and search helpers.
(define vector-filter-search-runtime-only-helper-names
  (map core-runtime-helper-name vector-filter-search-runtime-only-helpers))


;; vector-sort-runtime-only-forms : (listof datum?)
;;   Enumerate vector sorting helpers used by the monolithic runtime.
(define vector-sort-runtime-only-forms
  '(
            ;;; Vector Sorting

            ;; Quicksort with median-of-three pivot and insertion sort cutoff.
            ;; #:key and #:cache-keys? arguments are not supported.

            (func $vector-sort!:swap!
                  (param $vec (ref $Vector)) ;; vector
                  (param $i   i32)           ;; index
                  (param $j   i32)           ;; index

                  (local $arr (ref $Array))
                  (local $tmp (ref eq))
                  (local.set $arr   (struct.get $Vector $arr (local.get $vec)))
                  (local.set $tmp   (array.get $Array (local.get $arr) (local.get $i)))
                  (array.set $Array (local.get $arr) (local.get $i)
                             (array.get $Array (local.get $arr) (local.get $j)))
                  (array.set $Array (local.get $arr) (local.get $j) (local.get $tmp)))

            (func $vector-sort!:lt-idx?
                  (param $vec  (ref $Vector))            ;; vector
                  (param $f    (ref $Procedure))         ;; less-than
                  (param $finv (ref $ProcedureInvoker))  ;; invoker
                  (param $call (ref $Args))              ;; args array
                  (param $i    i32)                      ;; index
                  (param $j    i32)                      ;; index
                  (result      i32)

                  (local $arr (ref $Array))
                  (local $x   (ref eq))
                  (local $y   (ref eq))
                  (local $r   (ref eq))

                  (local.set $arr  (struct.get $Vector $arr (local.get $vec)))
                  (local.set $x    (array.get $Array (local.get $arr) (local.get $i)))
                  (local.set $y    (array.get $Array (local.get $arr) (local.get $j)))
                  (array.set $Args (local.get $call) (i32.const 0) (local.get $x))
                  (array.set $Args (local.get $call) (i32.const 1) (local.get $y))
                  (local.set $r    (call_ref $ProcedureInvoker
                                             (local.get $f)
                                             (local.get $call)
                                             (local.get $finv)))
                  (i32.eqz (ref.eq (local.get $r) (global.get $false))))

        (func $vector-sort!:median-of-three->end!
              (param $vec  (ref $Vector))            ;; vector
              (param $f    (ref $Procedure))         ;; less-than
              (param $finv (ref $ProcedureInvoker))  ;; invoker
              (param $call (ref $Args))              ;; args array
              (param $lo   i32)                      ;; start index
              (param $hi   i32)                      ;; end index (exclusive)

              (local $i i32)
              (local $k i32)
              (local $m i32)

              (local.set $i (local.get $lo))
              (local.set $k (i32.sub (local.get $hi) (i32.const 1)))
              (local.set $m (i32.add (local.get $lo)
                                     (i32.shr_u (i32.sub (local.get $hi) (local.get $lo))
                                                (i32.const 1))))
              (if (i32.ne (call $vector-sort!:lt-idx? (local.get $vec) (local.get $f)
                                                   (local.get $finv) (local.get $call)
                                                   (local.get $k) (local.get $i))
                          (i32.const 0))
                  (then (call $vector-sort!:swap! (local.get $vec) (local.get $k) (local.get $i))))
              (if (i32.ne (call $vector-sort!:lt-idx? (local.get $vec) (local.get $f)
                                                   (local.get $finv) (local.get $call)
                                                   (local.get $m) (local.get $i))
                          (i32.const 0))
                  (then (call $vector-sort!:swap! (local.get $vec) (local.get $m) (local.get $i))))
              (if (i32.ne (call $vector-sort!:lt-idx? (local.get $vec) (local.get $f)
                                                   (local.get $finv) (local.get $call)
                                                   (local.get $k) (local.get $m))
                          (i32.const 0))
                  (then (call $vector-sort!:swap! (local.get $vec) (local.get $k) (local.get $m))))
              (call $vector-sort!:swap! (local.get $vec) (local.get $m) (local.get $k)))

        (func $vector-sort!:partition!
              (param $vec  (ref $Vector))            ;; vector
              (param $f    (ref $Procedure))         ;; less-than
              (param $finv (ref $ProcedureInvoker))  ;; invoker
              (param $call (ref $Args))              ;; args array
              (param $lo   i32)                      ;; start index
              (param $hi   i32)                      ;; end index (exclusive)
              (result      i32)

              (local $arr   (ref $Array))
              (local $pivot (ref eq))
              (local $i     i32)
              (local $j     i32)
              (local $elem  (ref eq))
              (local $r     (ref eq))

              (local.set $arr   (struct.get $Vector $arr (local.get $vec)))
              (local.set $pivot (array.get $Array (local.get $arr)
                                           (i32.sub (local.get $hi) (i32.const 1))))
              (local.set $i     (local.get $lo))
              (local.set $j     (local.get $lo))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $j)
                                                  (i32.sub (local.get $hi) (i32.const 1))))
                           (local.set $elem (array.get $Array (local.get $arr) (local.get $j)))
                           (array.set $Args (local.get $call) (i32.const 0) (local.get $elem))
                           (array.set $Args (local.get $call) (i32.const 1) (local.get $pivot))
                           (local.set $r (call_ref $ProcedureInvoker
                                                   (local.get $f)
                                                   (local.get $call)
                                                   (local.get $finv)))
                           (if (i32.eqz (ref.eq (local.get $r) (global.get $false)))
                               (then (call $vector-sort!:swap! (local.get $vec) (local.get $i) (local.get $j))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))))
                           (local.set $j (i32.add (local.get $j) (i32.const 1)))
                           (br $loop)))
              (call $vector-sort!:swap! (local.get $vec) (local.get $i)
                                        (i32.sub (local.get $hi) (i32.const 1)))
              (local.get $i))

        (func $vector-sort!:insertion-sort!
              (param $vec  (ref $Vector))            ;; vector
              (param $f    (ref $Procedure))         ;; less-than
              (param $finv (ref $ProcedureInvoker))  ;; invoker
              (param $call (ref $Args))              ;; args array
              (param $lo   i32)                      ;; start index
              (param $hi   i32)                      ;; end index (exclusive)

              (local $arr  (ref $Array))
              (local $i    i32)
              (local $j    i32)
              (local $key  (ref eq))
              (local $elem (ref eq))
              (local $r    (ref eq))

              (local.set $arr (struct.get $Vector $arr (local.get $vec)))
              (local.set $i   (i32.add (local.get $lo) (i32.const 1)))
              (block $outer-done
                     (loop $outer
                           (br_if $outer-done (i32.ge_u (local.get $i) (local.get $hi)))
                           (local.set $key (array.get $Array (local.get $arr) (local.get $i)))
                           (local.set $j (i32.sub (local.get $i) (i32.const 1)))
                           (block $inner-done
                                  (loop $inner
                                        (br_if $inner-done
                                               (i32.lt_s (local.get $j) (local.get $lo)))
                                        (local.set $elem (array.get $Array (local.get $arr) (local.get $j)))
                                        (array.set $Args (local.get $call) (i32.const 0) (local.get $key))
                                        (array.set $Args (local.get $call) (i32.const 1) (local.get $elem))
                                        (local.set $r (call_ref $ProcedureInvoker
                                                                (local.get $f)
                                                                (local.get $call)
                                                                (local.get $finv)))
                                        (br_if $inner-done
                                               (ref.eq (local.get $r) (global.get $false)))
                                        (array.set $Array (local.get $arr)
                                                   (i32.add (local.get $j) (i32.const 1))
                                                   (local.get $elem))
                                        (local.set $j (i32.sub (local.get $j) (i32.const 1)))
                                        (br $inner)))
                           (array.set $Array (local.get $arr)
                                      (i32.add (local.get $j) (i32.const 1))
                                      (local.get $key))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $outer))))

        (func $vector-sort!:qs!
              (param $vec  (ref $Vector))            ;; vector
              (param $f    (ref $Procedure))         ;; less-than
              (param $finv (ref $ProcedureInvoker))  ;; invoker
              (param $call (ref $Args))              ;; args array
              (param $lo   i32)                      ;; start index
              (param $hi   i32)                      ;; end index (exclusive)

              (local $p     i32)
              (local $left  i32)
              (local $right i32)

              (block $done
                     (loop $loop
                           ; If the range to sort is shorted than 16, then use insertion sort.
                           ; Otherwise, ...
                           (if (i32.le_u (i32.sub (local.get $hi) (local.get $lo)) (i32.const 16))
                               (then (call $vector-sort!:insertion-sort!
                                           (local.get $vec) (local.get $f) (local.get $finv)
                                           (local.get $call) (local.get $lo) (local.get $hi))
                                     (br $done)))
                           (call $vector-sort!:median-of-three->end!
                                 (local.get $vec) (local.get $f) (local.get $finv)
                                 (local.get $call) (local.get $lo) (local.get $hi))
                           (local.set $p (call $vector-sort!:partition!
                                                (local.get $vec) (local.get $f)
                                                (local.get $finv) (local.get $call)
                                                (local.get $lo) (local.get $hi)))
                           (local.set $left (i32.sub (local.get $p) (local.get $lo)))
                           (local.set $right (i32.sub (local.get $hi)
                                                      (i32.add (local.get $p) (i32.const 1))))
                           (if (i32.lt_u (local.get $left) (local.get $right))
                               (then (call $vector-sort!:qs!
                                           (local.get $vec) (local.get $f) (local.get $finv)
                                           (local.get $call) (local.get $lo) (local.get $p))
                                     (local.set $lo (i32.add (local.get $p) (i32.const 1)))
                                     (br $loop))
                               (else (call $vector-sort!:qs!
                                           (local.get $vec) (local.get $f) (local.get $finv)
                                           (local.get $call)
                                           (i32.add (local.get $p) (i32.const 1))
                                           (local.get $hi))
                                     (local.set $hi (local.get $p))
                                     (br $loop))))))

        (func $vector-sort! (type $Prim24)
              (param $v     (ref eq))   ;; vector
              (param $proc  (ref eq))   ;; less-than procedure
              (param $start (ref eq))   ;; fixnum or $missing, default: 0
              (param $end   (ref eq))   ;; fixnum or $missing, default: (vector-length v)
              (result       (ref eq))

              (local $vec  (ref $Vector))
              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $call (ref $Args))
              (local $lo   i32)
              (local $hi   i32)
              (local $len  i32)

              ;; Validate vector
              (local.set $vec (global.get $dummy-vector))
              (if (ref.test (ref $Vector) (local.get $v))
                  (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-sort!)
                              (local.get $v))
                        (unreachable)))
              (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                  (then (call $raise-immutable-vector/who
                              (global.get $symbol:vector-sort!)
                              (local.get $v))
                        (unreachable)))

              ;; Validate procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-vector-argument-error/who
                              (global.get $symbol:vector-sort!)
                              (global.get $string:vector-binary-any-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 2)))
                  (then (call $raise-vector-argument-error/who
                              (global.get $symbol:vector-sort!)
                              (global.get $string:vector-binary-any-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $call (array.new $Args (global.get $null) (i32.const 2)))

              ;; Decode start/end and check range
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
              (if (ref.eq (local.get $start) (global.get $missing))
                  (then (local.set $lo (i32.const 0)))
                  (else (local.set $lo
                                   (call $vector-index/i32
                                         (global.get $symbol:vector-sort!)
                                         (local.get $start)))))
              (if (ref.eq (local.get $end) (global.get $missing))
                  (then (local.set $hi (local.get $len)))
                  (else (local.set $hi
                                   (call $vector-index/i32
                                         (global.get $symbol:vector-sort!)
                                         (local.get $end)))))
              (if (i32.or
                   (i32.or (i32.gt_u (local.get $lo) (local.get $len))
                           (i32.gt_u (local.get $hi) (local.get $len)))
                   (i32.gt_u (local.get $lo) (local.get $hi)))
                  (then (call $raise-bad-vector-copy-range/who
                              (global.get $symbol:vector-sort!)
                              (local.get $vec) (local.get $lo)
                              (local.get $vec) (local.get $lo) (local.get $hi))
                        (unreachable)))

              ;; Sort when range has more than one element
              (if (i32.lt_u (i32.add (local.get $lo) (i32.const 1)) (local.get $hi))
                  (then (call $vector-sort!:qs! (local.get $vec) (local.get $f)
                                                (local.get $finv) (local.get $call)
                                                (local.get $lo) (local.get $hi))))

              (local.get $vec))


        (func $vector-sort (type $Prim24)
              (param $v     (ref eq))   ;; vector
              (param $proc  (ref eq))   ;; less-than procedure
              (param $start (ref eq))   ;; fixnum or $missing, default: 0
              (param $end   (ref eq))   ;; fixnum or $missing, default: (vector-length v)
              (result       (ref eq))

              (local $copy (ref eq))
              (local $f    (ref $Procedure))

              ;; Validate procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-vector-argument-error/who
                              (global.get $symbol:vector-sort)
                              (global.get $string:vector-binary-any-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 2)))
                  (then (call $raise-vector-argument-error/who
                              (global.get $symbol:vector-sort)
                              (global.get $string:vector-binary-any-procedure)
                              (local.get $proc))
                        (unreachable)))

              ;; Copy the vector or subvector
              (local.set $copy
                         (call $vector-copy/who
                               (global.get $symbol:vector-sort)
                               (local.get $v)
                               (local.get $start)
                               (local.get $end)))

              ;; Sort the copy and return it
              (call $vector-sort!
                    (local.get $copy) (local.get $proc) (global.get $missing) (global.get $missing)))

        (func $vector-sort/expanded-keywords (type $Prim6)
              (param $v           (ref eq)) ; vector to sort
              (param $proc        (ref eq)) ; less-than? procedure
              (param $kw-key      (ref eq)) ; expanded #:key marker
              (param $key-proc    (ref eq)) ; key procedure or #f
              (param $kw-cache    (ref eq)) ; expanded #:cache-keys? marker
              (param $cache-keys? (ref eq)) ; accepted for compatibility
              (result             (ref eq))

              (local $xs        (ref eq))
              (local $sorted-xs (ref eq))

              ;; Support the common keyword path by sorting a vector slice as a
              ;; list with the existing `sort` keyword implementation.
              (if (ref.eq (local.get $key-proc) (global.get $false))
                  (then
                   (return_call $vector-sort
                                (local.get $v)
                                (local.get $proc)
                                (global.get $missing)
                                (global.get $missing))))
              (local.set $xs
                         (call $vector->list
                               (call $vector-copy/who
                                     (global.get $symbol:vector-sort)
                                     (local.get $v)
                                     (global.get $missing)
                                     (global.get $missing))))
              (local.set $sorted-xs
                         (call $sort/expanded-keywords
                               (local.get $xs)
                               (local.get $proc)
                               (local.get $kw-key)
                               (local.get $key-proc)
                               (local.get $kw-cache)
                               (local.get $cache-keys?)))
              (call $list->vector (local.get $sorted-xs)))

        (func $vector-sort!/expanded-keywords (type $Prim6)
              (param $v           (ref eq)) ; vector to sort in place
              (param $proc        (ref eq)) ; less-than? procedure
              (param $kw-key      (ref eq)) ; expanded #:key marker
              (param $key-proc    (ref eq)) ; key procedure or #f
              (param $kw-cache    (ref eq)) ; expanded #:cache-keys? marker
              (param $cache-keys? (ref eq)) ; accepted for compatibility
              (result             (ref eq))

              (local $sorted (ref eq))

              ;; The keyword bridge covers the whole-vector case. Optional
              ;; start/end plus keywords can be added with a wider invoker when
              ;; Goal 1 needs that surface.
              (if (ref.eq (local.get $key-proc) (global.get $false))
                  (then
                   (return_call $vector-sort!
                                (local.get $v)
                                (local.get $proc)
                                (global.get $missing)
                                (global.get $missing))))
              (local.set $sorted
                         (call $vector-sort/expanded-keywords
                               (local.get $v)
                               (local.get $proc)
                               (local.get $kw-key)
                               (local.get $key-proc)
                               (local.get $kw-cache)
                               (local.get $cache-keys?)))
              (return_call $vector-copy!
                           (local.get $v)
                           (ref.i31 (i32.const 0))
                           (local.get $sorted)
                           (global.get $missing)
                           (global.get $missing)))

        (func $vector-sort/keyword-apply (type $Prim4)
              (param $kws      (ref eq)) ; sorted keyword list from keyword-procedure-extract
              (param $kw-args  (ref eq)) ; parallel keyword value list
              (param $v        (ref eq)) ; vector to sort
              (param $proc     (ref eq)) ; less-than? procedure
              (result          (ref eq))

              (local $kw-cell      (ref $Pair))
              (local $kw-rest      (ref eq))
              (local $arg-cell     (ref $Pair))
              (local $arg-rest     (ref eq))
              (local $key-proc     (ref eq))
              (local $cache-keys?  (ref eq))

              ;; Like the `sort` bridge, parse each keyword/value pair by name.
              (local.set $key-proc    (global.get $false))
              (local.set $cache-keys? (global.get $false))
              (local.set $kw-rest (local.get $kws))
              (local.set $arg-rest (local.get $kw-args))
              (block $done
                (loop $loop
                  (if (i32.eqz (ref.test (ref $Pair) (local.get $kw-rest)))
                      (then (br $done)))
                  (local.set $kw-cell (ref.cast (ref $Pair) (local.get $kw-rest)))
                  (local.set $arg-cell (ref.cast (ref $Pair) (local.get $arg-rest)))
                  (if (ref.eq
                       (struct.get $Pair $a (local.get $kw-cell))
                       (call
                        $string->keyword/checked
                        (ref.cast (ref $String) (global.get $string:keyword:key))))
                      (then
                       (local.set $key-proc (struct.get $Pair $a (local.get $arg-cell)))))
                  (if (ref.eq
                       (struct.get $Pair $a (local.get $kw-cell))
                       (call
                        $string->keyword/checked
                        (ref.cast (ref $String) (global.get $string:keyword:cache-keys?))))
                      (then
                       (local.set $cache-keys? (struct.get $Pair $a (local.get $arg-cell)))))
                  (local.set $kw-rest (struct.get $Pair $d (local.get $kw-cell)))
                  (local.set $arg-rest (struct.get $Pair $d (local.get $arg-cell)))
                  (br $loop)))
              (if (ref.test (ref $Pair) (local.get $kw-args))
                  (then
                   (local.set $arg-cell (ref.cast (ref $Pair) (local.get $kw-args)))
                   (if (ref.eq (struct.get $Pair $d (local.get $arg-cell))
                               (global.get $null))
                       (then
                        (local.set $key-proc
                                   (struct.get $Pair $a (local.get $arg-cell)))))))
              (return_call $vector-sort/expanded-keywords
                           (local.get $v)
                           (local.get $proc)
                           (global.get $missing)
                           (local.get $key-proc)
                           (global.get $missing)
                           (local.get $cache-keys?)))

        (func $vector-sort!/keyword-apply (type $Prim4)
              (param $kws      (ref eq)) ; sorted keyword list from keyword-procedure-extract
              (param $kw-args  (ref eq)) ; parallel keyword value list
              (param $v        (ref eq)) ; vector to sort in place
              (param $proc     (ref eq)) ; less-than? procedure
              (result          (ref eq))

              (local $kw-cell      (ref $Pair))
              (local $kw-rest      (ref eq))
              (local $arg-cell     (ref $Pair))
              (local $arg-rest     (ref eq))
              (local $key-proc     (ref eq))
              (local $cache-keys?  (ref eq))

              (local.set $key-proc    (global.get $false))
              (local.set $cache-keys? (global.get $false))
              (local.set $kw-rest (local.get $kws))
              (local.set $arg-rest (local.get $kw-args))
              (block $done
                (loop $loop
                  (if (i32.eqz (ref.test (ref $Pair) (local.get $kw-rest)))
                      (then (br $done)))
                  (local.set $kw-cell (ref.cast (ref $Pair) (local.get $kw-rest)))
                  (local.set $arg-cell (ref.cast (ref $Pair) (local.get $arg-rest)))
                  (if (ref.eq
                       (struct.get $Pair $a (local.get $kw-cell))
                       (call
                        $string->keyword/checked
                        (ref.cast (ref $String) (global.get $string:keyword:key))))
                      (then
                       (local.set $key-proc (struct.get $Pair $a (local.get $arg-cell)))))
                  (if (ref.eq
                       (struct.get $Pair $a (local.get $kw-cell))
                       (call
                        $string->keyword/checked
                        (ref.cast (ref $String) (global.get $string:keyword:cache-keys?))))
                      (then
                       (local.set $cache-keys? (struct.get $Pair $a (local.get $arg-cell)))))
                  (local.set $kw-rest (struct.get $Pair $d (local.get $kw-cell)))
                  (local.set $arg-rest (struct.get $Pair $d (local.get $arg-cell)))
                  (br $loop)))
              (if (ref.test (ref $Pair) (local.get $kw-args))
                  (then
                   (local.set $arg-cell (ref.cast (ref $Pair) (local.get $kw-args)))
                   (if (ref.eq (struct.get $Pair $d (local.get $arg-cell))
                               (global.get $null))
                       (then
                        (local.set $key-proc
                                   (struct.get $Pair $a (local.get $arg-cell)))))))
              (return_call $vector-sort!/expanded-keywords
                           (local.get $v)
                           (local.get $proc)
                           (global.get $missing)
                           (local.get $key-proc)
                           (global.get $missing)
                           (local.get $cache-keys?)))


     ))

;; vector-sort-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector sorting helpers used by the monolithic runtime.
(define vector-sort-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-sort-runtime-only-helpers
   vector-sort-runtime-only-forms))

;; vector-sort-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector sorting helpers.
(define vector-sort-runtime-only-helper-names
  (map core-runtime-helper-name vector-sort-runtime-only-helpers))

;; vector-core-operation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for core vector operation helpers.
(define vector-core-operation-runtime-only-helper-names
  '($vector?/i32))

;; vector-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given vector helper names from the runtime helper index.
(define (vector-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; vector-mutability-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render vector mutability predicates in runtime assembly order.
(define (vector-mutability-runtime-helper-forms helper-index)
  (vector-helper-forms helper-index vector-mutability-runtime-only-helper-names))

;; vector-error-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render vector error helpers in runtime assembly order.
(define (vector-error-runtime-helper-forms helper-index)
  (vector-helper-forms helper-index vector-error-runtime-only-helper-names))

;; vector-main-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render the vector helper block before stencil vectors in runtime assembly order.
(define (vector-main-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (append
   (vector-helper-forms runtime-helper-index vector-make-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-constructor-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-build-runtime-only-helper-names)
   (vector-helper-forms core-runtime-helper-index vector-core-operation-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-operation-runtime-only-helper-names)))

;; vector-post-stencil-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render the vector helper block after stencil vectors in runtime assembly order.
(define (vector-post-stencil-runtime-helper-forms runtime-helper-index)
  (append
   (vector-helper-forms runtime-helper-index vector-copy-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-extend-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-append-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-slice-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-list-conversion-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-map-count-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-argminmax-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-filter-search-runtime-only-helper-names)
   (vector-helper-forms runtime-helper-index vector-sort-runtime-only-helper-names)))

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

;; vector-promoted-runtime-helper-names : (listof symbol?)
;;   Name runtime vector helpers that are available in the standalone core runtime.
(define vector-promoted-runtime-helper-names
  (append vector-error-runtime-only-helper-names
          vector-make-runtime-only-helper-names
          vector-constructor-runtime-only-helper-names
          vector-build-runtime-only-helper-names
          vector-operation-runtime-only-helper-names
          vector-copy-runtime-only-helper-names
          vector-extend-runtime-only-helper-names
          vector-append-runtime-only-helper-names
          vector-slice-runtime-only-helper-names
          vector-list-conversion-runtime-only-helper-names
          vector-map-count-runtime-only-helper-names
          vector-argminmax-runtime-only-helper-names
          vector-filter-search-runtime-only-helper-names
          vector-sort-runtime-only-helper-names
          vector-mutability-runtime-only-helper-names))

;; vector-mutability-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector mutability predicates used by the monolithic runtime.
(define vector-mutability-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-mutability-runtime-only-helpers
   '(
         (func $mutable-vector? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Vector $immutable
                                                 (ref.cast (ref $Vector) (local.get $v)))
                                     (i32.const 0))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $immutable-vector? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Vector $immutable
                                                 (ref.cast (ref $Vector) (local.get $v)))
                                     (i32.const 1))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))


     )))

;; vector-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers in monolithic runtime order.
(define vector-all-runtime-helpers
  (append
   vector-error-runtime-only-helpers
   vector-make-runtime-only-helpers
   vector-constructor-runtime-only-helpers
   vector-build-runtime-only-helpers
   vector-operation-runtime-only-helpers
   vector-copy-runtime-only-helpers
   vector-extend-runtime-only-helpers
   vector-append-runtime-only-helpers
   vector-slice-runtime-only-helpers
   vector-list-conversion-runtime-only-helpers
   vector-map-count-runtime-only-helpers
   vector-argminmax-runtime-only-helpers
   vector-filter-search-runtime-only-helpers
   vector-sort-runtime-only-helpers
   vector-mutability-runtime-only-helpers))

;; vector-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers available in the standalone core runtime.
(define vector-core-runtime-helpers
  (append vector-base-core-runtime-helpers
          (select-runtime-helpers vector-all-runtime-helpers
                                  vector-promoted-runtime-helper-names)))

;; vector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers that still depend on monolithic runtime globals.
(define vector-runtime-only-helpers
  (remove-runtime-helpers vector-all-runtime-helpers
                          vector-promoted-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define vector-helper-index
    (make-core-runtime-helper-index
     (append vector-core-runtime-helpers
             vector-runtime-only-helpers)))

  (define vector-core-helper-index
    (make-core-runtime-helper-index vector-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name vector-core-runtime-helpers)
   (append vector-core-operation-runtime-only-helper-names
           vector-promoted-runtime-helper-names))

  (check-equal?
   (map form-name (vector-mutability-runtime-helper-forms vector-helper-index))
   vector-mutability-runtime-only-helper-names)

  (check-equal?
   (map form-name (vector-error-runtime-helper-forms vector-helper-index))
   vector-error-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (vector-main-runtime-helper-forms vector-helper-index vector-core-helper-index))
   (append vector-make-runtime-only-helper-names
           vector-constructor-runtime-only-helper-names
           vector-build-runtime-only-helper-names
           vector-core-operation-runtime-only-helper-names
           vector-operation-runtime-only-helper-names))

  (check-equal?
   (map form-name
        (vector-post-stencil-runtime-helper-forms vector-helper-index))
   (append vector-copy-runtime-only-helper-names
           vector-extend-runtime-only-helper-names
           vector-append-runtime-only-helper-names
           vector-slice-runtime-only-helper-names
           vector-list-conversion-runtime-only-helper-names
           vector-map-count-runtime-only-helper-names
           vector-argminmax-runtime-only-helper-names
           vector-filter-search-runtime-only-helper-names
           vector-sort-runtime-only-helper-names)))
