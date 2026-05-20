#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         rackunit
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  regexp-provider-forms)
         "provider-slices.rkt"
         "regexp-provider.rkt")

(define-runtime-path webracket-rkt "../webracket.rkt")

(test-case "regexp provider slice is staged and enabled by default"
  (define slice (provider-slice-by-name 'regexp))
  (check-not-false slice)
  (check-true (provider-slice-default-enabled? slice))
  (check-equal? (provider-slice-status slice) 'active)
  (check-equal? (sort (provider-slice-exports slice) symbol<?)
                (sort webify-regexp-export-symbols symbol<?)))

(test-case "regexp ownership separates public provider names from literal helpers"
  (check-equal? (sort webify-regexp-provider-owned-symbols symbol<?)
                (sort webify-regexp-export-symbols symbol<?))
  (for ([sym (in-list webify-regexp-bootstrap-helper-symbols)])
    (check-false (memq sym webify-regexp-provider-owned-symbols)
                 (format "~a should remain a compiler literal helper" sym))))

(test-case "staged regexp source tree is copied under racket-src"
  (check-true (directory-exists? webify-regexp-source-root))
  (check-true (file-exists? webify-regexp-main-source))
  (check-true (file-exists? (build-path webify-regexp-source-root "../common/check.rkt")))
  (for ([relative (in-list '("main.zuo"
                             "parse/main.rkt"
                             "match/main.rkt"
                             "replace/main.rkt"
                             "analyze/validate.rkt"))])
    (check-true (file-exists? (build-path webify-regexp-source-root relative))
                relative)))

(test-case "regexp demod command uses staged source and cache paths"
  (define cache-root (build-path (find-system-path 'temp-dir)
                                 "webracket-regexp-provider-test-cache"))
  (define command (webify-regexp-demod-command cache-root))
  (define command-text (string-join command "\n"))
  (define-values (out-rktl dep-rktd bootstrap-cache)
    (webify-regexp-cache-paths cache-root))
  (check-not-false (member "-t" command))
  (check-not-false (member "--no-global" command))
  (check-true (string-contains? command-text (path->string webify-regexp-main-source)))
  (check-true (string-contains? command-text (path->string out-rktl)))
  (check-true (string-contains? command-text (path->string dep-rktd)))
  (check-true (string-contains? command-text (path->string bootstrap-cache))))

(test-case "regexp demod cache invalidates when the source fingerprint changes"
  (define cache-root (make-temporary-file "webracket-regexp-cache-test-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define-values (status-1 output-1 out-rktl-1)
        (webify-regexp-demod! #:cache-root cache-root #:force? #t))
      (check-equal? status-1 0 output-1)
      (check-true (file-exists? out-rktl-1))
      (define-values (status-2 output-2 out-rktl-2)
        (webify-regexp-demod! #:cache-root cache-root))
      (check-equal? status-2 0 output-2)
      (check-equal? out-rktl-2 out-rktl-1)
      (check-regexp-match #rx"using cached regexp demod linklet" output-2)
      (define fingerprint-path (path-add-extension out-rktl-1 #".fingerprint.rktd"))
      (call-with-output-file fingerprint-path
        (lambda (out) (write '(stale) out) (newline out))
        #:exists 'truncate/replace)
      (define-values (status-3 output-3 out-rktl-3)
        (webify-regexp-demod! #:cache-root cache-root))
      (check-equal? status-3 0 output-3)
      (check-equal? out-rktl-3 out-rktl-1)
      (check-false (regexp-match? #rx"using cached regexp demod linklet" output-3)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-root)))))

(test-case "lowered regexp provider forms are cached with the source fingerprint"
  (define cache-path (webify-regexp-lowered-provider-cache-path #t))
  (with-handlers ([exn:fail:filesystem? void])
    (delete-file cache-path))
  (define forms-1 (regexp-provider-forms #:public-aliases? #t))
  (check-true (file-exists? cache-path))
  (define forms-2 (regexp-provider-forms #:public-aliases? #t))
  (check-equal? (length forms-2) (length forms-1))
  (check-true (positive? (length forms-2))))

(test-case "regexp direct call compiles with no stdlib and no io/format provider"
  (define tmp-dir (make-temporary-file "webracket-regexp-no-stdlib-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define source-path (build-path tmp-dir "regexp-no-stdlib.rkt"))
      (define wat-path (build-path tmp-dir "regexp-no-stdlib.wat"))
      (define wasm-path (build-path tmp-dir "regexp-no-stdlib.wasm"))
      (define host-path (build-path tmp-dir "regexp-no-stdlib.js"))
      (call-with-output-file source-path
        (lambda (out)
          (displayln "(regexp-match? (regexp \"a+\") \"cat\")" out)
          (displayln "(regexp-match? (pregexp \"(a|b)+\") \"zzabba\")" out)
          (displayln "(regexp-match? (byte-regexp #\"a+\") #\"cat\")" out)
          (displayln "(regexp-match? (byte-pregexp #\"(a|b)+\") #\"zzabba\")" out))
        #:exists 'truncate)
      (define status
        (system*/exit-code
         (find-system-path 'exec-file)
         "-y"
         (path->string webracket-rkt)
         "--no-stdlib"
         "--no-io-format-provider"
         "--wat-file" (path->string wat-path)
         "--wasm-file" (path->string wasm-path)
         "--host-file" (path->string host-path)
         (path->string source-path)))
      (check-equal? status 0)
      (check-true (file-exists? wat-path))
      (check-true (file-exists? wasm-path)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files tmp-dir)))))

(module+ main
  (void))
