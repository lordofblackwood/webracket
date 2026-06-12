#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/bridge-stats.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-adapter.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-instance.rkt")

;; datum-contains? : any/c any/c -> boolean?
;;   Check whether target appears anywhere within datum.
(define (datum-contains? datum target)
  (or (equal? datum target)
      (cond
        [(pair? datum)
         (or (datum-contains? (car datum) target)
             (datum-contains? (cdr datum) target))]
        [(vector? datum)
         (for/or ([entry (in-vector datum)])
           (datum-contains? entry target))]
        [else
         #f])))

(test-case "cell-backed imports still read module-variable cells"
  (define datum
    (first-slice->top-level-datum/imports
     '(lambda (instance import-arg out-cell)
        imported)
     '(provider-cell)
     '(out)
     #:importss '((imported))
     #:imports-abis '((#f))))
  (check-true
   (datum-contains? datum
                    '(define imported (module-variable-ref import-arg))))
  (check-false
   (datum-contains? datum
                    '(define imported import-arg))))

(test-case "value-backed imports bind direct lexical values"
  (define datum
    (first-slice->top-level-datum/imports
     '(lambda (instance import-arg out-cell)
        imported)
     '(provider-value)
     '(out)
     #:importss '((imported))
     #:imports-abis '((#t))))
  (check-true
   (datum-contains? datum
                    '(define imported import-arg)))
  (check-false
   (datum-contains? datum
                    '(define imported (module-variable-ref import-arg)))))

(test-case "top-level export aliases reuse internal cached values"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell) (void))
     exports))
  (check-true
   (datum-contains? datum
                    `(define ,value-id (module-variable-ref ,cell-id))))
  (check-true
   (datum-contains? datum
                    `(define out ,value-id))))

(test-case "module instances expose direct value ids for value-safe imports"
  (define provider
    (make-webify-module-instance 'provider '(x)))
  (define provider-value-id
    (webify-module-instance-export-value-id provider 'x))
  (define provider-cell-id
    (webify-module-instance-export-cell-id provider 'x))
  (define-values (datum _instance)
    (first-slice->module-instance-datum/imports
     'consumer
     '(lambda (instance import-arg out-cell)
        imported)
     '((imported))
     (list (hasheq 'imported provider-value-id))
     '(out)
     #:imports-abis '((#t))))
  (check-true
   (datum-contains? datum
                    '(define imported import-arg)))
  (check-true
   (datum-contains? datum
                    `(webify-linklet-proc$0 (#%variable-reference) ,provider-value-id webify-export-cell0$0)))
  (check-false
   (datum-contains? datum
                    `(webify-linklet-proc$0 (#%variable-reference) ,provider-cell-id webify-export-cell0$0))))

(test-case "bridge stats count direct and cell-backed import decisions"
  (define stats (make-hasheq))
  (parameterize ([current-webify-bridge-stats stats])
    (first-slice->top-level-datum/imports
     '(lambda (instance cell-arg value-arg out-cell)
        imported-cell
        imported-value)
     '(provider-cell provider-value)
     '(out)
     #:importss '((imported-cell imported-value))
     #:imports-abis '((#f #t))))
  (check-equal? (hash-ref stats 'bridge-import-cell-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-direct-import-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-cell-elision-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-export-cell-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-module-variable-make-count 0) 1))

(module+ main
  (void))
