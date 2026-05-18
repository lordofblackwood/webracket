# WebRacket Goals

WebRacket has two related but distinct goals. Keeping them separate helps avoid
blocking useful ahead-of-time module support on the much harder problem of
browser-side `eval`.

## Goal 1: Run Module-Based Programs In The Browser

### Why

Most useful Racket programs do not need runtime `eval`. They need their module
graph expanded, compiled, linked, and executed. If WebRacket can run ordinary
module-based programs in the browser, then it can support examples, teaching
programs, demos, and many libraries without first implementing a browser-hosted
expander/compiler.

This is the practical near-term goal.

### How

Use an ahead-of-time pipeline:

```text
Racket module program
  -> host Racket expands/compiles modules to linklet-level information
  -> Webify extracts module/linklet reports
  -> Webify resolves providers, imports, exports, renames, and re-exports
  -> Webify composes module instances and module-variable cells
  -> WebRacket compiler emits Wasm-GC
  -> browser instantiates and runs the Wasm program
```

In this model, the browser does not need to expand source code or compile new
code at runtime. The host/development machine does the heavy lifting, and the
browser receives an executable WebRacket/Wasm artifact.

There are two source-language entry points:

- `#lang webracket` remains a script-compatible driver input. `webracket.rkt`
  recognizes the line and compiles the remaining forms as a top-level program.
- `#lang webracket/base` is the Goal 1 module-language path. Host Racket reads
  and expands it as a normal module using language `webracket/base`, and Webify
  can then consume the resulting module/linklet information.

For `webracket/base`, `racket/base` is the foundation: it supplies the core
module-language forms and basic runtime bindings that make ordinary modules
expand. The curated Goal 1 library surface is the layer above that foundation,
chosen from the libraries that the larger `racket` language adds around
`racket/base`.

### Current Progress

This goal is actively progressing.

Implemented or partially implemented:

- A first `#lang webracket/base` module language that host Racket reads as a
  real module, while preserving the existing `#lang webracket` script path.
- Transitional driver support for `#lang webracket/base`: the source is read
  through the normal module reader, then its module body is lowered to the
  existing top-level compiler path. This is enough for executable module-style
  programs that do not need arbitrary user `require`s yet; full provider-graph
  execution of the language module remains a deeper Goal 1 milestone.
- The driver resolves the `webracket/base` reader with Racket's normal
  collection search. It does not add checkout-specific fallback paths, so
  uninstalled development checkouts must be exposed explicitly via
  `PLTCOLLECTS`, collection links, or package installation. The transitional
  path also handles simple local string requires by inlining required
  `#lang webracket/base` sources before the root body.
- The source-level local require lowering is intentionally not growing into a
  module system. It accepts only plain local string requires for smoke tests and
  rejects richer require specs clearly. The next intended path is extracting
  local module reports and composing them through Webify's module registry.
- An opt-in `--webracket-base-module-bridge` driver path now extracts a local
  `#lang webracket/base` graph, composes it through module instances, and runs
  exports through module-variable cells. This is the replacement candidate for
  the transitional source-level lowering, but it remains behind a flag while
  the supported module subset is still small.
- Module-linklet inputs and manifests.
- Module registry, module instances, and module-variable cells.
- Import/export resolution for extracted module graphs.
- Provider graph discovery from compiled metadata.
- Handling for source-level and compiled-level renames/re-exports.
- Provider precedence rules for private providers versus broad base re-exports.
- Reflected relative provider normalization, such as resolving `"pico.rkt"` to
  `racket/private/pico`.
- Kernel-origin import handling for `#%kernel`.
- A synthetic kernel export row derived from `primitives-db.rkt`.
- A runtime-gap audit that separates "the resolver can name this primitive" from
  "runtime-wasm.rkt implements this primitive."

Recent successful smokes:

- `racket/list` graph resolution is clean.
- `racket/string` graph resolution is clean.
- Installed-module runtime smokes pass for selected uses of `racket/bool`,
  `racket/fixnum`, `racket/list`, `racket/string`, `racket/vector`, and
  `racket/function`; selected `racket/set` operations now instantiate and run.

Known remaining work:

- Grow the set of installed modules and libraries that compile and run.
- Use the runtime-gap audit to prioritize missing Wasm primitives.
- Avoid adding broad runtime support just because a primitive appears in a graph;
  prioritize primitives that are actually executed by useful programs.
