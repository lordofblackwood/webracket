#lang webracket/base

(require browser/dom
         history
         (only-in webracket/primitives
                  procedure->external))

(define page-history (history))
(define serial 0)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-status! elem text)
  (js-set! elem "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: #fcfaf5; color: #1f2933; }
          main { max-width: 760px; margin: 0 auto; padding: 32px 20px; }
          .actions { display: flex; flex-wrap: wrap; gap: 12px; margin: 18px 0; }
          button { border: 0; border-radius: 999px; padding: 12px 18px; cursor: pointer; font-weight: 700; }
          .primary { background: #0f766e; color: white; }
          .secondary { background: #dbeafe; color: #1d4ed8; }
          .panel { background: white; border: 1px solid #d7dce2; border-radius: 20px; padding: 16px; box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08); }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define h1 (js-create-element "h1"))
(define intro (js-create-element "p"))
(define actions (js-create-element "div"))
(define push-button (js-create-element "button"))
(define replace-button (js-create-element "button"))
(define back-button (js-create-element "button"))
(define forward-button (js-create-element "button"))
(define panel (js-create-element "div"))
(define status (js-create-element "p"))

(js-set-attribute! actions "class" "actions")
(js-set-attribute! push-button "class" "primary")
(js-set-attribute! replace-button "class" "secondary")
(js-set-attribute! back-button "class" "secondary")
(js-set-attribute! forward-button "class" "secondary")
(js-set-attribute! panel "class" "panel")

(append-text-node! h1 "History API Demo")
(append-text-node! intro "Push, replace, and traverse session history entries without leaving the page.")
(append-text-node! push-button "Push state")
(append-text-node! replace-button "Replace state")
(append-text-node! back-button "Back")
(append-text-node! forward-button "Forward")

(define (current-state-summary)
  (format "length=~a state=~s"
          (history-length page-history)
          (history-state page-history)))

(define (refresh-status! prefix)
  (set-status! status
               (format "~a: ~a"
                       prefix
                       (current-state-summary))))

(define (push-state!)
  (set! serial (add1 serial))
  (history-push-state! page-history
                       (vector "push" serial)
                       (format "#push-~a" serial))
  (refresh-status! "Pushed state"))

(define (replace-state!)
  (history-replace-state! page-history
                          (vector "replace" serial)
                          (format "#replace-~a" serial))
  (refresh-status! "Replaced state"))

(define (go-back!)
  (history-back! page-history)
  (refresh-status! "Requested back navigation"))

(define (go-forward!)
  (history-forward! page-history)
  (refresh-status! "Requested forward navigation"))

(history-add-popstate-listener!
 (lambda (_evt)
   (refresh-status! "Received popstate")))

(refresh-status! "Ready")

(js-append-child! panel status)
(js-append-child! actions push-button)
(js-append-child! actions replace-button)
(js-append-child! actions back-button)
(js-append-child! actions forward-button)
(js-append-child! main h1)
(js-append-child! main intro)
(js-append-child! main actions)
(js-append-child! main panel)
(js-append-child! body main)

(js-add-event-listener! push-button "click" (procedure->external (lambda (_evt) (push-state!) (void))))
(js-add-event-listener! replace-button "click" (procedure->external (lambda (_evt) (replace-state!) (void))))
(js-add-event-listener! back-button "click" (procedure->external (lambda (_evt) (go-back!) (void))))
(js-add-event-listener! forward-button "click" (procedure->external (lambda (_evt) (go-forward!) (void))))
