#lang webracket/base

;; Browser smoke for public browser/canvas wrapper host-method boundary errors.

(require browser/canvas
         (only-in webracket/unsafe/standard
                  js-eval))

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
              label))

(define ctx (canvas-2d-context-wrap (js-eval "({})")))
(define source (canvas-wrap (js-eval "({})")))
(define sample-image-data (canvas-image-data-wrap (js-eval "({})")))
(define gradient (canvas-gradient-wrap (js-eval "({})")))
(define pattern (canvas-pattern-wrap (js-eval "({})")))
(define matrix (canvas-dom-matrix-wrap (js-eval "({})")))
(define js-null (js-eval "null"))
(define js-undefined (js-eval "undefined"))
(define null-canvas (canvas-wrap js-null))
(define null-ctx (canvas-2d-context-wrap js-null))
(define null-image-data (canvas-image-data-wrap js-null))
(define null-gradient (canvas-gradient-wrap js-null))
(define null-pattern (canvas-pattern-wrap js-null))
(define null-text-metrics (canvas-text-metrics-wrap js-null))
(define null-matrix (canvas-dom-matrix-wrap js-null))
(define null-offscreen-canvas (offscreen-canvas-wrap js-null))
(define undefined-canvas (canvas-wrap js-undefined))
(define undefined-ctx (canvas-2d-context-wrap js-undefined))
(define undefined-image-data (canvas-image-data-wrap js-undefined))
(define undefined-gradient (canvas-gradient-wrap js-undefined))
(define undefined-pattern (canvas-pattern-wrap js-undefined))
(define undefined-text-metrics (canvas-text-metrics-wrap js-undefined))
(define undefined-matrix (canvas-dom-matrix-wrap js-undefined))
(define undefined-offscreen-canvas (offscreen-canvas-wrap js-undefined))
(define non-callable-gradient-style-message
  (catch-message
   (lambda ()
     (canvas-2d-fill-style
      (canvas-2d-context-wrap (js-eval "({fillStyle: {addColorStop: 1}})"))))))
(define non-callable-pattern-style-message
  (catch-message
   (lambda ()
     (canvas-2d-stroke-style
      (canvas-2d-context-wrap (js-eval "({strokeStyle: {setTransform: 1}})"))))))
(define valid-pattern
  (canvas-pattern-wrap (js-eval "({setTransform: function (matrix) { this.matrix = matrix; }})")))
(define forged-null-source (html-canvas-element js-null))
(define forged-undefined-image-data (image-data js-undefined))
(define forged-null-offscreen-canvas (offscreen-canvas js-null))
(define forged-null-gradient (canvas-gradient js-null))
(define forged-undefined-pattern (canvas-pattern js-undefined))
(define forged-null-matrix (dom-matrix js-null))

