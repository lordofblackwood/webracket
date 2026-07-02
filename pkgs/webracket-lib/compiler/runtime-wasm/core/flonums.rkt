#lang racket

(provide flonum-core-runtime-helpers
         flonum-constructor-runtime-only-helper-names
         flonum-conversion-runtime-only-helper-names
         flonum-minmax-runtime-only-helper-names
         flonum-predicate-runtime-only-helper-names
         flonum-runtime-only-helpers)

(require "../core-helper.rkt")

;; flonum-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum construction helpers.
(define flonum-constructor-runtime-only-helper-names
  '($i32->flonum))

;; flonum-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum predicate helpers.
(define flonum-predicate-runtime-only-helper-names
  '($flonum?
    $double-flonum?))

;; flonum-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum conversion helpers.
(define flonum-conversion-runtime-only-helper-names
  '($fx->fl/precise
    $fx->fl
    $->fl
    $raise-fl->fx
    $fl->fx
    $raise-fl->exact-integer
    $fl->exact-integer))

;; flonum-minmax-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum min/max helpers.
(define flonum-minmax-runtime-only-helper-names
  '($flmin/2
    $flmax/2
    $unsafe-flmin/2
    $unsafe-flmax/2
    $flmin
    $flmax
    $unsafe-flmin
    $unsafe-flmax))

