#lang racket/base

(require racket/contract/base)

(provide web-speech-synthesis-supported?
         web-speech-recognition-supported?
         speech-synthesis
         speech-synthesis?
         speech-synthesis-raw
         make-speech-utterance
         make-speech-utterance-options
         speech-utterance?
         speech-utterance-raw
         speech-synthesis-speak!
         speech-synthesis-cancel!
         speech-synthesis-pause!
         speech-synthesis-resume!
         speech-synthesis-speaking?
         speech-synthesis-paused?
         speech-synthesis-pending?
         speech-synthesis-voices
         speech-voice?
         speech-voice-raw
         speech-voice-name
         speech-voice-lang
         speech-voice-default?
         speech-voice-local-service?
         speech-voice-uri
         speech-utterance-set-voice!
         speech-utterance-on-end!
         speech-utterance-on-error!
         (struct-out speech-synthesis-info)
         (struct-out speech-utterance-info)
         (struct-out speech-voice-info)
         (struct-out speech-utterance-options)
         (for-label (all-defined-out)))

(define web-speech-synthesis-supported? any/c)
(define web-speech-recognition-supported? any/c)
(define speech-synthesis any/c)
(define speech-synthesis? any/c)
(define speech-synthesis-raw any/c)
(define make-speech-utterance any/c)
(define make-speech-utterance-options any/c)
(define speech-utterance? any/c)
(define speech-utterance-raw any/c)
(define speech-synthesis-speak! any/c)
(define speech-synthesis-cancel! any/c)
(define speech-synthesis-pause! any/c)
(define speech-synthesis-resume! any/c)
(define speech-synthesis-speaking? any/c)
(define speech-synthesis-paused? any/c)
(define speech-synthesis-pending? any/c)
(define speech-synthesis-voices any/c)
(define speech-voice? any/c)
(define speech-voice-raw any/c)
(define speech-voice-name any/c)
(define speech-voice-lang any/c)
(define speech-voice-default? any/c)
(define speech-voice-local-service? any/c)
(define speech-voice-uri any/c)
(define speech-utterance-set-voice! any/c)
(define speech-utterance-on-end! any/c)
(define speech-utterance-on-error! any/c)
(struct speech-synthesis-info (raw) #:transparent)
(struct speech-utterance-info (raw) #:transparent)
(struct speech-voice-info (raw) #:transparent)
(struct speech-utterance-options (lang volume rate pitch) #:transparent)
