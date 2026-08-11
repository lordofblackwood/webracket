#lang webracket/base

;;;
;;; WebRacket Simple Website
;;;

(require web-easy
         racket/list
         (only-in webracket/string
                  string-join))

;;;
;;; Content
;;;

;; TODO - This quickstart needs to be updated, when webracket
;;        is distributed as a Racket package.

;; quick-start-lines : (listof string?)
;;   Minimal first path for a user trying WebRacket locally.
(define quick-start-lines
  (list
   "git clone https://github.com/soegaard/webracket"
   "cd webracket"
   "racket webracket.rkt --browser examples/hello-world-2/hello-world.rkt"))

;; examples : (listof (list/c string? string? string?))
;;   Curated examples for the simpler website.
(define examples
   (list
   (list "MiniScheme"           "A Scheme interpreter."                                   "examples/minischeme/minischeme-page.html")
   (list "MathJax Live Preview" "LaTeX rendering through MathJax."                        "examples/mathjax/mathjax-page.html")
   (list "Canvas Hexagons"      "Procedural canvas rendering."                            "examples/canvas-hexagons/canvas-hexagons-page.html")
   (list "Space Invaders"       "A browser game."                                         "examples/space-invaders/space-invaders-page.html")
   (list "Formula 1 Countdown"  "A race countdown from a bundled ICS calendar."           "examples/formula1/formula1-page.html")
   (list "Matrix Rain"          "Animated terminal effects."                              "examples/matrix-rain/matrix-rain-page.html")
   (list "XtermJS Demo"         "An interactive browser terminal driven by Racket."       "examples/xtermjs-demo/xtermjs-demo-page.html")
   (list "JSXGraph Gallery"     "Interactive geometry."                                   "examples/jsxgraph-gallery/jsxgraph-gallery-page.html")
   (list "Connections"          "A word-group puzzle."                                    "examples/connections/connections-page.html")
   #;(list "web-easy"             "A separate page for the UI library and its examples."    "web-easy.html")))

;; docs-url : string?
;;   Rendered Scribble manual location inside the simple site build output.
(define docs-url "docs/webracket/index.html")

;; getting-started-url : string?
;;   Rendered Scribble getting-started page inside the simple site build output.
(define getting-started-url "docs/webracket/Getting_Started.html")

;; github-url : string?
;;   Source repository.
(define github-url "https://github.com/soegaard/webracket")

;;;
;;; View Helpers
;;;

;; nav-link : string? string? -> view?
;;   Build a top navigation link.
(define (nav-link label href)
  (A label #:attrs `((href ,href))))

;; QUESTION: Why not (A label #:href href) ?


;; cta-link : string? string? string? -> view?
;;   Build a prominent call-to-action link.
(define (cta-link class-name label href)
  (A label #:class class-name #:attrs `((href ,href))))

;; shell-section : string? string? view? ... -> view?
;;   Build a titled page section.
(define (shell-section id title . body)
  (keyword-apply
   Section
   '(#:class #:id)
   (list "site-section" id)
   (list
    (H2 title)
    (keyword-apply Div '(#:class) (list "section-body") body))))

;; code-lines : (listof string?) -> view?
;;   Render shell commands as a compact code block.
(define (code-lines lines)
  (Pre (string-join lines "\n") #:class "code-block"))

;; example-card : (list/c string? string? string?) -> view?
;;   Render one curated example.
(define (example-card item)
  (define title   (first  item))
  (define summary (second item))
  (define href    (third  item))
  (Article
   (H3 title)
   (P summary)
   (A "Open example" #:class "text-link" #:attrs `((href ,href)))
   #:class "example-card"))

;;;
;;; Page
;;;

;; site-page : view?
;;   Single-page suggestion for the simpler website.
(define site-page
  (window
   (Div

    ;; Header
    (Header
     (Nav
      (A
       (Img #:src   "assets/hex-racket-wasm-logo.svg"
            #:class "wordmark-logo"
            #:attrs '((alt "")))                       ; QUESTION No #:alt ?
       (Span "Web"    #:class "wordmark-muted")
       (Span "Racket" #:class "wordmark-strong")
       #:class "wordmark"
       #:attrs '((href "#top") (aria-label "WebRacket home")))
      (Div
       (nav-link "Quick Start"   "#quick-start")
       (nav-link "Examples"      "#examples")
       (nav-link "web-easy"      "web-easy.html")
       (nav-link "Documentation" docs-url)
       (nav-link "GitHub"        github-url)
       #:class "nav-links")
      #:class "top-nav")
     #:id "top"
     #:class "site-header")

    ;; Main
    (Main

     ;; Hero
     (Section
      (Div
       (P "Racket programs in the browser"
          #:class "eyebrow")
       (H1 "WebRacket")
       (P
        "A small website should make the first choice obvious: try a Racket program in the browser, then follow the Scribble manual when you want depth."
        #:class "hero-lede")
       
       (Div
        (cta-link "button-primary"   "Read the docs" docs-url)
        (cta-link "button-secondary" "See examples"  "#examples")
        #:class "hero-actions")
       
       #:class "hero-copy")
      
      (Div
       (Img #:src   "assets/hex-racket-wasm-logo.svg"
            #:class "hero-logo"
            #:attrs '((alt "WebRacket logo")))
       (Div "1" #:class "runtime-step-number")
       (P "Write Racket"                                      #:class "runtime-step-title")
       (P "Use normal Racket syntax and WebRacket libraries." #:class "runtime-step-text")
       (Div "2"                                               #:class "runtime-step-number")
       (P "Compile"                                           #:class "runtime-step-title")
       (P "Produce WebAssembly that runs in the browser."     #:class "runtime-step-text")
       (Div "3"                                               #:class "runtime-step-number")
       (P "Build UI with web-easy"                            #:class "runtime-step-title")
       (P "Declarative, Rackety library for UIs included."    #:class "runtime-step-text")
       (Div "4"                                               #:class "runtime-step-number")
       (P "Profit"                                            #:class "runtime-step-title")
       #:class "runtime-strip")
      #:class "hero")

     
     (shell-section "quick-start" "Quick Start"
      (P "Keep the first path short. The full explanation belongs in Scribble.")
      (code-lines quick-start-lines)
      (P
       (A "Open the Scribble getting-started documentation"
          #:class "text-link"
          #:attrs `((href ,getting-started-url)))))
     
     (shell-section "examples" "Examples"
      (P "The examples show the range of WebRacket.")
      (keyword-apply Div '(#:class) (list "example-grid") (map example-card examples)))
     
     (shell-section "docs" "Documentation"
      (P "Use the rendered Scribble manual as the documentation. The simple site should introduce, route, and frame; Scribble should explain.")
      (Div
       (cta-link "button-primary"   "Open Scribble manual" docs-url)
       (cta-link "button-secondary" "View source"          github-url)
       #:class "hero-actions"))
     
     #:class "site-main")

    (Footer
     (P "A simpler WebRacket site proposal. Implementation status is intentionally postponed.")
     #:class "site-footer")
    #:class "site-shell")))

;;;
;;; Themes
;;;

;; simple-theme : theme?
;;   External CSS theme for the simple website.
(define simple-theme
  (theme 'simple
         "we-theme-simple"
         "web-easy-core.css"
         "site.css"
         #f))

(define theme-manager
  (install-theme-manager! simple-theme))

;;;
;;; Mount
;;;

(define app-renderer
  (render site-page))

(mount-renderer! app-renderer)
