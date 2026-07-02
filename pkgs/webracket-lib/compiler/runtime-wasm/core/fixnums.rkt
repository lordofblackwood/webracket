#lang racket

(provide fixnum-core-runtime-helpers
         fixnum-comparison-runtime-only-helper-names
         fixnum-conversion-runtime-only-helper-names
         fixnum-minmax-runtime-only-helper-names
         fixnum-predicate-runtime-only-helper-names
         fixnum-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/immediates.rkt"
         "../../private/wasm-utils.rkt")

;; local-fixnum-bits-s : symbol? -> datum?
;;   Return WAT that reads the signed tagged fixnum bits from local-name.
(define (local-fixnum-bits-s local-name)
  `(i31.get_s (ref.cast i31ref (local.get ,local-name))))

;; local-fixnum-bits-u : symbol? -> datum?
;;   Return WAT that reads the unsigned tagged fixnum bits from local-name.
(define (local-fixnum-bits-u local-name)
  `(i31.get_u (ref.cast i31ref (local.get ,local-name))))

;; local-fixnum-payload-s : symbol? -> datum?
;;   Return WAT that decodes local-name to a signed i32 fixnum payload.
(define (local-fixnum-payload-s local-name)
  `(i32.shr_s ,(local-fixnum-bits-s local-name) (i32.const 1)))

;; local-fixnum-payload-u : symbol? -> datum?
;;   Return WAT that decodes local-name to an unsigned i32 fixnum payload.
(define (local-fixnum-payload-u local-name)
  `(i32.shr_s ,(local-fixnum-bits-u local-name) (i32.const 1)))

