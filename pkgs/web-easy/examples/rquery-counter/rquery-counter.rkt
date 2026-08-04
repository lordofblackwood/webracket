#lang webracket/base

(require (only-in rquery $ .on)
         web-easy)

(define @count (@ 0))

(define rquery-counter-app
  (window
   (container
    (h1 "Query Counter")
    (P "This example uses query selectors and .on to wire the buttons.")
    (hpanel
     (Button #:id "rquery-counter-decrement" "-")
     (text (obs-map @count number->string))
     (Button #:id "rquery-counter-increment" "+")))))

(define app-renderer
  (render rquery-counter-app))

(mount-renderer! app-renderer)

(define (install-rquery-counter-handlers!)
  (define dec-sel ($ "#rquery-counter-decrement"))
  (define inc-sel ($ "#rquery-counter-increment"))

  (.on inc-sel
       "click"
       (lambda (_evt)
         (obs-update! @count add1)))

  (.on dec-sel
       "click"
       (lambda (_evt)
         (obs-update! @count sub1)))

  (void))

(install-rquery-counter-handlers!)
