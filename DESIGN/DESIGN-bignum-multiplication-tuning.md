# Bignum Multiplication Tuning

WebRacket stores bignum magnitudes as little-endian arrays of unsigned
32-bit limbs. The production dispatcher preserves the single-limb and
power-of-two paths, uses schoolbook multiplication for unbalanced operands,
and selects recursive algorithms only for operands whose lengths differ by at
most a factor of two.

The default thresholds are deliberately WebRacket measurements, not GMP
thresholds. GMP has assembly implementations, target-specific `tuneup`
results, and different allocation behavior. Its documented algorithm ladder is
still the model: basecase, Karatsuba, then Toom-3, with separate square
thresholds. The reference is the [GMP multiplication-algorithms
manual](https://gmplib.org/manual/Multiplication-Algorithms).

## Current Decision

The local WebRacket sweep selected these defaults:

| Dispatcher | Threshold | Reason |
| --- | ---: | --- |
| Multiply Karatsuba | 128 limbs | Faster than schoolbook at 128 limbs and above in the refined dispatch sweep. |
| Square basecase | 128 limbs | Keeps small equal products on ordinary multiplication and permits a separate square schedule. |
| Square Karatsuba | 128 limbs | Matches the multiply crossover on the refined square sweep. |
| Multiply Toom-3 | disabled | Slower than the tuned Karatsuba schedule through 16384 limbs. |
| Square Toom-3 | disabled | Slower than the tuned Karatsuba schedule through 16384 limbs. |

The Toom-3 code remains implemented and covered by a forced-profile oracle.
It allocates canonical exact-integer temporaries during evaluation and
interpolation. A limb-slice workspace implementation is the next performance
step before enabling it by default.

The forced profiles include directed edge cases plus deterministic randomized
products, squares, sign changes, and distributive identities. This keeps both
recursive algorithms exercised even when their normal production threshold is
disabled or not reached by a particular corpus run.

## Reproduction

Start with the broad forced-recursion comparison:

```sh
racket tools/tune-bignum-mul.rkt \
  --limbs 16,24,32,40,48,64,96,128,192,256,384,512,768,1024 \
  --samples 3 --reps 1000 --warmup 200 \
  --cs '/Applications/Racket v9.3.0.2/bin/racket'
```

This reports forced-recursive crossover estimates, which establish whether an
algorithm is promising. It does not directly choose a dispatcher cutoff, since
children below a production threshold use schoolbook multiplication.

Refine candidate cutoffs with the generated dense cases and a fresh compiled
cache under `tmp/` for each profile. For example, compare the selected
Karatsuba profile with a Toom-3 candidate:

```sh
/usr/bin/env PLTCOMPILEDROOTS="$PWD/tmp/measure-karatsuba" \
  racket tools/measure-bignum-mul.rkt \
  --limbs 128,160,192,224,256,320,384,512 \
  --reps 1000 --warmup 200 --no-cs

/usr/bin/env PLTCOMPILEDROOTS="$PWD/tmp/measure-toom512" \
  WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD=128 \
  WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD=512 \
  WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD=128 \
  WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD=128 \
  WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD=512 \
  racket tools/measure-bignum-mul.rkt \
  --limbs 512,768,1024,1536,2048 \
  --reps 100 --warmup 20 --no-cs
```

Choose the smallest threshold with a stable win across at least three nearby
sizes. Re-run the forced algorithm oracle and the random Racket CS differential
check after changing a threshold.
