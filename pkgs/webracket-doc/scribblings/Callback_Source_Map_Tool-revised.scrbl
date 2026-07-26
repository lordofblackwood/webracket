#lang scribble/manual

@(require scribble-tools
          "webracket-scribble-utils.rkt")

@title{Callback Source-Map Tool - Revised}

The callback source-map tool helps connect a browser or Node callback error
back to the WebRacket source that produced the callback.

When a generated callback fails, WebRacket may print a debug label such as
@tt{label.4054}. The compiler records those labels in the generated
@tt{.wasm.map.sexp} file. Use @tt{tools/find-callback-source.rkt} to look up
the label and print the corresponding source location.

@section{When To Use It}

Use this tool when a callback error includes a @tt{debug-id}:

@verbatim[#:indent 2]{
WebRacket callback error
  kind: arity-mismatch
  name: on-click
  id: 0
  debug-id: label.4054
  expected: 0
  argc: 1
  detail: callback arity mismatch
}

The label is only meaningful for the build that produced it. Use the
@tt{.wasm.map.sexp} file generated with the failing @tt{.wasm} file.

@section{Basic Use}

Run the tool with the map file and the label:

@shellblock{
racket tools/find-callback-source.rkt path/to/program.wasm.map.sexp label.4054
}

The output includes the label, source path, source line and column, span, and
any alias target recorded with @tt{same-as}.

Example output:

@verbatim[#:indent 2]{
label: label.4054
source: /path/to/file.rkt:107:2
span: 135
}

@section{Showing The Source Form}

If the map was generated with form payloads, pass @(flag "--show-form") to
print the recorded source form too:

@shellblock{
racket tools/find-callback-source.rkt --show-form path/to/program.wasm.map.sexp label.4054
}

Example output:

@verbatim[#:indent 2]{
label: label.4054
source: /path/to/file.rkt:107:2
span: 135
form: "(let-values ...)"
}

Source locations do not require form payloads. If the map was generated
without @(flag "--label-map-forms"), the location lookup still works, but
@(flag "--show-form") may have no form to print.

@section{Typical Workflow}

@itemlist[
  @item{Reproduce the callback error.}
  @item{Copy the @tt{debug-id} label from the error message.}
  @item{Find the @tt{.wasm.map.sexp} file produced with the failing build.}
  @item{Run @tt{tools/find-callback-source.rkt} with the map file and label.}
  @item{Use @(flag "--show-form") when you need to inspect the recorded form
        and the map was generated with form payloads.}]

@section{Notes}

@itemlist[
  @item{The tool is read-only. It does not modify source files or map files.}
  @item{Labels are build-local. Rebuilds can assign different labels.}
  @item{If the tool reports @tt{same-as}, that means the label is an alias for
        another recorded label.}
  @item{A missing label usually means the wrong @tt{.wasm.map.sexp} file was
        used, or the error came from a different build.}]
