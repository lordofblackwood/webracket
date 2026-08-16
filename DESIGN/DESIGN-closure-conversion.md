# DESIGN-closure-conversion.md

This document explains closure conversion.

It answers four questions:

1. What is closure conversion?
2. Which analysis is needed before we can do it?
3. How is it implemented now in `compiler.rkt`?
4. Which representations and current design constraints shape the implementation?


## 1. What closure conversion is

A lambda can use variables that are not parameters of the lambda
itself.

Example:

```racket
(let ([y 10])
  (lambda (x) (+ x y)))
```

The lambda has one parameter, `x`, but it also uses `y`.
When the lambda is called later, `y` still needs to be available.

That is the job of a closure.

A closure is:

- code
- plus the saved values of the free variables used by that code

So this source program:

```racket
(let ([y 10])
  (lambda (x) (+ x y)))
```

is turned into something like:

```text
closure(
  code = label:add-y,
  free = [10]
)
```

and the code at `label:add-y` is changed so that it reads `y` from the
saved environment instead of from the original lexical scope.


## 2. Why we need closure conversion

Racket source code uses lexical scope.
WebAssembly does not have lexical closures built in.

That means the compiler must make closures explicit.

Informally:

```racket
(lambda (x) body)
```

becomes:

```text
make-a-closure(label-for-body, saved-free-variables)
```

and every reference to a free variable inside `body` becomes something
like:

```text
read slot i from the closure's saved environment
```


## 3. A small example

Start with:

```racket
(let ([y 10])
  ((lambda (x) (+ x y)) 5))
```

Before closure conversion, the lambda can mention `y` directly.

After closure conversion, we conceptually get:

```text
let y = 10
let clos = closure(label1, [y])
call clos with 5
```

and the lifted code becomes:

```text
label1(closure, args):
  x = first argument
  y = free variable 0 from closure
  return (+ x y)
```

So closure conversion does two big things:

- it lifts lambda bodies into separately named code labels
- it makes the environment explicit


## 4. What counts as a free variable

A free variable of a lambda is a variable that the lambda uses, but does
not bind itself.

Example:

```racket
(lambda (x) (+ x y))
```

Free variables:

- `y`

Not free:

- `x`
- `+`

Another example:

```racket
(let ([a 1]
      [b 2])
  (lambda (x)
    (let ([y 3])
      (+ a x y b))))
```

Free variables of the lambda:

- `a`
- `b`

Not free:

- `x`
- `y`

This analysis is the foundation of closure conversion.
If we get the free variables wrong, then the generated closure saves the
wrong values.


## 5. Which analysis is needed

At minimum, closure conversion needs:

- free-variable analysis
- a way to give each lambda a stable code label

In practice, a stronger closure conversion pass can also use:

- classification of lambdas
- caller information
- information about which lambdas are only called directly
- extended free-variable analysis


### 5.1 Free-variable analysis

For each lambda, we must compute the variables it captures.

Example:

```racket
(lambda (x) (+ x y z))
```

Free variables:

- `y`
- `z`

Then the closure can be represented as:

```text
closure(label, [y, z])
```


### 5.2 Stable labels

Each lifted lambda body needs a label so other generated code can call
it.

Example:

```text
label17
label18
label19
```

The exact names do not matter.
What matters is that each lambda gets a unique name.


### 5.3 Optional but useful: classifying lambdas

Not every lambda needs the full general closure treatment.

There are three useful categories:

- lambdas that really need closures
- lambdas with no free variables
- lambdas that are only ever called directly from known places

Example of a lambda with no free variables:

```racket
(lambda (x) (+ x 1))
```

This lambda does not need to save any environment.
It may still need to exist as a procedure value if the program passes it
around.

Example of a recursive helper that is only called directly:

```racket
(letrec ([loop (lambda (n)
                 (if (= n 0)
                     0
                     (loop (- n 1))))])
  (loop 10))
```

If `loop` is never passed around as a value, then we may not need a
full heap closure for it.