- Continue improving diagnostics so failures classify as graph-resolution,
  unsupported-runtime, compiler, or runtime errors.

### `webracket/base` Library Shape

The first `webracket/base` milestone should not claim that every binding
exported by full `racket/base` already executes correctly in WebRacket. It uses
`racket/base` as the module-language foundation, then grows a deliberately
tested library surface.

Good initial add-on candidates are the libraries already represented in Goal 1
smokes or close to the current browser runtime:

- `racket/bool`, `racket/bytes`, `racket/dict`, `racket/format`,
  `racket/function`, `racket/include`, `racket/list`, `racket/local`,
  `racket/match`, `racket/math`, `racket/path`, `racket/port`,
  `racket/promise`, `racket/sequence`, `racket/set`, `racket/shared`,
  `racket/stream`, `racket/string`, and `racket/vector`.

Libraries that should remain separate milestones for now are the ones that pull
harder on contracts, OS services, networking, parallelism, or larger object
systems:

- `racket/class`, `racket/cmdline`, `racket/contract`, `racket/file`,
  `racket/future`, `racket/place`, `racket/pretty`, `racket/system`,
  `racket/tcp`, `racket/udp`, and `racket/unit`.

The for-syntax surface should include the `racket/base` compile-time bindings,
because ordinary module expansion expects them. Additional for-syntax exports
should be added only when a concrete module-language smoke needs them.

### `#lang webracket/base` Driver Cutover

The transitional source-level lowering should be deleted only after the module
bridge path is the normal driver path for the supported subset. The cutover
criteria are:

- Local graph extraction works from a root `#lang webracket/base` file and
  follows plain local string requires without checkout-specific collection
  fallbacks.
- The extracted reports compose through `webify-module-registry` with
  `module-protocol` included explicitly.
- Runtime driver smokes run local module graphs through module-variable cells,
  not through textual flattening.
- Unsupported forms fail clearly at graph extraction or provider resolution.
- The bridge has enough provider coverage for the current `webracket/base`
  supported subset.

Current bridge readiness:

- Passing: simple local require, flattening-vs-bridge parity for the simple
  local require case, `only-in`, `rename-in`, `prefix-in`, shared local
  dependencies, one local re-export hop, and a staged `format` provider smoke.
- Passing metadata discovery: local dependencies are recovered from the
  expanded/compiled import map instead of raw source require syntax. A
  `define-require-syntax` smoke confirms that a require transformer expanding
  to a local file is discovered without driver-side knowledge of the custom
  require form.
- Passing provider route check: collection/provider requires are not treated as
  local files by graph extraction. The driver bridge can select a discovered
  registry with an in-memory provider report cache and demand-slice the
  required provider graph when compiled reports demand providers outside the
  ordinary `#lang webracket/base` language root.
- Default candidate matrix:
  `local-only` passes through both the old transitional path and the bridge;
  `provider-free staged helpers`, such as the current `format` provider smoke,
  remain on the fast closed-local bridge route; `provider-only` and
  `local+provider` currently route to discovered-provider composition but are
  too slow for default runtime smokes with `racket/list`; richer
  phase/import-provider graphs remain unsupported.
- Current provider-discovery instrumentation:
  the bridge classifier now has focused tests for language-root-only,
  local-only, and external `racket/list` demand shapes. Verbose driver mode
  reports per-provider fetch timing for the discovered-provider path. A narrow
  resolver rule maps compiled `1/syntax-source` imports to
  `webracket/primitives`, avoiding the previous ambiguity with `racket/linklet`.
  A discovery-only smoke composes a tiny `racket/list` provider report for the
  single `first` export without running a full WebRacket runtime compilation.
  Provider-cache hit/miss counters are tracked for this path, and a small
  provider-trial manifest now covers discovery-only demand checks for clusters
  in `racket/list`, `racket/string`, and `racket/bool`. The manifest is also
  the temporary allowlist for external providers in the bridge. A provider
  trial dashboard reports resolved inputs, primitive-demand counts,
  missing-primitive counts, primitive ownership, and cache hit/miss totals.
  It also reports demand-sliced versus full extracted closure sizes and can
  cache dashboard summaries on disk for fast repeated inspection.
  First attempts to promote allowlisted real providers to full runtime smokes
  still hit the 120-second child bound, so runtime promotion remains a
  performance/composition milestone rather than a completed default smoke.
  A bounded phase probe now shows the immediate timeout frontier for the
  `racket/list`, `racket/string`, and `racket/bool` trials is provider-graph
  discovery, before module composition, WebRacket compilation, Wasm assembly,
  or JavaScript execution. The same probe can print per-provider trace rows,
  grouped trace counters, and stop at a provider frontier limit. The first
  `racket/bool` probe produced more than 21k provider trace events, mostly
  cached `unresolved-import-candidate` checks. Candidate-report memoization
  reduced the 10-second traces for the three trial modules to about 1.9k-2.0k
  rows, but they still timed out at the provider-discovery stage. The bridge now
  cuts `webracket/base` language-root providers during external discovery by
  default. With that policy, the bounded phase probe reaches `compile-to-wat`
  for `racket/bool`, `racket/list`, and `racket/string`; provider discovery is
  roughly 0.5s for `racket/bool` and 1.5s for the list/string trials on the
  current machine. The probe also prints a local/language-root/external demand
  split, so future graph growth is easier to attribute.
