# Core Runtime Migration Notes

This file collects behavior that looks suspicious during the
`runtime-wasm.rkt` to `runtime-wasm/core/*.rkt` migration, but was
preserved intentionally to keep organizational moves separate from
semantic fixes.

When moving a helper into core:

- Preserve the existing behavior first.
- Add or keep a test that pins the current behavior, even if it looks odd.
- Record the concern here.
- Fix semantics in a later, focused change with its own minimal repro or
  behavior test.

For all primitives, the target behavior is proper Racket exceptions on
errors. Existing primitive implementations that only trap with a
WebAssembly exception are migration debt from an earlier bootstrap stage,
not behavior to carry forward into core support. Internal trusted helpers
may still use traps for impossible invariants, but primitive-facing error
paths should report Racket errors.

## Preserved Behavior To Revisit

### `$growable-bytes->bytes` Sets `$Bytes` Immutable Field To Byte Count

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/growable-bytes.rkt`
- previously in `pkgs/webracket-lib/compiler/runtime-wasm.rkt`

Current behavior:

- `$Bytes` is defined with fields `(hash immutable bs)`.
- `$growable-bytes->bytes` constructs `$Bytes` as:
  - `hash = 0`
  - `immutable = n`
  - `bs = copied byte array`
- Here `n` is the current byte count, not a boolean-like immutable flag.

Why this was preserved:

- The core split was intended to move code without changing runtime
  semantics.
- Changing this during the move would mix a semantic fix into an
  organizational refactor.
- The split-link test `growable_bytes_to_bytes_immutable_field` currently
  pins the existing behavior by expecting the byte count.

Follow-up:

- Confirm whether `$growable-bytes->bytes` should return mutable bytes
  (`immutable = 0`) or immutable bytes (`immutable = 1`).
- If the current behavior is wrong, fix the constructor and update the
  pinned split-link expectation in `core-runtime.rkt`.

## Deferred Migration Boundaries

These helpers remain in `runtime-wasm.rkt` because moving them cleanly
requires broader list, error, or decoding support in core:

- `$list->array`
- `$list->i32array`
- `$list->i8array`
- `$i8array->string`

Before moving the list conversions, add or move enough error support for
proper Racket exceptions. Do not make the new core list conversion paths
trusted unchecked helpers just to make the migration easy.

## Performance Notes

### Module Fingerprints Should Not Serialize And Throw Away WAT Repeatedly

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm.rkt`

Concern:

- `module-fingerprint` used to compute a SHA1 by writing a module to a
  string, converting that string to UTF-8 bytes, hashing the bytes, and then
  discarding the serialized module.
- Full module serialization is expensive, especially during tree-shake and
  runtime analysis where the module can be large.
- The same general serialization work also happens when the driver writes the
  final `.wat` file.

Follow-up:

- Prefer computing hashes and byte counts from the same serialized bytes/text
  that are already needed for output.
- The stable-runtime analysis cache key is needed before the final `.wat` file
  is written, so it cannot simply be delayed until driver output time without
  changing the cache lookup order. If that fingerprint remains necessary,
  keep the serialization explicit and avoid extra string-to-bytes copies or
  repeated full-module writes.
