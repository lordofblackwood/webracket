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
         racket/string
         "../test/number-tower/cases.rkt"
         "check-number-tower-cs.rkt")

(provide random-complex-cases)


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

;; finite-operation-cases : string? any/c string? -> (listof number-tower-case?)
;;   Build cases for finite complex inputs where Racket CS is the compatibility oracle.
(define (finite-operation-cases prefix z note)
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
    (string->symbol (format "~a-atan" prefix))
    `(atan ,z)
    '(complex-ulps 32)
    note)
   (random-complex-case
    (string->symbol (format "~a-log-base" prefix))
    `(log ,z (make-rectangular 2.0 1.0))
    '(complex-ulps 32)
    note)
   (random-complex-case
    (string->symbol (format "~a-expt-half" prefix))
    `(expt ,z 0.5)
    '(complex-ulps 32)
    note)))

;; generated-finite-cases :
;;   symbol? string? generator exact-nonnegative-integer? exact-nonnegative-integer?
;;   -> (values (listof number-tower-case?) exact-nonnegative-integer?)
;;   Generate one finite-input family.
(define (generated-finite-cases tag note generator count state)
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
                                     note))
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
     state1))
  (define-values (subnormal-cases state3)
    (generated-finite-cases
     'subnormal
     "Subnormal finite complex sample."
     subnormal-component
     count
     state2))
  (define-values (nonfinite-samples _state4)
    (nonfinite-cases count state3))
  (append normal-cases
          log-cases
          subnormal-cases
          (signed-zero-cases)
          (reverse nonfinite-samples)))


;;; Command Line

;; main : -> void?
;;   Run seeded randomized complex differential tests.
(define (main)
  (define seed #x6c8e9cf5)
  (define count 3)
  (define cs-path (default-racket-cs-path))
  (define webracket-racket-path (default-webracket-racket-path))
  (command-line
   #:program "check-complex-random-cs"
   #:once-each
   [("--seed") value "Exact nonnegative LCG seed"
               (set! seed (string->number value))]
   [("--count") value "Samples per finite/nonfinite input family"
                (set! count (string->number value))]
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! webracket-racket-path path)])
  (unless (and (exact-nonnegative-integer? seed)
               (exact-nonnegative-integer? count))
    (error 'check-complex-random-cs
           "--seed and --count must be exact nonnegative integers"))
  (define cases (random-complex-cases seed count))
  (printf "seed=~a count=~a cases=~a\n" seed count (length cases))
  (define summary
    (run-number-tower-cases cases
                            #:cs-path cs-path
                            #:webracket-racket-path webracket-racket-path))
  (print-number-tower-summary summary)
  (when (positive? (summary-failure-count summary))
    (exit 1)))

(module+ main
  (main))
