#lang webracket/base

(require browser/dom
         browser/event
         web-workers
         (only-in webracket/primitives
                  procedure->external))

(define current-worker #f)

(define (append-text-node! elem text)
  (js-append-child! elem (js-create-text-node text)))

(define (set-status! elem text)
  (js-set! elem "textContent" text))

(define style (js-create-element "style"))
(js-set! style "textContent"
         "body { margin: 0; font-family: 'IBM Plex Sans', sans-serif; background: #f8fafc; color: #0f172a; }
          main { max-width: 760px; margin: 0 auto; padding: 32px 20px; }
          .actions { display: flex; gap: 12px; flex-wrap: wrap; margin: 18px 0; }
          button { border: 0; border-radius: 999px; padding: 12px 18px; cursor: pointer; font-weight: 700; }
          .primary { background: #0f766e; color: white; }
          .secondary { background: #dbeafe; color: #1d4ed8; }
          .danger { background: #fee2e2; color: #b91c1c; }
          .log { background: white; border: 1px solid #dbe3ec; border-radius: 18px; padding: 16px; min-height: 80px; box-shadow: 0 12px 30px rgba(15, 23, 42, 0.08); }")
(js-append-child! (js-document-head) style)

(define body (js-document-body))
(define main (js-create-element "main"))
(define h1 (js-create-element "h1"))
(define intro (js-create-element "p"))
(define actions (js-create-element "div"))
(define start-button (js-create-element "button"))
(define ping-button (js-create-element "button"))
(define stop-button (js-create-element "button"))
(define status (js-create-element "p"))
(define log-box (js-create-element "div"))

(js-set-attribute! actions "class" "actions")
(js-set-attribute! start-button "class" "primary")
(js-set-attribute! ping-button "class" "secondary")
(js-set-attribute! stop-button "class" "danger")
(js-set-attribute! log-box "class" "log")

(append-text-node! h1 "Web Worker Demo")
(append-text-node! intro "Create a dedicated worker, send it a message, and watch the worker reply back on the main thread.")
(append-text-node! start-button "Start worker")
(append-text-node! ping-button "Send ping")
(append-text-node! stop-button "Terminate worker")

(define (set-log! text)
  (set-status! log-box text))

(define (set-main-status! text)
  (set-status! status text))

(define (install-worker-handlers! value)
  (worker-onmessage!
   value
   (lambda (evt)
     (set-log! (format "message: ~s" (message-event-data evt)))))
  (worker-onerror!
   value
   (lambda (_evt)
     (set-main-status! "Worker reported an error."))))

(define (start-worker!)
  (cond
    [(not (worker-supported?))
     (set-main-status! "Workers are not available here.")]
    [else
     (when current-worker
       (worker-terminate! current-worker))
     (set! current-worker
           (make-worker "worker.js"
                        (make-worker-options 'classic 'demo-worker #f)))
     (install-worker-handlers! current-worker)
     (set-main-status! "Started worker.")
     (set-log! "waiting for worker reply...")]))

(define (send-ping!)
  (cond
    [current-worker
     (worker-post-message! current-worker (vector "ping" 42))
     (set-main-status! "Sent ping to worker.")]
    [else
     (set-main-status! "Start the worker first.")]))

(define (stop-worker!)
  (cond
    [current-worker
     (worker-terminate! current-worker)
     (set! current-worker #f)
     (set-main-status! "Worker terminated.")
     (set-log! "worker stopped")]
    [else
     (set-main-status! "No worker is running.")]))

(set-main-status! "Ready")
(set-log! "no worker yet")

(js-append-child! actions start-button)
(js-append-child! actions ping-button)
(js-append-child! actions stop-button)
(js-append-child! main h1)
(js-append-child! main intro)
(js-append-child! main actions)
(js-append-child! main status)
(js-append-child! main log-box)
(js-append-child! body main)

(js-add-event-listener! start-button "click" (procedure->external (lambda (_evt) (start-worker!) (void))))
(js-add-event-listener! ping-button "click" (procedure->external (lambda (_evt) (send-ping!) (void))))
(js-add-event-listener! stop-button "click" (procedure->external (lambda (_evt) (stop-worker!) (void))))
