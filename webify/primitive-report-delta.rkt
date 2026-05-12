#lang racket/base

(require racket/cmdline
         racket/list
         racket/match
         racket/port
         racket/string)

;; primitive-report-delta : path-string? [path-string?] -> void?
;;   Summarize one expander primitive report, or compare it with a baseline.

(define limit 25)

(define report-sections
  '(program-root-primitives
    runtime-root-primitives
    retained-primitives
    isolated-primitives))

(define (symbol<?* a b)
  (string<? (symbol->string a) (symbol->string b)))

(define (read-report path)
  (call-with-input-file path read))

(define (report-ref report key [default '()])
  (define found (assq key report))
  (if found (cdr found) default))

(define (report-list report key)
  (define v (report-ref report key))
  (unless (list? v)
    (raise-user-error 'primitive-report-delta
                      "expected list section ~s in report"
                      key))
  v)

(define (report-summary report)
  (for/hash ([entry (in-list (report-list report 'summary))])
    (match entry
      [(list key value) (values key value)]
      [_ (values 'unknown entry)])))

(define (show-list names)
  (define sorted (sort names symbol<?*))
  (define shown (take sorted (min limit (length sorted))))
  (if (null? shown)
      "none"
      (string-join (map symbol->string shown) " ")))

(define (print-summary path report)
  (define summary (report-summary report))
  (printf "report: ~a\n" path)
  (for ([key '(total-primitives
               program-root-count
               runtime-root-count
               retained-count
               isolated-count)])
    (printf "~a: ~a\n" key (hash-ref summary key 'unknown)))
  (for ([section (in-list report-sections)])
    (printf "~a-list-count: ~a\n"
            section
            (length (report-list report section)))))

(define (set-diff xs ys)
  (define ys-set (for/hash ([y (in-list ys)]) (values y #t)))
  (sort (filter (lambda (x) (not (hash-has-key? ys-set x))) xs) symbol<?*))

(define (print-delta old-path old-report new-path new-report)
  (printf "baseline: ~a\n" old-path)
  (printf "current: ~a\n" new-path)
  (for ([section (in-list report-sections)])
    (define old (report-list old-report section))
    (define new (report-list new-report section))
    (define added (set-diff new old))
    (define removed (set-diff old new))
    (printf "~a-added-count: ~a\n" section (length added))
    (printf "~a-added: ~a\n" section (show-list added))
    (printf "~a-removed-count: ~a\n" section (length removed))
    (printf "~a-removed: ~a\n" section (show-list removed))))

(define paths
  (command-line
   #:program "primitive-report-delta"
   #:once-each
   [("--limit") n
                "maximum names to show per delta list"
                (set! limit (string->number n))]
   #:args paths
   paths))

(unless (or (= (length paths) 1) (= (length paths) 2))
  (raise-user-error 'primitive-report-delta
                    "usage: racket webify/primitive-report-delta.rkt REPORT [BASELINE]"))

(match paths
  [(list current-path)
   (print-summary current-path (read-report current-path))]
  [(list current-path baseline-path)
   (print-summary current-path (read-report current-path))
   (newline)
   (print-delta baseline-path
                (read-report baseline-path)
                current-path
                (read-report current-path))])
