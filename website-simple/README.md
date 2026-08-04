# WebRacket Simple Website Suggestion

This is a proposal for a smaller WebRacket website that uses WebRacket and
web-easy for the site shell, while letting the Scribble manual remain the
documentation source of truth.

## Goal

Make the website easier to understand on a first visit:

- Explain WebRacket in one screen.
- Send new users to one quick-start path.
- Show a small, curated set of examples.
- Point documentation traffic to the Scribble manual.
- Postpone implementation-status reporting until it is ready to be maintained.

## Suggested Pages

Keep the public site to four primary destinations:

- `Home`
  - What WebRacket is.
  - Why Wasm-GC matters.
  - A small "try it" path.
- `Quick Start`
  - Install, compile, run.
  - One minimal command sequence.
  - Link to the Scribble getting-started section.
- `Examples`
  - Curated examples only.
  - Suggested first set: MiniScheme, Canvas Hexagons, Space Invaders,
    Matrix Rain, JSXGraph gallery, and a few web-easy examples.
- `Documentation`
  - Link to the rendered Scribble manual bundled at
    `docs/webracket/index.html`.
  - Do not duplicate generated FFI pages inside this site.

## Navigation

Top navigation:

```text
WebRacket | Quick Start | Examples | Documentation | GitHub
```

The implementation-status page is intentionally omitted for now.

## Design Direction

Borrow from the new version of the old website, but simplify it:

- Use the Racket-like red accent for important actions.
- Use quiet blue links for technical references.
- Use a warm paper background and white content surfaces.
- Keep cards flat and sparse.
- Keep the logo/wordmark as the first visual signal.
- Avoid separate old/new switches, generated reference navigation, and status
  dashboards.

## Prototype

The first-pass prototype lives in `src/site.rkt` and `src/site.css`.

It is deliberately one page for now. The navigation can later become real
routes, but the first version should prove the simpler information architecture
before we split files.

The build renders the Scribble source from
`pkgs/webracket-doc/scribblings/webracket.scrbl` into `html/`, then copies the
rendered manual into `website-simple/local/docs/webracket/`.

The MiniScheme example is copied into
`website-simple/src/examples/minischeme/` so the replacement website owns the
example it links to. The build compiles it into
`website-simple/local/examples/minischeme/`. By default, the main site uses
`/Applications/Racket v9.2.0.2/bin/racket`, while MiniScheme uses
`/Applications/Racket v8.12/bin/racket` through `WEBRACKET_MINISCHEME_RACKET`
because its staged reader-provider path needs files that are not present in the
local 9.2.0.2 installation.

Build target:

```sh
bash website-simple/src/build.sh
```

The generated page should appear in `website-simple/local/site.html`.
