#lang webracket/base

(require browser/dom
         (only-in browser/element
                  element-id)
         intersection-observer)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (make-section id title body color)
  (define section (js-create-element "section"))
  (define h2 (js-create-element "h2"))
  (define p (js-create-element "p"))
  (js-set-attribute! section "id" id)
  (js-set-attribute! section "style"
                     (string-append "min-height: 70vh; margin: 16px 0; padding: 24px; border-radius: 18px; "
                                    "border: 1px solid rgba(0,0,0,0.08); background: " color ";"))
  (append-text-node! h2 title)
  (append-text-node! p body)
  (js-append-child! section h2)
  (js-append-child! section p)
  section)

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: #f7f3ea; color: #1d1d1d; }
          main { max-width: 760px; margin: 0 auto; padding: 24px; }
          .status { position: sticky; top: 0; z-index: 2; background: #fff8e8; padding: 14px 16px; border-bottom: 1px solid rgba(0,0,0,0.08); }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define status (js-create-element "div"))
(define intro (js-create-element "p"))
(define one (make-section "intro-watch" "First panel" "Scroll until each panel enters the viewport." "#f9dfc3"))
(define two (make-section "middle-watch" "Second panel" "IntersectionObserver reports the currently visible panel." "#d8ead7"))
(define three (make-section "end-watch" "Third panel" "The status banner updates from observer callbacks." "#d7e7f6"))

(js-set-attribute! status "class" "status")
(append-text-node! status "Visible panel: none yet")
(append-text-node! intro "This demo watches three panels and reports which one is visible.")

(js-append-child! main status)
(js-append-child! main intro)
(js-append-child! main one)
(js-append-child! main two)
(js-append-child! main three)
(js-append-child! body main)

(define observer
  (make-intersection-observer
   (lambda (entries _observer)
     (let loop ([i 0] [label #f])
       (cond
         [(= i (vector-length entries))
          (when label
            (js-set! status "textContent" label))]
         [else
          (define entry (vector-ref entries i))
          (if (intersection-observer-entry-is-intersecting? entry)
              (let* ([target (intersection-observer-entry-target entry)]
                     [id (element-id target)]
                     [ratio (intersection-observer-entry-intersection-ratio entry)])
                (loop (add1 i)
                      (format "Visible panel: ~a (~a)"
                              id
                              ratio)))
              (loop (add1 i) label))])))
   (make-intersection-observer-options #f "0px" #(0.25))))

(intersection-observer-observe! observer one)
(intersection-observer-observe! observer two)
(intersection-observer-observe! observer three)
