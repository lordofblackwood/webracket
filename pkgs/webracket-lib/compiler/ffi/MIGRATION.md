# FFI Migration Matrix

The `.ffi` files in this directory are raw host-import declarations. Goal 1
module programs should use ordinary providers instead:

```text
ffi/foo.ffi
  -> webracket/unsafe/foo
  -> js/foo or browser/foo
```

The unsafe layer is raw and explicitly unsafe. The public layer should choose a
small, documented surface with names that make sense for WebRacket programs.

## Current Matrix

| `.ffi` file | Unsafe module | Public module | Bundle inference | Dashboard coverage | Status |
| --- | --- | --- | --- | --- | --- |
| `console.ffi` | `webracket/unsafe/console` | `js/console` | yes | yes | migrated |
| `math.ffi` | `webracket/unsafe/math` | `js/math` | yes | yes | migrated |
| `performance.ffi` | `webracket/unsafe/performance` | `js/performance` | yes | yes | migrated |
| `standard.ffi` | `webracket/unsafe/standard` | `js/standard` | yes | yes | migrated starter surface |
| `temp.ffi` | `webracket/unsafe/temp` | `js/temp` | yes | yes | migrated benchmark surface |
| `array.ffi` | `webracket/unsafe/array` | `js/array` | yes | yes | migrated aggregate surface |
| `audio.ffi` | `webracket/unsafe/audio` | `browser/audio` | yes | no | migrated, browser dashboard later |
| `canvas.ffi` | `webracket/unsafe/canvas` | `browser/canvas` | yes | no | migrated, browser dashboard later |
| `document.ffi` | `webracket/unsafe/document` | `browser/document` | yes | no | migrated, browser dashboard later |
| `dom.ffi` | `webracket/unsafe/dom` | `browser/dom` | yes | no | migrated aggregate surface |
| `domrect.ffi` | `webracket/unsafe/domrect` | `browser/domrect` | yes | no | migrated, browser dashboard later |
| `element.ffi` | `webracket/unsafe/element` | `browser/element` | yes | no | migrated, browser dashboard later |
| `event.ffi` | `webracket/unsafe/event` | `browser/event` | yes | no | migrated, browser dashboard later |
| `image.ffi` | `webracket/unsafe/image` | `browser/image` | yes | no | migrated, browser dashboard later |
| `js.ffi` | `webracket/unsafe/js` | `js/array` | yes | via `array.ffi` | included by aggregate `array.ffi` |
| `jsxgraph.ffi` | `webracket/unsafe/jsxgraph` | `jsxgraph` | yes | no | migrated, example dashboard later |
| `media.ffi` | `webracket/unsafe/media` | `browser/media` | yes | no | migrated, browser dashboard later |
| `websocket.ffi` | `webracket/unsafe/websocket` | `browser/websocket` | yes | no | migrated, browser dashboard later |
| `window.ffi` | `webracket/unsafe/window` | `browser/window` | yes | no | migrated, browser dashboard later |
| `xtermjs.ffi` | `webracket/unsafe/xtermjs` | `xterm` | yes | no | migrated, example dashboard later |

## Namespace Policy

- Use `js/*` for JavaScript built-ins and host-independent JavaScript APIs:
  `js/math`, `js/console`, `js/performance`, `js/standard`, and `js/temp`.
- Use `browser/*` for DOM/window/document/canvas/media APIs. The raw unsafe
  module should still be `webracket/unsafe/foo`.
- Keep library-specific APIs under their own public namespaces after the
  browser/core split is stable; likely candidates are `jsxgraph/*` and
  `xterm/*`, not `js/*`.
- Do not make `.ffi` files public APIs. They are compiler/runtime declarations
  and should remain in `webracket-lib`.

## Performance Boundary

Migrated unsafe modules currently bind names through `unsafe-ffi-primitive`,
which returns closures from a runtime table. This keeps the modules ordinary and
composable, but calls are not yet direct primitive calls. See `README.md` for
the direct-call optimization note.

## Migration Plan

The migration should proceed in small, dashboard-visible slices. Each migrated
`.ffi` file should have:

- `webracket/unsafe/foo`, generated or generated-style from `foo.ffi`.
- A public module, usually `js/foo` or `browser/foo`.
- Automatic bundle inference through `ffi-module-registry.rkt`.
- A status row in `webify/ffi-migration-status.rkt`.
- At least one dashboard row when the API can run in the current Node/browser
  test environment.

### Phase 1: Close Existing Migrated Gaps

Goal: finish the already-migrated modules before adding more surface.

1. Add dashboard coverage for `js/performance`.
   - Use a Node-safe function if possible; `performance.ffi` currently maps to
     the browser `performance` object, so this may require either a Node host
     adapter or a browser-only dashboard category.
