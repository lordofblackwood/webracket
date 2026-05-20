#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/path
         racket/port
         racket/string
         racket/system
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
