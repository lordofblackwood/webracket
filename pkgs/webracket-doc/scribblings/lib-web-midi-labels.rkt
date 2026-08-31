#lang racket/base

(require racket/contract/base)

(provide web-midi-supported?
         web-midi-message?
         web-midi-timestamp?
         web-midi-access?
         web-midi-input?
         web-midi-output?
         web-midi-port?
         web-midi-message-event?
         web-midi-connection-event?
         web-midi-access-wrap
         web-midi-input-wrap
         web-midi-output-wrap
         web-midi-port-wrap
         web-midi-message-event-wrap
         web-midi-connection-event-wrap
         web-midi-request-access
         web-midi-access-sysex-enabled?
         web-midi-access-input-port-ids
         web-midi-access-output-port-ids
         web-midi-access-input
         web-midi-access-output
         web-midi-port-id
         web-midi-port-name
         web-midi-port-manufacturer
         web-midi-port-version
         web-midi-port-state
         web-midi-port-connection
         web-midi-port-open
         web-midi-port-close
         web-midi-output-send!
         web-midi-input-add-message-listener!
         web-midi-input-remove-message-listener!
         web-midi-access-add-state-change-listener!
         web-midi-access-remove-state-change-listener!
         web-midi-message-event-data
         web-midi-connection-event-port
         (for-label (all-defined-out)))

(define web-midi-supported? any/c)
(define web-midi-message? any/c)
(define web-midi-timestamp? any/c)
(define web-midi-access? any/c)
(define web-midi-input? any/c)
(define web-midi-output? any/c)
(define web-midi-port? any/c)
(define web-midi-message-event? any/c)
(define web-midi-connection-event? any/c)
(define web-midi-access-wrap any/c)
(define web-midi-input-wrap any/c)
(define web-midi-output-wrap any/c)
(define web-midi-port-wrap any/c)
(define web-midi-message-event-wrap any/c)
(define web-midi-connection-event-wrap any/c)
(define web-midi-request-access any/c)
(define web-midi-access-sysex-enabled? any/c)
(define web-midi-access-input-port-ids any/c)
(define web-midi-access-output-port-ids any/c)
(define web-midi-access-input any/c)
(define web-midi-access-output any/c)
(define web-midi-port-id any/c)
(define web-midi-port-name any/c)
(define web-midi-port-manufacturer any/c)
(define web-midi-port-version any/c)
(define web-midi-port-state any/c)
(define web-midi-port-connection any/c)
(define web-midi-port-open any/c)
(define web-midi-port-close any/c)
(define web-midi-output-send! any/c)
(define web-midi-input-add-message-listener! any/c)
(define web-midi-input-remove-message-listener! any/c)
(define web-midi-access-add-state-change-listener! any/c)
(define web-midi-access-remove-state-change-listener! any/c)
(define web-midi-message-event-data any/c)
(define web-midi-connection-event-port any/c)
