# Expander Extraction Notes

Webify should treat Racket's expander like the regexp layer: a Racket library
implementation that can be flattened to a closed linklet, then lowered toward
WebRacket one blocker at a time.

## Source Notes

The expander README is in:

```text
/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/README.txt
```

The useful points for Webify are:

- The expander is Racket's front end: reader, macro expander, module system,
  compiler-facing linklet generation, and top-level evaluation.
- The expander package is normally extracted and embedded into the Racket
  executable.
- `bootstrap-run.rkt -sx` is the supported path for extracting a source module
  and its dependencies into a single S-expression linklet.
- Extraction preserves distinct-symbol-per-binding names unless
  `--local-rename` is used.
- Runtime expander code must not depend on host Racket syntax objects or syntax
  functions; extraction checks that host references have been removed.

The exact standalone extraction recipe is in:

```text
/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/main.zuo
```

That file adds the reader knots, direct primitive rewrites, a disallow check for
`make-optional-keyword-procedure`, and the global-state exceptions that Racket
itself accepts for the embedded expander.

## Extraction Command

This command succeeded in the current checkout:

```sh
/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket \
  /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/bootstrap-run.rkt \
  -t /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/main.rkt \
  -c /private/tmp/webracket-expander-extract/cache-src \
  --depends /private/tmp/webracket-expander-extract/expander-dep.rktd \
  ++knot read /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/read/api.rkt \
  ++knot read /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/read/primitive-parameter.rkt \
  ++knot read /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/read/readtable-parameter.rkt \
  ++knot read /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/read/readtable.rkt \
  ++knot read /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/read/number.rkt \
  ++direct linklet \
  ++direct kernel \
  ++disallow make-optional-keyword-procedure \
  --no-global \
  ++global-ok core-forms \
  ++global-ok core-primitives \
  ++global-ok built-in-symbols \
  ++global-ok default-read-handler \
  ++global-ok current-previously-unbound \
  ++global-ok keep-source-locations? \
  ++global-ok rx:path-list \
  ++global-ok load-configure-expand \
  -k /Users/soegaard/Dropbox/GitHub/racket/racket \
  -s -x \
  -o /private/tmp/webracket-expander-extract/expander.rktl
```

The extraction reported:

```text
Traversed 311 modules
Got 298 relevant linklets
Need 245 of those linklets
Code is 3741933 bytes as source
Can remove 1126 of 4001 defined names, keeping 2875
Writing combined linklet to /private/tmp/webracket-expander-extract/expander.rktl
Flattened code is 1909474 bytes
```

The written S-expression artifact was 8,662,735 bytes in this checkout. The
dependency file recorded 310 source dependencies after the version tag.

## Full Compile Probe

The diagnostic probe is:

```sh
racket webify/probe-expander-full-compile.rkt --compile-timeout 30
```

It extracts the same closed expander linklet, lowers the first slice without
top-level export aliases, and then attempts full WebRacket compilation with a
bounded timeout.

Current result:

```text
Traversed 311 modules
Need 245 of those linklets
Can remove 1126 of 4001 defined names, keeping 2875
Flattened code is 1909474 bytes
extract-ms: 35245
read-linklet-ms: 537
webify-lower-ms: 629
exports: 71
compile-ms: 30001
compile-timeout-seconds: 30
```

An unbounded probe was manually stopped after several minutes in the compiler:

```text
user break
  context...:
   compiler.rkt:16685:0: record-label-map!
   compiler.rkt:15791:4: lift!
   ...
   compiler.rkt:15541:0: finish-closure-conversion
```

So the current full-expander status is not a new missing runtime primitive.
Extraction and lowering are fast enough, but full compilation is stuck in the
scale/performance profile of closure conversion.

## Linklet Shape

The flattened expander artifact has no linklet imports:

```racket
(cadr expander-linklet) ; => '()
```

It exports 71 names, including:

