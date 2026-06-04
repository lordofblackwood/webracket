#lang webracket/base

(require web-easy)

;; 7 GUI - Temperature Converter
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; Exercises observable input values plus dynamic input styling.

(define (F->C f) (* (- f 32) 5/9))
(define (C->F c) (+ (* c 9/5) 32))

(define @tempC (@ 26))
(define @tempF (@tempC . ~> . C->F))

(define (~background color) (or color ""))
(define (~a x)              (format "~a" x))
(define (~one x)            (number->string (/ (round (* x 10)) 10.0)))

;; Track where the user is actively editing, so that field does not get
;; overwritten by its derived counterpart while typing.
(define @source (@ "Celsius"))

;; temp : string? observable? (number? -> number?) -> view?
;;   Construct a temperature input and label pair.
(define (temp label @temp convert-to-C)
  (define @input (@ (~a (obs-peek @temp))))
  (define @background (@ #f))
  (define @input-style
    (@background . ~> .
                 (lambda (bg)
                   (format "background-color: ~a;" (~background bg)))))
  (define @input-value
    (obs-combine (lambda (temp input source)
                   (cond
                     [(equal? source label)
                      input]
                     [else
                      (:= @background #f)
                      (~one temp)]))
                 @temp
                 @input
                 @source))
  (hpanel
   (input @input-value
          (lambda (new-text)
            (:= @input new-text)
            (:= @source label)
            (define new-temp (string->number new-text))
            (cond
              [new-temp
               (:= @tempC (convert-to-C new-temp))
               (:= @background #f)]
              [else
               (:= @background "red")]))
          #:style @input-style)
   (text label)))

(define 7gui-temperature-converter-app
  (window
   (container
    (h1 "Temperature Converter")
    (hpanel
     (temp "Celsius" @tempC values)
     (text " = ")
     (temp "Fahrenheit" @tempF F->C)))))

(define app-renderer
  (render 7gui-temperature-converter-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
