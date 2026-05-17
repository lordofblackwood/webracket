#lang racket/base

(require racket/file
         racket/linklet
         racket/string
         rackunit
         "read-syntax-provider.rkt")

(test-case "read-syntax staging demodularizes"
  (define cache-dir (make-temporary-file "webracket-read-syntax-boundary-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define-values (status output)
        (webify-read-syntax-demod! cache-dir))
      (check-equal? status 0 output)
      (check-true (file-exists? (build-path cache-dir "read-syntax.rktl"))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(test-case "read-syntax provider reads a tiny syntax object"
  (define cache-dir (make-temporary-file "webracket-read-syntax-smoke-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define-values (status output)
        (webify-read-syntax-demod! cache-dir))
      (check-equal? status 0 output)
      (define linklet-datum
        (call-with-input-file (build-path cache-dir "read-syntax.rktl") read))
      (define instance
        (instantiate-linklet (compile-linklet linklet-datum) null))
      (define read-syntax*
        (instance-variable-value instance 'webify-expander-read-syntax))
      (define syntax->datum*
        (instance-variable-value instance 'webify-expander-syntax->datum))
      (define syntax-source*
        (instance-variable-value instance 'webify-expander-syntax-source))
      (define syntax-line*
        (instance-variable-value instance 'webify-expander-syntax-line))
      (define syntax-column*
        (instance-variable-value instance 'webify-expander-syntax-column))
      (define syntax-position*
        (instance-variable-value instance 'webify-expander-syntax-position))
      (define in (open-input-string "42"))
      (port-count-lines! in)
      (define stx (read-syntax* 'src in))
      (check-equal? (syntax->datum* stx) 42)
      (check-equal? (syntax-source* stx) 'src)
      (check-equal? (syntax-line* stx) 1)
      (check-equal? (syntax-column* stx) 0)
      (check-equal? (syntax-position* stx) 1))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(module+ main
  (void))
