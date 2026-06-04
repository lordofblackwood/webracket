#lang webracket/base

(require browser/dom
         (prefix-in ui: web-easy)
         (prefix-in pict: (except-in web-pict text))
         (only-in webracket/primitives
                  procedure->external))

;; Module-based web-pict playground.
;;
;; This is the first packaged replacement for the legacy
;; `lib/web-easy/examples/pict-playground` include-lib example. Keep it small
;; enough to be a useful Goal 1 smoke: a normal module requires `web-easy` and
;; `web-pict`, then draws a composed pict into a browser canvas.

(define canvas-name   "pict-playground-canvas")
(define canvas-width  720.0)
(define canvas-height 420.0)

(define @fish-width   (ui:@ 220))
(define @scale        (ui:@ 100))
(define @status       (ui:@ "Ready."))

;; get-canvas : -> any/c
;;   Look up the preview canvas by id.
(define (get-canvas)
  (define doc (js-var "document"))
  (js-send/extern/nullish doc "getElementById" (vector canvas-name)))

;; get-drawing-context : -> any/c
;;   Produce the browser 2D drawing context for the preview canvas.
(define (get-drawing-context)
  (define canvas (get-canvas))
  (and canvas
       (js-canvas-get-context canvas "2d" (js-var "undefined"))))

;; fill-background! : any/c -> void?
;;   Clear and repaint the playground backdrop.
(define (fill-background! dc)
  (dc 'fill-style "#f8fafc")
  (dc 'fill-rect 0.0 0.0 canvas-width canvas-height)
  (dc 'stroke-style "#d6dde8")
  (dc 'line-width 1.0)
  (dc 'stroke-rect 0.5 0.5 (- canvas-width 1.0) (- canvas-height 1.0))
  (dc 'fill-style "#70849d")
  (dc 'font "13px Georgia")
  (dc 'fill-text "A module-based web-easy page requiring web-pict." 18.0 28.0))

;; playground-pict : -> pict?
;;   Build a compact pict composition from the current controls.
(define (playground-pict)
  (define panel
    (pict:colorize
     (pict:filled-rounded-rectangle (ui:obs-peek @fish-width) 120 18)
     "royalblue"))
  (define badge
    (pict:cc-superimpose
     (pict:colorize (pict:disk 54 #f) "gold")
     (pict:colorize (pict:filled-rounded-rectangle 60 32 10) "#183153")))
  (define caption
    (pict:colorize
     (pict:filled-rounded-rectangle 260 34 12)
     "#30507a"))
  (pict:scale
   (pict:vc-append 18
                   caption
                   (pict:hc-append 18 panel badge))
   (/ (ui:obs-peek @scale) 100.0)))

;; draw-current-pict! : -> void?
;;   Redraw the preview canvas using the current control values.
(define (draw-current-pict!)
  (define ctx (get-drawing-context))
  (cond
    [(not ctx)
     (ui::= @status "Waiting for the preview canvas...")
     (void)]
    [else
     (define dc (pict:canvas-context->dc ctx))
     (define p  (playground-pict))
     (define x  (/ (- canvas-width (pict:pict-width p)) 2.0))
     (define y  86.0)
     (fill-background! dc)
     (ui::= @status "Preparing pict...")
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (ui::= @status (format "draw-pict failed: ~a" (exn-message e)))
                        (void))])
       (ui::= @status "Drawing pict...")
       (pict:draw-pict p dc x y)
       (ui::= @status
              (format "Rendered ~ax~a pict at ~a% scale."
                      (inexact->exact (round (pict:pict-width p)))
                      (inexact->exact (round (pict:pict-height p)))
                      (ui:obs-peek @scale))))
     (void)]))

;; queue-redraw! : -> void?
;;   Schedule a repaint after the DOM has updated.
(define (queue-redraw!)
  (void
   (js-window-set-timeout/delay
    (procedure->external draw-current-pict!)
    0.0)))

;; update! : observable? any/c -> void?
;;   Set an observable and redraw the preview.
(define (update! @obs value)
  (ui::= @obs value)
  (queue-redraw!))

(define canvas-style
  "display:block; width:min(720px, 100%); height:auto; border-radius:18px; box-shadow:0 12px 32px rgba(20,40,80,0.12); background:#f8fafc;")

(define playground-app
  (ui:window
   (ui:container #:style "width:min(980px, calc(100vw - 28px));"
    (ui:vpanel
     (ui:h1 "web-pict Playground")
     (ui:text "A packaged module example that renders picts onto a canvas.")
     (ui:group "Controls"
       (ui:vpanel
        (ui:text "Fish width")
        (ui:slider @fish-width
                   (lambda (new-value)
                     (update! @fish-width new-value))
                   120
                   320)
        (ui:text (ui:obs-map @fish-width
                             (lambda (n) (format "~a px" n))))
        (ui:text "Scale")
        (ui:slider @scale
                   (lambda (new-value)
                     (update! @scale new-value))
                   50
                   180)
        (ui:text (ui:obs-map @scale
                             (lambda (n) (format "~a%" n))))
        (ui:button "Redraw now" draw-current-pict!)))
     (ui:group "Preview"
       (ui:vpanel
        (ui:text @status)
        (ui:Canvas #:id canvas-name
                   #:width canvas-width
                   #:height canvas-height
                   #:style canvas-style)))))))

(define app-renderer
  (ui:render playground-app))

(define light-theme
  (ui:theme 'light
            "we-theme-light"
            "web-easy-core.css"
            "theme-light.css"
            #f))

(define theme-manager
  (ui:install-theme-manager! light-theme))

(ui:mount-renderer! app-renderer)
(queue-redraw!)
