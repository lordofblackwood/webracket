#lang racket/base

(require racket/file
         racket/string
         rackunit
         "test-module-support.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary WebRacket source file.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; run-io-substrate-program : string? -> (values exact-integer? string?)
;;   Run a no-stdlib program that uses only primitive port substrate.
(define (run-io-substrate-program source)
  (define source-dir (make-temporary-file "webracket-io-format-substrate-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-io-format-substrate-dest-~a" 'directory))
  (define source-path (build-path source-dir "io-format-substrate.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-program! source-path source)
      (run-webracket (list "--no-stdlib"
                           "-r"
                           "--dest" (path->string dest-dir)
                           (path->string source-path))
                     source-dir
                     #:timeout-seconds 120
                     #:memory-mb 1024))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "no-stdlib output string ports support io/format substrate"
  (define-values (status output)
    (run-io-substrate-program
     (string-append
      "(define p (open-output-string))\n"
      "(js-log (output-port? p))\n"
      "(js-log (string-port? p))\n"
      "(js-log (write-string \"héllo\" p 1 4))\n"
      "(js-log (get-output-string p))\n"
      "(define saved-output (current-output-port))\n"
      "(define captured-output (open-output-string))\n"
      "(current-output-port captured-output)\n"
      "(write-string \"default-out\")\n"
      "(current-output-port saved-output)\n"
      "(js-log (get-output-string captured-output))\n"
      "(define saved-error (current-error-port))\n"
      "(define captured-error (open-output-string))\n"
      "(current-error-port captured-error)\n"
      "(write-string \"default-err\" (current-error-port))\n"
      "(current-error-port saved-error)\n"
      "(js-log (get-output-string captured-error))\n")))
  (check-equal? status 0 output)
  (for ([expected (in-list '("true"
                             "true"
                             "3"
                             "éll"
                             "default-out"
                             "default-err"))])
    (check-true (string-contains? output expected)
                (format "missing ~s in output: ~a" expected output))))

(module+ main
  (void))
