#lang webracket/base

(require web-easy)

;; A minimal trusted embedded SVG example.
;; Svg expects complete <svg> markup and does not sanitize user input.

(define svg-markup
  "<svg viewBox=\"0 0 120 80\" role=\"img\"><title>Simple SVG badge</title><rect x=\"6\" y=\"6\" width=\"108\" height=\"68\" rx=\"14\" fill=\"#e0f2fe\" stroke=\"#0284c7\" stroke-width=\"4\"/><circle cx=\"42\" cy=\"40\" r=\"16\" fill=\"#0ea5e9\"/><path d=\"M65 28 L88 40 L65 52 Z\" fill=\"#0369a1\"/></svg>")

(define svg-basic-app
  (window
   (container
    (h1 "Embedded SVG")
    (text "The badge below is rendered from a trusted SVG string.")
    (Svg svg-markup
         #:id "example-svg-badge"
         #:class "example-svg-badge"
         #:aria-label "Simple SVG badge"))))

(define app-renderer
  (render svg-basic-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
