#lang racket

(provide time-runtime-step
         runtime-metric-add!
         runtime-metric-add/computed!
         runtime-record-built-module-metrics!
         runtime-record-split-module-metrics!
         runtime-record-tree-shake-retention-metrics!
         runtime-record-tree-shake-final-metrics!)

(require "../private/parameters.rkt"
         "../private/timings.rkt"
         (only-in "module-forms.rkt"
                  module-byte-size
                  module-data-name
                  module-export-count
                  module-func-count
                  module-global-count
                  module-global-name
                  symbol-prefix-count))

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

;; runtime-record-built-module-metrics! : list? -> void?
;;   Record whole-module size and declaration counts before pruning.
(define (runtime-record-built-module-metrics! full-module)
  (runtime-metric-add/computed! "runtime:module-bytes-before-prune"
                                (lambda ()
                                  (module-byte-size full-module)))
  (runtime-metric-add! "runtime:function-count-before-prune"
                       (module-func-count full-module))
  (runtime-metric-add! "runtime:global-count-before-prune"
                       (module-global-count full-module))
  (runtime-metric-add! "runtime:export-count-before-prune"
                       (module-export-count full-module)))

;; module-form-global-names : (listof datum?) -> (listof symbol?)
;;   Return named globals from module body forms.
(define (module-form-global-names forms)
  (for/list ([form (in-list forms)]
             #:do [(define name (module-global-name form))]
             #:when name)
    name))

;; module-form-data-names : (listof datum?) -> (listof symbol?)
;;   Return named data segments from module body forms.
(define (module-form-data-names forms)
  (for/list ([form (in-list forms)]
             #:do [(define name (module-data-name form))]
             #:when name)
    name))

;; runtime-record-split-module-metrics! : list? list? (listof symbol?) list? -> void?
;;   Record runtime/program split counts and runtime constant prefix counts.
(define (runtime-record-split-module-metrics! runtime-forms
                                              program-forms
                                              program-function-names
                                              top-level-variable-declarations)
  (runtime-metric-add! "runtime:runtime-form-count-before-prune"
                       (length runtime-forms))
  (runtime-metric-add! "runtime:program-form-count-before-prune"
                       (length program-forms))
  (define runtime-only-global-names
    (module-form-global-names runtime-forms))
  (define runtime-only-data-names
    (module-form-data-names runtime-forms))
  (runtime-metric-add! "runtime:runtime-string-global-count"
                       (symbol-prefix-count runtime-only-global-names "$string:"))
  (runtime-metric-add! "runtime:runtime-bytes-global-count"
                       (symbol-prefix-count runtime-only-global-names "$bytes:"))
  (runtime-metric-add! "runtime:runtime-symbol-global-count"
                       (symbol-prefix-count runtime-only-global-names "$symbol:"))
  (runtime-metric-add! "runtime:runtime-string-data-count"
                       (symbol-prefix-count runtime-only-data-names "$string-data:"))
  (runtime-metric-add! "runtime:runtime-bytes-data-count"
                       (symbol-prefix-count runtime-only-data-names "$bytes-data:"))
  (runtime-metric-add! "runtime:runtime-symbol-data-count"
                       (symbol-prefix-count runtime-only-data-names "$symbol-data:"))
  (runtime-metric-add! "runtime:program-function-count-before-prune"
                       (length program-function-names))
  (runtime-metric-add! "runtime:program-global-count-before-prune"
                       (length top-level-variable-declarations)))

;; runtime-record-tree-shake-retention-metrics! : list? list? -> void?
;;   Record retained primitive and function counts after the retention closure.
(define (runtime-record-tree-shake-retention-metrics! retained-primitives
                                                      retained-functions)
  (runtime-metric-add! "tree-shake:root-primitive-count"
                       (length retained-primitives))
  (runtime-metric-add! "tree-shake:retained-function-count"
                       (length retained-functions)))

;; runtime-record-tree-shake-final-metrics! : list? list? list? boolean? -> void?
;;   Record final tree-shake status and post-prune module size metrics.
(define (runtime-record-tree-shake-final-metrics! final-module
                                                  described-primitives
                                                  retained-primitives
                                                  tree-shake?)
  (runtime-metric-add! "tree-shake:enabled?"
                       (if tree-shake? "yes" "no"))
  (runtime-metric-add! "tree-shake:retained-primitive-count"
                       (length retained-primitives))
  (runtime-metric-add! "tree-shake:removed-primitive-count"
                       (- (length described-primitives)
                          (length retained-primitives)))
  (runtime-metric-add! "tree-shake:function-count-after-prune"
                       (module-func-count final-module))
  (runtime-metric-add! "tree-shake:global-count-after-prune"
                       (module-global-count final-module))
  (runtime-metric-add/computed! "tree-shake:module-bytes-after-prune"
                                (lambda ()
                                  (module-byte-size final-module))))

(module+ test
  (require rackunit)

  ;; metric-ref : (listof list?) string? -> string?
  ;;   Look up a recorded metric by label.
  (define (metric-ref rows label)
    (second (assoc label rows)))

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
  (check-false computed?)

  (define sample-module
    '(module
      (func $f)
      (global $g i32 (i32.const 0))
      (data $d "abc")
      (export "f" (func $f))))

  (parameterize ([current-runtime-metric-rows '()])
    (runtime-record-built-module-metrics! sample-module)
    (define rows (current-runtime-metric-rows))
    (check-equal? (metric-ref rows "runtime:function-count-before-prune") "1")
    (check-equal? (metric-ref rows "runtime:global-count-before-prune") "1")
    (check-equal? (metric-ref rows "runtime:export-count-before-prune") "1")
    (check-true (positive? (string->number
                            (metric-ref rows "runtime:module-bytes-before-prune")))))

  (parameterize ([current-runtime-metric-rows '()])
    (runtime-record-split-module-metrics!
     '((global $string:a (mut (ref eq)) (ref.i31 (i32.const 0)))
       (global $bytes:a (mut (ref eq)) (ref.i31 (i32.const 0)))
       (global $symbol:a (mut (ref eq)) (ref.i31 (i32.const 0)))
       (data $string-data:a "a")
       (data $bytes-data:a "a")
       (data $symbol-data:a "a"))
     '((func $program))
     '($program)
     '((global $top (mut (ref eq)) (ref.i31 (i32.const 0)))))
    (define rows (current-runtime-metric-rows))
    (check-equal? (metric-ref rows "runtime:runtime-form-count-before-prune") "6")
    (check-equal? (metric-ref rows "runtime:program-form-count-before-prune") "1")
    (check-equal? (metric-ref rows "runtime:runtime-string-global-count") "1")
    (check-equal? (metric-ref rows "runtime:runtime-bytes-global-count") "1")
    (check-equal? (metric-ref rows "runtime:runtime-symbol-global-count") "1")
    (check-equal? (metric-ref rows "runtime:runtime-string-data-count") "1")
    (check-equal? (metric-ref rows "runtime:runtime-bytes-data-count") "1")
    (check-equal? (metric-ref rows "runtime:runtime-symbol-data-count") "1")
    (check-equal? (metric-ref rows "runtime:program-function-count-before-prune") "1")
    (check-equal? (metric-ref rows "runtime:program-global-count-before-prune") "1"))

  (parameterize ([current-runtime-metric-rows '()])
    (runtime-record-tree-shake-retention-metrics! '(car cons) '($car $cons $cdr))
    (define rows (current-runtime-metric-rows))
    (check-equal? (metric-ref rows "tree-shake:root-primitive-count") "2")
    (check-equal? (metric-ref rows "tree-shake:retained-function-count") "3"))

  (parameterize ([current-runtime-metric-rows '()])
    (runtime-record-tree-shake-final-metrics! sample-module
                                              '(car cdr cons)
                                              '(car cons)
                                              #t)
    (define rows (current-runtime-metric-rows))
    (check-equal? (metric-ref rows "tree-shake:enabled?") "yes")
    (check-equal? (metric-ref rows "tree-shake:retained-primitive-count") "2")
    (check-equal? (metric-ref rows "tree-shake:removed-primitive-count") "1")
    (check-equal? (metric-ref rows "tree-shake:function-count-after-prune") "1")
    (check-equal? (metric-ref rows "tree-shake:global-count-after-prune") "1")
    (check-true (positive? (string->number
                            (metric-ref rows "tree-shake:module-bytes-after-prune"))))))
