#lang webracket/base

;; Browser smoke for web-pict host-boundary errors.

(require browser/canvas
         browser/dom
         web-pict)

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-false got label)
  (when got
    (error 'check-false label)))

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
              (format "~a: ~a" label message)))

(js-eval
 "globalThis.__wrWebPictBoundarySaved = {
    Path2D: Object.getOwnPropertyDescriptor(globalThis, 'Path2D'),
    OffscreenCanvas: Object.getOwnPropertyDescriptor(globalThis, 'OffscreenCanvas')
  };
  globalThis.__wrWebPictBoundarySetGlobal = (name, value) => {
    Object.defineProperty(globalThis, name, {
      value,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrWebPictBoundaryHidePath2D = () => {
    globalThis.__wrWebPictBoundarySetGlobal('Path2D', undefined);
  };
  globalThis.__wrWebPictBoundaryInstallNonConstructorPath2D = () => {
    globalThis.__wrWebPictBoundarySetGlobal('Path2D', {});
  };
  globalThis.__wrWebPictBoundaryInstallNonConstructorOffscreenCanvas = () => {
    globalThis.__wrWebPictBoundarySetGlobal('OffscreenCanvas', {});
  };
  globalThis.__wrWebPictBoundaryRestoreGlobal = (name, descriptor) => {
    if (descriptor) {
      Object.defineProperty(globalThis, name, descriptor);
    } else {
      delete globalThis[name];
    }
  };
  globalThis.__wrWebPictBoundaryRestore = () => {
    const saved = globalThis.__wrWebPictBoundarySaved;
    globalThis.__wrWebPictBoundaryRestoreGlobal('Path2D', saved.Path2D);
    globalThis.__wrWebPictBoundaryRestoreGlobal('OffscreenCanvas', saved.OffscreenCanvas);
    delete globalThis.__wrWebPictBoundarySaved;
    delete globalThis.__wrWebPictBoundarySetGlobal;
    delete globalThis.__wrWebPictBoundaryHidePath2D;
    delete globalThis.__wrWebPictBoundaryInstallNonConstructorPath2D;
    delete globalThis.__wrWebPictBoundaryInstallNonConstructorOffscreenCanvas;
    delete globalThis.__wrWebPictBoundaryRestoreGlobal;
    delete globalThis.__wrWebPictBoundaryRestore;
  };")

(define canvas (js-create-element "canvas"))
(canvas-set-width! canvas 32)
(canvas-set-height! canvas 32)
(js-append-child! (js-document-body) canvas)

(define ctx (canvas-2d-context-unwrap (canvas-get-context canvas "2d")))
(define dc (canvas-context->dc ctx))

(define (draw-clipped-pict)
  (draw-pict (clip (filled-rectangle 10 10)) dc 0 0))

(define (draw-alpha-pict)
  (draw-pict (cellophane (filled-rectangle 10 10) 0.5) dc 0 0))

(js-eval "__wrWebPictBoundaryHidePath2D();")
(check-false (js-constructible? (js-var "Path2D"))
             "hidden Path2D is not constructible")
(define missing-path2d-message
  (catch-message draw-clipped-pict))
(js-eval "__wrWebPictBoundaryRestoreGlobal('Path2D', __wrWebPictBoundarySaved.Path2D);")

(js-eval "__wrWebPictBoundaryInstallNonConstructorPath2D();")
(check-false (js-constructible? (js-var "Path2D"))
             "non-constructor Path2D is not constructible")
(define non-constructor-path2d-message
  (catch-message draw-clipped-pict))
(js-eval "__wrWebPictBoundaryRestoreGlobal('Path2D', __wrWebPictBoundarySaved.Path2D);")

(js-eval "__wrWebPictBoundaryInstallNonConstructorOffscreenCanvas();")
(define offscreen-fallback-message
  (catch-message draw-alpha-pict))
(js-eval "__wrWebPictBoundaryRestoreGlobal('OffscreenCanvas', __wrWebPictBoundarySaved.OffscreenCanvas);")

(check-message missing-path2d-message
               "Path2D constructor is not available"
               "missing Path2D constructor message")
(check-message non-constructor-path2d-message
               "Path2D constructor is not available"
               "non-constructible Path2D constructor message")
(check-false offscreen-fallback-message
             "non-constructible OffscreenCanvas falls back to canvas")

(js-eval "__wrWebPictBoundaryRestore();")

(js-log "web-pict-method-missing-host-ffi-ok")
#t
