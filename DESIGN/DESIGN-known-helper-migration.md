# Known-Helper Env Migration Plan

## Architectural Framing

The safe direction is to make direct-helper layout an analysis product
before it becomes a code generation decision.

Today:

- `extended` free-variable analysis already exists
- `body-layout-of` and `closure-env-of` are still mostly the same idea
- `known0` / `known1` / `known0-only` / `known1-only` exist as early
  experiments

The migration should first prove the Shivers-style environment model
with summaries and assertions, and only then let lowering consume it
in narrow slices.

## Phases

### 1. Analysis-Only Helper Env Summary

Goal:
- create one authoritative per-helper summary without changing output

Change:
- extend or wrap the current analysis with summary records containing:
  - label
  - binder
  - kind
  - value-use blockers
  - direct callees
  - base needs
  - extended needs
  - fixed arity
  - let/letrec origin
  - planned ABI
  - blockers

Unchanged:
- `body-layout-of`
- `closure-env-of`
- current known-helper lowering
- runtime representation

Assertions:
- for every direct edge `g -> f`, the propagated fixed point for `g`
  must include the extended needs of `f`

Tests:
- transitive `f/g/x` example
- direct chains
- branching callers
- value-use disqualification
- shadowing

Success:
- summaries match expected transitive needs
- no WAT or codegen changes

### 2. Availability Assertions, Still No Lowering Change

Goal:
- prevent “locally plausible but globally wrong” env sourcing

Change:
- add a checker over direct-call edges before closure-conversion decisions
- every env operand needed by a callee must be sourceable from caller
  locals, formals, or caller extended layout

Unchanged:
- generated code
- ABI selection

Assertions:
- `known1-env-variable-of`-style logic must be derived from summary, not
  guessed from callee names

Tests:
- a passing transitive `g -> f` case carrying `x`
- a blocker case where a caller cannot source the env

Success:
- checker explains blockers deterministically
- no whole-program regressions

### 3. Split Layout Concepts

Goal:
- make the model explicit

Change:
- `body-layout-of` means lifted body env operands
- `closure-env-of` means allocated procedure payload
- initially the old behavior can remain, but assertions compare against
  the new summary

Unchanged:
- closure allocation still uses `$Closure` / `$Closure1` / `$Closure2` / `$Closure3`
- known-only lowering does not expand

Assertions:
- direct-helper body layout must equal summary `extended-needs` when the
  new flag is enabled
- closure-backed helpers keep payload compatibility

Tests:
- summary and closure-converted shape tests showing the two concepts can
  differ

Success:
- terminology and plumbing are separated without behavior change

### 4. Sibling Known ABI Driven By Extended Needs

Goal:
- make existing `known0` / `known1` sibling labels consume the new
  analysis before deleting any closure entry

Change:
- drive `known0-target-eligible/local?`
- drive `known1-target-eligible/local?`
- drive direct-call env sourcing from summary `extended-needs`

Unchanged:
- ordinary `$ClosureCode` sibling still emitted
- closure allocation still happens

Assertions:
- every emitted `known1app` env operand comes from caller availability proof

Tests:
- focused direct-helper examples
- WAT shape tests for `.known0` / `.known1`
- whole-program checks

Success:
- correctness stays green
- code size does not regress materially from current sibling-transition tax

### 5. Known0-Only For Let-Bound Non-Recursive Leaf Helpers

Goal:
- remove ordinary closure ABI only for the smallest safe class

Change:
- restrict `known0-only` to:
  - non-recursive `let-values`
  - fixed-arity plain lambdas
  - direct-only use
  - empty extended needs
  - no case-lambda
  - no closure identity

Unchanged:
- `known1-only` stays off or ultra-narrow
- sibling known0 / known1 remains fallback

Assertions:
- no closure allocation
- no ordinary label entry
- no ordinary direct fallback for known-only labels

Tests:
- closure-converted shape
- WAT no-base-label test
- runtime tests for direct calls and arity errors

Success:
- green checks
- measurable WAT reduction on small examples

### 6. Known1-Only After Caller-Carried Layout Works

Goal:
- enable unary-env known-only only after phase 4 proves transitive env sourcing

Change:
- `known1-only` becomes summary-driven:
  - one extended need
  - all direct callers can source it
  - no value use
  - no recursive group
  - no closure allocation

Unchanged:
- no `known2-only`
- no letrec support yet

Assertions:
- env operand is caller-relative
- never reconstructed from callee closure
- `free-ref 0` maps to `$env0` only under `KnownCode1`

Tests:
- nested `f/g/x`
- two-hop chains
- shadowing
- lifted caller cases
- arity mismatch cases

Success:
- WAT size improves enough to offset deleted sibling labels
- no benchmark correctness failures

### 7. Known2 And Multi-Env Helpers

Goal:
- add `known2` only after deletion of old entries is proven

Change:
- add `$KnownCode2`
- add codegen params
- add `known2app`
- map free refs to two env operands

Unchanged:
- closure-backed helpers
- small-inline closure optimizations

Assertions:
- known env arity matches summary layout length

Tests:
- two-env transitive examples
- mixed known1 / known2 direct graphs

Success:
- code size improves on benchmark closure histograms
- compile-time overhead remains acceptable

### 8. Letrec And Recursive Groups Last

Goal:
- handle recursive direct helpers with SCC-aware extended needs

Change:
- integrate summary with direct-letrec lowering
- solve SCC env needs as groups
- handle shell allocation / patching only when still required

Unchanged:
- earlier phases should not depend on recursive known-only support

Assertions:
- recursive groups only delete closure identity when proven safe

Tests:
- self recursion
- mutual recursion
- recursive env capture
- blocker summaries

Success:
- same correctness as current letrec
- reduced closure allocation only in proven groups

## Feature Guidance

- `known1-only`: keep under the narrowest proven guard until phases 1-4 land
- `known0-only`: keep, but treat it as the first known-only production target
- `known0` / `known1` sibling ABI: keep as transition safety net
- `$Closure1` / `$Closure2` / `$Closure3`: leave untouched; they are orthogonal

## Rollback Strategy

Each phase should land independently.

Do not land together:
- layout splitting and known-only deletion
- `known2` and closure-entry removal

Metrics before moving on:
- focused tests
- `raco test compiler.rkt`
- `--no-stdlib` letrec run
- benchmark compile time
- WAT size
- counts of known labels
- counts of deleted closure labels
- max and average extended-needs size

Stop conditions:
- continue if assertions are green and summaries explain every known call
- pause if extended-needs grows unexpectedly or blockers are noisy
- back out if a known-only helper still allocates a closure, is observable
  as a procedure, or sources env from callee identity instead of caller layout

## Immediate Next Step

Implement phase 1 only:

- add an explicit direct-helper env summary beside the current extended analysis
- do not replace codegen
- do not change lowering
- add tests for the transitive `f/g/x` example and blocker summaries

That gives us the map before we move the roads.
