#lang webracket/base

(require browser/dom
         clipboard
         js/promise
         (only-in webracket/primitives
                  procedure->external))

;;;
;;; Clipboard example
;;;
;;; This example creates a small copy/paste playground that exercises the
;;; module-based `clipboard` wrapper.

(define page-css
  (string-append "body {\n"
                 "  margin: 0;\n"
                 "  min-height: 100vh;\n"
                 "  background: linear-gradient(180deg, #f5f7fb 0%, #edf2f7 100%);\n"
                 "  font-family: 'IBM Plex Sans', 'Segoe UI', sans-serif;\n"
                 "  color: #14213d;\n"
                 "}\n"
                 ".clipboard-demo {\n"
                 "  max-width: 760px;\n"
                 "  margin: 0 auto;\n"
                 "  padding: 48px 20px 72px;\n"
                 "}\n"
                 ".clipboard-card {\n"
                 "  background: rgba(255, 255, 255, 0.92);\n"
                 "  border: 1px solid rgba(20, 33, 61, 0.08);\n"
                 "  border-radius: 24px;\n"
                 "  box-shadow: 0 20px 50px rgba(20, 33, 61, 0.10);\n"
                 "  padding: 28px;\n"
                 "}\n"
                 "h1 {\n"
                 "  margin: 0 0 10px;\n"
                 "  font-size: 34px;\n"
                 "  letter-spacing: -0.03em;\n"
                 "}\n"
                 "p {\n"
                 "  margin: 0;\n"
                 "  line-height: 1.6;\n"
                 "  color: #445166;\n"
                 "}\n"
                 "textarea {\n"
                 "  width: 100%;\n"
                 "  min-height: 220px;\n"
                 "  margin-top: 22px;\n"
                 "  padding: 16px 18px;\n"
                 "  box-sizing: border-box;\n"
                 "  border-radius: 18px;\n"
                 "  border: 1px solid #cbd5e1;\n"
                 "  background: #fff;\n"
                 "  color: #0f172a;\n"
                 "  font: 500 16px/1.55 'IBM Plex Mono', 'SFMono-Regular', monospace;\n"
                 "  resize: vertical;\n"
                 "}\n"
                 ".actions {\n"
                 "  display: flex;\n"
                 "  gap: 12px;\n"
                 "  flex-wrap: wrap;\n"
                 "  margin-top: 18px;\n"
                 "}\n"
                 "button {\n"
                 "  appearance: none;\n"
                 "  border: 0;\n"
                 "  border-radius: 999px;\n"
                 "  padding: 12px 18px;\n"
                 "  font: 700 14px/1 'IBM Plex Sans', 'Segoe UI', sans-serif;\n"
                 "  letter-spacing: 0.02em;\n"
                 "  cursor: pointer;\n"
                 "}\n"
                 ".copy {\n"
                 "  background: #14213d;\n"
                 "  color: #fff;\n"
                 "}\n"
                 ".paste {\n"
                 "  background: #fca311;\n"
                 "  color: #1f2937;\n"
                 "}\n"
                 ".status {\n"
                 "  margin-top: 18px;\n"
                 "  padding: 12px 14px;\n"
                 "  border-radius: 14px;\n"
                 "  background: #e8eef8;\n"
                 "  color: #1d3557;\n"
                 "  font-size: 14px;\n"
                 "  font-weight: 600;\n"
                 "}\n"
                 ".hint {\n"
                 "  margin-top: 14px;\n"
                 "  font-size: 13px;\n"
                 "  color: #5c677d;\n"
                 "}\n"
                 "@media (max-width: 640px) {\n"
                 "  .clipboard-demo {\n"
                 "    padding-top: 28px;\n"
                 "  }\n"
                 "  .clipboard-card {\n"
                 "    padding: 20px;\n"
                 "  }\n"
                 "}\n"))

(define initial-text
  "Clipboard demo text.\n\nEdit this textarea, then click Copy text or Paste text.")

