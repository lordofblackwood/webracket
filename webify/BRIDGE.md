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

## Module Composer

`webify/module-composer.rkt` turns the instance-plan pattern into an explicit
composition API.

At the lowest level, `webify-module-fragment` pairs one generated top-level
datum with its `webify-module-instance`:

```racket
(webify-module-fragment a-datum a-instance)
```

`webify-compose-module-fragments` then splices the fragment bodies into one
top-level `begin`:

```racket
(webify-compose-module-fragments
 (list (webify-module-fragment a-datum a-instance)
       (webify-module-fragment b-datum b-instance))
 #:tail '((js-log y)))
```

The result is still plain top-level WebRacket code, not a `module` form.

For lowered first-slice fragments, `webify-compose-lowered-first-slices` also
performs the adaptation step. Each `webify-lowered-slice-spec` gives a name, a
lowered lambda, grouped import names, grouped import sources, and exports:

```racket
(webify-compose-lowered-first-slices
 (list
  (webify-lowered-slice-spec
   'a
   lowered-a
   '()
   '()
   '(x))
  (webify-lowered-slice-spec
   'b
   lowered-b
   '((ext-x))
   '(((ext-x a x)))
   '(y))))
```

The triple `(ext-x a x)` means: satisfy B's import `ext-x` with export `x` from
the previously adapted instance named `a`.

For actual linklet datums, `webify-compose-linklet-first-slices` removes the
remaining manual lowering step. Each `webify-linklet-slice-spec` gives a name,
a linklet datum, and grouped import sources:

```racket
(webify-compose-linklet-first-slices
 (list
  (webify-linklet-slice-spec
   'a
   '(linklet () (x)
      (define-values (x) 10))
   '())
  (webify-linklet-slice-spec
   'b
   '(linklet (([ext-x x])) (y)
      (define-values (y) x))
   '(((ext-x a x)))))
 ...)
```

The composer runs `webify-linklet-first-slice`, checks that the resulting
imports are cell imports, resolves each import source through prior instances,
adapts the lowered slice to top-level forms, and returns:

```racket
(values combined-datum fragments instances exports-infos)
```

This milestone means the bridge can compose real first-slice linklets. The
caller still supplies the dependency order and import-source mapping explicitly;
there is still no module registry or namespace lookup.

## Module Registry

`webify/module-registry.rkt` adds a small named-entry layer above the linklet
composer. It is still not a namespace and it does not load modules lazily. It
just stores linklet datums and flat import-source metadata next to a symbolic
name:

```racket
(define registry
  (make-webify-module-registry))

(webify-module-registry-add!
 registry
 'a
 '(linklet () (x)
    (define-values (x) 10)))

(webify-module-registry-add!
 registry
 'b
 '(linklet (([ext-x x])) (y)
    (define-values (y) x))
 #:imports '((ext-x a x)))
```

`webify-compose-module-registry` converts the requested entries to linklet
slice specs and delegates to `webify-compose-linklet-first-slices`:

```racket
(webify-compose-module-registry registry '(a b) ...)
```

The registry stores imports in the flat form `((ext-x a x))`, but each entry
also records the linklet's own grouped import metadata and export list. At
registration time, the registry checks that every declared flat import matches
an actual linklet import name and that no linklet import is missing from the
declaration. During composition, the linklet composer still groups those triples
according to the actual `importss` metadata returned by
`webify-linklet-first-slice`. This keeps the registry API small while
preserving the linklet's grouped import order.

The registry validates duplicate entry names, malformed linklet metadata,
duplicate flat import names, duplicate linklet imports/exports, unknown
registry entries, mismatched import metadata, and explicit composition orders
where a dependency does not appear before the importing entry. If `b` imports
from `a`, explicit composition must use `(a b)`, not `(b a)`.

The registry can also plan that order from roots:

```racket
(webify-module-registry-plan registry '(b))
;; => '(a b)
```

The planner follows flat import-source dependency metadata transitively, rejects
unknown dependencies, and rejects cycles. `webify-compose-module-registry/roots`
uses the planner and then delegates to `webify-compose-module-registry`:

```racket
(webify-compose-module-registry/roots
 registry
 '(b)
 #:tail '((js-log y))
 ...)
```

For the example above, composing root `b` automatically includes `a` first and
produces the same top-level WebRacket program as explicit order `(a b)`.

This is the first step from a test harness composer toward a module-instantiation
pipeline: named module entries now exist, but there is still no `module` form,
namespace, `dynamic-require`, lazy instantiation, or struct translation.

The composer carries reserved helper ids forward automatically. In the example
above, A uses `webify-linklet-proc$0` and `webify-export-cell0$0`; B therefore
gets `webify-linklet-proc$1` and `webify-export-cell0$1` without the caller
manually calculating reserved names.

The composer is intentionally ordered and explicit. It does not discover
dependencies, instantiate modules lazily, or implement namespaces. Its job is to
make the current bridge compositional while still targeting the compiler's
existing top-level-program path.

The adapter tests also run this imported-composition shape through
`webracket.rkt --no-stdlib -r`: the first adapted slice exports `x = 10`, the
second adapted slice imports the first slice's `x` cell and exports `y`, and
the generated program logs `10` from `y`.

## Composition Payloads

Registry composition also has a reusable payload form:

