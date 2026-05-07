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

The first Webify lowering attempt now gets past raw starred struct field
access and no longer introduces Chez-style struct allocation:

```text
run-first-slice-top-level regexp-linklet ; succeeds
comp first-slice-output                 ; succeeds
startup smoke with (js-log 123)         ; succeeds
```

That means the regexp layer gets through demod and into Webify's first-slice
adapter, and the starred raw accessor/mutator shape is no longer the immediate
blocker. Webify used to create a Chez/Schemify `unsafe-struct` call while
inlining known constructors, but the regexp linklet itself does not contain that
form. The WebRacket target now keeps constructor procedures from
`make-struct-type` instead of inventing a Chez allocation primitive. The startup
smoke additionally needs three intentionally small lowerings:

- `make-parameter` becomes a mutable closure with optional guard support, but no
  `parameterize` semantics.
- `make-continuation-prompt-tag`/`call-with-continuation-prompt` are lowered for
  non-error startup paths only; WebRacket still does not support prompts.
- `unsafe-make-place-local`/`unsafe-place-local-ref`/
  `unsafe-place-local-set!` become box operations, which is enough for
  WebRacket's single-place runtime.

The next runtime blocker is calling the exported constructor:

```racket
(regexp? (regexp "a"))
```

Startup succeeds and `regexp`/`regexp?` are exported as procedures, but the
constructor call still raises an uncaught WebAssembly exception. That puts the
next investigation inside the regexp parser/compiler body, not in demod,
first-slice lowering, compilation, or module startup.

## Immediate Lesson

The next Webify experiment should instrument or reduce the body of the exported
`regexp` constructor. Once that call works, regexp literals can later be lifted
into calls to the linklet's `regexp`, `byte-regexp`, `pregexp`, and
`byte-pregexp` exports, mirroring the literal lifting strategy in
`src/cs/convert.rkt`.
