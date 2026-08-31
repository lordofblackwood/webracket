#lang webracket/base

(require browser/dom
         browser/window
         device-orientation
         js/promise
         (only-in webracket/primitives
                  procedure->external))

(let ()

  (define (append-text-node! element text)
    (js-append-child! element (js-create-text-node text))
    (void))

  (define (set-text! element text)
    (js-set! element "textContent" text))

  (define (sensor-number value)
    (if value (number->string value) "not available"))

  (define style (js-create-element "style"))
  (js-set! style "textContent"
           "body { margin: 0; color: #15222c; background: linear-gradient(128deg, #d7ebf4, #f8f0d3 56%, #e2cfb6); font-family: Georgia, serif; }\n          main { max-width: 780px; margin: 0 auto; padding: 52px 22px 80px; }\n          h1 { margin: 0; max-width: 9ch; color: #173d51; font-size: clamp(2.8rem, 9vw, 5.4rem); line-height: .88; letter-spacing: -.065em; }\n          .lede { max-width: 40rem; font-size: 1.2rem; line-height: 1.55; }\n          .panel { margin-top: 24px; padding: 22px; border: 1px solid rgba(32, 81, 104, .3); border-radius: 22px; background: rgba(255,255,255,.76); box-shadow: 0 18px 40px rgba(28, 53, 62, .12); }\n          h2 { margin: 0 0 10px; color: #8a3d26; }\n          button { border: 0; border-radius: 999px; padding: 13px 20px; color: #fffaf1; background: #9a472d; cursor: pointer; font: 700 1rem/1 Georgia, serif; }\n          button:disabled { cursor: not-allowed; background: #a99c8c; }\n          #device-orientation-status { min-height: 1.5em; color: #74401e; font-weight: 700; }\n          pre { overflow: auto; padding: 15px; border-radius: 13px; background: #173d51; color: #ecf9f4; line-height: 1.45; white-space: pre-wrap; }\n          .note { color: #4f5d62; line-height: 1.5; }")
  (void (js-append-child! (js-document-head) style))

  (define body (js-document-body))
  (define main (js-create-element "main"))
  (define title (js-create-element "h1"))
  (define lede (js-create-element "p"))
  (define control-panel (js-create-element "section"))
  (define control-title (js-create-element "h2"))
  (define control-copy (js-create-element "p"))
  (define enable-button (js-create-element "button"))
  (define status (js-create-element "p"))
  (define orientation-panel (js-create-element "section"))
  (define orientation-title (js-create-element "h2"))
  (define orientation-values (js-create-element "pre"))
  (define motion-panel (js-create-element "section"))
  (define motion-title (js-create-element "h2"))
  (define motion-values (js-create-element "pre"))

  (js-set-attribute! control-panel "class" "panel")
  (js-set-attribute! orientation-panel "class" "panel")
  (js-set-attribute! motion-panel "class" "panel")
  (js-set-attribute! control-copy "class" "note")
  (js-set-attribute! status "id" "device-orientation-status")
  (js-set-attribute! orientation-values "id" "device-orientation-values")
  (js-set-attribute! motion-values "id" "device-motion-values")

  (append-text-node! title "Device Orientation")
  (append-text-node! lede
                     "Turn a phone or tablet to watch the browser's orientation, acceleration, and rotation readings arrive as checked Racket values.")
  (append-text-node! control-title "Enable device sensors")
  (append-text-node! control-copy
                     "On Safari and some other browsers, this button must make the permission request directly from a user click. Desktop browsers may have no physical sensor data to report.")
  (append-text-node! enable-button "Enable readings")
  (append-text-node! orientation-title "Orientation")
  (append-text-node! motion-title "Motion")
  (set-text! orientation-values "Waiting for a deviceorientation event...")
  (set-text! motion-values "Waiting for a devicemotion event...")

  (define listening? #f)
  (define sensor-reading-seen? #f)

  (define (show-orientation raw-event)
    (define event (device-orientation-event-wrap raw-event))
    (define alpha (device-orientation-event-alpha event))
    (define beta (device-orientation-event-beta event))
    (define gamma (device-orientation-event-gamma event))
    (define compass-heading (device-orientation-event-compass-heading event))
    (when (or alpha beta gamma compass-heading)
      (set! sensor-reading-seen? #t))
    (set-text! orientation-values
               (string-append
                "alpha (z): " (sensor-number alpha) " degrees\n"
                "beta  (x): " (sensor-number beta) " degrees\n"
                "gamma (y): " (sensor-number gamma) " degrees\n"
                "Earth frame: " (if (device-orientation-event-absolute? event) "yes" "no") "\n"
                "Compass heading: " (sensor-number compass-heading) " degrees"))
    (void))

  (define (show-absolute-orientation raw-event)
    (define event (device-orientation-event-wrap raw-event))
    (define alpha (device-orientation-event-alpha event))
    (when alpha
      (set! sensor-reading-seen? #t)
      (set-text! status
                 (string-append "Receiving absolute orientation. Alpha: "
                                (sensor-number alpha)
                                " degrees.")))
    (void))

  (define (show-motion raw-event)
    (define event (device-motion-event-wrap raw-event))
    (define acceleration-x (device-motion-event-acceleration-x event))
    (define acceleration-y (device-motion-event-acceleration-y event))
    (define acceleration-z (device-motion-event-acceleration-z event))
    (define gravity-x (device-motion-event-gravity-acceleration-x event))
    (define gravity-y (device-motion-event-gravity-acceleration-y event))
    (define gravity-z (device-motion-event-gravity-acceleration-z event))
    (define rotation-alpha (device-motion-event-rotation-alpha event))
    (define rotation-beta (device-motion-event-rotation-beta event))
    (define rotation-gamma (device-motion-event-rotation-gamma event))
    (define interval (device-motion-event-interval event))
    (when (or acceleration-x acceleration-y acceleration-z
              gravity-x gravity-y gravity-z
              rotation-alpha rotation-beta rotation-gamma)
      (set! sensor-reading-seen? #t))
    (set-text! motion-values
               (string-append
                "acceleration x/y/z: "
                (sensor-number acceleration-x) ", "
                (sensor-number acceleration-y) ", "
                (sensor-number acceleration-z) " m/s^2\n"
                "with gravity x/y/z: "
                (sensor-number gravity-x) ", "
                (sensor-number gravity-y) ", "
                (sensor-number gravity-z) " m/s^2\n"
                "rotation alpha/beta/gamma: "
                (sensor-number rotation-alpha) ", "
                (sensor-number rotation-beta) ", "
                (sensor-number rotation-gamma) " degrees/s\n"
                "sample interval: " (sensor-number interval) " ms"))
    (void))

  (define (report-missing-sensor-readings!)
    (unless sensor-reading-seen?
      (set-text!
       status
       "No sensor event arrived. This browser may not expose physical sensors. Try a phone or tablet, or use Chrome DevTools > More tools > Sensors to emulate orientation."))
    (void))

  (define (start-listening!)
    (unless listening?
      (set! listening? #t)
      (when (device-orientation-supported?)
        (device-orientation-add-listener! show-orientation)
        (device-orientation-add-absolute-listener! show-absolute-orientation))
      (when (device-motion-supported?)
        (device-motion-add-listener! show-motion)))
    (js-set! enable-button "disabled" #f)
    (set-text! status "Listening for sensor readings. Move or rotate the device.")
    (window-set-timeout/delay
     (procedure->external
      (lambda ()
        (report-missing-sensor-readings!)
        (void)))
     4000)
    (void))

  (define (permission-denied! kind)
    (js-set! enable-button "disabled" #f)
    (set-text! status (string-append kind " permission was denied or unavailable."))
    (void))

  (define (request-motion-or-start!)
    (cond
      [(device-motion-permission-requestable?)
       (js-promise-then
        (device-motion-request-permission)
        (lambda (raw-status)
          (if (eq? (device-orientation-permission-status raw-status) 'granted)
              (start-listening!)
              (permission-denied! "Motion"))
          (void))
        (lambda (_reason)
          (permission-denied! "Motion")
          (void)))]
      [else (start-listening!)]))

  (define (enable-readings!)
    (js-set! enable-button "disabled" #t)
    (set-text! status "Requesting sensor permission...")
    (cond
      [(device-orientation-permission-requestable?)
       (js-promise-then
        (device-orientation-request-permission #t)
        (lambda (raw-status)
          (if (eq? (device-orientation-permission-status raw-status) 'granted)
              (request-motion-or-start!)
              (permission-denied! "Orientation"))
          (void))
        (lambda (_reason)
          (permission-denied! "Orientation")
          (void)))]
      [else (request-motion-or-start!)]))

  (void
   (js-add-event-listener!
    enable-button
    "click"
    (procedure->external (lambda (_event) (enable-readings!) (void)))))

  (void (js-append-child! control-panel control-title))
  (void (js-append-child! control-panel control-copy))
  (void (js-append-child! control-panel enable-button))
  (void (js-append-child! control-panel status))
  (void (js-append-child! orientation-panel orientation-title))
  (void (js-append-child! orientation-panel orientation-values))
  (void (js-append-child! motion-panel motion-title))
  (void (js-append-child! motion-panel motion-values))
  (void (js-append-child! main title))
  (void (js-append-child! main lede))
  (void (js-append-child! main control-panel))
  (void (js-append-child! main orientation-panel))
  (void (js-append-child! main motion-panel))
  (void (js-append-child! body main))

  (cond
    [(or (device-orientation-supported?) (device-motion-supported?))
     (set-text! status "Press Enable readings, then move the device.")]
    [else
     (js-set! enable-button "disabled" #t)
     (set-text! status "Device Orientation and Motion are not available in this browser.")]))
