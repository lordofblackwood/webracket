#lang racket/base

(require (only-in "../primitives.rkt" unsafe-ffi-primitive))

(provide js-performance-clear-marks
         js-performance-clear-measures
         js-performance-clear-resource-timings
         js-performance-event-count-map-size
         js-performance-event-counts
         js-performance-get-entries
         js-performance-get-entries-by-name
         js-performance-get-entries-by-type
         js-performance-interaction-count
         js-performance-mark
         js-performance-measure
         js-performance-measure-user-agent-specific-memory
         js-performance-memory
         js-performance-memory-info-js-heap-size-limit
         js-performance-memory-info-total-js-heap-size
         js-performance-memory-info-used-js-heap-size
         js-performance-now
         js-performance-set-resource-timing-buffer-size
         js-performance-time-origin
         js-performance-to-json)

;; Raw Performance API bindings generated from `ffi/performance.ffi`.
;; The driver infers `performance.ffi` automatically from this module provider.

(define js-performance-clear-marks (unsafe-ffi-primitive 'js-performance-clear-marks))
(define js-performance-clear-measures (unsafe-ffi-primitive 'js-performance-clear-measures))
(define js-performance-clear-resource-timings (unsafe-ffi-primitive 'js-performance-clear-resource-timings))
(define js-performance-event-count-map-size (unsafe-ffi-primitive 'js-performance-event-count-map-size))
(define js-performance-event-counts (unsafe-ffi-primitive 'js-performance-event-counts))
(define js-performance-get-entries (unsafe-ffi-primitive 'js-performance-get-entries))
(define js-performance-get-entries-by-name (unsafe-ffi-primitive 'js-performance-get-entries-by-name))
(define js-performance-get-entries-by-type (unsafe-ffi-primitive 'js-performance-get-entries-by-type))
(define js-performance-interaction-count (unsafe-ffi-primitive 'js-performance-interaction-count))
(define js-performance-mark (unsafe-ffi-primitive 'js-performance-mark))
(define js-performance-measure (unsafe-ffi-primitive 'js-performance-measure))
(define js-performance-measure-user-agent-specific-memory (unsafe-ffi-primitive 'js-performance-measure-user-agent-specific-memory))
(define js-performance-memory (unsafe-ffi-primitive 'js-performance-memory))
(define js-performance-memory-info-js-heap-size-limit (unsafe-ffi-primitive 'js-performance-memory-info-js-heap-size-limit))
(define js-performance-memory-info-total-js-heap-size (unsafe-ffi-primitive 'js-performance-memory-info-total-js-heap-size))
(define js-performance-memory-info-used-js-heap-size (unsafe-ffi-primitive 'js-performance-memory-info-used-js-heap-size))
(define js-performance-now (unsafe-ffi-primitive 'js-performance-now))
(define js-performance-set-resource-timing-buffer-size (unsafe-ffi-primitive 'js-performance-set-resource-timing-buffer-size))
(define js-performance-time-origin (unsafe-ffi-primitive 'js-performance-time-origin))
(define js-performance-to-json (unsafe-ffi-primitive 'js-performance-to-json))
