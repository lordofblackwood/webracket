#lang webracket/base

(require browser/dom
         screen-orientation
         (only-in webracket/primitives
                  procedure->external))

(define orientation (screen-orientation))

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-text! elem text)
  (js-set! elem "textContent" text))

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define intro (js-create-element "p"))
(define status (js-create-element "p"))
(define lock-button (js-create-element "button"))
(define unlock-button (js-create-element "button"))

(append-text-node! title "Screen Orientation API Demo")
(append-text-node! intro "Read screen.orientation and listen for changes.")
(append-text-node! lock-button "Try landscape lock")
(append-text-node! unlock-button "Unlock")

(define (orientation-summary)
  (cond
    [orientation
     (format "~a at ~a degrees"
             (screen-orientation-type orientation)
             (screen-orientation-angle orientation))]
    [else
     "screen.orientation is not available in this browser."]))

(define (refresh-status!)
  (set-text! status (orientation-summary)))

(refresh-status!)

(when orientation
  (screen-orientation-add-change-listener!
   orientation
   (lambda (_event)
     (refresh-status!)
     (void))))

(js-append-child! main title)
(js-append-child! main intro)
(js-append-child! main status)
(js-append-child! main lock-button)
(js-append-child! main unlock-button)
(js-append-child! body main)

(js-add-event-listener!
 lock-button
 "click"
 (procedure->external
  (lambda (_event)
    (when orientation
      (screen-orientation-lock! orientation 'landscape))
    (void))))

(js-add-event-listener!
 unlock-button
 "click"
 (procedure->external
  (lambda (_event)
    (when orientation
      (screen-orientation-unlock! orientation)
      (refresh-status!))
    (void))))
