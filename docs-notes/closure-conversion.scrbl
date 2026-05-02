#lang scribble/manual

@(require scribble/core
          (except-in scribble-tools racketblock racketblock0)
          (for-label racket))

@title{Closure Conversion}

This document explains closure conversion.

It answers four questions:

@itemlist[
 @item{What is closure conversion?}
 @item{Which analysis is needed before we can do it?}
 @item{How is it implemented now in @tt{compiler.rkt}?}
 @item{Which representations and current design constraints shape the implementation?}
]

@section{What closure conversion is}

A lambda can use variables that are not parameters of the lambda
itself.

Example:

@racketblock[
(let ([y 10])
  (lambda (x) (+ x y)))
]

The lambda has one parameter, @racket[x], but it also uses @racket[y].
When the lambda is called later, @racket[y] still needs to be available.

That is the job of a closure.

A closure is:

@itemlist[
 @item{code}
 @item{plus the saved values of the free variables used by that code}
]

So this source program:

@racketblock[
(let ([y 10])
  (lambda (x) (+ x y)))
]

is turned into something like:

@verbatim{
closure(
  code = label:add-y,
  free = [10]
)
}

and the code at @tt{label:add-y} is changed so that it reads @racket[y]
from the saved environment instead of from the original lexical scope.


@section{Why we need closure conversion}

Racket source code uses lexical scope.
WebAssembly does not have lexical closures built in.

That means the compiler must make closures explicit.

Informally:

@racketblock[
(lambda (x) body)
]

becomes:

@verbatim{
make-a-closure(label-for-body, saved-free-variables)
}

and every reference to a free variable inside @racket[body] becomes
something like:

@verbatim{
read slot i from the closure's saved environment
}


@section{A small example}

Start with:

@racketblock[
(let ([y 10])
  ((lambda (x) (+ x y)) 5))
]

Before closure conversion, the lambda can mention @racket[y] directly.

After closure conversion, we conceptually get:

@verbatim{
let y = 10
let clos = closure(label1, [y])
call clos with 5
}

and the lifted code becomes:

@verbatim{
label1(closure, args):
  x = first argument
  y = free variable 0 from closure
  return (+ x y)
}

So closure conversion does two big things:

@itemlist[
 @item{it lifts lambda bodies into separately named code labels}
 @item{it makes the environment explicit}
]


@section{What counts as a free variable}

A free variable of a lambda is a variable that the lambda uses, but does
not bind itself.

Example:

@racketblock[
(lambda (x) (+ x y))
]

Free variables:

@itemlist[
 @item{@racket[y]}
]

Not free:

@itemlist[
 @item{@racket[x]}
 @item{@racket[+]}
]

Another example:

@racketblock[
(let ([a 1]
      [b 2])
  (lambda (x)
    (let ([y 3])
      (+ a x y b))))
]

Free variables of the lambda:

@itemlist[
 @item{@racket[a]}
 @item{@racket[b]}
]

Not free:

@itemlist[
 @item{@racket[x]}
 @item{@racket[y]}
]

This analysis is the foundation of closure conversion.
If we get the free variables wrong, then the generated closure saves the
wrong values.


@section{Which analysis is needed}

At minimum, closure conversion needs:

@itemlist[
 @item{free-variable analysis}
 @item{a way to give each lambda a stable code label}
]

In practice, a stronger closure conversion pass can also use:

@itemlist[
 @item{classification of lambdas}
 @item{caller information}
 @item{information about which lambdas are only called directly}
 @item{extended free-variable analysis}
]


@subsection{Free-variable analysis}

For each lambda, we must compute the variables it captures.

Example:

@racketblock[
(lambda (x) (+ x y z))
]

Free variables:

@itemlist[
 @item{@racket[y]}
 @item{@racket[z]}
]

Then the closure can be represented as:

@verbatim{
closure(label, [y, z])
}


@subsection{Stable labels}

Each lifted lambda body needs a label so other generated code can call
it.

Example:

@verbatim{
label17
label18
label19
}

The exact names do not matter.
What matters is that each lambda gets a unique name.


@subsection{Optional but useful: classifying lambdas}

Not every lambda needs the full general closure treatment.

There are three useful categories:

@itemlist[
 @item{lambdas that really need closures}
 @item{lambdas with no free variables}
 @item{lambdas that are only ever called directly from known places}
]

Example of a lambda with no free variables:

@racketblock[
(lambda (x) (+ x 1))
]

This lambda does not need to save any environment.
It may still need to exist as a procedure value if the program passes it
around.

Example of a recursive helper that is only called directly:

@racketblock[
(letrec ([loop (lambda (n)
                 (if (= n 0)
                     0
                     (loop (- n 1))))])
  (loop 10))
]

If @racket[loop] is never passed around as a value, then we may not
need a full heap closure for it.

These are different properties:

@itemlist[
 @item{@litchar{has no free variables} means there is no environment to save}
 @item{@litchar{is only called directly} means we may be able to avoid treating it as a first-class procedure value}
]


@subsection{Extended free-variable analysis}

Ordinary free-variable analysis tells us what a lambda uses directly.

Sometimes that is not enough.

Suppose one directly-called helper calls another directly-called helper.
Then the caller may need access not only to its own free variables, but
also to variables that it must pass onward to the callee.

Example:

@racketblock[
(let ([z 10]
      [w 20])
  (letrec ([g (lambda (x) (+ x w))]
           [f (lambda (y) (g (+ y z)))])
    (f 1)))
]

The direct free variables are:

@itemlist[
 @item{@racket[g] uses @racket[w]}
 @item{@racket[f] uses @racket[g] and @racket[z]}
]

If @racket[g] is treated as a directly-called helper, then @racket[f]
will need @racket[w] available too, so that @racket[f] can pass it
along when calling @racket[g].

So @racket[f] may need more than its ordinary free-variable set.

This larger set is often called the extended free-variable set, or just
the set of variables that the binder needs.

Informally:

@verbatim{
extended(f) =
  direct free vars of f
  plus the extended needs of directly-called helpers called by f
}

This is a backwards-flow problem, not just a simple recursive tree
walk.

In Shivers' formulation, the analysis is especially important for
first-order lambdas, because they do not receive a closure record.
Instead, their callers pass needed values directly.

That makes the @litchar{what do I need to have available?} question
transitive.


@section{The main rewrite performed by closure conversion}

Ignoring details, the rewrite looks like this:

@racketblock[
(lambda (x) body)
]

becomes:

@verbatim{
(closure label free-vars ...)
}

and a new top-level code definition is added:

@verbatim{
(define-label label
  (converted-lambda body'))
}

where:

@itemlist[
 @item{@tt{body'} is the converted body}
 @item{references to free variables are rewritten to closure-environment accesses}
]

That is the ordinary closure-backed shape.

The current compiler still uses that as its baseline representation, but
it now also recognizes some narrower direct-helper cases.

So conceptually there are two layers:

@itemlist[
 @item{the fundamental closure-conversion rewrite:
       @itemlist[
        @item{lift code}
        @item{make the environment explicit}
       ]}
 @item{narrower helper-specific lowerings:
       @itemlist[
        @item{keep the lifted label}
        @item{but avoid some closure allocation or ordinary closure-entry costs}
       ]}
]

The second layer does not replace closure conversion.
It specializes it in cases where analysis proves that the full
closure-backed path is not needed.


@section{Closure representations in the current compiler}

Before looking at the implementation details, it helps to separate the
representations the compiler currently uses.


@subsection{Runtime type definitions}

The runtime representation lives in @tt{runtime-wasm.rkt}.

The most important closure-related definitions are:

@wasmblock{
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
}

For small closure payloads, the runtime also has specialized inline
variants:

@wasmblock{
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
}

These definitions already show the main representation split:

@itemlist[
 @item{ordinary closure-backed calls go through @tt{$ClosureCode}}
 @item{known direct-helper entries use @tt{$KnownCode0} or @tt{$KnownCode1}}
 @item{closure values themselves are still @tt{$Procedure} values}
 @item{captured env payload may live in @tt{$Free} or in the inline
       @tt{$Closure1}/@tt{$Closure2}/@tt{$Closure3} fields}
]


@subsection{Ordinary closure-backed helpers}

This is the full general case.

The helper is represented as:

@itemlist[
 @item{a closure value}
 @item{carrying a closure payload}
 @item{pointing to a lifted label}
]

Its lifted code reads captured variables through the closure env view.

This path is needed when the helper must behave like an ordinary
procedure value:

@itemlist[
 @item{it can escape}
 @item{it can be stored or returned}
 @item{it may be called through generic procedure machinery}
 @item{or the specialized helper predicates do not apply}
]


@subsection{Direct helpers with known entries}

Some helpers are classified as @tt{direct}.

These helpers may get specialized known-helper entries such as:

@itemlist[
 @item{@tt{known0}}
 @item{@tt{known1}}
]

The important point is:

@itemlist[
 @item{@litchar{direct} does not automatically mean @litchar{not closure-backed}}
]

A helper can have:

@itemlist[
 @item{a known direct-call entry}
 @item{and still keep an ordinary closure-backed entry}
]

This is the transition-tax case that the analysis scripts have been
measuring.


@subsection{Known-only helpers}

Known-only helpers are the cases where the compiler can delete the
ordinary closure-backed path entirely.

For these helpers:

@itemlist[
 @item{direct calls use the known-helper entry}
 @item{no helper closure allocation remains}
 @item{no ordinary closure-backed entry remains}
]

The currently active known-only buckets are:

@itemlist[
 @item{@tt{known0-only}}
 @item{@tt{known1-only}}
]

These are not just ABI classifications.
They are deletion classifications.


@subsection{Lifted-body env layout versus closure payload layout}

The current implementation distinguishes:

@itemlist[
 @item{the env layout used by the lifted body}
 @item{the env layout stored in a closure payload}
]

These correspond to:

@itemlist[
 @item{@tt{body-layout-of}}
 @item{@tt{closure-env-of}}
]

They may coincide, but they are not the same concept.

This matters because:

@itemlist[
 @item{a helper body may use a propagated direct-helper env view}
 @item{while closure allocation still follows the ordinary closure payload layout}
]

So the compiler now treats env access and closure storage as related but
separate design questions.


@subsection{Why representation matters}

Most of the recent work in this area turned out not to be about adding
another ABI name.

It turned out to be about representation cost:

@itemlist[
 @item{can we avoid closure allocation?}
 @item{can we avoid the ordinary closure-backed entry?}
 @item{can we avoid growing closure payload elsewhere?}
]

That is why the current design distinguishes:

@itemlist[
 @item{closure-backed helpers}
 @item{known-entry helpers}
 @item{known-only helpers}
]

This representation split is now more important than the older
@litchar{everything is a closure} story.


@section{Another example}

Source:

@racketblock[
(let ([a 10])
  (lambda (x)
    (* x a)))
]

After free-variable analysis:

@verbatim{
free-vars = [a]
}

After closure conversion:

@verbatim{
(closure label:multiply-by-a [a])
}

and:

@verbatim{
label:multiply-by-a(clos, args):
  x = argument 0
  a = free-ref(clos, 0)
  return (* x a)
}

Before the next examples, it helps to separate two ideas.

@itemlist[
 @item{@tt{known0} and @tt{known1} describe specialized direct-call
       entries for a helper.}
 @item{@tt{known0-only} and @tt{known1-only} describe deletion: the
       helper can use the specialized entry and also drop the ordinary
       closure-backed path.}
]

So:

@itemlist[
 @item{@tt{known0} versus @tt{known1} is about how many env operands the
       known entry takes.}
 @item{the @tt{-only} forms are about whether closure allocation and the
       ordinary closure-backed entry can be removed.}
]

The exact labels and local names in generated @tt{.wat} are unstable, so
the snippets below show the shape of the current output rather than a
byte-for-byte dump of a full module.


@subsection{@tt{known0}}

Source:

@racketblock[
(let ([f (lambda (x) (+ x 1))])
  (f 5))
]

@racket[f] has:

@itemlist[
 @item{fixed arity}
 @item{no extended env needs}
 @item{direct-call structure}
]

So it can use the @tt{known0} helper ABI.

Conceptually, the compiler can keep an ordinary closure-backed
representation available if needed, but direct calls may target a known
entry that does not need an environment payload.

This is still not @tt{known0-only}.
The point is:

@itemlist[
 @item{the helper can use a specialized direct-call path}
 @item{but the ordinary closure-backed path may still exist}
]

Generated WebAssembly shape:

@wasmblock{
(func $f.known0 (param $args (ref $List)) (result (ref eq))
  ...)

(func $f (param $clos (ref $Closure)) (param $args (ref $List)) (result (ref eq))
  (return_call $f.known0
    (local.get $args)))

...
(call $f.known0 <args>)
}

The important point is that the direct call can go to @tt{$f.known0},
even though the ordinary closure entry @tt{$f} may still exist.


@subsection{@tt{known1}}

Source:

@racketblock[
(let ([x 10])
  (let ([f (lambda (y) (+ x y))])
    (f 2)))
]

@racket[f] has:

@itemlist[
 @item{fixed arity}
 @item{one authoritative env need: @racket[x]}
 @item{direct-call structure}
]

So it can use the unary @tt{known1} helper ABI.

Conceptually:

@verbatim{
known1 entry receives:
  env0 = x
  args = [y]
}

Again, this does not yet imply deletion of the ordinary closure-backed
path.
It means the helper qualifies for a specialized unary direct-call entry.

Generated WebAssembly shape:

@wasmblock{
(func $f.known1 (param $env0 (ref eq)) (param $args (ref $List)) (result (ref eq))
  ...)

(func $f (param $clos (ref $Closure)) (param $args (ref $List)) (result (ref eq))
  ...)

...
(call $f.known1 <env0> <args>)
}

Here the direct call passes the single carried env operand explicitly,
while the ordinary closure entry may still remain for general procedure
use.


@subsection{@tt{known0-only}}

Source:

@racketblock[
(let ([f (lambda (x) x)])
  (let ([g (lambda () (f 1))])
    (g)))
]

Here @racket[g] is a good zero-env known-only helper:

@itemlist[
 @item{fixed arity}
 @item{no env payload}
 @item{no value use}
 @item{no closure identity requirement}
 @item{non-recursive local binding}
]

So the compiler can delete:

@itemlist[
 @item{helper closure allocation}
 @item{the ordinary closure-backed entry}
]

and keep only the @tt{known0} path.

This is the first real deletion case.
It is not just @litchar{call a nicer label.}

Generated WebAssembly shape:

@wasmblock{
(func $g.known0 (param $args (ref $List)) (result (ref eq))
  ...)

...
(call $g.known0 <args>)
}

In this case there is no ordinary @tt{$g} closure entry and no helper
closure allocation for @racket[g].


@subsection{@tt{known1-only}}

Source:

@racketblock[
(let ([x 1])
  (let ([f (lambda (y) (+ x y))])
    (f 2)))
]

This is the unary known-only analogue.

@racket[f] has:

@itemlist[
 @item{one env value}
 @item{direct-only use}
 @item{no value escape}
 @item{no nested lift-sensitive form}
 @item{no nested capture of the carried env value}
 @item{callers that can already source the env}
]

So the compiler can keep only the unary known-helper entry and delete:

@itemlist[
 @item{helper closure allocation}
 @item{the ordinary closure-backed entry}
]

This is the most important nontrivial known-only case currently
supported by the implementation.

Generated WebAssembly shape:

@wasmblock{
(func $f.known1 (param $env0 (ref eq)) (param $args (ref $List)) (result (ref eq))
  ...)

...
(call $f.known1 <env0> <args>)
}

Unlike plain @tt{known1}, this case has no ordinary @tt{$f} closure
entry and no helper closure allocation.


@section{What the current implementation does}

The current implementation lives in @tt{compiler.rkt}.

The main moving parts are:

@itemlist[
 @item{@tt{determine-free-variables}}
 @item{@tt{classify-lambdas!}}
 @item{@tt{determine-extended-free-variables!}}
 @item{@tt{closure-conversion-analysis}}
 @item{@tt{closure-conversion}}
 @item{@tt{finish-closure-conversion}}
]

And then later code generation support for:

@itemlist[
 @item{@tt{closure}}
 @item{@tt{case-closure}}
 @item{@tt{free-ref}}
 @item{@tt{closedapp}}
 @item{@tt{define-label}}
 @item{the current known-helper entry paths}
]


@subsection{Analysis state before rewriting}

The compiler now computes more than plain free variables before the
actual closure-conversion rewrite.

The analysis stage records:

@itemlist[
 @item{the free variables of each abstraction}
 @item{the list of abstractions}
 @item{a lambda classification:
       @itemlist[
        @item{@tt{closed}}
        @item{@tt{trivial-closed}}
        @item{@tt{direct}}
       ]}
 @item{direct-call information}
 @item{value-use disqualification}
 @item{local binder/origin information}
 @item{extended env needs for direct helpers}
 @item{direct-callee relationships}
]

This is all packaged by @tt{closure-conversion-analysis}.

So closure conversion now starts from a richer view than:

@verbatim{
lambda -> free vars
}

It starts from:

@verbatim{
lambda -> free vars + kind + direct-call structure + extended env needs
}


@subsection{Current helper categories}

The implementation currently distinguishes three important cases:

@itemlist[
 @item{ordinary closure-backed lambdas}
 @item{trivial closed lambdas}
 @item{direct helpers}
]

Ordinary closure-backed lambdas still follow the general closure path.

Direct helpers are the interesting middle case:

@itemlist[
 @item{they may use known direct-call lowering}
 @item{they may still remain closure-backed}
 @item{and only a subset can currently become known-only helpers}
]

So @litchar{direct} does not mean @litchar{no closure exists.}
It means the compiler has enough structure to consider a more
specialized path.


@subsection{Current layout concepts}

The implementation now treats three env views as separate concepts:

@itemlist[
 @item{the ordinary free-variable set}
 @item{the extended env needs of a direct helper}
 @item{the current closure payload layout}
]

Inside @tt{finish-closure-conversion}, this becomes:

@itemlist[
 @item{@tt{extended-layout-of}}
 @item{@tt{body-layout-of}}
 @item{@tt{closure-env-of}}
]

Their roles are:

@itemlist[
 @item{@tt{extended-layout-of}
       @itemlist[
        @item{the propagated env needs of a direct helper}
       ]}
 @item{@tt{body-layout-of}
       @itemlist[
        @item{the env layout the lifted helper body currently uses}
       ]}
 @item{@tt{closure-env-of}
       @itemlist[
        @item{the env layout actually stored in a closure payload}
       ]}
]

These are intentionally not the same concept.

In many cases today:

@itemlist[
 @item{@tt{body-layout-of} and @tt{closure-env-of} are still equal}
]

But the compiler no longer assumes that they must always stay equal.
That split is already part of the implementation.


@subsection{Current rewrite shape}

The core closure-conversion rewrite still has the traditional shape.

For a lambda:

@racketblock[
(lambda (x) body)
]

the compiler:

@itemlist[
 @item{creates a fresh label}
 @item{rewrites the body}
 @item{lifts the rewritten body into @tt{define-label}}
 @item{replaces the original lambda expression with an explicit closure-like constructor or a known-helper form}
]

So the baseline result is still conceptually:

@verbatim{
(closure inferred-name label arity free-var-exprs ...)
}

plus:

@verbatim{
(define-label label converted-body)
}

That part has not changed.
What changed is that some direct helpers can now avoid parts of the full
closure path.


@subsection{Current free-variable references}

Inside closure-backed lifted code, captured variables are still read via
@tt{free-ref}.

That is still the ordinary closure-conversion mechanism.

For direct known-helper paths, the implementation may instead source env
values from specialized operands such as unary known-helper env passing.

So today there are two conceptual env access modes:

@itemlist[
 @item{closure-backed access:
       @itemlist[
        @item{@tt{free-ref}}
       ]}
 @item{specialized direct-helper access:
       @itemlist[
        @item{use the selected known-helper env path}
       ]}
]

The important point is that the compiler no longer assumes every lifted
helper must read its environment through a closure record.


@subsection{Current known-helper lowering}

The current implementation already has a real known-helper layer.

The important current buckets are:

@itemlist[
 @item{@tt{known0}}
 @item{@tt{known1}}
 @item{@tt{known0-only}}
 @item{@tt{known1-only}}
]

Meaning:

@itemlist[
 @item{@tt{known0}
       @itemlist[
        @item{direct helper with no authoritative env needs}
       ]}
 @item{@tt{known1}
       @itemlist[
        @item{direct helper with one authoritative env need}
       ]}
 @item{@tt{known0-only}
       @itemlist[
        @item{same basic helper family, but with closure allocation and ordinary closure entry deleted}
       ]}
 @item{@tt{known1-only}
       @itemlist[
        @item{unary-env version where the same deletion is safe}
       ]}
]

The implementation also includes a narrow body-layout migration for a
zero-env direct-helper subset.

What is not implemented as an active lowering path:

@itemlist[
 @item{@tt{known2}}
 @item{broader unary carried-layout migration}
 @item{recursive known-only lowering for @tt{letrec}}
]


@subsection{Current direct-helper analysis summaries}

The compiler now contains a substantial analysis/reporting layer for
closure-conversion work.

This includes summaries for:

@itemlist[
 @item{raw closure-conversion analysis}
 @item{extended free-variable analysis}
 @item{direct-helper env plans}
 @item{direct-edge env availability}
 @item{layout concepts}
 @item{payoff/frontier analysis}
 @item{known-helper deletion opportunities}
 @item{binary-env (@tt{known2}) frontier}
 @item{direct-letrec dependency/allocation/SCC summaries}
]

These are analysis-only summaries.

They exist so that:

@itemlist[
 @item{tests can lock down expected behavior}
 @item{measurement scripts can evaluate optimization ideas}
 @item{experimental migration work can be checked before touching lowering}
]

The current implementation also factors common summary state through a
shared helper instead of recomputing separate local versions in each
report.


@subsection{Current @tt{letrec-values} status}

The compiler has improved analysis for direct @tt{letrec} groups, but
it still treats recursive known-only lowering as a separate problem.

So today:

@itemlist[
 @item{direct-letrec structure is analyzed in detail}
 @item{allocation and patching summaries exist}
 @item{SCC structure is summarized}
 @item{some direct-letrec allocation simplifications exist}
]

But:

@itemlist[
 @item{recursive known-only helpers are still intentionally out of scope}
 @item{the current known-helper deletion work is focused on non-@tt{letrec} helpers}
]

That boundary is deliberate.


@section{What the recent experiments changed}

The implementation has already explored several optimization directions,
and those experiments changed the design in important ways.


@subsection{Extended-env analysis is now real}

This is no longer just a design idea.

The compiler now computes a Shivers-style extended env view for direct
helpers, and the analysis/reporting layer uses it heavily.

That means the design question is no longer:

@verbatim{
Should we add extended env analysis?
}

It is:

@verbatim{
How far should lowering follow that analysis, and at what cost?
}


@subsection{@tt{known2} is currently shelved}

The implementation investigated a sibling-only @tt{known2} frontier.

The result was negative:

@itemlist[
 @item{the strict safe subset came out empty on the measured workloads}
 @item{the blocked cases were dominated by:
       @itemlist[
        @item{layout mismatch}
        @item{env-not-in-closure}
        @item{non-direct structure}
       ]}
]

So @tt{known2} is not currently a practical next optimization.


@subsection{Broad carried-layout migration did not pay for itself}

Unary carried-layout migration was explored and backed out.

It was correct, but it did not improve code size enough to justify the
compile-time cost, especially on @tt{pict}.

That means the compiler has already learned an important lesson:

@itemlist[
 @item{a more principled env layout is not enough by itself}
 @item{a change must delete something expensive to be worthwhile}
]


@subsection{Known-helper deletion is now the main remaining frontier}

The compiler now has reports that distinguish:

@itemlist[
 @item{deletion-producing known-helper cases}
 @item{from shape-only or blocked cases}
]

That work showed:

@itemlist[
 @item{many easy known0/known1 wins have already landed}
 @item{the remaining residue is small}
 @item{the remaining residue is not a clean local lowering tweak}
]


@subsection{Pure unavailable-env residue is payload-cost dominated}

The current analysis can isolate the @litchar{pure unavailable-env}
residue:

@itemlist[
 @item{helpers that are otherwise clean}
 @item{but still cannot become known-only because callers cannot source the needed env}
]

The explanation report shows that these cases are mostly
@tt{closure-payload-cost}, not cheap lexical-only or body-layout-only
fixes.

So the current frontier is not:

@itemlist[
 @item{@litchar{relax one more predicate}}
]

It is:

@itemlist[
 @item{@litchar{understand whether env propagation would cost more in closure payload than it saves by deleting helper closure baggage}}
]


@section{Current design invariants}

The current implementation relies on a few important invariants.


@subsection{@tt{body-layout-of} and @tt{closure-env-of} are different concepts}

Even when they currently coincide for many helpers, they mean different
things:

@itemlist[
 @item{@tt{body-layout-of}
       @itemlist[
        @item{the env layout used by the lifted body}
       ]}
 @item{@tt{closure-env-of}
       @itemlist[
        @item{the env layout stored in the closure payload}
       ]}
]

The compiler is no longer written as though those must always be the
same.


@subsection{Known-only means real deletion}

A helper in a known-only class is not just @litchar{a nicer ABI label.}

It means:

@itemlist[
 @item{no helper closure allocation}
 @item{no ordinary closure-backed entry for that helper}
 @item{no ordinary closure path is required for procedure identity}
]

That is why the analysis/reporting work tracks deletion explicitly.


@subsection{Analysis summaries are conservative}

The summary layer is intentionally conservative.

It is used for:

@itemlist[
 @item{regression tests}
 @item{measurement scripts}
 @item{design validation}
]

So the summaries are supposed to describe the current compiler state,
not an optimistic future lowering.


@subsection{@tt{letrec} stays a separate problem}

Recursive helper optimization is not being mixed casually into the
non-recursive known-helper work.

That remains an intentional design boundary because @tt{letrec} brings:

@itemlist[
 @item{SCC structure}
 @item{patching requirements}
 @item{closure shell questions}
 @item{procedure-identity complications}
]


@section{What this means for future work}

The closure-conversion implementation is no longer at the stage where
the obvious next step is @litchar{add another direct-helper ABI.}

The easy known-helper wins are mostly already in.

The hard remaining question is now a cost-model question:

@itemlist[
 @item{when should we propagate direct-helper env needs if doing so may grow closure payloads elsewhere?}
]

So if this area is extended again, the next useful work is likely to be
payload-aware analysis rather than another immediate lowering tweak.

In particular, future work in this area should probably start with:

@itemlist[
 @item{who would need to carry new env values}
 @item{whether that would enlarge closure payloads}
 @item{whether enlarging those payloads would outweigh the known-helper deletion win}
]

That is a different kind of work from the earlier
@tt{known0}/@tt{known1}/@tt{known2} experiments, and the current
implementation has reached the point where that distinction matters.
