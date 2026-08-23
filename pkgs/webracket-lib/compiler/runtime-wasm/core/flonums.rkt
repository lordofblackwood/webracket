#lang racket

(provide flonum-core-runtime-helpers
         flonum-global-forms
         flonum-global-names
         flonum-initializer-forms
         flonum-runtime-helper-forms
         flonum-runtime-string-constants
         flonum-runtime-symbol-constants
         flonum-runtime-only-helpers)

(require "../core-helper.rkt"
         (only-in "../../private/wasm-utils.rkt"
                  Undefined))

;; flonum-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by flonum helpers and flonum errors.
(define flonum-runtime-string-constants
  '((flonum?                      "flonum?")
    (flonum-integer?              "(and/c flonum? integer?)")
    (flonum-error:colon-space     ": ")
    (fl->fx-error:result-for      "result for ")
    (fl->fx-error:outside-fixnum  " would be outside of fixnum range")
    (flbit-field:index            "(integer-in 0 64)")
    (flbit-field:start<=end       "start must be <= end")
    (flbit-field:outside-fixnum   "result would be outside of WebRacket fixnum range")))

;; flonum-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by flonum helpers and errors.
(define flonum-runtime-symbol-constants
  '(fx->fl
    ->fl
    fl->fx
    fl->exact-integer
    fl+
    fl-
    fl*
    fl/
    fl=
    fl<
    fl>
    fl<=
    fl>=
    flabs
    flround
    flfloor
    flceiling
    fltruncate
    flsingle
    flsin
    flcos
    fltan
    flasin
    flacos
    flatan
    flsinh
    flcosh
    fltanh
    flasinh
    flacosh
    flatanh
    fllog
    flexp
    flsqrt
    flexpt
    flbit-field
    flmin
    flmax))