These are different properties:

- "has no free variables" means there is no environment to save
- "is only called directly" means we may be able to avoid treating it
  as a first-class procedure value


### 5.4 Extended free-variable analysis

Ordinary free-variable analysis tells us what a lambda uses directly.

Sometimes that is not enough.

Suppose one directly-called helper calls another directly-called helper.
Then the caller may need access not only to its own free variables, but
also to variables that it must pass onward to the callee.

Example:

```racket
(let ([z 10]
      [w 20])
  (letrec ([g (lambda (x) (+ x w))]
           [f (lambda (y) (g (+ y z)))])
    (f 1)))
```

The direct free variables are:

- `g` uses `w`
- `f` uses `g` and `z`

If `g` is treated as a directly-called helper, then `f` will need `w`
available too, so that `f` can pass it along when calling `g`.

So `f` may need more than its ordinary free-variable set.

This larger set is often called the extended free-variable set, or just
the set of variables that the binder needs.

Informally:

```text
extended(f) =
  direct free vars of f
  plus the extended needs of directly-called helpers called by f
```

This is a backwards-flow problem, not just a simple recursive tree
walk.

In Shivers' formulation, the analysis is especially important for
first-order lambdas, because they do not receive a closure record.
Instead, their callers pass needed values directly.

That makes the "what do I need to have available?" question transitive.


## 6. The main rewrite performed by closure conversion

Ignoring details, the rewrite looks like this:

```racket
(lambda (x) body)
```

becomes:

```text
(closure label free-vars ...)
```

and a new top-level code definition is added:

```text
(define-label label
  (converted-lambda body'))
```

where:

- `body'` is the converted body
- references to free variables are rewritten to closure-environment
  accesses

That is the ordinary closure-backed shape.

The current compiler still uses that as its baseline representation, but
it now also recognizes some narrower direct-helper cases.

So conceptually there are two layers:

- the fundamental closure-conversion rewrite:
  - lift code
  - make the environment explicit
- narrower helper-specific lowerings:
  - keep the lifted label
  - but avoid some closure allocation or ordinary closure-entry costs

The second layer does not replace closure conversion.
It specializes it in cases where analysis proves that the full
closure-backed path is not needed.


## 7. Closure representations in the current compiler

Before looking at the implementation details, it helps to separate the
representations the compiler currently uses.


### 7.1 Runtime type definitions

The runtime representation lives in `runtime-wasm.rkt`.

The most important closure-related definitions are:

```wat
(type $Args      (array (mut (ref eq))))
(type $Free      (array (mut (ref eq))))

(type $ProcedureInvoker
      (func (param $proc (ref $Procedure))
            (param $args (ref $Args))
            (result (ref eq))))

(type $ClosureCode  (func (param $clos (ref $Closure))
                          (param $args (ref $Args))
                          (result (ref eq))))
(type $KnownCode0   (func (param $args (ref $Args))
                          (result (ref eq))))
(type $KnownCode1   (func (param $env0 (ref eq))
                          (param $args (ref $Args))
                          (result (ref eq))))

(type $Procedure
      (sub $Heap
           (struct
             (field $hash   (mut i32))
             (field $name   (ref eq))
             (field $arity  (ref eq))
             (field $realm  (ref eq))
             (field $invoke (ref $ProcedureInvoker)))))

(type $Closure
      (sub $Procedure
           (struct
             (field $hash     (mut i32))
             (field $name     (ref eq))
             (field $arity    (ref eq))
             (field $realm    (ref eq))
             (field $invoke   (ref $ProcedureInvoker))
             (field $debug-id (ref eq))
             (field $code     (ref $ClosureCode))
             (field $free     (ref $Free)))))
```

For small closure payloads, the runtime also has specialized inline
variants:

```wat
(type $Closure1
      (sub $Closure
           (struct ... (field $free0 (mut (ref eq))))))

(type $Closure2
      (sub $Closure
           (struct ... (field $free0 (mut (ref eq)))
                      (field $free1 (mut (ref eq))))))

(type $Closure3
      (sub $Closure
           (struct ... (field $free0 (mut (ref eq)))
                      (field $free1 (mut (ref eq)))
                      (field $free2 (mut (ref eq))))))
```

