#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-clipboard-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[clipboard]}
@declare-exporting[(lib "scribblings/lib-clipboard-labels.rkt" "webracket-doc")]

@defmodule[clipboard]

The @racketmodname[clipboard] module gives browser code access to
plain-text clipboard reads and writes through @tt{navigator.clipboard}.

@(mdn-bar "Clipboard API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API")

Use @racket[clipboard] when you want to:

@itemlist[
  @item{check whether browser clipboard text support is available}
  @item{read the current @tt{navigator.clipboard} object as a wrapped value}
  @item{start asynchronous plain-text clipboard reads}
  @item{start asynchronous plain-text clipboard writes}
]

@bold{Important browser constraints}

@itemlist[
  @item{Most browsers expose @tt{navigator.clipboard} only in a secure context, typically HTTPS or localhost.}
  @item{Clipboard reads and writes commonly require a user activation such as a button click.}
  @item{Clipboard reads and writes are asynchronous and return @racket[js-promise?] values.}
]

String-like text arguments accept either strings or symbols. Symbols are
converted with @racket[symbol->string] before the browser call.

@section{Clipboard Quick Start}

@racketblock[
(require browser/dom
         clipboard
         js/promise)

(define clip (clipboard))

(when clip
  (js-promise-then
   (clipboard-write-text! clip "Hello from WebRacket")
   (lambda (_ignored)
     (js-log "clipboard write finished")
     (void))))
]

@section{Clipboard API}

@defproc[(clipboard-supported?) boolean?]{
@(mdn-bar "Navigator: clipboard property"
          "https://developer.mozilla.org/en-US/docs/Web/API/Navigator/clipboard")
Returns @racket[#t] when the current browser exposes
@tt{navigator.clipboard} with the plain-text @tt{readText} and
@tt{writeText} methods.
}

@defproc[(clipboard) (or/c #f clipboard?)]{
@(mdn-bar "Navigator: clipboard property"
          "https://developer.mozilla.org/en-US/docs/Web/API/Navigator/clipboard")
Returns the current browser Clipboard object wrapped in a checked value, or
@racket[#f] when the Clipboard API is not available in this environment.
}

@defproc[(clipboard? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a wrapped Clipboard value with
plain-text read and write support.
}

@defproc[(clipboard-raw [value clipboard?]) external/raw]{
Returns the wrapped raw browser Clipboard object.
}

@defproc[(clipboard-read-text [value clipboard?]) js-promise?]{
@(mdn-bar "Clipboard: readText() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Clipboard/readText")
Starts an asynchronous clipboard text read and returns a wrapped JavaScript
Promise.
}

@defproc[(clipboard-write-text! [value clipboard?]
                                [text (or/c string? symbol?)])
         js-promise?]{
@(mdn-bar "Clipboard: writeText() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Clipboard/writeText")
Starts an asynchronous clipboard text write and returns a wrapped JavaScript
Promise.
}
