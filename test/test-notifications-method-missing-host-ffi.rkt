#lang webracket/base

;; Browser smoke for Notifications wrapper host-boundary errors.

(require notifications
         (only-in webracket/unsafe/dom
                  js-eval
                  js-null
                  js-undefined))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(js-eval
 "globalThis.__wrNotificationBoundarySaved = globalThis.Notification;
  globalThis.__wrNotificationBoundaryInstall = (missing) => {
    const thenable = {
      then(fn) { fn('default'); return this; },
      catch(_fn) { return this; }
    };
    globalThis.Notification = class Notification {
      static permission = 'default';
      static requestPermission() { return thenable; }
      constructor(title, options) {
        if (missing !== 'title') this.title = title;
        if (missing !== 'body') this.body = options && options.body || '';
        if (missing !== 'tag') this.tag = options && options.tag || '';
        if (missing !== 'data') this.data = options && options.data || null;
        if (missing !== 'icon') this.icon = options && options.icon || '';
        if (missing !== 'requireInteraction') this.requireInteraction = !!(options && options.requireInteraction);
        if (missing !== 'renotify') this.renotify = !!(options && options.renotify);
        if (missing !== 'silent') this.silent = !!(options && options.silent);
      }
      close() {}
    };
    if (missing === 'requestPermission') {
      delete globalThis.Notification.requestPermission;
    } else if (missing === 'permission') {
      delete globalThis.Notification.permission;
    } else {
      delete globalThis.Notification.prototype[missing];
    }
  };
  globalThis.__wrNotificationBoundaryHide = () => {
    globalThis.Notification = undefined;
  };
  globalThis.__wrNotificationBoundaryInstallNonConstructor = () => {
    globalThis.Notification = () => {};
  };
  globalThis.__wrNotificationBoundaryRestoreNotification = () => {
    if (globalThis.__wrNotificationBoundarySaved === undefined) {
      delete globalThis.Notification;
    } else {
      globalThis.Notification = globalThis.__wrNotificationBoundarySaved;
    }
  };
  globalThis.__wrNotificationBoundaryRestore = () => {
    globalThis.__wrNotificationBoundaryRestoreNotification();
    delete globalThis.__wrNotificationBoundarySaved;
    delete globalThis.__wrNotificationBoundaryInstall;
    delete globalThis.__wrNotificationBoundaryHide;
    delete globalThis.__wrNotificationBoundaryInstallNonConstructor;
    delete globalThis.__wrNotificationBoundaryRestoreNotification;
    delete globalThis.__wrNotificationBoundaryRestore;
  };")

(define (constructor-missing-message thunk)
  (js-eval "__wrNotificationBoundaryHide();")
  (define message (catch-message thunk))
  (js-eval "__wrNotificationBoundaryRestoreNotification();")
  message)

(define (constructor-non-constructor-message thunk)
  (js-eval "__wrNotificationBoundaryInstallNonConstructor();")
  (define message (catch-message thunk))
  (js-eval "__wrNotificationBoundaryRestoreNotification();")
  message)

(define (missing-method-message method thunk)
  (js-eval (string-append "__wrNotificationBoundaryInstall('"
                          method
                          "')"))
  (catch-message thunk))

(define (with-installed-notification missing thunk)
  (js-eval (string-append "__wrNotificationBoundaryInstall('"
                          missing
                          "')"))
  (define result (thunk))
  (js-eval "__wrNotificationBoundaryRestoreNotification();")
  result)

(define (make-fake-notification)
  (make-notification
   "WebRacket"
   (make-notification-options ""
                              ""
                              ""
                              #f
                              #f
                              #f
                              #f)))

(define (notification-predicate-result missing)
  (with-installed-notification
   missing
   (lambda ()
     (notification? (make-fake-notification)))))

(define request-permission-unsupported-message
  (constructor-missing-message
   (lambda ()
     (notification-request-permission))))

(define make-unsupported-message
  (constructor-missing-message
   (lambda ()
     (make-notification "WebRacket"))))

(define request-permission-non-constructor-message
  (constructor-non-constructor-message
   (lambda ()
     (notification-request-permission))))

(define make-non-constructor-message
  (constructor-non-constructor-message
   (lambda ()
     (make-notification "WebRacket"))))

(define request-permission-message
  (missing-method-message
   "requestPermission"
   (lambda ()
     (notification-request-permission))))

(define permission-message
  (missing-method-message
   "permission"
   (lambda ()
     (notification-permission))))

(define close-message
  (missing-method-message
   "close"
   (lambda ()
     (define n (make-notification "WebRacket"))
     (check-true (notification? n)
                 "notification? accepts fake host notification")
     (notification-close! n))))

(define title-message
  (missing-method-message
   "title"
   (lambda ()
     (notification-title (make-notification "WebRacket")))))

(define body-message
  (missing-method-message
   "body"
   (lambda ()
     (notification-body (make-notification "WebRacket")))))

(define tag-message
  (missing-method-message
   "tag"
   (lambda ()
     (notification-tag (make-notification "WebRacket")))))

(define data-message
  (missing-method-message
   "data"
   (lambda ()
     (notification-data (make-notification "WebRacket")))))

(define icon-message
  (missing-method-message
   "icon"
   (lambda ()
     (notification-icon (make-notification "WebRacket")))))

(define require-interaction-message
  (missing-method-message
   "requireInteraction"
   (lambda ()
     (notification-require-interaction? (make-notification "WebRacket")))))

(define renotify-message
  (missing-method-message
   "renotify"
   (lambda ()
     (notification-renotify? (make-notification "WebRacket")))))

(define silent-message
  (missing-method-message
   "silent"
   (lambda ()
     (notification-silent? (make-notification "WebRacket")))))

(define null-raw-notification
  (notification-info (js-null)))

(define undefined-raw-notification
  (notification-info (js-undefined)))

(check-true (notification-predicate-result "notAProperty")
            "notification? accepts present falsy Notification properties")
(check-true (not (notification-predicate-result "title"))
            "notification? rejects Notification missing title")
(check-true (not (notification-predicate-result "body"))
            "notification? rejects Notification missing body")
(check-true (not (notification-predicate-result "tag"))
            "notification? rejects Notification missing tag")
(check-true (not (notification-predicate-result "data"))
            "notification? rejects Notification missing data")
(check-true (not (notification-predicate-result "icon"))
            "notification? rejects Notification missing icon")
(check-true (not (notification-predicate-result "requireInteraction"))
            "notification? rejects Notification missing requireInteraction")
(check-true (not (notification-predicate-result "renotify"))
            "notification? rejects Notification missing renotify")
(check-true (not (notification-predicate-result "silent"))
            "notification? rejects Notification missing silent")
(check-true (not (notification? null-raw-notification))
            "notification? rejects null raw")
(check-true (not (notification? undefined-raw-notification))
            "notification? rejects undefined raw")

(define notification-null-raw-message
  (catch-message
   (lambda ()
     (notification-title null-raw-notification))))

(define notification-undefined-raw-message
  (catch-message
   (lambda ()
     (notification-title undefined-raw-notification))))

(check-message request-permission-message
               "Notification.requestPermission is not available"
               "missing Notification.requestPermission message")
(check-message permission-message
               "Notification.permission is not available"
               "missing Notification.permission message")
(check-message request-permission-unsupported-message
               "Notification is not available"
               "missing notification request unsupported message")
(check-message make-unsupported-message
               "Notification is not available"
               "missing make-notification unsupported message")
(check-message request-permission-non-constructor-message
               "Notification is not available"
               "non-constructible notification request unsupported message")
(check-message make-non-constructor-message
               "Notification is not available"
               "non-constructible make-notification unsupported message")
(check-message close-message
               "Notification.close is not available"
               "missing Notification.close message")
(check-message title-message
               "Notification.title is not available"
               "missing Notification.title message")
(check-message body-message
               "Notification.body is not available"
               "missing Notification.body message")
(check-message tag-message
               "Notification.tag is not available"
               "missing Notification.tag message")
(check-message data-message
               "Notification.data is not available"
               "missing Notification.data message")
(check-message icon-message
               "Notification.icon is not available"
               "missing Notification.icon message")
(check-message require-interaction-message
               "Notification.requireInteraction is not available"
               "missing Notification.requireInteraction message")
(check-message renotify-message
               "Notification.renotify is not available"
               "missing Notification.renotify message")
(check-message silent-message
               "Notification.silent is not available"
               "missing Notification.silent message")
(check-message notification-null-raw-message
               "notification?"
               "missing Notification null raw message")
(check-message notification-undefined-raw-message
               "notification?"
               "missing Notification undefined raw message")

(js-eval "__wrNotificationBoundaryRestore();")

(js-log "notifications-method-missing-host-ffi-ok")
#t
