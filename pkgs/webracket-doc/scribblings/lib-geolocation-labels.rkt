#lang racket/base

(require racket/contract/base)

(provide
  geolocation
  geolocation-raw
  geolocation?
  geolocation-supported?
  make-geolocation-options
  geolocation-options?
  geolocation-options-enable-high-accuracy
  geolocation-options-timeout
  geolocation-options-maximum-age
  geolocation-get-current-position
  geolocation-watch-position
  geolocation-clear-watch!
  geolocation-position
  geolocation-position?
  geolocation-position-raw
  geolocation-position-coordinates
  geolocation-position-timestamp
  geolocation-coordinates
  geolocation-coordinates?
  geolocation-coordinates-raw
  geolocation-coordinates-latitude
  geolocation-coordinates-longitude
  geolocation-coordinates-accuracy
  geolocation-coordinates-altitude
  geolocation-coordinates-altitude-accuracy
  geolocation-coordinates-heading
  geolocation-coordinates-speed
  geolocation-position-error
  geolocation-position-error?
  geolocation-position-error-raw
  geolocation-position-error-code
  geolocation-position-error-message
  (for-label (all-defined-out)))

(define geolocation any/c)
(define geolocation-raw any/c)
(define geolocation? any/c)
(define geolocation-supported? any/c)
(define make-geolocation-options any/c)
(define geolocation-options? any/c)
(define geolocation-options-enable-high-accuracy any/c)
(define geolocation-options-timeout any/c)
(define geolocation-options-maximum-age any/c)
(define geolocation-get-current-position any/c)
(define geolocation-watch-position any/c)
(define geolocation-clear-watch! any/c)
(struct geolocation-position (raw) #:transparent)
(define geolocation-position-coordinates any/c)
(define geolocation-position-timestamp any/c)
(struct geolocation-coordinates (raw) #:transparent)
(define geolocation-coordinates-latitude any/c)
(define geolocation-coordinates-longitude any/c)
(define geolocation-coordinates-accuracy any/c)
(define geolocation-coordinates-altitude any/c)
(define geolocation-coordinates-altitude-accuracy any/c)
(define geolocation-coordinates-heading any/c)
(define geolocation-coordinates-speed any/c)
(struct geolocation-position-error (raw) #:transparent)
(define geolocation-position-error-code any/c)
(define geolocation-position-error-message any/c)
