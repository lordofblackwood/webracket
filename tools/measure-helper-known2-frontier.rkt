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
  (eprintf "usage: racket tools/measure-helper-known2-frontier.rkt [source-file ...]\n")
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
;; (list label binder origin fixed-arity? direct? value-use? self-recursive?
;;       letrec? plain-lambda? nested-lift-sensitive? nested-capture-vars
;;       current-body-layout closure-env extended-needs
;;       body-layout-equals-extended? extended-needs-in-closure-env?
;;       incoming-direct-callers all-callers-can-source-both-envs?
;;       would-be-sibling-only-safe? blockers)
(define (entry-origin e)     (list-ref e 2))
(define (entry-direct? e)    (list-ref e 4))
(define (entry-value-use? e) (list-ref e 5))
(define (entry-letrec? e)    (list-ref e 7))
(define (entry-body e)       (length (list-ref e 11)))
(define (entry-closure e)    (length (list-ref e 12)))
(define (entry-ext e)        (length (list-ref e 13)))
(define (entry-callers e)    (length (list-ref e 16)))
(define (entry-can-source e) (list-ref e 17))
(define (entry-safe? e)      (list-ref e 18))
(define (entry-blockers e)   (list-ref e 19))

(define (print-summary source-path summary)
  (define total (length summary))
  (define safe-count (count entry-safe? summary))
  (define blocker-rows
    (histogram
     (append* (map entry-blockers summary))))
  (printf "Source: ~a\n" source-path)
  (printf "Binary frontier entries: ~a\n" total)
  (printf "Sibling-only safe: ~a\n" safe-count)
  (printf "Caller env sourceable: ~a\n" (count entry-can-source summary))
  (printf "Would be blocked: ~a\n" (- total safe-count))
  (printf "Direct/value-origin slices:\n")
  (printf "  direct: ~a\n" (count entry-direct? summary))
  (printf "  value-use: ~a\n" (count entry-value-use? summary))
  (printf "  letrec-origin: ~a\n" (count entry-letrec? summary))
  (print-section "Origins:" (histogram (map entry-origin summary)))
  (print-section "Current body-layout sizes:" (histogram (map entry-body summary)))
  (print-section "Closure-env sizes:" (histogram (map entry-closure summary)))
  (print-section "Incoming direct-caller counts:" (histogram (map entry-callers summary)))
  (unless (null? blocker-rows)
    (print-section "Blockers:" blocker-rows))
  (newline))

(for ([source-path (in-list source-paths)])
  (define summary
    (analyze-source source-path
                    'summarize-direct-helper-known2-frontier-closure-conversion-analysis))
  (print-summary source-path summary))
