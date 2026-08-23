# Number Ports

This directory is the source-backed port of Racket's number-related tests.

The port has two layers:

- `cases.rkt` exposes WebRacket/CS differential cases that can run through the
  number oracle.
- `generated/simple-cases.rkt` is generated from the upstream Racket test files
  by `tools/generate-numbers-port-cases.rkt`. Every upstream test-like form that
  the generator sees is recorded either as an executable port case or as an
  explicit skip with a reason.

The existing handwritten `test/number-tower/cases.rkt` corpus is included here
as the current gated suite. Generated upstream cases are recorded as non-gates
until each source family is audited and promoted.

Useful commands:

- Regenerate upstream accounting:
  `racket tools/generate-numbers-port-cases.rkt`
- List source coverage:
  `racket tools/check-numbers-cs.rkt --list-sources`
- Run the current gated CS/WebRacket number port suite:
  `racket tools/check-numbers-cs.rkt`
- Run recorded generated cases too:
  `racket tools/check-numbers-cs.rkt --all`