(define body #f)
(define text-area #f)
(define status #f)
(define copy-button #f)
(define paste-button #f)
(define current-clipboard #f)

;; set-status! : string? -> void?
;;   Update the status banner text.
(define (set-status! text)
  (when status
    (js-set! status "textContent" text)))

;; promise-handle : js-promise? (-> any/c any/c) (or/c #f (-> any/c any/c)) -> void?
;;   Attach success and failure handlers to a browser Promise-like value.
(define (promise-handle promise on-success [on-failure #f])
  (define chained
    (js-promise-then
     promise
     (lambda (value)
       (on-success value)
       (void))))
  (when on-failure
    (js-promise-catch
     chained
     (lambda (err)
       (on-failure err)
       (void))))
  (void))

;; install-style! : -> void?
;;   Inject the example stylesheet into the page head.
(define (install-style!)
  (define style (js-create-element "style"))
  (js-set! style "textContent" page-css)
  (js-append-child! (js-document-head) style))

;; append-text-node! : extern/raw string? -> void?
;;   Append a text node to elem.
(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

;; build-layout! : -> void?
;;   Construct the demo UI.
(define (build-layout!)
  (set! body (js-document-body))
  (define shell (js-create-element "main"))
  (define card (js-create-element "section"))
  (define title (js-create-element "h1"))
  (define intro (js-create-element "p"))
  (define actions (js-create-element "div"))
  (define hint (js-create-element "p"))

  (set! text-area (js-create-element "textarea"))
  (set! copy-button (js-create-element "button"))
  (set! paste-button (js-create-element "button"))
  (set! status (js-create-element "div"))

  (js-set-attribute! shell "class" "clipboard-demo")
  (js-set-attribute! card "class" "clipboard-card")
  (js-set-attribute! actions "class" "actions")
  (js-set-attribute! copy-button "class" "copy")
  (js-set-attribute! paste-button "class" "paste")
  (js-set-attribute! status "class" "status")
  (js-set-attribute! hint "class" "hint")
  (js-set-attribute! text-area "spellcheck" "false")

  (append-text-node! title "Clipboard API playground")
  (append-text-node! intro "This example uses the module-based clipboard wrapper. Copy writes the textarea text to navigator.clipboard; Paste reads it back into the textarea.")
  (append-text-node! copy-button "Copy text")
  (append-text-node! paste-button "Paste text")
  (append-text-node! hint "Clipboard access usually requires a secure context and a user-initiated click.")

  (js-set! text-area "value" initial-text)
  (set-status! "loading")

  (js-append-child! actions copy-button)
  (js-append-child! actions paste-button)
  (js-append-child! card title)
  (js-append-child! card intro)
  (js-append-child! card text-area)
  (js-append-child! card actions)
  (js-append-child! card status)
  (js-append-child! card hint)
  (js-append-child! shell card)
  (js-append-child! body shell))

;; disable-actions! : string? -> void?
;;   Disable both action buttons and explain why.
(define (disable-actions! message)
  (js-set! copy-button "disabled" #t)
  (js-set! paste-button "disabled" #t)
  (set-status! message))

;; on-copy : any/c -> void?
;;   Copy the textarea contents into navigator.clipboard.
(define (on-copy _evt)
  (define text (js-ref text-area "value"))
  (set-status! "Copying text to the clipboard...")
  (promise-handle
   (clipboard-write-text! current-clipboard text)
   (lambda (_ignored)
     (set-status! "Copied the textarea contents to the clipboard."))
   (lambda (_err)
     (set-status! "Clipboard write failed. The browser may require HTTPS or stricter permissions."))))

;; on-paste : any/c -> void?
;;   Read text from navigator.clipboard into the textarea.
(define (on-paste _evt)
  (set-status! "Reading text from the clipboard...")
  (promise-handle
   (clipboard-read-text current-clipboard)
   (lambda (text)
     (js-set! text-area "value" text)
     (set-status! "Read text from the clipboard into the textarea."))
   (lambda (_err)
     (set-status! "Clipboard read failed. The browser may require HTTPS, focus, or a fresh user gesture."))))

;; install-handlers! : -> void?
;;   Attach click handlers to the copy and paste buttons.
(define (install-handlers!)
  (js-add-event-listener! copy-button "click" (procedure->external on-copy))
  (js-add-event-listener! paste-button "click" (procedure->external on-paste)))

(install-style!)
(build-layout!)
(set! current-clipboard (clipboard))

(cond
  [current-clipboard
   (install-handlers!)
   (set-status! "Clipboard ready. Use the buttons to write or read plain text.")]
  [else
   (disable-actions! "Clipboard API is not available here. Try a secure browser page with clipboard permissions.")])
