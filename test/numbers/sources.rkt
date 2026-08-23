#lang racket/base

(require "model.rkt")

(provide number-port-sources)

;; number-port-sources : (listof number-port-source?)
;;   Racket numeric test sources that the WebRacket ports must account for.
(define number-port-sources
  (list
   (number-port-source
    'racket-number
    "../racket/pkgs/racket-test-core/tests/racket/number.rktl"
    3870
    "Main numeric tower tests: predicates, arithmetic, conversion, bitwise, random.")
   (number-port-source
    'racket-numstrs
    "../racket/pkgs/racket-test-core/tests/racket/numstrs.rktl"
    311
    "Reader and string->number table used by number.rktl.")
   (number-port-source
    'racket-fixnum
    "../racket/pkgs/racket-test-core/tests/racket/fixnum.rktl"
    500
    "racket/fixnum operations, boundaries, fxvectors, and unsafe parity.")
   (number-port-source
    'racket-flonum
    "../racket/pkgs/racket-test-core/tests/racket/flonum.rktl"
    496
    "racket/flonum operations, flvectors, flrandom, flexpt, and flbit-field.")
   (number-port-source
    'racket-math
    "../racket/pkgs/racket-test-core/tests/racket/math.rktl"
    583
    "racket/math predicates and helper functions.")
   (number-port-source
    'racket-gambit-numeric
    "../racket/pkgs/racket-test-core/tests/racket/gambit-numeric.rktl"
    325
    "Gambit-derived compact numeric smoke tests.")
   (number-port-source
    'racket-fasl
    "../racket/pkgs/racket-test-core/tests/racket/fasl.rktl"
    238
    "FASL round trips, including numeric and fx/flvector values.")
   (number-port-source
    'racket-extflonum
    "../racket/pkgs/racket-test-core/tests/racket/extflonum.rktl"
    #f
    "Extended flonum tests; mostly tracked as unsupported by WebRacket today.")
   (number-port-source
    'racket-number-hash
    "../racket/pkgs/racket-test/tests/racket/stress/number-hash.rkt"
    46
    "Stress coverage for numeric hash keys.")
   (number-port-source
    'racket-hash-random
    "../racket/pkgs/racket-test/tests/racket/hash-random.rkt"
    #f
    "Randomized hash-table stress tests with numeric hash codes.")
   (number-port-source
    'racket-random-future
    "../racket/pkgs/racket-test-extra/tests/future/random-future.rkt"
    #f
    "Random expression generator for futures; tracked for numeric generators.")
   (number-port-source
    'racket-place-chan-rand
    "../racket/pkgs/racket-test-extra/tests/racket/place-chan-rand.rkt"
    #f
    "Random place-channel payload coverage including flonums.")))
