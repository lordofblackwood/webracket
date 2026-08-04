#lang webracket/base

;;;
;;; WebRacket Simple Website: web-easy page
;;;

(require web-easy)

(define docs-url "docs/webracket/Library__web-easy.html")
(define github-url "https://github.com/soegaard/webracket")

(define (attrs xs) xs)

(define (nav-link label href)
  (A label #:attrs (attrs `((href ,href)))))

(define (cta-link class-name label href)
  (A label #:class class-name #:attrs (attrs `((href ,href)))))

(define (handwritten-example? example-id)
  (or (string=? example-id "hello-world")
      (string=? example-id "a-single-counter")
      (string=? example-id "multiple-counters")
      (string=? example-id "dynamic-counters")
      (string=? example-id "add-two-numbers")
      (string=? example-id "todo-lists")))

(define (source-url example-id file-name)
  (string-append "https://github.com/soegaard/webracket/blob/main/"
                 (if (handwritten-example? example-id)
                     "website-simple/src/examples/web-easy/"
                     "lib/web-easy/examples/")
                 example-id
                 "/"
                 file-name))

(define (example-url example-id file-name)
  (string-append "web-easy-examples/" example-id "/" file-name ".html"))

(define (example label example-id file-name summary)
  (list label example-id file-name summary))

(define handwritten-examples
  (list
   (example "Hello World" "hello-world" "hello-world" "The smallest page: render a view and mount it.")
   (example "A Single Counter" "a-single-counter" "a-single-counter" "A compact state update loop around one value.")
   (example "Multiple Counters" "multiple-counters" "multiple-counters" "Repeated controls backed by independent state.")
   (example "Dynamic Counters" "dynamic-counters" "dynamic-counters" "Add and remove counters while the UI stays in sync.")
   (example "Add Two Numbers" "add-two-numbers" "add-two-numbers" "Inputs, conversion, and computed display.")
   (example "Todo Lists" "todo-lists" "todo-lists" "A small list editor with persistent UI state.")))

(define rquery-examples
  (list
   (example "RQuery Helpers" "rquery-helpers" "rquery-helpers" "Selectors and small DOM update helpers.")
   (example "RQuery Counter" "rquery-counter" "rquery-counter" "A counter written with rquery-style event wiring.")
   (example "RQuery Toggle" "rquery-toggle" "rquery-toggle" "Toggle state through small DOM commands.")
   (example "RQuery Delegate List" "rquery-delegate-list" "rquery-delegate-list" "Selector-based delegated event handling.")
   (example "RQuery Once" "rquery-once" "rquery-once" "One-shot event handlers.")
   (example "RQuery Trigger" "rquery-trigger" "rquery-trigger" "Programmatic event triggering.")))

(define seven-gui-examples
  (list
   (example "7 GUI Counter" "7gui-counter" "7gui-counter" "The benchmark's minimal state update.")
   (example "7 GUI Temperature Converter" "7gui-temperature-converter" "7gui-temperature-converter" "Two synchronized inputs with validation.")
   (example "7 GUI Flight Booker" "7gui-flight-booker" "7gui-flight-booker" "A form with dependent controls and date validation.")
   (example "7 GUI Timer" "7gui-timer" "7gui-timer" "Progress over time, reset, and elapsed display.")
   (example "7 GUI CRUD" "7gui-crud" "7gui-crud" "Filtering, selection, editing, creating, and deleting records.")
   (example "7 GUI Circle" "7gui-circle" "7gui-circle" "Canvas interaction with undoable circle creation.")
   (example "7 GUI Circle Extended" "7gui-circle-extended" "7gui-circle-extended" "A larger circle editor with more interaction state.")))

(define pict-examples
  (list
   (example "Pict Playground" "pict-playground" "pict-playground" "Controls that render web-pict output.")
   (example "Pict Fish School" "pict-fish-school" "pict-fish-school" "A playful canvas scene driven by Racket values.")
   (example "Pict Hungry Fish" "pict-hungry-fish" "pict-hungry-fish" "Interactive pict rendering with animation.")))

(define browser-api-examples
  (list
   (example "Audio Oscillator" "audio-oscillator" "audio-oscillator" "Browser audio synthesis from a web-easy interface.")
   (example "Audio Buffer Playback" "audio-buffer-playback" "audio-buffer-playback" "Load and play audio buffers through browser APIs.")
   (example "Audio Analyser" "audio-analyser" "audio-analyser" "Read audio analysis data into the UI.")
   (example "Audio Effects" "audio-effects" "audio-effects" "Compose controls around a small effects chain.")
   (example "WebSocket" "websocket" "websocket" "A browser WebSocket interface rendered with web-easy.")))

(define (example-card item)
  (define label (car item))
  (define example-id (cadr item))
  (define file-name (caddr item))
  (define summary (cadddr item))
  (Article
   (H3 label)
   (P summary)
   (Div
    (A "Open example"
       #:class "text-link"
       #:attrs (attrs `((href ,(example-url example-id file-name)))))
    (A "Source"
       #:class "text-link text-link--quiet"
       #:attrs (attrs `((href ,(source-url example-id (string-append file-name ".rkt")))
                        (target "_blank")
                        (rel "noreferrer noopener"))))
    #:class "web-easy-card-actions")
   #:class "web-easy-example-card"))

(define (example-grid items)
  (cond
    [(= (length items) 3)
     (Div
      (example-card (list-ref items 0))
      (example-card (list-ref items 1))
      (example-card (list-ref items 2))
      #:class "web-easy-example-grid")]
    [(= (length items) 5)
     (Div
      (example-card (list-ref items 0))
      (example-card (list-ref items 1))
      (example-card (list-ref items 2))
      (example-card (list-ref items 3))
      (example-card (list-ref items 4))
      #:class "web-easy-example-grid")]
    [(= (length items) 6)
     (Div
      (example-card (list-ref items 0))
      (example-card (list-ref items 1))
      (example-card (list-ref items 2))
      (example-card (list-ref items 3))
      (example-card (list-ref items 4))
      (example-card (list-ref items 5))
      #:class "web-easy-example-grid")]
    [else
     (Div
      (example-card (list-ref items 0))
      (example-card (list-ref items 1))
      (example-card (list-ref items 2))
      (example-card (list-ref items 3))
      (example-card (list-ref items 4))
      (example-card (list-ref items 5))
      (example-card (list-ref items 6))
      #:class "web-easy-example-grid")]))

(define (example-section id title lead items)
  (Section
   (Div
    (P title #:class "web-easy-section-kicker")
    (H2 title)
    (P lead #:class "web-easy-section-lead")
    (example-grid items)
    #:class "web-easy-section-content")
   #:id id
   #:class "web-easy-section"))

(define web-easy-page
  (window
   (Div
    (Header
     (Nav
      (A
       (Img #:src "assets/hex-racket-wasm-logo.svg"
            #:class "wordmark-logo"
            #:attrs '((alt "")))
       (Span "Web" #:class "wordmark-muted")
       (Span "Racket" #:class "wordmark-strong")
       #:class "wordmark"
       #:attrs '((href "site.html") (aria-label "WebRacket home")))
      (Div
       (nav-link "Quick Start" "site.html#quick-start")
       (nav-link "Examples" "site.html#examples")
       (nav-link "web-easy" "web-easy.html")
       (nav-link "Documentation" "docs/webracket/index.html")
       (nav-link "GitHub" github-url)
       #:class "nav-links")
      #:class "top-nav")
     #:class "site-header")
    (Main
     (Section
      (Div
       (P "Declarative, Rackety browser UIs" #:class "eyebrow")
       (H1 "web-easy")
       (P
        "web-easy is WebRacket's small UI library for describing browser interfaces as Racket values. It gives you named HTML constructors, themes, stateful rendering, event handling, and a browser backend that turns Racket views into DOM updates."
        #:class "hero-lede")
       (Div
        (cta-link "button-primary" "Open examples" "#examples")
        (cta-link "button-secondary" "Read docs" docs-url)
        #:class "hero-actions")
       #:class "web-easy-hero-copy")
      (Div
       (P "What it can do" #:class "web-easy-panel-kicker")
       (Ul
        (Li "Build pages and app surfaces with Racket constructors such as Div, Button, Input, and Section.")
        (Li "Keep UI state close to the code that renders it.")
        (Li "Attach browser events and update the DOM without writing JavaScript glue for every widget.")
        (Li "Use themes and CSS files while keeping the page structure in Racket."))
       #:class "web-easy-capability-panel")
      #:class "web-easy-hero")
     (example-section
      "handwritten"
      "Handwritten Examples"
      "Small starter apps that show the basic web-easy workflow."
      handwritten-examples)
     (example-section
      "rquery"
      "RQuery Examples"
      "Examples for selector helpers, delegated events, one-shot handlers, and programmatic triggers."
      rquery-examples)
     (example-section
      "seven-gui"
      "7 GUI Examples"
      "The classic interface benchmark: counters, conversion, forms, timers, CRUD, and canvas interaction."
      seven-gui-examples)
     (example-section
      "pict"
      "Pict"
      "Examples that combine web-easy controls with web-pict canvas rendering."
      pict-examples)
     (example-section
      "browser-api"
      "Browser API Examples"
      "Examples assembled around browser APIs such as Audio and WebSocket."
      browser-api-examples)
     #:class "site-main web-easy-main")
    (Footer
     (P "web-easy examples ported from the old WebRacket examples page.")
     #:class "site-footer")
    #:class "site-shell page--web-easy")))

(define web-easy-theme
  (theme 'simple-web-easy
         "we-theme-simple"
         "web-easy-core.css"
         "site.css"
         "web-easy.css"))

(define theme-manager
  (install-theme-manager! web-easy-theme))

(define app-renderer
  (render web-easy-page))

(mount-renderer! app-renderer)