(define complete-canvas
  (canvas-wrap
   (js-eval
    "({ width: 320,
        height: 200,
        getContext(_kind) { return null; },
        toDataURL() { return 'data:'; },
        toBlob(callback) { callback(null); } })")))
(define incomplete-canvas
  (canvas-wrap
   (js-eval
    "({ width: 320,
        height: 200,
        getContext(_kind) { return null; },
        toDataURL() { return 'data:'; } })")))
(define complete-ctx
  (canvas-2d-context-wrap
   (js-eval
    "({ canvas: {},
        direction: 'ltr',
        fillStyle: 'red',
        strokeStyle: 'blue',
        font: '16px sans-serif',
        globalAlpha: 1,
        fillRect() {},
        strokeRect() {},
        beginPath() {},
        closePath() {},
        moveTo() {},
        lineTo() {},
        arc() {},
        clearRect() {},
        fill() {},
        stroke() {},
        save() {},
        restore() {},
        translate() {},
        scale() {},
        rotate() {},
        fillText() {},
        strokeText() {},
        measureText() { return { width: 0 }; } })")))
(define incomplete-ctx
  (canvas-2d-context-wrap
   (js-eval
    "({ canvas: {},
        direction: 'ltr',
        fillStyle: 'red',
        strokeStyle: 'blue',
        font: '16px sans-serif',
        globalAlpha: 1,
        fillRect() {} })")))
(define complete-image-data
  (canvas-image-data-wrap
   (js-eval "({ width: 1, height: 1, data: new Uint8ClampedArray([0, 0, 0, 0]) })")))
(define incomplete-image-data
  (canvas-image-data-wrap
   (js-eval "({ height: 1, data: new Uint8ClampedArray([0, 0, 0, 0]) })")))
(define complete-gradient
  (canvas-gradient-wrap
   (js-eval "({ addColorStop(_offset, _color) {} })")))
(define incomplete-gradient
  (canvas-gradient-wrap
   (js-eval "({ addColorStop: 1 })")))
(define complete-pattern
  (canvas-pattern-wrap
   (js-eval "({ setTransform(_matrix) {} })")))
(define incomplete-pattern
  (canvas-pattern-wrap
   (js-eval "({ setTransform: 1 })")))
(define complete-text-metrics
  (canvas-text-metrics-wrap
   (js-eval "({ width: 12 })")))
(define incomplete-text-metrics
  (canvas-text-metrics-wrap
   (js-eval "({})")))
(define complete-dom-matrix
  (canvas-dom-matrix-wrap
   (js-eval "({ a: 1, b: 0, c: 0, d: 1, e: 0, f: 0 })")))
(define incomplete-dom-matrix
  (canvas-dom-matrix-wrap
   (js-eval "({ b: 0, c: 0, d: 1, e: 0, f: 0 })")))
(define complete-offscreen-canvas
  (offscreen-canvas-wrap
   (js-eval "({ width: 320, height: 200 })")))
(define incomplete-offscreen-canvas
  (offscreen-canvas-wrap
   (js-eval "({ width: 320 })")))

(define bad-context-result-canvas
  (canvas-wrap
   (js-eval
    "({ width: 320,
        height: 200,
        getContext(_kind) { return {}; },
        toDataURL() { return 'data:'; },
        toBlob(callback) { callback(null); } })")))
(define bad-offscreen-result-canvas
  (canvas-wrap
   (js-eval
    "({ width: 320,
        height: 200,
        getContext(_kind) { return null; },
        toDataURL() { return 'data:'; },
        toBlob(callback) { callback(null); },
        transferControlToOffscreen() { return { width: 320 }; } })")))
(define bad-result-ctx
  (canvas-2d-context-wrap
   (js-eval
    "({ canvas: { width: 320 },
        createImageData() { return {}; },
        createPattern() { return {}; },
        createConicGradient() { return {}; },
        getImageData() { return {}; },
        getLineDash() { return 17; },
        getTransform() { return {}; },
        measureText() { return {}; },
        createLinearGradient() { return {}; },
        createRadialGradient() { return {}; },
        fillStyle: { addColorStop: 1 },
        strokeStyle: { setTransform: 1 } })")))
(define bad-array-image-data
  (canvas-image-data-wrap
   (js-eval "({ width: 1, height: 1, data: 17 })")))

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
     (canvas-2d-create-image-data-from ctx sample-image-data))))

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

(define get-context-result-message
  (catch-message
   (lambda ()
     (canvas-get-context bad-context-result-canvas "2d"))))

(define transfer-control-result-message
  (catch-message
   (lambda ()
     (canvas-transfer-control-to-offscreen bad-offscreen-result-canvas))))

(define context-canvas-result-message
  (catch-message
   (lambda ()
     (canvas-2d-canvas bad-result-ctx))))

(define create-image-data-result-message
  (catch-message
   (lambda ()
     (canvas-2d-create-image-data bad-result-ctx 1 1))))

(define create-image-data-from-result-message
  (catch-message
   (lambda ()
     (canvas-2d-create-image-data-from bad-result-ctx complete-image-data))))

(define pattern-result-message
  (catch-message
   (lambda ()
     (canvas-2d-create-pattern bad-result-ctx complete-canvas 'repeat))))

(define conic-gradient-result-message
  (catch-message
   (lambda ()
     (canvas-2d-create-conic-gradient bad-result-ctx 0 0 0))))

(define get-image-data-result-message
  (catch-message
   (lambda ()
     (canvas-2d-get-image-data bad-result-ctx 0 0 1 1))))

(define get-line-dash-result-message
  (catch-message
   (lambda ()
     (canvas-2d-get-line-dash bad-result-ctx))))

(define get-transform-result-message
  (catch-message
   (lambda ()
     (canvas-2d-get-transform bad-result-ctx))))

(define measure-text-result-message
  (catch-message
   (lambda ()
     (canvas-2d-measure-text bad-result-ctx "x"))))

(define linear-gradient-result-message
  (catch-message
   (lambda ()
     (canvas-2d-create-linear-gradient bad-result-ctx 0 0 1 1))))

(define radial-gradient-result-message
  (catch-message
   (lambda ()
     (canvas-2d-create-radial-gradient bad-result-ctx 0 0 1 1 1 2))))

(define image-data-data-result-message
  (catch-message
   (lambda ()
     (canvas-image-data-data bad-array-image-data))))

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

(define canvas-height-message
  (catch-message
   (lambda ()
     (canvas-height source))))

(define canvas-height-setter-message
  (catch-message
   (lambda ()
     (canvas-set-height! source 240))))

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

(define context-filter-message
  (catch-message
   (lambda ()
     (canvas-2d-filter ctx))))

(define context-filter-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-filter! ctx "blur(1px)"))))

(define context-font-message
  (catch-message
   (lambda ()
     (canvas-2d-font ctx))))

(define context-font-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-font! ctx "12px sans-serif"))))

(define context-global-alpha-message
  (catch-message
   (lambda ()
     (canvas-2d-global-alpha ctx))))

(define context-global-alpha-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-global-alpha! ctx 0.5))))

