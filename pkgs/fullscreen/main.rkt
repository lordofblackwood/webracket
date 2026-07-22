#lang webracket/base

(require browser/document
         browser/element
         js/promise
         (only-in webracket/unsafe/dom
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-typeof
                  js-undefined?)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide fullscreen-supported?
         fullscreen-enabled?
         fullscreen-element
         fullscreen-active?
         fullscreen-request!
         fullscreen-exit!
         fullscreen-add-change-listener!
         fullscreen-remove-change-listener!
         fullscreen-add-error-listener!
         fullscreen-remove-error-listener!)

;;;
;;; Fullscreen wrappers
;;;

(define fullscreen-callback-cache (make-hasheq))

;; fullscreen-document-raw : -> external/raw
;;   Read the current raw document object.
(define (fullscreen-document-raw)
  (dom-document-raw (Document)))

;; fullscreen-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (fullscreen-method-present? raw method-name)
  (and (fullscreen-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; fullscreen-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (fullscreen-property-present? raw property-name)
  (and (fullscreen-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; fullscreen-nullable-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a property, allowing null values.
(define (fullscreen-nullable-property-present? raw property-name)
  (and (fullscreen-raw-host-value? raw)
       (not (js-undefined? (js-ref/extern raw property-name)))))

;; fullscreen-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (fullscreen-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; check-fullscreen-document-method : symbol? string? -> void?
;;   Ensure the current document exposes a required Fullscreen method.
(define (check-fullscreen-document-method who method-name)
  (unless (fullscreen-method-present? (fullscreen-document-raw) method-name)
    (raise-arguments-error who
                           (string-append "document." method-name " is not available"))))

;; check-fullscreen-document-property : symbol? string? -> void?
;;   Ensure the current document exposes a required Fullscreen property.
(define (check-fullscreen-document-property who property-name)
  (unless (fullscreen-property-present? (fullscreen-document-raw) property-name)
    (raise-arguments-error who
                           (string-append "document." property-name " is not available"))))

;; check-fullscreen-document-nullable-property : symbol? string? -> void?
;;   Ensure the current document exposes a required nullable Fullscreen property.
(define (check-fullscreen-document-nullable-property who property-name)
  (unless (fullscreen-nullable-property-present? (fullscreen-document-raw) property-name)
    (raise-arguments-error who
                           (string-append "document." property-name " is not available"))))

;; check-fullscreen-element-method : symbol? any/c string? -> void?
;;   Ensure element exposes a required Fullscreen method.
(define (check-fullscreen-element-method who element method-name)
  (unless (fullscreen-method-present? (element-unwrap element) method-name)
    (raise-arguments-error who
                           (string-append "Element." method-name " is not available"))))

;; fullscreen-callback->external : symbol? any/c -> external/raw
;;   Convert a callback to a stable external callback wrapper.
(define (fullscreen-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref fullscreen-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply callback args)
             (void))))
        (hash-set! fullscreen-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; fullscreen-supported? : -> boolean?
;;   Report whether the browser exposes the core Fullscreen API methods.
(define (fullscreen-supported?)
  (define doc-raw (fullscreen-document-raw))
  (define root (document-element))
  (and root
       (fullscreen-method-present? doc-raw "exitFullscreen")
       (fullscreen-method-present? (element-unwrap root) "requestFullscreen")))

;; fullscreen-enabled? : -> boolean?
;;   Report whether the current document allows fullscreen requests.
(define (fullscreen-enabled?)
  (and (fullscreen-supported?)
       (begin
         (check-fullscreen-document-property 'fullscreen-enabled? "fullscreenEnabled")
         #t)
       (js-ref (fullscreen-document-raw) "fullscreenEnabled")))

;; fullscreen-element : -> (or/c #f dom-element?)
;;   Read the current fullscreen element, if any.
(define (fullscreen-element)
  (check-fullscreen-document-nullable-property 'fullscreen-element "fullscreenElement")
  (element-wrap (js-ref/extern (fullscreen-document-raw) "fullscreenElement")))

;; fullscreen-active? : -> boolean?
;;   Report whether any element is currently in fullscreen mode.
(define (fullscreen-active?)
  (not (eq? (fullscreen-element) #f)))

;; fullscreen-elementish? : any/c -> boolean?
;;   Recognize a wrapped or raw browser element.
(define (fullscreen-elementish? value)
  (or (dom-element? value)
      (fullscreen-raw-host-value? value)))

;; fullscreen-request! : (or/c dom-element? external?) -> js-promise?
;;   Request fullscreen display for element.
(define (fullscreen-request! element)
  (unless (fullscreen-elementish? element)
    (raise-argument-error 'fullscreen-request! "(or/c dom-element? external?)" element))
  (check-fullscreen-element-method 'fullscreen-request! element "requestFullscreen")
  (js-promise-wrap-result
   'fullscreen-request!
   "requestFullscreen"
   (js-send/extern (element-unwrap element) "requestFullscreen" (vector))
   "Element"))

;; fullscreen-exit! : -> js-promise?
;;   Exit fullscreen mode for the current document.
(define (fullscreen-exit!)
  (check-fullscreen-document-method 'fullscreen-exit! "exitFullscreen")
  (js-promise-wrap-result
   'fullscreen-exit!
   "exitFullscreen"
   (js-send/extern (fullscreen-document-raw) "exitFullscreen" (vector))
   "document"))

;; fullscreen-add-change-listener! : (or/c procedure? external?) -> external/raw
;;   Add a fullscreenchange listener to the current document.
(define (fullscreen-add-change-listener! callback)
  (check-fullscreen-document-method 'fullscreen-add-change-listener! "addEventListener")
  (define callback* (fullscreen-callback->external 'fullscreen-add-change-listener! callback))
  (js-send/extern/nullish (fullscreen-document-raw)
                          "addEventListener"
                          (vector "fullscreenchange" callback*))
  callback*)

;; fullscreen-remove-change-listener! : (or/c procedure? external?) -> void?
;;   Remove a previously installed fullscreenchange listener.
(define (fullscreen-remove-change-listener! callback)
  (check-fullscreen-document-method 'fullscreen-remove-change-listener! "removeEventListener")
  (define callback* (fullscreen-callback->external 'fullscreen-remove-change-listener! callback))
  (js-send/extern/nullish (fullscreen-document-raw)
                          "removeEventListener"
                          (vector "fullscreenchange" callback*))
  (void))

;; fullscreen-add-error-listener! : (or/c procedure? external?) -> external/raw
;;   Add a fullscreenerror listener to the current document.
(define (fullscreen-add-error-listener! callback)
  (check-fullscreen-document-method 'fullscreen-add-error-listener! "addEventListener")
  (define callback* (fullscreen-callback->external 'fullscreen-add-error-listener! callback))
  (js-send/extern/nullish (fullscreen-document-raw)
                          "addEventListener"
                          (vector "fullscreenerror" callback*))
  callback*)

;; fullscreen-remove-error-listener! : (or/c procedure? external?) -> void?
;;   Remove a previously installed fullscreenerror listener.
(define (fullscreen-remove-error-listener! callback)
  (check-fullscreen-document-method 'fullscreen-remove-error-listener! "removeEventListener")
  (define callback* (fullscreen-callback->external 'fullscreen-remove-error-listener! callback))
  (js-send/extern/nullish (fullscreen-document-raw)
                          "removeEventListener"
                          (vector "fullscreenerror" callback*))
  (void))
