# Expander Probe Repro Notes

## Command

From the repository root:

```sh
racket webify/probe-expander-full-compile.rkt \
  --compile-timeout 240 \
  --compile-memory-mb 2048 \
  --compile-progress-interval 100 \
  --compile-letrec-waddell \
  --enable-cc-analysis \
  --enable-simplify \
  --no-label-map-forms
```

## Important Setup Details

- The probe cleans only the generated `webified` syntax before compilation:
  `(datum->syntax #f (syntax->datum webified))`.
- `expander.rkt` namespace-introduces syntax before
  `expand-top-level-with-compile-time-evals`.
- `--no-label-map-forms` must survive `comp`'s internal `reset-label-map!`.
  Without that, closure-conversion progress is dominated by formatting huge
  generated source forms in `record-label-map!`.

## Observed Progress

With `--no-label-map-forms` working, closure conversion moved from roughly:

```text
100 lifts / 38 seconds
```

to roughly:

```text
7600 lifts / 3.6 seconds
```

The run reached closure conversion and then failed after thousands of lifts.

## Failure

The final failure was:

```text
compile-failure-category: unknown
compile-failure-message:
nanopass-case: empty else clause hit
(nanopass-case (LANF Abstraction) ab
  ((lambda ,s ,f ,e) (fixed-arity-formals? f)))
compiler.rkt:12557
```

The failing helper is:

```racket
(define (abstraction-fixed-arity? ab)
  (nanopass-case (LANF Abstraction) ab
    [(lambda ,s ,f ,e)
     (fixed-arity-formals? f)]))
```

This suggests a closure-conversion eligibility path is passing a non-plain
`LANF Abstraction` shape, likely a case-lambda-related value, to a helper that
assumes only plain lambda.

## Strategy Comparison

### Waddell

Command uses `--compile-letrec-waddell --enable-cc-analysis --enable-simplify
--no-label-map-forms`.

Observed:

```text
closure-conversion-progress: event=start ... ((free . 26513) ...)
closure-conversion-progress: event=lift-start count=7600 elapsed-ms=3605 ...
compile-failure-message:
nanopass-case: empty else clause hit ... compiler.rkt:12557:2
```

### Basic

Command uses `--compile-letrec-basic --enable-cc-analysis --enable-simplify
--no-label-map-forms`.

Observed:

```text
closure-conversion-progress: event=start ... ((free . 28469) ...)
closure-conversion-progress: event=lift-start count=12300 elapsed-ms=2353 ...
compile-failure-message:
nanopass-case: empty else clause hit ... compiler.rkt:12557:2
```

Basic reaches the same `abstraction-fixed-arity?` failure, but after more
lifts than Waddell.

After adding an explicit diagnostic to `abstraction-fixed-arity?`, the
offending shape was:

```text
abstraction-fixed-arity?: expected LANF lambda abstraction, got:
(case-lambda
  (lambda (want-layer_1.15200)
    (app check-nested_1.15199 want-layer_1.15200 (quote #t)))
  (lambda (want-layer_2.15201 ok?131_1.15202)
    (app check-nested_1.15199 want-layer_2.15201 ok?131_1.15202)))
```

So a direct-helper eligibility path was asking the plain-lambda fixed-arity
predicate about a case-lambda. The conservative fix is to return `#f` for
non-plain lambda shapes.

After the conservative fix, the Basic strategy completed closure conversion:

```text
closure-conversion-progress: event=done count=27198 elapsed-ms=6178 ...
compiler-progress: event=pass-done pass="closure-conversion"
compiler-progress: event=pass-start pass="generate-code"
```

The next blocker became:

```text
compile-failure-message:
core.rkt:142:13: primapp: too many arguments
  in: (#%plain-app get-output-bytes o_1 (quote #t))
```

Waddell reaches the same `get-output-bytes` code-generation blocker after the
case-lambda fixed-arity fix:

```text
closure-conversion-progress: event=done count=25242 elapsed-ms=9903 ...
compiler-progress: event=pass-start pass="generate-code"
compile-failure-message:
core.rkt:142:13: primapp: too many arguments
  in: (#%plain-app get-output-bytes o_1 (quote #t))
```

After teaching WebRacket that `get-output-bytes` has the Racket arity shape
`[1 2 3 4]`, the Basic strategy reaches and completes code generation:

```sh
racket webify/probe-expander-full-compile.rkt \
  --compile-timeout 240 \
  --compile-memory-mb 2048 \
  --compile-progress-interval 5000 \
  --compile-letrec-basic \
  --enable-cc-analysis \
  --enable-simplify \
  --no-label-map-forms
```

Observed:

