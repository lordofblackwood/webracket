#lang racket/base

(require racket/file
         racket/path
         racket/system)

;; find-repo-root : path? -> path?
;;   Find the checkout root that contains `webracket.rkt`.
(define (find-repo-root start)
  (let loop ([dir (simplify-path start)])
    (cond
      [(file-exists? (build-path dir "webracket.rkt"))
       dir]
      [else
       (define parent (path-only dir))
       (unless parent
         (error 'test-module-bridge-local-sibling
                "could not find repository root containing webracket.rkt"))
       (loop (path->complete-path parent))])))

;; repo-racket-executable : path? -> path?
;;   Prefer the adjacent Racket checkout with the bridge's expected toolchain.
(define (repo-racket-executable repo-root)
  (define candidate
    (build-path repo-root ".." "racket" "racket" "bin" "racket"))
  (cond
    [(file-exists? candidate) candidate]
    [else
     (or (find-executable-path "racket")
         (error 'test-module-bridge-local-sibling
                "could not find a racket executable"))]))

;; env-with-collections : path? path? -> environment-variables?
;;   Build a subprocess environment for the package-root collection layout.
(define (env-with-collections repo-root compiled-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (define racket-collects
    (build-path repo-root ".." "racket" "racket" "collects"))
  (define collects
    (string-append
     (path->string (build-path repo-root "pkgs"))
     ":"
     (path->string racket-collects)))
  (environment-variables-set! env #"PLTCOLLECTS" (string->bytes/utf-8 collects))
  (environment-variables-set! env
                              #"PLTCOMPILEDROOTS"
                              (string->bytes/utf-8 (path->string compiled-root)))
  env)

;; write-file! : path? string? -> void?
;;   Write one temporary source file.
(define (write-file! path content)
  (make-directory* (or (path-only path) (current-directory)))
  (call-with-output-file path
    (lambda (out)
      (display content out))
    #:exists 'truncate/replace))

;; run-local-sibling-smoke : path? path? -> void?
;;   Assert that sibling modules stay local and struct modules compose cleanly.
(define (run-local-sibling-smoke repo-root racket-exe)
  (define base (make-temporary-file "webracket-module-bridge-local-sibling-~a" 'directory))
  (define src-dir (build-path base "src"))
  (define compiled-root (build-path base "compiled"))
  (define script-path (build-path base "bridge-local-sibling-smoke.rkt"))
  (define helper-path (build-path src-dir "helper.rkt"))
  (define main-path (build-path src-dir "main.rkt"))
  (define struct-path (build-path src-dir "struct-main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (make-directory* src-dir)
      (make-directory* compiled-root)
      (write-file! helper-path
                   "#lang webracket/base\n(provide helper-value)\n(define helper-value 42)\n")
      (write-file! main-path
                   "#lang webracket/base\n(require \"helper.rkt\")\nhelper-value\n")
      (write-file! struct-path
                   "#lang webracket/base\n(struct point (x y))\n(point 1 2)\n")
      (call-with-output-file script-path
        (lambda (out)
          (display "#lang racket/base\n" out)
          (display "(require (file \"" out)
          (display (path->string (build-path repo-root "pkgs" "webracket-lib" "compiler" "driver.rkt")) out)
          (display "\"))\n" out)
          (display "(define (assert-local-main)\n" out)
          (display "  (define graph (webracket/base-file->local-module-graph \"" out)
          (display (path->string main-path) out)
          (display "\"))\n" out)
          (display "  (define reports (webracket/base-local-module-graph-reports graph))\n" out)
          (display "  (define external (webracket/base-external-provider-names reports))\n" out)
          (display "  (when (member 'helper external)\n" out)
          (display "    (error 'local-sibling \"helper escaped into external providers\" external))\n" out)
          (display "  (void (webracket/base-reports->module-graph\n" out)
          (display "         (webracket/base-local-module-graph-root graph)\n" out)
          (display "         reports)))\n" out)
          (display "(define (assert-struct-main)\n" out)
          (display "  (define graph (webracket/base-file->local-module-graph \"" out)
          (display (path->string struct-path) out)
          (display "\"))\n" out)
          (display "  (define reports (webracket/base-local-module-graph-reports graph))\n" out)
          (display "  (define external (webracket/base-external-provider-names reports))\n" out)
          (display "  (when (member 'racket/private/kernstruct external)\n" out)
          (display "    (error 'struct-main \"kernstruct should not escape as unsupported external provider\" external))\n" out)
          (display "  (void (webracket/base-reports->module-graph\n" out)
          (display "         (webracket/base-local-module-graph-root graph)\n" out)
          (display "         reports)))\n" out)
          (display "(assert-local-main)\n" out)
          (display "(assert-struct-main)\n" out)
          (display "(displayln 'module-bridge-local-sibling-ok)\n" out))
        #:exists 'truncate/replace)
      (define stdout (open-output-string))
      (define stderr (open-output-string))
      (define status
        (parameterize ([current-directory repo-root]
                       [current-output-port stdout]
                       [current-error-port stderr]
                       [current-environment-variables (env-with-collections repo-root compiled-root)])
          (system*/exit-code racket-exe (path->string script-path))))
      (define output
        (string-append (get-output-string stdout)
                       (get-output-string stderr)))
      (unless (zero? status)
        (error 'test-module-bridge-local-sibling
               (format "local sibling smoke failed (~a): ~a" status output)))
      (unless (regexp-match? #rx"module-bridge-local-sibling-ok" output)
        (error 'test-module-bridge-local-sibling
               (format "expected success marker: ~a" output))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (define repo-root
    (find-repo-root (or (current-load-relative-directory)
                        (current-directory))))
  (define racket-exe (repo-racket-executable repo-root))
  (run-local-sibling-smoke repo-root racket-exe))
