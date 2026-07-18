#lang webracket/base

;; Browser smoke for public browser/canvas wrapper host-method boundary errors.

(require browser/canvas
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

(define ctx (canvas-2d-context-wrap (js-eval "({})")))
(define source (canvas-wrap (js-eval "({})")))
(define image-data (canvas-image-data-wrap (js-eval "({})")))
(define gradient (canvas-gradient-wrap (js-eval "({})")))
(define pattern (canvas-pattern-wrap (js-eval "({})")))
(define matrix (canvas-dom-matrix-wrap (js-eval "({})")))
(define js-null (js-eval "null"))
(define null-image-data (canvas-image-data-wrap js-null))
(define null-text-metrics (canvas-text-metrics-wrap js-null))
(define null-matrix (canvas-dom-matrix-wrap js-null))

(define fill-message
  (catch-message
   (lambda ()
     (canvas-2d-fill ctx))))

(define create-image-data-message
  (catch-message
   (lambda ()
     (canvas-2d-create-image-data ctx 1 1))))

(define create-image-data-from-message
  (catch-message
   (lambda ()
     (canvas-2d-create-image-data-from ctx image-data))))

(define pattern-message
  (catch-message
   (lambda ()
     (canvas-2d-create-pattern ctx source 'repeat))))

(define conic-gradient-message
  (catch-message
   (lambda ()
     (canvas-2d-create-conic-gradient ctx 0 0 0))))

(define get-image-data-message
  (catch-message
   (lambda ()
     (canvas-2d-get-image-data ctx 0 0 1 1))))

(define linear-gradient-message
  (catch-message
   (lambda ()
     (canvas-2d-create-linear-gradient ctx 0 0 1 1))))

(define radial-gradient-message
  (catch-message
   (lambda ()
     (canvas-2d-create-radial-gradient ctx 0 0 1 1 1 2))))

(define gradient-add-color-stop-message
  (catch-message
   (lambda ()
     (canvas-gradient-add-color-stop! gradient 0 'red))))

(define pattern-set-transform-message
  (catch-message
   (lambda ()
     (canvas-pattern-set-transform! pattern matrix))))

(define canvas-width-message
  (catch-message
   (lambda ()
     (canvas-width source))))

(define canvas-width-setter-message
  (catch-message
   (lambda ()
     (canvas-set-width! source 320))))

(define context-canvas-message
  (catch-message
   (lambda ()
     (canvas-2d-canvas ctx))))

(define context-direction-message
  (catch-message
   (lambda ()
     (canvas-2d-direction ctx))))

(define context-direction-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-direction! ctx 'ltr))))

(define context-fill-style-message
  (catch-message
   (lambda ()
     (canvas-2d-fill-style ctx))))

(define context-fill-style-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-fill-style! ctx 'red))))

(define context-global-alpha-message
  (catch-message
   (lambda ()
     (canvas-2d-global-alpha ctx))))

(define context-image-smoothing-message
  (catch-message
   (lambda ()
     (canvas-2d-image-smoothing-enabled? ctx))))

(define image-data-width-message
  (catch-message
   (lambda ()
     (canvas-image-data-width image-data))))

(define image-data-data-message
  (catch-message
   (lambda ()
     (canvas-image-data-data image-data))))

(define text-metrics-width-message
  (catch-message
   (lambda ()
     (canvas-text-metrics-width (canvas-text-metrics-wrap (js-eval "({})"))))))

(define dom-matrix-a-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-a matrix))))

(define image-data-width-null-message
  (catch-message
   (lambda ()
     (canvas-image-data-width null-image-data))))

(define image-data-data-null-message
  (catch-message
   (lambda ()
     (canvas-image-data-data null-image-data))))

(define text-metrics-width-null-message
  (catch-message
   (lambda ()
     (canvas-text-metrics-width null-text-metrics))))

(define dom-matrix-a-null-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-a null-matrix))))

(check-message fill-message
               "CanvasRenderingContext2D.fill not available in this environment"
               "missing fill message")
(check-message create-image-data-message
               "CanvasRenderingContext2D.createImageData not available in this environment"
               "missing createImageData message")
(check-message create-image-data-from-message
               "CanvasRenderingContext2D.createImageData not available in this environment"
               "missing createImageData copy message")
(check-message pattern-message
               "CanvasRenderingContext2D.createPattern not available in this environment"
               "missing createPattern message")
(check-message conic-gradient-message
               "CanvasRenderingContext2D.createConicGradient not available in this environment"
               "missing createConicGradient message")
(check-message get-image-data-message
               "CanvasRenderingContext2D.getImageData not available in this environment"
               "missing getImageData message")
(check-message linear-gradient-message
               "CanvasRenderingContext2D.createLinearGradient not available in this environment"
               "missing createLinearGradient message")
(check-message radial-gradient-message
               "CanvasRenderingContext2D.createRadialGradient not available in this environment"
               "missing createRadialGradient message")
(check-message gradient-add-color-stop-message
               "CanvasGradient.addColorStop not available in this environment"
               "missing addColorStop message")
(check-message pattern-set-transform-message
               "CanvasPattern.setTransform not available in this environment"
               "missing setTransform message")
(check-message canvas-width-message
               "canvas.width not available in this environment"
               "missing canvas width message")
(check-message canvas-width-setter-message
               "canvas.width not available in this environment"
               "missing canvas width setter message")
(check-message context-canvas-message
               "CanvasRenderingContext2D.canvas not available in this environment"
               "missing context canvas message")
(check-message context-direction-message
               "CanvasRenderingContext2D.direction not available in this environment"
               "missing context direction message")
(check-message context-direction-setter-message
               "CanvasRenderingContext2D.direction not available in this environment"
               "missing context direction setter message")
(check-message context-fill-style-message
               "CanvasRenderingContext2D.fillStyle not available in this environment"
               "missing context fillStyle message")
(check-message context-fill-style-setter-message
               "CanvasRenderingContext2D.fillStyle not available in this environment"
               "missing context fillStyle setter message")
(check-message context-global-alpha-message
               "CanvasRenderingContext2D.globalAlpha not available in this environment"
               "missing context globalAlpha message")
(check-message context-image-smoothing-message
               "CanvasRenderingContext2D.imageSmoothingEnabled not available in this environment"
               "missing context imageSmoothingEnabled message")
(check-message image-data-width-message
               "ImageData.width not available in this environment"
               "missing ImageData.width message")
(check-message image-data-data-message
               "ImageData.data not available in this environment"
               "missing ImageData.data message")
(check-message text-metrics-width-message
               "TextMetrics.width not available in this environment"
               "missing TextMetrics.width message")
(check-message dom-matrix-a-message
               "DOMMatrix.a not available in this environment"
               "missing DOMMatrix.a message")
(check-message image-data-width-null-message
               "ImageData.width: target object is null or undefined"
               "null ImageData.width message")
(check-message image-data-data-null-message
               "ImageData.data: target object is null or undefined"
               "null ImageData.data message")
(check-message text-metrics-width-null-message
               "TextMetrics.width: target object is null or undefined"
               "null TextMetrics.width message")
(check-message dom-matrix-a-null-message
               "DOMMatrix.a: target object is null or undefined"
               "null DOMMatrix.a message")

(js-log "browser-canvas-method-missing-host-ffi-ok")
#t
