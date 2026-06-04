#lang webracket/base

(require web-easy)

;; Add Two Numbers (Light Theme)
;;
;; This mirrors the legacy `(include-lib web-easy)` example, but uses
;; `(require web-easy)` so it exercises the module-based WebRacket path.

;; The model consists of two numbers a and b and their sum s.
(define @a (@ 10))
(define @b (@ 20))
(define @s (obs-combine + @a @b))

;; Constants for initial input state.
(define @a-text (@ (number->string (obs-peek @a))))
(define @b-text (@ (number->string (obs-peek @b))))

;; The result is always computed from the model.
(define @s-text (obs-map @s number->string))

;; parse-number : string? -> (or/c number? #f)
;;   Parse s as a number, or #f when parsing fails.
(define (parse-number s)
  (string->number s))

;; update-model! : -> void?
;;   Update numeric model values when the input text parses.
(define (update-model!)
  (define a (parse-number (obs-peek @a-text)))
  (when a (:= @a a))
  (define b (parse-number (obs-peek @b-text)))
  (when b (:= @b b)))

(define app-renderer
  (render
   (window
    (container
     (stack
      (heading 2 "Add Two Numbers")
      (text "Type two numbers to see their sum.")
      (group "Inputs"
             (stack
              (text "First number")
              (input @a-text
                     (lambda (v)
                       (:= @a-text v)
                       (update-model!))
                     #:attrs '((placeholder "e.g. 12.5")))
              (text "Second number")
              (input @b-text
                     (lambda (v)
                       (:= @b-text v)
                       (update-model!))
                     #:attrs '((placeholder "e.g. 3.5")))))
      (group "Result"
             (inline (text "The sum is: ")
                     (text @s-text))))))))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
