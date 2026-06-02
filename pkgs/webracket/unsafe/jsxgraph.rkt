#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-jsx-init-board
 js-jsx-board-create
 js-jsx-board-id
 js-jsx-board-container
 js-jsx-board-renderer
 js-jsx-board-canvas-width
 js-jsx-board-canvas-height
 js-jsx-board-bounding-box
 js-jsx-board-num-objects
 js-jsx-board-objects-list
 js-jsx-board-create-point
 js-jsx-board-create-line
 js-jsx-board-create-segment
 js-jsx-board-create-arc
 js-jsx-board-create-angle
 js-jsx-board-create-sector
 js-jsx-board-create-glider
 js-jsx-board-create-circle
 js-jsx-board-create-conic
 js-jsx-board-create-ellipse
 js-jsx-board-create-curve
 js-jsx-board-create-functiongraph
 js-jsx-board-create-polygon
 js-jsx-board-create-midpoint
 js-jsx-board-create-parallel
 js-jsx-board-create-arrowparallel
 js-jsx-board-create-axis
 js-jsx-board-create-grid
 js-jsx-board-create-boxplot
 js-jsx-board-create-tangent
 js-jsx-board-create-tangentto
 js-jsx-board-create-polarline
 js-jsx-board-create-polepoint
 js-jsx-board-create-radicalaxis
 js-jsx-board-create-circumcircle
 js-jsx-board-create-incircle
 js-jsx-board-create-incenter
 js-jsx-board-create-circumcirclearc
 js-jsx-board-create-minorarc
 js-jsx-board-create-minorsector
 js-jsx-board-create-circumcirclesector
 js-jsx-board-create-semicircle
 js-jsx-board-create-majorarc
 js-jsx-board-create-majorsector
 js-jsx-board-create-curveintersection
 js-jsx-board-create-curvedifference
 js-jsx-board-create-curveunion
 js-jsx-board-create-derivative
 js-jsx-board-create-integral
 js-jsx-board-create-riemannsum
 js-jsx-board-create-slopefield
 js-jsx-board-create-vectorfield
 js-jsx-board-create-implicitcurve
 js-jsx-board-create-spline
 js-jsx-board-create-cardinalspline
 js-jsx-board-create-comb
 js-jsx-board-create-metapostspline
 js-jsx-board-create-polygonalchain
 js-jsx-board-create-regularpolygon
 js-jsx-board-create-hyperbola
 js-jsx-board-create-parabola
 js-jsx-board-create-stepfunction
 js-jsx-board-create-inequality
 js-jsx-board-create-turtle
 js-jsx-board-create-slopetriangle
 js-jsx-board-create-perpendicular
 js-jsx-board-create-reflection
 js-jsx-board-create-bisector
 js-jsx-board-create-normal
 js-jsx-board-create-intersection
 js-jsx-board-create-arrow
 js-jsx-board-create-button
 js-jsx-board-create-checkbox
 js-jsx-board-create-input
 js-jsx-board-create-slider
 js-jsx-board-create-chart
 js-jsx-board-create-legend
 js-jsx-board-create-smartlabel
 js-jsx-board-create-foreignobject
 js-jsx-board-create-tapemeasure
 js-jsx-board-create-ticks
 js-jsx-board-create-hatch
 js-jsx-board-create-transformation
 js-jsx-board-create-tracecurve
 js-jsx-board-create-parallelogram
 js-jsx-board-create-reflexangle
 js-jsx-board-create-nonreflexangle
 js-jsx-board-create-measurement
 js-jsx-board-create-bisectorlines
 js-jsx-board-create-perpendicularsegment
 js-jsx-board-create-circumcenter
 js-jsx-board-create-mirrorelement
 js-jsx-board-create-mirrorpoint
 js-jsx-board-create-otherintersection
 js-jsx-board-create-orthogonalprojection
 js-jsx-board-create-parallelpoint
 js-jsx-board-create-perpendicularpoint
 js-jsx-checkbox-Value
 js-jsx-input-set
 js-jsx-input-Value
 js-jsx-slider-setMax
 js-jsx-slider-setMin
 js-jsx-slider-setValue
 js-jsx-slider-Value
 js-jsx-chart-drawBar
 js-jsx-chart-drawFit
 js-jsx-chart-drawLine
 js-jsx-chart-drawPie
 js-jsx-chart-drawPoints
 js-jsx-chart-drawRadar
 js-jsx-chart-drawSpline
 js-jsx-chart-updateDataArray
 js-jsx-chart-updateRenderer
 js-jsx-board-create-text
 js-jsx-board-create-image
 js-jsx-board-create-group
 js-jsx-group-addParents
 js-jsx-group-addPoint
 js-jsx-group-addPoints
 js-jsx-group-addRotationPoint
 js-jsx-group-addScalePoint
 js-jsx-group-addTranslationPoint
 js-jsx-group-addGroup
 js-jsx-group-removePoint
 js-jsx-group-removeRotationPoint
 js-jsx-group-removeScalePoint
 js-jsx-group-removeTranslationPoint
 js-jsx-group-setParents
 js-jsx-group-setRotationCenter
 js-jsx-group-setRotationPoints
 js-jsx-group-setScaleCenter
 js-jsx-group-setScalePoints
 js-jsx-group-setTranslationPoints
 js-jsx-group-ungroup
 js-jsx-group-update
 js-jsx-text-_createFctUpdateText
 js-jsx-text-_setText
 js-jsx-text-bounds
 js-jsx-text-check-for-size-update
 js-jsx-text-checkForSizeUpdate
 js-jsx-text-convert-geonext2-css
 js-jsx-text-convertGeonext2CSS
 js-jsx-text-convert-geonext-and-sketchometry2-css
 js-jsx-text-convertGeonextAndSketchometry2CSS
 js-jsx-text-convert-sketchometry2-css
 js-jsx-text-convertSketchometry2CSS
 js-jsx-text-crude-size-estimate
 js-jsx-text-crudeSizeEstimate
 js-jsx-text-escape-ticks
 js-jsx-text-escapeTicks
 js-jsx-text-expand-short-math
 js-jsx-text-expandShortMath
 js-jsx-text-generate-term
 js-jsx-text-generateTerm
 js-jsx-text-get-anchor-x
 js-jsx-text-getAnchorX
 js-jsx-text-get-anchor-y
 js-jsx-text-getAnchorY
 js-jsx-text-get-number-of-conflicts
 js-jsx-text-getNumberOfConflicts
 js-jsx-text-get-size
 js-jsx-text-getSize
 js-jsx-text-has-point
 js-jsx-text-hasPoint
 js-jsx-text-notify-parents
 js-jsx-text-notifyParents
 js-jsx-text-poor-mans-tex
 js-jsx-text-poorMansTeX
 js-jsx-text-replace-sub
 js-jsx-text-replaceSub
 js-jsx-text-replace-sup
 js-jsx-text-replaceSup
 js-jsx-text-set-auto-position
 js-jsx-text-setAutoPosition
 js-jsx-text-set-coords
 js-jsx-text-setCoords
 js-jsx-text-set-text
 js-jsx-text-setText
 js-jsx-text-set-text-jessie-code
 js-jsx-text-setTextJessieCode
 js-jsx-text-unescape-ticks
 js-jsx-text-unescapeTicks
 js-jsx-text-update-size
 js-jsx-text-updateSize
 js-jsx-text-update-text
 js-jsx-text-updateText
 js-jsx-text-utf8-decode
 js-jsx-text-utf8_decode
 js-jsx-text-value-tag-to-jessie-code
 js-jsx-text-valueTagToJessieCode
 js-jsx-image-H
 js-jsx-image-W
 js-jsx-image-has-point
 js-jsx-image-set-size
 js-jsx-image-update
 js-jsx-image-update-renderer
 js-jsx-image-update-size
 js-jsx-image-update-span
 js-jsx-foreignobject-H
 js-jsx-foreignobject-W
 js-jsx-foreignobject-has-point
 js-jsx-foreignobject-set-size
 js-jsx-foreignobject-update
 js-jsx-foreignobject-update-renderer
 js-jsx-foreignobject-update-size
 js-jsx-foreignobject-update-span
 js-jsx-tapemeasure-Value
 js-jsx-board-update!
 js-jsx-board-full-update!
 js-jsx-board-remove-object!
 js-jsx-board-suspend-update!
 js-jsx-board-unsuspend-update!
 js-jsx-board-add-grid!
 js-jsx-board-add-hook!
 js-jsx-board-add-keyboard-event-handlers!
 js-jsx-board-add-mouse-event-handlers!
 js-jsx-board-add-pointer-event-handlers!
 js-jsx-board-add-resize-event-handlers!
 js-jsx-board-add-touch-event-handlers!
 js-jsx-board-add-wheel-event-handlers!
 js-jsx-board-add-fullscreen-event-handlers!
 js-jsx-board-add-event-handlers!
 js-jsx-board-on
 js-jsx-board-add-child!
 js-jsx-board-get-mouse-position
 js-jsx-board-get-mouse-position/index
 js-jsx-board-get-usr-coords-of-mouse
 js-jsx-board-get-coords-top-left-corner
 js-jsx-board-get-bounding-box
 js-jsx-board-get-scr-coords-of-mouse
 js-jsx-board-get-all-objects-under-mouse
 js-jsx-board-get-all-under-mouse
 js-jsx-board-has-point!
 js-jsx-board-add-animation!
 js-jsx-board-add-conditions!
 js-jsx-board-apply-zoom!
 js-jsx-board-calculate-snap-sizes!
 js-jsx-board-create-roulette!
 js-jsx-board-highlight-custom-infobox!
 js-jsx-board-highlight-custom-infobox/element!
 js-jsx-board-highlight-infobox!
 js-jsx-board-highlight-infobox/element!
 js-jsx-board-move-object!
 js-jsx-board-move-origin!
 js-jsx-board-finalize-adding!
 js-jsx-board-set-attribute!
 js-jsx-board-set-bounding-box!
 js-jsx-board-set-zoom!
 js-jsx-board-resize-container!
 js-jsx-board-remove-grids!
 js-jsx-board-remove-hook!
 js-jsx-board-off
 js-jsx-board-remove-keyboard-event-handlers!
 js-jsx-board-remove-mouse-event-handlers!
 js-jsx-board-remove-pointer-event-handlers!
 js-jsx-board-remove-resize-event-handlers!
 js-jsx-board-remove-event-handlers!
 js-jsx-board-remove-touch-event-handlers!
 js-jsx-board-select
 js-jsx-board-zoom100!
 js-jsx-board-zoom-all-points!
 js-jsx-board-zoom-in!
 js-jsx-board-zoom-out!
 js-jsx-board-start-selection-mode!
 js-jsx-board-stop-selection-mode!
 js-jsx-board-stop-all-animation!
 js-jsx-board-clear-traces!
 js-jsx-board-dehighlight-all!
 js-jsx-board-update-coords!
 js-jsx-board-update-container-dims!
 js-jsx-board-update-container-dims/size!
 js-jsx-board-update-csstransforms!
 js-jsx-board-update-elements!
 js-jsx-board-update-hooks!
 js-jsx-board-update-conditions!
 js-jsx-board-suppress-default!
 js-jsx-board-init-infobox!
 js-jsx-board-init-move-object!
 js-jsx-board-init-move-origin!
 js-jsx-board-show-dependencies!
 js-jsx-board-generate-id
 js-jsx-board-generate-name
 js-jsx-board-init-geonext-board!
 js-jsx-board-show-xml!
 js-jsx-board-to-fullscreen!
 js-jsx-board-start-resize-observer!
 js-jsx-board-stop-resize-observer!
 js-jsx-board-start-intersection-observer!
 js-jsx-board-stop-intersection-observer!
 js-jsx-board-update-infobox!
 js-jsx-board-set-id
 js-jsx-board-update-renderer!
 js-jsx-board-update-renderer-canvas!
 js-jsx-board-zoom-elements!
 js-jsx-element-call
 js-jsx-element-call/nullish
 js-jsx-element-add-event
 js-jsx-line-call
 js-jsx-line-call/nullish
 js-jsx-arc-get-radius
 js-jsx-arc-has-point-sector
 js-jsx-arc-radius
 js-jsx-arc-value
 js-jsx-angle-free
 js-jsx-angle-set-angle!
 js-jsx-angle-value
 js-jsx-sector-area
 js-jsx-sector-has-point-sector
 js-jsx-sector-l
 js-jsx-sector-perimeter
 js-jsx-sector-radius
 js-jsx-sector-set-position-directly!
 js-jsx-sector-set-radius!
 js-jsx-glider-start-animation!
 js-jsx-glider-stop-animation!
 js-jsx-circle-call
 js-jsx-circle-call/nullish
 js-jsx-curve-call
 js-jsx-curve-call/nullish
 js-jsx-riemannsum-Value
 js-jsx-slopefield-setF
 js-jsx-vectorfield-setF
 js-jsx-polygon-call
 js-jsx-polygon-call/nullish
 js-jsx-point?
 js-jsx-point-attractor-distance
 js-jsx-set-point-attractor-distance!
 js-jsx-point-attractors
 js-jsx-set-point-attractors!
 js-jsx-point-attractor-unit
 js-jsx-set-point-attractor-unit!
 js-jsx-point-attract-to-grid
 js-jsx-set-point-attract-to-grid!
 js-jsx-point-face
 js-jsx-set-point-face!
 js-jsx-point-ignored-snap-to-points
 js-jsx-set-point-ignored-snap-to-points!
 js-jsx-point-infobox-digits
 js-jsx-set-point-infobox-digits!
 js-jsx-point-show-infobox
 js-jsx-set-point-show-infobox!
 js-jsx-point-size
 js-jsx-set-point-size!
 js-jsx-point-size-unit
 js-jsx-set-point-size-unit!
 js-jsx-point-snap-size-x
 js-jsx-set-point-snap-size-x!
 js-jsx-point-snap-size-y
 js-jsx-set-point-snap-size-y!
 js-jsx-point-snap-to-grid
 js-jsx-set-point-snap-to-grid!
 js-jsx-point-snap-to-points
 js-jsx-set-point-snap-to-points!
 js-jsx-point-snatch-distance
 js-jsx-set-point-snatch-distance!
 js-jsx-point-style
 js-jsx-set-point-style!
 js-jsx-point-x
 js-jsx-point-y
 js-jsx-point-zoom
 js-jsx-set-point-zoom!
 js-jsx-point-has-point
 js-jsx-point-is-on
 js-jsx-point-make-intersection!
 js-jsx-point-normalize-face
 js-jsx-point-set-style!
 js-jsx-point-update!
 js-jsx-point-update-renderer!
 js-jsx-point-update-transform!)

