#lang racket/base

;;; Check Random Complex Numbers Against Racket CS
;;;
;;; Generate deterministic inexact complex inputs that cover ordinary finite
;;; values, logarithmically distributed magnitudes, subnormals, signed zeros,
;;; and NaN/infinity combinations. The generated expressions are run through
;;; the existing number-tower oracle, so WebRacket is compared against the
;;; selected Racket CS executable with the normal result normalizer.

(require racket/cmdline
         racket/list
         racket/match
         racket/string
         "../test/number-tower/cases.rkt"
         "check-number-tower-cs.rkt")

(provide random-complex-cases)

(define default-chunk-size 150)


;;; Deterministic Flonum Generator

;; u32-modulus : exact-positive-integer?
;;   Modulus for the 32-bit LCG state.
(define u32-modulus #x100000000)

;; next-u32 : exact-nonnegative-integer? -> exact-nonnegative-integer?
;;   Advance a fixed LCG and return one unsigned 32-bit value.
(define (next-u32 state)
  (modulo (+ (* 1664525 state) 1013904223) u32-modulus))

;; u32->unit : exact-nonnegative-integer? -> flonum?
;;   Convert a 32-bit value to a flonum in [0, 1).
(define (u32->unit n)
  (/ (exact->inexact n) (exact->inexact u32-modulus)))

;; signed-value : flonum? exact-integer? -> flonum?
;;   Apply a deterministic sign bit to magnitude.
(define (signed-value magnitude selector)
  (if (zero? (bitwise-and selector 1))
      magnitude
      (- magnitude)))

;; normal-component : exact-nonnegative-integer? -> (values flonum? exact-nonnegative-integer?)
;;   Produce an ordinary finite component near zero but not exactly zero.
(define (normal-component state)
  (define state1 (next-u32 state))
  (define state2 (next-u32 state1))
  (define magnitude (+ 0.125 (* 10.0 (u32->unit state1))))
  (values (signed-value magnitude state2) state2))

;; log-component : exact-nonnegative-integer? -> (values flonum? exact-nonnegative-integer?)
;;   Produce a finite component whose decimal exponent ranges from -300 to 300.
(define (log-component state)
  (define state1 (next-u32 state))
  (define state2 (next-u32 state1))
  (define state3 (next-u32 state2))
  (define exponent (- (modulo state1 601) 300))
  (define magnitude (* (+ 1.0 (u32->unit state2))
                       (expt 10.0 exponent)))
  (values (signed-value magnitude state3) state3))

;; subnormal-component : exact-nonnegative-integer? -> (values flonum? exact-nonnegative-integer?)
;;   Produce a nonzero subnormal component.
(define (subnormal-component state)
  (define state1 (next-u32 state))
  (define state2 (next-u32 state1))
  (define magnitude (* 5e-324 (add1 (modulo state1 1024))))
  (values (signed-value magnitude state2) state2))

;; component-pair : (exact-nonnegative-integer? -> (values flonum? exact-nonnegative-integer?))
;;                  exact-nonnegative-integer?
;;               -> (values flonum? flonum? exact-nonnegative-integer?)
;;   Produce a deterministic real/imaginary pair from one component generator.
(define (component-pair generator state)
  (define-values (real state1) (generator state))
  (define-values (imag state2) (generator state1))
  (values real imag state2))

;; rect-expr : flonum? flonum? -> any/c
;;   Build a source expression for a rectangular complex number.
(define (rect-expr real imag)
  `(make-rectangular ,real ,imag))


;;; Oracle Cases

;; random-complex-case : symbol? any/c any/c string? -> number-tower-case?
;;   Build one randomized complex differential case.
(define (random-complex-case id expr comparison note)
  (number-tower-case id 'random-complex expr comparison #t note))

;; finite-operation-cases :
;;   string? any/c string? [#:include-atan? boolean?]
;;   [#:include-inverse? boolean?] [#:include-atanh? boolean?]
;;   [#:include-pole-sensitive? boolean?]
;;   -> (listof number-tower-case?)
;;   Build cases for finite complex inputs where Racket CS is the compatibility oracle.
(define (finite-operation-cases prefix z note
                                #:include-atan? [include-atan? #t]
                                #:include-inverse? [include-inverse? #t]
                                #:include-atanh? [include-atanh? #t]
                                #:include-pole-sensitive? [include-pole-sensitive? #t])
  (append
   (list
    (random-complex-case
     (string->symbol (format "~a-magnitude" prefix))
     `(magnitude ,z)
     '(flonum-ulps 16)
     note)
    (random-complex-case
     (string->symbol (format "~a-sqrt" prefix))
     `(sqrt ,z)
     '(complex-ulps 32)
     note)
    (random-complex-case
     (string->symbol (format "~a-log" prefix))
     `(log ,z)
     '(complex-ulps 32)
     note)
    (random-complex-case
     (string->symbol (format "~a-mul" prefix))
     `(* ,z (make-rectangular -1.25 0.75))
     '(complex-ulps 64)
     note)
    (random-complex-case
     (string->symbol (format "~a-div" prefix))
     `(/ ,z (make-rectangular 2.0 -0.5))
     '(complex-ulps 64)
     note))
   (if include-inverse?
       (list
        (random-complex-case
         (string->symbol (format "~a-asin" prefix))
         `(asin ,z)
         '(complex-ulps 64)
         note)
        (random-complex-case
         (string->symbol (format "~a-acos" prefix))
         `(acos ,z)
         '(complex-ulps 64)
         note)
        (random-complex-case
         (string->symbol (format "~a-asinh" prefix))
         `(asinh ,z)
         '(complex-ulps 64)
         note)
        (random-complex-case
         (string->symbol (format "~a-acosh" prefix))
         `(acosh ,z)
         '(complex-ulps 64)
         note))
       '())
   (if include-atan?
       (list
        (random-complex-case
         (string->symbol (format "~a-atan" prefix))
         `(atan ,z)
         '(complex-ulps 32)
         note))
       '())
   (if include-atanh?
       (list
        (random-complex-case
         (string->symbol (format "~a-atanh" prefix))
         `(atanh ,z)
         '(complex-ulps 64)
         note))
       '())
   (if include-pole-sensitive?
       (list
        (random-complex-case
         (string->symbol (format "~a-tan" prefix))
         `(tan ,z)
         '(complex-ulps 64)
         note)
        (random-complex-case
         (string->symbol (format "~a-tanh" prefix))
         `(tanh ,z)
         '(complex-ulps 64)
         note))
       '())
   (list
    (random-complex-case
     (string->symbol (format "~a-log-base" prefix))
     `(log ,z (make-rectangular 2.0 1.0))
     '(complex-ulps 128)
     note)
    (random-complex-case
     (string->symbol (format "~a-expt-half" prefix))
     `(expt ,z 0.5)
     '(complex-ulps 32)
     note))))

;; generated-finite-cases :
;;   symbol? string? generator exact-nonnegative-integer? exact-nonnegative-integer?
;;   [#:include-atan? boolean?]
;;   [#:include-inverse? boolean?] [#:include-atanh? boolean?]
;;   [#:include-pole-sensitive? boolean?]
;;   -> (values (listof number-tower-case?) exact-nonnegative-integer?)
;;   Generate one finite-input family.
(define (generated-finite-cases tag note generator count state
                                #:include-atan? [include-atan? #t]
                                #:include-inverse? [include-inverse? #t]
                                #:include-atanh? [include-atanh? #t]
                                #:include-pole-sensitive? [include-pole-sensitive? #t])
  (for/fold ([cases '()]
             [next-state state])
            ([index (in-range count)])
    (define-values (real imag state1)
      (component-pair generator next-state))
    (define prefix (format "random-complex-~a-~a" tag index))
    (values
     (append cases
             (finite-operation-cases prefix
                                     (rect-expr real imag)
                                     note
                                     #:include-atan? include-atan?
                                     #:include-inverse? include-inverse?
                                     #:include-atanh? include-atanh?
                                     #:include-pole-sensitive? include-pole-sensitive?))
     (next-u32 state1))))

;; signed-zero-cases : -> (listof number-tower-case?)
;;   Build branch-cut cases around signed imaginary zero.
(define (signed-zero-cases)
  (define samples '((0.0 0.0)
                    (0.0 -0.0)
                    (-0.0 0.0)
                    (-0.0 -0.0)))
  (for/list ([sample (in-list samples)]
             [index (in-naturals)])
    (define real (car sample))
    (define imag (cadr sample))
    (random-complex-case
     (string->symbol (format "random-complex-signed-zero-~a" index))
     `(list (zero? ,(rect-expr real imag))
            (sqrt (make-rectangular -4.0 ,imag))
            (log (make-rectangular -1.0 ,imag)))
     'complex-ulps
     "Signed-zero complex branch-cut sample.")))

;; inverse-branch-cut-cases : -> (listof number-tower-case?)
;;   Build near-cut samples for inverse complex functions.
(define (inverse-branch-cut-cases)
  (define samples
    `((asin positive-real-upper (asin (make-rectangular 2.0 5e-324)))
      (asin positive-real-lower (asin (make-rectangular 2.0 -5e-324)))
      (acos positive-real-upper (acos (make-rectangular 2.0 5e-324)))
      (acos positive-real-lower (acos (make-rectangular 2.0 -5e-324)))
      (asin negative-real-upper (asin (make-rectangular -2.0 5e-324)))
      (asin negative-real-lower (asin (make-rectangular -2.0 -5e-324)))
      (acos negative-real-upper (acos (make-rectangular -2.0 5e-324)))
      (acos negative-real-lower (acos (make-rectangular -2.0 -5e-324)))
      (acosh negative-real-upper (acosh (make-rectangular -2.0 5e-324)))
      (acosh negative-real-lower (acosh (make-rectangular -2.0 -5e-324)))
      (asinh positive-imaginary-right (asinh (make-rectangular 5e-324 2.0)))
      (asinh positive-imaginary-left (asinh (make-rectangular -5e-324 2.0)))
      (asinh negative-imaginary-right (asinh (make-rectangular 5e-324 -2.0)))
      (asinh negative-imaginary-left (asinh (make-rectangular -5e-324 -2.0)))))
  (for/list ([sample (in-list samples)])
    (match-define (list op cut expr) sample)
    (random-complex-case
     (string->symbol (format "random-complex-~a-~a-branch" op cut))
     expr
     '(complex-ulps 64)
     "Near-branch-cut inverse complex sample.")))

;; near-pole-cases : -> (listof number-tower-case?)
;;   Build samples near the tan and tanh pole lines.
(define (near-pole-cases)
  (define samples
    `((tan left-real-pole
           (tan (make-rectangular
                 (- (/ pi 2) (expt 2 -28))
                 5e-324)))
      (tan right-real-pole
           (tan (make-rectangular
                 (+ (/ pi 2) (expt 2 -28))
                 -5e-324)))
      (tanh lower-imaginary-pole
            (tanh (make-rectangular
                   5e-324
                   (- (/ pi 2) (expt 2 -28)))))
      (tanh upper-imaginary-pole
            (tanh (make-rectangular
                   -5e-324
                   (+ (/ pi 2) (expt 2 -28)))))))
  (for/list ([sample (in-list samples)])
    (match-define (list op pole expr) sample)
    (random-complex-case
     (string->symbol (format "random-complex-~a-~a" op pole))
     expr
     '(complex-ulps 128)
     "Near-pole complex tangent sample.")))

;; exact-zero-arithmetic-cases : -> (listof number-tower-case?)
;;   Build exact-zero and mixed exact/flonum arithmetic samples.
(define (exact-zero-arithmetic-cases)
  (define samples
    `((mul-infinite-left-scalar
       (* 1.0 (make-rectangular +inf.0 -inf.0))
       exact)
      (mul-infinite-right-scalar
       (* (make-rectangular +inf.0 -inf.0) 1.0)
       exact)
      (mul-exact-zero-infinity
       (* 0 +inf.0)
       exact)
      (mul-exact-zero-infinity-exact?
       (exact? (* 0 +inf.0))
       exact)
      (mul-inexact-zero-infinity-nan?
       (nan? (* 0.0 +inf.0))
       exact)
      (div-infinite-real-scalar
       (/ (make-rectangular +inf.0 -inf.0) 1.0)
       exact)
      (div-exact-zero-numerator
       (/ 0 (make-rectangular 1.0 1.0))
       exact)
      (div-exact-zero-numerator-exact?
       (exact? (/ 0 (make-rectangular 1.0 1.0)))
       exact)
      (div-exact-zero-flonum-zero
       (/ 0 0.0)
       exact)
      (div-exact-zero-flonum-nan
       (/ 0 +nan.0)
       exact)
      (mixed-large-subnormal-product
       (let ([m (exact->inexact (/ 1 (expt 2 1074)))])
         (* (expt 2 1075) m))
       exact)
      (mixed-rational-subnormal-product
       (let ([m (exact->inexact (/ 1 (expt 2 1074)))])
         (* (/ (expt 2 1075) 3) m))
       exact)
      (mixed-large-positive-zero-product
       (* (expt 10 400) 0.0)
       exact)
      (mixed-large-negative-zero-product
       (* (- (expt 10 400)) 0.0)
       exact)
      (mixed-large-negative-zero-product-left
       (* 0.0 (- (expt 10 400)))
       exact)
      (mixed-large-divide-by-negative-zero
       (/ (expt 10 400) -0.0)
       exact)
      (mixed-infinity-div-left
       (/ +inf.0 (- (expt 10 400)))
       exact)
      (mixed-large-minus-infinity-add
       (+ (expt 10 400) -inf.0)
       exact)
      (mixed-large-nan-add
       (+ (expt 10 400) +nan.0)
       exact)
      (mixed-large-nan-div
       (/ (expt 10 400) +nan.0)
       exact)
      (mixed-complex-large-subnormal-real
       (let* ([m (exact->inexact (/ 1 (expt 2 1074)))]
              [z (* (make-rectangular (expt 2 1075) 1)
                    (make-rectangular m 1.0))])
         (real-part z))
       exact)
      (div-unit-imaginary
       (/ 1+2i 0+1i)
       exact)))
  (for/list ([sample (in-list samples)])
    (match-define (list name expr comparison) sample)
    (random-complex-case
     (string->symbol (format "random-complex-exact-zero-~a" name))
     expr
     comparison
     "Exact-zero complex arithmetic sample.")))

;; offset-suffix : exact-integer? -> string?
;;   Encode a small signed offset for generated case names.
(define (offset-suffix offset)
  (cond
    [(negative? offset) (format "m~a" (- offset))]
    [(positive? offset) (format "p~a" offset)]
    [else "p0"]))

;; floatable-rounding-order-cases : -> (listof number-tower-case?)
;;   Build deterministic samples where floatable exact operands round first.
(define (floatable-rounding-order-cases)
  (define base (expt 2 53))
  (define base/fl (exact->inexact base))
  (define third/fl (/ 1.0 3.0))
  (define integer-cases
    (for*/list ([offset (in-range -3 6)]
                [sample (in-list
                         `((add-cancel
                            (+ ,(+ base offset) ,(- base/fl)))
                           (add-cancel-reverse
                            (+ ,(- base/fl) ,(+ base offset)))
                           (sub-exact-fl
                            (- ,(+ base offset) ,base/fl))
                           (sub-fl-exact
                            (- ,base/fl ,(+ base offset)))
                           (mul-three
                            (* ,(+ base offset) 3.0))
                           (mul-three-reverse
                            (* 3.0 ,(+ base offset)))
                           (div-three
                            (/ ,(+ base offset) 3.0))
                           (div-fl-exact
                            (/ ,base/fl ,(+ base offset)))
                           (add-third
                            (+ ,(+ base offset) ,third/fl))
                           (mul-third
                            (* ,(+ base offset) ,third/fl))))])
      (match-define (list name expr) sample)
      (random-complex-case
       (string->symbol
        (format "random-complex-floatable-~a-~a"
                name
                (offset-suffix offset)))
       expr
       'exact
       "Floatable exact/inexact rounding-order sample.")))
  (define rational-cases
    `((rational-above-one-add
       (+ (+ 1 (/ 1 (expt 2 54))) -1.0))
      (rational-below-one-add
       (+ (- 1 (/ 1 (expt 2 54))) -1.0))
      (rational-above-one-sub
       (- (+ 1 (/ 1 (expt 2 54))) 1.0))
      (rational-one-minus-above
       (- 1.0 (+ 1 (/ 1 (expt 2 54)))))))
  (append
   integer-cases
   (for/list ([sample (in-list rational-cases)])
     (match-define (list name expr) sample)
     (random-complex-case
      (string->symbol
       (format "random-complex-floatable-~a" name))
      expr
      'exact
      "Floatable exact rational rounding-order sample."))))

;; nonfinite-cases : exact-nonnegative-integer? exact-nonnegative-integer?
;;                -> (values (listof number-tower-case?) exact-nonnegative-integer?)
;;   Build magnitude cases for deterministic NaN/infinity pairs.
(define (nonfinite-cases count state)
  (define choices '(+inf.0 -inf.0 +nan.0 1.0 -2.5))
  (for/fold ([cases '()]
             [next-state state])
            ([index (in-range count)])
    (define state1 (next-u32 next-state))
    (define state2 (next-u32 state1))
    (define real (list-ref choices (modulo state1 (length choices))))
    (define imag (list-ref choices (modulo state2 (length choices))))
    (values
     (cons
      (random-complex-case
       (string->symbol (format "random-complex-nonfinite-magnitude-~a" index))
       `(magnitude ,(rect-expr real imag))
       'flonum-ulps
       "NaN/infinity complex magnitude sample.")
      cases)
     state2)))

;; random-complex-cases : exact-nonnegative-integer? exact-nonnegative-integer?
;;                     -> (listof number-tower-case?)
;;   Build deterministic randomized complex-number oracle cases.
(define (random-complex-cases seed count)
  (define-values (normal-cases state1)
    (generated-finite-cases
     'normal
     "Ordinary finite complex sample."
     normal-component
     count
     seed))
  (define-values (log-cases state2)
    (generated-finite-cases
     'log
     "Log-distributed finite complex sample."
     log-component
     count
     state1
     #:include-atan? #f
     #:include-atanh? #f
     #:include-pole-sensitive? #f))
  (define-values (subnormal-cases state3)
    (generated-finite-cases
     'subnormal
     "Subnormal finite complex sample."
     subnormal-component
     count
     state2
     #:include-atan? #f
     #:include-atanh? #f
     #:include-pole-sensitive? #f))
  (define-values (nonfinite-samples _state4)
    (nonfinite-cases count state3))
  (append normal-cases
          log-cases
          subnormal-cases
          (signed-zero-cases)
          (inverse-branch-cut-cases)
          (near-pole-cases)
          (floatable-rounding-order-cases)
          (exact-zero-arithmetic-cases)
          (reverse nonfinite-samples)))

;; take-up-to : (listof any/c) exact-nonnegative-integer? -> (listof any/c)
;;   Return at most the first n values from xs.
(define (take-up-to xs n)
  (cond
    [(or (zero? n) (null? xs)) '()]
    [else (cons (car xs)
                (take-up-to (cdr xs) (sub1 n)))]))

;; drop-up-to : (listof any/c) exact-nonnegative-integer? -> (listof any/c)
;;   Drop at most the first n values from xs.
(define (drop-up-to xs n)
  (cond
    [(or (zero? n) (null? xs)) xs]
    [else (drop-up-to (cdr xs) (sub1 n))]))

;; list->chunks : (listof any/c) exact-positive-integer? -> (listof (listof any/c))
;;   Split xs into chunks of at most chunk-size values.
(define (list->chunks xs chunk-size)
  (cond
    [(null? xs) '()]
    [else
     (cons (take-up-to xs chunk-size)
           (list->chunks (drop-up-to xs chunk-size) chunk-size))]))

;; run-random-complex-cases :
;;   (listof number-tower-case?) path-string? path-string? exact-positive-integer?
;;   -> boolean?
;;   Run randomized cases in chunks so generated WebRacket programs stay small.
(define (run-random-complex-cases cases cs-path webracket-racket-path chunk-size)
  (define chunks (list->chunks cases chunk-size))
  (for/and ([chunk (in-list chunks)]
            [index (in-naturals 1)])
    (printf "chunk=~a/~a cases=~a\n" index (length chunks) (length chunk))
    (define summary
      (run-number-tower-cases chunk
                              #:cs-path cs-path
                              #:webracket-racket-path webracket-racket-path))
    (print-number-tower-summary summary)
    (zero? (summary-failure-count summary))))


;;; Command Line

;; main : -> void?
;;   Run seeded randomized complex differential tests.
(define (main)
  (define seed #x6c8e9cf5)
  (define count 3)
  (define chunk-size default-chunk-size)
  (define cs-path (default-racket-cs-path))
  (define webracket-racket-path (default-webracket-racket-path))
  (command-line
   #:program "check-complex-random-cs"
   #:once-each
   [("--seed") value "Exact nonnegative LCG seed"
               (set! seed (string->number value))]
   [("--count") value "Samples per finite/nonfinite input family"
                (set! count (string->number value))]
   [("--chunk-size") value "Maximum cases per generated WebRacket program"
                    (set! chunk-size (string->number value))]
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! webracket-racket-path path)])
  (unless (and (exact-nonnegative-integer? seed)
               (exact-nonnegative-integer? count)
               (exact-positive-integer? chunk-size))
    (error 'check-complex-random-cs
           "--seed and --count must be exact nonnegative integers; --chunk-size must be positive"))
  (define cases (random-complex-cases seed count))
  (printf "seed=~a count=~a cases=~a chunk-size=~a\n"
          seed
          count
          (length cases)
          chunk-size)
  (unless (run-random-complex-cases cases cs-path webracket-racket-path chunk-size)
    (exit 1)))

(module+ main
  (main))
