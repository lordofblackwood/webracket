#lang webracket/base

;;;
;;; Formula 1 countdown page (WebRacket simple site)
;;;

(require (for-syntax racket/base)
         (for-syntax (only-in racket/file file->string))
         web-easy
         browser/dom
         (only-in webracket/primitives
                  external-string->string))

(define-syntax (compile-time-file-to-string stx)
  (syntax-case stx ()
    [(_ file-name)
     (datum->syntax #'here (file->string (syntax-e #'file-name)))]))

(define (get-f1-calendar-ics)
  (compile-time-file-to-string "better-f1-calendar.ics"))

(define gh-base-file "https://github.com/soegaard/webracket/blob/main/")

(define (gh-file path)
  (string-append gh-base-file path))

(define (nav-link label href)
  `(a (@ (href ,href)) ,label))

(define (navbar)
  `(header (@ (class "site-header"))
           (nav (@ (class "top-nav"))
                (a (@ (class "wordmark") (href "../../site.html")
                      (aria-label "WebRacket home"))
                   (img (@ (src "../../assets/hex-racket-wasm-logo.svg")
                           (alt "")
                           (class "wordmark-logo")))
                   (span (@ (class "wordmark-muted")) "Web")
                   (span (@ (class "wordmark-strong")) "Racket"))
                (div (@ (class "nav-links"))
                     ,(nav-link "Quick Start" "../../site.html#quick-start")
                     ,(nav-link "Examples" "../../site.html#examples")
                     ,(nav-link "Documentation" "../../docs/webracket/index.html")
                     ,(nav-link "GitHub" "https://github.com/soegaard/webracket")))))

(define (footer-section)
  `(footer (@ (class "site-footer"))
           (p "Formula 1 Countdown, ported from the old WebRacket website.")))

(define (code-pill url text)
  `(a (@ (class "code-pill") (href ,url) (target "_blank") (rel "noreferrer noopener"))
      ,text))

;;;
;;; Page Layout
;;;

(define (formula1-page)
  `(div (@ (class "page page--formula1"))
        ,(navbar)
        (section (@ (class "examples-hero"))
                 (div (@ (class "hero-panel"))
                      (h1 (@ (class "hero-title")) "Formula 1 Countdown")
                      (p (@ (class "hero-lead"))
                         "Reads an ICS calendar and shows the next Formula 1 race.")))
        (section (@ (class "section section--examples"))
                 (div (@ (class "section-content"))
                      (div (@ (id "f1-countdown-card") (class "f1-countdown-card"))
                           (div (@ (class "f1-card-head"))
                                (p (@ (class "f1-kicker")) "Next race")
                                (span (@ (id "f1-data-badge") (class "f1-data-badge is-loading")
                                         (aria-live "polite"))
                                      "Loading"))
                           (h2 (@ (id "f1-next-race-title") (class "f1-race-title"))
                               "Loading next race...")
                           (div (@ (class "f1-countdown") (aria-live "polite"))
                                (span (@ (id "f1-countdown-value") (class "f1-countdown-value")) "-")
                                (span (@ (id "f1-countdown-unit") (class "f1-countdown-unit")) "days"))
                           (p (@ (id "f1-countdown-label") (class "f1-countdown-label"))
                              "until the next race")
                           (p (@ (id "f1-race-time") (class "f1-race-time")) "")
                           (p (@ (id "f1-countdown-status") (class "f1-countdown-status is-loading")
                                 (role "status") (aria-live "polite"))
                              "Loading calendar..."))))
        (section (@ (class "section section--examples-details"))
                 (div (@ (class "section-content"))
                      (div (@ (class "examples-details"))
                           (div (@ (class "demo-note"))
                                (p (@ (class "demo-note-label")) "What this shows")
                                (p "A browser program compiled from Racket parses a bundled calendar, "
                                   "uses the browser clock, and updates the page through DOM bindings."))
                           (div (@ (class "demo-note demo-note--source"))
                                (p (@ (class "demo-note-label")) "Source")
                                (p (@ (class "demo-note-muted"))
                                   "Adapted from the old website Formula 1 example.")
                                (div (@ (class "examples-actions demo-note-actions"))
                                     ,(code-pill (gh-file "web-site/src/examples/formula1-page.rkt")
                                                 "Old website source")
                                     ,(code-pill (gh-file "website-simple/src/examples/formula1/formula1-page.rkt")
                                                 "WebRacket source"))))))
        ,(footer-section)))

;;;
;;; Small string helpers
;;;

(define (string-prefix? s prefix)
  (define s-len (string-length s))
  (define prefix-len (string-length prefix))
  (and (<= prefix-len s-len)
       (string=? (substring s 0 prefix-len) prefix)))

(define (string-suffix? s suffix)
  (define s-len (string-length s))
  (define suffix-len (string-length suffix))
  (and (<= suffix-len s-len)
       (string=? (substring s (- s-len suffix-len) s-len) suffix)))

(define (string-contains? s needle)
  (define s-len (string-length s))
  (define needle-len (string-length needle))
  (cond
    [(= needle-len 0) #t]
    [(> needle-len s-len) #f]
    [else
     (let loop ([i 0])
       (cond
         [(> (+ i needle-len) s-len) #f]
         [(string=? (substring s i (+ i needle-len)) needle) #t]
         [else (loop (add1 i))]))]))

(define (string-split-lines s)
  (define len (string-length s))
  (let loop ([i 0] [start 0] [lines '()])
    (cond
      [(>= i len)
       (reverse (cons (substring s start len) lines))]
      [(char=? (string-ref s i) #\newline)
       (loop (add1 i) (add1 i) (cons (substring s start i) lines))]
      [else
       (loop (add1 i) start lines)])))

;;;
;;; Calendar model and parser
;;;

(struct f1-event (summary start))
(struct utc-date (year month day hour minute second))

(define (race-summary? summary)
  (and (string? summary)
       (string-contains? summary "Race")
       (not (string-contains? summary "Sprint"))))

(define (normalize-line line)
  (define len (string-length line))
  (if (and (> len 0) (char=? (string-ref line (- len 1)) #\return))
      (substring line 0 (- len 1))
      line))

(define (weekend-key summary)
  (cond
    [(not (string? summary)) ""]
    [(string-suffix? summary " - Sprint Race")
     (substring summary 0 (- (string-length summary)
                             (string-length " - Sprint Race")))]
    [(string-suffix? summary " - Race")
     (substring summary 0 (- (string-length summary)
                             (string-length " - Race")))]
    [else summary]))

(define (display-weekend-name summary)
  (define base (weekend-key summary))
  (define no-f1
    (if (string-prefix? base "F1 ")
        (substring base 3)
        base))
  (define sponsor-prefixes
    (list "Qatar Airways "
          "Aramco "
          "Lenovo "
          "Pirelli "
          "Aws "))
  (for/fold ([clean no-f1])
            ([prefix (in-list sponsor-prefixes)])
    (if (string-prefix? clean prefix)
        (substring clean (string-length prefix))
        clean)))

(define (parse-events text)
  (define lines (string-split-lines text))
  (for/fold ([events  '()]
             [summary #f]
             [start   #f]
             #:result (reverse events))
            ([raw-line (in-list lines)])
    (define line (normalize-line raw-line))
    (cond
      [(string-prefix? line "SUMMARY:")
       (values events (substring line 8) start)]
      [(string-prefix? line "DTSTART:")
       (values events summary (substring line 8))]
      [(string-prefix? line "END:VEVENT")
       (if (and summary start (string-contains? summary "Race"))
           (values (cons (f1-event summary start) events) #f #f)
           (values events #f #f))]
      [else
       (values events summary start)])))

(define (digits-only s)
  (list->string
   (filter char-numeric?
           (string->list s))))

(define (take-n s n)
  (values (substring s 0 n)
          (substring s n)))

(define (utc-string->utc-date s)
  (define ds (digits-only s))
  (when (< (string-length ds) 14)
    (error 'utc-string->utc-date
           "expected at least 14 digits in UTC date-time, got: ~a"
           s))
  (define-values (yyyy rest0) (take-n ds 4))
  (define-values (mm   rest1) (take-n rest0 2))
  (define-values (dd   rest2) (take-n rest1 2))
  (define-values (hh   rest3) (take-n rest2 2))
  (define-values (mi   rest4) (take-n rest3 2))
  (define-values (ss   _rest) (take-n rest4 2))
  (utc-date (string->number yyyy)
            (string->number mm)
            (string->number dd)
            (string->number hh)
            (string->number mi)
            (string->number ss)))

(define (safe-utc-string->utc-date s)
  (define ds (digits-only s))
  (if (< (string-length ds) 14)
      #f
      (utc-string->utc-date s)))

(define (date< a b)
  (cond
    [(< (utc-date-year a)   (utc-date-year b))   #t]
    [(> (utc-date-year a)   (utc-date-year b))   #f]
    [(< (utc-date-month a)  (utc-date-month b))  #t]
    [(> (utc-date-month a)  (utc-date-month b))  #f]
    [(< (utc-date-day a)    (utc-date-day b))    #t]
    [(> (utc-date-day a)    (utc-date-day b))    #f]
    [(< (utc-date-hour a)   (utc-date-hour b))   #t]
    [(> (utc-date-hour a)   (utc-date-hour b))   #f]
    [(< (utc-date-minute a) (utc-date-minute b)) #t]
    [(> (utc-date-minute a) (utc-date-minute b)) #f]
    [(< (utc-date-second a) (utc-date-second b)) #t]
    [else                                        #f]))

(define (same-day? a b)
  (and (= (utc-date-year a)  (utc-date-year b))
       (= (utc-date-month a) (utc-date-month b))
       (= (utc-date-day a)   (utc-date-day b))))

(define (pad2 n)
  (define s (number->string n))
  (if (< (string-length s) 2)
      (string-append "0" s)
      s))

(define (leap-year? y)
  (or (and (= (remainder y 4) 0)
           (not (= (remainder y 100) 0)))
      (= (remainder y 400) 0)))

(define (days-before-month y m)
  (define base (vector 0 31 59 90 120 151 181 212 243 273 304 334))
  (define d (vector-ref base (- m 1)))
  (if (and (> m 2) (leap-year? y)) (+ d 1) d))

(define (days-before-year y)
  (define y1 (- y 1))
  (+ (* y1 365)
     (quotient y1 4)
     (- (quotient y1 100))
     (quotient y1 400)))

(define (utc-date->unix-seconds d)
  (define days (+ (days-before-year (utc-date-year d))
                  (days-before-month (utc-date-year d) (utc-date-month d))
                  (- (utc-date-day d) 1)))
  (define days-1970 (days-before-year 1970))
  (define days-since-epoch (- days days-1970))
  (+ (* (exact->inexact days-since-epoch) 86400.0)
     (* (exact->inexact (utc-date-hour d)) 3600.0)
     (* (exact->inexact (utc-date-minute d)) 60.0)
     (exact->inexact (utc-date-second d))))

(define (utc-date->stamp d)
  (string-append (number->string (utc-date-year d)) "-"
                 (pad2 (utc-date-month d)) "-"
                 (pad2 (utc-date-day d)) " "
                 (pad2 (utc-date-hour d)) ":"
                 (pad2 (utc-date-minute d)) " UTC"))

(define (current-utc-date)
  (define iso-ext (js-eval "new Date().toISOString()"))
  (define iso     (external-string->string iso-ext))
  (utc-string->utc-date iso))

(define f1-ics-data (get-f1-calendar-ics))
(define f1-events   (parse-events f1-ics-data))

(define (find-next-race now)
  (define (event-start ev)
    (safe-utc-string->utc-date (f1-event-start ev)))
  (define (event-after-now? ev)
    (define start (event-start ev))
    (and start
         (or (date< now start)
             (and (same-day? now start)
                  (not (date< start now))))))
  (define (earlier-event? a b)
    (define a-start (event-start a))
    (define b-start (event-start b))
    (and a-start b-start (date< a-start b-start)))
  (for/fold ([best #f])
            ([ev (in-list f1-events)])
    (if (and (race-summary? (f1-event-summary ev))
             (event-after-now? ev))
        (cond
          [(not best) ev]
          [(earlier-event? ev best) ev]
          [else best])
        best)))

(define (pluralize n singular plural)
  (if (= n 1) singular plural))

(define (race-countdown-parts now event)
  (define start-date (safe-utc-string->utc-date (f1-event-start event)))
  (cond
    [(not start-date)
     (values "-" "time" "Race time unavailable.")]
    [else
     (define diff-seconds
       (- (utc-date->unix-seconds start-date)
          (utc-date->unix-seconds now)))
     (cond
       [(<= diff-seconds 0)
        (values "0" "hours" "Race started just now.")]
       [(same-day? now start-date)
        (define hours (max 1 (inexact->exact (ceiling (/ diff-seconds 3600)))))
        (values (number->string hours)
                (pluralize hours "hour" "hours")
                "until lights out")]
       [else
        (define days (max 1 (inexact->exact (ceiling (/ diff-seconds 86400)))))
        (values (number->string days)
                (pluralize days "day" "days")
                "until the next race")])]))

;;;
;;; DOM rendering
;;;

(define (set-text! id text)
  (define node (js-get-element-by-id id))
  (when node
    (js-set! node "textContent" text)))

(define (set-class! id text)
  (define node (js-get-element-by-id id))
  (when node
    (js-set! node "className" text)))

(define (render-f1-countdown!)
  (define now (current-utc-date))
  (define next-race (find-next-race now))
  (if next-race
      (let ()
        (define title
          (string-append "Next race: "
                         (display-weekend-name (f1-event-summary next-race))))
        (define start-date (safe-utc-string->utc-date (f1-event-start next-race)))
        (define-values (countdown-value countdown-unit countdown-label)
          (race-countdown-parts now next-race))
        (set-text! "f1-next-race-title" title)
        (set-text! "f1-countdown-value" countdown-value)
        (set-text! "f1-countdown-unit" countdown-unit)
        (set-text! "f1-countdown-label" countdown-label)
        (when start-date
          (set-text! "f1-race-time"
                     (string-append "Race start: " (utc-date->stamp start-date))))
        (set-text! "f1-data-badge" "Cached ICS")
        (set-class! "f1-data-badge" "f1-data-badge is-ready")
        (set-class! "f1-countdown-card" "f1-countdown-card is-ready")
        (set-class! "f1-countdown-status" "f1-countdown-status is-ready")
        (set-text! "f1-countdown-status"
                   (string-append "Browser time: " (utc-date->stamp now))))
      (begin
        (set-text! "f1-next-race-title" "No upcoming race found in the calendar.")
        (set-text! "f1-countdown-value" "-")
        (set-text! "f1-countdown-unit" "races")
        (set-text! "f1-countdown-label" "Check back soon")
        (set-text! "f1-data-badge" "Cached ICS")
        (set-class! "f1-data-badge" "f1-data-badge is-ready")
        (set-class! "f1-countdown-card" "f1-countdown-card is-error")
        (set-class! "f1-countdown-status" "f1-countdown-status is-error")
        (set-text! "f1-countdown-status" "The bundled calendar has no later race event."))))

(define (init-formula1-page!)
  (js-set! (js-var "document") "title" "Formula 1 Countdown")
  (render-f1-countdown!))

;;;
;;; SXML adapter
;;;

(define (sxml-attribute-value->string v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [(number? v) (number->string v)]
    [(boolean? v) (if v "true" "false")]
    [else (format "~a" v)]))

(define (sxml-attrs->view-attrs attrs)
  (map (lambda (attr)
         (cond
           [(and (pair? attr) (symbol? (car attr)) (pair? (cdr attr)))
            (cons (car attr)
                  (if (null? (cddr attr))
                      (sxml-attribute-value->string (cadr attr))
                      (apply string-append
                             (map sxml-attribute-value->string (cdr attr)))))]
           [else
            (error 'sxml->view "malformed attribute: ~a" attr)]))
       attrs))

(define (sxml-make-view tag attrs children)
  (define supported-tags
    '(a br code div footer h1 h2 header img nav p section span))
  (cond
    [(memq tag supported-tags)
     (view 'html-element-children
           (append (list (cons 'tag tag))
                   (if (null? attrs)
                       '()
                       (list (cons 'extra-attrs attrs))))
           children)]
    [else
     (error 'sxml->view "unsupported tag: ~a" tag)]))

(define (sxml->view exp)
  (cond
    [(view? exp)
     exp]
    [(string? exp)
     (view 'raw-text (list (cons 'value exp)) '())]
    [(or (symbol? exp) (number? exp) (char? exp))
     (view 'raw-text (list (cons 'value (format "~a" exp))) '())]
    [(and (pair? exp) (eq? (car exp) '@))
     (error 'sxml->view "stray attribute block: ~a" exp)]
    [(and (pair? exp) (symbol? (car exp)))
     (define tag (car exp))
     (define rest (cdr exp))
     (define attrs '())
     (define children rest)
     (when (and (pair? rest)
                (pair? (car rest))
                (eq? (car (car rest)) '@))
       (set! attrs (cdr (car rest)))
       (set! children (cdr rest)))
     (sxml-make-view tag
                     (sxml-attrs->view-attrs attrs)
                     (map sxml->view children))]
    [else
     (error 'sxml->view "malformed SXML expression: ~a" exp)]))

(define formula1-theme
  (theme 'simple-formula1
         "we-theme-simple"
         "web-easy-core.css"
         "site.css"
         "formula1.css"))

(define theme-manager
  (install-theme-manager! formula1-theme))

(define app-renderer
  (render (window (sxml->view (formula1-page)))))

(mount-renderer! app-renderer)
(init-formula1-page!)
