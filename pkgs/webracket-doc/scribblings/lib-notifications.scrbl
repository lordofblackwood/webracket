#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-notifications-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[notifications]}
@declare-exporting[(lib "scribblings/lib-notifications-labels.rkt" "webracket-doc")]

@defmodule[notifications]

The @racketmodname[notifications] module wraps the browser
@tt{Notification} API. It provides a checked wrapper for notification
instances plus a promise-based permission request helper.

@(mdn-bar "Notifications API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API")

@bold{Important browser constraints}

@itemlist[
  @item{Notifications may be unavailable in some browsers or contexts.}
  @item{Most browsers require a user gesture before prompting for permission.}
  @item{Permission requests are asynchronous and return @racket[js-promise?] values.}
]

@section{Quick Start}

@racketblock[
(require notifications
         js/promise)

(js-promise-then
 (notification-request-permission)
 (lambda (permission)
   (when (equal? permission "granted")
     (make-notification "Hello from WebRacket"))))
]

@section{API}

@defproc[(notifications-supported?) boolean?]{
Returns @racket[#t] when the browser exposes the @tt{Notification} API.
}

@defproc[(notification [raw external/raw]) notification?]{
Wraps a raw browser notification instance.
}

@defproc[(notification? [v any/c]) boolean?]{
Returns @racket[#t] when @racket[v] is a wrapped notification.
}

@defproc[(notification-raw [value notification?]) external/raw]{
Returns the wrapped raw notification object.
}

@defproc[(notification-permission) (or/c #f string?)]{
Returns the current browser notification permission string, or @racket[#f]
when the API is unavailable.
}

@defproc[(notification-request-permission) js-promise?]{
Starts an asynchronous browser permission request.
}

@defproc[(make-notification-options [body (or/c #f string? symbol?) #f]
                                    [icon (or/c #f string? symbol?) #f]
                                    [tag (or/c #f string? symbol?) #f]
                                    [data any/c #f]
                                    [silent (or/c #f boolean?) #f]
                                    [require-interaction (or/c #f boolean?) #f]
                                    [renotify (or/c #f boolean?) #f])
         notification-options?]{
Creates options for @tt{new Notification(...)}.
}

@defproc[(make-notification [title (or/c string? symbol?)]
                            [options (or/c #f notification-options?) #f])
         notification?]{
Creates a wrapped browser notification instance.
}

@defproc[(notification-close! [value notification?]) void?]{
Closes the notification.
}

@defproc[(notification-title [value notification?]) string?]{
Returns the notification title.
}

@defproc[(notification-body [value notification?]) string?]{
Returns the notification body text.
}

@defproc[(notification-tag [value notification?]) string?]{
Returns the notification tag.
}

@defproc[(notification-data [value notification?]) any/c]{
Returns the notification data payload.
}

@defproc[(notification-icon [value notification?]) string?]{
Returns the notification icon URL string.
}

@defproc[(notification-require-interaction? [value notification?]) boolean?]{
Reports whether the notification requests persistent display.
}

@defproc[(notification-renotify? [value notification?]) boolean?]{
Reports whether the notification asks the browser to renotify for matching tags.
}

@defproc[(notification-silent? [value notification?]) boolean?]{
Reports whether the notification suppresses sound and vibration.
}
