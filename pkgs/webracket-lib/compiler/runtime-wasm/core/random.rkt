#lang racket

(provide random-current-global-forms
         random-current-global-names
         random-runtime-string-constants
         random-current-initializer-forms
         random-core-runtime-helper-forms
         random-core-runtime-helpers
         random-generator-runtime-helper-forms
         random-public-runtime-helper-forms
         random-state-global-forms
         random-state-global-names
         random-runtime-only-helpers)

(require "../core-helper.rkt")

;; random-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by pseudo-random-generator helpers.
(define random-runtime-string-constants
  '((pseudo-random-generator? "pseudo-random-generator?")
    (random:seed-contract "(integer-in 0 (sub1 (expt 2 31)))")
    (random:single-argument-contract "(or/c (integer-in 1 4294967087) pseudo-random-generator?)")
    (random:generator-count-contract "(integer-in 1 4294967087)")
    (random:exact-integer? "exact-integer?")
    (random:second-argument-contract "(or/c exact-integer? pseudo-random-generator?)")
    (random:gt/c-prefix "(>/c ")
    (random:right-paren ")")
    (random:argument-position-1st "\n  argument position: 1st")
    (random:argument-position-2nd "\n  argument position: 2nd")
    (random:other-arguments "\n  other arguments...:\n   ")))

