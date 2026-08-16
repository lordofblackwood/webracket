# WebRacket Compiler TODO

This document records the next major areas of work for `compiler.rkt` and the
runtime-facing compiler pipeline. It is intentionally written as an engineering
roadmap rather than a loose wish list. Each chapter starts with the prioritized
suggestion as an abstract, then expands the work into motivation, likely
implementation shape, tests, risks, and stop conditions.

The current recommendation is to stop pushing the known-helper closure ABI
frontier for now. The recent measurement work showed that the easy deletion
surface in `known0` and `known1` is mostly exhausted, `known2` is not presently
a clean target, and the remaining environment frontier has closure-payload
consequences rather than being a local lowering tweak. The roadmap below
therefore shifts attention toward areas with clearer correctness or performance
leverage.

## No-Stdlib `parameterize` Status

The current no-stdlib path relies on the parser fallback from commit `2434cca9`.
That fallback repairs the already-expanded `(#%top . parameterize)` shape after
the syntax binding has been lost during top-level expansion. An audit of nearby
surface forms found sibling forms such as `with-handlers`, `let`, `let*`,
`letrec`, `cond`, `and`, `or`, `when`, and `unless` clean on this path, so the
issue presently looks isolated to `parameterize`.

Attempts to override the host `parameterize` binding inside the bootstrap
expansion namespace were not reliable enough to keep. In particular, the
no-stdlib expander continued to resolve `parameterize` to the host
`racket/base` binding and to produce the continuation-mark-based expansion that
WebRacket does not lower on this path. Revisit the source-level fix only when
the bootstrap namespace construction itself is redesigned; until then, keep the
parser fallback and do not broaden it to unrelated forms.

## 1. Finish The Letrec-Bound Abstraction Story

Abstract: Build a principled next pass around `letrec`-bound abstractions,
starting with workload-level measurement of representation modes, patching,
cross-links, value uses, environment payloads, and known-only eligibility.

`letrec` is now the largest closure-related area that still looks
architecturally important but insufficiently isolated. The current compiler has
substantial machinery for `letrec-values`, strongly connected components,
direct-letrec summaries, allocation order, patching decisions, and final-closure
eligibility. That machinery is useful, but it also means that the remaining
optimization opportunities are tied to semantic constraints that ordinary
non-recursive helper work avoided. A `letrec` binding can be referenced before
its final closure object exists, can participate in mutual recursion, can be
captured by nested closures, and can be used as a value in ways that require
procedure identity. Any optimization that pretends these cases are merely
ordinary direct helpers is likely to recreate the kind of leaked-local or layout
assumption failure we saw in the failed `known2` thread.

The first concrete step should be a measurement pass, not a lowering change. Add
or extend a reporting tool that walks the existing closure-converted summaries
and classifies every `letrec`-bound abstraction by representation mode:
ordinary closure-backed, direct self-recursive, direct mutually recursive,
patched shell, final-only allocation, and possible known-only if the binding
were not recursive. The report should also include environment payload size,
whether the helper's free variables are stable in the caller layout, whether the
binding has value uses, whether it is captured by nested closures, whether it
appears in exported or top-level positions, and whether the group has
cross-links. This lets us separate true semantic blockers from implementation
accidents.

The likely compiler locations are the `lower-letrec-values` SCC logic, the
direct-letrec summary code, and the `letrec-values` codegen path. The key design
point is that `letrec` should be handled as a group-level representation
decision, not as independent per-helper known-only eligibility. A mutually
recursive group has one shared correctness problem: how do all members obtain
stable references to each other, and which of those references are values that
must preserve closure identity? A single member looking locally known-only is
not enough if another member captures it as a procedure value or if the group
depends on patchable placeholders.

The measurement output should make it easy to answer a few targeted questions.
How many groups are self-recursive only? How many are mutually recursive but
never escape? How many allocate shells only because of current lowering order?
How often are group members called directly versus passed as values? How many
groups have zero environment payload or only direct caller-sourced payload? How
many would be deletion-producing if the recursive edge could be represented as a
label call rather than a closure value?

Once that data exists, the smallest implementation target is likely not
"known-only letrec" in general. A better first target would be a very narrow
self-recursive helper whose binding has no value use, no nested capture, no
top-level/export identity requirement, no mutual recursion, and no closure
payload. Such a function can often be represented as a direct label with a self
call, while the surrounding program never observes a closure object. The proof
obligation is crisp: every occurrence of the bound identifier must be a direct
call in a context where the callee label is statically known, and no expression
may demand the procedure as a value.

Tests should start with minimal programs. Include self recursion with no free
variables, self recursion with one free variable, mutual recursion that must not
optimize, value use of a recursive binding that must keep a closure, nested
capture of a recursive binding, and a `letrec-values` group with non-procedure
members. Whole-program tests should include `test/test-letrec.rkt`, but the
unit tests need to be small enough that a failed pass dump is readable.

Stop if the first report shows that most opportunities are mutually recursive,
captured, or value-used. Continue only if there is a clean self-recursive or
direct-only subset large enough to justify compiler complexity. Back out any
lowering change immediately if WAT validation shows unknown locals or if a pass
dump reveals environment operands being sourced from lexical names rather than
from an explicit group layout.

### Detailed Direction

The reason this item should remain first is that `letrec` is where several
compiler concerns meet at once. It is not only a closure-allocation problem. It
is also a binding-initialization problem, a procedure-identity problem, a
recursive-call problem, and a layout-stability problem. The recent known-helper
work showed that non-recursive direct helpers can sometimes shed closure
allocation and ordinary closure ABI entries when every use is statically known.
`letrec` asks the same question under harder conditions: can a binding be both
available recursively and still avoid becoming a general procedure value? That
question cannot be answered by looking at one lambda in isolation.

The compiler should therefore treat a `letrec` group as the unit of analysis.
Every binding in the group contributes to the representation decision of the
whole group. A single recursive binding can force placeholders. A single value
use can force procedure identity. A single nested capture can force a stable
closure object even if all direct calls are known. A single non-procedure member
can require a different initialization protocol from procedure shell patching.
This is why a report organized only by helper label would be misleading. The
report needs to show group structure: group size, SCC shape, which members call
which other members, which members escape, and which members are used only in
operator position.

A useful first report would have two layers. The first layer is a group summary.
For each `letrec-values` group, record the number of binding clusters, the
number of bound identifiers, whether every RHS is an abstraction, whether the
dependency graph is acyclic after expansion, whether it contains self edges,
whether it contains mutual edges, and whether any RHS produces multiple values.
The second layer is a per-member summary. For each abstraction member, record
free-variable count, closure payload layout, body layout, direct-call count,
generic value-use count, nested capture count, and current lowering mode. This
two-layer shape makes it possible to ask whether a group is blocked by one bad
member or whether the whole group is inherently recursive and closure-backed.

The best initial output format is not a wall of raw labels. It should include
aggregate counts first, then representative examples per bucket. The aggregate
counts answer whether there is enough surface area to justify work. The examples
answer whether the bucket is real or an artifact of conservative classification.
For example, a bucket named `self-only-zero-env-no-value-use` would be a strong
candidate for a first lowering experiment. A bucket named
`mutual-value-used-nested-capture` would be a clear "do not touch yet" bucket.

The first implementation milestone after measurement should be an assertion-only
mode. Before changing generated WAT, add checks that restate the current
compiler's understanding of `letrec` groups. If a binding is classified as
direct-recursive, every direct recursive call should be explainable from the
group graph. If a binding is closure-backed because of value use, the value use
should be visible in the summary. If a group uses patching, the patching order
should be consistent with the SCC order. These assertions will flush out cases
where the summaries are descriptive but not authoritative.

Only after the assertions are stable should lowering change. The narrowest
possible lowering is a non-exported, self-recursive, zero-env, fixed-arity
procedure whose binding is never used as a value. In that case, the recursive
edge can be represented as a direct label call. The compiler can avoid creating
a closure object only if every reference to the binding is a direct call or is
inside the helper body as a self call. The group must not need a placeholder
visible to arbitrary value expressions. If the program can evaluate the binding
itself, compare it with `eq?`, pass it to another function, store it in a data
structure, or capture it in a nested closure, the optimization should not fire.

The next widening, if the first step succeeds, is self-recursive with carried
environment. This is already more dangerous. A self-recursive helper that needs
an outer variable must receive that value consistently on every entry, including
the recursive entry. The recursive call can either pass the environment operand
again or rely on it being available in the callee's body layout. The compiler
must not source the environment from a lexical name that is not in scope in the
generated WAT. This is exactly the class of bug the known2 experiment exposed.
The invariant should say: recursive env operands are explicit operands or
explicitly carried body-layout values, never implicit free references.

Mutual recursion should be a later project. Even when no member escapes, mutual
recursion creates multiple labels with cyclic calls and possibly shared
environment requirements. The group may need a common environment layout, or
each member may need its own carried environment. If member `f` calls member
`g`, and `g` needs `x`, then either `f` must carry `x` or the call edge must have
another stable source for `x`. This is Shivers-style extended environment
analysis applied to a recursive group. It is doable, but it should not be mixed
with the first self-only lowering.

Multiple-value `letrec-values` should also remain separate from known-only
letrec optimization. A group that binds several names from one RHS has an
initialization shape that is different from a single recursive procedure. If the
RHS returns multiple values, the compiler must check arity and bind each result.
If one result is a procedure and another is a data value, shell allocation and
patching cannot be treated uniformly. This is why chapter 3 is its own
correctness project.

The testing discipline should be deliberately repetitive. For each candidate
lowering, write one test that should optimize and several nearby tests that must
not optimize. For self recursion, include factorial or a countdown helper that
is only called directly. Then add variants where the helper is returned, stored
in a pair, passed to `map` or another higher-order primitive, captured by a
nested lambda, exported, or mutually recursive. The optimized case should still
produce correct output, and the non-optimized cases should still produce
closures and pass generic procedure calls.

The metrics should include both performance and deletion. Count closure
allocations removed, closure code labels removed, patchable shell allocations
removed, direct calls introduced, and WAT bytes changed. Compile time should be
tracked separately, because `letrec` analysis can easily become graph-heavy.
If the report shows only a handful of candidates and the implementation adds
complex group-level machinery, the tradeoff is bad. If the report shows many
self-only zero-env helpers, the first lowering could be high leverage.

The design should also preserve the current small-inline closure work.
`$Closure1`, `$Closure2`, and `$Closure3` remain valuable for closure-backed
values. A letrec-bound abstraction that still needs closure identity should flow
through those representations when applicable. Known-only letrec work should not
try to mutate closure-backed layout just to chase a direct-call optimization.
The distinction is simple: if a closure value exists, optimize its payload with
the existing closure family; if no closure value exists, use a separate
known-only/direct representation.

The durable outcome of this project should be confidence. After the report and
assertions land, a developer should be able to look at any `letrec` helper and
say why it is closure-backed, direct-only, shell-patched, or not yet supported.
That clarity is worth landing even before a single closure allocation is
removed.

### First Patch Checklist

The first patch should add only a report and no lowering. It should have a
short, reviewable entry point such as `tools/measure-letrec-abstractions.rkt`
or an extension to an existing measurement script. The output should begin with
aggregate counts, then print representative groups for each blocker bucket. A
reviewer should be able to run it on `test/test-letrec.rkt`,
`test/test-basics.rkt`, and `examples/pict/pict.rkt` without reading generated
WAT.

The report should include at least these columns: group id, member labels,
group size, SCC kind, self-edge count, cross-edge count, value-use present,
nested-capture present, env payload size per member, current representation
mode, and hypothetical direct-only blocker. If any of these facts are not
available from existing summaries, the patch should expose that as an explicit
`unknown` bucket rather than inventing a guess.

The review question for this first patch is simple: does the report classify
the current world accurately? It should not argue that an optimization is safe
yet. It should make future arguments possible. Land it if it improves
visibility and keeps all existing tests green. Do not land it if it needs broad
compiler rewrites merely to print the first set of facts.

## 2. Reduce `$Args` Allocation For Fixed-Arity Calls

Abstract: Measure and then reduce avoidable `$Args` allocation in fixed-arity
call paths, especially direct, known, self, and closed calls where argument
vectors are currently runtime baggage rather than semantic necessity.

The closure work reduced some closure-object and code-size overhead, but many
calls still flow through the Racket argument-vector model. That model is
semantically important for generic procedure application, arity dispatch, rest
arguments, `case-lambda`, and runtime error reporting. It is not obviously
necessary for every statically known fixed-arity call. If a call site knows the
callee label and exact arity, and the callee body can receive values directly,
then allocating a `$Args` object just to immediately unpack it is pure overhead.
This is likely a stronger next performance frontier than adding more closure
payload arities or widening known-helper ABI families without a clear deletion
surface.

The first phase should be analysis-only. Add a report that counts `$Args`
allocation sites by call category: generic application, closed application,
direct helper call, self call, known0, known1, case-lambda arm, primitive call,
and any special runtime invoker. For each bucket, record arity, rest-argument
presence, whether the callee expects an argument vector, and whether the call is
inside a hot-looking workload such as `examples/pict/pict.rkt`. The report
should distinguish mandatory `$Args` allocations from suspicious ones. Mandatory
cases include unknown procedure calls and cases where the runtime must perform
arity dispatch. Suspicious cases include direct known labels with fixed arity and
no rest parameters.

After measurement, define an internal direct-call ABI for fixed-arity helpers
that is independent from the closure ABI question. The goal is not to remove
procedure identity; it is to avoid allocating the temporary argument vector when
the compiler is already emitting a statically known call. This ABI should be
introduced beside the existing paths, with strict eligibility checks. A helper
can use the direct value ABI only when all direct callers agree on the fixed
arity, the helper has no rest parameter, the call is not going through generic
apply, and the body lowering can bind formals from direct operands rather than
from `$Args`.

The implementation should be staged. First, teach the reporting code to name
candidate call sites. Second, add assertions that the current known/direct paths
have coherent arity metadata. Third, introduce a direct fixed-arity label for a
very small zero-env subset, but keep the existing closure-compatible label
unchanged. Fourth, switch only direct calls that already bypass closure identity
to the new label. Only after benchmarks prove value should the compiler expand
the subset to known1 or self-call cases.

Tests should include simple fixed-arity lambdas, wrong-arity calls that must
still report correctly, rest-argument procedures that must not optimize, generic
application through a variable, direct nested helper calls, and case-lambda
dispatch. It is especially important to keep wrong-arity behavior visible,
because removing `$Args` allocation must not accidentally remove the place where
arity errors are checked.

