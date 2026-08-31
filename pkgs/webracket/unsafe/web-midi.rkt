#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-web-midi-supported?
 js-web-midi-access?
 js-web-midi-input?
 js-web-midi-output?
 js-web-midi-message-event?
 js-web-midi-connection-event?
 js-web-midi-request-access
 js-web-midi-access-sysex-enabled?
 js-web-midi-access-input-port-ids
 js-web-midi-access-output-port-ids
 js-web-midi-access-input
 js-web-midi-access-output
 js-web-midi-port-id
 js-web-midi-port-name
 js-web-midi-port-manufacturer
 js-web-midi-port-version
 js-web-midi-port-state
 js-web-midi-port-connection
 js-web-midi-port-open
 js-web-midi-port-close
 js-web-midi-output-send!
 js-web-midi-output-send-at!
 js-web-midi-input-add-message-listener!
 js-web-midi-input-remove-message-listener!
 js-web-midi-access-add-state-change-listener!
 js-web-midi-access-remove-state-change-listener!
 js-web-midi-message-event-data
 js-web-midi-connection-event-port)

;; js-web-midi-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-supported? (unsafe-ffi-primitive 'js-web-midi-supported?))

;; js-web-midi-access? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access? (unsafe-ffi-primitive 'js-web-midi-access?))

;; js-web-midi-input? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-input? (unsafe-ffi-primitive 'js-web-midi-input?))

;; js-web-midi-output? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-output? (unsafe-ffi-primitive 'js-web-midi-output?))

;; js-web-midi-message-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-message-event? (unsafe-ffi-primitive 'js-web-midi-message-event?))

;; js-web-midi-connection-event? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-connection-event? (unsafe-ffi-primitive 'js-web-midi-connection-event?))

;; js-web-midi-request-access : ffi (boolean boolean) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-request-access (unsafe-ffi-primitive 'js-web-midi-request-access))

;; js-web-midi-access-sysex-enabled? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-sysex-enabled? (unsafe-ffi-primitive 'js-web-midi-access-sysex-enabled?))

;; js-web-midi-access-input-port-ids : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-input-port-ids (unsafe-ffi-primitive 'js-web-midi-access-input-port-ids))

;; js-web-midi-access-output-port-ids : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-output-port-ids (unsafe-ffi-primitive 'js-web-midi-access-output-port-ids))

;; js-web-midi-access-input : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-input (unsafe-ffi-primitive 'js-web-midi-access-input))

;; js-web-midi-access-output : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-output (unsafe-ffi-primitive 'js-web-midi-access-output))

;; js-web-midi-port-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-id (unsafe-ffi-primitive 'js-web-midi-port-id))

;; js-web-midi-port-name : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-name (unsafe-ffi-primitive 'js-web-midi-port-name))

;; js-web-midi-port-manufacturer : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-manufacturer (unsafe-ffi-primitive 'js-web-midi-port-manufacturer))

;; js-web-midi-port-version : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-version (unsafe-ffi-primitive 'js-web-midi-port-version))

;; js-web-midi-port-state : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-state (unsafe-ffi-primitive 'js-web-midi-port-state))

;; js-web-midi-port-connection : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-connection (unsafe-ffi-primitive 'js-web-midi-port-connection))

;; js-web-midi-port-open : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-open (unsafe-ffi-primitive 'js-web-midi-port-open))

;; js-web-midi-port-close : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-port-close (unsafe-ffi-primitive 'js-web-midi-port-close))

;; js-web-midi-output-send! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-output-send! (unsafe-ffi-primitive 'js-web-midi-output-send!))

;; js-web-midi-output-send-at! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-output-send-at! (unsafe-ffi-primitive 'js-web-midi-output-send-at!))

;; js-web-midi-input-add-message-listener! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-input-add-message-listener! (unsafe-ffi-primitive 'js-web-midi-input-add-message-listener!))

;; js-web-midi-input-remove-message-listener! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-input-remove-message-listener! (unsafe-ffi-primitive 'js-web-midi-input-remove-message-listener!))

;; js-web-midi-access-add-state-change-listener! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-add-state-change-listener! (unsafe-ffi-primitive 'js-web-midi-access-add-state-change-listener!))

;; js-web-midi-access-remove-state-change-listener! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-access-remove-state-change-listener! (unsafe-ffi-primitive 'js-web-midi-access-remove-state-change-listener!))

;; js-web-midi-message-event-data : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-message-event-data (unsafe-ffi-primitive 'js-web-midi-message-event-data))

;; js-web-midi-connection-event-port : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/web-midi.
(define js-web-midi-connection-event-port (unsafe-ffi-primitive 'js-web-midi-connection-event-port))
