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
         (error 'test-module-bridge-extraction
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
         (error 'test-module-bridge-extraction
                "could not find a racket executable"))]))

;; env-with-collections : path? -> environment-variables?
;;   Build a subprocess environment for the package-root collection layout.
(define (env-with-collections repo-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (define racket-collects
    (build-path repo-root ".." "racket" "racket" "collects"))
  (define collects
    (string-append
     (path->string (build-path repo-root "pkgs"))
     ":"
     (path->string racket-collects)))
  (environment-variables-set! env #"PLTCOLLECTS" (string->bytes/utf-8 collects))
  (environment-variables-set! env #"PLTCOMPILEDROOTS" #"/private/tmp/webracket-raco-compiled-92")
  env)

;; run-bridge-extraction-smoke : path? path? -> void?
;;   Assert that module-bridge extraction succeeds before Wasm compilation.
(define (run-bridge-extraction-smoke repo-root racket-exe)
  (define base (make-temporary-file "webracket-module-bridge-extraction-~a" 'directory))
  (define script-path (build-path base "bridge-extract-smoke.rkt"))
  (define source-path
    (build-path repo-root "pkgs" "web-easy" "examples" "hello-world" "hello-world.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file script-path
        (lambda (out)
          (display "#lang racket/base\n" out)
          (display "(require (file \"" out)
          (display (path->string (build-path repo-root "pkgs" "webracket-lib" "compiler" "driver.rkt")) out)
          (display "\"))\n" out)
          (display "(define graph\n" out)
          (display "  (webracket/base-file->local-module-graph\n" out)
          (display "   \"" out)
          (display (path->string source-path) out)
          (display "\"))\n" out)
          (display "(unless (pair? (webracket/base-local-module-graph-reports graph))\n" out)
          (display "  (error 'bridge-extract-smoke \"expected local reports\"))\n" out)
          (display "(write (webracket/base-local-module-graph-root graph))\n" out)
          (display "(newline)\n" out))
        #:exists 'truncate/replace)
      (define stdout (open-output-string))
      (define stderr (open-output-string))
      (define status
        (parameterize ([current-directory repo-root]
                       [current-output-port stdout]
                       [current-error-port stderr]
                       [current-environment-variables (env-with-collections repo-root)])
          (system*/exit-code racket-exe (path->string script-path))))
      (define output
        (string-append (get-output-string stdout)
                       (get-output-string stderr)))
      (unless (zero? status)
        (error 'test-module-bridge-extraction
               (format "module bridge extraction failed (~a): ~a" status output))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (define repo-root
    (find-repo-root (or (current-load-relative-directory)
                        (current-directory))))
  (define racket-exe (repo-racket-executable repo-root))
  (run-bridge-extraction-smoke repo-root racket-exe))
