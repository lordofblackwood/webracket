#lang webracket/base

(require web-easy)

;; Quickstart: Dynamic Counters (Light Theme)
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; Exercises keyed `list-view` rendering and dynamic observable list updates.

(define @counters (@ '((0 . 0))))

(define (append-counter counts)
  (define next-id (add1 (apply max -1 (map car counts))))
  (append counts `((,next-id . 0))))

(define (update-count counts k proc)
  (for/list ([entry (in-list counts)])
    (if (equal? (car entry) k)
        (cons k (proc (cdr entry)))
        entry)))

(define (counter count action)
  (hpanel
   (button "-" (lambda () (action sub1)))
   (text (number->string count))
   (button "+" (lambda () (action add1)))))

(define dynamic-counters-app
  (window
   (container
    (h1 "Dynamic Counters")
    (vpanel
     (hpanel
      (button "Add counter" (lambda () (@counters . <~ . append-counter))))
     (list-view @counters
                (lambda (k entry)
                  (counter (cdr entry)
                           (lambda (proc)
                             (@counters . <~ .
                                        (lambda (counts)
                                          (update-count counts k proc))))))
                car)))))

(define app-renderer
  (render dynamic-counters-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
