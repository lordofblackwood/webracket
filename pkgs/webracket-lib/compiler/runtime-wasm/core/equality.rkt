#lang racket

(provide equality-core-runtime-helpers
         equality-primitive-global-forms
         equality-primitive-global-names
         equality-runtime-only-helpers
         equality-core-runtime-helper-forms
         immutable-predicate-core-runtime-helper-forms
         immutable-predicate-runtime-helper-forms
         equality-runtime-helper-forms)

(require "../core-helper.rkt")

;; equality-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by an equality support global form.
(define (equality-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'equality-global-form-name
              "expected global form, got: ~s"
              form)]))

;; equality-primitive-global-forms : (listof datum?)
;;   Declare primitive procedure globals used as first-class comparators.
(define equality-primitive-global-forms
  '(
               (global $prim:eq?           (mut (ref eq)) (global.get $undefined))
               (global $prim:eqv?          (mut (ref eq)) (global.get $undefined))
               (global $prim:equal?        (mut (ref eq)) (global.get $undefined))
               (global $prim:equal-always? (mut (ref eq)) (global.get $undefined))))

;; equality-primitive-global-names : (listof symbol?)
;;   Enumerate equality primitive procedure globals shared by split modules.
(define equality-primitive-global-names
  (map equality-global-form-name equality-primitive-global-forms))

;; equality-all-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for equality helpers.
(define equality-all-runtime-helper-names
  '($eq?
    $eqv?
    $equal?
    $equal?/slow
    $regexp-equal?
    $equal?/pair
    $equal?/box
    $equal?/vector
    $equal?/hash
    $equal?/struct
    $equal+hash-recur/equal
    $equal+hash-recur/equal-always
    $equal+hash-recur/hash
    $equal+hash-recur/hash-always
    $struct-equal+hash-apply
    $struct-equal+hash-hash
    $equal-always?/struct
    $equal-always?
    $equal-always?/slow
    $equal-always?/pair
    $equal-always?/box
    $equal-always?/vector
    $equal-always?/string
    $equal-always?/bytes))

;; equality-core-runtime-helper-names : (listof symbol?)
;;   Name equality helpers available in the standalone core runtime.
(define equality-core-runtime-helper-names
  '($eq?
    $eqv?
    $equal-always?/bytes))

;; equality-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only emission order for equality helpers.
(define equality-runtime-only-helper-names
  (remove* equality-core-runtime-helper-names
           equality-all-runtime-helper-names))