- Default-switch policy: keep `--webracket-base-module-bridge` opt-in for now,
  but treat the local-only bridge as the preferred candidate. The remaining
  blocker is provider-graph performance and ambiguity, not local module
  semantics.
- Still intentionally unsupported in the bridge graph extractor: richer local
  phase/import-provider composition in the driver path.

The machine-readable tracking source for this surface is
`webify/webracket-base-surface.rkt`. Its status rows intentionally separate:

- `exported`: the library is re-exported by `webracket/base`.
- `extracts`: a representative module can be read/expanded and Webify can
  extract module/linklet metadata.
- `composes`: the provider graph can be composed into module instances and
  export cells.
- `runs`: representative compiled code reaches the WebRacket runtime smoke.

Some syntactic libraries, such as `racket/include`, `racket/local`, and
`racket/shared`, are tracked as `host-only` runtime rows because their main
effect is during host expansion.

### Current Goal 1 Supported Subset

The supported Goal 1 path is intentionally ahead-of-time:

- Source modules are expanded and lowered on the host Racket side.
- Webify extracts phase-0 runtime linklet inputs and provider metadata.
- Webify composes a closed module graph into module instances and export cells.
- WebRacket compiles the composed program to Wasm-GC and runs it in the browser.

The browser-side runtime is not expected to expand source, compile new code, or
answer arbitrary collection/module lookup questions. Kernel services such as
syntax serialization, syntax binding-set construction, collection lookup, and
syntax-error construction may be resolvable as metadata names, but they are
explicitly unsupported runtime services unless a Goal 1 program actually needs a
real implementation.

This boundary is useful: it keeps ordinary module programs moving without
accidentally turning Goal 1 into Goal 2.

Current installed-extraction runtime smokes cover:

- Must-have Goal 1 library families now tracked in the dependency matrix:
  `racket/set`, `racket/sequence`, `racket/match`, `racket/format`,
  `racket/promise`, `racket/class`, immutable hashes, and `for`/`for*` forms
  from `racket/base`. Use
  `webify/probe-installed-module-deps.rkt --goal1-dashboard` for the compact
  dependency view, or `--goal1-compact` when a script-friendly table is enough.
  For longer runs, prefer the bounded parallel form, for example
  `--goal1-compact-bounded --goal1-limit 50 --timeout 120 --memory-mb 1024
  --jobs 4`. Bounded progress lines start with `#`, so the TSV rows remain
  readable while the run still shows which child cases are active.
- `racket/bool`: `boolean=?`.
- `racket/fixnum`: `fx+`.
- `racket/list`: `first`, `rest`, `add-between`, `range`, `reverse`, and a
  combined `take`/`map` use with `racket/string`.
- `racket/string`: `string-join` and `string-prefix?`.
- `racket/vector`: `vector-member`, plus a combined `racket/vector` and
  `racket/list` provider-graph smoke.
- `racket/set`: a require-only source module instantiates and returns a normal
  value, and operation smokes now run too: `set?`, `set-count`, `set-member?`,
  `set-add`, `set-remove`, `set-union`, `set->list`, `set-intersect`,
  `set-subtract`, `set-symmetric-difference`, `set-map`, and the
  `racket/private/set-types` predicate case. Retiring this frontier required
  small runtime pieces that the provider graph actually executes: port
  struct-type-property identities, the unsafe struct-property constructor
  alias, syntax-literal placeholders for serialization metadata,
  `current-load-relative-directory`, `prop:custom-print-quotable`,
  `procedure-arity?`, and the documented immutable hash association-list
  constructors.
