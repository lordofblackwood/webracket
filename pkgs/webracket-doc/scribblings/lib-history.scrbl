#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-history-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[history]}
@declare-exporting[(lib "scribblings/lib-history-labels.rkt" "webracket-doc")]

@defmodule[history]

The @racketmodname[history] module wraps the browser
@tt{window.history} object.

@(mdn-bar "History API"
          "https://developer.mozilla.org/en-US/docs/Web/API/History_API")

@bold{Read the MDN page first.} The wrapper below gives you the
WebRacket surface, but the MDN documentation explains the browser
navigation model, URL constraints, and the meaning of @tt{popstate}.

Use @racketmodname[history] when you want to:

@itemlist[
  @item{inspect the current session-history state and length}
  @item{go backward or forward in history}
  @item{push or replace history state without reloading the page}
  @item{attach a @tt{popstate} listener on the current window}
]

@section{History Quick Start}

@racketblock[
(require history)

(define page-history (history))

(history-push-state! page-history
                     (vector "step" 1)
                     "#step-1")
]

@section{History API}

@defstruct[history-info ([raw external/raw])]{
Wraps the browser History object.
}

@defproc[(history-supported?) boolean?]{
Returns @racket[#t] when the current browser exposes the core
@tt{window.history} helpers used by this wrapper.
}

@defproc[(history) history-info?]{
Returns the current browser History object as a wrapped value.
}

@defproc[(history? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a wrapped browser History object.
}

@defproc[(history-raw [value history-info?]) external/raw]{
Returns the wrapped raw browser History object.
}

@defproc[(history-length [value history-info?]) exact-nonnegative-integer?]{
@(mdn-bar "History: length property"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/length")
Returns the number of entries in the session history.
}

@defproc[(history-state [value history-info?]) any/c]{
@(mdn-bar "History: state property"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/state")
Returns the current history state value.
}

@defproc[(history-back! [value history-info?]) void?]{
@(mdn-bar "History: back() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/back")
Requests navigation to the previous history entry.
}

@defproc[(history-forward! [value history-info?]) void?]{
@(mdn-bar "History: forward() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/forward")
Requests navigation to the next history entry.
}

@defproc[(history-go! [value history-info?]
                      [delta (or/c #f exact-integer?) #f])
         void?]{
@(mdn-bar "History: go() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/go")
Requests navigation by @racket[delta] entries. When @racket[delta] is
@racket[#f], the wrapper calls @tt{go()} with no argument.
}

@defproc[(history-push-state! [value history-info?]
                              [state any/c]
                              [url (or/c #f string? symbol?) #f])
         void?]{
@(mdn-bar "History: pushState() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/pushState")
Pushes a new history entry. The browser API includes an unused second
argument; this wrapper fills it in automatically.
}

@defproc[(history-replace-state! [value history-info?]
                                 [state any/c]
                                 [url (or/c #f string? symbol?) #f])
         void?]{
@(mdn-bar "History: replaceState() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/History/replaceState")
Replaces the current history entry. The browser API includes an unused
second argument; this wrapper fills it in automatically.
}

@defproc[(history-on-popstate! [callback (or/c #f procedure? external?)]) void?]{
@(mdn-bar "Window: popstate event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/popstate_event")
Installs or clears the current window's @tt{onpopstate} handler.
}

@defproc[(history-add-popstate-listener! [callback (or/c procedure? external?)])
         external/raw]{
@(mdn-bar "Window: popstate event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/popstate_event")
Adds a @tt{popstate} listener to the current window and returns the
installed callback value.
}

@defproc[(history-remove-popstate-listener! [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed @tt{popstate} listener from the current
window.
}