;; flonum-global-forms : (listof datum?)
;;   Declare globals for commonly used flonum constants.
(define flonum-global-forms
  `(
         ;; Commonly used flonums
         ;; - initialized during runtime startup
         (global $flzero  (mut (ref eq)) ,(Undefined))
         (global $flone   (mut (ref eq)) ,(Undefined))
         (global $fltwo   (mut (ref eq)) ,(Undefined))
         (global $flthree (mut (ref eq)) ,(Undefined))))

;; flonum-global-names : (listof symbol?)
;;   Enumerate globals for commonly used flonum constants.
(define flonum-global-names
  (for/list ([form (in-list flonum-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'flonum-global-names
                "expected global form, got: ~s"
                form)])))

;; flonum-initializer-forms : (listof datum?)
;;   Initialize globals for commonly used flonum constants.
(define flonum-initializer-forms
  '(
                     (global.set $flzero  (call $i32->flonum (i32.const 0)))
                     (global.set $flone   (call $i32->flonum (i32.const 1)))
                     (global.set $fltwo   (call $i32->flonum (i32.const 2)))
                     (global.set $flthree (call $i32->flonum (i32.const 3)))))

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

;; flonum-arithmetic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum arithmetic helpers.
(define flonum-arithmetic-runtime-only-helper-names
  '($raise-argument-error:flonum-expected
    $fl+
    $fl-
    $fl*
    $unsafe-fl/
    $fl//checked
    $raise-check-flonum
    $fl/))

;; flonum-unary-math-ops : (listof (list symbol? datum?))
;;   Enumerate unary flonum math operators and their f64 implementations.
(define flonum-unary-math-ops
  '((flabs      (f64.abs (local.get $a/f64)))
    (flround    (f64.nearest (local.get $a/f64)))
    (flfloor    (f64.floor (local.get $a/f64)))
    (flceiling  (f64.ceil (local.get $a/f64)))
    (fltruncate (f64.trunc (local.get $a/f64)))
    (flsingle   (f64.promote_f32 (f32.demote_f64 (local.get $a/f64))))
    (flsin      (call $js-raw-math-sin   (local.get $a/f64)))
    (flcos      (call $js-raw-math-cos   (local.get $a/f64)))
    (fltan      (call $js-raw-math-tan   (local.get $a/f64)))
    (flasin     (call $js-raw-math-asin  (local.get $a/f64)))
    (flacos     (call $js-raw-math-acos  (local.get $a/f64)))
    (flatan     (call $js-raw-math-atan  (local.get $a/f64)))
    (flsinh     (call $js-raw-math-sinh  (local.get $a/f64)))
    (flcosh     (call $js-raw-math-cosh  (local.get $a/f64)))
    (fltanh     (call $js-raw-math-tanh  (local.get $a/f64)))
    (flasinh    (call $js-raw-math-asinh (local.get $a/f64)))
    (flacosh    (call $js-raw-math-acosh (local.get $a/f64)))
    (flatanh    (call $js-raw-math-atanh (local.get $a/f64)))
    (fllog      (call $js-raw-math-log  (local.get $a/f64)))
    (flexp      (call $js-raw-math-exp  (local.get $a/f64)))
    (flsqrt     (call $js-raw-math-sqrt (local.get $a/f64)))))

;; flonum-binary-math-ops : (listof (list symbol? datum?))
;;   Enumerate binary flonum math operators and their f64 implementations.
(define flonum-binary-math-ops
  '((flexpt (call $pow-special (local.get $a/f64) (local.get $b/f64)))))

;; flonum-checked-name : symbol? -> symbol?
;;   Convert a public flonum operator name to its Wasm helper name.
(define (flonum-checked-name name)
  (string->symbol (format "$~a" name)))

;; flonum-unsafe-name : symbol? -> symbol?
;;   Convert a public flonum operator name to its unsafe Wasm helper name.
(define (flonum-unsafe-name name)
  (string->symbol (format "$unsafe-~a" name)))

;; wasm-name->runtime-symbol : symbol? -> symbol?
;;   Convert a Wasm helper name such as `$fl+` to the public `fl+` symbol.
(define (wasm-name->runtime-symbol name)
  (define s (symbol->string name))
  (if (string-prefix? s "$")
      (string->symbol (substring s 1))
      name))

;; wasm-name->symbol-global : symbol? -> symbol?
;;   Convert a Wasm helper name to the matching `$symbol:...` global.
(define (wasm-name->symbol-global name)
  (string->symbol
   (format "$symbol:~a" (wasm-name->runtime-symbol name))))

;; flonum-helper-who-symbol-global : symbol? -> symbol?
;;   Return the user-facing `who` symbol global for a flonum helper.
(define (flonum-helper-who-symbol-global name)
  (case name
    [($flmin/2) '$symbol:flmin]
    [($flmax/2) '$symbol:flmax]
    [else       (wasm-name->symbol-global name)]))

;; flonum-math-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum math helpers.
(define flonum-math-runtime-only-helper-names
  (append
   (for/list ([p (in-list flonum-unary-math-ops)])
     (flonum-checked-name (car p)))
   (for/list ([p (in-list flonum-unary-math-ops)])
     (flonum-unsafe-name (car p)))
   (for/list ([p (in-list flonum-binary-math-ops)])
     (flonum-checked-name (car p)))
   (for/list ([p (in-list flonum-binary-math-ops)])
     (flonum-unsafe-name (car p)))))

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

;; flonum-utility-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for remaining flonum utility helpers.
(define flonum-utility-runtime-only-helper-names
  '($fl=
    $fl<
    $fl>
    $fl<=
    $fl>=
    $flrandom
    $unsafe-flrandom
    $flbit-field))

;; flonum-binary-arithmetic-runtime-helper : symbol? symbol? -> core-runtime-helper?
;;   Build a checked binary flonum arithmetic helper.
(define (flonum-binary-arithmetic-runtime-helper name flbinop)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name
            (param $x (ref eq)) (param $y (ref eq))
            (result (ref eq))
            ;; Type checks
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $x)))
                (then (call $raise-argument-error:flonum-expected
                            (global.get ,(flonum-helper-who-symbol-global name))
                            (local.get $x))
                      (unreachable)))
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $y)))
                (then (call $raise-argument-error:flonum-expected
                            (global.get ,(flonum-helper-who-symbol-global name))
                            (local.get $y))
                      (unreachable)))
            ;; Compute and box result
            (struct.new $Flonum
                        (i32.const 0)
                        (,flbinop
                         (struct.get $Flonum $v
                                     (ref.cast (ref $Flonum) (local.get $x)))
                         (struct.get $Flonum $v
                                     (ref.cast (ref $Flonum) (local.get $y)))))))))

;; flonum-unary-math-runtime-helper : symbol? datum? boolean? -> core-runtime-helper?
;;   Build a unary flonum math helper, optionally assuming a validated argument.
(define (flonum-unary-math-runtime-helper name expr unsafe?)
  (define wasm-name (if unsafe? (flonum-unsafe-name name) (flonum-checked-name name)))
  (core-runtime-helper
   wasm-name
   (symbol->string wasm-name)
   (lambda ()
     `(func ,wasm-name
            (type $Prim1)
            (param $a (ref eq))
            (result (ref eq))
            (local $a/fl (ref $Flonum))
            (local $a/f64 f64)
            ,@(if unsafe?
                  '()
                  `((if (i32.eqz (ref.test (ref $Flonum) (local.get $a)))
                        (then (call $raise-argument-error:flonum-expected
                                    (global.get ,(flonum-helper-who-symbol-global wasm-name))
                                    (local.get $a))
                              (unreachable)))))
            (local.set $a/fl (ref.cast (ref $Flonum) (local.get $a)))
            (local.set $a/f64 (struct.get $Flonum $v (local.get $a/fl)))
            (struct.new $Flonum
                        (i32.const 0)
                        ,expr)))))

;; flonum-binary-math-runtime-helper : symbol? datum? boolean? -> core-runtime-helper?
;;   Build a binary flonum math helper, optionally assuming validated arguments.
(define (flonum-binary-math-runtime-helper name expr unsafe?)
  (define wasm-name (if unsafe? (flonum-unsafe-name name) (flonum-checked-name name)))
  (core-runtime-helper
   wasm-name
   (symbol->string wasm-name)
   (lambda ()
     `(func ,wasm-name
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
                        (then (call $raise-argument-error:flonum-expected
                                    (global.get ,(flonum-helper-who-symbol-global wasm-name))
                                    (local.get $a))
                              (unreachable)))
                    (if (i32.eqz (ref.test (ref $Flonum) (local.get $b)))
                        (then (call $raise-argument-error:flonum-expected
                                    (global.get ,(flonum-helper-who-symbol-global wasm-name))
                                    (local.get $b))
                              (unreachable)))))
            (local.set $a/fl (ref.cast (ref $Flonum) (local.get $a)))
            (local.set $b/fl (ref.cast (ref $Flonum) (local.get $b)))
            (local.set $a/f64 (struct.get $Flonum $v (local.get $a/fl)))
            (local.set $b/f64 (struct.get $Flonum $v (local.get $b/fl)))
            (struct.new $Flonum
                        (i32.const 0)
                        ,expr)))))

