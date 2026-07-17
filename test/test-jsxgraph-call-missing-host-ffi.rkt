#lang webracket/base

;; Browser smoke for dynamic JSXGraph method-call boundary errors.

(require (only-in webracket/unsafe/jsxgraph
                  js-jsx-board-add-grid!
                  js-jsx-board-create
                  js-jsx-board-create-point
                  js-jsx-board-generate-id
                  js-jsx-board-get-bounding-box
                  js-jsx-board-remove-object!
                  js-jsx-board-select
                  js-jsx-board-update!
                  js-jsx-angle-set-angle!
                  js-jsx-arc-get-radius
                  js-jsx-chart-drawBar
                  js-jsx-circle-call
                  js-jsx-circle-call/nullish
                  js-jsx-curve-call
                  js-jsx-curve-call/nullish
                  js-jsx-element-add-event
                  js-jsx-element-call
                  js-jsx-element-call/nullish
                  js-jsx-foreignobject-update
                  js-jsx-glider-start-animation!
                  js-jsx-group-addParents
                  js-jsx-input-set
                  js-jsx-line-call
                  js-jsx-line-call/nullish
                  js-jsx-point-update!
                  js-jsx-polygon-call
                  js-jsx-polygon-call/nullish
                  js-jsx-sector-area
                  js-jsx-slider-setValue
                  js-jsx-text-setText)
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define target
  (js-eval "({ present() { return {ok: true}; } })"))

(define args (vector))

(define board-without-create
  (js-eval "({})"))

(define board-create-message
  (catch-message
   (lambda ()
     (js-jsx-board-create board-without-create "point" args args))))

(define board-create-point-message
  (catch-message
   (lambda ()
     (js-jsx-board-create-point board-without-create args args))))

(define board-add-grid-message
  (catch-message
   (lambda ()
     (js-jsx-board-add-grid! board-without-create))))

(define board-generate-id-message
  (catch-message
   (lambda ()
     (js-jsx-board-generate-id board-without-create))))

(define board-get-bounding-box-message
  (catch-message
   (lambda ()
     (js-jsx-board-get-bounding-box board-without-create))))

(define board-select-message
  (catch-message
   (lambda ()
     (js-jsx-board-select board-without-create "p1" #t))))

(define board-update-message
  (catch-message
   (lambda ()
     (js-jsx-board-update! board-without-create))))

(define board-remove-object-message
  (catch-message
   (lambda ()
     (js-jsx-board-remove-object! board-without-create target))))

(define element-add-event-message
  (catch-message
   (lambda ()
     (js-jsx-element-add-event target "click" target))))

(define element-call-message
  (catch-message
   (lambda ()
     (js-jsx-element-call target "missingMethod" args))))

(define element-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-element-call/nullish target "missingMethod" args))))

(define line-call-message
  (catch-message
   (lambda ()
     (js-jsx-line-call target "missingMethod" args))))

(define line-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-line-call/nullish target "missingMethod" args))))

(define circle-call-message
  (catch-message
   (lambda ()
     (js-jsx-circle-call target "missingMethod" args))))

(define circle-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-circle-call/nullish target "missingMethod" args))))

(define curve-call-message
  (catch-message
   (lambda ()
     (js-jsx-curve-call target "missingMethod" args))))

(define curve-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-curve-call/nullish target "missingMethod" args))))

(define polygon-call-message
  (catch-message
   (lambda ()
     (js-jsx-polygon-call target "missingMethod" args))))

(define polygon-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-polygon-call/nullish target "missingMethod" args))))

(define text-setText-message
  (catch-message
   (lambda ()
     (js-jsx-text-setText target args))))

(define foreignobject-update-message
  (catch-message
   (lambda ()
     (js-jsx-foreignobject-update target))))

(define input-set-message
  (catch-message
   (lambda ()
     (js-jsx-input-set target args))))

(define slider-setValue-message
  (catch-message
   (lambda ()
     (js-jsx-slider-setValue target args))))

(define chart-drawBar-message
  (catch-message
   (lambda ()
     (js-jsx-chart-drawBar target args))))

(define group-addParents-message
  (catch-message
   (lambda ()
     (js-jsx-group-addParents target args))))

(define arc-get-radius-message
  (catch-message
   (lambda ()
     (js-jsx-arc-get-radius target))))

(define angle-set-angle-message
  (catch-message
   (lambda ()
     (js-jsx-angle-set-angle! target 0))))

(define sector-area-message
  (catch-message
   (lambda ()
     (js-jsx-sector-area target))))