The main risk is duplicating too much ABI surface. We do not want another
transition where every helper receives a closure ABI label plus several sibling
labels whose code-size cost cancels the runtime win. The gate should therefore
be stricter than "can compile": the new path should either remove an allocation
at a call site or remove enough unpacking code to show up in WAT size. If the
report shows that most fixed-arity calls already avoid `$Args`, stop. If the
first implementation improves small benchmarks but worsens `pict` compile time
substantially, pause and add a profitability gate before widening.

### Detailed Direction

This item is intentionally framed around `$Args`, not around closures. The
known-helper work has already taught us that closure representation changes are
easy to make locally plausible and hard to prove globally profitable. Argument
vector allocation is a different axis. A program can still have ordinary
closure-backed procedures and still avoid temporary `$Args` objects at call
sites where the callee, arity, and operands are statically known. That makes
this a promising next performance frontier because it can be staged around call
lowering without immediately changing procedure identity.

The first question is measurement. The compiler should know how many `$Args`
objects it emits and why. A report should count allocations by syntactic call
category after application categorization and closure conversion. Useful buckets
include generic unknown-procedure application, closed application to a known
closure value, direct helper call, self call, known0, known1, case-lambda arm,
primitive call, and runtime helper call. For each bucket, record the source
arity, whether the callee accepts rest arguments, whether the callee is
case-lambda, whether the callee's body immediately unpacks `$Args`, and whether
the call is known to be wrong-arity checked somewhere else.

This report should also count allocation shape. A call with zero arguments may
allocate an empty args object. A call with one or two arguments may allocate a
small array-like payload. A call with many arguments may allocate a larger
vector. These cases have different payoff. Removing a zero-argument allocation
may improve WAT size but little runtime allocation pressure. Removing a
multi-argument allocation may have more runtime payoff. Conversely, adding a
new sibling label to remove a rare one-argument allocation may increase WAT
size. The report should therefore include both count and estimated bytes.

The direct-value ABI should be introduced as an internal call convention, not as
a replacement for the closure ABI. A closure-compatible procedure can continue
to have an entry that accepts `(clos, args)` for generic use, while a direct
call-only sibling can accept ordinary operands when profitable. But this must be
guarded by a transition-tax rule. If adding the sibling label costs more WAT
than the removed `$Args` allocation code, the optimization should not fire. In
other words, the compiler should not repeat the known2 problem in a new form.

There are two possible implementation styles. The first is callee cloning: emit
a direct fixed-arity label in addition to the ordinary label, and lower eligible
call sites to it. The second is callee specialization: for known-only helpers
that already have no ordinary closure entry, make their sole label use direct
operands. Callee cloning is safer because it preserves generic behavior, but it
can add code size. Callee specialization is leaner but only applies to helpers
whose value identity is already gone. The first experiment should probably use
the second style for existing known-only helpers, because those helpers already
live in an internal ABI family and do not need a closure-compatible entry.

The key invariant is that arity checking remains correct. In the closure ABI,
arity checks may happen in the closure code, in an invoker, or through `$Args`
metadata. If a direct fixed-arity path bypasses that machinery, the compiler
must prove that the call is arity-correct statically. That proof is usually
available for direct calls emitted from the compiler: the number of operands is
known, and the callee's formal count is known. It is not available for generic
apply, calls through variables, or calls that depend on runtime case-lambda
dispatch. Those must continue to use the generic path.

Rest arguments should be excluded at first. A rest-argument procedure does not
merely receive N operands; it receives some fixed operands plus a list of the
remaining arguments. The direct path could build that list directly, but that is
a separate optimization. For the first phase, fixed arity means no rest
parameter and no optional dispatch. Case-lambda should also be excluded except
for already selected internal case arms. A case arm that has been chosen by
compile-time dispatch can be treated like a fixed-arity helper; a general
case-lambda procedure cannot.

The callee body lowering needs its own boundary. Today, many converted bodies
expect an argument object and use helper code to extract formals. A direct-value
body should bind formals from function parameters instead. That means there are
two related but distinct changes: changing the call site to pass direct operands
and changing the label body to receive them. The first implementation should
avoid touching arbitrary converted bodies. Instead, target labels whose body
lowering is already isolated by known-helper ABI work. This keeps the change
small and makes the proof obligations more familiar.

Wrong-arity errors need special attention. A statically correct direct call does
not need a runtime arity check for that call, but the same procedure may still
be called generically elsewhere. The ordinary closure entry must keep its arity
behavior. Tests should therefore include a procedure that is called directly in
one place and incorrectly through a value path in another. The direct path
should run without allocating `$Args`; the generic path should still report a
wrong-arity error.

The measurement script should have a "deletion-producing" lens. It should not
only ask "could this call use a direct ABI?" It should ask "would this remove an
allocation without adding a new label?" Existing known-only helpers are strong
candidates because they already avoid the ordinary closure entry. Existing
sibling known0/known1 helpers are weaker candidates because adding another
sibling may inflate code. Generic closure-backed procedures are weakest unless a
single new direct label serves many call sites.

Compile-time impact must be tracked from the start. The unary carried-layout
experiment was correct and still not cost-effective because compile time moved
the wrong way. A direct `$Args` optimization could have the same failure mode if
it requires expensive per-call profitability analysis or if it emits many extra
labels. The analysis should be mostly table-driven from summaries the compiler
already computes. If the first report requires building a new global fixpoint,
that is a warning sign.

This project also interacts with primitive inlining. A primitive call that
currently builds `$Args` only to call a fixed primitive should probably be
handled by primitive metadata and inline lowering rather than by the direct
helper ABI. The `$Args` report should therefore separate user helper calls from
primitive calls. If primitive calls dominate, chapter 8 may be a better next
implementation target.

The runtime should not need large changes for the first phase. `$Args` remains
the representation for generic procedure calls. Invokers remain available.
Closure-compatible labels remain valid. The new path is a compiler-only fast
path for statically known calls. That is the attractive part of this project:
it can produce runtime allocation wins without requiring a new procedure object
representation.

Stop conditions should be strict. Stop if the measurement report shows that
eligible `$Args` allocations are rare. Stop if the first direct-label experiment
adds more WAT than it removes. Stop if wrong-arity behavior becomes ambiguous.
Stop if the implementation starts depending on implicit lexical free variables.
Continue only when the path removes allocation at known call sites and keeps
the ordinary closure/apply semantics intact.

### First Patch Checklist

The first patch should count `$Args` allocation sites without changing codegen.
It should report call category, arity, rest/case-lambda status, whether the
callee is statically known, and whether the allocation appears mandatory. The
script should also include a "possible deletion without new label" bucket,
because that is the safest opportunity class.

The output should make transition tax visible. A candidate that requires a new
sibling label should not be mixed with a candidate that can reuse an existing
known-only label. The report should separate "removes allocation only,"
"requires callee clone," and "requires body ABI change." This prevents the next
implementation thread from treating all fixed-arity calls as equally cheap.

The patch should include no new ABI and no runtime changes. Success is a table
that tells us whether the project is worth pursuing. If most allocations are
generic apply or rest/case-lambda calls, stop. If known-only fixed-arity calls
show a real allocation count, the next patch can target that narrow subset.

### Review Cadence

Review this project after every measurement or ABI patch, not after a long
series of changes. The key numbers are allocation sites removed, labels added,
WAT bytes changed, compile time, and wrong-arity test coverage. If a patch adds
a direct ABI but does not remove allocation in the same narrow bucket, treat it
as infrastructure and require a follow-up measurement before widening. This
keeps the work honest: the goal is fewer unnecessary argument objects, not a
larger family of clever call conventions.

One open question is whether `$Args` removal should be controlled by a global
compiler flag during the first implementation. A flag would make benchmarking
and rollback easier, especially if the first direct-value path is correct but
has workload-dependent payoff. The flag should be temporary, but it can keep
the first patch safe.

## 3. Support Multiple Values In `letrec-values` Codegen

Abstract: Close the explicit `letrec-values` multiple-value codegen gap so the
compiler handles a larger, semantically central part of Racket without tripping
over an implementation error path.

This is the most correctness-oriented item on the list. The compiler already
has a `letrec-values` path, but codegen still contains an explicit unsupported
case for multiple values. Racket's `letrec-values` is not an obscure corner of
the language; it is part of the core binding model used by macros and compiler
expansions. Leaving a hard failure here means otherwise valid programs can make
it through earlier passes and then fail late in code generation. It also limits
future optimization work, because recursive groups with multiple produced values
cannot be analyzed or transformed confidently if the backend cannot represent
them.

The first step is to write tiny repro tests that document the current failure.
Use minimal programs with a single `letrec-values` binding that returns multiple
values, a group with two names bound by one RHS, a recursive procedure paired
with a non-procedure value, and a case where the number of produced values does
not match the number of bound identifiers. Keep these tests separate from large
stdlib workloads so failures point directly at the missing lowering.

Conceptually, the codegen needs a representation for the initialization protocol
of a recursive group whose RHS can produce multiple values. In ordinary
`let-values`, this is a destructuring problem: evaluate the RHS, receive N
values, bind them to N identifiers. In `letrec-values`, it is also a
backpatching problem: identifiers may be visible recursively while the group is
being initialized. The compiler must preserve Racket's rules about use before
initialization and arity mismatch. The exact runtime support depends on the
current value-return convention, but the implementation should not silently
collapse multiple values into a vector or list unless that is already the
compiler's official multiple-value representation. That kind of workaround would
break Racket semantics.

A safe plan is to first handle the non-recursive-looking subset inside
`letrec-values`: groups where no RHS refers to the bound identifiers. Such cases
can often lower similarly to `let-values` after SCC analysis proves no recursive
edge. Then handle procedure-only recursive groups that already use the existing
closure shell machinery. Finally, consider mixed procedure and non-procedure
groups. The mixed case is likely the tricky one, because a closure shell can be
patched later, but an arbitrary value binding may need a different placeholder
or initialization state.

Assertions should make the protocol explicit. The number of values produced by
each RHS must match the number of identifiers in its binding cluster. Every
recursive reference must either point to a valid placeholder with checked
initialization semantics or be rejected earlier. Codegen must not create
uninitialized non-defaultable locals. Branches that handle arity mismatch should
leave the stack balanced. If the compiler has a uniform multiple-value return
object or calling convention, the `letrec-values` path should use it rather than
inventing a local convention.

Tests should cover success and failure. Success cases should include mutually
recursive procedures, multiple names from one RHS, and interaction with direct
calls. Failure cases should include wrong number of values and reading a
recursive variable too early if the language surface can express it. Once
minimal tests pass, add one or two expanded-code examples that previously
failed in real workloads.

Stop if the implementation starts requiring broad changes to closure
conversion, value representation, and runtime multiple-value support all at
once. That is a sign to split the project. Continue if the first milestone can
turn the explicit codegen error into a passing narrow subset with clear
fallbacks for unsupported mixed groups.

### Detailed Direction

This chapter is different from the closure and `$Args` chapters because its
primary value is semantic coverage. Optimizations are useful only if the
compiler accepts the programs that Racket programmers expect to write. A hard
failure in `letrec-values` multiple-value codegen means the compiler can reject
valid expanded programs after spending many passes transforming them. That kind
of late failure is costly for users and for compiler developers, because the
error appears far away from the original source construct.

The work should begin by separating three concepts that are easy to conflate:
multiple-value production, recursive binding visibility, and procedure shell
allocation. `let-values` needs to destructure multiple results. `letrec-values`
needs to make names visible throughout the group while also destructuring
results. Recursive procedures may additionally need placeholder closures or
patching. A robust implementation should not assume that every
`letrec-values` group is a set of single-valued lambdas, because Racket's
expanded language does not make that guarantee.

The first analysis pass should report every `letrec-values` shape that reaches
codegen. For each binding clause, record the number of bound identifiers,
whether the RHS is a lambda, case-lambda, value expression, primitive call, or
multiple-value expression, whether the RHS references any names from the group,
and whether the clause participates in an SCC. The report should distinguish a
multi-name binding from a multi-clause group. A group with two clauses that each
bind one name is different from one clause that binds two names from one RHS.

From that report, define implementation strata. Stratum one is non-recursive
multi-name binding inside a `letrec-values` form. If SCC analysis proves the RHS
does not depend on the bound names, this can often be lowered like
`let-values`, while preserving the surrounding form's behavior. Stratum two is
recursive procedure-only groups where each RHS returns exactly one procedure.
That is closest to the current machinery and may already work for many cases.
Stratum three is mixed recursive groups with data values and procedures.
Stratum four is a recursive RHS that itself returns multiple values. Each
stratum has different proof obligations.

The compiler needs one authoritative multiple-value convention. Before adding a
special path for `letrec-values`, identify how ordinary multiple values are
represented in the compiler and runtime. Are they returned through a special
runtime object? Are they represented on the Wasm stack in limited cases? Is
there a `$Values` structure? Is arity checking performed by the caller? The
`letrec-values` implementation should reuse that convention. If the convention
is incomplete, the first project may need to be "document and stabilize
multiple-value return convention" rather than "finish all letrec-values."

Arity mismatch is not optional. If an RHS produces the wrong number of values,
Racket raises an error. A compiler that silently takes the first value, drops
extra values, fills missing values with `void`, or boxes all values into a
vector would be incorrect. The lowering should make the arity check visible in
the generated code or prove that the producer is statically exact. For example,
an RHS that is syntactically `(values a b)` for two bound names can be treated
as exact after simplification. An arbitrary function call returning two values
requires runtime checking unless the compiler has summary information for it.

Recursive visibility is the harder semantic point. In a `letrec-values` group,
the bound identifiers are in scope within the RHS expressions, but using a
binding before it is initialized can be an error depending on the form and
execution path. Procedure recursion is the common case because the procedure
body is not executed during initialization. Data recursion is much trickier.
For example, a value RHS that immediately reads another group member may require
an uninitialized-binding check. The compiler should not solve all of this
implicitly while adding multiple-value destructuring. It should classify which
cases it supports and reject or preserve checks for the rest.

A safe representation strategy is to allocate initialization cells for group
members that cannot be bound directly. Each cell can start in an uninitialized
state, then be filled after RHS evaluation succeeds. Reads from the cell check
initialization. Procedure shells are a specialized version of this idea for
closures; arbitrary values may need a more general cell. If such cells already
exist in the runtime or compiler for assignment conversion, reuse them if the
semantics match. Do not use mutable boxes as an invisible workaround unless
their identity and mutation behavior cannot be observed incorrectly.

For the first implementation, prefer static exact cases. A binding like
`(letrec-values ([(x y) (values 1 2)]) body)` does not require a general
multiple-value runtime if the simplifier preserves enough structure to bind
`x` and `y` directly. A binding where the RHS is a known fixed-values primitive
could also be handled statically. This would turn some hard failures into
successes without solving every dynamic multiple-value case. The code should
still leave a clear error for unsupported dynamic producers.

