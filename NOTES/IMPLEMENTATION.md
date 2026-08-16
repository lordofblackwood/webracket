Source Maps

Motivation
When WebAssembly compilation or runtime errors report only generated labels (e.g. label.1234),
it is hard to connect the error back to the original Racket source. A simple source map makes
it possible to resolve those labels to file/line/column positions.

Usage
After compilation, a label-map file is written next to the wasm file with the suffix
`.wasm.map.sexp`. Each entry maps a generated label to a source location. The
original form can be included explicitly for heavyweight debugging.

Format
The file is an s-expression list starting with `wasm-label-map`. Each entry is:
  (label "<label-id>" (src <path> <line> <column> <span>))

When form payloads are enabled, entries may also contain:
  (form "<printed-form>")

Fields:
- `<label-id>` is the generated label name (e.g. "label.9176").
- `<path>` is the source file path or `unknown` when unavailable.
- `<line>`, `<column>`, `<span>` are integers (0 when unavailable).
- `<printed-form>` is an optional printed representation of the original syntax form.

Example entry:
  (label "label.9176"
         (src "test/test-basics.rkt" 42 7 15))

When you see `label.9176` in a stack trace, search the label-map file for that label to
identify the original source location.

Implementation
The compiler collects label mappings during closure conversion when each abstraction
is lifted into a top-level label. The label is paired with the syntax object of the
original abstraction to extract source location and, when requested, form. The accumulated mappings are
written as an s-expression by the driver after the `.wasm` file is generated.
