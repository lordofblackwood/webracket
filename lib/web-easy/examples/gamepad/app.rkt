#lang webracket/base

(require browser/dom
         gamepad)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-text! elem text)
  (js-set! elem "textContent" text))

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define intro (js-create-element "p"))
(define status (js-create-element "p"))

(append-text-node! title "Gamepad API Demo")
(append-text-node! intro "Connect a gamepad and press a button to let the browser expose it.")

(define (count-present gamepad-slots)
  (for/fold ([count 0])
            ([slot (in-vector gamepad-slots)])
    (if slot (add1 count) count)))

(define (refresh-status!)
  (cond
    [(gamepad-supported?)
     (set-text! status
                (format "Detected ~a gamepad slot(s)."
                        (count-present (gamepads))))]
    [else
     (set-text! status "navigator.getGamepads is not available.")]))

(gamepad-add-connected-listener!
 (lambda (event)
   (define gp (gamepad-event-gamepad event))
   (when gp
     (set-text! status (format "Connected: ~a" (gamepad-id gp))))
   (void)))

(gamepad-add-disconnected-listener!
 (lambda (_event)
   (refresh-status!)
   (void)))

(refresh-status!)

(js-append-child! main title)
(js-append-child! main intro)
(js-append-child! main status)
(js-append-child! body main)