;; flonum-comparison-runtime-helper : symbol? symbol? -> core-runtime-helper?
;;   Build a checked binary flonum comparison helper.
(define (flonum-comparison-runtime-helper flname flcmp)
  (core-runtime-helper
   flname
   (symbol->string flname)
   (lambda ()
     `(func ,flname
            (param $x (ref eq)) (param $y (ref eq))
            (result (ref eq))
            ;; Type checks
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $x)))
                (then (call $raise-argument-error:flonum-expected
                            (global.get ,(flonum-helper-who-symbol-global flname))
                            (local.get $x))
                      (unreachable)))
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $y)))
                (then (call $raise-argument-error:flonum-expected
                            (global.get ,(flonum-helper-who-symbol-global flname))
                            (local.get $y))
                      (unreachable)))
            ;; Compute and box result
            (if (result (ref eq))
                (,flcmp
                 (struct.get $Flonum $v
                             (ref.cast (ref $Flonum) (local.get $x)))
                 (struct.get $Flonum $v
                             (ref.cast (ref $Flonum) (local.get $y))))
                (then (global.get $true))
                (else (global.get $false)))))))

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
                        (then (call $raise-argument-error:flonum-expected
                                    (global.get ,(flonum-helper-who-symbol-global name))
                                    (local.get $a))
                              (unreachable)))
                    (if (i32.eqz (ref.test (ref $Flonum) (local.get $b)))
                        (then (call $raise-argument-error:flonum-expected
                                    (global.get ,(flonum-helper-who-symbol-global name))
                                    (local.get $b))
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
                        (then (call $raise-argument-error:flonum-expected
                                    (global.get ,(flonum-helper-who-symbol-global name))
                                    (local.get $x0))
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
                                     (then (call $raise-argument-error:flonum-expected
                                                 (global.get ,(flonum-helper-who-symbol-global name))
                                                 (local.get $fx))
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
           ;; Check that v is a fixnum (ref i31) and has low bit 0.
           (if (i32.eqz (call $fixnum?/i32 (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:fx->fl)
                           (global.get $string:fixnum?)
                           (local.get $v))
                     (unreachable)))
           (local.set $v/i32 (i31.get_s (ref.cast (ref i31) (local.get $v))))
           ;; Convert fixnum to flonum
           (struct.new $Flonum
                       (i32.const 0)                             ;; hash = 0
                       (f64.convert_i32_s (i32.shr_s (local.get $v/i32) (i32.const 1)))))

     (func $->fl (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))

           (if (ref.eq (call $exact-integer? (local.get $v)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:->fl)
                           (global.get $string:exact-integer?)
                           (local.get $v))
                     (unreachable)))
           (call $fx->fl/precise (local.get $v)))

     (func $raise-fl->fx
           (param $x (ref eq))

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out
                      (call $make-growable-array (i32.const 5)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (global.get $symbol:fl->fx)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:flonum-error:colon-space))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:fl->fx-error:result-for))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $x)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:fl->fx-error:outside-fixnum))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))

           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $fl->fx (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq)) ; a fixnum

           (local $v/fl  (ref $Flonum))
           (local $x/f64 f64)
           (local $t/f64 f64)
           (local $i32   i32)

           ;; Check that v is a flonum
           (if (i32.eqz (ref.test (ref $Flonum) (local.get $v)))
               (then (call $raise-check-flonum
                           (global.get $symbol:fl->fx)
                           (local.get $v))
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

     (func $raise-fl->exact-integer
           (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:fl->exact-integer)
                 (global.get $string:flonum-integer?)
                 (local.get $x))
           (unreachable))

     (func $fl->exact-integer (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))

           (local $v/fl  (ref $Flonum))
           (local $x/f64 f64)
           (local $t/f64 f64)
           (local $i32   i32)

           ;; Check that v is a flonum
           (if (i32.eqz (ref.test (ref $Flonum) (local.get $v)))
               (then (call $raise-fl->exact-integer (local.get $v))
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

;; flonum-arithmetic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum arithmetic helpers used by the monolithic runtime.
(define flonum-arithmetic-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'flonum-arithmetic-runtime-only-helpers
    '(
      #;(func $fl+
              (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
              ;; Type checks
              (if (i32.eqz (ref.test (ref $Flonum) (local.get $x)))
                  (then (call $raise-argument-error:flonum-expected (local.get $x))))
              (if (i32.eqz (ref.test (ref $Flonum) (local.get $y)))
                  (then (call $raise-argument-error:flonum-expected (local.get $y))))
              ;; Compute and box result
              (struct.new $Flonum
                          (f64.add
                           (struct.get $Flonum $v
                                       (ref.cast (ref $Flonum) (local.get $x)))
                           (struct.get $Flonum $v
                                       (ref.cast (ref $Flonum) (local.get $y))))))

      (func $raise-argument-error:flonum-expected
            (param $who (ref eq))
            (param $x   (ref eq))
            (call $raise-argument-error1
                  (local.get $who)
                  (global.get $string:flonum?)
                  (local.get $x))
            (unreachable))))
   (for/list ([name    '($fl+    $fl-    $fl*)]
              [flbinop '(f64.add f64.sub f64.mul)])
     (flonum-binary-arithmetic-runtime-helper name flbinop))
   (function-forms->runtime-helpers
    'flonum-arithmetic-runtime-only-helpers
    '(
      (func $unsafe-fl/ (type $Prim2)
            (param $x (ref eq))
            (param $y (ref eq))
            (result   (ref eq))

            (local $x/fl (ref $Flonum))
            (local $y/fl (ref $Flonum))
            (local $x/f64 f64)
            (local $y/f64 f64)
            ;; Validate via cast (will trap if not a Flonum - hence unsafe)
            (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
            (local.set $y/fl (ref.cast (ref $Flonum) (local.get $y)))
            ;; Extract f64 values
            (local.set $x/f64 (struct.get $Flonum $v (local.get $x/fl)))
            (local.set $y/f64 (struct.get $Flonum $v (local.get $y/fl)))
            ;; Compute and box result
            (struct.new $Flonum
                        (i32.const 0)  ;; hash = 0
                        (f64.div (local.get $x/f64) (local.get $y/f64))))


      (func $fl//checked
            (param $x (ref $Flonum))
            (param $y (ref $Flonum))
            (result   (ref $Flonum))

            (struct.new $Flonum
                        (i32.const 0) ;; hash = 0
                        (f64.div
                         (struct.get $Flonum $v (local.get $x))
                         (struct.get $Flonum $v (local.get $y)))))


      (func $raise-check-flonum
            (param $who (ref eq))
            (param $x   (ref eq))
            (call $raise-argument-error1
                  (local.get $who)
                  (global.get $string:flonum?)
                  (local.get $x))
            (unreachable))

      (func $fl/ (type $Prim2)
            (param $x (ref eq))
            (param $y (ref eq))
            (result   (ref eq)) ; An (ref $Flonum)

            (local $x/fl  (ref $Flonum))
            (local $y/fl  (ref $Flonum))
            (local $x/f64 f64)
            (local $y/f64 f64)
            ;; Type checks
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $x)))
                (then (call $raise-check-flonum
                            (global.get $symbol:fl/)
                            (local.get $x))
                      (unreachable)))
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $y)))
                (then (call $raise-check-flonum
                            (global.get $symbol:fl/)
                            (local.get $y))
                      (unreachable)))
            ;; Cast and extract
            (local.set $x/fl  (ref.cast (ref $Flonum) (local.get $x)))
            (local.set $y/fl  (ref.cast (ref $Flonum) (local.get $y)))
            (local.set $x/f64 (struct.get $Flonum $v (local.get $x/fl)))
            (local.set $y/f64 (struct.get $Flonum $v (local.get $y/fl)))
            ;; Compute and box result
            (struct.new $Flonum
                        (i32.const 0)
                        (f64.div (local.get $x/f64) (local.get $y/f64))))))))

;; flonum-math-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum math helpers used by the monolithic runtime.
(define flonum-math-runtime-only-helpers
  (append
   ;; flonum -> flonum
   (for/list ([p (in-list flonum-unary-math-ops)])
     (flonum-unary-math-runtime-helper (car p) (cadr p) #f))
   (for/list ([p (in-list flonum-unary-math-ops)])
     (flonum-unary-math-runtime-helper (car p) (cadr p) #t))

   ;; flonum flonum -> flonum
   (for/list ([p (in-list flonum-binary-math-ops)])
     (flonum-binary-math-runtime-helper (car p) (cadr p) #f))
   (for/list ([p (in-list flonum-binary-math-ops)])
     (flonum-binary-math-runtime-helper (car p) (cadr p) #t))))

;; flonum-utility-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate remaining flonum utility helpers used by the monolithic runtime.
(define flonum-utility-runtime-only-helpers
  (append
   (for/list ([flname '($fl=    $fl<    $fl>    $fl<=     $fl>=)]
              [flcmp  '(f64.eq  f64.lt  f64.gt  f64.le    f64.ge)])
     (flonum-comparison-runtime-helper flname flcmp))
   (function-forms->runtime-helpers
    'flonum-utility-runtime-only-helpers
    '(
      (func $flrandom (type $Prim01) ; one optional argument
            ;; (flrandom [rand-gen pseudo-random-generator?]) -> flonum in (0,1)
            ;; rand-gen : pseudo-random-generator? (optional, default: uses shared generator)
            (param $rg (ref eq))
            (result    (ref eq))

            (local $gen (ref $PseudoRandomGenerator))
            (local $r i32)

            (local.set $gen (call $current-random-generator))
            (if (i32.eqz (ref.eq (local.get $rg) (global.get $missing)))
                (then
                 (if (i32.eqz (ref.test (ref $PseudoRandomGenerator) (local.get $rg)))
                     (then (call $raise-argument-error1
                                 (global.get $symbol:flrandom)
                                 (global.get $string:pseudo-random-generator?)
                                 (local.get $rg))
                           (unreachable)))
                 (local.set $gen
                            (ref.cast (ref $PseudoRandomGenerator) (local.get $rg)))))
            (local.set $r (call $random-u32/generator (local.get $gen)))
            (struct.new $Flonum
                        (i32.const 0)
                        (f64.div
                         (f64.add (f64.convert_i32_u (local.get $r))
                                  (f64.const 1))
                         (f64.const 4294967298.0))))

      (func $unsafe-flrandom (type $Prim01)
            ;; Unsafe variant: skip generator validation and use shared generator.
            ;; rand-gen : pseudo-random-generator? (optional, ignored)
            (param $rg (ref eq))
            (result    (ref eq))

            (local $r i32)

            (local.set $r (call $random-u32))
            (struct.new $Flonum
                        (i32.const 0)
                        (f64.div
                         (f64.add (f64.convert_i32_u (local.get $r))
                                  (f64.const 1))
                         (f64.const 4294967298.0))))


      ;; NOTE: Limited to results that fit in the fixnum range until bignums land.
      (func $flbit-field (type $Prim3)
            (param $a     (ref eq)) ;; [a]     flonum?
            (param $start (ref eq)) ;; [start] exact-nonnegative-integer?
            (param $end   (ref eq)) ;; [end]   exact-nonnegative-integer?
            (result       (ref eq))

            (local $fl         (ref $Flonum))
            (local $bits       i64)
            (local $start/i    i32)
            (local $end/i      i32)
            (local $width      i32)
            (local $mask       i64)
            (local $shifted    i64)
            (local $result64   i64)
            (local $result/i32 i32)

            ;; Validate flonum argument
            (if (i32.eqz (ref.test (ref $Flonum) (local.get $a)))
                (then (call $raise-argument-error:flonum-expected
                            (global.get $symbol:flbit-field)
                            (local.get $a))
                      (unreachable)))
            (local.set $fl (ref.cast (ref $Flonum) (local.get $a)))
            (local.set $bits (i64.reinterpret_f64 (struct.get $Flonum $v (local.get $fl))))

            (local.set $start/i
                       (call $exact-nonnegative-integer->i32/saturating
                             (local.get $start)))
            (local.set $end/i
                       (call $exact-nonnegative-integer->i32/saturating
                             (local.get $end)))

            ;; Range checks: 0 <= start <= end <= 64
            (if (i32.lt_s (local.get $start/i) (i32.const 0))
                (then (call $raise-argument-error1
                            (global.get $symbol:flbit-field)
                            (global.get $string:flbit-field:index)
                            (local.get $start))
                      (unreachable)))
            (if (i32.lt_s (local.get $end/i) (i32.const 0))
                (then (call $raise-argument-error1
                            (global.get $symbol:flbit-field)
                            (global.get $string:flbit-field:index)
                            (local.get $end))
                      (unreachable)))
            (if (i32.gt_u (local.get $start/i) (i32.const 64))
                (then (call $raise-argument-error1
                            (global.get $symbol:flbit-field)
                            (global.get $string:flbit-field:index)
                            (local.get $start))
                      (unreachable)))
            (if (i32.gt_u (local.get $end/i) (i32.const 64))
                (then (call $raise-argument-error1
                            (global.get $symbol:flbit-field)
                            (global.get $string:flbit-field:index)
                            (local.get $end))
                      (unreachable)))
            (if (i32.lt_s (local.get $end/i) (local.get $start/i))
                (then (call $raise-arguments-error
                            (global.get $symbol:flbit-field)
                            (global.get $string:flbit-field:start<=end)
                            (array.new_fixed $Args 0))
                      (unreachable)))

            ;; Compute mask for requested width
            (local.set $width (i32.sub (local.get $end/i) (local.get $start/i)))
            (local.set $mask
                       (if (result i64) (i32.ge_u (local.get $width) (i32.const 64))
                           (then (i64.const -1))
                           (else (i64.sub (i64.shl (i64.const 1)
                                                   (i64.extend_i32_u (local.get $width)))
                                          (i64.const 1)))))

            ;; Shift and mask the raw bits
            (local.set $shifted (i64.shr_u (local.get $bits)
                                           (i64.extend_i32_u (local.get $start/i))))
            (local.set $result64 (i64.and (local.get $shifted) (local.get $mask)))

            ;; Enforce fixnum-sized result (no bignum support yet)
            (if (i64.gt_u (local.get $result64) (i64.const 536870911))
                (then (call $raise-arguments-error
                            (global.get $symbol:flbit-field)
                            (global.get $string:flbit-field:outside-fixnum)
                            (array.new_fixed $Args 0))
                      (unreachable)))

            (local.set $result/i32 (i32.wrap_i64 (local.get $result64)))
            (ref.i31 (i32.shl (local.get $result/i32) (i32.const 1))))))))

;; flonum-promoted-runtime-helper-names : (listof symbol?)
;;   Name runtime flonum helpers that are available in the standalone core runtime.
(define flonum-promoted-runtime-helper-names
  '($i32->flonum
    $flonum?
    $double-flonum?
    $fx->fl/precise
    $raise-argument-error:flonum-expected
    $fl+
    $fl-
    $fl*
    $unsafe-fl/
    $fl//checked
    $raise-check-flonum
    $fl/
    $flabs
    $flround
    $flfloor
    $flceiling
    $fltruncate
    $flsingle
    $flsin
    $flcos
    $fltan
    $flasin
    $flacos
    $flatan
    $flsinh
    $flcosh
    $fltanh
    $flasinh
    $flacosh
    $flatanh
    $fllog
    $flexp
    $flsqrt
    $unsafe-flabs
    $unsafe-flround
    $unsafe-flfloor
    $unsafe-flceiling
    $unsafe-fltruncate
    $unsafe-flsingle
    $flexpt
    $flmin/2
    $flmax/2
    $unsafe-flmin/2
    $unsafe-flmax/2
    $flmin
    $flmax
    $unsafe-flmin
    $unsafe-flmax
    $fl=
    $fl<
    $fl>
    $fl<=
    $fl>=))

;; flonum-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers in monolithic runtime order.
(define flonum-all-runtime-helpers
  (append
   flonum-constructor-runtime-only-helpers
   flonum-predicate-runtime-only-helpers
   flonum-conversion-runtime-only-helpers
   flonum-arithmetic-runtime-only-helpers
   flonum-math-runtime-only-helpers
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
     (flonum-minmax-runtime-helper name cmp #t))
   flonum-utility-runtime-only-helpers))

;; flonum-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate manually defined flonum helpers that originated in core runtime.
(define flonum-base-core-runtime-helpers
  (list
   ;; fl?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a flonum, 0 otherwise.
   (core-runtime-helper
    '$fl?/i32
    "$fl?/i32"
    (lambda ()
      `(func $fl?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Flonum) (local.get $a)))))))

