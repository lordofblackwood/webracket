#lang racket/base

(require racket/file
         racket/path
         racket/string
         rackunit
         "../webify/test-module-support.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary WebRacket source program for a compile/run smoke.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

(test-case "unbound top-level runtime error does not emit compiler warning"
  (define source-dir (make-temporary-file "webracket-unbound-warning-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-unbound-warning-dest-~a" 'directory))
  (define source-path (build-path source-dir "unbound-warning.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-program! source-path "(missing-top-level)\n")
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir))
      (check-not-equal? status 0 output)
      (check-false (string-contains? output "WARNING")
                   "unbound runtime failures should not include compiler debug warnings")
      (check-true (or (string-contains? output "missing-top-level")
                      (string-contains? output "Uncaught WebAssembly exception"))
                  output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(module+ main
  (void))