2. Add dashboard coverage or an explicit diagnostic for `js/temp`.
   - `temp.ffi` is benchmark-only and expects an external object, so it may be
     better to mark it as temporary/diagnostic instead of promoting it as public
     API.
3. Update this matrix so `performance.ffi` and `temp.ffi` are no longer vague
   "registry/tests" rows.

Acceptance checks:

- `webify/ffi-migration-status.rkt` reports no migrated provider without either
  dashboard coverage or an explicit diagnostic reason.
- FFI-filtered `test-webracket-base-lang.rkt` passes.

### Phase 2: Improve Generator Workflow

Goal: make migration mostly mechanical and auditable.

1. Add a command-line mode to generate an unsafe module from a `.ffi` file.
2. Add a dry-run/check mode that compares generated output with an existing
   unsafe module.
3. Use the check mode for migrated unsafe modules in tests.
4. Decide whether generated modules should stay compact with `define-ffi`
   syntax or fully expanded with per-binding comments.

Acceptance checks:

- Existing unsafe modules are either generated byte-for-byte or explicitly
  documented as hand-written wrappers.
- Adding `ffi/foo.ffi` plus generated `webracket/unsafe/foo` causes registry
  inference without editing the registry.

### Phase 3: Migrate Low-Risk JavaScript Built-ins

Goal: expand host-independent JS APIs before DOM/browser APIs.

Preferred order:

1. `js.ffi` as `webracket/unsafe/js` plus a carefully named public module.
   - Do not blindly expose dangerous or vague operations; choose wrappers for
     object/ref/send/new functionality deliberately.
2. Revisit `array.ffi`.
   - It currently includes `standard.ffi` and `js.ffi`, so it should probably
     wait until `js.ffi` has a clean module story.
3. Keep `standard.ffi` public surface small.
   - Add wrappers only for value-oriented functions that do not require a
     larger external-object policy.

Acceptance checks:

- New public modules work with `(require js/foo)` and no manual `--ffi`.
- Dashboard rows avoid activating large aggregate `.ffi` files unless the
  timing is acceptable with a warm cache.

### Phase 4: Establish Browser Namespace

Goal: make the first DOM-facing provider without committing to the whole DOM.

Preferred first browser slice:

1. `window.ffi` -> `webracket/unsafe/window` -> `browser/window`
2. `document.ffi` -> `webracket/unsafe/document` -> `browser/document`
3. `domrect.ffi` -> `webracket/unsafe/domrect` -> `browser/domrect`

The public modules should expose a small browser-safe surface and should be
tested in a browser/headless category, not forced into Node-only dashboard rows
when the host object is unavailable.

Acceptance checks:

- Browser dashboard rows distinguish "not available in Node" from real
  WebRacket failures.
- The namespace policy stays `browser/*` for DOM/window/document APIs.

### Phase 5: DOM Composition Layer

Goal: make DOM APIs compose rather than migrate isolated files forever.

Order:

1. `element.ffi`
2. `event.ffi`
3. `dom.ffi`
4. `canvas.ffi`
5. `image.ffi`

This phase should focus on public wrapper quality. The raw unsafe modules can
be generated, but public APIs should prefer typed, documented wrappers over
one-to-one re-exporting every raw binding.

Acceptance checks:

- Small DOM examples compile as module programs with ordinary `require`s.
- Existing legacy `include-lib` DOM examples have module equivalents.

### Phase 6: Media, Networking, And Library-Specific APIs

Goal: migrate larger browser/library APIs after the core browser namespace is
settled.

Order:

1. `websocket.ffi` -> `browser/websocket`
2. `audio.ffi` and `media.ffi` -> `browser/audio` / `browser/media`
3. `jsxgraph.ffi` -> library-specific public namespace
4. `xtermjs.ffi` -> library-specific public namespace

Acceptance checks:

- Public module names are chosen deliberately; avoid dumping third-party APIs
  under `js/*`.
- Examples no longer depend on legacy `lib/libs/*` include wrappers once module
  equivalents exist.

### Phase 7: FFI Call Efficiency

Goal: optimize after the module surface is stable.

Current migrated modules bind raw names through `unsafe-ffi-primitive`, so calls
go through closure/module-variable dispatch. Later work should:

1. Detect aliases initialized from `(unsafe-ffi-primitive 'name)`.
2. Compile calls through those aliases directly to generated FFI wrappers when
   the binding is statically known.
3. Keep the closure-table path as a fallback for dynamic cases.
4. Measure warm-cache dashboard rows before and after the optimization.

Acceptance checks:

- Existing module programs behave the same.
- Direct-call optimization is visible in generated Wasm or compiler debug
  output.
- `js/standard` and future large FFI modules no longer pay excessive dynamic
  alias overhead for simple calls.
