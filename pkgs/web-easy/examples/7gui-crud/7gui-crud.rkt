#lang webracket/base

(require racket/list
         racket/string
         web-easy)

;; 7 GUI - CRUD
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; Exercises filtering, list groups, form inputs, and create/update/delete state.

;; ----------------------------------------
;; List utilities
;; ----------------------------------------

(define (replace-first xs x y same?)
  (let loop ([seen '()]
             [rest xs])
    (cond
      [(null? rest)
       (reverse seen)]
      [else
       (define x0 (car rest))
       (cond
         [(same? x x0)
          (append (reverse (cons y seen))
                  (cdr rest))]
         [else
          (loop (cons x0 seen)
                (cdr rest))])])))

(define (indexed-rendered-list xs render)
  (let loop ([rest xs]
             [i 0])
    (cond
      [(null? rest) '()]
      [else
       (cons (list i (render (car rest)))
             (loop (cdr rest)
                   (add1 i)))])))

(define (safe-list-ref xs i)
  (define n (length xs))
  (if (and (integer? i)
           (<= 0 i)
           (< i n))
      (list-ref xs i)
      #f))

;; ----------------------------------------
;; Data representation and formatting
;; ----------------------------------------

(struct person (name surname) #:transparent)

(define (~person p)
  (format "~a, ~a"
          (person-surname p)
          (person-name p)))

;; ----------------------------------------
;; Model
;; ----------------------------------------

(define @people
  (@ (list (person "Emil"  "Hans")
           (person "Max"   "Mustermann")
           (person "Roman" "Tisch"))))

(define (update p name surname)
  (define updated-p
    (person name surname))
  (@people . <~ . (lambda (people)
                    (replace-first people p updated-p eq?)))
  updated-p)

(define (create name surname)
  (define new-p
    (person name surname))
  (@people . <~ . (lambda (people)
                    (append people (list new-p))))
  new-p)

(define (delete! p)
  (@people . <~ . (lambda (people)
                    (remq p people)))
  (void))

;; ----------------------------------------
;; App state
;; ----------------------------------------

(define @prefix          (@ ""))
(define @selected-person (@ #f))
(define @current-name    (@ ""))
(define @current-surname (@ ""))

(define @filtered-people
  (obs-combine
   (lambda (people prefix)
     (for/list ([p (in-list people)]
                #:when (string-prefix? (string-downcase (person-surname p))
                                       (string-downcase prefix)))
       p))
   @people
   @prefix))

(define @selected-visible?
  (obs-combine
   (lambda (filtered selected)
     (and selected
          (memq selected filtered)))
   @filtered-people
   @selected-person))

(define (set-name-fields name surname)
  (:= @current-name name)
  (:= @current-surname surname))

(define (clear-name-fields)
  (:= @current-name "")
  (:= @current-surname ""))

(obs-observe!
 (obs-combine list @filtered-people @selected-person)
 (lambda (state)
   (define filtered (first state))
   (define selected (second state))
   (when (and selected
              (not (memq selected filtered)))
     (:= @selected-person #f)
     (clear-name-fields))))

;; ----------------------------------------
;; Views
;; ----------------------------------------

(define (rich-better-list-group @datas @selected-data render-data on-selected)
  (define @data-list
    (@datas . ~> . (lambda (datas)
                     (indexed-rendered-list datas render-data))))
  (define @selected-index
    (obs-combine
     (lambda (datas selected)
       (and selected
            (index-of datas selected eq?)))
     @datas
     @selected-data))
  (rich-list-group
   @data-list
   @selected-index
   (lambda (new-index)
     (define data
       (safe-list-ref (obs-peek @datas) new-index))
     (on-selected data)
     (void))))

(define (field label v)
  (hpanel
   (text label)
   (spacer)
   v))

(define (no-matches-list-group)
  (define italic/muted
    "font-style: italic; color: #888;")
  (rich-better-list-group
   (@ (list 'no-matches))
   (@ #f)
   (lambda (_)
     (Div (text "No matches")
          #:style italic/muted))
   (lambda (_) (void))))

(define (people-list-group)
  (rich-better-list-group
   @filtered-people
   @selected-person
   ~person
   on-person-selected))

(define (on-person-selected person0)
  (define selected
    (obs-peek @selected-person))
  (define deselect?
    (or (not person0)
        (eq? selected person0)))
  (cond
    [deselect?
     (:= @selected-person #f)
     (clear-name-fields)]
    [else
     (:= @selected-person person0)
     (set-name-fields (person-name person0)
                      (person-surname person0))])
  (void))

(define 7gui-crud-app
  (window
   (container
    (h1 "CRUD")
    (vpanel
     (hpanel
      (text "Filter prefix:")
      (input @prefix
             (lambda (new-text)
               (:= @prefix new-text))))
     (hpanel
      (spacer)
      (vpanel
       (observable-view
        (@filtered-people . ~> . null?)
        (lambda (empty?)
          (if empty?
              (no-matches-list-group)
              (people-list-group)))))
      (spacer)
      (vpanel
       (field "Name:"
              (input @current-name
                     (lambda (text0)
                       (:= @current-name text0))))
       (spacer)
       (field "Surname:"
              (input @current-surname
                     (lambda (text0)
                       (:= @current-surname text0)))))
      (spacer))
     (hpanel
      (button "Create"
              (lambda ()
                (define name
                  (obs-peek @current-name))
                (define surname
                  (obs-peek @current-surname))
                (unless (or (string=? name "")
                            (string=? surname ""))
                  (create name surname)
                  (:= @selected-person #f)
                  (clear-name-fields))
                (void)))
      (button "Update"
              (lambda ()
                (define name
                  (obs-peek @current-name))
                (define surname
                  (obs-peek @current-surname))
                (define p
                  (obs-peek @selected-person))
                (unless (or (string=? name "")
                            (string=? surname ""))
                  (:= @selected-person
                      (update p name surname)))
                (void))
              #:disabled (@selected-visible? . ~> . not))
      (button "Delete"
              (lambda ()
                (define p
                  (obs-peek @selected-person))
                (delete! p)
                (:= @selected-person #f)
                (clear-name-fields))
              #:disabled (@selected-visible? . ~> . not))))
    #:style "max-width: 500px;")))

(define app-renderer
  (render 7gui-crud-app))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