;; tag-fixnum-bits : datum? -> datum?
;;   Return WAT that encodes an i32 fixnum payload as tagged bits.
(define (tag-fixnum-bits bits)
  `(i32.shl ,bits (i32.const 1)))

;; fixnum-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for fixnum predicate helpers.
(define fixnum-predicate-runtime-only-helper-names
  '($raise-not-fixnum
    $fixnum?
    $fxvector?
    $fxzero?))

;; fixnum-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for fixnum conversion helpers.
(define fixnum-conversion-runtime-only-helper-names
  '($fixnum->i32
    $fixnum-for-every-system?))

;; fixnum-bitwise-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for variadic fixnum bitwise helpers.
(define fixnum-bitwise-runtime-only-helper-names
  '($fxand
    $fxior
    $fxxor))

;; fixnum-wraparound-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for fixnum wraparound helpers.
(define fixnum-wraparound-runtime-only-helper-names
  '($fx-/wraparound))

;; fixnum-minmax-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for fixnum min/max helpers.
(define fixnum-minmax-runtime-only-helper-names
  '($fxmin/2
    $fxmax/2
    $fxmin
    $fxmax))

;; fixnum-comparison-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for fixnum comparison helpers.
(define fixnum-comparison-runtime-only-helper-names
  '($most-positive-fixnum
    $most-negative-fixnum
    $fx=/2
    $fx</2
    $fx>/2
    $fx<=/2
    $fx>=/2
    $fx=
    $fx<
    $fx>
    $fx<=
    $fx>=))

;; fixnum-bound-runtime-helper : symbol? exact-integer? -> core-runtime-helper?
;;   Build a zero-argument helper that returns a tagged fixnum bound.
(define (fixnum-bound-runtime-helper name value)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type $Prim0) (result (ref eq))
            ,(Imm value)))))

;; fixnum-equal2-runtime-helper : -> core-runtime-helper?
;;   Build the binary fixnum equality helper.
(define (fixnum-equal2-runtime-helper)
  (core-runtime-helper
   '$fx=/2
   "$fx=/2"
   (lambda ()
     '(func $fx=/2 (type $Prim2) (param $v1 (ref eq)) (param $v2 (ref eq)) (result (ref eq))
            (if (result (ref eq))
                (ref.eq (call $fixnum? (local.get $v1))
                        (global.get $true))
                (then (return_call $eq? (local.get $v1) (local.get $v2)))
                (else (global.get $false)))))))

;; fixnum-compare2-runtime-helper : symbol? symbol? -> core-runtime-helper?
;;   Build a binary checked fixnum comparison helper.
(define (fixnum-compare2-runtime-helper name inst)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name
            (param $x (ref eq))
            (param $y (ref eq))
            (result   (ref eq))
            ; type check
            (if (i32.eqz (ref.test (ref i31) (local.get $x)))
                (then (call $raise-check-fixnum (local.get $x)) (unreachable)))
            (if (i32.eqz (ref.test (ref i31) (local.get $y)))
                (then (call $raise-check-fixnum (local.get $y)) (unreachable)))
            ; compare
            (if (result (ref eq))
                (,inst (i31.get_s (ref.cast (ref i31) (local.get $x)))
                       (i31.get_s (ref.cast (ref i31) (local.get $y))))
                (then (global.get $true))
                (else (global.get $false)))))))

;; fixnum-compare-runtime-helper : symbol? symbol? -> core-runtime-helper?
;;   Build a variadic checked fixnum comparison helper.
(define (fixnum-compare-runtime-helper name binary-name)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (param $x0 (ref eq)) (param $xs (ref eq)) (result (ref eq))
            (local $node (ref $Pair))
            (local $fx   (ref eq))
            ;; Validate the first argument
            (if (i32.eqz (ref.test (ref i31) (local.get $x0)))
                (then (call $raise-check-fixnum (local.get $x0)) (unreachable)))
            (block $done
                   (loop $loop
                         (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                         (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                         (local.set $fx   (struct.get $Pair $a (local.get $node)))
                         (if (i32.eqz (ref.test (ref i31) (local.get $fx)))
                             (then (call $raise-check-fixnum (local.get $fx)) (unreachable)))
                         (if (ref.eq (call ,binary-name (local.get $x0) (local.get $fx))
                                     (global.get $false))
                             (then (return (global.get $false))))
                         (local.set $x0 (local.get $fx))
                         (local.set $xs (struct.get $Pair $d (local.get $node)))
                         (br $loop)))
            (global.get $true)))))

;; fixnum-comparison-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum comparison helpers used by the monolithic runtime.
(define fixnum-comparison-runtime-only-helpers
  (append
   (list (fixnum-bound-runtime-helper '$most-positive-fixnum most-positive-fixnum)
         (fixnum-bound-runtime-helper '$most-negative-fixnum most-negative-fixnum)
         (fixnum-equal2-runtime-helper))
   (for/list ([name '( $fx</2   $fx>/2   $fx<=/2  $fx>=/2)]
              [inst '( i32.lt_s i32.gt_s i32.le_s i32.ge_s)])
     (fixnum-compare2-runtime-helper name inst))
   (for/list ([name        '( $fx=   $fx<   $fx>   $fx<=   $fx>=)]
              [binary-name '( $fx=/2 $fx</2 $fx>/2 $fx<=/2 $fx>=/2)])
     (fixnum-compare-runtime-helper name binary-name))))

;; fixnum-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum predicate helpers used by the monolithic runtime.
(define fixnum-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'fixnum-predicate-runtime-only-helpers
   `(
     (func $raise-not-fixnum (param $x (ref eq)) (unreachable))

     (func $fixnum? (type $Prim1) (param $v (ref eq)) (result (ref eq))
           (if (result (ref eq))
               (ref.test i31ref (local.get $v))
               (then (if (result (ref eq))
                         (i32.eqz (i32.and (i31.get_s (ref.cast i31ref (local.get $v)))
                                           (i32.const ,fixnum-mask)))
                         (then (global.get $true))
                         (else (global.get $false))))
               (else (global.get $false))))

     ;; fxvector? : any/c -> boolean?
     ;;   WebRacket does not have fxvector values yet, so this predicate
     ;;   is always false until a concrete fxvector representation exists.
     (func $fxvector? (type $Prim1)
           (param $v (ref eq)) ;; any/c
           (result (ref eq))
           (global.get $false))

     (func $fxzero? (type $Prim1) (param $x (ref eq)) (result (ref eq))
           (if (result (ref eq))
               (ref.test i31ref (local.get $x))
               (then (if (result (ref eq))
                         (i32.eqz (i31.get_s (ref.cast i31ref (local.get $x))))
                         (then (global.get $true))
                         (else (global.get $false))))
               (else (global.get $false)))))))

