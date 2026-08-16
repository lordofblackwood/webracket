## Alpha-Rename Notes

`alpha-rename` currently runs in two passes inside
[`pkgs/webracket-lib/compiler/compiler.rkt`](/Users/soegaard/Dropbox/GitHub/webracket/pkgs/webracket-lib/compiler/compiler.rkt).

- `α-rename/pass1` performs the actual traversal and threads a `rename-env`.
- `α-rename/pass2` patches `#%provide` entries so each exported name keeps both
  the original variable and the renamed variable.

### Environment Model

The pass uses `rename-env`, which carries three views:

- `lexical`: exact lexical-identifier mapping via `free-id-table`
- `by-name`: printed-name occupancy buckets for collision checks
- `fallback`: non-lexical printed-name mapping for top-level/module cases

Lookup prefers lexical identity. Printed-name fallback is only used for
non-lexical identifiers so a local binding such as `values` cannot capture a
core primitive accidentally.

### What Gets Renamed

- Local bindings in `lambda`, `case-lambda`, `let-values`, and `letrec-values`
  are renamed.
- In `'full` mode every introduced local gets a fresh name.
- In `'simple` mode the first binding with a name may keep that name; this mode
  exists only for older tests.

Top-level definitions outside modules are not renamed, but they are inserted
into the environment so later references can detect whether the binding has
already been seen.

### Preserved Names

- Compiler primitives remain direct primitive references unless a provider owns
  that alias.
- Provider-owned primitive aliases may resolve to collected top bindings once
  the binding has been seen.
- Constants and selected console-bridge names are preserved through the
  unbound-reference path.

### Recent Optimization

`top-binding?` used to scan the entire collected top-binding list for each
lookup-site check. The pass now precomputes an identifier set for top bindings
and uses set membership instead. This keeps the binding-identity behavior while
removing a repeated linear scan from the hot path.

### Profiling

Use:

```sh
racket webracket.rkt --alpha-rename-profile your-program.rkt
```

For the usual timing table as well:

```sh
racket webracket.rkt --timings --alpha-rename-profile your-program.rkt
```

The profile currently reports compact counters and helper timings for
`α-rename/pass1`, including lookup totals, binding introduction counts, fresh
name generation, top-binding checks, and coarse lookup/fresh-name milliseconds.
