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

Recent semantic cleanup:

- `module-call-with-prompt` now reports the unsupported module-prompt
  runtime path as `exn:fail:unsupported`, not as a thunk argument contract
  error.
- `s-exp->fasl` now reports values outside the current FASL encoder surface
  as `exn:fail:unsupported` with a `s-exp->fasl` message prefix.
- `make-reader-graph` now reports unsupported cyclic reader-graph and hash
  placeholder inputs as `exn:fail:unsupported`.
- `read-byte` and `read-char` now reject non-input-port values with
  caller-specific `input-port?` contract errors.
- `read-byte-or-special`, `read-char-or-special`, `peek-byte-or-special`,
  and `peek-char-or-special` now validate their wrapper-only optional
  arguments before delegating to the plain byte/character operations.
- `read` and `read-syntax` still raise unsupported-reader exceptions for
  valid ports, but now report `input-port?` contract errors for bad ports.
- Default read/write/display/print handlers now validate their port arguments
  and the print-handler quote depth with default handler `who` names.
- Focused generated-output coverage now includes public box-family errors
  and system/runtime helper argument errors.
- Regexp and byte-regexp constructors now validate source argument types
  before building literal regexp values, avoiding raw Wasm cast traps.

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

### Some VFS Buffer Overflow Guards Still Trap

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/filesystem.rkt`
- shared `$raise-string-buffer-overflow` in
  `pkgs/webracket-lib/compiler/runtime-wasm/core/strings.rkt`

Current behavior:

- VFS path-buffer overflow guards now raise catchable contract errors that
  include the filesystem operation `who`.
- VFS file-content reads and `webracket-vfs-write-file` content-size guards
  now raise catchable `exn:fail:out-of-memory` errors with the operation `who`
  and path.
- Multi-path filesystem operations now report oversized destination paths with
  caller-specific path-too-long contract errors.
- Some related fixed-buffer guards still call `$raise-string-buffer-overflow`,
  including low-level buffer-availability checks and fixed FASL result buffers.

Follow-up:

- Replace remaining primitive-facing `$raise-string-buffer-overflow` paths with
  caller-specific Racket exceptions.
- Distinguish path-buffer failures from file-content buffer failures in the
  error message.

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

### Some Peek Wrappers Still Do Not Support Custom Input Ports

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/ports.rkt`

Current behavior:

- `peek-bytes!`, `peek-string!`, `peek-bytes`, and `peek-string` still require
  string-backed input ports internally.
- Passing a custom input port to these wrappers now raises a catchable
  `exn:fail:unsupported` with the correct primitive `who` instead of falling
  through to a WebAssembly trap.
- Racket can use custom-port peek procedures for these operations, so this is a
  runtime capability gap rather than final semantics.

Follow-up:

- Add custom-input-port dispatch for the affected peek wrappers.
- Once custom peeking is implemented, replace the pinned unsupported-error test
  with successful custom-port behavior tests.

### `number->string` Treats Explicit `#f` Radix As Omitted

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/numbers.rkt`

Current behavior:

- `$number->string` accepts `#f` for the optional radix position and treats it
  as the default radix 10.
- This preserves the current compiled optional-argument convention: missing
  radix is normalized to `#f` inside the runtime helper.
- Racket rejects an explicit `#f` radix with a contract error, but WebRacket
  currently cannot distinguish an omitted radix from an explicit `#f` at this
  helper boundary.

Baseline observation:

- Before replacing the raw error stubs in this area, the committed runtime
  accepted `(number->string #f)` and `(number->string 1 #f)` without raising a
  catchable contract error. A value probe printed `(15 1)`, corresponding to
  strings `"15"` and `"1"`.
- The first behavior is a representation bug: `#f` is an immediate `i31`, so
  `$number->string` must check the low bit before treating an `i31` as a
  fixnum. That path now raises a `number?` contract error.
- The explicit-`#f` radix behavior is preserved for now because fixing it
  requires changing optional-argument lowering or the primitive wrapper
  convention, not only replacing runtime error stubs.

Follow-up:

