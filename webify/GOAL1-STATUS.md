# Goal 1 Status

Goal 1 is module-based WebRacket programs in the browser, without `eval` and
without the old textual stdlib path. The current implementation is useful but
curated: small `#lang webracket/base` programs run, `#lang webracket/full`
exports a selected add-on surface, and external `require`s are allowed only
through the temporary provider bridge allowlist.

## Current Green Paths

- Local `#lang webracket/base` and `#lang webracket/full` modules compile
  through the module bridge.
- Representative installed providers run for list, string, bool, bytes,
  vector, function, port, math, path, match, sequence, shared, pretty, hash,
  format, and dict coverage rows.
- WebRacket-owned staged providers cover the currently preferred surfaces for
  contracts, files, formatting, functions, hashes, ports, promises, sets,
  streams, regexp, and JS FFI modules. The default bridge now uses real
  installed providers for class, dict, list, pretty, sequence, string,
  `racket/private/for`, and `racket/private/kw` after their representative
  diagnostics reached runtime.
- Runtime-adjacent coverage now includes VFS file helpers, contract-erased
  queues, and the narrow logging export surface.
- Explicit `racket/class` requires now include extended runtime coverage for
  ordinary class creation, `init-field`, inheritance, `new`, `send`, `object?`,
  `is-a?`, interfaces, `class*`, `super`, `define/override`, keyword-style init
  arguments, and caught final-method override errors through the module bridge.
- Explicit `racket/unit` requires now include basic runtime coverage for
  signatures, unit imports/exports, and `define-values/invoke-unit` through the
  module bridge. Broader unit/linking forms are still separate coverage work.

## Current Boundaries

- Passing dashboard coverage is not a full compatibility claim. It means the
  representative API cluster works through the bridge.
- Staged providers intentionally erase or postpone contracts, generic
  interfaces, chaperones, impersonators, and host-OS services unless a provider
  documents otherwise.
- webracket/base should remain small. Broader batteries belong in
  `webracket/full` or explicit provider requires.
- The old stdlib path is transitional. Goal 1 should prefer module providers
  and staged original Racket code over textual inclusion.

## Dashboard Workflow

- Use `webify/goal1-dashboard.rkt --fast-required` for the quick inner loop.
- Use warmed-cache runs as the meaningful timing baseline. Cold
  `--no-cache-warmup` runs are useful for cache diagnostics, but they can spend
  the whole row budget in provider extraction before useful row output appears.
- Use `--coverage-core --warm-cache` for everyday Goal 1 provider coverage.
  Prefer `--jobs 2` for the currently verified developer loop; use `--jobs 4`
  selectively while measuring row-level performance.
- Use `--coverage-extended` before larger checkpoints or provider-surface
  changes.
- Module-language dashboard rows are routed through `--webracket-module-bridge`
  by default. The transitional top-level fallback should not be used for Goal 1
  dashboard coverage.
- Use `--composition` for heavyweight cross-provider composition rows. These
  rows are required checkpoints, but they are intentionally outside the
  everyday coverage presets. Prefer `--timeout 240` or higher for this preset.
- Use `--checkpoint` for the full required checkpoint set: core coverage,
  extended coverage, and composition rows. Prefer `--timeout 240` or higher
  for this preset.
- Use `--tier coverage` when you want every ordinary coverage row, including
  both core and extended presets.

Current verified smoke:

```sh
../racket/racket/bin/racket webify/goal1-dashboard.rkt \
  --tsv --fast-required --timeout 240 --memory-mb 1024 \
  --jobs 2 --warm-cache
```

That smoke currently passes all six fast-required rows.

Recent probes confirmed that warm-cache timings are the ones to optimize:
`--fast-required --jobs 2 --warm-cache --timeout 240` passes all six rows,
while `--jobs 4` can still over-contend and time out rows even after warmup.
Treat cold-cache runs, and over-contended parallel runs, as
provider-cache/performance diagnostics rather than evidence that a specific
provider regressed.
