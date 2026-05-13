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

The reader entry points are visible through the bridge. The bridge must call
`entry` before `wr-call`; otherwise, bridge name conversion can run before the
startup path initializes enough runtime state and null-deref while converting
the requested export name to a symbol.

After the bootstrap `port-read-handler` getter, reader accept parameters, and
special-aware byte/char input primitives were added, the empty-argument reader
smoke succeeds through the bridge:

```text
wr-ref-read-status: ok
wr-ref-read-syntax-status: ok

wr-call-read-status: ok
wr-call-read-kind: value
wr-call-read-value: <eof>
wr-call-read-printed: #<eof>

wr-call-read-syntax-status: ok
wr-call-read-syntax-kind: value
wr-call-read-syntax-value: <eof>
wr-call-read-syntax-printed: #<eof>
```

The primitive report confirms the reader now retains the special-input names:

```text
retained-primitives-matches: peek-byte-or-special peek-char-or-special read-byte-or-special read-char-or-special
```

This does not mean the full special-value custom-port protocol is implemented.
The current WebRacket runtime treats these as bootstrap-compatible wrappers
around ordinary byte/char input.

## Real-Input Reader Probe

The console bridge now injects three probe-only helpers into the generated
first-slice program:

```racket
(define (webify-probe-read-string text)
  (read (open-input-string text)))

(define (webify-probe-read-syntax-string source text)
  (read-syntax source (open-input-string text)))

(define (webify-probe-read-syntax-datum-string source text)
  (syntax->datum (read-syntax source (open-input-string text))))
```

This keeps `open-input-string` composition inside Wasm even though
`open-input-string` is not an expander export. The JS probe exposes these via
`--read-string`, `--read-syntax-string`,
`--read-syntax-datum-string`, and `--read-syntax-summary-string`.

After adding `read-case-sensitive`, plain `read` works for basic real input:

```text
wr-read-string-""-status: ok
wr-read-string-""-kind: value
wr-read-string-""-value: <eof>

wr-read-string-"42"-status: ok
wr-read-string-"42"-kind: value
wr-read-string-"42"-value: 42

wr-read-string-"abc"-status: ok
wr-read-string-"abc"-kind: value
wr-read-string-"abc"-value: abc

wr-read-string-"(a b)"-status: ok
wr-read-string-"(a b)"-kind: value
wr-read-string-"(a b)"-printed: (a b)
```

The syntax reader is now the boundary. After adding bootstrap support for
`fprintf`, `print-syntax-width`, `error-print-width`, and the current
no-op `extend-parameterization`, the raw `read-syntax` result no longer throws
a Wasm exception. It now returns a syntax-shaped value that the bridge cannot
FASL-decode:

```text
wr-read-syntax-string-"42"-status: failed
wr-read-syntax-string-"42"-kind: non-fasl-result
wr-read-syntax-string-"42"-failure-category: non-fasl-syntax-result
wr-read-syntax-string-"42"-failure-detail: read-syntax returned a syntax-shaped value that the JS bridge cannot FASL-decode yet
wr-read-syntax-string-"42"-error: The callback attempted to return a WebRacket value with no JavaScript equivalent (i.e. without a FASL encoding): #<syntax:probe.rkt:1:0 ~.s>
```

Asking the helper to convert or summarize the syntax object reaches a sharper
representation mismatch:

```text
wr-read-syntax-datum-string-"42"-status: failed
wr-read-syntax-datum-string-"42"-kind: exception
wr-read-syntax-datum-string-"42"-failure-category: syntax-object-representation-mismatch
wr-read-syntax-datum-string-"42"-failure-detail: read-syntax produced a syntax-shaped value that WebRacket syntax? does not recognize

wr-read-syntax-summary-string-"42"-status: failed
wr-read-syntax-summary-string-"42"-kind: exception
wr-read-syntax-summary-string-"42"-failure-category: syntax-object-representation-mismatch
wr-read-syntax-summary-string-"42"-failure-detail: read-syntax produced a syntax-shaped value that WebRacket syntax? does not recognize
```

So the current reader boundary is no longer bridge composition, EOF handling,
special input, `read-case-sensitive`, formatted output, printer width
parameters, or the bootstrap parameterization extension hook. It is now
syntax-object representation compatibility: the value prints like a syntax
object, but WebRacket's `syntax?` predicate and `syntax->datum` do not accept it.

The primitive report tracks the substrate progress. `fprintf`,
`print-syntax-width`, `error-print-width`, `extend-parameterization`,
`current-parameterization`, and `call-with-parameterization` are now available
to WebRacket. Parameterization support is still intentionally "poor man":
`extend-parameterization` builds a lightweight overlay where later bindings win,
selected runtime parameters consult the active overlay before their global cell,
and `call-with-parameterization` installs the overlay around a thunk with
exception-safe restore. This is enough for reader/printer bootstrap parameters,
but it is not a full continuation-mark-backed parameterization model.

The syntax reader's next milestone should therefore focus on why the
expander-produced syntax-shaped value is not represented as WebRacket's
`$Syntax` value.

After the lightweight parameterization bridge, `parameterization?` is no longer
the immediate missing primitive. A fresh decoded `read-syntax` probe reaches the
reader call but exhausts Node's heap even with `--max-old-space-size=8192`:

```text
node --max-old-space-size=8192 --experimental-wasm-exnref \
  webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-startup.wasm \
  --call-entry \
  --read-syntax-datum-string probe.rkt "42" \
  --read-syntax-summary-string probe.rkt "42"
```

The failure happens after `wr-read-syntax-datum-string-"42": start`, with V8
reporting `FATAL ERROR: Ineffective mark-compacts near heap limit Allocation
failed - JavaScript heap out of memory`. That makes the next reader milestone a
bounded/instrumented `read-syntax` runtime probe, not another missing-binding
chase.

The bounded probe now has two safer helper families:

```text
--read-syntax-phase-string SOURCE TEXT
--read-syntax-class-string SOURCE TEXT
--read-syntax-class-matrix SOURCE
--parameterization-pressure COUNT
```

`--read-syntax-phase-string` logs the phases before and after the raw
`read-syntax` call, without returning the syntax value. `--read-syntax-class-*`
does the same, then tests only whether the result satisfies WebRacket's
`syntax?`, returning the small string `"syntax"` or `"not-syntax"`. This avoids
forcing `syntax->datum`, formatting, or FASL conversion on the returned object.

The parameterization pressure probe is healthy:

```text
wr-parameterization-pressure-1000-status: ok
wr-parameterization-pressure-1000-value: parameterization-pressure:ok
```

That rules out the new poor-man parameterization overlay as the immediate cause
of the read-syntax memory blowup.

The small input matrix shows the real boundary:

```text
wr-read-syntax-class-string-""-value: not-syntax
wr-read-syntax-class-string-" "-value: not-syntax
wr-read-syntax-class-string-"42"-value: not-syntax
wr-read-syntax-class-string-"a"-value: not-syntax
wr-read-syntax-class-string-"()"-value: not-syntax
wr-read-syntax-class-string-"(a)"-value: not-syntax
```

Each of those logs `probe:class:read-syntax:done`, so raw `read-syntax` returns.
The value is syntax-shaped from the expander's perspective, but it is not a
WebRacket `$Syntax` value. The previous OOM therefore comes from the follow-up
conversion path, such as `syntax->datum` or summary extraction, not from token
reading itself.

The `#lang` input takes a separate reader/error path:

```text
wr-read-syntax-class-string-"#lang racket\n42"-failure-category: unbound-variable
wr-read-syntax-class-string-"#lang racket\n42"-failure-detail: error-print-source-location
```

So the next focused work should be the syntax representation bridge for ordinary
datum reads, plus a separate small primitive/stub for
`error-print-source-location` before using `#lang` as a reader probe.

`error-print-source-location` is now present as a bootstrap boolean parameter,
with the same default as Racket (`#t`) and the same poor-man parameterization
overlay behavior as the reader/printer parameters. A fresh `#lang` probe moves
past the missing binding and reaches a real reader-policy error:

```text
wr-read-syntax-class-string-"#lang racket\n42"-failure-category: bridge-call-failure
wr-read-syntax-class-string-"#lang racket\n42"-failure-detail: probe.rkt:1:0: read-syntax: `#lang` not enabled
```

That changes the `#lang` boundary: it is no longer blocked on a missing
primitive. The next `#lang` work is to invoke the reader in a context where
`#lang` is enabled, or add a targeted probe helper that uses the expander's
module-reading path instead of plain `read-syntax`.

## Syntax Representation Probe

The expander-source reading explains why the ordinary `read-syntax` result does
not satisfy WebRacket's `syntax?`. The closed expander has its own syntax-object
implementation:

```text
racket/src/expander/syntax/syntax.rkt
```

That file defines an authentic sealed `syntax` struct with fields for content,
scopes, module-path-index shifts, source location, properties, and inspector.
The public expander API in:

```text
racket/src/expander/syntax/api.rkt
```

wraps that implementation as the expander's `syntax?`, `datum->syntax`, and
`syntax->datum`. Separately, `racket/src/expander/host/correlate.rkt` documents
that the host layer also has names like `syntax?` and `datum->syntax`, but the
expander deliberately distinguishes those host/correlated syntax values from
its own syntax objects.

Inside WebRacket, the runtime `syntax?` predicate recognizes WebRacket `$Syntax`
values. The expander's internal syntax struct is therefore syntax-like, but not
a WebRacket `$Syntax` value. The cheap probe now reports this without forcing
`syntax->datum` or returning the raw object through FASL:

```text
wr-read-syntax-inspect-string-"42"-printed:
  ((eof-object? #f) (syntax? #f) (correlated? #f)
   (struct? #t) (vector? #f) (procedure? #t))
```

The safe datum probe also avoids the earlier V8 heap blow-up by normalizing only
the known-safe cases:

```text
wr-read-syntax-safe-datum-string-""-printed: (eof)
wr-read-syntax-safe-datum-string-" "-printed: (eof)
wr-read-syntax-safe-datum-string-"42"-printed:
  (foreign-syntax (syntax? #f) (correlated? #f)
                  (struct? #t) (vector? #f) (procedure? #t))
wr-read-syntax-safe-datum-string-"a"-printed:
  (foreign-syntax (syntax? #f) (correlated? #f)
                  (struct? #t) (vector? #f) (procedure? #t))
wr-read-syntax-safe-datum-string-"()"-printed:
  (foreign-syntax (syntax? #f) (correlated? #f)
                  (struct? #t) (vector? #f) (procedure? #t))
wr-read-syntax-safe-datum-string-"(a)"-printed:
  (foreign-syntax (syntax? #f) (correlated? #f)
                  (struct? #t) (vector? #f) (procedure? #t))
```

So the next real bridge is not a JS bridge change. It is a representation bridge
between the expander's private `syntax` struct and WebRacket's runtime `$Syntax`
operations. Until that exists, probes should use the safe classifier instead of
calling WebRacket `syntax->datum` on expander syntax values.

The first adapter probe confirms that we can extract useful data using the
expander-owned API surface that survives bridge export filtering. The names
`syntax?` and `syntax->datum` are still hidden by primitive-name collision
avoidance, but the non-colliding export `maybe-syntax->datum` is available and
recognizes the expander-private syntax object:

```text
wr-read-syntax-expander-datum-string-"42"-printed:
  (expander-datum 42)
```

A FASL-safe summary probe now extracts datum and source location without
returning the raw syntax object or a debug hash:

```text
wr-read-syntax-expander-summary-string-"42"-printed:
  ((datum 42)
   (source probe.rkt)
   (line 1)
   (column 0)
   (position 1)
   (span 2)
   (debug-known-keys (context))
   (debug-context-count 0))
```

This is the first practical adapter shape: let the expander keep its own syntax
representation internally, and expose selected summaries through expander-owned
operations. It avoids the previous OOM and avoids treating expander syntax as a
WebRacket `$Syntax` value.

The procedure-shape probe originally exposed an odd `procedure?` result:

```text
wr-read-syntax-procedure-shape-string-"42"-printed:
  ((object-name syntax)
   (procedure? #t)
   (procedure-arity 0)
   (struct-vector-length 8)
   (struct-vector-tag struct:syntax))
```

The expander source does not attach `prop:procedure` to its `syntax` struct.
This was a WebRacket predicate bug: `$Struct` is represented as a subtype of
`$Procedure` so callable structs can be invoked quickly, but public
`procedure?` must still mean "ordinary procedure or struct with
`prop:procedure`." The runtime now checks non-applicable structs semantically,
so plain expander structs report `(procedure? #f)`.

