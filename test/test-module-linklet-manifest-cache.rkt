#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt")

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

(test-case "manifest parser decodes cached hash transport markers in linklet data"
  (define manifest-datum
    '(webify-module-linklet-manifest
      (roots (demo))
      (input demo
             (linklet ()
                      ()
                      (quote (webracket-cache:hash
                              eq
                              ((put 4)
                               (prog 14)))))
             (imports ()))))
  (define manifest
    (datum->webify-module-linklet-manifest manifest-datum))
  (define input
    (car (webify-module-linklet-manifest-inputs manifest)))
  (define linklet
    (webify-module-linklet-input-linklet input))
  (check-false
   (datum-contains? linklet 'webracket-cache:hash))
  (check-equal?
   linklet
   `(linklet ()
             ()
             ',(hasheq 'put 4
                       'prog 14))))

(module+ main
  (void))
