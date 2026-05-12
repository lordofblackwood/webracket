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

After adding bootstrap `datum-intern-literal`, startup advances again. The
literal-interning blocker is gone, and the next first failure is another
unbound kernel/runtime value:

```text
entry-call: start
js_print_fasl: #(struct exn:fail:contract:variable #<undefined> #f prop:evt)
entry-call: threw
entry-failure-category: unbound-variable
entry-failure-detail: prop:evt
wr-names-count: 0
```

Bridge binding verification and minimal exported calls are still not reachable:
`entry` has not completed, so `wr-names` remains empty and `boot` is still a
missing binding from the console bridge. The next substrate milestone is
event/evt property support, starting with `prop:evt`.

The generated artifact's event-name audit shows `prop:evt` as the current
startup blocker, with additional event operations present for later:

```text
prop:evt
always-evt
never-evt
sync
sync/timeout
make-semaphore
semaphore-post
semaphore-peek-evt
filesystem-change-evt
filesystem-change-evt-ready?
filesystem-change-evt-cancel
progress-evt?
```

For the next patch, keep the scope to a runtime-provided struct-type property
constant for `prop:evt`. Racket CS classifies `prop:evt` as a known
struct-type property, and the expander's first failure is simply an unbound
property value. Real synchronization and filesystem events should remain
separate milestones unless startup actually reaches them.

After adding `prop:evt`, startup advanced to immutable hash removal:

```text
entry-call: start
js_print_fasl: #(struct exn:fail:contract:variable #<undefined> #f hash-remove)
entry-call: threw
entry-failure-category: unbound-variable
entry-failure-detail: hash-remove
wr-names-count: 0
```

`hash-remove` is now registered and implemented for the current immutable hash
slice. It rebuilds the shared private immutable-hash backing store without the
removed key and preserves the existing limitation that all immutable hash
wrappers currently use the eqv-based backing comparison.

The next probe then exposed a constance mismatch in the bootstrap namespace:

```text
entry-call: start
js_print_fasl: variable-reference-constant?
js_print_fasl: cannot modify a constant
entry-call: threw
entry-failure-category: unknown
entry-failure-detail: cannot modify a constant
wr-names-count: 0
```

The expander re-installs some namespace bindings with an explicit constance
mode. WebRacket now rejects ordinary mutation of constants, but permits a
constant or consistent reinstall to replace the value while preserving the
binding's constance.

After that, startup reached the newer error-rendering parameter family:

```text
entry-call: start
js_print_fasl: #(struct exn:fail:contract:variable #<undefined> #f error-syntax->name-handler)
entry-call: threw
entry-failure-category: unbound-variable
entry-failure-detail: error-syntax->name-handler
wr-names-count: 0
```

`error-syntax->name-handler` is now present as a minimal parameter. Its default
handler returns `#f`, which is enough for bootstrap name extraction to decline
without requiring richer syntax analysis.

The current final boundary is the sibling parameter
`error-syntax->string-handler`:

```text
entry-call: start
js_print_fasl: #(struct exn:fail:contract:variable #<undefined> #f error-syntax->string-handler)
entry-call: threw
entry-failure-category: unbound-variable
entry-failure-detail: error-syntax->string-handler
wr-names-count: 0
wr-ref-boot-kind: missing-binding
wr-call-boot-kind: missing-binding
```

Bridge binding verification and minimal exported calls are still gated:
`entry` has not completed, so `wr-names` is empty and `boot` is still missing.
The next substrate milestone should add the remaining error conversion
parameters as bootstrap-compatible parameter primitives, starting with
`error-syntax->string-handler`.

After adding the remaining bootstrap error-string handler parameters, the
closed expander finally reaches the next boundary: generated wasm startup
itself succeeds.

```text
entry-call: start
entry-call: ok
wr-names-call: ok
wr-names-count: 137
```

The full-expander probe now enables the `wr-*` console bridge by default and
keeps top-level aliases only for exported names that do not collide with
WebRacket primitives. That exposes ordinary expander exports such as `boot`
while avoiding primitive-name aliases like `datum->syntax`.

The first bridge-level fix was procedure metadata. A direct reference to
`boot` is not a missing binding anymore, but a WebRacket closure cannot be
encoded as FASL and sent to JavaScript. `wr-ref` now reports procedure refs
using FASL-safe metadata:

```text
wr-ref-boot-status: ok
wr-ref-boot-kind: procedure
wr-ref-boot-value: [boot, 0, #<procedure:boot>]
wr-ref-boot-printed: #<procedure:boot>
```

Reading the Racket expander sources confirms that `boot` is intentionally a
zero-argument procedure:

```racket
;; racket/src/expander/main.rkt
(provide boot ...)

;; racket/src/expander/boot/handler.rkt
(define (boot)
  ...)
```

The next bridge-level fix was argument marshalling. `wr-call` used to cast a
decoded FASL vector's backing `$Array` to `$Args`, which is not a valid Wasm-GC
downcast. It now copies the vector elements into a real `$Args` array before
invoking the target procedure.

That means the current failure is past name lookup, procedure lookup, and
argument marshalling:

```text
wr-call-boot-status: failed
wr-call-boot-kind: exception
wr-call-boot-error: #<undefined>
```

So the current blocker is inside the actual expander `boot` execution path.
The next useful milestone is to localize which operation inside `boot` raises
the undefined exception. The likely candidates are the startup handlers that
`boot` installs (`seal`, module-name resolver, load/use-compiled, reader guard,
eval, compile, load, and read-interaction), not the bridge lookup layer.

## Startup Probe Progress

The current startup probe gets through `entry` and `boot`, and bridge calls can
observe several opaque runtime values by their printed form:

```text
wr-call-read-installation-configuration-table-status: ok
wr-call-read-installation-configuration-table-kind: printed-hash-result
wr-call-read-installation-configuration-table-printed: #hash()

wr-call-current-namespace-status: ok
wr-call-current-namespace-kind: printed-opaque-result
wr-call-current-namespace-printed: #<namespace>

wr-call-make-namespace-status: ok
wr-call-make-namespace-kind: printed-opaque-result
wr-call-make-namespace-printed: #<namespace>
```

The reader entry points are now visible, but they are not yet usable through a
simple host-side `wr-call` smoke:

```text
wr-ref-read-status: ok
wr-ref-read-syntax-status: ok

wr-call-read-status: failed
wr-call-read-kind: exception
wr-call-read-printed: #(struct exn:fail:contract:variable #<undefined> #f port-read-handler)

wr-call-read-syntax-status: failed
wr-call-read-syntax-kind: exception
wr-call-read-syntax-printed: #(struct exn:fail:contract:variable #<undefined> #f port-read-handler)
```

That points at the reader parameter layer, not missing `read` or `read-syntax`
bindings. Also, `open-input-string` is not exported by this expander slice, so a
direct host-side `(read (open-input-string ...))` probe needs either a composed
in-Wasm helper or more of the ordinary port API available through the bridge.
