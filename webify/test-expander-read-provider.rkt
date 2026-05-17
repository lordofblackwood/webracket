#lang racket/base

(require racket/file
         racket/string
         rackunit
         "read-provider.rkt"
         "test-module-support.rkt")

(define shared-expander-read-cache-dir
  (make-temporary-file "webracket-expander-read-shared-cache-~a" 'directory))

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

;; run-temp-webracket/shared-provider-cache : string? (listof string?)
;;                                       -> (values exact-integer? string?)
;;   Isolate expander/read tests from the default cache while sharing one warm
;;   cache inside this test file.
(define (run-temp-webracket/shared-provider-cache source args)
  (run-temp-webracket
   source
   (append args
           (list "--provider-cache-dir"
                 (path->string shared-expander-read-cache-dir)))))

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
    (run-temp-webracket/shared-provider-cache
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
    (run-temp-webracket/shared-provider-cache
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
    (run-temp-webracket/shared-provider-cache
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

(test-case "expander/read provider handles regexp, hash, locations, and dot policy"
  (define-values (status output)
    (run-temp-webracket/shared-provider-cache
     (string-append
      "(define rx (read (open-input-string \"#rx\\\"a+\\\"\")))\n"
      "(define px (read (open-input-string \"#px\\\"(a|b)+\\\"\")))\n"
      "(define h (read (open-input-string \"#hash((a . 41))\")))\n"
      "(define in (open-input-string \"abc\\n42\" 'loc-smoke))\n"
      "(port-count-lines! in)\n"
      "(read in)\n"
      "(let-values ([(line col pos) (port-next-location in)])\n"
      "  (js-log (regexp-match? rx \"cat\"))\n"
      "  (js-log (regexp-match? px \"zzabba\"))\n"
      "  (js-log (hash-ref h 'a))\n"
      "  (js-log line)\n"
      "  (js-log col)\n"
      "  (js-log pos))\n"
      "(define old-dot (read-accept-dot))\n"
      "(read-accept-dot #t)\n"
      "(js-log (read-accept-dot))\n"
      "(read-accept-dot old-dot)\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider" "--expander-read-provider")))
  (check-equal? status 0 output)
  (check-equal? (regexp-match* #rx"(?m:^true$)" output)
                '("true" "true" "true"))
  (check-regexp-match #rx"(?m:^41$)" output)
  (check-regexp-match #rx"(?m:^1$)" output)
  (check-regexp-match #rx"(?m:^3$)" output)
  (check-regexp-match #rx"(?m:^4$)" output))

(test-case "private expander/read-syntax provider exposes Webify-owned aliases"
  (define-values (status output)
    (run-temp-webracket/shared-provider-cache
     (string-append
      "(define in (open-input-string \"(1 2) #(a b) \\\"λ\\\"\" 'syntax-src))\n"
      "(port-count-lines! in)\n"
      "(define s1 (webify-expander-read-syntax 'syntax-src in))\n"
      "(define s2 (webify-expander-read-syntax 'syntax-src in))\n"
      "(define s3 (webify-expander-read-syntax 'syntax-src in))\n"
      "(js-log (car (webify-expander-syntax->datum s1)))\n"
      "(js-log (vector-length (webify-expander-syntax->datum s2)))\n"
      "(js-log (webify-expander-syntax->datum s3))\n"
      "(js-log (eq? (webify-expander-syntax-source s1) 'syntax-src))\n"
      "(js-log (webify-expander-syntax-line s1))\n"
      "(js-log (webify-expander-syntax-column s1))\n"
      "(js-log (webify-expander-syntax-position s1))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider"
           "--expander-read-syntax-provider")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^1$)" output)
  (check-regexp-match #rx"(?m:^2$)" output)
  (check-regexp-match #rx"(?m:^λ$)" output)
  (check-regexp-match #rx"(?m:^true$)" output)
  (check-regexp-match #rx"(?m:^0$)" output))

(test-case "private expander/read-syntax provider rejects reader extensions deliberately"
  (define-values (status output)
    (run-temp-webracket/shared-provider-cache
     (string-append
      "(with-handlers ([exn:fail? (lambda (e) (js-log \"reader-extension-rejected\"))])\n"
      "  (webify-expander-read-syntax 'src\n"
      "                               (open-input-string \"#reader racket/base 42\" 'src))\n"
      "  (js-log \"unexpected-reader-extension-success\"))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider"
           "--expander-read-syntax-provider")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"reader-extension-rejected" output)
  (check-false (regexp-match? #rx"unexpected-reader-extension-success" output)))

(test-case "private expander/read-syntax provider rejects compiled-code input deliberately"
  (define-values (status output)
    (run-temp-webracket/shared-provider-cache
     (string-append
      "(with-handlers ([exn:fail? (lambda (e) (js-log \"compiled-code-rejected\"))])\n"
      "  (webify-expander-read-syntax 'src\n"
      "                               (open-input-string \"#~\" 'src))\n"
      "  (js-log \"unexpected-compiled-code-success\"))\n")
     (list "-r" "--no-stdlib" "--no-io-format-provider"
           "--expander-read-syntax-provider")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"compiled-code-rejected" output)
  (check-false (regexp-match? #rx"unexpected-compiled-code-success" output)))

(module+ main
  (with-handlers ([exn:fail:filesystem? void])
    (delete-directory/files shared-expander-read-cache-dir))
  (void))
