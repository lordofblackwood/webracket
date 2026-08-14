#lang racket/base

(require rackunit
         racket/file
         racket/path
         "../pkgs/webracket-lib/compiler/driver.rkt")

;; fresh-temp-directory : string? -> path?
;;   Create a temporary directory under /tmp for generated source/cache files.
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

;; write-view! : path? string? exact-integer? -> void?
;;   Write the included source file and force a deterministic mtime change.
(define (write-view! view-path body mtime)
  (write-file! view-path
               (string-append "#lang racket/base\n"
                              body))
  (file-or-directory-modify-seconds view-path mtime))

;; run-provider-cache-include-invalidation-smoke : -> void?
;;   Assert provider stub caches notice changes to transitive textual includes.
(define (run-provider-cache-include-invalidation-smoke)
  (define base (fresh-temp-directory "webracket-provider-cache-include"))
  (define cache-dir (build-path base "provider-cache"))
  (define coll-dir (build-path base "include-cache-fixture"))
  (define main-path (build-path coll-dir "main.rkt"))
  (define view-path (build-path coll-dir "view.rkt"))
  (define provider-name 'include-cache-fixture)
  (define build-count 0)
  (define (make-exports exports)
    (lambda ()
      (set! build-count (add1 build-count))
      (provider-compile-stub-exports #t exports '())))
  (dynamic-wind
    void
    (lambda ()
      (write-file!
       main-path
       (string-append
        "#lang racket/base\n"
        "(require racket/include)\n"
        "(begin-for-syntax\n"
        "  (define (read-syntax/skip-first-line source-name in)\n"
        "    (read-line in)\n"
        "    (read-syntax source-name in)))\n"
        "(include/reader \"view.rkt\" read-syntax/skip-first-line)\n"))
      (write-view! view-path
                   "(provide old-export)\n(define old-export 1)\n"
                   2000000000)
      (parameterize ([current-library-collection-paths
                      (cons base (current-library-collection-paths))]
                     [current-provider-cache-dir cache-dir]
                     [current-provider-cache-force? #f]
                     [current-provider-cache-verbose? #f])
        (check-not-false
         (member (simplify-path view-path)
                 (source-paths-with-textual-includes (list main-path))
                 equal?))
        (define first
          (cached-provider-stub-exports
           provider-name
           provider-name
           (make-exports '(old-export))))
        (check-equal? (provider-compile-stub-exports-public-exports first)
                      '(old-export))
        (check-equal? build-count 1)
        (define warm
          (cached-provider-stub-exports
           provider-name
           provider-name
           (make-exports '(old-export should-not-be-used))))
        (check-equal? (provider-compile-stub-exports-public-exports warm)
                      '(old-export))
        (check-equal? build-count 1)
        (write-view! view-path
                     (string-append
                      "(provide old-export new-export)\n"
                      "(define old-export 1)\n"
                      "(define new-export 2)\n")
                     2000000100)
        (define refreshed
          (cached-provider-stub-exports
           provider-name
           provider-name
           (make-exports '(old-export new-export))))
        (check-equal? (provider-compile-stub-exports-public-exports refreshed)
                      '(old-export new-export))
        (check-equal? build-count 2)
        (displayln 'provider-cache-include-invalidation-ok)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (run-provider-cache-include-invalidation-smoke))
