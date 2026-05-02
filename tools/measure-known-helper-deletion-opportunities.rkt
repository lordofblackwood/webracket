#lang racket

(require racket/list
         racket/match
         racket/path
         racket/runtime-path)

(define-runtime-path repo-root "..")
(define-runtime-path compiler-path "../compiler.rkt")

(define default-targets
  (list (build-path repo-root "test" "test-letrec.rkt")
        (build-path repo-root "test" "test-basics.rkt")
        (build-path repo-root "examples" "pict" "pict.rkt")))

(define (usage)
  (eprintf "usage: racket tools/measure-known-helper-deletion-opportunities.rkt [source-file ...]\n")
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

(define (histogram xs)
  (define ht (make-hash))
  (for ([x (in-list xs)])
    (hash-set! ht x (add1 (hash-ref ht x 0))))
  (sort (hash->list ht)
        (lambda (a b)
          (cond
            [(and (symbol? (car a)) (symbol? (car b)))
             (symbol<? (car a) (car b))]
            [else
             (string<? (~a (car a)) (~a (car b)))]))))

(define (print-section title rows)
  (printf "~a\n" title)
  (for ([row (in-list rows)])
    (match row
      [(cons k v)
       (printf "  ~a: ~a\n" k v)])))

;; Entry shape:
;; (list label binder origin known-abi known-only
;;       closure-allocation-remains? ordinary-closure-code-remains?
;;       value-use? callers-can-source-env? nested-lift-sensitive?
;;       nested-capture-vars letrec? recursive?
;;       deletes-allocation-and-base-label? blockers)
(define (entry-binder e)          (list-ref e 1))
(define (entry-origin e)          (list-ref e 2))
(define (entry-known-abi e)       (list-ref e 3))
(define (entry-known-only e)      (list-ref e 4))
(define (entry-clos-remains e)    (list-ref e 5))
(define (entry-code-remains e)    (list-ref e 6))
(define (entry-value-use e)       (list-ref e 7))
(define (entry-callers-source e)  (list-ref e 8))
(define (entry-nested-lift e)     (list-ref e 9))
(define (entry-nested-capture e)  (list-ref e 10))
(define (entry-letrec e)          (list-ref e 11))
(define (entry-recursive e)       (list-ref e 12))
(define (entry-deletes-both e)    (list-ref e 13))
(define (entry-blockers e)        (list-ref e 14))

(define (print-summary source-path summary)
  (printf "Source: ~a\n" source-path)
  (printf "Known-family entries: ~a\n" (length summary))
  (printf "Deletion-producing entries: ~a\n" (count entry-deletes-both summary))
  (printf "Closure allocation still remains: ~a\n" (count entry-clos-remains summary))
  (printf "Ordinary $ClosureCode still remains: ~a\n" (count entry-code-remains summary))
  (printf "Caller env already sourceable: ~a\n" (count entry-callers-source summary))
  (print-section "Current known ABI classes:" (histogram (map entry-known-abi summary)))
  (print-section "Current known-only classes:" (histogram (map entry-known-only summary)))
  (print-section "Origins:" (histogram (map entry-origin summary)))
  (printf "Blocker slices:\n")
  (printf "  value-use: ~a\n" (count entry-value-use summary))
  (printf "  nested-lift-sensitive: ~a\n" (count entry-nested-lift summary))
  (printf "  nested-capture: ~a\n" (count (lambda (e) (not (null? (entry-nested-capture e)))) summary))
  (printf "  letrec: ~a\n" (count entry-letrec summary))
  (printf "  recursive: ~a\n" (count entry-recursive summary))
  (unless (null? summary)
    (print-section "Blockers:" (histogram (append* (map entry-blockers summary)))))
  (newline))

(for ([source-path (in-list source-paths)])
  (define summary
    (analyze-source source-path
                    'summarize-known-helper-deletion-opportunities-closure-conversion-analysis))
  (print-summary source-path summary))
