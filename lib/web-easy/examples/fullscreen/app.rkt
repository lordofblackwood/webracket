#lang webracket/base

(require browser/dom
         fullscreen
         (only-in webracket/primitives
                  procedure->external))

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-status! elem text)
  (js-set! elem "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: linear-gradient(180deg, #fffaf0, #f0f9ff); color: #111827; }
          main { max-width: 820px; margin: 0 auto; padding: 32px 20px; }
          button { border: 0; border-radius: 999px; padding: 12px 18px; cursor: pointer; font-weight: 700; margin-right: 12px; }
          .primary { background: #b45309; color: white; }
          .secondary { background: #dbeafe; color: #1d4ed8; }
          .target { margin-top: 24px; min-height: 240px; border-radius: 28px; padding: 24px; background: radial-gradient(circle at top left, #f59e0b, #1d4ed8); color: white; box-shadow: 0 20px 50px rgba(29, 78, 216, 0.28); }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define h1 (js-create-element "h1"))
(define intro (js-create-element "p"))
(define enter-button (js-create-element "button"))
(define exit-button (js-create-element "button"))
(define status (js-create-element "p"))
(define target (js-create-element "section"))
(define target-title (js-create-element "h2"))
(define target-copy (js-create-element "p"))

(js-set-attribute! enter-button "class" "primary")
(js-set-attribute! exit-button "class" "secondary")
(js-set-attribute! target "class" "target")

(append-text-node! h1 "Fullscreen API Demo")
(append-text-node! intro "Turn the highlighted panel fullscreen and watch the status update on fullscreenchange.")
(append-text-node! enter-button "Enter fullscreen")
(append-text-node! exit-button "Exit fullscreen")
(append-text-node! target-title "Presentation Surface")
(append-text-node! target-copy "This panel becomes the fullscreen element when the request succeeds.")

(define (refresh-status! prefix)
  (set-status! status
               (format "~a: supported=~a enabled=~a active=~a"
                       prefix
                       (fullscreen-supported?)
                       (fullscreen-enabled?)
                       (fullscreen-active?))))

(fullscreen-add-change-listener!
 (lambda (_evt)
   (refresh-status! "fullscreenchange")))

(fullscreen-add-error-listener!
 (lambda (_evt)
   (refresh-status! "fullscreenerror")))

(define (enter!)
  (if (fullscreen-supported?)
      (begin
        (fullscreen-request! target)
        (refresh-status! "Requested fullscreen"))
      (refresh-status! "Fullscreen is not supported here")))

(define (leave!)
  (if (fullscreen-active?)
      (begin
        (fullscreen-exit!)
        (refresh-status! "Requested exit"))
      (refresh-status! "No fullscreen element is active")))

(refresh-status! "Ready")

(js-append-child! target target-title)
(js-append-child! target target-copy)
(js-append-child! main h1)
(js-append-child! main intro)
(js-append-child! main enter-button)
(js-append-child! main exit-button)
(js-append-child! main status)
(js-append-child! main target)
(js-append-child! body main)

(js-add-event-listener! enter-button "click" (procedure->external (lambda (_evt) (enter!) (void))))
(js-add-event-listener! exit-button "click" (procedure->external (lambda (_evt) (leave!) (void))))