- `racket/stream`: `stream-first` and `stream-rest`.
- `racket/hash`: an immutable hash constructor, functional `hash-set`,
  `hash-ref`, and immutable hash traversal through `hash-keys`, `hash-values`,
  `hash->list`, `hash-for-each`, `hash-map`, and `hash-clear`. The current
  comparator coverage checks the public hash-kind predicates; full duplicate
  behavior for non-symbol equal?/eqv?/eq? keys remains a separate semantic
  milestone.
- `racket/pretty`: a require-only installed-provider smoke.
- `racket/promise`: require-only, `promise?` on a plain value, `force` identity
  on a non-promise, `force` of a simple `delay`, and the basic
  `promise-forced?`/`promise-running?` state predicates.
- `racket/sequence`: `sequence->list` over a plain list, `in-range`,
  `for/list`, `for/fold`, and `for/vector` coverage in the Goal 1 matrix.
- `racket/base` `for` forms: `for/list`, `for/fold`, `for*/list`, and
  `for/first` source-module cases are tracked as must-have iteration coverage.
  The explicit producer matrix includes `in-list`, `in-vector`, `in-string`,
  `in-range`, bounded `in-naturals`, parallel sequence clauses, nested
  `for*/list` clauses, and `#:when`/`#:unless`/`#:break` control clauses.
- `racket/match`: a basic list pattern, a default branch, `match-let`, and a
  predicate pattern are tracked in the Goal 1 matrix.
- `racket/class`: a basic object with a public method.
- `racket/function`: `compose`, `identity`, `compose1`, `negate`, and `const`.
- Combined installed-library programs for `racket/list` + `racket/string`, for
  `racket/list` + `racket/string` + `racket/set`, and for a multi-module local
  source graph whose providers require those installed libraries separately,
  including a provider re-export graph.
- Dependency-first local source modules with quoted sibling requires, such as
  `(require 'base-values)`, through a shared-provider transitive smoke.

`racket/format` is the active next-library frontier. `webracket/base` exports
the common format surface through the staged `io/format` provider path, while
the old textual stdlib formatter is being retired. For now, keep the frontier
focused on `format`, `fprintf`, `printf`, `eprintf`, and common `~a`/`~s`/`~e`
paths; postpone full `~v` coverage until the ordinary format bridge is stable.
A `#lang webracket/base` driver smoke now verifies provider-backed `format`
with `~a`, `~s`, and `~e`.

Current local-manifest runtime smokes cover hand-authored bridge shapes that do
not depend on source extraction:

- Two-module provider/consumer composition.
- Re-export graphs that use the backing provider cell.
- Renamed imports.
- Multi-root graphs that share one provider instance.
- Negative classification for missing primitive-table entries.
- Negative classification for missing provider exports during composition.
- Negative classification for an escape from a `letrec` RHS that later reads
  the skipped binding, preserving the old `racket/set` unsafe-undefined
  frontier as a tiny manifest regression even though the installed set smokes
  have moved past it.
- Negative classification for the same guard through a two-module
  `racket/pretty` -> `racket/private/custom-write` shaped import, so the
  pretty/custom-write frontier is documented without requiring the full
  installed `racket/set` graph.

This split matters. Installed-extraction smokes are evidence that host Racket
metadata, provider discovery, Webify composition, and WebRacket runtime
execution all agree for a real source module. Local-manifest smokes are more
surgical: they protect bridge/runtime invariants even when the source extractor
cannot yet generate that exact graph shape.

Manual Goal 1 probes also show `racket/stream` can require and run
`(stream-first (stream 42))`. That result is not yet in the default installed
runtime suite, because the installed-module suite is expensive enough that new
smokes should be promoted only when they are directly guarding the active
frontier.

Use `webify/probe-installed-runtime-smoke.rkt` for one-at-a-time installed
runtime checks. It lists stable smoke indexes and runs a selected smoke in a
child Racket process with a hard timeout, so a single provider graph cannot
consume an unbounded debugging session. The `--memory-mb` flag is intentionally
best-effort: it limits the worker Racket process's own custodian-managed
allocations, but subprocesses used by extraction or WebRacket execution still
need the parent process timeout as the hard containment boundary.

