#lang racket

;; This file keeps the historical `webracket.rkt` entrypoint stable while
;; delegating the real work to the shared CLI library and optional compile
;; server client. In the bigger picture it is the thin compatibility layer that
;; preserves the user-facing launcher while letting the compiler grow a warm
;; daemon path behind the same command-line interface.

(require "cli-lib.rkt"
         "client.rkt"
         "compile-server-common.rkt")

;; compile-server-enabled? : -> boolean?
;;   Respect WEBRACKET_COMPILE_SERVER for ordinary compile requests.
(define (compile-server-enabled?)
  (string-true-value? (getenv "WEBRACKET_COMPILE_SERVER")))

;; main : -> void?
;;   Parse the command line and dispatch locally or through the compile server.
(define (main)
  (define command (parse-webracket-cli))
  (define exit-code
    (if (and (eq? (webracket-cli-command-kind command) 'compile)
             (compile-server-enabled?))
        (run-webracket-compile-via-server
         (webracket-cli-command-payload command))
        (run-webracket-cli-command command)))
  (unless (zero? exit-code)
    (exit exit-code)))

(main)
