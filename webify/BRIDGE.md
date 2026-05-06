# Webify Bridge Example

The first bridge is deliberately small. It does not implement Racket modules.
It turns an import-free linklet into top-level WebRacket forms that the current
compiler can already consume.

## Input Linklet

```racket
(linklet () (x)
  (define-values (x) (+ 1 2)))
```

## Lowered First Slice

`webify-linklet-first-slice` produces a lowered procedure. The first argument is
the placeholder instance/variable-reference value; the remaining arguments are
export cells.

```racket
(lambda (instance-variable-reference x1)
  (define x 3)
  (module-variable-define! x1 x 'consistent))
```

## Top-Level Adapter Output

`webify-linklet-first-slice-top-level` wraps the lowered procedure as top-level
forms:

```racket
(begin
  (define webify-linklet-proc$0
    (lambda (instance-variable-reference x1)
      (define x 3)
      (module-variable-define! x1 x 'consistent)))

  (define webify-export-cell0$0
    (module-variable-make 'x))

  (webify-linklet-proc$0 'webify-instance webify-export-cell0$0)

  (define x
    (module-variable-ref webify-export-cell0$0))

  (void))
```

The helper names are deterministic internal symbols. If an export already uses
one of those internal names, the adapter increments the `$N` suffix until it
finds a non-colliding helper name. This avoids collisions when a linklet exports
a name like `webify-linklet-proc$0`.

The export `x` is represented by the cell `webify-export-cell0$0`. The lowered
procedure writes the exported value into that cell with
`module-variable-define!`. The adapter then exposes the cell value as the
ordinary top-level binding `x`.

For multiple exports, the adapter preserves export order:

```racket
(linklet () (x y)
  (define-values (x) 1)
  (define-values (y) 2))
```

becomes a top-level shape with one cell per export:

```racket
(define webify-export-cell0$0 (module-variable-make 'x))
(define webify-export-cell1$0 (module-variable-make 'y))
(webify-linklet-proc$0 'webify-instance
                       webify-export-cell0$0
                       webify-export-cell1$0)
(define x (module-variable-ref webify-export-cell0$0))
(define y (module-variable-ref webify-export-cell1$0))
```

With no exports, the same shape degenerates cleanly: there are no export cells
and the lowered procedure is invoked with only the placeholder instance value.

```racket
(linklet () ()
  (define-values (x) 1))
```

bridges to:

```racket
(define webify-linklet-proc$0
  (lambda (instance-variable-reference)
    (define x 1)
    (void)))
(webify-linklet-proc$0 'webify-instance)
(void)
```

Mutated exports work the same way. The adapter reads the export cell after the
lowered linklet procedure has finished, so the top-level binding observes the
final cell value:

```racket
(linklet () (x)
  (define-values (x) 1)
  (set! x 2))
```

bridges to a shape ending in:

```racket
(webify-linklet-proc$0 'webify-instance webify-export-cell0$0)
(define x (module-variable-ref webify-export-cell0$0))
```

Here `x` is read after the procedure has performed its `module-variable-set!`.

Callable exports are handled the same way. For example:

```racket
(linklet () (f)
  (define-values (f)
    (lambda (x) (+ x 1))))
```

bridges to a top-level `f` binding read from the export cell:

```racket
(webify-linklet-proc$0 'webify-instance webify-export-cell0$0)
(define f (module-variable-ref webify-export-cell0$0))
```

The binding `f` is an ordinary top-level value from the compiler's point of
view; the bridge does not need a special procedure-export path.

## Runtime Smoke

The adapter test also checks the generated top-level program through the normal
Node path. For a mutated export:

```racket
(linklet () (x)
  (define-values (x) 1)
  (set! x 2))
```

the test appends one observation form:

```racket
(js-log x)
```

and runs the generated program with `webracket.rkt --no-stdlib -r`. The output
must be `2`, which confirms that the exposed top-level binding reads the final
module-variable cell value after the lowered linklet procedure finishes.

## Why Top-Level Forms?

The current WebRacket compiler does not support the `module` form. The adapter
therefore avoids generating modules and uses ordinary top-level definitions and
expressions instead.

This gives us a real compiler-facing bridge:

```text
linklet
  -> webify-linklet-first-slice
  -> top-level WebRacket forms
  -> comp / webracket.rkt
```

Imports are intentionally rejected in this first slice. Import wiring needs a
real module-instance story and should not be hidden inside this adapter.

The adapter also rejects export lists that cannot be represented as ordinary
top-level definitions yet. Export names must be symbols, and duplicate exports
are rejected before any source is generated.

The lowered first-slice value must also be a fixed-arity `lambda`. Its arity
must be one more than the export count: one placeholder instance argument,
followed by one module-variable cell argument per export. The lambda formals
must be unique symbols.
