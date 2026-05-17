#lang racket/base

;;; Full-expander extraction oracle.
;;;
;;; This intentionally stops before Webify lowering or Wasm compilation. The
;;; goal is to use Racket's own closed expander extraction as a demand oracle
;;; for primitive-table usage and missing primitive coverage.

(provide webify-expander-oracle-extraction-args
         webify-expander-oracle-report
         webify-expander-oracle-report?
         webify-expander-oracle-report-linklet-path
         webify-expander-oracle-report-linklet-import-count
         webify-expander-oracle-report-linklet-export-count
         webify-expander-oracle-report-primitive-demands
         webify-expander-oracle-report-missing-primitive-demands
         webify-expander-oracle-report-table-requests
         webify-expander-oracle-run!
         print-expander-oracle-summary
         print-expander-oracle-demands-tsv)

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         "module-input.rkt"
         "primitive-demands.rkt")

(define-runtime-path repo-root "..")

(define racket-root
  (simplify-path (build-path repo-root "../racket/racket")))

(define racket-bin
  (build-path racket-root "bin/racket"))

(define bootstrap-run-rkt
  (build-path racket-root "src/expander/bootstrap-run.rkt"))

(define expander-main-rkt
  (build-path racket-root "src/expander/main.rkt"))

(define expander-api-module-rkt
  (build-path racket-root "src/expander/namespace/api-module.rkt"))

