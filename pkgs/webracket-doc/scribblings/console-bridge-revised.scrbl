#lang scribble/manual

@(require scribble-tools
          "webracket-scribble-utils.rkt")

@title[#:tag "console-bridge-revised"]{The Browser Console Bridge - Revised}

The browser console bridge is an opt-in debugging helper for generated
browser pages. When enabled, the page installs @tt{globalThis.WR}, a small
JavaScript entry point that can look up selected WebRacket bindings, call
selected WebRacket functions, and list the names available to the bridge.

It is useful while developing browser examples because it lets you inspect a
running WebRacket page from DevTools without adding temporary logging and
rebuilding for every small question.

It is not a general Racket evaluator. Calls such as @tt{WR("counter")} look up
a binding named @tt{counter}; they do not read and evaluate Racket source text.

@section{Enable The Bridge}

Compile a browser program with @(flag "--console-bridge"). Use
@(flag "--dest") to keep generated files in one directory:

@shellblock{
webracket --browser --console-bridge --dest generated counter.rkt
}

This writes files such as @tt{generated/counter.html} and
@tt{generated/counter.wasm}. Serve the directory that contains the generated
output, open the page in a browser, and then open DevTools.

If the bridge was installed successfully, the browser console can use
@tt{WR}:

@verbatim|{
WR.help()
WR.names()
}|

@section{Small Example}

@filebox["counter.rkt"
@verbatim|{
#lang webracket/base

(define counter 0)

(define (increment! amount)
  (set! counter (+ counter amount))
  counter)

(define (current-counter)
  counter)

(display "counter page ready")
}|]

Compile it:

@shellblock{
webracket --browser --console-bridge --dest generated counter.rkt
}

Serve the project directory, then open @tt{generated/counter.html}. In the
browser console:

@verbatim|{
> WR("counter")
0
> WR("increment!", 5)
5
> WR.call("current-counter")
5
}|

There is also a checked-in example at
@filepath{examples/console-bridge/console-bridge.rkt}.

@section{What WR Does}

The bridge exposes a JavaScript function named @tt{WR}. Its common operations
are:

@itemlist[
  @item{@tt{WR(name)} looks up a binding and prints the WebRacket result.}
  @item{@tt{WR(name, ...args)} calls a binding as a function.}
  @item{@tt{WR.call(name, ...args)} always performs a function call, even with
        zero arguments.}
  @item{@tt{WR.value(name, ...args)} returns the converted JavaScript value
        without automatic console printing.}
  @item{@tt{WR.raw(name, ...args)} returns the full result object.}
  @item{@tt{WR.names()} lists exposed names.}
  @item{@tt{WR.search(query)} searches exposed names.}
  @item{@tt{WR.namesDetailed()} lists exposed names with metadata.}
  @item{@tt{WR.write(name, ...args)} prints the WebRacket representation.}
  @item{@tt{WR.print(name, ...args)} uses JavaScript console inspection for the
        converted value.}
  @item{@tt{WR.format(value)} formats a JavaScript value with WebRacket's
        printer.}
  @item{@tt{WR.help()} prints a usage summary.}]

@section{Lookup Versus Call}

The convenience function @tt{WR} chooses between lookup and call based on the
number of arguments.

@itemlist[
  @item{@tt{WR("current-counter")} looks up the function value.}
  @item{@tt{WR.call("current-counter")} calls the zero-argument function.}
  @item{@tt{WR("increment!", 1)} calls @tt{increment!} with one argument.}]

Use @tt{WR.call} when you want the intent to be unambiguous.

@section{Result Objects}

Use @tt{WR.raw} when you need to distinguish successful lookups from failures.
A typical successful result looks like this:

@verbatim|{
> WR.raw("counter")
{
  ok: true,
  kind: "value",
  value: 5,
  printed: "5",
  error: "",
  message: "",
  operation: "ref",
  name: "counter",
  args: []
}
}|

A missing binding returns a structured failure instead of pretending that the
lookup succeeded:

@verbatim|{
> WR.raw("does-not-exist")
{
  ok: false,
  kind: "missing-binding",
  value: false,
  printed: "",
  error: "...",
  message: "...",
  operation: "ref",
  name: "does-not-exist",
  args: []
}
}|

@section{Values Across The Boundary}

When @tt{WR} returns a value, WebRacket converts it to a JavaScript value where
possible. For example:

@itemlist[
  @item{fixnums and flonums become JavaScript numbers;}
  @item{strings become JavaScript strings;}
  @item{vectors become JavaScript arrays;}
  @item{booleans become JavaScript booleans;}]

The result object also keeps @tt{printed}, a WebRacket-style representation of
the value, which is often easier to read when debugging Racket data.

@section{Which Names Are Exposed}

The bridge exposes top-level bindings from the compiled browser program. That
includes definitions from your source file and some bindings that are present
because the compiled program uses them.

Local variables are not exposed. In this example, @tt{counter} and
@tt{increment!} may be visible through @tt{WR}, but @tt{temporary} is not:

@filebox["example.rkt"
@verbatim|{
#lang webracket/base

(define counter 0)

(define (increment! amount)
  (let ([temporary (* amount 2)])
    (set! counter (+ counter temporary))
    counter))
}|]

Use @tt{WR.names()} and @tt{WR.namesDetailed()} to see what the generated page
actually exposes.

@section{When To Use It}

Use the console bridge when you want to inspect or poke at a running browser
page during development.

It is less appropriate when:

@itemlist[
  @item{you need a general REPL for arbitrary Racket expressions;}
  @item{you want a stable application API for JavaScript code;}
  @item{you do not want the page to publish debugging hooks globally.}]

Because it installs a global debugging helper, the bridge is disabled by
default.

@section{Troubleshooting}

If @tt{WR} is missing in the browser console, check these first:

@itemlist[
  @item{Was the page compiled with @(flag "--console-bridge")?}
  @item{Did the page finish loading? Try @tt{WR.help()} after the page is ready.}
  @item{Are you serving the generated files you just built?}
  @item{Did the browser load the generated @tt{.wasm} file successfully?}]

If a lookup fails, start with:

@verbatim|{
WR.raw("name-you-expect")
WR.names()
WR.namesDetailed()
}|

Those calls usually tell you whether the name is missing, spelled differently,
or present because it came from generated support code.
