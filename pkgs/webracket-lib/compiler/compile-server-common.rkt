#lang racket/base

;; This file holds the small shared helpers that let the compile client and
;; server find each other inside a checkout. It keeps the collection-path,
;; state-directory, log-path, and environment conventions in one place so the
;; wrapper CLI, auto-start client, and background server all agree on where the
;; long-lived service lives.

(require racket/file
         racket/format
         racket/path
         racket/runtime-path
         racket/string)

(provide call-with-webracket-collection-paths
         default-compile-server-port
         default-compile-server-state-dir
         server-log-path
         server-state-path
         string-true-value?
         webracket-collection-env-value)

(define-runtime-path package-parent "../..")
(define-runtime-path repo-root "../../..")

(define path-list-separator
  (if (eq? (system-type 'os) 'windows) ";" ":"))

;; call-with-webracket-collection-paths : (-> any/c) -> any/c
;;   Run thunk with the checkout-local pkgs directory exposed as a collection root.
(define (call-with-webracket-collection-paths thunk)
  (parameterize ([current-library-collection-paths
                  (cons package-parent (current-library-collection-paths))])
    (thunk)))

;; default-compile-server-port : -> exact-positive-integer?
;;   Pick a stable localhost port for this checkout.
(define (default-compile-server-port)
  (+ 41000
     (modulo (abs (equal-hash-code (path->string (simplify-path repo-root))))
             20000)))

;; default-compile-server-state-dir : -> path?
;;   Return the shared temp directory for this checkout's compile server.
(define (default-compile-server-state-dir)
  (build-path "/private/tmp"
              (format "webracket-compile-server-~a"
                      (abs (equal-hash-code
                            (path->string (simplify-path repo-root)))))))

;; webracket-collection-env-value : -> string?
;;   Build a PLTCOLLECTS value that exposes this checkout's packages.
(define (webracket-collection-env-value)
  (format "~a~a~a"
          (path->string package-parent)
          path-list-separator
          (or (getenv "PLTCOLLECTS") "")))

;; server-state-path : path-string? -> path?
;;   Return the state file path inside state-dir.
(define (server-state-path state-dir)
  (build-path state-dir "server-state.sexp"))

;; server-log-path : path-string? -> path?
;;   Return the log file path inside state-dir.
(define (server-log-path state-dir)
  (build-path state-dir "server.log"))

;; string-true-value? : any/c -> boolean?
;;   Accept common truthy environment-variable spellings.
(define (string-true-value? v)
  (and (string? v)
       (member (string-downcase v)
               '("1" "true" "yes" "on" "auto"))))