The `#lang` probe also got sharper. Reinstalling `read-accept-lang` with the
poor-man parameterization does not change the result:

```text
wr-read-syntax-lang-parameterized-string-"#lang racket\n42"-failure-detail:
  probe.rkt:1:0: read-syntax: `#lang` not enabled
```

So `#lang` is not blocked by the parameter value. Plain `read-syntax` is being
called in a context where language reading is not enabled. The next `#lang`
milestone should use the expander's module-reading path, or add a helper that
sets up the same read configuration that the module reader expects.

## Eval Substrate Progress

The first `eval` probe originally failed before doing evaluator work:

```text
wr-call-json-eval-failure-category: unbound-variable
wr-call-json-eval-failure-detail: make-semaphore
```

That pointed at the expander namespace registry. The registry uses a reentrant
lock made from `current-thread`, `make-semaphore`, `semaphore-peek-evt`,
`semaphore-post`, `always-evt`, `never-evt`, `sync/timeout`, and `sync`.
WebRacket now has a deliberately small single-threaded substrate for that
cluster:

- `current-thread` returns a stable opaque thread token.
- `make-semaphore`, `semaphore?`, `semaphore-post`, `semaphore-peek-evt`, and
  `semaphore-peek-evt?` model ready counts and peek events.
- `always-evt` and `never-evt` are runtime constants.
- `sync` and `sync/timeout` poll the supported event shapes. They do not block
  or schedule yet; when nothing is ready they return `#f`.

After that cluster, the next `eval` probe advanced to:

```text
wr-call-json-eval-failure-category: unbound-variable
wr-call-json-eval-failure-detail: dynamic-wind
```

That is the cleanup wrapper around the same namespace lock. WebRacket now has a
first `dynamic-wind` implementation that runs before/body/after and invokes
`after` when the body raises. It does not model continuation jumps yet, but it
is enough for ordinary lock cleanup.

With both changes, `eval` no longer fails immediately with an unbound primitive.
The current boundary is heavier: probing `(eval 42)` enters the evaluator and
then exhausts the Node/V8 heap near 8GB instead of returning or raising a
classified WebRacket exception:

```text
wr-ref-eval-status: ok
wr-ref-eval-kind: procedure
wr-call-json-eval: start
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
```

So the milestone moved from "missing primitive" to "eval enters a deep or
non-terminating allocation path." The next eval milestone should add a bounded
or instrumented eval probe, preferably with progress checkpoints around the
expander/evaluator path, before adding more primitives blindly.

The bounded eval probe now runs each eval case in a child Node process with a
smaller heap and a wall-clock timeout, so a runaway eval cannot take down the
main probe process:

```text
node --experimental-wasm-exnref \
  webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-startup.wasm \
  --bounded-eval-matrix 12000
```

The probe helpers log entry and the point just before calling the expander's
`eval`:

```text
probe:eval:entered
probe:eval:before-call
```

There is also a direct lock-substrate sanity probe:

```text
node --max-old-space-size=8192 --experimental-wasm-exnref \
  webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-startup.wasm \
  --call-entry \
  --call-json webify-probe-namespace-lock-sanity-string "[100]"
```

That probe succeeds:

```text
wr-call-json-webify-probe-namespace-lock-sanity-string-status: ok
wr-call-json-webify-probe-namespace-lock-sanity-string-value: namespace-lock-sanity:ok
```

So the current semaphore/event/dynamic-wind substrate is not obviously spinning
on its own.

The bounded eval split initially exposed ordinary missing-primitive work:
`vector*-set!`, then `hash-keys-subset?`, then `unsafe-struct*-cas!`. Those
are now implemented enough for the expander probe:

* `vector*` safe operations are raw vector operations for now, because
  WebRacket does not implement impersonators yet.
* `hash-keys-subset?` iterates keys from the first hash and checks the second
  hash with `hash-has-key?`; it uses the existing generic hash iteration path,
  so it covers both mutable and immutable hash wrappers.
* `unsafe-struct*-cas!` is a single-threaded raw-field compare-and-set. It is
  not a full atomic substrate, but it preserves the expander's success/failure
  protocol for non-impersonated structs.

After those primitive gaps, the bounded eval matrix no longer reports an
unbound primitive. All current eval cases enter the expander eval path and then
abort under the bounded child heap:

```text
webify-probe-eval-self-evaluating:
  probe:eval:entered
  probe:eval:before-call
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed

webify-probe-eval-quoted-symbol:
  probe:eval:entered
  probe:eval:before-call
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed

webify-probe-eval-primitive-app:
  probe:eval:entered
  probe:eval:before-call
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed

webify-probe-eval-local-let:
  probe:eval:entered
  probe:eval:before-call
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
```

So the current eval boundary has moved from "missing primitive" to "eval
allocates or loops heavily immediately after entry." The next milestone should
instrument inside the expander/evaluator path after the `probe:eval:before-call`
checkpoint, or run an even smaller internal evaluator entry point if one can be
exposed from the compiled bundle.

The first safe instrumentation split avoids rewriting expander core functions,
because a source-rewrite attempt that wrapped `expand`/`per-top-level` changed
the generated program enough to stall normal Racket `topexpand`. Instead, the
probe now exports small step helpers for the `42` path:

```text
webify-probe-expand-self-evaluating/datum->syntax
webify-probe-expand-self-evaluating/namespace-introduce
webify-probe-expand-self-evaluating/full
```

The split shows:

```text
webify-probe-expand-self-evaluating/datum->syntax:
  probe:expand-step:datum->syntax:before
  probe:expand-step:datum->syntax:after
  value: datum->syntax:syntax

webify-probe-expand-self-evaluating/namespace-introduce:
  probe:expand-step:introduce:before-datum->syntax
  probe:expand-step:introduce:before-introduce
  failure-detail: namespace-syntax-introduce: contract violation

webify-probe-expand-self-evaluating/full:
  probe:expand-step:full:before
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
```

So `datum->syntax` itself is healthy and produces a value accepted by the
expander's `syntax?`. A direct `namespace-syntax-introduce` on that value fails
with a contract violation, while full `expand` still takes the heavy/OOM path.
That points the next investigation at namespace syntax introduction and the
specific path full `expand` uses to introduce datum input.

The next classification pass showed why the first contract check was suspect:

```text
webify-probe-expand-self-evaluating/namespace-args:
  ((syntax? #t)
   (stx-struct? #t)
   (stx-procedure? #t)
   (stx-object-name syntax)
   (namespace? #f)
   (ns-struct? #t)
   (ns-procedure? #t)
   (ns-object-name namespace))
```

The namespace value is the expander's own authentic `namespace` struct, but
WebRacket's runtime `namespace?` predicate initially recognized only its native
`$Namespace` values. The runtime predicate now includes a bootstrap bridge for
expander namespace structs named `namespace`, after which the same probe reports
`(namespace? #t)`.

That fixes the obvious predicate mismatch, but it does not unlock expansion yet:

```text
webify-probe-expand-self-evaluating/namespace-introduce:
  probe:expand-step:introduce:before-datum->syntax
  probe:expand-step:introduce:before-introduce
  failure-detail: namespace-syntax-introduce: contract violation

webify-probe-expand-self-evaluating/namespace-datum-introduce:
  probe:expand-step:datum-introduce:before
  probe:expand-step:datum-introduce:after
  value: datum-introduce:not-syntax

webify-probe-expand-self-evaluating/namespace-datum-introduce-shape:
  probe:expand-step:datum-introduce-shape:before
  probe:expand-step:datum-introduce-shape:after
  value: ((raised? #f)
          (introduced-shape
           ((syntax? #f)
            (struct? #t)
            (procedure? #t)
            (object-name syntax))))

webify-probe-expand-self-evaluating/namespace-introduce-shape:
  probe:expand-step:introduce-shape:before-datum->syntax
  probe:expand-step:introduce-shape:before-introduce
  value: ((raised? #t)
          (message "namespace-syntax-introduce: contract violation")
          ...)

webify-probe-expand-self-evaluating/full:
  probe:expand-step:full:before
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
```

So the remaining introduction problem is deeper than `namespace?`. Direct
`namespace-datum-introduce` returns but produces a value that the public probe's
`syntax?` does not recognize, even though it is a struct/procedure whose object
name is `syntax`. Direct `namespace-syntax-introduce` still raises a contract
violation after the predicate bridge, including the no-explicit-namespace path.
Attempts to instrument
`namespace-syntax-introduce` by rewriting its source body caused the generated
expander to stall in normal Racket `topexpand`, so the safe path is still
helper-level probes rather than source-rewriting core expander functions.

After the namespace predicate bridge, `expand 42`, the compile probe, and the
bounded eval matrix all still abort under the bounded child heap before
returning. The next likely fault line is a syntax representation split introduced
by namespace-scope manipulation: values can be syntax before namespace
introduction, but the introduced result is not recognized by the same public
probe path.

The next bridge pass clarified that the direct contract failure was a probe
artifact. The first-slice console bridge intentionally avoids defining
top-level aliases for exports whose public names collide with WebRacket
primitives. That meant helper probes using `datum->syntax` and `syntax?` were
calling WebRacket's runtime primitives, not the expander's exported functions.
The probe now defines prefixed aliases such as:

```text
webify-expander:datum->syntax
webify-expander:syntax?
webify-expander:maybe-syntax->datum
webify-expander:namespace-syntax-introduce
```

The comparison is now explicit:

```text
raw:
  runtime syntax? #t
  expander syntax? #f
  struct-vector-length 6
  maybe-syntax->datum self

expander-raw:
  expander syntax? #t
  runtime syntax? #f
  struct-vector-length 8
  expander-maybe-syntax->datum 42

introduced:
  expander syntax? #t
  runtime syntax? #f
  struct-vector-length 8
  expander-maybe-syntax->datum 42
```

So there really are two syntax representations in the generated program:
WebRacket runtime syntax objects and the expander's own authentic syntax
structs. The expander's namespace introduction works when fed expander syntax:

```text
webify-probe-expand-self-evaluating/expander-namespace-introduce:
  probe:expand-step:expander-introduce:before-datum->syntax
  probe:expand-step:expander-introduce:before-introduce
  probe:expand-step:expander-introduce:after-introduce
  value: ((expander-syntax? #t)
          (runtime-syntax? #f)
          (struct-vector-length 8)
          (expander-maybe-syntax->datum 42))
```

That means the remaining `expand 42`/`compile 42`/`eval` OOM boundary is deeper
than the direct `namespace-syntax-introduce` contract check. The next probe
should focus on the full `expand` path after entry, not on direct namespace
introduction.

The expander-correct input probes confirm that direct wrapper construction is
not itself growing unexpectedly:

```text
webify-probe-expand-self-evaluating/wrap-counts:
  runtime-raw:
    runtime syntax? #t
    expander syntax? #f
    struct-vector-length 6
  expander-raw:
    expander syntax? #t
    runtime syntax? #f
    struct-vector-length 8
    expander-maybe-syntax->datum 42
  introduced:
    expander syntax? #t
    runtime syntax? #f
    struct-vector-length 8
    expander-maybe-syntax->datum 42
  datum-introduced:
    expander syntax? #t
    runtime syntax? #f
    struct-vector-length 8
    expander-maybe-syntax->datum 42
```

`read-syntax` also remains healthy when the result is consumed by expander-owned
operations:

```text
webify-probe-read-syntax-expander-datum-string "probe.rkt" "42":
  value: (expander-datum 42)
```

Feeding expander-native syntax into `expand` does not avoid the heap blow-up:

```text
webify-probe-expand-self-evaluating/full-expander-syntax:
  probe:expand-step:full-expander-syntax:before-datum->syntax
  probe:expand-step:full-expander-syntax:before-expand
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed

webify-probe-expand-self-evaluating/full-runtime-syntax:
  probe:expand-step:full-runtime-syntax:before-datum->syntax
  probe:expand-step:full-runtime-syntax:before-expand
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
```

But the direct expander `compile` entry point gives a sharper, non-OOM boundary
when passed expander syntax:

```text
webify-probe-expand-self-evaluating/compile-expander-syntax:
  probe:compile-expander-syntax:before-datum->syntax
  probe:compile-expander-syntax:before-compile
  failure-category: unbound-variable
  failure-detail: current-compile-target-machine
```

So there are now two separate frontiers:

