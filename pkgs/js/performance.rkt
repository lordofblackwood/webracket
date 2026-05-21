#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/performance))

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

(define performance-clear-marks unsafe:js-performance-clear-marks)
(define performance-clear-measures unsafe:js-performance-clear-measures)
(define performance-clear-resource-timings unsafe:js-performance-clear-resource-timings)
(define performance-get-entries unsafe:js-performance-get-entries)
(define performance-get-entries-by-name unsafe:js-performance-get-entries-by-name)
(define performance-get-entries-by-type unsafe:js-performance-get-entries-by-type)
(define performance-mark unsafe:js-performance-mark)
(define performance-measure unsafe:js-performance-measure)
(define performance-now unsafe:js-performance-now)
(define performance-set-resource-timing-buffer-size unsafe:js-performance-set-resource-timing-buffer-size)
(define performance-time-origin unsafe:js-performance-time-origin)
(define performance-to-json unsafe:js-performance-to-json)
