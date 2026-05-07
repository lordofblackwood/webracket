# Webify Lowering

This document records the first module-variable lowering slice. It is not full
Racket namespace support. It is a small module/linklet instance model for
imports, exports, internal variables, initialization, and mutation.

## Module Variable Model

A module variable is a mutable cell with:

- a value;
- an initialized? bit;
- a constance marker, one of `#f`, `'constant`, or `'consistent`;
- a debug/source name.

The lowering pass does not implement the runtime cell. It rewrites
`schemify`-shaped forms to explicit WebRacket helper names so the remaining
runtime/compiler work has a stable target.

`module-variable.rkt` provides an executable Racket reference model for these
helper names. It is a semantic reference for tests and later runtime/compiler
work; it is not yet the Wasm implementation.

## Rewrites

Module variable forms:

- `(make-internal-variable name)`
  becomes `(module-variable-make name)`.
- `(variable-ref cell)`
  becomes `(module-variable-ref cell)`.
- `(variable-ref/no-check cell)`
  becomes `(module-variable-ref/no-check cell)`.
- `(variable-set! cell rhs)`
  becomes `(module-variable-set! cell rhs)`.
- `(variable-set!/check-undefined cell rhs)`
  becomes `(module-variable-set!/check-undefined! cell rhs)`.
- `(variable-set!/define cell rhs constance)`
  becomes `(module-variable-define! cell rhs constance)`.
- `(set-consistent-variables!/define cells rhss)`
  becomes `(module-variables-define-consistent! cells rhss)`.
- `(make-instance-variable-reference instance cell)`
  becomes `(module-variable-reference instance cell)`.
- `(variable-reference-constant? (make-instance-variable-reference instance cell))`
  becomes a check of `(module-variable-constance cell)`.
- `(variable-reference-from-unsafe? (make-instance-variable-reference instance cell))`
  currently becomes `#f`; Webify is not preserving unsafe-origin metadata in
  module variable reference records yet.

Module prompt forms:

- `(call-with-module-prompt thunk arg ...)`
  becomes `(module-call-with-prompt thunk arg ...)`.

WebRacket does not currently support prompts generally. For the first slice,
`module-call-with-prompt` is an explicit marker for prompt-shaped module
semantics, not a claim that prompts can run. A later lowering/compiler step
must either reject this form clearly or simplify cases that are proven not to
rely on prompt behavior.

`lower.rkt` provides `module-prompt-free?` and `assert-module-prompt-free` so
compiler integration can reject leftover prompt markers before Wasm emission.

It also provides `simplify-trivial-module-prompts`, which simplifies only
prompt shapes whose delimiter can be erased while preserving the module-variable
side effect. The no-metadata shape
`(module-call-with-prompt (lambda () body ...))` calls the thunk body directly.
A single body expression is used directly; multiple body forms become
`(let () body ...)` so internal definitions remain in a body context.

The singleton definition metadata shape is also simplified:

```racket
(module-call-with-prompt (lambda () rhs) '(x) '(constant) x-cell)
```

becomes:

```racket
(module-variable-define! x-cell rhs 'constant)
```

Multi-result metadata prompts remain unsupported because they need a fuller
result-arity story, not merely a dynamic prompt wrapper.

Compiler integration for this first slice should use `lower-module-first-slice`.
It applies module-variable lowering, simplifies trivial prompt wrappers, and
then rejects any remaining module prompt marker.

When starting from a linklet, use `webify-linklet-first-slice` from
`first-slice.rkt`. It calls `webify-linklet`, lowers the returned lambda with
`lower-module-first-slice`, and preserves the import/export metadata values.

For the first compiler-facing bridge, use `module-adapter.rkt`. It wraps an
import-free lowered first-slice lambda as top-level WebRacket forms, because
the current compiler does not support the `module` form. The generated unit
defines the lowered linklet procedure, creates one module-variable cell per
export, invokes the procedure with a placeholder instance plus those cells, and
then defines ordinary top-level bindings by reading the export cells. This is
intentionally still a bridge, not a full module loader. The import-free wrapper
rejects imports. The explicit-import wrapper accepts imported first-slice
linklets only when the caller supplies the import cells directly and the import
ABI metadata says those imports are cells. The generated unit is mainly a way to
drive the existing compiler pipeline on real webify output. The focused adapter
test covers both direct `comp` use and writing the generated top-level datum to
a source file that is compiled by `webracket.rkt --no-stdlib`. The Racket 9.2
compatibility wrapper skips that slower CLI lane by default.

`lower-module-first-slice` also rejects any remaining original `schemify`
module-variable helper forms. The lower-level predicates
`schemify-module-variable-free?` and `assert-schemify-module-variable-free`
are available when an integration point wants to check that invariant
separately.

The first-slice helper also rejects known compatibility forms from `OUTPUT.md`
that still need a WebRacket runtime/lowering story, including application
markers, continuation marks, arity-error helpers, and struct/record helpers.
Use `first-slice-unsupported-free?` or `assert-first-slice-unsupported-free`
when checking that invariant separately.

## Out Of Scope

This slice does not implement:

- full Racket namespaces;
- `namespace-require`;
- `dynamic-require`;
- `eval`;
- phase-separated namespace APIs;
- transformer bindings;
- module registry reflection.
