#lang webracket/base

(require web-easy)

;; 7 GUI - Counter
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; This intentionally uses `input` with `#:input-attrs` to exercise
;; component-level keyword handling.

(define @count (@ 0))

(define 7gui-counter-app
  (window
   (container
    (h1 "Counter")
    (hpanel
     (input (@count . ~> . number->string)
            (lambda _ (void))
            #:input-attrs '((readonly "readonly")))
     (button "count"
             (lambda () (obs-update! @count add1)))))))

(define app-renderer
  (render 7gui-counter-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
