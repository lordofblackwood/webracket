#lang scribble/manual

@(require scribble/manual)

@title{Thematic: Bootstrap Themes for @tt{web-easy}}

@defmodule[thematic]

The @racketmodname[thematic] package converts Bootstrap and Bootswatch
theme CSS into a @tt{web-easy} external theme. It is a theme extraction
tool, not a general Bootstrap compatibility layer.

Thematic reads Bootstrap's theme semantics, computes the values that
Bootstrap would apply in a selected theme root, and emits @tt{--we-*}
tokens plus the shared @tt{web-easy} theme scaffold. The generated
stylesheet is meant to be loaded after @tt{web-easy-core.css} and used
with a class on @tt{html}, such as @tt{we-theme-vapor}.

@section{Design Goal}

The goal is to make existing Bootstrap themes usable by @tt{web-easy}
applications while keeping @tt{web-easy} components native. Thematic
does not copy Bootstrap selectors into an application and does not
require @tt{.btn}, @tt{.card}, or @tt{.navbar} markup at runtime.

Instead, the generated theme maps Bootstrap design intent into
@tt{web-easy} tokens:

@itemlist[
  @item{global color, background, typography, radius, border, and shadow tokens}
  @item{semantic companions such as primary, success, warning, and danger surfaces}
  @item{component tokens for buttons, cards, tables, alerts, navs, forms, dialogs, and related chrome}
  @item{top-level font imports needed by the source theme}
]

This split keeps the architecture general: Bootstrap and Bootswatch CSS
are inputs, @tt{web-easy} tokens are outputs, and parser/computed-style
mechanics stay in @tt{parsers/css}.

@section{Command Line}

The generator can be run as a Racket library module:

@verbatim|{
racket -l thematic -- \
  --input path/to/bootstrap.css \
  --output path/to/theme-vapor.css \
  --theme-class we-theme-vapor
}|

Inside the WebRacket checkout, the repository launcher is equivalent:

@verbatim|{
racket -c tools/thematic \
  --input thematic/original/vapor/bootstrap.css \
  --output thematic/generated/vapor.css \
  --theme-class we-theme-vapor
}|

The generated stylesheet should be loaded after the @tt{web-easy} core
stylesheet:

@verbatim|{
<link rel="stylesheet" href="web-easy-core.css">
<link rel="stylesheet" href="theme-vapor.css">
}|

Then put the generated theme class on @tt{html}:

@verbatim|{
<html class="we-theme-vapor">
}|

@subsection{Generator Options}

@itemlist[
  @item{@tt{--input path}: required path to the Bootstrap or Bootswatch CSS file.}
  @item{@tt{--output path}: required path for the generated @tt{web-easy} theme CSS. Parent directories are created as needed.}
  @item{@tt{--theme-class class-name}: CSS class to emit on the @tt{html} selector. The default is @tt{we-theme-bootstrap}.}
  @item{@tt{--selector selector}: Bootstrap theme root to read. Supported values are @tt{:root}, @tt{[data-bs-theme=light]}, @tt{[data-bs-theme=dark]}, @tt{[data-theme=name]}, and @tt{.theme-name}. The default is @tt{:root}.}
  @item{@tt{--source-dialect dialect}: source token dialect to normalize before parsing. Supported values are @tt{auto}, @tt{bootstrap}, @tt{tabler}, @tt{pico}, @tt{bulma}, and @tt{daisyui}. The default is @tt{auto}.}
  @item{@tt{--report path}: optional path for a machine-readable JSON report describing the conversion.}
  @item{@tt{--accent-boost}: optional enhancement mode for themes whose subtle accent surfaces become too quiet in @tt{web-easy}.}
]

The default mode is strict: Thematic prefers authored Bootstrap values
and derives only the missing @tt{web-easy} companions. Use
@tt{--accent-boost} only when a theme needs stronger low-contrast
accent companions. Boosted output is intentionally opt-in so that
strict conversion remains predictable.

@subsection{Generation Reports}

Use @tt{--report} to write a machine-readable report beside a generated
theme:

@verbatim|{
racket -c tools/thematic \
  --input thematic/original/vapor/bootstrap.css \
  --output thematic/generated/vapor.css \
  --theme-class we-theme-vapor \
  --report thematic/generated/vapor.report.json
}|

The report uses schema @tt{thematic.generation-report.v1}. It includes
the requested and resolved source dialect, selected theme root, import
count, emitted token names, and any source-framework variables that
leaked into the generated stylesheet. A generated theme is considered
standalone when @tt{sourceVariableLeaks} is empty.

@section{Token Contract}

Thematic exposes its current generated @tt{--we-*} token inventory as
JSON:

@verbatim|{
racket -l thematic/token-contract
}|

Inside the WebRacket checkout, this launcher is equivalent:

