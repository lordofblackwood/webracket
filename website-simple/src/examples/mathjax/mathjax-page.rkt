#lang webracket/base

;;;
;;; MathJax live preview page
;;; Ported from the old WebRacket website example in web-site/src/examples/mathjax.rkt.
;;;

(require web-easy
         browser/dom
         (only-in webracket/primitives
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
           (p "MathJax live preview, ported from the old WebRacket website.")))

(define (code-pill url text)
  `(a (@ (class "code-pill") (href ,url) (target "_blank") (rel "noreferrer noopener"))
      ,text))

(define mathjax-cdn-url
  "https://cdn.jsdelivr.net/npm/mathjax@4/tex-mml-chtml.js")

(define mathjax-default-expression
  "\\int_{0}^{\\pi} \\sin(x)\\,\\mathrm{d}x = 2")

(define (mathjax-display latex)
  (string-append "$$" latex "$$"))

(define (mathjax-hero-section)
  `(section (@ (class "examples-hero"))
            (div (@ (class "hero-panel"))
                 (h1 (@ (class "hero-title")) "MathJax Live Preview")
                 (p (@ (class "hero-lead"))
                    "Type LaTeX and watch MathJax render it in the browser."))))

(define (mathjax-input-pane)
  `(div (@ (class "mathjax-pane"))
        (div (@ (class "mathjax-pane-header"))
             (label (@ (for "mathjax-input")
                       (class "pane-label"))
                    "LaTeX input")
             (span (@ (class "pane-meta"))
                   "updates on input"))
        (textarea (@ (id "mathjax-input")
                     (class "mathjax-input")
                     (rows "12")
                     (spellcheck "false"))
                  ,mathjax-default-expression)
        (p (@ (class "mathjax-hint"))
           "Try "
           (code "\\frac{1}{1+x^2}")
           ", "
           (code "\\sum_{n=0}^{\\infty} x^n")
           ", or "
           (code "\\sqrt{x^2 + y^2} = r")
           ".")))

(define (mathjax-preview-pane)
  `(div (@ (class "mathjax-pane"))
        (div (@ (class "mathjax-pane-header"))
             (span (@ (class "pane-label"))
                   "Preview")
             (span (@ (id "mathjax-status")
                      (class "pane-meta mathjax-status")
                      (data-state "loading"))
                   "loading MathJax"))
        (div (@ (id "mathjax-preview")
                (class "mathjax-preview")
                (aria-live "polite"))
             ,(mathjax-display mathjax-default-expression))))

(define (mathjax-editor-section)
  `(section (@ (class "section section--mathjax"))
            (div (@ (class "section-content"))
                 (div (@ (class "mathjax-grid"))
                      ,(mathjax-input-pane)
                      ,(mathjax-preview-pane)))))

(define (mathjax-details-section)
  `(section (@ (class "section section--examples-details"))
            (div (@ (class "section-content"))
                 (div (@ (class "examples-details"))
                      (p "This example is adapted from "
                         (code "web-site/src/examples/mathjax.rkt")
                         ".")
                      (div (@ (class "examples-actions"))
                           ,(code-pill (gh-file "web-site/src/examples/mathjax.rkt")
                                       "Old website source")
                           ,(code-pill (gh-file "website-simple/src/examples/mathjax/mathjax-page.rkt")
                                       "WebRacket source"))))))

(define (mathjax-page)
  `(div (@ (class "page page--mathjax"))
        ,(navbar)
        ,(mathjax-hero-section)
        ,(mathjax-editor-section)
        ,(mathjax-details-section)
        ,(footer-section)))

(define mathjax-textarea #f)
(define mathjax-preview  #f)
(define mathjax-status   #f)
(define mathjax-loaded?  #f)

(define (mark-status! state msg)
  (when mathjax-status
    (js-set-attribute! mathjax-status "data-state" state)
    (js-set! mathjax-status "textContent" msg)))

(define (mathjax-typeset-clear element)
  (js-send (js-var "MathJax") "typesetClear" (vector (vector element))))

(define (mathjax-typeset-promise element)
  (js-send (js-var "MathJax") "typesetPromise" (vector (vector element))))

(define (render-mathjax-preview)
  (when (and mathjax-textarea mathjax-preview)
    (define latex (js-ref mathjax-textarea "value"))
    (when (string? latex)
      (when mathjax-loaded?
        (mathjax-typeset-clear mathjax-preview))
      (js-set! mathjax-preview "textContent"
               (mathjax-display latex))
      (when mathjax-loaded?
        (mathjax-typeset-promise mathjax-preview)))))

(define mathjax-input-handler
  (procedure->external
   (lambda (_evt)
     (render-mathjax-preview)
     (void))))

(define mathjax-loaded-handler
  (procedure->external
   (lambda (_evt)
     (set! mathjax-loaded? #t)
     (mark-status! "ready" "ready")
     (render-mathjax-preview)
     (void))))

(define mathjax-error-handler
  (procedure->external
   (lambda (_evt)
     (mark-status! "error" "MathJax failed to load")
     (void))))

(define (attach-mathjax-input-handler!)
  (when mathjax-textarea
    (js-add-event-listener! mathjax-textarea "input" mathjax-input-handler)))

(define (load-mathjax-script!)
  (define existing (js-get-element-by-id "mathjax-script"))
  (cond
    [existing
     (js-add-event-listener! existing "load" mathjax-loaded-handler)
     (js-add-event-listener! existing "error" mathjax-error-handler)]
    [else
     (define head   (js-document-head))
     (define script (js-create-element "script"))
     (js-set-attribute! script "id" "mathjax-script")
     (js-set-attribute! script "defer" "")
     (js-set-attribute! script "src" mathjax-cdn-url)
     (js-add-event-listener! script "load" mathjax-loaded-handler)
     (js-add-event-listener! script "error" mathjax-error-handler)
     (js-append-child! head script)]))

(define (init-mathjax-page!)
  (set! mathjax-textarea (js-get-element-by-id "mathjax-input"))
  (set! mathjax-preview  (js-get-element-by-id "mathjax-preview"))
  (set! mathjax-status   (js-get-element-by-id "mathjax-status"))
  (js-set! (js-var "document") "title" "MathJax Live Preview")
  (attach-mathjax-input-handler!)
  (render-mathjax-preview)
  (mark-status! "loading" "loading MathJax")
  (load-mathjax-script!))

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
    '(a br code div footer h1 header img label nav p section span textarea))
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

(define mathjax-theme
  (theme 'simple-mathjax
         "we-theme-simple"
         "web-easy-core.css"
         "site.css"
         "mathjax.css"))

(define theme-manager
  (install-theme-manager! mathjax-theme))

(define app-renderer
  (render (window (sxml->view (mathjax-page)))))

(mount-renderer! app-renderer)
(init-mathjax-page!)
