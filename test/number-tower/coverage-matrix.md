# Number Tower Coverage Matrix

Source: [docs/reference/numbers.scrbl](../../docs/reference/numbers.scrbl), section 4.3.

This matrix records the public numeric surface that the full-tower branch must
bring under the Racket CS oracle. Milestone 0 only gates the `oracle-smoke`
group; broader cases are recorded observations until the milestone that owns
the representation or operation lands.

| numbers.scrbl area | Public surface | Primary milestone | Oracle group |
| --- | --- | --- | --- |
| Number types | `number?`, `complex?`, `real?`, `rational?`, `integer?`, `exact-integer?`, exact nonnegative/positive integer predicates | M1, M4, M7, M10 | `integer-representation`, `rational-representation`, `complex-construction` |
| Machine number predicates | `inexact-real?`, `fixnum?`, `flonum?`, `double-flonum?`, `single-flonum?`, `single-flonum-available?` | M1, M6 | `integer-representation`, `real-conversion` |
| Sign, parity, exactness | `zero?`, `positive?`, `negative?`, `even?`, `odd?`, `exact?`, `inexact?` | M1, M5, M6 | `integer-representation`, `integer-bitwise`, `real-math` |
| Exact/inexact conversion | `inexact->exact`, `exact->inexact`, `real->single-flonum`, `real->double-flonum` | M6 | `real-conversion` |
| Generic arithmetic | `+`, `-`, `*`, `/`, `add1`, `sub1`, `abs`, `max`, `min` | M2, M4, M6, M7 | `integer-arithmetic`, `rational-arithmetic`, `complex-basic` |
| Integer division | `quotient`, `remainder`, `quotient/remainder`, `modulo` | M3 | `integer-division` |
| GCD and LCM | `gcd`, `lcm` | M3, M4 | `integer-gcd`, `rational-arithmetic` |
| Rounding | `round`, `floor`, `ceiling`, `truncate`, exact rounding variants | M6 | `real-rounding` |
| Rational accessors | `numerator`, `denominator`, `rationalize` | M4, M6 | `rational-representation`, `real-conversion` |
| Comparisons | `=`, `<`, `<=`, `>`, `>=` | M2, M4, M6, M7 | `integer-ordering`, `rational-arithmetic`, `complex-equality` |
| Powers and roots | `sqrt`, `integer-sqrt`, `integer-sqrt/remainder`, `expt`, `exp`, `log` | M5, M6, M8 | `integer-root`, `integer-expt`, `real-math`, `complex-root`, `complex-expt` |
| Trigonometry | `sin`, `cos`, `tan`, `asin`, `acos`, `atan` | M6, M8 | `real-math`, `complex-transcendental` |
| Complex construction/projection | `make-rectangular`, `make-polar`, `real-part`, `imag-part`, `magnitude`, `angle`, `conjugate` | M7 | `complex-construction`, `complex-basic` |
| Bitwise operations | `bitwise-ior`, `bitwise-and`, `bitwise-xor`, `bitwise-not`, bit fields, shifts, `integer-length` | M5 | `integer-bitwise` |
| Random numbers | `random`, PRG predicates/conversion, `random-seed`, crypto randomness helpers | M10 | `large-index-errors`, `random-number-bounds` |
| Number/string conversion | `number->string`, `string->number`, `real->decimal-string` | M9 | `number-string`, `string-number` |
| Bytes conversion | integer and floating-point byte conversions, endian predicate | M9, M10 | `numeric-bytes`, `large-index-errors` |
| Constants and extras | `pi`, `pi.f`, degree/radian conversion, `sqr`, `sgn`, hyperbolic functions, `nan?`, `infinite?`, integer sign predicates, `natural?` | M6, M8 | `real-math`, `complex-transcendental`, `real-special-values` |

Milestone 0 seed groups:

| Oracle group | Gate now? | Purpose |
| --- | --- | --- |
| `oracle-smoke` | yes | Prove the runner uses Racket CS and can compare simple WebRacket results. |
| `integer-representation` | no | Record exact integer literal behavior around fixnum, limb, and f64 boundaries. |
| `integer-arithmetic` | no | Record current generic fixnum overflow behavior. |
| `rational-representation` | no | Record current exact rational literal behavior. |
| `complex-basic` | no | Record current complex literal and constructor behavior. |
| `real-special-values` | no | Record NaN, infinity, and signed-zero categories. |
