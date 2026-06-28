#lang webracket/base

(require browser/dom
         (only-in browser/element
                  dom-rect-raw)
         resize-observer)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: #f4f7fb; color: #17324d; }
          main { max-width: 760px; margin: 0 auto; padding: 32px 20px; }
          #panel { width: 320px; height: 180px; resize: both; overflow: auto; padding: 18px; border-radius: 18px;
                   border: 1px solid rgba(23,50,77,0.16); background: white; box-shadow: 0 10px 30px rgba(23,50,77,0.08); }
          .status { margin-top: 18px; font-weight: 700; }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define h1 (js-create-element "h1"))
(define intro (js-create-element "p"))
(define panel (js-create-element "div"))
(define status (js-create-element "p"))

(js-set-attribute! panel "id" "panel")
(js-set-attribute! status "class" "status")

(append-text-node! h1 "ResizeObserver Demo")
(append-text-node! intro "Drag the lower-right corner of the panel to resize it.")
(append-text-node! panel "Resize this panel.")
(append-text-node! status "Panel size: waiting for first measurement")

(js-append-child! main h1)
(js-append-child! main intro)
(js-append-child! main panel)
(js-append-child! main status)
(js-append-child! body main)

(define observer
  (make-resize-observer
   (lambda (entries _observer)
     (define entry (vector-ref entries 0))
     (define rect (resize-observer-entry-content-rect entry))
     (js-set! status
              "textContent"
              (format "Panel size: ~a x ~a"
                      (js-dom-rect-width (dom-rect-raw rect))
                      (js-dom-rect-height (dom-rect-raw rect)))))))

(resize-observer-observe! observer panel)
