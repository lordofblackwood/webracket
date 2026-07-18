#lang webracket/base

;; Browser smoke for optional object methods on DOM-backed FFI values.

(require (only-in webracket/unsafe/dom
                  js-canvas-capture-stream
                  js-canvas-get-context
                  js-canvas-to-blob
                  js-canvas-to-data-url
                  js-canvas-transfer-control-to-offscreen
                  js-canvas2d-arc
                  js-canvas2d-arc-to
                  js-canvas2d-begin-path
                  js-canvas2d-bezier-curve-to
                  js-canvas2d-clear-rect
                  js-canvas2d-clip
                  js-canvas2d-close-path
                  js-canvas2d-create-conic-gradient
                  js-canvas2d-create-image-data
                  js-canvas2d-create-image-data-from
                  js-canvas2d-create-linear-gradient
                  js-canvas2d-create-pattern
                  js-canvas2d-create-radial-gradient
                  js-canvas2d-draw-focus-if-needed!
                  js-canvas2d-draw-focus-if-needed-path!
                  js-canvas2d-draw-image
                  js-canvas2d-draw-image-5
                  js-canvas2d-draw-image-9
                  js-canvas2d-ellipse
                  js-canvas2d-fill
                  js-canvas2d-fill-rect
                  js-canvas2d-fill-text
                  js-canvas2d-get-image-data
                  js-canvas2d-get-line-dash
                  js-canvas2d-get-transform
                  js-canvas2d-is-point-in-path
                  js-canvas2d-is-point-in-stroke
                  js-canvas2d-line-to
                  js-canvas2d-measure-text
                  js-canvas2d-move-to
                  js-canvas2d-put-image-data
                  js-canvas2d-quadratic-curve-to
                  js-canvas2d-rect
                  js-canvas2d-reset
                  js-canvas2d-reset-transform
                  js-canvas2d-restore
                  js-canvas2d-rotate
                  js-canvas2d-round-rect
                  js-canvas2d-save
                  js-canvas2d-scale
                  js-canvas2d-set-line-dash
                  js-canvas2d-set-transform!
                  js-canvas2d-set-transform-matrix!
                  js-canvas2d-stroke
                  js-canvas2d-stroke-rect
                  js-canvas2d-stroke-text
                  js-canvas2d-transform
                  js-canvas2d-translate
                  js-image-decode
                  js-media-add-text-track!
                  js-media-can-play-type
                  js-media-capture-stream
                  js-media-fast-seek!
                  js-media-load!
                  js-media-pause
                  js-media-play
                  js-media-set-media-keys!
                  js-media-set-sink-id!
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

(js-eval
 "globalThis.__wrObjectMethodCanvas = document.createElement('canvas');
  globalThis.__wrObjectMethodCanvas.width = 4;
  globalThis.__wrObjectMethodCanvas.height = 4;
  globalThis.__wrObjectMethodCtx = globalThis.__wrObjectMethodCanvas.getContext('2d');
  globalThis.__wrObjectMethodMedia = document.createElement('video');
  globalThis.__wrObjectMethodImage = new Image();
  globalThis.__wrObjectMethodCallback = () => {};")

(define canvas (js-eval "globalThis.__wrObjectMethodCanvas"))
(define ctx (js-eval "globalThis.__wrObjectMethodCtx"))
(define media (js-eval "globalThis.__wrObjectMethodMedia"))
(define image (js-eval "globalThis.__wrObjectMethodImage"))
(define callback (js-eval "globalThis.__wrObjectMethodCallback"))
(define js-null (js-eval "null"))
(define empty-array (js-eval "[]"))

(js-eval
 "globalThis.__wrObjectMethodBoundaryTargets = [
    [globalThis.__wrObjectMethodCanvas, 'captureStream'],
    [globalThis.__wrObjectMethodCanvas, 'getContext'],
    [globalThis.__wrObjectMethodCanvas, 'toBlob'],
    [globalThis.__wrObjectMethodCanvas, 'toDataURL'],
    [globalThis.__wrObjectMethodCanvas, 'transferControlToOffscreen'],
    [globalThis.__wrObjectMethodCtx, 'arc'],
    [globalThis.__wrObjectMethodCtx, 'arcTo'],
    [globalThis.__wrObjectMethodCtx, 'beginPath'],
    [globalThis.__wrObjectMethodCtx, 'bezierCurveTo'],
    [globalThis.__wrObjectMethodCtx, 'clearRect'],
    [globalThis.__wrObjectMethodCtx, 'clip'],
    [globalThis.__wrObjectMethodCtx, 'closePath'],
    [globalThis.__wrObjectMethodCtx, 'createConicGradient'],
    [globalThis.__wrObjectMethodCtx, 'createImageData'],
    [globalThis.__wrObjectMethodCtx, 'createLinearGradient'],
    [globalThis.__wrObjectMethodCtx, 'createPattern'],
    [globalThis.__wrObjectMethodCtx, 'createRadialGradient'],
    [globalThis.__wrObjectMethodCtx, 'drawFocusIfNeeded'],
    [globalThis.__wrObjectMethodCtx, 'drawImage'],
    [globalThis.__wrObjectMethodCtx, 'ellipse'],
    [globalThis.__wrObjectMethodCtx, 'fill'],
    [globalThis.__wrObjectMethodCtx, 'fillRect'],
    [globalThis.__wrObjectMethodCtx, 'fillText'],
    [globalThis.__wrObjectMethodCtx, 'getImageData'],
    [globalThis.__wrObjectMethodCtx, 'getLineDash'],
    [globalThis.__wrObjectMethodCtx, 'getTransform'],
    [globalThis.__wrObjectMethodCtx, 'isPointInPath'],
    [globalThis.__wrObjectMethodCtx, 'isPointInStroke'],
    [globalThis.__wrObjectMethodCtx, 'lineTo'],
    [globalThis.__wrObjectMethodCtx, 'measureText'],
    [globalThis.__wrObjectMethodCtx, 'moveTo'],
    [globalThis.__wrObjectMethodCtx, 'putImageData'],
    [globalThis.__wrObjectMethodCtx, 'quadraticCurveTo'],
    [globalThis.__wrObjectMethodCtx, 'rect'],
    [globalThis.__wrObjectMethodCtx, 'reset'],
    [globalThis.__wrObjectMethodCtx, 'resetTransform'],
    [globalThis.__wrObjectMethodCtx, 'restore'],
    [globalThis.__wrObjectMethodCtx, 'rotate'],
    [globalThis.__wrObjectMethodCtx, 'roundRect'],
    [globalThis.__wrObjectMethodCtx, 'save'],
    [globalThis.__wrObjectMethodCtx, 'scale'],
    [globalThis.__wrObjectMethodCtx, 'setLineDash'],
    [globalThis.__wrObjectMethodCtx, 'setTransform'],
    [globalThis.__wrObjectMethodCtx, 'stroke'],
    [globalThis.__wrObjectMethodCtx, 'strokeRect'],
    [globalThis.__wrObjectMethodCtx, 'strokeText'],
    [globalThis.__wrObjectMethodCtx, 'transform'],
    [globalThis.__wrObjectMethodCtx, 'translate'],
    [globalThis.__wrObjectMethodMedia, 'addTextTrack'],
    [globalThis.__wrObjectMethodMedia, 'canPlayType'],
    [globalThis.__wrObjectMethodMedia, 'captureStream'],
    [globalThis.__wrObjectMethodMedia, 'fastSeek'],
    [globalThis.__wrObjectMethodMedia, 'load'],
    [globalThis.__wrObjectMethodMedia, 'pause'],
    [globalThis.__wrObjectMethodMedia, 'play'],
    [globalThis.__wrObjectMethodMedia, 'setMediaKeys'],
    [globalThis.__wrObjectMethodMedia, 'setSinkId'],
    [globalThis.__wrObjectMethodImage, 'decode']
  ];
  globalThis.__wrObjectMethodBoundary = [];
  for (const [obj, name] of globalThis.__wrObjectMethodBoundaryTargets) {
    globalThis.__wrObjectMethodBoundary.push({
      obj,
      name,
      hadOwn: Object.prototype.hasOwnProperty.call(obj, name),
      descriptor: Object.getOwnPropertyDescriptor(obj, name)
    });
    Object.defineProperty(obj, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define canvas-capture-message
  (catch-message
   (lambda ()
     (js-canvas-capture-stream canvas 0.0))))

(define canvas-get-context-message
  (catch-message
   (lambda ()
     (js-canvas-get-context canvas "2d" js-null))))

(define canvas-to-blob-message
  (catch-message
   (lambda ()
     (js-canvas-to-blob canvas callback "image/png" 1.0))))

(define canvas-to-data-url-message
  (catch-message
   (lambda ()
     (js-canvas-to-data-url canvas "image/png" 1.0))))

(define canvas-transfer-message
  (catch-message
   (lambda ()
     (js-canvas-transfer-control-to-offscreen canvas))))

(define arc-message
  (catch-message
   (lambda ()
     (js-canvas2d-arc ctx 0.0 0.0 1.0 0.0 1.0 0))))

(define arc-to-message
  (catch-message
   (lambda ()
     (js-canvas2d-arc-to ctx 0.0 0.0 1.0 1.0 1.0))))

(define begin-path-message
  (catch-message
   (lambda ()
     (js-canvas2d-begin-path ctx))))

(define bezier-curve-to-message
  (catch-message
   (lambda ()
     (js-canvas2d-bezier-curve-to ctx 0.0 0.0 1.0 1.0 2.0 2.0))))

(define clear-rect-message
  (catch-message
   (lambda ()
     (js-canvas2d-clear-rect ctx 0.0 0.0 1.0 1.0))))

(define clip-message
  (catch-message
   (lambda ()
     (js-canvas2d-clip ctx (void) (void)))))

(define close-path-message
  (catch-message
   (lambda ()
     (js-canvas2d-close-path ctx))))

(define conic-gradient-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-conic-gradient ctx 0.0 0.0 0.0))))

(define create-image-data-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-image-data ctx 1.0 1.0))))