```racket
(define composition
  (webify-compose-module-registry/roots/composition
   registry
   '(b)
   ...))
```

The payload is a `webify-module-composition` value containing the generated
top-level datum, adapted fragments, module-instance map, and export metadata.
The older multi-value APIs still exist; they unpack this payload for callers
that already expect `(values datum fragments instances exports-infos)`.

The payload API is the preferred shape for code that wants to compose once and
then build different observations or consumers of the same module instances:

```racket
(define x-cell
  (webify-module-composition-export-cell-id composition 'a 'x))
(define y-cell
  (webify-module-composition-export-cell-id composition 'b 'y))

(webify-module-composition-with-tail
 composition
 `((js-log (module-variable-ref ,x-cell))
   (js-log (module-variable-ref ,y-cell))))
```

This keeps the semantic observation path on module-variable cells instead of on
temporary top-level aliases. The aliases are still generated because the current
compiler target is a top-level program, but module-bridge tests should prefer
cell reads when they are checking module-instance behavior.

`webify-compose-module-registry/roots+observations` is a convenience/debug
helper layered over the payload API. It composes roots, resolves requested
`(module export)` pairs to export cells, and appends calls to an observer such
as `js-log`. It is useful for smoke tests, but it is intentionally not a
replacement for `dynamic-require`, namespaces, phases, or lazy module loading.

## Realistic Linklet Inputs

`webify/module-input.rkt` adds a small boundary for the shape a future module
extractor should hand to the bridge:

```racket
(list
 (webify-module-linklet-input
  'a
  '(linklet () (x)
     (define-values (x) 10))
  '())
 (webify-module-linklet-input
  'b
  '(linklet (([ext-x x])) (y)
     (define-values (y) (+ x 1)))
  '((ext-x a x))))
```

This is still not source-level Racket module support. The inputs are already
linklet-shaped, named, and separated into one entry per module-like unit.
`webify-module-linklet-inputs->registry` registers them in a normal
`webify-module-registry`, so the existing planner, composer, payload, and
loader paths are reused unchanged.

The important shift is where tests attach to the bridge. Earlier tests called
`webify-module-registry-add!` directly with inline linklet literals. The input
helper models the next seam instead: an extraction step produces a list of
named linklet inputs, and the bridge consumes that list without knowing how the
inputs were obtained.

The import-source triples are still explicit:

```racket
'((ext-x a x))
```

The triple means: satisfy B's import named `ext-x` from export `x` of input
`a`. Discovering that mapping from compiled module paths, phases, require
specs, or namespace state remains future work.

## Loader Facade

`webify/module-loader.rkt` is now the preferred API boundary for tests and
future integration code that want to treat the bridge as a module-instantiation
pipeline:

```racket
(define loader
  (make-webify-module-loader registry))

(webify-module-loader-instantiate! loader '(b) ...)

(define y-cell
  (webify-module-loader-lookup-export-cell loader 'b 'y))

(webify-module-loader-observe loader '((a x) (b y)))
```

The facade still composes a top-level WebRacket program under the hood. It does
not implement source-level `module`, lazy instantiation, `dynamic-require`, or
namespaces. The point is to make the current bridge read like explicit module
loading instead of direct helper-symbol manipulation.

The older names remain available:

```racket
webify-module-loader-instantiate-roots!
webify-module-loader-export-cell-id
webify-module-loader-with-tail
```

Those names are still useful when a test wants to emphasize the lower-level
composition mechanics.

The manifest smoke uses this facade from the outside in: read an `.rktd`
manifest, build a registry, instantiate the manifest roots, generate observer
forms, and run the resulting top-level program through `webracket.rkt
--no-stdlib`. That is now the preferred end-to-end bridge fixture because it
tests the handoff file format instead of only in-memory structs.

Manifests can also ask Webify to derive flat import triples from dependency
export tables:

```racket
(input b
       (linklet (([ext-x x])) (y)
         (define-values (y) (+ x 1)))
       (resolve-imports
        (dependency-exports ((a (x))))))
```

This is equivalent to:

```racket
(input b
       (linklet (([ext-x x])) (y)
         (define-values (y) (+ x 1)))
       (imports ((ext-x a x))))
```

If more than one dependency exports the same external name, the manifest can
provide an explicit local-import dependency mapping:

```racket
(resolve-imports
 (dependency-exports ((a (x)) (other (x))))
 (dependencies ((ext-x a))))
```

## Extractor Spike

`webify/module-extractor-spike.rkt` records the current result of probing real
compiled Racket modules. For a tiny source module:

```racket
(module a racket/base
  (provide x)
  (define x 10))
```

Racket compilation produces a `linklet-directory`. Its main bundle contains a
phase-0 linklet object whose export metadata includes `x`:

```racket
(webify-module-extractor-spike-phase0-exports report)
;; => '(x)
```

That is useful progress, but it is not enough to feed Webify's manifest bridge.
The bridge currently consumes linklet datums such as:

```racket
(linklet () (x)
  (define-values (x) 10))
```

The compiled module path gives us linklet objects, bundle keys, and import/export
metadata. The remaining blocker is an object-to-datum adapter or a different
Webify entry point that can consume compiled linklet objects directly. The spike
therefore reports `manifest-ready?` as `#f` on purpose.

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
