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
         (error 'test-module-bridge-local-cache
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
         (error 'test-module-bridge-local-cache
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

;; run-local-cache-smoke : path? path? -> void?
;;   Assert that extracted local-module graphs reuse their disk cache on a warm run.
(define (run-local-cache-smoke repo-root racket-exe)
  (define base (make-temporary-file "webracket-module-bridge-local-cache-~a" 'directory))
  (define cache-dir (build-path base "provider-cache"))
  (define script-path (build-path base "bridge-local-cache-smoke.rkt"))
  (define source-path
    (build-path repo-root "pkgs" "web-easy" "examples" "hello-world" "hello-world.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file script-path
        (lambda (out)
          (display "#lang racket/base\n" out)
          (display "(require racket/file\n" out)
          (display "         (file \"" out)
          (display (path->string (build-path repo-root "pkgs" "webracket-lib" "compiler" "driver.rkt")) out)
          (display "\"))\n" out)
          (display "(current-provider-cache-dir \"" out)
          (display (path->string cache-dir) out)
          (display "\")\n" out)
          (display "(current-provider-cache-force? #f)\n" out)
          (display "(current-provider-cache-verbose? #t)\n" out)
          (display "(define source-file \"" out)
          (display (path->string source-path) out)
          (display "\")\n" out)
          (display "(define (cache-mtime)\n" out)
          (display "  (define cache-path (local-module-graph-cache-path source-file))\n" out)
          (display "  (and (file-exists? cache-path)\n" out)
          (display "       (file-or-directory-modify-seconds cache-path)))\n" out)
          (display "(define graph-a (webracket/base-file->local-module-graph source-file))\n" out)
          (display "(define mtime-a (cache-mtime))\n" out)
          (display "(unless mtime-a\n" out)
          (display "  (error 'bridge-local-cache-smoke \"expected local module graph cache file\"))\n" out)
          (display "(define graph-b (webracket/base-file->local-module-graph source-file))\n" out)
          (display "(define mtime-b (cache-mtime))\n" out)
          (display "(unless (equal? (webracket/base-local-module-graph-root graph-a)\n" out)
          (display "                (webracket/base-local-module-graph-root graph-b))\n" out)
          (display "  (error 'bridge-local-cache-smoke \"expected cached graph root to match\"))\n" out)
          (display "(unless (equal? mtime-a mtime-b)\n" out)
          (display "  (error 'bridge-local-cache-smoke \"expected warm local graph cache hit without rewrite\"))\n" out)
          (display "(displayln 'local-module-graph-cache-ok)\n" out))
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
        (error 'test-module-bridge-local-cache
               (format "module bridge local-cache smoke failed (~a): ~a" status output)))
      (unless (regexp-match? #rx"local module graph hit" output)
        (error 'test-module-bridge-local-cache
               (format "expected warm local module graph hit log: ~a" output))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (define repo-root
    (find-repo-root (or (current-load-relative-directory)
                        (current-directory))))
  (define racket-exe (repo-racket-executable repo-root))
  (run-local-cache-smoke repo-root racket-exe))