(define create-image-data-from-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-image-data-from ctx js-null))))

(define linear-gradient-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-linear-gradient ctx 0.0 0.0 1.0 1.0))))

(define pattern-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-pattern ctx canvas "repeat"))))

(define radial-gradient-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-radial-gradient ctx 0.0 0.0 1.0 1.0 1.0 2.0))))

(define draw-focus-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-focus-if-needed! ctx canvas))))

(define draw-focus-path-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-focus-if-needed-path! ctx js-null canvas))))

(define draw-image-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-image ctx canvas 0.0 0.0))))

(define draw-image-5-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-image-5 ctx canvas 0.0 0.0 1.0 1.0))))

(define draw-image-9-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-image-9 ctx canvas 0.0 0.0 1.0 1.0 0.0 0.0 1.0 1.0))))

(define ellipse-message
  (catch-message
   (lambda ()
     (js-canvas2d-ellipse ctx 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0))))

(define fill-message
  (catch-message
   (lambda ()
     (js-canvas2d-fill ctx (void) (void)))))

(define fill-rect-message
  (catch-message
   (lambda ()
     (js-canvas2d-fill-rect ctx 0.0 0.0 1.0 1.0))))

(define fill-text-message
  (catch-message
   (lambda ()
     (js-canvas2d-fill-text ctx "x" 0.0 0.0 (void)))))