These definitions already show the main representation split:

- ordinary closure-backed calls go through `$ClosureCode`
- known direct-helper entries use `$KnownCode0` or `$KnownCode1`
- closure values themselves are still `$Procedure` values
- captured env payload may live in `$Free` or in the inline
  `$Closure1`/`$Closure2`/`$Closure3` fields


### 7.2 Ordinary closure-backed helpers

This is the full general case.

The helper is represented as:

- a closure value
- carrying a closure payload
- pointing to a lifted label

Its lifted code reads captured variables through the closure env view.

This path is needed when the helper must behave like an ordinary
procedure value:

- it can escape
- it can be stored or returned
- it may be called through generic procedure machinery
- or the specialized helper predicates do not apply


### 7.3 Direct helpers with known entries

Some helpers are classified as `direct`.

These helpers may get specialized known-helper entries such as:

- `known0`
- `known1`

The important point is:

- “direct” does not automatically mean “not closure-backed”

A helper can have:

- a known direct-call entry
- and still keep an ordinary closure-backed entry

This is the transition-tax case that the analysis scripts have been
measuring.


### 7.4 Known-only helpers

Known-only helpers are the cases where the compiler can delete the
ordinary closure-backed path entirely.

For these helpers:

- direct calls use the known-helper entry
- no helper closure allocation remains
- no ordinary closure-backed entry remains

The currently active known-only buckets are:

- `known0-only`
- `known1-only`

These are not just ABI classifications.
They are deletion classifications.


### 7.5 Lifted-body env layout versus closure payload layout

The current implementation distinguishes:

- the env layout used by the lifted body
- the env layout stored in a closure payload

These correspond to:

- `body-layout-of`
- `closure-env-of`

They may coincide, but they are not the same concept.

This matters because:

- a helper body may use a propagated direct-helper env view
- while closure allocation still follows the ordinary closure payload
  layout

So the compiler now treats env access and closure storage as related but
separate design questions.


### 7.6 Why representation matters

Most of the recent work in this area turned out not to be about adding
another ABI name.

It turned out to be about representation cost:

- can we avoid closure allocation?
- can we avoid the ordinary closure-backed entry?
- can we avoid growing closure payload elsewhere?

That is why the current design distinguishes:

- closure-backed helpers
- known-entry helpers
- known-only helpers

This representation split is now more important than the older
“everything is a closure” story.

## 8. Another example

Source:

```racket
(let ([a 10])
  (lambda (x)
    (* x a)))
```

After free-variable analysis:

```text
free-vars = [a]
```

After closure conversion:

```text
(closure label:multiply-by-a [a])
```

and:

```text
label:multiply-by-a(clos, args):
  x = argument 0
  a = free-ref(clos, 0)
  return (* x a)
```

Before the next examples, it helps to separate two ideas.

- `known0` and `known1` describe specialized direct-call entries for a
  helper.
- `known0-only` and `known1-only` describe deletion: the helper can use
  the specialized entry and also drop the ordinary closure-backed path.

So:

- `known0` versus `known1` is about how many env operands the known
  entry takes.
- the `-only` forms are about whether closure allocation and the
  ordinary closure-backed entry can be removed.

The exact labels and local names in generated `.wat` are unstable, so
the snippets below show the shape of the current output rather than a
byte-for-byte dump of a full module.


### 8.1 `known0`

Source:

```racket
(let ([f (lambda (x) (+ x 1))])
  (f 5))
```

`f` has:

- fixed arity
- no extended env needs
- direct-call structure

So it can use the `known0` helper ABI.

Conceptually, the compiler can keep an ordinary closure-backed
representation available if needed, but direct calls may target a known
entry that does not need an environment payload.

This is still not `known0-only`.
The point is:

