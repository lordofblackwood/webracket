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
    locks, threads, thread groups, thread cells, custodians, custodian boxes,
    and security guards now print as `#<...>` values instead of falling
    through to `$raise-format/display:unknown-datatype`. Compact regexp values
    now print from their stored source as `#rx`, `#px`, `#rx#`, or `#px#`
    forms.
  - `$raise-not-a-string` currently belongs to a commented-out `string->bytes`
    helper. Treat it as dead unless that helper is restored.

- `procedures.rkt`:
  - First-class closure/case-lambda/primitive arity errors already use
    catchable `exn:fail:contract:arity`.
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
  - Some numeric conversion helpers still use older validation shapes; audit
    those separately before claiming complete numeric parity.

- `checkers.rkt`:
  - `$match:error` now raises a catchable `exn:fail` value instead of raising a
    plain string. Racket uses the more precise `exn:misc:match` subtype with
    value and source-location fields; WebRacket still needs that subtype if
    code depends on `exn:misc:match?` or `prop:exn:srclocs`.

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
    Follow-up: several public treelist wrappers still decode index arguments
    with unsigned shifts, so negative exact indexes may be reported after
    unsigned reinterpretation instead of as the original negative value.

- `structs.rkt`:
  - `$raise-check-struct-type` is only used by `$check-struct-type`, which is
    not obviously source-visible. If a public caller is found, preserve its
    `who` and expected contract, probably `(or/c struct-type? #f)`.

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
