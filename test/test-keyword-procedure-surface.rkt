#lang racket/base

(require racket/file
         racket/path
         rackunit
         "../webify/test-module-support.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary WebRacket source program for runtime smoke checks.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; check-webracket-output : string? regexp? -> void?
;;   Run a no-stdlib WebRacket program and match its observable output.
(define (check-webracket-output source expected-output)
  (define source-dir (make-temporary-file "webracket-keyword-proc-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-keyword-proc-dest-~a" 'directory))
  (define source-path (build-path source-dir "keyword-procedure-surface.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-program! source-path source)
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir))
      (check-equal? status 0 output)
      (check-regexp-match expected-output output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "struct proc-spec field makes instances callable"
  (check-webracket-output
   (string-append
    "(define-values (struct:p make-p p? p-ref p-set!)\n"
    "  (make-struct-type 'p #f 1 0 #f null #f 0 '(0)))\n"
    "(define p (make-p (lambda (x) (+ x 1))))\n"
    "(js-log (procedure? p))\n"
    "(js-log (p 41))\n")
   #rx"(?m:^true\n42\n#<void>$)"))

(test-case "struct proc-spec procedure makes instances callable"
  (check-webracket-output
   (string-append
    "(define-values (struct:p make-p p? p-ref p-set!)\n"
    "  (make-struct-type\n"
    "   'p #f 1 0 #f null #f\n"
    "   (lambda (self delta)\n"
    "     (+ (p-ref self 0) delta))))\n"
    "(define p (make-p 10))\n"
    "(js-log (procedure? p))\n"
    "(js-log (p 5))\n")
   #rx"(?m:^true\n15\n#<void>$)"))

(test-case "keyword-procedure-shaped subtype dispatches through child proc-spec field"
  (check-webracket-output
   (string-append
    "(define-values (struct:keyword-procedure make-kp kp? kp-ref kp-set!)\n"
    "  (make-struct-type 'keyword-procedure #f 4 0 #f null #f #f '(0 1 2 3)))\n"
    "(define-values (struct:optional-keyword-procedure make-okp okp? okp-ref okp-set!)\n"
    "  (make-struct-type 'procedure struct:keyword-procedure 1 0 #f null #f 0 '(0)))\n"
    "(define okp\n"
    "  (make-okp 'checker 'keyword-proc 'required 'allowed\n"
    "            (lambda (x) (+ x 1))))\n"
    "(js-log (procedure? okp))\n"
    "(js-log (okp 41))\n"
    "(js-log (okp? okp))\n"
    "(js-log (kp? okp))\n")
   #rx"(?m:^true\n42\ntrue\ntrue\n#<void>$)"))

(module+ main
  (void))