;; js-jsx-init-board : ffi (string value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-init-board (unsafe-ffi-primitive 'js-jsx-init-board))

;; js-jsx-board-create : ffi (extern string value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create (unsafe-ffi-primitive 'js-jsx-board-create))

;; js-jsx-board-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-id (unsafe-ffi-primitive 'js-jsx-board-id))

;; js-jsx-board-container : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-container (unsafe-ffi-primitive 'js-jsx-board-container))

;; js-jsx-board-renderer : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-renderer (unsafe-ffi-primitive 'js-jsx-board-renderer))

;; js-jsx-board-canvas-width : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-canvas-width (unsafe-ffi-primitive 'js-jsx-board-canvas-width))

;; js-jsx-board-canvas-height : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-canvas-height (unsafe-ffi-primitive 'js-jsx-board-canvas-height))

;; js-jsx-board-bounding-box : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-bounding-box (unsafe-ffi-primitive 'js-jsx-board-bounding-box))

;; js-jsx-board-num-objects : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-num-objects (unsafe-ffi-primitive 'js-jsx-board-num-objects))

;; js-jsx-board-objects-list : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-objects-list (unsafe-ffi-primitive 'js-jsx-board-objects-list))

;; js-jsx-board-create-point : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-point (unsafe-ffi-primitive 'js-jsx-board-create-point))

;; js-jsx-board-create-line : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-line (unsafe-ffi-primitive 'js-jsx-board-create-line))

;; js-jsx-board-create-segment : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-segment (unsafe-ffi-primitive 'js-jsx-board-create-segment))

;; js-jsx-board-create-arc : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-arc (unsafe-ffi-primitive 'js-jsx-board-create-arc))

;; js-jsx-board-create-angle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-angle (unsafe-ffi-primitive 'js-jsx-board-create-angle))

;; js-jsx-board-create-sector : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-sector (unsafe-ffi-primitive 'js-jsx-board-create-sector))

;; js-jsx-board-create-glider : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-glider (unsafe-ffi-primitive 'js-jsx-board-create-glider))

;; js-jsx-board-create-circle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-circle (unsafe-ffi-primitive 'js-jsx-board-create-circle))

;; js-jsx-board-create-conic : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-conic (unsafe-ffi-primitive 'js-jsx-board-create-conic))

;; js-jsx-board-create-ellipse : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-ellipse (unsafe-ffi-primitive 'js-jsx-board-create-ellipse))

;; js-jsx-board-create-curve : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-curve (unsafe-ffi-primitive 'js-jsx-board-create-curve))

;; js-jsx-board-create-functiongraph : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-functiongraph (unsafe-ffi-primitive 'js-jsx-board-create-functiongraph))

;; js-jsx-board-create-polygon : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-polygon (unsafe-ffi-primitive 'js-jsx-board-create-polygon))

;; js-jsx-board-create-midpoint : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-midpoint (unsafe-ffi-primitive 'js-jsx-board-create-midpoint))

;; js-jsx-board-create-parallel : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-parallel (unsafe-ffi-primitive 'js-jsx-board-create-parallel))

;; js-jsx-board-create-arrowparallel : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-arrowparallel (unsafe-ffi-primitive 'js-jsx-board-create-arrowparallel))

;; js-jsx-board-create-axis : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-axis (unsafe-ffi-primitive 'js-jsx-board-create-axis))

;; js-jsx-board-create-grid : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-grid (unsafe-ffi-primitive 'js-jsx-board-create-grid))

;; js-jsx-board-create-boxplot : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-boxplot (unsafe-ffi-primitive 'js-jsx-board-create-boxplot))

;; js-jsx-board-create-tangent : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-tangent (unsafe-ffi-primitive 'js-jsx-board-create-tangent))

;; js-jsx-board-create-tangentto : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-tangentto (unsafe-ffi-primitive 'js-jsx-board-create-tangentto))

;; js-jsx-board-create-polarline : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-polarline (unsafe-ffi-primitive 'js-jsx-board-create-polarline))

;; js-jsx-board-create-polepoint : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-polepoint (unsafe-ffi-primitive 'js-jsx-board-create-polepoint))

;; js-jsx-board-create-radicalaxis : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-radicalaxis (unsafe-ffi-primitive 'js-jsx-board-create-radicalaxis))

;; js-jsx-board-create-circumcircle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-circumcircle (unsafe-ffi-primitive 'js-jsx-board-create-circumcircle))

;; js-jsx-board-create-incircle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-incircle (unsafe-ffi-primitive 'js-jsx-board-create-incircle))

;; js-jsx-board-create-incenter : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-incenter (unsafe-ffi-primitive 'js-jsx-board-create-incenter))

;; js-jsx-board-create-circumcirclearc : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-circumcirclearc (unsafe-ffi-primitive 'js-jsx-board-create-circumcirclearc))

;; js-jsx-board-create-minorarc : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-minorarc (unsafe-ffi-primitive 'js-jsx-board-create-minorarc))

;; js-jsx-board-create-minorsector : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-minorsector (unsafe-ffi-primitive 'js-jsx-board-create-minorsector))

;; js-jsx-board-create-circumcirclesector : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-circumcirclesector (unsafe-ffi-primitive 'js-jsx-board-create-circumcirclesector))

;; js-jsx-board-create-semicircle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-semicircle (unsafe-ffi-primitive 'js-jsx-board-create-semicircle))

;; js-jsx-board-create-majorarc : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-majorarc (unsafe-ffi-primitive 'js-jsx-board-create-majorarc))

;; js-jsx-board-create-majorsector : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-majorsector (unsafe-ffi-primitive 'js-jsx-board-create-majorsector))

;; js-jsx-board-create-curveintersection : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-curveintersection (unsafe-ffi-primitive 'js-jsx-board-create-curveintersection))

;; js-jsx-board-create-curvedifference : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-curvedifference (unsafe-ffi-primitive 'js-jsx-board-create-curvedifference))

;; js-jsx-board-create-curveunion : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-curveunion (unsafe-ffi-primitive 'js-jsx-board-create-curveunion))

;; js-jsx-board-create-derivative : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-derivative (unsafe-ffi-primitive 'js-jsx-board-create-derivative))

;; js-jsx-board-create-integral : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-integral (unsafe-ffi-primitive 'js-jsx-board-create-integral))

;; js-jsx-board-create-riemannsum : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-riemannsum (unsafe-ffi-primitive 'js-jsx-board-create-riemannsum))

;; js-jsx-board-create-slopefield : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-slopefield (unsafe-ffi-primitive 'js-jsx-board-create-slopefield))

;; js-jsx-board-create-vectorfield : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-vectorfield (unsafe-ffi-primitive 'js-jsx-board-create-vectorfield))

;; js-jsx-board-create-implicitcurve : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-implicitcurve (unsafe-ffi-primitive 'js-jsx-board-create-implicitcurve))

;; js-jsx-board-create-spline : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-spline (unsafe-ffi-primitive 'js-jsx-board-create-spline))

;; js-jsx-board-create-cardinalspline : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-cardinalspline (unsafe-ffi-primitive 'js-jsx-board-create-cardinalspline))

;; js-jsx-board-create-comb : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-comb (unsafe-ffi-primitive 'js-jsx-board-create-comb))

;; js-jsx-board-create-metapostspline : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-metapostspline (unsafe-ffi-primitive 'js-jsx-board-create-metapostspline))

;; js-jsx-board-create-polygonalchain : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-polygonalchain (unsafe-ffi-primitive 'js-jsx-board-create-polygonalchain))

;; js-jsx-board-create-regularpolygon : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-regularpolygon (unsafe-ffi-primitive 'js-jsx-board-create-regularpolygon))

;; js-jsx-board-create-hyperbola : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-hyperbola (unsafe-ffi-primitive 'js-jsx-board-create-hyperbola))

;; js-jsx-board-create-parabola : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-parabola (unsafe-ffi-primitive 'js-jsx-board-create-parabola))

;; js-jsx-board-create-stepfunction : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-stepfunction (unsafe-ffi-primitive 'js-jsx-board-create-stepfunction))

;; js-jsx-board-create-inequality : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-inequality (unsafe-ffi-primitive 'js-jsx-board-create-inequality))

;; js-jsx-board-create-turtle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-turtle (unsafe-ffi-primitive 'js-jsx-board-create-turtle))

;; js-jsx-board-create-slopetriangle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-slopetriangle (unsafe-ffi-primitive 'js-jsx-board-create-slopetriangle))

;; js-jsx-board-create-perpendicular : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-perpendicular (unsafe-ffi-primitive 'js-jsx-board-create-perpendicular))

;; js-jsx-board-create-reflection : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-reflection (unsafe-ffi-primitive 'js-jsx-board-create-reflection))

;; js-jsx-board-create-bisector : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-bisector (unsafe-ffi-primitive 'js-jsx-board-create-bisector))

;; js-jsx-board-create-normal : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-normal (unsafe-ffi-primitive 'js-jsx-board-create-normal))

;; js-jsx-board-create-intersection : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-intersection (unsafe-ffi-primitive 'js-jsx-board-create-intersection))

;; js-jsx-board-create-arrow : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-arrow (unsafe-ffi-primitive 'js-jsx-board-create-arrow))

;; js-jsx-board-create-button : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-button (unsafe-ffi-primitive 'js-jsx-board-create-button))

;; js-jsx-board-create-checkbox : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-checkbox (unsafe-ffi-primitive 'js-jsx-board-create-checkbox))

;; js-jsx-board-create-input : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-input (unsafe-ffi-primitive 'js-jsx-board-create-input))

;; js-jsx-board-create-slider : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-slider (unsafe-ffi-primitive 'js-jsx-board-create-slider))

;; js-jsx-board-create-chart : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-chart (unsafe-ffi-primitive 'js-jsx-board-create-chart))

;; js-jsx-board-create-legend : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-legend (unsafe-ffi-primitive 'js-jsx-board-create-legend))

;; js-jsx-board-create-smartlabel : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-smartlabel (unsafe-ffi-primitive 'js-jsx-board-create-smartlabel))

;; js-jsx-board-create-foreignobject : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-foreignobject (unsafe-ffi-primitive 'js-jsx-board-create-foreignobject))

;; js-jsx-board-create-tapemeasure : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-tapemeasure (unsafe-ffi-primitive 'js-jsx-board-create-tapemeasure))

;; js-jsx-board-create-ticks : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-ticks (unsafe-ffi-primitive 'js-jsx-board-create-ticks))

;; js-jsx-board-create-hatch : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-hatch (unsafe-ffi-primitive 'js-jsx-board-create-hatch))

;; js-jsx-board-create-transformation : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-transformation (unsafe-ffi-primitive 'js-jsx-board-create-transformation))

;; js-jsx-board-create-tracecurve : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-tracecurve (unsafe-ffi-primitive 'js-jsx-board-create-tracecurve))

;; js-jsx-board-create-parallelogram : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-parallelogram (unsafe-ffi-primitive 'js-jsx-board-create-parallelogram))

;; js-jsx-board-create-reflexangle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-reflexangle (unsafe-ffi-primitive 'js-jsx-board-create-reflexangle))

;; js-jsx-board-create-nonreflexangle : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-nonreflexangle (unsafe-ffi-primitive 'js-jsx-board-create-nonreflexangle))

;; js-jsx-board-create-measurement : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-measurement (unsafe-ffi-primitive 'js-jsx-board-create-measurement))

;; js-jsx-board-create-bisectorlines : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-bisectorlines (unsafe-ffi-primitive 'js-jsx-board-create-bisectorlines))

;; js-jsx-board-create-perpendicularsegment : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-perpendicularsegment (unsafe-ffi-primitive 'js-jsx-board-create-perpendicularsegment))

;; js-jsx-board-create-circumcenter : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-circumcenter (unsafe-ffi-primitive 'js-jsx-board-create-circumcenter))

;; js-jsx-board-create-mirrorelement : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-mirrorelement (unsafe-ffi-primitive 'js-jsx-board-create-mirrorelement))

;; js-jsx-board-create-mirrorpoint : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-mirrorpoint (unsafe-ffi-primitive 'js-jsx-board-create-mirrorpoint))

;; js-jsx-board-create-otherintersection : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-otherintersection (unsafe-ffi-primitive 'js-jsx-board-create-otherintersection))

;; js-jsx-board-create-orthogonalprojection : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-orthogonalprojection (unsafe-ffi-primitive 'js-jsx-board-create-orthogonalprojection))

;; js-jsx-board-create-parallelpoint : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-parallelpoint (unsafe-ffi-primitive 'js-jsx-board-create-parallelpoint))

;; js-jsx-board-create-perpendicularpoint : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-perpendicularpoint (unsafe-ffi-primitive 'js-jsx-board-create-perpendicularpoint))

;; js-jsx-checkbox-Value : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-checkbox-Value (unsafe-ffi-primitive 'js-jsx-checkbox-Value))

;; js-jsx-input-set : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-input-set (unsafe-ffi-primitive 'js-jsx-input-set))

;; js-jsx-input-Value : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-input-Value (unsafe-ffi-primitive 'js-jsx-input-Value))

;; js-jsx-slider-setMax : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-slider-setMax (unsafe-ffi-primitive 'js-jsx-slider-setMax))

;; js-jsx-slider-setMin : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-slider-setMin (unsafe-ffi-primitive 'js-jsx-slider-setMin))

;; js-jsx-slider-setValue : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-slider-setValue (unsafe-ffi-primitive 'js-jsx-slider-setValue))

;; js-jsx-slider-Value : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-slider-Value (unsafe-ffi-primitive 'js-jsx-slider-Value))

;; js-jsx-chart-drawBar : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawBar (unsafe-ffi-primitive 'js-jsx-chart-drawBar))

;; js-jsx-chart-drawFit : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawFit (unsafe-ffi-primitive 'js-jsx-chart-drawFit))

;; js-jsx-chart-drawLine : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawLine (unsafe-ffi-primitive 'js-jsx-chart-drawLine))

;; js-jsx-chart-drawPie : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawPie (unsafe-ffi-primitive 'js-jsx-chart-drawPie))

;; js-jsx-chart-drawPoints : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawPoints (unsafe-ffi-primitive 'js-jsx-chart-drawPoints))

;; js-jsx-chart-drawRadar : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawRadar (unsafe-ffi-primitive 'js-jsx-chart-drawRadar))

;; js-jsx-chart-drawSpline : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-drawSpline (unsafe-ffi-primitive 'js-jsx-chart-drawSpline))

;; js-jsx-chart-updateDataArray : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-updateDataArray (unsafe-ffi-primitive 'js-jsx-chart-updateDataArray))

;; js-jsx-chart-updateRenderer : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-chart-updateRenderer (unsafe-ffi-primitive 'js-jsx-chart-updateRenderer))

;; js-jsx-board-create-text : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-text (unsafe-ffi-primitive 'js-jsx-board-create-text))

;; js-jsx-board-create-image : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-image (unsafe-ffi-primitive 'js-jsx-board-create-image))

;; js-jsx-board-create-group : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-group (unsafe-ffi-primitive 'js-jsx-board-create-group))

;; js-jsx-group-addParents : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addParents (unsafe-ffi-primitive 'js-jsx-group-addParents))

;; js-jsx-group-addPoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addPoint (unsafe-ffi-primitive 'js-jsx-group-addPoint))

;; js-jsx-group-addPoints : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addPoints (unsafe-ffi-primitive 'js-jsx-group-addPoints))

;; js-jsx-group-addRotationPoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addRotationPoint (unsafe-ffi-primitive 'js-jsx-group-addRotationPoint))

;; js-jsx-group-addScalePoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addScalePoint (unsafe-ffi-primitive 'js-jsx-group-addScalePoint))

;; js-jsx-group-addTranslationPoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addTranslationPoint (unsafe-ffi-primitive 'js-jsx-group-addTranslationPoint))

;; js-jsx-group-addGroup : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-addGroup (unsafe-ffi-primitive 'js-jsx-group-addGroup))

;; js-jsx-group-removePoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-removePoint (unsafe-ffi-primitive 'js-jsx-group-removePoint))

;; js-jsx-group-removeRotationPoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-removeRotationPoint (unsafe-ffi-primitive 'js-jsx-group-removeRotationPoint))

;; js-jsx-group-removeScalePoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-removeScalePoint (unsafe-ffi-primitive 'js-jsx-group-removeScalePoint))

;; js-jsx-group-removeTranslationPoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-removeTranslationPoint (unsafe-ffi-primitive 'js-jsx-group-removeTranslationPoint))

;; js-jsx-group-setParents : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-setParents (unsafe-ffi-primitive 'js-jsx-group-setParents))

;; js-jsx-group-setRotationCenter : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-setRotationCenter (unsafe-ffi-primitive 'js-jsx-group-setRotationCenter))

;; js-jsx-group-setRotationPoints : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-setRotationPoints (unsafe-ffi-primitive 'js-jsx-group-setRotationPoints))

;; js-jsx-group-setScaleCenter : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-setScaleCenter (unsafe-ffi-primitive 'js-jsx-group-setScaleCenter))

;; js-jsx-group-setScalePoints : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-setScalePoints (unsafe-ffi-primitive 'js-jsx-group-setScalePoints))

;; js-jsx-group-setTranslationPoints : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-setTranslationPoints (unsafe-ffi-primitive 'js-jsx-group-setTranslationPoints))

;; js-jsx-group-ungroup : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-ungroup (unsafe-ffi-primitive 'js-jsx-group-ungroup))

;; js-jsx-group-update : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-group-update (unsafe-ffi-primitive 'js-jsx-group-update))

;; js-jsx-text-_createFctUpdateText : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-_createFctUpdateText (unsafe-ffi-primitive 'js-jsx-text-_createFctUpdateText))

;; js-jsx-text-_setText : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-_setText (unsafe-ffi-primitive 'js-jsx-text-_setText))

;; js-jsx-text-bounds : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-bounds (unsafe-ffi-primitive 'js-jsx-text-bounds))

;; js-jsx-text-check-for-size-update : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-check-for-size-update (unsafe-ffi-primitive 'js-jsx-text-check-for-size-update))

;; js-jsx-text-checkForSizeUpdate : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-checkForSizeUpdate (unsafe-ffi-primitive 'js-jsx-text-checkForSizeUpdate))

;; js-jsx-text-convert-geonext2-css : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-convert-geonext2-css (unsafe-ffi-primitive 'js-jsx-text-convert-geonext2-css))

;; js-jsx-text-convertGeonext2CSS : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-convertGeonext2CSS (unsafe-ffi-primitive 'js-jsx-text-convertGeonext2CSS))

;; js-jsx-text-convert-geonext-and-sketchometry2-css : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-convert-geonext-and-sketchometry2-css (unsafe-ffi-primitive 'js-jsx-text-convert-geonext-and-sketchometry2-css))

;; js-jsx-text-convertGeonextAndSketchometry2CSS : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-convertGeonextAndSketchometry2CSS (unsafe-ffi-primitive 'js-jsx-text-convertGeonextAndSketchometry2CSS))

;; js-jsx-text-convert-sketchometry2-css : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-convert-sketchometry2-css (unsafe-ffi-primitive 'js-jsx-text-convert-sketchometry2-css))

;; js-jsx-text-convertSketchometry2CSS : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-convertSketchometry2CSS (unsafe-ffi-primitive 'js-jsx-text-convertSketchometry2CSS))

;; js-jsx-text-crude-size-estimate : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-crude-size-estimate (unsafe-ffi-primitive 'js-jsx-text-crude-size-estimate))

;; js-jsx-text-crudeSizeEstimate : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-crudeSizeEstimate (unsafe-ffi-primitive 'js-jsx-text-crudeSizeEstimate))

;; js-jsx-text-escape-ticks : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-escape-ticks (unsafe-ffi-primitive 'js-jsx-text-escape-ticks))

;; js-jsx-text-escapeTicks : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-escapeTicks (unsafe-ffi-primitive 'js-jsx-text-escapeTicks))

;; js-jsx-text-expand-short-math : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-expand-short-math (unsafe-ffi-primitive 'js-jsx-text-expand-short-math))

;; js-jsx-text-expandShortMath : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-expandShortMath (unsafe-ffi-primitive 'js-jsx-text-expandShortMath))

;; js-jsx-text-generate-term : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-generate-term (unsafe-ffi-primitive 'js-jsx-text-generate-term))

;; js-jsx-text-generateTerm : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-generateTerm (unsafe-ffi-primitive 'js-jsx-text-generateTerm))

;; js-jsx-text-get-anchor-x : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-get-anchor-x (unsafe-ffi-primitive 'js-jsx-text-get-anchor-x))

;; js-jsx-text-getAnchorX : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-getAnchorX (unsafe-ffi-primitive 'js-jsx-text-getAnchorX))

;; js-jsx-text-get-anchor-y : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-get-anchor-y (unsafe-ffi-primitive 'js-jsx-text-get-anchor-y))

;; js-jsx-text-getAnchorY : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-getAnchorY (unsafe-ffi-primitive 'js-jsx-text-getAnchorY))

;; js-jsx-text-get-number-of-conflicts : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-get-number-of-conflicts (unsafe-ffi-primitive 'js-jsx-text-get-number-of-conflicts))

;; js-jsx-text-getNumberOfConflicts : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-getNumberOfConflicts (unsafe-ffi-primitive 'js-jsx-text-getNumberOfConflicts))

;; js-jsx-text-get-size : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-get-size (unsafe-ffi-primitive 'js-jsx-text-get-size))

;; js-jsx-text-getSize : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-getSize (unsafe-ffi-primitive 'js-jsx-text-getSize))

;; js-jsx-text-has-point : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-has-point (unsafe-ffi-primitive 'js-jsx-text-has-point))

;; js-jsx-text-hasPoint : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-hasPoint (unsafe-ffi-primitive 'js-jsx-text-hasPoint))

;; js-jsx-text-notify-parents : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-notify-parents (unsafe-ffi-primitive 'js-jsx-text-notify-parents))

;; js-jsx-text-notifyParents : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-notifyParents (unsafe-ffi-primitive 'js-jsx-text-notifyParents))

;; js-jsx-text-poor-mans-tex : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-poor-mans-tex (unsafe-ffi-primitive 'js-jsx-text-poor-mans-tex))

;; js-jsx-text-poorMansTeX : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-poorMansTeX (unsafe-ffi-primitive 'js-jsx-text-poorMansTeX))

;; js-jsx-text-replace-sub : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-replace-sub (unsafe-ffi-primitive 'js-jsx-text-replace-sub))

;; js-jsx-text-replaceSub : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-replaceSub (unsafe-ffi-primitive 'js-jsx-text-replaceSub))

;; js-jsx-text-replace-sup : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-replace-sup (unsafe-ffi-primitive 'js-jsx-text-replace-sup))

;; js-jsx-text-replaceSup : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-replaceSup (unsafe-ffi-primitive 'js-jsx-text-replaceSup))

;; js-jsx-text-set-auto-position : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-set-auto-position (unsafe-ffi-primitive 'js-jsx-text-set-auto-position))

;; js-jsx-text-setAutoPosition : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-setAutoPosition (unsafe-ffi-primitive 'js-jsx-text-setAutoPosition))

;; js-jsx-text-set-coords : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-set-coords (unsafe-ffi-primitive 'js-jsx-text-set-coords))

;; js-jsx-text-setCoords : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-setCoords (unsafe-ffi-primitive 'js-jsx-text-setCoords))

;; js-jsx-text-set-text : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-set-text (unsafe-ffi-primitive 'js-jsx-text-set-text))

;; js-jsx-text-setText : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-setText (unsafe-ffi-primitive 'js-jsx-text-setText))

;; js-jsx-text-set-text-jessie-code : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-set-text-jessie-code (unsafe-ffi-primitive 'js-jsx-text-set-text-jessie-code))

;; js-jsx-text-setTextJessieCode : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-setTextJessieCode (unsafe-ffi-primitive 'js-jsx-text-setTextJessieCode))

;; js-jsx-text-unescape-ticks : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-unescape-ticks (unsafe-ffi-primitive 'js-jsx-text-unescape-ticks))

;; js-jsx-text-unescapeTicks : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-unescapeTicks (unsafe-ffi-primitive 'js-jsx-text-unescapeTicks))

;; js-jsx-text-update-size : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-update-size (unsafe-ffi-primitive 'js-jsx-text-update-size))

;; js-jsx-text-updateSize : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-updateSize (unsafe-ffi-primitive 'js-jsx-text-updateSize))

;; js-jsx-text-update-text : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-update-text (unsafe-ffi-primitive 'js-jsx-text-update-text))

;; js-jsx-text-updateText : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-updateText (unsafe-ffi-primitive 'js-jsx-text-updateText))

;; js-jsx-text-utf8-decode : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-utf8-decode (unsafe-ffi-primitive 'js-jsx-text-utf8-decode))

;; js-jsx-text-utf8_decode : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-utf8_decode (unsafe-ffi-primitive 'js-jsx-text-utf8_decode))

;; js-jsx-text-value-tag-to-jessie-code : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-value-tag-to-jessie-code (unsafe-ffi-primitive 'js-jsx-text-value-tag-to-jessie-code))

;; js-jsx-text-valueTagToJessieCode : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-text-valueTagToJessieCode (unsafe-ffi-primitive 'js-jsx-text-valueTagToJessieCode))

;; js-jsx-image-H : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-H (unsafe-ffi-primitive 'js-jsx-image-H))

;; js-jsx-image-W : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-W (unsafe-ffi-primitive 'js-jsx-image-W))

;; js-jsx-image-has-point : ffi (extern value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-has-point (unsafe-ffi-primitive 'js-jsx-image-has-point))

;; js-jsx-image-set-size : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-set-size (unsafe-ffi-primitive 'js-jsx-image-set-size))

;; js-jsx-image-update : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-update (unsafe-ffi-primitive 'js-jsx-image-update))

;; js-jsx-image-update-renderer : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-update-renderer (unsafe-ffi-primitive 'js-jsx-image-update-renderer))

;; js-jsx-image-update-size : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-update-size (unsafe-ffi-primitive 'js-jsx-image-update-size))

;; js-jsx-image-update-span : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-image-update-span (unsafe-ffi-primitive 'js-jsx-image-update-span))

;; js-jsx-foreignobject-H : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-H (unsafe-ffi-primitive 'js-jsx-foreignobject-H))

;; js-jsx-foreignobject-W : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-W (unsafe-ffi-primitive 'js-jsx-foreignobject-W))

;; js-jsx-foreignobject-has-point : ffi (extern value value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-has-point (unsafe-ffi-primitive 'js-jsx-foreignobject-has-point))

;; js-jsx-foreignobject-set-size : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-set-size (unsafe-ffi-primitive 'js-jsx-foreignobject-set-size))

;; js-jsx-foreignobject-update : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-update (unsafe-ffi-primitive 'js-jsx-foreignobject-update))

;; js-jsx-foreignobject-update-renderer : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-update-renderer (unsafe-ffi-primitive 'js-jsx-foreignobject-update-renderer))

;; js-jsx-foreignobject-update-size : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-update-size (unsafe-ffi-primitive 'js-jsx-foreignobject-update-size))

;; js-jsx-foreignobject-update-span : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-foreignobject-update-span (unsafe-ffi-primitive 'js-jsx-foreignobject-update-span))

;; js-jsx-tapemeasure-Value : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-tapemeasure-Value (unsafe-ffi-primitive 'js-jsx-tapemeasure-Value))

;; js-jsx-board-update! : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update! (unsafe-ffi-primitive 'js-jsx-board-update!))

;; js-jsx-board-full-update! : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-full-update! (unsafe-ffi-primitive 'js-jsx-board-full-update!))

;; js-jsx-board-remove-object! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-object! (unsafe-ffi-primitive 'js-jsx-board-remove-object!))

;; js-jsx-board-suspend-update! : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-suspend-update! (unsafe-ffi-primitive 'js-jsx-board-suspend-update!))

;; js-jsx-board-unsuspend-update! : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-unsuspend-update! (unsafe-ffi-primitive 'js-jsx-board-unsuspend-update!))

;; js-jsx-board-add-grid! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-grid! (unsafe-ffi-primitive 'js-jsx-board-add-grid!))

;; js-jsx-board-add-hook! : ffi (extern value value extern) -> (value)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-hook! (unsafe-ffi-primitive 'js-jsx-board-add-hook!))

;; js-jsx-board-add-keyboard-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-keyboard-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-keyboard-event-handlers!))

;; js-jsx-board-add-mouse-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-mouse-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-mouse-event-handlers!))

;; js-jsx-board-add-pointer-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-pointer-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-pointer-event-handlers!))

;; js-jsx-board-add-resize-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-resize-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-resize-event-handlers!))

;; js-jsx-board-add-touch-event-handlers! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-touch-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-touch-event-handlers!))

;; js-jsx-board-add-wheel-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-wheel-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-wheel-event-handlers!))

;; js-jsx-board-add-fullscreen-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-fullscreen-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-fullscreen-event-handlers!))

;; js-jsx-board-add-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-add-event-handlers!))

;; js-jsx-board-on : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-on (unsafe-ffi-primitive 'js-jsx-board-on))

;; js-jsx-board-add-child! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-child! (unsafe-ffi-primitive 'js-jsx-board-add-child!))

;; js-jsx-board-get-mouse-position : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-mouse-position (unsafe-ffi-primitive 'js-jsx-board-get-mouse-position))

;; js-jsx-board-get-mouse-position/index : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-mouse-position/index (unsafe-ffi-primitive 'js-jsx-board-get-mouse-position/index))

;; js-jsx-board-get-usr-coords-of-mouse : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-usr-coords-of-mouse (unsafe-ffi-primitive 'js-jsx-board-get-usr-coords-of-mouse))

;; js-jsx-board-get-coords-top-left-corner : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-coords-top-left-corner (unsafe-ffi-primitive 'js-jsx-board-get-coords-top-left-corner))

;; js-jsx-board-get-bounding-box : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-bounding-box (unsafe-ffi-primitive 'js-jsx-board-get-bounding-box))

;; js-jsx-board-get-scr-coords-of-mouse : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-scr-coords-of-mouse (unsafe-ffi-primitive 'js-jsx-board-get-scr-coords-of-mouse))

;; js-jsx-board-get-all-objects-under-mouse : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-all-objects-under-mouse (unsafe-ffi-primitive 'js-jsx-board-get-all-objects-under-mouse))

;; js-jsx-board-get-all-under-mouse : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-get-all-under-mouse (unsafe-ffi-primitive 'js-jsx-board-get-all-under-mouse))

;; js-jsx-board-has-point! : ffi (extern value value) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-has-point! (unsafe-ffi-primitive 'js-jsx-board-has-point!))

;; js-jsx-board-add-animation! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-animation! (unsafe-ffi-primitive 'js-jsx-board-add-animation!))

;; js-jsx-board-add-conditions! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-add-conditions! (unsafe-ffi-primitive 'js-jsx-board-add-conditions!))

;; js-jsx-board-apply-zoom! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-apply-zoom! (unsafe-ffi-primitive 'js-jsx-board-apply-zoom!))

;; js-jsx-board-calculate-snap-sizes! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-calculate-snap-sizes! (unsafe-ffi-primitive 'js-jsx-board-calculate-snap-sizes!))

;; js-jsx-board-create-roulette! : ffi (extern value value value value value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-create-roulette! (unsafe-ffi-primitive 'js-jsx-board-create-roulette!))

;; js-jsx-board-highlight-custom-infobox! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-highlight-custom-infobox! (unsafe-ffi-primitive 'js-jsx-board-highlight-custom-infobox!))

;; js-jsx-board-highlight-custom-infobox/element! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-highlight-custom-infobox/element! (unsafe-ffi-primitive 'js-jsx-board-highlight-custom-infobox/element!))

;; js-jsx-board-highlight-infobox! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-highlight-infobox! (unsafe-ffi-primitive 'js-jsx-board-highlight-infobox!))

;; js-jsx-board-highlight-infobox/element! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-highlight-infobox/element! (unsafe-ffi-primitive 'js-jsx-board-highlight-infobox/element!))

;; js-jsx-board-move-object! : ffi (extern value value value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-move-object! (unsafe-ffi-primitive 'js-jsx-board-move-object!))

;; js-jsx-board-move-origin! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-move-origin! (unsafe-ffi-primitive 'js-jsx-board-move-origin!))

;; js-jsx-board-finalize-adding! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-finalize-adding! (unsafe-ffi-primitive 'js-jsx-board-finalize-adding!))

;; js-jsx-board-set-attribute! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-set-attribute! (unsafe-ffi-primitive 'js-jsx-board-set-attribute!))

;; js-jsx-board-set-bounding-box! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-set-bounding-box! (unsafe-ffi-primitive 'js-jsx-board-set-bounding-box!))

;; js-jsx-board-set-zoom! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-set-zoom! (unsafe-ffi-primitive 'js-jsx-board-set-zoom!))

;; js-jsx-board-resize-container! : ffi (extern value value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-resize-container! (unsafe-ffi-primitive 'js-jsx-board-resize-container!))

;; js-jsx-board-remove-grids! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-grids! (unsafe-ffi-primitive 'js-jsx-board-remove-grids!))

;; js-jsx-board-remove-hook! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-hook! (unsafe-ffi-primitive 'js-jsx-board-remove-hook!))

;; js-jsx-board-off : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-off (unsafe-ffi-primitive 'js-jsx-board-off))

;; js-jsx-board-remove-keyboard-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-keyboard-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-remove-keyboard-event-handlers!))

;; js-jsx-board-remove-mouse-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-mouse-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-remove-mouse-event-handlers!))

;; js-jsx-board-remove-pointer-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-pointer-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-remove-pointer-event-handlers!))

;; js-jsx-board-remove-resize-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-resize-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-remove-resize-event-handlers!))

;; js-jsx-board-remove-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-remove-event-handlers!))

;; js-jsx-board-remove-touch-event-handlers! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-remove-touch-event-handlers! (unsafe-ffi-primitive 'js-jsx-board-remove-touch-event-handlers!))

;; js-jsx-board-select : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-select (unsafe-ffi-primitive 'js-jsx-board-select))

;; js-jsx-board-zoom100! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-zoom100! (unsafe-ffi-primitive 'js-jsx-board-zoom100!))

;; js-jsx-board-zoom-all-points! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-zoom-all-points! (unsafe-ffi-primitive 'js-jsx-board-zoom-all-points!))

;; js-jsx-board-zoom-in! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-zoom-in! (unsafe-ffi-primitive 'js-jsx-board-zoom-in!))

;; js-jsx-board-zoom-out! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-zoom-out! (unsafe-ffi-primitive 'js-jsx-board-zoom-out!))

;; js-jsx-board-start-selection-mode! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-start-selection-mode! (unsafe-ffi-primitive 'js-jsx-board-start-selection-mode!))

;; js-jsx-board-stop-selection-mode! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-stop-selection-mode! (unsafe-ffi-primitive 'js-jsx-board-stop-selection-mode!))

;; js-jsx-board-stop-all-animation! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-stop-all-animation! (unsafe-ffi-primitive 'js-jsx-board-stop-all-animation!))

;; js-jsx-board-clear-traces! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-clear-traces! (unsafe-ffi-primitive 'js-jsx-board-clear-traces!))

;; js-jsx-board-dehighlight-all! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-dehighlight-all! (unsafe-ffi-primitive 'js-jsx-board-dehighlight-all!))

;; js-jsx-board-update-coords! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-coords! (unsafe-ffi-primitive 'js-jsx-board-update-coords!))

;; js-jsx-board-update-container-dims! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-container-dims! (unsafe-ffi-primitive 'js-jsx-board-update-container-dims!))

;; js-jsx-board-update-container-dims/size! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-container-dims/size! (unsafe-ffi-primitive 'js-jsx-board-update-container-dims/size!))

;; js-jsx-board-update-csstransforms! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-csstransforms! (unsafe-ffi-primitive 'js-jsx-board-update-csstransforms!))

;; js-jsx-board-update-elements! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-elements! (unsafe-ffi-primitive 'js-jsx-board-update-elements!))

;; js-jsx-board-update-hooks! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-hooks! (unsafe-ffi-primitive 'js-jsx-board-update-hooks!))

;; js-jsx-board-update-conditions! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-conditions! (unsafe-ffi-primitive 'js-jsx-board-update-conditions!))

;; js-jsx-board-suppress-default! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-suppress-default! (unsafe-ffi-primitive 'js-jsx-board-suppress-default!))

;; js-jsx-board-init-infobox! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-init-infobox! (unsafe-ffi-primitive 'js-jsx-board-init-infobox!))

;; js-jsx-board-init-move-object! : ffi (extern value value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-init-move-object! (unsafe-ffi-primitive 'js-jsx-board-init-move-object!))

;; js-jsx-board-init-move-origin! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-init-move-origin! (unsafe-ffi-primitive 'js-jsx-board-init-move-origin!))

;; js-jsx-board-show-dependencies! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-show-dependencies! (unsafe-ffi-primitive 'js-jsx-board-show-dependencies!))

;; js-jsx-board-generate-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-generate-id (unsafe-ffi-primitive 'js-jsx-board-generate-id))

;; js-jsx-board-generate-name : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-generate-name (unsafe-ffi-primitive 'js-jsx-board-generate-name))

;; js-jsx-board-init-geonext-board! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-init-geonext-board! (unsafe-ffi-primitive 'js-jsx-board-init-geonext-board!))

;; js-jsx-board-show-xml! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-show-xml! (unsafe-ffi-primitive 'js-jsx-board-show-xml!))

;; js-jsx-board-to-fullscreen! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-to-fullscreen! (unsafe-ffi-primitive 'js-jsx-board-to-fullscreen!))

;; js-jsx-board-start-resize-observer! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-start-resize-observer! (unsafe-ffi-primitive 'js-jsx-board-start-resize-observer!))

;; js-jsx-board-stop-resize-observer! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-stop-resize-observer! (unsafe-ffi-primitive 'js-jsx-board-stop-resize-observer!))

;; js-jsx-board-start-intersection-observer! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-start-intersection-observer! (unsafe-ffi-primitive 'js-jsx-board-start-intersection-observer!))

;; js-jsx-board-stop-intersection-observer! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-stop-intersection-observer! (unsafe-ffi-primitive 'js-jsx-board-stop-intersection-observer!))

;; js-jsx-board-update-infobox! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-infobox! (unsafe-ffi-primitive 'js-jsx-board-update-infobox!))

;; js-jsx-board-set-id : ffi (extern extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-set-id (unsafe-ffi-primitive 'js-jsx-board-set-id))

;; js-jsx-board-update-renderer! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-renderer! (unsafe-ffi-primitive 'js-jsx-board-update-renderer!))

;; js-jsx-board-update-renderer-canvas! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-update-renderer-canvas! (unsafe-ffi-primitive 'js-jsx-board-update-renderer-canvas!))

;; js-jsx-board-zoom-elements! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-board-zoom-elements! (unsafe-ffi-primitive 'js-jsx-board-zoom-elements!))

;; js-jsx-element-call : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-element-call (unsafe-ffi-primitive 'js-jsx-element-call))

;; js-jsx-element-call/nullish : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-element-call/nullish (unsafe-ffi-primitive 'js-jsx-element-call/nullish))

;; js-jsx-element-add-event : ffi (extern string/symbol value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-element-add-event (unsafe-ffi-primitive 'js-jsx-element-add-event))

;; js-jsx-line-call : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-line-call (unsafe-ffi-primitive 'js-jsx-line-call))

;; js-jsx-line-call/nullish : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-line-call/nullish (unsafe-ffi-primitive 'js-jsx-line-call/nullish))

;; js-jsx-arc-get-radius : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-arc-get-radius (unsafe-ffi-primitive 'js-jsx-arc-get-radius))

;; js-jsx-arc-has-point-sector : ffi (extern f64 f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-arc-has-point-sector (unsafe-ffi-primitive 'js-jsx-arc-has-point-sector))

;; js-jsx-arc-radius : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-arc-radius (unsafe-ffi-primitive 'js-jsx-arc-radius))

;; js-jsx-arc-value : ffi (extern value value) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-arc-value (unsafe-ffi-primitive 'js-jsx-arc-value))

;; js-jsx-angle-free : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-angle-free (unsafe-ffi-primitive 'js-jsx-angle-free))

;; js-jsx-angle-set-angle! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-angle-set-angle! (unsafe-ffi-primitive 'js-jsx-angle-set-angle!))

;; js-jsx-angle-value : ffi (extern value) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-angle-value (unsafe-ffi-primitive 'js-jsx-angle-value))

;; js-jsx-sector-area : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-area (unsafe-ffi-primitive 'js-jsx-sector-area))

;; js-jsx-sector-has-point-sector : ffi (extern f64 f64) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-has-point-sector (unsafe-ffi-primitive 'js-jsx-sector-has-point-sector))

;; js-jsx-sector-l : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-l (unsafe-ffi-primitive 'js-jsx-sector-l))

;; js-jsx-sector-perimeter : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-perimeter (unsafe-ffi-primitive 'js-jsx-sector-perimeter))

;; js-jsx-sector-radius : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-radius (unsafe-ffi-primitive 'js-jsx-sector-radius))

;; js-jsx-sector-set-position-directly! : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-set-position-directly! (unsafe-ffi-primitive 'js-jsx-sector-set-position-directly!))

;; js-jsx-sector-set-radius! : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-sector-set-radius! (unsafe-ffi-primitive 'js-jsx-sector-set-radius!))

;; js-jsx-glider-start-animation! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-glider-start-animation! (unsafe-ffi-primitive 'js-jsx-glider-start-animation!))

;; js-jsx-glider-stop-animation! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-glider-stop-animation! (unsafe-ffi-primitive 'js-jsx-glider-stop-animation!))

;; js-jsx-circle-call : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-circle-call (unsafe-ffi-primitive 'js-jsx-circle-call))

;; js-jsx-circle-call/nullish : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-circle-call/nullish (unsafe-ffi-primitive 'js-jsx-circle-call/nullish))

;; js-jsx-curve-call : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-curve-call (unsafe-ffi-primitive 'js-jsx-curve-call))

;; js-jsx-curve-call/nullish : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-curve-call/nullish (unsafe-ffi-primitive 'js-jsx-curve-call/nullish))

;; js-jsx-riemannsum-Value : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-riemannsum-Value (unsafe-ffi-primitive 'js-jsx-riemannsum-Value))

;; js-jsx-slopefield-setF : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-slopefield-setF (unsafe-ffi-primitive 'js-jsx-slopefield-setF))

;; js-jsx-vectorfield-setF : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-vectorfield-setF (unsafe-ffi-primitive 'js-jsx-vectorfield-setF))

;; js-jsx-polygon-call : ffi (extern string/symbol value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-polygon-call (unsafe-ffi-primitive 'js-jsx-polygon-call))

;; js-jsx-polygon-call/nullish : ffi (extern string/symbol value) -> (extern)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-polygon-call/nullish (unsafe-ffi-primitive 'js-jsx-polygon-call/nullish))

;; js-jsx-point? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point? (unsafe-ffi-primitive 'js-jsx-point?))

;; js-jsx-point-attractor-distance : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-attractor-distance (unsafe-ffi-primitive 'js-jsx-point-attractor-distance))

;; js-jsx-set-point-attractor-distance! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-attractor-distance! (unsafe-ffi-primitive 'js-jsx-set-point-attractor-distance!))

;; js-jsx-point-attractors : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-attractors (unsafe-ffi-primitive 'js-jsx-point-attractors))

;; js-jsx-set-point-attractors! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-attractors! (unsafe-ffi-primitive 'js-jsx-set-point-attractors!))

;; js-jsx-point-attractor-unit : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-attractor-unit (unsafe-ffi-primitive 'js-jsx-point-attractor-unit))

;; js-jsx-set-point-attractor-unit! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-attractor-unit! (unsafe-ffi-primitive 'js-jsx-set-point-attractor-unit!))

;; js-jsx-point-attract-to-grid : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-attract-to-grid (unsafe-ffi-primitive 'js-jsx-point-attract-to-grid))

;; js-jsx-set-point-attract-to-grid! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-attract-to-grid! (unsafe-ffi-primitive 'js-jsx-set-point-attract-to-grid!))

;; js-jsx-point-face : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-face (unsafe-ffi-primitive 'js-jsx-point-face))

;; js-jsx-set-point-face! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-face! (unsafe-ffi-primitive 'js-jsx-set-point-face!))

;; js-jsx-point-ignored-snap-to-points : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-ignored-snap-to-points (unsafe-ffi-primitive 'js-jsx-point-ignored-snap-to-points))

;; js-jsx-set-point-ignored-snap-to-points! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-ignored-snap-to-points! (unsafe-ffi-primitive 'js-jsx-set-point-ignored-snap-to-points!))

;; js-jsx-point-infobox-digits : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-infobox-digits (unsafe-ffi-primitive 'js-jsx-point-infobox-digits))

;; js-jsx-set-point-infobox-digits! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-infobox-digits! (unsafe-ffi-primitive 'js-jsx-set-point-infobox-digits!))

;; js-jsx-point-show-infobox : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-show-infobox (unsafe-ffi-primitive 'js-jsx-point-show-infobox))

;; js-jsx-set-point-show-infobox! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-show-infobox! (unsafe-ffi-primitive 'js-jsx-set-point-show-infobox!))

;; js-jsx-point-size : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-size (unsafe-ffi-primitive 'js-jsx-point-size))

;; js-jsx-set-point-size! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-size! (unsafe-ffi-primitive 'js-jsx-set-point-size!))

;; js-jsx-point-size-unit : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-size-unit (unsafe-ffi-primitive 'js-jsx-point-size-unit))

;; js-jsx-set-point-size-unit! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-size-unit! (unsafe-ffi-primitive 'js-jsx-set-point-size-unit!))

;; js-jsx-point-snap-size-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-snap-size-x (unsafe-ffi-primitive 'js-jsx-point-snap-size-x))

;; js-jsx-set-point-snap-size-x! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-snap-size-x! (unsafe-ffi-primitive 'js-jsx-set-point-snap-size-x!))

;; js-jsx-point-snap-size-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-snap-size-y (unsafe-ffi-primitive 'js-jsx-point-snap-size-y))

;; js-jsx-set-point-snap-size-y! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-snap-size-y! (unsafe-ffi-primitive 'js-jsx-set-point-snap-size-y!))

;; js-jsx-point-snap-to-grid : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-snap-to-grid (unsafe-ffi-primitive 'js-jsx-point-snap-to-grid))

;; js-jsx-set-point-snap-to-grid! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-snap-to-grid! (unsafe-ffi-primitive 'js-jsx-set-point-snap-to-grid!))

;; js-jsx-point-snap-to-points : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-snap-to-points (unsafe-ffi-primitive 'js-jsx-point-snap-to-points))

;; js-jsx-set-point-snap-to-points! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-snap-to-points! (unsafe-ffi-primitive 'js-jsx-set-point-snap-to-points!))

;; js-jsx-point-snatch-distance : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-snatch-distance (unsafe-ffi-primitive 'js-jsx-point-snatch-distance))

;; js-jsx-set-point-snatch-distance! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-snatch-distance! (unsafe-ffi-primitive 'js-jsx-set-point-snatch-distance!))

;; js-jsx-point-style : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-style (unsafe-ffi-primitive 'js-jsx-point-style))

;; js-jsx-set-point-style! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-style! (unsafe-ffi-primitive 'js-jsx-set-point-style!))

;; js-jsx-point-x : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-x (unsafe-ffi-primitive 'js-jsx-point-x))

;; js-jsx-point-y : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-y (unsafe-ffi-primitive 'js-jsx-point-y))

;; js-jsx-point-zoom : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-zoom (unsafe-ffi-primitive 'js-jsx-point-zoom))

;; js-jsx-set-point-zoom! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-set-point-zoom! (unsafe-ffi-primitive 'js-jsx-set-point-zoom!))

;; js-jsx-point-has-point : ffi (extern f64 f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-has-point (unsafe-ffi-primitive 'js-jsx-point-has-point))

;; js-jsx-point-is-on : ffi (extern extern f64) -> (i32)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-is-on (unsafe-ffi-primitive 'js-jsx-point-is-on))

;; js-jsx-point-make-intersection! : ffi (extern extern extern i32 i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-make-intersection! (unsafe-ffi-primitive 'js-jsx-point-make-intersection!))

;; js-jsx-point-normalize-face : ffi (extern string) -> (string)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-normalize-face (unsafe-ffi-primitive 'js-jsx-point-normalize-face))

;; js-jsx-point-set-style! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-set-style! (unsafe-ffi-primitive 'js-jsx-point-set-style!))

;; js-jsx-point-update! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-update! (unsafe-ffi-primitive 'js-jsx-point-update!))

;; js-jsx-point-update-renderer! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-update-renderer! (unsafe-ffi-primitive 'js-jsx-point-update-renderer!))

;; js-jsx-point-update-transform! : ffi (extern i32) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/jsxgraph.
(define js-jsx-point-update-transform! (unsafe-ffi-primitive 'js-jsx-point-update-transform!))