(define get-image-data-message
  (catch-message
   (lambda ()
     (js-canvas2d-get-image-data ctx 0.0 0.0 1.0 1.0 (void)))))

(define get-line-dash-message
  (catch-message
   (lambda ()
     (js-canvas2d-get-line-dash ctx))))

(define get-transform-message
  (catch-message
   (lambda ()
     (js-canvas2d-get-transform ctx))))

(define is-point-in-path-message
  (catch-message
   (lambda ()
     (js-canvas2d-is-point-in-path ctx (void) 0.0 0.0 (void)))))

(define is-point-in-stroke-message
  (catch-message
   (lambda ()
     (js-canvas2d-is-point-in-stroke ctx (void) 0.0 0.0))))

(define line-to-message
  (catch-message
   (lambda ()
     (js-canvas2d-line-to ctx 0.0 0.0))))

(define measure-text-message
  (catch-message
   (lambda ()
     (js-canvas2d-measure-text ctx "x"))))

(define move-to-message
  (catch-message
   (lambda ()
     (js-canvas2d-move-to ctx 0.0 0.0))))

(define put-image-data-message
  (catch-message
   (lambda ()
     (js-canvas2d-put-image-data ctx js-null 0.0 0.0 (void) (void) (void) (void)))))

(define quadratic-curve-to-message
  (catch-message
   (lambda ()
     (js-canvas2d-quadratic-curve-to ctx 0.0 0.0 1.0 1.0))))

