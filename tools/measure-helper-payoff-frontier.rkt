#lang racket

(require racket/list
         racket/match
         racket/path
         racket/pretty
         racket/runtime-path)

(define-runtime-path repo-root "..")
(define-runtime-path compiler-path "../pkgs/webracket-lib/compiler/compiler.rkt")

(define default-targets
  (list (build-path repo-root "test" "test-letrec.rkt")
        (build-path repo-root "test" "test-basics.rkt")
        (build-path repo-root "examples" "pict" "pict.rkt")))

(define (usage)
  (eprintf "usage: racket tools/measure-helper-payoff-frontier.rkt [source-file ...]\n")
  (exit 1))

(define args (current-command-line-arguments))

(define source-paths
  (for/list ([raw (in-list (if (zero? (vector-length args))
                               (map path->string default-targets)
                               (vector->list args)))])
    (simplify-path (path->complete-path raw (current-directory)))))

(for ([p (in-list source-paths)])
  (unless (file-exists? p)
    (eprintf "missing source file: ~a\n" p)
    (usage)))

(dynamic-require compiler-path #f)
(define compiler-ns (module->namespace `(file ,(path->string compiler-path))))

(define (analyze-source source-path summarize-sym)
  (define source-stx
    (parameterize ([current-directory (or (path-only source-path)
                                          (current-directory))])
      (call-with-input-file source-path
        (lambda (in)
          (read-syntax (path->string source-path) in)))))
  (namespace-set-variable-value! 'target-stx source-stx #t compiler-ns)
  (parameterize ([current-directory (or (path-only source-path)
                                        (current-directory))])
    (eval
     `(let ()
        (reset-counter!)
        (define p0  (parse (unexpand (topexpand target-stx))))
        (define s0  (simplify-LFE p0))
        (define ft  (flatten-topbegin s0))
        (define in  (infer-names ft))
        (define cq  (convert-quotations in))
        (define eb  (explicit-begin cq))
        (define ecl (explicit-case-lambda eb))
        (define ar  (α-rename ecl))
        (define ua  (uncover-assigned! ar))
        (define lr  (parameterize ([current-assigned-analysis ua])
                      (lower-letrec-values ar)))
        (define ac  (parameterize ([current-assigned-analysis ua])
                      (assignment-conversion lr)))
        (define ca  (categorize-applications ac))
        (define an  (anormalize ca))
        (parameterize ([current-enable-cc-analysis? #t])
          (,summarize-sym an)))
     compiler-ns)))

(define (histogram key xs)
  (define ht (make-hash))
  (for ([x (in-list xs)])
    (define k (key x))
    (hash-set! ht k (add1 (hash-ref ht k 0))))
  (sort (hash->list ht)
        (lambda (a b)
          (cond
            [(and (symbol? (car a)) (symbol? (car b)))
             (symbol<? (car a) (car b))]
            [else
             (< (car a) (car b))]))))

(define (safe-average xs)
  (if (null? xs)
      0.0
      (/ (apply + xs) (exact->inexact (length xs)))))

(define (entry-binder e)   (list-ref e 1))
(define (entry-kind e)     (list-ref e 2))
(define (entry-origin e)   (list-ref e 3))
(define (entry-body e)     (list-ref e 5))
(define (entry-closure e)  (list-ref e 6))
(define (entry-ext e)      (list-ref e 7))
(define (entry-known e)    (list-ref e 8))
(define (entry-only e)     (list-ref e 9))
(define (entry-del-clos e) (list-ref e 10))
(define (entry-del-code e) (list-ref e 11))
(define (entry-shape e)    (list-ref e 12))
(define (entry-in e)       (list-ref e 13))
(define (entry-out e)      (list-ref e 14))
(define (entry-blockers e) (list-ref e 15))

(define (print-section title rows)
  (printf "~a\n" title)
  (for ([row (in-list rows)])
    (match row
      [(cons k v)
       (printf "  ~a: ~a\n" k v)])))

(define (print-summary source-path summary)
  (define direct-entries
    (filter (lambda (e) (eq? (entry-kind e) 'direct)) summary))
  (define ext-direct
    (filter (lambda (e) (member (entry-ext e) '(0 1 2))) direct-entries))
  (define blocker-rows
    (histogram values
               (append*
                (map entry-blockers summary))))
  (printf "Source: ~a\n" source-path)
  (printf "Entries: ~a total, ~a direct\n"
          (length summary)
          (length direct-entries))
  (printf "Deletion payoff:\n")
  (printf "  delete closure allocation: ~a\n"
          (count entry-del-clos direct-entries))
  (printf "  delete ordinary $ClosureCode: ~a\n"
          (count entry-del-code direct-entries))
  (printf "  shape-only churn: ~a\n"
          (count entry-shape direct-entries))
  (printf "Env frontier counts (direct helpers, ext-size 0/1/2):\n")
  (printf "  zero-env:   ~a\n"
          (count (lambda (e) (= (entry-ext e) 0)) ext-direct))
  (printf "  unary-env:  ~a\n"
          (count (lambda (e) (= (entry-ext e) 1)) ext-direct))
  (printf "  binary-env: ~a\n"
          (count (lambda (e) (= (entry-ext e) 2)) ext-direct))
  (print-section "Known ABI classes:" (histogram entry-known direct-entries))
  (print-section "Known-only classes:" (histogram entry-only direct-entries))
  (print-section "Origins:" (histogram entry-origin summary))
  (printf "Direct-call graph:\n")
  (printf "  max in-degree:  ~a\n" (if (null? direct-entries) 0 (apply max (map entry-in direct-entries))))
  (printf "  avg in-degree:  ~a\n" (~r (safe-average (map entry-in direct-entries)) #:precision '(= 2)))
  (printf "  max out-degree: ~a\n" (if (null? direct-entries) 0 (apply max (map entry-out direct-entries))))
  (printf "  avg out-degree: ~a\n" (~r (safe-average (map entry-out direct-entries)) #:precision '(= 2)))
  (print-section "Body-layout sizes:" (histogram entry-body direct-entries))
  (print-section "Closure-env sizes:" (histogram entry-closure direct-entries))
  (print-section "Extended-needs sizes:" (histogram entry-ext direct-entries))
  (unless (null? blocker-rows)
    (print-section "Blockers:" blocker-rows))
  (newline))

(for ([source-path (in-list source-paths)])
  (define summary
    (analyze-source source-path
                    'summarize-direct-helper-payoff-frontier-closure-conversion-analysis))
  (print-summary source-path summary))