However, avoid over-specializing too deeply. If the compiler accumulates a
large set of ad hoc RHS recognizers, it will become fragile. The better path is
to expose a small internal representation for "this expression produces exactly
N values" and let earlier passes annotate or preserve it. Then `let-values` and
`letrec-values` can consume the same fact. That is a more durable design than
teaching `letrec-values` about every expression form separately.

Tests should be written before implementation. Start with a file dedicated to
multiple-value binding if one does not already exist. Include exact static
success, dynamic success if supported, wrong-count failure, recursive procedure
plus data, mutual recursive procedures in a multi-clause group, and a group that
must remain unsupported with a clear error. Use `--dump-passes-limit` on the
small failures to ensure the pass shape is understandable.

The codegen should respect WebAssembly stack discipline. Multiple-value
destructuring often tempts one to leave temporary values on the stack across
branches. That is risky in folded WAT. Prefer explicit locals for intermediate
results, initialized before use. Follow the project rule about avoiding
uninitialized non-defaultable locals: validate first, fail on mismatch, then
assign and proceed. Branches handling success and failure must leave compatible
stack shapes.

This project has a useful interaction with error reporting. A good
`letrec-values` implementation should produce meaningful errors for wrong value
counts and unsupported recursive shapes. If the compiler currently emits a
generic codegen error, replace it with a phase-specific message that names the
binding shape. This supports chapter 9 even if full dynamic multiple values are
deferred.

The runtime impact should be minimized initially. If existing multiple-value
support is sufficient, do not add new runtime structures. If runtime support is
missing, add the smallest general primitive needed for multiple-value arity
checking and extraction. Avoid adding a `letrec-values`-specific runtime helper
unless the initialization protocol truly needs it; special helpers tend to hide
semantics that should be visible in the compiler's binding model.

Success for this chapter comes in tiers. Tier one: the compiler reports all
remaining unsupported `letrec-values` shapes clearly. Tier two: static exact
multi-name bindings work. Tier three: dynamic producers with runtime arity
checks work. Tier four: mixed recursive groups are handled correctly. It is
acceptable to land tier one or two without the rest. What matters is that the
unsupported area becomes explicit and smaller, rather than remaining a late
codegen trap.

### First Patch Checklist

The first patch should be diagnostic and test-driven. Add minimal failing tests
that show the current unsupported multiple-value `letrec-values` shapes, then
change the compiler only enough to produce precise errors for unsupported
cases. This converts an opaque late failure into a documented limitation and
creates a stable target for later implementation.

The diagnostic should print the number of identifiers in the binding cluster,
whether the RHS is statically known to produce that many values, and whether
the binding is recursive. If the compiler can already identify static
`(values ...)` producers, the patch may include a report of how often they
appear, but it should not lower them yet unless the change is truly local.

The review question is whether the compiler now knows what it is rejecting.
If a future implementation patch can point at one diagnostic bucket and say
"this bucket is now supported," the first patch succeeded. If the first patch
starts redesigning multiple-value representation, it is too large.

### Review Cadence

Review this project one semantic stratum at a time. Do not combine static
multi-name destructuring, dynamic multiple-value arity checks, recursive
procedure groups, and mixed data/procedure groups in one patch. Each stratum
should add tests that fail before the patch and pass after it, plus nearby
tests that remain rejected if still unsupported. This gives the compiler a
ratchet: every landed step either supports a clear shape or reports it better.

## 4. Implement Or Lower `wcm` Correctly

Abstract: Decide and implement the compiler story for continuation marks and
`wcm`, either by supporting the necessary runtime representation or by lowering
only a verified subset with explicit semantics.

The compiler currently has a visible hard edge around `wcm`. Continuation marks
are not incidental in Racket; they are used for dynamic context, debugging,
profiling, stack inspection, exception context, and libraries that depend on
parameterization-like behavior. WebRacket may not need the entire Racket
continuation-mark system immediately, but leaving the compiler with a TODO or
error path means expanded programs can fail in non-obvious ways. This item is
therefore partly correctness work and partly a design decision about the runtime
surface WebRacket intends to support.

The first task is semantic scoping. Identify how `wcm` appears in the compiler's
intermediate language, which source forms produce it, and whether current
stdlib examples depend on observable continuation mark behavior or merely pass
through forms that could be erased safely. This distinction matters. If marks
are never inspected, a narrow erasure might be sound for some workloads, but it
must not be presented as full support. If marks are inspected by primitives or
runtime APIs, then erasure is a semantic bug.

A minimal implementation needs a representation for the current continuation
mark set. In a Wasm-GC runtime without full continuations, this can often be a
dynamically scoped stack of mark frames maintained explicitly by compiled code.
Entering a `wcm` pushes or installs a key/value binding, evaluates the body, and
restores the previous mark state on every exit path. The hard part is not the
happy path; it is preserving restoration across errors, early returns, and any
control effects WebRacket supports. If exceptions or continuation capture are
limited, the implementation can be correspondingly simpler, but the limitation
must be explicit.

The compiler should start by adding an analysis report for `wcm` occurrence.
Count occurrences in standard workloads and classify them by whether there is
any mark inspection. Then write minimal tests that use `with-continuation-mark`
or the lowered form directly, including nested marks with the same key, nested
marks with different keys, body result preservation, and interaction with
function calls. If mark inspection is not implemented, tests should document the
chosen unsupported behavior rather than letting it fail accidentally.

Implementation should be isolated. Add runtime helpers for pushing/restoring
mark frames and retrieving marks only if retrieval is in scope. In codegen,
lower `wcm` to a structured sequence that saves the old mark state, installs the
new one, evaluates the body, restores the old state, and returns the body value.
Avoid using raw locals in a way that could trigger uninitialized local failures.
Because Wasm structured control flow requires stack discipline, every branch of
the lowering must have matching result behavior.

The risk is overcommitting to a continuation-mark model that later blocks
exceptions, parameters, or true continuations. The mitigation is to document the
runtime invariant now: are marks a simple dynamic stack for the current
single-shot execution model, or are they part of a future continuation object?
If the latter, the representation should be designed with capture/restore in
mind even if capture is not implemented yet.

Stop if a correct implementation requires solving full continuations first.
Continue if workload measurement shows limited usage and a dynamic-stack model
can satisfy current semantics cleanly. Do not silently erase `wcm` in general;
that would create the kind of semantic workaround the project guidelines
explicitly warn against.

### Detailed Direction

The `wcm` item should be approached as a semantic design project before it is
treated as a codegen TODO. Continuation marks are one of those Racket features
that can look like metadata until a program observes them. Once observed, they
are part of dynamic extent and control behavior. A compiler that erases them
may appear to work for examples that never inspect marks, then fail subtly in
libraries that use marks for context, debugging, or parameters. WebRacket does
not need to implement the entire Racket control tower in one step, but it does
need to be explicit about which part of the tower it supports.

The first practical question is occurrence. Add a small report that counts
lowered `wcm` forms in representative workloads. For each occurrence, record
whether the key is statically recognizable, whether the body is simple or may
call arbitrary code, whether mark lookup primitives appear in the same program,
and whether the form is generated by common expansion patterns. If `wcm` forms
occur frequently but mark inspection never occurs, the first milestone might be
diagnostic and conservative. If inspection occurs, runtime support becomes more
urgent.

The report should also identify surrounding control constructs. A `wcm` around
a straight-line expression is much easier than a `wcm` whose body can raise an
exception, invoke a continuation, or perform non-local exit. Even if full
continuations are not supported, errors and runtime traps still matter because
the mark stack must be restored on normal exits and should not corrupt later
execution after handled errors. The current runtime's exception model should be
reviewed before committing to a mark representation.

A minimal semantic model for WebRacket could be a dynamic mark stack stored in a
runtime global. Each frame contains a key, a value, and a link to the previous
frame or previous mark set. Entering `wcm` evaluates the key and value, saves
the current mark stack, installs the new binding, evaluates the body, then
restores the saved stack. Lookup walks the stack from most recent to oldest and
returns values matching the requested key according to Racket's equality rules
for continuation mark keys. This model is straightforward for normal
single-shot execution.

The subtlety is restoration. In source languages with `try/finally`, this is
the classic use of a finally block. In Wasm structured control flow, WebRacket
needs an explicit lowering pattern that guarantees restoration for every normal
branch leaving the body. If the body is compiled as an expression with one
result, the lowering can store the result in a local, restore the old mark
stack, then return the local. If the body has multiple values, the pattern must
follow the multiple-value convention. If the body can trap or raise an exception
that unwinds past the restoration code, runtime exception integration is needed.

This suggests an incremental support matrix. The first milestone can support
`wcm` only for normal expression evaluation if the program does not use
exceptions or first-class continuations. The compiler should document that
limitation. The second milestone can integrate with WebRacket's exception
mechanism if one exists. The third milestone can consider continuation capture,
where the mark stack is no longer just a global dynamic stack but part of the
captured continuation state. That third milestone should not be smuggled into
the first implementation.

The key/value evaluation order must match Racket. If the surface form evaluates
the key, then the value, then the body, the generated code must preserve that
order and any side effects. If key or value evaluation fails, the mark should
not be installed. If body evaluation fails under a supported exception model,
the old mark state should be restored as the dynamic extent exits. These are
small details, but they are exactly where semantic bugs hide.

The runtime representation should be simple and typed. A `$ContinuationMark`
structure could hold key, value, and previous frame as `(ref null
$ContinuationMark)` or an equivalent nullable reference. A global current mark
frame can represent the stack. If marks are grouped by continuation frame later,
the representation may need a mark-set object rather than a single linked list.
For the first phase, choose the representation that matches current control
support while leaving a migration path.

Lookup semantics should not be guessed. Racket's continuation mark APIs can
return the first value for a key, a list of marks, or a continuation mark set
depending on the primitive. WebRacket should implement only the primitives it
claims to support. If only internal `wcm` is lowered but no public lookup
primitive exists, then the runtime can carry marks for future use but tests
should not claim full API compatibility. If lookup primitives are exported,
tests must cover nested marks and shadowing.

The compiler lowering should avoid implicit temporaries. For a single-value
body, a safe pattern is: evaluate key into a local, evaluate value into a local,
save old mark stack into a local, install new mark, evaluate body into a result
local, restore old mark, then leave the result. This follows the project's
validate-first and initialized-local discipline. For a body that returns void,
the same pattern applies without a result value. For multiple values, defer
until the multiple-value convention is clear.

Tests should be divided by semantic layer. Basic tests should show that a mark
does not affect the body result. Lookup tests should show nearest mark wins,
outer marks reappear after leaving an inner mark, different keys do not
interfere, and nested function calls can see dynamically installed marks if the
API says they should. Error tests should show that unsupported control behavior
fails clearly rather than corrupting the mark stack.

This chapter also has a documentation component. If WebRacket implements a
subset of continuation marks, the limitation should be documented near the
runtime helper and in a user-facing note if such notes exist. Developers should
not have to infer from codegen that continuation capture is unsupported or that
mark restoration only applies on normal return.

The risk is architectural lock-in. A global linked stack is easy, but if
WebRacket later implements full continuations, the current mark state must be
capturable and restorable as part of continuation objects. If that future is
likely, represent the current mark stack as a value that can be saved, not as
unstructured mutable state scattered across runtime helpers. Even if the global
stores the current pointer, the pointer itself can be treated as continuation
state.

The stop condition is clear: if correct restoration requires exception or
continuation machinery that does not exist, do not fake it. Land occurrence
measurement and early diagnostics first. If a normal-return-only implementation
is useful for current workloads, gate it behind documented assumptions. The
worst outcome would be silent erasure or a partial implementation that appears
correct until a library inspects marks.

### First Patch Checklist

The first patch should answer how often `wcm` appears and whether it is
observed. Add an occurrence report that counts `wcm` forms, continuation-mark
lookup primitives, surrounding control constructs, and representative source or
expanded contexts. It should be possible to run the report on the standard
workloads without enabling a new runtime feature.

The same patch can improve the current unsupported error. If codegen reaches a
`wcm` form, the error should say whether WebRacket currently lacks mark runtime
support, mark lookup support, or restoration support for the relevant control
shape. This is much better than a generic TODO.

Do not implement a mark stack in the first patch. The measurement should tell
us whether a normal-return-only model is enough for current programs. If lookup
primitives appear, the next design must include observable semantics from the
start. If no lookup appears, a documented preservation or erasure strategy can
be discussed explicitly.

### Review Cadence

Review `wcm` work through a semantic support matrix. The matrix should have
rows for normal return, nested marks, mark lookup, exceptions, multiple values,
and continuation capture. A patch should say which rows it supports and which
rows remain rejected. This prevents accidental claims of full continuation-mark
support. It also gives reviewers a simple question: does the implementation
restore dynamic state for every supported exit path? If the answer is unclear,
the patch is not ready.

One open question is how much continuation-mark behavior current WebRacket
programs actually observe. If marks are present only because expansion inserts
them and no lookup API is available, the immediate priority is clear
diagnostics and preservation of future options. If programs already call mark
lookup primitives, then `wcm` becomes a runtime semantics project rather than a
codegen cleanup. The measurement phase should settle this before any lowering
choice is made.

Another useful review question is whether `wcm` should be tested first through
expanded core forms or source-level Racket forms. Source-level tests are better
for user semantics, but expanded-core tests may isolate the lowering. Ideally
the first test pair includes both: one tiny lowered-form case for compiler
debugging and one source-level case for confidence that expansion still reaches
the expected construct.

## 5. Clean Up Module, Require, Provide, And Syntax Binding Handling

Abstract: Make the module boundary story more explicit by tightening handling
of `require`, `provide`, top-level definitions, and `define-syntaxes`, reducing
late codegen surprises from partially supported expanded forms.

The compiler has accumulated several TODOs around module forms, require/provide
handling, top-level definitions, and syntax-related bindings. This is expected
in a compiler that began by targeting a core expanded language, but it becomes
more painful as WebRacket compiles larger programs. The danger is not just that
some forms are unsupported. The danger is that unsupported or partially
understood module forms can leak through multiple passes, acquire misleading
intermediate representations, and fail late with an error that does not explain
the source-level limitation.

The goal of this project is to turn module-boundary behavior into an explicit
contract. Which module forms are accepted? Which are erased after expansion?
Which are compile-time-only and should never reach runtime codegen? Which
require forms are supported only because the current driver supplies the
stdlib? Which provide forms matter for generated exports? Which top-level
definitions need stable identity? These questions intersect with closure work
because exported procedures and top-level values have stronger identity and
entry-point constraints than internal direct helpers.

