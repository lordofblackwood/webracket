#lang webracket/base

;; Browser smoke for missing JSXGraph host-library errors.

(require jsxgraph
         (only-in webracket/unsafe/jsxgraph
                  js-jsx-board-id
                  js-jsx-board-canvas-width
                  js-jsx-board-objects-list
                  js-jsx-point-size
                  js-jsx-set-point-size!
                  js-jsx-point-snap-to-grid)
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

(define js-null (js-eval "null"))
(define missing-board (js-eval "({})"))
(define missing-point (js-eval "({})"))

(define board-message
  (catch-message
   (lambda ()
     (jsx-create-board "missing-jsxgraph-host"))))

(define point-message
  (catch-message
   (lambda ()
     (jsx-point?/raw (js-eval "({})")))))

(define board-id-null-message
  (catch-message
   (lambda ()
     (js-jsx-board-id js-null))))

(define board-canvas-width-null-message
  (catch-message
   (lambda ()
     (js-jsx-board-canvas-width js-null))))

(define board-objects-list-null-message
  (catch-message
   (lambda ()
     (js-jsx-board-objects-list js-null))))

(define point-size-null-message
  (catch-message
   (lambda ()
     (js-jsx-point-size js-null))))

(define set-point-size-null-message
  (catch-message
   (lambda ()
     (js-jsx-set-point-size! js-null 4.0))))

(define point-snap-to-grid-null-message
  (catch-message
   (lambda ()
     (js-jsx-point-snap-to-grid js-null))))

(define board-id-missing-message
  (catch-message
   (lambda ()
     (js-jsx-board-id missing-board))))

(define board-canvas-width-missing-message
  (catch-message
   (lambda ()
     (js-jsx-board-canvas-width missing-board))))

(define board-objects-list-missing-message
  (catch-message
   (lambda ()
     (js-jsx-board-objects-list missing-board))))

(define point-size-missing-message
  (catch-message
   (lambda ()
     (js-jsx-point-size missing-point))))

(define set-point-size-missing-message
  (catch-message
   (lambda ()
     (js-jsx-set-point-size! missing-point 4.0))))

(define point-snap-to-grid-missing-message
  (catch-message
   (lambda ()
     (js-jsx-point-snap-to-grid missing-point))))

(check-message board-message
               "JSXGraph JXG.JSXGraph not available"
               "missing JSXGraph board message")
(check-message point-message
               "JSXGraph JXG.isPoint not available"
               "missing JSXGraph point message")
(check-message board-id-null-message
               "JSXGraph Board.id: target object is null or undefined"
               "null JSXGraph Board.id message")
(check-message board-canvas-width-null-message
               "JSXGraph Board.canvasWidth: target object is null or undefined"
               "null JSXGraph Board.canvasWidth message")
(check-message board-objects-list-null-message
               "JSXGraph Board.objects: target object is null or undefined"
               "null JSXGraph Board.objects message")
(check-message point-size-null-message
               "JSXGraph Point.size: target object is null or undefined"
               "null JSXGraph Point.size message")
(check-message set-point-size-null-message
               "JSXGraph Point.size: target object is null or undefined"
               "null JSXGraph Point.size setter message")
(check-message point-snap-to-grid-null-message
               "JSXGraph Point.snapToGrid: target object is null or undefined"
               "null JSXGraph Point.snapToGrid message")
(check-message board-id-missing-message
               "JSXGraph Board.id not available in this environment"
               "missing JSXGraph Board.id message")
(check-message board-canvas-width-missing-message
               "JSXGraph Board.canvasWidth not available in this environment"
               "missing JSXGraph Board.canvasWidth message")
(check-message board-objects-list-missing-message
               "JSXGraph Board.objects not available in this environment"
               "missing JSXGraph Board.objects message")
(check-message point-size-missing-message
               "JSXGraph Point.size not available in this environment"
               "missing JSXGraph Point.size message")
(check-message set-point-size-missing-message
               "JSXGraph Point.size not available in this environment"
               "missing JSXGraph Point.size setter message")
(check-message point-snap-to-grid-missing-message
               "JSXGraph Point.snapToGrid not available in this environment"
               "missing JSXGraph Point.snapToGrid message")

(js-log "jsxgraph-missing-host-ffi-ok")
#t