;; Half : datum? -> datum?
;;   Decode a tagged fixnum expression to an i32 payload.
(define (Half x)
  `(i32.shr_s ,x (i32.const 1)))

;; predicate-body : symbol? -> (listof datum?)
;;   Generate a standard WebRacket predicate body for ref-type.
(define (predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; random-state-global-forms : (listof datum?)
;;   Declare shared fallback state for early pseudo-random generation.
(define random-state-global-forms
  '(
        ;; Shared fallback state for early pseudo-random generation.
        ;; Normal random calls use $current-pseudo-random-generator-value after
        ;; entry initialization.
        (global $random-state (mut i32) (i32.const 0x9E3779B9))))

;; random-state-global-names : (listof symbol?)
;;   Enumerate fallback pseudo-random state globals.
(define random-state-global-names
  (for/list ([form (in-list random-state-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'random-state-global-names
                "expected global form, got: ~s"
                form)])))

;; random-current-global-forms : (listof datum?)
;;   Declare the current pseudo-random generator backing global.
(define random-current-global-forms
  '(
               (global $current-pseudo-random-generator-value (mut (ref eq)) (global.get $false))))

;; random-current-global-names : (listof symbol?)
;;   Enumerate current pseudo-random generator globals.
(define random-current-global-names
  (for/list ([form (in-list random-current-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'random-current-global-names
                "expected global form, got: ~s"
                form)])))

;; random-current-initializer-forms : (listof datum?)
;;   Initialize the current pseudo-random generator backing value.
(define random-current-initializer-forms
  '(
                     (global.set $current-pseudo-random-generator-value
                                 (struct.new $PseudoRandomGenerator
                                             (i32.const 0)
                                             (i32.const 0x9E3779B9)))))

;; random-generator-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for random generator helpers.
(define random-generator-helper-names
  '($random-u32/generator
    $current-random-generator
    $random-u32
    $make-pseudo-random-generator
    $pseudo-random-generator?))

;; random-public-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public random helpers.
(define random-public-helper-names
  '($raise-random-seed:contract
    $raise-random:single-argument-contract
    $raise-random:generator-count-contract
    $raise-random:first-exact-integer-contract
    $raise-random:second-argument-contract
    $raise-random:range-contract
    $raise-random:argument-error2
    $random-seed
    $random))

;; random-core-runtime-helper-names : (listof symbol?)
;;   Name random helpers available in the standalone core runtime.
(define random-core-runtime-helper-names
  (append random-generator-helper-names
          random-public-helper-names))

;; random-generator-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only random generator helper emission order.
(define random-generator-runtime-only-helper-names
  (remove* random-core-runtime-helper-names
           random-generator-helper-names
           eq?))

;; random-public-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only public random helper emission order.
(define random-public-runtime-only-helper-names
  (remove* random-core-runtime-helper-names
           random-public-helper-names
           eq?))

;; random-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given random helper names from a helper index.
(define (random-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; random-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render random helpers shared with the standalone core runtime.
(define (random-core-runtime-helper-forms helper-index)
  (random-helper-forms helper-index random-core-runtime-helper-names))

;; random-generator-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render random generator helpers in runtime assembly order.
(define (random-generator-runtime-helper-forms helper-index)
  (random-helper-forms helper-index random-generator-runtime-only-helper-names))

;; random-public-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render public random helpers in runtime assembly order.
(define (random-public-runtime-helper-forms helper-index)
  (random-helper-forms helper-index random-public-runtime-only-helper-names))

;; random-generator-helpers : (listof core-runtime-helper?)
;;   Enumerate random generator helpers.
(define random-generator-helpers
  (function-forms->runtime-helpers
   'random-generator-helpers
   `(
        (func $random-u32/generator
              (param $gen (ref $PseudoRandomGenerator)) ;; pseudo-random-generator?
              (result i32)
              (local $z i32)
              (local.set $z (i32.add (struct.get $PseudoRandomGenerator $state
                                                 (local.get $gen))
                                     (i32.const 0x9E3779B9)))
              (struct.set $PseudoRandomGenerator $state
                          (local.get $gen)
                          (local.get $z))
              (local.set $z (i32.xor (local.get $z)
                                      (i32.shr_u (local.get $z) (i32.const 16))))
              (local.set $z (i32.mul (local.get $z) (i32.const 0x85EBCA6B)))
              (local.set $z (i32.xor (local.get $z)
                                      (i32.shr_u (local.get $z) (i32.const 13))))
              (local.set $z (i32.mul (local.get $z) (i32.const 0xC2B2AE35)))
              (local.set $z (i32.xor (local.get $z)
                                      (i32.shr_u (local.get $z) (i32.const 16))))
              (local.get $z))

        (func $current-random-generator
              (result (ref $PseudoRandomGenerator))
              (if (ref.test (ref $PseudoRandomGenerator)
                            (global.get $current-pseudo-random-generator-value))
                  (then (return
                         (ref.cast (ref $PseudoRandomGenerator)
                                   (global.get $current-pseudo-random-generator-value)))))
              (struct.new $PseudoRandomGenerator
                          (i32.const 0)
                          (global.get $random-state)))

        ;; A simple SplitMix32 generator that produces uniformly distributed
        ;; 32-bit integers. It is fast and sufficient for current bootstrap
        ;; probes, but not yet Racket's documented MRG32k3a algorithm.
        (func $random-u32 (result i32)
              (call $random-u32/generator (call $current-random-generator)))

        ;; make-pseudo-random-generator : -> pseudo-random-generator?
        ;;   Create a lightweight generator seeded from the current generator.
        (func $make-pseudo-random-generator (type $Prim0)
              (result (ref eq))
              (struct.new $PseudoRandomGenerator
                          (i32.const 0)
                          (call $random-u32)))

        ;; pseudo-random-generator? : any/c -> boolean?
        ;;   Recognize WebRacket pseudo-random-generator values.
        (func $pseudo-random-generator? (type $Prim1)
              ,@(predicate-body '$PseudoRandomGenerator))


     )))

;; random-public-helpers : (listof core-runtime-helper?)
;;   Enumerate public random helpers.
(define random-public-helpers
  (function-forms->runtime-helpers
   'random-public-helpers
   `(
        (func $raise-random-seed:contract
              (param $x (ref eq))

              (call $raise-argument-error1
                    (global.get $symbol:random-seed)
                    (global.get $string:random:seed-contract)
                    (local.get $x)))

        (func $raise-random:single-argument-contract
              (param $x (ref eq))

              (call $raise-argument-error1
                    (global.get $symbol:random)
                    (global.get $string:random:single-argument-contract)
                    (local.get $x)))

        (func $raise-random:generator-count-contract
              (param $x (ref eq))

              (call $raise-argument-error1
                    (global.get $symbol:random)
                    (global.get $string:random:generator-count-contract)
                    (local.get $x)))

        (func $raise-random:first-exact-integer-contract
              (param $x (ref eq))

              (call $raise-argument-error1
                    (global.get $symbol:random)
                    (global.get $string:random:exact-integer?)
                    (local.get $x)))

        (func $raise-random:second-argument-contract
              (param $x (ref eq))

              (call $raise-argument-error1
                    (global.get $symbol:random)
                    (global.get $string:random:second-argument-contract)
                    (local.get $x)))

        (func $raise-random:range-contract
              (param $min-raw (ref eq))
              (param $x       (ref eq))
              (local $expected (ref $String))

              (local.set $expected
                         (call $string-append/2
                               (global.get $string:random:gt/c-prefix)
                               (call $string-append/2
                                     (call $format/display (local.get $min-raw))
                                     (global.get $string:random:right-paren))))
              (call $raise-random:argument-error2
                    (local.get $expected)
                    (local.get $x)
                    (global.get $string:random:argument-position-2nd)
                    (local.get $min-raw)))

        (func $raise-random:argument-error2
              (param $expected (ref eq))
              (param $bad      (ref eq))
              (param $position (ref eq))
              (param $other    (ref eq))

              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              (local.set $out
                         (call $make-growable-array (i32.const 9)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (global.get $symbol:random)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out)
                    (local.get $expected))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out)
                    (call $format/error-value->string (local.get $bad)))
              (call $growable-array-add! (local.get $out)
                    (local.get $position))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:random:other-arguments))
              (call $growable-array-add! (local.get $out)
                    (call $format/error-value->string (local.get $other)))
              (local.set $message
                         (call $growable-array-of-strings->string
                               (local.get $out)))
              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks
                                (global.get $missing)))
                    (global.get $true))
              (unreachable))

        ;; random-seed : exact-integer? -> void?
        ;;   Seed the current lightweight generator. The accepted range follows
        ;;   Racket's documented 0 <= k < 2^31 restriction for fixnums.
        (func $random-seed (type $Prim1)
              (param $k-raw (ref eq)) ;; exact integer in [0, 2^31)
              (result       (ref eq))
              (local $k i32)
              (if (i32.eqz (call $fx?/i32 (local.get $k-raw)))
                  (then (call $raise-random-seed:contract (local.get $k-raw))
                        (unreachable)))
              (local.set $k ,(Half `(i31.get_s (ref.cast i31ref (local.get $k-raw)))))
              (if (i32.lt_s (local.get $k) (i32.const 0))
                  (then (call $raise-random-seed:contract (local.get $k-raw))
                        (unreachable)))
              (struct.set $PseudoRandomGenerator $state
                          (call $current-random-generator)
                          (i32.xor (local.get $k) (i32.const 0x9E3779B9)))
              (global.get $void))


        (func $random (type $Prim02) ; two optional arguments
              ;; (random)         -> flonum in (0,1)
              ;; (random k)       -> exact integer in [0,k)
              ;; (random min max) -> exact integer in [min,max)
              ;; (random gen) and (random k gen) are supported.
              (param $a (ref eq))
              (param $b (ref eq))
              (result   (ref eq))

              (local $k     i32)
              (local $min   i32)
              (local $max   i32)
              (local $range i32)
              (local $r     i32)
              (local $gen   (ref $PseudoRandomGenerator))

              (local.set $gen (call $current-random-generator))

              (if (ref.eq (local.get $a) (global.get $missing))
                  (then (local.set $r (call $random-u32/generator (local.get $gen)))
                        (return
                         (struct.new $Flonum
                                     (i32.const 0)
                                     (f64.div
                                      (f64.add (f64.convert_i32_u (local.get $r))
                                               (f64.const 1))
                                      (f64.const 4294967298.0)))))
                  (else
                   (if (ref.eq (local.get $b) (global.get $missing))
                       (then (if (ref.test (ref $PseudoRandomGenerator) (local.get $a))
                                 (then (local.set $gen
                                                  (ref.cast (ref $PseudoRandomGenerator)
                                                            (local.get $a)))
                                       (local.set $r
                                                  (call $random-u32/generator
                                                        (local.get $gen)))
                                       (return
                                        (struct.new $Flonum
                                                    (i32.const 0)
                                                    (f64.div
                                                     (f64.add (f64.convert_i32_u
                                                               (local.get $r))
                                                              (f64.const 1))
                                                     (f64.const 4294967298.0))))))
                             (if (i32.eqz (call $fx?/i32 (local.get $a)))
                                 (then (call $raise-random:single-argument-contract (local.get $a))
                                       (unreachable)))
                             (local.set $k ,(Half `(i31.get_s (ref.cast i31ref (local.get $a)))))
                             (if (i32.le_s (local.get $k) (i32.const 0))
                                 (then (call $raise-random:single-argument-contract (local.get $a))
                                       (unreachable)))
                             (local.set $r (i32.rem_u
                                            (call $random-u32/generator
                                                  (local.get $gen))
                                            (local.get $k)))
                             (return (ref.i31 (i32.shl (local.get $r) (i32.const 1)))))
                       (else (if (ref.test (ref $PseudoRandomGenerator) (local.get $b))
                                 (then (local.set $gen
                                                  (ref.cast (ref $PseudoRandomGenerator)
                                                            (local.get $b)))))
                             (if (i32.eqz (call $fx?/i32 (local.get $a)))
                                 (then (if (ref.test (ref $PseudoRandomGenerator) (local.get $b))
                                           (then (call $raise-random:argument-error2
                                                       (global.get $string:random:generator-count-contract)
                                                       (local.get $a)
                                                       (global.get $string:random:argument-position-1st)
                                                       (local.get $b)))
                                           (else (call $raise-random:argument-error2
                                                       (global.get $string:random:exact-integer?)
                                                       (local.get $a)
                                                       (global.get $string:random:argument-position-1st)
                                                       (local.get $b))))
                                       (unreachable)))
                             (if (i32.eqz (ref.test (ref $PseudoRandomGenerator) (local.get $b)))
                                 (then
                                  (if (i32.eqz (call $fx?/i32 (local.get $b)))
                                      (then (call $raise-random:argument-error2
                                                  (global.get $string:random:second-argument-contract)
                                                  (local.get $b)
                                                  (global.get $string:random:argument-position-2nd)
                                                  (local.get $a))
                                            (unreachable)))))
                             (local.set $min ,(Half `(i31.get_s (ref.cast i31ref (local.get $a)))))
                             (if (ref.test (ref $PseudoRandomGenerator) (local.get $b))
                                 (then (local.set $max (local.get $min))
                                       (local.set $min (i32.const 0)))
                                 (else
                                  (local.set $max ,(Half `(i31.get_s
                                                           (ref.cast i31ref
                                                                     (local.get $b)))))))
                             (local.set $range (i32.sub (local.get $max) (local.get $min)))
                             (if (i32.le_s (local.get $range) (i32.const 0))
                                 (then (if (ref.test (ref $PseudoRandomGenerator) (local.get $b))
                                           (then (call $raise-random:argument-error2
                                                       (global.get $string:random:generator-count-contract)
                                                       (local.get $a)
                                                       (global.get $string:random:argument-position-1st)
                                                       (local.get $b)))
                                           (else (call $raise-random:range-contract
                                                       (local.get $a)
                                                       (local.get $b))))
                                       (unreachable)))
                             (local.set $r (i32.add (local.get $min)
                                                    (i32.rem_u
                                                               (call $random-u32/generator
                                                                     (local.get $gen))
                                                               (local.get $range))))
                             (return (ref.i31 (i32.shl (local.get $r) (i32.const 1))))))))
              (unreachable))


     )))

;; random-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate all random helpers in runtime emission order.
(define random-all-runtime-helpers
  (append random-generator-helpers
          random-public-helpers))

;; random-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate random helpers available in the standalone core runtime.
(define random-core-runtime-helpers
  (select-runtime-helpers random-all-runtime-helpers
                          random-core-runtime-helper-names))

;; random-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate random helpers still owned by the program/runtime module.
(define random-runtime-only-helpers
  (remove-runtime-helpers random-all-runtime-helpers
                          random-core-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define random-helper-index
    (make-core-runtime-helper-index
     (append random-core-runtime-helpers
             random-runtime-only-helpers)))

  (define random-core-helper-index
    (make-core-runtime-helper-index random-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name random-core-runtime-helpers)
   random-core-runtime-helper-names)

  (check-equal?
   (map form-name (random-core-runtime-helper-forms random-core-helper-index))
   random-core-runtime-helper-names)

  (check-equal?
   (map form-name (random-generator-runtime-helper-forms random-helper-index))
   random-generator-runtime-only-helper-names)

  (check-equal?
   (map form-name (random-public-runtime-helper-forms random-helper-index))
   random-public-runtime-only-helper-names))
