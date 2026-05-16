#lang racket/base

;;; Source-level dependency facts for staging Racket's io/format layer.
;;;
;;; This is intentionally a lightweight source reader, not a full module
;;; resolver. The first io/format milestone only needs stable guardrails:
;;; the format parser should stay regexp-free, and regexp support should remain
;;; an io/print hook until the demodularized regexp provider is composed.

(require racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string)

(provide io-source-root
         upstream-io-source-root
         io-format-staged-source-files
         io-format-source-files
         io-format-file->path
         io-format-file-forms
         io-format-direct-require-paths
         io-format-regexp-symbols
         io-format-regexp-symbol-uses
         io-format-source-summary
         io-format-source-summary?
         io-format-source-summary-file
         io-format-source-summary-direct-requires
         io-format-source-summary-direct-require-specs
         io-format-source-summary-regexp-symbols
         io-print-regexp-hook-exports
         io-format-local-closure-report
         io-format-local-closure-report?
         io-format-local-closure-report-present
         io-format-local-closure-report-missing
         io-format-local-closure-report-external
         io-format-local-require-closure
         io-format-summaries)

(define-runtime-path io-source-root "../racket-src/io")
(define-runtime-path upstream-io-source-root "../../racket/racket/src/io")

(define (simplified-complete-path path)
  (simplify-path (path->complete-path path) #f))

(define io-format-source-files
  '("format/main.rkt"
    "format/printf.rkt"))

(define io-format-staged-source-files
  '("common/check.rkt"
    "error/value-string.rkt"
    "format/main.rkt"
    "format/printf.rkt"
    "port/output-port.rkt"
    "port/parameter.rkt"
    "port/string-output.rkt"
    "port/string-port.rkt"
    "print/main.rkt"
    "print/mode.rkt"
    "print/parameter.rkt"
    "print/regexp.rkt"
    "string/convert.rkt"))

(define io-format-regexp-symbols
  '(regexp
    regexp?
    pregexp
    pregexp?
    byte-regexp
    byte-regexp?
    byte-pregexp
    byte-pregexp?
    regexp-match
    regexp-match?
    regexp-match-positions
    regexp-replace
    regexp-replace*
    regexp-split))