Use `webify/probe-installed-module-deps.rkt` with the newer `../racket`
checkout for provider-graph deltas. The current `racket/set` comparison is:
require-only extracts only `module-protocol` and the root module, while
`set?` and `set-count` add the same broad provider cluster, including
`racket/pretty` and `racket/private/custom-write`. The important update is that
this broad provider cluster now initializes far enough for first set operations
and follow-on immutable set updates to run.

Direct provider probes clarified a useful caveat: require-only cases that never
use an imported binding are demand-sliced down to `module-protocol` plus the
root module, so they do not prove provider initialization. The meaningful
smaller operation is `(require racket/private/set-types)` plus `(set? 42)`;
that pulls the same broad provider cluster and now completes successfully.
Earlier `--no-observe` probes were useful because they showed the retired
blocker was not result printing or `js-log`; the failure was in module
execution of the operation-demanded set/custom-write/pretty slice.

Use `webify/probe-installed-runtime-smoke.rkt --preserve-dir DIR` to keep a
runtime frontier transcript. The preserved `composed-source` directory contains
the generated `module-runtime-run.rkt`, `composed-dest` contains the emitted
JS/Wasm/WAT/map artifacts, and `installed-source` contains the extractor script
and manifest. For the current set frontier, useful transcripts were generated
under `/private/tmp/wr-goal1-set-types-predicate-after-immutable-hash` and
`/private/tmp/wr-goal1-set-count-after-immutable-hash`.

The runtime-smoke harness treats output mismatches as hard process failures.
That matters for bounded probes: a mismatch should produce `probe-result: fail`
instead of only a RackUnit log inside a child process that exits normally.

The escape-continuation decision is deliberately conservative. The Reference
says an escape continuation can only be called during the dynamic extent of the
`call-with-escape-continuation` call. WebRacket's current bootstrap
implementation supports the useful early-return shape with a private Wasm
exception, but it does not yet enforce dynamic invalidation or prompt/barrier
semantics. That is sufficient for direct escape and for escaping with a closure
that does not read skipped `letrec` bindings; it should not be used to paper
over real `unsafe-undefined` guards. The old `racket/set` guard path is still
preserved as a local regression even though the installed set smokes now pass.

Source-module extraction compiles a supplied module-data list in one shared
host namespace. Earlier declarations are installed before later modules are
compiled, which lets quoted sibling requires resolve for dependency-first test
graphs without requiring browser-side namespace support.

## Goal 2: Make `eval` Work In The Browser

### Why

Racket has a strong interactive tradition. Browser-side `eval` would make
WebRacket much more than an ahead-of-time compiler target:

- REPLs could run entirely in the browser.
- Teaching environments could evaluate user input without a server.
- Macro experiments and dynamic code examples could be interactive.
- Programs could construct and run code at runtime in a Racket-like way.

This is strategically important, but it is a different problem from running
precompiled module programs.

### How

Full browser `eval` needs a runtime pipeline:

```text
input datum or syntax
  -> read, if starting from text
  -> expand in a namespace
  -> compile to an executable representation
  -> instantiate or run in the current namespace/module state
  -> return values
```

In full Racket, `eval` delegates to `current-eval`, and the default evaluation
handler indirectly uses `current-compile`. The default compiler produces
compiled-expression values, which print as `#~` compiled code. Linklets have
their own API, but Racket's expander implementation can compile linklets through
the underlying compile/eval substrate.

WebRacket does not need to copy Racket's bytecode format, but it needs an
equivalent runtime "compiled code" representation.

The reader is not necessarily a from-scratch problem. Racket's expander tree
already contains a substantial reader subsystem under `src/expander/read`,
including `read`, `read/recursive`, `read-language`, readtables, reader
parameters, strings, chars, vectors, hashes, graph notation, quotes, boxes,
regular expressions, `#reader`, and `#lang` handling. The syntax layer wraps
that reader to provide `read-syntax` and `read-syntax/recursive`.

For WebRacket, the question is therefore not "invent a reader?" but "how much
of the expander reader can run in WebRacket, and what policies do we want for
features that depend on modules, compiled code, or the host filesystem?"

### Current Progress

This goal is still exploratory.

Useful pieces already built for Goal 1 also help Goal 2:

- Module instances and module-variable cells.
- Linklet/module composition experiments.
- Provider graph resolution.
- Kernel primitive classification.
- Runtime support for more Racket values, structs, hashes, syntax objects, and
  exceptions.