(define rect-message
  (catch-message
   (lambda ()
     (js-canvas2d-rect ctx 0.0 0.0 1.0 1.0))))

(define reset-message
  (catch-message
   (lambda ()
     (js-canvas2d-reset ctx))))

(define reset-transform-message
  (catch-message
   (lambda ()
     (js-canvas2d-reset-transform ctx))))

(define restore-message
  (catch-message
   (lambda ()
     (js-canvas2d-restore ctx))))

(define rotate-message
  (catch-message
   (lambda ()
     (js-canvas2d-rotate ctx 0.0))))

(define round-rect-message
  (catch-message
   (lambda ()
     (js-canvas2d-round-rect ctx 0.0 0.0 1.0 1.0 (void)))))

(define save-message
  (catch-message
   (lambda ()
     (js-canvas2d-save ctx))))

(define scale-message
  (catch-message
   (lambda ()
     (js-canvas2d-scale ctx 1.0 1.0))))

(define set-line-dash-message
  (catch-message
   (lambda ()
     (js-canvas2d-set-line-dash ctx empty-array))))

(define set-transform-message
  (catch-message
   (lambda ()
     (js-canvas2d-set-transform! ctx 1.0 0.0 0.0 1.0 0.0 0.0))))

(define set-transform-matrix-message
  (catch-message
   (lambda ()
     (js-canvas2d-set-transform-matrix! ctx js-null))))

(define stroke-message
  (catch-message
   (lambda ()
     (js-canvas2d-stroke ctx (void)))))

(define stroke-rect-message
  (catch-message
   (lambda ()
     (js-canvas2d-stroke-rect ctx 0.0 0.0 1.0 1.0))))

(define stroke-text-message
  (catch-message
   (lambda ()
     (js-canvas2d-stroke-text ctx "x" 0.0 0.0 (void)))))

(define transform-message
  (catch-message
   (lambda ()
     (js-canvas2d-transform ctx 1.0 0.0 0.0 1.0 0.0 0.0))))

(define translate-message
  (catch-message
   (lambda ()
     (js-canvas2d-translate ctx 0.0 0.0))))

(define media-add-text-track-message
  (catch-message
   (lambda ()
     (js-media-add-text-track! media "subtitles" (void) (void)))))

(define media-can-play-type-message
  (catch-message
   (lambda ()
     (js-media-can-play-type media "audio/ogg"))))

(define media-capture-message
  (catch-message
   (lambda ()
     (js-media-capture-stream media (void)))))

(define media-fast-seek-message
  (catch-message
   (lambda ()
     (js-media-fast-seek! media 0.0))))

(define media-load-message
  (catch-message
   (lambda ()
     (js-media-load! media))))

(define media-pause-message
  (catch-message
   (lambda ()
     (js-media-pause media))))

(define media-play-message
  (catch-message
   (lambda ()
     (js-media-play media))))

(define media-set-media-keys-message
  (catch-message
   (lambda ()
     (js-media-set-media-keys! media js-null))))

(define media-set-sink-id-message
  (catch-message
   (lambda ()
     (js-media-set-sink-id! media ""))))

(define image-decode-message
  (catch-message
   (lambda ()
     (js-image-decode image))))

(define null-canvas-message
  (catch-message
   (lambda ()
     (js-canvas-get-context js-null "2d" js-null))))

(define null-canvas2d-message
  (catch-message
   (lambda ()
     (js-canvas2d-fill js-null (void) (void)))))

(define null-media-message
  (catch-message
   (lambda ()
     (js-media-play js-null))))

(define null-image-message
  (catch-message
   (lambda ()
     (js-image-decode js-null))))

(js-eval
 "for (const saved of globalThis.__wrObjectMethodBoundary) {
    if (saved.hadOwn) {
      Object.defineProperty(saved.obj, saved.name, saved.descriptor);
    } else {
      delete saved.obj[saved.name];
    }
  }
  delete globalThis.__wrObjectMethodBoundary;
  delete globalThis.__wrObjectMethodBoundaryTargets;
  delete globalThis.__wrObjectMethodCanvas;
  delete globalThis.__wrObjectMethodCtx;
  delete globalThis.__wrObjectMethodMedia;
  delete globalThis.__wrObjectMethodImage;
  delete globalThis.__wrObjectMethodCallback;")

