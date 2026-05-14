#lang racket/base

(provide known-module-cases
         module-case-data
         extract-case-inputs
         input-names
         set-diff
         print-case-summary
         print-case-delta)

(require racket/cmdline
         racket/list
         racket/match
         racket/string
         "module-extractor.rkt"
         "module-input.rkt"
         "module-protocol.rkt"
         "primitive-demands.rkt")

(define known-module-cases
  '(set-require
    set-predicate
    set-count
    set-member
    set-add
    set-remove
    set-union
    set->list
    stream-first
    stream-rest
    hash-basic
    combined-list-string-set
    pretty-require
    custom-write-require
    set-types-require
    set-types-predicate))

;; module-case-data : symbol? -> (listof source-module-datum?)
;;   Return a small installed-module source slice for dependency probing.
(define (module-case-data name)
  (case name
    [(set-require)
     '((module use-set-require-only racket/base
         (require racket/set)
         (provide y)
         (define y 42)))]
    [(set-predicate)
     '((module use-set-predicate racket/base
         (require racket/set)
         (provide y)
         (define y (set? 42))))]
    [(set-count)
     '((module use-set-count racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set 1 2 2)))))]
    [(set-member)
     '((module use-set-member racket/base
         (require racket/set)
         (provide y)
         (define y (set-member? (set 'a 'b) 'b))))]
    [(set-add)
     '((module use-set-add racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set-add (set 1 2) 3)))))]
    [(set-remove)
     '((module use-set-remove racket/base
         (require racket/set)
         (provide y)
         (define y (set-member? (set-remove (set 'a 'b) 'a) 'a))))]
    [(set-union)
     '((module use-set-union racket/base
         (require racket/set)
         (provide y)
         (define y (set-count (set-union (set 1 2) (set 2 3))))))]
    [(set->list)
     '((module use-set-to-list racket/base
         (require racket/set)
         (provide y)
         (define y (length (set->list (set 1 2))))))]
    [(stream-first)
     '((module use-stream-first racket/base
         (require racket/stream)
         (provide y)
         (define y (stream-first (stream 42)))))]
    [(stream-rest)
     '((module use-stream-rest racket/base
         (require racket/stream)
         (provide y)
         (define y (stream-first (stream-rest (stream 40 42))))))]
    [(hash-basic)
     '((module use-hash-basic racket/base
         (provide y)
         (define y
           (hash-ref (hash-set (make-immutable-hash '((a . 1))) 'b 41)
                     'b))))]
    [(combined-list-string-set)
     '((module use-combined-list-string-set racket/base
         (require racket/list racket/string racket/set)
         (provide y)
         (define y
           (+ (first '(37 38))
              (string-length (string-join '("ab" "c") ""))
              (set-count (set 'x 'y 'y))))))]
    [(pretty-require)
     '((module use-pretty-require racket/base
         (require racket/pretty)
         (provide y)
         (define y 42)))]
    [(custom-write-require)
     '((module use-custom-write-require racket/base
         (require racket/private/custom-write)
         (provide y)
         (define y 42)))]
    [(set-types-require)
     '((module use-set-types-require racket/base
         (require racket/private/set-types)
         (provide y)
         (define y 42)))]
    [(set-types-predicate)
     '((module use-set-types-predicate racket/base
         (require racket/private/set-types)
         (provide y)
         (define y (set? 42))))]
    [else
     (raise-user-error 'probe-installed-module-deps
                       "unknown case ~a; expected one of ~a"
                       name
                       known-module-cases)]))

;; extract-case-inputs : symbol? -> (listof webify-module-linklet-input?)
;;   Extract the demand-sliced installed provider graph for one case.
(define (extract-case-inputs name)
  (webify-source-modules->discovered-resolved-linklet-inputs
   (module-case-data name)
   #:extra-reports (list webify-module-protocol-report)
   #:module-protocol-dependency webify-module-protocol-dependency
   #:demand-slice? #t))

;; input-names : (listof webify-module-linklet-input?) -> (listof symbol?)
;;   Return extracted module names in manifest order.
(define (input-names inputs)
  (map webify-module-linklet-input-name inputs))

;; symbol<?* : symbol? symbol? -> boolean?
;;   Sort symbols by printed name.
(define (symbol<?* a b)
  (string<? (symbol->string a) (symbol->string b)))

;; set-diff : (listof symbol?) (listof symbol?) -> (listof symbol?)
;;   Return sorted names in xs but not ys.
(define (set-diff xs ys)
  (define ys-table (for/hasheq ([y (in-list ys)]) (values y #t)))
  (sort (filter (lambda (x) (not (hash-has-key? ys-table x))) xs) symbol<?*))

;; print-case-summary : symbol? (listof input?) -> void?
;;   Print a compact dependency and primitive-demand summary.
(define (print-case-summary name inputs)
  (define report (webify-module-linklet-inputs->primitive-demands inputs))
  (printf "case: ~a\n" name)
  (printf "input-count: ~a\n" (length inputs))
  (printf "inputs: ~s\n" (input-names inputs))
  (printf "primitive-demand-count: ~a\n"
          (length (webify-primitive-demand-report-demands report)))
  (printf "missing-primitive-demand-count: ~a\n"
          (length (webify-primitive-demand-report-missing report))))

;; print-case-delta : symbol? inputs symbol? inputs -> void?
;;   Print module-name deltas between two extracted cases.
(define (print-case-delta baseline baseline-inputs current current-inputs)
  (define baseline-names (input-names baseline-inputs))
  (define current-names  (input-names current-inputs))
  (printf "baseline-case: ~a\n" baseline)
  (printf "current-case: ~a\n" current)
  (printf "added-inputs: ~s\n" (set-diff current-names baseline-names))
  (printf "removed-inputs: ~s\n" (set-diff baseline-names current-names)))

(module+ main
  (define selected-case 'set-require)
  (define baseline-case #f)

  (command-line
   #:program "probe-installed-module-deps"
   #:once-each
   [("--case") name "case to extract"
               (set! selected-case (string->symbol name))]
   [("--baseline") name "optional case to diff against"
                   (set! baseline-case (string->symbol name))])

  (define selected-inputs (extract-case-inputs selected-case))
  (print-case-summary selected-case selected-inputs)
  (when baseline-case
    (newline)
    (define baseline-inputs (extract-case-inputs baseline-case))
    (print-case-summary baseline-case baseline-inputs)
    (newline)
    (print-case-delta baseline-case baseline-inputs selected-case selected-inputs)))