;; equality-runtime-only-forms : (listof datum?)
;;   Enumerate equality helpers used by the monolithic runtime.
(define equality-runtime-only-forms
  '(
         ;;;
         ;;;  4.1 Equality
         ;;;

         ;; https://docs.racket-lang.org/reference/Equality.html

         (func $eq? (type $Prim2) (param $v1 (ref eq)) (param $v2 (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.eq (local.get $v1) (local.get $v2))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $eqv? (type $Prim2)
               ; Except for numbers and characters, `eqv?` works like `eq?`.
               (param $v1 (ref eq))
               (param $v2 (ref eq))
               (result    (ref eq))

               (local $i1 i32)
	               (local $i2 i32)
	               (local $f1 (ref $Flonum))
	               (local $f2 (ref $Flonum))
	               (local $fbits1 i64)
	               (local $fbits2 i64)
	               (local $b1 (ref $Bignum))
	               (local $b2 (ref $Bignum))
	               (local $r1 (ref $Rational))
	               (local $r2 (ref $Rational))
	               (local $c1 (ref $Complex))
	               (local $c2 (ref $Complex))
	               ;; --- Fast path: ref.eq ---
               (if (ref.eq (local.get $v1) (local.get $v2))
                   (then (return (global.get $true))))
               ;; --- Case: both bignums ---
               (if (i32.and (ref.test (ref $Bignum) (local.get $v1))
                            (ref.test (ref $Bignum) (local.get $v2)))
                   (then
                    (local.set $b1 (ref.cast (ref $Bignum) (local.get $v1)))
                    (local.set $b2 (ref.cast (ref $Bignum) (local.get $v2)))
                    (return (call $bignum-eqv? (local.get $b1) (local.get $b2)))))
               ;; --- Case: both rationals ---
               (if (i32.and (ref.test (ref $Rational) (local.get $v1))
                            (ref.test (ref $Rational) (local.get $v2)))
                   (then
                    (local.set $r1 (ref.cast (ref $Rational) (local.get $v1)))
                    (local.set $r2 (ref.cast (ref $Rational) (local.get $v2)))
                    (return (call $rational-eqv? (local.get $r1) (local.get $r2)))))
               ;; --- Case: both flonums ---
               (if (i32.and (ref.test (ref $Flonum) (local.get $v1))
                            (ref.test (ref $Flonum) (local.get $v2)))
                   (then
                    (local.set $f1 (ref.cast (ref $Flonum) (local.get $v1)))
                    (local.set $f2 (ref.cast (ref $Flonum) (local.get $v2)))
                    ;; Racket's eqv? distinguishes 0.0 from -0.0, so compare
                    ;; flonums by their IEEE payload instead of f64.eq.
                    (local.set $fbits1
                               (i64.reinterpret_f64
                                (struct.get $Flonum $v (local.get $f1))))
                    (local.set $fbits2
                               (i64.reinterpret_f64
                                (struct.get $Flonum $v (local.get $f2))))
                    (if (i64.eq (local.get $fbits1) (local.get $fbits2))
	                        (then (return (global.get $true)))
	                        (else (return (global.get $false))))))
	               ;; --- Case: both complex numbers ---
	               (if (i32.and (ref.test (ref $Complex) (local.get $v1))
	                            (ref.test (ref $Complex) (local.get $v2)))
	                   (then
	                    (local.set $c1 (ref.cast (ref $Complex) (local.get $v1)))
	                    (local.set $c2 (ref.cast (ref $Complex) (local.get $v2)))
	                    (if (ref.eq (call $eqv? (struct.get $Complex $real (local.get $c1))
	                                                (struct.get $Complex $real (local.get $c2)))
	                                (global.get $true))
	                        (then (return (call $eqv? (struct.get $Complex $imag (local.get $c1))
	                                                 (struct.get $Complex $imag (local.get $c2)))))
	                        (else (return (global.get $false))))))
	               ;; --- Characters ---
               ; With our implementation, we `eqv` is the same as `eq` on characters.
               ;; --- Fallback: ref.eq ---
               (if (ref.eq (local.get $v1) (local.get $v2))
                   (then (return (global.get $true)))
                   (else (return (global.get $false))))
               (unreachable))

         ;;; equal?

         ;; Top-level equal?
         (func $equal? (type $Prim2)
               (param $v1 (ref eq))
               (param $v2 (ref eq))
               (result    (ref eq))

               ;; Fast path: ref.eq
               (if (ref.eq (local.get $v1) (local.get $v2))
                   (then (return (global.get $true))))
               ;; Fallback to eqv?
               (if (ref.eq (call $eqv? (local.get $v1) (local.get $v2)) (global.get $true))
                   (then (return (global.get $true))))
               ;; Slower recursive structural equality
               (return (call $equal?/slow (local.get $v1) (local.get $v2))))

         ;; Slow structural equality (recursive)
         (func $equal?/slow
               (param $v1 (ref eq))
               (param $v2 (ref eq))
               (result    (ref eq))

               ;; --- Pair ---
               (if (i32.and (ref.test (ref $Pair) (local.get $v1))
                            (ref.test (ref $Pair) (local.get $v2)))
                   (then (return_call $equal?/pair
                                      (ref.cast (ref $Pair) (local.get $v1))
                                      (ref.cast (ref $Pair) (local.get $v2)))))
               ;; --- Box ---
               (if (i32.and (ref.test (ref $Box) (local.get $v1))
                            (ref.test (ref $Box) (local.get $v2)))
                   (then (return_call $equal?/box
                                      (ref.cast (ref $Box) (local.get $v1))
                                      (ref.cast (ref $Box) (local.get $v2)))))
               ;; --- Vector ---
               (if (i32.and (ref.test (ref $Vector) (local.get $v1))
                            (ref.test (ref $Vector) (local.get $v2)))
                   (then (return_call $equal?/vector
                                      (ref.cast (ref $Vector) (local.get $v1))
                                      (ref.cast (ref $Vector) (local.get $v2)))))
               ;; --- String ---
               (if (i32.and (ref.test (ref $String) (local.get $v1))
                            (ref.test (ref $String) (local.get $v2)))
                   (then (return_call $string=?/2
                                      (ref.cast (ref $String) (local.get $v1))
                                      (ref.cast (ref $String) (local.get $v2)))))
               ;; --- Bytes ---
               (if (i32.and (ref.test (ref $Bytes) (local.get $v1))
                            (ref.test (ref $Bytes) (local.get $v2)))
                   (then (return_call $bytes=?/2/checked
                                      (ref.cast (ref $Bytes) (local.get $v1))
                                      (ref.cast (ref $Bytes) (local.get $v2)))))
               ;; --- Regexp ---
               (if (i32.and (ref.test (ref $Regexp) (local.get $v1))
                            (ref.test (ref $Regexp) (local.get $v2)))
                   (then (return_call $regexp-equal?
                                      (ref.cast (ref $Regexp) (local.get $v1))
                                      (ref.cast (ref $Regexp) (local.get $v2)))))
               ;; --- Struct --- (fieldwise comparison)
               (if (i32.and (ref.test (ref $Struct) (local.get $v1))
                            (ref.test (ref $Struct) (local.get $v2)))
                   (then (return_call $equal?/struct
                                      (ref.cast (ref $Struct) (local.get $v1))
                                      (ref.cast (ref $Struct) (local.get $v2)))))
               ;; --- Hash ---
               (if (i32.and (ref.test (ref $Hash) (local.get $v1))
                            (ref.test (ref $Hash) (local.get $v2)))
                   (then (return_call $equal?/hash
                                      (local.get $v1)
                                      (local.get $v2))))
               ;; --- Fallback ---
               (return (global.get $false)))

         ;; regexp-equal? : regexp? regexp? -> boolean?
         ;;   Compare regexp values by kind and source name.
         (func $regexp-equal?
               (param $rx1 (ref $Regexp))
               (param $rx2 (ref $Regexp))
               (result    (ref eq))
               (if (i32.ne (struct.get $Regexp $kind (local.get $rx1))
                           (struct.get $Regexp $kind (local.get $rx2)))
                   (then (return (global.get $false))))
               (return_call $equal?
                            (struct.get $Regexp $source (local.get $rx1))
                            (struct.get $Regexp $source (local.get $rx2))))


         ;; Compare pairs
         (func $equal?/pair
               (param $p1 (ref $Pair))
               (param $p2 (ref $Pair))
               (result    (ref eq))

               (if (ref.eq (call $equal? (struct.get $Pair $a (local.get $p1))
                                         (struct.get $Pair $a (local.get $p2)))
                           (global.get $true))
                   (then (return_call $equal? (struct.get $Pair $d (local.get $p1))
                                              (struct.get $Pair $d (local.get $p2))))
                   (else (return (global.get $false))))
               (unreachable))


         ;; Compare boxes
         (func $equal?/box
               (param $b1 (ref $Box))
               (param $b2 (ref $Box))
               (result    (ref eq))
               (return_call $equal?
                            (struct.get $Box $v (local.get $b1))
                            (struct.get $Box $v (local.get $b2))))


         ;; Compare vectors
         (func $equal?/vector
               (param $v1 (ref $Vector))
               (param $v2 (ref $Vector))
               (result    (ref eq))

               (local $a1  (ref $Array))
               (local $a2  (ref $Array))
               (local $len i32)
               (local $i   i32)
               (local $x1  (ref eq))
               (local $x2  (ref eq))

               (local.set $a1  (struct.get $Vector $arr (local.get $v1)))
               (local.set $a2  (struct.get $Vector $arr (local.get $v2)))
               (local.set $len (array.len (local.get $a1)))
               (if (i32.ne (local.get $len) (array.len (local.get $a2)))
                   (then (return (global.get $false))))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $x1 (array.get $Array (local.get $a1) (local.get $i)))
                            (local.set $x2 (array.get $Array (local.get $a2) (local.get $i)))
                            (if (ref.eq (call $equal? (local.get $x1) (local.get $x2)) (global.get $false))
                                (then (return (global.get $false))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (return (global.get $true)))

         ;; equal?/hash : hash? hash? -> boolean?
         ;;   Compare hash tables by mutability, key mode, count, and entries.
         (func $equal?/hash
               (param $ht1 (ref eq))
               (param $ht2 (ref eq))
               (result     (ref eq))

               (local $kind i32)
               (local $pos  (ref eq))
               (local $key  (ref eq))
               (local $val1 (ref eq))
               (local $val2 (ref eq))
               (local $miss (ref eq))

               (if (i32.ne (call $hash-mutable?/i32 (local.get $ht1))
                           (call $hash-mutable?/i32 (local.get $ht2)))
                   (then (return (global.get $false))))
               (local.set $kind (call $hash-kind/i32 (local.get $ht1)))
               (if (i32.ne (local.get $kind)
                           (call $hash-kind/i32 (local.get $ht2)))
                   (then (return (global.get $false))))
               (if (i32.ne (call $fixnum->i32 (call $hash-count (local.get $ht1)))
                           (call $fixnum->i32 (call $hash-count (local.get $ht2))))
                   (then (return (global.get $false))))
               (local.set $miss (call $cons (global.get $false) (global.get $false)))
               (local.set $pos (call $mutable-hash-iterate-first (local.get $ht1)))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                            (local.set $key
                                       (call $mutable-hash-iterate-key
                                             (local.get $ht1)
                                             (local.get $pos)
                                             (global.get $missing)))
                            (local.set $val1
                                       (call $mutable-hash-iterate-value
                                             (local.get $ht1)
                                             (local.get $pos)
                                             (global.get $missing)))
                            (local.set $val2
                                       (call $hash-ref
                                             (local.get $ht2)
                                             (local.get $key)
                                             (local.get $miss)))
                            (if (ref.eq (local.get $val2) (local.get $miss))
                                (then (return (global.get $false))))
                            (if (ref.eq (call $equal?
                                              (local.get $val1)
                                              (local.get $val2))
                                        (global.get $false))
                                (then (return (global.get $false))))
                            (local.set $pos
                                       (call $mutable-hash-iterate-next
                                             (local.get $ht1)
                                             (local.get $pos)))
                            (br $loop)))
               (global.get $true))


         ;; Compare structs fieldwise
         (func $equal?/struct
               (param $s1 (ref $Struct))
               (param $s2 (ref $Struct))
               (result    (ref eq))

               (local $t1        (ref $StructType))
               (local $t2        (ref $StructType))
               (local $a1        (ref $Array))
               (local $a2        (ref $Array))
               (local $len       i32)
               (local $i         i32)
               (local $x1        (ref eq))
               (local $x2        (ref eq))
               (local $prop-name (ref $Symbol))
               (local $sentinel  (ref eq))
               (local $prop-val  (ref eq))
               (local $prop-info (ref $Array))

               (local.set $t1 (struct.get $Struct $type (local.get $s1)))
               (local.set $t2 (struct.get $Struct $type (local.get $s2)))

               (local.set $prop-name (ref.cast (ref $Symbol)
                                                (global.get $symbol:prop:equal+hash)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))

               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (local.get $t1)
                                (local.get $prop-name)
                                (local.get $sentinel)))
               (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel)))
                   (then
                    (local.set $prop-info (ref.cast (ref $Array) (local.get $prop-val)))
                    (return (call $struct-equal+hash-apply
                                   (local.get $prop-info)
                                   (ref.cast (ref eq) (local.get $s1))
                                   (ref.cast (ref eq) (local.get $s2))
                                   (i32.const 1)))))

               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (local.get $t2)
                                (local.get $prop-name)
                                (local.get $sentinel)))
               (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel)))
                   (then
                    (local.set $prop-info (ref.cast (ref $Array) (local.get $prop-val)))
                    (return (call $struct-equal+hash-apply
                                   (local.get $prop-info)
                                   (ref.cast (ref eq) (local.get $s2))
                                   (ref.cast (ref eq) (local.get $s1))
                                   (i32.const 1)))))

               (if (ref.eq (local.get $t1) (local.get $t2))
                   (then
                    (local.set $a1  (struct.get $Struct $fields (local.get $s1)))
                    (local.set $a2  (struct.get $Struct $fields (local.get $s2)))
                    (local.set $len (array.len (local.get $a1)))
                    (local.set $i   (i32.const 0))
                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $x1 (array.get $Array (local.get $a1) (local.get $i)))
                                 (local.set $x2 (array.get $Array (local.get $a2) (local.get $i)))
                                 (if (ref.eq (call $equal? (local.get $x1) (local.get $x2))
                                             (global.get $false))
                                     (then (return (global.get $false))))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                    (return (global.get $true))))
               (global.get $false))

         (func $equal+hash-recur/equal (type $ClosureCode)
               (param $clos (ref $Closure))
               (param $args (ref $Args))
               (result (ref eq))

               (local $argc i32)
               (local $a    (ref eq))
               (local $b    (ref eq))

               (local.set $argc (array.len (local.get $args)))
               (if (i32.ne (local.get $argc) (i32.const 2))
                   (then (call $raise-arity-mismatch/proc (local.get $clos) (local.get $argc))
                         (unreachable)))

               (local.set $a (array.get $Args (local.get $args) (i32.const 0)))
               (local.set $b (array.get $Args (local.get $args) (i32.const 1)))
               (call $equal? (local.get $a) (local.get $b)))

         (func $equal+hash-recur/equal-always (type $ClosureCode)
               (param $clos (ref $Closure))
               (param $args (ref $Args))
               (result (ref eq))

               (local $argc i32)
               (local $a    (ref eq))
               (local $b    (ref eq))

               (local.set $argc (array.len (local.get $args)))
               (if (i32.ne (local.get $argc) (i32.const 2))
                   (then (call $raise-arity-mismatch/proc (local.get $clos) (local.get $argc))
                         (unreachable)))

               (local.set $a (array.get $Args (local.get $args) (i32.const 0)))
               (local.set $b (array.get $Args (local.get $args) (i32.const 1)))
               (call $equal-always? (local.get $a) (local.get $b)))

         (func $equal+hash-recur/hash (type $ClosureCode)
               (param $clos (ref $Closure))
               (param $args (ref $Args))
               (result (ref eq))

               (local $argc i32)
               (local $v    (ref eq))

               (local.set $argc (array.len (local.get $args)))
               (if (i32.ne (local.get $argc) (i32.const 1))
                   (then (call $raise-arity-mismatch/proc (local.get $clos) (local.get $argc))
                         (unreachable)))

               (local.set $v (array.get $Args (local.get $args) (i32.const 0)))
               (call $equal-hash-code (local.get $v)))

         (func $equal+hash-recur/hash-always (type $ClosureCode)
               (param $clos (ref $Closure))
               (param $args (ref $Args))
               (result (ref eq))

               (local $argc i32)
               (local $v    (ref eq))

               (local.set $argc (array.len (local.get $args)))
               (if (i32.ne (local.get $argc) (i32.const 1))
                   (then (call $raise-arity-mismatch/proc (local.get $clos) (local.get $argc))
                         (unreachable)))

               (local.set $v (array.get $Args (local.get $args) (i32.const 0)))
               (call $equal-always-hash-code (local.get $v)))

         (func $struct-equal+hash-apply
               (param $info  (ref $Array))
               (param $self  (ref eq))
               (param $other (ref eq))
               (param $mode  i32)
               (result (ref eq))

               (local $tag       (ref i31))
               (local $variant   i32)
               (local $proc      (ref $Procedure))
               (local $inv       (ref $ProcedureInvoker))
               (local $args      (ref $Args))
               (local $recur     (ref eq))
               (local $mode-val  (ref eq))

               ;; Initialize non-defaultable locals
               (local.set $recur    (global.get $equal+hash-recur/equal))
               (local.set $mode-val (global.get $false))

               (local.set $tag (ref.cast (ref i31)
                                         (array.get $Array (local.get $info) (i32.const 0))))
               (local.set $variant (i32.shr_u (i31.get_u (local.get $tag)) (i32.const 1)))

               (if (i32.eq (local.get $mode) (i32.const 0))
                   (then (local.set $recur    (global.get $equal+hash-recur/equal-always))
                         (local.set $mode-val (global.get $false)))
                   (else (local.set $recur    (global.get $equal+hash-recur/equal))
                         (local.set $mode-val (global.get $true))))

               (if (i32.eq (local.get $variant) (i32.const 3))
                   (then
                    (local.set $proc
                               (ref.cast (ref $Procedure)
                                         (array.get $Array (local.get $info) (i32.const 1))))
                    (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                    (local.set $args (array.new $Args (global.get $null) (i32.const 3)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $self))
                    (array.set $Args (local.get $args) (i32.const 1) (local.get $other))
                    (array.set $Args (local.get $args) (i32.const 2) (local.get $recur))
                    (return_call_ref $ProcedureInvoker
                                     (local.get $proc)
                                     (local.get $args)
                                     (local.get $inv))))

               (local.set $proc
                          (ref.cast (ref $Procedure)
                                    (array.get $Array (local.get $info) (i32.const 1))))
               (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
               (local.set $args (array.new $Args (global.get $null) (i32.const 4)))
               (array.set $Args (local.get $args) (i32.const 0) (local.get $self))
               (array.set $Args (local.get $args) (i32.const 1) (local.get $other))
               (array.set $Args (local.get $args) (i32.const 2) (local.get $recur))
               (array.set $Args (local.get $args) (i32.const 3) (local.get $mode-val))
               (return_call_ref $ProcedureInvoker
                                (local.get $proc)
                                (local.get $args)
                                (local.get $inv)))

         (func $struct-equal+hash-hash
               (param $info (ref $Array))
               (param $self (ref $Struct))
               (param $mode i32)
               (result i32)

               (local $tag      (ref i31))
               (local $variant  i32)
               (local $proc     (ref $Procedure))
               (local $inv      (ref $ProcedureInvoker))
               (local $args     (ref $Args))
               (local $mode-val (ref eq))
               (local $recur    (ref eq))
               (local $result   (ref eq))
               (local $hash     (ref i31))
               (local $value    i32)

               ;; Initialize non-defaultable locals
               (local.set $mode-val (global.get $false))
               (local.set $recur    (global.get $equal+hash-recur/hash-always))
               (local.set $result   (global.get $false))

               ;; Decode arguments
               (local.set $tag     (ref.cast (ref i31)
                                             (array.get $Array (local.get $info) (i32.const 0))))
               (local.set $variant (i32.shr_u (i31.get_u (local.get $tag)) (i32.const 1)))

               (if (i32.eq (local.get $mode) (i32.const 0))
                   (then (local.set $mode-val (global.get $false)))
                   (else (local.set $mode-val (global.get $true))
                         (local.set $recur (global.get $equal+hash-recur/hash))))

               (if (i32.eq (local.get $variant) (i32.const 3))
                   (then
                    (local.set $proc
                               (ref.cast (ref $Procedure)
                                         (array.get $Array (local.get $info) (i32.const 2))))
                    (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                    (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
                    (array.set $Args (local.get $args) (i32.const 0)
                               (ref.cast (ref eq) (local.get $self)))
                    (array.set $Args (local.get $args) (i32.const 1)
                               (local.get $recur))
                    (local.set $result
                               (call_ref $ProcedureInvoker
                                         (local.get $proc)
                                         (local.get $args)
                                         (local.get $inv))))
                   (else
                    (local.set $proc
                               (ref.cast (ref $Procedure)
                                         (array.get $Array (local.get $info) (i32.const 2))))
                    (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                    (local.set $args (array.new $Args (global.get $null) (i32.const 3)))
                    (array.set $Args (local.get $args) (i32.const 0)
                               (ref.cast (ref eq) (local.get $self)))
                    (array.set $Args (local.get $args) (i32.const 1)
                               (local.get $recur))
                    (array.set $Args (local.get $args) (i32.const 2) (local.get $mode-val))
                    (local.set $result
                               (call_ref $ProcedureInvoker
                                         (local.get $proc)
                                         (local.get $args)
                                         (local.get $inv)))))

               (local.set $hash (ref.cast (ref i31) (local.get $result)))
               (local.set $value (i32.shr_s (i31.get_s (local.get $hash)) (i32.const 1)))
               (local.get $value))

         (func $equal-always?/struct
               (param $s1 (ref $Struct))
               (param $s2 (ref $Struct))
               (result    (ref eq))

               (local $t1        (ref $StructType))
               (local $t2        (ref $StructType))
               (local $prop-name (ref $Symbol))
               (local $sentinel  (ref eq))
               (local $prop-val  (ref eq))
               (local $prop-info (ref $Array))

               (local.set $t1 (struct.get $Struct $type (local.get $s1)))
               (local.set $t2 (struct.get $Struct $type (local.get $s2)))

               (local.set $prop-name (ref.cast (ref $Symbol)
                                                (global.get $symbol:prop:equal+hash)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))

               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (local.get $t1)
                                (local.get $prop-name)
                                (local.get $sentinel)))
               (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel)))
                   (then
                    (local.set $prop-info (ref.cast (ref $Array) (local.get $prop-val)))
                    (return (call $struct-equal+hash-apply
                                   (local.get $prop-info)
                                   (ref.cast (ref eq) (local.get $s1))
                                   (ref.cast (ref eq) (local.get $s2))
                                   (i32.const 0)))))

               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (local.get $t2)
                                (local.get $prop-name)
                                (local.get $sentinel)))
               (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel)))
                   (then
                    (local.set $prop-info (ref.cast (ref $Array) (local.get $prop-val)))
                    (return (call $struct-equal+hash-apply
                                   (local.get $prop-info)
                                   (ref.cast (ref eq) (local.get $s2))
                                   (ref.cast (ref eq) (local.get $s1))
                                   (i32.const 0)))))

               (global.get $false))

         ;; equal-always?
         (func $equal-always? (type $Prim2)
               (param $v1 (ref eq))
               (param $v2 (ref eq))
               (result    (ref eq))

               ;; Fast path: identical references
               (if (ref.eq (local.get $v1) (local.get $v2))
                   (then (return (global.get $true))))
               ;; Numbers, characters, etc.
               (if (ref.eq (call $eqv? (local.get $v1) (local.get $v2)) (global.get $true))
                   (then (return (global.get $true))))
               ;; Structural comparison that enforces immutability contracts
               (return (call $equal-always?/slow (local.get $v1) (local.get $v2))))

         (func $equal-always?/slow
               (param $v1 (ref eq))
               (param $v2 (ref eq))
               (result    (ref eq))

               ;; Mutable pairs must be eq?
               (if (i32.or (ref.test (ref $MPair) (local.get $v1))
                           (ref.test (ref $MPair) (local.get $v2)))
                   (then (return (global.get $false))))
               ;; --- Pair ---
               (if (i32.and (ref.test (ref $Pair) (local.get $v1))
                            (ref.test (ref $Pair) (local.get $v2)))
                   (then (return_call $equal-always?/pair
                                      (ref.cast (ref $Pair) (local.get $v1))
                                      (ref.cast (ref $Pair) (local.get $v2)))))
               ;; --- Box ---
               (if (i32.and (ref.test (ref $Box) (local.get $v1))
                            (ref.test (ref $Box) (local.get $v2)))
                   (then (return_call $equal-always?/box
                                      (ref.cast (ref $Box) (local.get $v1))
                                      (ref.cast (ref $Box) (local.get $v2)))))
               ;; --- Vector ---
               (if (i32.and (ref.test (ref $Vector) (local.get $v1))
                            (ref.test (ref $Vector) (local.get $v2)))
                   (then (return_call $equal-always?/vector
                                      (ref.cast (ref $Vector) (local.get $v1))
                                      (ref.cast (ref $Vector) (local.get $v2)))))
               ;; --- Struct ---
               (if (i32.and (ref.test (ref $Struct) (local.get $v1))
                            (ref.test (ref $Struct) (local.get $v2)))
                   (then (return_call $equal-always?/struct
                                      (ref.cast (ref $Struct) (local.get $v1))
                                      (ref.cast (ref $Struct) (local.get $v2)))))
               ;; --- String ---
               (if (i32.and (ref.test (ref $String) (local.get $v1))
                            (ref.test (ref $String) (local.get $v2)))
                   (then (return_call $equal-always?/string
                                      (ref.cast (ref $String) (local.get $v1))
                                      (ref.cast (ref $String) (local.get $v2)))))
               ;; --- Bytes ---
               (if (i32.and (ref.test (ref $Bytes) (local.get $v1))
                            (ref.test (ref $Bytes) (local.get $v2)))
                   (then (return_call $equal-always?/bytes
                                      (ref.cast (ref $Bytes) (local.get $v1))
                                      (ref.cast (ref $Bytes) (local.get $v2)))))
               ;; Fallback: not equal-always
               (return (global.get $false)))

         ;; Compare pairs with equal-always?
         (func $equal-always?/pair
               (param $p1 (ref $Pair))
               (param $p2 (ref $Pair))
               (result    (ref eq))

               (if (ref.eq (call $equal-always? (struct.get $Pair $a (local.get $p1))
                                 (struct.get $Pair $a (local.get $p2)))
                           (global.get $true))
                   (then (return_call $equal-always? (struct.get $Pair $d (local.get $p1))
                                      (struct.get $Pair $d (local.get $p2))))
                   (else (return (global.get $false))))
               (unreachable))

         ;; Compare boxes (immutable only)
         (func $equal-always?/box
               (param $b1 (ref $Box))
               (param $b2 (ref $Box))
               (result    (ref eq))

               (if (i32.eq (struct.get $Box $immutable (local.get $b1)) (i32.const 1))
                   (then
                    (if (i32.eq (struct.get $Box $immutable (local.get $b2)) (i32.const 1))
                        (then (return_call $equal-always?
                                           (struct.get $Box $v (local.get $b1))
                                           (struct.get $Box $v (local.get $b2)))))))
               (return (global.get $false)))

         ;; Compare vectors (immutable only)
         (func $equal-always?/vector
               (param $v1 (ref $Vector))
               (param $v2 (ref $Vector))
               (result    (ref eq))

               (local $a1  (ref $Array))
               (local $a2  (ref $Array))
               (local $len i32)
               (local $i   i32)
               (local $x1  (ref eq))
               (local $x2  (ref eq))

               (if (i32.ne (struct.get $Vector $immutable (local.get $v1)) (i32.const 1))
                   (then (return (global.get $false))))
               (if (i32.ne (struct.get $Vector $immutable (local.get $v2)) (i32.const 1))
                   (then (return (global.get $false))))
               (local.set $a1  (struct.get $Vector $arr (local.get $v1)))
               (local.set $a2  (struct.get $Vector $arr (local.get $v2)))
               (local.set $len (array.len (local.get $a1)))
               (if (i32.ne (local.get $len) (array.len (local.get $a2)))
                   (then (return (global.get $false))))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $x1 (array.get $Array (local.get $a1) (local.get $i)))
                            (local.set $x2 (array.get $Array (local.get $a2) (local.get $i)))
                            (if (ref.eq (call $equal-always? (local.get $x1) (local.get $x2)) (global.get $false))
                                (then (return (global.get $false))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (return (global.get $true)))

         ;; Compare strings (immutable only)
         (func $equal-always?/string
               (param $s1 (ref $String))
               (param $s2 (ref $String))
               (result    (ref eq))

               (if (i32.eq (struct.get $String $immutable (local.get $s1)) (i32.const 1))
                   (then
                    (if (i32.eq (struct.get $String $immutable (local.get $s2)) (i32.const 1))
                        (then (return_call $string=?/2 (local.get $s1) (local.get $s2))))))
               (return (global.get $false)))

         ;; Compare byte strings (immutable only)
         (func $equal-always?/bytes
               (param $b1 (ref $Bytes))
               (param $b2 (ref $Bytes))
               (result    (ref eq))

               (if (i32.eq (struct.get $Bytes $immutable (local.get $b1)) (i32.const 1))
                   (then
                    (if (i32.eq (struct.get $Bytes $immutable (local.get $b2)) (i32.const 1))
                        (then (return_call $bytes=?/2/checked (local.get $b1) (local.get $b2))))))
               (return (global.get $false)))


    ))

