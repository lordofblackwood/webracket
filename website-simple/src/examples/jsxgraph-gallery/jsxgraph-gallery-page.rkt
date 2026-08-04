#lang webracket/base

;;;
;;; JSXGraph gallery page
;;; Ported from the old WebRacket documentation examples in web-site/src/documentation.rkt.
;;;

(require web-easy
         browser/dom
         (only-in webracket/primitives
                  external?
                  procedure->external))

(define gh-base-file "https://github.com/soegaard/webracket/blob/main/")

(define (gh-file path)
  (string-append gh-base-file path))

(define (nav-link label href)
  `(a (@ (href ,href)) ,label))

(define (navbar)
  `(header (@ (class "site-header"))
           (nav (@ (class "top-nav"))
                (a (@ (class "wordmark") (href "../../site.html")
                      (aria-label "WebRacket home"))
                   (img (@ (src "../../assets/hex-racket-wasm-logo.svg")
                           (alt "")
                           (class "wordmark-logo")))
                   (span (@ (class "wordmark-muted")) "Web")
                   (span (@ (class "wordmark-strong")) "Racket"))
                (div (@ (class "nav-links"))
                     ,(nav-link "Quick Start" "../../site.html#quick-start")
                     ,(nav-link "Examples" "../../site.html#examples")
                     ,(nav-link "Documentation" "../../docs/webracket/index.html")
                     ,(nav-link "GitHub" "https://github.com/soegaard/webracket")))))

(define (footer-section)
  `(footer (@ (class "site-footer"))
           (p "JSXGraph Gallery, ported from the old WebRacket documentation examples.")))

(define (code-pill url text)
  `(a (@ (class "code-pill") (href ,url) (target "_blank") (rel "noreferrer noopener"))
      ,text))

