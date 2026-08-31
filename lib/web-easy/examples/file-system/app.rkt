#lang webracket/base

(require browser/dom
         file-system
         js/promise
         (only-in webracket/primitives procedure->external))

(define (append-text-node! element text)
  (js-append-child! element (js-create-text-node text)))

(define (set-text! element text)
  (js-set! element "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; color: #172033; background: radial-gradient(circle at top right, #def6ed, #fff9ef 54%, #e8f1ff); font-family: Georgia, serif; }
          main { max-width: 760px; margin: 0 auto; padding: 48px 22px; }
          h1 { font-size: clamp(2.2rem, 8vw, 4.4rem); letter-spacing: -0.055em; margin: 0; }
          .lede { font-size: 1.18rem; max-width: 42rem; line-height: 1.55; }
          .card { margin-top: 28px; padding: 24px; border: 1px solid #b9d9cd; border-radius: 22px; background: rgba(255,255,255,.82); box-shadow: 0 16px 42px rgba(14, 65, 48, .10); }
          button { appearance: none; border: 0; border-radius: 999px; cursor: pointer; padding: 12px 18px; color: white; background: #0c6a55; font: 700 1rem/1 Georgia, serif; }
          button:disabled { cursor: not-allowed; background: #8da99f; }
          #file-system-status { min-height: 1.6em; color: #07513f; font-weight: 700; }
          .note { color: #4a5b66; line-height: 1.45; }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define title (js-create-element "h1"))
(define lede (js-create-element "p"))
(define opfs-card (js-create-element "section"))
(define opfs-title (js-create-element "h2"))
(define status (js-create-element "p"))
(define picker-card (js-create-element "section"))
(define picker-title (js-create-element "h2"))
(define picker-copy (js-create-element "p"))
(define picker-button (js-create-element "button"))

(js-set-attribute! opfs-card "class" "card")
(js-set-attribute! picker-card "class" "card")
(js-set-attribute! status "id" "file-system-status")
(js-set-attribute! picker-copy "class" "note")

(append-text-node! title "File System API")
(append-text-node! lede
                   "The first card verifies a real read/write round trip in this origin's private file system. The button demonstrates the user-selected file path.")
(append-text-node! opfs-title "Origin-private file system")
(append-text-node! picker-title "Read a selected file")
(append-text-node! picker-copy
                   "The browser must receive this call directly from a click. The static wrapper uses the default single-file picker, then reads the selected file as text.")
(append-text-node! picker-button "Choose a text file")

(define (fail! text)
  (set-text! status (string-append "FAIL: " text)))

(define (run-opfs-round-trip!)
  (define directory #f)
  (define handle #f)
  (define writable #f)
  (define (promise-failed _reason)
    (fail! "a File System API Promise was rejected")
    (void))
  (define (finish-text text)
    (if (string=? text "WebRacket File System API")
        (set-text! status "PASS: wrote and read file-system-demo.txt in OPFS.")
        (fail! "OPFS returned unexpected text"))
    (void))
  (define (finish-file raw-file)
    (define file (file-system-file-wrap raw-file))
    (js-promise-then (file-system-file-text file)
                     finish-text
                     promise-failed)
    (void))
  (define (finish-close _ignored)
    (js-promise-then (file-system-file-handle-get-file handle)
                     finish-file
                     promise-failed)
    (void))
  (define (finish-write _ignored)
    (js-promise-then (file-system-writable-file-stream-close writable)
                     finish-close
                     promise-failed)
    (void))
  (define (finish-writable raw-stream)
    (set! writable (file-system-writable-file-stream-wrap raw-stream))
    (js-promise-then (file-system-writable-file-stream-write
                      writable
                      "WebRacket File System API")
                     finish-write
                     promise-failed)
    (void))
  (define (finish-handle raw-handle)
    (set! handle (file-system-file-handle-wrap raw-handle))
    (js-promise-then (file-system-file-handle-create-writable handle)
                     finish-writable
                     promise-failed)
    (void))
  (define (finish-directory raw-directory)
    (set! directory (file-system-directory-handle-wrap raw-directory))
    (js-promise-then (file-system-directory-get-file-handle
                      directory
                      "file-system-demo.txt"
                      #t)
                     finish-handle
                     promise-failed)
    (void))
  (js-promise-then (file-system-origin-private-directory)
                   finish-directory
                   promise-failed)
  (void))

(define (read-picked-file!)
  (define (picker-failed _reason)
    (set-text! picker-copy "The picker was dismissed or the browser denied file access.")
    (void))
  (define (show-text text)
    (set-text! picker-copy (string-append "Selected-file text: " text))
    (void))
  (define (read-file raw-file)
    (js-promise-then (file-system-file-text (file-system-file-wrap raw-file))
                     show-text
                     picker-failed)
    (void))
  (define (get-file raw-handle)
    (define handle (file-system-file-handle-wrap raw-handle))
    (js-promise-then (file-system-file-handle-get-file handle)
                     read-file
                     picker-failed)
    (void))
  (js-promise-then (file-system-pick-open-file)
                   get-file
                   picker-failed)
  (void))

(js-append-child! opfs-card opfs-title)
(js-append-child! opfs-card status)
(js-append-child! picker-card picker-title)
(js-append-child! picker-card picker-copy)
(js-append-child! picker-card picker-button)
(js-append-child! main title)
(js-append-child! main lede)
(js-append-child! main opfs-card)
(js-append-child! main picker-card)
(js-append-child! body main)

(cond
  [(file-system-supported?)
   (set-text! status "Running an origin-private file-system round trip...")
   (run-opfs-round-trip!)]
  [else
   (fail! "origin-private file-system storage is not available in this browser.")])

(if (file-system-open-picker-supported?)
    (js-add-event-listener!
     picker-button
     "click"
     (procedure->external (lambda (_event) (read-picked-file!) (void))))
    (begin
      (js-set! picker-button "disabled" #t)
      (set-text! picker-copy "This browser does not expose showOpenFilePicker().")))