The first phase should be an inventory pass. Search the parser, simplifier,
unexpander, and codegen for module-form TODOs and unsupported clauses. For each
one, create a table with the form, current behavior, desired behavior, and a
minimal test. This can become a small `docs/` note or a section in the TODO
roadmap. The important shift is that unsupported forms should be rejected early
with a useful message, while supported compile-time-only forms should be
discarded before runtime lowering.

`define-syntaxes` deserves special attention. In fully expanded Racket code,
many syntax bindings should have done their work before WebRacket sees the
runtime program. If a `define-syntaxes` form remains, the compiler needs to know
whether it is harmless metadata, an unsupported compile-time effect, or an
indication that expansion was incomplete. A late codegen TODO is not the right
place to decide that. The simplifier or earlier module-normalization pass should
classify it and either remove it or fail clearly.

Tests should be organized around boundaries. Include a module with simple
provide of values, a module with imported primitives, a compile-time-only
syntax definition that should not affect runtime, an unsupported require shape
that should fail early, and a top-level exported procedure that must keep
closure identity. The tests should exercise both `--no-stdlib` and normal
stdlib modes where relevant, because module behavior often changes when the
driver preloads support code.

Implementation should avoid a big module-system rewrite. Start by improving
diagnostics and early rejection. Then normalize forms that are already
semantically inert after expansion. Only after that should WebRacket grow new
module capabilities. This keeps the compiler honest: it either supports a form
or says why it cannot.

The biggest risk is accidentally deleting a compile-time form whose runtime
effect is indirect. Another risk is overfitting to currently expanded output and
then breaking when Racket changes expansion shape. The mitigation is to keep
tests at the source level when possible and to make form classifiers conservative
by default. Stop if classification starts depending on fragile printed syntax
rather than stable expanded structure.

### Detailed Direction

The module-boundary work is less glamorous than closure ABI optimization, but
it is one of the places where a compiler starts feeling dependable. Users rarely
think in terms of "the closure converter accepted my lambda." They think in
terms of modules, imports, exports, examples, and libraries. If module forms
are partially supported, failures can appear unrelated to the code the user
wrote. A `require` that is ignored too aggressively may produce an unbound
identifier later. A `provide` that is not represented correctly may hide an
exported procedure from generated JavaScript glue. A leftover
`define-syntaxes` may reach codegen even though it should have been a
compile-time-only concern.

The first conceptual step is to distinguish the compilation modes WebRacket
supports. In `--no-stdlib` mode, the compiler is intentionally given a smaller
world, and programs may rely only on explicitly present primitives and local
bindings. In normal mode, the compiler may preload or compile runtime support
and standard-library fragments. Module handling may legitimately differ between
these modes, but the difference should be intentional. The module report should
therefore include the driver mode when classifying failures.

The compiler should define a normalized internal module shape. Source Racket
has many surface forms, and expanded Racket has its own representation. The
rest of the compiler should not need to understand every module variant.
Instead, an early module-normalization step should translate accepted forms into
a small set of internal declarations: runtime value definition, compile-time
only declaration, import of known primitive/module binding, export of runtime
binding, begin-like sequencing, and unsupported module form. Once normalized,
later passes can operate on runtime definitions and expressions without
rediscovering module semantics.

`require` needs a policy. Some requires may be satisfied by WebRacket's runtime
primitive table. Some may point at modules the compiler can compile. Some may be
compile-time-only and disappear after expansion. Some may be unsupported. The
dangerous behavior is silently accepting an unsupported `require` and then
letting unresolved identifiers fail later. A better behavior is to resolve the
require early into known imports or reject it with the module path and reason.

`provide` also needs a policy. For internal test programs, provide may not
matter if the program is compiled as a whole and run for side effects. For
library-style output, provide controls what names are exported or made visible
to the host. Exported procedures generally need stable closure identity and
closure-compatible entry points. This connects directly to known-only work:
an exported helper should not be made known-only unless the export mechanism
itself provides an equivalent procedure value. The module boundary should feed
an "externally observable" fact into closure conversion.

Top-level definitions deserve similar treatment. A top-level value may be
referenced by generated host glue, by later module code, or by dynamic lookup if
that is supported. The compiler should classify top-level procedures as
identity-sensitive by default unless a whole-program analysis proves otherwise.
This is a conservative stance, but it prevents internal helper optimizations
from accidentally deleting values that a module boundary expects to exist.

`define-syntaxes` should be handled before runtime lowering. In a fully expanded
program, syntax transformers have already run. A remaining `define-syntaxes`
form might be metadata, a compile-time side effect that was not executed, or an
unsupported expansion artifact. The compiler should not treat it as a runtime
definition. The module-normalizer should either drop it with a clear invariant
("compile-time-only form after expansion") or reject it because WebRacket does
not support the required compile-time evaluation. Which choice is correct may
depend on how the input program is produced.

The inventory pass should be mechanical. Search for every branch that mentions
`module`, `require`, `provide`, `define-syntaxes`, `begin-for-syntax`,
`quote-syntax`, and top-level forms. For each branch, write down: accepted
syntax, current action, whether runtime code is emitted, whether bindings are
created, and whether errors are early or late. This table will likely reveal
that some forms are already handled correctly and some are only tolerated
because current workloads do not exercise them.

After the inventory, add a small set of module-boundary tests. One module should
define and provide a value. One should define and provide a procedure. One
should require a known primitive or support module. One should contain a
compile-time syntax definition that should not produce runtime code. One should
use an unsupported require and fail early. One should export a procedure that is
also used internally so closure conversion sees both internal calls and
external identity.

The tests should verify behavior, not just successful compilation. For
provided values, generated output should expose or preserve the expected name
according to WebRacket's module-output model. For unsupported forms, the error
should name the unsupported module form. For syntax definitions, runtime output
should not contain bogus closures or labels for compile-time-only code.

This project should improve diagnostics before adding new module features. If a
form is unsupported, the compiler should say so near the normalization phase.
That alone is a meaningful improvement. Once diagnostics are clear, the team
can choose which unsupported forms to implement based on actual workload needs.
Without that step, there is a temptation to patch individual failures wherever
they surface.

The implementation should avoid requiring the whole compiler to carry syntax
objects everywhere. Module normalization can operate near the front of the
pipeline, preserve source context in a small origin record, and then pass a
simpler representation onward. Later passes should know whether a binding is
top-level/exported/imported, but they do not need the full original module
syntax.

There is a subtle interaction with primitives. Some imported names are really
compiler-known primitives, some are runtime functions, and some are ordinary
module bindings. If primitive metadata is consolidated later, module
normalization should consume that metadata rather than duplicating lists of
primitive names. This argues for a light interface: a resolver function that
answers whether a module import maps to a primitive descriptor, runtime binding,
or unsupported import.

The risk of overfitting is real. Racket expansion output can be complex, and a
normalizer that matches exact printed shapes may break as inputs vary. Prefer
using structural predicates over string matching. Keep tests source-level where
possible so they document user-visible behavior. When pass-level tests are
needed, keep them small and explain why the intermediate shape is stable enough
to rely on.

The stop condition is when module work starts turning into a full separate
module compiler. WebRacket may eventually need that, but the near-term goal is
smaller: make accepted module forms explicit, reject unsupported ones early,
and feed top-level/export identity information into later compiler passes. That
goal is achievable incrementally and will make future feature work less
surprising.

### First Patch Checklist

The first patch should inventory module forms and improve one class of
diagnostics. Add a table, comment block, or small report that lists the module
forms currently recognized by the front end and where unsupported forms are
rejected. Then choose one late failure class, such as leftover
`define-syntaxes` or unsupported `require`, and move it to an earlier, clearer
error.

The patch should not attempt to implement a new module system. It should make
the current module contract visible. If a form is compile-time-only and safe to
drop after expansion, document why. If a form is unsupported, reject it with the
form name and phase. If a form affects exports, record that it should mark the
binding as externally observable.

Success is a smaller surprise radius. A user or developer should learn at the
module boundary what WebRacket cannot compile, rather than discovering it in
closure conversion or codegen. Keep the patch focused enough that source-level
module tests can explain the behavior.

### Review Cadence

Review module work by source-level examples first and expanded-shape details
second. A patch should explain what a user can now write, what still fails, and
where the failure occurs. If the patch changes exported binding identity or
top-level observability, it should also state the effect on closure conversion.
Module cleanup should not quietly make exported procedures eligible for
known-only lowering. Any such interaction needs an explicit test and probably a
separate optimization patch.

One open question is whether WebRacket should eventually compile multiple
modules as separate Wasm units or continue to treat most inputs as whole
programs. The near-term cleanup should not depend on that answer, but it should
avoid closing the door. Recording imports, exports, and externally observable
bindings explicitly will help either future: separate compilation needs that
metadata, and whole-program optimization needs to know when it can ignore it.

Another practical question is how module errors should be surfaced in examples.
If an example depends on an unsupported library form, the right response is not
to rewrite the example around the compiler. The right response is a minimal
repro, a clear unsupported-form error, and then either a compiler fix or an
explicit documented limitation. That keeps compatibility work aligned with the
project's no-workaround policy.

That policy should be visible in review notes whenever module cleanup touches
examples or documentation.

## 6. Improve Quotation And Datum Support

Abstract: Extend quotation conversion for currently unsupported datum shapes,
especially hash-table variants, while preserving immutability, sharing
expectations, and Racket-compatible printed/value behavior.

Quotation looks simple until it becomes a full value-construction subsystem.
Racket quoted data can include symbols, lists, vectors, boxes, strings, bytes,
hash tables, prefab structures, and more depending on the supported language
surface. WebRacket already has conversion machinery, but unsupported hash table
variants and related datum cases still appear in the code. This is a good
correctness project because it expands the class of ordinary Racket programs
that compile without touching the more fragile closure and ABI layers.

The first task is to define the supported quoted datum set precisely. For each
datum kind, decide whether WebRacket should construct it at compile time as a
runtime literal, emit code that builds it at startup, or reject it. Immutable
strings, bytes, vectors, and hashes need careful handling because Racket
programs can observe mutability. A quoted mutable value should not accidentally
become mutable just because the runtime constructor defaults that way. Likewise,
equal hash, eq hash, and eqv hash tables have different key-comparison
semantics; compiling all of them to one representation would be wrong.

Hash tables are the likely next concrete target. The runtime already has hash
support in some form, but quotation conversion needs to know which hash kind it
is building, how keys and values are recursively converted, and how immutability
is represented. If the runtime cannot yet represent all hash variants, the
compiler should support only the variants whose semantics are implemented and
reject the rest early. A comment in the conversion code should explain the
limitation.

Tests should cover quoted empty hash tables, single-entry hashes, multiple
entries, nested quoted data inside hash values, symbol keys, string keys,
immediate keys, and mutation attempts against quoted immutable hashes. If eq and
equal hash tables are both supported, tests must show that key comparison
differs where Racket differs. If only one kind is supported, tests should make
the unsupported kinds fail clearly.

A second quotation improvement is better sharing discipline. The AGENTS notes
already say FASL graph sharing is not supported. Quotation can face a related
issue: Racket's reader and quote semantics may preserve some identity in
specific cases or reject cyclic data. WebRacket should be explicit about what it
does. If graph sharing is not preserved, document the limitation and avoid
silently claiming equivalence for programs that observe identity with `eq?`.
For many immutable datum cases this is acceptable, but it should be a known
semantic boundary.

Implementation should be local. Extend the quotation converter, add any missing
runtime constructors or primitive exports only when needed, and keep tests in
`test/test-basics.rkt` near the relevant datum section. Do not use source-level
workarounds in examples. If a quoted datum fails, add a minimal repro and fix
the converter or runtime.

Stop if supporting a datum kind requires broad new runtime infrastructure such
as complete struct printing or full reader semantics. Continue with hashes and
other common immutable data if the runtime representation already has the
necessary primitives. The payoff is practical: many real Racket programs use
quoted tables or nested data, and supporting them improves compatibility without
destabilizing codegen.

### Detailed Direction

Quotation support is a compatibility multiplier. Many programs that do not use
advanced control features still use quoted data constantly: symbols, lists,
vectors, byte strings, lookup tables, keyword-like symbols, and nested
configuration structures. When quotation conversion fails, the user often sees
the compiler reject data rather than behavior. That can make WebRacket feel
less complete even when the runtime is capable of representing the values.

The first step is a datum support matrix. List every datum shape the converter
can encounter after expansion: booleans, fixnums, characters, strings, bytes,
symbols, keywords if present, null, pairs, lists, vectors, boxes, hash tables,
prefab structures, regular structures, paths if represented, regexps if
represented, and cyclic or shared data. For each one, record current behavior:
supported, rejected early, rejected late, or accidentally accepted with
questionable semantics. Then record the intended behavior for the next release.

This matrix matters because quoted values have observable properties beyond
their printed shape. Strings and bytes have mutability. Vectors have mutability.
Hash tables have equality modes and mutability. Symbols have interning.
Characters and fixnums use immediate representations. Pairs and lists may be
immutable by convention even if the underlying runtime pair fields are mutable.
If the compiler builds a value with the wrong mutability or equality behavior,
programs can observe the bug.

Hash tables are the most likely high-payoff unsupported datum class. Racket has
different hash constructors and literal hash forms with equality modes such as
`equal?`, `eq?`, and `eqv?`. WebRacket's runtime hash implementation must be
checked before quotation conversion grows support. If the runtime only
implements one equality mode, the converter should only accept literal hashes
for that mode. If the runtime supports immutable and mutable hashes separately,
quoted hashes should become immutable. If mutability is not represented yet,
that limitation should be documented and tests should avoid claiming full
Racket compatibility.

A good implementation pattern is recursive construction with explicit
constructors. The converter should not generate arbitrary source-level code
that happens to build the datum; it should emit the compiler's internal value
construction forms or runtime constructor calls. This keeps quotation lowering
visible and makes it easier to preserve immutability. For a quoted hash, the
converter can recursively compile each key and value, allocate a hash of the
right mode and size, insert entries, then mark it immutable if that is the
runtime representation.

Duplicate keys require care. Racket's reader or literal semantics may define
how duplicate keys are handled for hash literals. The converter should match
Racket or reject ambiguous input. This is another reason to consult the
expanded datum rather than textual syntax. By the time the converter sees a
datum, duplicates may already have been resolved or represented in a particular
way.

Symbols and interning should be audited as part of quotation. A quoted symbol
should produce the same interned symbol value as runtime symbol construction
where Racket semantics require it. Gensyms and unreadable symbols, if they can
appear in quoted data, may require separate treatment. A naive symbol allocation
that creates a fresh object every time can break `eq?` on symbols. If the
runtime has a symbol table, quotation should use it consistently.