* `expand` still allocates/loops heavily after entry, even with expander syntax.
* direct `compile` reaches a missing runtime/compiler parameter,
  `current-compile-target-machine`, before hitting the same full-expansion OOM
  path.

`current-compile-target-machine` is now implemented as a WebRacket bootstrap
parameter. Its default is the same target marker used by
`(system-type 'target-machine)`, currently `webracket`; the setter accepts any
value for compatibility with the expander/compiler parameter surface. The
compiler also treats it as an optional `[0,1]` primitive, which is necessary so
zero-argument calls lower with the `$missing` sentinel instead of generating an
invalid direct Wasm call.

After that fix, the direct compile probe moved from a classified missing binding
to the same bounded heap failure as `expand`:

```text
webify-probe-expand-self-evaluating/compile-expander-syntax:
  probe:compile-expander-syntax:before-datum->syntax
  probe:compile-expander-syntax:before-compile
  FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
```

The complete gate matrix is now consistent:

```text
webify-probe-expand-self-evaluating/wrap-counts:
  ok

webify-probe-read-syntax-expander-datum-string "probe.rkt" "42":
  value: (expander-datum 42)

webify-probe-expand-self-evaluating/full-expander-syntax:
  before-expand
  OOM

webify-probe-compile-self-evaluating/expand:
  before-expand
  OOM

webify-probe-eval-*:
  before-call
  OOM
```

So the current frontier is no longer a missing compile-target primitive. The
frontier is the first heavy allocation/loop inside expansion itself, after
inputs are already expander-native syntax and after controlled namespace
introduction remains stable.

## Direct Expand Frontier

Reading the expander sources gives the relevant call chain:

```text
expander/eval/api.rkt expand
  -> intro
  -> direct expand from expander/eval/main.rkt
  -> per-top-level
  -> expand-capturing-lifts with only-immediate?
  -> expand-single
  -> expand-capturing-lifts
```

The extracted `main.rkt` export named `expand` is the direct
`expander/eval/main.rkt` entry point, not the public `eval/api.rkt` wrapper. So
the probe alias `webify-expander:expand` already bypasses the public
`intro` wrapper and enters the direct `per-top-level` path.

The newest helper-level probes keep instrumentation outside the expander source
body. That matters because previous source-rewrite instrumentation changed the
flattened program enough to stall normal Racket expansion before WebRacket was
involved.

The pre-expand state probe succeeds:

```text
webify-probe-expand-self-evaluating/pre-expand-state:
  probe:pre-expand-state:before
  probe:pre-expand-state:after
  namespace: struct:namespace, 18 fields
  raw: expander syntax, datum 42
  introduced: expander syntax, datum 42
  module-id: expander syntax, datum module
```

That rules out expander-owned `datum->syntax`,
`namespace-syntax-introduce`, and `namespace-module-identifier` as the current
runaway.

The direct expander flag probes all fail at the same boundary:

```text
webify-probe-expand-self-evaluating/direct-expand-default:
  before-datum->syntax
  before-expand
  SIGABRT: JavaScript heap out of memory

webify-probe-expand-self-evaluating/direct-expand-observable:
  before-datum->syntax
  before-expand
  SIGABRT: JavaScript heap out of memory

webify-probe-expand-self-evaluating/direct-expand-to-parsed:
  before-datum->syntax
  before-expand
  SIGABRT: JavaScript heap out of memory
```

The nonserializable direct compile path reaches the same expansion boundary:

```text
webify-probe-expand-self-evaluating/compile-expander-syntax/nonserializable:
  before-datum->syntax
  before-compile
  SIGABRT: JavaScript heap out of memory
```

So the problem is not the public API wrapper, syntax construction, namespace
introduction, observable expansion mode, parsed-output mode, or serializable
compile output. The current frontier is inside the direct expansion body,
between entering `expander/eval/main.rkt`'s `expand` and returning from the
first `per-top-level`/`expand-capturing-lifts` work.

The next useful milestone should therefore avoid more primitive chasing and
instead expose one narrower internal expander step. Good candidates are:

1. Add a probe-only export for `per-top-level` or `expand-capturing-lifts` in
   the extracted bundle, if it can be done at the linklet/export layer without
   source body rewrites.
2. Add allocation/count instrumentation to WebRacket runtime constructors used
   heavily by syntax scopes, hashes, sets, and lists, then rerun the direct
   expand probe to see which representation is exploding.
3. Compare direct Racket execution of the same extracted direct `expand` call
   against WebRacket to confirm the input path should return quickly for `42`.

## Allocation And Control Spike

The internal functions `per-top-level`, `expand-single`, and
`expand-capturing-lifts` are local definitions in:

```text
/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/eval/main.rkt
```

They are not public exports of the closed `main.rkt` bundle. The safe probe path
therefore remains helper-level instrumentation unless Webify grows a
linklet/export-layer way to expose selected local definitions without rewriting
the expander source body.

WebRacket now has two probe-only debug primitives:

```racket
(webracket-debug-allocation-budget! n)
(webracket-debug-allocation-counters)
```

When a positive budget is installed, selected hot allocation paths count down
and deliberately trap when the budget is exhausted after logging:

```text
allocation-budget-exhausted
((pairs <n>) (vectors <n>) (structs <n>) (hash-sets <n>))
```

The current counted paths are:

```text
runtime $cons
compiler-generated rest-list pair allocation
runtime make-vector/checked
runtime struct-constructor/no-guard
runtime hash-set and hash-set!
```

The healthy setup path remains small:

```text
webify-probe-expand-self-evaluating/pre-expand-budget 1000:
  before-budget
  before
  after
  counters: ((pairs 199) (vectors 0) (structs 6) (hash-sets 5))
```

The direct expand path still aborts with V8 heap exhaustion before exhausting a
budget as low as 250:

```text
webify-probe-expand-self-evaluating/direct-expand-budget 250:
  before-budget
  before-datum->syntax
  before-expand
  SIGABRT: JavaScript heap out of memory
```

That means the runaway is not dominated by the counted helper paths. It is
either in currently uncounted Wasm-GC allocations, such as generated arrays,
closure/application argument arrays, strings/bytes, or direct struct
allocations, or in a host-side/JS allocation path triggered while the wasm call
is running.

A normal Racket control script for expansion of the generated bridged datum now
writes successfully after teaching the free-identifier walker about named
`let`. The generated-control result is scale-useful but not a direct expander
runtime repro:

```text
read-datum-ms: 507
expand-syntax/raw-ms: 410
expand-syntax/raw-result: failed
expand-syntax/introduced-ms: 15442
expand-syntax/introduced-result: ok
expand-top-level-with-compile-time-evals/raw-ms: 17667
expand-top-level-with-compile-time-evals/raw-result: failed
expand-top-level-with-compile-time-evals/introduced-ms: 16332
expand-top-level-with-compile-time-evals/introduced-result: failed
```

The sharper control is the source expander itself. Running the same direct
expander entry on expander-owned syntax for `42` under the newest Racket
checkout fails quickly:

```sh
/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket -e \
  '(require (prefix-in exp: (file "/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/main.rkt")))
   (define ns (exp:current-namespace))
   (define stx (exp:datum->syntax #f 42))
   (time (void (exp:expand stx ns #f #f #f #f)))'
```

Result:

```text
?: literal data is not allowed;
 no #%datum syntax transformer is bound
  at: 42
  context...:
   .../src/expander/eval/main.rkt:319:0: expand-capturing-lifts
   .../src/expander/eval/main.rkt:148:0: expand-single
```

So `expand` of bare `42` is not supposed to succeed in this namespace, but it is
also not supposed to allocate indefinitely. WebRacket should reach the same
fast syntax-error path.

Disabling source-location printing does not avoid the WebRacket runaway:

```text
webify-probe-expand-self-evaluating/direct-expand-no-source-location:
  before-parameter
  before-datum->syntax
  before-expand
  SIGABRT: JavaScript heap out of memory
```

After adding `datum->kernel-syntax` probes, the frontier is a little sharper.
In upstream Racket, both of these source-expander controls return immediately:

```sh
/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket -e \
  '(require (prefix-in exp: (file "/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/main.rkt")))
   (define ns (exp:current-namespace))
   (define stx (exp:datum->kernel-syntax 42))
   (time (displayln (exp:syntax->datum (exp:expand stx ns #f #f #f #f))))'
```

```text
(quote 42)
cpu time: 1 real time: 1 gc time: 1
```

and:

```sh
/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket -e \
  '(require (prefix-in exp: (file "/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/main.rkt")))
   (define ns (exp:current-namespace))
   (define stx (exp:datum->kernel-syntax (quote (quote 42))))
   (time (displayln (exp:syntax->datum (exp:expand stx ns #f #f #f #f))))'
```

```text
(quote 42)
cpu time: 0 real time: 0 gc time: 0
```

The corresponding WebRacket probes reach `before-expand` and then exhaust the
Node heap:

```text
webify-probe-expand-self-evaluating/direct-expand-kernel-datum:
  before-kernel-syntax
  before-expand
  SIGABRT: JavaScript heap out of memory

webify-probe-expand-self-evaluating/direct-expand-kernel-quote:
  before-kernel-syntax
  before-expand
  SIGABRT: JavaScript heap out of memory
```

That means the bug is not only the missing-`#%datum` error path. Even
already-core syntax that upstream expands directly to `(quote 42)` runs away
inside WebRacket.

The allocation budget now reports these buckets:

```text
((pairs N) (vectors N) (structs N) (hash-sets N)
 (closures N) (arg-arrays N) (strings N) (bytes N)
 (value-arrays N) (free-arrays N) (invocations N))
```

After adding generated allocation ticks for closure, argument, value, and free
arrays, the pre-expand path is still small enough to be boring in the useful
way:

```text
pre-expand-budget 1000:
  ((pairs 199) (vectors 0) (structs 6) (hash-sets 5)
   (closures 200) (arg-arrays 309) (strings 0) (bytes 0)
   (value-arrays 0) (free-arrays 42) (invocations 0))
```

Direct expansion still OOMs if only allocation budgets are enabled, so the
runaway is not simply "lots of visible allocation before anything calls back."

The next useful bounded repro is invocation-based. `webracket-debug-invoke-budget!`
counts both dynamic invocations and generated lifted-function entries. With it,
the same direct kernel-syntax probe stops before Node OOMs:

```sh
node --experimental-wasm-exnref webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-startup.wasm \
  --bounded-call-json 10000 \
  webify-probe-expand-self-evaluating/direct-expand-kernel-datum/invoke-budget \
  '[100]'
```

Result:

```text
probe:direct-expand-kernel-datum/invoke-budget:before-budget
probe:direct-expand-kernel-datum/invoke-budget:before-kernel-syntax
probe:direct-expand-kernel-datum/invoke-budget:before-expand
invoke-budget-exhausted
((pairs 0) (vectors 0) (structs 0) (hash-sets 0)
 (closures 0) (arg-arrays 0) (strings 0) (bytes 0)
 (value-arrays 0) (free-arrays 0) (invocations 100))
```

With a budget of 1000 the same two labels are at the top of the runtime stack:

```text
debug-invoke-tick
label.102683
label.75608
wr-call
```

The primitive report classifies those labels as:

```text
label.75608:
  webify-probe-expand-self-evaluating/direct-expand-kernel-datum/invoke-budget
  uses js-log, webracket-debug-allocation-counters, webracket-debug-invoke-budget!

label.102683:
  uses parameterization?, procedure-arity-includes?, procedure?,
       raise-argument-error, void
```

So the current frontier is a tight loop or very deep direct-call path reached
after the probe enters `expand`, with no counted allocation before the
invocation watchdog fires. The next step is to map `label.102683` back to the
expander source form via the label map and then add source-aware progress marks
around that function's neighbors.

Follow-up: focused label map and watchdog identity
--------------------------------------------------

The focused map was regenerated with:

```sh
racket webify/probe-expander-full-compile.rkt \
  --compile-timeout 1000 \
  --compile-memory-mb 2048 \
  --compile-progress-interval 5000 \
  --compile-letrec-basic \
  --enable-cc-analysis \
  --enable-simplify \
  --label-map-form-labels label.102683,label.75608 \
  --write-map /private/tmp/webracket-expander-label-map.sexp \
  --write-primitive-report /private/tmp/webracket-expander-primitives.sexp \
  --write-wat /private/tmp/webracket-expander-startup.wat \
  --write-wasm /private/tmp/webracket-expander-startup.wasm \
  --validate-wat
```

