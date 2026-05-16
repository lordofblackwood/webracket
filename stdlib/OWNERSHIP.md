# WebRacket Stdlib Ownership

This document records which public names belong to the WebRacket runtime
primitive layer, which names are temporarily primitive-owned for Goal 1, and
which names are expected to move to real Racket subsystem ports later.

## Current Stdlib Bridge

`driver.rkt` no longer textually splices `stdlib/stdlib.rkt` or
`stdlib/stdlib-for-browser.rkt` directly into the user top level. Instead, it
uses `stdlib/module-exports.rkt` to rewrite stdlib definitions to private names
and expose selected public names through `module-variable` cells.

This is an interim bridge, not full Racket module support. It preserves
script-style `--stdlib` compatibility while avoiding top-level primitive
redefinition collisions. The long-term shape should compose real module/linklet
providers, so this private-name rewrite should not grow into a second module
system.

The browser stdlib root is separate:

```text
stdlib/stdlib.rkt              ; Node/default stdlib root
stdlib/stdlib-for-browser.rkt  ; default stdlib plus browser.rkt
```

## Runtime Primitive Substrate

These names should remain primitive/runtime-owned. They represent low-level
exception records, raising machinery, runtime state, or compiler-facing
operations.

```racket
exn
exn?
exn-message
exn-continuation-marks
make-exn
raise
raise-unbound-variable-reference
raise-binding-result-arity-error
raise-definition-result-arity-error
raise-read-error
raise-read-eof-error
raise-syntax-error

current-print
error-print-width
error-value->string-handler

print-as-expression
print-boolean-long-form
print-box
print-graph
print-hash-table
print-mpair-curly-braces
print-pair-curly-braces
print-reader-abbreviations
print-struct
print-syntax-width
print-unreadable
print-vector-length
```

## Temporary Primitive-Owned Public Helpers

These names currently overlap with stdlib source exports, but are intentionally
not re-exported by the stdlib bridge yet. Installed-module Goal 1 composition can
demand these names without composing the WebRacket stdlib root, so moving them
too early regresses runtime smokes.

```racket
format
fprintf
raise-argument-error
raise-arguments-error
read
read-syntax
```

Long term:

```text
format/fprintf/display/write/print  -> ../racket/racket/src/io/format/
read/read-syntax                    -> ../racket/racket/src/expander/read/
```

## Stdlib-Owned Compatibility Helpers

These names are library-level compatibility helpers today. They may later be
replaced by providers from `io/format`, but they should not be implemented as
compiler primitives merely because the temporary stdlib needs them.

```racket
error
primitive-realm
error-message->adjusted-string
error-value->string

raise-argument-error*
raise-arguments-error*
raise-range-error
raise-range-error*
raise-result-error

display
write
print
displayln
writeln
println
printf
eprintf
fprintf*
```

## Do Not Finish In `stdlib/`

These files are historical or transitional. Do not spend effort polishing them
into final implementations.

```text
stdlib/hash.rkt     ; abandoned immutable hash attempt; runtime HAMT is the path
stdlib/regexp.rkt   ; obsolete; use ../racket/racket/src/regexp/
stdlib/reading.rkt  ; temporary; use ../racket/racket/src/expander/read/
stdlib/writing.rkt  ; temporary; use ../racket/racket/src/io/format/
```

`stdlib/intmap.rkt` is also transitional. Its public `intmap-*` exports are
bridge scaffolding unless a future design explicitly keeps them public.

## Browser Stdlib

Browser-only helpers should remain owned by `stdlib/stdlib-for-browser.rkt`:

```racket
sxml->dom
create-element/with-context
set-elem-attributes!
set-elem-attributes/loop!
attribute-value->string
attribute-entry->name+value
attribute-marker?
add-children!
raise-sxml-*
```

## Guardrail

`webify/check-stdlib-primitive-collisions.rkt` checks that generated stdlib
aliases do not collide with compiler primitives. If a new overlap appears, it
must be classified as either:

```text
runtime primitive substrate
temporary primitive-owned public helper
stdlib-owned compatibility helper
obsolete/transitional implementation detail
```
