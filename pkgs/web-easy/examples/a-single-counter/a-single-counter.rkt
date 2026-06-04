#lang webracket/base

(require web-easy)

;; Quickstart: A Single Counter
;;
;; Module-based port of the legacy quickstart example.

(define @count (@ 0))

(define a-single-counter-app
  (window
   (container
    (h1 "A Single Counter")
    (hpanel
     (button "-" (lambda () (@count . <~ . sub1)))
     (text (@count . ~> . number->string))
     (button "+" (lambda () (@count . <~ . add1)))))))

(define a-single-counter-app-2
  (window
   (container
    (h1 "A Single Counter - 2")
    (hpanel
     (button "-" (lambda () (obs-update! @count sub1)))
     (text (obs-map @count number->string))
     (button "+" (lambda () (obs-update! @count add1)))))))

(define app-renderer
  (render a-single-counter-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
