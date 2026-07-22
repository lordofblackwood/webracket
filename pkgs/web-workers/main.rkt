#lang webracket/base

(require webracket/unsafe/dom
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide make-worker
         worker-supported?
         worker-raw
         worker?
         worker-post-message!
         worker-terminate!
         worker-onmessage!
         worker-onerror!
         worker-add-event-listener!
         worker-remove-event-listener!
         make-worker-options
         worker-options?
         worker-options-type
         worker-options-name
         worker-options-credentials)

;;;
;;; Web Worker wrappers
;;;

(struct worker-info (raw) #:transparent)

(struct worker-options (type name credentials)
  #:transparent
  #:constructor-name make-worker-options
  #:guard
  (lambda (type name credentials ctor-name)
    (unless (or (eq? type #f) (string? type) (symbol? type))
      (raise-argument-error ctor-name "(or/c #f string? symbol?)" type))
    (unless (or (eq? name #f) (string? name) (symbol? name))
      (raise-argument-error ctor-name "(or/c #f string? symbol?)" name))
    (unless (or (eq? credentials #f) (string? credentials) (symbol? credentials))
      (raise-argument-error ctor-name "(or/c #f string? symbol?)" credentials))
    (values type name credentials)))

(define worker-callback-cache (make-hasheq))

;; worker-raw : worker? -> external/raw
;;   Extract the raw browser Worker object.
(define (worker-raw value)
  (worker-info-raw value))

;; worker-stringish->string : symbol? any/c -> string?
;;   Normalize a string-like argument to a browser string.
(define (worker-stringish->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" value)]))

;; worker-constructor : -> external/raw
;;   Read the browser Worker constructor.
(define (worker-constructor)
  (js-var "Worker"))

;; worker-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (worker-method-present? raw method-name)
  (and (worker-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; worker-nullable-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a property, allowing null values.
(define (worker-nullable-property-present? raw property-name)
  (and (worker-raw-host-value? raw)
       (not (js-undefined? (js-ref/extern raw property-name)))))

;; worker-core-surface-present? : external/raw -> boolean?
;;   Report whether raw has the required Worker surface.
(define (worker-core-surface-present? raw)
  (and (worker-method-present? raw "postMessage")
       (worker-method-present? raw "terminate")
       (worker-method-present? raw "addEventListener")
       (worker-method-present? raw "removeEventListener")
       (worker-nullable-property-present? raw "onmessage")
       (worker-nullable-property-present? raw "onerror")))

;; worker-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (worker-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; worker-supported? : -> boolean?
;;   Report whether the browser exposes the Worker constructor.
(define (worker-supported?)
  (js-constructible? (worker-constructor)))

;; worker? : any/c -> boolean?
;;   Report whether v is a wrapped browser Worker object.
(define (worker? v)
  (and (worker-host-value? v)
       (worker-core-surface-present? (worker-raw v))))

;; worker-host-value? : any/c -> boolean?
;;   Report whether v wraps an external Worker-like host value.
(define (worker-host-value? v)
  (and (worker-info? v)
       (worker-supported?)
       (worker-raw-host-value? (worker-raw v))
       (js-instanceof (worker-raw v) (worker-constructor))))

;; check-worker : symbol? any/c -> void?
;;   Ensure value is a wrapped Worker object.
(define (check-worker who value)
  (unless (worker-host-value? value)
    (raise-argument-error who "worker?" value)))

;; worker-check-instance-result : symbol? string? any/c -> external/raw
;;   Validate that a Worker constructor returned a Worker instance.
(define (worker-check-instance-result who display-name raw)
  (unless (and (worker-raw-host-value? raw)
               (js-instanceof raw (worker-constructor)))
    (raise-arguments-error who
                           (string-append display-name
                                          " result must be Worker")))
  raw)

;; check-worker-method : symbol? worker? string? -> void?
;;   Ensure a required Worker method is available.
(define (check-worker-method who value method-name)
  (unless (worker-method-present? (worker-raw value) method-name)
    (raise-arguments-error who
                           (string-append "Worker." method-name " is not available"))))

;; check-worker-nullable-property : symbol? worker? string? -> void?
;;   Ensure a required nullable Worker property is available.
(define (check-worker-nullable-property who value property-name)
  (unless (worker-nullable-property-present? (worker-raw value) property-name)
    (raise-arguments-error who
                           (string-append "Worker." property-name " is not available"))))

;; worker-callback->external : symbol? any/c -> external/raw
;;   Convert a callback to a stable external callback wrapper.
(define (worker-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref worker-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply callback args)
             (void))))
        (hash-set! worker-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; worker-handler->external : symbol? any/c -> external/raw
;;   Convert a handler to an external callback or JS null.
(define (worker-handler->external who handler)
  (cond
    [(eq? handler #f) (js-null)]
    [else (worker-callback->external who handler)]))

;; worker-message-value? : any/c -> boolean?
;;   Conservatively recognize values suitable for worker postMessage.
(define (worker-message-value? value)
  (cond
    [(or (eq? value #f)
         (boolean? value)
         (string? value)
         (symbol? value)
         (real? value)
         (bytes? value)
         (external? value))
     #t]
    [(null? value) #t]
    [(pair? value)
     (and (worker-message-value? (car value))
          (worker-message-value? (cdr value)))]
    [(vector? value)
     (for/and ([entry (in-vector value)])
       (worker-message-value? entry))]
    [else #f]))

;; worker-options->raw : worker-options? -> external/raw
;;   Convert a Rackety worker options struct to a browser dictionary.
(define (worker-options->raw options)
  (define type (worker-options-type options))
  (define name (worker-options-name options))
  (define credentials (worker-options-credentials options))
  (define fields
    (append
     (if (eq? type #f) '() (list (vector "type" (worker-stringish->string 'make-worker-options type))))
     (if (eq? name #f) '() (list (vector "name" (worker-stringish->string 'make-worker-options name))))
     (if (eq? credentials #f) '() (list (vector "credentials" (worker-stringish->string 'make-worker-options credentials))))))
  (js-object (list->vector fields)))

;; make-worker : (or/c string? symbol?) [(or/c #f worker-options?)] -> worker?
;;   Create a dedicated Worker from a script URL and optional constructor options.
(define (make-worker script-url [options #f])
  (unless (worker-supported?)
    (raise-arguments-error 'make-worker "Worker is not available"))
  (unless (or (eq? options #f) (worker-options? options))
    (raise-argument-error 'make-worker "(or/c #f worker-options?)" options))
  (define script-url* (worker-stringish->string 'make-worker script-url))
  (worker-info
   (worker-check-instance-result
    'make-worker
    "Worker constructor"
    (if (eq? options #f)
        (js-new (worker-constructor) (vector script-url*))
        (js-new (worker-constructor)
                (vector script-url*
                        (worker-options->raw options)))))))

;; worker-post-message! : worker? worker-message-value? -> void?
;;   Post a structured-cloneable message to a Worker.
(define (worker-post-message! value message)
  (check-worker 'worker-post-message! value)
  (check-worker-method 'worker-post-message! value "postMessage")
  (unless (worker-message-value? message)
    (raise-argument-error 'worker-post-message!
                          "(or/c #f boolean? string? symbol? real? bytes? external? null? pair? vector?)"
                          message))
  (js-send/extern/nullish (worker-raw value) "postMessage" (vector message))
  (void))

;; worker-terminate! : worker? -> void?
;;   Terminate a Worker immediately.
(define (worker-terminate! value)
  (check-worker 'worker-terminate! value)
  (check-worker-method 'worker-terminate! value "terminate")
  (js-send/extern/nullish (worker-raw value) "terminate" (vector))
  (void))

;; worker-set-handler! : symbol? worker? string? any/c -> void?
;;   Install or clear a Worker event handler property.
(define (worker-set-handler! who value prop handler)
  (check-worker who value)
  (unless (or (eq? handler #f) (procedure? handler) (external? handler))
    (raise-argument-error who "(or/c #f procedure? external?)" handler))
  (check-worker-nullable-property who value prop)
  (js-set! (worker-raw value) prop (worker-handler->external who handler))
  (void))

;; worker-onmessage! : worker? (or/c #f procedure? external?) -> void?
;;   Install or clear the onmessage handler.
(define (worker-onmessage! value handler)
  (worker-set-handler! 'worker-onmessage! value "onmessage" handler))

;; worker-onerror! : worker? (or/c #f procedure? external?) -> void?
;;   Install or clear the onerror handler.
(define (worker-onerror! value handler)
  (worker-set-handler! 'worker-onerror! value "onerror" handler))

;; worker-add-event-listener! : worker? (or/c string? symbol?) (or/c procedure? external?) -> external/raw
;;   Add a Worker event listener and return the installed callback.
(define (worker-add-event-listener! value event-name callback)
  (check-worker 'worker-add-event-listener! value)
  (check-worker-method 'worker-add-event-listener! value "addEventListener")
  (define event-name* (worker-stringish->string 'worker-add-event-listener! event-name))
  (define callback* (worker-callback->external 'worker-add-event-listener! callback))
  (js-send/extern/nullish (worker-raw value)
                          "addEventListener"
                          (vector event-name* callback*))
  callback*)

;; worker-remove-event-listener! : worker? (or/c string? symbol?) (or/c procedure? external?) -> void?
;;   Remove a previously installed Worker event listener.
(define (worker-remove-event-listener! value event-name callback)
  (check-worker 'worker-remove-event-listener! value)
  (check-worker-method 'worker-remove-event-listener! value "removeEventListener")
  (define event-name* (worker-stringish->string 'worker-remove-event-listener! event-name))
  (define callback* (worker-callback->external 'worker-remove-event-listener! callback))
  (js-send/extern/nullish (worker-raw value)
                          "removeEventListener"
                          (vector event-name* callback*))
  (void))
