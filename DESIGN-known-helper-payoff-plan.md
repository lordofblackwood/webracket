# Known-Helper Payoff-Oriented Migration Plan

## New Migration Plan

The new north star should be: only migrate layout/ABI when it deletes
something costly.

The unary carried-layout experiment proved that correctness alone is
not enough; a migration must remove closure allocation, remove a
`$ClosureCode` sibling, shrink closure payloads, or unlock a measured
call-path win.

### Phase A: Add A Payoff Summary

Goal:
- measure remaining opportunities before changing lowering again

Add an analysis-only summary in `compiler.rkt` that reports, per direct helper:

- current body layout size
- current closure env size
- extended-needs size
- known ABI class: `known0`, `known1`, possible `known2`
- known-only class: `known0-only`, `known1-only`, possible future only
- whether migration would delete closure allocation
- whether migration would delete ordinary `$ClosureCode`
- whether migration would only change body layout
- direct-call in/out degree
- origin: `let-values`, `letrec-values`, other
- blockers: value use, letrec, recursive, env too large, unavailable env, case-lambda, nested capture

Success:
- we can explain why `pict.rkt` gets `.wat` wins but compile-time cost
- we can identify changes with real deletion payoff

### Phase B: Benchmark The Summary

Goal:
- choose the next lowering based on opportunity counts

Run the new summary on:

- `test/test-letrec.rkt`
- `test/test-basics.rkt`
- `examples/pict/pict.rkt`
- optionally MiniScheme

Track:

- number of zero-env, unary-env, binary-env candidates
- how many are already known-only
- how many still allocate closures
- how many have ordinary closure ABI siblings
- how many migration candidates are “shape-only”
- max/average direct-call graph depth
- closure payload arity histogram after current passes

Success:
- a table that says which frontier has the best deletion-per-complexity ratio

### Phase C: Do Not Widen Unary Yet

Goal:
- avoid repeating the backed-out detour

Keep the current unary carried-layout migration deferred.
Revisit only if the summary shows a strict gate such as:

- unary migration enables `known1-only`
- unary migration removes a closure allocation
- unary migration removes an ordinary `$ClosureCode` sibling
- unary migration removes a captured direct-helper binder from an enclosing closure payload

Do not retry if it only changes `body-layout-of`.

### Phase D: Consider Sibling `known2` Only If Measurement Justifies It

Goal:
- evaluate a low-semantic-risk ABI extension

If binary-env direct helpers are common and direct-call-heavy, add sibling-only `known2`:

- add `$KnownCode2`
- add `known2app`
- add `known2-code-label`
- map `free-ref 0/1` to `$env0/$env1`
- keep ordinary closure ABI sibling
- no `known2-only` yet
- no letrec support yet

Success:
- measurable `.wat` or runtime/codegen benefit without large compile-time regression
- if it adds sibling tax without deletion payoff, back it out

### Phase E: Known-Only Deletion Frontier

Goal:
- delete old entries only where proof is strong

After payoff summary data, expand known-only only for helpers with:

- direct-only use
- no value escape
- no top-level export / procedure identity requirement
- non-recursive `let-values` origin
- all callers can source env operands
- no generic apply/invoker path
- no ordinary closure allocation remains
- no `$ClosureCode` label is referenced

Candidate order:

- more `known0-only` cleanup if any remains
- deletion-producing `known1-only`
- only later `known2-only`

Success:
- generated WAT loses both allocation and base label, not just changes call shape

### Phase F: Letrec Preparation, Analysis Only

Goal:
- prepare recursive groups without destabilizing current wins

Add or refine summaries for:

- SCC env needs
- same-group direct-call edges
- closure shell requirements
- patching requirements
- recursive helpers that would be known-only except for letrec
- groups where final allocation is already avoidable

No lowering changes yet.

Success:
- we know which recursive groups are realistic future candidates
- we know which are blocked by identity/patching

## What Not To Do

- Do not broadly widen body-layout migration next.
- Do not implement `known2-only` before sibling `known2` is measured.
- Do not mix letrec lowering with known-only work.
- Do not alter `$Closure1/$Closure2/$Closure3`; they remain useful for closure-backed values.
- Do not land an optimization whose only proven effect is “layout is more conceptually correct.”

## Recommended Immediate Step

Implement Phase A only: a payoff-oriented direct-helper frontier summary.

That is the smallest safe next step because it changes no generated
code, gives us benchmark-relevant facts, and should tell us whether the
next profitable move is `known2`, deletion-focused `known1-only`, or
letrec preparation.
