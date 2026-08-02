# Error Semantics Audit

This file is the working map for replacing user-facing raw WebAssembly/JS traps
with Racket exceptions. It complements `CORE-MIGRATION-NOTES.md`: the notes keep
the narrative history, while this table tracks remaining surface area.

Audit policy:

- Public primitives should turn bad user input into catchable `exn:fail:*`
  values with a useful `who`.
- Unsupported public features should raise catchable `exn:fail:unsupported`.
- Callback arguments should be checked at the public boundary when Racket's
  contract names an arity.
- Formatter/printer paths should prefer printing supported values over raising;
  fallback errors should still be catchable.
- Trusted `/checked`, unsafe, and representation-invariant helpers should stay
  fast unless a public path reaches them without validation.

Status legend:

- `good`: focused coverage exists and no known public raw-trap issue is open.
- `partial`: important paths are fixed, but the file still has known or likely
  public surface to audit.
- `pending`: not yet audited deeply enough to claim public coverage.
- `internal`: primarily trusted runtime infrastructure; raw traps may be
  acceptable invariants.
- `unsupported`: deliberately not implemented, but should raise catchable
  unsupported exceptions when public.

## Audit Table

| Core file | Public wrong-argument coverage | Callback coverage | Formatter coverage | Unsupported-feature coverage | Known internal-only traps / trusted paths | Focus / tests |
| --- | --- | --- | --- | --- | --- | --- |
| `arrays.rkt` | internal array helpers; public coverage mostly through vectors/strings/bytes | n/a | n/a | n/a | array bounds and casts are trusted callers | low; covered indirectly |
| `booleans.rkt` | good for simple predicates/values | n/a | prints as immediates | n/a | no known user-facing trap surface | low |
| `boxes.rkt` | good for public box operations and compiler-box fallback errors; box contract values route through `error-value->string-handler` | n/a | ordinary heap formatting | n/a | compiler-box helpers remain internal | `test/test-box-errors.rkt` |
| `bytes.rkt` | partial/good; broad public bytes/range/UTF-8/converter paths are covered, and byte value/index/sequence/text diagnostics route rendered values through `error-value->string-handler`; the file is large enough to keep auditing | n/a | bytes print through formatter | n/a | `/checked` byte operations stay trusted after public validation | high; `test/test-byte-*-errors.rkt` |
| `characters.rkt` | good for character predicates/conversions currently tested; character contract values route through `error-value->string-handler` | n/a | characters print through formatter | n/a | immediate decoding helpers are trusted | `test/test-character-errors.rkt` |
| `checkers.rkt` | partial; match and sequence checks now raise catchable errors; `match:error` routes the unmatched value through `error-value->string-handler` | n/a | error values depend on formatter coverage | n/a | internal predicate/checker fast paths remain trusted | `test/test-match-errors.rkt`, `test/test-sequence-checker-errors.rkt` |
| `closures.rkt` | internal closure representation, not a direct public contract surface | n/a | n/a | n/a | closure code/arity invariants are trusted by construction | low/internal |
| `control-flow.rkt` | partial; `dynamic-require` fallback contract and unsupported path are catchable | fallback thunk checked | n/a | `dynamic-require` without supported loading raises unsupported | `catch` lowering is special; do not rewrite mechanically | `test/test-control-flow-errors.rkt` |
| `equality.rkt` | mostly predicates with few argument contracts | n/a | formatter may be used for diagnostics | n/a | equality recursion/invariants need separate semantic audit | pending/low |
| `events.rkt` | partial; event and channel contracts have focused coverage | `handle-evt`, `sync/timeout` use semantic procedure checks | opaque event formatting exists for common values | n/a | sync traversal helpers assume checked event lists | `test/test-event-sync-errors.rkt` |
| `exceptions.rkt` | good as shared exception-construction foundation; message fidelity still improves incrementally | n/a | exception messages depend on formatter | n/a | helper construction may use `unreachable` after raising by design | many fixtures |
| `fasl.rkt` | pending/partial; public `s-exp->fasl` unsupported values are catchable and route rendered values through `error-value->string-handler` | n/a | FASL unsupported diagnostics depend on formatter | reader/FASL gaps should become unsupported or contract errors if public | decoder representation checks may be trusted for compiler-produced data | `test/test-misc-primitive-errors.rkt` |
| `ffi.rkt` | partial; public bridge contracts and callback exports have focused coverage | callback procedure checks use semantic `procedure?` | FFI values need useful opaque formatting | missing host features should be clear/catchable where possible | hot bridge paths must avoid per-call defensive overhead where validated once | `test/test-ffi-errors.rkt` |
| `filesystem.rkt` | good for public VFS/path callback contract ordering currently covered | file thunks/callbacks checked before path effects | path/error formatting depends on paths/formatter | unsupported real filesystem operations should be catchable | VFS table invariants remain internal | `test/test-filesystem-errors.rkt` |
| `fixnums.rkt` | good for public fx contracts currently covered; overflow/custom fixnum diagnostics route rendered numeric values through `error-value->string-handler` | n/a | numeric formatter | n/a | `unsafe-fx*` and checked fixnum helpers stay trusted | `test/test-fixnum-errors.rkt` |
| `flonums.rkt` | good for public flonum arithmetic/conversion paths currently covered | n/a | numeric formatter | n/a | unsafe flonum helpers stay trusted | `test/test-flonum-errors.rkt` |
| `formatter-error-closure.rkt` | internal support for printer error callbacks | callback behavior depends on formatter paths | partial by definition | n/a | invoked only by formatter/runtime setup | low/internal |
| `formatting.rkt` | partial; public `format`/`display`/`write` contracts, `fprintf` port validation, format argument-count errors, ill-formed pattern errors, and `~c`/`~b`/`~o`/`~x` directive errors improved, but fallback printer surface remains a major target | custom-write/custom-display paths use semantic procedure checks in current code; custom-write now receives the Racket mode arguments for `~a`, `~s`, and `~v` | partial; opaque runtime, reflection, control/parameterization, impersonator-property, date/date*, environment, graph placeholder/ephemeron, srcloc, and stencil-vector values now print; write-mode bytes/box/hash/ordinary-struct/treelist containers now preserve nested quoting; character and byte display/write modes now differ correctly for common values; `~.a`/`~.s`/`~.v` use `error-print-width`; `~e`/`~E`, shared exception value positions, and `format` bad-argument/argument-summary diagnostics now route through `error-value->string-handler`; common symbol/keyword display/write/error-message cases now use reader-facing quoting and escapes, but full reader grammar and exact struct print-as-expression behavior remain audit items; unknown values still need audit | n/a | internal formatting helpers may assert already-dispatched types | high; `test/test-format-errors.rkt` |
| `growable-arrays.rkt` | internal builder helpers | n/a | n/a | n/a | capacity/index invariants are trusted by callers | low/internal |
| `growable-bytes.rkt` | internal builder helpers | n/a | n/a | n/a | note suspicious `$growable-bytes->bytes` immutable/count field separately | low/internal |
| `growable-i32-arrays.rkt` | internal builder helpers | n/a | n/a | n/a | capacity/index invariants are trusted by callers | low/internal |
| `hashes.rkt` | partial/good for public hash contracts and higher-order callbacks | hash callbacks check semantic procedure and named arities | hash values depend on formatter | n/a | concrete mutable/immutable dispatch helpers remain trusted after public dispatch | `test/test-hash-errors.rkt` |
| `i32-arrays.rkt` | internal array helpers | n/a | n/a | n/a | trusted callers | low/internal |
| `i8-arrays.rkt` | internal array helpers | n/a | n/a | n/a | trusted callers | low/internal |
| `immutable-hashes.rkt` | partial/good through public hash wrappers | callback coverage lives mostly in `hashes.rkt` | hash formatting depends on formatter | n/a | concrete immutable hash helpers are trusted after dispatch | `test/test-hash-errors.rkt` |
| `immediates.rkt` | internal immediate constants/predicates | n/a | immediate values print elsewhere | n/a | tag decoding helpers are trusted | low/internal |
| `impersonators.rkt` | good for current intentionally unsupported public surface | n/a | opaque/unsupported diagnostics depend on formatter | `impersonator-val` raises unsupported | n/a | `test/test-impersonator-errors.rkt` |
| `io-handlers.rkt` | good for current read/handler/env-var public contracts | handler setters use semantic `procedure?` | default print/display handlers covered | `read`/`read-syntax` raise unsupported | handler invocation still trusts installed handlers | `test/test-port-input-errors.rkt`, `test/test-port-output-errors.rkt` |
| `keywords.rkt` | good for current keyword predicate/conversion/order contracts; keyword contract values route through shared `error-value->string-handler` diagnostics | n/a | keyword formatting handled in formatter | n/a | tag/struct checks trusted after public validation | `test/test-misc-primitive-errors.rkt` |
| `linklet-instances.rkt` | partial; missing/constant bindings now catchable | n/a | instance diagnostics depend on formatter | n/a | linklet instance table invariants remain internal | `test/test-linklet-errors.rkt` |
| `linklets.rkt` | partial; public-ish linklet shape/instantiate paths have focused coverage | linklet callbacks are specialized runtime calls | diagnostics depend on formatter | unsupported linklet features should be catchable | linklet application internals remain trusted | `test/test-linklet-errors.rkt` |
| `lists.rkt` | good for many public list/range/callback paths; list index/length and range diagnostics route rendered values through `error-value->string-handler`; keep auditing less-common list helpers | fixed-arity callbacks checked at wrapper boundary | list formatting depends on formatter | n/a | `/checked` traversals remain trusted | `test/test-list-errors.rkt`, `test/test-range-errors.rkt` |
| `locations.rkt` | good for current srcloc constructor/accessor contracts; srcloc contract values route through `error-value->string-handler` | n/a | source locations print as ordinary structs and through `srcloc->string` | n/a | internal location structs trusted | `test/test-location-errors.rkt` |
| `locks.rkt` | good for current public lock contract fixture; lock contract values route through `error-value->string-handler` | n/a | opaque lock formatting exists | n/a | lock state invariants internal | `test/test-lock-errors.rkt` |
| `loggers.rkt` | good for current inert logger/log-receiver contracts; contract values route through shared `error-value->string-handler` diagnostics | logger callbacks, if any, need separate audit | opaque logger formatting exists | n/a | logging queues/state internal | `test/test-logger-errors.rkt` |
| `memory-map.rkt` | internal memory layout data | n/a | n/a | n/a | no public primitive surface | internal |
| `mlists.rkt` | good for current mutable-pair accessor/mutator contracts; mutable-pair contract values route through `error-value->string-handler` | n/a | mpair formatting depends on formatter | n/a | checked mpair accessors can stay trusted after public validation | `test/test-list-errors.rkt` |
| `mutable-hashes.rkt` | partial/good through public hash wrappers and concrete fallback helpers | callback coverage in `hashes.rkt` | hash formatting depends on formatter | n/a | table-full out-of-memory path is hard to exercise; concrete helpers trusted after dispatch | `test/test-hash-errors.rkt` |
| `namespaces.rkt` | partial; namespace variable errors now catchable | n/a | diagnostics depend on formatter/symbols | unsupported namespace behavior should be explicit | `/checked` namespace table helpers trusted after validation | linklet/namespace focused rows |
| `numbers.rkt` | partial/good; broad numeric contracts, conversions, range errors, byte-string conversion, and selected numeric diagnostics route rendered values through `error-value->string-handler`; uncommon conversion corners still worth periodic audit | n/a | numeric formatting is split with `formatting.rkt` | n/a | numeric `/checked` and unsafe arithmetic helpers stay trusted | `test/test-number-conversion-errors.rkt`, `test/test-numeric-range-errors.rkt`, `test/test-range-errors.rkt` |
| `parameters.rkt` | good for current parameter setter contracts | parameter guards/handlers need public-boundary checks when arity is named | diagnostics depend on formatter | n/a | current-parameter storage invariants internal | `test/test-parameterization-errors.rkt` |
| `paths.rkt` | good/partial for path conversion and path contract fixture; path content and absolute-path diagnostics now route rendered value positions through `error-value->string-handler` | n/a | path formatting used by formatter | unsupported filesystem path behavior should be catchable | internal path byte/string helpers trusted | `test/test-path-errors.rkt` |
| `ports.rkt` | partial/good; basic input/output/string-port contracts and closed errors covered, input/output contract values plus byte/string range value positions route through `error-value->string-handler`, but full port model remains large | custom port handlers use semantic procedure checks | port values/locations depend on formatter | custom backend unsupported paths catchable | line-counting state parity intentionally not complete; internal port checked helpers trusted | `test/test-port-input-errors.rkt`, `test/test-port-output-errors.rkt` |
| `procedures.rkt` | good for many public procedure/arity/apply paths; keep special plain-struct behavior documented | procedure-valued contracts use semantic `procedure?` where public | procedure formatting improved but still tied to formatter | n/a | primitive dispatch invariants now catchable, but remain internal assertions | `test/test-procedure-errors.rkt` |
| `random.rkt` | good for current public `random` contract shapes; two-argument diagnostics route rendered bad/other values through `error-value->string-handler` | n/a | pseudo-random generators print opaquely | n/a | generator internals trusted | `test/test-random-errors.rkt` |
| `realms.rkt` | internal realm constants/helpers | n/a | n/a | n/a | no direct public primitive surface | internal |
| `reflection.rkt` | partial/good for current module-path/syntax metadata contracts | n/a | opaque reflection values now print | unsupported reflection metadata should be conservative/catchable | representation details trusted after validation | `test/test-reflection-errors.rkt` |
| `regexps.rkt` | partial; regexp constructor/match contracts have focused coverage | n/a | compact regexp values print from stored source | unsupported regexp features should raise unsupported/contract, not trap | staged provider/runtime regexp internals remain trusted | `test/test-regexp-errors.rkt` |
| `runtime-bytes-constants.rkt` | constants only | n/a | n/a | n/a | no public surface | internal |
| `runtime-constants.rkt` | constants/globals only | n/a | n/a | n/a | no public surface | internal |
| `runtime-string-constants.rkt` | constants only | n/a | n/a | n/a | no public surface | internal |
| `runtime-symbol-constants.rkt` | constants only | n/a | n/a | n/a | no public surface | internal |
| `security.rkt` | good for current security-guard/custodian public contract fixture | hook callbacks check Racket arities | opaque security values print | unsupported security behavior should be catchable | custodian/security state invariants internal | `test/test-security-errors.rkt` |
| `semaphores.rkt` | partial/good through event/semaphore fixtures | `call-with-semaphore` thunk checked | opaque semaphore formatting exists | n/a | semaphore state transitions internal | `test/test-event-sync-errors.rkt` |
| `stencil-vectors.rkt` | good for current public stencil-vector contracts; stencil-vector contract values route through `error-value->string-handler` | n/a | vector-like formatting depends on formatter | n/a | checked helpers trusted after public validation | `test/test-stencil-vector-errors.rkt` |
| `strings.rkt` | partial; broad string constructor/index/copy/trim coverage exists, but conversion and text edge cases remain high-value | `build-string` callback checked at wrapper boundary | string formatting core | n/a | string `/checked` helpers remain trusted; buffer overflow maps to out-of-memory | `test/test-string-*-errors.rkt`, `test/test-build-string-errors.rkt` |
| `structs.rkt` | partial; struct constructor/accessor/mutator contracts have focused coverage, but struct system is broad | struct property callbacks need careful public-boundary validation | struct printing still incomplete | unsupported struct features should be explicit | descriptor/layout invariants internal | `test/test-struct-errors.rkt` |
| `symbols.rkt` | good for current public symbol conversion/order/gensym contracts; symbol contract values route through shared `error-value->string-handler` diagnostics, and symbol table OOM is catchable | n/a | symbol formatting important for diagnostics | n/a | intern table insertion saturation hard to exercise | `test/test-misc-primitive-errors.rkt`; OOM path covered by source tests |
| `syntax.rkt` | partial/good for phase argument validation currently covered | n/a | syntax values should format without trapping | unsupported syntax metadata should be conservative/catchable | syntax object representation internal | `test/test-syntax-errors.rkt` |
| `system.rkt` | good for current system/env contracts in fixture; contract values route through shared `error-value->string-handler` diagnostics | n/a | diagnostics depend on formatter | unsupported host system calls should be catchable | host/env bridge internals trusted | `test/test-system-errors.rkt` |
| `threads.rkt` | good for current single-threaded thread/thread-cell/thread-group contracts; contract values route through shared `error-value->string-handler` diagnostics | thread callbacks, if exposed later, need semantic procedure checks | opaque thread formatting exists | unsupported real threading should be catchable | scheduler/thread state internal | `test/test-thread-errors.rkt` |
| `time.rkt` | good for current time/date contract fixture; date/time contract values route through `error-value->string-handler` | n/a | date/time values depend on formatter | n/a | internal time conversion trusted | `test/test-time-errors.rkt` |
| `treelists.rkt` | good for current public treelist index/range fixture | callbacks, if any, need public arity checks | treelist formatting depends on formatter | n/a | checked tree navigation trusted | `test/test-treelist-errors.rkt` |
| `unsafe.rkt` | deliberately trusted unsafe public surface | n/a | n/a | n/a | do not add defensive validation to unsafe fast paths unless a safe primitive reaches them | internal/trusted |
| `vectors.rkt` | good for current public vector index/range/callback fixture; vector range diagnostics route rendered vector values and target-size fields through `error-value->string-handler` where Racket does | named-arity callbacks checked; map/count intentionally let application report arity | vector formatting depends on formatter | n/a | checked vector helpers trusted | `test/test-vector-errors.rkt` |
| `wills.rkt` | good for current will executor/register contract fixture | `will-register` callback checked | opaque will values print | n/a | will queue internals trusted | `test/test-will-errors.rkt` |

