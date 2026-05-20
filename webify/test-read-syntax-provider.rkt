#lang racket/base

(require racket/file
         racket/linklet
         racket/string
         rackunit
         "../pkgs/webracket-lib/compiler/webify/read-syntax-provider.rkt")

(define shared-read-syntax-cache-dir
  (make-temporary-file "webracket-read-syntax-shared-cache-~a" 'directory))

(test-case "read-syntax staging demodularizes"
  (define-values (status output out-rktl)
    (webify-read-syntax-demod! #:cache-root shared-read-syntax-cache-dir
                               #:force? #t))
  (check-equal? status 0 output)
  (check-true (file-exists? out-rktl)))

(test-case "read-syntax provider reads a tiny syntax object"
  (define linklet-datum
    (webify-read-syntax-linklet #:cache-root shared-read-syntax-cache-dir))
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

(module+ main
  (with-handlers ([exn:fail:filesystem? void])
    (delete-directory/files shared-read-syntax-cache-dir))
  (void))
