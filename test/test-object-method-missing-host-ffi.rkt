#lang webracket/base

;; Browser smoke for optional object methods on DOM-backed FFI values.

(require (only-in webracket/unsafe/dom
                  js-canvas-capture-stream
                  js-canvas-get-context
                  js-canvas-to-blob
                  js-canvas-to-data-url
                  js-canvas-transfer-control-to-offscreen
                  js-canvas2d-create-conic-gradient
                  js-canvas2d-draw-focus-if-needed!
                  js-canvas2d-draw-focus-if-needed-path!
                  js-canvas2d-reset
                  js-canvas2d-reset-transform
                  js-canvas2d-round-rect
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

(js-eval
 "globalThis.__wrObjectMethodBoundaryTargets = [
    [globalThis.__wrObjectMethodCanvas, 'captureStream'],
    [globalThis.__wrObjectMethodCanvas, 'getContext'],
    [globalThis.__wrObjectMethodCanvas, 'toBlob'],
    [globalThis.__wrObjectMethodCanvas, 'toDataURL'],
    [globalThis.__wrObjectMethodCanvas, 'transferControlToOffscreen'],
    [globalThis.__wrObjectMethodCtx, 'createConicGradient'],
    [globalThis.__wrObjectMethodCtx, 'drawFocusIfNeeded'],
    [globalThis.__wrObjectMethodCtx, 'reset'],
    [globalThis.__wrObjectMethodCtx, 'resetTransform'],
    [globalThis.__wrObjectMethodCtx, 'roundRect'],
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

(define conic-gradient-message
  (catch-message
   (lambda ()
     (js-canvas2d-create-conic-gradient ctx 0.0 0.0 0.0))))

(define draw-focus-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-focus-if-needed! ctx canvas))))

(define draw-focus-path-message
  (catch-message
   (lambda ()
     (js-canvas2d-draw-focus-if-needed-path! ctx js-null canvas))))

(define reset-message
  (catch-message
   (lambda ()
     (js-canvas2d-reset ctx))))

(define reset-transform-message
  (catch-message
   (lambda ()
     (js-canvas2d-reset-transform ctx))))

(define round-rect-message
  (catch-message
   (lambda ()
     (js-canvas2d-round-rect ctx 0.0 0.0 1.0 1.0 (void)))))

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
(check-message conic-gradient-message
               "CanvasRenderingContext2D.createConicGradient not available in this environment"
               "missing createConicGradient message")
(check-message draw-focus-message
               "CanvasRenderingContext2D.drawFocusIfNeeded not available in this environment"
               "missing drawFocusIfNeeded message")
(check-message draw-focus-path-message
               "CanvasRenderingContext2D.drawFocusIfNeeded not available in this environment"
               "missing drawFocusIfNeeded path message")
(check-message reset-message
               "CanvasRenderingContext2D.reset not available in this environment"
               "missing reset message")
(check-message reset-transform-message
               "CanvasRenderingContext2D.resetTransform not available in this environment"
               "missing resetTransform message")
(check-message round-rect-message
               "CanvasRenderingContext2D.roundRect not available in this environment"
               "missing roundRect message")
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

(js-log "object-method-missing-host-ffi-ok")
#t