```text
closure-conversion-progress: event=done count=27198 elapsed-ms=6658 ...
compiler-progress: event=pass-start pass="generate-code" detail=()
compiler-progress: event=pass-done pass="generate-code" detail=((ms . #f))
Traversed 311 modules
Need 245 of those linklets
Can remove 1126 of 4001 defined names, keeping 2875
Flattened code is 1909474 bytes
extract-ms: 36512
read-linklet-ms: 499
webify-lower-ms: 664
clean-webified-syntax-ms: 227
exports: 71
compile-ms: 103591
compile-wat-bytes: 65114127
```

This confirms that the old `get-output-bytes` arity failure is fixed. The
probe now produces the large expander WAT payload; the next useful milestone is
validating and instantiating that payload, then triaging runtime/linklet issues.

## WAT Validation

The probe can now preserve and validate the generated expander WAT:

```sh
racket webify/probe-expander-full-compile.rkt \
  --compile-timeout 240 \
  --compile-memory-mb 2048 \
  --compile-progress-interval 5000 \
  --compile-letrec-basic \
  --enable-cc-analysis \
  --enable-simplify \
  --no-label-map-forms \
  --write-wat /private/tmp/webracket-expander-probe.wat \
  --write-wasm /private/tmp/webracket-expander-probe.wasm \
  --validate-wat
```

Before the integer-literal fix, this reached code generation but
`wasm-tools parse` rejected the generated WAT:

```text
wasm-tools-parse-status: 1
error: unknown operator or unexpected token
```

The local context showed a leaked Racket quote form in generated WAT:

```wat
(array.new_fixed $Args 2 (local.get $$i_138.12697) (quote 2147483647))
```

The root cause was that WebRacket fixnum immediates have a smaller signed range
than Racket's host fixnums. The compiler was treating host fixnums such as
`2147483647` as immediate literals, then falling through to the generic quote
path during code generation. The fix is to use `wr-signed-fixnum?` consistently
for WebRacket immediate integer literals and convert larger exact integers to
flonums before WAT generation.

After the fix, the validation run completed:

```text
Traversed 311 modules
Need 245 of those linklets
Can remove 1126 of 4001 defined names, keeping 2875
Flattened code is 1909474 bytes
compile-ms: 105614
compile-wat-bytes: 65115193
compile-wat-path: /private/tmp/webracket-expander-probe.wat
write-wat-ms: 2901
wasm-tools-parse-status: 0
wasm-tools-parse-ms: 1036
compile-wasm-path: /private/tmp/webracket-expander-probe.wasm
compile-wasm-bytes: 11913611
```

## Wasm Instantiation

The generated Wasm also instantiates with the ordinary WebRacket host import
shape:

```sh
node --experimental-wasm-exnref \
  webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-probe.wasm
```

Observed:

```text
imports: 18
exports: 27227
instantiate-status: ok
entry-kind: function
wr-names-kind: function
```

The instantiation probe intentionally does not call `entry` by default. It uses
minimal host stubs only to prove that the generated module validates, links, and
instantiates. The next milestone is to call an entry point under controlled host
imports and classify the first runtime/linklet failure.

## Entry Runtime Failure

The instantiation probe can also call the generated `entry` export:

```sh
node --experimental-wasm-exnref \
  webify/probe-expander-instantiate.js \
  /private/tmp/webracket-expander-probe.wasm \
  --call-entry
```

Current result:

```text
entry-call: start
js_print_fasl: #<undefined>
entry-call: threw
exception-kind: Exception
wasm-exception?: true
foreign-exception?: false
```

The raw `#<undefined>` line is printed by WebRacket's entry-level uncaught
exception handler. A temporary WAT patch that logged the handler path showed
that the caught value satisfies `exn?`, and a second temporary patch showed the
available subtype predicates:

```text
js_print_fasl: Symbol(exn?)
js_print_fasl: true
js_print_fasl: Symbol(exn:fail?)
js_print_fasl: true
js_print_fasl: Symbol(exn:fail:contract?)
js_print_fasl: true
js_print_fasl: Symbol(exn:fail:filesystem?)
js_print_fasl: false
js_print_fasl: #<undefined>
```

So the next blocker is more specific than "entry throws": the generated expander
raises an `exn:fail:contract?`, but `(exn-message e)` is `#<undefined>`.
That points toward either a malformed exception object produced by the
webified/linklet path or a struct-inheritance field-layout issue where a subtype
passes the right predicate but inherited `exn` fields are not stored/read in the
shape expected by `exn-message`.

### SCC

Command uses `--compile-letrec-scc --enable-cc-analysis --enable-simplify
--no-label-map-forms`.

Observed:

```text
compiler-progress: event=pass-start pass="lower-letrec-values" detail=()
compile-ms: 240002
compile-timeout-seconds: 240
```

SCC did not finish `lower-letrec-values` within the 240-second compile window.
