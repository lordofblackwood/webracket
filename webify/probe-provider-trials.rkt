#lang racket/base

;;; Discovery-only dashboard for curated Goal 1 external-provider trials.

(require racket/cmdline
         racket/format
         racket/string
         "module-extractor.rkt"
         "provider-trials.rkt")

;; join-symbols : (listof symbol?) -> string?
;;   Render symbols compactly for TSV cells.
(define (join-symbols symbols)
  (string-join (map symbol->string symbols) ","))

;; join-ownership-counts : alist? -> string?
;;   Render primitive ownership counts compactly for dashboards.
(define (join-ownership-counts counts)
  (string-join
   (for/list ([count (in-list counts)])
     (format "~a:~a" (car count) (cdr count)))
   ","))

;; print-provider-trial-dashboard : boolean? -> void?
;;   Print discovery-only provider trial status.
(define (print-provider-trial-dashboard tsv?)
  (when tsv?
    (printf "module\texports\tstatus\telapsed-ms\tinputs\tprimitive-demands\tmissing-primitives\townership\tcache-hits\tcache-misses\n"))
  (for ([report (in-list (webify-provider-trial-run-all))])
    (define trial (webify-provider-trial-report-trial report))
    (define primitive-report
      (webify-provider-trial-report-primitive-report report))
    (define primitive-demand-count
      (length (webify-primitive-demand-report-demands primitive-report)))
    (define missing-count
      (length (webify-provider-trial-report-missing-primitives report)))
    (cond
      [tsv?
       (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
               (webify-provider-trial-module trial)
               (join-symbols (webify-provider-trial-exports trial))
               (webify-provider-trial-report-status report)
               (~r (webify-provider-trial-report-elapsed-ms report)
                   #:precision 3)
               (join-symbols (webify-provider-trial-report-input-names report))
               primitive-demand-count
               missing-count
               (join-ownership-counts
                (webify-provider-trial-report-primitive-ownership-counts report))
               (webify-provider-trial-report-provider-cache-hits report)
               (webify-provider-trial-report-provider-cache-misses report))]
      [else
       (printf "~a: ~a (~a export(s), ~a input(s), ~a primitive demand(s), ~a missing)\n"
               (webify-provider-trial-module trial)
               (webify-provider-trial-report-status report)
               (length (webify-provider-trial-exports trial))
               (length (webify-provider-trial-report-input-names report))
               primitive-demand-count
               missing-count)
       (when (webify-provider-trial-report-error-message report)
         (printf "  error: ~a\n"
                 (webify-provider-trial-report-error-message report)))])))

(module+ main
  (define tsv? #f)
  (command-line
   #:program "probe-provider-trials"
   #:once-each
   [("--tsv") "print a tab-separated discovery dashboard"
              (set! tsv? #t)])
  (print-provider-trial-dashboard tsv?))
