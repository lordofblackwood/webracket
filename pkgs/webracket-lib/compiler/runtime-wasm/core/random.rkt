#lang racket

(provide random-current-global-forms
         random-runtime-string-constants
         random-current-initializer-forms
         random-generator-runtime-only-helper-names
         random-public-runtime-only-helper-names
         random-state-global-forms
         random-runtime-only-helpers)

(require "../core-helper.rkt")

;; random-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by pseudo-random-generator helpers.
(define random-runtime-string-constants
  '((pseudo-random-generator? "pseudo-random-generator?")))

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

;; random-current-global-forms : (listof datum?)
;;   Declare the current pseudo-random generator backing global.
(define random-current-global-forms
  '(
               (global $current-pseudo-random-generator-value (mut (ref eq)) (global.get $false))))

;; random-current-initializer-forms : (listof datum?)
;;   Initialize the current pseudo-random generator backing value.
(define random-current-initializer-forms
  '(
                     (global.set $current-pseudo-random-generator-value
                                 (struct.new $PseudoRandomGenerator
                                             (i32.const 0)
                                             (i32.const 0x9E3779B9)))))

;; random-generator-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for random generator helpers.
(define random-generator-runtime-only-helper-names
  '($random-u32/generator
    $current-random-generator
    $random-u32
    $make-pseudo-random-generator
    $pseudo-random-generator?))

;; random-public-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public random helpers.
(define random-public-runtime-only-helper-names
  '($random-seed
    $random))

;; random-generator-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate random generator helpers that still depend on monolithic runtime globals.
(define random-generator-runtime-only-helpers
  (function-forms->runtime-helpers
   'random-generator-runtime-only-helpers
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

;; random-public-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public random helpers that still depend on monolithic runtime globals.
(define random-public-runtime-only-helpers
  (function-forms->runtime-helpers
   'random-public-runtime-only-helpers
   `(
        ;; random-seed : exact-integer? -> void?
        ;;   Seed the current lightweight generator. The accepted range follows
        ;;   Racket's documented 0 <= k < 2^31 restriction for fixnums.
        (func $random-seed (type $Prim1)
              (param $k-raw (ref eq)) ;; exact integer in [0, 2^31)
              (result       (ref eq))
              (local $k i32)
              (if (i32.eqz (call $fx?/i32 (local.get $k-raw)))
                  (then (call $raise-expected-number (local.get $k-raw))
                        (unreachable)))
              (local.set $k ,(Half `(i31.get_s (ref.cast i31ref (local.get $k-raw)))))
              (if (i32.lt_s (local.get $k) (i32.const 0))
                  (then (call $raise-argument-error/internal (local.get $k-raw))
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
                                 (then (call $raise-expected-number (local.get $a)) (unreachable)))
                             (local.set $k ,(Half `(i31.get_s (ref.cast i31ref (local.get $a)))))
                             (if (i32.le_s (local.get $k) (i32.const 0))
                                 (then (call $raise-argument-error/internal (local.get $a)) (unreachable)))
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
                                 (then (call $raise-expected-number (local.get $a)) (unreachable)))
                             (if (i32.eqz (ref.test (ref $PseudoRandomGenerator) (local.get $b)))
                                 (then
                                  (if (i32.eqz (call $fx?/i32 (local.get $b)))
                                      (then (call $raise-expected-number (local.get $b))
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
                                 (then (call $raise-argument-error/internal (local.get $b)) (unreachable)))
                             (local.set $r (i32.add (local.get $min)
                                                    (i32.rem_u
                                                               (call $random-u32/generator
                                                                     (local.get $gen))
                                                               (local.get $range))))
                             (return (ref.i31 (i32.shl (local.get $r) (i32.const 1))))))))
              (unreachable))


     )))

;; random-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate random helpers that still depend on monolithic runtime globals.
(define random-runtime-only-helpers
  (append random-generator-runtime-only-helpers
          random-public-runtime-only-helpers))
