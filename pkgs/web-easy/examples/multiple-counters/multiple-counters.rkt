#lang webracket/base

(require web-easy)

;; Quickstart: Multiple Counters (Light Theme)

(define (counter @count action)
  (hpanel
   (button "-" (lambda () (action sub1)))
   (text (@count . ~> . number->string))
   (button "+" (lambda () (action add1)))))

(define @counter-1 (@ 0))
(define @counter-2 (@ 0))

(define multiple-counters-app
  (window
   (container
    (h1 "Two Counters")
    (vpanel
     (counter @counter-1 (lambda (proc) (@counter-1 . <~ . proc)))
     (counter @counter-2 (lambda (proc) (@counter-2 . <~ . proc)))))))

(define app-renderer
  (render multiple-counters-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
