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
         (error 'test-core-host-compat
                "could not find repository root containing webracket.rkt"))
       (loop (path->complete-path parent))])))

;; host-racket-executable : -> path?
;;   Use the host `racket` executable to catch compatibility regressions.
(define (host-racket-executable)
  (or (find-executable-path "racket")
      (error 'test-core-host-compat
             "could not find the host racket executable")))

;; env-with-package-collections : path? -> environment-variables?
;;   Build a subprocess environment that adds the repo package tree.
(define (env-with-package-collections repo-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (define collects
    (string-append
     (path->string (build-path repo-root "pkgs"))
     ":"))
  (environment-variables-set! env #"PLTCOLLECTS" (string->bytes/utf-8 collects))
  env)

;; run-core-host-compat-smoke : path? path? -> void?
;;   Assert that `pkgs/webracket/core.rkt` loads under the host Racket.
(define (run-core-host-compat-smoke repo-root racket-exe)
  (define base (make-temporary-file "webracket-core-host-compat-~a" 'directory))
  (define script-path (build-path base "core-host-compat-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file script-path
        (lambda (out)
          (display "#lang racket/base\n" out)
          (display "(require (file \"" out)
          (display (path->string (build-path repo-root "pkgs" "webracket" "core.rkt")) out)
          (display "\"))\n" out)
          (display "(displayln 'core-host-compat-ok)\n" out))
        #:exists 'truncate/replace)
      (define stdout (open-output-string))
      (define stderr (open-output-string))
      (define status
        (parameterize ([current-directory repo-root]
                       [current-output-port stdout]
                       [current-error-port stderr]
                       [current-environment-variables
                        (env-with-package-collections repo-root)])
          (system*/exit-code racket-exe (path->string script-path))))
      (define output
        (string-append (get-output-string stdout)
                       (get-output-string stderr)))
      (unless (zero? status)
        (error 'test-core-host-compat
               (format "host core load failed (~a): ~a" status output))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (define repo-root
    (find-repo-root (or (current-load-relative-directory)
                        (current-directory))))
  (define racket-exe (host-racket-executable))
  (run-core-host-compat-smoke repo-root racket-exe))
