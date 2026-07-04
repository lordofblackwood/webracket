#lang racket

(provide time-runtime-step
         runtime-metric-add!
         runtime-metric-add/computed!)

(require "../private/parameters.rkt"
         "../private/timings.rkt")

;; time-runtime-step : string? (-> any/c) -> any/c
;;   Run thunk, preserving multiple values and recording elapsed time when enabled.
(define (time-runtime-step label thunk)
  (if (current-runtime-timing-rows)
      (let-values ([(vals ms)
                    (with-timing
                      (lambda ()
                        (call-with-values thunk list)))])
        (current-runtime-timing-rows
         (cons (list label ms) (current-runtime-timing-rows)))
        (apply values vals))
      (thunk)))

;; runtime-metric-add! : string? any/c -> void?
;;   Record a stringified runtime metric when metric rows are active.
(define (runtime-metric-add! label value)
  (when (current-runtime-metric-rows)
    (current-runtime-metric-rows
     (cons (list label (~a value)) (current-runtime-metric-rows)))))

;; runtime-metric-add/computed! : string? (-> any/c) -> void?
;;   Compute and record a runtime metric only when metric rows are active.
(define (runtime-metric-add/computed! label thunk)
  (when (current-runtime-metric-rows)
    (runtime-metric-add! label (thunk))))

(module+ test
  (require rackunit)

  (parameterize ([current-runtime-timing-rows '()])
    (define-values (a b)
      (time-runtime-step "multi-value-step"
                         (lambda ()
                           (values 'a 'b))))
    (check-equal? (list a b) '(a b))
    (check-equal? (length (current-runtime-timing-rows)) 1)
    (check-equal? (first (first (current-runtime-timing-rows)))
                  "multi-value-step"))

  (parameterize ([current-runtime-metric-rows '()])
    (runtime-metric-add! "direct" 17)
    (runtime-metric-add/computed! "computed" (lambda () 'value))
    (check-equal? (map first (current-runtime-metric-rows))
                  '("computed" "direct"))
    (check-equal? (map second (current-runtime-metric-rows))
                  '("value" "17")))

  (define computed? #f)
  (parameterize ([current-runtime-metric-rows #f])
    (runtime-metric-add/computed! "disabled"
                                  (lambda ()
                                    (set! computed? #t)
                                    'ignored)))
  (check-false computed?))