(define context-global-composite-operation-message
  (catch-message
   (lambda ()
     (canvas-2d-global-composite-operation ctx))))

(define context-global-composite-operation-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-global-composite-operation! ctx 'source-over))))

(define context-image-smoothing-message
  (catch-message
   (lambda ()
     (canvas-2d-image-smoothing-enabled? ctx))))

(define context-image-smoothing-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-image-smoothing-enabled! ctx #t))))

(define context-image-smoothing-quality-message
  (catch-message
   (lambda ()
     (canvas-2d-image-smoothing-quality ctx))))

(define context-image-smoothing-quality-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-image-smoothing-quality! ctx 'high))))

(define context-line-cap-message
  (catch-message
   (lambda ()
     (canvas-2d-line-cap ctx))))

(define context-line-cap-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-line-cap! ctx 'round))))

(define context-line-dash-offset-message
  (catch-message
   (lambda ()
     (canvas-2d-line-dash-offset ctx))))

(define context-line-dash-offset-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-line-dash-offset! ctx 1.0))))

(define context-line-join-message
  (catch-message
   (lambda ()
     (canvas-2d-line-join ctx))))

(define context-line-join-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-line-join! ctx 'round))))

(define context-line-width-message
  (catch-message
   (lambda ()
     (canvas-2d-line-width ctx))))

(define context-line-width-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-line-width! ctx 2.0))))

(define context-miter-limit-message
  (catch-message
   (lambda ()
     (canvas-2d-miter-limit ctx))))

(define context-miter-limit-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-miter-limit! ctx 10.0))))

(define context-shadow-blur-message
  (catch-message
   (lambda ()
     (canvas-2d-shadow-blur ctx))))

(define context-shadow-blur-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-shadow-blur! ctx 3.0))))

(define context-shadow-color-message
  (catch-message
   (lambda ()
     (canvas-2d-shadow-color ctx))))

(define context-shadow-color-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-shadow-color! ctx 'black))))

(define context-shadow-offset-x-message
  (catch-message
   (lambda ()
     (canvas-2d-shadow-offset-x ctx))))

(define context-shadow-offset-x-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-shadow-offset-x! ctx 1.0))))

