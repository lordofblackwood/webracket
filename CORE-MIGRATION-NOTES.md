# Core Migration Notes

This file records semantic and organizational notes discovered while moving
runtime helpers into `compiler/runtime-wasm/core/` and replacing primitive-facing
WebAssembly traps with Racket exceptions.

## Error Semantics

Remaining literal error stubs should not all be replaced mechanically. Some are
ordinary user-facing contract paths, some are trusted `/checked` helper
contracts, and some are internal representation invariants where the correct
next step may be a printer, an out-of-memory error, or a dedicated internal
assertion.

Current remaining raw-stub classes:

- `exceptions.rkt`:
  - `$raise-expected-string` was removed. `linear-memory->string` now raises a
    catchable `exn:fail:contract` with `who` tied to `linear-memory->string`
    when decoded FASL data is not a string.
  - `$raise-expected-fixnum` now raises a catchable `exn:fail:contract`.
    Public `range` validates arguments before choosing the fixnum/flonum
    implementation, so this remains a fallback path rather than a deliberately
    polished public error message.
  - Generic `raise-argument-error` now preserves zero-based position arguments
    from source-level calls when there is more than one supplied argument,
    reports the selected bad value, and includes an `other arguments...` block
    for the remaining supplied arguments. The realm-aware
    `raise-argument-error*` entry now shares this message path for proper
    Racket-shaped calls and keeps the older simplified WebRacket shape as a
    compatibility path that routes through `raise-argument-error` instead of
    trapping.
  - Generic `raise-arguments-error` now formats field/value detail pairs,
    validates that field labels are strings, and reports a catchable
    `missing value after field string` error for odd detail lists. It still
    omits Racket's multiline reindentation and unquoted-printing-string
    special case.

- `mutable-hashes.rkt` and `symbols.rkt`:
  - `$raise-hash-insert:table-full` and
    `$raise-symbol-table-insert:table-full` now raise catchable
    `exn:fail:out-of-memory` values. They are hard to exercise from a focused
    source-level test because normal growth should resize before saturation.
  - Concrete mutable hash helper stubs such as
    `$raise-argument-error:mutable-hasheq-expected` now raise catchable
    `exn:fail:contract` values. These helpers are shared across several hidden
    concrete mutable-hash dispatch paths, so they currently use the generic
    mutable-hash contract rather than preserving the precise public `who`.
  - Concrete mutable hash read-family stubs such as
    `$raise-argument-error:hasheq-expected` now raise catchable
    `exn:fail:contract` values instead of raw traps. These helpers are hidden
    concrete dispatch guards, so they currently use `hash-ref`/`hash?` for the
    fallback message rather than trying to expose a non-public concrete helper
    name.

- `strings.rkt` and `bytes.rkt`:
  - `$raise-check-string`, `$raise-bad-string-index`, and
    `$raise-expected-mutable-bytes` now raise catchable contract errors, but
    they still appear to be legacy/unused stubs. Public string and bytes
    primitives mostly route through newer helpers that preserve `who`.
  - `$raise-invalid-utf8-input`, `$raise-invalid-utf8-start`, and
    `$raise-invalid-utf8-end` in `strings.rkt` now raise catchable fallback
    errors, but still appear unreferenced; the public `bytes->string/utf-8`
    path uses the byte-decoding helpers in `bytes.rkt`, which already raise
    catchable contract errors.
  - `$raise-string-copy!/checked:out-of-bounds` belongs to a `/checked` helper
    and now raises a catchable internal contract error. Keep `/checked` trusted
    unless evidence shows a user/compiler path reaches it without prior
    validation.
  - `$raise-string-buffer-overflow` now raises a catchable
    `exn:fail:out-of-memory`, since the live callers are shared linear-memory
    staging buffers used by FFI and filesystem bridges. `$bomb` now raises a
    catchable internal contract error.
  - `bytes-convert` exposed a fallback `$primitive-invoke` bug for at-least
    list-rest primitive shapes: the at-least-1, at-least-2, and at-least-3
    branches built `$rest` on a successful type test but performed the
    `return_call_ref` in the failure branch. First-class calls could therefore
    trap with an illegal cast instead of reaching the primitive contract error.
    It also exposed a tail-call emission bug: variadic primitives are already
    lowered to mandatory arguments plus one rest argument, so direct
    `return_call` generation must not re-pad those calls with `$missing`.
    The first-class primitive object also needs a finite-arity/rest-list
    invoker shape because Racket reports `bytes-convert` as accepting 2 through
    7 arguments while WebRacket's runtime entry is `$Prim>=2` with a rest list.

