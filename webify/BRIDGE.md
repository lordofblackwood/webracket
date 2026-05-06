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

When adapting multiple import-free slices into one top-level program, pass the
helper ids from earlier slices as reserved names for later slices. The helper
function `first-slice-top-level-helper-ids` reports the internal names that a
slice will use, and `first-slice-top-level-export-cell-ids` maps each export to
its generated cell id:

```racket
(first-slice-top-level-helper-ids '(x))
;; => '(webify-linklet-proc$0 webify-export-cell0$0)

(hash-ref (first-slice-top-level-export-cell-ids '(x)) 'x)
;; => 'webify-export-cell0$0

(first-slice->top-level-datum lowered-y
                              '(y)
                              #:reserved '(x
                                            webify-linklet-proc$0
                                            webify-export-cell0$0))
```

The second slice then uses `webify-linklet-proc$1` and
`webify-export-cell0$1`, so the two generated top-level fragments can be placed
in the same `begin`.

For a lowered first-slice lambda that already has import cell arguments, use
`first-slice->top-level-datum/imports` and pass the import cell expressions
explicitly. For example, a second slice can import the first slice's export cell:

```racket
(define x-helpers
  (first-slice-top-level-helper-ids '(x)))
(define x-cells
  (first-slice-top-level-export-cell-ids '(x)))

(first-slice->top-level-datum/imports lowered-y
                                      (list (hash-ref x-cells 'x))
                                      '(y)
                                      #:reserved (append '(x) x-helpers))
```

The generated call passes the explicit import cells before the new export cells:

```racket
(webify-linklet-proc$1
 'webify-instance
 webify-export-cell0$0
 webify-export-cell0$1)
```

This is still not a full module loader. It is a direct composition hook for
already-lowered first-slice fragments whose import cells are known.

When starting from a linklet datum instead of an already-lowered lambda, use
`webify-linklet-first-slice-top-level/imports`. It runs the normal webify and
first-slice lowering path, checks that the linklet's imports are cell imports,
checks that the supplied import-cell count matches the import metadata, and then
uses the same top-level adapter:

```racket
(webify-linklet-first-slice-top-level/imports
 '(linklet (([ext-x x])) (y)
    (define-values (y) x))
 (list 'webify-export-cell0$0)
 #:reserved '(x webify-linklet-proc$0 webify-export-cell0$0)
 ...)
```

Use `first-slice-import-cell-args` to turn grouped import metadata and one cell
environment per import group into the flat argument order expected by the
lowered lambda:

```racket
(first-slice-import-cell-args
 '((ext-x))
 (list (hasheq 'ext-x 'webify-export-cell0$0)))
;; => '(webify-export-cell0$0)
```

For multiple import groups, names are resolved independently per group and then
flattened in linklet import order.

This is the first small bridge from import metadata to explicit WebRacket cell
wiring: imports are still not discovered from a module registry, but they are no
longer hidden inside prompt behavior or Chez-side linklet machinery.

## Module Instance Plans

`webify/module-instance.rkt` adds the next small abstraction. A
`webify-module-instance` is not a WebRacket runtime module value yet. It is an
adapter-side plan that records:

```racket
(webify-module-instance
 name
 exports
 export-cell-ids
 helper-ids)
```

For example:

```racket
(define a-instance
  (make-webify-module-instance 'a '(x)))

(webify-module-instance-export-cell-id a-instance 'x)
;; => 'webify-export-cell0$0
```

This lets composition code talk about an instance export instead of knowing the
generated helper name by hand. A second slice can build an import-cell
environment from the first instance:

```racket
(define b-imports
  (webify-module-instance-import-env
   a-instance
   '((ext-x . x))))

(first-slice-import-cell-args
 '((ext-x))
 (list b-imports))
;; => '(webify-export-cell0$0)
```

The pair `(ext-x . x)` means: the importing linklet expects an import named
`ext-x`, and that import should be backed by export `x` from `a-instance`.

The instance also exposes reserved ids for later generated slices:

```racket
(webify-module-instance-reserved-ids a-instance)
;; => '(x webify-linklet-proc$0 webify-export-cell0$0)
```

Using those reserved ids keeps helper names deterministic while avoiding
collisions in a combined top-level program.

For already-lowered slices, the convenience wrappers return both the generated
top-level datum and the instance plan:

```racket
(define-values (a-datum a-instance)
  (first-slice->module-instance-datum
   'a
   lowered-a
   '(x)))

(define-values (b-datum b-instance)
  (first-slice->module-instance-datum/imports
   'b
   lowered-b
   '((ext-x))
   (list (webify-module-instance-import-env a-instance
                                            '((ext-x . x))))
   '(y)
   #:reserved (webify-module-instance-reserved-ids a-instance)))
```

This is the milestone bridge shape: generated top-level code still feeds the
existing compiler, but imports and exports are now described as module-instance
cell relationships instead of loose helper-symbol plumbing.

The adapter tests also run this imported-composition shape through
`webracket.rkt --no-stdlib -r`: the first adapted slice exports `x = 10`, the
second adapted slice imports the first slice's `x` cell and exports `y`, and
the generated program logs `10` from `y`.

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
