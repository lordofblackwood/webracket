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

### `$raise-check-symbol` Still Needs Caller-Specific `who`

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/symbols.rkt`
- callers in `core/paths.rkt`, `core/namespaces.rkt`, and `core/linklets.rkt`

Current behavior:

- Public symbol primitives now route their argument checks through helpers that
  take an explicit `who`.
- The shared `$raise-check-symbol` helper remains a trap-style placeholder
  because it is used by several other domains whose correct end-user `who`
  differs by caller.

Follow-up:

- Replace each remaining `$raise-check-symbol` caller with a caller-specific
  symbol contract error.
- Avoid giving `$raise-check-symbol` a single generic `who`; that would make
  the error catchable, but would report misleading messages for paths,
  namespaces, and linklets.

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

### Some Byte-Oriented Port Range Decoders Still Treat Negative Fixnums As Unsigned

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/ports.rkt`

Current behavior:

- Several port range paths decode start/end/skip indexes with unsigned
  `i31.get_u` and `i32.shr_u`.
- The string-buffer paths for `read-string!`, `peek-string!`, and
  `write-string` now use signed fixnum decoding and raise caller-specific
  `exact-nonnegative-integer?` contract errors for negative indexes.
- The byte-buffer paths for `read-bytes!`, `read-bytes-avail!`,
  `read-bytes-avail!*`, `peek-bytes!`, `peek-bytes-avail!`,
  `peek-bytes-avail!*`, and `write-bytes` now use signed fixnum decoding and
  raise caller-specific index/range errors.
- `get-output-bytes` now handles its special port-content range messages and
  accepts `#f` as the optional end index.
- The allocation wrappers `peek-bytes` and `peek-string` now use signed
  fixnum decoding and raise caller-specific count/skip errors.
- The allocation wrappers `read-bytes` and `read-string` now use signed fixnum
  decoding and raise caller-specific count errors.
- Single-value peek wrappers `peek-byte` and `peek-char` now use signed fixnum
  decoding and raise caller-specific skip errors.

Follow-up:

- Continue replacing unsigned decode patterns in remaining primitive-facing
  port range paths with signed fixnum decoding.
- Raise caller-specific `exact-nonnegative-integer?` contract errors for
  negative indexes, preserving the primitive `who`.

### Immutable Byte/String Input Destinations Are Mutated By Port Reads

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/ports.rkt`

Current behavior:

- The public byte-buffer wrappers accept immutable byte strings as
  destinations and mutate their backing arrays. The affected wrappers are
  `read-bytes!`, `read-bytes-avail!`, `read-bytes-avail!*`, `peek-bytes!`,
  `peek-bytes-avail!`, and `peek-bytes-avail!*`.
- `read-string!` and `peek-string!` likewise accept immutable strings as
  destinations and mutate their backing arrays.

Oracle observation:

- In Racket, `bytes-set!` rejects immutable byte strings with an
  `(and/c bytes? (not/c immutable?))` contract.
- In the oracle runs performed during the port error work, `read-bytes!` and
  `peek-bytes!` accepted immutable byte strings as destinations. This is
  quirky but intentional to record: destination immutability is not treated
  the same way here as it is by `bytes-set!`.
- The accepting behavior was observed with byte strings created by
  `bytes->immutable-bytes`.
- In Racket, `string-set!` rejects immutable strings with a `mutable-string?`
  contract, but the oracle runs showed `read-string!` and `peek-string!`
  mutating immutable strings created with `string->immutable-string`.
- WebRacket used to reject these destinations with trap-style
  `$raise-expected-mutable-bytes` and `$raise-immutable-string` calls.
  Removing those checks matches Racket and avoids replacing them with incorrect
  mutable-destination contract errors.

Follow-up:

- Keep generated-output tests for the byte/string read and peek wrappers so
  later mutability cleanups do not accidentally reintroduce this trap path.

## Runtime-Only Core Boundaries

These helpers have moved out of `runtime-wasm.rkt` into themed core modules,
but they still live in runtime-only helper groups because moving them into the
standalone core runtime cleanly requires broader list, error, bytes/string, or
decoding support in core:

- `$list->array`
- `$list->i32array`
- `$list->i8array`
- `$i8array->string`
- `$mcar`
- `$mcdr`
- `$set-mcar!`
- `$set-mcdr!`

Current owners:

- `core/arrays.rkt` owns `$list->array`.
- `core/i32-arrays.rkt` owns `$list->i32array`.
- `core/i8-arrays.rkt` owns `$list->i8array`, `$i8array->string`,
  `$i8array->bytes`, and `$i8array->immutable-bytes`.
- `core/mlists.rkt` keeps the pure `$mpair?` and `$mcons` helpers in
  standalone core, while mutable-pair accessors and mutators remain
  runtime-only so they can raise Racket contract errors with caller-specific
  `who`.

Before moving the list conversions into standalone core emission, add or move
enough error support for proper Racket exceptions. Do not make the new core
list conversion paths trusted unchecked helpers just to make the migration
easy. Before moving `$i8array->string` into standalone core emission, account
for its dependency on byte/string UTF-8 decoding support.

## Performance Notes

### Module Fingerprints Should Not Serialize And Throw Away WAT Repeatedly

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm.rkt`

