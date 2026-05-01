#lang racket/base

;;;
;;; find-callback-source
;;;

(require racket/cmdline
         racket/file
         racket/format
         racket/match
         racket/path
         racket/port
         racket/string)

;; map-entry : string? path-string? exact-nonnegative-integer? exact-nonnegative-integer?
;;             exact-nonnegative-integer? (or/c string? #f) (or/c string? #f) -> hash?
;;   Build one parsed label-map entry.
(define (map-entry label src line col span same-as form)
  (hash 'label   label
        'src     src
        'line    line
        'col     col
        'span    span
        'same-as same-as
        'form    form))

;; normalize-label-map-text : string? -> string?
;;   Rewrite unreadable printed path tokens into readable string literals.
(define (normalize-label-map-text text)
  (regexp-replace* #px"#<path:([^>]+)>"
                   text
                   (lambda (m path)
                     (format "~s" path))))

;; parse-src-token : any/c -> string?
;;   Decode one source token from the emitted label map.
(define (parse-src-token token)
  (cond
    [(path? token)   (path->string token)]
    [(string? token) token]
    [(symbol? token) (symbol->string token)]
    [else            (~a token)]))

;; sexp->entry : any/c -> (or/c hash? #f)
;;   Parse one `(label ...)` s-expression from a `.wasm.map.sexp` file.
(define (sexp->entry stx)
  (match stx
    [`(label ,label (src ,src ,line ,col ,span) . ,rest)
     (define same-as
       (for/first ([field (in-list rest)])
         (match field
           [`(same-as ,target) target]
           [_ #f])))
     (define form
       (for/first ([field (in-list rest)])
         (match field
           [`(form ,value) value]
           [_ #f])))
     (map-entry label
                (parse-src-token src)
                line
                col
                span
                same-as
                form)]
    [_ #f]))

;; parse-label-map : path-string? -> (hash/c string? hash?)
;;   Parse a `.wasm.map.sexp` file into a label table.
(define (parse-label-map map-path)
  (define table (make-hash))
  (define raw-text (file->string map-path))
  (define normalized-text (normalize-label-map-text raw-text))
  (define label-map
    (with-input-from-string normalized-text read))
  (match label-map
    [`(wasm-label-map . ,entries)
     (for ([entry-sexp (in-list entries)])
       (define entry (sexp->entry entry-sexp))
       (when entry
         (hash-set! table (hash-ref entry 'label) entry)))]
    [_ (error 'parse-label-map "unexpected label map format in ~a" map-path)])
  table)

;; format-location : hash? -> string?
;;   Render one parsed entry as `path:line:col`.
(define (format-location entry)
  (format "~a:~a:~a"
          (hash-ref entry 'src)
          (hash-ref entry 'line)
          (hash-ref entry 'col)))

;; print-entry : hash? boolean? -> void?
;;   Print a human-readable result block.
(define (print-entry entry show-form?)
  (printf "label: ~a\n" (hash-ref entry 'label))
  (printf "source: ~a\n" (format-location entry))
  (printf "span: ~a\n" (hash-ref entry 'span))
  (define same-as (hash-ref entry 'same-as))
  (when same-as
    (printf "same-as: ~a\n" same-as))
  (when show-form?
    (define form (hash-ref entry 'form))
    (when form
      (printf "form: ~a\n" form))))

(define show-form? #f)

(define-values (map-path label)
  (command-line
   #:program "find-callback-source"
   #:once-each
   [("--show-form") "Print the recorded source form when available."
                    (set! show-form? #t)]
   #:args (map-path label)
   (values map-path label)))

(define table (parse-label-map map-path))
(define entry (hash-ref table label #f))

(cond
  [entry
   (print-entry entry show-form?)
   (exit 0)]
  [else
   (eprintf "find-callback-source: label not found: ~a\n" label)
   (eprintf "  map: ~a\n" (path->string (simplify-path (path->complete-path map-path))))
   (exit 1)])