;; fixnum-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum conversion helpers used by the monolithic runtime.
(define fixnum-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'fixnum-conversion-runtime-only-helpers
   '(
     (func $fixnum->i32 (param $x (ref eq)) (result i32)
           (local $val i32)
           (if (ref.test (ref i31) (local.get $x))
               (then (local.set $val (i31.get_s (ref.cast (ref i31) (local.get $x))))
                     (if (i32.eqz (i32.and (local.get $val) (i32.const 1)))
                         (then (return (i32.shr_s (local.get $val) (i32.const 1)))) ;; return unboxed i32
                         (else (call $raise-not-fixnum (local.get $x)))))
               (else (call $raise-not-fixnum (local.get $x))))
           (unreachable))

     (func $fixnum-for-every-system? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $bits i32)
           (local $value i32)
           ;; Validate that v is a fixnum with low bit 0.
           (if (i32.eqz (ref.test (ref i31) (local.get $v)))
               (then (return (global.get $false))))
           (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $v))))
           (if (i32.and (local.get $bits) (i32.const 1))
               (then (return (global.get $false))))
           ;; Decode the fixnum payload and ensure it fits the cross-platform range.
           (local.set $value (i32.shr_s (local.get $bits) (i32.const 1)))
           (if (i32.lt_s (local.get $value) (i32.const -536870912))
               (then (return (global.get $false))))
           (if (i32.gt_s (local.get $value) (i32.const 536870911))
               (then (return (global.get $false))))
           (global.get $true)))))

