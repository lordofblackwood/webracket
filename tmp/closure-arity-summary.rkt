#lang racket

(require racket/match
         racket/pretty
         racket/runtime-path)

(define-runtime-path compiler-path "../compiler.rkt")

(define (usage)
  (eprintf "usage: racket tmp/closure-arity-summary.rkt <source-file>\n")
  (exit 1))

(define args (current-command-line-arguments))
(when (not (= (vector-length args) 1))
  (usage))

(define source-path
  (path->complete-path (vector-ref args 0) (current-directory)))

(dynamic-require compiler-path #f)
(define compiler-ns (module->namespace `(file ,(path->string compiler-path))))

(define source-stx
  (call-with-input-file source-path
    (lambda (in)
      (read-syntax (path->string source-path) in))))

(namespace-set-variable-value! 'target-stx source-stx #t compiler-ns)

(define results
  (eval
   '(let ()
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
        (list
         (summarize-closure-layout-arity-counts-closure-conversion-analysis an)
         (summarize-closure-layout-arity-closure-conversion-analysis an))))
   compiler-ns))

(match-define (list counts details) results)

(printf "Source: ~a\n" source-path)
(printf "Counts:\n")
(for ([entry (in-list counts)])
  (match entry
    [(list bucket count)
     (printf "  ~a: ~a\n" bucket count)]))

(printf "Top detail sample (first 20):\n")
(for ([entry (in-list (take details (min 20 (length details))))])
  (pretty-print entry))
