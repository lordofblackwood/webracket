#lang webracket/base

(require js/promise
         (only-in webracket/unsafe/dom
                  js-constructible?
                  js-instanceof
                  js-nullish?
                  js-new
                  js-object
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-typeof
                  js-undefined?
                  js-var)
         (only-in webracket/primitives
                  external?))

(provide (all-defined-out))

;;;
;;; Notifications wrappers
;;;

(struct notification-info (raw) #:transparent)

(struct notification-options (body icon tag data silent require-interaction renotify)
  #:transparent
  #:constructor-name make-notification-options
  #:guard
  (lambda (body icon tag data silent require-interaction renotify name)
    (unless (or (eq? body #f) (string? body) (symbol? body))
      (raise-argument-error name "(or/c #f string? symbol?)" body))
    (unless (or (eq? icon #f) (string? icon) (symbol? icon))
      (raise-argument-error name "(or/c #f string? symbol?)" icon))
    (unless (or (eq? tag #f) (string? tag) (symbol? tag))
      (raise-argument-error name "(or/c #f string? symbol?)" tag))
    (unless (or (eq? silent #f) (boolean? silent))
      (raise-argument-error name "(or/c #f boolean?)" silent))
    (unless (or (eq? require-interaction #f) (boolean? require-interaction))
      (raise-argument-error name "(or/c #f boolean?)" require-interaction))
    (unless (or (eq? renotify #f) (boolean? renotify))
      (raise-argument-error name "(or/c #f boolean?)" renotify))
    (values body icon tag data silent require-interaction renotify)))

(define (notifications-supported?)
  (js-constructible? (js-var "Notification")))

;; notification-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable Notification method.
(define (notification-host-method-present? raw method-name)
  (and (notification-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; notification-host-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish Notification property.
(define (notification-host-property-present? raw property-name)
  (and (notification-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; notification-host-nullable-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a Notification property, allowing null values.
(define (notification-host-nullable-property-present? raw property-name)
  (and (notification-raw-host-value? raw)
       (not (js-undefined? (js-ref/extern raw property-name)))))

;; notification-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (notification-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; check-notification-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required Notification host method is available.
(define (check-notification-host-method who raw receiver-name method-name)
  (unless (notification-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " is not available"))))

;; check-notification-host-property : symbol? external/raw string? string? -> void?
;;   Ensure a required Notification host property is available.
(define (check-notification-host-property who raw receiver-name property-name)
  (unless (notification-host-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " is not available"))))

;; check-notification-host-nullable-property : symbol? external/raw string? string? -> void?
;;   Ensure a required nullable Notification host property is available.
(define (check-notification-host-nullable-property who raw receiver-name property-name)
  (unless (notification-host-nullable-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " is not available"))))

(define (notification raw)
  (notification-info raw))

(define (notification-raw value)
  (notification-info-raw value))

(define (notification? v)
  (and (notification-host-value? v)
       (notification-required-properties-present? (notification-raw v))))

;; notification-host-value? : any/c -> boolean?
;;   Report whether v wraps an external Notification-like host value.
(define (notification-host-value? v)
  (and (notification-info? v)
       (notifications-supported?)
       (notification-raw-host-value? (notification-raw v))
       (js-instanceof (notification-raw v) (js-var "Notification"))))

;; notification-required-properties-present? : external/raw -> boolean?
;;   Report whether raw exposes the required Notification data properties.
(define (notification-required-properties-present? raw)
  (and (notification-host-property-present? raw "title")
       (notification-host-property-present? raw "body")
       (notification-host-property-present? raw "tag")
       (notification-host-nullable-property-present? raw "data")
       (notification-host-property-present? raw "icon")
       (notification-host-property-present? raw "requireInteraction")
       (notification-host-property-present? raw "renotify")
       (notification-host-property-present? raw "silent")))

;; check-notification : symbol? any/c -> void?
;;   Ensure value wraps an external Notification-like host value.
(define (check-notification who value)
  (unless (notification-host-value? value)
    (raise-argument-error who "notification?" value)))

(define (notification-stringish->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" value)]))

(define (notification-optional-string who value)
  (if (eq? value #f)
      #f
      (notification-stringish->string who value)))

(define (notification-options->raw options)
  (define body (notification-options-body options))
  (define icon (notification-options-icon options))
  (define tag (notification-options-tag options))
  (define data (notification-options-data options))
  (define silent (notification-options-silent options))
  (define require-interaction (notification-options-require-interaction options))
  (define renotify (notification-options-renotify options))
  (define fields
    (append
     (if (eq? body #f) '() (list (vector "body" (notification-optional-string 'make-notification body))))
     (if (eq? icon #f) '() (list (vector "icon" (notification-optional-string 'make-notification icon))))
     (if (eq? tag #f) '() (list (vector "tag" (notification-optional-string 'make-notification tag))))
     (if (eq? data #f) '() (list (vector "data" data)))
     (if (eq? silent #f) '() (list (vector "silent" silent)))
     (if (eq? require-interaction #f) '() (list (vector "requireInteraction" require-interaction)))
     (if (eq? renotify #f) '() (list (vector "renotify" renotify)))))
  (js-object (list->vector fields)))

(define (notification-permission)
  (if (notifications-supported?)
      (begin
        (check-notification-host-property 'notification-permission
                                          (js-var "Notification")
                                          "Notification"
                                          "permission")
        (js-ref (js-var "Notification") "permission"))
      #f))

(define (notification-request-permission)
  (unless (notifications-supported?)
    (raise-arguments-error 'notification-request-permission "Notification is not available"))
  (check-notification-host-method 'notification-request-permission
                                  (js-var "Notification")
                                  "Notification"
                                  "requestPermission")
  (js-promise-wrap-result
   'notification-request-permission
   "requestPermission"
   (js-send/extern (js-var "Notification") "requestPermission" (vector))
   "Notification"))

(define (make-notification title [options #f])
  (unless (notifications-supported?)
    (raise-arguments-error 'make-notification "Notification is not available"))
  (unless (or (eq? options #f) (notification-options? options))
    (raise-argument-error 'make-notification "(or/c #f notification-options?)" options))
  (define title* (notification-stringish->string 'make-notification title))
  (notification
   (if (eq? options #f)
       (js-new (js-var "Notification") (vector title*))
       (js-new (js-var "Notification")
               (vector title*
                       (notification-options->raw options))))))

(define (notification-close! value)
  (check-notification 'notification-close! value)
  (check-notification-host-method 'notification-close!
                                  (notification-raw value)
                                  "Notification"
                                  "close")
  (js-send/extern/nullish (notification-raw value) "close" (vector))
  (void))

(define (notification-title value)
  (check-notification 'notification-title value)
  (check-notification-host-property 'notification-title
                                    (notification-raw value)
                                    "Notification"
                                    "title")
  (js-ref (notification-raw value) "title"))

(define (notification-body value)
  (check-notification 'notification-body value)
  (check-notification-host-property 'notification-body
                                    (notification-raw value)
                                    "Notification"
                                    "body")
  (js-ref (notification-raw value) "body"))

(define (notification-tag value)
  (check-notification 'notification-tag value)
  (check-notification-host-property 'notification-tag
                                    (notification-raw value)
                                    "Notification"
                                    "tag")
  (js-ref (notification-raw value) "tag"))

(define (notification-data value)
  (check-notification 'notification-data value)
  (check-notification-host-nullable-property 'notification-data
                                             (notification-raw value)
                                             "Notification"
                                             "data")
  (js-ref (notification-raw value) "data"))

(define (notification-icon value)
  (check-notification 'notification-icon value)
  (check-notification-host-property 'notification-icon
                                    (notification-raw value)
                                    "Notification"
                                    "icon")
  (js-ref (notification-raw value) "icon"))

(define (notification-require-interaction? value)
  (check-notification 'notification-require-interaction? value)
  (check-notification-host-property 'notification-require-interaction?
                                    (notification-raw value)
                                    "Notification"
                                    "requireInteraction")
  (js-ref (notification-raw value) "requireInteraction"))

(define (notification-renotify? value)
  (check-notification 'notification-renotify? value)
  (check-notification-host-property 'notification-renotify?
                                    (notification-raw value)
                                    "Notification"
                                    "renotify")
  (js-ref (notification-raw value) "renotify"))

(define (notification-silent? value)
  (check-notification 'notification-silent? value)
  (check-notification-host-property 'notification-silent?
                                    (notification-raw value)
                                    "Notification"
                                    "silent")
  (js-ref (notification-raw value) "silent"))
