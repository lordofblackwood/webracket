#lang racket/base

(require racket/file
         racket/list
         rackunit
         "module-adapter.rkt"
         "read-provider.rkt")

(test-case "expander/read provider demodularizes and caches"
  (define cache-dir (make-temporary-file "webracket-read-provider-cache-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define-values (status output out-rktl)
        (webify-read-demod! #:cache-root cache-dir #:force? #t))
      (check-equal? status 0 output)
      (check-true (file-exists? out-rktl))
      (define-values (status2 output2 out-rktl2)
        (webify-read-demod! #:cache-root cache-dir))
      (check-equal? status2 0 output2)
      (check-equal? out-rktl2 out-rktl)
      (check-true (regexp-match? #rx"cached expander/read" output2)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(test-case "expander/read provider exposes Webify-owned export names"
  (define cache-dir (make-temporary-file "webracket-read-provider-cache-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define lk
        (webify-read-linklet #:cache-root cache-dir #:force? #t))
      (define-values (_provider-stx exports _exports-info)
        (webify-linklet-first-slice-top-level
         lk
         #:define-export-aliases? #f
         #:serializable?-box     #f
         #:datum-intern?         #f
         #:target                #f
         #:allow-set!-undefined? #f
         #:unsafe-mode?          #f
         #:enforce-constant?     #t
         #:allow-inline?         #t
         #:no-prompt?            #f
         #:prim-knowns           (hasheq)
         #:primitives            (hasheq)
         #:compiler-query        (lambda (v) #f)
         #:get-import-knowns     (lambda (key) (values #f #f #f))
         #:import-keys           #f))
      (check-equal? (sort exports symbol<?)
                    (sort webify-read-export-symbols symbol<?)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(module+ main
  (void))