(struct webify-expander-oracle-report
  (linklet-path
   linklet-import-count
   linklet-export-count
   primitive-demands
   missing-primitive-demands
   table-requests)
  #:transparent)

;; webify-expander-oracle-extraction-args : path? -> (listof string?)
;;   Build the closed-expander extraction command used by the oracle.
(define (webify-expander-oracle-extraction-args out-dir)
  (define out-rktl (build-path out-dir "expander.rktl"))
  (define dep-rktd (build-path out-dir "expander-dep.rktd"))
  (define cache-dir (build-path out-dir "cache-src"))
  (define startup-wrapper (build-path out-dir "expander-startup-wrapper.rkt"))
  (call-with-output-file* startup-wrapper
    (lambda (out)
      (fprintf out "#lang racket/base\n")
      (fprintf out "(require (file ~s)\n" (path->string expander-main-rkt))
      (fprintf out "         (only-in (file ~s) module->namespace module->imports module->exports))\n"
               (path->string expander-api-module-rkt))
      (fprintf out "(provide (all-from-out (file ~s))\n" (path->string expander-main-rkt))
      (fprintf out "         module->namespace module->imports module->exports)\n"))
    #:exists 'truncate/replace)
  (list
   (path->string bootstrap-run-rkt)
   "-t" (path->string startup-wrapper)
   "-c" (path->string cache-dir)
   "--depends" (path->string dep-rktd)
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/api.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/primitive-parameter.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/readtable-parameter.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/readtable.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/number.rkt"))
   "++direct" "linklet"
   "++direct" "kernel"
   "++disallow" "make-optional-keyword-procedure"
   "--no-global"
   "++global-ok" "core-forms"
   "++global-ok" "core-primitives"
   "++global-ok" "built-in-symbols"
   "++global-ok" "default-read-handler"
   "++global-ok" "current-previously-unbound"
   "++global-ok" "keep-source-locations?"
   "++global-ok" "rx:path-list"
   "++global-ok" "load-configure-expand"
   "-k" (path->string racket-root)
   "-s" "-x"
   "-o" (path->string out-rktl)))

;; run-extraction! : path? boolean? -> path?
;;   Extract the closed expander linklet and return the generated rktl path.
(define (run-extraction! out-dir verbose?)
  (unless (and (file-exists? racket-bin)
               (file-exists? bootstrap-run-rkt)
               (file-exists? expander-main-rkt)
               (file-exists? expander-api-module-rkt))
    (error 'webify-expander-oracle
           "expected Racket checkout under ../racket/racket"))
  (make-directory* out-dir)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (apply system*/exit-code
             (path->string racket-bin)
             (webify-expander-oracle-extraction-args out-dir))))
  (define output (string-append (get-output-string stdout)
                                (get-output-string stderr)))
  (unless (zero? status)
    (error 'webify-expander-oracle
           "extraction failed with status ~a\n~a"
           status
           output))
  (unless (or (not verbose?) (string=? output ""))
    (for ([pattern (in-list '(#rx"Traversed [0-9]+ modules"
                              #rx"Need [0-9]+ of those linklets"
                              #rx"Can remove [^\n]+"
                              #rx"Flattened code is [0-9]+ bytes"))])
      (define m (regexp-match pattern output))
      (when m (displayln (car m)))))
  (build-path out-dir "expander.rktl"))

;; linklet-import-count : any/c -> exact-nonnegative-integer?
;;   Count top-level import groups in a linklet datum.
(define (linklet-import-count datum)
  (match datum
    [`(linklet ,imports ,_exports . ,_body) (length imports)]
    [_ 0]))

;; linklet-export-count : any/c -> exact-nonnegative-integer?
;;   Count top-level exports in a linklet datum.
(define (linklet-export-count datum)
  (match datum
    [`(linklet ,_imports ,exports . ,_body) (length exports)]
    [_ 0]))

;; webify-expander-oracle-run! : path? [#:verbose? boolean?] -> webify-expander-oracle-report?
;;   Extract the closed expander and report conservative primitive demands.
(define (webify-expander-oracle-run! out-dir #:verbose? [verbose? #t])
  (define linklet-path (run-extraction! out-dir verbose?))
  (define datum (call-with-input-file linklet-path read))
  (define input (webify-module-linklet-input 'full-expander datum '()))
  (define demand-report (webify-module-linklet-inputs->primitive-demands (list input)))
  (define missing-demands (webify-primitive-demand-report-missing demand-report))
  (webify-expander-oracle-report
   linklet-path
   (linklet-import-count datum)
   (linklet-export-count datum)
   (webify-primitive-demand-report-demands demand-report)
   missing-demands
   (webify-primitive-demand-report-table-requests demand-report)))

;; print-demand-row : webify-primitive-demand? -> void?
;;   Print one demand as a TSV row.
(define (print-demand-row demand)
  (printf "~a\t~a\t~s\n"
          (webify-primitive-demand-module demand)
          (webify-primitive-demand-name demand)
          (webify-primitive-demand-sources demand)))

;; print-expander-oracle-summary : webify-expander-oracle-report? -> void?
;;   Print a compact human-oriented oracle summary.
(define (print-expander-oracle-summary report)
  (printf "full-expander-oracle\n")
  (printf "linklet-path: ~a\n"
          (webify-expander-oracle-report-linklet-path report))
  (printf "linklet-import-count: ~a\n"
          (webify-expander-oracle-report-linklet-import-count report))
  (printf "linklet-export-count: ~a\n"
          (webify-expander-oracle-report-linklet-export-count report))
  (printf "primitive-demand-count: ~a\n"
          (length (webify-expander-oracle-report-primitive-demands report)))
  (printf "missing-primitive-demand-count: ~a\n"
          (length (webify-expander-oracle-report-missing-primitive-demands report)))
  (printf "primitive-table-request-count: ~a\n"
          (length (webify-expander-oracle-report-table-requests report)))
  (unless (null? (webify-expander-oracle-report-missing-primitive-demands report))
    (printf "missing-primitive-demands:\n")
    (for ([demand (in-list (webify-expander-oracle-report-missing-primitive-demands report))])
      (printf "  ~a ~a sources=~s\n"
              (webify-primitive-demand-module demand)
              (webify-primitive-demand-name demand)
              (webify-primitive-demand-sources demand)))))

;; print-expander-oracle-demands-tsv : webify-expander-oracle-report? boolean? -> void?
;;   Print all or missing-only primitive demands as TSV.
(define (print-expander-oracle-demands-tsv report missing-only?)
  (printf "module\tname\tsources\n")
  (for ([demand (in-list (if missing-only?
                             (webify-expander-oracle-report-missing-primitive-demands report)
                             (webify-expander-oracle-report-primitive-demands report)))])
    (print-demand-row demand)))

(module+ main
  (define out-dir #f)
  (define demands-tsv? #f)
  (define missing-tsv? #f)
  (command-line
   #:program "expander-oracle"
   #:once-each
   [("--out-dir") path
    "Directory for extracted expander oracle artifacts"
    (set! out-dir (string->path path))]
   [("--primitive-demands-tsv")
    "Print all conservative primitive demands as TSV"
    (set! demands-tsv? #t)]
   [("--missing-primitives-tsv")
    "Print missing conservative primitive demands as TSV"
    (set! missing-tsv? #t)])
  (define root (or out-dir
                   (make-temporary-file "webracket-expander-oracle-~a" 'directory)))
  (define report
    (webify-expander-oracle-run! root #:verbose? (not (or missing-tsv? demands-tsv?))))
  (cond
    [missing-tsv? (print-expander-oracle-demands-tsv report #t)]
    [demands-tsv? (print-expander-oracle-demands-tsv report #f)]
    [else (print-expander-oracle-summary report)]))