;; immutable-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic immutability predicates.
(define immutable-predicate-runtime-only-helper-names
  '())

;; immutable-predicate-core-runtime-helper-names : (listof symbol?)
;;   Name generic immutability predicates available in the standalone core runtime.
(define immutable-predicate-core-runtime-helper-names
  '($immutable?))

;; equality-promoted-runtime-helper-names : (listof symbol?)
;;   Name helpers from this module available in the standalone core runtime.
(define equality-promoted-runtime-helper-names
  (append equality-core-runtime-helper-names
          immutable-predicate-core-runtime-helper-names))

;; equality-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given equality helper names from a helper index.
(define (equality-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; equality-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted equality helpers in runtime assembly order.
(define (equality-core-runtime-helper-forms helper-index)
  (equality-helper-forms helper-index equality-core-runtime-helper-names))

;; equality-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render runtime-only equality helpers in runtime assembly order.
(define (equality-runtime-helper-forms helper-index)
  (equality-helper-forms helper-index equality-runtime-only-helper-names))

;; immutable-predicate-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render generic immutability predicates in runtime assembly order.
(define (immutable-predicate-runtime-helper-forms helper-index)
  (equality-helper-forms helper-index immutable-predicate-runtime-only-helper-names))

;; immutable-predicate-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted generic immutability predicates in runtime assembly order.
(define (immutable-predicate-core-runtime-helper-forms helper-index)
  (equality-helper-forms helper-index immutable-predicate-core-runtime-helper-names))

;; immutable-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic immutability predicates used by the monolithic runtime.
(define immutable-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'immutable-predicate-runtime-only-helpers
   '(
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
     )))

(define equality-all-runtime-helpers
  (append (function-forms->runtime-helpers
           'equality-all-runtime-helpers
           equality-runtime-only-forms)
          immutable-predicate-runtime-only-helpers))

;; equality-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate equality helpers available in the standalone core runtime.
(define equality-core-runtime-helpers
  (select-runtime-helpers equality-all-runtime-helpers
                          equality-promoted-runtime-helper-names))

;; equality-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate equality helpers that still depend on monolithic runtime globals.
(define equality-runtime-only-helpers
  (remove-runtime-helpers equality-all-runtime-helpers
                          equality-promoted-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define equality-helper-index
    (make-core-runtime-helper-index
     (append equality-core-runtime-helpers
             equality-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name equality-core-runtime-helpers)
   equality-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (equality-core-runtime-helper-forms equality-helper-index))
   equality-core-runtime-helper-names)

  (check-equal?
   (map form-name (immutable-predicate-core-runtime-helper-forms equality-helper-index))
   immutable-predicate-core-runtime-helper-names)

  (check-equal?
   (map form-name (equality-runtime-helper-forms equality-helper-index))
   equality-runtime-only-helper-names)

  (check-equal?
   (map form-name (immutable-predicate-runtime-helper-forms equality-helper-index))
   immutable-predicate-runtime-only-helper-names))
