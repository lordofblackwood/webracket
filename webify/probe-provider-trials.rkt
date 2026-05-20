#lang racket/base

;;; Discovery-only dashboard for curated Goal 1 external-provider trials.

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/path
         racket/string
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "../pkgs/webracket-lib/compiler/webify/provider-trials.rkt")

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

;; trial-cache-key : webify-provider-trial? -> string?
;;   Build a conservative cache key for a dashboard row.
(define (trial-cache-key trial)
  (format "~a-~a-~a.rktd"
          (regexp-replace* #rx"/" (symbol->string (webify-provider-trial-module trial)) "_")
          (version)
          (string-join (map symbol->string (webify-provider-trial-exports trial))
                       "+")))

;; cache-read : path-string? webify-provider-trial? -> (or/c hash? #f)
;;   Read a cached dashboard summary if present.
(define (cache-read cache-dir trial)
  (define path (build-path cache-dir (trial-cache-key trial)))
  (and (file-exists? path)
       (call-with-input-file path read)))

;; cache-write! : path-string? webify-provider-trial? hash? -> void?
;;   Store a cacheable dashboard summary.
(define (cache-write! cache-dir trial summary)
  (make-directory* cache-dir)
  (call-with-output-file (build-path cache-dir (trial-cache-key trial))
    (lambda (out) (write summary out))
    #:exists 'truncate/replace))

;; report-or-cache-summary : path-string? boolean? report -> hash?
;;   Return a cacheable summary, writing it when cache-dir is supplied.
(define (report-or-cache-summary cache-dir force? report)
  (define trial (webify-provider-trial-report-trial report))
  (define summary (webify-provider-trial-report->summary-datum report))
  (when cache-dir
    (cache-write! cache-dir trial summary))
  summary)

;; trial-summary : path-string? boolean? webify-provider-trial? -> hash?
;;   Read or compute one provider-trial dashboard summary.
(define (trial-summary cache-dir force? trial)
  (cond
    [(and cache-dir (not force?) (cache-read cache-dir trial))]
    [else
     (report-or-cache-summary
      cache-dir
      force?
      (webify-provider-trial-run trial))]))

;; summary-ref : hash? symbol? any/c -> any/c
;;   Read a summary key with a default for older cache rows.
(define (summary-ref summary key [default '()])
  (hash-ref summary key default))

;; print-provider-trial-row : boolean? hash? -> void?
;;   Print one provider-trial dashboard row.
(define (print-provider-trial-row tsv? summary)
  (define demand-inputs (summary-ref summary 'demand-input-count 0))
  (define full-inputs (summary-ref summary 'full-input-count demand-inputs))
  (define demand-imports (summary-ref summary 'demand-import-count 0))
  (define full-imports (summary-ref summary 'full-import-count demand-imports))
  (define demand-exports (summary-ref summary 'demand-export-count 0))
  (define full-exports (summary-ref summary 'full-export-count demand-exports))
  (cond
    [tsv?
     (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
             (summary-ref summary 'module)
             (join-symbols (summary-ref summary 'exports))
             (summary-ref summary 'status)
             (~r (summary-ref summary 'elapsed-ms 0) #:precision 3)
             demand-inputs
             full-inputs
             (- full-inputs demand-inputs)
             demand-imports
             full-imports
             demand-exports
             full-exports
             (summary-ref summary 'primitive-demands 0)
             (summary-ref summary 'missing-primitives 0)
             (join-ownership-counts (summary-ref summary 'ownership))
             (summary-ref summary 'cache-hits 0)
             (summary-ref summary 'cache-misses 0)
             (summary-ref summary 'largest-inputs '()))]
    [else
     (printf "~a: ~a (~a export(s), demand/full inputs ~a/~a, primitive demand(s) ~a, missing ~a)\n"
             (summary-ref summary 'module)
             (summary-ref summary 'status)
             (length (summary-ref summary 'exports))
             demand-inputs
             full-inputs
             (summary-ref summary 'primitive-demands 0)
             (summary-ref summary 'missing-primitives 0))
     (when (summary-ref summary 'error-message #f)
       (printf "  error: ~a\n" (summary-ref summary 'error-message)))]))

;; print-provider-trial-dashboard : boolean? [path-string?] boolean? -> void?
;;   Print discovery-only provider trial status.
(define (print-provider-trial-dashboard tsv? cache-dir force-cache?)
  (when tsv?
    (printf "module\texports\tstatus\telapsed-ms\tdemand-inputs\tfull-inputs\tinput-delta\tdemand-imports\tfull-imports\tdemand-exports\tfull-exports\tprimitive-demands\tmissing-primitives\townership\tcache-hits\tcache-misses\tlargest-inputs\n"))
  (for ([trial (in-list webify-provider-trials)])
    (print-provider-trial-row
     tsv?
     (trial-summary cache-dir force-cache? trial))))

(module+ main
  (define tsv? #f)
  (define cache-dir #f)
  (define force-cache? #f)
  (command-line
   #:program "probe-provider-trials"
   #:once-each
   [("--tsv") "print a tab-separated discovery dashboard"
              (set! tsv? #t)]
   [("--cache-dir") dir "cache dashboard summaries in dir"
                    (set! cache-dir (string->path dir))]
   [("--force-cache-refresh") "refresh provider-trial dashboard cache rows"
                              (set! force-cache? #t)])
  (print-provider-trial-dashboard tsv? cache-dir force-cache?))
