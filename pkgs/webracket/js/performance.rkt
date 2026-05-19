#lang racket/base

(require "../unsafe/performance.rkt")

(provide performance-clear-marks
         performance-clear-measures
         performance-clear-resource-timings
         performance-get-entries
         performance-get-entries-by-name
         performance-get-entries-by-type
         performance-mark
         performance-measure
         performance-now
         performance-set-resource-timing-buffer-size
         performance-time-origin
         performance-to-json)

;; Public JavaScript Performance wrappers. The browser-only raw object accessors
;; stay available from `webracket/unsafe/performance` until we settle a safe
;; extern-value API for WebRacket modules.

(define performance-clear-marks js-performance-clear-marks)
(define performance-clear-measures js-performance-clear-measures)
(define performance-clear-resource-timings js-performance-clear-resource-timings)
(define performance-get-entries js-performance-get-entries)
(define performance-get-entries-by-name js-performance-get-entries-by-name)
(define performance-get-entries-by-type js-performance-get-entries-by-type)
(define performance-mark js-performance-mark)
(define performance-measure js-performance-measure)
(define performance-now js-performance-now)
(define performance-set-resource-timing-buffer-size js-performance-set-resource-timing-buffer-size)
(define performance-time-origin js-performance-time-origin)
(define performance-to-json js-performance-to-json)
