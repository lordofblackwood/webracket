#lang racket/base

(require rackunit
         racket/file
         racket/path
         racket/runtime-path
         racket/system)

(define-runtime-path repo-root "..")

;; package-parent : path?
;;   Checkout-local collection root used by WebRacket tests in this repo.
(define package-parent
  (build-path repo-root "pkgs"))

;; with-webracket-collections : (-> any/c) -> any/c
;;   Run thunk with the checkout-local package collections available.
(define (with-webracket-collections thunk)
  (parameterize ([current-library-collection-paths
                  (cons package-parent (current-library-collection-paths))])
    (thunk)))

;; client-module-path : path?
;;   File path for the compile-server client module under test.
(define client-module-path
  (build-path repo-root "pkgs" "webracket-lib" "compiler" "client.rkt"))

;; common-module-path : path?
;;   File path for the shared compile-server path helpers.
(define common-module-path
  (build-path repo-root "pkgs" "webracket-lib" "compiler" "compile-server-common.rkt"))

;; webracket-entrypoint-path : path?
;;   Repository-root CLI wrapper used by the explicit server workflow.
(define webracket-entrypoint-path
  (build-path repo-root "webracket.rkt"))

;; compile-server-smoke : -> void?
;;   Start the compile server, query its status, then stop it again.
(define (compile-server-smoke)
  (with-handlers ([exn:fail:filesystem? void])
    (delete-directory/files
     (with-webracket-collections
      (lambda ()
        ((dynamic-require common-module-path 'default-compile-server-state-dir))))))
  (dynamic-wind
    void
    (lambda ()
      (with-webracket-collections
       (lambda ()
         (define state-dir
           ((dynamic-require common-module-path 'default-compile-server-state-dir)))
         (define stop!
           (dynamic-require client-module-path 'stop-compile-server!))
         (define status
           (dynamic-require client-module-path 'compile-server-status))
         (define running?
           (dynamic-require client-module-path 'compile-server-status-info-running?))
         (define port
           (dynamic-require client-module-path 'compile-server-status-info-port))
         (define log-path
           (dynamic-require client-module-path 'compile-server-status-info-log-path))
         (define racket-exe
           (or (find-executable-path "racket")
               (error 'compile-server-smoke "could not find racket executable")))
         (define collection-env-value
           ((dynamic-require common-module-path 'webracket-collection-env-value)))
         (make-directory* state-dir)
         (define log-port
           (open-output-file (build-path state-dir "server-driver.log") #:exists 'append))
         (define-values (proc _stdout _stdin _stderr)
           (subprocess log-port
                       (open-input-file "/dev/null")
                       log-port
                       "/usr/bin/env"
                       (format "PLTCOLLECTS=~a" collection-env-value)
                       (path->string racket-exe)
                       (path->string webracket-entrypoint-path)
                       "--server-start"))

         (define started
           (let loop ([remaining 80])
             (define s (status state-dir))
             (cond
               [(running? s) s]
               [(zero? remaining)
                (error 'compile-server-smoke "server did not become ready")]
               [else
                (sleep 0.1)
                (loop (sub1 remaining))])))
         (check-true (running? started))
         (check-pred exact-positive-integer? (port started))
         (check-true (file-exists? (log-path started)))

         (define alive (status state-dir))
         (check-true (running? alive))
         (check-equal? (port alive) (port started))

         (check-true (stop! state-dir))
         (define stopped (status state-dir))
         (check-false (running? stopped))
         (subprocess-wait proc))))
    (lambda ()
      (with-webracket-collections
       (lambda ()
         (define state-dir
           ((dynamic-require common-module-path 'default-compile-server-state-dir)))
         (with-handlers ([exn:fail:filesystem? void])
           (delete-directory/files state-dir)))))))

(compile-server-smoke)
