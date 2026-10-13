#lang scribble/manual

@(require scribble-tools
          "webracket-scribble-utils.rkt")

@title[#:tag "tools"]{Tools}

WebRacket comes with a few tools for building programs and debugging browser
output.

Use this chapter as a quick guide. The tool pages later in the manual give
more detail.

@section{Overview}

Most tools fit into one of three jobs:

@itemlist[
  @item{compile a Racket source file to WebAssembly}
  @item{inspect a running browser page}
  @item{map browser errors back to generated labels and source locations}
]

For debugging, always keep the generated files from the same build together.
The @tt{.wasm} file and the @tt{.wasm.map.sexp} file must match.

@section{Command-Line Compiler}

The main tool is the WebRacket compiler:

@shellblock{
webracket --browser program.rkt
}

You can also run it as a @tt{raco} command:

@shellblock{
raco webracket --browser program.rkt
}

In browser mode, the compiler writes files such as:

@itemlist[
  @item{@tt{program.html}}
  @item{@tt{program.wasm}}
  @item{@tt{program.wat}}
  @item{@tt{program.wasm.map.sexp}}
]

In Node mode, it writes a @tt{.js} host file instead of a browser page:

@shellblock{
webracket --node --run program.rkt
}

Use @shell-code{--dest <dir>} to keep generated files in one directory:

@shellblock{
webracket --browser --dest generated program.rkt
}

@section{Console Bridge}

The console bridge is useful for day-to-day browser debugging.

Compile with @(flag "--console-bridge"):

@shellblock{
webracket --browser --console-bridge program.rkt
}

Then open the generated page in a browser and open DevTools. The page installs
@tt{WR} in the JavaScript console.

You can use @tt{WR} to inspect and call exposed WebRacket bindings:

@verbatim|{
WR("counter")
WR("increment!", 1)
WR.names()
WR.help()
}|

The console bridge is not a Racket evaluator. It looks up bindings in the
running program.

@section{Callback Source-Map Lookup}

Some browser or Node errors include a WebRacket debug label:

@verbatim[#:indent 2]{
debug-id: label.4054
}

Use @tt{tools/find-callback-source.rkt} when you already have a label:

@shellblock{
racket tools/find-callback-source.rkt program.wasm.map.sexp label.4054
}

The tool prints the source file, line, column, and span recorded for that
label.

If the map was built with source forms, add @(flag "--show-form"):

@shellblock{
racket tools/find-callback-source.rkt --show-form program.wasm.map.sexp label.4054
}

@section{Browser Wasm Frame Lookup}

Some browser stack traces do not include a @tt{debug-id}. They only show wasm
function indexes:

@verbatim[#:indent 2]{
wasm-function[6785]:0x260d1e
}

Use @tt{tools/wasm-frame-source.rkt} for those frames:

@shellblock{
racket tools/wasm-frame-source.rkt program.wasm program.wasm.map.sexp \
  'wasm-function[6785]:0x260d1e'
}

You can pass more than one frame:

@shellblock{
racket tools/wasm-frame-source.rkt program.wasm program.wasm.map.sexp \
  'wasm-function[3690]:0x1774e2' \
  'wasm-function[6785]:0x260d1e'
}

The tool reports:

@itemlist[
  @item{the wasm function index}
  @item{the generated label, such as @tt{label.58582}}
  @item{the source-map entry, if one exists}
  @item{a clear message when the label is not in the source map}
  @item{nearby source-mapped labels by function index, when useful}
]

This tool reads the @tt{.wasm} binary directly. It does not parse generated
@tt{.wat} text with Racket @racket[read].

@section{Notes For Debugging Builds}

Use the files from the failing build. Labels are only stable within one build.

Prefer @tt{tools/wasm-frame-source.rkt} for browser frames that name
@tt{wasm-function[N]}. Prefer @tt{tools/find-callback-source.rkt} when the
error already gives you @tt{debug-id: label.N}.

If a label is missing from @tt{program.wasm.map.sexp}, that is useful
information. It usually means the generated function was not recorded with a
source location, or the map file does not match the wasm file.