Strings and bytes should preserve immutability. A quoted string in Racket is
immutable. If WebRacket's `$String` has an immutable field, the converter should
set it correctly. Tests should attempt mutation and expect failure if mutation
primitives are available. If mutation primitives are not available, tests can
still inspect the immutable flag indirectly if the runtime exposes predicates.

Pairs and vectors are also worth checking. Quoted lists are deeply immutable in
the sense that mutating literal constants is not allowed in Racket. If WebRacket
currently uses mutable pair fields for ordinary pairs, it may not yet enforce
literal immutability. That could be an existing limitation. The quotation matrix
should document it. A future improvement might add immutable pair/vector
variants or a literal-constant flag, but that is a larger runtime design.

Sharing is a subtle topic. The project notes already say FASL graph sharing is
not supported. Quotation may similarly duplicate substructures that Racket might
share in some circumstances. The team should decide what observable identity
guarantees quoted data has in WebRacket. If `(let ([x '#(a)]) (eq? x x))` works
because `x` is the same binding, that is different from preserving sharing
between two separately quoted but textually identical vectors. The document
should distinguish intra-datum cycles, intra-datum sharing, and repeated
literal occurrence sharing.

Cyclic data should probably be rejected until there is a clear graph-building
protocol. Building cyclic immutable data requires allocating placeholders and
patching, similar in spirit to recursive bindings. It is not a good first
quotation project. If cyclic data can appear through compiled FASL or reader
forms, reject it with a precise error rather than recursing forever or
generating invalid code.

The first implementation target should be chosen from the matrix and workload
measurement. Add a tool or compiler debug flag that counts unsupported quoted
datum kinds in standard workloads. If hash tables dominate, implement hashes.
If prefab structures dominate, choose a different plan. Without that data,
quotation work can become a long compatibility buffet where the team implements
rare datum shapes while common ones still fail.

Tests should be organized by datum kind and observable property. For hash
tables, test construction, lookup, equality mode if observable, immutability,
nested keys/values, empty hashes, and multiple entries. For strings and bytes,
test value equality and mutation rejection. For symbols, test `eq?` with
runtime-created symbols if available. For nested structures, test that deep
values are recursively constructed correctly.

The runtime should not be expanded blindly. If the converter needs an immutable
hash constructor and the runtime only has a mutable hash constructor, there are
two choices: implement the immutable runtime behavior or reject quoted hashes
until it exists. Do not compile quoted immutable hashes into mutable hashes just
to pass superficial lookup tests. That would violate the project's
no-workaround policy.

The converter should also improve failure messages. Instead of "unsupported
quote" or a generic match failure, report "quoted eq hash table is unsupported"
or "cyclic quoted datum is unsupported." Include the path inside the datum if
reasonable, such as "inside vector element 3" or "inside hash value for key
foo." This will make large quoted tables much easier to debug.

This chapter pairs well with primitive metadata cleanup. If hash lookup,
mutation, and predicates are primitives, their metadata and runtime behavior
must align with quoted hash construction. A quoted value should satisfy the
same predicates as a value built at runtime with the corresponding constructor.
Tests should compare those paths.

Success is a broader accepted-data surface with no semantic sleight of hand.
The compiler should accept more ordinary quoted data, reject truly unsupported
data early, and preserve observable Racket properties for the datum kinds it
claims to support. That kind of compatibility work is not flashy, but it
reduces friction for every larger example program.

### First Patch Checklist

The first patch should build the datum support matrix directly into a report or
developer note. Run representative workloads and count unsupported quoted datum
kinds. The output should distinguish unsupported hash variants, mutable versus
immutable literal concerns, cyclic/shared data, prefab or struct data, and
anything that currently reaches a generic fallback.

If one unsupported datum kind clearly dominates, add minimal failing tests for
it but do not necessarily implement it in the same patch. For hash tables, the
tests should record equality mode and immutability expectations. For strings,
bytes, vectors, and pairs, the tests should record mutation expectations if
mutation primitives are available.

The first patch succeeds if the next implementation target is no longer a
guess. It should answer "which datum kind blocks real programs?" and "what
runtime semantics must exist before supporting it?" Do not land a converter
change that constructs a value with weaker mutability or equality semantics
than Racket requires.

### Review Cadence

Review quotation work by observable properties, not constructor convenience.
For every newly supported datum kind, ask whether predicates, equality,
mutation, printing if available, and nested construction behave as expected.
If any property is intentionally unsupported, the converter should either
reject the datum shape or document the limitation directly. A patch that merely
makes a quoted value compile is not enough; the compiled value must be the right
kind of value.

One open question is whether literal immutability should be enforced uniformly
for all quoted compound data now or introduced per datum family. Uniform
enforcement is semantically cleaner, but it may require broader runtime support.
Per-family enforcement is easier to stage, but the converter must then reject
families whose immutability cannot yet be represented.

Another question is whether quoted datum construction should happen at module
initialization time or be emitted as prebuilt runtime constants where possible.
Prebuilt constants can reduce startup work, but they require careful handling of
GC references and identity. Initialization-time construction is simpler and
more flexible. The first implementation should choose simplicity unless
measurement shows quoted data construction is a real cost.

## 7. Consolidate Closure-Conversion Analysis Helpers

Abstract: Refactor the closure-conversion summary layer so environment needs,
body layouts, closure payload layouts, direct-call availability, and known-only
eligibility are computed from clearly named concepts rather than overlapping
historical helpers.

The closure work has produced useful machinery, but it now carries the sediment
of several experiments: small inline closures, known0, known1, known-only
variants, extended free-variable analysis, direct-edge availability summaries,
body-layout versus closure-env splits, binary-frontier reports, and deletion
opportunity scripts. The good news is that the compiler is more informed than it
was before. The risk is that multiple helpers now answer similar questions with
slightly different assumptions. That increases the chance of another locally
plausible but globally wrong lowering change.

This project should be a cleanup and invariant project, not an optimization
push. The goal is to make the analysis vocabulary precise. `closure-env-of`
should mean the payload stored in a closure-backed value. `body-layout-of`
should mean the environment values a converted body expects to access directly.
Extended needs should mean the fixed-point set of values a direct helper must be
able to receive or carry because of its own references and direct callees'
needs. Direct-edge availability should mean whether a caller can source the
callee's required operands from its formals, body layout, closure payload, or
other stable locations. Known-only eligibility should mean no closure
allocation, no ordinary closure ABI entry, and no value use that observes
procedure identity.

The first implementation step is to inventory all closure-analysis helpers and
group them by concept. Mark helpers that are measurement-only, production
lowering, assertions, or obsolete experiment residue. Dead helper predicates
from earlier narrow `known1` experiments should be removed if tests pass. Phase
comments such as "phase 7" should be rewritten as stable invariants. Measurement
scripts should either import shared summary helpers or clearly state that they
duplicate logic for reporting only.

The second step is to add assertions at the seams. If a known-only helper is
classified as deletion-producing, there must be no closure allocation and no
ordinary `$ClosureCode` label for it. If a direct call lowers to a known-helper
ABI, every env operand must be sourced from the caller's explicit carried
layout, formals, or another recorded source. If a helper's body layout differs
from its closure env, codegen must know which one it is using. If a direct edge
is marked available, the assertion should be able to explain why.

The tests for this refactor are mostly guardrails. Existing focused tests must
remain green. Add tiny tests for known0-only, known1-only, direct caller env
propagation, nested capture blockers, letrec blockers, and closure-backed value
use. The measurement scripts should continue to run and produce stable buckets
even if exact counts shift due to cleanup.

The main risk is accidental semantic change during cleanup. To avoid that, keep
refactoring separate from lowering expansion. A good rule is: one PR may rename,
factor, assert, and delete dead code, but it should not make new helpers
known-only or add new ABI families. If cleanup exposes a bug, fix the bug in a
separate, minimal patch.

Success looks like a smaller, more readable closure-conversion section with
fewer duplicated predicates and clearer comments. It should be easier to answer:
"Why does this helper still need a closure ABI entry?" and "Where does this env
operand come from?" If those answers become mechanical, future optimization
work becomes safer.

### Detailed Direction

This chapter is deliberately about consolidation rather than more closure
optimization. The project has learned a lot from the closure ABI experiments:
small inline closure payloads help, known0 and known1 can delete real code,
known2 is not currently a clean frontier, and the remaining known1 residue is
mostly nested structure, letrec, or environment payload cost. Those conclusions
are valuable. The compiler should now encode them in clearer analysis
boundaries so future work does not rediscover the same traps.

The first cleanup principle is naming. A helper whose name sounds like it
answers a general question should not secretly answer an experiment-specific
question. For example, a predicate that means "known1-only under the narrow
transition-era sibling rules" should not be named as though it means "known1
helper is semantically direct." The closure-conversion section should separate
semantic facts from profitability facts and from temporary lowering gates.
Semantic facts describe the program. Profitability facts describe whether an
optimization is worth emitting. Lowering gates describe what the compiler can
currently implement safely.

The second principle is one owner per concept. `closure-env-of` should own the
payload stored in closure-backed values. `body-layout-of` should own what a
converted body expects to access directly. Extended environment needs should
own the backward-flow requirement induced by direct callees. Direct-edge
availability should own the question "can this caller source that callee's
needed operands?" Known-only eligibility should own the identity question:
whether the helper can exist with no closure allocation and no ordinary closure
ABI entry. If two helpers compute overlapping versions of these ideas, one
should become a wrapper or be deleted.

The third principle is to keep measurement code honest. The recent reporting
scripts are useful and should not be thrown away casually. But measurement
scripts that duplicate production classification logic can drift. For each
script, decide whether it is a guardrail, a historical diagnostic, or an active
planning tool. Active planning tools should import or call shared summary
functions when possible. Historical diagnostics can remain standalone but
should say that they are diagnostic snapshots, not lowering authorities.

The cleanup should start with an inventory. Create a temporary checklist of all
closure-analysis functions and classify each one as production, assertion,
measurement, dead, or historical. Production functions affect generated code.
Assertion functions check invariants. Measurement functions feed tools.
Historical functions are retained only to reproduce old reports. Dead functions
have no callers and should be removed after tests pass. This classification can
be done in comments or in a local planning note before any code moves.

Dead code removal should be the first actual patch. Earlier scans suggested
there are helper predicates from narrow known1 experiments that no longer have
callers. Removing these is low risk if `raco test compiler.rkt` passes and the
measurement tools still run. This kind of deletion has a psychological benefit:
it tells future readers that the codebase does not preserve every experiment as
permanent sediment.

The second patch should refresh stale comments. Comments that mention phase
numbers from the migration plan were useful during the experiment, but they are
not stable documentation. Replace them with invariants. Instead of "phase 7
migrated zero-env direct helper layouts," say what is now true: zero-env
known-only helpers may have body layouts that intentionally differ from
closure-env layouts, and codegen must use the body layout for body free
references. This makes the code understandable after the migration context is
forgotten.

The third patch should add seam assertions. These assertions should live near
the transitions between analysis and lowering. Before emitting a known-only
label, assert that the helper has no closure allocation and no closure ABI
entry. Before lowering a known-helper call with env operands, assert that each
operand source is recorded and available. Before using `body-layout-of` in
codegen, assert that the target helper's body layout is present and stable.
Before using `closure-env-of` to allocate a closure, assert that the payload
matches the closure representation family chosen for the allocation.

Assertions should produce explanations, not just booleans. If a direct edge is
unavailable, the error should say which env variables are missing, where the
caller expected to source them, and which layouts were considered. The
measurement scripts already contain logic for explanations; production
assertions can reuse a concise version. This is not only a debugging nicety. It
prevents future optimization work from failing as "unknown local" in WAT when
the real error was an unsourced environment operand.

The fourth patch can factor common summary construction. If the same helper
label is looked up in several tables to decide known-only eligibility, direct
call status, and closure layout, introduce a small summary record or accessor
layer. Avoid overengineering. The goal is not to build an object system for the
compiler. The goal is to make it difficult for one path to use stale or partial
facts. A plain struct with fields such as label, formals, closure-env,
body-layout, extended-needs, direct-call status, value-use status, and blockers
may be enough.

The cleanup should preserve the distinction between "possible" and "chosen."
A helper may be possible-known1 according to arity and environment count, but
the compiler may choose not to emit known1-only because of nested capture or
profitability. The summary layer should expose both. This avoids confusion
where reports count theoretical candidates and lowering code assumes they are
safe.

Letrec should remain an explicit blocker in this cleanup. Do not quietly fold
letrec helpers into the non-recursive known-only classifier. Instead, have the
classifier return a blocker such as `letrec-group` or `recursive-group`. That
blocker can feed the letrec report from chapter 1. This keeps the boundary
between mature known-only work and future letrec work visible.

Nested lift-sensitive forms and nested capture should also remain explicit
blockers. The deletion-opportunity reports showed that these are real
remaining blockers for known1 transition tax. A cleanup that merely hides them
behind a generic `not-safe` result would lose useful information. Blocker
taxonomy is part of the compiler's institutional memory.

Testing for this cleanup should include before/after reports. Run the known2
frontier report and known-helper deletion report before refactoring, then after
refactoring. Exact labels may shift if dead code was removed or comments
changed, but aggregate buckets should not change unless the patch deliberately
changes classification. If a cleanup changes the number of known-only helpers,
that is a behavior change and should be separated.

This chapter has a strong rollback story. Dead-code removal can be reverted
independently. Comment refreshes can be reverted independently. Assertions can
be disabled or narrowed if they reveal a preexisting ambiguous case. Summary
factoring can be reverted if it introduces cycles or performance cost. None of
these patches should be bundled with new lowering.

The success condition is not fewer lines at any cost. Some consolidation may
add lines because explanations and assertions are verbose. Success is that the
closure-conversion section becomes easier to reason about. A new contributor
should be able to trace a helper from classification to allocation to call
lowering and understand why it has the representation it has.

This work is also protective. The next time someone is tempted to retry
known2, widen carried layouts, or push letrec known-only, the compiler should
have enough explicit facts to say whether the change is semantically safe and
whether it is deletion-producing. That is how we avoid another correct but
not-cost-effective detour.

### First Patch Checklist

The first patch should remove or mark abandoned helpers, not change lowering.
Use `rg` to identify closure-analysis predicates with no callers, especially
leftovers from narrow known1 experiments. Remove only helpers whose absence is
confirmed by tests and measurement scripts. For helpers that are historical but
still useful for reports, add comments saying they are diagnostic.

