#lang scribble/manual

@title{WebRacket for Racket Programmers - Revised}

This revised chapter describes WebRacket from the perspective of a Racket
programmer using the current module-oriented workflow.

@section{Overview}

@margin-note{WebRacket programs can also run under Node.js, but browser output
is the main target for interactive examples.}

WebRacket lets you write Racket programs and run them on a custom runtime
compiled to WebAssembly. It uses Racket's reader, expander, and macro system
at compile time, then lowers the expanded program to WebAssembly and a small
host file for either the browser or Node.js.

New WebRacket programs should usually be written as modules:

@filebox["hello.rkt"
@verbatim|{
#lang webracket/base

(require web-easy)

(define page
  (window
   (container
    (text "Hello from WebRacket"))))

(mount-renderer! (render page))
}|]

Keep this in mind:

@itemlist[
  @item{compile-time Racket is ordinary host Racket;}
  @item{run-time Racket is WebRacket's WebAssembly runtime;}
  @item{browser and Node integration go through generated host support code;}
  @item{files and assets are made available through WebRacket's virtual
        filesystem, not arbitrary host filesystem access.}
]

@section{The Compilation Pipeline}

A WebRacket module is processed in several stages:

@itemlist[
  @item{The source file is read and expanded by Racket.}
  @item{The module graph and required WebRacket support code are extracted.}
  @item{The expanded program is lowered through WebRacket's compiler passes.}
  @item{The compiler emits WebAssembly text (WAT) for the program module.}
  @item{@tt{wasm-tools} assembles the program WAT into a @tt{.wasm} module;
        split-runtime output also uses reusable runtime and FFI sidecar
        modules.}
  @item{WebRacket writes a host file: JavaScript for Node mode, or HTML for
        browser mode.}
]

Because the Racket expander is used, macros and compile-time libraries run in
the normal host Racket environment. A macro can use ordinary Racket libraries
at phase 1, even when the generated run-time code must use only the Racket
operations that WebRacket supports.

@section{What Is The Same}

Many familiar Racket ideas carry over:

@itemlist[
  @item{Programs use Racket syntax and the Racket expander.}
  @item{Macros, including macros built with @racket[syntax-parse], run at
        compile time.}
  @item{Core expression forms such as @racket[lambda], @racket[if],
        @racket[let], @racket[match], and @racket[for] are supported in the
        module workflow.}
  @item{Tail calls and multiple values are supported.}
  @item{Common values such as numbers, characters, pairs, vectors, treelists,
        strings, bytes, symbols, keywords, boxes, structures, procedures, and
        mutable and immutable hash tables are represented by the WebRacket
        runtime. Immutable hash table variants include @racket[hasheq],
        @racket[hasheqv], @racket[hash], and @racket[hashalw].}
  @item{You can use modules as you would in normal Racket.}
]

@section{What Is Different}

WebRacket programs do not run on Racket's usual runtime system. They run on a
custom WebAssembly runtime, usually inside a browser page. That creates some
important differences:

@itemlist[
  @item{@bold{Runtime coverage is partial.} WebRacket implements a growing
        subset of Racket's runtime. Some primitives and libraries are not yet
        available, and some features have WebRacket-specific limitations.}
  @item{@bold{Browser programs are sandboxed.} They cannot read arbitrary host
        files or directories. Use the virtual filesystem options to preload
        files, URLs, inline data, directories, or tar archives.}
  @item{@bold{Continuations are limited.} Full continuations such as
        @racket[call/cc] are not part of the current runtime model.}
  @item{@bold{No Racket threads or places.} Browser programs run in the
        browser's JavaScript/WebAssembly execution model.}
  @item{@bold{Numbers are not the full Racket tower.} Fixnums and flonums are
        the main supported numeric representations.}
  @item{@bold{Host interaction is explicit.} DOM access, browser APIs,
        JavaScript callbacks, and console interaction go through WebRacket
        libraries and generated host support code.}
]

The practical rule is: if something happens at compile time, you are in host
Racket; if something happens after the generated @tt{.wasm} starts, you are in
WebRacket's runtime.

@section{Module-Based Programs}

New WebRacket code should normally use a @tt{#lang webracket/base} module.
Import libraries with @racket[require]:

@filebox["status.rkt"
@verbatim|{
#lang webracket/base

(require browser/dom)

(define status (document-create-element "div"))
(element-set-text-content! status "ready")
(body-append-child! status)
}|]

Local sibling modules work too:

@filebox["model.rkt"
@verbatim|{
#lang webracket/base

(provide message)

(define message "Hello from a sibling module")
}|]

@filebox["main.rkt"
@verbatim|{
#lang webracket/base

(require "model.rkt"
         web-easy)

(mount-renderer!
 (render
  (window
   (container
    (text message)))))
}|]

@section{Legacy Top-Level Programs}

Older WebRacket examples used a top-level style based on forms such as
@racket[include-lib]. In that model, library code was inserted into one large
top-level program:

@racketblock[
(include-lib web-easy)

(mount-renderer!
 (render
  (window
   (container
    (text "legacy style")))))
]

That style is still useful for understanding older examples and compatibility
code, but it should not be the first model for new programs. Prefer
@tt{#lang webracket/base} and @racket[require] unless you are deliberately
working with legacy top-level code.

@section{The Runtime Model}

WebRacket uses a custom runtime implemented in WebAssembly GC.

@itemlist[
  @item{Immediate values such as booleans, characters, null, void, and EOF use
        WebRacket's tagged representation.}
  @item{Heap values such as pairs, strings, bytes, vectors, boxes, structs,
        closures, and hash tables are represented by WebAssembly GC objects.}
  @item{Closures are explicit runtime values with code and captured free
        variables.}
  @item{JavaScript values cross the boundary through WebRacket's FFI and host
        bridge.}
]

@section{Interacting With The Browser}

Browser interaction is explicit. Programs usually build or update DOM state,
register callbacks, and keep running in response to browser events.

Common layers are:

@itemlist[
  @item{@racketmodname[web-easy] for a declarative UI style;}
  @item{@racketmodname[browser/dom] and related browser modules for direct DOM
        access;}
  @item{the JavaScript FFI for lower-level host calls;}
  @item{the browser console bridge for optional debugging.}
]

Because WebAssembly and JavaScript have different value representations,
values that cross the boundary must be converted by WebRacket's bridge code.
That is why browser APIs are usually exposed through wrappers instead of being
called as arbitrary JavaScript directly.

@section{Files And Assets}

Browser programs cannot freely open host paths. WebRacket provides a virtual
filesystem so programs can use familiar file and port operations on paths such
as @tt{/app/config.txt}.

Assets are supplied at startup with options such as @tt{--vfs-url},
@tt{--vfs-text}, @tt{--vfs-base64}, and tar mounts. In Node mode, host-file
and host-directory preloads are also available.

The key distinction is:

@itemlist[
  @item{the source path or URL names where the generated host code gets the
        bytes;}
  @item{the VFS path names where the WebRacket program sees those bytes.}
]

See @secref["files-and-vfs"] for the detailed VFS guide.

@section{Program Structure}

Browser-oriented WebRacket programs usually do not compute one value and exit.
They tend to:

@itemlist[
  @item{construct an initial page or widget tree;}
  @item{mount it into the browser document;}
  @item{register callbacks for user events;}
  @item{update visible state over time.}
]

Node-oriented programs can be more script-like, especially when using
@tt{--run}, but they still execute on WebRacket's runtime rather than the
ordinary Racket runtime.

@section{Summary}

For a Racket programmer, the current WebRacket model is:

@itemlist[
  @item{write module-based Racket source with @tt{#lang webracket/base};}
  @item{use ordinary @racket[require] where WebRacket modules are available;}
  @item{let host Racket handle expansion and macros;}
  @item{run the expanded program on WebRacket's WebAssembly runtime;}
  @item{interact with browser APIs through explicit WebRacket libraries and
        host bridges;}
  @item{use the virtual filesystem for browser-safe file access.}
]
