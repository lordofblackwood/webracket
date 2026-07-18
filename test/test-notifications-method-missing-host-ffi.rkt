#lang webracket/base

;; Browser smoke for Notifications wrapper host-method boundary errors.

(require notifications
         (only-in webracket/unsafe/standard
                  js-eval))

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
        this.title = title;
        this.body = options && options.body || '';
        this.tag = options && options.tag || '';
        this.data = options && options.data;
        this.icon = options && options.icon || '';
        this.requireInteraction = !!(options && options.requireInteraction);
        this.renotify = !!(options && options.renotify);
        this.silent = !!(options && options.silent);
      }
      close() {}
    };
    if (missing === 'requestPermission') {
      delete globalThis.Notification.requestPermission;
    } else {
      delete globalThis.Notification.prototype[missing];
    }
  };
  globalThis.__wrNotificationBoundaryHide = () => {
    globalThis.Notification = undefined;
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
    delete globalThis.__wrNotificationBoundaryRestoreNotification;
    delete globalThis.__wrNotificationBoundaryRestore;
  };")

(define (constructor-missing-message thunk)
  (js-eval "__wrNotificationBoundaryHide();")
  (define message (catch-message thunk))
  (js-eval "__wrNotificationBoundaryRestoreNotification();")
  message)

(define (missing-method-message method thunk)
  (js-eval (string-append "__wrNotificationBoundaryInstall('"
                          method
                          "')"))
  (catch-message thunk))

(define request-permission-unsupported-message
  (constructor-missing-message
   (lambda ()
     (notification-request-permission))))

(define make-unsupported-message
  (constructor-missing-message
   (lambda ()
     (make-notification "WebRacket"))))

(define request-permission-message
  (missing-method-message
   "requestPermission"
   (lambda ()
     (notification-request-permission))))

(define close-message
  (missing-method-message
   "close"
   (lambda ()
     (define n (make-notification "WebRacket"))
     (check-true (notification? n)
                 "notification? accepts fake host notification")
     (notification-close! n))))

(check-message request-permission-message
               "Notification.requestPermission is not available"
               "missing Notification.requestPermission message")
(check-message request-permission-unsupported-message
               "Notification is not available"
               "missing notification request unsupported message")
(check-message make-unsupported-message
               "Notification is not available"
               "missing make-notification unsupported message")
(check-message close-message
               "Notification.close is not available"
               "missing Notification.close message")

(js-eval "__wrNotificationBoundaryRestore();")

(js-log "notifications-method-missing-host-ffi-ok")
#t
