<INSTRUCTIONS>
# AGENTS.md (web-site-new/)

These conventions apply when working in `web-site-new/`.

## Racket Formatting & Syntax
- Always count delimiters after edits: `()` `[]` `{}` must match separately.
- Use `[]` for `cond` clauses.
- Use `[]` in `let*` binding clauses.
- Avoid `letrec` unless explicitly requested; prefer internal `define` when appropriate.

## WebRacket Constraints
- Do not introduce JavaScript implementations for page behavior. Use WebRacket/DOM bindings instead.
- If using debug logging, keep it minimal and remove it when done.

## New Example Rules
- Do not reuse CSS classes from unrelated example families (for example, avoid using `mathjax-*` classes in non-MathJax examples).
- Give each new example page a dedicated page namespace (`page--<example-name>`) and use example-specific classes where needed.
- Shared utility classes are allowed only when they are intentionally global and documented in `web-site.rkt` styles.
- When porting an example between old/new sites, keep class naming semantics aligned; avoid ad-hoc renames in only one site.
- Keep old/new site example class semantics aligned.
- For any new example, verify visually that styling does not depend on another example page being present.
- If temporary instrumentation is added while debugging an example, remove it before final build.
- Start by planning the data representation before implementing behavior or rendering.
- Involve the user early: present the planned data representation and main interactions before implementation.
- New examples must follow HtDP style.
- Structure web application examples into clear sections: `Model`, `View`, and `Control`.

## Function Comment Style
For exported and internal helper functions, add both:
- A contract comment line:
  - `;; name : contract -> result`
- A purpose comment line that starts with two spaces after `;;`:
  - `;;   Brief purpose sentence.`

Example:
- `;; char-set-member? : char-set? char? -> boolean?`
- `;;   Check whether ch is a member of cs.`

## Control-Flow Style
- Prefer `cond` over nested `if`/`let` patterns when branching logic is non-trivial.
- Prefer internal `define`s inside `cond` branches instead of wrapping branch bodies in `let` just to name intermediates.
- Align right-hand-side expressions in `cond` clauses where it improves readability.
- For consecutive `define` forms, align right-hand-side expressions where it improves readability.

## Debugging
- Prefer small, focused instrumentation that can be removed later.
- Confirm hypotheses with a minimal test program before changing core logic.

## DOM Id Normalization (Prevention)
- Normalize any DOM-provided id or `data-*` value at the boundary: if `external?` then convert with `external-string->string`.
- Convert normalized ids to symbols and use `make-hasheq` for lookup maps; do not mix string and symbol keys.
- Never compare or hash raw `external?` values; normalize first.
- Add/keep a small test (e.g. `test-toc.rkt`) that verifies the normalization and lookup path.

## Docs-Only Build Gotchas
- `documentation.rkt` is shared by `web-site.rkt` and `website-docs-only.rkt`; changes affect both builds.
- `website-docs-only.rkt` intentionally omits example includes/data to keep builds fast; avoid reintroducing them.
- Use the correct build script: `build.sh` for full site, `build-docs-only.sh` for docs-only.
- Hard-reload after rebuilds to avoid stale `web-site.wasm` in the browser cache.
</INSTRUCTIONS>
