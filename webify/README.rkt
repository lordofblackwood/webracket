Webify
======

This folder contains a port of `schemify` from the Racket to Chez Scheme compiler.
Eventually, this `webify` will be integrated with the compiler in order to support modules.

This is a work in progress.

See `OUTPUT.md` for the current output-language notes.
See `LOWERING.md` for the first module-variable lowering slice.
See `BRIDGE.md` for a concrete linklet-to-top-level adapter example.

Bridge-facing module APIs:

- `module-extractor.rkt` is the stable report/discovery facade. Prefer its
  `webify-module-report-*` names over the lower-level `module-extractor-spike`
  probes.
- `module-protocol.rkt` provides the synthetic `module-protocol` report/input
  for `.get-syntax-literal!` and `.set-transformer!`.
- `module-phase-policy.rkt` records the current phase-0-only bridge policy.
- `module-input.rkt`, `module-registry.rkt`, and `module-loader.rkt` are the
  current handoff path from extracted linklet reports to executable top-level
  WebRacket programs.

Focused checks:

- `raco test webify/test-module-adapter.rkt` checks the first compiler-facing
  adapter with the default Racket, including the `webracket.rkt --no-stdlib`
  CLI smoke.
- `raco test webify/test-module-protocol.rkt` checks the reusable module
  protocol provider, including a small runtime graph smoke.
- `webify/check-racket92-adapter.sh` runs the same adapter check with a local
  Racket 9.2 checkout, but skips the slower CLI smoke by default. Set
  `WEBIFY_RACKET92_CLI_SMOKE=1` to include it. Override `RACKET92_BIN`,
  `PLTCOMPILEDROOTS`, or `PLTCOLLECTS_PREFIX` if your checkout layout differs.

The C FFI/foreign-inline parts of upstream `schemify` are intentionally
omitted here. They target native C embedding and do not currently map to
WebAssembly.
