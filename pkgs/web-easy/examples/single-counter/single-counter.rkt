#lang webracket/base
(require web-easy)

;; This example builds a small reactive counter application.

;; First the observable (a reactive value) `@count` is initialized to 0.
;; The UI below reads from `@count`, and the two buttons update it.
;; Whenever `@count` changes, the displayed text is automatically re-rendered.

(define @count (@ 0)) ; an observable value

(define single-counter-app
  (window
   (container
    (h1 "A Single Counter")
    (hpanel
     (button "-" (lambda () (@count . <~ . sub1)))          ; callback updates count
     (text                  (@count . ~> . number->string)) ; read count
     (button "+" (lambda () (@count . <~ . add1)))))))      ; callback updates count

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
