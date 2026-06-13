#lang racket/base

(require browser/element
         (only-in webracket/unsafe/array
                  js-object)
         webracket/unsafe/window)

(provide (struct-out dom-window)
         (struct-out window-document-info)
         (struct-out window-location-info)
         (struct-out window-scroll-options)
         Window
         window-self
         window-document
         window-name
         window-set-name!
         window-location
         window-open
         window-confirm
         window-scroll-to
         window-set-timeout/delay
         window-match-media
         window-get-computed-style
         (all-from-out webracket/unsafe/window))

;; This is the canonical module version of the old `include-lib window`
;; safe wrapper. Raw bindings remain in `webracket/unsafe/window`.
;; The checked wrapper surface below currently covers the migrated legacy subset;
;; add further legacy names here as module clients move off `include-lib`.

;;;
;;; Window wrappers
;;;

;; window-i32->boolean : integer? -> boolean?
;;   Convert a browser i32 flag to a boolean.
(define (window-i32->boolean v)
  (not (zero? v)))

;; window-real->flonum : symbol? any/c -> real?
;;   Validate a real coordinate and coerce it to an inexact value for FFI calls.
(define (window-real->flonum who v)
  (unless (real? v)
    (raise-argument-error who "real?" v))
  (exact->inexact v))

;; window-stringish->string : symbol? any/c -> string?
;;   Normalize a string-like wrapper argument to a browser string.
(define (window-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else (raise-argument-error who "(or/c string? symbol?)" v)]))