(define (jsxgraph-gallery-page)
  `(div (@ (class "page page--jsxgraph-gallery"))
        ,(navbar)
        (section (@ (class "examples-hero"))
                 (div (@ (class "hero-panel"))
                      (h1 (@ (class "hero-title")) "JSXGraph Gallery")
                      (p (@ (class "hero-lead"))
                         "Interactive geometry examples using the JavaScript FFI.")))
        (section (@ (class "section section--examples"))
                 (div (@ (class "section-content"))
                      (div (@ (class "gallery-grid"))
                           (article (@ (class "gallery-card"))
                                    (div (@ (class "gallery-card-copy"))
                                         (h2 "Board Points")
                                         (p "A live JSXGraph board with draggable points P, Q, and R."))
                                    (div (@ (id "extended-jsx-board")
                                            (class "jxgbox gallery-board")))
                                    (p (@ (id "extended-jsx-board-status")
                                          (class "gallery-status"))
                                       "Loading JSXGraph..."))
                           (article (@ (class "gallery-card"))
                                    (div (@ (class "gallery-card-copy"))
                                         (h2 "Geometry Constructors")
                                         (p "Point, line, segment, circle, intersection, and text constructors."))
                                    (div (@ (id "extended-jsx-geometry-board")
                                            (class "jxgbox gallery-board")))
                                    (p (@ (id "extended-jsx-geometry-board-status")
                                          (class "gallery-status"))
                                       "Loading JSXGraph...")))))
        (section (@ (class "section section--examples-details"))
                 (div (@ (class "section-content"))
                      (div (@ (class "examples-details"))
                           (p "These examples are adapted from "
                              (code "web-site/src/documentation.rkt")
                              ".")
                           (div (@ (class "examples-actions"))
                                ,(code-pill (gh-file "web-site/src/documentation.rkt")
                                            "Old website source")
                                ,(code-pill (gh-file "website-simple/src/examples/jsxgraph-gallery/jsxgraph-gallery-page.rkt")
                                            "WebRacket source")))))
        ,(footer-section)))

(define local-jsxgraph-css "assets/vendor/jsxgraph/jsxgraph.css")
(define local-jsxgraph-js "assets/vendor/jsxgraph/jsxgraphcore.js")
(define cdn-jsxgraph-css "https://cdn.jsdelivr.net/npm/jsxgraph/distrib/jsxgraph.css")
(define cdn-jsxgraph-js "https://cdn.jsdelivr.net/npm/jsxgraph/distrib/jsxgraphcore.js")

(define jsxgraph-assets-requested? #f)
(define jsxgraph-points-started? #f)
(define jsxgraph-geometry-started? #f)

(define (extern-present? v)
  (external? v))

(define (set-status! id msg)
  (define status-el (js-get-element-by-id id))
  (when status-el
    (js-set! status-el "textContent" msg)))

(define (ensure-jsxgraph-assets!)
  (unless jsxgraph-assets-requested?
    (set! jsxgraph-assets-requested? #t)
    (define head (js-document-head))
    (define body (js-document-body))
    (define append-target (if (extern-present? head) head body))
    (unless (extern-present? (js-query-selector "link[data-jsxgraph-css='1']"))
      (define link (js-create-element "link"))
      (js-set-attribute! link "rel" "stylesheet")
      (js-set-attribute! link "href" cdn-jsxgraph-css)
      (js-set-attribute! link "data-jsxgraph-css" "1")
      (define on-css-error
        (procedure->external
         (lambda (_evt)
           (js-set-attribute! link "href" local-jsxgraph-css))))
      (js-add-event-listener! link "error" on-css-error)
      (js-append-child! append-target link))
    (unless (extern-present? (js-query-selector "script[data-jsxgraph-core='1']"))
      (define script (js-create-element "script"))
      (js-set-attribute! script "src" cdn-jsxgraph-js)
      (js-set-attribute! script "data-jsxgraph-core" "1")
      (define on-error
        (procedure->external
         (lambda (_evt)
           (js-set-attribute! script "src" local-jsxgraph-js))))
      (js-add-event-listener! script "error" on-error)
      (js-append-child! append-target script))))

(define (jsxgraph-object)
  (define jxg (js-ref (js-window-window) "JXG"))
  (and (extern-present? jxg)
       (let ([jsxgraph (js-ref jxg "JSXGraph")])
         (and (extern-present? jsxgraph) jsxgraph))))

(define (init-board-points! jsxgraph)
  (unless jsxgraph-points-started?
    (define board-el (js-get-element-by-id "extended-jsx-board"))
    (when board-el
      (set! jsxgraph-points-started? #t)
      (define attrs
        (js-object
         (vector (vector "boundingbox" #[-6 6 6 -6])
                 (vector "axis" #t)
                 (vector "keepaspectratio" #t))))
      (define board
        (js-send/extern jsxgraph "initBoard" (vector "extended-jsx-board" attrs)))
      (js-send/extern board "create"
                      (vector "point" #[-3 1]
                              (js-object
                               (vector (vector "name" "P")
                                       (vector "size" 4)
                                       (vector "strokeColor" "#2b6cb0")
                                       (vector "fillColor" "#2b6cb0")))))
      (js-send/extern board "create"
                      (vector "point" #[2 2]
                              (js-object
                               (vector (vector "name" "Q")
                                       (vector "size" 4)
                                       (vector "strokeColor" "#2f855a")
                                       (vector "fillColor" "#2f855a")))))
      (js-send/extern board "create"
                      (vector "point" #[1 -3]
                              (js-object
                               (vector (vector "name" "R")
                                       (vector "size" 4)
                                       (vector "strokeColor" "#c53030")
                                       (vector "fillColor" "#c53030")))))
      (js-send/extern board "update" (vector))
      (js-set-attribute! board-el "data-jxg-ready" "1")
      (set-status! "extended-jsx-board-status" "Board ready. Drag points P, Q, and R."))))

(define (list->js-array v)
  (cond
    [(list? v) (list->vector (map list->js-array v))]
    [else v]))

(define (init-geometry-board! jsxgraph)
  (unless jsxgraph-geometry-started?
    (define board-el (js-get-element-by-id "extended-jsx-geometry-board"))
    (when board-el
      (set! jsxgraph-geometry-started? #t)
      (define attrs
        (js-object
         (vector (vector "boundingbox" #[-7 7 7 -7])
                 (vector "axis" #t)
                 (vector "keepaspectratio" #t))))
      (define board
        (js-send/extern jsxgraph "initBoard" (vector "extended-jsx-geometry-board" attrs)))
      (define p-parent '(-4 1))
      (define q-parent '(2 3))
      (define line-parents (list p-parent q-parent))
      (define text-parent '(-6 6 "P-Q constructors"))
      (define p
        (js-send/extern board "create"
                        (vector "point" (list->js-array p-parent)
                                (js-object (vector (vector "name" "P")
                                                   (vector "size" 4))))))
      (define q
        (js-send/extern board "create"
                        (vector "point" (list->js-array q-parent)
                                (js-object (vector (vector "name" "Q")
                                                   (vector "size" 4))))))
      (define l
        (js-send/extern board "create"
                        (vector "line" (list->js-array line-parents) (js-object (vector)))))
      (js-send/extern board "create"
                      (vector "segment" (list->js-array line-parents) (js-object (vector))))
      (define c
        (js-send/extern board "create"
                        (vector "circle" (list->js-array line-parents) (js-object (vector)))))
      (define i
        (js-send/extern board "create"
                        (vector "point" (list->js-array '(0 0))
                                (js-object (vector (vector "name" "I")
                                                   (vector "size" 3))))))
      (js-send/extern i "makeIntersection" (vector l c 0 0))
      (js-send/extern board "create"
                      (vector "text" (list->js-array text-parent) (js-object (vector))))
      (js-send/extern board "suspendUpdate" (vector))
      (js-set! p "size" 5)
      (js-set! q "size" 5)
      (js-send/extern board "unsuspendUpdate" (vector))
      (js-send/extern board "fullUpdate" (vector))
      (js-set-attribute! board-el "data-jxg-ready" "1")
      (set-status! "extended-jsx-geometry-board-status" "Board ready. Constructors demo loaded."))))

(define (try-init-gallery!)
  (define jsxgraph (jsxgraph-object))
  (if jsxgraph
      (begin
        (init-board-points! jsxgraph)
        (init-geometry-board! jsxgraph)
        #t)
      #f))

(define (init-jsxgraph-gallery-page!)
  (js-set! (js-var "document") "title" "JSXGraph Gallery")
  (ensure-jsxgraph-assets!)
  (let ([tries 0]
        [attempt-ext #f])
    (define (attempt . _args)
      (if (try-init-gallery!)
          (void)
          (begin
            (set! tries (+ tries 1))
            (if (< tries 80)
                (js-window-set-timeout/delay attempt-ext 100.)
                (begin
                  (set-status! "extended-jsx-board-status" "Failed to load JSXGraph assets.")
                  (set-status! "extended-jsx-geometry-board-status" "Failed to load JSXGraph assets."))))))
    (set! attempt-ext (procedure->external attempt))
    (attempt #f)))

(define (sxml-attribute-value->string v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [(number? v) (number->string v)]
    [else (format "~a" v)]))

(define (sxml-attrs->view-attrs attrs)
  (map (lambda (attr)
         (cons (car attr)
               (if (null? (cddr attr))
                   (cadr attr)
                   (apply string-append
                          (map sxml-attribute-value->string (cdr attr))))))
       attrs))

(define (sxml-make-view tag attrs children)
  (define supported-tags
    '(a article br code div footer h1 h2 header img main nav p section span))
  (cond
    [(memq tag supported-tags)
     (view 'html-element-children
           (append (list (cons 'tag tag))
                   (if (null? attrs)
                       '()
                       (list (cons 'extra-attrs attrs))))
           children)]
    [else
     (error 'sxml->view "unsupported tag: ~a" tag)]))

(define (sxml->view exp)
  (cond
    [(view? exp)
     exp]
    [(string? exp)
     (view 'raw-text (list (cons 'value exp)) '())]
    [(or (symbol? exp) (number? exp) (char? exp))
     (view 'raw-text (list (cons 'value (format "~a" exp))) '())]
    [(and (pair? exp) (eq? (car exp) '@))
     (error 'sxml->view "stray attribute block: ~a" exp)]
    [(and (pair? exp) (symbol? (car exp)))
     (define tag (car exp))
     (define rest (cdr exp))
     (define attrs '())
     (define children rest)
     (when (and (pair? rest)
                (pair? (car rest))
                (eq? (car (car rest)) '@))
       (set! attrs (cdr (car rest)))
       (set! children (cdr rest)))
     (sxml-make-view tag
                     (sxml-attrs->view-attrs attrs)
                     (map sxml->view children))]
    [else
     (error 'sxml->view "malformed SXML expression: ~a" exp)]))

(define jsxgraph-gallery-theme
  (theme 'simple-jsxgraph-gallery
         "we-theme-simple"
         "web-easy-core.css"
         "site.css"
         "jsxgraph-gallery.css"))

(define theme-manager
  (install-theme-manager! jsxgraph-gallery-theme))

(define app-renderer
  (render (window (sxml->view (jsxgraph-gallery-page)))))

(mount-renderer! app-renderer)
(init-jsxgraph-gallery-page!)