Concern:

- `module-fingerprint` originally computed a SHA1 by writing a module to a
  string, converting that string to UTF-8 bytes, hashing the bytes, and then
  discarding the serialized module:

  ```racket
  (define (module-fingerprint module)
    (bytes->hex-string
     (sha1-bytes
      (string->bytes/utf-8
       (with-output-to-string
         (lambda ()
           (write module)))))))
  ```

- The current implementation avoids the intermediate string by writing to
  bytes, but it still serializes the module only to hash it.
- Full module serialization is expensive, especially during tree-shake and
  runtime analysis where the module can be large.
- The same general serialization work also happens when the driver writes the
  final `.wat` file.
- Treat the `with-output-to-string` shape above as a regression if it reappears:
  writing a large module to a string, converting it to bytes, and then throwing
  the string away adds avoidable allocation pressure.

Follow-up:

- Prefer computing hashes and byte counts from the same serialized bytes/text
  that are already needed for output.
- The tempting cleanup is: serialize once when writing the `.wat` file, compute
  the SHA1 from those bytes, and then write those same bytes. That is the right
  shape for fingerprints or metrics about the final emitted module.
- For the final program module, yes: if the driver needs a fingerprint,
  byte count, or other output metric, compute it in `write-wat-to-file` from
  the same serialized WAT text/bytes that are written to disk.
- The stable-runtime analysis cache key is needed before the final `.wat` file
  is written, so it cannot simply be delayed until driver output time without
  changing the cache lookup order. If that fingerprint remains necessary,
  keep the serialization explicit and avoid extra string-to-bytes copies or
  repeated full-module writes.
- In particular, do not assume the stable-runtime module and the emitted WAT
  file are the same serialization point. The stable-runtime cache hashes a
  runtime-only analysis module before tree shaking finishes; the driver later
  writes the final program module after pruning and program forms have been
  composed.
- If stable-runtime analysis still needs a module-content fingerprint, compute
  it from a single serialized representation produced at the analysis boundary.
  Do not serialize the same runtime module once for the hash and again for a
  later write/debug path.
- Output-time reuse is still a good target for final-module diagnostics. Any
  metric or fingerprint that describes the final emitted module should be
  computed while `driver.rkt` serializes the `.wat` file, rather than by
  serializing the final module once for measurement and then again for output.
- A good shape for a later cleanup is to serialize each relevant module once,
  keep the serialized bytes/text together with its hash and byte count, and
  write that already-computed serialization when the `.wat` file is emitted.