- the helper can use a specialized direct-call path
- but the ordinary closure-backed path may still exist

Generated WebAssembly shape:

```wat
(func $f.known0 (param $args (ref $List)) (result (ref eq))
  ...)

(func $f (param $clos (ref $Closure)) (param $args (ref $List)) (result (ref eq))
  (return_call $f.known0
    (local.get $args)))

...
(call $f.known0 <args>)
```

The important point is that the direct call can go to `$f.known0`, even
though the ordinary closure entry `$f` may still exist.


### 8.2 `known1`

Source:

```racket
(let ([x 10])
  (let ([f (lambda (y) (+ x y))])
    (f 2)))
```

`f` has:

- fixed arity
- one authoritative env need: `x`
- direct-call structure

So it can use the unary `known1` helper ABI.

Conceptually:

```text
known1 entry receives:
  env0 = x
  args = [y]
```

Again, this does not yet imply deletion of the ordinary closure-backed
path.
It means the helper qualifies for a specialized unary direct-call entry.

Generated WebAssembly shape:

```wat
(func $f.known1 (param $env0 (ref eq)) (param $args (ref $List)) (result (ref eq))
  ...)

(func $f (param $clos (ref $Closure)) (param $args (ref $List)) (result (ref eq))
  ...)

...
(call $f.known1 <env0> <args>)
```

Here the direct call passes the single carried env operand explicitly,
while the ordinary closure entry may still remain for general procedure
use.


### 8.3 `known0-only`

Source:

```racket
(let ([f (lambda (x) x)])
  (let ([g (lambda () (f 1))])
    (g)))
```

Here `g` is a good zero-env known-only helper:

- fixed arity
- no env payload
- no value use
- no closure identity requirement
- non-recursive local binding

So the compiler can delete:

- helper closure allocation
- the ordinary closure-backed entry

and keep only the `known0` path.

This is the first real deletion case.
It is not just “call a nicer label.”

Generated WebAssembly shape:

```wat
(func $g.known0 (param $args (ref $List)) (result (ref eq))
  ...)

...
(call $g.known0 <args>)
```

In this case there is no ordinary `$g` closure entry and no helper
closure allocation for `g`.


### 8.4 `known1-only`

Source:

```racket
(let ([x 1])
  (let ([f (lambda (y) (+ x y))])
    (f 2)))
```

This is the unary known-only analogue.

`f` has:

- one env value
- direct-only use
- no value escape
- no nested lift-sensitive form
- no nested capture of the carried env value
- callers that can already source the env

So the compiler can keep only the unary known-helper entry and delete:

- helper closure allocation
- the ordinary closure-backed entry

This is the most important nontrivial known-only case currently
supported by the implementation.

Generated WebAssembly shape:

```wat
(func $f.known1 (param $env0 (ref eq)) (param $args (ref $List)) (result (ref eq))
  ...)

...
(call $f.known1 <env0> <args>)
```

Unlike plain `known1`, this case has no ordinary `$f` closure entry and
no helper closure allocation.


## 9. What the current implementation does

The current implementation lives in `compiler.rkt`.

The main moving parts are:

- `determine-free-variables`
- `classify-lambdas!`
- `determine-extended-free-variables!`
- `closure-conversion-analysis`
- `closure-conversion`
- `finish-closure-conversion`

And then later code generation support for:

- `closure`
- `case-closure`
- `free-ref`
- `closedapp`
- `define-label`
- the current known-helper entry paths


### 9.1 Analysis state before rewriting

The compiler now computes more than plain free variables before the
actual closure-conversion rewrite.

The analysis stage records:

- the free variables of each abstraction
- the list of abstractions
- a lambda classification:
  - `closed`
  - `trivial-closed`
  - `direct`
- direct-call information
- value-use disqualification
- local binder/origin information
- extended env needs for direct helpers
- direct-callee relationships

This is all packaged by `closure-conversion-analysis`.

So closure conversion now starts from a richer view than:

```text
lambda -> free vars
```

It starts from:

