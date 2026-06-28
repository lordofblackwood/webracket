#lang webracket/base

(require browser/dom
         geolocation
         (only-in webracket/primitives
                  procedure->external))

(define current-watch-id #f)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-status! elem text)
  (js-set! elem "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: #f6f5f2; color: #263238; }
          main { max-width: 760px; margin: 0 auto; padding: 32px 20px; }
          .actions { display: flex; gap: 12px; flex-wrap: wrap; margin: 18px 0; }
          button { border: 0; border-radius: 999px; padding: 12px 18px; cursor: pointer; font-weight: 700; }
          .primary { background: #0f766e; color: white; }
          .secondary { background: #dbeafe; color: #1d4ed8; }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define h1 (js-create-element "h1"))
(define intro (js-create-element "p"))
(define actions (js-create-element "div"))
(define read-button (js-create-element "button"))
(define watch-button (js-create-element "button"))
(define stop-button (js-create-element "button"))
(define status (js-create-element "p"))

(js-set-attribute! actions "class" "actions")
(js-set-attribute! read-button "class" "primary")
(js-set-attribute! watch-button "class" "secondary")
(js-set-attribute! stop-button "class" "secondary")

(append-text-node! h1 "Geolocation Demo")
(append-text-node! intro "Use the buttons to read your current position or start a watch.")
(append-text-node! read-button "Read current position")
(append-text-node! watch-button "Start watch")
(append-text-node! stop-button "Stop watch")
(append-text-node! status "Status: waiting")

(define (format-position position)
  (define coords (geolocation-position-coordinates position))
  (format "Lat ~a, Lon ~a, accuracy ~am"
          (geolocation-coordinates-latitude coords)
          (geolocation-coordinates-longitude coords)
          (geolocation-coordinates-accuracy coords)))

(define geo (geolocation))

(define (on-success position)
  (set-status! status (format-position position)))

(define (on-error err)
  (set-status! status
               (format "Error ~a: ~a"
                       (geolocation-position-error-code err)
                       (geolocation-position-error-message err))))

(define (read-current-position)
  (if geo
      (begin
        (set-status! status "Reading current position...")
        (geolocation-get-current-position
         geo
         on-success
         on-error
         (make-geolocation-options #t 10000 0)))
      (set-status! status "Geolocation is not available here.")))

(define (start-watch)
  (if geo
      (begin
        (when current-watch-id
          (geolocation-clear-watch! geo current-watch-id))
        (set! current-watch-id
              (geolocation-watch-position
               geo
               on-success
               on-error
               (make-geolocation-options #t 10000 0)))
        (set-status! status "Started geolocation watch."))
      (set-status! status "Geolocation is not available here.")))

(define (stop-watch)
  (cond
    [(and geo current-watch-id)
     (geolocation-clear-watch! geo current-watch-id)
     (set! current-watch-id #f)
     (set-status! status "Stopped geolocation watch.")]
    [else
     (set-status! status "No active geolocation watch.")]))

(js-append-child! actions read-button)
(js-append-child! actions watch-button)
(js-append-child! actions stop-button)
(js-append-child! main h1)
(js-append-child! main intro)
(js-append-child! main actions)
(js-append-child! main status)
(js-append-child! body main)

(js-add-event-listener! read-button "click" (procedure->external (lambda (_evt) (read-current-position) (void))))
(js-add-event-listener! watch-button "click" (procedure->external (lambda (_evt) (start-watch) (void))))
(js-add-event-listener! stop-button "click" (procedure->external (lambda (_evt) (stop-watch) (void))))
