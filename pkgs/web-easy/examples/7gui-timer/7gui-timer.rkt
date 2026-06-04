#lang webracket/base

(require web-easy
         (only-in racket/math
                  exact-round)
         (only-in webracket/primitives
                  procedure->external)
         webracket/unsafe/window)

;; 7 GUI - Timer
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; Exercises browser intervals, progress bars, sliders, and observable updates.

;; ----------------------------------------
;; Timers
;; ----------------------------------------

(define interval-id #f)

;; start-timer : (-> void?) real? -> void?
;;   Call on-tick every delay milliseconds.
(define (start-timer on-tick delay)
  (when interval-id
    (js-window-clear-interval interval-id))
  (define callback
    (procedure->external on-tick))
  (set! interval-id
        (js-window-set-interval callback delay)))

;; ----------------------------------------
;; App state
;; ----------------------------------------

(define @elapsed  (@ 0))   ; Time elapsed since last reset, capped at duration.
(define @duration (@ 10))  ; Max duration for timer.

(define (on-tick)
  (@elapsed . <~ . (lambda (elapsed)
                     (define next-elapsed (+ elapsed 0.1))
                     (define duration     (obs-peek @duration))
                     (if (< next-elapsed duration)
                         next-elapsed
                         duration))))

(define (~seconds s)
  (number->string (/ (round (* s 100)) 100.0)))

(define 7gui-timer-app
  (window
   (container
    (h1 "Timer")
    (Form
     (vpanel
      (Label "Elapsed time")
      (progress (@elapsed . ~> . (lambda (elapsed)
                                   (exact-round (* elapsed 10))))
                #:max (@duration . ~> . (lambda (duration)
                                          (* duration 10)))
                #:min 0)
      (text (@elapsed . ~> . ~seconds))
      (text " ")
      (vpanel
       (Label "Duration")
       (slider @duration
               (lambda (duration) (:= @duration duration))
               1
               100)
       (text (@duration . ~> . ~seconds)))
      (hpanel
       (button "Reset"
               (lambda () (:= @elapsed 0))
               #:type "button"))))
    #:style "max-width: 400px;")))

(define app-renderer
  (render 7gui-timer-app))

(start-timer on-tick 100.0)

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
