#lang webracket/base

(require racket/string
         web-easy)

;; TODO Lists
;;
;; Module-based port of the legacy `(include-lib web-easy)` example.
;; Exercises keyed list rendering, checkboxes, edit mode, and summary views.

(define (~a* . xs)
  (string-append* (map (lambda (x) (format "~a" x))
                       xs)))

;; ----------------------------------------
;; Data representation
;; ----------------------------------------

(struct todo (id done? text) #:transparent)

(define (set-todo-done entry done?)
  (todo (todo-id entry)
        done?
        (todo-text entry)))

(define (set-todo-text entry text)
  (todo (todo-id entry)
        (todo-done? entry)
        text))

(define (todo-not-done? entry)
  (not (todo-done? entry)))

(define tasks
  '("laundry"          "get groceries"         "wash dishes"       "vacuum apartment"
    "take out trash"   "water plants"          "pay bills"         "check email"
    "read a book"      "exercise"              "go for a walk"     "call a friend"
    "cook dinner"      "make breakfast"        "organize desk"     "backup files"
    "update software"  "review notes"          "study programming" "practice guitar"
    "learn a new word" "tidy bedroom"          "sort laundry"      "fold clothes"
    "iron shirt"       "clean kitchen counter" "wipe table"        "empty dishwasher"
    "load dishwasher"  "clean fridge"          "buy vegetables"    "buy fruit"
    "prepare lunch"    "stretch"               "meditate"          "check calendar"
    "review goals"     "practice typing"       "delete old files"  "clean keyboard"
    "charge devices"   "refill water bottle"   "take vitamins"     "review budget"
    "plan weekend"     "sleep early"           "clean bathroom"    "write journal"
    "plan meals"       "write to-do list"))

(define next-task-index 0)

(define (next-task)
  (define task
    (list-ref tasks next-task-index))
  (set! next-task-index
        (remainder (add1 next-task-index)
                   (length tasks)))
  task)

;; ----------------------------------------
;; Model
;; ----------------------------------------

(define @draft
  (@ (next-task)))

(define @next-id
  (@ 6))

(define @todos
  (@ (list (todo 1 #f (next-task))
           (todo 2 #f (next-task))
           (todo 3 #f (next-task))
           (todo 4 #f (next-task))
           (todo 5 #f (next-task)))))

(define @editing-id
  (@ #f))

(define @editing-text
  (@ ""))

(define (toggle-todo! id done?)
  (obs-update! @todos
               (lambda (todos)
                 (map (lambda (entry)
                        (if (= (todo-id entry) id)
                            (set-todo-done entry done?)
                            entry))
                      todos)))
  (void))

(define (mark-all-done!)
  (obs-update! @todos
               (lambda (todos)
                 (map (lambda (entry)
                        (set-todo-done entry #t))
                      todos)))
  (void))

(define (add-todo!)
  (define label
    (obs-peek @draft))
  (unless (string=? label "")
    (define id
      (obs-peek @next-id))
    (obs-update! @todos
                 (lambda (todos)
                   (append todos
                           (list (todo id #f label)))))
    (obs-update! @next-id add1)
    (obs-set! @draft (next-task))))

(define (start-edit! entry)
  (obs-set! @editing-id (todo-id entry))
  (obs-set! @editing-text (todo-text entry)))

(define (cancel-edit!)
  (obs-set! @editing-id #f)
  (obs-set! @editing-text ""))

(define (save-edit! id)
  (define new-text
    (obs-peek @editing-text))
  (obs-update! @todos
               (lambda (todos)
                 (map (lambda (entry)
                        (if (= (todo-id entry) id)
                            (set-todo-text entry new-text)
                            entry))
                      todos)))
  (cancel-edit!))

(define (clear-done!)
  (obs-update! @todos
               (lambda (todos)
                 (filter todo-not-done? todos)))
  (cancel-edit!))

;; ----------------------------------------
;; View
;; ----------------------------------------

(define app-renderer
  (render
   (window
    (container
     (vpanel
      (h1 "The TODO List")
      (text "Enter an item. ")
      (text "Add the item to the list using either the Add button, or press <enter>.")
      (h2 "The List")
      (list-view @todos
                 (lambda (_key entry)
                   (define id
                     (todo-id entry))
                   (define done?
                     (todo-done? entry))
                   (define label
                     (todo-text entry))
                   (hpanel
                    (checkbox done?
                              (lambda (new-value)
                                (toggle-todo! id new-value)))
                    (if-view (~> @editing-id
                                 (lambda (editing-id)
                                   (and editing-id
                                        (= editing-id id))))
                             (hpanel
                              (input @editing-text
                                     (lambda (new-value)
                                       (:= @editing-text new-value)))
                              (button "save"
                                      (lambda () (save-edit! id)))
                              (button "cancel" cancel-edit!))
                             (hpanel
                              (text label)
                              (button "edit"
                                      (lambda () (start-edit! entry)))))))
                 todo-id)
      (spacer)
      (hpanel
       (button "All done!" mark-all-done!)
       (button "Remove done items" clear-done!))
      (h2 "New Item")
      (grid '(50 50)
            (vpanel
             (input @draft
                    (lambda (new-value)
                      (:= @draft new-value))
                    add-todo!)
             (hpanel
              (button "Add" add-todo!)))
            (spacer))
      (h2 "Summary")
      (text (~> @todos
                (lambda (todos)
                  (~a* "Total:" (length todos)))))
      (text (~> @todos
                (lambda (todos)
                  (~a* "Done:" (length (filter todo-done? todos))))))
      (text (~> @todos
                (lambda (todos)
                  (~a* "To Do:" (length (filter todo-not-done? todos)))))))))))

(define light-theme
  (theme 'light
         "we-theme-light"
         "web-easy-core.css"
         "theme-light.css"
         #f))

(define theme-manager
  (install-theme-manager! light-theme))

(mount-renderer! app-renderer)
