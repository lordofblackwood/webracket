#lang webracket/base

(require browser/dom
         (only-in racket/math
                  pi
                  sqr)
         web-easy
         (only-in webracket/primitives
                  js-log))

;; 7 GUI - Circle
;;
;; Module-based port of the circle drawer example. It keeps the core 7GUI
;; behavior while avoiding the legacy textual include path:
;; click to create/select circles, right-click selected circles for a context
;; menu, adjust diameter, delete, undo, and redo.

(define canvas-width  400.0)
(define canvas-height 300.0)
(define canvas-name   "circle-canvas")

(define default-circle-red   207)
(define default-circle-green 232)
(define default-circle-blue  255)

(define next-id 0)

(struct circle (id x y diameter red green blue) #:transparent)
(struct history (prev current next) #:transparent)
(struct menu-state (offset-x offset-y) #:transparent)
(struct adjust-diameter-state (original-diameter) #:transparent)

(define (new-id)
  (define id next-id)
  (set! next-id (add1 next-id))
  id)

(define (make-circle x y)
  (circle (new-id)
          x
          y
          40
          default-circle-red
          default-circle-green
          default-circle-blue))

(define (same-circle? a b)
  (and (circle? a)
       (circle? b)
       (equal? (circle-id a)
               (circle-id b))))

(define (circle-fill-color c)
  (format "rgb(~a, ~a, ~a)"
          (circle-red c)
          (circle-green c)
          (circle-blue c)))

(define (set-circle-diameter c d)
  (circle (circle-id c)
          (circle-x c)
          (circle-y c)
          d
          (circle-red c)
          (circle-green c)
          (circle-blue c)))

(define (circle-radius c)
  (/ (circle-diameter c) 2.0))

(define (circle-distance c x y)
  (sqrt (+ (sqr (- x (circle-x c)))
           (sqr (- y (circle-y c))))))

(define (find-closest-circle circles x y)
  (let loop ([circles circles]
             [closest #f]
             [closest-dist +inf.0])
    (cond
      [(null? circles)
       (and closest
            (<= closest-dist (circle-radius closest))
            closest)]
      [else
       (define c    (car circles))
       (define dist (circle-distance c x y))
       (if (< dist closest-dist)
           (loop (cdr circles) c dist)
           (loop (cdr circles) closest closest-dist))])))

(define (adjust-circle/id circles c-id new-diameter)
  (map (lambda (c)
         (if (equal? (circle-id c) c-id)
             (set-circle-diameter c new-diameter)
             c))
       circles))

(define (remove-circle/id circles c-id)
  (filter (lambda (c)
            (not (equal? (circle-id c) c-id)))
          circles))

(define (add-history h circles)
  (cond
    [(equal? circles (history-current h))
     h]
    [else
     (history (cons (history-current h)
                    (history-prev h))
              circles
              '())]))

(define (history-undo h)
  (if (pair? (history-prev h))
      (history (cdr (history-prev h))
               (car (history-prev h))
               (cons (history-current h)
                     (history-next h)))
      h))

(define (history-redo h)
  (if (pair? (history-next h))
      (history (cons (history-current h)
                     (history-prev h))
               (car (history-next h))
               (cdr (history-next h)))
      h))

(define @history
  (@ (history '() '() '())))

(define @circles
  (@history . ~> . history-current))

(define @selected-circle
  (@ #f))

(define @menu
  (@ #f))

(define @adjusting-diameter
  (@ #f))

(define @diam
  (@ 40))

(define @task-active?
  (@ #f))

(obs-watch! @adjusting-diameter
  (lambda (adjusting-diameter)
    (:= @task-active? (and adjusting-diameter #t))))

(define (commit-circles! f)
  (@history . <~ . (lambda (h)
                     (define circles     (history-current h))
                     (define new-circles (f circles))
                     (if (equal? circles new-circles)
                         h
                         (add-history h new-circles))))
  (void))

(define (undo!)
  (:= @history (history-undo (obs-peek @history)))
  (void))

(define (redo!)
  (:= @history (history-redo (obs-peek @history)))
  (void))

(define (add-circle! c)
  (commit-circles! (lambda (circles)
                     (append circles (list c)))))

(define (delete-circle/id! c-id)
  (commit-circles! (lambda (circles)
                     (remove-circle/id circles c-id))))

(define (adjust-circle/id! c-id new-diameter)
  (commit-circles! (lambda (circles)
                     (adjust-circle/id circles c-id new-diameter))))

(define (clear-app-state!)
  (:= @selected-circle #f)
  (:= @menu #f)
  (:= @adjusting-diameter #f)
  (void))

(define (get-canvas)
  (define doc (js-var "document"))
  (js-send/extern/nullish doc "getElementById" (vector canvas-name)))

(define (get-drawing-context)
  (define canvas (get-canvas))
  (and canvas
       (js-canvas-get-context canvas "2d" (js-var "undefined"))))

(define (clear-canvas! ctx)
  (js-canvas2d-clear-rect ctx 0.0 0.0 canvas-width canvas-height))

(define (draw-circle! ctx c selected?)
  (define radius
    (/ (circle-diameter c) 2.0))
  (js-canvas2d-begin-path ctx)
  (js-canvas2d-arc ctx
                   (exact->inexact (circle-x c))
                   (exact->inexact (circle-y c))
                   (exact->inexact radius)
                   0.0
                   (* 2 pi)
                   #f)
  (cond
    [selected?
     (js-set-canvas2d-fill-style! ctx "#e8cfff")
     (js-set-canvas2d-stroke-style! ctx "#5f2bab")]
    [else
     (js-set-canvas2d-fill-style! ctx (circle-fill-color c))
     (js-set-canvas2d-stroke-style! ctx "#2b5fab")])
  (js-canvas2d-fill ctx (void) (void))
  (js-canvas2d-stroke ctx (void))
  (void))

(define (client-position->canvas-position client-x client-y)
  (define canvas (get-canvas))
  (define rect   (js-get-bounding-client-rect canvas))
  (define left   (js-dom-rect-left rect))
  (define top    (js-dom-rect-top rect))
  (define width  (js-dom-rect-width rect))
  (define height (js-dom-rect-height rect))
  (define x (* (/ (- client-x left) width)
               (js-canvas-width canvas)))
  (define y (* (/ (- client-y top) height)
               (js-canvas-height canvas)))
  (values x y))

(define (get-mouse-position evt)
  (client-position->canvas-position
   (mouse-event-client-x evt)
   (mouse-event-client-y evt)))

(define (get-mouse-offsets evt)
  (values (mouse-event-offset-x evt)
          (mouse-event-offset-y evt)))

(define (update-selected-circle-from-point! x y)
  (unless (or (obs-peek @task-active?)
              (obs-peek @menu))
    (define closest
      (find-closest-circle (obs-peek @circles) x y))
    (:= @selected-circle closest))
  (void))

(define (redraw-canvas! circles)
  (define ctx      (get-drawing-context))
  (define selected (obs-peek @selected-circle))
  (define adjusting-diameter
    (obs-peek @adjusting-diameter))
  (define diam
    (obs-peek @diam))
  (when ctx
    (clear-canvas! ctx)
    (for-each
     (lambda (c)
       (define selected?
         (same-circle? c selected))
       (draw-circle! ctx
                     (if (and selected? adjusting-diameter)
                         (set-circle-diameter c diam)
                         c)
                     selected?))
     circles)))

(obs-watch! @circles @selected-circle @diam
  (lambda (circles _selected _diam)
    (redraw-canvas! circles)))

(define (on-click/tap x y)
  (unless (obs-peek @task-active?)
    (cond
      [(obs-peek @menu)
       (:= @menu #f)]
      [else
       (define closest
         (find-closest-circle (obs-peek @circles) x y))
       (cond
         [closest
          (:= @selected-circle closest)]
         [else
          (add-circle! (make-circle x y))])
       (update-selected-circle-from-point! x y)]))
  (void))

(define (commit-adjustment!)
  (js-log "commit-adjustment!")
  (define selected
    (obs-peek @selected-circle))
  (define adjusting
    (obs-peek @adjusting-diameter))
  (when (and selected adjusting)
    (adjust-circle/id! (circle-id selected)
                       (obs-peek @diam))
    (clear-app-state!))
  (void))

(define (menu-handle-key! evt)
  (when (string=? (keyboard-event-key evt) "Escape")
    (prevent-default! evt)
    (:= @menu #f))
  (void))

(define 7gui-circle-drawer-app
  (window
   (container #:style (format "max-width: ~apx;" canvas-width)
    (h1 "Circle Drawer" #:style "text-align: center;")
    (text "Click to create a new circle.")
    (text "Right click on a circle to adjust or delete it.")
    (vpanel
     (hpanel
      (spacer)
      (button "Undo"
              (lambda ()
                (clear-app-state!)
                (undo!)))
      (button "Redo"
              (lambda ()
                (clear-app-state!)
                (redo!)))
      (spacer))
     (Div #:style "position: relative; overflow: visible;"
          (Canvas #:id canvas-name
                  #:width canvas-width
                  #:height canvas-height
                  #:style "border: 1px solid #ccc;"
                  #:on-mousemove
                  (lambda (evt)
                    (define-values (x y)
                      (get-mouse-position evt))
                    (update-selected-circle-from-point! x y))
                  #:on-contextmenu
                  (lambda (evt)
                    (prevent-default! evt)
                    (when (and (obs-peek @selected-circle)
                               (not (obs-peek @task-active?)))
                      (define-values (mx my)
                        (get-mouse-offsets evt))
                      (:= @menu (menu-state mx my)))
                    (void))
                  #:on-click
                  (lambda (evt)
                    (prevent-default! evt)
                    (define-values (x y)
                      (get-mouse-position evt))
                    (on-click/tap x y)))
          (observable-view
           @menu
           (lambda (m)
             (cond
               [m
                (define c (obs-peek @selected-circle))
                (menu-popup
                 #:left (menu-state-offset-x m)
                 #:top (menu-state-offset-y m)
                 #:z-index 1000
                 #:autofocus #t
                 #:on-keydown menu-handle-key!
                 (menu-item "Adjust diameter"
                            (lambda ()
                              (when c
                                (:= @adjusting-diameter
                                    (adjust-diameter-state
                                     (circle-diameter c)))
                                (:= @diam (circle-diameter c))
                                (:= @menu #f))))
                 (divider)
                 (menu-item "Delete"
                            (lambda ()
                              (when c
                                (delete-circle/id! (circle-id c)))
                              (:= @menu #f)
                              (:= @selected-circle #f))
                            #:style "color: #a12626; font-weight: 600;"))]
               [else
                (Span "")]))))
     (observable-view
      @adjusting-diameter
      (lambda (state)
        (cond
          [state
           (vpanel
            (heading 3 "Adjust Diameter")
            (slider @diam
                    (lambda (diam)
                      (:= @diam diam))
                    0
                    100)
            (hpanel
             (spacer)
             (Button "Cancel"
                     #:on-click
                     (lambda (_evt)
                       (clear-app-state!)))
             (Button "Save"
                     #:on-click
                     (lambda (_evt)
                       (commit-adjustment!)))
             (spacer)))]
          [else
           (text "")])))))))

(define app-renderer
  (render 7gui-circle-drawer-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
