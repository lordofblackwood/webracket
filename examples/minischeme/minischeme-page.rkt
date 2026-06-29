#lang webracket/base

;;;
;;; MiniScheme page (module-based web-easy example)
;;; Repl page that reuses the copied interpreter in minischeme.rkt.
;;;

(require browser/dom
         web-easy
         "minischeme.rkt")

(define sample-program
  "(define (factorial n)\n  (if (zero? n)\n      1\n      (* n (factorial (- n 1)))))\n(factorial 6)\n")

(define @source (obs sample-program))
(define @output (obs "MiniScheme ready."))
(define @status (obs "loading"))

(define status-banner (js-create-element "div"))

;; mark-status! : string? string? -> void?
;;   Update the browser status marker for smoke tests and manual checks.
(define (mark-status! state message)
  (js-set-attribute! status-banner "data-state" state)
  (js-set! status-banner "textContent" message)
  (obs-set! @status message))

(define (run-program!)
  (define source (obs-peek @source))
  (mark-status! "running" "running")
  (with-handlers ([exn? (lambda (e)
                          (obs-set! @output (format "MiniScheme error: ~a" (exn-message e)))
                          (mark-status! "error" (exn-message e)))])
    (obs-set! @output (minischeme-process-input source))
    (mark-status! "ready" "ready")))

(define (reset-minischeme-state!)
  (minischeme-reset-state!)
  (obs-set! @output "MiniScheme state has been reset.")
  (mark-status! "ready" "ready"))

(define minischeme-page
  (window
   (container
    (vpanel
     (heading 2 "MiniScheme REPL")
     (text "A MiniScheme REPL built directly from examples/minischeme/minischeme.rkt.")

     (text "Program")
     (textarea @source
               (lambda (next-source) (obs-set! @source next-source))
               #:rows 18
               #:textarea-attrs '((spellcheck "false")
                                  (placeholder "Type MiniScheme forms here.")))

     (hpanel
      (button "Run" run-program!)
      (button "Reset State" reset-minischeme-state!)
      (button "Clear Output"
              (lambda ()
                (obs-set! @output "")
                (mark-status! "ready" "ready"))))

     (hpanel
      (text "Status: ")
      (text @status))

     (text "Output")
     (textarea @output
               (lambda (_new-value) (void))
               #:rows 12
               #:textarea-attrs '((readonly "readonly")
                                  (spellcheck "false")))))))

(define app-renderer (render minischeme-page))

(js-set-attribute! status-banner "id" "status")
(js-set-attribute! status-banner "data-state" "loading")
(js-set-attribute! status-banner
                   "style"
                   "margin:0 0 18px;padding:8px 12px;border-radius:999px;display:inline-flex;align-items:center;gap:8px;background:#e0e7ff;color:#3730a3;font-size:12px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;")
(js-set! status-banner "textContent" "loading")

(mount-renderer! app-renderer)
(js-append-child! (js-document-body) status-banner)
(mark-status! "ready" "ready")