- Give optional primitive wrappers a way to distinguish an omitted argument
  from an explicitly supplied `#f`.
- Once that boundary can distinguish the two cases, make `(number->string 1
  #f)` raise the Racket-compatible radix contract error.

### Optional Primitive Padding Can Obscure Offending Values

Location:

- `pkgs/webracket-lib/compiler/compiler.rkt`
- runtime helpers for optional primitives, observed with
  `namespace-set-variable-value!`

Current behavior:

- Optional primitive calls are padded with `$missing` so direct Wasm calls can
  use a fixed helper signature.
- Some runtime helpers have source-level argument conventions that do not line
  up with the raw helper argument order.
- After replacing `$raise-check-symbol`, the
  `namespace-set-variable-value!` wrong-symbol path is catchable and reports
  the correct `who` and expected `symbol?` contract, but one source-level arity
  shape reports `given: #<missing>` instead of the original bad argument.

Follow-up:

- Audit optional primitive wrappers whose helper argument order differs from
  source-level order.
- Prefer wrapper-specific validation before padding or pass enough metadata for
  runtime helpers to report the source-level offending value.

### Mutable Pairs in Formatted Error Values

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/formatting.rkt`
- error paths that call `$raise-argument-error1` with an offending value that
  contains mutable pairs

Status:

- Fixed. `$format/display` and `$format/write` now render `$MPair` values, so
  malformed hash constructor association lists containing `(mcons 'x 'y)` raise
  catchable contract exceptions instead of trapping while rendering `given`.
- The formatter follows Racket's default `print-mpair-curly-braces` behavior for
  ordinary write/display output, for example `{x . y}`.

Follow-up:

- Racket's internal error-value renderer can print mutable pairs in constructor
  notation for `~e`, for example `(mcons 'x 'y)`. WebRacket's bootstrap
  formatter still implements only a subset of full `format`/error-value
  rendering, so this is a formatting-parity follow-up rather than a remaining
  trap.

### Exception Handler Validation Is Eager

Location:

- `pkgs/webracket-lib/compiler/runtime-wasm/core/exceptions.rkt`

Current behavior:

- `catch`, `catch*`, and `call-with-exception-handler` now raise catchable
  contract exceptions instead of trapping when an existing procedure validation
  path fails.
- Some validations are still eager. For example, Racket allows
  `(with-handlers ([42 values]) 'ok)` and
  `(call-with-exception-handler 42 (lambda () 'ok))` to return normally because
  the bad predicate/handler is never applied. WebRacket currently validates
  these paths before running the body.

Follow-up:

- Move predicate/handler procedure checks to the point where the exception path
  actually applies them, while still reporting the correct `who` and offending
  value when an exception does force the bad predicate or handler.

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

### Split Sidecar Program-Only Fast Path Depends On Filtered FFI Initializers

An attempted optimization extended the split-runtime program-only fast path from
`--split-runtime-cache-reference` to ordinary sidecar `--split-runtime` builds
when the stable core wasm cache was warm. The cache preconditions were good:
boundary metadata existed, the stable core wasm existed, and the program was
compatible with that boundary.

The resulting sidecar program failed to assemble with an unknown `$js-global-this`
function. The generated program module still contained FFI primitive procedure
initialization for globals such as `$prim:js-global-this`, but the corresponding
host import/function was not present in that program-only sidecar shape.

The root cause was that normal entry generation captured
`entry-ffi-primitive-initializer-forms` before
`runtime-ffi-state-filter-current-bindings!` had selected the active FFI
bindings. The existing reference-only fast path avoided the stale initializer
list by recomputing FFI primitive initializer forms from the filtered
`ffi-state`. Program-only sidecar generation now uses that filtered initializer
shape too.

The sidecar fast path still must be guarded by a stable core wasm cache hit.
If the stable core wasm is missing or provider-cache forcing is enabled, the
compiler has to build the full runtime module so the sidecar can be assembled.

### Core Allocation Ticks Cannot Depend On JS Logging

`$debug-allocation-tick` is now standalone-core-safe. It still updates the
shared debug allocation counters and traps when an explicit allocation budget is
exhausted, but it no longer calls `$js-log` to print the budget-exhausted marker
and counter list.

That logging path depends on the full FASL/JS callback bridge and would keep
otherwise-simple constructors pinned to the program/runtime-local module. If the
allocation-budget probe needs formatted output in split mode, add a runtime-only
wrapper or host-side inspector that logs before/after enabling the budget; do
not put `$js-log` back into the hot tick helper.

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

### Module-Bridge Frontend Syntax Cache Is Not A Useful Warm-Cache Shortcut Yet

Location:

- `pkgs/webracket-lib/compiler/driver.rkt`
- `pkgs/webracket-lib/compiler/compiler.rkt`

Concern:

- A July 2026 experiment temporarily allowed `--frontend-cache` for module
  inputs. The generated program still ran correctly on
  `test/test-module-read-demand.rkt`, but the warm split-runtime
  cache-reference compile got slower.
- The cache-reference compile reported `frontend-cache-mode:
  enabled-module-input`, missed the frontend cache, and then spent about 5.8s
  in `frontend-cache-write`. That pushed the compile pipeline to about 21.6s,
  compared with about 15.6s after the compact WAT writer and with the module
  frontend cache disabled.
- The existing guard in `driver.rkt` that disables the frontend cache for
  module inputs should stay in place until the cache key is made stable and
  cheap for module-bridge syntax.

Follow-up:

- If we revisit this, do not cache serialized post-unexpand syntax directly
  for module-bridge inputs. Prefer a provider/object cache or a split-provider
  Wasm boundary that avoids recompiling stable provider code instead of
  serializing replayed generated binding identities.

### Split Runtime Procedure Boundary Requires Identical Shared Types

Location:

- `tools/check-split-runtime-procedure-boundary.rkt`
- `pkgs/webracket-lib/compiler/runtime-wasm/split-runtime.rkt`
- `pkgs/webracket-lib/compiler/runtime-wasm/shared-types.rkt`

Observation:

- A minimal two-module Wasm-GC check now verifies that a procedure allocated in
  a runtime module passes a program-side `(ref.test (ref $Procedure) ...)` when
  both modules use identical shared type declarations.
- The same check verifies that the program can pass the imported procedure
  value back to a runtime-side apply shim and get the expected result.
- This means the split-runtime design does not need to avoid cross-module
  procedure values in principle. The important invariant is that runtime and
  program modules keep the shared type prelude identical.

Current generated-provider wrinkle:

- A prototype that merged a cached read-provider fragment into the runtime core
  and retargeted the program's provider imports to that merged core still failed
  while running `test/test-module-read-demand.rkt`.
- Sharper probes showed that the imported primitive globals, imported provider
  boxes, and unboxed provider values all pass program-side `$Procedure` tests.
- Site tracing narrowed the failure to `$invoke-struct`: the read-provider code
  applies a struct named `procedure`, but `$struct-type-property-lookup` misses
  the active `$prop:procedure` descriptor and raises "application: not a
  procedure".
- The provider value itself remains a `$Procedure`; the bad value appears inside
  read-provider execution. This points at runtime-owned struct-property identity
  and initialization order, not at cross-module Wasm-GC procedure identity.
- A temporary no-entry-init program module works when the host initializes the
  merged runtime/provider module once, runs the provider entry, and then calls a
  program entry that does not re-run split-runtime initialization. The run
  prints `42` and `#<void>`.
- `tools/check-provider-runtime-split.rkt` now repeats this setup using
  reusable merge/host logic instead of hand-patched WAT. On
  `test/test-module-read-demand.rkt`, it emits a provider-augmented
  `runtime.wasm`, a separate stripped `program.wasm`, initializes runtime once,
  calls `"provider-entry"`, and the program output is `42` and `#<void>`.

Follow-up:

- Keep `tools/check-split-runtime-procedure-boundary.rkt` as the small ABI
  guard before changing shared type generation or split-runtime import/export
  shape.
- For provider-fragment split work, preserve the invariant that runtime-owned
  state is initialized exactly once before provider fragments build runtime
  structs that carry properties such as `prop:procedure`.
