#lang webracket/base

(require browser/dom
         racket/match
         (only-in racket/math
                  pi
                  sqr)
         web-easy)

;; 7 GUI - Circle (Extended)
;;
;; Module-based extended circle drawer. In addition to the base task, selected
;; circles can be adjusted by diameter or RGB color through either the context
;; menu or the visible action bar.

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

(define (same-circle-id? c c-id)
  (and (circle? c)
       (equal? (circle-id c) c-id)))

(define (circle-fill-color c)
  (format "rgb(~a, ~a, ~a)"
          (circle-red c)
          (circle-green c)
          (circle-blue c)))

(define (preview-fill-color red green blue)
  (format "rgb(~a, ~a, ~a)" red green blue))

(define (set-circle-diameter c d)
  (circle (circle-id c)
          (circle-x c)
          (circle-y c)
          d
          (circle-red c)
          (circle-green c)
          (circle-blue c)))

(define (set-circle-color c red green blue)
  (circle (circle-id c)
          (circle-x c)
          (circle-y c)
          (circle-diameter c)
          red
          green
          blue))

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

(define (find-circle-by-id circles c-id)
  (let loop ([circles circles])
    (cond
      [(null? circles) #f]
      [(same-circle-id? (car circles) c-id) (car circles)]
      [else (loop (cdr circles))])))

(define (adjust-circle-diameter/id circles c-id new-diameter)
  (map (lambda (c)
         (if (same-circle-id? c c-id)
             (set-circle-diameter c new-diameter)
             c))
       circles))

(define (adjust-circle-color/id circles c-id red green blue)
  (map (lambda (c)
         (if (same-circle-id? c c-id)
             (set-circle-color c red green blue)
             c))
       circles))

(define (remove-circle/id circles c-id)
  (filter (lambda (c)
            (not (same-circle-id? c c-id)))
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

(define @selected-circle-id
  (@ #f))

(define @menu
  (@ #f))

(define @editor-mode
  (@ #f)) ; #f, 'diameter, or 'color

(define @diam-preview
  (@ 40))

(define @red-preview
  (@ default-circle-red))

(define @green-preview
  (@ default-circle-green))

(define @blue-preview
  (@ default-circle-blue))

(define (selected-circle-id)
  (obs-peek @selected-circle-id))

(define (selected-circle)
  (find-circle-by-id (obs-peek @circles)
                     (selected-circle-id)))

(define (editor-active?)
  (obs-peek @editor-mode))

(define (clear-menu!)
  (:= @menu #f)
  (void))

(define (cancel-editor!)
  (:= @editor-mode #f)
  (clear-menu!))

(define (clear-transient-ui!)
  (:= @editor-mode #f)
  (clear-menu!))

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

(define (adjust-circle-diameter/id! c-id new-diameter)
  (commit-circles! (lambda (circles)
                     (adjust-circle-diameter/id circles c-id new-diameter))))

(define (adjust-circle-color/id! c-id red green blue)
  (commit-circles! (lambda (circles)
                     (adjust-circle-color/id circles c-id red green blue))))

(define (start-diameter-editor!)
  (define c (selected-circle))
  (when c
    (:= @diam-preview (circle-diameter c))
    (:= @editor-mode 'diameter)
    (clear-menu!))
  (void))

(define (start-color-editor!)
  (define c (selected-circle))
  (when c
    (:= @red-preview (circle-red c))
    (:= @green-preview (circle-green c))
    (:= @blue-preview (circle-blue c))
    (:= @editor-mode 'color)
    (clear-menu!))
  (void))

(define (save-editor!)
  (define c-id (selected-circle-id))
  (when c-id
    (cond
      [(eq? (obs-peek @editor-mode) 'diameter)
       (adjust-circle-diameter/id! c-id (obs-peek @diam-preview))]
      [(eq? (obs-peek @editor-mode) 'color)
       (adjust-circle-color/id! c-id
                                (obs-peek @red-preview)
                                (obs-peek @green-preview)
                                (obs-peek @blue-preview))]
      [else
       (void)]))
  (:= @editor-mode #f)
  (clear-menu!)
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

(define (draw-circle! ctx c selected? fill-color)
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
  (js-set-canvas2d-fill-style! ctx (or fill-color (circle-fill-color c)))
  (cond
    [selected?
     (js-set-canvas2d-line-width! ctx 3.0)
     (js-set-canvas2d-stroke-style! ctx "#111111")]
    [else
     (js-set-canvas2d-line-width! ctx 1.0)
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

(define (get-touch-position t)
  (client-position->canvas-position
   (touch-client-x t)
   (touch-client-y t)))

(define (get-mouse-offsets evt)
  (values (mouse-event-offset-x evt)
          (mouse-event-offset-y evt)))

(define (update-selected-circle-from-point! x y)
  (unless (or (editor-active?)
              (obs-peek @menu))
    (define closest
      (find-closest-circle (obs-peek @circles) x y))
    (:= @selected-circle-id
        (and closest (circle-id closest))))
  (void))

(define (redraw-canvas! circles)
  (define ctx         (get-drawing-context))
  (define selected-id (selected-circle-id))
  (define mode        (obs-peek @editor-mode))
  (when ctx
    (clear-canvas! ctx)
    (for-each
     (lambda (c)
       (define selected?
         (same-circle-id? c selected-id))
       (cond
         [(and selected? (eq? mode 'diameter))
          (draw-circle! ctx
                        (set-circle-diameter c (obs-peek @diam-preview))
                        selected?
                        #f)]
         [(and selected? (eq? mode 'color))
          (draw-circle! ctx
                        c
                        selected?
                        (preview-fill-color (obs-peek @red-preview)
                                            (obs-peek @green-preview)
                                            (obs-peek @blue-preview)))]
         [else
          (draw-circle! ctx c selected? #f)]))
     circles)))

(obs-watch! @circles @selected-circle-id @editor-mode
            @diam-preview @red-preview @green-preview @blue-preview
  (lambda (circles _selected _mode _diam _red _green _blue)
    (redraw-canvas! circles)))

(define (on-click/tap x y)
  (unless (editor-active?)
    (cond
      [(obs-peek @menu)
       (clear-menu!)]
      [else
       (define closest
         (find-closest-circle (obs-peek @circles) x y))
       (cond
         [closest
          (:= @selected-circle-id (circle-id closest))]
         [else
          (define c (make-circle x y))
          (add-circle! c)
          (:= @selected-circle-id (circle-id c))])]))
  (void))

(define (menu-handle-key! evt)
  (when (string=? (keyboard-event-key evt) "Escape")
    (prevent-default! evt)
    (clear-menu!))
  (void))

(define (editor-handle-key! evt)
  (define key
    (keyboard-event-key evt))
  (cond
    [(string=? key "Escape")
     (prevent-default! evt)
     (cancel-editor!)]
    [(string=? key "Enter")
     (prevent-default! evt)
     (save-editor!)]
    [else
     (void)]))

(define (editor-shell title body)
  (Div #:style "border: 1px solid #999; background: white; padding: 12px; border-radius: 6px;"
       #:attrs '((tabindex "-1"))
       #:on-keydown editor-handle-key!
       (vpanel
        (heading 3 title)
        body
        (hpanel
         (spacer)
         (Button "Cancel"
                 #:on-click
                 (lambda (_evt)
                   (cancel-editor!)))
         (Button "Save"
                 #:on-click
                 (lambda (_evt)
                   (save-editor!)))
         (spacer)))))

(define (touch-action-bar)
  (define c (selected-circle))
  (cond
    [(and c (not (editor-active?)))
     (hpanel
      (spacer)
      (Button "Adjust diameter"
              #:on-click
              (lambda (_evt)
                (start-diameter-editor!)))
      (Button "Adjust color"
              #:on-click
              (lambda (_evt)
                (start-color-editor!)))
      (Button "Delete"
              #:on-click
              (lambda (_evt)
                (delete-circle/id! (circle-id c))
                (:= @selected-circle-id #f)
                (clear-menu!)))
      (spacer))]
    [else
     (text "")]))

(define (delete-selected-circle!)
  (define c-id (selected-circle-id))
  (when c-id
    (delete-circle/id! c-id)
    (:= @selected-circle-id #f)
    (clear-menu!))
  (void))

(define 7gui-circle-extended-app
  (window
   (container #:style (format "max-width: ~apx;" canvas-width)
    (h1 "Circle Drawer Extended" #:style "text-align: center;")
    (text "Click to create a new circle. Move the mouse to retarget selection.")
    (text "Right click for a context menu, or use the action bar after selecting a circle.")
    (vpanel
     (hpanel
      (spacer)
      (button "Undo"
              (lambda ()
                (clear-transient-ui!)
                (undo!)))
      (button "Redo"
              (lambda ()
                (clear-transient-ui!)
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
                    (when (and (selected-circle-id)
                               (not (editor-active?)))
                      (define-values (mx my)
                        (get-mouse-offsets evt))
                      (:= @menu (menu-state mx my)))
                    (void))
                  #:on-click
                  (lambda (evt)
                    (prevent-default! evt)
                    (define-values (x y)
                      (get-mouse-position evt))
                    (on-click/tap x y))
                  #:on-touchend
                  (lambda (evt)
                    (prevent-default! evt)
                    (define touches
                      (touch-event-changed-touches evt))
                    (define t
                      (touch-list-ref touches 0))
                    (when t
                      (define-values (x y)
                        (get-touch-position t))
                      (on-click/tap x y))))
          (observable-view
           @menu
           (lambda (m)
             (cond
               [m
                (menu-popup
                 #:left (menu-state-offset-x m)
                 #:top (menu-state-offset-y m)
                 #:z-index 1000
                 #:autofocus #t
                 #:on-keydown menu-handle-key!
                 (menu-item "Adjust diameter"
                            (lambda ()
                              (start-diameter-editor!)))
                 (menu-item "Adjust color"
                            (lambda ()
                              (start-color-editor!)))
                 (divider)
                 (menu-item "Delete"
                            delete-selected-circle!
                            #:style "color: #a12626; font-weight: 600;"))]
               [else
                (Span "")]))))
     (observable-view
      (obs-combine list @selected-circle-id @editor-mode)
      (lambda (_)
        (touch-action-bar)))
     (observable-view
      @editor-mode
      (lambda (mode)
        (cond
          [(eq? mode 'diameter)
           (editor-shell
            "Adjust Diameter"
            (vpanel
             (text (@diam-preview . ~> .
                                  (lambda (diam)
                                    (format "Diameter: ~a" diam))))
             (slider @diam-preview
                     (lambda (diam)
                       (:= @diam-preview diam))
                     0
                     100
                     #:autofocus #t)))]
          [(eq? mode 'color)
           (editor-shell
            "Adjust Color"
            (vpanel
             (observable-view
              (obs-combine list @red-preview @green-preview @blue-preview)
              (lambda (rgb)
                (match-define (list red green blue) rgb)
                (Div #:style
                     (format (string-append "width: 72px; height: 36px; border-radius: 6px; "
                                            "border: 1px solid #999; margin: 0 auto; "
                                            "background: rgb(~a, ~a, ~a);")
                             red green blue)
                     (text " "))))
             (text (@red-preview . ~> .
                                 (lambda (red)
                                   (format "Red: ~a" red))))
             (slider @red-preview
                     (lambda (red)
                       (:= @red-preview red))
                     0
                     255
                     #:autofocus #t)
             (text (@green-preview . ~> .
                                   (lambda (green)
                                     (format "Green: ~a" green))))
             (slider @green-preview
                     (lambda (green)
                       (:= @green-preview green))
                     0
                     255)
             (text (@blue-preview . ~> .
                                  (lambda (blue)
                                    (format "Blue: ~a" blue))))
             (slider @blue-preview
                     (lambda (blue)
                       (:= @blue-preview blue))
                     0
                     255)))]
          [else
           (text "")])))))))

(define app-renderer
  (render 7gui-circle-extended-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
