#lang webracket/base

(require js/promise
         (only-in webracket/unsafe/dom
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-set!
                  js-typeof
                  js-window-screen)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (all-defined-out))

;;;
;;; Screen Orientation wrappers
;;;

(define screen-orientation-callback-cache (make-hasheq))

;; screen-orientation-info : external/raw -> screen-orientation-info?
;;   Wrap a browser ScreenOrientation object.
(struct screen-orientation-info (raw) #:transparent)

;; screen-orientation-raw : screen-orientation-info? -> external/raw
;;   Extract the raw ScreenOrientation object.
(define (screen-orientation-raw value)
  (screen-orientation-info-raw value))

;; screen-orientation-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (screen-orientation-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; screen-orientation-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (screen-orientation-property-present? raw property-name)
  (not (js-nullish? (js-ref/extern raw property-name))))

;; screen-orientation-supported-raw : -> (or/c #f external/raw)
;;   Read screen.orientation when it is available.
(define (screen-orientation-supported-raw)
  (define orientation (js-ref/extern (js-window-screen) "orientation"))
  (and (not (js-nullish? orientation))
       orientation))

;; screen-orientation-supported? : -> boolean?
;;   Report whether the browser exposes screen.orientation.
(define (screen-orientation-supported?)
  (not (eq? (screen-orientation-supported-raw) #f)))

;; screen-orientation : -> (or/c #f screen-orientation-info?)
;;   Read the current browser ScreenOrientation object when available.
(define (screen-orientation)
  (define raw (screen-orientation-supported-raw))
  (and raw (screen-orientation-info raw)))

;; screen-orientation? : any/c -> boolean?
;;   Report whether v is a wrapped ScreenOrientation value.
(define (screen-orientation? v)
  (and (screen-orientation-info? v)
       (external? (screen-orientation-raw v))))

;; check-screen-orientation : symbol? any/c -> void?
;;   Ensure value wraps an external ScreenOrientation-like host value.
(define (check-screen-orientation who value)
  (unless (screen-orientation? value)
    (raise-argument-error who "screen-orientation?" value)))

;; check-screen-orientation-method : symbol? screen-orientation-info? string? -> void?
;;   Ensure a required ScreenOrientation method is available.
(define (check-screen-orientation-method who value method-name)
  (unless (screen-orientation-method-present? (screen-orientation-raw value) method-name)
    (raise-arguments-error who
                           (string-append "ScreenOrientation." method-name " is not available"))))

;; check-screen-orientation-property : symbol? screen-orientation-info? string? -> void?
;;   Ensure a required ScreenOrientation property is available.
(define (check-screen-orientation-property who value property-name)
  (unless (screen-orientation-property-present? (screen-orientation-raw value) property-name)
    (raise-arguments-error who
                           (string-append "ScreenOrientation."
                                          property-name
                                          " is not available"))))

;; screen-orientation-type : screen-orientation-info? -> string?
;;   Read the orientation type, such as "portrait-primary".
(define (screen-orientation-type value)
  (check-screen-orientation 'screen-orientation-type value)
  (check-screen-orientation-property 'screen-orientation-type value "type")
  (js-ref (screen-orientation-raw value) "type"))

;; screen-orientation-angle : screen-orientation-info? -> number?
;;   Read the orientation angle in degrees.
(define (screen-orientation-angle value)
  (check-screen-orientation 'screen-orientation-angle value)
  (check-screen-orientation-property 'screen-orientation-angle value "angle")
  (js-ref (screen-orientation-raw value) "angle"))

;; screen-orientation-lock-type? : any/c -> boolean?
;;   Recognize orientation lock strings accepted by ScreenOrientation.lock().
(define (screen-orientation-lock-type? value)
  (and (or (string? value) (symbol? value))
       (let ([s (if (symbol? value) (symbol->string value) value)])
         (or (string=? s "any")
             (string=? s "natural")
             (string=? s "landscape")
             (string=? s "portrait")
             (string=? s "portrait-primary")
             (string=? s "portrait-secondary")
             (string=? s "landscape-primary")
             (string=? s "landscape-secondary")))))

;; screen-orientation-lock-type->string : symbol? any/c -> string?
;;   Normalize a screen orientation lock type to a JavaScript string.
(define (screen-orientation-lock-type->string who value)
  (unless (screen-orientation-lock-type? value)
    (raise-argument-error who "screen-orientation-lock-type?" value))
  (if (symbol? value) (symbol->string value) value))

;; screen-orientation-lock! : screen-orientation-info? (or/c string? symbol?) -> js-promise?
;;   Request an orientation lock and return the browser Promise.
(define (screen-orientation-lock! value lock-type)
  (check-screen-orientation 'screen-orientation-lock! value)
  (check-screen-orientation-method 'screen-orientation-lock! value "lock")
  (define lock-type* (screen-orientation-lock-type->string 'screen-orientation-lock! lock-type))
  (js-promise-wrap
   (js-send/extern (screen-orientation-raw value) "lock" (vector lock-type*))))

;; screen-orientation-unlock! : screen-orientation-info? -> void?
;;   Remove an active orientation lock.
(define (screen-orientation-unlock! value)
  (check-screen-orientation 'screen-orientation-unlock! value)
  (check-screen-orientation-method 'screen-orientation-unlock! value "unlock")
  (js-send/extern/nullish (screen-orientation-raw value) "unlock" (vector))
  (void))

;; screen-orientation-callback->external : symbol? any/c -> external/raw
;;   Convert a callback to a stable external callback wrapper.
(define (screen-orientation-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref screen-orientation-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply callback args)
             (void))))
        (hash-set! screen-orientation-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; screen-orientation-on-change! : screen-orientation-info? (or/c procedure? external? #f) -> void?
;;   Set the onchange handler on a ScreenOrientation object.
(define (screen-orientation-on-change! value callback)
  (check-screen-orientation 'screen-orientation-on-change! value)
  (define callback* (and callback
                         (screen-orientation-callback->external
                          'screen-orientation-on-change!
                          callback)))
  (js-set! (screen-orientation-raw value) "onchange" callback*)
  (void))

;; screen-orientation-add-change-listener! : screen-orientation-info? (or/c procedure? external?) -> external/raw
;;   Add a change listener to a ScreenOrientation object.
(define (screen-orientation-add-change-listener! value callback)
  (check-screen-orientation 'screen-orientation-add-change-listener! value)
  (check-screen-orientation-method 'screen-orientation-add-change-listener! value "addEventListener")
  (define callback* (screen-orientation-callback->external
                     'screen-orientation-add-change-listener!
                     callback))
  (js-send/extern/nullish (screen-orientation-raw value)
                          "addEventListener"
                          (vector "change" callback*))
  callback*)

;; screen-orientation-remove-change-listener! : screen-orientation-info? (or/c procedure? external?) -> void?
;;   Remove a previously installed change listener.
(define (screen-orientation-remove-change-listener! value callback)
  (check-screen-orientation 'screen-orientation-remove-change-listener! value)
  (check-screen-orientation-method 'screen-orientation-remove-change-listener! value "removeEventListener")
  (define callback* (screen-orientation-callback->external
                     'screen-orientation-remove-change-listener!
                     callback))
  (js-send/extern/nullish (screen-orientation-raw value)
                          "removeEventListener"
                          (vector "change" callback*))
  (void))