The rebuild is bounded and alive: closure conversion reports 27,183 lifted
functions and finishes in about 6-7 seconds once reached. The whole extraction
and compile still takes about 110 seconds, but it is not stuck in the compiler.

The map identifies `label.102683` as the lowered `call-with-parameterization`
guard wrapper:

```racket
(lambda (paramz_0 thunk_0)
  (if (#%plain-app (#%top . parameterization?) paramz_0)
      (#%plain-app void)
      (#%plain-app raise-argument-error
                   'call-with-parameterization
                   "parameterization?"
                   '0
                   paramz_0
                   thunk_0))
  (if (if (#%plain-app procedure? thunk_0)
          (#%plain-app procedure-arity-includes? thunk_0 '0)
          '#f)
      (#%plain-app void)
      (#%plain-app raise-argument-error
                   'call-with-parameterization
                   "(-> any)"
                   '1
                   paramz_0
                   thunk_0))
  (#%plain-app call-with-parameterization
               paramz_0
               (lambda () (#%plain-app thunk_0))))
```

The relevant detail is the last call: it calls `call-with-parameterization`
again by the same top-level name. The first hypothesis was therefore
primitive/provider alias recursion: a lowered provider wrapper might be calling
itself instead of WebRacket's runtime primitive.

The focused budget series now reports the current procedure identity:

```text
budget 10:
  stops before expand while building kernel syntax
  failure-detail: #<procedure:to-srcloc-stx>

budget 50:
  before-expand
  invoke-budget-exhausted
  ((current-procedure false))
  ((name label.102683))
  ((debug-id false))
  ((invocations 50))

budget 100:
  same as budget 50, with ((invocations 100))

budget 1000:
  same as budget 50, with ((invocations 1000))
```

The `direct-expand-kernel-quote/invoke-budget` probe with budget 100 reaches
the same `label.102683` trap, so this is not specific to the datum `42` path.

One guard mismatch was fixed while classifying this: WebRacket's runtime
initialized `current-parameterization-value` to `#f`, even though
`call-with-parameterization` expects a `parameterization?`. Runtime startup now
installs an empty `$Parameterization`, and the Racket-side dummy
`current-parameterization` returns an empty WebRacket parameterization marker.
That makes the guard semantics line up with the intended baseline, but it does
not by itself fix the alias recursion.

Follow-up: runtime-preferred primitive alias rule
------------------------------------------------

Webify now treats `call-with-parameterization` as a runtime-preferred primitive
alias. This is intentionally narrow: the name is a runtime protocol primitive in
WebRacket, and a provider wrapper must not shadow it when generated code refers
to the protocol operation.

The compiler changes are:

```text
categorize-applications:
  calls to call-with-parameterization become primapp forms

direct-call analysis:
  call-with-parameterization wrappers are not classified as direct local labels

code generation:
  references to the name use the runtime primitive
  stores to the top-level alias evaluate and drop the RHS instead of replacing
  the runtime binding

label map:
  focused forms can report
  (runtime-preferred-primitive-aliases call-with-parameterization)
```

After rebuilding the expander startup wasm, the direct WAT call sites to the
wrapper are gone:

```sh
wasm-tools print /private/tmp/webracket-expander-startup.wasm |
  rg -n "call \\$label\\.102683|return_call \\$label\\.102683"
```

That search now produces no matches. So the simple direct-call alias recursion
route has been fixed or ruled out.

The runtime frontier did not move, though. The invocation-budget probes still
stop at the same wrapper:

```text
budget 100:
  before-expand
  invoke-budget-exhausted
  ((name label.102683))
  ((invocations 100))

budget 1000:
  before-expand
  invoke-budget-exhausted
  ((name label.102683))
  ((invocations 1000))

budget 10000:
  before-expand
  invoke-budget-exhausted
  ((name label.102683))
  ((invocations 10000))
```

The refined conclusion is that `label.102683` is definitely a hot dynamic
frontier for direct expansion, but it is no longer explained by direct calls to
the wrapper label in generated wasm. The next investigation should trace how the
wrapper is reached dynamically: either through a closure value stored in the
provider/module environment, through an indirect alias cell, or through a
legitimate repeated parameterization path that is hiding the real non-progress
inside the thunk.

Follow-up: wrapper argument trace
---------------------------------

The next probe added a watched-label hook for `label.102683`. It does not
rewrite the expander source; generated code for the focused label calls a
runtime debug helper with the raw `$Args` array. The helper logs only while an
invoke budget is active and caps output to the first dozen wrapper entries.

The standalone parameterization stress probe succeeds:

```text
webify-probe-parameterization-pressure-string 1000:
  parameterization-pressure:ok
```

So the WebRacket `call-with-parameterization` primitive can install and restore
parameterizations repeatedly in isolation.

The rebuilt expander startup wasm still has no direct calls to the wrapper:

```sh
wasm-tools print /private/tmp/webracket-expander-startup.wasm |
  rg -n "call \\$label\\.102683|return_call \\$label\\.102683"
```

The only focused generated call is the probe hook:

```text
call $debug-watch-label102683
```

The direct expand probes now show the shape of the repeated dynamic path:

```text
call-with-parameterization-wrapper-entry
((argc . (2 . null)))
((arg0-parameterization? . (true . null)))
((arg1-procedure? . (true . null)))
((arg1-name . (false . null)))
((arg1-debug-id . (label.84947 . null)))

call-with-parameterization-wrapper-entry
((argc . (2 . null)))
((arg0-parameterization? . (true . null)))
((arg1-procedure? . (true . null)))
((arg1-name . (false . null)))
((arg1-debug-id . (label.102684 . null)))
```

After the first entry, both `direct-expand-kernel-datum/invoke-budget` and
`direct-expand-kernel-quote/invoke-budget` repeat with thunk debug id
`label.102684` until the invocation budget is exhausted at `label.102683`.

The focused label map identifies the relevant labels:

```racket
label.102683:
  (lambda (paramz_0 thunk_0)
    ...
    (#%plain-app call-with-parameterization
                 paramz_0
                 (lambda () (#%plain-app thunk_0))))

label.102684:
  (lambda () (#%plain-app thunk_0))

label.84947:
  (lambda ()
    (let-values ([(temp98_3)
                  (lambda (s_755 ns_123 as-tail?_5)
                    (#%plain-app expand-single.1 ...))])
      (#%plain-app per-top-level.1 ... temp98_3 ...)))
```

This refines the failure classification again. The arguments are valid, and the
runtime primitive works in isolation. The non-progress is now specifically a
dynamic wrapper/thunk cycle: the provider wrapper receives a proper
parameterization and a proper thunk, then repeatedly invokes the wrapper-created
`label.102684` thunk. The next milestone should decide whether the wrapper is
still being reached through an alias cell in the provider/module environment, or
whether the expander's `per-top-level` path is repeatedly installing the same
parameterization because some inner expander condition never advances.

Follow-up: primitive bypass and new frontier
--------------------------------------------

The wrapper/self-call path was then inspected in generated wasm. The lowered
`label.102683` body ended with:

```text
local.get $clos
local.get $$paramz_0.1394
<make label.102684 thunk>
array.new_fixed $Args 2
return_call $label.102683
```

So the remaining cycle was not a module binding lookup after all. It was a
direct `selfapp` optimization for the provider wrapper. The compiler now has a
focused bypass for this watched label: the wrapper's self-call to
`call-with-parameterization` is emitted as a direct call to the runtime
`$call-with-parameterization` primitive instead of a tail-call back to
`$label.102683`.

After rebuilding, the bounded trace changed as expected:

```text
call-with-parameterization-wrapper-entry
((arg1-debug-id . (label.84947 . null)))

call-with-parameterization-primitive-entry
((arg1-debug-id . (label.102684 . null)))

invoke-budget-exhausted
((name . (label.86928 . null)))
```

That proves the provider wrapper now reaches the runtime primitive, and the
frontier moves beyond the old `label.102683` cycle. The new budget frontier,
`label.86928`, is a small box-clear helper: it unboxes a box, applies a stored
procedure to the old value, then clears the box with `set-box!`. That looks like
real expander cleanup/lift plumbing rather than the parameterization alias bug.

The unbudgeted direct kernel probes now split:

```text
direct-expand-kernel-quote:
  before-kernel-syntax
  before-expand
  after-expand
  expander-maybe-syntax->datum: (quote 42)

direct-expand-kernel-datum:
  before-kernel-syntax
  before-expand
  failure-category: unbound-variable
  failure-detail: call-with-continuation-barrier
```

This is a major milestone: the known-good upstream shape for
`(datum->kernel-syntax '(quote 42))` now runs to completion in WebRacket. The
plain datum path no longer OOMs; it reaches the next ordinary missing primitive.
Upstream `expander/eval/main.rkt` confirms the direct control path:

```text
expand
  -> parameterize current-expand-observe
  -> per-top-level
  -> expand-single
  -> expand-capturing-lifts
```

The next frontier is therefore no longer the parameterization wrapper. It is
supporting `call-with-continuation-barrier` enough for the expander's datum path
and error/control plumbing.

Follow-up: continuation barrier and structural wrapper bypass
-------------------------------------------------------------

`call-with-continuation-barrier` is now available as a WebRacket primitive and
as a `#lang webracket` dummy binding. This first implementation is intentionally
only a bootstrap approximation:

```racket
(call-with-continuation-barrier thunk) => (thunk)
```

That is enough while WebRacket does not implement first-class continuation
jumps. If `call/cc`, aborts, or prompt jumps are reinstated, the primitive must
become a real delimiter for continuation jumps.

Adding another probe shifted the generated label numbers, which exposed that
the old `label.102683` bypass was too brittle. A broader "source mentions
call-with-parameterization" rule was also wrong: many helper labels mention the
name without being the tiny provider wrapper. The compiler now uses structural
recognition instead. During closure conversion it records only labels whose
source syntax has this shape:

```racket
(lambda (arg0 arg1)
  ...
  (#%plain-app call-with-parameterization ...))
```

Those labels are allowed to bypass an ordinary `selfapp` back to the generated
label and call the runtime primitive directly. The recognizer is deliberately
syntax-level and shallow; a full `syntax->datum` scan over every lifted label
made closure conversion jump from about 7 seconds to about 112 seconds on the
expander bundle.

A stable smoke checker captures the current kernel-expansion frontier:

```text
racket webify/check-expander-kernel-smoke.rkt /private/tmp/webracket-expander-startup.wasm
```

It verifies that the kernel quote probe still expands to `(quote 42)`, and
that both the kernel datum and small kernel `let` probes run to completion.
The datum probe now returns expander syntax whose expander-owned
`maybe-syntax->datum` summary is `(quote 42)`.

```text
webify-probe-expand-self-evaluating/direct-expand-kernel-datum
  probe:direct-expand-kernel-datum:after-expand
  expander-maybe-syntax->datum: (quote 42)
```

The old plain `let` probe also returns expander syntax, but it is not a good
"core let" proof:

```text
webify-probe-expand-self-evaluating/direct-expand-kernel-let
  before-kernel-syntax
  before-expand
  after-expand
  expander-maybe-syntax->datum:
    (#%app (#%top . let) (#%app (#%app (#%top . x) (quote 1))) (#%top . x))
```

That shape is expected for this probe: `let` is source syntax, while the kernel
core form is `let-values`. The current stable expansion matrix therefore uses
real kernel forms in addition to the plain-`let` sanity marker:

```text
direct-expand-kernel-quote:         (quote 42)
direct-expand-kernel-datum:         (quote 42)
direct-expand-kernel-let:           (#%app (#%top . let) ...)
direct-expand-kernel-let-values:    (let-values (((x) (quote 1))) x)
direct-expand-kernel-if:            (if (quote #t) (quote yes) (quote no))
direct-expand-kernel-lambda:        (lambda (x) x)
direct-expand-kernel-primitive-app: (#%app (#%top . +) (quote 1) (quote 2))
```

The root cause of the previous `application: not a procedure` frontier was
`procedure?` returning true for all structs. In the expander, `transformer?`
uses `(procedure? t)` before the core-form path. Since `core-form` is a plain
struct, WebRacket misclassified it as an ordinary transformer and later tried
to apply the `core-form` record itself. Fixing semantic `procedure?` lets the
expander dispatch through `core-form-expander` as intended.

Compile now reaches a later frontier. Adding `current-compile-realm` as a
parameterized bootstrap primitive moved `compile-kernel-datum` past the missing
primitive failure:

```text
webify-probe-expand-self-evaluating/compile-kernel-datum
  probe:compile-kernel-datum:before-kernel-syntax
  probe:compile-kernel-datum:before-compile
  failure-detail: raise-binding-result-arity-error: result arity mismatch;
```

So the next frontier is no longer expansion of small kernel forms. It is the
compiler path's binding result arity handling.

Follow-up: compile bridge and ordinary syntax frontier
------------------------------------------------------

The binding-result arity frontier has been cleared for the focused kernel
compile path. `compile-linklet`/`recompile-linklet` now preserve the Racket CS
two-value protocol when import keys are supplied, and linklet-shaped datums
produce metadata-only compiled-linklet placeholders. The stable smoke matrix now
checks both expansion and compile for small kernel forms:

```text
compile-kernel-datum:         returned
compile-kernel-quote:         returned
compile-kernel-let-values:    returned
compile-kernel-if:            returned
compile-kernel-lambda:        returned
compile-kernel-primitive-app: returned
```

The next non-kernel probe initially failed with:

```text
procedure-arity-frontier
debug-id: label.102809
expected-count: 2
received-count: 0
```

The focused label map identified `label.102809` as the body procedure created
inside the expander's `call-handled-body` helper:

```racket
(lambda (bpz body-thunk)
  ... (body-thunk))
```

The root cause was Webify's temporary prompt lowering:

```racket
(call-with-continuation-prompt thunk tag handler arg ...)
```

was lowered to:

```racket
(thunk)
```

That was too aggressive. Even while WebRacket treats prompts as a bootstrap
no-op, Racket still applies the prompt thunk to the arguments after the prompt
tag and handler. The lowering now preserves those arguments:

```racket
(call-with-continuation-prompt thunk tag handler x y)
;; =>
(thunk x y)
```

After that fix, the next failure was an unbound `exception-handler-key`. It is
now bootstrapped like `break-enabled-key` and `parameterization-key`: a stable
symbol value is installed in the `#%paramz` primitive table and in the runtime
constant environment. This keeps continuation-mark key evaluation intact
without pretending that full continuation marks are implemented.

The current smoke frontier is intentionally sharper:

```text
webify-probe-expand-self-evaluating/full-expander-syntax/invoke-budget:
  before-expand
  failure-detail: ?: literal data is not allowed;

webify-probe-expand-self-evaluating/compile-expander-syntax/invoke-budget:
  before-compile
  failure-detail: ?: literal data is not allowed;
```

That is the same kind of fast source-expander error seen in upstream Racket for
bare ordinary syntax `42` in this namespace: no `#%datum` transformer is bound.
The important regression guard is that this path no longer OOMs, no longer hits
the old procedure arity frontier, and no longer fails on `exception-handler-key`.

The next useful milestone is to feed ordinary syntax through a namespace that
has the expected datum/core bindings, or to add a focused probe that expands a
non-literal ordinary form whose bindings are known to be present. Kernel syntax
is already green; ordinary source syntax now reaches a real expander error path.

Follow-up: ordinary syntax through a kernel namespace
----------------------------------------------------

The focused ordinary-syntax path is now green. The key detail from upstream
Racket is that a fresh expander namespace does not automatically bind
`#%datum`, `#%app`, `quote`, `if`, `lambda`, `let-values`, or `+`. The working
recipe is:

```racket
(namespace-require '(quote #%kernel) ns)
(namespace-syntax-introduce (datum->syntax #f datum) ns)
```

Webify now has focused probes for that recipe:

```text
ordinary-kernel-binding-audit:
  ((#%datum #t) (#%app #t) (quote #t) (if #t)
   (lambda #t) (let-values #t) (+ #t))

ordinary-kernel-datum:
  (quote 42)

ordinary-kernel-primitive-app:
  (#%app + (quote 1) (quote 2))

ordinary-kernel-if:
  (if (quote #t) (quote 1) (quote 2))
```

The runtime blocker uncovered by this probe was `hash-ref-key`, which the
expander uses while interning phase-and-space keys. WebRacket now implements
`hash-ref-key` as a real primitive for mutable hashes and for the current
immutable HAMT representation, including the normal failure/default behavior.

The older `full-expander-syntax/invoke-budget` probe is intentionally still a
negative smoke: it feeds bare ordinary syntax into the current namespace without
the explicit `#%kernel` require/introduction step, so it should keep reaching
the fast `literal data is not allowed` frontier instead of regressing to OOM,
arity failures, or missing bootstrap values.

Follow-up: ordinary compile and namespace frontier
--------------------------------------------------

The next five-probe slice keeps three lanes separate:

* direct kernel syntax still expands and compiles;
* ordinary syntax works after an explicit `#%kernel` require/introduction step;
* `racket/base` namespace setup is tracked as its own frontier.

The ordinary binding-shape probe now reports more than booleans. It shows which
required identifiers are core forms and which are runtime bindings:

```text
ordinary-kernel-binding-shapes:
  (#%datum    module-binding core? #t runtime? #f)
  (#%app      module-binding core? #t runtime? #f)
  (quote      module-binding core? #t runtime? #f)
  (if         module-binding core? #t runtime? #f)
  (lambda     module-binding core? #t runtime? #f)
  (let-values module-binding core? #t runtime? #f)
  (+          module-binding core? #f runtime? #t)
```

That gives the probe a cheap regression guard for "namespace has the right
shape", not merely "some binding exists".

The ordinary compile lane is now green for the small forms:

```text
compile-ordinary-kernel-datum:         returned
compile-ordinary-kernel-primitive-app: returned
compile-ordinary-kernel-if:            returned
compile-ordinary-kernel-lambda:        returned
```

This is stronger than the earlier expansion-only result. It means WebRacket can
feed ordinary source syntax through `namespace-require '(quote #%kernel)`,
introduce it with the expander namespace, and reach the expander's `compile`
entry successfully for these small forms.

Follow-up: eval bridge and require contract frontier
----------------------------------------------------

The tiny eval probe now gets past the previous post-compile arity failure:

```text
eval-ordinary-kernel-primitive-app:
  probe:eval-compile:after-compile
  probe:eval-compile:after-call
  probe:eval-ordinary-kernel-primitive-app:after-eval
  value: 0
```

This is deliberately not claiming that `eval` of `(+ 1 2)` computes `3` yet.
The compiled value returned by the expander is a `compiled-in-memory` struct,
not a linklet, linklet bundle, or linklet directory:

```text
compile-ordinary-kernel-summary:
  object-name:          compiled-in-memory
  struct-vector-length: 17
  linklet-directory?:   #f
  linklet-bundle?:      #f
  linklet?:             #f
```

The runtime `compile-linklet` placeholder used to carry `$dummy-closure`, whose
arity is exactly zero. When the expander/evaluator called it with runtime
arguments, that produced the old `#f: arity mismatch` frontier. WebRacket now
uses a separate placeholder linklet closure with arity-at-least zero. That
clears the bridge-call shape problem and exposes the real remaining work:
executing the compiled-in-memory/linklet body instead of returning the
metadata-only placeholder result `0`.

The next inspection probe shows why this is not just a WebRacket
`CompiledLinklet` problem. The `compiled-in-memory` value is an expander struct
with 17 fields. Field 1 is itself an expander `linklet-directory` struct, and
field 15 is a `namespace-scopes` struct:

```text
compiled-in-memory-fields:
  field 1:  object-name linklet-directory, struct-vector-length 2
  field 15: object-name namespace-scopes,  struct-vector-length 3
```

Those are not WebRacket's runtime `linklet-directory?` / `linklet-bundle?`
wrappers, which is why the top-level summary still reports:

```text
linklet-directory?: #f
linklet-bundle?:    #f
linklet?:           #f
```

So the eval bridge needs to learn the expander's compiled-in-memory/linklet
directory representation, not merely instantiate WebRacket's own
metadata-only `CompiledLinklet` wrapper. To keep the runtime side honest,
metadata-only compiled linklets now use a distinct placeholder closure whose
body raises if it is actually invoked; import/export inspection remains
available, but the placeholder body should no longer be treated as executable
semantics.

The `racket/base` namespace setup probe also moved. The first attempt exposed
a missing `raise-arguments-error` primitive. WebRacket now has a bootstrap
implementation and the compiler lowers its rest arguments through the same
`$Args` convention used by other variadic primitives, including the exact
two-argument case where the rest array is empty.

After that fix, `racket/base` no longer stops on an unbound
`raise-arguments-error`. The current frontier is:

```text
racket-base-require:
  probe:racket-base-require:before-require
  failure-category: bridge-call-failure
  failure-detail: require: contract violation
```

That is a better next problem: the require path is now executing far enough to
raise an ordinary contract error, not failing because a bootstrap exception
primitive is absent or miscompiled.

The focused require probes now catch that exception so the smoke matrix can
compare several module paths without treating the process exit as the signal:

```text
racket-base-require/catch:
  (require-failed (message require: contract violation ...))

racket-bool-require/catch:
  (require-failed (message require: contract violation ...))

racket-base-via-kernel-then-base/catch:
  probe:racket-base-via-kernel/catch:before-kernel
  probe:racket-base-via-kernel/catch:before-base
  (require-failed (message require: contract violation ...))
```

That comparison matters because `racket/bool` is a small provider and
kernel-then-base explicitly preloads `#%kernel`. Seeing the same contract
frontier in all three cases means the next blocker is probably in the
module/require contract path itself, not simply a missing initial `#%kernel`
namespace setup and not something unique to the size of `racket/base`.

The caught exception payload is now a little sharper:

```text
racket-base-require/catch:
  (require-failed
    (message "require: contract violation\n  expected: unknown module")
    (shape object-name exn:fail:contract))

racket-bool-require/catch:
  same: expected unknown module

racket-base-via-kernel-then-base/catch:
  same: expected unknown module
```

The smaller provider controls are useful:

```text
kernel-require/catch:
  require-ok, binds #%datum/#%app/quote/if/lambda/let-values/+.

paramz-require/catch:
  require-ok, binds parameterization-key and exception-handler-key.
```

That narrows the require problem: built-in bootstrap providers such as
`#%kernel` and `#%paramz` are loadable, but ordinary module paths like
`racket/base` and `racket/bool` are still classified as unknown modules by the
current WebRacket/expander module-name-resolution bridge.

Finally, the WebRacket runtime linklet wrappers themselves still satisfy their
own boundary invariants:

```text
linklet-boundary-audit:
  compiled linklet?: #t
  imports:           ((x))
  exports:           (y)
  bundle?:           #t
  directory?:        #t
  instance?:         #t
```

The mismatch is therefore between the expander's compiled module/linklet
directory structures and WebRacket's runtime wrappers, not a total absence of
runtime linklet, bundle, directory, or instance values.

Follow-up: decoding the expander linklet directory
--------------------------------------------------

The next bridge probe reads the expander-side `linklet-directory` structurally
with `struct->vector`. That confirms the direct layout from
`src/expander/compile/linklet.rkt`: a two-slot struct whose payload field is a
hash.

For a tiny compiled ordinary expression, the directory payload is:

```text
compiled-linklet-directory-hash:
  directory:
    object-name: linklet-directory
    payload:     hash-count 1
    entries:     #f -> linklet-bundle

  main-entry:
    object-name: linklet-bundle
    payload:     hash-count 3
    entries:     original-phase, max-phase, 0
```

That gives us the first concrete adapter target:

```text
compiled-in-memory
  field 1: expander linklet-directory
    ht[#f] -> expander linklet-bundle
      ht[0] -> phase-0 linklet payload
```

A deliberately naive adapter probe copies the expander directory hash into a
mutable `hasheq` and passes it to WebRacket's runtime
`hash->linklet-directory`. It fails as expected:

```text
compiled-directory-adapter/catch:
  adapter-failed
  hash->linklet-directory: contract violation
```

The important point is that mutability is not the only mismatch. The copied
value is still an expander `linklet-bundle` struct whose payload contains
encoded/compiled linklet data, not WebRacket runtime `LinkletBundle` and
`CompiledLinklet` values. The next adapter must translate recursively:

```text
expander linklet-directory -> WebRacket LinkletDirectory
expander linklet-bundle    -> WebRacket LinkletBundle
phase payload / FASL bytes  -> executable or inspectable WebRacket linklet data
```

The module-name resolver probe also clarified a limitation of the current probe
surface. `current-module-name-resolver` is protected in the expander primitive
layer and is not exposed through the first-slice alias table, so the direct
resolver audit reports:

```text
module-name-resolver-audit:
  resolver-unavailable
  object-name exn:fail:contract:variable
```

For now the useful module-resolution signal is therefore the caught
`namespace-require` result, not a direct call to the resolver. Those require
probes already show that `#%kernel` and `#%paramz` resolve, while `racket/base`
and `racket/bool` reach `expected: unknown module`.

Finally, a tiny ordinary module experiment is not through the frontier yet:

```text
tiny-module-require/catch:
  before eval module
  eval-compile:before-compile
  exn:fail:contract:variable
```

This says the current eval namespace still does not have the right module-form
binding/protocol to declare and then require an ordinary module. That is a
smaller version of the same problem: Webify can inspect expander compiled
module products, but has not yet wired an ordinary module declaration into the
runtime module registry that `namespace-require` consults.

Follow-up: opening the phase-0 payload box
------------------------------------------

The next probe compared four tiny ordinary expressions:

```text
42
(+ 1 2)
(lambda (x) x)
(let-values ([(x) 1]) x)
```

All four have the same outer compiled shape:

```text
compiled-in-memory
  linklet-directory payload hash-count 1
  #f -> linklet-bundle
    payload hash-count 3
    keys: original-phase, max-phase, 0
```

The `original-phase` and `max-phase` entries are numbers. The phase `0` entry
is not exposed to WebRacket as ordinary bytes or as an ordinary compound value:

```text
phase-0:
  syntax?           #f
  struct?           #f
  procedure?        #f
  object-name       #f
  bytes?            #f
  immutable-bytes?  #f
  mutable-bytes?    #f
  pair?             #f
  vector?           #f
  hash?             #f
```

That refines the earlier "FASL-looking bytes" observation. The error printer
for the expander `linklet-bundle` can show a `#~...8.12...expB...`-looking
payload, but WebRacket does not receive phase `0` as a normal byte string that
`bytes?`, `bytes-length`, or the existing FASL helpers can inspect. The bytes
boundary is therefore still inside the expander/linklet serialization layer.

So the next execution strategy should not start with WebRacket's existing FASL
reader. There are three realistic paths:

```text
1. Expose/reflect the expander linklet-bundle payload through expander-side
   accessors, so WebRacket can obtain ordinary inspectable data.

2. Teach WebRacket about the expander's opaque serialized linklet payload
   format directly, but only after finding the serializer/deserializer boundary
   in the Racket expander sources.

3. Avoid decoding the payload initially and instead wire a module registry path
   where expander-compiled module products remain expander objects until the
   expander's own evaluator/loader consumes them.
```

Given the probes so far, path 1 is the smallest next step. We should add a
focused expander-side reflection hook or alias for the linklet-bundle/hash
accessors used by `src/expander/compile/linklet-api.rkt`, then re-run the same
matrix with actual bundle values instead of opaque phase payloads. Path 2 is
probably premature: the payload is not yet ordinary bytes at the WebRacket
level. Path 3 is attractive for `namespace-require`, but it risks hiding the
eval boundary again unless we still keep the read-only payload probes.

Follow-up: controlling what the expander generates
--------------------------------------------------

Reading the expander source showed that we can control this at generation time.
In `src/expander/eval/main.rkt`, the public `compile` wrapper computes:

```racket
(define to-correlated-linklet? (and serializable?
                                    (not (current-compile-target-machine))))
```

That flag flows through `compile-top` and `compile-module`. When it is true,
the compiler stores `(make-correlated-linklet s name)` instead of immediately
calling `compile-linklet` on the generated linklet expression. In other words,
the machine-independent/source-shaped representation is already an upstream
mode; Webify does not have to reverse-engineer the opaque phase-0 value first.

The new WebRacket probe confirms the mode works when the compile call is run
with `serializable?` true and `current-compile-target-machine` temporarily set
to `#f`:

```text
webify-probe-expand-self-evaluating/correlated-phase0-payload-matrix:
  target-machine #f
  bundle-payload hash-count 4
  keys: original-phase, link, max-phase, 0
  link:    object-name correlated-linklet, struct-vector-length 4
  phase-0: object-name correlated-linklet, struct-vector-length 4
```

This changes the recommendation. The shortest path is now:

```text
1. Compile expander products for Webify with `serializable? #t` and
   `current-compile-target-machine #f`.

2. Add a Webify adapter for `correlated-linklet` values that extracts the
   generated linklet expression field.

3. Feed that source-shaped linklet expression into the existing Webify linklet
   lowering path.
```

One small runtime lesson came with the probe: `parameterize` around
`current-compile-target-machine` failed in this embedded path with
`application: not a procedure`, but direct save/set/restore via
`dynamic-wind` worked. That suggests the primitive getter/setter is usable, but
the parameter protocol around this particular primitive still deserves a later
cleanup.

Follow-up: bridge adapter for correlated linklets
------------------------------------------------

Webify now has a small adapter in `webify/correlated-linklet.rkt` for the
source-shaped values produced by correlated compile mode. It recognizes an
inspectable `correlated-linklet` struct, extracts the generated linklet
expression from the struct payload, and strips correlated source wrappers before
handing the result to the existing first-slice path. In `struct->vector` terms,
the tag is at vector slot 0 and the expression payload is at vector slot 1.

The adapter is intentionally guarded. Host Racket keeps expander
`correlated-linklet` values opaque outside the expander's inspector, so a local
adapter cannot always inspect real values with `struct->vector`. Inside the
embedded WebRacket expander probe, the same shape is inspectable and the phase-0
payload is confirmed as:

```text
object-name correlated-linklet
struct-vector-length 4
struct-vector-tag struct:correlated-linklet
```

The local tests therefore use same-shaped synthetic values to prove the bridge
logic:

```text
correlated-linklet
  -> generated linklet datum
  -> webify-linklet-first-slice
  -> lowered first-slice lambda
```

The expression matrix covers constant, primitive application, lambda, and
`let-values` linklet bodies. That is enough to make the next implementation
step precise: add an expander-side accessor/export for real correlated-linklet
values, then feed that accessor result into this adapter instead of relying on
probe-only `struct->vector` access.

Follow-up: real phase-0 correlated extraction
---------------------------------------------

The embedded expander probe now has a probe-local accessor for real
`correlated-linklet` values. That accessor runs on the expander side, where the
struct is inspectable, and extracts a machine-independent phase-0 linklet datum
from the compiled payload.

For small top-level forms, real correlated extraction now returns ordinary
linklet source like this:

```text
(linklet ((.top-level-bind! .top-level-require!)
          (.mpi-vector .syntax-literals)
          (.namespace .phase .self .inspector .bulk-binding-registry .set-transformer!))
  ()
  42)