@verbatim|{
racket -c tools/thematic-token-contract \
  --output thematic/generated/token-contract.json
}|

The token contract uses schema @tt{thematic.token-contract.v1}. It is
generated from the same token builder used by normal theme generation,
so it is a public contract artifact rather than a hand-maintained list.

@section{Bootstrap Scoping Tool}

@defmodule[thematic/scope-bootstrap]

The @racketmodname[thematic/scope-bootstrap] module provides a small
companion tool for comparison pages. It rewrites a Bootstrap stylesheet
so selectors apply only under one wrapper selector.

@verbatim|{
racket -l thematic/scope-bootstrap -- \
  --input path/to/bootstrap.css \
  --output path/to/bootstrap-vapor-scoped.css \
  --scope .bs-preview
}|

The WebRacket checkout also provides:

@verbatim|{
racket -c tools/thematic-scope \
  --input thematic/original/vapor/bootstrap.css \
  --output thematic/generated/bootstrap-vapor-scoped.css \
  --scope .bs-preview
}|

The scoper rewrites ordinary selectors, root-like selectors
(@tt{:root}, @tt{html}, and @tt{body}), and selectors inside recursive
CSS at-rules such as media, supports, layer, and container rules. It
preserves raw at-rule bodies such as font-face and keyframes rules.

@section{What Thematic Reads}

Thematic uses @tt{parsers/css} for CSS parsing, exact
selector-group queries, reduced computed-style lookup, custom-property
computation, and limited shorthand expansion. The generator consumes
both Bootstrap custom properties and selected component rules.

Important source values include:

@itemlist[
  @item{body foreground, background, background image, and text shadow}
  @item{semantic colors such as @tt{--bs-primary}, @tt{--bs-success}, @tt{--bs-warning}, and @tt{--bs-danger}}
  @item{semantic companion tokens such as @tt{--bs-*-text-emphasis}, @tt{--bs-*-bg-subtle}, and @tt{--bs-*-border-subtle}}
  @item{font family, heading typography, font weights, line height, and letter spacing}
  @item{border widths, border colors, radii, shadows, and component spacing}
  @item{component-level styles where Bootstrap expresses visual intent outside root custom properties}
]

Top-level import rules are preserved and emitted before the
generated theme body. This is important for Bootswatch themes that load
Google Fonts or companion CSS.

@section{Tabler Sources}

Thematic can also read Tabler Free's compiled CSS by using the
@tt{tabler} source dialect:

@verbatim|{
racket -c tools/thematic \
  --input path/to/tabler.css \
  --output path/to/theme-tabler.css \
  --theme-class we-theme-tabler \
  --source-dialect tabler
}|

Tabler is Bootstrap-based, but its custom properties use the
@tt{--tblr-*} prefix. The @tt{tabler} dialect normalizes those names to
Bootstrap-shaped @tt{--bs-*} names before Thematic's existing
Bootstrap-to-@tt{web-easy} mapping runs.

The WebRacket checkout includes an opt-in helper:

@verbatim|{
./thematic/fetch-tabler-local.sh
}|

That helper downloads Tabler CSS into @filepath{thematic/original/tabler}
and writes Tabler-derived generated CSS into ignored local output paths.
These files are intentionally not committed. Tabler Free is MIT
licensed, so redistributing those downloaded inputs or generated
derivatives would require carrying Tabler's copyright and license
notices. Thematic keeps the support code and workflow, not the Tabler
assets.

@section{Pico CSS Sources}

Thematic can read Pico CSS v2 compiled stylesheets by using the
@tt{pico} source dialect:

@verbatim|{
racket -c tools/thematic \
  --input path/to/pico.jade.css \
  --output path/to/theme-pico-jade.css \
  --theme-class we-theme-pico-jade \
  --source-dialect pico
}|

Pico is not Bootstrap. It is a semantic HTML CSS framework whose themes
are expressed with @tt{--pico-*} custom properties. The @tt{pico}
dialect rewrites Pico light/dark theme selectors into Bootstrap-shaped
theme selectors and adds a semantic bridge that maps Pico variables and
semantic element styling into the Bootstrap-shaped inputs Thematic
already knows how to convert.

When a scoped Pico theme only overrides part of the base variable set,
Thematic seeds that scope with inherited base variables before applying
the authored overrides. This keeps exact selector extraction faithful to
how the CSS would behave in a browser.

The WebRacket checkout includes an opt-in helper:

@verbatim|{
./thematic/fetch-pico-local.sh
}|

That helper downloads Pico's precompiled color themes into
@filepath{thematic/original/pico} and writes generated @tt{web-easy}
themes into ignored local output paths. By default it knows Pico's 20
color families and generates light and dark @tt{web-easy} themes for
each selected color. Set @tt{PICO_THEMES} or @tt{PICO_MODES} to narrow a
local run.

