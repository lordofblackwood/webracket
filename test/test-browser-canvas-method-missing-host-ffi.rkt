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

(js-log "browser-canvas-method-missing-host-ffi-ok")
#t