(check-message canvas-capture-message
               "canvas.captureStream not available in this environment"
               "missing canvas.captureStream message")
(check-message canvas-get-context-message
               "canvas.getContext not available in this environment"
               "missing canvas.getContext message")
(check-message canvas-to-blob-message
               "canvas.toBlob not available in this environment"
               "missing canvas.toBlob message")
(check-message canvas-to-data-url-message
               "canvas.toDataURL not available in this environment"
               "missing canvas.toDataURL message")
(check-message canvas-transfer-message
               "canvas.transferControlToOffscreen not available in this environment"
               "missing canvas.transferControlToOffscreen message")
(check-message arc-message
               "CanvasRenderingContext2D.arc not available in this environment"
               "missing arc message")
(check-message arc-to-message
               "CanvasRenderingContext2D.arcTo not available in this environment"
               "missing arcTo message")
(check-message begin-path-message
               "CanvasRenderingContext2D.beginPath not available in this environment"
               "missing beginPath message")
(check-message bezier-curve-to-message
               "CanvasRenderingContext2D.bezierCurveTo not available in this environment"
               "missing bezierCurveTo message")
(check-message clear-rect-message
               "CanvasRenderingContext2D.clearRect not available in this environment"
               "missing clearRect message")
(check-message clip-message
               "CanvasRenderingContext2D.clip not available in this environment"
               "missing clip message")
(check-message close-path-message
               "CanvasRenderingContext2D.closePath not available in this environment"
               "missing closePath message")
(check-message conic-gradient-message
               "CanvasRenderingContext2D.createConicGradient not available in this environment"
               "missing createConicGradient message")
(check-message create-image-data-message
               "CanvasRenderingContext2D.createImageData not available in this environment"
               "missing createImageData message")
(check-message create-image-data-from-message
               "CanvasRenderingContext2D.createImageData not available in this environment"
               "missing createImageData copy message")
(check-message linear-gradient-message
               "CanvasRenderingContext2D.createLinearGradient not available in this environment"
               "missing createLinearGradient message")
(check-message pattern-message
               "CanvasRenderingContext2D.createPattern not available in this environment"
               "missing createPattern message")
(check-message radial-gradient-message
               "CanvasRenderingContext2D.createRadialGradient not available in this environment"
               "missing createRadialGradient message")
(check-message draw-focus-message
               "CanvasRenderingContext2D.drawFocusIfNeeded not available in this environment"
               "missing drawFocusIfNeeded message")
(check-message draw-focus-path-message
               "CanvasRenderingContext2D.drawFocusIfNeeded not available in this environment"
               "missing drawFocusIfNeeded path message")
(check-message draw-image-message
               "CanvasRenderingContext2D.drawImage not available in this environment"
               "missing drawImage message")
(check-message draw-image-5-message
               "CanvasRenderingContext2D.drawImage not available in this environment"
               "missing drawImage 5 message")
(check-message draw-image-9-message
               "CanvasRenderingContext2D.drawImage not available in this environment"
               "missing drawImage 9 message")
(check-message ellipse-message
               "CanvasRenderingContext2D.ellipse not available in this environment"
               "missing ellipse message")
(check-message fill-message
               "CanvasRenderingContext2D.fill not available in this environment"
               "missing fill message")
(check-message fill-rect-message
               "CanvasRenderingContext2D.fillRect not available in this environment"
               "missing fillRect message")
(check-message fill-text-message
               "CanvasRenderingContext2D.fillText not available in this environment"
               "missing fillText message")
(check-message get-image-data-message
               "CanvasRenderingContext2D.getImageData not available in this environment"
               "missing getImageData message")
(check-message get-line-dash-message
               "CanvasRenderingContext2D.getLineDash not available in this environment"
               "missing getLineDash message")
(check-message get-transform-message
               "CanvasRenderingContext2D.getTransform not available in this environment"
               "missing getTransform message")
(check-message is-point-in-path-message
               "CanvasRenderingContext2D.isPointInPath not available in this environment"
               "missing isPointInPath message")
(check-message is-point-in-stroke-message
               "CanvasRenderingContext2D.isPointInStroke not available in this environment"
               "missing isPointInStroke message")