The downloaded Pico inputs and Pico-derived generated CSS are
intentionally not committed. Pico CSS is MIT licensed, so redistributing
those downloaded inputs or generated derivatives would require carrying
Pico's copyright and license notices. Thematic keeps the support code
and workflow, not the Pico assets.

@section{Bulma Sources}

Thematic can read Bulma v1 compiled stylesheets by using the
@tt{bulma} source dialect:

@verbatim|{
racket -c tools/thematic \
  --input path/to/bulma.css \
  --output path/to/theme-bulma-dark.css \
  --theme-class we-theme-bulma-dark \
  --selector "[data-theme=dark]" \
  --source-dialect bulma
}|

Bulma is not Bootstrap. It is a CSS framework whose themes are
collections of @tt{--bulma-*} custom properties, including the built-in
@tt{light} and @tt{dark} themes. The @tt{bulma} dialect adds a semantic
bridge that maps Bulma scheme variables, semantic colors, typography,
radii, borders, shadows, and common component styling into
Bootstrap-shaped inputs before Thematic emits @tt{web-easy} tokens.

Bulma's compiled dark theme is intentionally partial: it overrides the
base variables that differ from light mode. To make extraction work from
exact theme selectors such as @tt{[data-theme=dark]}, Thematic seeds
scoped Bulma theme roots with inherited base variables before applying
the source theme overrides.

The WebRacket checkout includes an opt-in helper:

@verbatim|{
./thematic/fetch-bulma-local.sh
}|

That helper downloads Bulma CSS into
@filepath{thematic/original/bulma} and writes generated @tt{web-easy}
themes into ignored local output paths. By default it generates
@tt{bulma-light.css} and @tt{bulma-dark.css}; set @tt{BULMA_THEMES} to
narrow a local run.

The downloaded Bulma input and Bulma-derived generated CSS are
intentionally not committed. Bulma is MIT licensed, so redistributing
those downloaded inputs or generated derivatives would require carrying
Bulma's copyright and license notices. Thematic keeps the support code
and workflow, not the Bulma assets.

After generating local Bulma themes, open
@filepath{thematic/bulma-example.html} to see the generated @tt{Light}
and @tt{Dark} themes applied to a small @tt{web-easy} component sample.

@section{daisyUI Sources}

Thematic can read daisyUI v5 compiled theme stylesheets by using the
@tt{daisyui} source dialect:

@verbatim|{
racket -c tools/thematic \
  --input path/to/themes.css \
  --output path/to/theme-daisyui-synthwave.css \
  --theme-class we-theme-daisyui-synthwave \
  --selector "[data-theme=synthwave]" \
  --source-dialect daisyui
}|

daisyUI is not Bootstrap. It is a Tailwind CSS component library whose
themes are expressed with custom properties such as
@tt{--color-base-100}, @tt{--color-primary},
@tt{--radius-field}, and @tt{--border}. The @tt{daisyui} dialect adds a
semantic bridge that maps those variables into Bootstrap-shaped inputs
before Thematic's existing Bootstrap-to-@tt{web-easy} conversion runs.

The WebRacket checkout includes an opt-in helper:

@verbatim|{
./thematic/fetch-daisyui-local.sh
}|

That helper downloads daisyUI's @tt{themes.css} into
@filepath{thematic/original/daisyui} and writes generated
@tt{web-easy} themes into ignored local output paths. By default it
knows the 35 bundled daisyUI v5 themes and generates one @tt{web-easy}
theme for each selected @tt{[data-theme=name]} root. Set
@tt{DAISYUI_THEMES} to narrow a local run.

The downloaded daisyUI input and daisyUI-derived generated CSS are
intentionally not committed. daisyUI is MIT licensed, so redistributing
those downloaded inputs or generated derivatives would require carrying
daisyUI's copyright and license notices. Thematic keeps the support code
and workflow, not the daisyUI assets.

After generating local daisyUI themes, open
@filepath{thematic/daisyui-example.html} to see the generated
@tt{Synthwave}, @tt{Cupcake}, and @tt{Dark} themes applied to a small
@tt{web-easy} component sample.

@section{Generated Output}

The output stylesheet has three conceptual parts:

@itemlist[
  @item{preserved top-level imports, when present}
  @item{an @tt{html.<theme-class>} block containing generated @tt{--we-*} tokens}
  @item{the shared @tt{web-easy} theme scaffold, specialized to the requested theme class}
]

The generated CSS targets @tt{web-easy} classes, not Bootstrap classes.
For example, Bootstrap button and card semantics become tokens and
rules consumed by @tt{.we-button}, @tt{.we-card}, @tt{.we-alert}, and
other @tt{web-easy} component classes.

