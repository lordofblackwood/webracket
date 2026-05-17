#lang racket/base

(require racket/file
         racket/string
         rackunit
         "read-provider.rkt"
         "test-module-support.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary source program for expander/read provider smokes.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; run-temp-webracket : string? (listof string?) -> (values exact-integer? string?)
;;   Run a temporary source program through WebRacket.
(define (run-temp-webracket source args)
  (define source-dir (make-temporary-file "webracket-expander-read-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-expander-read-dest-~a" 'directory))
  (define source-path (build-path source-dir "expander-read.rkt"))
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

;; run-temp-webracket/fresh-provider-cache : string? (listof string?)
;;                                      -> (values exact-integer? string?)
;;   Isolate expander/read tests from stale generated provider artifacts.
(define (run-temp-webracket/fresh-provider-cache source args)
  (define cache-dir (make-temporary-file "webracket-expander-read-cache-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (run-temp-webracket
       source
       (append args
               (list "--provider-cache-dir" (path->string cache-dir)
                     "--clear-provider-cache"))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(test-case "expander/read lowered cache fingerprints include public alias policy"
  (define cache-dir (make-temporary-file "webracket-read-provider-cache-policy-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define source "(define in (open-input-string \"42\"))\n(js-log (read in))\n")
      (define-values (first-status first-output)
        (run-temp-webracket
         source
         (list "-v" "-r" "--no-stdlib" "--no-io-format-provider"
               "--expander-read-provider"
               "--provider-cache-dir" (path->string cache-dir)
               "--clear-provider-cache")))
      (check-equal? first-status 0 first-output)
      (check-regexp-match #rx"provider-cache: expander/read lowered forms miss"
                          first-output)
      (define cache-path (webify-read-lowered-provider-cache-path cache-dir))
      (check-true (file-exists? cache-path)
                  (path->string cache-path))
      (define cache-entry (call-with-input-file cache-path read))
      (check-match cache-entry (list _ _))
      (define fingerprint (car cache-entry))
      (check-not-false (member webify-read-public-alias-symbols fingerprint)
                       (format "fingerprint did not include alias policy: ~s"
                               fingerprint))
      (define-values (second-status second-output)
        (run-temp-webracket
         source
         (list "-v" "-r" "--no-stdlib" "--no-io-format-provider"
               "--expander-read-provider"
               "--provider-cache-dir" (path->string cache-dir))))
      (check-equal? second-status 0 second-output)
      (check-regexp-match #rx"provider-cache: expander/read lowered forms hit"
                          second-output))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(test-case "expander/read provider exposes Webify-owned reader aliases"
  (define-values (status output)
    (run-temp-webracket/fresh-provider-cache
     (string-append
      "(define in (open-input-string \"(1 2) 42\"))\n"
      "(js-log (webify-expander-read in))\n"
      "(js-log (webify-expander-read in))\n"
      "(js-log (eof-object? (webify-expander-read in)))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider" "--expander-read-provider")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"car: 1" output)
  (check-regexp-match #rx"(?m:^42$)" output)
  (check-regexp-match #rx"(?m:^true$)" output))

(test-case "expander/read provider handles string ports and datum classes"
  (define-values (status output)
    (run-temp-webracket/fresh-provider-cache
     (string-append
      "(define in (open-input-string \"#; ignored 'sym #(1 2 3) \\\"λ\\\"\" 'reader-smoke))\n"
      "(js-log (webify-expander-read in))\n"
      "(js-log (vector-length (webify-expander-read in)))\n"
      "(js-log (webify-expander-read in))\n"
      "(let-values ([(line col pos) (port-next-location in)])\n"
      "  (js-log line)\n"
      "  (js-log col)\n"
      "  (js-log pos))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider" "--expander-read-provider")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"car: Symbol\\(quote\\)" output)
  (check-regexp-match #rx"(?m:^3$)" output)
  (check-regexp-match #rx"(?m:^λ$)" output)
  (check-regexp-match #rx"(?m:^1$)" output))

(test-case "expander/read provider publishes public reader aliases"
  (define-values (status output)
    (run-temp-webracket/fresh-provider-cache
     (string-append
      "(define in (open-input-string \"42\"))\n"
      "(js-log (read in))\n"
      "(js-log (not (current-readtable)))\n"
      "(read-accept-reader #t)\n"
      "(js-log (read-accept-reader))\n"
      "(read-accept-reader #f)\n"
      "(js-log (read-accept-reader))\n"
      "(js-log (string->number \"42\"))\n"
      "(js-log (eq? (read-language (open-input-string \"42\")\n"
      "                         (lambda () 'no-lang))\n"
      "              'no-lang))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider" "--expander-read-provider")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^42$)" output)
  (check-equal? (regexp-match* #rx"(?m:^(true|false)$)" output)
                '("true" "true" "false" "true")))

(module+ main
  (void))
