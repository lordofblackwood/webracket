This folder contains the reader for `#lang webracket`.

`#lang webracket` is currently kept as script-compatible input for
`webracket.rkt`: the driver recognizes the line and compiles the remaining
forms as a top-level program.

The module-oriented Goal 1 path starts with `#lang webracket/base`, whose
reader lives in `base/lang/reader.rkt` and expands through host Racket as a
normal module using language `webracket/base`.

The command-line driver currently supports `#lang webracket/base` with a
transitional bridge: it reads the source as a normal module, strips module-only
declarations such as `provide`, and compiles the body through the existing
top-level compiler path. Full module-provider execution is still tracked as a
future Goal 1 step.

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