- Racket's expander includes a reader implementation that may be portable with
  the expander, instead of writing a new reader from scratch.

But browser `eval` still needs major pieces:

- A browser-side reader integration story: ports, source locations, readtables,
  reader parameters, syntax wrapping, and policies for `#reader`, `#lang`, and
  `#~` compiled input.
- Enough expander support to expand runtime input.
- A namespace/module registry that supports dynamic declarations and lookups.
- A browser-side compiled-code representation.
- Runtime support for expander-heavy primitives, including syntax binding,
  syntax serialization, parameters, paths, exceptions, continuation marks, and
  module path indexes.

### Options For Browser-Side `eval`

#### Option A: Dynamic Wasm Generation

```text
eval input
  -> expand
  -> WebRacket compiler emits new Wasm
  -> browser compiles and instantiates the new Wasm module
```

Pros:

- Reuses the same execution target as ahead-of-time WebRacket.
- Has the best long-term performance story.
- Avoids a second interpreter or bytecode engine.

Cons:

- Hardest implementation path.
- Requires packaging enough of the compiler to run in the browser.
- Requires dynamic Wasm-GC generation and linking against live module state.
- Browser Wasm compilation/instantiation is operationally more complex than
  calling an existing closure.

This is attractive as a long-term endpoint, not as the first bridge.

#### Option B: Closure-Generated Code

This is inspired by Feeley and Lapalme's "Using closures for code generation."
Instead of compiling runtime input to bytecode or Wasm, compile it to a graph of
closures. Each generated closure implements one lowered construct.

```text
eval input
  -> expand/lower
  -> generate WebRacket closures
  -> call the generated closure in an environment/module instance
```

Pros:

- Avoids dynamic Wasm generation.
- More efficient than repeatedly interpreting source because classification and
  lowering happen once.
- Fits WebRacket's existing closure/procedure machinery.
- Can start small and grow construct-by-construct.

Cons:

- Creates a second execution path beside ahead-of-time Wasm compilation.
- Needs careful representation of environments, top-level variables, mutation,
  multiple values, tail calls, and module instances.
- Needs optimization if it is expected to run substantial programs.

This is probably the simplest credible path for a first browser-side `eval`.

#### Option C: Bytecode Or AST Interpreter

```text
eval input
  -> expand/lower
  -> compact bytecode or AST
  -> interpreter loop runs it
```

Pros:

- Easiest to inspect and debug.
- Keeps compiled expressions as ordinary data.
- Avoids dynamic Wasm generation.

Cons:

- Likely slower.
- Creates a parallel virtual machine.
- Every semantic feature must be implemented in the interpreter or bridged to
  WebRacket runtime primitives.

This is useful as a bootstrapping or debugging path, but it risks becoming a
large second runtime.

#### Option D: Linklet Interpreter

```text
eval input
  -> expand to linklet-level form
  -> interpret linklet forms directly
```

Pros:

- Aligns with Racket's module/linklet model.
- Reuses the same lower-level representation used by module extraction.
- Could share module-instance and import/export machinery with Goal 1.

Cons:

- Still an interpreter.
- Needs complete enough linklet semantics: imports, exports, mutation,
  instances, primitive calls, multiple values, and prompts.
- Performance may be limited unless later compiled to closures or Wasm.

This may be a good stepping stone, especially if the interpreter can later be
replaced by closure generation.

#### Option E: Server Or Host Compiler

```text
browser input
  -> send to native Racket or server
  -> expand/compile/run or return artifact
```

Pros:

- Fastest way to get correct Racket behavior.
- Useful as a development oracle.

Cons:

- Not browser-only.
- Requires network access and a trusted server.
- Does not satisfy the core WebRacket goal of self-contained browser execution.

This should be treated as an oracle or development aid, not the final design.

### Suggested Direction

Keep Goal 1 and Goal 2 on separate tracks.

For Goal 1:

```text
prioritize ahead-of-time module programs
  -> expand installed-module coverage
  -> implement runtime primitives as demanded by executable programs
```

For Goal 2:

```text
prototype a tiny browser-side compiled representation
  -> probably closure-generated code or a small linklet interpreter
  -> start with self-evaluating values and primitive applications
  -> then add lexical variables, top-level variables, mutation, and modules
```

Do not block Goal 1 on browser `eval`. The ahead-of-time module path can deliver
useful browser programs much sooner, while the `eval` path can proceed as a
careful research track.
