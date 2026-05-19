#lang racket/base

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-module-support.rkt")

(define package-parent (build-path webracket-repo-root "pkgs"))
(define package-root   (build-path package-parent "webracket"))

(check-equal? (simplify-path (webracket-collection-parent))
              (simplify-path package-parent))

(check-true (file-exists? (build-path package-root "base.rkt")))
(check-true (file-exists? (build-path package-root "main.rkt")))
(check-true (file-exists? (build-path package-root "info.rkt")))

(define non-package-dirs
  '("assets"
    "examples"
    "html"
    "tmp"
    "web-site"
    "web-site-new"))

(for ([dir (in-list non-package-dirs)])
  (check-false (directory-exists? (build-path package-root dir))
               (format "non-package directory leaked into package root: ~a" dir)))

(define env-value (webracket-collection-env-value))
(check-true (string-prefix? env-value (path->string package-parent)))