```text
lambda -> free vars + kind + direct-call structure + extended env needs
```


### 9.2 Current helper categories

The implementation currently distinguishes three important cases:

- ordinary closure-backed lambdas
- trivial closed lambdas
- direct helpers

Ordinary closure-backed lambdas still follow the general closure path.

Direct helpers are the interesting middle case:
- they may use known direct-call lowering
- they may still remain closure-backed
- and only a subset can currently become known-only helpers

So “direct” does not mean “no closure exists.”
It means the compiler has enough structure to consider a more specialized
path.


### 9.3 Current layout concepts

The implementation now treats three env views as separate concepts:

- the ordinary free-variable set
- the extended env needs of a direct helper
- the current closure payload layout

Inside `finish-closure-conversion`, this becomes:

- `extended-layout-of`
- `body-layout-of`
- `closure-env-of`

Their roles are:

- `extended-layout-of`
  - the propagated env needs of a direct helper
- `body-layout-of`
  - the env layout the lifted helper body currently uses
- `closure-env-of`
  - the env layout actually stored in a closure payload

These are intentionally not the same concept.

In many cases today:
- `body-layout-of` and `closure-env-of` are still equal

But the compiler no longer assumes that they must always stay equal.
That split is already part of the implementation.


### 9.4 Current rewrite shape

The core closure-conversion rewrite still has the traditional shape.

For a lambda:

```racket
(lambda (x) body)
```

the compiler:

1. creates a fresh label
2. rewrites the body
3. lifts the rewritten body into `define-label`
4. replaces the original lambda expression with an explicit closure-like
   constructor or a known-helper form

So the baseline result is still conceptually:

```text
(closure inferred-name label arity free-var-exprs ...)
```

plus:

```text
(define-label label converted-body)
```

That part has not changed.
What changed is that some direct helpers can now avoid parts of the full
closure path.


### 9.5 Current free-variable references

Inside closure-backed lifted code, captured variables are still read via
`free-ref`.

That is still the ordinary closure-conversion mechanism.

For direct known-helper paths, the implementation may instead source env
values from specialized operands such as unary known-helper env passing.

So today there are two conceptual env access modes:

- closure-backed access:
  - `free-ref`
- specialized direct-helper access:
  - use the selected known-helper env path

The important point is that the compiler no longer assumes every lifted
helper must read its environment through a closure record.


### 9.6 Current known-helper lowering

The current implementation already has a real known-helper layer.

The important current buckets are:

- `known0`
- `known1`
- `known0-only`
- `known1-only`

Meaning:

- `known0`
  - direct helper with no authoritative env needs
- `known1`
  - direct helper with one authoritative env need
- `known0-only`
  - same basic helper family, but with closure allocation and ordinary
    closure entry deleted
- `known1-only`
  - unary-env version where the same deletion is safe

The implementation also includes a narrow body-layout migration for a
zero-env direct-helper subset.

What is not implemented as an active lowering path:

- `known2`
- broader unary carried-layout migration
- recursive known-only lowering for `letrec`


### 9.7 Current direct-helper analysis summaries

The compiler now contains a substantial analysis/reporting layer for
closure-conversion work.

This includes summaries for:

- raw closure-conversion analysis
- extended free-variable analysis
- direct-helper env plans
- direct-edge env availability
- layout concepts
- payoff/frontier analysis
- known-helper deletion opportunities
- binary-env (`known2`) frontier
- direct-letrec dependency/allocation/SCC summaries

These are analysis-only summaries.

They exist so that:

- tests can lock down expected behavior
- measurement scripts can evaluate optimization ideas
- experimental migration work can be checked before touching lowering

The current implementation also factors common summary state through a
shared helper instead of recomputing separate local versions in each
report.


### 9.8 Current `letrec-values` status

The compiler has improved analysis for direct `letrec` groups, but it
still treats recursive known-only lowering as a separate problem.

So today:

- direct-letrec structure is analyzed in detail
- allocation and patching summaries exist
- SCC structure is summarized
- some direct-letrec allocation simplifications exist

