#lang racket/base

(require racket/file
         racket/string
         rackunit
         "expander-oracle.rkt"
         "primitive-demands.rkt")

(test-case "expander oracle extraction command targets a closed linklet"
  (define tmp-dir (make-temporary-file "webracket-expander-oracle-test-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define args (webify-expander-oracle-extraction-args tmp-dir))
      (check-not-false (member "--no-global" args))
      (check-not-false (member "++direct" args))
      (check-not-false (member "++global-ok" args))
      (check-true
       (for/or ([arg (in-list args)])
         (string-contains? arg "expander.rktl"))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files tmp-dir)))))

(test-case "expander oracle TSV printer is machine readable"
  (define report
    (webify-expander-oracle-report
     "expander.rktl"
     0
     2
     (list (webify-primitive-demand '#%kernel 'cons '(full-expander)))
     (list (webify-primitive-demand '#%kernel 'missing-name '(full-expander)))
     '()))
  (define out (open-output-string))
  (parameterize ([current-output-port out])
    (print-expander-oracle-demands-tsv report #t))
  (check-equal?
   (string-split (get-output-string out) "\n" #:trim? #t)
   '("module\tname\tsources"
     "#%kernel\tmissing-name\t(full-expander)")))

(test-case "expander oracle has no missing primitive demands"
  (define tmp-dir (make-temporary-file "webracket-expander-oracle-run-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define report (webify-expander-oracle-run! tmp-dir #:verbose? #f))
      (check-equal? (webify-expander-oracle-report-linklet-import-count report) 0)
      (check-equal? (webify-expander-oracle-report-missing-primitive-demands report)
                    '()))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files tmp-dir)))))

(module+ main
  (void))
