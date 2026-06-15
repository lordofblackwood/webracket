#lang webracket/base

(require browser/canvas
         browser/dom
         web-pict)

(define body (js-document-body))
(define one-pixel-png
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z2ioAAAAASUVORK5CYII=")

(js-set-attribute! body "data-state" "starting")

(define canvas (js-create-element "canvas"))
(canvas-set-width! canvas 4)
(canvas-set-height! canvas 4)
(js-append-child! body canvas)

(define ctx (canvas-get-context canvas "2d"))

(load-bitmap
 one-pixel-png
 (lambda (_url image)
   (canvas-2d-draw-image ctx image 0 0)
   (js-set-attribute! body "data-state" "loaded")
   (js-append-child! body (js-create-text-node "canvas-draw-image-integers-ok")))
 (lambda (failed-url)
   (js-set-attribute! body "data-state" "error")
   (js-append-child!
    body
    (js-create-text-node
     (string-append "error=" failed-url)))))
