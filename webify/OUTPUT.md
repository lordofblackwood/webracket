# Webify Output Language

`webify-linklet` currently lowers a linklet to a Racket-like lambda plus
import/export metadata. This file records the intended status of the forms
that the pass may emit. The goal is to separate the first WebRacket module
slice from upstream `schemify` compatibility machinery.

## Result Shape

`webify-linklet` returns multiple values:

- `webified`: a lambda whose first argument is `instance-variable-reference`,
  followed by import variables/values and export variables.
- `importss`: external import names, grouped by import group.
- `exports`: external export names, with source-name pairs when needed.
- `import-keys`: revised import keys when inlining adds import groups.
- `imports-abis`: whether each import should be passed as a value or variable.
- `exports-info`: known-value information for cross-linklet optimization.

## First-Slice Core Forms

These are the forms to prioritize for the first WebRacket module slice:

- Literals and quoted literals.
- Variable references and `set!`.
- `lambda` and `case-lambda`.
- `define` and `define-values`.
- `let`, `let-values`, `letrec*`, and `letrec-values` after current rewrites.
- `if`, `begin`, `begin0`, and `begin-unsafe`.
- Direct primitive applications.
- `values` and `call-with-values` for simple multi-value cases.

## Compatibility Forms

These forms are inherited from `schemify` output. They should either be
lowered before Wasm emission or assigned explicit WebRacket runtime meaning.

- Export/import variable operations:
  `variable-ref`, `variable-ref/no-check`, `variable-set!`,
  `variable-set!/check-undefined`, `variable-set!/define`,
  `set-consistent-variables!/define`, and `make-internal-variable`.
- Module-prompt and result-arity wrappers:
  `call-with-module-prompt`, `raise-definition-result-arity-error`, and
  `raise-binding-result-arity-error`.
- Variable-reference support:
  `make-instance-variable-reference`, `variable-reference-constant?`, and
  `variable-reference-from-unsafe?`.
- Application markers:
  `#%app` and `#%app/value`. `#%app/no-return` is currently erased to an
  ordinary application; reinstate a real marker only if WebRacket starts using
  bottom/no-return information for optimization or unreachable-code validation.
- Undefined checks:
  `check-not-unsafe-undefined` and `check-not-unsafe-undefined/assign`.
- Continuation marks:
  `with-continuation-mark` and `with-continuation-mark*`.

## Struct Compatibility Forms

Struct conversion is ported from `schemify`, but its output is still
Chez/Racket-runtime shaped. These forms need a WebRacket lowering or runtime
contract before struct-heavy modules can be part of the first supported slice.
See `STRUCTS.md` for the current WebRacket-specific translation plan; struct
handling should not be treated as a straight Schemify port.

- Record descriptor operations:
  `make-record-type-descriptor`, `make-record-constructor-descriptor`,
  `record-constructor`, `record-predicate`, `record-accessor`, and
  `record-mutator`.
- Struct installation and metadata:
  `make-struct-type-install-properties`, `structure-type-lookup-prefab-uid`,
  `struct-type-constructor-add-guards`, and `#%nongenerative-uid`.
- Struct wrappers and unsafe operations:
  `#%struct-constructor`, `#%struct-predicate`,
  `#%struct-field-accessor`, `#%struct-field-mutator`, `unsafe-struct`,
  `unsafe-sealed-struct?`, `unsafe-struct*-ref`, and `unsafe-struct*-set!`.
- Impersonator/error paths:
  `impersonate-ref`, `impersonate-set!`, `#%struct-ref-error`, and
  `#%struct-set!-error`.

## Out Of Scope For Now

These upstream `schemify` features are intentionally omitted or disabled in
`webify` until WebRacket has a concrete need and runtime story for them.

- C FFI and `#%foreign-inline` support.
- `ffi-static-core`.
- `make-ctype`/`assert-ctype` known-value propagation.
- `compiler-sizeof`.
- `system-type` folding.
- Interpreter/JIT-specific support from upstream `interpret` and `jitify`.
