#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/path
         racket/string
         "test-module-support.rkt")

(define package-parent (build-path webracket-repo-root "pkgs"))
(define package-root   (build-path package-parent "webracket"))
(define private-package-root
  (build-path package-parent "webracket-lib" "compiler" "private"))

(check-equal? (simplify-path (webracket-collection-parent))
              (simplify-path package-parent))

(check-true (file-exists? (build-path package-root "base.rkt")))
(check-true (file-exists? (build-path package-root "main.rkt")))
(check-true (file-exists? (build-path package-root "info.rkt")))

(check-true (file-exists? (build-path private-package-root "immediates.rkt")))
(check-true (file-exists? (build-path private-package-root "primitives-db.rkt")))

(define package-info-source
  (file->string (build-path package-root "info.rkt")))
(define private-package-info-source
  (file->string (build-path package-parent "webracket-lib" "info.rkt")))

(check-true (string-contains? package-info-source "(define collection \"webracket\")"))
(check-true (string-contains? private-package-info-source "(define collection \"webracket-lib\")"))

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

(define removed-root-collection-files
  '("base.rkt"
    "contract.rkt"
    "full.rkt"
    "js.rkt"
    "main.rkt"
    "promise.rkt"
    "set.rkt"
    "stream.rkt"
    "base/main.rkt"
    "base/lang/reader.rkt"
    "full/main.rkt"
    "full/lang/reader.rkt"
    "js/main.rkt"
    "lang/reader.rkt"
    "private/for.rkt"
    "syntax/contract.rkt"
    "unsafe/console.rkt"
    "unsafe/math.rkt"
    "unsafe/performance.rkt"
    "unsafe/temp.rkt"))

(for ([path (in-list removed-root-collection-files)])
  (check-false (file-exists? (apply build-path webracket-repo-root (string-split path "/")))
               (format "root collection shim should stay removed: ~a" path)))

(define private-helper-files
  '("browser-options.rkt"
    "define-foreign.rkt"
    "fasl.rkt"
    "get-env-path.rkt"
    "immediates.rkt"
    "parameters.rkt"
    "priminfo.rkt"
    "primitives-db.rkt"
    "structs.rkt"
    "timings.rkt"
    "wasm-data.rkt"
    "wasm-utils.rkt"
    "wat-identifiers.rkt"))

(for ([file (in-list private-helper-files)])
  (check-true (file-exists? (build-path private-package-root file))
              (format "compiler-private helper should live in webracket-lib: ~a" file))
  (check-false (file-exists? (build-path webracket-repo-root file))
               (format "compiler-private helper should not live at repo root: ~a" file))
  (check-false (file-exists? (build-path package-root file))
               (format "compiler-private helper should not live in public package: ~a" file)))

(define env-value (webracket-collection-env-value))
(check-true (string-prefix? env-value (path->string package-parent)))