(define context-shadow-offset-y-message
  (catch-message
   (lambda ()
     (canvas-2d-shadow-offset-y ctx))))

(define context-shadow-offset-y-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-shadow-offset-y! ctx 1.0))))

(define context-stroke-style-message
  (catch-message
   (lambda ()
     (canvas-2d-stroke-style ctx))))

(define context-stroke-style-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-stroke-style! ctx 'blue))))

(define context-text-align-message
  (catch-message
   (lambda ()
     (canvas-2d-text-align ctx))))

(define context-text-align-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-text-align! ctx 'center))))

(define context-text-baseline-message
  (catch-message
   (lambda ()
     (canvas-2d-text-baseline ctx))))

(define context-text-baseline-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-text-baseline! ctx 'middle))))

(define context-text-rendering-message
  (catch-message
   (lambda ()
     (canvas-2d-text-rendering ctx))))

(define context-text-rendering-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-text-rendering! ctx 'geometricPrecision))))

(define context-font-kerning-message
  (catch-message
   (lambda ()
     (canvas-2d-font-kerning ctx))))

(define context-font-kerning-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-font-kerning! ctx 'normal))))

(define context-font-stretch-message
  (catch-message
   (lambda ()
     (canvas-2d-font-stretch ctx))))

(define context-font-stretch-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-font-stretch! ctx 'normal))))

(define context-font-variant-caps-message
  (catch-message
   (lambda ()
     (canvas-2d-font-variant-caps ctx))))

(define context-font-variant-caps-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-font-variant-caps! ctx 'normal))))

(define context-font-variant-ligatures-message
  (catch-message
   (lambda ()
     (canvas-2d-font-variant-ligatures ctx))))

(define context-font-variant-ligatures-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-font-variant-ligatures! ctx 'normal))))

(define context-font-variant-numeric-message
  (catch-message
   (lambda ()
     (canvas-2d-font-variant-numeric ctx))))

(define context-font-variant-numeric-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-font-variant-numeric! ctx 'normal))))

(define context-letter-spacing-message
  (catch-message
   (lambda ()
     (canvas-2d-letter-spacing ctx))))

(define context-letter-spacing-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-letter-spacing! ctx "1px"))))

(define context-word-spacing-message
  (catch-message
   (lambda ()
     (canvas-2d-word-spacing ctx))))

(define context-word-spacing-setter-message
  (catch-message
   (lambda ()
     (canvas-2d-set-word-spacing! ctx "1px"))))

(define image-data-width-message
  (catch-message
   (lambda ()
     (canvas-image-data-width sample-image-data))))

(define image-data-height-message
  (catch-message
   (lambda ()
     (canvas-image-data-height sample-image-data))))

(define image-data-data-message
  (catch-message
   (lambda ()
     (canvas-image-data-data sample-image-data))))

(define text-metrics-width-message
  (catch-message
   (lambda ()
     (canvas-text-metrics-width (canvas-text-metrics-wrap (js-eval "({})"))))))

(define dom-matrix-a-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-a matrix))))

(define dom-matrix-b-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-b matrix))))

(define dom-matrix-c-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-c matrix))))

(define dom-matrix-d-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-d matrix))))

(define dom-matrix-e-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-e matrix))))

(define dom-matrix-f-message
  (catch-message
   (lambda ()
     (canvas-dom-matrix-f matrix))))

