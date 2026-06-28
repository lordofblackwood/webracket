#lang webracket/base

(require browser/dom
         web-speech
         (only-in webracket/primitives
                  procedure->external))

(define synth (speech-synthesis))

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-text! elem text)
  (js-set! elem "textContent" text))

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define intro (js-create-element "p"))
(define status (js-create-element "p"))
(define speak-button (js-create-element "button"))
(define cancel-button (js-create-element "button"))

(append-text-node! title "Web Speech API Demo")
(append-text-node! intro "Click Speak to queue a SpeechSynthesisUtterance.")
(append-text-node! speak-button "Speak")
(append-text-node! cancel-button "Cancel")

(define (speak!)
  (cond
    [synth
     (define utterance
       (make-speech-utterance
        "Hello from WebRacket"
        (make-speech-utterance-options "en-US" 1 1 1)))
     (speech-utterance-on-end!
      utterance
      (lambda (_event)
        (set-text! status "Finished speaking.")
        (void)))
     (speech-synthesis-speak! synth utterance)
     (set-text! status "Speaking...")]
    [else
     (set-text! status "Speech synthesis is not available.")]))

(set-text! status
           (if synth
               "Speech synthesis is available."
               "Speech synthesis is not available."))

(js-append-child! main title)
(js-append-child! main intro)
(js-append-child! main status)
(js-append-child! main speak-button)
(js-append-child! main cancel-button)
(js-append-child! body main)

(js-add-event-listener!
 speak-button
 "click"
 (procedure->external
  (lambda (_event)
    (speak!)
    (void))))

(js-add-event-listener!
 cancel-button
 "click"
 (procedure->external
  (lambda (_event)
    (when synth
      (speech-synthesis-cancel! synth)
      (set-text! status "Canceled."))
    (void))))