;; window-resolve-optional : any/c -> any/c
;;   Treat #f as omitted, and force thunks when a literal value is needed.
(define (window-resolve-optional value)
  (cond
    [(eq? value #f) (void)]
    [(procedure? value) (value)]
    [else value]))

;; window-resolve-stringish-optional : symbol? any/c -> any/c
;;   Resolve an optional string-like argument and normalize strings and symbols.
(define (window-resolve-stringish-optional who value)
  (define resolved (window-resolve-optional value))
  (cond
    [(string? resolved) resolved]
    [(symbol? resolved) (symbol->string resolved)]
    [else resolved]))

;; window-resolve-scroll-options : any/c -> (or/c #f window-scroll-options?)
;;   Treat #f as omitted and force thunks for scroll option values.
(define (window-resolve-scroll-options value)
  (cond
    [(window-scroll-options? value) value]
    [else
     (define resolved (window-resolve-optional value))
     (cond
       [(eq? resolved (void)) #f]
       [(eq? resolved #f) #f]
       [(window-scroll-options? resolved) resolved]
       [else resolved])]))

;; window-scroll-options : any/c any/c any/c -> void?
;;   Validate a browser ScrollToOptions dictionary wrapper.
(struct window-scroll-options (top left behavior)
  #:transparent
  #:constructor-name make-window-scroll-options
  #:guard (lambda (top left behavior name)
            (unless (or (eq? top #f) (real? top))
              (raise-argument-error name "(or/c #f real?)" top))
            (unless (or (eq? left #f) (real? left))
              (raise-argument-error name "(or/c #f real?)" left))
            (unless (or (eq? behavior #f) (string? behavior) (symbol? behavior))
              (raise-argument-error name "(or/c #f string? symbol?)" behavior))
            (values top left behavior)))

;; window-scroll-options->raw : window-scroll-options? real? real? -> external/raw
;;   Convert a Rackety scroll-options struct to a browser dictionary.
(define (window-scroll-options->raw options fallback-x fallback-y)
  (define top (window-scroll-options-top options))
  (define left (window-scroll-options-left options))
  (define behavior (window-scroll-options-behavior options))
  (define fields
    (list (list "top" (if (eq? top #f) fallback-y top))
          (list "left" (if (eq? left #f) fallback-x left))))
  (define fields*
    (if (eq? behavior #f)
        fields
        (append fields
                (list (list "behavior"
                            (if (symbol? behavior)
                                (symbol->string behavior)
                                behavior))))))
  (js-object (list->vector (map list->vector fields*))))

;; dom-window : external/raw -> dom-window?
;;   Wrap a browser Window object.
(struct dom-window (raw) #:transparent)

;; Window : -> dom-window?
;;   Read the current window object.
(define (Window)
  (dom-window (js-window-window)))

;; window-wrap-optional : any/c -> (or/c #f dom-window?)
;;   Wrap a browser Window-like value when one is present.
(define (window-wrap-optional value)
  (and (not (eq? value #f))
       (dom-window value)))

;; window-document-info : external/raw -> window-document-info?
;;   Wrap the current document object.
(struct window-document-info (raw) #:transparent)

;; window-self : -> dom-window?
;;   Read the current window via self.
(define (window-self)
  (dom-window (js-window-self)))

;; window-document : -> window-document-info?
;;   Read the document for the current window.
(define (window-document)
  (window-document-info (js-window-document)))

;; window-name : -> string?
;;   Read the window name.
(define (window-name)
  (js-window-name))

;; window-set-name! : (or/c string? symbol?) -> void?
;;   Set the window name.
(define (window-set-name! name)
  (define name* (window-stringish->string 'window-set-name! name))
  (js-set-window-name! name*)
  (void))

;; window-location-info : external/raw -> window-location-info?
;;   Wrap the current window location object.
(struct window-location-info (raw) #:transparent)

;; window-location : -> window-location-info?
;;   Read the window location object.
(define (window-location)
  (window-location-info (js-window-location)))

;; window-open : (or/c string? symbol?) [target (or/c string? symbol? procedure?) #f] [features (or/c string? symbol? procedure?) #f] [replace (or/c boolean? procedure?) #f] -> (or/c #f window?)
;;   Open a new browsing context.
(define (window-open url [target #f] [features #f] [replace #f])
  (define url* (window-stringish->string 'window-open url))
  (define target* (window-resolve-stringish-optional 'window-open target))
  (define features* (window-resolve-stringish-optional 'window-open features))
  (define replace* (window-resolve-optional replace))
  (when (and (not (eq? target* (void)))
             (not (or (string? target*) (eq? target* #f))))
    (raise-argument-error 'window-open "(or/c #f string? symbol? procedure?)" target))
  (when (and (not (eq? features* (void)))
             (not (or (string? features*) (eq? features* #f))))
    (raise-argument-error 'window-open "(or/c #f string? symbol? procedure?)" features))
  (when (and (not (eq? replace* (void)))
             (not (boolean? replace*)))
    (raise-argument-error 'window-open "(or/c #f boolean? procedure?)" replace))
  (window-wrap-optional (js-window-open url* target* features* replace*)))

;; window-confirm : (or/c string? symbol?) -> boolean?
;;   Show a confirmation dialog.
(define (window-confirm message)
  (define message* (window-stringish->string 'window-confirm message))
  (window-i32->boolean (js-window-confirm message*)))

;; window-scroll-to : real? real? [or/c #f window-scroll-options? procedure?] -> void?
;;   Scroll the window to an absolute position.
(define (window-scroll-to x y [options #f])
  (define x* (window-real->flonum 'window-scroll-to x))
  (define y* (window-real->flonum 'window-scroll-to y))
  (define options* (window-resolve-scroll-options options))
  (cond
    [(eq? options* #f)
     (js-window-scroll-to x* y* (void))]
    [(window-scroll-options? options*)
     (js-window-scroll-to x* y* (window-scroll-options->raw options* x* y*))]
    [else
     (raise-argument-error 'window-scroll-to
                           "(or/c #f window-scroll-options? procedure?)"
                           options)])
  (void))

;; window-set-timeout/delay : external? real? -> u32?
;;   Schedule a one-shot timer callback with an explicit delay.
(define (window-set-timeout/delay callback delay)
  (js-window-set-timeout/delay callback delay))

;; window-match-media : (or/c string? symbol?) -> media-query-list?
;;   Evaluate a media query.
(define (window-match-media query)
  (define query* (window-stringish->string 'window-match-media query))
  (media-query-list-wrap (js-window-match-media query*)))

;; window-get-computed-style : external? [any/c #f] -> css-style-declaration?
;;   Read computed style for an element.
(define (window-get-computed-style element [pseudo-element #f])
  (define pseudo-element* (window-resolve-stringish-optional 'window-get-computed-style
                                                             pseudo-element))
  (css-style-declaration-wrap
   (js-window-get-computed-style (element-unwrap element) pseudo-element*)))