(struct io-format-source-summary (file direct-requires direct-require-specs regexp-symbols)
  #:transparent)

(struct io-format-local-closure-report (present missing external)
  #:transparent)

;; io-format-file->path : path-string? -> path?
;;   Resolve a staged io source path relative to racket-src/io.
(define (io-format-file->path file)
  (build-path io-source-root file))

;; io-format-file-forms : path-string? -> (listof any/c)
;;   Read a #lang Racket source file as datums after its language line.
(define (io-format-file-forms file)
  (call-with-input-file (io-format-file->path file)
    (lambda (in)
      (read-line in 'any)
      (let loop ([forms '()])
        (define form (read in))
        (if (eof-object? form)
            (reverse forms)
            (loop (cons form forms)))))))

;; require-spec-path : any/c -> (or/c path-string? #f)
;;   Extract the source path from the require specs used by io/format.
(define (require-spec-path spec)
  (match spec
    [(? string? path) path]
    [`(submod ,(? string? path) . ,_) path]
    [`(only-in ,inner . ,_) (require-spec-path inner)]
    [`(rename-in ,inner . ,_) (require-spec-path inner)]
    [`(except-in ,inner . ,_) (require-spec-path inner)]
    [_ #f]))

;; relative-require-path? : path-string? -> boolean?
;;   Recognize filesystem-relative require paths.
(define (relative-require-path? path)
  (or (string-prefix? path "./")
      (string-prefix? path "../")
      (and (not (string-prefix? path "/"))
           (regexp-match? #rx"[.]rkt$" path))))

;; path-string<? : path-string? path-string? -> boolean?
;;   Sort paths by printed form.
(define (path-string<? a b)
  (string<? (path->string a) (path->string b)))

;; path-prefix? : path? path? -> boolean?
;;   Check whether child is textually under root after simplification.
(define (path-prefix? root child)
  (define root-str (path->string (simplified-complete-path root)))
  (define child-str (path->string (simplified-complete-path child)))
  (or (equal? root-str child-str)
      (string-prefix? child-str
                      (string-append
                       (if (string-suffix? root-str "/")
                           root-str
                           (string-append root-str "/"))))))

;; staged-relative-path : path? -> path-string?
;;   Return a path relative to the staged io source root.
(define (staged-relative-path path)
  (path->string
   (find-relative-path (simplified-complete-path io-source-root)
                       (simplified-complete-path path))))

;; require-spec-label : any/c -> (or/c string? #f)
;;   Describe a direct require while preserving submodule edges.
(define (require-spec-label spec)
  (match spec
    [(? string? path) path]
    [`(submod ,(? string? path) . ,submods)
     (format "~a submodule ~a"
             path
             (string-join (map symbol->string submods) "/"))]
    [`(only-in ,inner . ,_) (require-spec-label inner)]
    [`(rename-in ,inner . ,_) (require-spec-label inner)]
    [`(except-in ,inner . ,_) (require-spec-label inner)]
    [_ #f]))

;; io-format-direct-require-paths : path-string? -> (listof path-string?)
;;   Return direct relative require paths from one source file.
(define (io-format-direct-require-paths file)
  (sort
   (remove-duplicates
    (for*/list ([form (in-list (io-format-file-forms file))]
                #:when (pair? form)
                #:when (eq? 'require (car form))
                [spec (in-list (cdr form))]
                [path (in-value (require-spec-path spec))]
                #:when path)
      path)
    equal?)
   string<?))

;; io-format-local-require-closure : (listof path-string?) -> closure-report?
;;   Traverse staged relative requires and report present, missing, and external
;;   source files. "External" means a relative path escapes racket-src/io.
(define (io-format-local-require-closure roots)
  (define present (make-hash))
  (define missing (make-hash))
  (define external (make-hash))
  (define (record! table path)
    (hash-set! table path #t))
  (define (visit file)
    (unless (hash-ref present file #f)
      (define file-path (io-format-file->path file))
      (cond
        [(not (file-exists? file-path))
         (record! missing file)]
        [else
         (record! present file)
         (for ([req (in-list (io-format-direct-require-paths file))]
               #:when (relative-require-path? req))
           (define req-path
             (simplify-path (build-path (path-only file-path) req) #f))
           (cond
             [(not (path-prefix? io-source-root req-path))
              (record! external (path->string req-path))]
             [else
              (define req-file (staged-relative-path req-path))
              (if (file-exists? req-path)
                  (visit req-file)
                  (record! missing req-file))]))])))
  (for ([root (in-list roots)])
    (visit root))
  (io-format-local-closure-report
   (sort (hash-keys present) string<?)
   (sort (hash-keys missing) string<?)
   (sort (hash-keys external) string<?)))


;; io-format-direct-require-specs : path-string? -> (listof string?)
;;   Return direct require labels, preserving submodule edges.
(define (io-format-direct-require-specs file)
  (sort
   (remove-duplicates
    (for*/list ([form (in-list (io-format-file-forms file))]
                #:when (pair? form)
                #:when (eq? 'require (car form))
                [spec (in-list (cdr form))]
                [label (in-value (require-spec-label spec))]
                #:when label)
      label)
    equal?)
   string<?))

;; datum-symbols : any/c -> (listof symbol?)
;;   Collect symbols used in a datum, skipping quoted data is not necessary for
;;   this guard: a regexp literal in data would still be a dependency signal.
(define (datum-symbols v)
  (cond
    [(symbol? v) (list v)]
    [(pair? v)   (append (datum-symbols (car v))
                         (datum-symbols (cdr v)))]
    [(vector? v) (append-map datum-symbols (vector->list v))]
    [else        '()]))

;; io-format-regexp-symbol-uses : path-string? -> (listof symbol?)
;;   Return regexp-related symbols mentioned by a source file.
(define (io-format-regexp-symbol-uses file)
  (sort
   (filter (lambda (sym) (memq sym io-format-regexp-symbols))
           (remove-duplicates
            (append-map datum-symbols (io-format-file-forms file))
            eq?))
   symbol<?))

;; provide-symbols : any/c -> (listof symbol?)
;;   Extract simple provided identifiers.
(define (provide-symbols form)
  (match form
    [`(provide . ,specs)
     (for/list ([spec (in-list specs)]
                #:when (symbol? spec))
       spec)]
    [_ '()]))

;; io-print-regexp-hook-exports : -> (listof symbol?)
;;   Return the small hook exported by io/print/regexp.rkt.
(define (io-print-regexp-hook-exports)
  (sort
   (remove-duplicates
    (append-map provide-symbols
                (io-format-file-forms "print/regexp.rkt"))
    eq?)
   symbol<?))

;; io-format-summaries : -> (listof io-format-source-summary?)
;;   Summarize the source facts that matter for the staging decision.
(define (io-format-summaries)
  (for/list ([file (in-list io-format-source-files)])
    (io-format-source-summary
     file
     (io-format-direct-require-paths file)
     (io-format-direct-require-specs file)
     (io-format-regexp-symbol-uses file))))

(module+ main
  (for ([summary (in-list (io-format-summaries))])
    (printf "~a\n" (io-format-source-summary-file summary))
    (printf "  direct-requires: ~s\n"
            (io-format-source-summary-direct-requires summary))
    (printf "  direct-require-specs: ~s\n"
            (io-format-source-summary-direct-require-specs summary))
    (printf "  regexp-symbols: ~s\n"
            (io-format-source-summary-regexp-symbols summary)))
  (printf "print-regexp-hook-exports: ~s\n"
          (io-print-regexp-hook-exports))
  (define closure (io-format-local-require-closure io-format-source-files))
  (printf "local-closure-present (~a): ~s\n"
          (length (io-format-local-closure-report-present closure))
          (io-format-local-closure-report-present closure))
  (printf "local-closure-missing (~a): ~s\n"
          (length (io-format-local-closure-report-missing closure))
          (io-format-local-closure-report-missing closure))
  (printf "local-closure-external (~a): ~s\n"
          (length (io-format-local-closure-report-external closure))
          (io-format-local-closure-report-external closure))
  (displayln "io/format regexp dependency guard passed"))