```racket
boot
bound-identifier=?
compile
current-compile
current-eval
current-namespace
datum->kernel-syntax
datum->syntax
dynamic-require
eval
eval-top-level
expand
expander-place-init!
identifier-binding
identifier?
make-namespace
namespace-require
read
read-syntax
syntax->datum
syntax-e
syntax-property
syntax?
```

So the immediate Webify problem is not provider-graph composition. The expander
is already closed at the linklet boundary. The next problems are inside the
flattened body: Webify's known-procedure metadata, lowered forms, and WebRacket
runtime support.

## Webify Progress

Running the closed expander linklet through the same first-slice adapter used
for regexp first exposed a missing known-info assumption:

```text
known-procedure-arity-mask: contract violation
  expected: known-procedure?
  given: #f
```

This means Webify is consulting arity metadata for a binding whose known-info
lookup failed. That is a compiler metadata/lowering blocker, not evidence that
the expander cannot be extracted.

The probe classifies this as:

```racket
'known-procedure-metadata
```

That assumption has been fixed for the hash-constructor path that the expander
uses. The next blocker was:

```text
webify: unsupported webify compatibility form remains after lowering: with-continuation-mark*
```

The probe classifies this as:

```racket
'continuation-mark
```

Webify now erases `with-continuation-mark*` as a temporary no-op while
preserving evaluation of the key and value. This is deliberately lossy:
WebRacket will need real continuation marks eventually.

After that bridge, the closed expander linklet lowers through the first-slice
adapter:

```racket
(length exports)                  ; => 71
(first-slice-unsupported-free? v) ; => #t
(module-prompt-free? v)           ; => #t
```

After that, WebRacket compilation exposed regexp literals embedded in the
expander data:

```text
datum->construction-expr: got: #rx"^[\\][\\][?][\\]"
```

The probe used to classify this as:

```racket
'regexp-literal
```

WebRacket now has a compact regexp value representation for reader literals.
The compiler reconstructs literal values with private literal constructors:

```racket
(webracket-literal-regexp       (object-name #rx"..."))
(webracket-literal-pregexp      (object-name #px"..."))
(webracket-literal-byte-regexp  (object-name #rx#"..."))
(webracket-literal-byte-pregexp (object-name #px#"..."))
```

This follows the Reference: regexp reader forms produce compiled regexp values,
and `object-name` returns the source string or bytes that can be passed back to
the matching constructor for equivalent behavior. The WebRacket runtime stores
that source plus a kind tag. It supports literal construction, `object-name`,
and `equal?` by kind/source.

That is deliberately not a regexp matcher. It lets closed linklets that contain
regexp literal data compile without requiring the demodded regexp library to be
present. If the expander later executes a real match such as `regexp-match?`,
that is a runtime-library milestone, not a literal-lifting milestone.

The private constructor names are intentional. The public names `regexp`,
`byte-regexp`, `pregexp`, `byte-pregexp`, and their predicates remain available
for the demodded regexp layer to export without colliding with compiler
primitives.

With regexp literal reconstruction in place, the closed expander linklet now
lowers through the first-slice adapter with regexp literals rewritten to private
constructors. A small representative regexp-literal program compiles to
WebRacket WAT, which keeps the regression focused without making the test suite
compile the whole expander body on every run.

## Next Direction

The next milestone should stay on the expander startup boundary:

1. Run a minimal expander startup call against the compiled first slice.
2. Classify the first runtime failure by missing primitive/runtime substrate
   instead of by extraction or WAT compilation.
3. Keep regexp matching separate: only add it when startup actually needs it,
   or when the demodded regexp layer is intentionally composed.

Likely next substrate investments are syntax objects, namespaces, ports/reader
support, immutable hashes, continuation marks, and linklet/module instance
operations.

## Startup Probe

The current startup repro is:

