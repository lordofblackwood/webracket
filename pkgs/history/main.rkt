#lang webracket/base

(require browser/window
         (only-in webracket/unsafe/dom
                  js-null
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern/nullish
                  js-set!
                  js-typeof)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide history
         history-raw
         history?
         history-supported?
         history-length
         history-state
         history-back!
         history-forward!
         history-go!
         history-push-state!
         history-replace-state!
         history-on-popstate!
         history-add-popstate-listener!
         history-remove-popstate-listener!
         history-info
         history-info?)

;;;
;;; History wrappers
;;;

(struct history-info (raw) #:transparent)

(define history-callback-cache (make-hasheq))

;; history-raw : history-info? -> external/raw
;;   Extract the raw browser History object.
(define (history-raw value)
  (history-info-raw value))

;; history-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (history-method-present? raw method-name)
  (and (history-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; history-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (history-property-present? raw property-name)
  (and (history-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; history-supported? : -> boolean?
;;   Report whether the browser exposes window.history with the core methods.
(define (history-supported?)
  (with-handlers ([exn:fail? (lambda (_e) #f)])
    (define value (history))
    (and (history-info? value)
         (history-raw-host-value? (history-raw value))
         (history-method-present? (history-raw value) "back")
         (history-method-present? (history-raw value) "forward")
         (history-method-present? (history-raw value) "go")
         (history-method-present? (history-raw value) "pushState")
         (history-method-present? (history-raw value) "replaceState"))))

;; history : -> history-info?
;;   Read the current browser History object.
(define (history)
  (history-info (window-history-info-raw (window-history))))

;; history? : any/c -> boolean?
;;   Report whether v is a wrapped browser History object.
(define (history? v)
  (and (history-host-value? v)
       (history-method-present? (history-raw v) "back")
       (history-method-present? (history-raw v) "forward")
       (history-method-present? (history-raw v) "go")
       (history-method-present? (history-raw v) "pushState")
       (history-method-present? (history-raw v) "replaceState")))

;; history-host-value? : any/c -> boolean?
;;   Report whether v wraps an external History-like host value.
(define (history-host-value? v)
  (and (history-info? v)
       (history-raw-host-value? (history-raw v))))

;; history-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (history-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; check-history : symbol? any/c -> void?
;;   Ensure value wraps an external History-like host value.
(define (check-history who value)
  (unless (history-host-value? value)
    (raise-argument-error who "history?" value)))

;; check-history-method : symbol? history-info? string? -> void?
;;   Ensure a required History method is available.
(define (check-history-method who value method-name)
  (unless (history-method-present? (history-raw value) method-name)
    (raise-arguments-error who
                           (string-append "History." method-name " is not available"))))

;; check-history-property : symbol? history-info? string? -> void?
;;   Ensure a required History property is available.
(define (check-history-property who value property-name)
  (unless (history-property-present? (history-raw value) property-name)
    (raise-arguments-error who
                           (string-append "History." property-name " is not available"))))

;; check-history-window-method : symbol? string? -> void?
;;   Ensure window exposes a required event listener method.
(define (check-history-window-method who method-name)
  (unless (history-method-present? (history-window-raw) method-name)
    (raise-arguments-error who
                           (string-append "window." method-name " is not available"))))

;; history-stringish->string : symbol? any/c -> string?
;;   Normalize a string-like argument to a browser string.
(define (history-stringish->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" value)]))

;; history-callback->external : symbol? any/c -> external/raw
;;   Convert a callback to a stable external callback wrapper.
(define (history-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref history-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply callback args)
             (void))))
        (hash-set! history-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; history-window-raw : -> external/raw
;;   Read the current raw window object.
(define (history-window-raw)
  (dom-window-raw (Window)))

;; history-length : history? -> exact-nonnegative-integer?
;;   Read the number of session history entries.
(define (history-length value)
  (check-history 'history-length value)
  (check-history-property 'history-length value "length")
  (js-ref (history-raw value) "length"))

;; history-state : history? -> any/c
;;   Read the current history state object or value.
(define (history-state value)
  (check-history 'history-state value)
  (js-ref (history-raw value) "state"))

;; history-back! : history? -> void?
;;   Navigate to the previous history entry.
(define (history-back! value)
  (check-history 'history-back! value)
  (check-history-method 'history-back! value "back")
  (js-send/extern/nullish (history-raw value) "back" (vector))
  (void))

;; history-forward! : history? -> void?
;;   Navigate to the next history entry.
(define (history-forward! value)
  (check-history 'history-forward! value)
  (check-history-method 'history-forward! value "forward")
  (js-send/extern/nullish (history-raw value) "forward" (vector))
  (void))

;; history-go! : history? (or/c #f exact-integer?) -> void?
;;   Navigate by delta entries, or reload when delta is omitted.
(define (history-go! value [delta #f])
  (check-history 'history-go! value)
  (check-history-method 'history-go! value "go")
  (unless (or (eq? delta #f) (exact-integer? delta))
    (raise-argument-error 'history-go! "(or/c #f exact-integer?)" delta))
  (js-send/extern/nullish (history-raw value)
                          "go"
                          (if (eq? delta #f)
                              (vector)
                              (vector delta)))
  (void))

;; history-push-state! : history? any/c [(or/c #f string? symbol?)] -> void?
;;   Push a new history entry with state and an optional URL.
(define (history-push-state! value state [url #f])
  (check-history 'history-push-state! value)
  (check-history-method 'history-push-state! value "pushState")
  (unless (or (eq? url #f) (string? url) (symbol? url))
    (raise-argument-error 'history-push-state! "(or/c #f string? symbol?)" url))
  (js-send/extern/nullish (history-raw value)
                          "pushState"
                          (if (eq? url #f)
                              (vector state "")
                              (vector state "" (history-stringish->string 'history-push-state! url))))
  (void))

;; history-replace-state! : history? any/c [(or/c #f string? symbol?)] -> void?
;;   Replace the current history entry with state and an optional URL.
(define (history-replace-state! value state [url #f])
  (check-history 'history-replace-state! value)
  (check-history-method 'history-replace-state! value "replaceState")
  (unless (or (eq? url #f) (string? url) (symbol? url))
    (raise-argument-error 'history-replace-state! "(or/c #f string? symbol?)" url))
  (js-send/extern/nullish (history-raw value)
                          "replaceState"
                          (if (eq? url #f)
                              (vector state "")
                              (vector state "" (history-stringish->string 'history-replace-state! url))))
  (void))

;; history-on-popstate! : (or/c #f procedure? external?) -> void?
;;   Install or clear the window onpopstate handler.
(define (history-on-popstate! callback)
  (unless (or (eq? callback #f) (procedure? callback) (external? callback))
    (raise-argument-error 'history-on-popstate! "(or/c #f procedure? external?)" callback))
  (js-set! (history-window-raw)
           "onpopstate"
           (if (eq? callback #f)
               (js-null)
               (history-callback->external 'history-on-popstate! callback)))
  (void))

;; history-add-popstate-listener! : (or/c procedure? external?) -> external/raw
;;   Add a popstate event listener to the current window.
(define (history-add-popstate-listener! callback)
  (check-history-window-method 'history-add-popstate-listener! "addEventListener")
  (define callback* (history-callback->external 'history-add-popstate-listener! callback))
  (js-send/extern/nullish (history-window-raw)
                          "addEventListener"
                          (vector "popstate" callback*))
  callback*)

;; history-remove-popstate-listener! : (or/c procedure? external?) -> void?
;;   Remove a previously installed popstate listener from the current window.
(define (history-remove-popstate-listener! callback)
  (check-history-window-method 'history-remove-popstate-listener! "removeEventListener")
  (define callback* (history-callback->external 'history-remove-popstate-listener! callback))
  (js-send/extern/nullish (history-window-raw)
                          "removeEventListener"
                          (vector "popstate" callback*))
  (void))
