#lang racket/base

(require racket/file
         racket/path
         rackunit
         "test-module-support.rkt")

;; call-with-goal1-program : (listof (cons/c path-string? string?)) path-string? (path? -> any/c) -> any/c
;;   Materialize a small multi-file Goal 1 program and run body on its main file.
(define (call-with-goal1-program files main-file body)
  (define source-dir (make-temporary-file "webracket-goal1-program-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-goal1-program-dest-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (for ([entry (in-list files)])
        (define path (build-path source-dir (car entry)))
        (make-directory* (or (path-only path) source-dir))
        (call-with-output-file path
          (lambda (out) (display (cdr entry) out))
          #:exists 'truncate/replace))
      (body (build-path source-dir main-file) dest-dir source-dir))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; run-goal1-program : (listof (cons/c path-string? string?)) path-string? regexp? -> void?
;;   Compile and run one module-language program with bounded resources.
(define (run-goal1-program files main-file expected
                           #:bridge? [bridge? #f]
                           #:io-format? [io-format? #f])
  (call-with-goal1-program
   files
   main-file
   (lambda (main-path dest-dir source-dir)
     (parameterize ([current-environment-variables
                     (environment-variables-copy
                      (current-environment-variables))])
       (environment-variables-set!
        (current-environment-variables)
        #"PLTCOLLECTS"
        (string->bytes/utf-8 (webracket-collection-env-value)))
       (define-values (status output)
         (run-webracket
          (append
           (list "-r" "--no-stdlib")
           (if io-format? '() '("--no-io-format-provider"))
           (if bridge? '("--webracket-module-bridge") '())
           (list "--dest" (path->string dest-dir)
                 (path->string main-path)))
          source-dir
          #:timeout-seconds 120
          #:memory-mb 1024))
       (check-equal? status 0 output)
       (check-regexp-match expected output)))))

(test-case "Goal 1 base program handles shared local dependencies and re-export"
  (run-goal1-program
   `(("core.rkt" . ,(string-append
                     "#lang webracket/base\n"
                     "(provide base add2)\n"
                     "(define base 20)\n"
                     "(define (add2 x) (+ x 2))\n"))
     ("a.rkt" . ,(string-append
                  "#lang webracket/base\n"
                  "(require \"core.rkt\")\n"
                  "(provide a-val)\n"
                  "(define a-val (add2 base))\n"))
     ("b.rkt" . ,(string-append
                  "#lang webracket/base\n"
                  "(require (rename-in \"core.rkt\" [base b-base]))\n"
                  "(provide b-val)\n"
                  "(define b-val b-base)\n"))
     ("exports.rkt" . ,(string-append
                        "#lang webracket/base\n"
                        "(require \"a.rkt\" \"b.rkt\")\n"
                        "(provide a-val b-val)\n"))
     ("main.rkt" . ,(string-append
                     "#lang webracket/base\n"
                     "(require \"exports.rkt\")\n"
                     "(js-log (+ a-val b-val))\n")))
   "main.rkt"
   #rx"(?m:^42$)"))

(test-case "Goal 1 full program combines staged data providers"
  (run-goal1-program
   `(("main.rkt" . ,(string-append
                     "#lang webracket/full\n"
                     "(define h (hash 'a 10 'b 20))\n"
                     "(define xs (for/list ([x (in-list '(1 2 3))]) (+ x 1)))\n"
                     "(define v '#(a b c))\n"
                     "(define total (+ (hash-ref h 'a)\n"
                     "                 (hash-ref h 'b)\n"
                     "                 (length xs)\n"
                     "                 (vector-length v)\n"
                     "                 (string-length \"web\")\n"
                     "                 3))\n"
                     "(js-log total)\n")))
   "main.rkt"
   #rx"(?m:^42$)"))

(test-case "Goal 1 module program infers JS math FFI bundle"
  (run-goal1-program
   `(("main.rkt" . ,(string-append
                     "#lang webracket/base\n"
                     "(require js/math)\n"
                     "(js-log (math-sqrt 9.0))\n")))
   "main.rkt"
   #rx"(?m:^3$)"
   #:bridge? #t))

(test-case "Goal 1 full program uses format when io-format provider is enabled"
  (run-goal1-program
   `(("main.rkt" . ,(string-append
                     "#lang webracket/full\n"
                     "(js-log (format \"fmt ~a\" 'web))\n")))
   "main.rkt"
   #rx"(?m:^fmt web$)"
   #:io-format? #t))

(test-case "Goal 1 full program routes compose through staged function provider"
  (run-goal1-program
   `(("main.rkt" . ,(string-append
                     "#lang webracket/full\n"
                     "(define f (compose add1 add1))\n"
                     "(js-log (f 40))\n")))
   "main.rkt"
   #rx"(?m:^42$)"))

(module+ main
  (void))
