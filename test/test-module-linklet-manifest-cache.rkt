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

(test-case "module import resolver indexes generated export names"
  (define-values (imports outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (((local foo.2))) () local)
     '((provider-a (bar))
       (provider-b (foo.1)))
     #:module-name 'demo))
  (check-equal? imports '((local provider-b foo.1)))
  (check-equal?
   (map (lambda (outcome)
          (list (webify-module-resolution-outcome-dependency outcome)
                (webify-module-resolution-outcome-provider-export outcome)
                (webify-module-resolution-outcome-status outcome)))
        outcomes)
   '((provider-b foo.1 resolved-by-export-scan))))

(test-case "module import resolver keeps dependency row order for indexed candidates"
  (define message
    (with-handlers ([exn:fail? exn-message])
      (webify-resolve-module-linklet-imports/outcomes
       '(linklet (((local foo.9))) () local)
       '((provider-a (foo.1))
         (provider-b (foo.2)))
       #:module-name 'demo)
      #f))
  (check-true (string? message))
  (check-not-false (regexp-match? #rx"candidates: '\\(provider-a provider-b\\)" message)))

(module+ main
  (void))