```sh
racket webify/probe-expander-full-compile.rkt \
  --compile-timeout 480 \
  --compile-memory-mb 2048 \
  --compile-progress-interval 5000 \
  --compile-letrec-basic \
  --enable-cc-analysis \
  --enable-simplify \
  --write-wat /private/tmp/webracket-expander-startup.wat \
  --write-wasm /private/tmp/webracket-expander-startup.wasm \
  --validate-wat

node --experimental-wasm-exnref \
  webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-startup.wasm \
  --call-entry \
  --list-names \
  --ref boot \
  --call boot
```

As of the expander bootstrap primitive milestone, the full compile succeeds
with the basic letrec strategy plus closure-conversion analysis and simplify:

```text
closure-conversion-progress: event=done count=26978 elapsed-ms=6548 detail=((lifted . 26978))
compile-ms: 84576
compile-wat-bytes: 65762860
wasm-tools-parse-status: 0
compile-wasm-bytes: 12031167
```

The generated wasm instantiates, but startup fails during `entry` before any
WebRacket top-level bridge bindings are installed:

```text
instantiate-status: ok
entry-call: start
js_print_fasl: #(struct exn:fail:contract:variable #<undefined> #f continuation-mark-set-first)
entry-call: threw
entry-failure-category: unbound-variable
entry-failure-detail: continuation-mark-set-first
wr-names-count: 0
wr-ref-boot-kind: missing-binding
wr-call-boot-kind: missing-binding
```

So the current first startup blocker is not extraction, provider composition,
regexp literals, immutable hash iteration, `system-type`, or `format`. It is an
unbound continuation-mark helper, currently `continuation-mark-set-first`.

The continuation-mark demand audit against the generated WAT is intentionally
narrow. The relevant names are:

```text
continuation-mark-set-first
current-continuation-marks
exn-continuation-marks
```

`current-continuation-marks` and `exn-continuation-marks` are already WebRacket
runtime primitives. The many generated `ignored-continuation-mark-key...` and
`ignored-continuation-mark-val...` names in the WAT are artifacts of Webify's
temporary `with-continuation-mark*` erasure, where key and value expressions are
still evaluated for effects. They are not separate runtime demands.

After adding a first `continuation-mark-set-first` bootstrap stub, startup gets
one step further: the name is bound, but the expander calls it with four
arguments, not two.

```text
entry-call: start
js_print_fasl: #(struct exn:fail:contract:arity continuation-mark-set-first: arity mismatch;
 the expected number of arguments does not match the given number
  expected: 2
  given: 4 #f)
entry-failure-category: unknown
entry-failure-detail: continuation-mark-set-first: arity mismatch;
 the expected number of arguments does not match the given number
  expected: 2
  given: 4
wr-names-count: 0
```

The next continuation-mark milestone is therefore to widen the bootstrap stub
to the arity shape used by the expander, while preserving the same deliberately
lossy "no mark found" behavior.

The widened bootstrap decision follows the Reference and CS implementation:
`continuation-mark-set-first` accepts 2 to 4 arguments:

```racket
(continuation-mark-set-first marks key)
(continuation-mark-set-first marks key none-v)
(continuation-mark-set-first marks key none-v prompt-tag)
```

For now, WebRacket implements only the "not found" path. It returns `#f` when
`none-v` is omitted and returns `none-v` when it is supplied. This is enough to
keep parameter-like expander code moving without pretending that continuation
marks are implemented. In particular, this does not support parameterization,
break state, syntax-context marks, or mark-sensitive error adjustment. Any code
that depends on observing marks still needs a real continuation-mark runtime.

With the widened stub in place, the continuation-mark startup blocker is gone.
The next startup probe reaches a new unbound variable before any bridge exports
are installed:

```text
entry-call: start
js_print_fasl: #(struct exn:fail:contract:variable #<undefined> #f datum-intern-literal)
entry-call: threw
entry-failure-category: unbound-variable
entry-failure-detail: datum-intern-literal
wr-names-count: 0
wr-ref-boot-kind: missing-binding
```

This means bridge binding verification is not reachable yet. The next substrate
blocker is literal interning, not continuation marks.
