This folder contains the reader for `#lang webracket`.

`#lang webracket` is currently kept as script-compatible input for
`webracket.rkt`: the driver recognizes the line and compiles the remaining
forms as a top-level program.

The module-oriented Goal 1 path starts with `#lang webracket/base` and
`#lang webracket/full`. Both expand through host Racket as normal modules:
`webracket/base` is the small `racket/base`-like foundation, while
`webracket/full` is the curated batteries-included surface.

The command-line driver currently supports both module languages with a module
bridge: it reads the source as a normal module, extracts module reports, builds
a small module registry, composes module instances, and compiles the resulting
top-level bootstrap through the existing compiler path. This is still
scaffolding, but the source-level flattening path is no longer the normal path
for local-only modules.

The local bridge subset is deliberately small, but it is metadata-driven rather
than raw require-syntax driven. Plain local string requires, `only-in`,
`rename-in`, `prefix-in`, shared local dependencies, and one-hop local
re-exports are covered by smokes. Unsupported require shapes and phase imports
must fail clearly instead of being approximated here. The intended direction is
to keep moving behavior into Webify's module report/registry/composer pipeline
and delete any remaining source-level fallback.

The module bridge is now the default for local-only `#lang webracket/base` and
`#lang webracket/full` graphs. The driver extracts a local graph, builds a
module registry with `module-protocol`, and composes the root through module
instances and module-variable cells. The `--webracket-module-bridge` flag only
forces this path for provider-demanding modules while provider graph support is
still experimental.

The bridge currently recovers local dependencies from expanded/compiled import
metadata instead of raw source require syntax. Smokes pass for simple local
requires, `only-in`, `rename-in`, `prefix-in`, a custom
`define-require-syntax` transformer that expands to a local file, shared local
dependencies, a one-hop local re-export, a provider-only `racket/bool` runtime
smoke without stdlib, and local graph extraction in the presence of collection
requires. Collection/provider requires are left to provider discovery instead
of local file traversal. The bridge driver can select that provider-discovery
path with an in-memory provider report cache and demand slicing when reports
actually demand providers outside the ordinary `#lang webracket/base` language
root, but direct broad-provider runtime smokes are still too slow for default
coverage. Verbose driver mode logs per-provider fetch timing and
provider-cache hit/miss totals for this path.
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
such as through `PLTCOLLECTS`, a collection link, or package installation. The
repository is declared as a multi-collection package so sibling collections
such as `webracket` and `js` are installed together instead of relying on
checkout-specific parent-directory guesses.

`racket/base` is the foundation for `webracket/base`, not one of the optional
library add-ons. The broader Goal 1 surface is `webracket/full`, which layers
selected libraries from the larger `racket` language on top of that foundation,
such as `racket/list`, `racket/string`, `racket/set`, `racket/sequence`,
`racket/match`, `racket/format`, `racket/promise`, and related
browser-plausible modules.

WebRacket-specific host interop is tracked separately from Racket libraries.
`webracket/js` is the first explicit FFI provider and currently owns `js-log`.
`webracket/base` and `webracket/full` re-export it for compatibility, but new
JS, browser, or Node bindings should be added through WebRacket provider
modules instead of as accidental ambient top-level names.

The first public wrapper pilot is `(require js/console)`, backed by
`webracket/unsafe/console`. The unsafe layer corresponds to `ffi/console.ffi`.
The second pilot is `(require js/math)`, backed by generated metadata from
`ffi/math.ffi`; its unsafe layer now resolves active `.ffi` primitive closures
through `unsafe-ffi-primitive`, so runtime users still need the matching FFI
bundle such as `--ffi math`. The public `js/*` layer is where checked, Rackety
wrappers belong. Use `browser/*` for DOM/window/document APIs instead of mixing
those names into the JavaScript built-in namespace.

The current full add-on list and status vocabulary live in
`webify/webracket-full-surface.rkt`. A library can be exported by
`webracket/full` before every one of its bindings has full runtime coverage,
but the status table must say whether it merely expands/extracts, composes, or
has representative runtime smokes. The companion dashboard prints TSV/JSON rows
with export status, provider allowlist status, direct runtime-smoke status, and
the current last-known blocker.

The old textual `stdlib/` is legacy top-level compatibility for script-style
programs. It should not become a dependency of `#lang webracket/base` or
`#lang webracket/full`; module-language programs should get functionality from
original Racket providers, staged providers such as regexp/read/format, or
explicit WebRacket primitives.
