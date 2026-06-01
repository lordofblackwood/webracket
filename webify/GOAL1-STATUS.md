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
- Use `--coverage-core` for everyday Goal 1 provider coverage.
- Use `--coverage-extended` before larger checkpoints or provider-surface
  changes.
- Use `--tier coverage` when you want every coverage row, including both core
  and extended presets.
