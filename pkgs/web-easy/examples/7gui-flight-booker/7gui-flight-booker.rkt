#lang webracket/base

(require web-easy)

;; 7 GUI - Flight Booker
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; Exercises choice controls, validation, disabled state, and dialogs.

;; Dates, replacing the legacy example's avoided `gregor` dependency.
(struct flight-date (year month day) #:transparent)

(define (date<? a b)
  (cond
    [(< (flight-date-year a) (flight-date-year b)) #t]
    [(> (flight-date-year a) (flight-date-year b)) #f]
    [(< (flight-date-month a) (flight-date-month b)) #t]
    [(> (flight-date-month a) (flight-date-month b)) #f]
    [else (< (flight-date-day a) (flight-date-day b))]))

(define (today/date)
  (flight-date 2026 3 16))

(define (tomorrow/date)
  (flight-date 2026 3 17))

(define (leap-year? y)
  (or (zero? (remainder y 400))
      (and (zero? (remainder y 4))
           (not (zero? (remainder y 100))))))

(define (days-in-month y m)
  (case m
    [(1 3 5 7 8 10 12) 31]
    [(4 6 9 11) 30]
    [(2) (if (leap-year? y) 29 28)]
    [else 0]))

(define (pad2 n)
  (if (< n 10)
      (string-append "0" (number->string n))
      (number->string n)))

(define (~date d)
  (string-append
   (number->string (flight-date-year d))
   "."
   (pad2 (flight-date-month d))
   "."
   (pad2 (flight-date-day d))))

(define (digit-value ch)
  (define n (- (char->integer ch) (char->integer #\0)))
  (and (<= 0 n 9) n))

(define (parse-2digits s start)
  (and (< (+ start 1) (string-length s))
       (let ([d1 (digit-value (string-ref s start))]
             [d2 (digit-value (string-ref s (+ start 1)))])
         (and d1 d2 (+ (* d1 10) d2)))))

(define (parse-4digits s start)
  (and (< (+ start 3) (string-length s))
       (let ([d1 (digit-value (string-ref s start))]
             [d2 (digit-value (string-ref s (+ start 1)))]
             [d3 (digit-value (string-ref s (+ start 2)))]
             [d4 (digit-value (string-ref s (+ start 3)))])
         (and d1 d2 d3 d4
              (+ (* d1 1000)
                 (* d2 100)
                 (* d3 10)
                 d4)))))

(define (string->date s)
  (and (= (string-length s) 10)
       (char=? (string-ref s 4) #\.)
       (char=? (string-ref s 7) #\.)
       (let* ([y  (parse-4digits s 0)]
              [mo (parse-2digits s 5)]
              [d  (parse-2digits s 8)])
         (and y mo d
              (<= 1 mo 12)
              (<= 1 d (days-in-month y mo))
              (flight-date y mo d)))))

(define flight-types
  '((one-way "one-way flight")
    (return "return flight")))

(define @type    (@ 'one-way))
(define @t1      (@ (~date (today/date))))
(define @t2      (@ (~date (tomorrow/date))))
(define @booked? (@ #f))

(define @valid?
  (obs-combine
   (lambda (type t1 t2)
     (case type
       [(one-way) (and (string->date t1) #t)]
       [(return)
        (define d1 (string->date t1))
        (define d2 (string->date t2))
        (and d1 d2 (date<? d1 d2))]))
   @type
   @t1
   @t2))

(define @booking-message
  (obs-combine
   (lambda (type t1 t2)
     (case type
       [(one-way)
        (format "You've booked a one-way flight on ~a." t1)]
       [(return)
        (format "You've booked a return flight on ~a (returning on ~a)." t1 t2)]))
   @type
   @t1
   @t2))

(define @return-disabled
  (@type . ~> . (lambda (type) (eq? type 'one-way))))

(define (input-style valid?)
  (if valid?
      ""
      "background-color: #ffdddd;"))

(define (book-button)
  (button "Book"
          (lambda () (:= @booked? #t))
          #:disabled (@valid? . ~> . (lambda (valid) (not valid)))))

(define 7gui-flight-booker-app
  (window
   (container
    (h1 "Flight Booker")
    (group "Book Flight"
           (vpanel
            (choice flight-types
                    @type
                    (lambda (new-type) (obs-set! @type new-type))
                    #:id "flight-type-choice")
            (input @t1
                   (lambda (text) (obs-set! @t1 text))
                   #:id "away-date-input"
                   #:input-attrs
                   (list (cons 'placeholder "yyyy.MM.dd")
                         (cons 'style (@t1 . ~> . input-style))))
            (input @t2
                   (lambda (text) (obs-set! @t2 text))
                   #:id "return-date-input"
                   #:style (@t2 . ~> . (lambda (t) (input-style (string->date t))))
                   #:disabled @return-disabled
                   #:placeholder "yyyy.MM.dd")
            (observable-view
             @valid?
             (lambda (valid?)
               (if valid?
                   (text "")
                   (alert "Use yyyy.MM.dd. For return flights, the return date must be later."
                          'danger))))
            (hpanel (spacer) (book-button) (spacer))))
    (dialog @booked?
            (lambda () (obs-set! @booked? #f))
            (text @booking-message)
            #:title "Flight Booked"
            #:footer
            (hpanel
             (spacer)
             (button "OK" (lambda () (obs-set! @booked? #f)))))
    #:style "max-width: 320px;")))

(define app-renderer
  (render 7gui-flight-booker-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