(define forged-source-message
  (catch-message
   (lambda ()
     (canvas-2d-create-pattern ctx forged-null-source 'repeat))))

(define forged-image-data-message
  (catch-message
   (lambda ()
     (canvas-2d-put-image-data ctx forged-undefined-image-data 0 0))))

(define forged-offscreen-canvas-message
  (catch-message
   (lambda ()
     (canvas-2d-draw-image ctx forged-null-offscreen-canvas 0 0))))

(define forged-gradient-style-message
  (catch-message
   (lambda ()
     (canvas-2d-set-fill-style! ctx forged-null-gradient))))

(define forged-pattern-style-message
  (catch-message
   (lambda ()
     (canvas-2d-set-stroke-style! ctx forged-undefined-pattern))))

(define forged-matrix-message
  (catch-message
   (lambda ()
     (canvas-pattern-set-transform! valid-pattern forged-null-matrix))))

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
(check-message get-context-result-message
               "canvas.getContext result must be CanvasRenderingContext2D-like"
               "bad getContext result message")
(check-message transfer-control-result-message
               "canvas.transferControlToOffscreen result must be OffscreenCanvas-like"
               "bad transferControlToOffscreen result message")
(check-message context-canvas-result-message
               "CanvasRenderingContext2D.canvas result must be HTMLCanvasElement-like"
               "bad context canvas result message")
(check-message create-image-data-result-message
               "CanvasRenderingContext2D.createImageData result must be ImageData-like"
               "bad createImageData result message")
(check-message create-image-data-from-result-message
               "CanvasRenderingContext2D.createImageData result must be ImageData-like"
               "bad createImageData copy result message")
(check-message pattern-result-message
               "CanvasRenderingContext2D.createPattern result must be CanvasPattern-like"
               "bad createPattern result message")
(check-message conic-gradient-result-message
               "CanvasRenderingContext2D.createConicGradient result must be CanvasGradient-like"
               "bad createConicGradient result message")
(check-message get-image-data-result-message
               "CanvasRenderingContext2D.getImageData result must be ImageData-like"
               "bad getImageData result message")
(check-message get-line-dash-result-message
               "CanvasRenderingContext2D.getLineDash result must be array-like"
               "bad getLineDash result message")
(check-message get-transform-result-message
               "CanvasRenderingContext2D.getTransform result must be DOMMatrix-like"
               "bad getTransform result message")
(check-message measure-text-result-message
               "CanvasRenderingContext2D.measureText result must be TextMetrics-like"
               "bad measureText result message")
(check-message linear-gradient-result-message
               "CanvasRenderingContext2D.createLinearGradient result must be CanvasGradient-like"
               "bad createLinearGradient result message")
(check-message radial-gradient-result-message
               "CanvasRenderingContext2D.createRadialGradient result must be CanvasGradient-like"
               "bad createRadialGradient result message")
(check-message image-data-data-result-message
               "ImageData.data result must be array-like"
               "bad ImageData.data result message")
(check-message gradient-add-color-stop-message
               "CanvasGradient.addColorStop not available in this environment"
               "missing addColorStop message")
(check-message pattern-set-transform-message
               "CanvasPattern.setTransform not available in this environment"
               "missing setTransform message")
(check-message non-callable-gradient-style-message
               "CanvasRenderingContext2D.fillStyle result must be a string, CanvasGradient-like, or CanvasPattern-like"
               "bad fillStyle result message")
(check-message non-callable-pattern-style-message
               "CanvasRenderingContext2D.strokeStyle result must be a string, CanvasGradient-like, or CanvasPattern-like"
               "bad strokeStyle result message")
(check-true (html-canvas-element? complete-canvas)
            "complete canvas predicate")
(check-false (html-canvas-element? incomplete-canvas)
             "incomplete canvas predicate")
(check-true (canvas-rendering-context-2d? complete-ctx)
            "complete context predicate")
(check-false (canvas-rendering-context-2d? incomplete-ctx)
             "incomplete context predicate")
(check-true (image-data? complete-image-data)
            "complete ImageData predicate")
(check-false (image-data? incomplete-image-data)
             "incomplete ImageData predicate")
(check-true (canvas-gradient? complete-gradient)
            "complete CanvasGradient predicate")
(check-false (canvas-gradient? incomplete-gradient)
             "incomplete CanvasGradient predicate")
(check-true (canvas-pattern? complete-pattern)
            "complete CanvasPattern predicate")
(check-false (canvas-pattern? incomplete-pattern)
             "incomplete CanvasPattern predicate")
(check-true (text-metrics? complete-text-metrics)
            "complete TextMetrics predicate")
(check-false (text-metrics? incomplete-text-metrics)
             "incomplete TextMetrics predicate")
(check-true (dom-matrix? complete-dom-matrix)
            "complete DOMMatrix predicate")
(check-false (dom-matrix? incomplete-dom-matrix)
             "incomplete DOMMatrix predicate")
(check-true (offscreen-canvas? complete-offscreen-canvas)
            "complete OffscreenCanvas predicate")
(check-false (offscreen-canvas? incomplete-offscreen-canvas)
             "incomplete OffscreenCanvas predicate")
(check-message canvas-width-message
               "canvas.width not available in this environment"
               "missing canvas width message")
(check-message canvas-width-setter-message
               "canvas.width not available in this environment"
               "missing canvas width setter message")
(check-message canvas-height-message
               "canvas.height not available in this environment"
               "missing canvas height message")
(check-message canvas-height-setter-message
               "canvas.height not available in this environment"
               "missing canvas height setter message")
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
(check-message context-filter-message
               "CanvasRenderingContext2D.filter not available in this environment"
               "missing context filter message")
(check-message context-filter-setter-message
               "CanvasRenderingContext2D.filter not available in this environment"
               "missing context filter setter message")
(check-message context-font-message
               "CanvasRenderingContext2D.font not available in this environment"
               "missing context font message")
(check-message context-font-setter-message
               "CanvasRenderingContext2D.font not available in this environment"
               "missing context font setter message")
(check-message context-global-alpha-message
               "CanvasRenderingContext2D.globalAlpha not available in this environment"
               "missing context globalAlpha message")
(check-message context-global-alpha-setter-message
               "CanvasRenderingContext2D.globalAlpha not available in this environment"
               "missing context globalAlpha setter message")
(check-message context-global-composite-operation-message
               "CanvasRenderingContext2D.globalCompositeOperation not available in this environment"
               "missing context globalCompositeOperation message")
(check-message context-global-composite-operation-setter-message
               "CanvasRenderingContext2D.globalCompositeOperation not available in this environment"
               "missing context globalCompositeOperation setter message")
(check-message context-image-smoothing-message
               "CanvasRenderingContext2D.imageSmoothingEnabled not available in this environment"
               "missing context imageSmoothingEnabled message")
(check-message context-image-smoothing-setter-message
               "CanvasRenderingContext2D.imageSmoothingEnabled not available in this environment"
               "missing context imageSmoothingEnabled setter message")
(check-message context-image-smoothing-quality-message
               "CanvasRenderingContext2D.imageSmoothingQuality not available in this environment"
               "missing context imageSmoothingQuality message")
(check-message context-image-smoothing-quality-setter-message
               "CanvasRenderingContext2D.imageSmoothingQuality not available in this environment"
               "missing context imageSmoothingQuality setter message")
(check-message context-line-cap-message
               "CanvasRenderingContext2D.lineCap not available in this environment"
               "missing context lineCap message")
(check-message context-line-cap-setter-message
               "CanvasRenderingContext2D.lineCap not available in this environment"
               "missing context lineCap setter message")
(check-message context-line-dash-offset-message
               "CanvasRenderingContext2D.lineDashOffset not available in this environment"
               "missing context lineDashOffset message")
(check-message context-line-dash-offset-setter-message
               "CanvasRenderingContext2D.lineDashOffset not available in this environment"
               "missing context lineDashOffset setter message")
(check-message context-line-join-message
               "CanvasRenderingContext2D.lineJoin not available in this environment"
               "missing context lineJoin message")
(check-message context-line-join-setter-message
               "CanvasRenderingContext2D.lineJoin not available in this environment"
               "missing context lineJoin setter message")
(check-message context-line-width-message
               "CanvasRenderingContext2D.lineWidth not available in this environment"
               "missing context lineWidth message")
(check-message context-line-width-setter-message
               "CanvasRenderingContext2D.lineWidth not available in this environment"
               "missing context lineWidth setter message")
(check-message context-miter-limit-message
               "CanvasRenderingContext2D.miterLimit not available in this environment"
               "missing context miterLimit message")
(check-message context-miter-limit-setter-message
               "CanvasRenderingContext2D.miterLimit not available in this environment"
               "missing context miterLimit setter message")
(check-message context-shadow-blur-message
               "CanvasRenderingContext2D.shadowBlur not available in this environment"
               "missing context shadowBlur message")
(check-message context-shadow-blur-setter-message
               "CanvasRenderingContext2D.shadowBlur not available in this environment"
               "missing context shadowBlur setter message")
(check-message context-shadow-color-message
               "CanvasRenderingContext2D.shadowColor not available in this environment"
               "missing context shadowColor message")
(check-message context-shadow-color-setter-message
               "CanvasRenderingContext2D.shadowColor not available in this environment"
               "missing context shadowColor setter message")
(check-message context-shadow-offset-x-message
               "CanvasRenderingContext2D.shadowOffsetX not available in this environment"
               "missing context shadowOffsetX message")
(check-message context-shadow-offset-x-setter-message
               "CanvasRenderingContext2D.shadowOffsetX not available in this environment"
               "missing context shadowOffsetX setter message")
(check-message context-shadow-offset-y-message
               "CanvasRenderingContext2D.shadowOffsetY not available in this environment"
               "missing context shadowOffsetY message")
(check-message context-shadow-offset-y-setter-message
               "CanvasRenderingContext2D.shadowOffsetY not available in this environment"
               "missing context shadowOffsetY setter message")
(check-message context-stroke-style-message
               "CanvasRenderingContext2D.strokeStyle not available in this environment"
               "missing context strokeStyle message")
(check-message context-stroke-style-setter-message
               "CanvasRenderingContext2D.strokeStyle not available in this environment"
               "missing context strokeStyle setter message")
(check-message context-text-align-message
               "CanvasRenderingContext2D.textAlign not available in this environment"
               "missing context textAlign message")
(check-message context-text-align-setter-message
               "CanvasRenderingContext2D.textAlign not available in this environment"
               "missing context textAlign setter message")
(check-message context-text-baseline-message
               "CanvasRenderingContext2D.textBaseline not available in this environment"
               "missing context textBaseline message")
(check-message context-text-baseline-setter-message
               "CanvasRenderingContext2D.textBaseline not available in this environment"
               "missing context textBaseline setter message")
(check-message context-text-rendering-message
               "CanvasRenderingContext2D.textRendering not available in this environment"
               "missing context textRendering message")
(check-message context-text-rendering-setter-message
               "CanvasRenderingContext2D.textRendering not available in this environment"
               "missing context textRendering setter message")
(check-message context-font-kerning-message
               "CanvasRenderingContext2D.fontKerning not available in this environment"
               "missing context fontKerning message")
(check-message context-font-kerning-setter-message
               "CanvasRenderingContext2D.fontKerning not available in this environment"
               "missing context fontKerning setter message")
(check-message context-font-stretch-message
               "CanvasRenderingContext2D.fontStretch not available in this environment"
               "missing context fontStretch message")
(check-message context-font-stretch-setter-message
               "CanvasRenderingContext2D.fontStretch not available in this environment"
               "missing context fontStretch setter message")
(check-message context-font-variant-caps-message
               "CanvasRenderingContext2D.fontVariantCaps not available in this environment"
               "missing context fontVariantCaps message")
(check-message context-font-variant-caps-setter-message
               "CanvasRenderingContext2D.fontVariantCaps not available in this environment"
               "missing context fontVariantCaps setter message")
(check-message context-font-variant-ligatures-message
               "CanvasRenderingContext2D.fontVariantLigatures not available in this environment"
               "missing context fontVariantLigatures message")
(check-message context-font-variant-ligatures-setter-message
               "CanvasRenderingContext2D.fontVariantLigatures not available in this environment"
               "missing context fontVariantLigatures setter message")
(check-message context-font-variant-numeric-message
               "CanvasRenderingContext2D.fontVariantNumeric not available in this environment"
               "missing context fontVariantNumeric message")
(check-message context-font-variant-numeric-setter-message
               "CanvasRenderingContext2D.fontVariantNumeric not available in this environment"
               "missing context fontVariantNumeric setter message")
(check-message context-letter-spacing-message
               "CanvasRenderingContext2D.letterSpacing not available in this environment"
               "missing context letterSpacing message")
(check-message context-letter-spacing-setter-message
               "CanvasRenderingContext2D.letterSpacing not available in this environment"
               "missing context letterSpacing setter message")
(check-message context-word-spacing-message
               "CanvasRenderingContext2D.wordSpacing not available in this environment"
               "missing context wordSpacing message")
(check-message context-word-spacing-setter-message
               "CanvasRenderingContext2D.wordSpacing not available in this environment"
               "missing context wordSpacing setter message")
(check-message image-data-width-message
               "ImageData.width not available in this environment"
               "missing ImageData.width message")
(check-message image-data-height-message
               "ImageData.height not available in this environment"
               "missing ImageData.height message")
(check-message image-data-data-message
               "ImageData.data not available in this environment"
               "missing ImageData.data message")
(check-message text-metrics-width-message
               "TextMetrics.width not available in this environment"
               "missing TextMetrics.width message")
(check-message dom-matrix-a-message
               "DOMMatrix.a not available in this environment"
               "missing DOMMatrix.a message")
(check-message dom-matrix-b-message
               "DOMMatrix.b not available in this environment"
               "missing DOMMatrix.b message")
(check-message dom-matrix-c-message
               "DOMMatrix.c not available in this environment"
               "missing DOMMatrix.c message")
(check-message dom-matrix-d-message
               "DOMMatrix.d not available in this environment"
               "missing DOMMatrix.d message")
(check-message dom-matrix-e-message
               "DOMMatrix.e not available in this environment"
               "missing DOMMatrix.e message")
(check-message dom-matrix-f-message
               "DOMMatrix.f not available in this environment"
               "missing DOMMatrix.f message")
(check-message forged-source-message
               "html-canvas-element with non-nullish raw value"
               "missing forged canvas source message")
(check-message forged-image-data-message
               "image-data with non-nullish raw value"
               "missing forged ImageData message")
(check-message forged-offscreen-canvas-message
               "offscreen-canvas with non-nullish raw value"
               "missing forged OffscreenCanvas message")
(check-message forged-gradient-style-message
               "canvas-gradient with non-nullish raw value"
               "missing forged CanvasGradient style message")
(check-message forged-pattern-style-message
               "canvas-pattern with non-nullish raw value"
               "missing forged CanvasPattern style message")
(check-message forged-matrix-message
               "dom-matrix with non-nullish raw value"
               "missing forged DOMMatrix message")
(check-false null-canvas "null canvas wrapper returns #f")
(check-false null-ctx "null canvas context wrapper returns #f")
(check-false null-image-data "null ImageData wrapper returns #f")
(check-false null-gradient "null CanvasGradient wrapper returns #f")
(check-false null-pattern "null CanvasPattern wrapper returns #f")
(check-false null-text-metrics "null TextMetrics wrapper returns #f")
(check-false null-matrix "null DOMMatrix wrapper returns #f")
(check-false null-offscreen-canvas "null OffscreenCanvas wrapper returns #f")
(check-false undefined-canvas "undefined canvas wrapper returns #f")
(check-false undefined-ctx "undefined canvas context wrapper returns #f")
(check-false undefined-image-data "undefined ImageData wrapper returns #f")
(check-false undefined-gradient "undefined CanvasGradient wrapper returns #f")
(check-false undefined-pattern "undefined CanvasPattern wrapper returns #f")
(check-false undefined-text-metrics "undefined TextMetrics wrapper returns #f")
(check-false undefined-matrix "undefined DOMMatrix wrapper returns #f")
(check-false undefined-offscreen-canvas "undefined OffscreenCanvas wrapper returns #f")

(js-log "browser-canvas-method-missing-host-ffi-ok")
#t
