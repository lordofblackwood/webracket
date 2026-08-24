#lang racket/base

;;; Check Random Bignum Multiplication Against Racket CS
;;;
;; Generate deterministic exact integers as 32-bit little-endian limbs, then
;; run the resulting multiplication expressions through the existing number
;; tower oracle. The generator lives on the host; WebRacket only sees exact
;; integer literals and ordinary Racket multiplication expressions.

(require racket/cmdline
         racket/list
         racket/string
         "../test/number-tower/cases.rkt"
         "check-number-tower-cs.rkt")

(provide random-bignum-mul-cases)


;;; Deterministic Limb Generator

;; u32-modulus : exact-positive-integer?
;;   Modulus for the limb generator.
(define u32-modulus #x100000000)

;; next-u32 : exact-nonnegative-integer? -> exact-nonnegative-integer?
;;   Advance a fixed LCG and return one unsigned 32-bit limb.
(define (next-u32 state)
  (modulo (+ (* 1664525 state) 1013904223) u32-modulus))

;; random-magnitude : exact-nonnegative-integer? exact-positive-integer? -> (values exact-positive-integer? exact-nonnegative-integer?)
;;   Construct a nonzero exact integer with exactly limb-count 32-bit limbs.
(define (random-magnitude state limb-count)
  (for/fold ([magnitude 0]
             [next-state state])
            ([i (in-range limb-count)])
    (define limb (next-u32 next-state))
    (define nonzero-top-limb
      (if (= i (sub1 limb-count))
          (bitwise-ior limb 1)
          limb))
    (values (+ magnitude
               (arithmetic-shift nonzero-top-limb (* i 32)))
            limb)))

;; signed-operand : exact-positive-integer? exact-nonnegative-integer? -> exact-integer?
;;   Assign a deterministic sign while retaining a nonzero magnitude.
(define (signed-operand magnitude selector)
  (if (zero? (bitwise-and selector 1))
      magnitude
      (- magnitude)))


;;; Oracle Cases

;; random-bignum-mul-cases : exact-nonnegative-integer? (listof exact-positive-integer?) -> (listof number-tower-case?)
;;   Build balanced, signed, and square multiplication differential cases.
(define (random-bignum-mul-cases seed limb-counts)
  (define-values (cases ignored-state)
    (for/fold ([cases '()]
               [state seed])
              ([limbs (in-list limb-counts)])
      (define-values (x-mag state1) (random-magnitude state limbs))
      (define-values (y-mag state2) (random-magnitude state1 limbs))
      (define x (signed-operand x-mag state2))
      (define y (signed-operand y-mag (next-u32 state2)))
      (define id-prefix (format "random-bignum-~a-limbs" limbs))
      (values
       (append cases
               (list
                (number-tower-case
                 (string->symbol (format "~a-product" id-prefix))
                 'random-bignum-multiplication
                 `(* ,x ,y)
                 'ignore-fixnum-width
                 #t
                 "Seeded dense signed product.")
                (number-tower-case
                 (string->symbol (format "~a-square" id-prefix))
                 'random-bignum-multiplication
                 `(* ,x ,x)
                 'ignore-fixnum-width
                 #t
                 "Seeded dense square.")
                (number-tower-case
                 (string->symbol (format "~a-cross-sign" id-prefix))
                 'random-bignum-multiplication
                 `(* ,(- x) ,y)
                 'ignore-fixnum-width
                 #t
                 "Seeded product with the left sign reversed.")
                (number-tower-case
                 (string->symbol (format "~a-distributive" id-prefix))
                 'random-bignum-multiplication
                 `(- (* ,x (+ ,y 1)) (* ,x ,y))
                 'ignore-fixnum-width
                 #t
                 "Seeded distributive-law product difference.")))
       (next-u32 state2))))
  cases)


;;; Command Line

;; parse-limb-list : string? -> (listof exact-positive-integer?)
;;   Parse comma-separated requested bignum limb widths.
(define (parse-limb-list text)
  (for/list ([part (in-list (string-split text ","))]
             #:unless (string=? (string-trim part) ""))
    (define value (string->number (string-trim part)))
    (unless (exact-positive-integer? value)
      (error 'check-bignum-mul-random-cs
             "expected a positive exact limb count, got ~e"
             part))
    value))

;; main : -> void?
;;   Run seeded bignum multiplication differential tests.
(define (main)
  (define seed #x4d595df4)
  (define limb-counts '(2 3 4 7 15 16 17 31 32 33 47 48 63 64 65 95 96 127 128 129 191 192))
  (define cs-path (default-racket-cs-path))
  (define webracket-racket-path (default-webracket-racket-path))
  (command-line
   #:program "check-bignum-mul-random-cs"
   #:once-each
   [("--seed") value "Exact nonnegative LCG seed"
               (set! seed (string->number value))]
   [("--limbs") counts "Comma-separated balanced limb widths"
                (set! limb-counts (parse-limb-list counts))]
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! webracket-racket-path path)])
  (unless (and (exact-nonnegative-integer? seed)
               (andmap exact-positive-integer? limb-counts))
    (error 'check-bignum-mul-random-cs
           "--seed must be an exact nonnegative integer and --limbs must be positive"))
  (define selected-limbs (sort (remove-duplicates limb-counts) <))
  (define cases (random-bignum-mul-cases seed selected-limbs))
  (printf "seed=~a limb-widths=~s cases=~a\n"
          seed
          selected-limbs
          (length cases))
  (define summary
    (run-number-tower-cases cases
                            #:cs-path cs-path
                            #:webracket-racket-path webracket-racket-path))
  (print-number-tower-summary summary)
  (when (positive? (summary-failure-count summary))
    (exit 1)))

(module+ main
  (main))
