# docs-notes

This directory is for design notes, migration notes, investigation notes,
and other compiler/runtime documentation that is useful to keep in the
repository but is not part of the user-facing manuals.

Typical contents:

- design notes such as `DESIGN-*.md`
- implementation-status or migration notes
- experiment writeups
- internal reference material for ongoing compiler/runtime work

Guidelines:

- Keep user-facing documentation in `docs/` or `scribblings/`.
- Keep short task-local scratch notes out of this directory unless they are
  worth preserving for future work.
- Prefer one topic per file.
- Prefer stable descriptive filenames.

Rendering:

- To render `closure-conversion.scrbl` locally, run:
  `raco scribble +m --html --dest html/ closure-conversion.scrbl`

At the moment this directory is an organizational home for such notes.
Existing root-level note files can be moved here incrementally.