- `formatting.rkt` and struct formatting:
  - Formatter fallback stubs are not all ordinary contract errors. For some
    values the correct Racket behavior is likely to add a printer instead of
    raising an exception.
  - Defensive formatter traps for unexpected pair/struct/vector/value cases now
    raise catchable formatter exceptions. `$raise-format/display:pair:expected-pair`
    and `$raise-format/display:struct:expected-struct` include the offending
    value when it is available.
  - Public opaque values for semaphores, semaphore-peek events, will
    executors, loggers, log receivers, bytes converters, uninterruptible
    locks, pseudo-random generators, threads, thread groups, thread cells,
    custodians, custodian boxes, and security guards now print as `#<...>`
    values instead of falling
    through to `$raise-format/display:unknown-datatype`. Compact regexp values
    now print from their stored source as `#rx`, `#px`, `#rx#`, or `#px#`
    forms.
  - `$raise-not-a-string` currently belongs to a commented-out `string->bytes`
    helper. Treat it as dead unless that helper is restored.

- `procedures.rkt`:
  - First-class closure/case-lambda/primitive arity errors already use
    catchable `exn:fail:contract:arity`.
  - `$raise-apply-final-arg-not-list` now prints the offending final argument
    in its `given:` line, so strings and symbols are rendered like Racket
    contract errors instead of display-rendered.
  - Legacy placeholders such as `$raise-arity-mismatch` and
    `$raise-arity-error:exactly`/`$raise-arity-error:at-least` now raise
    catchable `exn:fail:contract:arity` values. They remain unused
    placeholders and can be removed later.
  - Primitive-dispatch invariants such as missing primitive code, code/arity
    shape mismatch, and unhandled shapes now raise catchable contract errors
    instead of logging or trapping.

- `numbers.rkt`:
  - The legacy `$raise-expected-number*` helpers now raise catchable
    `exn:fail:contract` values with `number?` and the offending value instead
    of logging and trapping. Public `+`, `-`, `*`, and `/` now use a
    `who`-aware path for bad number arguments.
  - Numeric real? contract helpers and keyword contract helpers now share
    `$raise-argument-error1`, so their `given:` values use printed Racket
    syntax (`"x"`, `'bad`) instead of display syntax.
  - A broad generic-numeric pass now preserves `who` and the more precise
    Racket contract for many primitive-facing wrong-type paths, including
    `zero?`, `positive?`, `negative?`, `even?`, `odd?`, `nan?`, `infinite?`,
    `quotient`, `remainder`, `modulo`, `quotient/remainder`, `add1`, `sub1`,
    `sqr`, `sqrt`, `abs`, `round`, `floor`, `ceiling`, `truncate`, `sgn`,
    the exact rounding functions, trigonometric functions, `atan`, and angle
    conversion. `modulo` now validates integer arguments before delegating to
    `remainder`, so type errors preserve `modulo` as `who`.
  - Public bitwise helpers now preserve `who` and use Racket's
    `exact-integer?` / `exact-nonnegative-integer?` contracts for wrong-type
    paths, including the compiler fast path for one-argument `bitwise-and`,
    `bitwise-ior`, and `bitwise-xor`.
  - `real->floating-point-bytes` now preserves `who` and the `real?` contract
    for bad first arguments instead of falling through to the legacy generic
    `number?` path.
  - Public numeric comparators and `min`/`max` now avoid treating immediate
    values such as `#f` as malformed fixnums. Bad arguments raise catchable
    contract errors with public `who`; `=` reports `number?`, while ordering
    comparators and `min`/`max` report `real?`.
  - `exact->inexact` now reports Racket's public `number?` contract for bad
    arguments and accepts WebRacket complex numbers by converting their real and
    imaginary components.
  - `inexact->exact` now reports Racket's non-finite domain error for `+nan.0`,
    `+inf.0`, and `-inf.0` instead of a misleading `number?` contract error.
    Finite non-integral flonums still need rational-number support before they
    can match Racket's successful conversion behavior.
  - Some numeric conversion helpers still use older validation shapes; audit
    those separately before claiming complete numeric parity.

- `lists.rkt`:
  - Positive out-of-range `list-ref`, `list-tail`, `list-set`, and
    `list-update` errors now report list index context instead of incorrectly
    claiming that the already-valid index failed `exact-nonnegative-integer?`.
    `list-tail` preserves Racket's distinction where index 0 accepts any value,
    but positive indexes that cannot step through pairs report an index error.
  - `take`, `drop`, `take-right`, and `drop-right` length failures now report
    the required element/pair count and print the original offending value.