;; flonum-binary-minmax-runtime-helper : symbol? datum? boolean? -> core-runtime-helper?
;;   Build a binary flonum min/max helper, optionally assuming validated arguments.
(define (flonum-binary-minmax-runtime-helper name expr unsafe?)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name
            (type $Prim2)
            (param $a (ref eq))
            (param $b (ref eq))
            (result (ref eq))
            (local $a/fl (ref $Flonum))
            (local $b/fl (ref $Flonum))
            (local $a/f64 f64)
            (local $b/f64 f64)
            ,@(if unsafe?
                  '()
                  `((if (i32.eqz (ref.test (ref $Flonum) (local.get $a)))
                        (then (call $raise-argument-error:flonum-expected (local.get $a))
                              (unreachable)))
                    (if (i32.eqz (ref.test (ref $Flonum) (local.get $b)))
                        (then (call $raise-argument-error:flonum-expected (local.get $b))
                              (unreachable)))))
            (local.set $a/fl (ref.cast (ref $Flonum) (local.get $a)))
            (local.set $b/fl (ref.cast (ref $Flonum) (local.get $b)))
            (local.set $a/f64 (struct.get $Flonum $v (local.get $a/fl)))
            (local.set $b/f64 (struct.get $Flonum $v (local.get $b/fl)))
            (struct.new $Flonum
                        (i32.const 0)
                        ,expr)))))

;; flonum-minmax-runtime-helper : symbol? symbol? boolean? -> core-runtime-helper?
;;   Build a variadic flonum min/max helper, optionally assuming validated arguments.
(define (flonum-minmax-runtime-helper name cmp unsafe?)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (param $x0 (ref eq)) (param $xs (ref eq)) (result (ref eq))
            (local $node (ref $Pair))
            (local $fx   (ref eq))
            (local $best (ref eq))
            ,@(if unsafe?
                  '()
                  `((if (i32.eqz (ref.test (ref $Flonum) (local.get $x0)))
                        (then (call $raise-argument-error:flonum-expected (local.get $x0))
                              (unreachable)))))
            (local.set $best (local.get $x0))
            (block $done
                   (loop $loop
                         (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                         (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                         (local.set $fx   (struct.get $Pair $a (local.get $node)))
                         ,@(if unsafe?
                               '()
                               `((if (i32.eqz (ref.test (ref $Flonum) (local.get $fx)))
                                     (then (call $raise-argument-error:flonum-expected (local.get $fx))
                                           (unreachable)))))
                         (local.set $best (call ,cmp (local.get $best) (local.get $fx)))
                         (local.set $xs (struct.get $Pair $d (local.get $node)))
                         (br $loop)))
            (local.get $best)))))

;; flonum-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum construction helpers used by the monolithic runtime.
(define flonum-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'flonum-constructor-runtime-only-helpers
   '(
     (func $i32->flonum (param $n i32) (result (ref $Flonum))
           (struct.new $Flonum
                       (i32.const 0)  ;; initial hash = 0
                       (f64.convert_i32_s (local.get $n)))))))

;; flonum-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum predicate helpers used by the monolithic runtime.
(define flonum-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'flonum-predicate-runtime-only-helpers
   '(
     ;; flonum? : (ref eq) -> (ref eq)
     ;;   Returns #t if the value is a flonum, #f otherwise
     (func $flonum? (type $Prim1) (param $a (ref eq)) (result (ref eq))
           (if (result (ref eq))
               (ref.test (ref $Flonum) (local.get $a))
               (then (global.get $true))
               (else (global.get $false))))

     ;; double-flonum? : (ref eq) -> (ref eq)
     ;;   All flonums are double precision, so reuse flonum?
     (func $double-flonum? (type $Prim1) (param $a (ref eq)) (result (ref eq))
           (call $flonum? (local.get $a))))))

;; flonum-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum conversion helpers used by the monolithic runtime.
(define flonum-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'flonum-conversion-runtime-only-helpers
   '(
     (func $fx->fl/precise (param $v (ref eq)) (result (ref $Flonum))
           (local $v/i32 i32)
           ;; Check that v is a fixnum (ref i31) and has low bit 0
           (if (i32.eqz (ref.test (ref i31) (local.get $v)))
               (then (call $raise-check-fixnum (local.get $v))
                     (unreachable)))
           (local.set $v/i32 (i31.get_s (ref.cast (ref i31) (local.get $v))))
           (if (i32.and (local.get $v/i32) (i32.const 1))
               (then (call $raise-check-fixnum (local.get $v))
                     (unreachable)))
           ;; Convert fixnum to flonum
           (struct.new $Flonum
                       (i32.const 0)                             ;; hash = 0
                       (f64.convert_i32_s (i32.shr_s (local.get $v/i32) (i32.const 1)))))

     (func $fx->fl (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))  ; a $Flonum

           (local $v/i32 i32)
           ;; Check that v is a fixnum (ref i31) and has low bit 0
           (if (i32.eqz (ref.test (ref i31) (local.get $v)))
               (then (call $raise-check-fixnum (local.get $v))
                     (unreachable)))
           (local.set $v/i32 (i31.get_s (ref.cast (ref i31) (local.get $v))))
           (if (i32.and (local.get $v/i32) (i32.const 1))
               (then (call $raise-check-fixnum (local.get $v))
                     (unreachable)))
           ;; Convert fixnum to flonum
           (struct.new $Flonum
                       (i32.const 0)                             ;; hash = 0
                       (f64.convert_i32_s (i32.shr_s (local.get $v/i32) (i32.const 1)))))

     (func $->fl (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))
           (call $fx->fl (local.get $v)))

     (func $raise-fl->fx (param $x (ref eq)) (unreachable))

     (func $fl->fx (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq)) ; a fixnum

           (local $v/fl  (ref $Flonum))
           (local $x/f64 f64)
           (local $t/f64 f64)
           (local $i32   i32)

           ;; Check that v is a flonum
           (if (i32.eqz (ref.test (ref $Flonum) (local.get $v)))
               (then (call $raise-check-flonum (local.get $v))
                     (unreachable)))
           (local.set $v/fl  (ref.cast (ref $Flonum) (local.get $v)))
           (local.set $x/f64 (struct.get $Flonum $v (local.get $v/fl)))
           ;; Truncate toward zero
           (local.set $t/f64 (f64.trunc (local.get $x/f64)))
           ;; NaN?
           (if (f64.ne (local.get $t/f64) (local.get $t/f64))
               (then (call $raise-fl->fx (local.get $v))
                     (unreachable)))
           ;; Check fixnum range
           (if (i32.or (f64.gt (local.get $t/f64) (f64.const 536870911.0))
                       (f64.lt (local.get $t/f64) (f64.const -536870912.0)))
               (then (call $raise-fl->fx (local.get $v))
                     (unreachable)))
           ;; Convert to i32 and box
           (local.set $i32 (i32.trunc_f64_s (local.get $t/f64)))
           (ref.i31 (i32.shl (local.get $i32) (i32.const 1))))

     (func $raise-fl->exact-integer (param $x (ref eq)) (unreachable))

     (func $fl->exact-integer (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))

           (local $v/fl  (ref $Flonum))
           (local $x/f64 f64)
           (local $t/f64 f64)
           (local $i32   i32)

           ;; Check that v is a flonum
           (if (i32.eqz (ref.test (ref $Flonum) (local.get $v)))
               (then (call $raise-check-flonum (local.get $v))
                     (unreachable)))
           (local.set $v/fl  (ref.cast (ref $Flonum) (local.get $v)))
           (local.set $x/f64 (struct.get $Flonum $v (local.get $v/fl)))
           (local.set $t/f64 (f64.trunc (local.get $x/f64)))
           ;; Must be integer
           (if (f64.ne (local.get $x/f64) (local.get $t/f64))
               (then (call $raise-fl->exact-integer (local.get $v))
                     (unreachable)))
           ;; NaN?
           (if (f64.ne (local.get $t/f64) (local.get $t/f64))
               (then (call $raise-fl->exact-integer (local.get $v))
                     (unreachable)))
           ;; Check fixnum range
           (if (i32.or (f64.gt (local.get $t/f64) (f64.const 536870911.0))
                       (f64.lt (local.get $t/f64) (f64.const -536870912.0)))
               (then (call $raise-fl->exact-integer (local.get $v))
                     (unreachable)))
           (local.set $i32 (i32.trunc_f64_s (local.get $t/f64)))
           (ref.i31 (i32.shl (local.get $i32) (i32.const 1)))))))

;; flonum-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers that depend on monolithic runtime errors.
(define flonum-runtime-only-helpers
  (append
   flonum-constructor-runtime-only-helpers
   flonum-predicate-runtime-only-helpers
   flonum-conversion-runtime-only-helpers
   (for/list ([name '( $flmin/2 $flmax/2 )]
              [expr '((f64.min (local.get $a/f64) (local.get $b/f64))
                      (f64.max (local.get $a/f64) (local.get $b/f64)))])
     (flonum-binary-minmax-runtime-helper name expr #f))
   (for/list ([name '( $unsafe-flmin/2 $unsafe-flmax/2 )]
              [expr '((f64.min (local.get $a/f64) (local.get $b/f64))
                      (f64.max (local.get $a/f64) (local.get $b/f64)))])
     (flonum-binary-minmax-runtime-helper name expr #t))
   (for/list ([name '( $flmin $flmax )]
              [cmp  '( $flmin/2 $flmax/2 )])
     (flonum-minmax-runtime-helper name cmp #f))
   (for/list ([name '( $unsafe-flmin $unsafe-flmax )]
              [cmp  '( $unsafe-flmin/2 $unsafe-flmax/2 )])
     (flonum-minmax-runtime-helper name cmp #t))))

;; flonum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers that can be emitted in core runtime.
(define flonum-core-runtime-helpers
  (list
   ;; fl?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a flonum, 0 otherwise.
   (core-runtime-helper
    '$fl?/i32
    "$fl?/i32"
    (lambda ()
      `(func $fl?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Flonum) (local.get $a)))))))
