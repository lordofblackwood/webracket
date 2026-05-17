# Regexp Layer Notes

Webify should treat Racket's regexp implementation as a library layer, not as a
hand-written WebAssembly primitive pile.

The source staged for WebRacket lives at:

```text
racket-src/regexp/
```

Unlike `io/format`, the regexp slice intentionally copies the whole upstream
directory. The Racket CS build already knows how to demodularize that graph to
one closed linklet, so the WebRacket path should be:

```text
racket-src/regexp/          ; copied upstream regexp source tree
racket-src/common/check.rkt ; shared helper required by regexp/main.rkt
        ↓
bootstrap-run demod cache   ; `webify/regexp-provider.rkt`
        ↓
regexp.rktl                 ; one cached closed linklet
        ↓
lowered provider forms      ; cached top-level forms
        ↓
Webify provider slice       ; composed by default
```

## Demod Artifact

The Racket CS build already flattens the regexp source tree into a single
linklet. The upstream recipe is in:

```text
/Users/soegaard/Dropbox/GitHub/racket/racket/src/regexp/main.zuo
```

The important target invokes the expander bootstrap runner, not
`src/expander/main.rkt` directly:

```sh
/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket \
  /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/bootstrap-run.rkt \
  -t /Users/soegaard/Dropbox/GitHub/webracket/racket-src/regexp/main.rkt \
  -c /private/tmp/webracket-regexp-cache \
  -k /Users/soegaard/Dropbox/GitHub/racket/racket \
  -s -x \
  --depends /private/tmp/webracket-regexp-dep.rktd \
  --no-global \
  -o /private/tmp/webracket-regexp.rktl
```

`webify/regexp-provider.rkt` builds this command and defaults the cache root to
the host temporary directory. A caller can pass another cache root to get a
stable artifact location for a test run or provider build. The cache is guarded
by a fingerprint of `racket-src/regexp/` plus `racket-src/common/check.rkt`;
changing staged source regenerates the demodded linklet.

The driver also caches the lowered provider top-level forms in the same cache
root. That avoids re-running first-slice lowering for every WebRacket compile
when the staged regexp sources are unchanged.

The command-line driver exposes cache controls:

```sh
--provider-cache-dir DIR
--clear-provider-cache
--force-provider-cache-refresh
```

With `--verbose`, provider composition reports cache hits and misses for the
demodded regexp linklet, the lowered regexp provider forms, and other provider
slices that share the same cache directory.

An earlier command produced `/private/tmp/webracket-regexp.rktl`, a flattened
linklet of roughly 472 KB in this checkout. The expander reported:

```text
Traversed 103 modules
Got 89 relevant linklets
Need 49 of those linklets
Can remove 491 of 882 defined names, keeping 391
Writing combined linklet to /private/tmp/webracket-regexp.rktl
```

The linklet exports 24 names:

```racket
byte-pregexp
byte-pregexp?
byte-regexp
byte-regexp?
pregexp
pregexp?
regexp
regexp-capture-group-count
regexp-match
regexp-match-peek
regexp-match-peek-immediate
regexp-match-peek-positions
regexp-match-peek-positions-immediate
regexp-match-peek-positions-immediate/end
regexp-match-peek-positions/end
regexp-match-positions
regexp-match-positions/end
regexp-match/end
regexp-match?
regexp-max-lookbehind
regexp-place-init!
regexp-replace
regexp-replace*
regexp?
```

The generated linklet is closed at the linklet boundary:

```racket
(cadr regexp-linklet) ; => '()
```

So the next blocker is not linklet import wiring. The next blocker is whether
Webify and WebRacket can lower and compile the forms, primitives, struct shapes,
and literals that remain inside the flattened body.

The first Webify lowering attempt now gets past raw starred struct field
access and no longer introduces Chez-style struct allocation:

```text
run-first-slice-top-level regexp-linklet ; succeeds
comp first-slice-output                 ; blocked by primitive alias collision
startup smoke with public exports       ; blocked by the same ownership issue
```

