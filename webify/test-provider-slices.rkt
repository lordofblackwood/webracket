#lang racket/base

(require racket/file
         racket/string
         rackunit
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  provider-slice-forms)
         "../pkgs/webracket-lib/compiler/webify/provider-slices.rkt"
         "test-module-support.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary source program for provider-slice smokes.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; run-temp-webracket : string? (listof string?) -> (values exact-integer? string?)
;;   Run a temporary source program through WebRacket.
(define (run-temp-webracket source args)
  (define source-dir (make-temporary-file "webracket-provider-slice-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-provider-slice-dest-~a" 'directory))
  (define source-path (build-path source-dir "provider-slice.rkt"))
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

;; run-temp-webracket/datum : any/c (listof string?) -> (values exact-integer? string?)
;;   Run a generated top-level datum through WebRacket.
(define (run-temp-webracket/datum source args)
  (define source-dir (make-temporary-file "webracket-provider-slice-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-provider-slice-dest-~a" 'directory))
  (define source-path (build-path source-dir "provider-slice.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-datum-program! source-path source)
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

(test-case "provider-slice report lists active and staged provider slices"
  (define report (string-join (provider-slice-report-lines) "\n"))
  (check-true (string-contains? report "io/format\tdefault: enabled") report)
  (check-true (string-contains? report "regexp\tdefault: enabled") report)
  (check-true (string-contains? report "whole staged regexp/ tree") report)
  (check-true (string-contains? report "expander/read\tdefault: disabled\tstatus: staged") report)
  (check-true (string-contains? report "io/print\tdefault: disabled\tstatus: staged") report)
  (check-true (string-contains? report "cell-only smokes pass") report))

(test-case "io/print provider slice composes private cells only"
  (define forms (provider-slice-forms 'io/print))
  (check-not-false
   (for/or ([form (in-list forms)])
     (and (pair? form)
          (eq? (car form) 'define)
          (eq? (cadr form) 'webify-io-print-export-cell$display))))
  (check-exn
   #rx"io/print public aliases are not ready"
   (lambda ()
     (provider-slice-forms 'io/print #:public-aliases? #t))))

(test-case "io/print provider slice private cells run through driver forms"
  (define provider-forms (provider-slice-forms 'io/print))
  (define-values (status output)
    (run-temp-webracket/datum
     `(begin
        ,@provider-forms
        (define provided-display
          (module-variable-ref webify-io-print-export-cell$display))
        (define provided-write
          (module-variable-ref webify-io-print-export-cell$write))
        (define provided-print
          (module-variable-ref webify-io-print-export-cell$print))
        (define provided-newline
          (module-variable-ref webify-io-print-export-cell$newline))
        (define out (open-output-string))
        (provided-display "hello" out)
        (provided-newline out)
        (provided-write '(1 2) out)
        (provided-newline out)
        (provided-print 'quoted out)
        (provided-newline out)
        (provided-print 'depth-one out 1)
        (provided-newline out)
        (provided-print '(a b) out)
        (provided-newline out)
        (provided-print '(a b) out 1)
        (provided-newline out)
        (print-as-expression #f)
        (provided-print 'plain out)
        (print-as-expression #t)
        (provided-newline out)
        (js-log (get-output-string out)))
     (list "-r" "--no-stdlib" "--no-io-format-provider")))
  (check-equal? status 0 output)
  (check-true
   (string-contains? output "hello\n(1 2)\n'quoted\ndepth-one\n'(a b)\n(a b)\nplain\n")
   output))

(test-case "provider cache flags expose verbose cache decisions"
  (define cache-dir (make-temporary-file "webracket-provider-cache-flag-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define-values (status output)
        (run-temp-webracket
         "(js-log (regexp-match? #rx\"a\" \"cat\"))\n"
         (list "-v" "-r" "--no-stdlib" "--no-io-format-provider"
               "--provider-cache-dir" (path->string cache-dir)
               "--clear-provider-cache"
               "--force-provider-cache-refresh")))
      (check-equal? status 0 output)
      (check-regexp-match #rx"provider-cache: cache directory:" output)
      (check-regexp-match #rx"provider-cache: regexp lowered forms miss" output)
      (check-regexp-match #rx"provider-cache: regexp demod miss" output)
      (check-regexp-match #rx"(?m:^true$)" output))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(test-case "provider-backed format helpers are visible with --stdlib"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(define out (open-output-string))\n"
      "(fprintf out \"io ~a ~s ~x ~o ~b ~c\" \"ok\" '(1 2) 255 8 5 #\\Z)\n"
      "(js-log (get-output-string out))\n"
      "(js-log (format \"fmt ~a ~v ~e~nnext\" 'ok \"vv\" '(err)))\n")
     (list "-r" "--stdlib")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^io ok \\(1 2\\) ff 10 101 Z$)" output)
  (check-true (string-contains? output "fmt ok \"vv\" (err)\nnext")
              output))

(test-case "io/format provider exposes private cells and public aliases"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(define provider-format\n"
      "  (module-variable-ref webify-io-format-export-cell$format))\n"
      "(js-log (provider-format \"provider ~x ~o ~b ~c\" 255 8 5 #\\Z))\n"
      "(js-log (format \"public ~x\" 255))\n")
     (list "-r" "--stdlib")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^provider ff 10 101 Z$)" output)
  (check-regexp-match #rx"(?m:^public ff$)" output))

(test-case "format provider is visible with --no-stdlib"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(define out (open-output-string))\n"
      "(fprintf out \"no-stdlib ~x ~o ~b ~c\" 255 8 5 #\\Z)\n"
      "(js-log (get-output-string out))\n"
      "(js-log (format \"fmt ~a ~e\" 'ok '(err)))\n")
     (list "-r" "--no-stdlib")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^no-stdlib ff 10 101 Z$)" output)
  (check-regexp-match #rx"(?m:^fmt ok \\(err\\)$)" output))

(test-case "format provider routes ~v through the print handler"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(define out (open-output-string))\n"
      "(port-print-handler out (lambda (v o quote-depth) (write-string \"PRINTED\" o)))\n"
      "(fprintf out \"~a|~v\" \"x\" \"x\")\n"
      "(js-log (get-output-string out))\n")
     (list "-r" "--no-stdlib")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^x\\|PRINTED$)" output))

(test-case "format is absent when io/format provider is disabled"
  (define-values (status output)
    (run-temp-webracket
     "(js-log (format \"fmt ~a\" 'nope))\n"
     (list "-r" "--no-stdlib" "--no-io-format-provider")))
  (check-not-equal? status 0 output)
  (check-true
   (or (string-contains? output "format")
       (string-contains? output "unbound"))
   output))

(test-case "regexp provider is visible with --no-stdlib"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(js-log (regexp? (regexp \"a\")))\n"
      "(js-log (regexp-match? (regexp \"a+\") \"cat\"))\n"
      "(js-log (regexp-replace* (regexp \"a\") \"banana\" \"o\"))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider")))
  (check-equal? status 0 output)
  (check-equal? (regexp-match* #rx"(?m:^true$)" output) '("true" "true"))
  (check-regexp-match #rx"(?m:^bonono$)" output))

(test-case "regexp provider covers literals, captures, positions, bytes, and pregexp"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(js-log (regexp-match? #rx\"a+\" \"cat\"))\n"
      "(js-log (regexp-match? #px\"(a|b)+\" \"zzabba\"))\n"
      "(js-log (regexp-match? #rx\"^a\" \"ba\"))\n"
      "(js-log (regexp-match? #rx\"^a\" \"ab\"))\n"
      "(js-log (regexp-match? #rx#\"a\" #\"cat\"))\n"
      "(js-log (regexp-match #rx\"(a)\" \"cat\"))\n"
      "(js-log (regexp-match-positions #rx\"a\" \"cat\"))\n"
      "(js-log (regexp-replace #rx\"a\" \"cat\" \"o\"))\n"
      "(js-log (regexp-replace* #rx\"a\" \"banana\" \"o\"))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider")))
  (check-equal? status 0 output)
  (check-equal? (regexp-match* #rx"(?m:^(true|false)$)" output)
                '("true" "true" "false" "true" "true"))
  (check-regexp-match #rx"cdr: \\{ tag: 'pair', car: 'a'" output)
  (check-regexp-match #rx"car: \\{ tag: 'pair', car: 1, cdr: 2 \\}" output)
  (check-regexp-match #rx"(?m:^cot$)" output)
  (check-regexp-match #rx"(?m:^bonono$)" output))

(test-case "format public alias depends on io/format provider"
  (define-values (status output)
    (run-temp-webracket
     "(js-log (format \"fmt ~a\" 'nope))\n"
     (list "-r" "--stdlib" "--no-io-format-provider")))
  (check-not-equal? status 0 output)
  (check-true
   (or (string-contains? output "format")
       (string-contains? output "unbound"))
   output))

(module+ main
  (void))
