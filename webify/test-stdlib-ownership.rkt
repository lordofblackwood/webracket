#lang racket/base

(require racket/file
         racket/string
         rackunit
         "test-module-support.rkt"
         "../stdlib/module-exports.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary source program for stdlib bridge smokes.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; run-temp-webracket : string? (listof string?) -> (values exact-integer? string?)
;;   Run a temporary source program through WebRacket.
(define (run-temp-webracket source args)
  (define source-dir (make-temporary-file "webracket-stdlib-ownership-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-stdlib-ownership-dest-~a" 'directory))
  (define source-path (build-path source-dir "stdlib-ownership.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-program! source-path source)
      (run-webracket (append args
                             (list "--dest" (path->string dest-dir)
                                   (path->string source-path)))
                     source-dir
                     #:timeout-seconds 120
                     #:memory-mb 1024))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "exception ownership lists classify temporary primitive helpers"
  (for ([sym (in-list '(format
                        fprintf
                        raise-argument-error
                        raise-arguments-error
                        read
                        read-syntax))])
    (check-not-false (memq sym stdlib-primitive-owned-export-symbols)
                     (format "~a should be temporary primitive-owned" sym)))
  (for ([sym (in-list '(error
                        primitive-realm
                        error-message->adjusted-string
                        error-value->string
                        raise-argument-error*
                        raise-arguments-error*
                        raise-range-error
                        raise-range-error*
                        raise-result-error))])
    (check-false (memq sym stdlib-primitive-owned-export-symbols)
                 (format "~a should be stdlib-owned" sym))))

(test-case "stdlib-owned exception helpers are visible through --stdlib bridge"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(js-log (error-message->adjusted-string \"add1\" 'realm \"problem\" 'other))\n"
      "(js-log (symbol? primitive-realm))\n"
      "(with-handlers ([exn:fail? (lambda (e) (js-log \"caught\"))])\n"
      "  (raise-argument-error* 'map 'racket/primitive \"list?\" 0 42))\n")
     (list "-r" "--stdlib")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^add1: problem$)" output)
  (check-regexp-match #rx"(?m:^true$)" output)
  (check-regexp-match #rx"(?m:^caught$)" output))

(test-case "stdlib-owned exception helpers are absent with --no-stdlib"
  (define-values (status output)
    (run-temp-webracket
     "(js-log error-message->adjusted-string)\n"
     (list "-r" "--no-stdlib")))
  (check-not-equal? status 0 output)
  (check-true
   (or (string-contains? output "error-message->adjusted-string")
       (string-contains? output "unbound"))
   output))

(module+ main
  (void))
