#lang webracket/base

(require racket/list
         racket/math
         browser/dom
         web-pict)

;;;
;;; Web Pict Example
;;;

;; Small browser demo that exercises the extracted `web-pict` library.

(define image-urls
  (list "../assets/fish-1.png"
        "../assets/fish-2.png"))

(define pending-images (length image-urls))
(define main-started?  #f)
(define body           (js-document-body))
(define status         (js-create-element "div"))

(js-set-attribute! status "id" "status")
(js-set-attribute! status "data-state" "loading")
(js-set! status "textContent" "loading")
(js-append-child! body status)

;; mark-status! : string? string? -> void?
;;   Update the example status marker for browser smoke/manual checks.
(define (mark-status! state text)
  (js-set-attribute! status "data-state" state)
  (js-set! status "textContent" text))

;; flush : -> void?
;;   Forward buffered output to the browser log.
(define (flush)
  (js-log (get-output-string (current-output-port))))

;; maybe-start-main : -> void?
;;   Start the demo once every image has either loaded or failed.
(define (maybe-start-main)
  (when (and (not main-started?) (zero? pending-images))
    (set! main-started? #t)
    (main)))

;; note-image-finished! : -> void?
;;   Record one completed image fetch and maybe start the demo.
(define (note-image-finished!)
  (set! pending-images (sub1 pending-images))
  (maybe-start-main))

;; draw-demo : any/c any/c any/c -> void?
;;   Render a compact `web-pict` showcase onto dc.
(define (draw-demo dc nemo-image tropical-image)
  (draw-pict (scale (bitmap tropical-image) 0.5) dc 800 100)
  (draw-pict (flip-x (scale (bitmap tropical-image) 0.5)) dc 800 475)
  (draw-pict (flip-x (flip-x (scale (bitmap tropical-image) 0.5))) dc 800 700)
  (draw-pict (flip-y (scale (bitmap tropical-image) 0.2)) dc 100 900)
  (draw-pict (flip-y (flip-y (scale (bitmap tropical-image) 0.2))) dc 200 900)
  (draw-pict (shear (scale (bitmap tropical-image) 0.2) -0.5 0.3) dc 300 900)
  (draw-pict (rotate (frame (scale (bitmap tropical-image) 0.2)) (/ 3.1415 4))
             dc 525 800)
  (draw-pict (frame (scale (inset (text (string #\U1F41F)) 0 -4) 4))
             dc 500 200)
  (draw-pict (frame (text "Hello World" '() 24 (/ 3.14 4))) dc 200 200)
  (draw-pict (hc-append (frame (blank 30))
                        (frame (blank 60)))
             dc 300 300)
  (draw-pict (cc-superimpose (frame (blank 30))
                             (frame (blank 60)))
             dc 400 200)
  (draw-pict (frame (text "web-pict" '() 28 (/ pi 16))) dc 120 140)
  (draw-pict (scale (frame (text "Hello World" '() 16)) 2) dc 120 250)
  (draw-pict (colorize (filled-rounded-rectangle 140 80 16) "lightblue") dc 120 420)
  (draw-pict (circle 90 "darkblue" 3) dc 300 410)
  (draw-pict (colorize (filled-ellipse 110 60 #t "darkblue" 5) "lightskyblue") dc 430 425)
  (draw-pict (cc-superimpose (colorize (filled-rectangle 120 70) "darkcyan")
                             (cellophane (disk 54) 0.55))
             dc 620 450)
  (draw-pict (table 4
                    (map (lambda (x) (text (format "~a" x)))
                         (list 1 2 3 4
                               5 6 7 8
                               9 10 11 12))
                    cc-superimpose
                    cc-superimpose
                    10
                    10)
             dc 510 690)
  (draw-pict (standard-fish 80 40)
             dc 100 300)
  (draw-pict (let ()
               (define txt (colorize (text "Freeze!" null 18) "deepskyblue"))
               (vl-append (scale (frame txt) 2)
                          (scale (frame (freeze txt)) 2)))
             dc 100 660)
  (draw-pict (let ()
               (define t (text "ij"))
               (define tt (vl-append t t))
               (explain tt))
             dc 300 650)
  (draw-pict (hc-append (frame (blank 40))
                        (blank 16)
                        (scale-to-fit (colorize (filled-rectangle 40 40) "olive")
                                      (disk 70)))
             dc 120 530)
  (draw-pict (scale (bitmap nemo-image) 0.28) dc 845 715)
  (dc 'fill-style "red")
  (dc 'font "56px 'Arial'")
  (dc 'fill-text "webracket/pict" 260 70))

;; main : -> void?
;;   Build the demo canvas and render the scene.
(define (main)
  (define canvas (js-create-element "canvas"))
  (js-set-canvas-width! canvas 1024)
  (js-set-canvas-height! canvas 1024)
  (js-append-child! body canvas)

  (define ctx (js-canvas-get-context canvas "2d" (js-undefined)))
  (define dc  (canvas-context->dc ctx))
  (define nemo-image (bitmap-ref (first image-urls)))
  (define tropical-image (bitmap-ref (second image-urls)))

  (with-handlers ([exn:fail?
                   (lambda (e)
                     (mark-status! "error"
                                   (string-append "msg=" (exn-message e)))
                     (displayln e)
                     (flush))])
    (draw-demo dc nemo-image tropical-image)
    (mark-status! "ready" "ready"))
  (flush))

(for-each
 (lambda (url)
   (load-bitmap url
                (lambda (_url _image)
                  (note-image-finished!))
                (lambda (failed-url)
                  (mark-status! "error" (string-append "bitmap load failed: " failed-url))
                  (displayln "bitmap load failed:")
                  (displayln failed-url)
                  (note-image-finished!))))
 image-urls)
