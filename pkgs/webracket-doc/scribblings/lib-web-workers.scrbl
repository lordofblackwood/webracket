#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-web-workers-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-event-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[web-workers]}
@declare-exporting[(lib "scribblings/lib-web-workers-labels.rkt" "webracket-doc")]

@defmodule[web-workers]

The @racketmodname[web-workers] module wraps a small, practical slice of
the dedicated Web Worker API.

@(mdn-bar "Web Workers API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API")

@bold{Read the MDN page first.} The wrapper below gives you the
WebRacket surface, while the MDN documentation explains worker loading,
message passing, origin rules, and the distinction between classic and
module workers.

Use @racketmodname[web-workers] when you want to:

@itemlist[
  @item{create a dedicated worker from a script URL}
  @item{send messages to the worker}
  @item{terminate the worker}
  @item{attach @tt{message} and @tt{error} handlers}
]

@section{Web Workers Quick Start}

@racketblock[
(require web-workers)

(define w (make-worker "worker.js"))

(worker-post-message! w #(ping 42))
]

@section{Worker API}

@defproc[(worker-supported?) boolean?]{
Returns @racket[#t] when the browser exposes the @tt{Worker}
constructor.
}

@defproc[(make-worker [script-url (or/c string? symbol?)]
                      [options (or/c #f worker-options?) #f])
         worker?]{
@(mdn-bar "Worker: Worker() constructor"
          "https://developer.mozilla.org/en-US/docs/Web/API/Worker/Worker")
Creates a dedicated worker from @racket[script-url].
}

@defproc[(worker? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a wrapped browser Worker object.
}

@defproc[(worker-raw [value worker?]) external/raw]{
Returns the wrapped raw browser Worker object.
}

@defproc[(worker-post-message! [value worker?]
                               [message (or/c #f
                                              boolean?
                                              string?
                                              symbol?
                                              real?
                                              bytes?
                                              external?
                                              null?
                                              pair?
                                              vector?)])
         void?]{
@(mdn-bar "Worker: postMessage() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Worker/postMessage")
Posts a structured-cloneable message to the worker. This wrapper accepts
a conservative set of Racket values that map cleanly to the browser
message channel.
}

@defproc[(worker-terminate! [value worker?]) void?]{
@(mdn-bar "Worker: terminate() method"
          "https://developer.mozilla.org/en-US/docs/Web/API/Worker/terminate")
Terminates the worker immediately.
}

@defproc[(worker-onmessage! [value worker?]
                            [handler (or/c #f procedure? external?)])
         void?]{
@(mdn-bar "Worker: message event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Worker/message_event")
Installs or clears the worker's @tt{onmessage} handler.
}

@defproc[(worker-onerror! [value worker?]
                          [handler (or/c #f procedure? external?)])
         void?]{
@(mdn-bar "Worker: error event"
          "https://developer.mozilla.org/en-US/docs/Web/API/Worker/error_event")
Installs or clears the worker's @tt{onerror} handler.
}

@defproc[(worker-add-event-listener! [value worker?]
                                     [event-name (or/c string? symbol?)]
                                     [callback (or/c procedure? external?)])
         external/raw]{
Adds a worker event listener and returns the installed callback value.
}

@defproc[(worker-remove-event-listener! [value worker?]
                                        [event-name (or/c string? symbol?)]
                                        [callback (or/c procedure? external?)])
         void?]{
Removes a previously installed worker event listener.
}

@defproc[(make-worker-options [type (or/c #f string? symbol?) #f]
                              [name (or/c #f string? symbol?) #f]
                              [credentials (or/c #f string? symbol?) #f])
         worker-options?]{
@(mdn-bar "WorkerOptions"
          "https://developer.mozilla.org/en-US/docs/Web/API/Worker/Worker#parameters")
Builds an options dictionary for @racket[make-worker]. Use it for common
keys such as @tt{type}, @tt{name}, and @tt{credentials}.
}

@defproc[(worker-options? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a @racket[make-worker-options]
value.
}

@defproc[(worker-options-type [value worker-options?]) (or/c #f string? symbol?)]{
Returns the configured worker @tt{type} value.
}

@defproc[(worker-options-name [value worker-options?]) (or/c #f string? symbol?)]{
Returns the configured worker @tt{name} value.
}

@defproc[(worker-options-credentials [value worker-options?]) (or/c #f string? symbol?)]{
Returns the configured worker @tt{credentials} value.
}
