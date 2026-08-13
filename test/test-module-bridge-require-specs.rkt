#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/string
         "../pkgs/webracket-lib/compiler/driver.rkt")

;; fresh-temp-directory : string? -> path?
;;   Create a temporary directory under /tmp for generated module sources.
(define (fresh-temp-directory name)
  (define path
    (build-path "/tmp"
                (format "~a-~a-~a"
                        name
                        (current-process-milliseconds)
                        (random 1000000))))
  (make-directory* path)
  path)

;; write-file! : path? string? -> void?
;;   Write one temporary source file.
(define (write-file! path content)
  (make-directory* (or (path-only path) (current-directory)))
  (call-with-output-file path
    (lambda (out)
      (display content out))
    #:exists 'truncate/replace))

;; missing-required-paths : (listof path?) (listof path?) -> (listof path?)
;;   Return expected paths that were not discovered by the local require scanner.
(define (missing-required-paths expected actual)
  (define actual* (map simplify-path actual))
  (filter-not (lambda (path)
                (member (simplify-path path) actual*))
              expected))

;; sorted-paths : (listof path?) -> (listof path?)
;;   Sort paths by their printable form for stable comparisons.
(define (sorted-paths paths)
  (sort (map simplify-path paths) string<? #:key path->string))

;; provider-symbols-for-path : path? path? -> (listof symbol?)
;;   Return the provider symbols that diagnostics may use for a local source path.
(define (provider-symbols-for-path source-dir path)
  (define relative
    (path->string (find-relative-path source-dir path)))
  (define without-extension
    (if (string-suffix? relative ".rkt")
        (substring relative 0 (- (string-length relative) 4))
        relative))
  (remove-duplicates
   (list (string->symbol without-extension)
         (string->symbol relative))
   eq?))

;; assert-local-require-spec-paths : symbol? any/c path? (listof path?) -> void?
;;   Check the cheap source-level local require-spec scanner.
(define (assert-local-require-spec-paths label spec source-dir expected-paths)
  (define actual-paths
    (local-require-spec-paths spec source-dir))
  (unless (equal? (sorted-paths actual-paths)
                  (sorted-paths expected-paths))
    (raise-arguments-error label
                           "local require scanner returned unexpected paths"
                           "spec" spec
                           "expected paths" expected-paths
                           "actual paths" actual-paths))
  (printf "scanner-ok ~a\n" label)
  (flush-output))

;; assert-require-spec-case : symbol? path-string? path? (listof path?) -> void?
;;   Build the local module graph and check that local providers do not leak as externals.
(define (assert-require-spec-case label source-path source-dir expected-paths)
  (printf "case-start ~a\n" label)
  (flush-output)
  (define-values (root reports local-source-paths)
    (webracket/base-file->local-module-reports source-path))
  (define missing
    (missing-required-paths expected-paths local-source-paths))
  (unless (null? missing)
    (raise-arguments-error label
                           "local require scanner missed expected source paths"
                           "missing paths" missing
                           "local source paths" local-source-paths))
  (define external (webracket/base-external-provider-names reports))
  (define forbidden-providers
    (append* (map (lambda (path)
                    (provider-symbols-for-path source-dir path))
                  expected-paths)))
  (define leaked
    (filter (lambda (name) (member name external)) forbidden-providers))
  (unless (null? leaked)
    (raise-arguments-error label
                           "local module escaped into external providers"
                           "leaked providers" leaked
                           "external providers" external))
  (void
   (webracket/base-reports->module-graph
    root
    reports
    #:local-source-paths local-source-paths))
  (printf "case-ok ~a\n" label)
  (flush-output))

;; run-require-spec-smoke : -> void?
;;   Cover common phase-0 require-spec wrappers over local modules.
(define (run-require-spec-smoke)
  (define base (fresh-temp-directory "webracket-module-bridge-require-specs"))
  (define src-dir (build-path base "src"))
  (define sub-dir (build-path src-dir "sub"))
  (define cache-dir (build-path base "provider-cache"))
  (define only-path (build-path src-dir "only-provider.rkt"))
  (define except-path (build-path src-dir "except-provider.rkt"))
  (define rename-left-path (build-path src-dir "rename-left.rkt"))
  (define rename-right-path (build-path src-dir "rename-right.rkt"))
  (define combine-left-path (build-path src-dir "combine-left.rkt"))
  (define combine-right-path (build-path src-dir "combine-right.rkt"))
  (define nested-path (build-path src-dir "nested-provider.rkt"))
  (define file-path (build-path src-dir "file-provider.rkt"))
  (define meta-path (build-path src-dir "meta-zero.rkt"))
  (define anchor-path (build-path sub-dir "anchor.rkt"))
  (define relative-path (build-path sub-dir "relative-provider.rkt"))
  (define (source name)
    (build-path src-dir name))
  (define (case-path name)
    (source (format "main-~a.rkt" name)))
  (define (write-main! name require-text body-text)
    (define path (case-path name))
    (write-file! path
                 (format "#lang webracket/base\n(require ~a)\n~a\n"
                         require-text
                         body-text))
    path)
  (dynamic-wind
    void
    (lambda ()
      (make-directory* sub-dir)
      (write-file! only-path
                   "#lang webracket/base\n(provide shared only-value)\n(define shared 11)\n(define only-value 12)\n")
      (write-file! except-path
                   "#lang webracket/base\n(provide shared visible hidden)\n(define shared 21)\n(define visible 22)\n(define hidden 23)\n")
      (write-file! rename-left-path
                   "#lang webracket/base\n(provide shared)\n(define shared 31)\n")
      (write-file! rename-right-path
                   "#lang webracket/base\n(provide shared)\n(define shared 32)\n")
      (write-file! combine-left-path
                   "#lang webracket/base\n(provide shared)\n(define shared 41)\n")
      (write-file! combine-right-path
                   "#lang webracket/base\n(provide shared)\n(define shared 42)\n")
      (write-file! nested-path
                   "#lang webracket/base\n(provide shared)\n(define shared 51)\n")
      (write-file! file-path
                   "#lang webracket/base\n(provide file-shared file-extra)\n(define file-shared 31)\n(define file-extra 32)\n")
      (write-file! meta-path
                   "#lang webracket/base\n(provide meta-value)\n(define meta-value 41)\n")
      (write-file! anchor-path
                   "#lang webracket/base\n(provide anchor-value)\n(define anchor-value 51)\n")
      (write-file! relative-path
                   "#lang webracket/base\n(provide relative-value shared)\n(define relative-value 61)\n(define shared 62)\n")
      (parameterize ([current-provider-cache-dir cache-dir]
                     [current-provider-cache-force? #f]
                     [current-provider-cache-verbose? #f])
        (assert-local-require-spec-paths
         'only-in
         '(only-in "only-provider.rkt" only-value [shared only-shared])
         src-dir
         (list only-path))
        (assert-local-require-spec-paths
         'except-in
         '(except-in "except-provider.rkt" hidden)
         src-dir
         (list except-path))
        (assert-local-require-spec-paths
         'rename-in
         '(rename-in "rename-left.rkt" [shared left-shared])
         src-dir
         (list rename-left-path))
        (assert-local-require-spec-paths
         'combine-in
         '(combine-in
           (only-in "combine-left.rkt" [shared left-shared])
           (only-in "combine-right.rkt" [shared right-shared]))
         src-dir
         (list combine-left-path combine-right-path))
        (assert-local-require-spec-paths
         'nested-prefix-only-in
         '(prefix-in nested: (only-in "nested-provider.rkt" [shared value]))
         src-dir
         (list nested-path))
        (assert-local-require-spec-paths
         'only-in-file-module-path
         '(only-in (file "file-provider.rkt") file-shared)
         src-dir
         (list file-path))
        (assert-local-require-spec-paths
         'relative-in
         '(relative-in "sub/anchor.rkt" "relative-provider.rkt")
         src-dir
         (list relative-path))
        (assert-local-require-spec-paths
         'relative-in-file-base
         '(relative-in (file "sub/anchor.rkt") "relative-provider.rkt")
         src-dir
         (list relative-path))
        (assert-local-require-spec-paths
         'for-meta-zero
         '(for-meta 0 "meta-zero.rkt")
         src-dir
         (list meta-path))
        (assert-local-require-spec-paths
         'only-meta-in-zero
         '(only-meta-in 0 "meta-zero.rkt")
         src-dir
         (list meta-path))
        (define aggregate-path
          (write-main! "aggregate"
                       "(only-in \"only-provider.rkt\" only-value [shared only-shared])\n         (except-in \"except-provider.rkt\" hidden shared)\n         (rename-in \"rename-left.rkt\" [shared rename-left-shared])\n         (rename-in \"rename-right.rkt\" [shared rename-right-shared])\n         (combine-in\n          (only-in \"combine-left.rkt\" [shared combine-left-shared])\n          (only-in \"combine-right.rkt\" [shared combine-right-shared]))\n         (prefix-in nested: (only-in \"nested-provider.rkt\" [shared value]))\n         (only-in (file \"file-provider.rkt\") file-shared)\n         (relative-in \"sub/anchor.rkt\"\n                      (only-in \"relative-provider.rkt\"\n                               relative-value\n                               [shared relative-shared]))\n         (for-meta 0 \"meta-zero.rkt\")\n         (only-meta-in 0 \"meta-zero.rkt\")"
                       "(+ only-value only-shared visible rename-left-shared rename-right-shared combine-left-shared combine-right-shared nested:value file-shared relative-value relative-shared meta-value)"))
        (assert-require-spec-case
         'aggregate-require-spec-bridge
         aggregate-path
         src-dir
         (list only-path
               except-path
               rename-left-path
               rename-right-path
               combine-left-path
               combine-right-path
               nested-path
               file-path
               relative-path
               meta-path))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (run-require-spec-smoke))
