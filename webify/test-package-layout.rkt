#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system)

(define-runtime-path webracket-repo-root* "..")

(define webracket-repo-root
  (simplify-path webracket-repo-root*))

(define path-list-separator
  (if (eq? (system-type 'os) 'windows) ";" ":"))

;; webracket-collection-parent : -> path?
;;   Return the collection parent to put on PLTCOLLECTS for this checkout.
(define (webracket-collection-parent)
  (define package-root (build-path webracket-repo-root "pkgs" "webracket"))
  (if (and (directory-exists? package-root)
           (file-exists? (build-path package-root "base.rkt"))
           (file-exists? (build-path package-root "info.rkt")))
      (build-path webracket-repo-root "pkgs")
      (raise-arguments-error
       'webracket-collection-parent
       "package collection root is not ready"
       "expected" package-root)))

;; webracket-collection-env-value : -> string?
;;   Build a PLTCOLLECTS value that exposes the package collections.
(define (webracket-collection-env-value)
  (format "~a~a~a"
          (path->string (webracket-collection-parent))
          path-list-separator
          (or (getenv "PLTCOLLECTS") "")))

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
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "ffi" "standard.ffi")))
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "ffi" "dom.ffi")))
(check-false (file-exists? (build-path webracket-repo-root "ffi" "standard.ffi"))
             "tracked FFI declarations should not live at repo root")
(check-true (file-exists? (build-path package-parent
                                      "webracket-lib"
                                      "compiler"
                                      "legacy-stdlib"
                                      "stdlib.rkt")))
(check-true (file-exists? (build-path package-parent
                                      "webracket-lib"
                                      "compiler"
                                      "legacy-stdlib"
                                      "module-exports.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "stdlib" "stdlib.rkt"))
             "tracked legacy stdlib sources should not live at repo root")
(check-false (file-exists? (build-path webracket-repo-root "stdlib" "module-exports.rkt"))
             "tracked legacy stdlib support should not live at repo root")
(check-true (file-exists? (build-path package-parent
                                      "webracket-lib"
                                      "compiler"
                                      "webify"
                                      "webify.rkt")))
(check-true (file-exists? (build-path package-parent
                                      "webracket-lib"
                                      "compiler"
                                      "webify"
                                      "module-extractor.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "webify" "webify.rkt"))
             "tracked Webify implementation should not live at repo root")
(check-false (file-exists? (build-path webracket-repo-root "webify" "module-extractor.rkt"))
             "tracked Webify module extraction implementation should not live at repo root")
(check-true (file-exists? (build-path package-root "private" "module-variable.rkt")))
(check-false (file-exists? (build-path package-root "webify" "module-variable.rkt"))
             "host-side module-variable reference implementation should be private, not a public webracket/webify collection")
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "assembler.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "assembler.rkt"))
             "compiler implementation entrypoint should not live at repo root: assembler.rkt")
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "runtime-wasm.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "runtime-wasm.rkt"))
             "compiler implementation entrypoint should not live at repo root: runtime-wasm.rkt")
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "expander.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "expander.rkt"))
             "compiler implementation entrypoint should not live at repo root: expander.rkt")
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "compiler.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "compiler.rkt"))
             "compiler implementation entrypoint should not live at repo root: compiler.rkt")
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "driver.rkt")))
(check-false (file-exists? (build-path webracket-repo-root "driver.rkt"))
             "compiler implementation entrypoint should not live at repo root: driver.rkt")
(check-true (file-exists? (build-path package-parent "webracket-lib" "compiler" "cli.rkt")))

(define package-info-source
  (file->string (build-path package-root "info.rkt")))
(define private-package-info-source
  (file->string (build-path package-parent "webracket-lib" "info.rkt")))

(check-true (string-contains? package-info-source "(define collection \"webracket\")"))
(check-true (string-contains? private-package-info-source "(define collection \"webracket-lib\")"))
(check-true (string-contains? package-info-source "\"math-lib\""))
(check-true (string-contains? package-info-source "\"webracket-lib\""))
(check-true (string-contains? private-package-info-source "\"math-lib\""))
(check-true (string-contains? private-package-info-source "\"nanopass\""))

(for ([path (in-list '("core.rkt"
                       "main.rkt"
                       "base/main.rkt"
                       "full/main.rkt"
                       "primitives.rkt"))])
  (define source
    (file->string (apply build-path package-root (string-split path "/"))))
  (check-false (regexp-match? #rx"\\(file +\"\\.\\./(\\.\\./)?webracket-lib/" source)
               (format "public package should use collection requires for webracket-lib: ~a" path)))

(parameterize ([current-library-collection-paths
                (cons package-parent (current-library-collection-paths))])
  (dynamic-require 'webracket/base #f)
  (dynamic-require 'webracket-lib/compiler/compiler #f)
  (dynamic-require 'webracket-lib/compiler/driver #f))

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
    "lang/README.md"
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

(define git-executable
  (or (find-executable-path "git")
      (let ([candidate "/usr/bin/git"])
        (and (file-exists? candidate) candidate))))

(when git-executable
  (define tracked-root-rkt-files
    (parameterize ([current-directory webracket-repo-root])
      (filter (lambda (path)
                (and (string-suffix? path ".rkt")
                     (not (string-contains? path "/"))
                     (file-exists? (build-path webracket-repo-root path))))
              (string-split
               (with-output-to-string
                 (lambda ()
                   (unless (system* git-executable "ls-files" "--" "*.rkt")
                     (error 'test-package-layout "git ls-files failed"))))
               "\n"))))

  (check-equal? tracked-root-rkt-files
                '("webracket.rkt")
                "only the CLI wrapper should be a tracked root-level Racket file"))

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
