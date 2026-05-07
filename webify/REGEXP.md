# Regexp Layer Notes

Webify should treat Racket's regexp implementation as a library layer, not as a
hand-written WebAssembly primitive pile.

## Demod Artifact

The Racket CS build already flattens the regexp source tree into a single
linklet. The recipe is in:

```text
/Users/soegaard/Dropbox/GitHub/racket/racket/src/regexp/main.zuo
```

The important target invokes the expander bootstrap runner, not
`src/expander/main.rkt` directly:

```sh
/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket \
  /Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/bootstrap-run.rkt \
  -t /Users/soegaard/Dropbox/GitHub/racket/racket/src/regexp/main.rkt \
  -c /private/tmp/webracket-regexp-cache \
  -k /Users/soegaard/Dropbox/GitHub/racket/racket \
  -s -x \
  --depends /private/tmp/webracket-regexp-dep.rktd \
  --no-global \
  -o /private/tmp/webracket-regexp.rktl
```

That command produced `/private/tmp/webracket-regexp.rktl`, a flattened linklet
of roughly 472 KB in this checkout. The expander reported:

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

The first Webify lowering attempt reaches a concrete struct-operation blocker:

```text
webify: unsupported webify compatibility form remains after lowering: unsafe-struct*-ref
```

That means the regexp layer gets through demod and into Webify's first-slice
adapter, but known-struct inlining still emits Schemify/Chez-style
`unsafe-struct*` operations. WebRacket currently exposes `unsafe-struct-ref`
and `unsafe-struct-set!`, so the next implementation milestone is to translate
or support the `unsafe-struct*` accessor/mutator shape instead of treating it as
unsupported.

## Immediate Lesson

The next Webify experiment should consume the flattened linklet directly and
classify its imports. If the bridge can lower/compose that linklet, regexp
literals can later be lifted into calls to the linklet's `regexp`,
`byte-regexp`, `pregexp`, and `byte-pregexp` exports, mirroring the literal
lifting strategy in `src/cs/convert.rkt`.
