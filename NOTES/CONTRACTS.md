# Erased Contracts

WebRacket currently provides `webracket/contract` as an erased compatibility
layer for Goal 1 module programs.

The provider intentionally exports the same phase-0 value and syntax names as
`racket/contract`, so modules that mention contracts can compile while we work
on the rest of the module ecosystem. It does not enforce contracts, construct
blame objects with real projections, or create chaperones/impersonators.

When the Goal 1 module bridge sees `(require racket/contract)` or
`(require racket/contract/base)`, it currently substitutes this provider instead
of compiling the full installed contract graph. That makes the common contract
entry points usable for module programs that only need erased annotations and
lightweight contract metadata.

## What Works

- `contract`, `define/contract`, `contract-out`, `provide/contract`, and
  `with-contract` preserve the underlying values and exports.
- Common contract combinators such as `->`, `->*`, `case->`, `and/c`, `or/c`,
  `listof`, `vector/c`, `hash/c`, `parameter/c`, and range contracts produce
  inert contract descriptors.
- `contract-name`, `contract-first-order`, `contract-first-order-passes?`, and
  `flat-contract-predicate` provide best-effort metadata for common erased
  descriptors. These checks are useful for library probes, but they do not turn
  contract boundaries into enforcing wrappers.
- First-order checks cover common flat/container shapes including `false/c`,
  `natural-number/c`, `char-in`, `char-in/c`, `string-len/c`,
  `non-empty-listof`, `list*of`, `vector-immutableof`, `box-immutable/c`,
  `parameter/c`, `promise/c`, and `procedure-arity-includes/c`.
- Struct contract forms such as `struct/contract`, `define-struct/contract`,
  and `define-contract-struct` define ordinary structs while erasing field
  contracts. Options such as `#:transparent`, `#:mutable`, and parent-struct
  forms are preserved.
- Several dependent/advanced source shapes are accepted explicitly, including
  `->d`, `dynamic->*`, `cons/dc`, `hash/dc`, `struct/dc`, `values/drop`,
  `vector-immutable/c`, and `with-contract-continuation-mark`.

## Semantic Caveat

The provider is deliberately unsound. For example:

```racket
#lang webracket/base
(require webracket/contract)

(define/contract x integer? "not an integer")
(contract integer? "also not an integer" 'positive 'negative)
```

Both values are accepted unchanged. This is useful for running module-based
programs that carry contract annotations, but it is not suitable as a contract
system.

## Missing Parts

- Real blame tracking and blame-object behavior.
- Chaperone and impersonator wrappers.
- Contract projections and late-negative projections.
- Complete first-order predicate coverage for every exported contract
  constructor.
- Contract-continuation marks beyond preserving simple expression side effects.
- Full semantic compatibility for dependent contracts such as `->i`, `->d`,
  `hash/dc`, and `struct/dc`.
- Some installed libraries that were already expanded with `provide/contract`
  can still expose private `racket/contract` implementation dependencies. The
  compact dashboard keeps diagnostic rows for real modules such as
  `racket/hash`, `racket/format`, and `racket/logging` to keep those gaps
  visible.
- Integration with a future real `racket/contract` provider once the runtime has
  enough chaperone/impersonator support.

## Testing

The current checks are:

- `webify/test-webracket-contract.rkt` compares the exported API with
  `racket/contract`, tests host expansion behavior, and runs bounded WebRacket
  smokes for `webracket/contract`, substituted `racket/contract`, and
  substituted `racket/contract/base`.
- `webify/goal1-dashboard.rkt --case full-contract-erased` checks the compact
  staged-provider row through the Goal 1 dashboard.
- The dashboard also includes diagnostic real-module rows for installed
  libraries that use `racket/contract/base`, so we can distinguish contract
  substitution progress from unrelated provider-resolution gaps.
- Provider extraction now uses a fresh namespace where `racket/contract` and
  `racket/contract/base` are predeclared as erased `webracket/contract`
  providers. That lets installed modules such as `data/queue` expand their
  `provide/contract` forms through WebRacket's erased macros instead of
  Racket's private contract implementation.
- `racket/private/for` is routed to a small WebRacket-owned provider for the
  generic `make-sequence`/`make-do-sequence` protocol and a few validation
  helpers needed by installed provider probes.