```

The same matrix works for `(+ 1 2)`, `lambda`, and `let-values`. Those extracted
linklets have expander-support imports and no exports because they represent
top-level expression bodies, not module export bodies.
`webify/test-correlated-linklet.rkt` now uses these real extracted shapes as
fixtures and verifies that they lower through `webify-linklet-first-slice`; in
particular, the `(+ 1 2)` fixture folds to `3`.

The remaining production gap is API shape, not extraction theory. Host Racket
still keeps these structs opaque outside the expander inspector, so production
Webify should get this datum through an expander-side exported accessor rather
than duplicating `struct->vector` outside the expander.

For definitions and modules, the source protocol remains different from
top-level expressions. A top-level `begin` with an internal definition still
does not look like the simple expression path:

```text
(datum (begin (define-values (webify-top-x) 1) webify-top-x))
(directory-object-name linklet-directory)
(directory-keys (0 1 data))
(bundle-object-name #f)
(bundle-entries #f)
```

But a plain top-level definition does carry ordinary correlated linklets in the
same bundle shape as expression compilation:

```text
(datum (define-values (webify-top-x) 1))
(directory-keys (#f))
(bundle-object-name linklet-bundle)
(bundle-entries
  ...
  (0    ... (linklet-summary ((linklet? #t)
                              (import-group-count 3)
                              (export-count 1)
                              (first-body-form define-values))))
  (link ... (linklet-summary ((linklet? #t)
                              (import-group-count 2)
                              (export-count 4)
                              (first-body-form define-values)))))
```

That narrowed the definition frontier, and the first bridge is now in place.
`webify/correlated-runner.rkt` can run a lowered top-level correlated linklet
with export cells. The standalone definition fixture lowers and executes:

```text
phase 0 linklet export: webify-top-x.1
export cell value:      1
top-level binding key:  webify-top-x
binding name metadata:  webify-top-x.1
```

The runner supplies the expander support imports, allocates export
`module-variable` cells, and records `.top-level-bind!` metadata in a
host-side table. That is still only the standalone definition case. A `begin`
containing both definition and expression is a different compiled-directory
shape, so the next bridge should either split that directory shape or drive it
through the expander's eval path instead of pretending it is a single phase-0
expression linklet.

Module compilations, per `src/expander/compile/module.rkt`, use
module-oriented keys such as `name`, `decl`, `data`, `stx`, `stx-data`,
optional submodule keys, and phase `0`. A direct embedded tiny-module
correlated compile now succeeds and returns a `compiled-in-memory` value:

```text
probe:correlated-tiny-module-compile/catch:after-compile
object-name compiled-in-memory
```

The remaining tiny-module frontier is one step later. Evaluating the module
body and then requiring it reaches `after-call` and `before-require`, then
returns a catchable `exn:fail:contract:variable` with an unavailable message.
Expanded exception-field diagnostics recover the hidden variable name:

```text
probe:tiny-module-require/catch:before-require
probe:tiny-module-require/catch:caught
object-name exn:fail:contract:variable
message #<undefined>
symbol-value load-on-demand-enabled
```

That is the module-registration hypothesis test in miniature: evaluating the
compiled module reaches `after-call`, so the compiler/evaluator path no longer
crashes. The failure appears when `namespace-require` tries to load or consult
the module and reaches the expander's `load-on-demand-enabled` binding. The
next module milestone is therefore to provide or stub that expander parameter
well enough for tiny-module require to proceed.

The raw `RuntimeError` was caused by a real primitive dispatcher mismatch:
`make-hasheqv` was declared as optional-arity `[0 1]`, so the dispatcher used
shape 16 (`$Prim01`), but the runtime implementation was emitted as `$Prim1`.
Changing the mutable hash constructors to `$Prim01` moved both module probes
forward.

This changes the next frontier again. The bridge should keep the top-level
correlated route as the stable path, add standalone definition extraction next,
and treat tiny-module `namespace-require` as the remaining module-system
binding/registration problem.

Follow-up: primitive approximations added for the expander
---------------------------------------------------------

Two expander-facing primitive gaps were closed with intentionally conservative
approximations:

- `string->unreadable-symbol` currently delegates to uninterned-symbol
  construction. The Racket Reference distinguishes unreadable symbols from
  interned and uninterned symbols, but WebRacket does not yet track that symbol
  category. This is enough for expander startup probes that need a fresh,
  non-interned-looking symbol, and the runtime comment marks it as temporary.

- `make-ephemeron`, `ephemeron?`, and `ephemeron-value` currently use a strong
  heap record. The Reference semantics are GC-sensitive: an ephemeron can hide
  its value unless the key is otherwise reachable. Wasm GC does not expose the
  reachability hook WebRacket would need here yet, so this is deliberately a
  conservative strong fallback, not a complete ephemeron implementation.

The expander primitive report confirms these names are live in the closed
expander build, not merely retained by accident:

```text
program-root-primitives-matches: ephemeron-value make-ephemeron make-ephemeron-hasheq
runtime-root-primitives-matches: ephemeron-value make-ephemeron make-ephemeron-hasheq
retained-primitives-matches: ephemeron-value ephemeron? make-ephemeron make-ephemeron-hasheq
```

The same report includes `string->unreadable-symbol` as both a program root and
runtime root. So the current approximations are intentional bootstrapping
support for live expander paths; they should be replaced later only when
WebRacket gains a real unreadable-symbol category or weak/ephemeron GC hooks.

Follow-up: bounded probe diagnostics
------------------------------------

`webify/probe-expander-instantiate.js` now preserves more child diagnostics for
bounded probes. In particular, it keeps `js_print_fasl:` lines, raw
`RuntimeError` stacks, `raise-code-type-mismatch`, and
`primitive-invoke:shape-*` frames. That made the `make-hasheqv` mismatch visible
without dropping into `wasm-tools print`:

```text
js_print_fasl: #<primitive:make-hasheqv:(0 1):3>
RuntimeError: unreachable
at raise-code-type-mismatch
at primitive-invoke:shape-16
```

Follow-up: tiny module require and definition bridge composition
----------------------------------------------------------------

`load-on-demand-enabled` is now exposed as a WebRacket boolean parameter. The
Racket Reference documents it as a default-`#t` parameter used by the default
load handler to decide whether reading should use delayed source loading. The
current WebRacket implementation provides the parameter cell and scoped
parameterization behavior; it does not yet implement delayed reader/source
loading itself.

That was enough to move the tiny-module probe through `namespace-require`:

```text
probe:tiny-module-require/catch:before-require
probe:tiny-module-require/catch:after-require
(require-ok
  (module-binding
    (internal webify-tiny-value.1)
    (external webify-tiny-value)
    (core? #f)
    (runtime? #f)))
```

So the old `symbol-value load-on-demand-enabled` frontier is closed. The module
path is still tiny, but it proves this sequence now works in the expander wasm:
compile an in-memory module, evaluate/register it, require it, and recover the
provided binding metadata.

The standalone definition bridge is now a named API instead of just a fixture
test. `webify/correlated-runner.rkt` can:

- extract export names from a correlated or plain linklet datum,
- recognize the current standalone top-level definition shape,
- run several lowered top-level linklets in order while preserving the same
  top-level binding table.

The composition smoke is deliberately small: run the standalone definition
linklet for `(define-values (webify-top-x) 1)`, then run a separate expression
linklet `(+ 1 2)` in the same bridge state. The final result is `3`, while the
definition's export cell and `.top-level-bind!` metadata remain available:

```text
export cell webify-top-x.1 => 1
binding key webify-top-x
binding metadata name webify-top-x.1
```

The begin-with-definition directory shape is also pinned now. A standalone
definition has directory key `#f` and a bundle with correlated linklets, while
`(begin (define-values ...) webify-top-x)` has directory keys `(data 0 1)` and
no direct bundle object:

```text
(datum (define-values (webify-top-x) 1))
(directory-keys (#f))
(bundle-object-name linklet-bundle)

(datum (begin (define-values (webify-top-x) 1) webify-top-x))
(directory-keys (data 0 1))
(bundle-object-name #f)
(bundle-entries #f)
```

That means the next bridge layer should treat begin directories as a directory
composition problem, not as a single hidden phase-0 linklet.

Follow-up: begin decoding and tiny-module value frontier
--------------------------------------------------------

The bridge now normalizes the begin-directory key shape. The raw directory keys
come from a hash, so the numeric entries are not stable in printed order:

```text
(directory-keys (data 0 1))
;; or
(directory-keys (data 1 0))
```

`webify-correlated-begin-directory-keys` normalizes either form to
`'(data 0 1)`, and `webify-correlated-begin-directory-description?` recognizes
that shape as the currently observed begin-with-definition directory.

The bridge also has a small top-level reference helper now. After a standalone
definition linklet runs, `webify-correlated-top-level-ref` follows the recorded
`.top-level-bind!` metadata from the external name to the internal export cell:

```text
external name: webify-top-x
internal name: webify-top-x.1
value:         1
```

For expander-side modules, `namespace-require` gets as far as installing the
binding metadata, but value lookup exposes the next runtime/module-instance
frontier. The probe follows the documented `namespace-variable-value` route
after require:

```text
probe:tiny-module-value/catch:after-require
instance-variable-value
instance variable not found:
webify-tiny-value.1
```

Before this probe, `namespace-variable-value` stopped at an unbound
`call-with-escape-continuation`. WebRacket now has a bootstrap
`call-with-escape-continuation` implemented with a private Wasm exception
payload, which is enough for the expander's `let/ec` pattern to perform a
non-local return through the current call. It is intentionally not a complete
continuation implementation: the escape procedure is not dynamically
invalidated after the call returns, and prompt/barrier interaction remains
future work.

So the current module boundary is sharper:

- module declaration/evaluation reaches `after-call`,
- `namespace-require` reaches `after-require`,
- binding metadata for `webify-tiny-value` is visible,
- runtime module instance storage does not yet contain the provided internal
  variable `webify-tiny-value.1`.

The next real module milestone is therefore not another namespace binding
probe; it is making module instantiation populate the runtime instance variable
table for phase-0 exports.

Module boundary update
----------------------

The first explicit module-instance audit shows that `namespace-require` and
`module->namespace` are exercising different registry paths:

```text
(binding
  (module-binding
    (internal webify-tiny-value.1)
    (external webify-tiny-value)
    (core? #f)
    (runtime? #f)))
(module-mapped-symbols
  (module->namespace-failed ... exn:fail:contract:variable ...))
```

So the top-level namespace knows the import binding, but `module->namespace`
cannot yet recover the instantiated module body namespace. That suggests the
next module-runtime work is in the module-instance registry, not in the binding
metadata.

There is now a second value probe that uses the Reference-documented
`dynamic-require` route. `dynamic-require` with `#f` should force phase-0
instantiation, and `dynamic-require` with a symbol should return the provided
value:

```text
probe:tiny-module-dynamic-value/catch:before-dynamic-require
probe:tiny-module-dynamic-value/catch:after-require
instance-variable-value
instance variable not found:
webify-tiny-value.1
```

This fails for the same reason as `namespace-variable-value`: WebRacket's
current `compile-linklet` is a metadata-only bootstrap placeholder. It records
the linklet import/export shape, but it does not produce an executable linklet
body. When the expander later instantiates the module phase linklet, the
placeholder closure cannot run the `define-values` body that would populate the
`webify-tiny-value.1` export cell.

That keeps the tiny value milestone open, but the blocker is now precise:
module metadata and binding registration work; executable linklet-body support
for runtime-produced linklets is missing.

Begin-directory executor sketch
-------------------------------

The begin-with-definition directory shape should be executed as a small
directory program, not flattened as one linklet. The current design target is:

- Decode the `data` entry first, because it carries the shared declaration/data
  instance payload needed by numbered linklets.
- Execute numbered entries in dependency order, preserving one top-level bridge
  state and one module-instance registry across entries.
- Treat each numbered entry as a correlated linklet with the same import
  discipline as the standalone top-level linklet runner.
- Register any `.top-level-bind!` metadata before running later entries that
  may reference those names.
- Keep `module` forms at the boundary for now: top-level begin directories are
  executable, but full Racket module-directory execution still needs body
  namespace installation and `module->namespace` support.

Executable source-linklet bridge update
---------------------------------------

WebRacket's runtime `compile-linklet` bridge now turns linklet-shaped source
data into a compiled-linklet record with an executable bootstrap closure. This
is not machine-code linklet compilation; it is a deliberately small source
linklet interpreter for the first module slice. The bridge currently handles:

- source-linklet import/export metadata,
- exact body-procedure arity based on the linklet import groups,
- syntax-wrapped linklet identifiers via `syntax-e`,
- `(quote datum)`,
- `(begin body ...)`,
- `(void)`,
- `(set! id rhs)`, and
- single-value `(define-values (id) rhs)`.

That is enough for the tiny module value probes to instantiate a module body
and populate the exported internal variable:

```text
probe:tiny-module-value/catch:after-require
(require-ok
  ((binding
     (module-binding
       (internal webify-tiny-value.1)
       (external webify-tiny-value)
       (core? #f)
       (runtime? #f)))
   (value 42)))

probe:tiny-module-dynamic-value/catch:after-require
(require-ok ((binding (unbound)) (value 42)))
```

The still-open namespace frontier is narrower. `module->namespace` still fails
inside the expander with `exn:fail:contract:variable` and message
`#<undefined>`, even when the audit passes `webify-expander:current-namespace`
explicitly:

```text
(module->namespace-failed
  (message #<undefined>)
  (shape ... exn:fail:contract:variable ...)
  (struct-fields ... webify-expander:module->namespace ...))
```

So phase-0 module instantiation and export-cell population now work for the
tiny case. Recovering the module body namespace remains a separate
module-registry/root-expand-context problem, not the old missing export-cell
problem.

Source-linklet executor widening
--------------------------------

The bootstrap source-linklet executor now carries the linklet import groups and
the actual instantiation argument array through expression evaluation. A symbol
reference is resolved from the import instance that declares the symbol, falling
back to the target instance for local definitions. This follows the Reference
model for `instantiate-linklet`: each import set is satisfied by one instance,
and the number of instances must match the number of import sets.

The intentionally small expression subset is now:

- variable references from the target instance or an import instance,
- `(quote datum)`,
- `(begin body ...)`,
- `(if test then else)`, where only `#f` is false,
- `(void)`,
- `(set! id rhs)`, including imported variables,
- single and packed-multiple `(define-values ids rhs)`,
- `(#%app + arg ...)`,
- `(#%app - arg arg ...)`,
- `(#%app * arg ...)`,
- `(#%app values arg ...)`,
- `(#%app list arg ...)`, and
- `(#%app cons a d)`,
- `(#%app car p)`, and
- `(#%app cdr p)`.

The new runtime tests cover source linklets that import a value, compute with
`+`, `*`, and `-`, unpack `(values ...)` into multiple exports, select `car`,
and build a list containing a pair. Primitive application is centralized through
`linklet-apply-primitive`, so adding more first-slice primitives no longer
requires growing the `#%app` branch itself.

The correlated adapter also has a named begin-directory runner now:
`webify-run-correlated-begin-directory/exports`. It validates the observed
`(data 0 1)` directory summary and runs the lowered definition entry followed
by the expression entry over a shared top-level binding table.

The expander module smoke has moved past the old `module->namespace` frontier.
The focused audit now declares and requires a tiny `#%kernel` module:

```racket
(module webify-tiny-instance-audit '#%kernel
  (#%provide webify-tiny-value)
  (define-values (webify-tiny-value) '42))
```

`module->namespace` is exposed to the probe by extracting through a small
wrapper module that re-provides `module->namespace`, `module->imports`, and
`module->exports` from `namespace/api-module.rkt` alongside `expander/main.rkt`.
The audit now reports:

```text
module->namespace-alias? #t
module-declared? #t
binding internal webify-tiny-value.1
binding internal-interned? #f
binding internal-eq-instance-key? #t
module-instance-names (webify-tiny-value.1)
module-instance-actual-key-value 42
current-namespace-external-value 42
```

One important diagnostic lesson: the printed internal name
`webify-tiny-value.1` is an unreadable/uninterned symbol, as intended by
`racket/src/expander/expand/def-id.rkt` for non-simple module bindings.
Reconstructing it with `'webify-tiny-value.1` or
`(string->symbol "webify-tiny-value.1")` produces an interned symbol and misses
in the linklet instance's eq-hash. Probes must preserve the actual symbol from
`identifier-binding` or `instance-variable-names` when inspecting body
namespace variables.

This also clarifies the public/private namespace split. The requiring namespace
maps the external export name `webify-tiny-value` and reads it as `42` with
`namespace-variable-value`. The module body namespace returned by
`module->namespace` contains the internal linklet key, so direct inspection must
use that exact uninterned key.

The probe now has reusable helpers for that pattern:

```text
webify-probe-namespace-binding-key
webify-probe-instance-key-by-printed-name
webify-probe-instance-value-by-key
```

For exported names, the key can come from `identifier-binding` in the requiring
namespace. For private body names, there may be no namespace mapping at all, so
diagnostics have to recover the unreadable key from `instance-variable-names`
and preserve that exact symbol.

The reflection probe also confirms that `module->imports` and `module->exports`
are usable enough for Webify diagnostics when opaque module-path-index values
are summarized instead of returned directly:

```text
imports ((0 (... module-path-index ...)))
exports ((variables ((0 (webify-tiny-value () webify-tiny-value.1))))
         (syntaxes ()))
```

That matches the Reference-level API shape: imports are grouped by phase, and
exports report the external name plus the internal generated name. Webify should
consume this metadata as provider/export metadata, not as executable values. In
particular, the internal generated symbol must be preserved by identity when it
is later used to inspect or compose linklet instances.

Two additional tiny module probes are now green:

```text
private helper:
  public-value 5
  private-value-in-requirer missing
  public-instance-value 5
  private-instance-value 5

two-module require:
  provider-declared? #t
  consumer-declared? #t
  consumer-value 41
  provider-value-in-requirer missing
  consumer-instance-value 41
```

The two-module probe uses ordinary kernel source:

```racket
(module webify-tiny-provider '#%kernel
  (#%provide webify-a-value)
  (define-values (webify-a-value) '41))

(module webify-tiny-consumer '#%kernel
  (#%require (quote webify-tiny-provider))
  (#%provide webify-b-value)
  (define-values (webify-b-value) webify-a-value))
```

This is the first clean composed-module success case in the expander bridge:
both modules are declared, the consumer imports the provider, requiring only the
consumer exposes only the consumer export, and the consumer module instance
contains the computed value.

The next bridge step carries the same idea into the reusable graph-audit path.
`webify/module-audit.rkt` now records a `webify-module-reflection-row` for each
extractor report:

```text
name
phase-0 imports
phase-0 exports
required provider names
unresolved import groups
```

That row is intentionally metadata-only. It does not instantiate modules or
read values. Its purpose is to give the bridge a stable diagnostic surface for
provider-graph decisions before composing linklet inputs.

Two more tiny expander probes exercise the cases that the audit layer needs to
model next:

```text
three-module chain:
  webify-chain-a -> webify-chain-b -> webify-chain-c
  c-value 17
  a-value-in-requirer missing
  c-instance-value 17

rename re-provide:
  provider internal export: webify-internal-value
  consumer public export:  webify-public-value
  module->exports maps public webify-public-value through the provider path to internal webify-internal-value.1
  public-value 23
  internal-value-in-requirer missing
  public-instance-value missing
```

The important rename lesson is that the provider graph cannot resolve by printed
public names alone. `module->exports` exposes the public name and the generated
internal name together, and the internal name is the one that must be preserved
when inspecting module instances. For a pure re-provide, the re-exporting module
does not necessarily contain a local instance cell for the value; normal
namespace lookup can succeed by following the imported binding while direct
inspection of the re-exporting module instance reports `missing`.

The graph audit now keeps that distinction explicitly. Each reflection row has
normalized export bindings with:

```text
phase
external/public name
provider path metadata
internal/generated name
```

For simple local exports, the provider path is empty and the internal name is
the exported variable. For `module->exports`-style metadata, any middle fields
between the external and internal names are preserved as provider-path metadata.
The audit also computes conservative reflection import hints for unresolved
imports when exactly one reflection row exports the requested name.

Two more tiny require-shape probes are covered by the smoke runner:

```text
only require:
  provider exports webify-only-x and webify-only-y
  consumer imports only webify-only-x
  consumer exports webify-only-z = 31
  neither provider name leaks into the requiring namespace

rename require:
  provider exports webify-original-x
  consumer imports it locally as webify-local-x
  consumer exports webify-renamed-z = 37
  neither the original nor local import name leaks into the requiring namespace
```

This gives the bridge a compact matrix for the next provider resolver: ordinary
import, transitive import, re-provide, selective import, and renamed local
import.

The resolver now accepts those reflection hints as an input, instead of only
reporting them in audits. The precedence is intentionally conservative:

```text
explicit import alias
explicit dependency
reflection hint
broad dependency-export scan
```

A reflection hint has to name a provider and exported binding that still appears
in the dependency export table. That means metadata can disambiguate provider
selection, but it cannot fabricate a dependency that the extracted graph did not
actually provide.

Resolution outcomes are classified for audits:

```text
resolved-by-explicit-dependency
resolved-by-reflection-hint
resolved-by-export-scan
ambiguous-after-reflection
missing-after-reflection
```

The first source-module smoke for this path is deliberately tiny: a compiled
module that imports `first` from `racket/list` can be resolved with a reflection
hint even when another dependency export table also contains `first`. The hint
selects `racket/list`, and the resolver still validates that `racket/list`
exports `first`.

Re-provide metadata now has a similarly explicit path. If a normalized export
binding includes provider-path metadata such as:

```text
(provider provider-module backing-export)
```

then reflection-hint construction resolves an import of the public re-export to
`provider-module/backing-export`, not to the re-exporting module. This matches
the expander probe where a pure re-provide is visible through namespace lookup
but has no local cell in the re-exporting module instance.

The current real-module rename-in smoke uses:

```racket
(require (rename-in racket/list [first head]))
```

On the default Racket 8.12 host, that module is classified as blocked by missing
`decompile-linklet` support before provider metadata can be resolved. On a newer
linklet-capable checkout, the same test path is ready to resolve the renamed
import with a reflection hint.

Follow-up: raw provider-path normalization
------------------------------------------

The host-side audit now resolves raw `module->exports` provider-path entries
before constructing reflection hints. This follows the Reference contract for
`module-compiled-exports`: a re-export origin is either a bare
module-path-index or a four-field origin of the form:

```text
(module-path-index import-phase imported-name nominal-phase)
```

For symbolic modules, a tiny re-provide produces a raw variable export row like:

```text
((0 (public-x ((#<module-path-index:'provider> 0 internal-x 0)) internal-x)))
```

The normalizer resolves the module-path-index without loading, converts it to a
stable dependency key, and records the provider path as:

```text
(provider provider internal-x)
```

That lets a composed graph resolve a consumer's public re-export import to the
backing provider cell, not to the re-exporting module:

```text
(consumer public-x provider internal-x)
```

The same normalization handles relative file providers by converting the
resolved path payload into Webify's current symbol-shaped dependency key. This
is the small version of the `racket/private/list` -> `"pico.rkt"` problem:
relative provider paths must be resolved against their source module before
Webify decides that an import is genuinely missing.

A focused newer-Racket smoke is available as:

```sh
../racket/racket/bin/racket -y webify/check-newer-racket-rename-smoke.rkt
```

It confirms that the machine-independent `rename-in racket/list` case reaches a
decompilable phase-0 linklet on the newer checkout and resolves the lowered
import as:

```text
(first racket/list first)
```

Follow-up: automated metadata collection and real providers
-----------------------------------------------------------

The newer-Racket smoke now isolates its compiled-file cache with
`current-compiled-file-roots`, so running:

```sh
../racket/racket/bin/racket -y webify/check-newer-racket-rename-smoke.rkt
```

does not leave 9.2 `.zo` files in the normal `webify/compiled` tree used by the
default Racket 8.12 tests.

The extractor layer also has host-side metadata collectors:

```text
webify-source-module->module-export-metadata
webify-source-modules->module-export-metadata
webify-module-path->module-export-metadata
webify-module-paths->module-export-metadata
```

These return `(module-name raw-module->exports-variable-rows)` pairs. The audit
layer can consume those rows directly through `#:module-export-metadata`, and
`webify-module-reports->discovered-graph-audit` now combines provider discovery,
metadata collection, reflection-hint construction, and graph resolution in one
host-side pass.

The real `racket/private/list` smoke confirms the compiled/reflection path for
the old reverse problem:

```text
module->exports reverse row:
  (reverse ((#<module-path-index:"pico.rkt" ...> 0 alt-reverse 0)) reverse)

provider closure includes:
  racket/private/pico

resolved linklet import:
  (1/reverse racket/private/pico reverse)
```

So the fix is not source-level `rename-in` scraping. The compiled metadata and
provider closure now carry the relative `"pico.rkt"` edge far enough to resolve
the lowered private-list import against the real provider.

The same smoke revisits the `racket/string` / `string-join` case. With provider
closure discovery enabled, the current frontier is no longer an unresolved
`string-join` import. The first reported missing import is now:

```text
string->number
```

That means the `string-join` variants are no longer the immediate blocker for
this path; the next work should follow the newly exposed transitive dependency
frontier instead of adding ad hoc `string-join` hints.

Follow-up: metadata exports and the string frontier
---------------------------------------------------

Tracing `string->number` shows that the failing importer is
`racket/private/string`, and the needed binding is re-exported by
`racket/private/pre-base` from `#%kernel`:

```text
(string->number (#<module-path-index:'#%kernel>) string->number)
```

The phase-0 linklet export table alone does not include that re-export, so
provider discovery could find `racket/private/pre-base` but still classify
`1/string->number` as missing. The audit now augments dependency export tables
with public names from raw `module->exports` metadata before resolving imports.
That is still host-side metadata use; it does not add source-level scraping.

After this change, the newer-Racket smoke confirms that
`racket/private/pre-base` contributes `string->number` to the resolver export
table. The `racket/string` path moved again and exposed a provider-precedence
problem: public metadata makes many base-like modules advertise broad re-exports,
while the extracted provider linklets identify the more direct implementation
module.

The resolver now uses two export views when inferring imports from a compiled
module's `phase-to-link-modules`/MPI candidates:

* the augmented view answers "can this dependency provide the public name at
  all?", including `module->exports` metadata re-exports;
* the provider-local view breaks ties by preferring names actually exported by
  the extracted provider linklet.

For the former `1/reverse` frontier, broad metadata candidates such as
`racket/private/list`, `racket/private/pre-base`, `racket/private/base`, and
`racket/base` no longer tie with the implementation provider. The required
candidate list still describes the possible providers, but the provider-local
export table singles out `racket/private/pico`, so the import resolves as:

```text
(1/reverse racket/private/pico reverse)
```

The broad export-scan fallback now applies the same idea to base aggregators:
`racket/base` and `racket/private/base` are treated as broad re-export modules,
so a concrete private provider such as `racket/private/pre-base` wins when all
three advertise the same public name. That moved the former `1/syntax?` frontier
to:

```text
(1/syntax? racket/private/pre-base syntax?)
```

Ambiguity diagnostics now include candidate reasons, so the next frontier says
which candidates came from provider-local exports versus broad metadata:

```text
ambiguous inferred import dependency
  import: path-string?
  candidates: (path-string? racket/private/path)
              (path-string? racket/private/old-path)
  candidate reasons:
              (path-string? racket/private/path provider-local-export)
              (path-string? racket/private/misc metadata-export-candidate)
              (path-string? racket/private/old-path provider-local-export)
```

The resolver now uses `module->exports 'defined-names` origins to rank those
candidates. Per the Reference, an empty origin list means the export is defined
locally, while a non-empty origin list describes a re-export. For
`path-string?`, `racket/private/path` defines the binding locally and
`racket/private/misc` re-exports the same provider; those duplicate origin paths
collapse to one hint:

```text
(path-string? racket/private/path path-string?)
```

That moves `racket/string` past `path-string?`. The current frontier is no
longer an ambiguous name; it is a provider-key normalization problem. First,
reflection metadata produced a file-like dependency key with no export table:

```text
import dependency has no export table entry
  dependency: /Users/soegaard/Dropbox/GitHub/webracket/pico.rkt
```

The reflected origin decoder now handles singleton MPI origins, including the
extra-list shape that appears as `((#<module-path-index:...>))`, and
canonicalizes file-style provider keys against discovered provider rows by
basename plus export evidence. That moves the `pico.rkt` case back to the
discovered `racket/private/pico` provider.

Kernel origins are now handled separately from ordinary module providers. If a
reflected `#%kernel` origin names a primitive already present in Webify's
primitive database, the resolver accepts it as a kernel primitive. If the name
is not implemented as a Webify primitive, it fails with a dedicated kernel
diagnostic instead of looking for a normal module export table.

The resolver also adds a synthetic `#%kernel` export row derived from
`primitives-db.rkt`. This lets unhinted kernel primitive imports resolve by the
same export-scan path as module imports, but only for names Webify has
explicitly declared. Concrete module providers still outrank the kernel row, so
ordinary provider exports such as `syntax?` continue to resolve to
`racket/private/pre-base` instead of becoming ambiguous with `#%kernel`.

The first unsupported kernel-origin binding was:

```text
unsupported kernel-origin binding
  dependency: #%kernel
  export: raise-syntax-error
```

`raise-syntax-error` is now registered as a Webify primitive name and exposed by
`primitives.rkt` as a positional wrapper around Racket's documented
`raise-syntax-error` procedure. The wrapper covers the non-keyword arities used
by the reflected kernel-origin path; the full `#:exn` customization is not part
of this compatibility layer yet.

The next kernel/export holes were the filesystem missing-module exception
family, collection lookup helpers, `do-raise-syntax-error`, syntax binding-set
helpers, and syntax serialization helpers. The public names were checked
against the Reference before being added to the primitive database or
`primitives.rkt`; `do-raise-syntax-error` remains an internal kernel bridge name.

The current `racket/string` graph-audit smoke now resolves without failures.
That is useful progress: `reverse` was a provider-local precedence problem,
`syntax?` was a base-aggregator precedence problem, `path-string?` was an
origin-ranking problem, `pico.rkt` was a reflected relative-provider
normalization problem, `raise-syntax-error` was a kernel primitive-support
frontier, and the later exception/collection/syntax helpers were missing
kernel-surface coverage.
