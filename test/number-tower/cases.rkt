#lang racket/base

(require racket/list)

(provide (struct-out number-tower-case)
         number-tower-cases
         number-tower-groups
         select-number-tower-cases)

(struct number-tower-case
  (id group expr comparison gate? note)
  #:transparent)

;; nt-case : symbol? symbol? any/c -> number-tower-case?
;;   Build one CS/WebRacket differential case.
(define (nt-case id group expr
                 #:comparison [comparison 'exact]
                 #:gate? [gate? #f]
                 #:note [note ""])
  (number-tower-case id group expr comparison gate? note))

;; number-tower-cases : (listof number-tower-case?)
;;   Number tower oracle cases, with current known gaps recorded as non-gates.
(define number-tower-cases
  (list
   (nt-case 'oracle-fixnum-add
            'oracle-smoke
            '(+ 1 2)
            #:gate? #t
            #:note "Small exact arithmetic should already agree.")
   (nt-case 'oracle-flonum-add
            'oracle-smoke
            '(+ 1.0 2.5)
            #:gate? #t
            #:note "Small flonum arithmetic should already agree.")
   (nt-case 'fixnum-upper-bound
            'integer-representation
            536870911
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Largest current WebRacket signed 30-bit fixnum.")
   (nt-case 'fixnum-lower-bound
            'integer-representation
            -536870912
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Smallest current WebRacket signed 30-bit fixnum.")
   (nt-case 'above-fixnum-upper-bound
            'integer-representation
            536870912
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "First positive exact integer that needs bignum support.")
   (nt-case 'below-fixnum-lower-bound
            'integer-representation
            -536870913
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "First negative exact integer that needs bignum support.")
   (nt-case 'two-to-32
            'integer-representation
            4294967296
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer around the 32-bit limb boundary.")
   (nt-case 'two-to-53
            'integer-representation
            9007199254740992
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer at the f64 integer precision boundary.")
   (nt-case 'two-to-53-plus-one
            'integer-representation
            9007199254740993
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer just past the f64 integer precision boundary.")
   (nt-case 'two-to-64
            'integer-representation
            18446744073709551616
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer around a two-limb unsigned boundary.")
   (nt-case 'two-to-32-binary-string
            'integer-representation
            '(number->string 4294967296 2)
            #:gate? #t
            #:note "Bignum number->string must support radix 2.")
   (nt-case 'two-to-32-hex-string
            'integer-representation
            '(number->string 4294967296 16)
            #:gate? #t
            #:note "Bignum number->string must support radix 16.")
   (nt-case 'negative-bignum-octal-string
            'integer-representation
            '(number->string -536870913 8)
            #:gate? #t
            #:note "Bignum number->string must support radix 8 and signs.")
   (nt-case 'bignum-eqv-same-value
            'integer-representation
            '(eqv? 9007199254740993 9007199254740993)
            #:gate? #t
            #:note "Bignum eqv? compares canonical limb values.")
   (nt-case 'bignum-eqv-different-value
            'integer-representation
            '(eqv? 9007199254740993 9007199254740992)
            #:gate? #t
            #:note "Bignum eqv? distinguishes neighboring limb values.")
   (nt-case 'bignum-equal-same-value
            'integer-representation
            '(equal? 9007199254740993 9007199254740993)
            #:gate? #t
            #:note "Bignum equal? falls through to value-based eqv?.")
   (nt-case 'natural-predicate-positive-bignum
            'integer-representation
            '(natural? 9007199254740993)
            #:gate? #t
            #:note "natural? accepts exact nonnegative bignums.")
   (nt-case 'natural-predicate-negative-bignum
            'integer-representation
            '(natural? -9007199254740993)
            #:gate? #t
            #:note "natural? rejects negative exact bignums.")
   (nt-case 'exact-nonnegative-integer-predicate-bignum
            'integer-representation
            '(exact-nonnegative-integer? 9007199254740993)
            #:gate? #t
            #:note "exact-nonnegative-integer? accepts exact nonnegative bignums.")
   (nt-case 'two-fourths
            'rational-representation
            2/4
            #:gate? #t
            #:note "Rational literals must canonicalize to 1/2.")
   (nt-case 'exact-decimal-tenth
            'rational-representation
            #e0.1
            #:gate? #t
            #:note "Exact decimal syntax must preserve 1/10.")
   (nt-case 'rational-predicate
            'rational-representation
            '(rational? 1/2)
            #:gate? #t
            #:note "Exact rational values satisfy rational?.")
   (nt-case 'rational-exact-predicate
            'rational-representation
            '(exact? 1/2)
            #:gate? #t
            #:note "Exact rational values satisfy exact?.")
   (nt-case 'rational-noninteger-predicate
            'rational-representation
            '(integer? 1/2)
            #:gate? #t
            #:note "Non-integer exact rationals are not integer?.")
   (nt-case 'rational-eqv-same-value
            'rational-representation
            '(eqv? 2/4 1/2)
            #:gate? #t
            #:note "Canonical rationals compare by numerator and denominator.")
   (nt-case 'rational-binary-string
            'rational-representation
            '(number->string 1/10 2)
            #:gate? #t
            #:note "Rational number->string applies the radix to both parts.")
   (nt-case 'negative-rational-hex-string
            'rational-representation
            '(number->string -1/10 16)
            #:gate? #t
            #:note "Rational number->string preserves signs and radix.")
   (nt-case 'complex-default-string
            'number-string
            '(number->string 1+2i)
            #:gate? #t
            #:note "Complex number->string prints rectangular components.")
   (nt-case 'complex-negative-string
            'number-string
            '(number->string -1-2i)
            #:gate? #t
            #:note "Complex number->string preserves negative imaginary signs.")
   (nt-case 'unit-imaginary-string
            'number-string
            '(number->string +i)
            #:gate? #t
            #:note "Unit imaginary values print with explicit zero real part.")
   (nt-case 'complex-hex-string
            'number-string
            '(number->string 1+10i 16)
            #:gate? #t
            #:note "Complex number->string applies radix to exact integer components.")
   (nt-case 'complex-rational-hex-string
            'number-string
            '(number->string 10+11/12i 16)
            #:gate? #t
            #:note "Complex number->string applies radix to exact rational components.")
   (nt-case 'format-display-bignum
            'number-formatting
            '(format "~a" 4294967296)
            #:gate? #t
            #:note "format ~a uses numeric display formatting for bignums.")
   (nt-case 'format-write-rational
            'number-formatting
            '(format "~s" 1/10)
            #:gate? #t
            #:note "format ~s uses numeric write formatting for rationals.")
   (nt-case 'format-print-complex-rational
            'number-formatting
            '(format "~v" 1/2+1/3i)
            #:gate? #t
            #:note "format ~v uses numeric print formatting for exact complex values.")
   (nt-case 'format-radix-bignum
            'number-formatting
            '(format "~b ~o ~x" 4294967296 4294967296 4294967296)
            #:gate? #t
            #:note "format radix directives use number->string for bignums.")
   (nt-case 'display-bignum
            'number-formatting
            '(let ([out (open-output-string)])
               (display 4294967296 out)
               (get-output-string out))
            #:gate? #t
            #:note "display writes bignums through numeric display formatting.")
   (nt-case 'displayln-rational
            'number-formatting
            '(let ([out (open-output-string)])
               (displayln 1/10 out)
               (get-output-string out))
            #:gate? #t
            #:note "displayln writes rationals and a newline.")
   (nt-case 'fprintf-complex
            'number-formatting
            '(let ([out (open-output-string)])
               (fprintf out "~a|~s|~v" 4294967296 1/10 1/2+1/3i)
               (get-output-string out))
            #:gate? #t
            #:note "fprintf inherits number formatting for display, write, and print modes.")
   (nt-case 'string->number-decimal-bignum
            'string-number
            '(string->number "4294967296")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "string->number parses decimal exact integers beyond the WebRacket fixnum range.")
   (nt-case 'string->number-negative-bignum
            'string-number
            '(string->number "-536870913")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "string->number preserves signs for parsed bignums.")
   (nt-case 'string->number-hex-bignum
            'string-number
            '(string->number "100000000" 16)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "string->number parses exact bignums in explicit radices.")
   (nt-case 'string->number-rational-canonical
            'string-number
            '(string->number "2/4")
            #:gate? #t
            #:note "string->number parses and reduces exact rationals.")
   (nt-case 'string->number-bignum-rational
            'string-number
            '(string->number "4294967296/3")
            #:gate? #t
            #:note "string->number preserves bignum rational components.")
   (nt-case 'string->number-radix-rational
            'string-number
            '(string->number "10/100" 2)
            #:gate? #t
            #:note "string->number applies explicit radix to both rational components.")
   (nt-case 'string->number-hex-prefix-bignum
            'string-number
            '(string->number "#x100000000")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "string->number parses source radix prefixes beyond the WebRacket fixnum range.")
   (nt-case 'string->number-prefix-negative
            'string-number
            '(string->number "#x-10")
            #:gate? #t
            #:note "string->number accepts signs after source radix prefixes.")
   (nt-case 'string->number-prefix-overrides-argument
            'string-number
            '(string->number "#b10" 16)
            #:gate? #t
            #:note "Source radix prefixes override the optional radix argument.")
   (nt-case 'string->number-prefix-rational
            'string-number
            '(string->number "#x1/10")
            #:gate? #t
            #:note "string->number applies source radix prefixes to rational components.")
   (nt-case 'string->number-prefix-only
            'string-number
            '(string->number "#x")
            #:gate? #t
            #:note "Bare radix prefixes parse as #f.")
   (nt-case 'string->number-inexact-prefix
            'string-number
            '(string->number "#i10")
            #:gate? #t
            #:note "Inexact prefixes convert exact integer syntax to flonums.")
   (nt-case 'string->number-exact-decimal-prefix
            'string-number
            '(string->number "#e1.5")
            #:gate? #t
            #:note "Exact prefixes convert decimal syntax to exact rationals.")
   (nt-case 'string->number-exact-leading-dot
            'string-number
            '(string->number "#e.1")
            #:gate? #t
            #:note "Exact decimal parsing handles missing integer parts.")
   (nt-case 'string->number-exact-before-radix
            'string-number
            '(string->number "#e#x10")
            #:gate? #t
            #:note "Exactness prefixes can precede source radix prefixes.")
   (nt-case 'string->number-exact-after-radix
            'string-number
            '(string->number "#x#e10")
            #:gate? #t
            #:note "Exactness prefixes can follow source radix prefixes.")
   (nt-case 'string->number-inexact-radix-rational
            'string-number
            '(string->number "#i#x1/10")
            #:gate? #t
            #:note "Inexact prefixes convert prefixed exact rationals to flonums.")
   (nt-case 'string->number-duplicate-exactness-prefix
            'string-number
            '(string->number "#e#i10")
            #:gate? #t
            #:note "Duplicate exactness prefixes parse as #f.")
   (nt-case 'string->number-duplicate-radix-prefix
            'string-number
            '(string->number "#x#x10")
            #:gate? #t
            #:note "Duplicate radix prefixes parse as #f.")
   (nt-case 'string->number-inexact-negative-zero
            'string-number
            '(string->number "#i-0")
            #:gate? #t
            #:note "Inexact prefixes preserve negative zero for signed exact zero syntax.")
   (nt-case 'string->number-positive-infinity
            'string-number
            '(string->number "+inf.0")
            #:gate? #t
            #:note "string->number parses signed positive infinity syntax.")
   (nt-case 'string->number-negative-infinity
            'string-number
            '(string->number "-inf.0")
            #:gate? #t
            #:note "string->number parses signed negative infinity syntax.")
   (nt-case 'string->number-positive-nan
            'string-number
            '(string->number "+nan.0")
            #:gate? #t
            #:note "string->number parses signed NaN syntax.")
   (nt-case 'string->number-negative-nan
            'string-number
            '(string->number "-nan.0")
            #:gate? #t
            #:note "Negative NaN syntax normalizes to +nan.0.")
   (nt-case 'string->number-exact-infinity
            'string-number
            '(string->number "#e+inf.0")
            #:gate? #t
            #:note "Exact infinity syntax parses as #f.")
   (nt-case 'string->number-radix-infinity
            'string-number
            '(string->number "#x+inf.0")
            #:gate? #t
            #:note "Source radix prefixes do not block infinity syntax.")
   (nt-case 'string->number-unsigned-infinity
            'string-number
            '(string->number "inf.0")
            #:gate? #t
            #:note "Infinity syntax must include an explicit sign.")
   (nt-case 'string->number-rectangular-exact
            'string-number
            '(string->number "1+2i")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "string->number parses rectangular complex syntax.")
   (nt-case 'string->number-rectangular-negative-imag
            'string-number
            '(string->number "1-2i")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "string->number parses negative imaginary components.")
   (nt-case 'string->number-unit-imaginary
            'string-number
            '(string->number "+i")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Signed unit imaginary syntax parses as a complex value.")
   (nt-case 'string->number-negative-unit-imaginary
            'string-number
            '(string->number "-i")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Negative signed unit imaginary syntax parses as a complex value.")
   (nt-case 'string->number-signed-imaginary
            'string-number
            '(string->number "+2i")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Signed pure imaginary coefficients are accepted.")
   (nt-case 'string->number-rational-complex
            'string-number
            '(string->number "1/2+3/4i")
            #:gate? #t
            #:note "Rectangular components reuse exact rational parsing.")
   (nt-case 'string->number-radix-complex
            'string-number
            '(string->number "#x1+ai")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Source radix prefixes apply to rectangular components.")
   (nt-case 'string->number-inexact-complex-prefix
            'string-number
            '(string->number "#i1+2i")
            #:gate? #t
            #:note "Inexact prefixes convert rectangular components to flonums.")
   (nt-case 'string->number-exact-decimal-complex
            'string-number
            '(string->number "#e1.5+2.5i")
            #:gate? #t
            #:note "Exact prefixes convert decimal rectangular components to rationals.")
   (nt-case 'string->number-inexact-imaginary-component
            'string-number
            '(string->number "1+2.5i")
            #:gate? #t
            #:note "An inexact rectangular component makes the complex value inexact.")
   (nt-case 'string->number-infinity-imaginary-component
            'string-number
            '(string->number "1+inf.0i")
            #:gate? #t
            #:note "Rectangular imaginary components can use signed infinity syntax.")
   (nt-case 'string->number-unsigned-imaginary-rejected
            'string-number
            '(string->number "2i")
            #:gate? #t
            #:note "Unsigned pure imaginary coefficients parse as #f.")
   (nt-case 'string->number-polar-complex
            'string-number
            '(string->number "1@2")
            #:gate? #t
            #:note "string->number parses polar complex syntax.")
   (nt-case 'string->number-polar-negative-angle
            'string-number
            '(string->number "1@-2")
            #:gate? #t
            #:note "Polar syntax accepts signed angle components.")
   (nt-case 'string->number-polar-zero-angle
            'string-number
            '(string->number "1@0")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact zero polar angles canonicalize through make-polar.")
   (nt-case 'string->number-polar-radix
            'string-number
            '(string->number "#x10@0")
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Source radix prefixes apply to polar components.")
   (nt-case 'string->number-polar-inexact-prefix
            'string-number
            '(string->number "#i1@0")
            #:gate? #t
            #:note "Inexact prefixes preserve inexact zero-angle polar components.")
   (nt-case 'string->number-polar-exact-decimal
            'string-number
            '(string->number "#e1.5@2.5")
            #:gate? #t
            #:note "Exact prefixes exactify polar results.")
   (nt-case 'string->number-polar-missing-angle
            'string-number
            '(string->number "1@")
            #:gate? #t
            #:note "Missing polar angle components parse as #f.")
   (nt-case 'string->number-polar-multiple-separators
            'string-number
            '(string->number "1@@2")
            #:gate? #t
            #:note "Multiple polar separators parse as #f.")
   (nt-case 'string->number-polar-complex-magnitude-rejected
            'string-number
            '(string->number "1+2i@3")
            #:gate? #t
            #:note "Polar magnitude and angle components must be real.")
   (nt-case 'string->number-decimal-mode-exact
            'string-number
            '(string->number "1.5" 10 'number-or-false 'decimal-as-exact)
            #:gate? #t
            #:note "decimal-as-exact converts decimal tokens to exact rationals.")
   (nt-case 'string->number-decimal-mode-inexact
            'string-number
            '(string->number "1.5" 10 'number-or-false 'decimal-as-inexact)
            #:gate? #t
            #:note "decimal-as-inexact keeps decimal tokens as flonums.")
   (nt-case 'string->number-read-convert-mode
            'string-number
            '(string->number "1.5" 10 'read 'decimal-as-exact 'double)
            #:gate? #t
            #:note "The read convert mode accepts the documented decimal mode.")
   (nt-case 'string->number-single-flonum-mode
            'string-number
            '(string->number "1.5" 10 'number-or-false 'decimal-as-inexact 'single)
            #:gate? #t
            #:note "The single-flonum mode is accepted, but WebRacket has only double flonums.")
   (nt-case 'string->number-decimal-mode-prefix-override
            'string-number
            '(string->number "#i1.5" 10 'number-or-false 'decimal-as-exact)
            #:gate? #t
            #:note "Explicit #i exactness overrides decimal-as-exact mode.")
   (nt-case 'string->number-decimal-mode-rectangular
            'string-number
            '(string->number "1+2.5i" 10 'number-or-false 'decimal-as-exact)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "decimal-as-exact applies to rectangular decimal components.")
   (nt-case 'string->number-decimal-mode-polar
            'string-number
            '(string->number "1@2.5" 10 'number-or-false 'decimal-as-exact)
            #:gate? #t
            #:note "decimal-as-exact applies to polar components without exactifying the polar result.")
   (nt-case 'string->number-zero-denominator
            'string-number
            '(string->number "1/0")
            #:gate? #t
            #:note "string->number returns #f for rational syntax with zero denominator.")
   (nt-case 'rational-add
            'rational-arithmetic
            '(+ 1/3 1/6)
            #:gate? #t
            #:note "Exact rational addition must normalize.")
   (nt-case 'rational-subtract
            'rational-arithmetic
            '(- 1/2 2/3)
            #:gate? #t
            #:note "Exact rational subtraction must normalize signs.")
   (nt-case 'rational-multiply
            'rational-arithmetic
            '(* 2/3 9/4)
            #:gate? #t
            #:note "Exact rational multiplication must normalize.")
   (nt-case 'integer-division-rational
            'rational-arithmetic
            '(/ 1 2)
            #:gate? #t
            #:note "Exact integer / can produce a rational.")
   (nt-case 'rational-divide
            'rational-arithmetic
            '(/ 3/4 9/10)
            #:gate? #t
            #:note "Exact rational division must normalize.")
   (nt-case 'bignum-rational-divide
            'rational-arithmetic
            '(/ 9007199254740993 2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact division can preserve a bignum numerator.")
   (nt-case 'rational-equal-comparison
            'rational-arithmetic
            '(= 2/4 1/2)
            #:gate? #t
            #:note "Exact rational equality compares normalized value.")
   (nt-case 'rational-less-than
            'rational-arithmetic
            '(< 1/3 1/2)
            #:gate? #t
            #:note "Exact rational ordering compares by value.")
   (nt-case 'rational-greater-than-negative
            'rational-arithmetic
            '(> -1/3 -1/2)
            #:gate? #t
            #:note "Exact rational ordering handles negative values.")
   (nt-case 'rational-zero-predicate
            'rational-arithmetic
            '(zero? 1/2)
            #:gate? #t
            #:note "Canonical non-integer rationals are nonzero.")
   (nt-case 'rational-positive-predicate
            'rational-arithmetic
            '(positive? 1/2)
            #:gate? #t
            #:note "Rational positivity follows the numerator sign.")
   (nt-case 'rational-negative-predicate
            'rational-arithmetic
            '(negative? -1/2)
            #:gate? #t
            #:note "Rational negativity follows the numerator sign.")
   (nt-case 'inexact->exact-rational-identity
            'rational-conversion
            '(inexact->exact 1/2)
            #:gate? #t
            #:note "inexact->exact returns exact rationals unchanged.")
   (nt-case 'inexact->exact-bignum-identity
            'rational-conversion
            '(inexact->exact 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "inexact->exact returns exact bignums unchanged.")
   (nt-case 'inexact->exact-finite-flonum
            'rational-conversion
            '(inexact->exact 1.5)
            #:gate? #t
            #:note "Finite non-integral flonums convert to exact rationals.")
   (nt-case 'inexact->exact-binary-flonum
            'rational-conversion
            '(inexact->exact 2.3)
            #:gate? #t
            #:note "Finite flonums convert to their exact binary rational value.")
   (nt-case 'exact->inexact-rational
            'rational-conversion
            '(exact->inexact 1/2)
            #:gate? #t
            #:note "exact->inexact converts exact rationals to flonums.")
   (nt-case 'exact->inexact-bignum
            'rational-conversion
            '(exact->inexact 9007199254740993)
            #:gate? #t
            #:note "exact->inexact converts bignums using f64 rounding.")
   (nt-case 'exact->inexact-rational-double-round
            'rational-conversion
            '(exact->inexact 2106270354592/12789239550964971)
            #:gate? #t
            #:note "exact->inexact rounds exact rationals directly, avoiding numerator/denominator double rounding.")
   (nt-case 'exact->inexact-negative-rational-underflow
            'rational-conversion
            '(exact->inexact (/ -1 (expt 2 1075)))
            #:gate? #t
            #:note "Tiny negative exact rationals underflow to -0.0.")
   (nt-case 'real->double-flonum-rational
            'rational-conversion
            '(real->double-flonum 1/2)
            #:gate? #t
            #:note "real->double-flonum accepts exact rationals.")
   (nt-case 'real->double-flonum-bignum
            'rational-conversion
            '(real->double-flonum 9007199254740993)
            #:gate? #t
            #:note "real->double-flonum accepts exact bignums.")
   (nt-case 'real->double-flonum-rational-double-round
            'rational-conversion
            '(real->double-flonum 2106270354592/12789239550964971)
            #:gate? #t
            #:note "real->double-flonum uses direct exact rational rounding.")
   (nt-case 'numerator-integer
            'rational-components
            '(numerator 5)
            #:gate? #t
            #:note "The numerator of an exact integer is the integer itself.")
   (nt-case 'denominator-integer
            'rational-components
            '(denominator 5)
            #:gate? #t
            #:note "The denominator of an exact integer is 1.")
   (nt-case 'numerator-rational
            'rational-components
            '(numerator 34/8)
            #:gate? #t
            #:note "Rational numerator uses the canonical reduced form.")
   (nt-case 'denominator-rational
            'rational-components
            '(denominator 34/8)
            #:gate? #t
            #:note "Rational denominator uses the canonical reduced form.")
   (nt-case 'numerator-bignum-rational
            'rational-components
            '(numerator 9007199254740993/2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Numerators can be exact bignums.")
   (nt-case 'denominator-bignum-rational
            'rational-components
            '(denominator 9007199254740993/2)
            #:gate? #t
            #:note "Denominators remain exact positive integers.")
   (nt-case 'numerator-flonum
            'rational-components
            '(numerator 2.3)
            #:gate? #t
            #:note "Inexact rational numerator is coerced back to inexact.")
   (nt-case 'denominator-flonum
            'rational-components
            '(denominator 2.3)
            #:gate? #t
            #:note "Inexact rational denominator is coerced back to inexact.")
   (nt-case 'numerator-negative-zero
            'rational-components
            '(numerator -0.0)
            #:gate? #t
            #:note "Inexact negative zero preserves its sign in numerator.")
   (nt-case 'denominator-negative-zero
            'rational-components
            '(denominator -0.0)
            #:gate? #t
            #:note "Inexact negative zero has inexact denominator 1.0.")
   (nt-case 'gcd-rationals
            'rational-gcd-lcm
            '(gcd 1/2 1/3)
            #:gate? #t
            #:note "Rational gcd uses numerator gcd over denominator lcm.")
   (nt-case 'lcm-rationals
            'rational-gcd-lcm
            '(lcm 1/2 1/3)
            #:gate? #t
            #:note "Rational lcm uses numerator lcm over denominator gcd.")
   (nt-case 'gcd-negative-rational
            'rational-gcd-lcm
            '(gcd -1/2 1/3)
            #:gate? #t
            #:note "Rational gcd is nonnegative.")
   (nt-case 'lcm-negative-rational
            'rational-gcd-lcm
            '(lcm -1/2 1/3)
            #:gate? #t
            #:note "Rational lcm is nonnegative.")
   (nt-case 'gcd-rational-zero
            'rational-gcd-lcm
            '(gcd 1/2 0)
            #:gate? #t
            #:note "Rational gcd handles exact zero arguments.")
   (nt-case 'lcm-rational-zero
            'rational-gcd-lcm
            '(lcm 1/2 0)
            #:gate? #t
            #:note "Rational lcm returns zero if any argument is zero.")
   (nt-case 'gcd-inexact-rational
            'rational-gcd-lcm
            '(gcd 12 81.0)
            #:gate? #t
            #:note "Inexact rational inputs coerce the gcd result to inexact.")
   (nt-case 'lcm-inexact-rational
            'rational-gcd-lcm
            '(lcm 12 81.0)
            #:gate? #t
            #:note "Inexact rational inputs coerce the lcm result to inexact.")
   (nt-case 'gcd-binary-flonum-rational
            'rational-gcd-lcm
            '(gcd 0.1 1/5)
            #:gate? #t
            #:note "Inexact rational gcd uses exact binary flonum values.")
   (nt-case 'lcm-unary-rational
            'rational-gcd-lcm
            '(lcm 1/2)
            #:gate? #t
            #:note "Unary rational lcm returns the absolute argument.")
   (nt-case 'lcm-rational-with-one
            'rational-gcd-lcm
            '(lcm 1 1/2)
            #:gate? #t
            #:note "Binary rational lcm with 1 follows the pair formula.")
   (nt-case 'lcm-bignum-rational
            'rational-gcd-lcm
            '(lcm 9007199254740993/2 3/2)
            #:gate? #t
            #:note "Rational lcm can preserve a bignum numerator.")
   (nt-case 'rational-sqr
            'rational-unary
            '(sqr 1/2)
            #:gate? #t
            #:note "sqr accepts exact rationals and preserves exactness.")
   (nt-case 'rational-abs
            'rational-unary
            '(abs -1/2)
            #:gate? #t
            #:note "abs accepts exact rationals and returns a nonnegative exact rational.")
   (nt-case 'rational-sgn-positive
            'rational-unary
            '(sgn 1/2)
            #:gate? #t
            #:note "sgn accepts positive exact rationals.")
   (nt-case 'rational-sgn-negative
            'rational-unary
            '(sgn -1/2)
            #:gate? #t
            #:note "sgn accepts negative exact rationals.")
   (nt-case 'bignum-sgn-negative
            'rational-unary
            '(sgn -9007199254740993)
            #:gate? #t
            #:note "sgn accepts bignum exact integers.")
   (nt-case 'floor-positive-rational
            'rational-rounding
            '(floor 3/2)
            #:gate? #t
            #:note "floor rounds exact rationals toward negative infinity.")
   (nt-case 'floor-negative-rational
            'rational-rounding
            '(floor -3/2)
            #:gate? #t
            #:note "floor adjusts negative non-integer rationals below truncate.")
   (nt-case 'ceiling-positive-rational
            'rational-rounding
            '(ceiling 3/2)
            #:gate? #t
            #:note "ceiling adjusts positive non-integer rationals above truncate.")
   (nt-case 'ceiling-negative-rational
            'rational-rounding
            '(ceiling -3/2)
            #:gate? #t
            #:note "ceiling rounds negative exact rationals toward positive infinity.")
   (nt-case 'truncate-negative-rational
            'rational-rounding
            '(truncate -3/2)
            #:gate? #t
            #:note "truncate rounds exact rationals toward zero.")
   (nt-case 'round-half-even-zero
            'rational-rounding
            '(round 1/2)
            #:gate? #t
            #:note "round uses ties-to-even for exact rationals.")
   (nt-case 'round-half-even-two
            'rational-rounding
            '(round 3/2)
            #:gate? #t
            #:note "round ties 3/2 to the even integer 2.")
   (nt-case 'round-negative-half-even
            'rational-rounding
            '(round -3/2)
            #:gate? #t
            #:note "round ties negative exact rationals to even integers.")
   (nt-case 'exact-floor-bignum-rational
            'rational-rounding
            '(exact-floor 9007199254740993/2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "exact-floor can return a bignum-sized exact integer.")
   (nt-case 'exact-ceiling-negative-bignum-rational
            'rational-rounding
            '(exact-ceiling -9007199254740993/2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "exact-ceiling can return a negative bignum-sized exact integer.")
   (nt-case 'exact-round-bignum-identity
            'rational-rounding
            '(exact-round 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "exact-round accepts bignum exact integer inputs.")
   (nt-case 'rectangular-literal
            'complex-basic
            1+2i
            #:gate? #t
            #:note "Rectangular complex literal with exact components.")
   (nt-case 'rectangular-rational-literal-exact
            'complex-basic
            '(let ([z 1/2+1/3i])
               (and (exact? z)
                    (equal? (real-part z) 1/2)
                    (equal? (imag-part z) 1/3)))
            #:gate? #t
            #:note "Exact complex literals preserve rational components.")
   (nt-case 'quoted-complex-literal-exact
            'complex-basic
            '(let ([z (vector-ref '#(1/2+1/3i) 0)])
               (and (exact? z)
                    (equal? (real-part z) 1/2)
                    (equal? (imag-part z) 1/3)))
            #:gate? #t
            #:note "Quoted exact complex values preserve rational components.")
   (nt-case 'unit-imaginary
            'complex-basic
            +i
            #:gate? #t
            #:note "Abbreviated imaginary literal.")
   (nt-case 'polar-zero-angle
            'complex-basic
            2@0
            #:gate? #t
            #:note "Polar syntax that collapses to an exact real in CS.")
   (nt-case 'make-rectangular-exact-zero
            'complex-basic
            '(make-rectangular 1 0)
            #:gate? #t
            #:note "Exact zero imaginary component collapses to a real.")
   (nt-case 'make-rectangular-inexact-positive-zero
            'complex-basic
            '(make-rectangular 1 0.0)
            #:gate? #t
            #:note "CS preserves the inexact zero imaginary component.")
   (nt-case 'make-rectangular-inexact-negative-zero
            'complex-basic
            '(make-rectangular 1 -0.0)
            #:gate? #t
            #:note "CS preserves the negative zero imaginary component.")
   (nt-case 'real-part-complex
            'complex-basic
            '(real-part 1+2i)
            #:gate? #t
            #:note "real-part extracts the rectangular real component.")
   (nt-case 'imag-part-real-inexact
            'complex-basic
            '(imag-part 1.0)
            #:gate? #t
            #:note "imag-part of a real number is exact zero.")
   (nt-case 'make-polar-exact-zero-magnitude
            'complex-basic
            '(make-polar 0 1.0)
            #:gate? #t
            #:note "Exact zero magnitude collapses to exact zero.")
   (nt-case 'magnitude-exact-3-4-5
            'complex-basic
            '(magnitude 3+4i)
            #:gate? #t
            #:note "Exact complex magnitude stays exact when the root is exact.")
   (nt-case 'angle-positive-inexact-real
            'complex-basic
            '(angle 1.0)
            #:gate? #t
            #:note "Positive inexact real angle is exact zero.")
   (nt-case 'conjugate-inexact-positive-zero
            'complex-basic
            '(conjugate (make-rectangular 1 0.0))
            #:gate? #t
            #:note "Conjugate flips the sign of an inexact zero imaginary part.")
   (nt-case 'complex-add-exact
            'complex-basic
            '(+ 1+2i 3+4i)
            #:gate? #t
            #:note "Complex addition combines rectangular components.")
   (nt-case 'complex-sub-unary-exact
            'complex-basic
            '(- 1+2i)
            #:gate? #t
            #:note "Unary negation works for complex values.")
   (nt-case 'complex-mul-exact
            'complex-basic
            '(* 1+2i 3+4i)
            #:gate? #t
            #:note "Complex multiplication uses the rectangular formula.")
   (nt-case 'complex-div-exact
            'complex-basic
            '(/ 1+2i 3+4i)
            #:gate? #t
            #:note "Exact complex division keeps rational components.")
   (nt-case 'complex-div-inexact-underflow-scaled
            'complex-basic
            '(/ (make-rectangular 1e-308 1e-308)
                (make-rectangular 1e-308 -1e-308))
            #:gate? #t
            #:note "Inexact complex division avoids denominator underflow.")
   (nt-case 'complex-div-inexact-zero
            'complex-basic
            '(/ 1 (make-rectangular 0.0 0.0))
            #:gate? #t
            #:note "Inexact zero complex divisors produce NaN components.")
   (nt-case 'complex-equal-same
            'complex-basic
            '(= 1+2i 1+2i)
            #:gate? #t
            #:note "Numeric equality compares complex components.")
   (nt-case 'complex-equal-different-imag
            'complex-basic
            '(= 1+2i 1+3i)
            #:gate? #t
            #:note "Numeric equality rejects different imaginary components.")
   (nt-case 'complex-eqv-same
            'complex-basic
            '(eqv? 1+2i (make-rectangular 1 2))
            #:gate? #t
            #:note "eqv? compares exact complex components.")
   (nt-case 'complex-equal-predicate-same
            'complex-basic
            '(equal? 1+2i (make-rectangular 1 2))
            #:gate? #t
            #:note "equal? falls through to component-wise complex equality.")
   (nt-case 'complex-equal-hash-consistent
            'complex-basic
            '(= (equal-hash-code 1+2i)
                (equal-hash-code (make-rectangular 1 2)))
            #:gate? #t
            #:note "equal-hash-code is stable across equal complex values.")
   (nt-case 'complex-eqv-hash-consistent
            'complex-basic
            '(= (eqv-hash-code 1+2i)
                (eqv-hash-code (make-rectangular 1 2)))
            #:gate? #t
            #:note "eqv-hash-code is stable across eqv complex values.")
   (nt-case 'sqrt-negative-perfect-square
            'complex-root
            '(sqrt -4)
            #:gate? #t
            #:note "Negative exact square roots become exact imaginary values.")
   (nt-case 'sqrt-negative-non-square
            'complex-root
            '(sqrt -2)
            #:gate? #t
            #:note "Negative non-square exact roots become inexact complex values.")
   (nt-case 'sqrt-negative-rational-perfect-square
            'complex-root
            '(sqrt -1/4)
            #:gate? #t
            #:note "Negative exact rational perfect squares preserve exactness.")
   (nt-case 'sqrt-negative-flonum
            'complex-root
            '(sqrt -4.0)
            #:gate? #t
            #:note "Negative flonum roots produce inexact complex values.")
   (nt-case 'sqrt-complex-exact-3-4
            'complex-root
            '(sqrt 3+4i)
            #:gate? #t
            #:note "Complex square roots can remain exact.")
   (nt-case 'sqrt-complex-negative-zero-imag
            'complex-root
            '(sqrt (make-rectangular -1 -0.0))
            #:gate? #t
            #:note "Complex sqrt follows the imaginary signed-zero branch.")
   (nt-case 'sqrt-complex-positive-real-negative-zero-imag
            'complex-root
            '(sqrt (make-rectangular 4 -0.0))
            #:gate? #t
            #:note "Complex sqrt preserves negative zero imaginary components.")
   (nt-case 'complex-exp-unit-imaginary
            'complex-transcendental
            '(exp +i)
            #:gate? #t
            #:note "Complex exp composes real exp with sin/cos.")
   (nt-case 'complex-exp-rectangular
            'complex-transcendental
            '(exp 1+2i)
            #:gate? #t
            #:note "Complex exp handles nonzero real and imaginary components.")
   (nt-case 'complex-exp-inexact-zero-imaginary
            'complex-transcendental
            '(exp (make-rectangular 0 0.0))
            #:gate? #t
            #:note "Complex exp preserves inexact zero imaginary inputs.")
   (nt-case 'log-negative-exact
            'complex-transcendental
            '(log -1)
            #:gate? #t
            #:note "Natural log of a negative exact real enters the complex plane.")
   (nt-case 'log-negative-flonum
            'complex-transcendental
            '(log -1.0)
            #:gate? #t
            #:note "Natural log of a negative flonum enters the complex plane.")
   (nt-case 'complex-log-rectangular
            'complex-transcendental
            '(log 3+4i)
            #:gate? #t
            #:note "Complex natural log uses magnitude and angle.")
   (nt-case 'complex-log-inexact-zero
            'complex-transcendental
            '(log (make-rectangular 0.0 0.0))
            #:gate? #t
            #:note "Complex log of inexact zero keeps the complex result shape.")
   (nt-case 'complex-sin-shape
            'complex-transcendental
            '(let ([z (sin 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex sin uses the rectangular formula.")
   (nt-case 'complex-sin-value
            'complex-transcendental
            '(sin 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex sin value matches CS within a small ULP budget.")
   (nt-case 'complex-cos-shape
            'complex-transcendental
            '(let ([z (cos 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex cos uses the rectangular formula.")
   (nt-case 'complex-cos-value
            'complex-transcendental
            '(cos 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex cos value matches CS within a small ULP budget.")
   (nt-case 'complex-tan-shape
            'complex-transcendental
            '(let ([z (tan +i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex tan uses sin/cos division.")
   (nt-case 'complex-tan-value
            'complex-transcendental
            '(tan +i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex tan value matches CS within a small ULP budget.")
   (nt-case 'complex-sinh-shape
            'complex-transcendental
            '(let ([z (sinh 1+i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex sinh uses the rectangular formula.")
   (nt-case 'complex-sinh-value
            'complex-transcendental
            '(sinh 1+i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex sinh value matches CS within a small ULP budget.")
   (nt-case 'complex-cosh-shape
            'complex-transcendental
            '(let ([z (cosh 1+i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex cosh uses the rectangular formula.")
   (nt-case 'complex-cosh-value
            'complex-transcendental
            '(cosh 1+i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex cosh value matches CS within a small ULP budget.")
   (nt-case 'complex-tanh-shape
            'complex-transcendental
            '(let ([z (tanh 1+i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex tanh uses sinh/cosh division.")
   (nt-case 'complex-tanh-value
            'complex-transcendental
            '(tanh 1+i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex tanh value matches CS within a small ULP budget.")
   (nt-case 'complex-asin-shape
            'complex-transcendental
            '(let ([z (asin 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex asin uses the logarithmic branch formula.")
   (nt-case 'complex-asin-value
            'complex-transcendental
            '(asin 1+2i)
            #:comparison '(complex-ulps 12)
            #:gate? #t
            #:note "Complex asin value matches CS within its operation-specific ULP budget.")
   (nt-case 'complex-acos-shape
            'complex-transcendental
            '(let ([z (acos 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex acos uses pi/2 minus complex asin.")
   (nt-case 'complex-acos-value
            'complex-transcendental
            '(acos 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex acos value matches CS within a small ULP budget.")
   (nt-case 'complex-atan-shape
            'complex-transcendental
            '(let ([z (atan 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Unary complex atan uses the logarithmic branch formula.")
   (nt-case 'complex-atan-value
            'complex-transcendental
            '(atan 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex atan value matches CS within a small ULP budget.")
   (nt-case 'complex-asinh-shape
            'complex-transcendental
            '(let ([z (asinh 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex asinh uses the logarithmic branch formula.")
   (nt-case 'complex-asinh-value
            'complex-transcendental
            '(asinh 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex asinh value matches CS within a small ULP budget.")
   (nt-case 'complex-acosh-shape
            'complex-transcendental
            '(let ([z (acosh 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex acosh uses the documented logarithmic formula.")
   (nt-case 'complex-acosh-value
            'complex-transcendental
            '(acosh 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex acosh value matches CS within a small ULP budget.")
   (nt-case 'complex-atanh-shape
            'complex-transcendental
            '(let ([z (atanh 1+2i)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Complex atanh uses the logarithmic branch formula.")
   (nt-case 'complex-atanh-value
            'complex-transcendental
            '(atanh 1+2i)
            #:comparison '(complex-ulps 4)
            #:gate? #t
            #:note "Complex atanh value matches CS within a small ULP budget.")
   (nt-case 'asin-real-out-of-domain-exact
            'complex-transcendental
            '(let ([z (asin 2)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "asin exits the real line for exact values above 1.")
   (nt-case 'acos-real-out-of-domain-exact
            'complex-transcendental
            '(let ([z (acos 2)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "acos exits the real line for exact values above 1.")
   (nt-case 'asin-real-out-of-domain-flonum
            'complex-transcendental
            '(let ([z (asin -2.0)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "asin exits the real line for inexact values below -1.")
   (nt-case 'acosh-exact-below-one
            'complex-transcendental
            '(let ([z (acosh 0)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Exact acosh below 1 enters the complex plane.")
   (nt-case 'acosh-flonum-below-one
            'complex-transcendental
            '(string=? (number->string (acosh 0.0)) "+nan.0")
            #:gate? #t
            #:note "Flonum acosh below 1 follows the flonum helper and returns NaN.")
   (nt-case 'atanh-real-out-of-domain
            'complex-transcendental
            '(string=? (number->string (atanh 2)) "+nan.0")
            #:gate? #t
            #:note "Real atanh outside [-1,1] follows the flonum helper and returns NaN.")
   (nt-case 'complex-expt-exact-integer
            'complex-expt
            '(expt 1+2i 2)
            #:gate? #t
            #:note "Exact integer complex exponents preserve exactness.")
   (nt-case 'complex-expt-negative-integer
            'complex-expt
            '(expt 1+2i -1)
            #:gate? #t
            #:note "Negative exact integer complex exponents preserve exact rationals.")
   (nt-case 'complex-expt-negative-half
            'complex-expt
            '(expt -4 1/2)
            #:gate? #t
            #:note "Exact half exponents route through complex-aware sqrt.")
   (nt-case 'complex-expt-complex-half
            'complex-expt
            '(expt 3+4i 1/2)
            #:gate? #t
            #:note "Complex half exponents can remain exact.")
   (nt-case 'complex-expt-real-exponent
            'complex-expt
            '(let ([z (expt 1+2i 3.0)])
               (and (number? z) (complex? z) (not (real? z)) (inexact? z)))
            #:gate? #t
            #:note "Non-integer complex exponentiation uses exp/log composition; ULP comparison is not available yet.")
   (nt-case 'complex-expt-complex-exponent
            'complex-expt
            '(expt 2 1+i)
            #:gate? #t
            #:note "Complex exponents on real bases use exp/log composition.")
   (nt-case 'fasl-bignum-roundtrip
            'numeric-fasl
            '(let ([x (expt 2 40)])
               (equal? (fasl->s-exp (s-exp->fasl x)) x))
            #:gate? #t
            #:note "FASL preserves exact bignums.")
   (nt-case 'fasl-rational-roundtrip
            'numeric-fasl
            '(let ([x (/ (expt 2 40) 3)])
               (equal? (fasl->s-exp (s-exp->fasl x)) x))
            #:gate? #t
            #:note "FASL preserves exact rational components.")
   (nt-case 'fasl-complex-roundtrip
            'numeric-fasl
            '(let ([z (make-rectangular (/ (expt 2 40) 3) 5/7)])
               (equal? (fasl->s-exp (s-exp->fasl z)) z))
            #:gate? #t
            #:note "FASL preserves exact complex components.")
   (nt-case 'fasl-numeric-vector-roundtrip
            'numeric-fasl
            '(let ([v (vector (expt 2 40) 2/3 1+2i)])
               (equal? (fasl->s-exp (s-exp->fasl v)) v))
            #:gate? #t
            #:note "FASL preserves numeric values nested in compound data.")
   (nt-case 'positive-nan
            'real-special-values
            +nan.0
            #:note "NaN predicate, text, and eqv category.")
   (nt-case 'positive-infinity
            'real-special-values
            +inf.0
            #:note "Positive infinity category.")
   (nt-case 'negative-infinity
            'real-special-values
            -inf.0
            #:note "Negative infinity category.")
   (nt-case 'positive-zero
            'real-special-values
            0.0
            #:note "Positive inexact zero category.")
   (nt-case 'negative-zero
            'real-special-values
            -0.0
            #:note "Negative inexact zero category.")
   (nt-case 'generic-add-overflow
            'integer-arithmetic
            '(+ 536870911 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic + promotes beyond WebRacket's fixnum range.")
   (nt-case 'generic-sub-overflow
            'integer-arithmetic
            '(- -536870912 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic - promotes below WebRacket's fixnum range.")
   (nt-case 'generic-mul-overflow
            'integer-arithmetic
            '(* 536870911 2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic * promotes beyond WebRacket's fixnum range.")
   (nt-case 'bignum-add-limb-carry
            'integer-arithmetic
            '(+ 4294967295 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum addition carries across a 32-bit limb.")
   (nt-case 'bignum-add-two-large
            'integer-arithmetic
            '(+ 9007199254740993 7)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum addition preserves integers beyond f64 precision.")
   (nt-case 'bignum-sub-to-fixnum
            'integer-arithmetic
            '(- 536870912 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum subtraction collapses canonical fixnum results.")
   (nt-case 'bignum-sub-cancel
            'integer-arithmetic
            '(- 9007199254740993 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum subtraction canonicalizes zero as a fixnum.")
   (nt-case 'bignum-mul-two-limbs
            'integer-arithmetic
            '(* 4294967296 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles two-limb products.")
   (nt-case 'bignum-mul-max-limb-carry
            'integer-arithmetic
            '(* 4294967295 4294967295)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles the largest single-limb product.")
   (nt-case 'bignum-mul-max-limb-negative
            'integer-arithmetic
            '(* -4294967295 4294967295)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication preserves signs for largest single-limb products.")
   (nt-case 'bignum-mul-dense-96-bit-carry
            'integer-arithmetic
            '(* (- (arithmetic-shift 1 96) 1)
                (- (arithmetic-shift 1 96) 1))
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication propagates carries across dense multi-limb operands.")
   (nt-case 'bignum-mul-dense-96-bit-negative
            'integer-arithmetic
            '(* (- (- (arithmetic-shift 1 96) 1))
                (- (arithmetic-shift 1 96) 1))
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles signs for dense multi-limb operands.")
   (nt-case 'bignum-mul-sparse-power-left
            'integer-arithmetic
            '(* (arithmetic-shift 1 130) 123456789)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles sparse power-of-two operands.")
   (nt-case 'bignum-mul-sparse-power-right
            'integer-arithmetic
            '(* 123456789 (arithmetic-shift 1 130))
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication is order-independent for sparse operands.")
   (nt-case 'bignum-mul-sparse-alternating
            'integer-arithmetic
            '(* (+ (arithmetic-shift 1 96) (arithmetic-shift 1 32) 1)
                (+ (arithmetic-shift 1 128) 7))
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles internal zero limbs.")
   (nt-case 'bignum-mul-asymmetric-short-left
            'integer-arithmetic
            '(* (+ (arithmetic-shift 1 33) 17)
                (- (arithmetic-shift 1 192) 123456789))
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles asymmetric multi-limb operands.")
   (nt-case 'bignum-mul-asymmetric-short-right
            'integer-arithmetic
            '(* (- (arithmetic-shift 1 192) 123456789)
                (+ (arithmetic-shift 1 33) 17))
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles reversed asymmetric multi-limb operands.")
   (nt-case 'bignum-mul-normalizes-to-fixnum
            'integer-arithmetic
            '(* 536870912 -1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication canonicalizes results in the WebRacket fixnum range.")
   (nt-case 'add1-overflow
            'integer-arithmetic
            '(add1 536870911)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "add1 promotes beyond WebRacket's fixnum range.")
   (nt-case 'sub1-overflow
            'integer-arithmetic
            '(sub1 -536870912)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "sub1 promotes below WebRacket's fixnum range.")
   (nt-case 'abs-most-negative-fixnum
            'integer-arithmetic
            '(abs -536870912)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "abs promotes the most-negative WebRacket fixnum.")
   (nt-case 'bignum-numeric-equal-same-value
            'integer-ordering
            '(= 9007199254740993 9007199254740993)
            #:gate? #t
            #:note "Generic = compares bignum exact integers by value.")
   (nt-case 'bignum-numeric-equal-neighbor
            'integer-ordering
            '(= 9007199254740993 9007199254740992)
            #:gate? #t
            #:note "Generic = distinguishes neighboring bignums.")
   (nt-case 'fixnum-less-than-bignum
            'integer-ordering
            '(< 536870911 536870912)
            #:gate? #t
            #:note "Generic < handles fixnum to bignum boundaries.")
   (nt-case 'bignum-less-than-bignum
            'integer-ordering
            '(< 9007199254740992 9007199254740993)
            #:gate? #t
            #:note "Generic < compares positive bignums by magnitude.")
   (nt-case 'negative-fixnum-greater-than-bignum
            'integer-ordering
            '(> -536870912 -536870913)
            #:gate? #t
            #:note "Generic > handles negative fixnum to bignum boundaries.")
   (nt-case 'bignum-less-equal-same-value
            'integer-ordering
            '(<= 4294967296 4294967296)
            #:gate? #t
            #:note "Generic <= accepts equal bignum values.")
   (nt-case 'negative-bignum-greater-equal-neighbor
            'integer-ordering
            '(>= -9007199254740993 -9007199254740992)
            #:gate? #t
            #:note "Generic >= compares negative bignum magnitudes correctly.")
   (nt-case 'variadic-exact-integer-ordering
            'integer-ordering
            '(< -9007199254740993 -536870913 0 536870912 9007199254740993)
            #:gate? #t
            #:note "Variadic < threads exact fixnum and bignum comparisons.")
   (nt-case 'mixed-exact-flonum-equal-rounded-down
            'integer-ordering
            '(= 9007199254740993 9007199254740992.0)
            #:gate? #t
            #:note "Mixed = compares against the exact f64 value, not a rounded exact integer.")
   (nt-case 'mixed-exact-flonum-greater-rounded-down
            'integer-ordering
            '(> 9007199254740993 9007199254740992.0)
            #:gate? #t
            #:note "Mixed > keeps exact integer precision past 2^53.")
   (nt-case 'mixed-exact-flonum-less-next-f64
            'integer-ordering
            '(< 9007199254740993 9007199254740994.0)
            #:gate? #t
            #:note "Mixed < compares a bignum with a neighboring finite f64.")
   (nt-case 'mixed-exact-flonum-equal-two-to-53
            'integer-ordering
            '(= 9007199254740992 9007199254740992.0)
            #:gate? #t
            #:note "Mixed = recognizes an exactly representable f64 integer.")
   (nt-case 'mixed-exact-flonum-positive-infinity
            'integer-ordering
            '(< 9007199254740993 +inf.0)
            #:gate? #t
            #:note "Mixed < orders finite exact integers below +inf.0.")
   (nt-case 'mixed-exact-flonum-negative-infinity
            'integer-ordering
            '(> -9007199254740993 -inf.0)
            #:gate? #t
            #:note "Mixed > orders finite exact integers above -inf.0.")
   (nt-case 'mixed-exact-flonum-nan-unordered
            'integer-ordering
            '(< 9007199254740993 +nan.0)
            #:gate? #t
            #:note "Mixed comparisons with NaN are unordered and return #f.")
   (nt-case 'mixed-rational-flonum-not-equal
            'integer-ordering
            '(= 1/10 0.1)
            #:gate? #t
            #:note "Mixed rational/flonum equality compares against the exact binary flonum value.")
   (nt-case 'mixed-rational-flonum-less-than
            'integer-ordering
            '(< 1/10 0.1)
            #:gate? #t
            #:note "The exact 1/10 is less than the binary flonum 0.1.")
   (nt-case 'mixed-flonum-rational-greater-than
            'integer-ordering
            '(> 0.1 1/10)
            #:gate? #t
            #:note "Mixed rational/flonum ordering handles the flonum-left case.")
   (nt-case 'mixed-rational-flonum-exact-tie
            'integer-ordering
            '(= 1/2 0.5)
            #:gate? #t
            #:note "Exactly representable rational/flonum pairs still compare equal.")
   (nt-case 'bignum-min-exact-only
            'integer-ordering
            '(min 9007199254740993 2)
            #:gate? #t
            #:note "Generic min accepts bignum exact integers.")
   (nt-case 'bignum-max-exact-only
            'integer-ordering
            '(max 9007199254740993 2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic max can return a bignum exact integer.")
   (nt-case 'bignum-min-mixed-flonum
            'integer-ordering
            '(min 9007199254740993 2.0)
            #:gate? #t
            #:note "Generic min accepts mixed bignum/flonum inputs.")
   (nt-case 'bignum-max-mixed-flonum
            'integer-ordering
            '(max 9007199254740993 2.0)
            #:gate? #t
            #:note "Generic max returns inexact when a flonum participates.")
   (nt-case 'mixed-min-signed-zero-tie
            'integer-ordering
            '(eqv? (min -0.0 0) 0.0)
            #:gate? #t
            #:note "Mixed min preserves the current signed-zero tie behavior.")
   (nt-case 'mixed-max-signed-zero-tie
            'integer-ordering
            '(eqv? (max 0 -0.0) -0.0)
            #:gate? #t
            #:note "Mixed max preserves the current signed-zero tie behavior.")
   (nt-case 'bignum-min-nan
            'integer-ordering
            '(eqv? (min +nan.0 9007199254740993) +nan.0)
            #:gate? #t
            #:note "Generic min propagates NaN with bignum inputs.")
   (nt-case 'bignum-max-nan
            'integer-ordering
            '(eqv? (max 9007199254740993 +nan.0) +nan.0)
            #:gate? #t
            #:note "Generic max propagates NaN with bignum inputs.")
   (nt-case 'bignum-quotient-small-divisor
            'integer-division
            '(quotient 9007199254740993 3)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact quotient divides a bignum dividend by a one-limb divisor.")
   (nt-case 'bignum-remainder-small-divisor
            'integer-division
            '(remainder 9007199254740993 7)
            #:gate? #t
            #:note "Exact remainder divides a bignum dividend by a one-limb divisor.")
   (nt-case 'negative-bignum-modulo-small-divisor
            'integer-division
            '(modulo -9007199254740993 7)
            #:gate? #t
            #:note "Exact modulo adjusts the truncating remainder to the divisor sign.")
   (nt-case 'bignum-quotient-remainder-small-divisor
            'integer-division
            '(let-values ([(q r) (quotient/remainder -9007199254740993 7)])
               (and (= q -1286742750677284)
                    (= r -5)))
            #:gate? #t
            #:note "quotient/remainder returns the truncating exact pair for a bignum dividend.")
   (nt-case 'bignum-quotient-smaller-dividend
            'integer-division
            '(quotient 3 9007199254740993)
            #:gate? #t
            #:note "Exact quotient handles the trivial zero quotient with a multi-limb divisor.")
   (nt-case 'bignum-remainder-smaller-dividend
            'integer-division
            '(remainder 3 9007199254740993)
            #:gate? #t
            #:note "Exact remainder handles the trivial dividend remainder with a multi-limb divisor.")
   (nt-case 'bignum-quotient-multi-limb-divisor
            'integer-division
            '(quotient 18446744073709551616 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact quotient handles a multi-limb divisor.")
   (nt-case 'bignum-remainder-multi-limb-divisor
            'integer-division
            '(remainder 18446744073709551617 4294967296)
            #:gate? #t
            #:note "Exact remainder handles a multi-limb divisor.")
   (nt-case 'negative-bignum-modulo-multi-limb-divisor
            'integer-division
            '(modulo -18446744073709551617 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact modulo adjusts signs after multi-limb division.")
   (nt-case 'bignum-quotient-negative-multi-limb-divisor
            'integer-division
            '(quotient 18446744073709551617 -4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact quotient follows sign rules with a negative multi-limb divisor.")
   (nt-case 'bignum-remainder-negative-multi-limb-divisor
            'integer-division
            '(remainder 18446744073709551617 -4294967296)
            #:gate? #t
            #:note "Exact remainder keeps the dividend sign with a negative multi-limb divisor.")
   (nt-case 'bignum-modulo-negative-multi-limb-divisor
            'integer-division
            '(modulo 18446744073709551617 -4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact modulo follows the negative divisor sign.")
   (nt-case 'bignum-quotient-remainder-multi-limb-divisor
            'integer-division
            '(let-values ([(q r) (quotient/remainder -18446744073709551617
                                                     4294967296)])
               (and (= q -4294967296)
                    (= r -1)))
            #:gate? #t
            #:note "quotient/remainder handles signed multi-limb division.")
   (nt-case 'bignum-quotient-remainder-non-power-divisor
            'integer-division
            '(let-values ([(q r) (quotient/remainder 123456789012345678901234567890
                                                     9876543210987654321)])
               (and (= q 12499999886)
                    (= r 925925941327160484)))
            #:gate? #t
            #:note "Multi-limb division handles a non-power divisor and remainder.")
   (nt-case 'bignum-divmod-fixed-random-positive
            'integer-division
            '(let ([n 340282366920938463463374607431768211457]
                   [d 18446744073709551617])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q 18446744073709551615)
                      (= r 2)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant for positive multi-limb operands.")
   (nt-case 'bignum-divmod-fixed-random-negative-dividend
            'integer-division
            '(let ([n -1234567890123456789012345678901234567890]
                   [d 98765432109876543210987654321])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q -12499999886)
                      (= r -9259259400925925941327160484)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant with a negative dividend.")
   (nt-case 'bignum-divmod-fixed-random-negative-divisor
            'integer-division
            '(let ([n 99999999999999999999999999999999999999]
                   [d -3333333333333333333333333333])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q -30000000000)
                      (= r 9999999999)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant with a negative divisor.")
   (nt-case 'bignum-divmod-fixed-random-both-negative
            'integer-division
            '(let ([n -340282366920938463463374607431768211455]
                   [d -18446744073709551615])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q 18446744073709551617)
                      (= r 0)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant with both operands negative.")
   (nt-case 'bignum-quotient-equal-multi-limb
            'integer-division
            '(quotient 18446744073709551616 18446744073709551616)
            #:gate? #t
            #:note "Exact quotient handles equal multi-limb operands.")
   (nt-case 'bignum-remainder-equal-multi-limb
            'integer-division
            '(remainder 18446744073709551616 18446744073709551616)
            #:gate? #t
            #:note "Exact remainder handles equal multi-limb operands.")
   (nt-case 'bignum-gcd-small-divisor
            'integer-gcd
            '(gcd 9007199254740993 3)
            #:gate? #t
            #:note "gcd can reduce a bignum by a one-limb divisor.")
   (nt-case 'bignum-lcm-small-divisor
            'integer-gcd
            '(lcm 9007199254740993 3)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "lcm routes exact bignum division through quotient before multiplying.")
   (nt-case 'bignum-gcd-zero-left
            'integer-gcd
            '(gcd 0 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "gcd handles the zero-left case with a multi-limb divisor.")
   (nt-case 'bignum-gcd-multi-limb-divisor
            'integer-gcd
            '(gcd 18446744073709551616 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "gcd can reduce exact integers through multi-limb division.")
   (nt-case 'bignum-lcm-multi-limb-divisor
            'integer-gcd
            '(lcm 18446744073709551616 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "lcm can use exact quotient with a multi-limb gcd.")
   (nt-case 'integer-sqrt-bignum-perfect-square
            'integer-root
            '(integer-sqrt 81129638414606681695789005144064)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "integer-sqrt handles exact bignum perfect squares.")
   (nt-case 'integer-sqrt-bignum-nonperfect
            'integer-root
            '(integer-sqrt 81129638414606681695789005156409)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "integer-sqrt floors non-perfect bignum roots.")
   (nt-case 'integer-sqrt-remainder-bignum-invariant
            'integer-root
            '(let-values ([(s r) (integer-sqrt/remainder
                                  81129638414606681695789005156409)])
               (and (= s 9007199254740992)
                    (= r 12345)))
            #:gate? #t
            #:note "integer-sqrt/remainder preserves s^2+r=n for bignums.")
   (nt-case 'exact-expt-promotes-bignum
            'exact-expt
            '(expt 2 40)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact expt promotes beyond the WebRacket fixnum range.")
   (nt-case 'exact-expt-negative-base-odd
            'exact-expt
            '(expt -3 21)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact expt preserves the sign for odd exponents.")
   (nt-case 'exact-expt-negative-exponent
            'exact-expt
            '(expt 2 -40)
            #:gate? #t
            #:note "Exact integer negative exponents produce rationals.")
   (nt-case 'exact-rational-expt-negative
            'exact-expt
            '(expt 2/3 -4)
            #:gate? #t
            #:note "Exact rational bases support negative integer exponents.")
   (nt-case 'exact-expt-bignum-exponent-parity
            'exact-expt
            '(expt -1 536870913)
            #:gate? #t
            #:note "Exact bignum exponents are reduced by squaring.")
   (nt-case 'sqrt-bignum-perfect-square
            'real-math
            '(sqrt 18446744073709551616)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "sqrt returns an exact root for bignum perfect squares.")
   (nt-case 'sqrt-bignum-nonperfect-inexact
            'real-math
            '(sqrt 536870912)
            #:gate? #t
            #:note "sqrt falls back to an inexact result for non-perfect bignums.")
   (nt-case 'sqrt-rational-perfect-square
            'real-math
            '(sqrt 9/16)
            #:gate? #t
            #:note "sqrt returns exact rational roots when numerator and denominator are squares.")
   (nt-case 'sqrt-bignum-rational-perfect-square
            'real-math
            '(sqrt (/ (expt 9007199254740993 2) 25))
            #:gate? #t
            #:note "sqrt preserves exactness for bignum rational perfect squares.")
   (nt-case 'rationalize-positive-exact
            'real-math
            '(rationalize 1/4 1/10)
            #:gate? #t
            #:note "rationalize finds the simplest exact rational in an exact interval.")
   (nt-case 'rationalize-negative-exact
            'real-math
            '(rationalize -1/4 1/10)
            #:gate? #t
            #:note "rationalize handles negative exact intervals symmetrically.")
   (nt-case 'rationalize-interval-crosses-zero
            'real-math
            '(rationalize 1/4 1/4)
            #:gate? #t
            #:note "rationalize chooses zero when the interval contains zero.")
   (nt-case 'rationalize-smallest-denominator
            'real-math
            '(rationalize 11/40 1/4)
            #:gate? #t
            #:note "rationalize picks the simplest denominator in a wide interval.")
   (nt-case 'rationalize-inexact-tolerance
            'real-math
            '(rationalize 1/4 0.1)
            #:gate? #t
            #:note "rationalize returns an inexact result when the tolerance is inexact.")
   (nt-case 'rationalize-inexact-inputs
            'real-math
            '(rationalize 1.2 0.1)
            #:gate? #t
            #:note "rationalize accepts finite flonum inputs and returns an inexact result.")
   (nt-case 'expt-half-perfect-square
            'real-math
            '(expt 9 1/2)
            #:gate? #t
            #:note "expt with exact 1/2 delegates to exact sqrt for perfect squares.")
   (nt-case 'expt-half-rational-perfect-square
            'real-math
            '(expt 9/16 1/2)
            #:gate? #t
            #:note "expt with exact 1/2 preserves exact rational square roots.")
   (nt-case 'expt-half-nonperfect-inexact
            'real-math
            '(expt 2 1/2)
            #:gate? #t
            #:note "expt with exact 1/2 falls back to inexact sqrt when needed.")
   (nt-case 'expt-half-bignum-perfect-square
            'real-math
            '(expt 18446744073709551616 1/2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "expt with exact 1/2 handles bignum perfect squares.")
   (nt-case 'expt-half-flonum
            'real-math
            '(expt 2.0 1/2)
            #:gate? #t
            #:note "expt with exact 1/2 accepts nonnegative flonum bases.")
   (nt-case 'exp-rational
            'real-math
            '(exp 1/2)
            #:gate? #t
            #:note "exp accepts exact rational inputs through the real inexact path.")
   (nt-case 'log-rational
            'real-math
            '(log 3/2)
            #:gate? #t
            #:note "log accepts exact rational inputs through the real inexact path.")
   (nt-case 'log-rational-base
            'real-math
            '(log 8/27 2/3)
            #:gate? #t
            #:note "log with a base accepts exact rational inputs.")
   (nt-case 'sin-rational
            'real-math
            '(sin 1/2)
            #:gate? #t
            #:note "trigonometric functions accept exact rational inputs.")
   (nt-case 'cos-rational
            'real-math
            '(cos 1/2)
            #:gate? #t
            #:note "cos accepts exact rational inputs.")
   (nt-case 'atan-rational
            'real-math
            '(atan 1/4)
            #:gate? #t
            #:note "atan accepts exact rational inputs.")
   (nt-case 'atan2-rational
            'real-math
            '(atan 1/2 3/4)
            #:gate? #t
            #:note "two-argument atan accepts exact rational inputs.")
   (nt-case 'integer-length-bignum-two-to-53-plus-one
            'integer-bitwise
            '(integer-length 9007199254740993)
            #:gate? #t
            #:note "integer-length accepts positive bignums near the f64 precision boundary.")
   (nt-case 'integer-length-bignum-power-of-two
            'integer-bitwise
            '(integer-length 18446744073709551616)
            #:gate? #t
            #:note "integer-length handles positive multi-limb powers of two.")
   (nt-case 'integer-length-negative-bignum-power-of-two
            'integer-bitwise
            '(integer-length -18446744073709551616)
            #:gate? #t
            #:note "integer-length of negative powers follows infinite two's-complement.")
   (nt-case 'integer-length-negative-bignum-neighbor
            'integer-bitwise
            '(integer-length -18446744073709551617)
            #:gate? #t
            #:note "integer-length distinguishes the neighbor below a negative power of two.")
   (nt-case 'bitwise-not-positive-bignum
            'integer-bitwise
            '(bitwise-not 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-not follows infinite two's-complement for positive bignums.")
   (nt-case 'bitwise-not-negative-bignum
            'integer-bitwise
            '(bitwise-not -9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-not follows infinite two's-complement for negative bignums.")
   (nt-case 'bitwise-and-positive-bignums
            'integer-bitwise
            '(bitwise-and 18446744073709551615 1085102592571150095)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-and combines positive bignum limbs.")
   (nt-case 'bitwise-ior-positive-bignums
            'integer-bitwise
            '(bitwise-ior 18446744073709551616 255)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-ior combines positive bignum limbs.")
   (nt-case 'bitwise-xor-positive-bignums
            'integer-bitwise
            '(bitwise-xor 18446744073709551615 1085102592571150095)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-xor combines positive bignum limbs.")
   (nt-case 'bitwise-and-negative-positive-bignum
            'integer-bitwise
            '(bitwise-and -18446744073709551616 18446744073709551615)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-and handles negative and positive bignum operands.")
   (nt-case 'bitwise-ior-negative-positive-bignum
            'integer-bitwise
            '(bitwise-ior -18446744073709551616 255)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-ior handles negative and positive bignum operands.")
   (nt-case 'bitwise-xor-negative-positive-bignum
            'integer-bitwise
            '(bitwise-xor -18446744073709551616 255)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-xor handles negative and positive bignum operands.")
   (nt-case 'bitwise-and-negative-bignums
            'integer-bitwise
            '(bitwise-and -18446744073709551616 -1085102592571150096)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-and handles two negative bignum operands.")
   (nt-case 'bitwise-ior-negative-bignums
            'integer-bitwise
            '(bitwise-ior -18446744073709551616 -1085102592571150096)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-ior handles two negative bignum operands.")
   (nt-case 'bitwise-xor-negative-bignums
            'integer-bitwise
            '(bitwise-xor -18446744073709551616 -1085102592571150096)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "bitwise-xor handles two negative bignum operands.")
   (nt-case 'bitwise-and-variadic-bignum
            'integer-bitwise
            '(bitwise-and 18446744073709551615 281474976710655 65535)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Variadic bitwise-and folds through bignum intermediates.")
   (nt-case 'bitwise-ior-variadic-bignum
            'integer-bitwise
            '(bitwise-ior 18446744073709551616 281474976710655 65535)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Variadic bitwise-ior folds through bignum intermediates.")
   (nt-case 'bitwise-xor-variadic-bignum
            'integer-bitwise
            '(bitwise-xor 18446744073709551616 281474976710655 65535)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Variadic bitwise-xor folds through bignum intermediates.")
   (nt-case 'bitwise-bit-set-positive-bignum-set
            'integer-bitwise
            '(bitwise-bit-set? 9007199254740992 53)
            #:gate? #t
            #:note "bitwise-bit-set? can inspect set bits in positive bignums.")
   (nt-case 'bitwise-bit-set-positive-bignum-clear
            'integer-bitwise
            '(bitwise-bit-set? 9007199254740992 52)
            #:gate? #t
            #:note "bitwise-bit-set? can inspect clear bits in positive bignums.")
   (nt-case 'bitwise-bit-set-positive-bignum-huge-index
            'integer-bitwise
            '(bitwise-bit-set? 9007199254740992 9007199254740993)
            #:gate? #t
            #:note "Positive exact integers have high zero bits past their finite length.")
   (nt-case 'bitwise-bit-set-negative-bignum-huge-index
            'integer-bitwise
            '(bitwise-bit-set? -9007199254740992 9007199254740993)
            #:gate? #t
            #:note "Negative exact integers have infinitely many high one bits.")
   (nt-case 'bitwise-bit-set-negative-bignum-low-clear
            'integer-bitwise
            '(bitwise-bit-set? -9007199254740992 0)
            #:gate? #t
            #:note "Negative bignum bit tests follow infinite two's-complement at low bits.")
   (nt-case 'bitwise-first-bit-set-positive-bignum
            'integer-bitwise
            '(bitwise-first-bit-set 9007199254740992)
            #:gate? #t
            #:note "bitwise-first-bit-set finds the lowest set limb bit in positive bignums.")
   (nt-case 'bitwise-first-bit-set-negative-bignum
            'integer-bitwise
            '(bitwise-first-bit-set -9007199254740992)
            #:gate? #t
            #:note "bitwise-first-bit-set handles negative bignums via two's-complement.")
   (nt-case 'arithmetic-shift-fixnum-left-to-bignum
            'integer-bitwise
            '(arithmetic-shift 1 40)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "arithmetic-shift promotes left shifts beyond the WebRacket fixnum range.")
   (nt-case 'arithmetic-shift-negative-fixnum-left-to-bignum
            'integer-bitwise
            '(arithmetic-shift -1 40)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "arithmetic-shift preserves sign when left-shifting negative exact integers.")
   (nt-case 'arithmetic-shift-bignum-left
            'integer-bitwise
            '(arithmetic-shift 9007199254740993 5)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "arithmetic-shift can left-shift bignum exact integers.")
   (nt-case 'arithmetic-shift-bignum-right
            'integer-bitwise
            '(arithmetic-shift 9007199254740993 -20)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "arithmetic-shift can right-shift positive bignum exact integers.")
   (nt-case 'arithmetic-shift-negative-bignum-right
            'integer-bitwise
            '(arithmetic-shift -9007199254740993 -20)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "arithmetic-shift right on negative bignums rounds toward negative infinity.")
   (nt-case 'arithmetic-shift-negative-bignum-huge-right
            'integer-bitwise
            '(arithmetic-shift -9007199254740993 -80)
            #:gate? #t
            #:note "arithmetic-shift sign-extends negative exact integers shifted past their length.")
   (nt-case 'vector-ref-first-bignum-index-error
            'exact-integer-consumers
            '(with-handlers ([exn:fail:contract? (lambda (exn) 'contract)])
               (vector-ref '#(a b) 536870912)
               'not-raised)
            #:gate? #t
            #:note "Bignum vector indexes are exact indexes and fail as catchable range errors.")
   (nt-case 'vector-ref-huge-bignum-index-error
            'exact-integer-consumers
            '(with-handlers ([exn:fail:contract? (lambda (exn) 'contract)])
               (vector-ref '#(a b) 4294967296)
               'not-raised)
            #:gate? #t
            #:note "Multi-limb bignum vector indexes must not reach an unchecked i31 cast.")
   (nt-case 'bytes-ref-bignum-index-error
            'exact-integer-consumers
            '(with-handlers ([exn:fail:contract? (lambda (exn) 'contract)])
               (bytes-ref #"ab" 536870912)
               'not-raised)
            #:gate? #t
            #:note "Bignum byte-string indexes fail as catchable range errors.")
   (nt-case 'bytes-bignum-value-error
            'exact-integer-consumers
            '(with-handlers ([exn:fail:contract? (lambda (exn) 'contract)])
               (bytes 4294967296)
               'not-raised)
            #:gate? #t
            #:note "Bignum byte values fail the byte? boundary without unchecked i31 casts.")))

;; number-tower-groups : -> (listof symbol?)
;;   Return the distinct oracle groups in stable display order.
(define (number-tower-groups)
  (remove-duplicates (map number-tower-case-group number-tower-cases)))

;; selected-by-symbols? : (any/c -> symbol?) (listof symbol?) any/c -> boolean?
;;   Check whether a symbol filter accepts v.
(define (selected-by-symbols? selector allowed v)
  (or (null? allowed)
      (memq (selector v) allowed)))

;; select-number-tower-cases :
;;   [#:groups (listof symbol?)] [#:ids (listof symbol?)] [#:include-non-gates? boolean?]
;;   -> (listof number-tower-case?)
;;   Select cases for a runner invocation.
(define (select-number-tower-cases #:groups [groups '()]
                                   #:ids [ids '()]
                                   #:include-non-gates? [include-non-gates? #f])
  (filter
   (lambda (c)
     (and (selected-by-symbols? number-tower-case-group groups c)
          (selected-by-symbols? number-tower-case-id ids c)
          (or include-non-gates?
              (number-tower-case-gate? c))))
   number-tower-cases))