The same patch can replace stale migration-phase comments with stable
invariants. Avoid saying "phase 7 does X" in production code. Say what the
compiler now guarantees: which helpers may have body layouts distinct from
closure payloads, when closure env is authoritative, and when known-only means
no closure allocation.

Success is boring: fewer misleading helpers, clearer comments, no classification
changes, and green tests. If the cleanup changes known-only counts or WAT
output, split that behavior change into a separate patch. This first cleanup
should make future work safer without moving the frontier.

### Review Cadence

Review closure-analysis cleanup with before/after summaries. Run the existing
known-helper reports before the patch and after the patch. If counts change,
the patch is not merely cleanup. That may be fine, but it should be reviewed as
a behavior change. For pure cleanup, reviewers should see clearer names,
removed dead code, stronger assertions, and unchanged generated programs. This
discipline keeps measurement history trustworthy.

One open question is where shared measurement helpers should live. They should
not make production code depend on tools, but the tools also should not drift
from production classifiers. A small internal summary module may eventually be
the right compromise.

## 8. Clean Up Primitive Metadata And Inlining

Abstract: Normalize primitive metadata, arity information, inlining rules, and
runtime primitive registration so new primitives are easier to add correctly and
existing primitive calls generate less accidental overhead.

Primitive handling sits at the junction of compiler knowledge and runtime
semantics. The compiler needs to know names, arities, result behavior, whether a
primitive can be inlined, whether arguments require tag checks, whether a
primitive accepts optional or rest arguments, and how it maps to runtime support.
The AGENTS instructions already describe the manual workflow: implement in
`runtime-wasm.rkt`, add to compiler primitive lists, add inlining if needed,
export in `primitives.rkt`, add dummy implementations when necessary, and add
tests. That workflow is clear, but the amount of manual synchronization is a
source of drift.

The project should start by documenting the current primitive metadata model in
the code itself. Which table is authoritative for arity? Which table decides
inlining? Which table controls runtime imports or exports? Which primitives are
WebRacket-only? Which primitives have restricted semantics compared with
Racket? Once that is clear, consolidate duplicated metadata where possible. A
single primitive descriptor should ideally contain name, arity shape, runtime
symbol, inline lowering hook, validation strategy, and export/dummy status. It
does not have to be a grand abstraction, but it should reduce the current need
to edit several unrelated places for one primitive.

Inlining should be treated as a correctness-sensitive optimization. For simple
fixnum or character operations, inlining can remove call overhead and enable
better Wasm code. But an inline path must perform the same validation and error
behavior as the runtime primitive unless it is guarded by earlier type checks.
The type-checking style in AGENTS is important here: validate first, fail if not
valid, then proceed with checked operations. Inline code should follow the same
pattern and use checked runtime helpers only after tag validation.

The first measurable task is to report primitive call frequency and inline
coverage in standard workloads. Count calls by primitive, arity, whether they
inline, whether they allocate, and whether the call falls back to generic
application. This will identify high-payoff primitives before implementation
work begins. It may show, for example, that a small number of list, vector, or
numeric primitives dominate generated code.

Tests should accompany every primitive metadata change. Add tests for correct
results, wrong-type errors where applicable, optional argument defaults, arity
errors, and interaction with compiled versus interpreted `#lang webracket`
dummy definitions. If a primitive intentionally differs from Racket, the test
and runtime comment should say so.

The main risk is building an abstraction that is too clever and makes individual
primitive lowering harder to read. Keep the descriptor format plain Racket data
and preserve escape hatches for primitives with unusual behavior. Another risk
is changing arity or validation behavior accidentally while moving metadata.
Mitigate with before/after tests and by landing mechanical consolidation
separately from new primitive implementations.

Success means adding a primitive becomes boring and reliable. The compiler
should tell the implementer where metadata lives, tests should catch missing
exports or dummy definitions, and high-frequency primitive calls should have
clear inline opportunities.

### Detailed Direction

Primitive metadata cleanup is a leverage project because primitives are where
language semantics, runtime representation, and codegen meet. Every primitive
has at least three identities: the Racket-facing name, the compiler's internal
knowledge about arity and behavior, and the runtime implementation name. Some
also have inline expansions, checked helper variants, dummy source-level
definitions, documentation restrictions, optional arguments, and special error
behavior. If those facts live in separate hand-maintained lists, drift is
inevitable.

The first goal is to identify the authoritative source of each primitive fact.
For example, if the compiler wants to know whether `+` is fixed arity or
variable arity, where does it ask? If the runtime exports a function for
`string-length`, how does the compiler know its Wasm name? If a primitive is
WebRacket-only and needs a dummy implementation in `primitives.rkt`, where is
that recorded? If an inline lowering exists, where is the non-inline fallback
declared? The answer should not require a developer to remember five tables.

A useful primitive descriptor might include fields such as source name,
runtime name, arity shape, optional argument defaults, rest-argument behavior,
result convention, validation policy, inline lowering hook, checked helper
name, export status, dummy-required status, and semantic notes. This does not
mean every primitive needs a massive record. Defaults can cover ordinary
fixed-arity runtime calls. The important point is that exceptional primitives
should be exceptional in one place rather than scattered across compiler and
runtime files.

Arity shape should be represented precisely. Fixed arity, arity-at-least,
case-like arity, optional arguments, and rest arguments generate different
calling code and error behavior. A primitive with optional arguments should
record the default value and where the default is supplied. This matches the
project instruction to mention optional parameter defaults in inline comments.
If optional defaults are handled by compiler inlining for one path and runtime
dispatch for another, tests should cover both paths.

Validation policy is equally important. Some runtime helpers expect raw
unchecked values and perform validation internally. Some checked helpers assume
the compiler has already verified tags with `ref.test` and `ref.cast`. Inline
lowerings often want to validate once and then use checked operations. The
descriptor should make this visible. A primitive that takes a fixnum should not
silently receive arbitrary `(ref eq)` values in an inline path just because the
runtime fallback would have checked them.

The cleanup should start with reporting rather than restructuring. Add or run a
primitive inventory report that lists every primitive known to the compiler,
whether it has a runtime implementation, whether it is exported through
`primitives.rkt`, whether it has a dummy source implementation, whether it has
an inline path, and whether tests mention it. This report will find missing
metadata before any abstraction changes. It may also reveal primitives that are
dead, duplicated, or only half-implemented.

The next report should be workload frequency. Count primitive calls in the
standard workloads after simplification and application categorization. Record
which calls inline, which call runtime directly, and which pass through generic
application. This helps prioritize inlining work. There is little reason to
build a beautiful inline path for a rare primitive while a common list or
numeric primitive still allocates or dispatches unnecessarily.

Inlining should follow a profitability and correctness gate. A primitive is a
good inline candidate when the inline code is small, validation is simple,
runtime call overhead is meaningful, and behavior is easy to match. Fixnum
arithmetic, character predicates, simple vector/string length operations, and
tag predicates may fit. A primitive is a bad inline candidate when it has
complex allocation, subtle error messages, optional/rest dispatch, or depends
on runtime state. Those should stay as runtime calls until the semantics are
well covered.

The compiler should distinguish semantic inlining from lowering selection.
Some "inlines" may be necessary because the primitive has special syntax-like
calling behavior or variable arity that cannot be represented as a plain
runtime call. Others are performance optimizations. The descriptor should mark
why an inline hook exists. Performance inline hooks can be disabled for
debugging or benchmarking; required lowering hooks cannot.

Runtime comments should be part of the workflow. The AGENTS instructions say
that restrictions or differences from Racket should be commented in
`runtime-wasm.rkt`, and optional parameter defaults should be mentioned. The
primitive descriptor can include a semantic note, but the runtime implementation
should still carry local comments where they help maintainers. The descriptor
and runtime comments serve different readers: the compiler wants metadata; the
runtime maintainer wants implementation constraints.

Testing should be generated or at least checklist-driven. For each primitive,
there should be result tests, wrong-type tests when applicable, arity tests,
optional default tests, boundary-value tests, and compiled-versus-source dummy
tests for WebRacket-only primitives. Not every primitive needs exhaustive tests
in one patch, but the metadata report should make missing coverage visible.

This cleanup interacts with `$Args` allocation. A variable-arity primitive may
currently force an argument vector. A fixed-arity primitive should not. If
primitive metadata precisely records arity, call lowering can avoid unnecessary
generic paths. Conversely, if a primitive has rest arguments, the compiler can
avoid unsafe direct-call optimizations. This is another reason primitive
metadata should be authoritative.

It also interacts with module handling. A `require` that imports a primitive
should resolve through the same primitive table used by codegen. If the module
normalizer and code generator maintain separate primitive name lists, they can
disagree. A shared descriptor layer would let module resolution answer "this
import is a compiler-known primitive" without duplicating details.

The migration should be incremental. First land inventory and frequency
reports. Then choose a tiny descriptor wrapper around existing data without
moving all primitives. Then migrate one small family, such as fixnum predicates
or character operations. Run tests. Only after the pattern is proven should the
larger primitive table move. Avoid a single enormous patch that changes every
primitive and every inline path at once.

The main risk is abstraction drag. Primitive lowering often has sharp corners,
and a too-general descriptor system can make those corners harder to express.
Keep escape hatches. A primitive descriptor can contain a custom lowering hook
or mark a primitive as special. The goal is not to force uniformity where the
language is not uniform; the goal is to make ordinary primitives ordinary and
special primitives visibly special.

A second risk is changing behavior accidentally while normalizing metadata.
Treat the first descriptor patches as mechanical. If a primitive's arity,
runtime name, or inline behavior changes, that should be intentional and tested
in its own patch. For reviews, it should be easy to distinguish "moved metadata"
from "changed primitive semantics."

Success means future primitive work follows a predictable path. A developer
adds or updates one descriptor, implements runtime support, exports or dummies
the primitive as needed, and gets checklist failures if something is missing.
That will make WebRacket's primitive surface grow faster and with less
regression risk.

### First Patch Checklist

The first patch should be an inventory script or report. It should list every
compiler-known primitive, its runtime implementation name if known, arity shape,
inline status, export status, dummy implementation status, and test coverage if
that can be approximated. Missing facts should be printed as missing rather
than silently defaulted.

The report should also identify high-frequency primitive calls in the standard
workloads. This prevents cleanup from becoming purely aesthetic. If a primitive
is called thousands of times and never inlined, it deserves attention. If a
primitive is listed in metadata but never used and lacks tests, it may be
unfinished or obsolete.

Do not migrate the whole primitive table in the first patch. Use the report to
choose one small family for a later descriptor pilot. Success is knowing where
drift exists: missing runtime implementation, missing export, missing dummy,
unclear arity, or inline/fallback disagreement.

### Review Cadence

Review primitive cleanup primitive-family by primitive-family. A patch that
migrates fixnum predicates should not also migrate strings, hashes, vectors,
and formatting. For each family, compare interpreted `#lang webracket`
behavior, compiled behavior, inline behavior, and runtime fallback behavior.
If these disagree, fix the semantic mismatch before adding more metadata
abstraction. The cadence should make primitive work feel like tightening a
ratchet, not stirring a large table.

One open question is whether primitive descriptors should be executable data
used directly by codegen or documentation-like data checked against existing
tables. Executable descriptors reduce drift more strongly, but they make the
first migration riskier. A checked inventory report is safer as a first step
and can evolve into authoritative descriptors once the shape is proven.

Another question is how to represent primitives that expand to compiler
patterns rather than runtime calls. These should not be forced into the same
shape as ordinary runtime functions. The descriptor can mark them as
syntax-like or lowering-only, with no expectation of a one-to-one runtime
export. Making this explicit will help avoid confusing missing runtime symbols
with intentionally special compiler forms.

The descriptor should also record when a primitive is intentionally unavailable
in source interpretation, so dummy-definition decisions are explicit.

That small fact prevents confusing an intentional host-only primitive with a
forgotten stub.

## 9. Improve Error Paths And Source-Location Reporting

Abstract: Make compiler and runtime failures easier to diagnose by preserving
source context through passes, improving unsupported-form errors, and avoiding
late generic failures when an earlier pass can report the real problem.

WebRacket is now complex enough that debugging quality matters. A compiler that
fails with "unsupported form" or a WAT validator error after several lowering
passes forces the developer to reconstruct the original source cause manually.
The project guidelines already recommend `--dump-passes` and
`--dump-passes-limit`; better error reporting would make those tools more
effective and reduce time spent chasing symptoms such as unknown locals.

There are three related goals. First, unsupported source or expanded forms
should fail early with a message that names the form and the compiler phase that
rejected it. Second, generated runtime error paths should preserve enough
procedure or primitive context to explain arity and type failures. Third,
internal compiler invariant failures should print the relevant helper label,
layout, direct edge, or binding group instead of a raw assertion failure.

The first phase should inventory current `error`, `TODO`, and unsupported-form
sites. Classify them as user-facing language limitations, internal compiler
bugs, runtime semantic errors, or temporary development assertions. Each class
needs a different style. User-facing limitations should say what is unsupported
and ideally point to the form. Internal bugs should include enough compiler
state to reproduce. Runtime semantic errors should match Racket behavior where
WebRacket claims compatibility.

Source locations are the hard part. If syntax objects enter the compiler with
locations, the simplifier and later passes should preserve a lightweight origin
field for forms where practical. It may be too expensive to annotate every
intermediate node immediately, so start with forms that commonly fail:
applications, binding forms, quotations, module forms, and unsupported special
forms. Even a best-effort origin is better than losing all context.

For closure and direct-call work, add specialized invariant reporters. If a
known-helper call cannot source an environment operand, the error should print
the caller label, callee label, required env, caller body layout, caller closure
env, and direct-call chain. The measurement scripts already generate similar
explanations; production assertions can reuse a smaller version of that logic.
If WAT generation would reference a local that is not in scope, catch it before
emitting invalid WAT.

Tests should include expected failure tests, not only success tests. A small
unsupported module form should produce an early module error. A wrong-arity
primitive should report the primitive. A known internal invariant test can be
harder to keep stable, but helper functions can be unit tested directly where
possible.

The risk is making error handling invasive. Avoid threading large source objects
through every pass in the first iteration. Use small origin records and helper
functions. Another risk is overpromising Racket-identical error messages.
WebRacket does not need byte-for-byte identical messages at first; it needs
accurate, actionable failures.

Success means less time reading enormous pass dumps for routine issues. When a
new compiler limitation is encountered, the developer should know whether to
write a primitive, extend a lowering pass, fix runtime semantics, or reject a
source form earlier.

### Detailed Direction

Error reporting is infrastructure for every other project in this document.
When a compiler is small, a developer can often infer the failing phase by
looking at the stack trace. As the pipeline grows, that stops working. A failure
in generated WAT may originate in closure conversion. A missing local may
originate in environment availability analysis. An unsupported expanded form
may survive until codegen even though the right fix is in module
normalization. Better errors shorten the feedback loop and reduce the chance of
fixing symptoms instead of causes.