## Current Priorities

1. Keep using large, coherent public-surface slices because generated compile/run
   time dominates edit time.
2. Next high-value implementation slices:
   - formatter/printer fallback and custom-write/custom-display edge cases;
   - remaining numeric/string/bytes conversion corners;
   - mutable-list-specific public fixture rows;
   - symbol/keyword/thread public contract audit gaps.
3. Do not mechanically replace every `unreachable`. Treat `unreachable` after a
   raise as normal Wasm control-flow plumbing, and treat `/checked`/unsafe
   helper traps as trusted until a public path proves otherwise.

## Trap-Finding Harness

Use `tools/classify-error-fixtures.py` to run generated-output fixtures and
classify failures:

```sh
python3 tools/classify-error-fixtures.py --jobs 4
```

The harness writes compile outputs and logs under `/tmp/` by default. It reports
one progress line for each completed fixture, then prints a final markdown
summary table. Use `--quiet` to suppress the progress lines. Each fixture is
classified as one of:

- `pass`: fixture compiled, ran, and did not print a failing `#f` row.
- `fixture-failure`: fixture ran but one or more rows printed `#f`.
- `uncaught-racket-exn`: an uncaught `exn:fail:*` or contract error escaped.
- `uncaught-unsupported`: an unsupported-feature exception escaped.
- `raw-wasm-js-trap`: a Wasm/JS runtime trap escaped.
- `compile-or-link-failure`: Wasm generation, validation, compilation, or
  linking failed before normal fixture execution.
- `guard-timeout` / `guard-memory`: the guarded runner stopped the command.
- `process-failure`: nonzero process exit that did not match the categories
  above.