(define glider-start-animation-message
  (catch-message
   (lambda ()
     (js-jsx-glider-start-animation! target 0 0 0))))

(define point-update-message
  (catch-message
   (lambda ()
     (js-jsx-point-update! target 1))))

(check-message board-create-message
               "JSXGraph Board.create not available in this environment"
               "missing JSXGraph Board.create message")
(check-message board-create-point-message
               "JSXGraph Board.create not available in this environment"
               "missing JSXGraph Board.create point message")
(check-message board-add-grid-message
               "JSXGraph Board.addGrid not available in this environment"
               "missing JSXGraph Board.addGrid message")
(check-message board-generate-id-message
               "JSXGraph Board.generateId not available in this environment"
               "missing JSXGraph Board.generateId message")
(check-message board-get-bounding-box-message
               "JSXGraph Board.getBoundingBox not available in this environment"
               "missing JSXGraph Board.getBoundingBox message")
(check-message board-select-message
               "JSXGraph Board.select not available in this environment"
               "missing JSXGraph Board.select message")
(check-message board-update-message
               "JSXGraph Board.update not available in this environment"
               "missing JSXGraph Board.update message")
(check-message board-remove-object-message
               "JSXGraph Board.removeObject not available in this environment"
               "missing JSXGraph Board.removeObject message")
(check-message element-add-event-message
               "JSXGraph GeometryElement.addEvent not available in this environment"
               "missing JSXGraph GeometryElement.addEvent message")
(check-message element-call-message
               "jsx-element.call: method missingMethod not available in this environment"
               "missing jsx-element call message")
(check-message element-call/nullish-message
               "jsx-element.call/nullish: method missingMethod not available in this environment"
               "missing jsx-element call/nullish message")
(check-message line-call-message
               "jsx-line.call: method missingMethod not available in this environment"
               "missing jsx-line call message")
(check-message line-call/nullish-message
               "jsx-line.call/nullish: method missingMethod not available in this environment"
               "missing jsx-line call/nullish message")
(check-message circle-call-message
               "jsx-circle.call: method missingMethod not available in this environment"
               "missing jsx-circle call message")
(check-message circle-call/nullish-message
               "jsx-circle.call/nullish: method missingMethod not available in this environment"
               "missing jsx-circle call/nullish message")
(check-message curve-call-message
               "jsx-curve.call: method missingMethod not available in this environment"
               "missing jsx-curve call message")
(check-message curve-call/nullish-message
               "jsx-curve.call/nullish: method missingMethod not available in this environment"
               "missing jsx-curve call/nullish message")
(check-message polygon-call-message
               "jsx-polygon.call: method missingMethod not available in this environment"
               "missing jsx-polygon call message")
(check-message polygon-call/nullish-message
               "jsx-polygon.call/nullish: method missingMethod not available in this environment"
               "missing jsx-polygon call/nullish message")
(check-message text-setText-message
               "JSXGraph Text.setText not available in this environment"
               "missing JSXGraph Text.setText message")
(check-message foreignobject-update-message
               "JSXGraph ForeignObject.update not available in this environment"
               "missing JSXGraph ForeignObject.update message")
(check-message input-set-message
               "JSXGraph Input.set not available in this environment"
               "missing JSXGraph Input.set message")
(check-message slider-setValue-message
               "JSXGraph Slider.setValue not available in this environment"
               "missing JSXGraph Slider.setValue message")
(check-message chart-drawBar-message
               "JSXGraph Chart.drawBar not available in this environment"
               "missing JSXGraph Chart.drawBar message")
(check-message group-addParents-message
               "JSXGraph Group.addParents not available in this environment"
               "missing JSXGraph Group.addParents message")
(check-message arc-get-radius-message
               "JSXGraph Arc.getRadius not available in this environment"
               "missing JSXGraph Arc.getRadius message")
(check-message angle-set-angle-message
               "JSXGraph Angle.setAngle not available in this environment"
               "missing JSXGraph Angle.setAngle message")
(check-message sector-area-message
               "JSXGraph Sector.Area not available in this environment"
               "missing JSXGraph Sector.Area message")
(check-message glider-start-animation-message
               "JSXGraph Glider.startAnimation not available in this environment"
               "missing JSXGraph Glider.startAnimation message")
(check-message point-update-message
               "JSXGraph Point.update not available in this environment"
               "missing JSXGraph Point.update message")

(js-log "jsxgraph-call-missing-host-ffi-ok")
#t
