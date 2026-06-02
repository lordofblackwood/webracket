#lang webracket/base

(require web-easy)

;; A small stateful module-based WebRacket/web-easy program.
;;
;; This mirrors the legacy `(include-lib web-easy)` counter shape, but uses
;; `(require web-easy)` so it exercises observables and callbacks through the
;; module bridge.

(define @count (@ 0))

(define single-counter-app
  (window
   (container
    (h1 "A Single Counter")
    (hpanel
     (button "-" (lambda () (@count . <~ . sub1)))
     (text (@count . ~> . number->string))
     (button "+" (lambda () (@count . <~ . add1)))))))

(define app-renderer
  (render single-counter-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
