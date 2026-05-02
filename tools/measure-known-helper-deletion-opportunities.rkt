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
(define (entry-label e)           (list-ref e 0))
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

;; Layout entry shape:
;; (list binder kind body-layout closure-env extended-needs layout-matches-extended?)
(define (layout-entry-binder e)        (list-ref e 0))
(define (layout-entry-body-layout e)   (list-ref e 2))
(define (layout-entry-closure-env e)   (list-ref e 3))
(define (layout-entry-extended-needs e)(list-ref e 4))

;; Availability entry shape:
;; (list caller callee caller-kind caller-formals caller-layout
;;       available needed missing ok?)
(define (availability-entry-caller e)        (list-ref e 0))
(define (availability-entry-callee e)        (list-ref e 1))
(define (availability-entry-formals e)       (list-ref e 3))
(define (availability-entry-layout e)        (list-ref e 4))
(define (availability-entry-needed e)        (list-ref e 6))
(define (availability-entry-missing e)       (list-ref e 7))
(define (availability-entry-ok? e)           (list-ref e 8))

(define blocker-drilldown-order
  '(unavailable-env nested-lift-sensitive nested-capture letrec recursive value-use))

(define (remaining-transition-tax? e)
  (and (entry-clos-remains e)
       (entry-code-remains e)))

(define (pure-unavailable-env-residue? e)
  (and (eq? (entry-known-abi e) 'known1)
       (eq? (entry-known-only e) 'none)
       (remaining-transition-tax? e)
       (eq? (entry-origin e) 'let-values)
       (not (entry-value-use e))
       (not (entry-letrec e))
       (not (entry-recursive e))
       (not (entry-nested-lift e))
       (null? (entry-nested-capture e))
       (not (entry-callers-source e))
       (equal? (entry-blockers e) '(unavailable-env))))

(define (entry-has-blocker? blocker e)
  (member blocker (entry-blockers e)))

(define (take-up-to xs n)
  (take xs (min n (length xs))))

(define (print-entry-drilldown e)
  (printf "    ~a (~a)\n"
          (entry-binder e)
          (entry-known-abi e))
  (printf "      label: ~a\n" (entry-label e))
  (printf "      origin: ~a\n" (entry-origin e))
  (printf "      known-only: ~a\n" (entry-known-only e))
  (printf "      callers-can-source-env: ~a\n" (entry-callers-source e))
  (printf "      nested-lift-sensitive: ~a\n" (entry-nested-lift e))
  (printf "      nested-capture-vars: ~a\n" (entry-nested-capture e))
  (printf "      letrec: ~a\n" (entry-letrec e))
  (printf "      recursive: ~a\n" (entry-recursive e))
  (printf "      blockers: ~a\n" (entry-blockers e)))

;; Explanation entry shape:
;; (list callee-binder callee-label caller-binder caller-label
;;       callee-extended-env
;;       caller-body-layout caller-closure-env caller-formals caller-extended-needs
;;       missing-env
;;       lexical-available?
;;       caller-should-carry?
;;       only-body-layout-growth?
;;       closure-payload-growth?
;;       call-chain
;;       classifications)
(define (print-pure-explanation e)
  (match e
    [(list callee callee-label caller caller-label
           callee-extended-env
           caller-body-layout caller-closure-env caller-formals caller-extended-needs
           missing-env
           lexical-available?
           caller-should-carry?
           only-body-layout-growth?
           closure-payload-growth?
           call-chain
           classifications)
     (printf "    ~a <- ~a\n" callee caller)
     (printf "      callee-label: ~a\n" callee-label)
     (printf "      caller-label: ~a\n" caller-label)
     (printf "      callee-extended-env: ~a\n" callee-extended-env)
     (printf "      caller-body-layout: ~a\n" caller-body-layout)
     (printf "      caller-closure-env: ~a\n" caller-closure-env)
     (printf "      caller-formals: ~a\n" caller-formals)
     (printf "      caller-extended-needs: ~a\n" caller-extended-needs)
     (printf "      missing-env: ~a\n" missing-env)
     (printf "      lexical-available?: ~a\n" lexical-available?)
     (printf "      caller-should-carry?: ~a\n" caller-should-carry?)
     (printf "      only-body-layout-growth?: ~a\n" only-body-layout-growth?)
     (printf "      closure-payload-growth?: ~a\n" closure-payload-growth?)
     (printf "      call-chain: ~a\n" call-chain)
     (printf "      classifications: ~a\n" classifications)]))

(define (build-binder-map entries binder-of)
  (for/hash ([e (in-list entries)]
             #:when (binder-of e))
    (values (binder-of e) e)))

(define (build-incoming-map availability-summary)
  (define incoming (make-hash))
  (for ([e (in-list availability-summary)])
    (define caller (availability-entry-caller e))
    (define callee (availability-entry-callee e))
    (when caller
      (hash-set! incoming caller (hash-ref incoming caller '())))
    (when callee
      (hash-set! incoming callee
                 (cons caller (hash-ref incoming callee '())))))
  incoming)

(define (shortest-root-chain incoming target)
  (define (walk x seen)
    (cond
      [(member x seen) (list x)]
      [else
       (define callers (filter values (hash-ref incoming x '())))
       (cond
         [(null? callers) (list x)]
         [else
          (argmin length
                  (for/list ([caller (in-list callers)])
                    (append (walk caller (cons x seen)) (list x))))])]))
  (walk target '()))

(define (compute-pure-explanations summary layout-summary availability-summary)
  (define layout-map (build-binder-map layout-summary layout-entry-binder))
  (define incoming   (build-incoming-map availability-summary))
  (define residue
    (filter pure-unavailable-env-residue? summary))
  (remove-duplicates
   (append*
    (for/list ([e (in-list residue)])
     (define callee (entry-binder e))
     (define callee-label (entry-label e))
     (define callee-layout-entry (hash-ref layout-map callee #f))
     (define callee-extended-env
       (if callee-layout-entry
           (layout-entry-extended-needs callee-layout-entry)
           '()))
     (for/list ([edge (in-list availability-summary)]
                #:when (and (equal? (availability-entry-callee edge) callee)
                            (not (availability-entry-ok? edge))
                            (equal? (availability-entry-missing edge) callee-extended-env)))
       (define caller (availability-entry-caller edge))
       (define caller-layout-entry (hash-ref layout-map caller #f))
       (define caller-body-layout
         (if caller-layout-entry
             (layout-entry-body-layout caller-layout-entry)
             (availability-entry-layout edge)))
       (define caller-closure-env
         (if caller-layout-entry
             (layout-entry-closure-env caller-layout-entry)
             '()))
       (define caller-extended-needs
         (if caller-layout-entry
             (layout-entry-extended-needs caller-layout-entry)
             '()))
       (define missing-env (availability-entry-missing edge))
       (define lexical-available?
         (for/and ([x (in-list missing-env)])
           (not (not (member x caller-closure-env)))))
       (define caller-should-carry?
         (for/and ([x (in-list missing-env)])
           (not (not (member x caller-extended-needs)))))
       (define only-body-layout-growth?
         (and lexical-available?
              (not (null? missing-env))))
       (define closure-payload-growth?
         (for/or ([x (in-list missing-env)])
           (not (member x caller-closure-env))))
       (define call-chain
         (shortest-root-chain incoming callee))
       (define classifications
         (append
          (if caller-should-carry? '(caller-should-carry) '())
          (if lexical-available? '(caller-can-use-lexical) '())
          (if only-body-layout-growth? '(only-body-layout-growth) '())
          (if closure-payload-growth? '(closure-payload-cost) '())
          (if (> (length call-chain) 2) '(direct-chain-cost) '())))
       (list callee
             callee-label
             caller
             #f
             callee-extended-env
             caller-body-layout
             caller-closure-env
             (availability-entry-formals edge)
             caller-extended-needs
             missing-env
             lexical-available?
             caller-should-carry?
             only-body-layout-growth?
             closure-payload-growth?
             call-chain
             classifications))))
   equal?))

(define (print-blocker-drilldown summary)
  (define remaining
    (filter remaining-transition-tax? summary))
  (unless (null? remaining)
    (printf "Representative remaining transition-tax entries:\n")
    (for ([blocker (in-list blocker-drilldown-order)])
      (define matches
        (filter (λ (e) (entry-has-blocker? blocker e)) remaining))
      (unless (null? matches)
        (printf "  blocker ~a (~a total):\n" blocker (length matches))
        (for ([e (in-list (take-up-to matches 3))])
          (print-entry-drilldown e))))))

(define (print-pure-unavailable-env-residue summary)
  (define residue
    (filter pure-unavailable-env-residue? summary))
  (printf "Pure unavailable-env residue: ~a\n" (length residue))
  (unless (null? residue)
    (printf "Representative pure unavailable-env residue entries:\n")
    (for ([e (in-list (take-up-to residue 3))])
      (print-entry-drilldown e))))

(define (print-summary source-path summary explanations)
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
  (print-pure-unavailable-env-residue summary)
  (unless (null? explanations)
    (printf "Pure unavailable-env explanations:\n")
    (for ([e (in-list explanations)])
      (print-pure-explanation e)))
  (unless (null? summary)
    (print-section "Blockers:" (histogram (append* (map entry-blockers summary)))))
  (print-blocker-drilldown summary)
  (newline))

(for ([source-path (in-list source-paths)])
  (define summary
    (analyze-source source-path
                    'summarize-known-helper-deletion-opportunities-closure-conversion-analysis))
  (define layout-summary
    (analyze-source source-path
                    'summarize-direct-helper-layout-concepts-closure-conversion-analysis))
  (define availability-summary
    (analyze-source source-path
                    'summarize-direct-helper-env-availability-closure-conversion-analysis))
  (define explanations
    (compute-pure-explanations summary
                               layout-summary
                               availability-summary))
  (print-summary source-path summary explanations))
