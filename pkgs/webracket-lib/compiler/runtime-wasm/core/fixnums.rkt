#lang racket

(provide fixnum-core-runtime-helpers
         fixnum-runtime-string-constants
         fixnum-runtime-symbol-constants
         fixnum-global-forms
         fixnum-runtime-helper-forms
         fixnum-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/immediates.rkt"
         "../../private/wasm-utils.rkt")

;; fixnum-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by fixnum helpers and fixnum errors.
(define fixnum-runtime-string-constants
  '((fixnum?             "fixnum?")
    (fx-overflow:middle  ": fixnum overflow with arguments ")
    (fx-overflow:and     " and ")
    (fx-division-by-zero ": attempt to divide by zero")
    (division-by-zero    ": division by zero")
    (expected-fixnum:got "expected fixnum, got: ")))

;; fixnum-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by fixnum helpers and errors.
(define fixnum-runtime-symbol-constants
  '(fixnum?
    fixnum
    /
    fx/))

;; fixnum-global-forms : (listof datum?)
;;   Declare globals for commonly used fixnums.
(define fixnum-global-forms
  `(
         ;; Commonly used fixnums
         (global $zero  (ref eq) ,(Imm 0))
         (global $one   (ref eq) ,(Imm 1))
         (global $two   (ref eq) ,(Imm 2))
         (global $three (ref eq) ,(Imm 3))))

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

;; Half : datum? -> datum?
;;   Decode a tagged fixnum expression to an i32 payload.
(define (Half x)
  `(i32.shr_s ,x (i32.const 1)))