- `checkers.rkt`:
  - `$match:error` now raises a catchable `exn:fail` value instead of raising a
    plain string. Racket uses the more precise `exn:misc:match` subtype with
    value and source-location fields; WebRacket still needs that subtype if
    code depends on `exn:misc:match?` or `prop:exn:srclocs`.
  - `$check-mlist` now rejects ordinary immutable pairs and accepts only null or
    mutable pairs at the initial `in-mlist` check, matching Racket now that
    WebRacket has `$MPair` support. It does not pre-walk the whole mutable-list
    tail; improper mutable tails still fail later through the relevant mpair
    accessor, as in Racket.

- `io-handlers.rkt`:
  - The intentionally unsupported `read` and `read-syntax` stubs now raise
    catchable `exn:fail:unsupported` values with `read:` / `read-syntax:` in the
    message instead of encoding the unsupported reader as an argument contract.
  - `environment-variables-ref` now raises catchable contract errors for bad
    environment-variable sets and malformed byte-string names instead of
    returning the internal `$error` sentinel.

- `parameters.rkt`:
  - `current-environment-variables` now raises a catchable
    `environment-variables?` contract error for bad setter values instead of
    returning the internal `$error` sentinel.
  - `current-print` now raises a catchable
    `(procedure-arity-includes/c 1)` contract error for non-procedures and
    zero-arity procedures instead of returning the internal `$error` sentinel.

- `control-flow.rkt`:
  - `dynamic-require` without a fallback thunk now raises a catchable
    `exn:fail:unsupported` value with `dynamic-require:` in the message instead
    of encoding unsupported dynamic module loading as an argument contract. Bad
    fallback-thunk values remain ordinary contract errors.

- `namespaces.rkt` and `linklet-instances.rkt`:
  - Missing namespace and instance bindings now raise catchable
    `exn:fail:contract:variable` values with the missing symbol in the
    variable-id field instead of logging and trapping.
  - Reassigning an instance variable marked constant now raises a catchable
    contract error instead of logging and trapping.

- `treelists.rkt`:
  - Positive out-of-range indexes for `treelist-ref`, `treelist-set`,
    `treelist-insert`, and `treelist-delete` now raise catchable range-style
    contract errors with the bad index, valid range, and treelist length.
  - Negative index arguments for public treelist index and split helpers now
    preserve the original negative value in catchable
    `exact-nonnegative-integer?` contract errors. The focused
    `test/test-treelist-errors.rkt` generated-output fixture covers this.

- `vectors.rkt`:
  - Positive out-of-range element indexes for `vector-ref`, `vector-set!`,
    `vector*-ref`, `vector*-set!`, and `vector-set/copy`, plus positive
    out-of-range slice counts for `vector-take`, `vector-drop`,
    `vector-take-right`, `vector-drop-right`, `vector-split-at`, and
    `vector-split-at-right`, now raise catchable range-style contract errors
    with the bad index, valid range, and vector.
  - `vector-copy`, `vector-copy!`, `vector->values`, `vector-sort`, and
    `vector-sort!` now distinguish start-index, end-index, end-before-start, and
    target-capacity range failures with catchable Racket-style contract errors.

- `structs.rkt`:
  - `$check-struct-type` is a shared validator that receives an explicit `who`
    and already raises a catchable `(or/c #f struct-type?)` argument error.
    It does not appear to be a separate source-visible primitive; the focused
    `test/test-struct-errors.rkt` generated-output fixture covers the public
    struct constructor paths that use it.

- `random.rkt`:
  - Two-argument `random` contract errors now include the bad argument position
    and an `other arguments...` block, matching the diagnostic shape Racket
    uses for first/second argument and range failures. Formatting pseudo-random
    generators as `#<pseudo-random-generator>` is required for those messages
    to remain catchable when the other argument is a generator.

## Other Semantic Notes

- `read-bytes!` and `peek-bytes!`: an oracle run showed that Racket accepts an
  immutable byte string as the destination. Recheck the exact docs/source before
  enforcing mutability in WebRacket.

- `$growable-bytes->bytes`: the current behavior stores the byte count in the
  `$Bytes` immutable field. That looks suspicious but was deliberately preserved
  during the core-runtime split; fix it as a separate semantic change with a
  targeted test.

- Module fingerprints: computing a fingerprint by writing the whole module to a
  string and then hashing the string is expensive. Prefer computing the hash at
  the same time the WAT text is written, or cache the serialized text if it must
  be materialized.

- V8 single-code-object limit: full `test-basics` can produce a Wasm module that
  is too large for V8's default single-code-object limit. Use the chunked
  no-stdlib runner for regular validation, and only rely on a V8 size flag after
  verifying the exact flag with the Node/V8 version in use.
