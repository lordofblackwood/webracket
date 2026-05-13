# WebRacket Goals

WebRacket has two related but distinct goals. Keeping them separate helps avoid
blocking useful ahead-of-time module support on the much harder problem of
browser-side `eval`.

## Goal 1: Run Module-Based Programs In The Browser

### Why

Most useful Racket programs do not need runtime `eval`. They need their module
graph expanded, compiled, linked, and executed. If WebRacket can run ordinary
module-based programs in the browser, then it can support examples, teaching
programs, demos, and many libraries without first implementing a browser-hosted
expander/compiler.

This is the practical near-term goal.

### How

Use an ahead-of-time pipeline:

```text
Racket module program
  -> host Racket expands/compiles modules to linklet-level information
  -> Webify extracts module/linklet reports
  -> Webify resolves providers, imports, exports, renames, and re-exports
  -> Webify composes module instances and module-variable cells
  -> WebRacket compiler emits Wasm-GC
  -> browser instantiates and runs the Wasm program
```

In this model, the browser does not need to expand source code or compile new
code at runtime. The host/development machine does the heavy lifting, and the
browser receives an executable WebRacket/Wasm artifact.

### Current Progress

This goal is actively progressing.

Implemented or partially implemented:

- Module-linklet inputs and manifests.
- Module registry, module instances, and module-variable cells.
- Import/export resolution for extracted module graphs.
- Provider graph discovery from compiled metadata.
- Handling for source-level and compiled-level renames/re-exports.
- Provider precedence rules for private providers versus broad base re-exports.
- Reflected relative provider normalization, such as resolving `"pico.rkt"` to
  `racket/private/pico`.
- Kernel-origin import handling for `#%kernel`.
- A synthetic kernel export row derived from `primitives-db.rkt`.
- A runtime-gap audit that separates "the resolver can name this primitive" from
  "runtime-wasm.rkt implements this primitive."

Recent successful smokes:

- `racket/list` graph resolution is clean.
- `racket/string` graph resolution is clean.
- Installed-module runtime smokes pass for selected uses of `racket/bool`,
  `racket/fixnum`, `racket/list`, `racket/string`, and `racket/function`.

Known remaining work:

- Grow the set of installed modules and libraries that compile and run.
- Use the runtime-gap audit to prioritize missing Wasm primitives.
- Avoid adding broad runtime support just because a primitive appears in a graph;
  prioritize primitives that are actually executed by useful programs.
- Continue improving diagnostics so failures classify as graph-resolution,
  unsupported-runtime, compiler, or runtime errors.

### Current Goal 1 Supported Subset

The supported Goal 1 path is intentionally ahead-of-time:

- Source modules are expanded and lowered on the host Racket side.
- Webify extracts phase-0 runtime linklet inputs and provider metadata.
- Webify composes a closed module graph into module instances and export cells.
- WebRacket compiles the composed program to Wasm-GC and runs it in the browser.

The browser-side runtime is not expected to expand source, compile new code, or
answer arbitrary collection/module lookup questions. Kernel services such as
syntax serialization, syntax binding-set construction, collection lookup, and
syntax-error construction may be resolvable as metadata names, but they are
explicitly unsupported runtime services unless a Goal 1 program actually needs a
real implementation.

This boundary is useful: it keeps ordinary module programs moving without
accidentally turning Goal 1 into Goal 2.

## Goal 2: Make `eval` Work In The Browser

### Why

Racket has a strong interactive tradition. Browser-side `eval` would make
WebRacket much more than an ahead-of-time compiler target:

- REPLs could run entirely in the browser.
- Teaching environments could evaluate user input without a server.
- Macro experiments and dynamic code examples could be interactive.
- Programs could construct and run code at runtime in a Racket-like way.

This is strategically important, but it is a different problem from running
precompiled module programs.

### How

Full browser `eval` needs a runtime pipeline:

```text
input datum or syntax
  -> read, if starting from text
  -> expand in a namespace
  -> compile to an executable representation
  -> instantiate or run in the current namespace/module state
  -> return values
```

In full Racket, `eval` delegates to `current-eval`, and the default evaluation
handler indirectly uses `current-compile`. The default compiler produces
compiled-expression values, which print as `#~` compiled code. Linklets have
their own API, but Racket's expander implementation can compile linklets through
the underlying compile/eval substrate.

WebRacket does not need to copy Racket's bytecode format, but it needs an
equivalent runtime "compiled code" representation.

The reader is not necessarily a from-scratch problem. Racket's expander tree
already contains a substantial reader subsystem under `src/expander/read`,
including `read`, `read/recursive`, `read-language`, readtables, reader
parameters, strings, chars, vectors, hashes, graph notation, quotes, boxes,
regular expressions, `#reader`, and `#lang` handling. The syntax layer wraps
that reader to provide `read-syntax` and `read-syntax/recursive`.