The first distinction is between user-facing errors and internal compiler
invariants. User-facing errors include unsupported language forms, wrong arity,
wrong type, missing primitive support, and runtime semantic failures. Internal
invariants include impossible layout mismatches, unsourced environment operands,
unknown labels, malformed ANF, and codegen stack-shape assumptions. These two
classes should use different wording. A user-facing error should explain what
the program did that WebRacket does not support. An internal invariant should
say "compiler bug" or equivalent and print the compiler facts needed to debug.

The inventory should search for `error`, `raise`, `TODO`, `unsupported`, and
plain match fallthroughs. Each site should be classified by phase and audience.
For example, an unsupported hash-table quote is a user-facing limitation in
quotation conversion. An unknown local emitted in WAT is an internal compiler
bug and should be caught before WAT emission. A wrong fixnum argument to a
primitive is a runtime semantic error. This classification can be recorded in
comments or helper wrappers.

Source locations should be added gradually. The compiler likely receives syntax
objects with source information near the front end, but later intermediate
forms may be plain Racket data. Threading full syntax objects through every
pass could be expensive and invasive. Instead, introduce a lightweight origin
record that can be attached to important forms. The origin might contain source
path, line, column, span if available, and an original form summary. If exact
locations are unavailable, phase and binding name are still useful.

Origins should be preserved first for forms that commonly fail: applications,
binding forms, quotations, module forms, `letrec-values`, and special forms
such as `wcm`. Do not attempt full origin preservation for every temporary ANF
binding in the first pass. A best-effort origin on the enclosing source form is
enough to make many errors actionable. Later work can refine origin propagation
for generated temporaries.

Unsupported-form errors should include phase names. "unsupported form" is much
less useful than "simplify: unsupported require form" or "codegen:
`letrec-values` with dynamic multiple values is unsupported." Phase names help
developers decide where to look. They also discourage late rejection: if a
module form is rejected in codegen, the phase name itself suggests that the
normalizer should have handled it earlier.

Internal closure errors should use structured explainers. The measurement work
already produced useful explanations for environment availability: callee
extended env, caller body layout, caller closure env, caller formals, caller
extended needs, missing env, direct-call chain, and blocker bucket. A shorter
version of this should be available to assertions. If a known-helper call would
emit an operand from a missing local, the compiler should fail with this
explanation before generating WAT.

WAT local validation can be improved at the compiler level. Before emitting a
local reference, codegen can check that the local is declared in the current
function environment. This may already happen in some paths, but the known2
failure showed that unknown locals can still reach generated WAT. A defensive
local lookup helper that fails with label, local name, and available locals
would catch these earlier. It should be used consistently instead of manually
formatting local names.

Runtime errors should preserve procedure and primitive names where possible.
If a primitive raises a type error, the message should name the primitive and
the expected kind. If a closure arity check fails, the message should identify
the procedure if metadata is available. This may require procedure-name fields
or debug metadata in closure code. If full Racket-style error objects are not
implemented, human-readable messages are still useful.

There is a tradeoff between code size and runtime error quality. Embedding
names and source locations in generated Wasm can increase output size. The
compiler may eventually need debug and release modes. For now, prioritize
compiler-time errors and internal invariant explanations, because they do not
necessarily affect generated code size. Runtime error metadata can be gated if
needed.

Expected-failure tests are important. Many compiler test suites focus on
programs that should run. Error reporting needs tests that intentionally fail.
These tests do not need to assert the entire message byte-for-byte, but they
should assert key substrings: phase name, unsupported form name, primitive name,
or binding label. This keeps messages flexible while preventing regressions to
opaque failures.

For internal invariants, tests may be harder because the compiler should not
normally generate invalid states. Where possible, unit test helper functions
directly with malformed summary data. For example, a direct-edge explainer can
be tested with a fake caller/callee layout. This avoids needing to construct a
real program that triggers a compiler bug.

The error system should avoid swallowing context. Wrapping every failure in a
generic handler can erase useful stack traces. Prefer helper functions that add
context and re-raise or construct a richer error. If Racket condition types are
used, define a small compiler-error structure with phase and origin fields.
Even if output formatting remains simple, structured errors make future tooling
possible.

This chapter also supports documentation. A clear unsupported-form error can
point to a TODO section or docs page in the future. For now, the message should
be concise and actionable: what failed, where, and whether it is unsupported
language surface or a compiler bug. Avoid apologetic but vague messages.

The rollout should be staged. First inventory and classify error sites. Second
introduce phase-tagged error helpers. Third convert a few high-value areas:
quotation, module normalization, letrec-values, and closure env availability.
Fourth add origin records for those areas. Fifth consider runtime debug
metadata. Each stage should improve diagnostics without requiring the next.

The biggest risk is making every pass heavier. Do not let source-location work
turn every intermediate node into a large object. Keep origin metadata optional
and shared. Another risk is spending too much time polishing messages before
semantics are fixed. The goal is practical debugging, not literary perfection.

Success means the next time WebRacket hits a compiler limitation, the error
points to the right neighborhood. Instead of "unknown local $$x.276" after WAT
validation, we want "closure-conversion/codegen: callee f requires env x, but
caller g cannot source it; caller body layout ..., closure env ...." That kind
of message changes the debugging experience completely.

### First Patch Checklist

The first patch should add phase-tagged error helpers and convert a small
number of high-value sites. Good first sites are unsupported quotation forms,
unsupported `letrec-values` shapes, unsupported module forms, and closure env
availability assertions. These are places where a precise message directly
guides the next fix.

The patch should include expected-failure tests that match key substrings, not
entire messages. For example, a quotation test might check for `quote` and
`hash`, while a letrec-values test might check for `letrec-values` and
`multiple values`. This gives the project stable diagnostics without freezing
wording forever.

Do not thread full source objects through the whole compiler in the first
patch. Add phase names and local context first. If that proves useful, introduce
lightweight origin records for the forms that fail most often. Success is a
clearer failure today and a path toward richer locations tomorrow.

### Review Cadence

Review diagnostics by reproducing real debugging stories. Each patch should
include at least one before/after example in the commit or PR notes, showing
the old vague failure and the new actionable message. Tests should assert only
stable message fragments, but the reviewer should still be able to see the
human improvement. If a diagnostic patch adds lots of machinery without making
one concrete failure easier to understand, it is probably too abstract.

One open question is how much source-origin metadata should survive
optimization. Full fidelity may be expensive and noisy, while too little
metadata leaves users lost. The practical compromise is to preserve origins for
forms that introduce bindings, calls, literals, and unsupported constructs
first. Generated temporaries can inherit enclosing origins until a finer-grained
scheme is justified.

Another question is whether runtime errors should carry full source locations
or only procedure and primitive names. Full source locations are nicer for
debugging but can increase code size. A reasonable first step is compiler-time
locations and runtime names. Later, a debug-build mode could include richer
locations without forcing release builds to pay for them.

The debug-build idea should stay optional. The normal compiler path should
remain small and predictable, while the richer path can trade size for
diagnostics when someone is actively investigating a failure.

It also gives benchmark runs a clean baseline: diagnostics can be enabled when
needed without changing the default performance story.

That separation will matter as examples grow and code size becomes easier to
track.

Keep the diagnostic path observable in tests.

## 10. Modularize `compiler.rkt` Gradually

Abstract: Split `compiler.rkt` into coherent internal modules over time, using
stable seams such as primitive metadata, syntax normalization, closure analysis,
letrec lowering, and code generation, without disrupting active compiler work.

`compiler.rkt` is large because it contains the whole compiler pipeline:
primitive metadata, parsing and unexpansion, simplification, letrec lowering,
assignment conversion, application categorization, ANF, free-variable analysis,
closure conversion, code generation, instrumentation, and driver glue. A large
single file is not automatically bad, especially in a fast-moving compiler. It
keeps local reasoning simple when representations are still changing. But the
file is now large enough that navigation, ownership, and accidental coupling are
becoming real costs.

The right modularization strategy is gradual extraction, not a sweeping rewrite.
Start with sections that have relatively stable boundaries and few circular
dependencies. Primitive metadata is a good candidate because it is conceptually
data plus lowering hooks. Measurement/reporting helpers may also be extractable.
Syntax normalization and quotation conversion could become their own module once
their input and output forms are documented. Closure-conversion analysis is a
candidate later, but only after the cleanup project clarifies its concepts.
Codegen should probably remain last, because it depends on nearly everything.

Before moving code, add section-level contracts in comments. For each major
section, write down the input representation, output representation, and
important invariants. This creates a map for extraction and helps reveal hidden
dependencies. Then choose one low-risk section and move it into a private module
with explicit provides. Run `raco test compiler.rkt` after each move. Avoid
combining movement with behavior changes.

The extraction should preserve development ergonomics. If splitting files makes
it harder to trace a single form through the pipeline, the project loses
something valuable. Keep names searchable, avoid overly deep directories, and
prefer modules named after compiler stages rather than abstract utility
categories. For example, `compiler/private/primitives.rkt`,
`compiler/private/quote.rkt`, or `compiler/private/closure-analysis.rkt` are
more helpful than `compiler/private/core-utils.rkt`.

Tests are mostly regression tests. The same compiler tests should pass before
and after each extraction. Add a smoke check that requiring the new internal
modules does not trigger compilation cycles. If Racket compile time changes,
record it; modularization can sometimes improve incremental development but
hurt cold compile time.

The main risk is introducing circular dependencies. A monolithic file can hide
cycles because every helper is in scope. Once modules are split, those cycles
become explicit. That is useful, but it can also derail a cleanup patch. The
mitigation is to extract data-only or leaf-like sections first and to create
small shared utility modules only when a dependency is genuinely common.

Another risk is destabilizing active optimization work. Modularization should
not happen in the middle of a delicate closure ABI change or letrec lowering
change. It is best done immediately after a stable baseline, with no semantic
edits mixed in. If a future optimization needs to touch code that was just
moved, the move should be easy to review and should not obscure the behavioral
diff.

Success is not a beautiful architecture diagram. Success is a compiler that is
easier to navigate, easier to test in pieces, and less prone to accidental
cross-stage coupling. The best first extraction is the one that makes future
work safer without forcing every open thread to rebase through a giant rewrite.

### Detailed Direction

Modularization should be treated as maintenance infrastructure, not as a
rewrite. The compiler's current single-file shape has real advantages. It makes
search easy, avoids module cycles, and lets experimental representations evolve
without constantly adjusting provides. Those advantages mattered during the
closure ABI work. But as the file grows, the costs become more visible:
unrelated helpers share namespace, section boundaries blur, comments from old
experiments linger, and a developer has to keep too much of the pipeline in
mind to make a small change.

The first step is not moving code. The first step is drawing stable seams. Add
or refresh section headers that name each major stage and its representation
contract. For each stage, document input shape, output shape, important
invariants, and known dependencies. This can be done inside `compiler.rkt`
without changing behavior. It immediately improves navigation and creates a
map for later extraction.

Good candidate seams include primitive metadata, syntax/module normalization,
quotation conversion, letrec lowering, application categorization, ANF,
free-variable analysis, closure-conversion summaries, closure-conversion
lowering, codegen helpers, and pipeline driver/instrumentation. Not all of
these should become separate modules immediately. The seam exercise simply
asks whether each section has a coherent public surface.

Primitive metadata is probably the safest first extraction after chapter 8's
cleanup. It is mostly declarative data plus a limited set of lookup functions.
Moving it to `compiler/private/primitives.rkt` could reduce top-level noise and
make primitive workflow clearer. However, if inline lowering hooks depend
heavily on local codegen helpers, extract only the data and lookup layer first,
leaving lowering hooks in the main compiler until their dependencies are
cleaner.

Quotation conversion is another plausible extraction. It has a natural input
and output: quoted Racket data in, compiler/runtime value construction out.
If it depends on many runtime constructor names, those can be passed through a
small interface. Extracting quotation after the datum support matrix is
complete would make sense. Extracting it before semantics are clarified might
just move confusion into a new file.

Closure analysis should not be the first extraction. It is important, but it is
currently the most historically layered part of the compiler. Extracting it
before chapter 7's consolidation could freeze messy boundaries into module
interfaces. After cleanup, however, it may become a strong candidate because
its summary functions could be tested independently and reused by measurement
tools.

Code generation should be late. It depends on runtime names, primitive
metadata, closure-conversion output, local environments, representation
details, and driver options. Moving codegen too early risks creating a module
that imports half the compiler or forcing unnatural abstractions. Before
codegen moves, smaller helper layers should be extracted and stable.

The project should use a private module directory rather than a broad public
API. These modules are compiler internals. Names such as
`compiler/private/primitives.rkt`, `compiler/private/quote.rkt`,
`compiler/private/module-normalize.rkt`, and
`compiler/private/closure-summary.rkt` are clear. Avoid vague names like
`utils.rkt` unless the contents are genuinely generic. Vague utility modules
often become junk drawers.

Dependency direction should be explicit. Early pipeline modules should not
import late codegen modules. Data/metadata modules can be imported by many
stages. Measurement tools can import analysis modules, but production compiler
modules should not import measurement scripts. If a proposed extraction creates
a cycle, that is a signal that the seam is not ready.

Each extraction patch should be mechanical. Move code, add provides/requires,
adjust references, run tests. Do not rename functions, change behavior, or add
new features in the same patch. Mechanical movement is already enough for a
reviewer to verify. If behavior changes are needed, land them before or after
the move.

Compile time should be measured. Racket module boundaries can affect both cold
compile time and incremental development. Splitting a large file may improve
incremental loading for some workflows and worsen it for others. Record
`raco test compiler.rkt` time before and after major extractions. If a move
significantly worsens compile time, reconsider the boundary or use submodules
only where they help.

Tests should include requiring the main compiler and, where useful, requiring
new private modules directly. Direct module tests are useful for pure analysis
or conversion helpers. For codegen or pipeline pieces with many dependencies,
end-to-end compiler tests may be enough. Avoid creating a brittle test suite
that locks down every internal helper signature unless those helpers are meant
to be stable.

The extraction order should follow stability. First, section comments and
contracts. Second, data-only primitive metadata after cleanup. Third, reporting
or measurement support helpers that already act as independent tools. Fourth,
quotation conversion after datum semantics are clarified. Fifth, module
normalization after accepted forms are specified. Sixth, closure summaries after
analysis consolidation. Codegen and driver glue last, if ever.

This chapter has a human factor. A giant `compiler.rkt` can be intimidating,
but too many tiny modules can be equally frustrating. The target should be a
small number of meaningful files, each corresponding to a compiler concept.
The split should make it easier to answer "where does this logic live?" not
harder.

