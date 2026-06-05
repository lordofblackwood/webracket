#lang racket/base

(require racket/file
         racket/match
         racket/path
         rackunit
         "test-module-support.rkt")

;; This is an integration-style suite: each case invokes the WebRacket compiler
;; on a small module graph so require/provide handling is tested end-to-end.

;; run-webracket/base : (listof string?) path? -> values
;;   Run webracket with this checkout's package collection visible.
(define (run-webracket/base args cwd)
  (parameterize ([current-environment-variables
                  (environment-variables-copy
                   (current-environment-variables))])
    (environment-variables-set!
     (current-environment-variables)
     #"PLTCOLLECTS"
     (string->bytes/utf-8 (webracket-collection-env-value)))
    (run-webracket args
                   cwd
                   #:timeout-seconds 120
                   #:memory-mb 1024)))

;; write-module! : path-string? string? -> void?
;;   Write a module source file for a temporary require-form test.
(define (write-module! path content)
  (call-with-output-file path
    (lambda (out)
      (display content out))
    #:exists 'truncate/replace))

;; run-module-case : string? (listof (list/c string? string?)) -> string?
;;   Compile and run a temporary #lang webracket/base module graph.
(define (run-module-case name files)
  (define source-dir (make-temporary-file (format "webracket-module-require-~a-src-~~a" name) 'directory))
  (define dest-dir   (make-temporary-file (format "webracket-module-require-~a-dest-~~a" name) 'directory))
  (dynamic-wind
    void
    (lambda ()
      (for ([file (in-list files)])
        (match-define (list relative content) file)
        (define path (build-path source-dir relative))
        (make-directory* (or (path-only path) source-dir))
        (write-module! path content))
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string (build-path source-dir "main.rkt")))
         source-dir))
      (values status output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; check-module-case : string? (listof (list/c string? string?)) regexp? -> void?
;;   Compile and run a module graph, expecting successful output.
(define (check-module-case name files expected)
  (define-values (status output) (run-module-case name files))
  (check-equal? status 0 output)
  (check-regexp-match expected output))

;; check-module-case-fails : string? (listof (list/c string? string?)) regexp? -> void?
;;   Compile a module graph, expecting a require/provide failure.
(define (check-module-case-fails name files expected)
  (define-values (status output) (run-module-case name files))
  (check-not-equal? status 0 output)
  (check-regexp-match expected output))

(define provider-source
  (string-append
   "#lang webracket/base\n"
   "(provide add2 sub2 hidden)\n"
   "(define (add2 x) (+ x 2))\n"
   "(define (sub2 x) (- x 2))\n"
   "(define hidden 999)\n"))

(test-case "plain local require"
  (check-module-case
   "plain"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "only-in local require"
  (check-module-case
   "only-in"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (only-in \"lib.rkt\" add2))\n(js-log (add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "only-in local require with rename"
  (check-module-case
   "only-in-rename"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (only-in \"lib.rkt\" [add2 plus2]))\n(js-log (plus2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "rename-in local require"
  (check-module-case
   "rename-in"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (rename-in \"lib.rkt\" [add2 plus2]))\n(js-log (plus2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "prefix-in local require"
  (check-module-case
   "prefix-in"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (prefix-in lib: \"lib.rkt\"))\n(js-log (lib:add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "nested prefix-in and only-in local require"
  (check-module-case
   "nested-prefix-only"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (prefix-in lib: (only-in \"lib.rkt\" add2)))\n(js-log (lib:add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "except-in local require keeps unexcluded names"
  (check-module-case
   "except-in-keeps"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (except-in \"lib.rkt\" hidden))\n(js-log (+ (add2 20) (sub2 22)))\n"))
   #rx"(?m:^42$)"))

(test-case "except-in local require hides excluded names or is rejected"
  (check-module-case-fails
   "except-in"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (except-in \"lib.rkt\" add2))\n(js-log (add2 40))\n"))
   #rx"(unsupported #lang webracket/base local require spec|unbound identifier|add2)"))

(test-case "combine-in local require"
  (check-module-case
   "combine-in"
   `(("lib.rkt" ,provider-source)
     ("main.rkt" "#lang webracket/base\n(require (combine-in (only-in \"lib.rkt\" add2) (rename-in \"lib.rkt\" [sub2 minus2])))\n(js-log (+ (add2 20) (minus2 22)))\n"))
   #rx"(?m:^42$)"))

(test-case "custom require transformer over local require"
  (check-module-case
   "custom-require-transformer"
   `(("lib.rkt" ,provider-source)
     ("main.rkt"
      ,(string-append
        "#lang webracket/base\n"
        "(require racket/require-syntax\n"
        "         (for-syntax racket/base racket/require-syntax))\n"
        "(define-require-syntax (just-add2 stx)\n"
        "  (syntax-local-require-introduce #'(only-in \"lib.rkt\" add2)))\n"
        "(require (just-add2))\n"
        "(js-log (add2 40))\n")))
   #rx"(?m:^42$)"))

(test-case "provider rename-out with plain local require"
  (check-module-case
   "provider-rename-out"
   `(("lib.rkt" "#lang webracket/base\n(provide (rename-out [add2 plus2]))\n(define (add2 x) (+ x 2))\n")
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (plus2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "provider except-out with plain local require"
  (check-module-case
   "provider-except-out"
   `(("lib.rkt" "#lang webracket/base\n(provide (except-out (all-defined-out) hidden))\n(define (add2 x) (+ x 2))\n(define hidden 999)\n")
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "provider prefix-out with plain local require"
  (check-module-case
   "provider-prefix-out"
   `(("lib.rkt" "#lang webracket/base\n(provide (prefix-out exported: (all-defined-out)))\n(define (add2 x) (+ x 2))\n")
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (exported:add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "provider combine-out with plain local require"
  (check-module-case
   "provider-combine-out"
   `(("lib.rkt" "#lang webracket/base\n(provide (combine-out add2 sub2))\n(define (add2 x) (+ x 2))\n(define (sub2 x) (- x 2))\n")
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (+ (add2 20) (sub2 22)))\n"))
   #rx"(?m:^42$)"))

(test-case "provider struct-out with plain local require"
  (check-module-case
   "provider-struct-out"
   `(("lib.rkt" "#lang webracket/base\n(provide (struct-out pt))\n(struct pt (x y) #:transparent)\n")
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(define p (pt 20 22))\n(js-log (+ (pt-x p) (pt-y p)))\n"))
   #rx"(?m:^42$)"))

(test-case "custom provide transformer with plain local require"
  (check-module-case
   "custom-provide-transformer"
   `(("lib.rkt"
      ,(string-append
        "#lang webracket/base\n"
        "(require racket/provide-syntax\n"
        "         (for-syntax racket/base racket/provide-syntax))\n"
        "(define-provide-syntax (export-add2 stx)\n"
        "  (syntax-local-provide-introduce #'(rename-out [add2 plus2])))\n"
        "(provide (export-add2))\n"
        "(define (add2 x) (+ x 2))\n"))
     ("main.rkt" "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (plus2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "provider all-defined-out with prefix-in"
  (check-module-case
   "provider-all-defined-prefix"
   `(("lib.rkt" "#lang webracket/base\n(provide (all-defined-out))\n(define (add2 x) (+ x 2))\n")
     ("main.rkt" "#lang webracket/base\n(require (prefix-in lib: \"lib.rkt\"))\n(js-log (lib:add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "one-hop all-from-out re-export"
  (check-module-case
   "all-from-out"
   `(("a.rkt" "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n")
     ("b.rkt" "#lang webracket/base\n(require \"a.rkt\")\n(provide (all-from-out \"a.rkt\"))\n")
     ("main.rkt" "#lang webracket/base\n(require \"b.rkt\")\n(js-log (add2 40))\n"))
   #rx"(?m:^42$)"))

(test-case "external only-in require"
  (check-module-case
   "external-only-in"
   `(("main.rkt" "#lang webracket/base\n(require (only-in racket/list first))\n(js-log (first '(42 99)))\n"))
   #rx"(?m:^42$)"))

(test-case "external prefix-in require"
  (check-module-case
   "external-prefix-in"
   `(("main.rkt" "#lang webracket/base\n(require (prefix-in lst: racket/list))\n(js-log (lst:first '(42 99)))\n"))
   #rx"(?m:^42$)"))
