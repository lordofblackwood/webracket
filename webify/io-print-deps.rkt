#lang racket/base

;;; Source-level dependency facts for staging Racket's io/print layer.

(require racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         "io-print-provider.rkt")

(provide io-print-source-root
         upstream-io-source-root
         io-print-source-files
         io-print-first-helper-slice
         io-print-file->path
         io-print-file-forms
         io-print-direct-require-paths
         io-print-direct-require-specs
         io-print-local-closure-report
         io-print-local-closure-report?
         io-print-local-closure-report-present
         io-print-local-closure-report-missing
         io-print-local-closure-report-external
         io-print-local-require-closure)

(define-runtime-path io-print-source-root "../racket-src/io")
(define-runtime-path upstream-io-source-root "../../racket/racket/src/io")

(define io-print-source-files
  '("print/main.rkt"))

(define io-print-first-helper-slice
  '("print/bytes.rkt"
    "print/char.rkt"
    "print/config.rkt"
    "print/custom-write.rkt"
    "print/more-pending.rkt"
    "print/string.rkt"
    "print/symbol.rkt"
    "print/write-with-max.rkt"))

(struct io-print-local-closure-report (present missing external)
  #:transparent)

;; io-print-file->path : path-string? -> path?
;;   Resolve a staged io source path relative to racket-src/io.
(define (io-print-file->path file)
  (build-path io-print-source-root file))

;; io-print-file-forms : path-string? -> (listof any/c)
;;   Read a #lang Racket source file as datums after its language line.
(define (io-print-file-forms file)
  (call-with-input-file (io-print-file->path file)
    (lambda (in)
      (read-line in 'any)
      (let loop ([forms '()])
        (define form (read in))
        (if (eof-object? form)
            (reverse forms)
            (loop (cons form forms)))))))

(define (require-spec-path spec)
  (match spec
    [(? string? path) path]
    [`(submod ,(? string? path) . ,_) path]
    [`(only-in ,inner . ,_) (require-spec-path inner)]
    [`(rename-in ,inner . ,_) (require-spec-path inner)]
    [`(except-in ,inner . ,_) (require-spec-path inner)]
    [_ #f]))

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

(define (relative-require-path? path)
  (or (string-prefix? path "./")
      (string-prefix? path "../")
      (and (not (string-prefix? path "/"))
           (regexp-match? #rx"[.]rkt$" path))))

(define (simplified-complete-path path)
  (simplify-path (path->complete-path path) #f))

(define (path-prefix? root child)
  (define root-str (path->string (simplified-complete-path root)))
  (define child-str (path->string (simplified-complete-path child)))
  (or (equal? root-str child-str)
      (string-prefix? child-str
                      (string-append
                       (if (string-suffix? root-str "/")
                           root-str
                           (string-append root-str "/"))))))

(define (staged-relative-path path)
  (path->string
   (find-relative-path (simplified-complete-path io-print-source-root)
                       (simplified-complete-path path))))

;; io-print-direct-require-paths : path-string? -> (listof path-string?)
;;   Return direct relative require paths from one staged io/print source file.
(define (io-print-direct-require-paths file)
  (sort
   (remove-duplicates
    (for*/list ([form (in-list (io-print-file-forms file))]
                #:when (pair? form)
                #:when (eq? 'require (car form))
                [spec (in-list (cdr form))]
                [path (in-value (require-spec-path spec))]
                #:when path)
      path)
    equal?)
   string<?))

;; io-print-direct-require-specs : path-string? -> (listof string?)
;;   Return direct require labels, preserving submodule edges.
(define (io-print-direct-require-specs file)
  (sort
   (remove-duplicates
    (for*/list ([form (in-list (io-print-file-forms file))]
                #:when (pair? form)
                #:when (eq? 'require (car form))
                [spec (in-list (cdr form))]
                [label (in-value (require-spec-label spec))]
                #:when label)
      label)
    equal?)
   string<?))

;; io-print-local-require-closure : (listof path-string?) -> closure-report?
;;   Traverse staged relative requires and report present, missing, and external
;;   source files.
(define (io-print-local-require-closure roots)
  (define present (make-hash))
  (define missing (make-hash))
  (define external (make-hash))
  (define (record! table path)
    (hash-set! table path #t))
  (define (visit file)
    (unless (hash-ref present file #f)
      (define file-path (io-print-file->path file))
      (cond
        [(not (file-exists? file-path))
         (record! missing file)]
        [else
         (record! present file)
         (for ([req (in-list (io-print-direct-require-paths file))]
               #:when (relative-require-path? req))
           (define req-path
             (simplify-path (build-path (path-only file-path) req) #f))
           (cond
             [(not (path-prefix? io-print-source-root req-path))
              (record! external (path->string req-path))]
             [else
              (define req-file (staged-relative-path req-path))
              (if (file-exists? req-path)
                  (visit req-file)
                  (record! missing req-file))]))])))
  (for ([root (in-list roots)])
    (visit root))
  (io-print-local-closure-report
   (sort (hash-keys present) string<?)
   (sort (hash-keys missing) string<?)
   (sort (hash-keys external) string<?)))

(module+ main
  (define closure (io-print-local-require-closure io-print-source-files))
  (printf "io/print direct requires: ~s\n"
          (io-print-direct-require-specs "print/main.rkt"))
  (printf "io/print present (~a): ~s\n"
          (length (io-print-local-closure-report-present closure))
          (io-print-local-closure-report-present closure))
  (printf "io/print missing (~a): ~s\n"
          (length (io-print-local-closure-report-missing closure))
          (io-print-local-closure-report-missing closure))
  (printf "io/print external (~a): ~s\n"
          (length (io-print-local-closure-report-external closure))
          (io-print-local-closure-report-external closure)))