For WebRacket, the question is therefore not "invent a reader?" but "how much
of the expander reader can run in WebRacket, and what policies do we want for
features that depend on modules, compiled code, or the host filesystem?"

### Current Progress

This goal is still exploratory.

Useful pieces already built for Goal 1 also help Goal 2:

- Module instances and module-variable cells.
- Linklet/module composition experiments.
- Provider graph resolution.
- Kernel primitive classification.
- Runtime support for more Racket values, structs, hashes, syntax objects, and
  exceptions.
- Racket's expander includes a reader implementation that may be portable with
  the expander, instead of writing a new reader from scratch.

But browser `eval` still needs major pieces:

- A browser-side reader integration story: ports, source locations, readtables,
  reader parameters, syntax wrapping, and policies for `#reader`, `#lang`, and
  `#~` compiled input.
- Enough expander support to expand runtime input.
- A namespace/module registry that supports dynamic declarations and lookups.
- A browser-side compiled-code representation.
- Runtime support for expander-heavy primitives, including syntax binding,
  syntax serialization, parameters, paths, exceptions, continuation marks, and
  module path indexes.

### Options For Browser-Side `eval`

#### Option A: Dynamic Wasm Generation

```text
eval input
  -> expand
  -> WebRacket compiler emits new Wasm
  -> browser compiles and instantiates the new Wasm module
```

Pros:

- Reuses the same execution target as ahead-of-time WebRacket.
- Has the best long-term performance story.
- Avoids a second interpreter or bytecode engine.

Cons:

- Hardest implementation path.
- Requires packaging enough of the compiler to run in the browser.
- Requires dynamic Wasm-GC generation and linking against live module state.
- Browser Wasm compilation/instantiation is operationally more complex than
  calling an existing closure.

This is attractive as a long-term endpoint, not as the first bridge.

#### Option B: Closure-Generated Code

This is inspired by Feeley and Lapalme's "Using closures for code generation."
Instead of compiling runtime input to bytecode or Wasm, compile it to a graph of
closures. Each generated closure implements one lowered construct.

```text
eval input
  -> expand/lower
  -> generate WebRacket closures
  -> call the generated closure in an environment/module instance
```

Pros:

- Avoids dynamic Wasm generation.
- More efficient than repeatedly interpreting source because classification and
  lowering happen once.
- Fits WebRacket's existing closure/procedure machinery.
- Can start small and grow construct-by-construct.

Cons:

- Creates a second execution path beside ahead-of-time Wasm compilation.
- Needs careful representation of environments, top-level variables, mutation,
  multiple values, tail calls, and module instances.
- Needs optimization if it is expected to run substantial programs.

This is probably the simplest credible path for a first browser-side `eval`.

#### Option C: Bytecode Or AST Interpreter

```text
eval input
  -> expand/lower
  -> compact bytecode or AST
  -> interpreter loop runs it
```

Pros:

- Easiest to inspect and debug.
- Keeps compiled expressions as ordinary data.
- Avoids dynamic Wasm generation.

Cons:

- Likely slower.
- Creates a parallel virtual machine.
- Every semantic feature must be implemented in the interpreter or bridged to
  WebRacket runtime primitives.

This is useful as a bootstrapping or debugging path, but it risks becoming a
large second runtime.

#### Option D: Linklet Interpreter

```text
eval input
  -> expand to linklet-level form
  -> interpret linklet forms directly
```

Pros:

- Aligns with Racket's module/linklet model.
- Reuses the same lower-level representation used by module extraction.
- Could share module-instance and import/export machinery with Goal 1.

Cons:

- Still an interpreter.
- Needs complete enough linklet semantics: imports, exports, mutation,
  instances, primitive calls, multiple values, and prompts.
- Performance may be limited unless later compiled to closures or Wasm.

This may be a good stepping stone, especially if the interpreter can later be
replaced by closure generation.

#### Option E: Server Or Host Compiler

```text
browser input
  -> send to native Racket or server
  -> expand/compile/run or return artifact
```

Pros:

- Fastest way to get correct Racket behavior.
- Useful as a development oracle.

Cons:

- Not browser-only.
- Requires network access and a trusted server.
- Does not satisfy the core WebRacket goal of self-contained browser execution.

This should be treated as an oracle or development aid, not the final design.

### Suggested Direction

Keep Goal 1 and Goal 2 on separate tracks.

For Goal 1:

```text
prioritize ahead-of-time module programs
  -> expand installed-module coverage
  -> implement runtime primitives as demanded by executable programs
```

For Goal 2:

```text
prototype a tiny browser-side compiled representation
  -> probably closure-generated code or a small linklet interpreter
  -> start with self-evaluating values and primitive applications
  -> then add lexical variables, top-level variables, mutation, and modules
```

Do not block Goal 1 on browser `eval`. The ahead-of-time module path can deliver
useful browser programs much sooner, while the `eval` path can proceed as a
careful research track.