Some @tt{--we-*} values are direct mappings from Bootstrap custom
properties. Others are derived when Bootstrap does not publish an
equivalent token. Derived values are chosen to preserve the source
theme's personality while keeping @tt{web-easy} components readable.

@subsection{Output Contract}

A generated theme is intended to be standalone after
@tt{web-easy-core.css}. Source dialect bridges may use source-framework
variables internally while normalizing CSS, but the emitted stylesheet
should not require those variables at runtime. For example, generated
Pico, Bulma, Tabler, and daisyUI themes should not contain unresolved
@tt{var(--pico-*)}, @tt{var(--bulma-*)}, @tt{var(--tblr-*)}, or
@tt{var(--color-*)} references.

The emitted stylesheet may still contain @tt{var(--we-*)} references.
Those are part of the @tt{web-easy} theme scaffold and are expected.

@subsection{Opt-In External Source Checks}

The repository includes an opt-in smoke script for real external CSS
sources:

@verbatim|{
THEMATIC_EXTERNAL_SOURCES=1 ./thematic/check-external-sources-local.sh
}|

The script downloads local MIT-licensed fixtures for Tabler, Pico,
Bulma, and daisyUI, generates @tt{web-easy} themes, and checks that the
emitted CSS does not retain source-framework variable references. The
downloaded inputs and generated external-source outputs remain in
ignored local paths.

@section{Validation Workflow}

The package includes a side-by-side Bootstrap versus @tt{web-easy}
comparison harness under @filepath{pkgs/thematic/test}.

To regenerate reference fixtures:

@verbatim|{
./thematic/regenerate.sh
}|

To run the computed-style parity check:

@verbatim|{
make smoke-thematic-bootstrap-compare
}|

To also write a ranked JSON parity dashboard:

@verbatim|{
THEMATIC_COMPARE_REPORT=thematic/generated/parity-dashboard.json \
  make smoke-thematic-bootstrap-compare
}|

The dashboard uses schema @tt{thematic.parity-dashboard.v1}. It ranks
mismatches by theme, section heading, property, and case severity so the
next visual parity pass can start from the highest-signal computed-style
differences.

The generated comparison page is:

@verbatim|{
pkgs/thematic/test/test-browser-theme-thematic-bootstrap-compare.html
}|

When served from the repository root with @tt{raco static-web}, the URL
has this shape:

@verbatim|{
http://127.0.0.1:8765/pkgs/thematic/test/test-browser-theme-thematic-bootstrap-compare.html?theme=vapor
}|

The comparison harness intentionally checks computed styles first. Use
screenshots as supporting evidence, not as the primary source of truth,
when computed-style inspection is available.

@section{Refactoring Roadmap}

The next structural improvement is to split the current implementation
into smaller dialect and reporting modules:

@itemlist[
  @item{@tt{thematic/private/dialects/bootstrap.rkt}: native Bootstrap and Bootswatch extraction}
  @item{@tt{thematic/private/dialects/tabler.rkt}: Tabler token normalization}
  @item{@tt{thematic/private/dialects/pico.rkt}: Pico selector rewriting and inheritance seeding}
  @item{@tt{thematic/private/dialects/bulma.rkt}: Bulma selector discovery and inheritance seeding}
  @item{@tt{thematic/private/dialects/daisyui.rkt}: daisyUI theme bridge}
  @item{@tt{thematic/private/report.rkt}: generation reports, token-contract JSON, and source-variable leak checks}
]

That split should be mechanical: move code behind the existing
@tt{normalize-theme-source}, @tt{resolve-source-dialect}, report, and
token-contract boundaries without changing generated CSS behavior.

@section{Adding A Theme Fixture}

For a new Bootswatch theme fixture:

@itemlist[
  @item{download the theme's compiled @tt{bootstrap.css} into @filepath{thematic/original/<theme>/bootstrap.css}}
  @item{add the theme name to @filepath{thematic/regenerate.sh}}
  @item{add the theme to the comparison page and checker tables in @filepath{pkgs/thematic/test}}
  @item{run @tt{./thematic/regenerate.sh}}
  @item{run @tt{make smoke-thematic-bootstrap-compare}}
]

The important policy is that fixes should stay at the smallest correct
layer:

@itemlist[
  @item{comparison markup fixes belong in the comparison page}
  @item{shared @tt{web-easy} component behavior belongs in the theme scaffold}
  @item{Bootstrap-to-@tt{web-easy} semantic mapping belongs in @racketmodname[thematic]}
  @item{general CSS parsing or computed-style mechanics belong in @tt{parsers/css}}
]

@section{Limitations}

Thematic currently works from compiled CSS. It does not read SCSS
sources, run Bootstrap JavaScript, or promise exact Bootstrap layout
compatibility. The output is a native @tt{web-easy} theme that should
carry the source theme's colors, typography, spacing, borders, shadows,
and component personality into @tt{web-easy} components.
