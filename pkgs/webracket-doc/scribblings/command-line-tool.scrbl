#lang scribble/manual

@(require scribble-tools
          "webracket-scribble-utils.rkt")

@title{Command-Line Tool}

This chapter is the current command-line reference for WebRacket. For
installation and first-run walkthroughs, see the website
Quick Start and Installation pages.

The entry point is @tt{webracket.rkt}. It accepts either:

@itemlist[
  @item{One source file plus optional flags (compile mode).}
  @item{No source file together with @(flag "--list-primitives") (listing mode).}
]

@section{Overview}

The overall goal is to compile a WebRacket source file, such as a
@tt{#lang webracket/base} module, to WebAssembly.

By default, WebRacket emits split-runtime output: a program @tt{.wasm}, a
content-addressed runtime sidecar named like
@tt{webracket-runtime-<fingerprint>.wasm}, and a generated host support
file. Programs that use direct JavaScript FFI wrappers also emit a
content-addressed FFI sidecar named like
@tt{webracket-ffi-<fingerprint>.wasm} by default:

@itemlist[
  @item{Node mode: a @tt{.js} host file that loads and runs the program and
        runtime Wasm modules in the terminal.}
  @item{Browser mode: a @tt{.html} host file that loads and runs the program
        and runtime Wasm modules in the browser.}
]

So the normal output is a small set of files that work together: compile
artifact(s), metadata, and host-side runtime support.

To keep source directories tidy, prefer writing generated files to a
separate directory:

@shellblock{
racket webracket.rkt --browser --dest generated program.rkt
}

@section{Canonical Invocation}

@shellblock{
racket webracket.rkt [option ...] <filename>
}

Primitive listing mode:

@shellblock{
racket webracket.rkt --list-primitives
}

@section{Quick Start (CLI)}

Minimal compile:

@shellblock{
racket webracket.rkt --node program.rkt
}

Compile and run immediately in Node mode:

@shellblock{
racket webracket.rkt --node --run program.rkt
}

@section{Common Tasks}

Compile with default output names:

@shellblock{
racket webracket.rkt --node program.rkt
}

Choose explicit output files:

@shellblock{
racket webracket.rkt --node --wat-file out/program.wat --wasm-file out/program.wasm --host-file out/program.js program.rkt
}

Choose a destination directory for the default outputs:

@shellblock{
racket webracket.rkt --node --dest out program.rkt
}

Explicit `--wat-file`, `--wasm-file`, and `--host-file` options still take
precedence over `--dest`.

Target browser host generation:

@shellblock{
racket webracket.rkt --browser program.rkt
}

Browser output must be served over HTTP. Do not open the generated
@tt{.html} file directly as a @tt{file://} page.

Target browser host generation with the browser console bridge enabled:

@shellblock{
racket webracket.rkt --browser --console-bridge program.rkt
}

Dump compiler passes (limit to 25 dumps):

@shellblock{
racket webracket.rkt --node --dump-passes tmp/passes --dump-passes-limit 25 program.rkt
}

Print timing information:

@shellblock{
racket webracket.rkt --node --timings program.rkt
}

Write pretty-formatted WAT (default is non-pretty):

@shellblock{
racket webracket.rkt --node --pretty-wat program.rkt
}

Print all known primitives:

@shellblock{
racket webracket.rkt --list-primitives
}

@section{Operational Constraints}

@itemlist[
  @item{@(flag "--run") cannot be used together with @(flag "--browser").}
  @item{Compile mode requires exactly one source filename.}
  @item{Listing mode (@(flag "--list-primitives")) requires no source filename.}
  @item{When using @(flag "--run") in Node mode, a working @tt{node} executable with WebAssembly @tt{exnref} support is required.}
  @item{A working @tt{wasm-tools} installation is required for WAT-to-WASM assembly.}
  @item{Output paths must be distinct (WAT, WASM, map sidecar, and host output cannot collide).}
  @item{Output locations must be writable.}
  @item{@(flag "--dump-passes-limit <n>") requires an exact nonnegative integer.}
]

See @secref["Installation"] for Node version guidance. Current Node 24 LTS
and Node 26 enable WebAssembly @tt{exnref} by default; older supported Node
lines may require @(flag "--experimental-wasm-exnref").

@section{Output Files And Defaults}

For input @tt{program.rkt}, default outputs are:

@itemlist[
  @item{@tt{program.wat}: Text-form WebAssembly produced by the compiler. Useful
        for inspection and debugging.}
  @item{@tt{program.wasm}: Binary WebAssembly module produced from @tt{.wat}.
        This is the executable artifact.}
  @item{@tt{webracket-runtime-<fingerprint>.wasm}: Runtime sidecar used by
        split-runtime output. The fingerprint is stable for identical runtime
        contents, so multiple programs can share the same runtime file.}
  @item{@tt{webracket-ffi-<fingerprint>.wasm}: Optional FFI sidecar emitted
        when direct JavaScript FFI wrappers are active.}
  @item{@tt{program.wasm.map.sexp}: Label map sidecar metadata used to map
        generated code labels back to source-oriented information.}
  @item{@tt{program.js} (Node mode default): Host support/runtime file that
        loads the @tt{.wasm} module and provides the environment needed to run
        in Node.js.}
  @item{@tt{program.html} (browser mode default): Host support/runtime file that
        loads the @tt{.wasm} module and provides the environment needed to run
        in a browser.}
]

@section{Complete Option Reference}

Run behavior:

@itemlist[
  @item{@(flag "-r") / @(flag "--run"): Run the compiled program after generation (Node mode only).}
]

Target selection (mutually exclusive):

@itemlist[
  @item{@(flag "-n") / @(flag "--node"): Generate Node host output (default).}
  @item{@(flag "-b") / @(flag "--browser"): Generate browser host output.}
]

Output path options:

@itemlist[
  @item{@(flag "--wat-file <path>"): Explicit WAT output path.}
  @item{@(flag "--wasm-file <path>"): Explicit WASM output path.}
  @item{@(flag "--host-file <path>"): Explicit host output path.}
  @item{@(flag "--dest <dir>"): Write the default outputs under @tt{<dir>}.}
]

Debug and inspection options:

@itemlist[
  @item{@(flag "-v") / @(flag "--verbose"): Verbose compiler messages.}
  @item{@(flag "--list-primitives"): Print sorted primitive names and exit.}
  @item{@(flag "--console-bridge"): In browser mode, install @tt{globalThis.WR} so the browser console can inspect and call exposed WebRacket bindings.}
  @item{@(flag "--no-console-bridge"): Disable the browser console bridge (default).}
  @item{@(flag "--label-map-forms"): Include heavyweight source form payloads in @tt{.wasm.map.sexp}.}
  @item{@(flag "--no-label-map-forms"): Omit source form payloads in @tt{.wasm.map.sexp} (default).}
  @item{@(flag "--dump-passes <dir>"): Write per-pass dumps to @tt{<dir>}.}
  @item{@(flag "--dump-passes-limit <n>"): Limit pass dumps; @tt{0} means no dumps.}
  @item{@(flag "--timings"): Print timing breakdown for compilation stages.}
  @item{@(flag "--no-pretty-wat"): Write @tt{.wat} without pretty formatting (default).}
  @item{@(flag "--pretty-wat"): Write @tt{.wat} with pretty formatting.}
]

Virtual filesystem options:

@itemlist[
  @item{@(flag "--vfs-file VFS=PATH"): Preload a Node host file into a VFS file.}
  @item{@(flag "--vfs-url VFS=URL"): Fetch a URL into a VFS file.}
  @item{@(flag "--vfs-text VFS=TEXT"): Embed inline text as a VFS file.}
  @item{@(flag "--vfs-base64 VFS=BASE64"): Embed small inline base64 bytes as a VFS file.}
  @item{@(flag "--vfs-mkdir VFS"): Create an empty VFS directory.}
  @item{@(flag "--vfs-dir VFS=PATH"): Preload a Node host directory into a VFS directory.}
  @item{@(flag "--vfs-tar-file VFS=PATH"): Mount a Node host tar archive as a read-only VFS subtree.}
  @item{@(flag "--vfs-tar-url VFS=URL"): Mount a tar archive fetched by URL as a read-only VFS subtree.}
]

Sources ending in @tt{.tar.gz} or @tt{.tgz} are treated as gzip-compressed tar
archives. For a tutorial and compatibility notes, see @secref["files-and-vfs"].

@section{Legacy Standard Library And Manual FFI}

Most module-based programs should use @racket[require] forms in the source
module instead of manual standard-library or @tt{.ffi} command-line flags.
The following options remain available for legacy inputs and diagnostics.

Legacy standard library inclusion:

@itemlist[
  @item{@(flag "--stdlib"): Include the legacy standard library.}
  @item{@(flag "--no-stdlib"): Do not include the legacy standard library (default).}
]

Manual FFI and linker flags:

@itemlist[
  @item{@(flag "--ffi <file>"): Add an @tt{.ffi} input file; may be repeated.}
  @item{@(flag "-l") / @(flag "--link-flags <flag>"): Accepted but currently ignored by the driver.}
]

Legacy examples:

@itemlist[
  @item{@shell-code{racket webracket.rkt --node --stdlib program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --ffi dom --ffi standard program.rkt}}
  @item{@shell-code{racket webracket.rkt --list-primitives --ffi dom --ffi standard}}
]

@section{Internal And Advanced Options}

These options are mainly for compiler development, module-bridge debugging,
performance investigation, and staged-provider experiments. They are useful
when reducing WebRacket bugs, but ordinary programs usually should not need
them.

Assembler environment options:

@itemlist[
  @item{@(flag "--exec-path-from-shell"): Import @tt{PATH} and @tt{MANPATH} from the login shell before finding @tt{wasm-tools} (default).}
  @item{@(flag "--no-exec-path-from-shell"): Use the current process environment when finding @tt{wasm-tools}. This is useful for tests and CI environments that already provide the desired @tt{PATH}.}
]

Module and provider options:

@itemlist[
  @item{@(flag "--webracket-module-bridge"): Force @tt{#lang webracket/base} or @tt{#lang webracket/full} through the module bridge.}
  @item{@(flag "--provider-substitutions"): Enable Goal 1 provider substitutions (default).}
  @item{@(flag "--no-provider-substitutions"): Disable Goal 1 provider substitutions for diagnostics.}
  @item{@(flag "--provider-cache-dir <dir>"): Use @tt{<dir>} for provider-slice caches.}
  @item{@(flag "--provider-cache-report"): Print provider-cache entries and exit.}
  @item{@(flag "--clear-provider-cache"): Delete the provider cache directory before compiling.}
  @item{@(flag "--force-provider-cache-refresh"): Regenerate provider cache artifacts even when fingerprints match.}
]

Staged provider options:

@itemlist[
  @item{@(flag "--io-format-provider"): Compose the staged original-Racket @tt{io/format} provider.}
  @item{@(flag "--no-io-format-provider"): Disable the staged @tt{io/format} provider for debugging.}
  @item{@(flag "--expander-read-provider"): Compose the staged original-Racket @tt{expander/read} provider. This is needed by programs that use datum @racket[read].}
  @item{@(flag "--no-expander-read-provider"): Disable the staged @tt{expander/read} provider (default).}
  @item{@(flag "--expander-read-syntax-provider"): Compose the private staged original-Racket @tt{read-syntax} provider.}
  @item{@(flag "--no-expander-read-syntax-provider"): Disable the private staged @tt{read-syntax} provider (default).}
]

Runtime output options:

@itemlist[
  @item{@(flag "--split-runtime"): Emit split program/runtime Wasm output (default).}
  @item{@(flag "--no-split-runtime"): Emit one monolithic Wasm module.}
  @item{@(flag "--split-runtime-cache-reference"): In Node split-runtime mode, read the stable runtime Wasm directly from the runtime cache. This requires the cache to be prewarmed.}
  @item{@(flag "--no-split-runtime-cache-reference"): Materialize the content-addressed runtime sidecar next to the program output (default).}
  @item{@(flag "--split-runtime-core-url <url>"): In browser split-runtime mode, fetch a prewarmed runtime Wasm from @tt{<url>} instead of materializing a local runtime sidecar.}
  @item{@(flag "--no-split-runtime-core-url"): Materialize the browser runtime sidecar next to the program output (default).}
  @item{@(flag "--split-runtime-core-only"): Split only registered core-runtime helpers into the runtime module.}
  @item{@(flag "--no-split-runtime-core-only"): Use the classified runtime/program split strategy (default).}
  @item{@(flag "--split-runtime-provider-runtime"): For module-language input, merge cached module-bridge provider fragments into the split runtime.}
  @item{@(flag "--no-split-runtime-provider-runtime"): Keep module-bridge provider fragments in the program module (default).}
  @item{@(flag "--split-runtime-ffi-module"): Explicitly emit active direct FFI wrappers as an FFI Wasm sidecar. This is the default in compatible split-runtime modes when FFI wrappers are active.}
  @item{@(flag "--no-split-runtime-ffi-module"): Keep active direct FFI wrappers in the program module.}
]

Experimental compiler options:

@itemlist[
  @item{@(flag "--alpha-rename-profile"): Print alpha-rename/pass1 counters and helper timings.}
  @item{@(flag "--simplify-profile"): Print simplify-LFE rule and shape diagnostics.}
  @item{@(flag "--enable-cc-analysis"): Enable the new closure-conversion analysis.}
  @item{@(flag "--enable-simplify"): Run the early simplify-LFE pass.}
  @item{@(flag "--frontend-cache"): Cache serialized post-unexpand frontend syntax in the project provider cache. This is experimental and opt-in.}
  @item{@(flag "--no-frontend-cache"): Disable frontend syntax caching (default).}
  @item{@(flag "--module-bridge-elide-public-cells"): Expose safe module-bridge public exports as plain values.}
  @item{@(flag "--tree-shake"): Tree-shake runtime primitives (default).}
  @item{@(flag "--no-tree-shake"): Do not tree-shake runtime primitives.}
  @item{@(flag "--tree-shake-report <file>"): Write the runtime primitive report to @tt{<file>}.}
  @item{@(flag "--letrec-basic"): Use the basic letrec lowering strategy.}
  @item{@(flag "--letrec-waddell"): Use the Waddell letrec lowering strategy.}
  @item{@(flag "--letrec-scc"): Use the SCC letrec lowering strategy (default).}
  @item{@(flag "--print-top-level-results"): Print each top-level expression result with @racket[print].}
  @item{@(flag "--list-provider-slices"): Print original-Racket provider slices and exit.}
]

Local server options:

The local compile server reduces compiler startup costs by keeping one
Racket process warm across repeated compiles.  It is especially useful
with prewarmed split-runtime caches, where the user program can avoid
both rebuilding the shared runtime and reloading the compiler process.
Set @tt{WEBRACKET_COMPILE_SERVER=1} to route ordinary compile commands
through the server.  Server state defaults to a checkout-local
@filepath{tmp/webracket-compile-server-...} directory; set
@tt{WEBRACKET_COMPILE_SERVER_STATE_DIR} to choose a different location.

@itemlist[
  @item{@(flag "--server-start"): Run the local compile server in the foreground.}
  @item{@(flag "--server-status"): Print local compile server status and exit.}
  @item{@(flag "--server-stop"): Stop the local compile server and exit.}
]

@section{Command-Line Examples}

@itemlist[
  @item{@shell-code{racket webracket.rkt --node program.rkt}}
  @item{@shell-code{racket webracket.rkt --list-primitives}}
  @item{@shell-code{racket webracket.rkt --node --run program.rkt}}
  @item{@shell-code{racket webracket.rkt --browser program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --wat-file out/program.wat --wasm-file out/program.wasm --host-file out/program.js program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --dest out program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --dump-passes tmp/passes --dump-passes-limit 25 program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --timings program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --pretty-wat program.rkt}}
  @item{@shell-code{racket webracket.rkt --node --vfs-text /app/message.txt=hello program.rkt}}
  @item{@shell-code{racket webracket.rkt --browser --vfs-tar-url /assets=./assets.tgz program.rkt}}
  @item{@shell-code{racket webracket.rkt --browser --expander-read-provider program.rkt}}
]
