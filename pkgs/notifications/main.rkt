#lang webracket/base

(require js/promise
         (only-in webracket/unsafe/dom
                  js-instanceof
                  js-nullish?
                  js-new
                  js-object
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-typeof
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
  (string=? (js-typeof (js-var "Notification")) "function"))

;; notification-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable Notification method.
(define (notification-host-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; notification-host-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish Notification property.
(define (notification-host-property-present? raw property-name)
  (not (js-nullish? (js-ref/extern raw property-name))))

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

(define (notification raw)
  (notification-info raw))

(define (notification-raw value)
  (notification-info-raw value))

(define (notification? v)
  (and (notification-info? v)
       (notifications-supported?)
       (external? (notification-raw v))
       (js-instanceof (notification-raw v) (js-var "Notification"))))

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
  (js-promise-wrap
   (js-send/extern (js-var "Notification") "requestPermission" (vector))))

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
  (unless (notification? value)
    (raise-argument-error 'notification-close! "notification?" value))
  (check-notification-host-method 'notification-close!
                                  (notification-raw value)
                                  "Notification"
                                  "close")
  (js-send/extern/nullish (notification-raw value) "close" (vector))
  (void))

(define (notification-title value)
  (unless (notification? value)
    (raise-argument-error 'notification-title "notification?" value))
  (check-notification-host-property 'notification-title
                                    (notification-raw value)
                                    "Notification"
                                    "title")
  (js-ref (notification-raw value) "title"))

(define (notification-body value)
  (unless (notification? value)
    (raise-argument-error 'notification-body "notification?" value))
  (check-notification-host-property 'notification-body
                                    (notification-raw value)
                                    "Notification"
                                    "body")
  (js-ref (notification-raw value) "body"))

(define (notification-tag value)
  (unless (notification? value)
    (raise-argument-error 'notification-tag "notification?" value))
  (check-notification-host-property 'notification-tag
                                    (notification-raw value)
                                    "Notification"
                                    "tag")
  (js-ref (notification-raw value) "tag"))

(define (notification-data value)
  (unless (notification? value)
    (raise-argument-error 'notification-data "notification?" value))
  (js-ref (notification-raw value) "data"))

(define (notification-icon value)
  (unless (notification? value)
    (raise-argument-error 'notification-icon "notification?" value))
  (check-notification-host-property 'notification-icon
                                    (notification-raw value)
                                    "Notification"
                                    "icon")
  (js-ref (notification-raw value) "icon"))

(define (notification-require-interaction? value)
  (unless (notification? value)
    (raise-argument-error 'notification-require-interaction? "notification?" value))
  (check-notification-host-property 'notification-require-interaction?
                                    (notification-raw value)
                                    "Notification"
                                    "requireInteraction")
  (js-ref (notification-raw value) "requireInteraction"))

(define (notification-renotify? value)
  (unless (notification? value)
    (raise-argument-error 'notification-renotify? "notification?" value))
  (check-notification-host-property 'notification-renotify?
                                    (notification-raw value)
                                    "Notification"
                                    "renotify")
  (js-ref (notification-raw value) "renotify"))

(define (notification-silent? value)
  (unless (notification? value)
    (raise-argument-error 'notification-silent? "notification?" value))
  (check-notification-host-property 'notification-silent?
                                    (notification-raw value)
                                    "Notification"
                                    "silent")
  (js-ref (notification-raw value) "silent"))