;; Double : datum? -> datum?
;;   Encode an i32 payload as tagged fixnum bits.
(define (Double x)
  `(i32.shl ,x (i32.const 1)))

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

;; fixnum-arithmetic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for fixnum arithmetic helpers.
(define fixnum-arithmetic-runtime-only-helper-names
  '($fx+
    $fx-
    $fx/
    $raise-fx-overflow
    $ensure-fixnum-argument
    $fx*
    $raise-division-by-zero/who
    $raise-division-by-zero
    $unsafe-fxquotient
    $fxquotient
    $unsafe-fxremainder
    $fxremainder
    $unsafe-fxmodulo
    $fxmodulo
    $unsafe-fxabs
    $fxabs))

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
     (func $raise-not-fixnum
           (param $x (ref eq))
           (call $raise-check-fixnum (local.get $x))
           (unreachable))

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

;; fixnum-arithmetic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum arithmetic helpers used by the monolithic runtime.
(define fixnum-arithmetic-runtime-only-helpers
  (function-forms->runtime-helpers
   'fixnum-arithmetic-runtime-only-helpers
   `(
     #;(func $fx+ (type $Prim2)
             (param $x (ref eq))
             (param $y (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.add (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))

     (func $fx+ (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $sum i64) ;; tagged sum payload: 2x + 2y

           ;; Check fixnum arguments
           ;; - note: this avoids functions calls in the non-error case
           (if (i32.eqz
                (i32.and
                 (if (result i32) (ref.test (ref i31) (local.get $x))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $x)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))
                 (if (result i32) (ref.test (ref i31) (local.get $y))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $y)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))))
               (then
                (call $ensure-fixnum-argument (global.get $symbol:fx+) (local.get $x))
                (call $ensure-fixnum-argument (global.get $symbol:fx+) (local.get $y)))
               (else))

           ;; Add
           (local.set $sum
                      (i64.add
                       (i64.extend_i32_s
                        (i31.get_s (ref.cast (ref i31) (local.get $x))))
                       (i64.extend_i32_s
                        (i31.get_s (ref.cast (ref i31) (local.get $y))))))

           ;; Tagged payload must fit in signed i31 and remain even:
           ;; range is [-2^30, 2^30-2].
           (if (i32.or
                (i64.lt_s (local.get $sum) (i64.const -1073741824))  ;; -2^30
                (i64.gt_s (local.get $sum) (i64.const  1073741822))) ;;  2^30-2
               (then
                (call $raise-fx-overflow (global.get $symbol:fx+) (local.get $x) (local.get $y))
                (unreachable))
               (else))

           (ref.i31 (i32.wrap_i64 (local.get $sum))))

     #;(func $fx- (type $Prim2) (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.sub (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))

     (func $fx- (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $dt i64) ;; tagged difference payload: 2(x - y)

           ;; Check fixnum arguments
           ;; - note: this avoids functions calls in the non-error case
           (if (i32.eqz
                (i32.and
                 (if (result i32) (ref.test (ref i31) (local.get $x))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $x)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))
                 (if (result i32) (ref.test (ref i31) (local.get $y))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $y)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))))
               (then
                (call $ensure-fixnum-argument (global.get $symbol:fx-) (local.get $x))
                (call $ensure-fixnum-argument (global.get $symbol:fx-) (local.get $y)))
               (else))

           ;; The subtraction
           (local.set $dt
                      (i64.sub
                       (i64.extend_i32_s
                        (i31.get_s (ref.cast (ref i31) (local.get $x))))
                       (i64.extend_i32_s
                        (i31.get_s (ref.cast (ref i31) (local.get $y))))))

           ;; Tagged payload must fit in signed i31 and remain even:
           ;; range is [-2^30, 2^30-2].
           (if (i32.or
                (i64.lt_s (local.get $dt) (i64.const -1073741824))  ;; -2^30
                (i64.gt_s (local.get $dt) (i64.const  1073741822))) ;;  2^30-2
               (then
                (call $raise-fx-overflow (global.get $symbol:fx-) (local.get $x) (local.get $y))
                (unreachable))
               (else))

           (ref.i31 (i32.wrap_i64 (local.get $dt))))

     #;(func $fx/ (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.div_s (i31.get_s (ref.cast i31ref (local.get $x)))
                                 ,(Double `(i31.get_s (ref.cast i31ref (local.get $y)))))))

     (func $fx/
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $xi i32) ;; untagged x
           (local $yi i32) ;; untagged y
           (local $q  i32) ;; untagged quotient

           ;; Check fixnum arguments
           ;; - note: this avoids functions calls in the non-error case
           (if (i32.eqz
                (i32.and
                 (if (result i32) (ref.test (ref i31) (local.get $x))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $x)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))
                 (if (result i32) (ref.test (ref i31) (local.get $y))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $y)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))))
               (then
                (call $ensure-fixnum-argument (global.get $symbol:fx/) (local.get $x))
                (call $ensure-fixnum-argument (global.get $symbol:fx/) (local.get $y)))
               (else))

           (local.set $xi (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $x)))
                                     (i32.const 1)))
           (local.set $yi (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $y)))
                                     (i32.const 1)))

           (if (i32.eqz (local.get $yi))
               (then
                (call $raise-division-by-zero/who (global.get $symbol:fx/))
                (unreachable))
               (else))

           ;; Tagged quotient would overflow when -2^29 / -1 = 2^29.
           (if (i32.and
                (i32.eq (local.get $xi) (i32.const -536870912))
                (i32.eq (local.get $yi) (i32.const -1)))
               (then
                (call $raise-fx-overflow (global.get $symbol:fx/) (local.get $x) (local.get $y))
                (unreachable))
               (else))

           (local.set $q (i32.div_s (local.get $xi) (local.get $yi)))
           (ref.i31 (i32.shl (local.get $q) (i32.const 1))))

     ;; Since an integer n is represented as 2n, we need to halve one argument.
     ;;   This version doesn't throw an exception on overflow.
     #;(func $fx* (type $Prim2) (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.mul (i31.get_s (ref.cast i31ref (local.get $x)))
                               ,(Half `(i31.get_s (ref.cast i31ref (local.get $y)))))))

     (func $raise-fx-overflow
           (param $who (ref eq))
           (param $x   (ref eq))
           (param $y   (ref eq))

           (local $message (ref $String))
           (local $who-str (ref $String))
           (local $x-str   (ref $String))
           (local $y-str   (ref $String))
           (local $exn     (ref $Struct))

           (local.set $who-str (call $format/display (local.get $who)))
           (local.set $x-str   (call $format/error-value->string (local.get $x)))
           (local.set $y-str   (call $format/error-value->string (local.get $y)))

           (local.set $message (call $string-append/2
                                     (local.get $who-str)
                                     (global.get $string:fx-overflow:middle)))
           (local.set $message (call $string-append/2
                                     (local.get $message)
                                     (local.get $x-str)))
           (local.set $message (call $string-append/2
                                     (local.get $message)
                                     (global.get $string:fx-overflow:and)))
           (local.set $message (call $string-append/2
                                     (local.get $message)
                                     (local.get $y-str)))

           (local.set $exn     (call $exn:fail:contract:non-fixnum-result/make
                                     (ref.cast (ref eq) (local.get $message))
                                     (global.get $null)))

           ;; barrier? is ignored by WebRacket raise, but pass #t for compatibility
           (call $raise
                 (ref.cast (ref eq) (local.get $exn))
                 (global.get $true))
           (unreachable))

     (func $ensure-fixnum-argument
           (param $who (ref eq))
           (param $x   (ref eq))

           (local $message (ref $String))
           (local $who-str (ref $String))
           (local $x-str   (ref $String))
           (local $exn     (ref $Struct))

           (if (i32.eqz (call $fixnum?/i32 (local.get $x)))
               (then
                (local.set $who-str (call $format/display (local.get $who)))
                (local.set $x-str   (call $format/error-value->string (local.get $x)))

                (local.set $message (call $string-append/2
                                          (local.get $who-str)
                                          (global.get $string:expected-fixnum:got)))
                (local.set $message (call $string-append/2
                                          (local.get $message)
                                          (local.get $x-str)))

                (local.set $exn     (call $exn:fail:contract/make
                                          (ref.cast (ref eq) (local.get $message))
                                          (global.get $null)))

                (call $raise (ref.cast (ref eq) (local.get $exn)) (global.get $true))
                (unreachable))))

     (func $fx* (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $pt i64) ;; tagged product payload: 2xy

           ;; Check fixnum arguments
           ;; - note: this avoids functions calls in the non-error case
           (if (i32.eqz
                (i32.and
                 (if (result i32) (ref.test (ref i31) (local.get $x))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $x)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))
                 (if (result i32) (ref.test (ref i31) (local.get $y))
                     (then
                      (i32.eqz
                       (i32.and
                        (i31.get_u (ref.cast (ref i31) (local.get $y)))
                        (i32.const 1))))
                     (else
                      (i32.const 0)))))
               (then
                (call $ensure-fixnum-argument (global.get $symbol:fx*) (local.get $x))
                (call $ensure-fixnum-argument (global.get $symbol:fx*) (local.get $y)))
               (else))


           ;; Fixnums are tagged as 2n.
           ;; If x = 2a and y = 2b, then:
           ;;   (x * y) >> 1 = (2a * 2b) >> 1 = 2ab
           ;; which is exactly the tagged payload for the product.
           (local.set $pt
                      (i64.shr_s
                       (i64.mul
                        (i64.extend_i32_s
                         (i31.get_s (ref.cast (ref i31) (local.get $x))))
                        (i64.extend_i32_s
                         (i31.get_s (ref.cast (ref i31) (local.get $y)))))
                       (i64.const 1)))

           ;; Tagged payload must fit in signed i31 and remain even:
           ;; range is [-2^30, 2^30-2].
           (if (i32.or
                (i64.lt_s (local.get $pt) (i64.const -1073741824))  ;; -2^30
                (i64.gt_s (local.get $pt) (i64.const  1073741822))) ;;  2^30-2
               (then
                (call $raise-fx-overflow (global.get $symbol:fx*) (local.get $x) (local.get $y))
                (unreachable))
               (else))

           (ref.i31 (i32.wrap_i64 (local.get $pt))))

     (func $raise-division-by-zero/who
           (param $who (ref eq))

           (local $message (ref $String))
           (local $exn     (ref $Struct))

           (local.set $message
                      (call $string-append/2
                            (call $format/display (local.get $who))
                            (global.get $string:fx-division-by-zero)))
           (local.set $exn
                      (call $exn:fail:contract/make
                            (ref.cast (ref eq) (local.get $message))
                            (call $current-continuation-marks
                                  (global.get $missing))))
           (call $raise
                 (ref.cast (ref eq) (local.get $exn))
                 (global.get $true))
           (unreachable))

     (func $raise-division-by-zero
           (local $message (ref $String))
           (local $exn     (ref $Struct))

           (local.set $message
                      (call $string-append/2
                            (call $format/display (global.get $symbol:/))
                            (global.get $string:division-by-zero)))
           (local.set $exn
                      (call $exn:fail:contract/make
                            (ref.cast (ref eq) (local.get $message))
                            (call $current-continuation-marks
                                  (global.get $missing))))
           (call $raise
                 (ref.cast (ref eq) (local.get $exn))
                 (global.get $true))
           (unreachable))

     (func $unsafe-fxquotient (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (ref.i31 ,(Double `(i32.div_s ,(Half `(i31.get_s (ref.cast i31ref (local.get $x))))
                                         ,(Half `(i31.get_s (ref.cast i31ref (local.get $y))))))))

     (func $fxquotient (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $xu i32) (local $yu i32)     ;; raw tagged bits
           (local $xi i32) (local $yi i32)     ;; untagged i32s
           (local $q  i32)                     ;; quotient

           ;; --- check $x is a fixnum ---
           (call $ensure-fixnum-argument
                 (global.get $symbol:fxquotient)
                 (local.get $x))
           (local.set $xu (i31.get_s (ref.cast (ref i31) (local.get $x))))
           (local.set $xi (i32.shr_s (local.get $xu) (i32.const 1)))
           ;; --- check $y is a fixnum ---
           (call $ensure-fixnum-argument
                 (global.get $symbol:fxquotient)
                 (local.get $y))
           (local.set $yu (i31.get_s (ref.cast (ref i31) (local.get $y))))
           (local.set $yi (i32.shr_s (local.get $yu) (i32.const 1)))
           ;; --- divide by zero? ---
           (if (i32.eqz (local.get $yi))
               (then (call $raise-division-by-zero/who
                           (global.get $symbol:fxquotient))
                     (unreachable)))
           ;; --- compute truncating quotient ---
           (local.set $q (i32.div_s (local.get $xi) (local.get $yi)))
           ;; --- (optional) fixnum-range check: [-2^29, 2^29-1] ---
           ;; uncomment if you want to signal overflow instead of wrapping
           ;; (if (i32.or
           ;;       (i32.lt_s (local.get $q) (i32.const -536870912)) ;; -2^29
           ;;       (i32.gt_s (local.get $q) (i32.const  536870911))) ;;  2^29-1
           ;;     (then (call $raise-fixnum-overflow) (unreachable)))
           ;; --- re-tag as fixnum ---
           (ref.i31 (i32.shl (local.get $q) (i32.const 1))))

     (func $unsafe-fxremainder (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (ref.i31 (i32.rem_s (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))

     (func $fxremainder (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $xv i32)
           (local $yv i32)

           (call $ensure-fixnum-argument
                 (global.get $symbol:fxremainder)
                 (local.get $x))
           (call $ensure-fixnum-argument
                 (global.get $symbol:fxremainder)
                 (local.get $y))
           (local.set $xv (i31.get_s (ref.cast i31ref (local.get $x))))
           (local.set $yv (i31.get_s (ref.cast i31ref (local.get $y))))
           (if (i32.eqz (local.get $yv))
               (then (call $raise-division-by-zero/who
                           (global.get $symbol:fxremainder))
                     (unreachable)))
           (ref.i31 (i32.rem_s (local.get $xv) (local.get $yv))))

     (func $unsafe-fxmodulo (type $Prim2)
           (param $x (ref eq))
           (param $y (ref eq))
           (result   (ref eq))

           (local $xv i32)
           (local $yv i32)
           (local $r  i32)

           (local.set $xv (i31.get_s (ref.cast i31ref (local.get $x))))
           (local.set $yv (i31.get_s (ref.cast i31ref (local.get $y))))
           (local.set $r  (i32.rem_s (local.get $xv) (local.get $yv)))
           (if (result (ref eq))
               (i32.eqz (local.get $r))
               (then (ref.i31 (local.get $r)))
               (else (if (result (ref eq))
                         (i32.eq (i32.lt_s (local.get $r) (i32.const 0))
                                 (i32.lt_s (local.get $yv) (i32.const 0)))
                         (then (ref.i31 (local.get $r)))
                         (else (ref.i31 (i32.add (local.get $r) (local.get $yv))))))))

     (func $fxmodulo (type $Prim2)
           (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
           (local $xv i32) (local $yv i32) (local $r i32)

           (call $ensure-fixnum-argument
                 (global.get $symbol:fxmodulo)
                 (local.get $x))
           (call $ensure-fixnum-argument
                 (global.get $symbol:fxmodulo)
                 (local.get $y))
           (local.set $xv (i31.get_s (ref.cast i31ref (local.get $x))))
           (local.set $yv (i31.get_s (ref.cast i31ref (local.get $y))))
           (if (i32.eqz (local.get $yv))
               (then (call $raise-division-by-zero/who
                           (global.get $symbol:fxmodulo))
                     (unreachable)))
           (local.set $r  (i32.rem_s (local.get $xv) (local.get $yv)))
           (if (result (ref eq))
               (i32.eqz (local.get $r))
               (then (ref.i31 (local.get $r)))
               (else (if (result (ref eq))
                         (i32.eq (i32.lt_s (local.get $r) (i32.const 0))
                                 (i32.lt_s (local.get $yv) (i32.const 0)))
                         (then (ref.i31 (local.get $r)))
                         (else (ref.i31 (i32.add (local.get $r) (local.get $yv))))))))

     (func $unsafe-fxabs (type $Prim1)
           (param $x (ref eq))
           (result   (ref eq))

           (local $xi i32)

           (local.set $xi (i31.get_s (ref.cast i31ref (local.get $x))))
           (ref.i31 (if (result i32)
                        (i32.lt_s (local.get $xi) (i32.const 0))
                        (then (i32.sub (i32.const 0) (local.get $xi)))
                        (else (local.get $xi)))))

     (func $fxabs (type $Prim1)
           (param $x (ref eq)) (result (ref eq))
           (local $xi i32)
           (local.set $xi (i31.get_s (ref.cast i31ref (local.get $x))))
           (ref.i31 (if (result i32)
                        (i32.lt_s (local.get $xi) (i32.const 0))
                        (then (i32.sub (i32.const 0) (local.get $xi)))
                        (else (local.get $xi))))))))

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
                         (else
                          (call $raise-arity-mismatch/name+given
                                (global.get $symbol:fx-/wraparound)
                                (i32.add (i32.const 1)
                                         (call $length/i32 (local.get $rest))))
                          (unreachable))))
                    (else
                     (call $raise-arity-mismatch/name+given
                           (global.get $symbol:fx-/wraparound)
                           (i32.const 2))
                     (unreachable)))))
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

;; fixnum-promoted-runtime-helper-names : (listof symbol?)
;;   Name runtime fixnum helpers that are available in the standalone core runtime.
(define fixnum-promoted-runtime-helper-names
  '($fixnum?
    $fxvector?
    $fxzero?
    $fx+
    $fx-
    $fx/
    $raise-fx-overflow
    $ensure-fixnum-argument
    $fx*
    $raise-division-by-zero/who
    $raise-division-by-zero
    $unsafe-fxquotient
    $fxquotient
    $unsafe-fxremainder
    $fxremainder
    $unsafe-fxmodulo
    $fxmodulo
    $unsafe-fxabs
    $fxabs
    $most-positive-fixnum
    $most-negative-fixnum
    $fx=/2
    $fx</2
    $fx>/2
    $fx<=/2
    $fx>=/2
    $fxand
    $fxior
    $fxxor
    $fxmin/2
    $fxmax/2
    $fixnum-for-every-system?))

;; fixnum-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum helpers in monolithic runtime order.
(define fixnum-all-runtime-helpers
  (append
   fixnum-predicate-runtime-only-helpers
   fixnum-arithmetic-runtime-only-helpers
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

;; fixnum-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate manually defined fixnum helpers that originated in core runtime.
(define fixnum-base-core-runtime-helpers
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

;; fixnum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum helpers available in the standalone core runtime.
(define fixnum-core-runtime-helpers
  (append fixnum-base-core-runtime-helpers
          (select-runtime-helpers fixnum-all-runtime-helpers
                                  fixnum-promoted-runtime-helper-names)))

;; fixnum-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum helpers that still depend on monolithic runtime globals.
(define fixnum-runtime-only-helpers
  (remove-runtime-helpers fixnum-all-runtime-helpers
                          fixnum-promoted-runtime-helper-names))

;; fixnum-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given fixnum helper names from the runtime helper index.
(define (fixnum-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; fixnum-core-helper-form : hasheq? symbol? -> datum?
;;   Render one fixnum core helper.
(define (fixnum-core-helper-form helper-index name)
  (core-runtime-helper-form helper-index name))

;; fixnum-bitwise-and-wraparound-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render the mixed core/runtime fixnum bitwise and wraparound block.
(define (fixnum-bitwise-and-wraparound-helper-forms runtime-helper-index core-runtime-helper-index)
  (list
   (fixnum-core-helper-form core-runtime-helper-index '$fixnum?/i32)
   (fixnum-core-helper-form core-runtime-helper-index '$fxand/2)
   (core-runtime-helper-form runtime-helper-index '$fxand)
   (fixnum-core-helper-form core-runtime-helper-index '$fxior/2)
   (core-runtime-helper-form runtime-helper-index '$fxior)
   (fixnum-core-helper-form core-runtime-helper-index '$fxxor/2)
   (core-runtime-helper-form runtime-helper-index '$fxxor)
   (fixnum-core-helper-form core-runtime-helper-index '$fxnot)
   (fixnum-core-helper-form core-runtime-helper-index '$fxlshift)
   (fixnum-core-helper-form core-runtime-helper-index '$fxrshift)
   (fixnum-core-helper-form core-runtime-helper-index '$fxpopcount)
   (fixnum-core-helper-form core-runtime-helper-index '$fxpopcount32)
   (fixnum-core-helper-form core-runtime-helper-index '$fxpopcount16)
   (fixnum-core-helper-form core-runtime-helper-index '$fx+/wraparound)
   (core-runtime-helper-form runtime-helper-index '$fx-/wraparound)
   (fixnum-core-helper-form core-runtime-helper-index '$fx*/wraparound)
   (fixnum-core-helper-form core-runtime-helper-index '$fxlshift/wraparound)
   (fixnum-core-helper-form core-runtime-helper-index '$fxrshift/logical)))

;; fixnum-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render the full fixnum helper block in runtime assembly order.
(define (fixnum-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (append
   (fixnum-helper-forms runtime-helper-index fixnum-predicate-runtime-only-helper-names)
   (list (fixnum-core-helper-form core-runtime-helper-index '$fx?/i32))
   (fixnum-helper-forms runtime-helper-index fixnum-arithmetic-runtime-only-helper-names)
   (fixnum-bitwise-and-wraparound-helper-forms runtime-helper-index core-runtime-helper-index)
   (fixnum-helper-forms runtime-helper-index fixnum-comparison-runtime-only-helper-names)
   (fixnum-helper-forms runtime-helper-index fixnum-minmax-runtime-only-helper-names)
   (fixnum-helper-forms runtime-helper-index fixnum-conversion-runtime-only-helper-names)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define fixnum-helper-index
    (make-core-runtime-helper-index
     (append fixnum-core-runtime-helpers
             fixnum-runtime-only-helpers)))

  (define fixnum-core-helper-index
    (make-core-runtime-helper-index fixnum-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name
        (select-runtime-helpers fixnum-core-runtime-helpers
                                fixnum-promoted-runtime-helper-names))
   fixnum-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (fixnum-bitwise-and-wraparound-helper-forms fixnum-helper-index
                                                    fixnum-core-helper-index))
   '($fixnum?/i32
     $fxand/2
     $fxand
     $fxior/2
     $fxior
     $fxxor/2
     $fxxor
     $fxnot
     $fxlshift
     $fxrshift
     $fxpopcount
     $fxpopcount32
     $fxpopcount16
     $fx+/wraparound
     $fx-/wraparound
     $fx*/wraparound
     $fxlshift/wraparound
     $fxrshift/logical))

  (check-equal?
   (map form-name
        (fixnum-runtime-helper-forms fixnum-helper-index
                                     fixnum-core-helper-index))
   (append fixnum-predicate-runtime-only-helper-names
           '($fx?/i32)
           fixnum-arithmetic-runtime-only-helper-names
           '($fixnum?/i32
             $fxand/2
             $fxand
             $fxior/2
             $fxior
             $fxxor/2
             $fxxor
             $fxnot
             $fxlshift
             $fxrshift
             $fxpopcount
             $fxpopcount32
             $fxpopcount16
             $fx+/wraparound
             $fx-/wraparound
             $fx*/wraparound
             $fxlshift/wraparound
             $fxrshift/logical)
           fixnum-comparison-runtime-only-helper-names
           fixnum-minmax-runtime-only-helper-names
           fixnum-conversion-runtime-only-helper-names)))
