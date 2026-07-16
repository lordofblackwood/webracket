#lang webracket/base

;; Browser smoke for the standalone JavaScript Performance FFI module.

(require js/performance
         webracket/primitives)

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-number>= got minimum label)
  (unless (and (number? got)
               (>= got minimum))
    (error 'check-number>=
           (format "~a: got ~s minimum ~s" label got minimum))))

(define (check-external got label)
  (check-true (external? got) label))

(define before (performance-now))
(check-number>= before 0.0 "performance-now")
(check-number>= (performance-time-origin) 0.0 "performance-time-origin")

(performance-set-resource-timing-buffer-size 64)
(performance-clear-marks 'split-ffi-start)
(performance-clear-measures 'split-ffi-measure)
(performance-clear-resource-timings)

(define mark-entry (performance-mark 'split-ffi-start))
(check-external mark-entry "performance-mark result")

(define after-mark (performance-now))
(check-number>= after-mark before "performance-now monotonic")

(define measure-entry (performance-measure 'split-ffi-measure
                                           'split-ffi-start))
(check-external measure-entry "performance-measure result")
(check-external (performance-get-entries) "performance-get-entries result")
(check-external (performance-get-entries-by-name 'split-ffi-start 'mark)
                "performance-get-entries-by-name result")
(check-external (performance-get-entries-by-type 'measure)
                "performance-get-entries-by-type result")
(check-external (performance-to-json) "performance-to-json result")

(define counts (performance-event-counts))
(when counts
  (check-true (performance-event-counts-info? counts)
              "performance-event-counts wrapper")
  (check-true (exact-nonnegative-integer?
               (performance-event-count-map-size counts))
              "performance-event-count-map-size result"))

(performance-clear-marks 'split-ffi-start)
(performance-clear-measures 'split-ffi-measure)

(js-log "js-performance-ffi-ok")
#t
