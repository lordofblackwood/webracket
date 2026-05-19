# Erased Contracts

WebRacket currently provides `webracket/contract` as an erased compatibility
layer for Goal 1 module programs.

The provider intentionally exports the same phase-0 value and syntax names as
`racket/contract`, so modules that mention contracts can compile while we work
on the rest of the module ecosystem. It does not enforce contracts, construct
blame objects with real projections, or create chaperones/impersonators.

## What Works

- `contract`, `define/contract`, `contract-out`, `provide/contract`, and
  `with-contract` preserve the underlying values and exports.
- Common contract combinators such as `->`, `->*`, `case->`, `and/c`, `or/c`,
  `listof`, `vector/c`, `hash/c`, `parameter/c`, and range contracts produce
  inert contract descriptors.
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
- Contract projections, late-negative projections, and first-order checks.
- Contract-continuation marks beyond preserving simple expression side effects.
- Full semantic compatibility for dependent contracts such as `->i`, `->d`,
  `hash/dc`, and `struct/dc`.
- Integration with a future real `racket/contract` provider once the runtime has
  enough chaperone/impersonator support.

## Testing

The current checks are:

- `webify/test-webracket-contract.rkt` compares the exported API with
  `racket/contract`, tests host expansion behavior, and runs a bounded
  WebRacket smoke for advanced erased source shapes.
- `webify/goal1-dashboard.rkt --case full-contract-erased` checks the compact
  staged-provider row through the Goal 1 dashboard.
