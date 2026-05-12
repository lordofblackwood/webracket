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

The procedure-shape probe explains the odd `procedure?` result well enough to
make it actionable:

```text
wr-read-syntax-procedure-shape-string-"42"-printed:
  ((object-name syntax)
   (procedure? #t)
   (procedure-arity 0)
   (struct-vector-length 8)
   (struct-vector-tag struct:syntax))
```

The expander source does not attach `prop:procedure` to its `syntax` struct.
Since `struct->vector` reports `struct:syntax`, but WebRacket also reports a
zero-arity procedure, this is likely a WebRacket struct-property/procedure
classification bug for extracted structs, not an intentional expander syntax
feature. The next core-runtime follow-up should be to audit how WebRacket
decides that a struct value is callable.

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
