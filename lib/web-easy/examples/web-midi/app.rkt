#lang webracket/base

(require browser/dom
         js/promise
         web-midi
         (only-in webracket/primitives procedure->external))

(define (append-text-node! element text)
  (js-append-child! element (js-create-text-node text)))

(define (set-text! element text)
  (js-set! element "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; color: #172033; background: radial-gradient(circle at top right, #fff0d9, #f3fbff 54%, #e8f0d3); font-family: Georgia, serif; }
          main { max-width: 760px; margin: 0 auto; padding: 48px 22px; }
          h1 { font-size: clamp(2.2rem, 8vw, 4.4rem); letter-spacing: -0.055em; margin: 0; }
          .lede { font-size: 1.18rem; max-width: 42rem; line-height: 1.55; }
          .card { margin-top: 28px; padding: 24px; border: 1px solid #d4c588; border-radius: 22px; background: rgba(255,255,255,.84); box-shadow: 0 16px 42px rgba(69, 58, 13, .10); }
          button { appearance: none; border: 0; border-radius: 999px; cursor: pointer; padding: 12px 18px; color: white; background: #7a5600; font: 700 1rem/1 Georgia, serif; }
          button:disabled { cursor: not-allowed; background: #aa9f83; }
          #web-midi-status { min-height: 1.6em; color: #604100; font-weight: 700; }
          #web-midi-ports { margin: 16px 0 0; padding: 16px; border-radius: 12px; background: #fffdf7; color: #3d3b35; white-space: pre-wrap; }
          .note { color: #4a5b66; line-height: 1.45; }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define lede (js-create-element "p"))
(define card (js-create-element "section"))
(define card-title (js-create-element "h2"))
(define copy (js-create-element "p"))
(define access-button (js-create-element "button"))
(define status (js-create-element "p"))
(define ports (js-create-element "pre"))

(js-set-attribute! card "class" "card")
(js-set-attribute! copy "class" "note")
(js-set-attribute! status "id" "web-midi-status")
(js-set-attribute! ports "id" "web-midi-ports")

(append-text-node! title "Web MIDI API")
(append-text-node! lede
                   "Ask the browser for MIDI access, then inspect the input and output ports that it exposes. Plug in a controller or synthesizer before pressing the button to see it in the list.")
(append-text-node! card-title "Discover MIDI ports")
(append-text-node! copy
                   "Browsers can require a secure context and user permission. This button makes the access request from a click, then lists the currently available ports without sending any MIDI messages.")
(append-text-node! access-button "Request MIDI access")

(define (describe-port kind port)
  (define name (or (web-midi-port-name port) "Unnamed port"))
  (define manufacturer (or (web-midi-port-manufacturer port) "Unknown manufacturer"))
  (string-append kind ": " name
                 "\n  manufacturer: " manufacturer
                 "\n  id: " (web-midi-port-id port)
                 "\n  state: " (symbol->string (web-midi-port-state port))
                 ", connection: "
                 (symbol->string (web-midi-port-connection port))
                 "\n"))

(define (append-port-descriptions! output kind ids lookup)
  (let loop ([index 0])
    (when (< index (vector-length ids))
      (define port (lookup (vector-ref ids index)))
      (when port
        (set-text! output
                   (string-append (js-ref output "textContent")
                                  (describe-port kind port))))
      (loop (add1 index)))))

(define (show-access raw-access)
  (define access (web-midi-access-wrap raw-access))
  (define input-ids (web-midi-access-input-port-ids access))
  (define output-ids (web-midi-access-output-port-ids access))
  (set-text! ports "")
  (append-port-descriptions! ports "Input" input-ids
                             (lambda (id) (web-midi-access-input access id)))
  (append-port-descriptions! ports "Output" output-ids
                             (lambda (id) (web-midi-access-output access id)))
  (when (and (= (vector-length input-ids) 0)
             (= (vector-length output-ids) 0))
    (set-text! ports "No MIDI input or output ports are currently available."))
  (set-text! status
             (string-append "Access granted. Inputs: "
                            (number->string (vector-length input-ids))
                            "; outputs: "
                            (number->string (vector-length output-ids))
                            "."))
  (void))

(define (request-access!)
  (js-set! access-button "disabled" #t)
  (set-text! status "Requesting MIDI access...")
  (js-promise-then
   (web-midi-request-access)
   (lambda (raw-access)
     (show-access raw-access)
     (js-set! access-button "disabled" #f)
     (void))
   (lambda (_reason)
     (set-text! status "The browser denied MIDI access or this API is unavailable here.")
     (js-set! access-button "disabled" #f)
     (void)))
  (void))

(js-append-child! card card-title)
(js-append-child! card copy)
(js-append-child! card access-button)
(js-append-child! card status)
(js-append-child! card ports)
(js-append-child! main title)
(js-append-child! main lede)
(js-append-child! main card)
(js-append-child! body main)

(cond
  [(web-midi-supported?)
   (set-text! status "Press the button to request MIDI access.")]
  [else
   (js-set! access-button "disabled" #t)
   (set-text! status "Web MIDI is not available in this browser.")])

(js-add-event-listener!
 access-button
 "click"
 (procedure->external (lambda (_event) (request-access!) (void))))
