#lang racket/base

(require racket/file
         racket/string
         rackunit
         "read-syntax-provider.rkt")

(test-case "read-syntax staging reaches the next missing weaker-inspector dependency"
  (define cache-dir (make-temporary-file "webracket-read-syntax-boundary-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define-values (status output)
        (webify-read-syntax-demod! cache-dir))
      (check-equal? status 1 output)
      (check-true
       (string-contains? output "racket-src/expander/syntax/weaker-inspector.rkt")
       output)
      (check-false
       (string-contains? output "racket-src/expander/syntax/taint-object.rkt\n  system error")
       output))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(module+ main
  (void))
