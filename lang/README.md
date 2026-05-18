This folder contains the reader for `#lang webracket`.

`#lang webracket` is currently kept as script-compatible input for
`webracket.rkt`: the driver recognizes the line and compiles the remaining
forms as a top-level program.

The module-oriented Goal 1 path starts with `#lang webracket/base`, whose
reader lives in `base/lang/reader.rkt` and expands through host Racket as a
normal module using language `webracket/base`.

The command-line driver currently supports `#lang webracket/base` with a
transitional bridge: it reads the source as a normal module, lowers a tiny
subset of local module structure, and compiles the resulting body through the
existing top-level compiler path. This is scaffolding, not the intended module
semantics.

The transitional require subset is deliberately small. Plain local string
requires such as `(require "lib.rkt")` are accepted for smoke tests. Unsupported
require specs, including `only-in`, `rename-in`, collection imports, and phase
imports, must fail clearly instead of being approximated here. The intended
direction is to use Webify's module report/registry/composer pipeline and then
delete this source-level lowering.

An opt-in bridge for that direction is available with
`--webracket-base-module-bridge`. In that mode, the driver extracts a local
`#lang webracket/base` graph, builds a module registry with `module-protocol`,
and composes the root through module instances and module-variable cells. Keep
this path behind the flag until it covers the supported `webracket/base`
surface; it is the candidate replacement for the transitional source-level
lowering, not an additional parser to grow indefinitely.

The bridge currently recovers local dependencies from expanded/compiled import
metadata instead of raw source require syntax. Smokes pass for simple local
requires, `only-in`, `rename-in`, `prefix-in`, a custom
`define-require-syntax` transformer that expands to a local file, shared local
dependencies, a one-hop local re-export, flattening-vs-bridge parity on the
simple local require case, a staged `format` provider-backed program, a direct
provider route check, and local graph extraction in the presence of collection
requires. Collection/provider requires are left to provider discovery instead
of local file traversal. The bridge driver can select that provider-discovery
path with an in-memory provider report cache and demand slicing when reports
actually demand providers outside the ordinary `#lang webracket/base` language
root, but direct `racket/list` runtime smokes are still too slow for default
coverage. Keep the bridge opt-in until provider coverage and turnaround time
are less experimental; the local-only bridge is now the preferred default
candidate rather than just a local-module experiment. Verbose driver mode logs
per-provider fetch timing and provider-cache hit/miss totals for this path.
The current discovery-only smokes use a tiny fake `racket/list` provider
cluster and compare it with real extraction-only provider demands. The first
provider-trial manifest covers small clusters from `racket/list`,
`racket/string`, and `racket/bool` without launching full WebRacket runtime
compilation for those installed provider graphs. The bridge uses that manifest
as a temporary external-provider allowlist; providers outside it are rejected
instead of silently widening the experimental module system.
The provider-trial dashboard can cache summary rows on disk and reports
demand-sliced versus full extracted closure sizes. The bounded provider phase
probe currently places the `racket/bool` timeout in provider-graph discovery,
before composition or WebRacket compilation. It also supports provider trace
rows and a frontier limit; the first `racket/bool` trace points at repeated
cached unresolved-import candidate checks as the likely next bottleneck.

Reader resolution uses Racket's normal collection search via
`collection-file-path`. The driver does not add checkout-specific fallback
paths; an uninstalled development checkout must be made visible explicitly,
such as through `PLTCOLLECTS`, a collection link, or package installation.

`racket/base` is the foundation for `webracket/base`, not one of the optional
library add-ons. The next Goal 1 surface should layer selected libraries from
the larger `racket` language on top of that foundation, such as `racket/list`,
`racket/string`, `racket/set`, `racket/sequence`, `racket/match`,
`racket/format`, `racket/promise`, and related browser-plausible modules.

The current add-on list and status vocabulary live in
`webify/webracket-base-surface.rkt`. A library can be exported by
`webracket/base` before every one of its bindings has full runtime coverage, but
the status table must say whether it merely expands/extracts, composes, or has
representative runtime smokes.