Another human factor is active work. Do not modularize across code that is in
the middle of a delicate optimization thread. A large move causes merge
conflicts and makes it harder to compare benchmark branches. The best time to
move code is after a stable baseline and before the next risky implementation
frontier. If another thread is changing closure conversion, do not move closure
conversion out from under it.

Documentation should move with code. If section comments describe invariants,
they should be preserved in the new module. If a module exposes a helper used
by other stages, its provide list should be intentionally small and documented.
Avoid providing everything just to make the move easy; that recreates the
single-file namespace problem across module boundaries.

Rollback should be easy. Because each extraction is mechanical, reverting it
should restore the old file layout without semantic fallout. This is another
reason not to mix behavior changes with movement. If a module split creates
cycles, performance regressions, or review pain, back it out and choose a
smaller seam.

Success is reached when the compiler has clearer neighborhoods. A developer
working on primitives should not need to scroll through closure conversion. A
developer working on quotation should not fear breaking known-helper lowering.
A developer working on closure analysis should be able to run or import summary
helpers without dragging in the whole driver. That is the practical value of
modularization: not architectural purity, but lower cognitive load.

### First Patch Checklist

The first patch should not move code. It should add or refresh major section
headers and representation contracts inside `compiler.rkt`. Each section should
state what representation it consumes, what it produces, and which invariants
later passes rely on. This creates the extraction map without creating module
cycles.

The second patch can move a genuinely low-risk leaf, but only after the map
exists. Candidate leaves are primitive data after the primitive cleanup, or
small measurement-support helpers that do not participate in the main pipeline.
Avoid moving closure conversion or codegen first. Those sections are too
connected and too active.

Success is lower cognitive load with no behavioral diff. If a move changes WAT,
benchmark results, or classification counts, it is not a mechanical move and
should be split. Modularization is valuable only if it reduces future risk; a
giant rebase-heavy file split would do the opposite.

### Review Cadence

Review modularization by diff shape. A mechanical move should be mostly moved
lines, provide lists, require lists, and unchanged tests. A semantic change
should be a different patch. After each extraction, ask whether the new module
has a clear reason to exist and a small public surface. If the new file exports
nearly everything it defines, the seam is probably not mature. If the move
creates cycles or forces awkward utility modules, back up and choose a smaller
boundary.

One open question is whether to use separate files or Racket submodules for the
first extractions. Separate files create clearer ownership and easier targeted
requires. Submodules can reduce path churn and keep tightly related code near
the main pipeline. The right answer may differ by section. Primitive metadata
probably wants a file; a small local test helper may be better as a submodule.

Another question is how much public surface private compiler modules should
expose to tools. Measurement tools benefit from importing real classifiers, but
wide exports make internals harder to change. Prefer narrow exported summary
functions over exporting raw tables. Tools should ask high-level questions like
"why is this helper blocked?" rather than reconstructing the compiler's private
state from pieces.

This keeps tools useful without turning every internal representation into a
permanent API commitment.

It also makes future refactors less scary, because tools depend on questions
the compiler promises to answer rather than on the exact storage shape.

That is the healthier boundary for a compiler still evolving this quickly.

Prefer that boundary whenever tools need compiler facts.

## 11. Make FFI Bindings First Class

Abstract: Promote FFI bindings from a side-channel primitive mechanism into a
first-class compiler/runtime binding category with explicit identity, arity,
type adaptation, import/export metadata, tree-shaking behavior, and ordinary
value semantics.

WebRacket already has meaningful FFI infrastructure. The compiler can read
foreign declarations, add FFI names to the primitive set, compute FFI primitive
arity, and reset FFI primitive state before parsing. The runtime can generate
foreign imports, wrap them as primitive globals, filter active FFI wrappers
during tree shaking, represent host values with `$External`, convert Racket
procedures into host callbacks with `procedure->external`, and move values
through the FASL bridge. This is not a blank slate. The issue is that the FFI
machinery is still partly bolted onto the primitive path rather than being a
coherent binding story. In `compiler.rkt`, FFI names are classified separately,
but reference and assignment code still contain `TODO` cases for FFI variables.
That is the smell: the compiler recognizes that these bindings exist, but it
does not yet treat them as ordinary first-class values throughout the pipeline.

First-class FFI means that a foreign binding behaves like a value binding with
well-defined representation and metadata. A program should be able to refer to
an imported foreign function as a procedure value when that is semantically
intended, pass it around, store it in data structures, export it from a module,
call it directly when statically known, and receive useful arity/type errors
when it is misused. A foreign value should also have clear printing,
serialization, identity, and callback behavior. This does not mean WebRacket
must support arbitrary C-style FFI or every JavaScript host object operation at
once. It means the binding category should be explicit and integrated, rather
than sneaking through the primitive table until a variable reference needs to be
generated.

The current `.ffi`-driven primitive model appears to treat declared foreigns as
primitive names. That is useful for direct calls, because the compiler can know
arity and the runtime can generate wrapper functions. But a primitive name is
not the same thing as a first-class binding. A primitive can be inlined, called,
or installed as a global procedure object by runtime initialization. A foreign
binding may additionally carry host import module/name, argument type adapters,
return type adapters, exception behavior, callback permissions, external value
wrapping behavior, and tree-shaking dependencies. Those facts should live in a
foreign-binding descriptor rather than being spread across `.ffi` parsing,
primitive lists, generated WAT imports, and runtime wrapper filtering.

The first design decision is the value representation of an FFI binding. There
are at least three possibilities. First, an FFI function can be represented as a
normal `$Procedure`, with an invoker that calls the generated foreign wrapper.
This gives procedure identity, `procedure?`, generic `apply`, arity checking,
and module export behavior for free, at the cost of allocating procedure
objects and going through the runtime procedure path. Second, an FFI function
can be represented as a special `$External` host value, with a separate call
path. This reflects host identity more directly, but it means `procedure?`,
`apply`, arity errors, and Racket procedure metadata need special handling.
Third, there can be two layers: a Racket procedure wrapper around an underlying
external host reference. For WebRacket, the third model is probably the most
future-proof. The Racket-facing binding should usually be a `$Procedure` when
the declared foreign is callable as a Racket function, while `$External`
continues to represent opaque host values returned by foreign calls.

That distinction matters. `external?` should answer whether a value is an
opaque host value, not whether a value is a Racket procedure that happens to
call the host. `procedure->external` should remain the bridge from Racket
procedures to host callbacks. Foreign functions imported from the host should
be callable from Racket with Racket calling conventions. If the host returns a
DOM node, JS object, callback handle, or nullish value, that result can be
wrapped as `$External` or converted according to the declared return type. This
keeps the Racket world coherent: functions are procedures; host objects are
external values.

The second design decision is where FFI binding metadata enters the compiler.
Today, `reset-ffi-primitives` repopulates FFI primitive names from
`current-ffi-foreigns`, and `ffi-primitive-arity` consults the foreign's
argument types. A first-class model should preserve that but make it more
structured. Introduce a conceptual `foreign-binding` summary with fields such
as Racket name, host module, host import name, argument type list, return type,
arity shape, purity/effect metadata if ever needed, callback policy, exception
policy, wrapper function name, imported function name, generated global name,
and whether the binding is value-observable. The compiler can still add the
name to the primitive set for call lowering, but the binding itself should have
one authoritative descriptor.

The third design decision is how references should compile. The current
`Reference` path has an `ffi` case that is still `TODO`. In a first-class
design, referencing an FFI binding should produce the Racket value associated
with the binding, most likely a global initialized in runtime startup. That
global should contain a procedure wrapper or other declared value. Direct calls
may bypass the global and call the generated wrapper directly, but ordinary
reference must work. This is the same distinction used elsewhere in the
compiler: a binding can have an optimized call path and still have a value
representation when used outside operator position.

Assignment should probably be rejected for FFI bindings by default. A declared
foreign import is not a mutable top-level variable unless the FFI system
explicitly supports rebinding. Therefore the `Store!` `ffi` case should not be
`TODO`; it should raise a clear compile-time or runtime error saying that FFI
bindings are immutable imports. If mutable foreign variables are ever supported,
they should be a separate declaration kind with getter/setter adapters and host
semantics. Do not let ordinary `set!` silently mutate a compiler table or a
Wasm global unless that is explicitly the FFI contract.

Direct calls should be layered on top of value semantics. If a call expression's
operator is a statically known FFI binding, the compiler can lower it directly
to the generated wrapper, using the descriptor's arity and adapters. If the
same binding is passed as a value and later applied generically, the procedure
wrapper's invoker should call the same generated wrapper. This gives both
efficiency and correctness. Direct-call lowering is an optimization;
first-class reference behavior is the semantic baseline.

Type adaptation should be explicit and tested. The `.ffi` declaration already
knows argument and return types. Each adapter should have a named lowering
strategy: Racket fixnum to host number, Racket flonum to host number, Racket
string to host string, bytes to linear-memory range, external value to
externref, procedure to callback external, nullish host result to Racket false
or external-null depending on declaration, and so on. The runtime already has
helpers such as external number/string conversion and nullish predicates. The
first-class FFI descriptor should connect declarations to these helpers in one
place. Avoid embedding type adaptation decisions only in generated WAT strings,
because then the compiler cannot reason about them.

Exception behavior also needs a contract. The runtime imports an FFI host
exception tag so foreign imports can communicate host-language errors. A
first-class FFI binding should specify whether host exceptions become Racket
exceptions, external error values, or uncaught traps. The Racket-facing behavior
should be consistent whether the foreign is called directly or through a
procedure wrapper. Tests should include a foreign function that throws and a
Racket handler if exception handling is supported.

Tree shaking should become descriptor-driven. The runtime currently filters
active FFI foreigns based on used primitive names. That is a good start, but
first-class bindings complicate "used." A binding can be used by direct call,
by reference, by export, by callback registration, by module import/export, or
by reflective bridge code. The active-foreign calculation should consume a
single set of used foreign binding names gathered from call lowering and value
reference analysis. If a foreign binding is exported, it must be retained even
if no local direct call exists. If a foreign binding is referenced as a value,
its procedure wrapper and import must be retained.

Module integration is important. A foreign declaration should create a binding
with module-like identity. If a module provides an FFI binding, the export
should expose the Racket wrapper value. If another module requires it, it
should see a normal binding, not reconstruct the host import independently.
This prevents duplicated imports and preserves identity. It also connects to
chapter 5: module normalization should know that an FFI declaration introduces
externally backed runtime bindings.

The console bridge and external FASL support should be reviewed as part of this
work. `$External` values can be formatted as `#<external>` or
`#<external-null>`, and external values can be registered/lookup through the
host bridge. First-class FFI bindings should decide what can cross the bridge.
A host object returned by an FFI call may be serializable only as an external
handle. A Racket procedure converted to an external callback should preserve
arity metadata so host-side errors are useful. These behaviors already exist in
pieces; the FFI binding plan should document them as part of the value model.

The first implementation phase should be analysis-only. Add a report that lists
all FFI declarations, their generated primitive names, arity, argument/return
types, whether they are directly called, whether they are referenced as values,
whether they are exported, whether they survive tree shaking, and whether the
compiler would currently hit a `Reference` or `Store!` `TODO`. Run it on any
existing `.ffi` workloads and on a tiny hand-written test. This report will
tell us whether first-class references are rare or already blocking real code.

The second phase should make FFI references explicit without changing direct
call lowering. Initialize each active FFI callable as a Racket procedure wrapper
global, and compile `Reference` of an FFI binding to that global. Keep direct
operator calls on the existing optimized wrapper path if it already works. Add
tests where a foreign function is bound to a local variable, passed to a
higher-order function, and called through generic `apply` if supported. Also
test `procedure?` on the binding. If this phase is too large, narrow it to
fixed-arity foreign functions with simple number/string adapters.

The third phase should replace the `Store!` `ffi` `TODO` with an explicit
immutable-binding error. This can be earlier if it is local. The important
point is to avoid leaving `TODO` in a path users can reach. A clear error is a
semantic improvement even before mutable foreign variables exist.

The fourth phase should make the descriptor authoritative. Generated imports,
wrapper functions, primitive globals, arity metadata, tree-shaking retention,
and module binding records should all come from the same foreign-binding
summary. This is also the point where primitive metadata cleanup from chapter 8
can help. FFI callables are primitive-like, but they should not be anonymous
extra primitive names with hidden side tables.

The fifth phase can consider non-callable foreign bindings. Some host imports
may be values rather than functions: DOM objects, constants, constructors,
mutable host fields, or capability handles. These should not pretend to be
procedures. Their descriptors need value type, mutability, getter/setter
semantics, and external wrapping policy. This should be separate from callable
FFI, because callable imports already have enough complexity.

Tests should be split by bridge direction. Racket-to-host tests call imported
foreign functions with valid and invalid Racket values. Host-to-Racket tests use
`procedure->external` and callback registration. Value tests store external
results, print them, compare identity if supported, and pass them back to
foreign functions. Binding tests reference a foreign function as a value,
export it, import it, and attempt to assign it. Tree-shaking tests compile a
program with several declared foreigns and verify that unused imports/wrappers
are removed while referenced/exported ones remain.

The biggest risk is confusing host values with Racket values. `$External` is an
opaque wrapper around `externref`; it should not accidentally satisfy
`procedure?` or behave like a Racket struct unless explicitly wrapped. The
second risk is duplicating wrappers: one for direct calls, one for generic
procedure calls, one for exports, and one for the bridge. The descriptor should
make these relationships explicit so a foreign binding has one identity and
multiple lowering views, not multiple unrelated objects. The third risk is
code-size growth. If every foreign declaration emits imports, wrappers,
procedure objects, symbol constants, and bridge metadata whether used or not,
the cost will be visible. Tree shaking must remain part of the design.

The smallest safe first patch is a measurement and diagnostic patch. It should
not change FFI semantics. It should report the current FFI binding universe and
replace reachable `TODO` failures with phase-tagged errors if that is local.
The next implementation patch should target one fixed-arity callable foreign
whose arguments and result use already-supported adapters. The success
criterion is simple: direct calls still work, ordinary reference returns a
procedure value, assignment fails clearly, tree shaking retains only needed
foreigns, and runtime tests still pass.

Review this project by binding behavior, not only by generated WAT. A patch
should say what a foreign declaration introduces into the Racket namespace,
what value a reference produces, what a direct call emits, what happens under
generic apply, how errors are reported, and when the runtime import is retained.
If those answers are clear, FFI has become a first-class part of the compiler.
If the answer is still "it is a primitive unless you reference it," the project
is not finished.
