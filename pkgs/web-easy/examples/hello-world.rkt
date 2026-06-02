#lang webracket/base

(require web-easy)

;; A small module-based WebRacket/web-easy program.
;;
;; This mirrors the legacy `(include-lib web-easy)` hello-world example, but
;; uses the package module provider so it exercises the Goal 1 path.

(define hello-world-app
  (window
   (container
    (h1 "Hello World")
    (text "Have a nice day."))))

(define app-renderer
  (render hello-world-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