But:

- recursive known-only helpers are still intentionally out of scope
- the current known-helper deletion work is focused on non-`letrec`
  helpers

That boundary is deliberate.


## 10. What the recent experiments changed

The implementation has already explored several optimization directions,
and those experiments changed the design in important ways.


### 10.1 Extended-env analysis is now real

This is no longer just a design idea.

The compiler now computes a Shivers-style extended env view for direct
helpers, and the analysis/reporting layer uses it heavily.

That means the design question is no longer:

```text
Should we add extended env analysis?
```

It is:

```text
How far should lowering follow that analysis, and at what cost?
```


### 10.2 Known2 is currently shelved

The implementation investigated a sibling-only `known2` frontier.

The result was negative:

- the strict safe subset came out empty on the measured workloads
- the blocked cases were dominated by:
  - layout mismatch
  - env-not-in-closure
  - non-direct structure

So `known2` is not currently a practical next optimization.


### 10.3 Broad carried-layout migration did not pay for itself

Unary carried-layout migration was explored and backed out.

It was correct, but it did not improve code size enough to justify the
compile-time cost, especially on `pict`.

That means the compiler has already learned an important lesson:

- a more principled env layout is not enough by itself
- a change must delete something expensive to be worthwhile


### 10.4 Known-helper deletion is now the main remaining frontier

The compiler now has reports that distinguish:

- deletion-producing known-helper cases
- from shape-only or blocked cases

That work showed:

- many easy known0/known1 wins have already landed
- the remaining residue is small
- the remaining residue is not a clean local lowering tweak


### 10.5 Pure unavailable-env residue is payload-cost dominated

The current analysis can isolate the “pure unavailable-env” residue:

- helpers that are otherwise clean
- but still cannot become known-only because callers cannot source the
  needed env

The explanation report shows that these cases are mostly
`closure-payload-cost`, not cheap lexical-only or body-layout-only
fixes.

So the current frontier is not:

- “relax one more predicate”

It is:

- “understand whether env propagation would cost more in closure payload
  than it saves by deleting helper closure baggage”


## 11. Current design invariants

The current implementation relies on a few important invariants.


### 11.1 `body-layout-of` and `closure-env-of` are different concepts

Even when they currently coincide for many helpers, they mean different
things:

- `body-layout-of`
  - the env layout used by the lifted body
- `closure-env-of`
  - the env layout stored in the closure payload

The compiler is no longer written as though those must always be the
same.


### 11.2 Known-only means real deletion

A helper in a known-only class is not just “a nicer ABI label.”

It means:

- no helper closure allocation
- no ordinary closure-backed entry for that helper
- no ordinary closure path is required for procedure identity

That is why the analysis/reporting work tracks deletion explicitly.


### 11.3 Analysis summaries are conservative

The summary layer is intentionally conservative.

It is used for:

- regression tests
- measurement scripts
- design validation

So the summaries are supposed to describe the current compiler state,
not an optimistic future lowering.


### 11.4 `letrec` stays a separate problem

Recursive helper optimization is not being mixed casually into the
non-recursive known-helper work.

That remains an intentional design boundary because `letrec` brings:

- SCC structure
- patching requirements
- closure shell questions
- procedure-identity complications


## 12. What this means for future work

The closure-conversion implementation is no longer at the stage where
the obvious next step is “add another direct-helper ABI.”

The easy known-helper wins are mostly already in.

The hard remaining question is now a cost-model question:

- when should we propagate direct-helper env needs if doing so may grow
  closure payloads elsewhere?

So if this area is extended again, the next useful work is likely to be
payload-aware analysis rather than another immediate lowering tweak.

In particular, future work in this area should probably start with:

- who would need to carry new env values
- whether that would enlarge closure payloads
- whether enlarging those payloads would outweigh the known-helper
  deletion win

That is a different kind of work from the earlier known0/known1/known2
experiments, and the current implementation has reached the point where
that distinction matters.