(check-message line-to-message
               "CanvasRenderingContext2D.lineTo not available in this environment"
               "missing lineTo message")
(check-message measure-text-message
               "CanvasRenderingContext2D.measureText not available in this environment"
               "missing measureText message")
(check-message move-to-message
               "CanvasRenderingContext2D.moveTo not available in this environment"
               "missing moveTo message")
(check-message put-image-data-message
               "CanvasRenderingContext2D.putImageData not available in this environment"
               "missing putImageData message")
(check-message quadratic-curve-to-message
               "CanvasRenderingContext2D.quadraticCurveTo not available in this environment"
               "missing quadraticCurveTo message")
(check-message rect-message
               "CanvasRenderingContext2D.rect not available in this environment"
               "missing rect message")
(check-message reset-message
               "CanvasRenderingContext2D.reset not available in this environment"
               "missing reset message")
(check-message reset-transform-message
               "CanvasRenderingContext2D.resetTransform not available in this environment"
               "missing resetTransform message")
(check-message restore-message
               "CanvasRenderingContext2D.restore not available in this environment"
               "missing restore message")
(check-message rotate-message
               "CanvasRenderingContext2D.rotate not available in this environment"
               "missing rotate message")
(check-message round-rect-message
               "CanvasRenderingContext2D.roundRect not available in this environment"
               "missing roundRect message")
(check-message save-message
               "CanvasRenderingContext2D.save not available in this environment"
               "missing save message")
(check-message scale-message
               "CanvasRenderingContext2D.scale not available in this environment"
               "missing scale message")
(check-message set-line-dash-message
               "CanvasRenderingContext2D.setLineDash not available in this environment"
               "missing setLineDash message")
(check-message set-transform-message
               "CanvasRenderingContext2D.setTransform not available in this environment"
               "missing setTransform message")
(check-message set-transform-matrix-message
               "CanvasRenderingContext2D.setTransform not available in this environment"
               "missing setTransform matrix message")
(check-message stroke-message
               "CanvasRenderingContext2D.stroke not available in this environment"
               "missing stroke message")
(check-message stroke-rect-message
               "CanvasRenderingContext2D.strokeRect not available in this environment"
               "missing strokeRect message")
(check-message stroke-text-message
               "CanvasRenderingContext2D.strokeText not available in this environment"
               "missing strokeText message")
(check-message transform-message
               "CanvasRenderingContext2D.transform not available in this environment"
               "missing transform message")
(check-message translate-message
               "CanvasRenderingContext2D.translate not available in this environment"
               "missing translate message")
(check-message media-add-text-track-message
               "HTMLMediaElement.addTextTrack not available in this environment"
               "missing addTextTrack message")
(check-message media-can-play-type-message
               "HTMLMediaElement.canPlayType not available in this environment"
               "missing canPlayType message")
(check-message media-capture-message
               "HTMLMediaElement.captureStream not available in this environment"
               "missing media captureStream message")
(check-message media-fast-seek-message
               "HTMLMediaElement.fastSeek not available in this environment"
               "missing fastSeek message")
(check-message media-load-message
               "HTMLMediaElement.load not available in this environment"
               "missing load message")
(check-message media-pause-message
               "HTMLMediaElement.pause not available in this environment"
               "missing pause message")
(check-message media-play-message
               "HTMLMediaElement.play not available in this environment"
               "missing play message")
(check-message media-set-media-keys-message
               "HTMLMediaElement.setMediaKeys not available in this environment"
               "missing setMediaKeys message")
(check-message media-set-sink-id-message
               "HTMLMediaElement.setSinkId not available in this environment"
               "missing setSinkId message")
(check-message image-decode-message
               "HTMLImageElement.decode not available in this environment"
               "missing image decode message")
(check-message null-canvas-message
               "canvas.getContext: target object is null or undefined"
               "missing null canvas target message")
(check-message null-canvas2d-message
               "CanvasRenderingContext2D.fill: target object is null or undefined"
               "missing null canvas2d target message")
(check-message null-media-message
               "HTMLMediaElement.play: target object is null or undefined"
               "missing null media target message")
(check-message null-image-message
               "HTMLImageElement.decode: target object is null or undefined"
               "missing null image target message")

(js-log "object-method-missing-host-ffi-ok")
#t