;; flonum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers available in the standalone core runtime.
(define flonum-core-runtime-helpers
  (append flonum-base-core-runtime-helpers
          (select-runtime-helpers flonum-all-runtime-helpers
                                  flonum-promoted-runtime-helper-names)))

;; flonum-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers that still depend on monolithic runtime globals.
(define flonum-runtime-only-helpers
  (remove-runtime-helpers flonum-all-runtime-helpers
                          flonum-promoted-runtime-helper-names))

;; flonum-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given flonum helper names from the runtime helper index.
(define (flonum-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; flonum-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render the full flonum helper block in runtime assembly order.
(define (flonum-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (append
   (flonum-helper-forms runtime-helper-index flonum-constructor-runtime-only-helper-names)
   (list (core-runtime-helper-form core-runtime-helper-index '$fl?/i32))
   (flonum-helper-forms runtime-helper-index flonum-predicate-runtime-only-helper-names)
   (flonum-helper-forms runtime-helper-index flonum-conversion-runtime-only-helper-names)
   (flonum-helper-forms runtime-helper-index flonum-arithmetic-runtime-only-helper-names)
   (flonum-helper-forms runtime-helper-index flonum-math-runtime-only-helper-names)
   ;; Variadic flonum min/max helpers are built on binary helpers.
   (flonum-helper-forms runtime-helper-index flonum-minmax-runtime-only-helper-names)
   (flonum-helper-forms runtime-helper-index flonum-utility-runtime-only-helper-names)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define flonum-helper-index
    (make-core-runtime-helper-index
     (append flonum-core-runtime-helpers
             flonum-runtime-only-helpers)))

  (define flonum-core-helper-index
    (make-core-runtime-helper-index flonum-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name
        (select-runtime-helpers flonum-core-runtime-helpers
                                flonum-promoted-runtime-helper-names))
   flonum-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (flonum-runtime-helper-forms flonum-helper-index
                                     flonum-core-helper-index))
   (append flonum-constructor-runtime-only-helper-names
           '($fl?/i32)
           flonum-predicate-runtime-only-helper-names
           flonum-conversion-runtime-only-helper-names
           flonum-arithmetic-runtime-only-helper-names
           flonum-math-runtime-only-helper-names
           flonum-minmax-runtime-only-helper-names
           flonum-utility-runtime-only-helper-names)))