That means the regexp layer gets through demod and into Webify's first-slice
adapter, and the starred raw accessor/mutator shape is no longer the immediate
blocker. Webify used to create a Chez/Schemify `unsafe-struct` call while
inlining known constructors, but the regexp linklet itself does not contain that
form. The WebRacket target now keeps constructor procedures from
`make-struct-type` instead of inventing a Chez allocation primitive.

The current integration shape mirrors the `io/format` migration: the provider
is composed through module-variable cells, and the compiler no longer treats
public regexp exports as primitive-owned names. Compiled regexp literals are
lowered to public provider constructors such as `regexp`, `pregexp`,
`byte-regexp`, and `byte-pregexp`.

The driver now composes the regexp provider for normal compilations even when
`--no-stdlib` is used, and regexp public names are included in the compiler's
provider-owned alias set. That means direct references like `regexp-match?`
should resolve through the provider cell path instead of silently falling back
to older runtime primitive stubs.

The historical startup smoke needed these intentionally small lowerings, which
remain relevant when the ownership collision is removed:

- `make-parameter` becomes a mutable closure with optional guard support, but no
  `parameterize` semantics.
- `make-continuation-prompt-tag`/`call-with-continuation-prompt` are lowered for
  non-error startup paths only; WebRacket still does not support prompts.
- `unsafe-make-place-local`/`unsafe-place-local-ref`/
  `unsafe-place-local-set!` become box operations, which is enough for
  WebRacket's single-place runtime.
- `hash-iterate-first`/`hash-iterate-next`/`hash-iterate-key` and friends are
  lowered to WebRacket's mutable hash iterator primitives for no-stdlib slices.
  The demodded validator iterates local `#hasheqv()` tables, and WebRacket's
  current hash representation already maps these literals to mutable hash
  objects.
- `hash-set` now stays functional, using WebRacket's first immutable `hasheqv`
  runtime slice. The old `hash-set!` bridge was removed because it mutates
  immutable-looking tables and breaks expander/regexp paths once `#hasheqv()`
  is represented as an immutable hash.

Earlier direct top-level runtime probes confirmed these exported constructor
and basic matcher paths before the primitive ownership guard started rejecting
the public aliases:

```racket
(regexp? (regexp "a"))
(regexp-match? (regexp "a") "a")
(regexp-match (regexp "a") "cat")
(regexp-match? (regexp "ab") "xxabyy")
(regexp-match? (regexp "[ab]") "b")
(regexp-match (regexp "(a)") "cat")
(regexp-match? (regexp "a*") "bbb")
(regexp-match? (regexp "a+") "bbb")
(regexp-match? (regexp "^a") "ba")
(regexp-match? (regexp "^a") "ab")
(regexp-match? (byte-regexp #"a") #"cat")
(regexp-match? (pregexp "a|b") "b")
(regexp-match? (regexp "a?") "bbb")
(regexp-match-positions (regexp "a") "cat")
(regexp-replace (regexp "a") "cat" "o")
(regexp-replace* (regexp "a") "banana" "o")
```

Those probes exercised parsing, conversion, validation, matcher compilation,
allocation of the final regexp struct, capture bookkeeping, repetition, anchors,
byte regexp constructors, pregexp variants, position results, and replacement.
They should be restored as provider-cell runtime smokes once the public export
collision is resolved.

## Immediate Lesson

The regexp provider slice is staged, cache-aware, and composed by default,
including under `--no-stdlib`. Regular expressions are therefore part of the
baseline runtime surface, not an optional stdlib add-on.

The next Webify experiment should move from these first-order smoke tests to
broader conformance and integration:

```racket
(regexp-match (pregexp "(a|b)+") "zzabba")
(regexp-match? (regexp "\\\\p{Lu}") "A")
literal regexp compilation through Webify
```

Regexp literals now route through the provider constructors. The old
`webracket-literal-*regexp` primitives remain only as quarantined bootstrap
helpers and should not be extended with public regexp behavior.
