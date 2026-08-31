#lang webracket/base

(require browser/dom
         js/promise
         web-midi)

(define (set-status! text)
  (js-set! (js-document-body) "textContent" text))

(define input-message-seen? #f)
(define state-change-seen? #f)

(define (message-received raw-event)
  (define event (web-midi-message-event-wrap raw-event))
  (define message (web-midi-message-event-data event))
  (set! input-message-seen?
        (and (= (bytes-length message) 3)
             (= (bytes-ref message 0) 144)
             (= (bytes-ref message 1) 60)
             (= (bytes-ref message 2) 100)))
  (void))

(define (state-changed raw-event)
  (define event (web-midi-connection-event-wrap raw-event))
  (define port (web-midi-connection-event-port event))
  (set! state-change-seen?
        (and (string=? (web-midi-port-id port) "fixture-input")
             (eq? (web-midi-port-state port) 'connected)))
  (void))

(define (finish-open _ignored)
  (if (and input-message-seen? state-change-seen?)
      (set-status! "PASS: static Web MIDI access, ports, bytes, and events")
      (set-status! "FAIL: static Web MIDI fixture events did not arrive"))
  (void))

(define (finish-access raw-access)
  (define access (web-midi-access-wrap raw-access))
  (define input-ids (web-midi-access-input-port-ids access))
  (define output-ids (web-midi-access-output-port-ids access))
  (define input
    (and (positive? (vector-length input-ids))
         (web-midi-access-input access (vector-ref input-ids 0))))
  (define output
    (and (positive? (vector-length output-ids))
         (web-midi-access-output access (vector-ref output-ids 0))))
  (cond
    [(not (and input output))
     (set-status! "FAIL: fixture MIDI ports were not found")]
    [(or (not (string=? (web-midi-port-name input) "Fixture Input"))
         (not (string=? (web-midi-port-name output) "Fixture Output"))
         (web-midi-access-sysex-enabled? access))
     (set-status! "FAIL: fixture MIDI metadata did not match")]
    [else
     (web-midi-access-add-state-change-listener! access state-changed)
     (web-midi-input-add-message-listener! input message-received)
     (web-midi-output-send! output (bytes 144 60 100))
     (web-midi-output-send! output (bytes 128 60 0) 1)
     (js-promise-then (web-midi-port-open input)
                      finish-open
                      (lambda (_reason)
                        (set-status! "FAIL: fixture MIDI input did not open")
                        (void)))])
  (void))

(define (access-rejected _reason)
  ;; Headless browsers commonly expose the method without a MIDI service or
  ;; grantable permission. Reaching this path still proves the static import
  ;; loaded and returned a browser Promise.
  (set-status! "PASS: static Web MIDI access request rejected by this browser")
  (void))

(cond
  [(web-midi-supported?)
   (js-promise-then (web-midi-request-access)
                    finish-access
                    access-rejected)
   (void)]
  [else
   (set-status! "PASS: Web MIDI API unavailable in this headless browser.")])