;; fixnum-bitwise-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate variadic fixnum bitwise helpers used by the monolithic runtime.
(define fixnum-bitwise-runtime-only-helpers
  (function-forms->runtime-helpers
   'fixnum-bitwise-runtime-only-helpers
   `(
     (func $fxand (type $Prim>=0)
           (param $xs0 (ref eq)) (result (ref eq))
           (local $xs   (ref eq))
           (local $node (ref $Pair))
           (local $v    (ref eq))
           (local $r    (ref eq))
           (local.set $xs
                      (if (result (ref eq))
                          (ref.test (ref $Args) (local.get $xs0))
                          (then (call $rest-arguments->list
                                      (ref.cast (ref $Args) (local.get $xs0))
                                      (i32.const 0)))
                          (else (local.get $xs0))))
           (local.set $r ,(Imm -1))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $v    (struct.get $Pair $a (local.get $node)))
                        (local.set $r    (call $fxand/2 (local.get $r) (local.get $v)))
                        (local.set $xs   (struct.get $Pair $d (local.get $node)))
                        (br $loop)))
           (local.get $r))

     (func $fxior (type $Prim>=0)
           (param $xs0 (ref eq)) (result (ref eq))
           (local $xs   (ref eq))
           (local $node (ref $Pair))
           (local $v    (ref eq))
           (local $r    (ref eq))
           (local.set $xs
                      (if (result (ref eq))
                          (ref.test (ref $Args) (local.get $xs0))
                          (then (call $rest-arguments->list
                                      (ref.cast (ref $Args) (local.get $xs0))
                                      (i32.const 0)))
                          (else (local.get $xs0))))
           (local.set $r (global.get $zero))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $v    (struct.get $Pair $a (local.get $node)))
                        (local.set $r    (call $fxior/2 (local.get $r) (local.get $v)))
                        (local.set $xs   (struct.get $Pair $d (local.get $node)))
                        (br $loop)))
           (local.get $r))

     (func $fxxor (type $Prim>=0)
           (param $xs0 (ref eq)) (result (ref eq))
           (local $xs   (ref eq))
           (local $node (ref $Pair))
           (local $v    (ref eq))
           (local $r    (ref eq))
           (local.set $xs
                      (if (result (ref eq))
                          (ref.test (ref $Args) (local.get $xs0))
                          (then (call $rest-arguments->list
                                      (ref.cast (ref $Args) (local.get $xs0))
                                      (i32.const 0)))
                          (else (local.get $xs0))))
           (local.set $r (global.get $zero))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $v    (struct.get $Pair $a (local.get $node)))
                        (local.set $r    (call $fxxor/2 (local.get $r) (local.get $v)))
                        (local.set $xs   (struct.get $Pair $d (local.get $node)))
                        (br $loop)))
           (local.get $r)))))

;; fixnum-wraparound-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate variadic fixnum wraparound helpers used by the monolithic runtime.
(define fixnum-wraparound-runtime-only-helpers
  (function-forms->runtime-helpers
   'fixnum-wraparound-runtime-only-helpers
   '(
     (func $fx-/wraparound (type $Prim>=1)
           (param $a1   (ref eq))
           (param $rest (ref eq))
           (result      (ref eq))

           (local $a    (ref eq))
           (local $b    (ref eq))
           (local $node (ref $Pair))

           ;; Eager init so locals are definitely assigned before any possible get.
           (local.set $a (ref.i31 (i32.const 0)))
           (local.set $b (local.get $a1))
           ;; Determine arguments based on rest list
           (if (ref.eq (local.get $rest) (global.get $null))
               (then
                ;; (0 - a1)
                (local.set $a (ref.i31 (i32.const 0)))
                (local.set $b (local.get $a1)))
               (else
                (if (ref.test (ref $Pair) (local.get $rest))
                    (then
                     (local.set $node (ref.cast (ref $Pair) (local.get $rest)))
                     (local.set $a    (local.get $a1))
                     (local.set $b    (struct.get $Pair $a (local.get $node)))
                     ;; Ensure no extra arguments
                     (if (ref.eq (struct.get $Pair $d (local.get $node))
                                 (global.get $null))
                         (then (nop))
                         (else (call $raise-arity-error:exactly) (unreachable))))
                    (else (call $raise-arity-error:exactly) (unreachable)))))
           (ref.i31
            (i32.sub
             (i31.get_s (ref.cast (ref i31) (local.get $a)))
             (i31.get_s (ref.cast (ref i31) (local.get $b)))))))))

;; fixnum-minmax2-runtime-helper : symbol? symbol? -> core-runtime-helper?
;;   Build a binary fixnum min/max helper with checked arguments.
(define (fixnum-minmax2-runtime-helper name inst)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type $Prim2)
            (param $x (ref eq))
            (param $y (ref eq))
            (result (ref eq))
            (if (i32.eqz (ref.test (ref i31) (local.get $x)))
                (then (call $raise-check-fixnum (local.get $x)) (unreachable)))
            (if (i32.eqz (ref.test (ref i31) (local.get $y)))
                (then (call $raise-check-fixnum (local.get $y)) (unreachable)))
            (if (result (ref eq))
                (,inst (i31.get_s (ref.cast (ref i31) (local.get $x)))
                       (i31.get_s (ref.cast (ref i31) (local.get $y))))
                (then (local.get $x))
                (else (local.get $y)))))))

;; fixnum-minmax-runtime-helper : symbol? symbol? -> core-runtime-helper?
;;   Build a variadic fixnum min/max helper with checked arguments.
(define (fixnum-minmax-runtime-helper name cmp)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (param $x0 (ref eq)) (param $xs (ref eq)) (result (ref eq))
            (local $node (ref $Pair))
            (local $fx   (ref eq))
            (local $best (ref eq))
            (if (i32.eqz (ref.test (ref i31) (local.get $x0)))
                (then (call $raise-check-fixnum (local.get $x0)) (unreachable)))
            (local.set $best (local.get $x0))
            (block $done
                   (loop $loop
                         (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                         (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                         (local.set $fx   (struct.get $Pair $a (local.get $node)))
                         (if (i32.eqz (ref.test (ref i31) (local.get $fx)))
                             (then (call $raise-check-fixnum (local.get $fx)) (unreachable)))
                         (local.set $best (call ,cmp (local.get $best) (local.get $fx)))
                         (local.set $xs (struct.get $Pair $d (local.get $node)))
                         (br $loop)))
            (local.get $best)))))

;; fixnum-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum helpers that depend on monolithic runtime errors.
(define fixnum-runtime-only-helpers
  (append
   fixnum-predicate-runtime-only-helpers
   fixnum-comparison-runtime-only-helpers
   fixnum-bitwise-runtime-only-helpers
   fixnum-wraparound-runtime-only-helpers
   (for/list ([name '( $fxmin/2 $fxmax/2 )]
              [inst '( i32.lt_s i32.gt_s )])
     (fixnum-minmax2-runtime-helper name inst))
   (for/list ([name '( $fxmin $fxmax )]
              [cmp  '( $fxmin/2 $fxmax/2 )])
     (fixnum-minmax-runtime-helper name cmp))
   fixnum-conversion-runtime-only-helpers))

;; fixnum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum helpers that can be emitted in core runtime.
(define fixnum-core-runtime-helpers
  (list
   ;; $fx?/i32 : any/c -> i32
   ;;   Return 1 when v is an i31 fixnum value, otherwise 0.
   ;;   This raw i32 predicate is used in validation paths that branch on
   ;;   fixnum-ness instead of returning a WebRacket boolean.
   (core-runtime-helper
    '$fx?/i32
    "$fx?/i32"
    (lambda ()
      `(func $fx?/i32 (param $v (ref eq)) (result i32)
             (local $v/tag i32)
             (if (ref.test (ref i31) (local.get $v))
                 (then (local.set $v/tag (i31.get_u (ref.cast (ref i31) (local.get $v))))
                       (return (i32.eqz (i32.and (local.get $v/tag)
                                                 (i32.const 1)))))
                 (else (return (i32.const 0))))
             (unreachable))))
   ;; $fixnum?/i32 : any/c -> i32
   ;;   Return 1 when v is an i31 fixnum value, otherwise 0.
   ;;   Keep this helper separate from `$fixnum?`, which returns a WebRacket
   ;;   boolean and therefore depends on runtime boolean globals.
   (core-runtime-helper
    '$fixnum?/i32
    "$fixnum?/i32"
    (lambda ()
      `(func $fixnum?/i32
             (param $v (ref eq))
             (result   i32)

             (if (result i32)
                 (ref.test (ref i31) (local.get $v))
                 (then (i32.eqz
                        (i32.and
                         (i31.get_u (ref.cast (ref i31) (local.get $v)))
                         (i32.const 1))))
                 (else (i32.const 0))))))
   ;; $fxand/2 : fixnum? fixnum? -> fixnum?
   ;;   Compute the bitwise-and of two already validated fixnums.
   (core-runtime-helper
    '$fxand/2
    "$fxand/2"
    (lambda ()
      `(func $fxand/2 (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.and (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))))
   ;; $fxior/2 : fixnum? fixnum? -> fixnum?
   ;;   Compute the bitwise-ior of two already validated fixnums.
   (core-runtime-helper
    '$fxior/2
    "$fxior/2"
    (lambda ()
      `(func $fxior/2 (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.or (i31.get_s (ref.cast i31ref (local.get $x)))
                              (i31.get_s (ref.cast i31ref (local.get $y))))))))
   ;; $fxxor/2 : fixnum? fixnum? -> fixnum?
   ;;   Compute the bitwise-xor of two already validated fixnums.
   (core-runtime-helper
    '$fxxor/2
    "$fxxor/2"
    (lambda ()
      `(func $fxxor/2 (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.xor (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))))
   ;; $fxnot : fixnum? -> fixnum?
   ;;   Compute the bitwise-not of an already validated fixnum.
   (core-runtime-helper
    '$fxnot
    "$fxnot"
    (lambda ()
      `(func $fxnot (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.xor ,(local-fixnum-payload-s '$x)
                                  (i32.const -1)))))))
   ;; $fxlshift : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum left by an already validated amount.
   (core-runtime-helper
    '$fxlshift
    "$fxlshift"
    (lambda ()
      `(func $fxlshift (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $fxrshift : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum right by an already validated amount.
   (core-runtime-helper
    '$fxrshift
    "$fxrshift"
    (lambda ()
      `(func $fxrshift (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_s ,(local-fixnum-payload-s '$x)
                                    ,(local-fixnum-payload-s '$y)))))))
   ;; $fxpopcount : fixnum? -> fixnum?
   ;;   Count one bits in an already validated fixnum.
   (core-runtime-helper
    '$fxpopcount
    "$fxpopcount"
    (lambda ()
      `(func $fxpopcount (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-payload-u '$x)))))))
   ;; $fxpopcount32 : fixnum? -> fixnum?
   ;;   Count one bits in an already validated fixnum.
   (core-runtime-helper
    '$fxpopcount32
    "$fxpopcount32"
    (lambda ()
      `(func $fxpopcount32 (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-payload-u '$x)))))))
   ;; $fxpopcount16 : fixnum? -> fixnum?
   ;;   Count one bits in the low 16 bits of an already validated fixnum.
   (core-runtime-helper
    '$fxpopcount16
    "$fxpopcount16"
    (lambda ()
      `(func $fxpopcount16 (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt
                          (i32.and ,(local-fixnum-payload-u '$x)
                                   (i32.const 65535))))))))
   ;; $fx+/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Add two already validated fixnums with wraparound.
   (core-runtime-helper
    '$fx+/wraparound
    "$fx+/wraparound"
    (lambda ()
      `(func $fx+/wraparound (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.add ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-bits-s '$y))))))
   ;; $fx*/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Multiply two already validated fixnums with wraparound.
   (core-runtime-helper
    '$fx*/wraparound
    "$fx*/wraparound"
    (lambda ()
      `(func $fx*/wraparound (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.mul ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $fxlshift/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum left with wraparound.
   (core-runtime-helper
    '$fxlshift/wraparound
    "$fxlshift/wraparound"
    (lambda ()
      `(func $fxlshift/wraparound (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $fxrshift/logical : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum right logically.
   (core-runtime-helper
    '$fxrshift/logical
    "$fxrshift/logical"
    (lambda ()
      `(func $fxrshift/logical (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_u ,(local-fixnum-payload-u '$x)
                                    ,(local-fixnum-payload-u '$y)))))))
   ;; $unsafe-fxnot : fixnum? -> fixnum?
   ;;   Compute bitwise-not; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxnot
    "$unsafe-fxnot"
    (lambda ()
      `(func $unsafe-fxnot (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.xor ,(local-fixnum-payload-s '$x)
                                  (i32.const -1)))))))
   ;; $unsafe-fxpopcount : fixnum? -> fixnum?
   ;;   Count one bits; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxpopcount
    "$unsafe-fxpopcount"
    (lambda ()
      `(func $unsafe-fxpopcount (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-bits-u '$x)))))))
   ;; $unsafe-fxpopcount32 : fixnum? -> fixnum?
   ;;   Count one bits; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxpopcount32
    "$unsafe-fxpopcount32"
    (lambda ()
      `(func $unsafe-fxpopcount32 (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-bits-u '$x)))))))
   ;; $unsafe-fxpopcount16 : fixnum? -> fixnum?
   ;;   Count one bits in the low 16 representation bits; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxpopcount16
    "$unsafe-fxpopcount16"
    (lambda ()
      `(func $unsafe-fxpopcount16 (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt
                          (i32.and ,(local-fixnum-bits-u '$x)
                                   (i32.const 65535))))))))
   ;; $unsafe-fxlshift : fixnum? fixnum? -> fixnum?
   ;;   Shift left; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxlshift
    "$unsafe-fxlshift"
    (lambda ()
      `(func $unsafe-fxlshift (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$k))))))
   ;; $unsafe-fx+/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Add with wraparound; x and y must already be fixnums.
   (core-runtime-helper
    '$unsafe-fx+/wraparound
    "$unsafe-fx+/wraparound"
    (lambda ()
      `(func $unsafe-fx+/wraparound (type $Prim2)
             (param $x (ref eq))
             (param $y (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.add ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-bits-s '$y))))))
   ;; $unsafe-fx*/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Multiply with wraparound; x and y must already be fixnums.
   (core-runtime-helper
    '$unsafe-fx*/wraparound
    "$unsafe-fx*/wraparound"
    (lambda ()
      `(func $unsafe-fx*/wraparound (type $Prim2)
             (param $x (ref eq))
             (param $y (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.mul ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $unsafe-fxlshift/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Shift left with wraparound; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxlshift/wraparound
    "$unsafe-fxlshift/wraparound"
    (lambda ()
      `(func $unsafe-fxlshift/wraparound (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$k))))))
   ;; $unsafe-fxrshift : fixnum? fixnum? -> fixnum?
   ;;   Shift right; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxrshift
    "$unsafe-fxrshift"
    (lambda ()
      `(func $unsafe-fxrshift (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_s ,(local-fixnum-payload-s '$x)
                                    ,(local-fixnum-payload-s '$k)))))))
   ;; $unsafe-fxrshift/logical : fixnum? fixnum? -> fixnum?
   ;;   Shift right logically; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxrshift/logical
    "$unsafe-fxrshift/logical"
    (lambda ()
      `(func $unsafe-fxrshift/logical (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_u ,(local-fixnum-payload-u '$x)
                                    ,(local-fixnum-payload-u '$k)))))))))
