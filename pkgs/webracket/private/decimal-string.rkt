#lang racket/base

(provide real->decimal-string)

;; scaled-decimal-integer : rational? exact-nonnegative-integer? -> exact-integer?
;;   Scale, round, and exactify n without requiring exact rationals for flonums.
(define (scaled-decimal-integer n digits)
  (define e (expt 10 digits))
  (cond
    [(exact? n)
     (round (abs (* e n)))]
    [else
     (inexact->exact
      (round
       (abs (* (exact->inexact e) n))))]))

;; real->decimal-string : rational? [exact-nonnegative-integer?] -> string?
;;   Format n with digits after the decimal point.
(define (real->decimal-string n [digits 2])
  (unless (rational? n)
    (raise-argument-error 'real->decimal-string "rational?" n))
  (unless (exact-nonnegative-integer? digits)
    (raise-argument-error 'real->decimal-string
                          "exact-nonnegative-integer?"
                          digits))
  (define e (expt 10 digits))
  (define num (scaled-decimal-integer n digits))
  (define frac
    (cond
      [(zero? digits) ""]
      [else
       (define s (number->string (remainder num e)))
       (if (= (string-length s) digits)
           s
           (string-append (make-string (- digits (string-length s)) #\0)
                          s))]))
  (string-append
   (if (or (negative? n) (equal? n -0.0)) "-" "")
   (number->string (quotient num e))
   "."
   frac))
