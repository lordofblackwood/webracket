#lang webracket/base

(require browser/dom
         js/promise
         notifications
         (only-in webracket/primitives
                  procedure->external))

(define latest-notification #f)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-status! elem text)
  (js-set! elem "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: #f7f5ff; color: #241b35; }
          main { max-width: 760px; margin: 0 auto; padding: 32px 20px; }
          .actions { display: flex; gap: 12px; flex-wrap: wrap; margin: 18px 0; }
          button { border: 0; border-radius: 999px; padding: 12px 18px; cursor: pointer; font-weight: 700; }
          .primary { background: #0f172a; color: white; }
          .secondary { background: #ddd6fe; color: #5b21b6; }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define h1 (js-create-element "h1"))
(define intro (js-create-element "p"))
(define actions (js-create-element "div"))
(define request-button (js-create-element "button"))
(define send-button (js-create-element "button"))
(define close-button (js-create-element "button"))
(define status (js-create-element "p"))

(js-set-attribute! actions "class" "actions")
(js-set-attribute! request-button "class" "primary")
(js-set-attribute! send-button "class" "secondary")
(js-set-attribute! close-button "class" "secondary")

(append-text-node! h1 "Notifications Demo")
(append-text-node! intro "Request permission, then send a browser notification.")
(append-text-node! request-button "Request permission")
(append-text-node! send-button "Send notification")
(append-text-node! close-button "Close latest notification")
(append-text-node! status
                   (format "Current permission: ~a"
                           (notification-permission)))

(define (request-permission!)
  (if (notifications-supported?)
      (begin
        (set-status! status "Requesting notification permission...")
        (js-promise-then
         (notification-request-permission)
         (lambda (permission)
           (set-status! status (format "Permission result: ~a" permission))
           (void))))
      (set-status! status "Notifications are not available here.")))

(define (send-notification!)
  (cond
    [(not (notifications-supported?))
     (set-status! status "Notifications are not available here.")]
    [(not (equal? (notification-permission) "granted"))
     (set-status! status "Permission is not granted yet.")]
    [else
     (set! latest-notification
           (make-notification
            "WebRacket notification"
            (make-notification-options
             "This notification came from the module-based wrapper."
             #f
             "webracket-demo"
             #f
             #f
             #f
             #f)))
     (set-status! status (format "Sent notification: ~a" (notification-title latest-notification)))]))

(define (close-latest!)
  (if (and latest-notification (notification? latest-notification))
      (begin
        (notification-close! latest-notification)
        (set-status! status "Closed the latest notification."))
      (set-status! status "No notification has been created yet.")))

(js-append-child! actions request-button)
(js-append-child! actions send-button)
(js-append-child! actions close-button)
(js-append-child! main h1)
(js-append-child! main intro)
(js-append-child! main actions)
(js-append-child! main status)
(js-append-child! body main)

(js-add-event-listener! request-button "click" (procedure->external (lambda (_evt) (request-permission!) (void))))
(js-add-event-listener! send-button "click" (procedure->external (lambda (_evt) (send-notification!) (void))))
(js-add-event-listener! close-button "click" (procedure->external (lambda (_evt) (close-latest!) (void))))
