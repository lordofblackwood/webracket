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
  - `$raise-expected-string` is used by `linear-memory->string`, which is an
    exported Wasm/host bridge helper for FASL data. It is not currently a normal
    Racket primitive path. If host data can make this reachable, raise a
    catchable `exn:fail:contract` with `who` tied to `linear-memory->string`.
  - `$raise-expected-fixnum` is used by `$list-from-range`; public `range`
    validates arguments before choosing the fixnum/flonum implementations.
    Keep this lower priority unless a compiler fast path is found to call
    `$list-from-range` without validation.

- `mutable-hashes.rkt` and `symbols.rkt`:
  - `$raise-hash-insert:table-full` and
    `$raise-symbol-table-insert:table-full` are internal capacity failures.
    They should probably become an internal runtime error or
    `exn:fail:out-of-memory`, but they are hard to exercise from a focused
    source-level test.
  - Concrete mutable hash helper stubs such as
    `$raise-argument-error:mutable-hasheq-expected` are internal dispatch
    targets. The public generic operations already validate and raise with
    `who`. If a concrete helper becomes source-visible, add a focused test and
    give it a concrete `who`.

- `strings.rkt` and `bytes.rkt`:
  - `$raise-check-string`, `$raise-bad-string-index`, and
    `$raise-expected-mutable-bytes` appear to be legacy/unused stubs. Public
    string and bytes primitives mostly route through newer helpers that preserve
    `who`.
  - `$raise-invalid-utf8-input`, `$raise-invalid-utf8-start`, and
    `$raise-invalid-utf8-end` in `strings.rkt` appear unreferenced; the public
    `bytes->string/utf-8` path uses the byte-decoding helpers in `bytes.rkt`,
    which already raise catchable contract errors.
  - `$raise-string-copy!/checked:out-of-bounds` belongs to a `/checked` helper.
    Keep `/checked` trusted unless evidence shows a user/compiler path reaches
    it without prior validation.
  - `$raise-string-buffer-overflow` and `$bomb` are builder/internal invariant
    failures. If user input can reach them, decide whether the right exception
    is contract, unsupported, or out-of-memory before replacing the trap.

- `formatting.rkt` and struct formatting:
  - Formatter fallback stubs such as
    `$raise-format/display:unknown-datatype`,
    `$raise-format/display:pair:expected-pair`,
    `$raise-format/display:vector:expected-vector`, and
    `$raise-format/display:struct:expected-struct` are not all ordinary
    contract errors. For some values the correct Racket behavior is likely to
    add a printer instead of raising an exception.
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
  - Remaining stubs such as `$raise-arity-mismatch`,
    `$raise-primitive-invoke:unhandled-shape`, and
    `$raise-arity-error:exactly`/`$raise-arity-error:at-least` are currently
    unused placeholders or primitive-dispatch invariants.

- `numbers.rkt`:
  - The legacy `$raise-expected-number*` helpers now raise catchable
    `exn:fail:contract` values with `number?` and the offending value instead
    of logging and trapping. They still do not preserve the precise
    primitive-level `who`, because their old call sites only pass the offending
    value. A follow-up should add `who`-aware call paths for public arithmetic
    and numeric primitives.

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
